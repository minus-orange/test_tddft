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

## One-command x86 CPU/FFTW build and reference run

On x86-64 Linux, the following helper performs toolchain checks, builds FFTW,
CG, SD, and TDDFT, prepares the Si111-H input, runs three independent
CG -> SD -> 100-step TDDFT sequences with 16 MPI ranks, archives every TDDFT
result, requires
normal check and relaxed compare to pass, compares runs 02/03 strictly with
run 01, and prints the median and range:

```sh
./tools/run_tddft_x86_baseline.sh
```

The default toolchain is Intel oneAPI: CG and SD use `ifx`, TDDFT uses
`mpiifx`, the MPI C wrapper is `mpiicx`, and the local FFTW build uses
`icx`/`ifx`. Run it with:

```sh
./tools/run_tddft_x86_baseline.sh
```

GNU/OpenMPI remains available as an explicit fallback:

```sh
TOOLCHAIN=gnu ./tools/run_tddft_x86_baseline.sh
```

To use an existing FFTW installation instead of building a local copy:

```sh
SKIP_FFTW=1 FFTW_ROOT=/path/to/fftw \
  ./tools/run_tddft_x86_baseline.sh
```

This build-and-run helper retains its historical reference configuration of
16 MPI ranks, 1 OpenMP thread per rank, diagnostics off, and 100 TDDFT steps.
Override `NPROCS` and `OMP_NUM_THREADS` only when a separate investigation is
required; CG and SD remain at one OpenMP thread. Set `RUNS=1` only for a smoke
test; the default three-run result is required for a controlled median.
Immediately before each TDDFT run, the helper prints the effective launch.
Use the fixed 32 MPI x 8 OpenMP helper documented below for the current
accepted performance configuration.

If a run returns to the prompt before printing the three-run summary, diagnose
the latest x86 output, stderr, normal check, and relaxed comparison with:

```sh
./tools/check_tddft_x86_result.sh
```

The x86 cross-toolchain/rank comparison uses energy `1e-4` Hartree, force
`2e-4` Hartree/Bohr, position `2e-6` Bohr, and velocity `1e-6` tolerances.
The force threshold is about `0.0103 eV/Angstrom`; the observed 16-rank Intel
difference that motivated it was about `0.00624 eV/Angstrom`. These wider
force and position thresholds apply only to the x86 baseline helpers. The
global comparator defaults and GPU validation tolerances remain unchanged,
and x86 runs 02/03 must still pass the existing strict pairwise comparison
against run 01.

The helper defaults to `BUILD_MODE=auto`. It records separate CG, SD, and TDDFT
build signatures under the ignored `.cache/tddft_x86_build/` directory and
reuses each existing binary when its tracked sources, build settings, and
compiler identities still match. Unchanged components are therefore not
rebuilt when only one source tree changes. Use `BUILD_MODE=always` to force a
rebuild. Use `BUILD_MODE=never` once to adopt known-compatible existing
binaries without compiling; that run records their signatures, so subsequent
default `auto` runs can reuse them safely.

To screen 4/8/16/32 MPI ranks against 2/4/8/16 OpenMP threads without
recompiling, run:

```sh
./tools/run_tddft_x86_mpi_omp_sweep.sh
```

The 256-core default sets `MAX_TOTAL_THREADS=256`, so `32 MPI x 16 OpenMP`
is skipped and the remaining 15 configurations run once each. CG and SD
remain fixed at one OpenMP thread; only TDDFT receives the requested thread
count. Intel MPI uses `I_MPI_PIN_DOMAIN=omp` and Intel OpenMP uses compact
affinity. The terminal summary is ranked by TDDFT wall time and records total
threads and whether that count exceeds the online logical CPUs. Set
`RUNS_PER_CONFIG=3` only for a controlled three-run sweep; the normal workflow
is to screen once and then repeat only the fastest valid configuration three
times.

The accepted x86 performance baseline is 32 MPI ranks x 8 OpenMP threads. To
build or safely reuse the matching Intel binaries and repeat its controlled
three-run measurement with the accepted compact binding, use the fixed
configuration helper:

```sh
./tools/run_tddft_x86_32mpi_8omp.sh
```

