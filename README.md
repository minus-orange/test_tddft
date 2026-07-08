# test_tddft

FPSEID21 TDDFT profiling patch.

This repository contains a lightly instrumented copy of the FPSEID21 TDDFT
source needed to build `tddft_exe`. The profiling additions use `MPI_Wtime`
and print a summary block to standard output at the end of `tddft_exe` runs.

## Build

The included `mk.sh` follows the upstream NEC Aurora/ASL build style. It
expects these tools/libraries to be available in the build environment:

- `mpinfort`
- NEC ASL, providing `asl_unified` and `-lasl_sequential`
- MPI headers/libraries

Build from the TDDFT source directory:

```sh
cd FPSEID21/tddft_2022October
chmod 744 mk.sh
./mk.sh
```

## Intel/FFTW build

For an Intel compiler environment, use the separate FFTW build path. FFTW is
not vendored in this repository; `tools/build_fftw3.sh` downloads the official
FFTW source tarball and installs it under `tools/fftw-3.3.11/install` by
default.

```sh
./tools/build_fftw3.sh
cd FPSEID21/tddft_2022October
FFTW_ROOT=$PWD/../../tools/fftw-3.3.11/install ./mk_ifort.sh
```

The default TDDFT compiler wrapper is `mpiifort`. Override it when needed:

```sh
FC=mpiifx FFTW_ROOT=$PWD/../../tools/fftw-3.3.11/install ./mk_ifort.sh
```

GNU/OpenMPI builds can use Homebrew or system FFTW:

```sh
FC=mpifort CC=mpicc FFLAGS="-O2 -fopenmp -fno-automatic -fallow-argument-mismatch -fallow-invalid-boz" \
  FFTW_ROOT=/opt/homebrew/opt/fftw ./mk_ifort.sh
```

The Intel/default and NVIDIA HPC SDK build paths use the original source files.
GNU Fortran builds use `_gnu.f` source variants only where that compiler needs
format-statement compatibility fixes.

## NVIDIA HPC SDK build

This path uses NVIDIA HPC SDK compilers for a CPU/OpenMP + MPI build. It does
not offload TDDFT kernels to NVIDIA GPUs yet; GPU execution will require
separate OpenACC/CUDA-oriented source changes after this compiler/runtime check
is stable.

Load the NVIDIA HPC SDK and MPI environment first. The exact module names are
site-specific, for example:

```sh
module load nvhpc
module load openmpi
```

Then build FFTW, CG, SD, and TDDFT with the helper script:

```sh
./tools/build_nvhpc.sh
```

The script defaults to:

- `NVFORTRAN=nvfortran`
- `MPI_FC=mpifort`
- `MPI_CC=mpicc`
- `FFTW_CC=cc`
- `FFTW_FC=gfortran`
- `FFTW_F77=gfortran`
- `FFTW_ROOT=tools/fftw-3.3.11-nvhpc/install`
- `FFLAGS="-O2 -mp -Msave -Mlarge_arrays"`

The NVIDIA HPC SDK path intentionally uses the original FPSEID21 sources. Use
this path first to validate CG, then SD, then TDDFT behavior before reapplying
compiler-specific source changes.

FFTW is built with GCC-compatible compilers by default, not `nvc`/`nvfortran`.
This avoids NVIDIA compiler installations that cannot find the host GCC
toolchain during FFTW `configure`. If the system `cc` is not a working
GCC-compatible compiler, select one explicitly:

```sh
FFTW_CC=gcc FFTW_FC=gfortran FFTW_F77=gfortran ./tools/build_nvhpc.sh
```

If TDDFT fails at runtime with `libatomic.so.1: cannot open shared object
file`, add the GCC runtime directory to `LD_LIBRARY_PATH` before running:

```sh
GCC_RT=$(dirname "$(gfortran -print-file-name=libatomic.so.1)")
export LD_LIBRARY_PATH="$GCC_RT:${LD_LIBRARY_PATH:-}"
```

`tools/build_nvhpc.sh` prints this export line when it can detect the runtime
directory.

Override them when the site uses a different MPI wrapper:

```sh
MPI_FC=mpifort MPI_CC=mpicc ./tools/build_nvhpc.sh
```

If FFTW is already installed, skip the local FFTW build:

```sh
SKIP_FFTW=1 FFTW_ROOT=/path/to/fftw ./tools/build_nvhpc.sh
```

To build the first GPU-enabled TDDFT variant, switch only the FFT wrapper from
FFTW to cuFFT:

```sh
ENABLE_GPU_FFT=1 ./tools/build_nvhpc.sh
```

This keeps CG and SD on the CPU and changes TDDFT's
`FFT3BX_fftwASL`/`FFT3FX_fftwASL` backend to cuFFT. The current cuFFT path is
an initial validation step: each FFT copies one complex array from host to GPU,
executes cuFFT, and copies it back. Use the existing profile output to verify
correctness and whether `fft_wrapper`/`s2_fft_local` improve before moving more
of `tmevl_s2` onto the GPU.

