# NVHPC cuFFT Runtime Log: Si111-H TDDFT

Date: 2026-06-30

This records the first GPU-enabled TDDFT check for the AIST FPSEID21
`Si111-H` sample. The implementation switches only the TDDFT FFT wrapper from
FFTW to cuFFT; CG and SD remain CPU code.

## Environment

- GPU: NVIDIA A100-PCIE-40GB
- Driver: 595.45.04
- Reported CUDA version: 13.2
- Observed TDDFT GPU memory use: about 426 MiB
- Observed GPU utilization during TDDFT: about 11%
- Compiler path: NVIDIA HPC SDK, `nvfortran`/`nvc`, with MPI wrapper
- GCC runtime module: `gcc/14.3.0`

## GPU Implementation

The GPU path was added as an optional FFT backend:

```sh
ENABLE_GPU_FFT=1 ./tools/build_nvhpc.sh
```

The TDDFT build can also be selected manually:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort CC=nvc FFT_BACKEND=cufft \
  FFLAGS="-O2 -mp -Msave -Mlarge_arrays" \
  CUFFT_LIBS="-cudalib=cufft" ./mk_ifort.sh
```

Files added for the cuFFT path:

- `FPSEID21/tddft_2022October/fft_cufft.f`
- `FPSEID21/tddft_2022October/fpseid_cufft_wrap.c`

The Fortran entry points keep the existing names
`FFT3BX_fftwASL`/`FFT3FX_fftwASL`, so the surrounding TDDFT code does not need
call-site changes. The current implementation copies each complex FFT input
array from host to GPU, executes cuFFT, then copies it back. This is a first
validation step, not yet a full GPU-resident `tmevl_s2` implementation.

## Runtime Results

### cuFFT Backend

| run | steps took sec | time_step_total | tmevl_total | tmevl_s2 | s2_nonlocal | s2_fft_local | fft_wrapper |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 steps | 12.755 | 13.046 | 9.794 | 7.018 | 2.833 | 4.185 | 3.182 |
| 50 steps | 262.933 | 263.208 | 226.043 | 184.677 | 74.061 | 110.615 | 60.853 |
| 100 steps | 496.290 | 496.564 | 424.181 | 346.778 | 139.209 | 207.567 | 114.626 |

### NVHPC CPU FFT Baseline

| run | steps took sec | time_step_total | tmevl_total | tmevl_s2 | s2_nonlocal | s2_fft_local | fft_wrapper |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 steps | 14.375 | 14.681 | 11.333 | 8.302 | 2.857 | 5.445 | 5.233 |
| 50 steps | 298.547 | 298.851 | 259.012 | 217.442 | 74.814 | 142.627 | 100.025 |
| 100 steps | 567.725 | 568.031 | 490.883 | 412.545 | 141.440 | 271.103 | 188.390 |

### Improvement From cuFFT

| run | time_step_total | tmevl_total | tmevl_s2 | s2_fft_local | fft_wrapper |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2 steps | 11.1% | 13.6% | 15.5% | 23.1% | 39.2% |
| 50 steps | 11.9% | 12.7% | 15.1% | 22.4% | 39.2% |
| 100 steps | 12.6% | 13.6% | 15.9% | 23.4% | 39.2% |

## Interpretation

The first cuFFT backend is functionally useful: all tested 2/50/100-step runs
complete and show a consistent improvement. The largest direct improvement is
in `fft_wrapper`, which drops by about 39%. This also reduces the enclosing
`s2_fft_local`, `tmevl_s2`, and total timestep time.

GPU utilization remains low because the implementation still transfers each
FFT array between host and GPU for every wrapper call. The next optimization
step should keep `tmevl_s2` working arrays resident on the GPU, especially:

- `RHO1_`
- `RHO2_`
- `P`
- local-potential multiply using `VG`/`Vloc`

After that, the nonlocal portion `s2_nonlocal` is the next major target.
