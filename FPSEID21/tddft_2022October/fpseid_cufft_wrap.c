#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <cuda_runtime.h>
#include <cufft.h>

static cufftHandle g_plan_fwd = 0;
static cufftHandle g_plan_bwd = 0;
static size_t g_bytes = 0;
static cufftDoubleComplex *g_dev = NULL;
static cudaEvent_t g_ev_start = NULL;
static cudaEvent_t g_ev_after_h2d = NULL;
static cudaEvent_t g_ev_after_fft = NULL;
static cudaEvent_t g_ev_after_d2h = NULL;
static int g_timing_enabled = 0;
static long long g_exec_count = 0;
static double g_h2d_sec = 0.0;
static double g_fft_sec = 0.0;
static double g_d2h_sec = 0.0;
static double g_total_sec = 0.0;

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

static int create_timing_events(void)
{
  if (check_cuda(cudaEventCreate(&g_ev_start), "cudaEventCreate start")) {
    return 1;
  }
  if (check_cuda(cudaEventCreate(&g_ev_after_h2d),
                 "cudaEventCreate after_h2d")) {
    return 1;
  }
  if (check_cuda(cudaEventCreate(&g_ev_after_fft),
                 "cudaEventCreate after_fft")) {
    return 1;
  }
  if (check_cuda(cudaEventCreate(&g_ev_after_d2h),
                 "cudaEventCreate after_d2h")) {
    return 1;
  }
  g_timing_enabled = 1;
  return 0;
}

static int destroy_event(cudaEvent_t *event, const char *where)
{
  if (*event == NULL) {
    return 0;
  }
  if (check_cuda(cudaEventDestroy(*event), where)) {
    return 1;
  }
  *event = NULL;
  return 0;
}

static void destroy_timing_events(void)
{
  destroy_event(&g_ev_start, "cudaEventDestroy start");
  destroy_event(&g_ev_after_h2d, "cudaEventDestroy after_h2d");
  destroy_event(&g_ev_after_fft, "cudaEventDestroy after_fft");
  destroy_event(&g_ev_after_d2h, "cudaEventDestroy after_d2h");
  g_timing_enabled = 0;
}

static int accumulate_timing(void)
{
  float h2d_ms = 0.0f;
  float fft_ms = 0.0f;
  float d2h_ms = 0.0f;
  float total_ms = 0.0f;

  if (!g_timing_enabled) {
    return 0;
  }

  if (check_cuda(cudaEventSynchronize(g_ev_after_d2h),
                 "cudaEventSynchronize after_d2h")) {
    return 1;
  }
  if (check_cuda(cudaEventElapsedTime(&h2d_ms, g_ev_start, g_ev_after_h2d),
                 "cudaEventElapsedTime h2d")) {
    return 1;
  }
  if (check_cuda(cudaEventElapsedTime(&fft_ms, g_ev_after_h2d,
                                      g_ev_after_fft),
                 "cudaEventElapsedTime fft")) {
    return 1;
  }
  if (check_cuda(cudaEventElapsedTime(&d2h_ms, g_ev_after_fft,
                                      g_ev_after_d2h),
                 "cudaEventElapsedTime d2h")) {
    return 1;
  }
  if (check_cuda(cudaEventElapsedTime(&total_ms, g_ev_start,
                                      g_ev_after_d2h),
                 "cudaEventElapsedTime total")) {
    return 1;
  }

  g_exec_count++;
  g_h2d_sec += (double)h2d_ms * 1.0e-3;
  g_fft_sec += (double)fft_ms * 1.0e-3;
  g_d2h_sec += (double)d2h_ms * 1.0e-3;
  g_total_sec += (double)total_ms * 1.0e-3;
  return 0;
}

