/* SPDX-License-Identifier: Apache-2.0 */
#include "oracle.h"
#include <math.h>
static uint8_t quantize(double x) { return (uint8_t)lround(fmin(255.0, fmax(0.0, x))); }
static void coefficients(enum oracle_matrix m, double *kr, double *kb)
{ *kr = m == ORACLE_BT709 ? .2126 : .299; *kb = m == ORACLE_BT709 ? .0722 : .114; }
void oracle_rgb_to_yuv(const uint8_t rgb[3], uint8_t yuv[3], enum oracle_matrix m, enum oracle_range range)
{
    double kr, kb; coefficients(m, &kr, &kb);
    double r=rgb[0]/255.0, g=rgb[1]/255.0, b=rgb[2]/255.0;
    double y=kr*r+(1-kr-kb)*g+kb*b;
    double ys=range == ORACLE_LIMITED ? 219 : 255, cs=range == ORACLE_LIMITED ? 224 : 255;
    yuv[0]=quantize((range == ORACLE_LIMITED ? 16 : 0)+ys*y);
    yuv[1]=quantize(128+cs*(b-y)/(2*(1-kb)));
    yuv[2]=quantize(128+cs*(r-y)/(2*(1-kr)));
}
void oracle_yuv_to_rgb(const uint8_t yuv[3], uint8_t rgb[3], enum oracle_matrix m, enum oracle_range range)
{
    double kr, kb; coefficients(m, &kr, &kb);
    double y=(yuv[0]-(range == ORACLE_LIMITED ? 16.0 : 0))/(range == ORACLE_LIMITED ? 219 : 255);
    double cb=(yuv[1]-128.0)/(range == ORACLE_LIMITED ? 224 : 255);
    double cr=(yuv[2]-128.0)/(range == ORACLE_LIMITED ? 224 : 255);
    double r=y+2*(1-kr)*cr, b=y+2*(1-kb)*cb;
    rgb[0]=quantize(255*r); rgb[1]=quantize(255*(y-kr*r-kb*b)/(1-kr-kb)); rgb[2]=quantize(255*b);
}
double oracle_psnr(const uint8_t *a, const uint8_t *b, size_t n)
{
    if (!n) return NAN;
    double sum=0;
    for (size_t i=0;i<n;i++) { double d=(double)a[i]-b[i]; sum+=d*d; }
    return sum == 0 ? INFINITY : 10*log10(255.0*255*n/sum);
}
static double pixel(const uint8_t *p, int w, int h, int stride, int step, int x, int y)
{
    if (x<0) x=0;
    if (y<0) y=0;
    if (x>=w) x=w-1;
    if (y>=h) y=h-1;
    return p[y*stride+x*step];
}
void oracle_resample(const uint8_t *s, int sw, int sh, int stride, int step,
                     uint8_t *d, int dw, int dh, int ds, int dt, enum oracle_filter f)
{
    for (int y=0;y<dh;y++) for (int x=0;x<dw;x++) {
        double v=0;
        if (f == ORACLE_BILINEAR) {
            double sx=(x+.5)*sw/dw-.5, sy=(y+.5)*sh/dh-.5;
            int ix=(int)floor(sx), iy=(int)floor(sy);
            double ax=sx-ix, ay=sy-iy;
            v=(1-ay)*((1-ax)*pixel(s,sw,sh,stride,step,ix,iy)+ax*pixel(s,sw,sh,stride,step,ix+1,iy))
              +ay*((1-ax)*pixel(s,sw,sh,stride,step,ix,iy+1)+ax*pixel(s,sw,sh,stride,step,ix+1,iy+1));
        } else {
            double x0=(double)x*sw/dw,x1=(double)(x+1)*sw/dw;
            double y0=(double)y*sh/dh,y1=(double)(y+1)*sh/dh;
            for (int j=(int)floor(y0);j<(int)ceil(y1);j++)
                for (int i=(int)floor(x0);i<(int)ceil(x1);i++)
                    v+=pixel(s,sw,sh,stride,step,i,j)*(fmin(i+1,x1)-fmax(i,x0))*(fmin(j+1,y1)-fmax(j,y0));
            v/=(x1-x0)*(y1-y0);
        }
        d[y*ds+x*dt]=quantize(v);
    }
}
