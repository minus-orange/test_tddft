#include <openacc.h>
#include <stddef.h>
#include <stdint.h>

static int fpseid_acc_query(const void *host, size_t nbytes,
                            intptr_t *host_addr, intptr_t *device_addr)
{
    void *device;

    *host_addr = (intptr_t)host;
    *device_addr = (intptr_t)0;
    if (host == NULL || nbytes == 0) {
        return 0;
    }
    if (!acc_is_present((void *)host, nbytes)) {
        return 0;
    }

    device = acc_deviceptr((void *)host);
    *device_addr = (intptr_t)device;
    return 1;
}

int fpseid_acc_query_c16(const void *host, size_t nbytes,
                         intptr_t *host_addr, intptr_t *device_addr)
{
    return fpseid_acc_query(host, nbytes, host_addr, device_addr);
}

int fpseid_acc_query_r8(const void *host, size_t nbytes,
                        intptr_t *host_addr, intptr_t *device_addr)
{
    return fpseid_acc_query(host, nbytes, host_addr, device_addr);
}

int fpseid_acc_query_i4(const void *host, size_t nbytes,
                        intptr_t *host_addr, intptr_t *device_addr)
{
    return fpseid_acc_query(host, nbytes, host_addr, device_addr);
}
