/* SPDX-License-Identifier: Apache-2.0 */
#include "oracle.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define CHECK(x) do { if (!(x)) { fprintf(stderr,"oracle check failed line %d\n",__LINE__); return 1; } } while (0)
int main(void)
{
    const uint8_t colors[8][3]={{0,0,0},{255,255,255},{255,0,0},{0,255,0},{0,0,255},{255,255,0},{0,255,255},{255,0,255}};
    const uint8_t expected[2][8][3]={
        {{16,128,128},{235,128,128},{81,90,240},{145,54,34},{41,240,110},{210,16,146},{170,166,16},{106,202,222}},
        {{16,128,128},{235,128,128},{63,102,240},{173,42,26},{32,240,118},{219,16,138},{188,154,16},{78,214,230}}};
    for (int m=0;m<2;m++) {
        uint8_t actual[192], reference[192];
        for (int y=0;y<8;y++) for (int x=0;x<8;x++) {
            oracle_rgb_to_yuv(colors[x],actual+3*(y*8+x),m,ORACLE_LIMITED);
            memcpy(reference+3*(y*8+x),expected[m][x],3);
        }
        CHECK(isinf(oracle_psnr(actual,reference,sizeof actual)));
        printf("BT.%s limited 8x8 hand-computed bars: PSNR=inf\n",m ? "709" : "601");
        for (int range=0;range<2;range++) for (int i=0;i<8;i++) {
            uint8_t yuv[3],rgb[3];
            oracle_rgb_to_yuv(colors[i],yuv,m,range);
            oracle_yuv_to_rgb(yuv,rgb,m,range);
            for (int c=0;c<3;c++) CHECK(abs((int)rgb[c]-colors[i][c])<=2);
        }
        const uint8_t red_full[2][3]={{76,85,255},{54,99,255}};
        uint8_t red[3]; oracle_rgb_to_yuv(colors[2],red,m,ORACLE_FULL);
        CHECK(!memcmp(red,red_full[m],3));
    }
    uint8_t src[16]={0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30},dst[4],ref[4]={5,9,21,25};
    for (int f=0;f<2;f++) { oracle_resample(src,4,4,4,1,dst,2,2,2,1,f); CHECK(!memcmp(dst,ref,4)); }
    CHECK(isnan(oracle_psnr(src,src,0)));
    dst[0]++; CHECK(isfinite(oracle_psnr(dst,ref,4)));
    return 0;
}