static void print_timing_summary(void)
{
  if (g_exec_count <= 0) {
    return;
  }

  printf("FPSEID_CUFFT_PROFILE_BEGIN\n");
  printf("  count h2d_sec fft_sec d2h_sec total_sec\n");
  printf("  %lld %.9f %.9f %.9f %.9f\n",
         g_exec_count, g_h2d_sec, g_fft_sec, g_d2h_sec, g_total_sec);
  printf("FPSEID_CUFFT_PROFILE_END\n");
  fflush(stdout);
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
  if (create_timing_events()) {
    *ierr = 4;
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

  if (g_timing_enabled &&
      check_cuda(cudaEventRecord(g_ev_start, 0), "cudaEventRecord start")) {
    *ierr = 25;
    return;
  }
  if (check_cuda(cudaMemcpy(g_dev, host_data, bytes,
                            cudaMemcpyHostToDevice),
                 "cudaMemcpy H2D")) {
    *ierr = 22;
    return;
  }
  if (g_timing_enabled &&
      check_cuda(cudaEventRecord(g_ev_after_h2d, 0),
                 "cudaEventRecord after_h2d")) {
    *ierr = 26;
    return;
  }
  if (check_cufft(cufftExecZ2Z(plan, g_dev, g_dev, cufft_dir),
                  "cufftExecZ2Z")) {
    *ierr = 23;
    return;
  }
  if (g_timing_enabled &&
      check_cuda(cudaEventRecord(g_ev_after_fft, 0),
                 "cudaEventRecord after_fft")) {
    *ierr = 27;
    return;
  }
  if (check_cuda(cudaMemcpy(host_data, g_dev, bytes,
                            cudaMemcpyDeviceToHost),
                 "cudaMemcpy D2H")) {
    *ierr = 24;
    return;
  }
  if (g_timing_enabled &&
      check_cuda(cudaEventRecord(g_ev_after_d2h, 0),
                 "cudaEventRecord after_d2h")) {
    *ierr = 28;
    return;
  }
  if (accumulate_timing()) {
    *ierr = 29;
    return;
  }
}

void fpseid_cufft_exec_device_(int64_t *plan_value,
                               cufftDoubleComplex *device_data,
                               int *ng, int *direction, int *ierr)
{
  cufftHandle plan;
  int cufft_dir;
  size_t bytes;

  *ierr = 0;

  plan = (cufftHandle)(*plan_value);
  cufft_dir = (*direction < 0) ? CUFFT_FORWARD : CUFFT_INVERSE;
  bytes = (size_t)(*ng) * sizeof(cufftDoubleComplex);
  if (bytes > g_bytes) {
    *ierr = 41;
    return;
  }

  if (g_timing_enabled &&
      check_cuda(cudaEventRecord(g_ev_start, 0), "cudaEventRecord start")) {
    *ierr = 45;
    return;
  }
  if (g_timing_enabled &&
      check_cuda(cudaEventRecord(g_ev_after_h2d, 0),
                 "cudaEventRecord after_h2d")) {
    *ierr = 46;
    return;
  }
  if (check_cufft(cufftExecZ2Z(plan, device_data, device_data, cufft_dir),
                  "cufftExecZ2Z device")) {
    *ierr = 43;
    return;
  }
  if (g_timing_enabled &&
      check_cuda(cudaEventRecord(g_ev_after_fft, 0),
                 "cudaEventRecord after_fft")) {
    *ierr = 47;
    return;
  }
  if (g_timing_enabled &&
      check_cuda(cudaEventRecord(g_ev_after_d2h, 0),
                 "cudaEventRecord after_d2h")) {
    *ierr = 48;
    return;
  }
  if (accumulate_timing()) {
    *ierr = 49;
    return;
  }
}

void fpseid_cufft_destroy_(int *ierr)
{
  *ierr = 0;
  print_timing_summary();
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
  destroy_timing_events();
  g_bytes = 0;
  g_exec_count = 0;
  g_h2d_sec = 0.0;
  g_fft_sec = 0.0;
  g_d2h_sec = 0.0;
  g_total_sec = 0.0;
}
