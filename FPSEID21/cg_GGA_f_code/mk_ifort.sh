#!/bin/sh
set -eu

# Intel Fortran build for the FPSEID21 CG executable.
#
# Optional environment:
#   FC      Fortran compiler. Default: ifort
#   FFLAGS  Fortran flags. Default depends on FC.
#   LDFLAGS Additional linker flags.

FC=${FC:-ifort}
case "$FC" in
  *gfortran*)
    FFLAGS=${FFLAGS:-"-O2 -fopenmp -fno-automatic -fallow-argument-mismatch -fallow-invalid-boz"}
    MAIN_SRC=${MAIN_SRC:-cg_main_gga_df_omp_YY_allct_gnu.f}
    RARR4_SRC=${RARR4_SRC:-rarr4_gnu.f}
    ;;
  *)
    FFLAGS=${FFLAGS:-"-O3 -mcmodel=medium -qopenmp -traceback -heap-arrays"}
    MAIN_SRC=${MAIN_SRC:-cg_main_gga_df_omp_YY_allct.f}
    RARR4_SRC=${RARR4_SRC:-rarr4.f}
    ;;
esac
LDFLAGS=${LDFLAGS:-}
OUT=${OUT:-cg_exe}

set -x
"$FC" $FFLAGS \
  -o "$OUT" \
  eigsystm.F90 "$MAIN_SRC" dosgen.f \
  newfft.f orbanly_part_f.f cg_inputs3.f "$RARR4_SRC" \
  potextr.f pack.f smatchk2.f gga_lib_3_PBE.f \
  omp_clock.f bannerCG.f \
  $LDFLAGS
