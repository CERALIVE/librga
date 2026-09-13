/* SPDX-License-Identifier: Apache-2.0 */
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "rga_ioctl.h"

#if defined(__aarch64__)
typedef int (*writer)(struct rga_req *, int);
extern int poison_call(writer fn, struct rga_req *req, int mode, uint64_t pattern);
/* Seed the callee's stack without changing the request or the library. */
__asm__(".text\n.global poison_call\n.type poison_call,%function\n"
        "poison_call:\nmov x16,x0\nmov x0,x1\nmov w1,w2\n"
        "mov x9,sp\nsub sp,sp,#4096\nmov x10,sp\n"
        "1: str x3,[x9,#-8]!\ncmp x9,x10\nb.ne 1b\n"
        "add sp,sp,#4096\nbr x16\n.size poison_call,.-poison_call\n");

int main(void)
{
    writer fn = NULL;
    *(void **)(&fn) = dlsym(RTLD_DEFAULT, "_Z30NormalRgaFullColorSpaceConvertP7rga_reqi");
    if (!fn) { fprintf(stderr, "%s\n", dlerror()); return 2; }
    struct rga_req a = {0}, b = {0};
    if (poison_call(fn, &a, 0xb00, UINT64_C(0xaaaaaaaaaaaaaaaa)) ||
        poison_call(fn, &b, 0xb00, UINT64_C(0x5555555555555555))) return 2;
    printf("full_csc offset=%zu size=%zu; coe_y=%zu coe_u=%zu coe_v=%zu; off=%zu\n",
           offsetof(struct rga_req, full_csc), sizeof(full_csc_t),
           offsetof(full_csc_t, coe_y), offsetof(full_csc_t, coe_u),
           offsetof(full_csc_t, coe_v), offsetof(csc_coe_t, off));
    const unsigned char *x = (const unsigned char *)&a, *y = (const unsigned char *)&b;
    for (size_t i = 0; i < sizeof a; i++)
        if (x[i] != y[i]) printf("offset=%zu before=%02x after=%02x\n", i, x[i], y[i]);
    printf("flag=%u Y=%d,%d,%d,%d U=%d,%d,%d,%d V=%d,%d,%d,%d\n",
           a.full_csc.flag, a.full_csc.coe_y.r_v, a.full_csc.coe_y.g_y,
           a.full_csc.coe_y.b_u, a.full_csc.coe_y.off,
           a.full_csc.coe_u.r_v, a.full_csc.coe_u.g_y,
           a.full_csc.coe_u.b_u, a.full_csc.coe_u.off,
           a.full_csc.coe_v.r_v, a.full_csc.coe_v.g_y,
           a.full_csc.coe_v.b_u, a.full_csc.coe_v.off);
    return memcmp(&a, &b, sizeof a) != 0;
}
#else
int main(void) { fputs("This diagnostic requires aarch64\n", stderr); return 77; }
#endif
