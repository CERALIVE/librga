#define main inherited_bench_main
#include "rga-convert-bench.c"
#undef main
#include <sys/stat.h>

static int compare_double(const void *a, const void *b)
{ double x=*(const double *)a,y=*(const double *)b; return (x>y)-(x<y); }
static volatile int calibration_sink;
static __attribute__((noinline,noclone)) int empty_property(void) { return 0; }
static __attribute__((noinline,noclone)) double cost(int (*fn)(void))
{
    double start=now_us();
    for (int i=0;i<100000;i++) calibration_sink=fn();
    return (now_us()-start)/100000;
}
static int property_call(void) { return getenv("ROCKCHIP_RGA_LOG") != NULL; }
static int (*property)(void);
static void (*debug_state)(void);
static int debug_call(void) { debug_state(); return 0; }
static int trace_fd;
static int observer_call(void)
{
    char path[64],target[256];
    snprintf(path,sizeof path,"/proc/self/fd/%d",trace_fd);
    (void)now_us();
    int n=(int)readlink(path,target,sizeof target);
    (void)now_us();
    return n;
}

int main(int argc, char **argv)
{
    if (argc==2 && !strcmp(argv[1],"--selftest")) {
        double values[]={9,1,5}; qsort(values,3,sizeof(double),compare_double);
        if (values[0]!=1 || values[1]!=5 || values[2]!=9 || cost(property_call)<0) return 2;
        puts("PASS: H4 quantiles and batched getenv calibration (not a board measurement)"); return 0;
    }
    if (argc!=3) return 2;
    struct stat st;
    if (dlsym(RTLD_DEFAULT,"fake_rga_active")) return 2;
    if (stat("/dev/rga",&st) || !S_ISCHR(st.st_mode)) return 77;
    void (*begin)(void)=dlsym(RTLD_DEFAULT,"rga_timing_begin");
    void (*end)(void)=dlsym(RTLD_DEFAULT,"rga_timing_end");
    void (*env_begin)(void)=dlsym(RTLD_DEFAULT,"task43_env_begin");
    unsigned long (*env_end)(void)=dlsym(RTLD_DEFAULT,"task43_env_end");
    property=dlsym(RTLD_DEFAULT,"_Z16get_int_propertyv");
    debug_state=dlsym(RTLD_DEFAULT,"_Z12is_debug_logv");
    if (!begin || !end || !env_begin || !env_end || !property || !debug_state) return 2;
    struct cell c={"G1",3840,2160,3840,2160,RK_FORMAT_YCbCr_422_SP,0,0,0};
    struct buffer src={.fd=-1},dst={.fd=-1};
    if (allocate(&src,3840UL*2160*2) || allocate(&dst,3840UL*2160*3/2)) return 2;
    if (sync_cpu(&src,DMA_BUF_SYNC_START|DMA_BUF_SYNC_WRITE)) return 2;
    fill(src.data,&c);
    if (sync_cpu(&src,DMA_BUF_SYNC_END|DMA_BUF_SYNC_WRITE)) return 2;
    rga_buffer_t s=wrapbuffer_fd(src.fd,3840,2160,c.format,3840,2160);
    rga_buffer_t d=wrapbuffer_fd(dst.fd,3840,2160,RK_FORMAT_YCbCr_420_SP,3840,2160),empty={0};
    im_rect zero={0};
    for (int i=0;i<32;i++) if (improcess(s,d,empty,zero,zero,zero,IM_SYNC)!=IM_STATUS_SUCCESS) return 2;
    double lower=INFINITY,upper=0,observer=0;
    trace_fd=open("/dev/rga",O_RDWR|O_CLOEXEC); if (trace_fd<0) return 2;
    FILE *cal=fopen("calibration.csv","wx"); if (!cal) return 2;
    fputs("round,noop_us,property_us,debug_state_us,observer_us\n",cal);
    for (int i=0;i<31;i++) {
        double overhead=cost(empty_property),p=cost(property),debug=cost(debug_call);
        double observed=cost(observer_call);
        fprintf(cal,"%d,%.9f,%.9f,%.9f,%.9f\n",i,overhead,p,debug,observed);
        observer=fmax(observer,observed);
        lower=fmin(lower,fmax(0,p-overhead)); upper=fmax(upper,debug);
    }
    fclose(cal); close(trace_fd);
    const char *timing=getenv("RGA_TIMING_CSV"); if (!timing) return 2;
    FILE *raw=fopen(timing,"r"); if (!raw) return 2;
    fseek(raw,0,SEEK_END);
    FILE *csv=fopen("perf.csv","wx"); if (!csv) return 2;
    fputs("lib,board,sample,t_total_us,t_ioctl_us,userspace_us\n",csv);
    FILE *counts=fopen("counts.csv","wx"); if (!counts) return 2;
    fputs("sample,getenv_calls,ioctls\n",counts);
    double totals[2000],ioctls[2000],users[2000],min_user=INFINITY,max_user=0;
    unsigned long min_calls=~0UL,max_calls=0; int max_ioctls=0;
    for (int i=0;i<2000;i++) {
        begin(); env_begin();
        IM_STATUS status=improcess(s,d,empty,zero,zero,zero,IM_SYNC);
        unsigned long calls=env_end(); end();
        if (status!=IM_STATUS_SUCCESS) { fprintf(stderr,"G1 status=%d\n",status); return 2; }
        clearerr(raw); char line[256]; double total=0,sum=0; int nr=0;
        while (fgets(line,sizeof line,raw)) {
            long pid; unsigned long cmd; double t,k; int rc,error;
            if (sscanf(line,"%ld,0x%lx,%lf,%lf,%d,%d",&pid,&cmd,&t,&k,&rc,&error)!=6 || rc<0) return 2;
            if (nr && total!=t) return 2;
            total=t; sum+=k; ++nr;
        }
        if (!nr || total<sum || calls==0) return 2;
        totals[i]=total; ioctls[i]=sum; users[i]=total-sum;
        min_user=fmin(min_user,users[i]); max_user=fmax(max_user,users[i]);
        if (calls<min_calls) min_calls=calls;
        if (calls>max_calls) max_calls=calls;
        if (nr>max_ioctls) max_ioctls=nr;
        fprintf(csv,"%s,%s,%d,%.3f,%.3f,%.3f\n",argv[1],argv[2],i,total,sum,users[i]);
        fprintf(counts,"%d,%lu,%d\n",i,calls,nr);
        fflush(csv); fflush(counts);
        if (i%100==99) fprintf(stderr,"H4 %s %d/2000\n",argv[1],i+1);
    }
    fclose(csv); fclose(counts); fclose(raw);
    const char *names[]={"t_total_us","t_ioctl_us","userspace_us"};
    double *arrays[]={totals,ioctls,users};
    for (int i=0;i<3;i++) {
        qsort(arrays[i],2000,sizeof(double),compare_double);
        printf("%s median=%.3f p95=%.3f p99=%.3f\n",names[i],(arrays[i][999]+arrays[i][1000])/2,arrays[i][1899],arrays[i][1979]);
    }
    double estimate=100*min_calls*lower/users[1000];
    printf("property_lower_us=%.9f debug_upper_us=%.9f calls=%lu..%lu userspace_range_us=%.3f..%.3f\n",lower,upper,min_calls,max_calls,min_user,max_user);
    printf("getenv_parse_pct_estimate=%.6f lower_observed_pct=%.6f upper_uncorrected_pct=%.6f\n",estimate,100*min_calls*lower/max_user,100*max_calls*upper/min_user);
    double allowance=max_ioctls*(4*observer+1)+max_calls*upper;
    double pct_low=100*min_calls*lower/max_user;
    double pct_high=min_user>allowance ? 100*max_calls*upper/(min_user-allowance) : INFINITY;
    printf("observer_allowance_us=%.9f gate_pct_observed_envelope=%.9f..%.9f\n",allowance,pct_low,pct_high);
    printf("gate=%s\n",pct_low>=2 ? "MEASUREMENT-AT-OR-ABOVE-GATE" : pct_high<2 ? "MEASUREMENT-BELOW-GATE" : "INCONCLUSIVE-REPEAT-PROFILE");
    release(&src); release(&dst); return 0;
}
