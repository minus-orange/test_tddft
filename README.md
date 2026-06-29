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

The Intel/default build keeps using the original source files. GNU builds use
the `_gnu.f` source variants only where GNU Fortran needs compatibility fixes.

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

The Intel/default build keeps using the original source files. GNU builds use
the `_gnu.f` source variants only where GNU Fortran needs compatibility fixes.

## Static call tree

The TDDFT build-source call tree is generated in `docs/tddft_call_tree.md`.
Regenerate it with:

```sh
tools/generate_tddft_call_tree.sh
```

GNU runtime-check logs for the `Si111-H` sample are recorded in
`docs/gnu_runtime_log.md`.

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

Look for:

```text
FPSEID_PROFILE_BEGIN
...
FPSEID_PROFILE_END
```

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
