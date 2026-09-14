#define main inherited_bench_main
#include "rga-convert-bench.c"
#undef main
#include <pthread.h>
#include <stdatomic.h>
#include <sys/stat.h>
#include <signal.h>

struct worker {
    struct buffer src,dst;
    atomic_ulong frames,last;
    atomic_int status,done;
    int id;
};
static pthread_barrier_t gate;
static atomic_int stop;
#ifdef TASK43_QEMU_FIXTURE
static int injected_stall;
#endif
static void *work(void *arg)
{
    struct worker *w=arg;
    rga_buffer_t s=wrapbuffer_fd(w->src.fd,3840,2160,RK_FORMAT_YCbCr_422_SP,3840,2160);
    rga_buffer_t d=wrapbuffer_fd(w->dst.fd,3840,2160,RK_FORMAT_YCbCr_420_SP,3840,2160),empty={0};
    im_rect zero={0};
    pthread_barrier_wait(&gate);
    while (!atomic_load(&stop)) {
#ifdef TASK43_QEMU_FIXTURE
        (void)s; (void)d; (void)empty; (void)zero;
        usleep(1000);
        if (injected_stall && w->id==0) continue;
        IM_STATUS status=IM_STATUS_SUCCESS;
#else
        IM_STATUS status=improcess(s,d,empty,zero,zero,zero,IM_SYNC);
#endif
        if (status!=IM_STATUS_SUCCESS) { atomic_store(&w->status,status); break; }
        atomic_fetch_add(&w->frames,1);
        atomic_store(&w->last,(unsigned long)now_us());
    }
    atomic_store(&w->done,1);
    return NULL;
}
int main(int argc,char **argv)
{
    if (argc!=3) return 2;
    int n=atoi(argv[1]),seconds=atoi(argv[2]);
    if ((n!=1 && n!=4 && n!=6 && n!=8) || seconds<1 || seconds>60) return 2;
    double stall_us=5000000;
#ifdef TASK43_QEMU_FIXTURE
    injected_stall=getenv("TASK43_INJECT_STALL")!=NULL;
    stall_us=200000;
    fputs("QEMU-FIXTURE: synthetic progress only, never hardware evidence\n",stderr);
#else
    struct stat st;
    if (dlsym(RTLD_DEFAULT,"fake_rga_active")) return 2;
    if (stat("/dev/rga",&st) || !S_ISCHR(st.st_mode)) return 77;
#endif
    FILE *csv=fdopen(dup(STDOUT_FILENO),"w");
    if (!csv || dup2(STDERR_FILENO,STDOUT_FILENO)<0) return 2;
    struct worker workers[8]={0}; pthread_t threads[8];
    struct cell c={"G1",3840,2160,3840,2160,RK_FORMAT_YCbCr_422_SP,0,0,0};
    for (int i=0;i<n;i++) {
        workers[i].id=i; workers[i].src.fd=workers[i].dst.fd=-1;
        atomic_init(&workers[i].frames,0); atomic_init(&workers[i].last,0);
        atomic_init(&workers[i].status,IM_STATUS_SUCCESS);
        atomic_init(&workers[i].done,0);
#ifndef TASK43_QEMU_FIXTURE
        if (allocate(&workers[i].src,3840UL*2160*2) || allocate(&workers[i].dst,3840UL*2160*3/2)) return 2;
        if (sync_cpu(&workers[i].src,DMA_BUF_SYNC_START|DMA_BUF_SYNC_WRITE)) return 2;
        fill(workers[i].src.data,&c);
        if (sync_cpu(&workers[i].src,DMA_BUF_SYNC_END|DMA_BUF_SYNC_WRITE)) return 2;
#else
        (void)c;
#endif
    }
    if (pthread_barrier_init(&gate,NULL,n+1)) return 2;
    for (int i=0;i<n;i++) if (pthread_create(&threads[i],NULL,work,&workers[i])) return 2;
    double started=now_us();
    for (int i=0;i<n;i++) atomic_store(&workers[i].last,(unsigned long)started);
    pthread_barrier_wait(&gate);
    const char *verdict="OK";
    for (;;) {
        usleep(100000);
        if (now_us()-started>=seconds*1e6) atomic_store(&stop,1);
        int finished=0;
        for (int i=0;i<n;i++) {
            if (atomic_load(&workers[i].status)!=IM_STATUS_SUCCESS) verdict="IM_STATUS_FAILURE";
            else if (atomic_load(&workers[i].done)) ++finished;
            else if (now_us()-atomic_load(&workers[i].last)>stall_us) verdict="STALL";
            if (strcmp(verdict,"OK")) break;
        }
        if (strcmp(verdict,"OK") || finished==n) break;
    }
    double elapsed=(now_us()-started)/1e6;
    fprintf(csv,"threads,worker,seconds,frames,fps,status,verdict\n");
    for (int i=0;i<n;i++) fprintf(csv,"%d,%d,%.6f,%lu,%.6f,%d,%s\n",n,i,elapsed,
        atomic_load(&workers[i].frames),atomic_load(&workers[i].frames)/elapsed,
        atomic_load(&workers[i].status),verdict);
    fclose(csv);
    if (strcmp(verdict,"OK")) {
        FILE *f=fopen("incident","wx"); if (!f) return 2;
        fprintf(f,"%ld %s\n",(long)getpid(),verdict); fclose(f);
#ifndef TASK43_QEMU_FIXTURE
        raise(SIGSTOP);
#else
        atomic_store(&stop,1);
        for (int i=0;i<n;i++) if (pthread_join(threads[i],NULL)) _Exit(2);
#endif
        _Exit(3);
    }
    atomic_store(&stop,1);
    for (int i=0;i<n;i++) {
        if (pthread_join(threads[i],NULL)) return 2;
        release(&workers[i].src); release(&workers[i].dst);
    }
    pthread_barrier_destroy(&gate);
    return 0;
}
