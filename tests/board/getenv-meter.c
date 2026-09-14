#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <string.h>
#include <unistd.h>
static char *(*next_getenv)(const char *);
static pthread_once_t once = PTHREAD_ONCE_INIT;
static _Thread_local unsigned long calls;
static _Thread_local int active;
static void resolve(void)
{
    *(void **)(&next_getenv) = dlsym(RTLD_NEXT, "getenv");
    if (!next_getenv) _exit(125);
}
void task43_env_begin(void) { calls = 0; active = 1; }
unsigned long task43_env_end(void) { active = 0; return calls; }
char *getenv(const char *name)
{
    pthread_once(&once, resolve);
    if (active && (!strcmp(name, "ROCKCHIP_RGA_LOG") || !strcmp(name, "ROCKCHIP_RGA_LOG_LEVEL"))) ++calls;
    return next_getenv(name);
}
