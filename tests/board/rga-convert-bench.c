// Modified by CeraLive 2026-09-05: bounded G-A routing and soak modes.
#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/dma-buf.h>
#include <linux/dma-heap.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include "im2d.h"
#include "RgaApi.h"
#include "../oracle/oracle.h"
struct buffer { int fd; size_t size; uint8_t *data; };
struct cell { const char *name; int sw,sh,dw,dh,format,crop,rotate,csc; };
static double deadline;
static int sync_cpu(struct buffer *b, uint64_t flags)
{
    struct dma_buf_sync sync={.flags=flags};
    int rc;
    do { rc=ioctl(b->fd,DMA_BUF_IOCTL_SYNC,&sync); } while (rc<0 && errno==EINTR);
    if (rc<0) perror("DMA_BUF_IOCTL_SYNC");
    return rc;
}
static int allocate(struct buffer *b, size_t size)
{
    int heap=open("/dev/dma_heap/system",O_RDWR|O_CLOEXEC);
    if (heap<0) { perror("dma_heap/system"); return -1; }
    struct dma_heap_allocation_data a={.len=size,.fd_flags=O_RDWR|O_CLOEXEC};
    int rc=ioctl(heap,DMA_HEAP_IOCTL_ALLOC,&a); close(heap);
    if (rc<0) { perror("DMA_HEAP_IOCTL_ALLOC"); return -1; }
    b->fd=(int)a.fd; b->size=size;
    b->data=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_SHARED,b->fd,0);
    if (b->data==MAP_FAILED) { close(b->fd); b->fd=-1; b->data=NULL; return -1; }
    return 0;
}
static void release(struct buffer *b)
{ if (b->data) munmap(b->data,b->size); if (b->fd>=0) close(b->fd); }
static int census(void)
{
    DIR *d=opendir("/proc/self/fd"); if (!d) return -1;
    int n=0; struct dirent *e;
    while ((e=readdir(d))) if (strcmp(e->d_name,".") && strcmp(e->d_name,"..")) n++;
    closedir(d); return n;
}
static double now_us(void)
{ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec*1e6+t.tv_nsec/1e3; }
static void fill(uint8_t *p, const struct cell *c)
{
    static const uint8_t bars[8][3]={{255,255,255},{255,255,0},{0,255,255},{0,255,0},{255,0,255},{255,0,0},{0,0,255},{0,0,0}};
    int w=c->sw,h=c->sh;
    if (c->format==RK_FORMAT_BGR_888) {
        for (int y=0;y<h;y++) for (int x=0;x<w;x++) for (int k=0;k<3;k++)
            p[3*(y*w+x)+k]=(uint8_t)(bars[x*8/w][2-k]*(.5+.5*y/(h-1)));
    } else {
        for (int y=0;y<h;y++) for (int x=0;x<w;x++) p[y*w+x]=(uint8_t)(16+219*x/(w-1));
        int ch=c->format==RK_FORMAT_YCbCr_422_SP ? h : h/2;
        for (int y=0;y<ch;y++) for (int x=0;x<w;x+=2) {
            p[w*h+y*w+x]=(uint8_t)(32+192*y/(ch-1));
            p[w*h+y*w+x+1]=(uint8_t)(32+192*x/(w-2));
        }
    }
}
static void reference(const uint8_t *p, uint8_t *out, const struct cell *c, enum oracle_filter filter)
{
    int w=c->sw,h=c->sh,dw=c->dw,dh=c->dh;
    if (c->format==RK_FORMAT_BGR_888) {
        for (int y=0;y<h;y+=2) for (int x=0;x<w;x+=2) {
            unsigned u=0,v=0;
            for (int j=0;j<2;j++) for (int i=0;i<2;i++) {
                const uint8_t *b=p+3*((y+j)*w+x+i);
                uint8_t rgb[3]={b[2],b[1],b[0]},yuv[3];
                oracle_rgb_to_yuv(rgb,yuv,c->csc>=3 ? ORACLE_BT709 : ORACLE_BT601,
                                  c->csc==2 || c->csc==4 ? ORACLE_FULL : ORACLE_LIMITED);
                out[(y+j)*w+x+i]=yuv[0]; u+=yuv[1]; v+=yuv[2];
            }
            out[w*h+y/2*w+x]=(uint8_t)((u+2)/4); out[w*h+y/2*w+x+1]=(uint8_t)((v+2)/4);
        }
        return;
    }
    for (int plane=0;plane<3;plane++) {
        int step=plane ? 2 : 1, sw=w/step, sh=plane && c->format!=RK_FORMAT_YCbCr_422_SP ? h/2 : h;
        int ow=dw/step,oh=plane ? dh/2 : dh;
        const uint8_t *s=p+(plane ? w*h+plane-1 : 0);
        uint8_t *d=out+(plane ? dw*dh+plane-1 : 0);
        if (c->rotate) {
            for (int y=0;y<oh;y++) for (int x=0;x<ow;x++) d[y*dw+x*step]=s[(sh-1-x)*w+y*step];
        } else {
            if (c->crop) { s+= (plane ? 4 : 8)*w+8; sw=ow; sh=oh; }
            oracle_resample(s,sw,sh,w,step,d,ow,oh,dw,step,filter);
        }
    }
}
static int run_cell(const struct cell *c, int iterations, int legacy, enum oracle_filter filter, double minimum)
{
    struct buffer src={.fd=-1},dst={.fd=-1}; int result=1;
    size_t input=(size_t)c->sw*c->sh*(c->format==RK_FORMAT_BGR_888 ? 6 : c->format==RK_FORMAT_YCbCr_422_SP ? 4 : 3)/2;
    size_t output=(size_t)c->dw*c->dh*3/2;
    uint8_t *expected=malloc(output),*host=malloc(input);
    if (!expected || !host) goto done;
    fill(host,c); reference(host,expected,c,filter);
    if (allocate(&src,input) || allocate(&dst,output)) goto done;
    if (sync_cpu(&src,DMA_BUF_SYNC_START|DMA_BUF_SYNC_WRITE)) goto done;
    memcpy(src.data,host,input);
    if (sync_cpu(&src,DMA_BUF_SYNC_END|DMA_BUF_SYNC_WRITE)) goto done;
    void (*begin)(void)=NULL; void (*end)(void)=NULL;
    *(void **)(&begin)=dlsym(RTLD_DEFAULT,"rga_timing_begin");
    *(void **)(&end)=dlsym(RTLD_DEFAULT,"rga_timing_end");
    double total=0;
    int completed=0;
    for (int n=0;n<iterations && (!deadline || now_us()<deadline);n++) {
        if (sync_cpu(&dst,DMA_BUF_SYNC_START|DMA_BUF_SYNC_WRITE)) goto done;
        memset(dst.data,0xa5,output);
        if (sync_cpu(&dst,DMA_BUF_SYNC_END|DMA_BUF_SYNC_WRITE)) goto done;
        double start=now_us(); if (begin) begin();
        int ok;
        if (legacy) {
            rga_info_t s={0},d={0}; s.fd=src.fd; d.fd=dst.fd; s.mmuFlag=d.mmuFlag=1;
            s.rotation=c->rotate ? HAL_TRANSFORM_ROT_90 : 0;
            rga_set_rect(&s.rect,c->crop ? 8 : 0,c->crop ? 8 : 0,c->crop ? c->dw : c->sw,c->crop ? c->dh : c->sh,c->sw,c->sh,c->format);
            rga_set_rect(&d.rect,0,0,c->dw,c->dh,c->dw,c->dh,RK_FORMAT_YCbCr_420_SP);
            ok=c_RkRgaBlit(&s,&d,NULL)==0;
        } else {
            rga_buffer_t s=wrapbuffer_fd(src.fd,c->sw,c->sh,c->format,c->sw,c->sh);
            rga_buffer_t d=wrapbuffer_fd(dst.fd,c->dw,c->dh,RK_FORMAT_YCbCr_420_SP,c->dw,c->dh),empty={0};
            im_rect crop={0},zero={0};
            if (c->crop) crop=(im_rect){8,8,c->dw,c->dh};
            if (c->csc) {
                const int spaces[]={0,IM_YUV_BT601_LIMIT_RANGE,IM_YUV_BT601_FULL_RANGE,IM_YUV_BT709_LIMIT_RANGE,IM_YUV_BT709_FULL_RANGE};
                imsetColorSpace(&s,IM_RGB_FULL); imsetColorSpace(&d,spaces[c->csc]);
            }
            IM_STATUS status=improcess(s,d,empty,crop,zero,zero,IM_SYNC|(c->rotate ? IM_HAL_TRANSFORM_ROT_90 : 0));
            ok=status==IM_STATUS_SUCCESS;
            if (!ok) fprintf(stderr,"%s: %s\n",c->name,imStrError(status));
        }
        if (end) end();
        total+=now_us()-start;
        if (!ok) goto done;
        if (sync_cpu(&dst,DMA_BUF_SYNC_START|DMA_BUF_SYNC_READ)) goto done;
        double psnr=oracle_psnr(dst.data,expected,output);
        int end_rc=sync_cpu(&dst,DMA_BUF_SYNC_END|DMA_BUF_SYNC_READ);
        printf("%s,%s,%d,%.3f,%.6f\n",c->name,legacy ? "legacy" : "improcess",n,total/(n+1),psnr);
        if (end_rc || isnan(psnr) || psnr<minimum) goto done;
        completed++;
    }
    printf("completed=%d cell=%s\n",completed,c->name);
    result=0;
done:
    release(&src); release(&dst); free(expected); free(host); return result;
}
int main(int argc, char **argv)
{
    int iterations=10,selftest=0,explicit_csc=0,core=0,routing=0,soak=0,imonly=0; double minimum=30;
    enum oracle_filter filter=ORACLE_BOX;
    for (int i=1;i<argc;i++) {
        if (!strcmp(argv[i],"--selftest")) { selftest=1; iterations=1; minimum=INFINITY; }
        else if (!strcmp(argv[i],"--explicit-csc")) explicit_csc=1;
        else if (!strcmp(argv[i],"--bilinear")) filter=ORACLE_BILINEAR;
        else if (!strcmp(argv[i],"--improcess-only")) imonly=1;
        else if (!strcmp(argv[i],"--routing")) { routing=1; iterations=1000; }
        else if (!strcmp(argv[i],"--soak")) { soak=1; iterations=1000000; }
        else if (!strcmp(argv[i],"--core") && i+1<argc) { char *end; long n=strtol(argv[++i],&end,10); if (*end || (n!=1 && n!=2 && n!=4)) return 2; core=(int)n; }
        else if (!strcmp(argv[i],"--iterations") && i+1<argc) { char *end; long n=strtol(argv[++i],&end,10); if (*end || n<1 || n>1000000) return 2; iterations=(int)n; }
        else { fprintf(stderr,"usage: %s [--selftest] [--iterations N] [--explicit-csc] [--bilinear]\n",argv[0]); return 2; }
    }
    if (dlsym(RTLD_DEFAULT,"fake_rga_active")) { fprintf(stderr,"refusing fake RGA for hardware bench\n"); return 1; }
    if (access("/dev/rga",R_OK|W_OK) || access("/dev/dma_heap/system",R_OK|W_OK)) { perror("hardware preflight"); return 77; }
    if (c_RkRgaInit()) return 1;
    if (core && imconfig(IM_CONFIG_SCHEDULER_CORE,core)!=IM_STATUS_SUCCESS) return 1;
    int before=census(),rc=0;
    const struct cell cells[]={
        {"nv16-nv12",1280,720,1280,720,RK_FORMAT_YCbCr_422_SP,0,0,0},
        {"bgr-nv12",1280,720,1280,720,RK_FORMAT_BGR_888,0,0,0},
        {"scale-4k-1080p",3840,2160,1920,1080,RK_FORMAT_YCbCr_420_SP,0,0,0},
        {"crop",1280,720,640,352,RK_FORMAT_YCbCr_420_SP,1,0,0},
        {"rotate-90",1280,720,720,1280,RK_FORMAT_YCbCr_420_SP,0,1,0}};
    puts("cell,api,iteration,mean_total_us,psnr_db");
    if (routing) { const struct cell c={"routing-copy",128,64,128,64,RK_FORMAT_YCbCr_420_SP,0,0,0}; rc=run_cell(&c,1000,0,filter,INFINITY); }
    else if (soak) { const struct cell c={"soak-4k-nv16",3840,2160,3840,2160,RK_FORMAT_YCbCr_422_SP,0,0,0}; deadline=now_us()+295e6; rc=run_cell(&c,iterations,0,filter,minimum); }
    else if (selftest) { const struct cell c={"copy-selftest",64,64,64,64,RK_FORMAT_YCbCr_420_SP,0,0,0}; rc=run_cell(&c,1,0,filter,minimum); }
    else {
        for (size_t i=0;i<sizeof cells/sizeof cells[0];i++) for (int api=0;api<(imonly ? 1 : 2);api++) rc|=run_cell(&cells[i],iterations,api,filter,minimum);
        if (explicit_csc) for (int csc=1;csc<=4;csc++) { struct cell c=cells[1]; c.csc=csc; const char *names[]={"","bgr-601-limited","bgr-601-full","bgr-709-limited","bgr-709-full"}; c.name=names[csc]; rc|=run_cell(&c,iterations,0,filter,minimum); }
    }
    int after=census(); printf("fd_census_before=%d after=%d\n",before,after);
    c_RkRgaDeInit();
    return rc || before<0 || before!=after;
}
