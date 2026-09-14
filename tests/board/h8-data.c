#include "../oracle/oracle.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void save(const char *name,const uint8_t *p,size_t size)
{
    FILE *f=fopen(name,"wb");
    if (!f || fwrite(p,1,size,f)!=size || fclose(f)) exit(2);
    fprintf(stderr,"prepared %s (%zu bytes)\n",name,size);
}
static int clamp(int x,int limit) { return x<0 ? 0 : x>=limit ? limit-1 : x; }
static double sinc(double x) { return x==0 ? 1 : sin(M_PI*x)/(M_PI*x); }
static void lanczos_half(const uint8_t *src,uint8_t *dst,int w,int h,int step,int stride)
{
    double weights[12],sum=0;
    for (int i=0;i<12;i++) { double x=(i-5.5)/2; weights[i]=sinc(x)*sinc(x/3); sum+=weights[i]; }
    for (int i=0;i<12;i++) weights[i]/=sum;
    double *tmp=malloc((size_t)(w/2)*h*sizeof(double)); if (!tmp) exit(2);
    for (int y=0;y<h;y++) for (int x=0;x<w/2;x++) {
        double v=0;
        for (int k=0;k<12;k++) v+=weights[k]*src[y*stride+clamp(x*2+k-5,w)*step];
        tmp[y*(w/2)+x]=v;
    }
    for (int y=0;y<h/2;y++) for (int x=0;x<w/2;x++) {
        double v=0;
        for (int k=0;k<12;k++) v+=weights[k]*tmp[clamp(y*2+k-5,h)*(w/2)+x];
        dst[y*(stride/2)+x*step]=(uint8_t)fmax(0,fmin(255,floor(v+.5)));
    }
    free(tmp);
}
static void bgr_to_nv12(const uint8_t *bgr,uint8_t *nv12,int w,int h,enum oracle_matrix matrix)
{
    for (int y=0;y<h;y+=2) for (int x=0;x<w;x+=2) {
        unsigned u=0,v=0;
        for (int j=0;j<2;j++) for (int i=0;i<2;i++) {
            const uint8_t *b=bgr+3*((y+j)*w+x+i);
            uint8_t rgb[3]={b[2],b[1],b[0]},yuv[3];
            oracle_rgb_to_yuv(rgb,yuv,matrix,ORACLE_LIMITED);
            nv12[(y+j)*w+x+i]=yuv[0]; u+=yuv[1]; v+=yuv[2];
        }
        nv12[w*h+(y/2)*w+x]=(u+2)/4; nv12[w*h+(y/2)*w+x+1]=(v+2)/4;
    }
}
int main(int argc,char **argv)
{
    if (argc==2 && !strcmp(argv[1],"--selftest")) {
        uint8_t src[256],dst[64]; memset(src,93,sizeof src);
        lanczos_half(src,dst,16,16,1,16);
        for (size_t i=0;i<sizeof dst;i++) if (dst[i]!=93) return 2;
        for (int y=0;y<16;y++) for (int x=0;x<16;x++) src[y*16+x]=x*8;
        lanczos_half(src,dst,16,16,1,16);
        if (dst[3]!=52 || dst[4]!=68) return 2;
        puts("PASS: Lanczos-3 half-scale constant and interior affine anchors"); return 0;
    }
    if (argc!=2 || chdir(argv[1])) return 2;
    const int w=3840,h=2160; size_t pixels=(size_t)w*h;
    uint8_t *bgr=malloc(pixels*3),*nv12=malloc(pixels*3/2),*out=malloc(pixels*3);
    if (!bgr || !nv12 || !out) return 2;
    const uint8_t bars[8][3]={{255,255,255},{255,255,0},{0,255,255},{0,255,0},{255,0,255},{255,0,0},{0,0,255},{0,0,0}};
    for (int y=0;y<h;y++) for (int x=0;x<w;x++) for (int k=0;k<3;k++)
        bgr[3*(y*w+x)+k]=bars[x*8/w][2-k]*(.5+.5*y/(h-1));
    save("bgr.raw",bgr,pixels*3);
    bgr_to_nv12(bgr,nv12,w,h,ORACLE_BT601); save("bgr-601-nv12.raw",nv12,pixels*3/2);
    bgr_to_nv12(bgr,nv12,w,h,ORACLE_BT709); save("bgr-709-nv12.raw",nv12,pixels*3/2);
    save("nv12.raw",nv12,pixels*3/2);
    memcpy(out,nv12,pixels);
    for (int y=0;y<h;y++) memcpy(out+pixels+y*w,nv12+pixels+(y/2)*w,w);
    save("nv16.raw",out,pixels*2);
    for (int matrix=0;matrix<2;matrix++) {
        for (int y=0;y<h;y++) for (int x=0;x<w;x++) {
            uint8_t yuv[3]={nv12[y*w+x],nv12[pixels+(y/2)*w+(x/2)*2],nv12[pixels+(y/2)*w+(x/2)*2+1]},rgb[3];
            oracle_yuv_to_rgb(yuv,rgb,matrix ? ORACLE_BT709 : ORACLE_BT601,ORACLE_LIMITED);
            for (int k=0;k<3;k++) out[3*(y*w+x)+k]=rgb[2-k];
        }
        save(matrix ? "nv12-709-bgr.raw" : "nv12-601-bgr.raw",out,pixels*3);
    }
    lanczos_half(nv12,out,w,h,1,w);
    lanczos_half(nv12+pixels,out+pixels/4,w/2,h/2,2,w);
    lanczos_half(nv12+pixels+1,out+pixels/4+1,w/2,h/2,2,w);
    save("lanczos-nv12.raw",out,pixels*3/8);
    free(bgr); free(nv12); free(out); return 0;
}
