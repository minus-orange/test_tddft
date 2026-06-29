#!/bin/sh
set -eu

# Intel Fortran build for the FPSEID21 SD executable.
#
# Optional environment:
#   FC      Fortran compiler. Default: ifort
#   FFLAGS  Fortran flags. Default depends on FC.
#   LDFLAGS Additional linker flags.

FC=${FC:-ifort}
case "$FC" in
  *gfortran*)
    FFLAGS=${FFLAGS:-"-O2 -fopenmp -fno-automatic -fallow-argument-mismatch -fallow-invalid-boz"}
    MAIN_SRC=${MAIN_SRC:-sd_main_df_SXACE_allct_gnu.f}
    RARR3_SRC=${RARR3_SRC:-rarr3_gnu.f}
    ;;
  *)
    FFLAGS=${FFLAGS:-"-O3 -mcmodel=medium -qopenmp -traceback -heap-arrays"}
    MAIN_SRC=${MAIN_SRC:-sd_main_df_SXACE_allct.f}
    RARR3_SRC=${RARR3_SRC:-rarr3.f}
    ;;
esac
LDFLAGS=${LDFLAGS:-}
OUT=${OUT:-sd_exe}

set -x
"$FC" $FFLAGS \
  -o "$OUT" \
  eigsystm.F90 "$MAIN_SRC" newfft.f \
  orbanly_part_f.f sd_inputs3.f "$RARR3_SRC" bannerSD.f \
  potextr.f sddiag3_f_YY.f pack.f ortho.f smatchk2.f \
  gga_lib_3_PBE.f omp_clock.f \
  $LDFLAGS
