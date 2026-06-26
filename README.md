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

This build uses `fft_fftw.f` instead of the NEC ASL FFT wrapper. FFTW itself is
distributed under the GNU GPL; see the official FFTW download page for source
and license details:
https://www.fftw.org/download.html

## Static call tree

The TDDFT build-source call tree is generated in `docs/tddft_call_tree.md`.
Regenerate it with:

```sh
tools/generate_tddft_call_tree.sh
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
