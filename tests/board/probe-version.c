#include <fcntl.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include "im2d.h"
#include "rga_ioctl.h"
int main(void)
{
    int fd=open("/dev/rga",O_RDWR|O_CLOEXEC);
    if (fd<0) { perror("/dev/rga"); return 77; }
    struct rga_version_t v={0};
    int rc=ioctl(fd,RGA_IOC_GET_DRVIER_VERSION,&v);
    close(fd);
    if (rc<0) { perror("RGA_IOC_GET_DRVIER_VERSION"); return 1; }
    printf("driver=%u.%u.%u text=%.*s\n",v.major,v.minor,v.revision,(int)sizeof v.str,v.str);
    printf("%s\n",querystring(RGA_ALL));
    return 0;
}
