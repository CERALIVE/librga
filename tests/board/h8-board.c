#define main inherited_bench_main
#include "rga-convert-bench.c"
#undef main
#include <sys/stat.h>

static uint8_t *load(const char *path,size_t size)
{
    uint8_t *p=malloc(size); FILE *f=fopen(path,"rb");
    if (!p || !f || fread(p,1,size,f)!=size || fgetc(f)!=EOF || fclose(f)) exit(2);
    return p;
}
static int score(const char *name,const uint8_t *actual,size_t size,double *value)
{
    uint8_t *ref=load(name,size); *value=oracle_psnr(actual,ref,size); free(ref);
    return isnan(*value) ? 2 : 0;
}
int main(int argc,char **argv)
{
    if (argc!=2 || chdir(argv[1])) return 2;
#ifndef TASK43_QEMU_FIXTURE
    struct stat st;
    if (dlsym(RTLD_DEFAULT,"fake_rga_active")) return 2;
    if (stat("/dev/rga",&st) || !S_ISCHR(st.st_mode)) return 77;
#else
    fprintf(stderr,"QEMU-FIXTURE: oracle-backed outputs, not silicon/CSC validation\n");
#endif
    FILE *csv=fdopen(dup(STDOUT_FILENO),"w");
    if (!csv || dup2(STDERR_FILENO,STDOUT_FILENO)<0) return 2;
    const size_t pixels=3840UL*2160;
    double default709=NAN,explicit709=NAN;
    fprintf(csv,"cell,mode,reference,psnr_db,status\n");
    for (int kind=0;kind<4;kind++) {
        int sf=kind==0 ? RK_FORMAT_BGR_888 : kind==2 ? RK_FORMAT_YCbCr_422_SP : RK_FORMAT_YCbCr_420_SP;
        int df=kind==1 ? RK_FORMAT_BGR_888 : RK_FORMAT_YCbCr_420_SP;
        size_t input=pixels*(kind==0 ? 6 : kind==2 ? 4 : 3)/2;
        size_t output=kind==1 ? pixels*3 : kind==3 ? pixels*3/8 : pixels*3/2;
        const char *input_name=kind==0 ? "bgr.raw" : kind==2 ? "nv16.raw" : "nv12.raw";
        uint8_t *host=load(input_name,input);
        struct buffer src={.fd=-1},dst={.fd=-1};
#ifndef TASK43_QEMU_FIXTURE
        if (allocate(&src,input) || allocate(&dst,output)) return 2;
        if (sync_cpu(&src,DMA_BUF_SYNC_START|DMA_BUF_SYNC_WRITE)) return 2;
        memcpy(src.data,host,input);
        if (sync_cpu(&src,DMA_BUF_SYNC_END|DMA_BUF_SYNC_WRITE)) return 2;
#else
        dst.data=malloc(output); if (!dst.data) return 2;
#endif
        free(host);
        for (int mode=0;mode<(kind<2 ? 3 : 2);mode++) {
            int dw=kind==3 ? 1920 : 3840,dh=kind==3 ? 1080 : 2160;
            rga_buffer_t s=wrapbuffer_fd(src.fd,3840,2160,sf,3840,2160);
            rga_buffer_t d=wrapbuffer_fd(dst.fd,dw,dh,df,dw,dh);
            int csc=kind==0 ? (mode==1 ? IM_RGB_TO_YUV_BT601_LIMIT : IM_RGB_TO_YUV_BT709_LIMIT) :
                (mode==1 ? IM_YUV_TO_RGB_BT601_LIMIT : IM_YUV_TO_RGB_BT709_LIMIT);
            if (!mode) csc=IM_COLOR_SPACE_DEFAULT;
            if (kind==2) csc=mode ? IM_RGB_TO_YUV_BT709_LIMIT : IM_COLOR_SPACE_DEFAULT;
            IM_STATUS status;
#ifndef TASK43_QEMU_FIXTURE
            if (sync_cpu(&dst,DMA_BUF_SYNC_START|DMA_BUF_SYNC_WRITE)) return 2;
            memset(dst.data,0xa5,output);
            if (sync_cpu(&dst,DMA_BUF_SYNC_END|DMA_BUF_SYNC_WRITE)) return 2;
            status=kind==3 ? imresize_t(s,d,0,0,mode ? IM_INTERP(IM_INTERP_CUBIC,IM_INTERP_CUBIC) : IM_INTERP_DEFAULT,1) : imcvtcolor_t(s,d,sf,df,csc,1);
#else
            (void)s; (void)d; (void)csc;
            const char *reference_name=kind==0 ? (mode==2 ? "bgr-709-nv12.raw" : "bgr-601-nv12.raw") : kind==1 ?
                (mode==2 ? "nv12-709-bgr.raw" : "nv12-601-bgr.raw") : kind==2 ? "nv12.raw" : "lanczos-nv12.raw";
            uint8_t *reference_data=load(reference_name,output); memcpy(dst.data,reference_data,output); free(reference_data);
            status=(kind==2 && mode) ? IM_STATUS_ILLEGAL_PARAM : IM_STATUS_SUCCESS;
#endif
            if (kind==2 && mode) {
                fprintf(csv,"nv16-nv12,csc-negative,not-applicable,nan,%d\n",status);
                if (status==IM_STATUS_SUCCESS) { fprintf(stderr,"YUV-YUV CSC unexpectedly accepted; investigate\n"); return 2; }
                continue;
            }
            if (status!=IM_STATUS_SUCCESS) { fprintf(stderr,"H8 kind=%d mode=%d status=%d\n",kind,mode,status); return 2; }
#ifndef TASK43_QEMU_FIXTURE
            if (sync_cpu(&dst,DMA_BUF_SYNC_START|DMA_BUF_SYNC_READ)) return 2;
#endif
            const char *names[]={"bgr-nv12","nv12-bgr","nv16-nv12","scale-4k-1080p"};
            const char *modes[]={"default","601-limited","709-limited"};
            for (int ref=0;ref<(kind<2 ? 2 : 1);ref++) {
                const char *file=kind==0 ? (ref ? "bgr-709-nv12.raw" : "bgr-601-nv12.raw") :
                    kind==1 ? (ref ? "nv12-709-bgr.raw" : "nv12-601-bgr.raw") : kind==2 ? "nv12.raw" : "lanczos-nv12.raw";
                double psnr; if (score(file,dst.data,output,&psnr)) return 2;
                fprintf(csv,"%s,%s,%s,%.6f,%d\n",names[kind],kind==3 ? (mode ? "cubic" : "default") : modes[mode],
                    kind==3 ? "lanczos3" : kind==2 ? "709-same-colourimetry" : ref ? "709-limited" : "601-limited",psnr,status);
                if (kind==0 && ref==1 && mode==0) default709=psnr;
                if (kind==0 && ref==1 && mode==2) explicit709=psnr;
            }
#ifndef TASK43_QEMU_FIXTURE
            if (sync_cpu(&dst,DMA_BUF_SYNC_END|DMA_BUF_SYNC_READ)) return 2;
#endif
            fflush(csv);
        }
#ifndef TASK43_QEMU_FIXTURE
        release(&src); release(&dst);
#else
        free(dst.data);
#endif
    }
    if (isnan(default709) || isnan(explicit709) || !(explicit709-default709>=1)) {
        fprintf(stderr,"explicit-709 negative control failed: default=%f explicit=%f\n",default709,explicit709); return 2;
    }
    fprintf(stderr,"explicit-709 beats default against 709 by %.6f dB\n",explicit709-default709);
    fclose(csv);
    return 0;
}
