#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <cuda_runtime.h>
#include <cufft.h>

static cufftHandle g_plan_fwd = 0;
static cufftHandle g_plan_bwd = 0;
static size_t g_bytes = 0;
static cufftDoubleComplex *g_dev = NULL;

static int check_cuda(cudaError_t status, const char *where)
{
  if (status != cudaSuccess) {
    fprintf(stderr, "CUDA error at %s: %s\n", where,
            cudaGetErrorString(status));
    return 1;
  }
  return 0;
}

static int check_cufft(cufftResult status, const char *where)
{
  if (status != CUFFT_SUCCESS) {
    fprintf(stderr, "cuFFT error at %s: %d\n", where, (int)status);
    return 1;
  }
  return 0;
}

void fpseid_cufft_plan_(int64_t *plan_fwd, int64_t *plan_bwd,
                        int *nrx, int *nry, int *nrz, int *ierr)
{
  int n[3];
  size_t bytes;

  *ierr = 0;

  if (g_plan_fwd != 0 || g_plan_bwd != 0 || g_dev != NULL) {
    *ierr = 10;
    return;
  }

  /* Fortran layout has NRX as the fastest-varying dimension. */
  n[0] = *nrz;
  n[1] = *nry;
  n[2] = *nrx;
  bytes = (size_t)(*nrx) * (size_t)(*nry) * (size_t)(*nrz) *
          sizeof(cufftDoubleComplex);

  if (check_cufft(cufftPlanMany(&g_plan_fwd, 3, n,
                                NULL, 1, 0, NULL, 1, 0,
                                CUFFT_Z2Z, 1),
                  "cufftPlanMany forward")) {
    *ierr = 1;
    return;
  }
  if (check_cufft(cufftPlanMany(&g_plan_bwd, 3, n,
                                NULL, 1, 0, NULL, 1, 0,
                                CUFFT_Z2Z, 1),
                  "cufftPlanMany backward")) {
    *ierr = 2;
    return;
  }
  if (check_cuda(cudaMalloc((void **)&g_dev, bytes), "cudaMalloc")) {
    *ierr = 3;
    return;
  }

  g_bytes = bytes;
  *plan_fwd = (int64_t)g_plan_fwd;
  *plan_bwd = (int64_t)g_plan_bwd;
}

void fpseid_cufft_exec_(int64_t *plan_value, cufftDoubleComplex *host_data,
                        int *ng, int *direction, int *ierr)
{
  cufftHandle plan;
  int cufft_dir;
  size_t bytes;

  *ierr = 0;
  if (g_dev == NULL) {
    *ierr = 20;
    return;
  }

  plan = (cufftHandle)(*plan_value);
  cufft_dir = (*direction < 0) ? CUFFT_FORWARD : CUFFT_INVERSE;
  bytes = (size_t)(*ng) * sizeof(cufftDoubleComplex);
  if (bytes > g_bytes) {
    *ierr = 21;
    return;
  }

  if (check_cuda(cudaMemcpy(g_dev, host_data, bytes,
                            cudaMemcpyHostToDevice),
                 "cudaMemcpy H2D")) {
    *ierr = 22;
    return;
  }
  if (check_cufft(cufftExecZ2Z(plan, g_dev, g_dev, cufft_dir),
                  "cufftExecZ2Z")) {
    *ierr = 23;
    return;
  }
  if (check_cuda(cudaMemcpy(host_data, g_dev, bytes,
                            cudaMemcpyDeviceToHost),
                 "cudaMemcpy D2H")) {
    *ierr = 24;
    return;
  }
}

void fpseid_cufft_destroy_(int *ierr)
{
  *ierr = 0;
  if (g_plan_fwd != 0) {
    if (check_cufft(cufftDestroy(g_plan_fwd), "cufftDestroy forward")) {
      *ierr = 30;
    }
    g_plan_fwd = 0;
  }
  if (g_plan_bwd != 0) {
    if (check_cufft(cufftDestroy(g_plan_bwd), "cufftDestroy backward")) {
      *ierr = 31;
    }
    g_plan_bwd = 0;
  }
  if (g_dev != NULL) {
    if (check_cuda(cudaFree(g_dev), "cudaFree")) {
      *ierr = 32;
    }
    g_dev = NULL;
  }
  g_bytes = 0;
}
