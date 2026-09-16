#include <stdint.h>
#include <string.h>
#include "rga_ioctl.h"
int padding_control(struct rga_req *req, int mode)
    __asm__("_Z30NormalRgaFullColorSpaceConvertP7rga_reqi");
int padding_control(struct rga_req *req, int mode)
{
    if (mode!=0xb00) return -1;
    memset(&req->full_csc,0,sizeof req->full_csc);
#if defined(__aarch64__) && defined(PADDING_MUTANT)
    uint64_t value;
    __asm__ volatile("ldur %0, [sp, #-256]" : "=r"(value));
    ((unsigned char *)&req->full_csc)[1]=(unsigned char)value;
#endif
    req->full_csc.flag=1;
    return 0;
}
