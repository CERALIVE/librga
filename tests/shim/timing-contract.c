#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#define CHECK(x) do { if (!(x)) { fprintf(stderr,"timing check failed line %d\n",__LINE__); return 1; } } while (0)
/* Emulate only fd-path discovery; the forwarding shim must reach libc's real ioctl. */
ssize_t readlink(const char *path, char *buf, size_t size)
{
    (void)path;
    const char name[]="/dev/rga";
    if (size<sizeof name-1) { errno=EINVAL; return -1; }
    memcpy(buf,name,sizeof name-1); return sizeof name-1;
}
int main(void)
{
    CHECK(!dlsym(RTLD_DEFAULT,"fake_rga_active"));
    void (*begin)(void)=NULL;
    void (*end)(void)=NULL;
    *(void **)(&begin)=dlsym(RTLD_DEFAULT,"rga_timing_begin");
    *(void **)(&end)=dlsym(RTLD_DEFAULT,"rga_timing_end");
    CHECK(begin && end);
    char path[]="/tmp/rga-timing-contract-XXXXXX";
    int fd=mkstemp(path); CHECK(fd>=0); close(fd);
    CHECK(setenv("RGA_TIMING_CSV",path,1)==0);
    begin(); usleep(2000);
    int arg=0; errno=0;
    CHECK(ioctl(-1,0x5017UL,&arg)==-1 && errno==EBADF);
    end(); CHECK(errno==EBADF);
    FILE *f=fopen(path,"r"); CHECK(f);
    char header[128]; CHECK(fgets(header,sizeof header,f));
    long pid; unsigned long cmd; double total,kernel; int rc,error;
    CHECK(fscanf(f,"%ld,0x%lx,%lf,%lf,%d,%d",&pid,&cmd,&total,&kernel,&rc,&error)==6);
    CHECK(pid==getpid() && cmd==0x5017 && total>=1000 && total>=kernel && rc==-1 && error==EBADF);
    fclose(f); unlink(path);
    puts("PASS: forwarding preserves real EBADF; total scope includes userspace; CSV records ioctl duration");
    return 0;
}
