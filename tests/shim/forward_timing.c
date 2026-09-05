#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
static int (*real_ioctl)(int,unsigned long,...);
static pthread_once_t timing_once=PTHREAD_ONCE_INIT;
struct timing_row { unsigned long command; double elapsed; int result,error; };
static _Thread_local struct timing_row rows[256];
static _Thread_local size_t count;
static _Thread_local int active;
static _Thread_local double started;
static double clock_us(void)
{ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec*1e6+t.tv_nsec/1e3; }
static void resolve_ioctl(void)
{ *(void **)(&real_ioctl)=dlsym(RTLD_NEXT,"ioctl"); if (!real_ioctl) _exit(125); }
static void flush_rows(double total)
{
    const char *path=getenv("RGA_TIMING_CSV");
    int fd=open(path ? path : "timing.csv",O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC,0600);
    if (fd<0 || flock(fd,LOCK_EX)) _exit(125);
    struct stat st;
    if (fstat(fd,&st)) _exit(125);
    if (!st.st_size && dprintf(fd,"pid,command,t_total_us,t_ioctl_us,result,errno\n")<0) _exit(125);
    for (size_t i=0;i<count;i++)
        if (dprintf(fd,"%ld,0x%lx,%.3f,%.3f,%d,%d\n",(long)getpid(),rows[i].command,total,rows[i].elapsed,rows[i].result,rows[i].error)<0) _exit(125);
    flock(fd,LOCK_UN); close(fd); count=0;
}
void rga_timing_begin(void) { count=0; active=1; started=clock_us(); }
void rga_timing_end(void)
{ int saved=errno; double total=clock_us()-started; active=0; if (count) flush_rows(total); errno=saved; }
int ioctl(int fd,unsigned long command,...)
{
    pthread_once(&timing_once,resolve_ioctl);
    va_list args; va_start(args,command); void *arg=va_arg(args,void *); va_end(args);
    int incoming=errno;
    char path[64],target[256]; snprintf(path,sizeof path,"/proc/self/fd/%d",fd);
    ssize_t len=readlink(path,target,sizeof target-1);
    int rga=0;
    if (len>=0) { target[len]=0; rga=!strcmp(target,"/dev/rga"); }
    errno=incoming;
    double before=clock_us();
    int rc=real_ioctl(fd,command,arg),saved=errno;
    double elapsed=clock_us()-before;
    if (rga) {
        if (count==sizeof rows/sizeof rows[0]) _exit(125);
        rows[count++]=(struct timing_row){command,elapsed,rc,rc<0 ? saved : 0};
        if (!active) flush_rows(elapsed);
    }
    errno=saved; return rc;
}
