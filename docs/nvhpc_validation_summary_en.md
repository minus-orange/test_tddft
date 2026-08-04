# NVHPC Validation Summary

> [Japanese version](nvhpc_validation_summary_ja.md)

Date: 2026-07-08

This note summarizes the NVIDIA HPC SDK validation work for the FPSEID21
`Si111-H` CG -> SD -> TDDFT workflow. It records the practical build flags,
known pass/fail points, comparison policy, and the current recommendation for
continuing GPU/FFT work.

## Environment

- Compiler: NVIDIA HPC SDK `nvfortran`, `nvc`, MPI wrapper `mpifort`/`mpicc`
- CPU FFT backend: FFTW 3.3.11 built for the NVHPC run environment
- Runtime dependency note: loading `gcc/14.3.0` resolved `libatomic.so.1`
  runtime errors on the tested system
- GPU test system used earlier: NVIDIA A100-PCIE-40GB

## Source Compatibility Fixes

NVHPC rejects several legacy fixed-form `FORMAT` statements that other
compilers accepted. The required source changes are separator-only fixes, for
example `FORMAT(8X` -> `FORMAT(8X,` and `I4/8X` -> `I4/8X,`.

Affected areas:

- CG: `cg_main_gga_df_omp_YY_allct.f`, `rarr4.f`
- SD: `sd_main_df_SXACE_allct.f`, `rarr3.f`, `rarr4.f`, `rarr5.f`
- TDDFT: `lib4_ASL_2_check_Vext_SXACE.f`, `rarr3.f`

## Comparison Policy

The comparison tools use committed GNU logs as the default references:

- CG: `docs/runtime_logs/gnu_si111_h_cg.out`
- SD: `docs/runtime_logs/gnu_si111_h_sd.out`
- TDDFT: `docs/runtime_logs/gnu_si111_h_tddft_100steps.out`

Relaxed tolerances are the default because compiler, MPI rank count, and
reduction order change low-order numerical results. Strict mode remains
available with `--strict`.

Commands:

```sh
python3 ./tools/compare_cg_result.py compare ./run/Si111-H_nvhpc/Si111-H.out
python3 ./tools/compare_sd_result.py compare ./run/Si111-H_nvhpc/Si111-H_sd.out
python3 ./tools/check_tddft_result.py compare ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI
```

## CG Results

NVHPC CG was useful for compiler investigation but is not the current baseline
for downstream SD/TDDFT. The Intel CG result is used as the practical input for
SD.

Observed behavior:

- `-O0 -Kieee`: much closer to GNU/Intel, but still not the preferred baseline
- `-O1 -Kieee`: improved/usable for investigation
- `-O2`: diverges from the first CG/SCF iteration and is not recommended

## SD Results

SD was run using the Intel CG output as input.

Recommended build:

```sh
cd FPSEID21/sd_GGA_f_compact_code
FC=nvfortran FFLAGS="-O1 -mp -Msave -Mlarge_arrays -Kieee" ./mk_ifort.sh
```

Observed behavior:

- `-O0 -Kieee`: PASS with relaxed comparison
- `-O1 -Kieee`: PASS with relaxed comparison
- `-O2`: FAIL; ETOT, force, band energies, and final convergence differ too much

The relaxed SD comparison accepts different SCF iteration counts when both
final potential convergence values satisfy the SD convergence threshold.

## TDDFT CPU FFTW Results

TDDFT was tested using Intel CG output and NVHPC SD output.

Recommended build:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort \
CC=mpicc \
FFLAGS="-O1 -mp -Msave -Mlarge_arrays -Kieee" \
FFTW_ROOT=../../fftw-3.3.11-nvhpc/install \
./mk_ifort.sh
```

Recommended input for validation:

```text
Si111-H_tm.in_100steps
```

TDDFT status by MPI process count:

| MPI ranks | status | approximate wall time for 100 steps |
| ---: | --- | ---: |
| 1 | PASS | 1457 s |
| 2 | PASS | 797 s |
| 4 | PASS | 456 s |
| 5 | PASS | 392 s |
| 6 | FAIL | incomplete output / MPI termination |
| 8 | FAIL | incomplete output / MPI termination |
| 16 | FAIL | incomplete output / MPI termination |

Current recommendation:

```text
Use -np 5 for the NVHPC CPU FFTW TDDFT baseline.
```

Example run:

```sh
cd run/Si111-H_nvhpc
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M

mpirun --quiet -np 5 ../../FPSEID21/tddft_2022October/tddft_exe \
  < Si111-H_tm.in_100steps \
  > Si111-H_tm.out_100steps_5MPI \
  2> Si111-H_tm_5MPI.err
```

Check and compare:

```sh
cd ../..
python3 ./tools/check_tddft_result.py check \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI \
  --err ./run/Si111-H_nvhpc/Si111-H_tm_5MPI.err

python3 ./tools/check_tddft_result.py compare \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_5MPI \
  --test-err ./run/Si111-H_nvhpc/Si111-H_tm_5MPI.err
```

## Current Interpretation

NVHPC CPU execution is validated for SD and for TDDFT up to 5 MPI ranks. The
TDDFT failure at 6 or more ranks is not an input-file issue because `np=1..5`
complete and compare successfully. It is likely related to MPI decomposition,
rank-dependent communication, or an array partitioning assumption.

## Next Step

Use the `-np 5` NVHPC CPU FFTW TDDFT run as the CPU-side performance baseline.
For the first GPU/cuFFT validation, use a simpler `1 GPU + 1 MPI rank` policy.
This separates GPU FFT correctness and transfer overhead from the known
rank-count issue seen at `-np 6` and above.

GPU validation run:

```sh
cd run/Si111-H_nvhpc
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M
export CUDA_VISIBLE_DEVICES=0

