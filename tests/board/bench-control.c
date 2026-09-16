/* SPDX-License-Identifier: Apache-2.0 */
#define _GNU_SOURCE
#define main bench_main
#define open control_open
#define ioctl control_ioctl
#define access control_access
#define clock_gettime control_clock
#define dlsym control_dlsym
#define c_RkRgaInit control_init
#define c_RkRgaGetContext control_context
#define c_RkRgaDeInit control_deinit
#define imcheck_t control_check
#define improcess control_process
#define oracle_psnr control_psnr
#include "rga-convert-bench.c"
#undef main
#include <stdarg.h>

static int ticks, calls;
static const char *fault;
int control_open(const char *path, int flags, ...)
{
    (void)flags;
    if (strcmp(path,"/dev/dma_heap/system")) abort();
    return memfd_create("bench-control-heap",MFD_CLOEXEC);
}
int control_ioctl(int fd, unsigned long cmd, ...)
{
    (void)fd;
    va_list ap; va_start(ap,cmd); void *arg=va_arg(ap,void *); va_end(ap);
    if (cmd==DMA_HEAP_IOCTL_ALLOC) {
        struct dma_heap_allocation_data *a=arg;
        int buffer=memfd_create("bench-control-buffer",MFD_CLOEXEC);
        if (buffer<0 || ftruncate(buffer,(off_t)a->len)) abort();
        a->fd=(unsigned)buffer;
        return 0;
    }
    if (cmd!=DMA_BUF_IOCTL_SYNC) abort();
    return !strcmp(fault,"sync") ? -1 : 0;
}
int control_access(const char *path, int mode) { (void)path; (void)mode; return 0; }
int control_clock(clockid_t id, struct timespec *t)
{ (void)id; t->tv_sec=ticks++ * 600; t->tv_nsec=0; return 0; }
void *control_dlsym(void *handle, const char *name) { (void)handle; (void)name; return NULL; }
int control_init(void) { return 0; }
void control_deinit(void) {}
void control_context(void **context) { *context=&ticks; }
IM_STATUS control_check(rga_buffer_t src, rga_buffer_t dst, rga_buffer_t pat,
                       im_rect sr, im_rect dr, im_rect pr, int usage)
{
    (void)src; (void)dst; (void)pat; (void)sr; (void)dr; (void)pr; (void)usage;
    return IM_STATUS_NOERROR;
}
IM_STATUS control_process(rga_buffer_t src, rga_buffer_t dst, rga_buffer_t pat,
                         im_rect sr, im_rect dr, im_rect pr, int usage)
{
    (void)src; (void)dst; (void)pat; (void)sr; (void)dr; (void)pr; (void)usage;
    calls++;
    return !strcmp(fault,"submit") ? IM_STATUS_FAILED : IM_STATUS_SUCCESS;
}
double control_psnr(const uint8_t *a, const uint8_t *b, size_t size)
{ (void)a; (void)b; (void)size; return !strcmp(fault,"pixels") ? 0 : INFINITY; }
int main(int argc, char **argv)
{
    if (argc!=2) return 2;
    fault=argv[1];
    char *args[]={"bench-control","--soak",NULL};
    int rc=bench_main(2,args);
    printf("control_calls=%d control_clock_seconds=%d\n",calls,(ticks-1)*600);
    return rc;
}