Manual TDDFT-only build:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort CC=mpicc FFLAGS="-O2 -mp -Msave -Mlarge_arrays" \
  FFTW_ROOT=$PWD/../../tools/fftw-3.3.11-nvhpc/install ./mk_ifort.sh
```

Manual TDDFT-only cuFFT build:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort CC=mpicc FFT_BACKEND=cufft \
  FFLAGS="-O2 -mp -Msave -Mlarge_arrays" \
  CUFFT_LIBS="-cudalib=cufft" ./mk_ifort.sh
```

If the MPI C wrapper cannot find CUDA headers, use the NVIDIA C compiler or
add the CUDA include/library paths supplied by the site module, for example:

```sh
FC=mpifort CC=nvc FFT_BACKEND=cufft \
  CUFFT_LIBS="-cudalib=cufft" ./mk_ifort.sh
```

The top-level NVHPC helper does this automatically for GPU FFT builds by using
`GPU_CC=nvc` unless overridden:

```sh
GPU_CC=nvc ENABLE_GPU_FFT=1 ./tools/build_nvhpc.sh
```

If CUDA is installed outside the compiler module's default search path, point
the helper at it explicitly:

```sh
CUDA_ROOT=/path/to/cuda ENABLE_GPU_FFT=1 ./tools/build_nvhpc.sh
```

or pass only the include path:

```sh
GPU_CFLAGS="-I/path/to/cuda/include" ENABLE_GPU_FFT=1 ./tools/build_nvhpc.sh
```

If `cuda_runtime.h` and `cufft.h` are in different include directories, set
them separately:

```sh
CUDA_RUNTIME_INCLUDE=/path/to/cuda/include \
CUFFT_INCLUDE=/path/to/cufft/include \
ENABLE_GPU_FFT=1 ./tools/build_nvhpc.sh
```

For a smoke test after building:

```sh
./tools/prepare_si111_h_sample.sh
ulimit -s unlimited
export OMP_STACKSIZE=512M
export OMP_NUM_THREADS=1
NPROCS=1 TDDFT_INPUT=Si111-H_tm.in_2steps ./tools/run_si111_h_sample.sh
python3 tools/check_tddft_result.py check run/Si111-H/Si111-H_tm.out \
  --err run/Si111-H/Si111-H_tm.err
```

Then compare MPI process counts:

```sh
REF_NPROCS=1 TEST_NPROCS=32 TDDFT_INPUT=Si111-H_tm.in_100steps \
  ./tools/run_tddft_consistency_check.sh
```

This build uses `fft_fftw.f` instead of the NEC ASL FFT wrapper. FFTW itself is
distributed under the GNU GPL; see the official FFTW download page for source
and license details:
https://www.fftw.org/download.html

## CG/SD Intel builds

The non-TDDFT CG and SD source trees are included with Intel-oriented wrapper
scripts. Build them from each source directory:

```sh
cd FPSEID21/cg_GGA_f_code
./mk_ifort.sh

cd ../sd_GGA_f_compact_code
./mk_ifort.sh
```

Both scripts default to `FC=ifort`. Override the compiler or flags when needed:

```sh
FC=ifx FFLAGS="-O3 -qopenmp -traceback" ./mk_ifort.sh
```

The CG/SD code has large work arrays, for example in `FRPRMN`. On Linux Intel
runtime builds, set a large process/thread stack before launching if CG fails
with `forrtl: severe (174): SIGSEGV` near the first executable line of the
routine:

```sh
ulimit -s unlimited
export OMP_STACKSIZE=512M
```

GNU builds were checked with:

```sh
FC=gfortran FFLAGS="-O2 -fopenmp -fno-automatic -fallow-argument-mismatch -fallow-invalid-boz" ./mk_ifort.sh
```

The Intel/default and NVIDIA HPC SDK build paths use the original source files.
GNU Fortran builds use `_gnu.f` source variants only where that compiler needs
format-statement compatibility fixes.

## Static call tree

The TDDFT build-source call tree is generated in `docs/tddft_call_tree.md`.
Regenerate it with:

```sh
tools/generate_tddft_call_tree.sh
```

GNU runtime-check logs for the `Si111-H` sample are recorded in
`docs/gnu_runtime_log.md`.

Intel Xeon Platinum 8592+ TDDFT 2/50/100-step profiling results are recorded
in `docs/intel_8592_runtime_log.md`.

## Si111-H sample setup

The sample data used for the GNU runtime check is not committed. Download the
AIST `Si111-H` inputs and pseudopotentials, then prepare a local run directory:

```sh
./tools/prepare_si111_h_sample.sh
```

By default this writes downloaded files to `.cache/fpseid21-samples` and the
run directory to `run/Si111-H`. Both paths are ignored by git. Override them
when needed:

```sh
CACHE_DIR=/tmp/fpseid21-samples RUN_DIR=/tmp/fpseid21-run TDDFT_STEPS="2 50 100" \
  ./tools/prepare_si111_h_sample.sh
```