mpirun --quiet -np 1 ../../FPSEID21/tddft_2022October/tddft_exe \
  < Si111-H_tm.in_100steps \
  > Si111-H_tm.out_100steps_gpu_1rank \
  2> Si111-H_tm_gpu_1rank.err
```

The current cuFFT result shows that Host <-> Device transfer dominates the FFT
wrapper time. The next implementation target is therefore OpenACC-based GPU
residency in the `S2_` local FFT section, not more one-call FFT replacement and
not custom CUDA kernels. cuFFT remains available as a library backend through
OpenACC device-pointer interoperability. Details are tracked in
`docs/tddft_gpu_residency_plan.md`.

```sh
cd run/Si111-H_nvhpc
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=512M
export CUDA_VISIBLE_DEVICES=0

mpirun --quiet -np 1 ../../FPSEID21/tddft_2022October/tddft_exe \
  < Si111-H_tm.in_100steps \
  > Si111-H_tm.out_100steps_gpu_1rank \
  2> Si111-H_tm_gpu_1rank.err
```

Check the GPU run against the committed GNU reference with the existing relaxed
TDDFT comparison:

```sh
cd ../..
python3 ./tools/check_tddft_result.py check \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_gpu_1rank \
  --err ./run/Si111-H_nvhpc/Si111-H_tm_gpu_1rank.err

python3 ./tools/check_tddft_result.py compare \
  ./run/Si111-H_nvhpc/Si111-H_tm.out_100steps_gpu_1rank \
  --test-err ./run/Si111-H_nvhpc/Si111-H_tm_gpu_1rank.err
```

### Initial cuFFT Result

The first `1 GPU + 1 MPI rank` cuFFT run completed 100 TDDFT steps and passed
the relaxed comparison against the committed GNU TDDFT reference. The archived
run labels are:

- FFTW baseline: `run/tddft_archives/nvhpc_fftw_1rank_o2`
- cuFFT test: `run/tddft_archives/nvhpc_cufft_1rank_o2`

Correctness status:

- `check_tddft_result.py check`: PASS
- `check_tddft_result.py compare`: PASS
- `ETOT`, `Eelec+Enucl-Eext-Ework`, force, positions, and velocities were all
  within relaxed tolerances.

Performance summary for 100 steps:

| profile region | FFTW sec | cuFFT sec | speedup |
| --- | ---: | ---: | ---: |
| `time_step_total` | 501.068871 | 443.502158 | 1.13x |
| `frprmn` | 492.014268 | 434.422398 | 1.13x |
| `tmevl_total` | 427.833639 | 373.854727 | 1.14x |
| `tmevl_s2` | 357.088483 | 306.979328 | 1.16x |
| `s2_nonlocal` | 122.986159 | 123.152011 | 1.00x |
| `s2_fft_local` | 234.100450 | 183.825464 | 1.27x |
| `fft_wrapper` | 163.592244 | 100.969549 | 1.62x |

Interpretation:

- The cuFFT backend is active and improves the targeted FFT regions.
- `fft_wrapper` improved by about 1.62x even though this initial version still
  copies data host -> GPU -> host for every FFT call.
- End-to-end `time_step_total` improved by about 1.13x.
- `s2_nonlocal` did not improve, so it remains a separate non-FFT GPU
  acceleration candidate.
- Further speedup likely requires splitting transfer time from cuFFT execution
  time and keeping the relevant `tmevl_s2` working arrays resident on the GPU
  with OpenACC data regions.

The cuFFT wrapper now prints an additional block at shutdown:

```text
FPSEID_CUFFT_PROFILE_BEGIN
  count h2d_sec fft_sec d2h_sec total_sec
  ...
FPSEID_CUFFT_PROFILE_END
```

This splits the `fft_wrapper` time into host-to-device copy, cuFFT execution,
device-to-host copy, and their CUDA-event measured total. Use this to decide
whether the next optimization should target transfers or FFT execution itself.

Both the TDDFT CPU/FFTW and GPU/cuFFT builds call the name-based
`start_timer('region')` and `stop_timer('region')` interfaces in
`mod_timer.f90`. Their common logical regions are emitted in the original
`[Timer Output]` table and the MPI-aggregated `FPSEID_PROFILE` format. The
GPU-only `FPSEID_CUFFT_PROFILE` remains available for CUDA-event transfer and
cuFFT breakdowns.

Compare both correctness and profile regions:

- `time_step_total`
- `frprmn`
- `tmevl_total`
- `tmevl_s2`
- `s2_fft_local`
- `s2_nonlocal`
- `fft_wrapper`

The initial cuFFT implementation mainly targets `fft_wrapper` and
`s2_fft_local`. Larger speedups will likely require keeping the relevant
`tmevl_s2` working arrays resident on the GPU with OpenACC, then passing those
device pointers to cuFFT where FFT operations are needed.

Important design constraint:

- Keep the current host-copy cuFFT wrapper as a validated compatibility path.
- Add a separate device-pointer cuFFT wrapper for OpenACC-managed arrays.
- The first OpenACC data region should be narrow: enter after the CPU-side
  nonlocal section, keep `RHO1_`/`RHO2_`/`VG` device-side through the local FFT
  pair, and copy `P` back before returning to CPU-side code.
- Build `VG=VGG+Vloc` on the GPU when validating the OpenACC local FFT path.
- Start with a short strict-oriented run, then use the existing 100-step relaxed
  comparison.
