#include <fftw3.h>

void dfftw_init_threads_(int *iret)
{
  *iret = fftw_init_threads();
}

void dfftw_plan_with_nthreads_(int *nthreads)
{
  fftw_plan_with_nthreads(*nthreads);
}