The helper fixes `TOOLCHAIN=intel`, 32 MPI ranks, 8 TDDFT OpenMP threads,
one CG/SD OpenMP thread, `I_MPI_PIN_DOMAIN=omp`, and compact rank/thread
placement. It does not expose an MPI/OpenMP configuration override. Set
`RUNS=1` only for a smoke test; the default `RUNS=3` is required for a formal
median. The general sweep helper remains available for investigation, but is
not needed to repeat the accepted configuration.

On the Intel Xeon 6980P measurement host this configuration produced a
`16.5392820835` sec median and `0.0579471588` sec range. The earlier 16 MPI
x 1 OpenMP baseline remains historical scaling evidence.

The completed Intel MPI rank-order screen is retained under
`tools/history/x86/`. Its scatter variant emitted IPL2 domain-size errors,
failed the normal stderr gate, and took `78.1684319973` sec. Spread was not
run after the required early stop. Keep the accepted compact placement and do
not rerun the historical helper automatically.

## NVIDIA HPC SDK build

This path uses NVIDIA HPC SDK compilers for a CPU/OpenMP + MPI build. It does
not offload TDDFT kernels to NVIDIA GPUs yet; GPU execution will require
separate OpenACC/CUDA-oriented source changes after this compiler/runtime check
is stable.

For the current NVHPC validation status, recommended optimization levels, MPI
rank limits, and comparison policy, see
[`docs/nvhpc_validation_summary.md`](docs/nvhpc_validation_summary.md).

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
The CG original-source baseline includes only standard `FORMAT` separator fixes
needed by NVHPC; no CG numerical algorithm changes are applied.

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

Manual TDDFT-only OpenACC + cuFFT build with compiler reports:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort CC=nvc FFT_BACKEND=cufft BUILD_REPORT=1 \
  FFLAGS="-O2 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays -Kieee" \
  CUFFT_LIBS="-cudalib=cufft" ./mk_ifort.sh
```

Useful flag meanings:

- `-O2`: enable normal optimization without the more aggressive transformations
  of `-O3`.
- `-acc`: enable OpenACC directive compilation.
- `-gpu=cc80`: generate GPU code for NVIDIA Ampere/A100 class GPUs. Adjust this
  to the installed GPU when needed.
- `-mp`: enable OpenMP support for the existing CPU-side OpenMP regions.
- `-Msave`: give local variables static storage, matching assumptions in older
  Fortran code.
- `-Mlarge_arrays`: allow large static/local arrays used by the FPSEID21 TDDFT
  sources.
- `-Kieee`: preserve IEEE floating-point behavior more strictly. This is useful
  while comparing compiler/runtime variants.
- `BUILD_REPORT=1`: append compiler report flags and print the final compiler,
  include, and link settings used by `mk_ifort.sh`.
- default NVHPC `REPORT_FLAGS`: `-Minfo=accel -Minfo=mp`, which reports
  OpenACC accelerator generation and OpenMP processing decisions.

To make the compiler report even more verbose, override `REPORT_FLAGS`, for
example:

```sh
BUILD_REPORT=1 REPORT_FLAGS="-Minfo=accel -Minfo=mp -Minfo=inline" ./mk_ifort.sh
```

cuFFT builds print an additional `FPSEID_CUFFT_PROFILE` block at shutdown. It
splits the FFT wrapper time into host-to-device copy, cuFFT execution,
device-to-host copy, and CUDA-event measured total time.
CPU/FFTW and GPU/cuFFT builds call the same name-based timers from
`mod_timer.f90` at matching logical regions. The `[Timer Output]` table is an
indented call-path tree: child regions appear below their active parent, and
the same region name is shown separately when it is reached from different
parents. Its elapsed values are inclusive. The MPI-aggregated
`FPSEID_PROFILE` block remains a flat name-based summary for existing result
checks and reporting tools. The cuFFT C wrapper keeps its additional CUDA-event
breakdown for GPU-only transfer and execution analysis.

The photographed Step 119 Intel x86 timer-tree values and matching three-run
provenance are preserved in `docs/STEP119_X86_TIMER_TREE.md`.

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

The same variables can be passed to the TDDFT-only build:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort CC=nvc FFT_BACKEND=cufft \
  CUDA_RUNTIME_INCLUDE=/path/to/cuda/include \
  CUFFT_INCLUDE=/path/to/cufft/include \
  CUFFT_LIBS="-cudalib=cufft" ./mk_ifort.sh
```