After building the executables, run CG first, SD second, and TDDFT last from
the prepared run directory. CG and SD generate the `rh.Si111-H` and
`wf_fft.Si111-H` files consumed by TDDFT.

For Intel runtime checks, apply the stack settings in the same shell before
running CG/SD/TDDFT:

```sh
ulimit -s unlimited
export OMP_STACKSIZE=512M
```

The helper below runs the prepared sample in order and promotes the generated
density/wavefunction files before the next stage. CG/SD leave the density in
`fort.24`, the TDDFT reciprocal-space wavefunction in `fort.23`, and a
real-space intermediate in `fort.88`. The helper copies `fort.24` to
`rh.Si111-H` and `fort.23` to `wf_fft.Si111-H`, avoiding stale or mismatched
state. It also initializes the TDDFT control files behind `fort.18`,
`fort.28`, `fort.60`, and `fort.62`. `fort.88` is kept because SD reads it as
wavefunction input:

```sh
./tools/run_si111_h_sample.sh
```

To check the implicit Fortran unit files before running a stage manually:

```sh
./tools/check_si111_h_unit_files.sh cg
./tools/check_si111_h_unit_files.sh sd
./tools/check_si111_h_unit_files.sh tddft Si111-H_tm.in_100steps
```

To run and check only the CG stage, for example when validating the NVIDIA HPC
SDK baseline from the original sources:

```sh
cd run/Si111-H
ulimit -s unlimited
export OMP_STACKSIZE=512M
export OMP_NUM_THREADS=1
../../FPSEID21/cg_GGA_f_code/cg_exe < Si111-H.in > Si111-H.out 2> Si111-H.err
cd ../..
./tools/check_cg_result.sh
```

The CG result checker validates that the log reached `CPU TIME END OF PSPW`,
prints the final `ETOT`, checks the force block, scans stdout/stderr for
obvious runtime errors, and confirms that the density/wavefunction outputs
needed by SD are present.

Look for:

```text
FPSEID_PROFILE_BEGIN
...
FPSEID_PROFILE_END
```

## TDDFT result consistency checks

Use `tools/check_tddft_result.py` to sanity-check one TDDFT log or compare two
logs from different MPI process counts, compilers, or machines. The comparison
uses tolerances because MPI reduction order and compiler math can change the
last digits without changing the result materially.

Check one output/error pair:

```sh
python3 tools/check_tddft_result.py check \
  run/Si111-H/Si111-H_tm.out \
  --err run/Si111-H/Si111-H_tm.err
```

Compare a 1-rank reference with a 32-rank run:

```sh
python3 tools/check_tddft_result.py compare \
  run/Si111-H_np1/Si111-H_tm.out \
  run/Si111-H_np32/Si111-H_tm.out \
  --ref-err run/Si111-H_np1/Si111-H_tm.err \
  --test-err run/Si111-H_np32/Si111-H_tm.err
```

The default tolerances are:

- energy: `1e-5` Hartree
- force: `1e-5` Hartree/au
- position: `1e-6`
- velocity: `1e-6`

Relax or tighten them when comparing different compiler/MPI environments:

```sh
python3 tools/check_tddft_result.py compare ref.out test.out \
  --energy-atol 1e-4 \
  --force-atol 1e-4 \
  --position-atol 1e-5
```

Before comparing logs from different compiler environments, verify that both
TDDFT runs started from identical input state:

```sh
TDDFT_INPUT=Si111-H_tm.in_100steps \
  ./tools/compare_tddft_run_inputs.sh run/Si111-H run/Si111-H_nvhpc
```

This checks the TDDFT input file, control files, density/wavefunction state
files, pseudopotentials, and the relevant `fort.*` unit links/files. If this
fails, the output logs should not be interpreted as a compiler or GPU
correctness comparison.

To run the sample twice and compare automatically, use:

```sh
REF_NPROCS=1 TEST_NPROCS=32 TDDFT_INPUT=Si111-H_tm.in_100steps \
  ./tools/run_tddft_consistency_check.sh
```

The wrapper reuses `tools/prepare_si111_h_sample.sh` and
`tools/run_si111_h_sample.sh`, so the usual environment overrides still apply,
including `MPIRUN`, `CG_EXE`, `SD_EXE`, `TDDFT_EXE`, `OMP_NUM_THREADS`,
`RUN_BASE`, and the tolerance variables `ENERGY_ATOL`, `FORCE_ATOL`,
`POSITION_ATOL`, and `VELOCITY_ATOL`.

Instrumented files:

- `FPSEID21/tddft_2022October/prof_timer.f`
- `FPSEID21/tddft_2022October/mk.sh`
- `FPSEID21/tddft_2022October/mk_ifort.sh`
- `FPSEID21/tddft_2022October/pspw_tm11_Vext_Avec_v4_alloc.f`
- `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`
- `FPSEID21/tddft_2022October/FFT_ASL_new.f`
- `FPSEID21/tddft_2022October/fft_fftw.f`
- `tools/build_fftw3.sh`

The original FPSEID21 source is distributed by AIST:
https://staff.aist.go.jp/yoshi-miyamoto/