If the compiler finds headers but the linker cannot find `-lcufft` or
`-lcudart`, also pass the library directories:

```sh
cd FPSEID21/tddft_2022October
FC=mpifort CC=nvc FFT_BACKEND=cufft \
  CUDA_RUNTIME_INCLUDE=/path/to/cuda/include \
  CUFFT_INCLUDE=/path/to/math_libs/13.2/targets/x86_64-linux/include \
  CUDA_RUNTIME_LIB=/path/to/cuda/lib64 \
  CUFFT_LIB=/path/to/math_libs/13.2/targets/x86_64-linux/lib \
  CUFFT_LIBS="-lcufft -lcudart" ./mk_ifort.sh
```

For a smoke test after building:

```sh
./tools/prepare_si111_h_sample.sh
ulimit -s unlimited
export OMP_STACKSIZE=512M
export OMP_NUM_THREADS=1
NPROCS=1 TDDFT_INPUT=Si111-H_tm.in_2steps ./tools/run_si111_h_sample.sh
python3 tools/check_tddft_result.py check run/Si111-H/Si111-H_tm.out \
  --err run/Si111-H/Si111-H_tm.err \
  --expected-steps 2
```

Archive a TDDFT run before changing compilers, FFT backends, or MPI settings:

```sh
LABEL=nvhpc_fftw_1rank ./tools/archive_tddft_result.sh run/Si111-H_nvhpc
```

The archive is written under `run/tddft_archives/` by default and includes
`tddft.out`, optional `tddft.err`, the TDDFT input/state files, `fort.*` unit
links, and a `README.txt` with check/compare commands.

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

To compare CG logs from two platforms, use `tools/compare_cg_result.py`.
First confirm that the two CG input states match:

```sh
./tools/compare_cg_run_inputs.sh intel-run nvhpc-run
```

Then compare an Intel reference run and an NVHPC test run:

```sh
python3 tools/compare_cg_result.py compare \
  intel-run/Si111-H.out nvhpc-run/Si111-H.out \
  --ref-err intel-run/Si111-H.err \
  --test-err nvhpc-run/Si111-H.err \
  --ref-run-dir intel-run \
  --test-run-dir nvhpc-run
```

The comparison checks `ETOT`, total charge, all force components, and band
energies with tolerances. It also reports density/wavefunction file size and
SHA-256 when run directories are provided. Exact file hash equality is reported
but not required by default; add `--require-file-match` only when bitwise
matching is expected.

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
  --err run/Si111-H/Si111-H_tm.err \
  --expected-steps 100
```

Compare a 1-rank reference with a 32-rank run:

```sh
python3 tools/check_tddft_result.py compare \
  run/Si111-H_np1/Si111-H_tm.out \
  run/Si111-H_np32/Si111-H_tm.out \
  --ref-err run/Si111-H_np1/Si111-H_tm.err \
  --test-err run/Si111-H_np32/Si111-H_tm.err \
  --expected-steps 100
```

The default tolerances are:

- energy: `1e-4` Hartree
- force: `1e-4` Hartree/au
- position: `1e-6`
- velocity: `1e-6`

Every check also requires a valid `steps took ... sec` completion marker.
`compare` rejects different reference and test step counts. For a fixed-size
validation, pass `--expected-steps N` to require the exact intended count.
Pass `--strict` to use `1e-5` for energy and force while retaining the
`1e-6` position and velocity tolerances.

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

- `FPSEID21/tddft_2022October/mod_timer.f90`
- `FPSEID21/tddft_2022October/mk.sh`
- `FPSEID21/tddft_2022October/mk_ifort.sh`
- `FPSEID21/tddft_2022October/pspw_tm11_Vext_Avec_v4_alloc.f`
- `FPSEID21/tddft_2022October/tmevl10_Avec_v4.f`
- `FPSEID21/tddft_2022October/FFT_ASL_new.f`
- `FPSEID21/tddft_2022October/fft_fftw.f`
- `tools/build_fftw3.sh`

The original FPSEID21 source is distributed by AIST:
https://staff.aist.go.jp/yoshi-miyamoto/
