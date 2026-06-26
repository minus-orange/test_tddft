#!/bin/sh
set -eu

# Intel Fortran build for the FPSEID21 SD executable.
#
# Optional environment:
#   FC      Fortran compiler. Default: ifort
#   FFLAGS  Fortran flags. Default: -O3 -mcmodel=medium -qopenmp -traceback
#   LDFLAGS Additional linker flags.

FC=${FC:-ifort}
FFLAGS=${FFLAGS:-"-O3 -mcmodel=medium -qopenmp -traceback"}
LDFLAGS=${LDFLAGS:-}
OUT=${OUT:-sd_exe}

set -x
"$FC" $FFLAGS \
  -o "$OUT" \
  eigsystm.F90 sd_main_df_SXACE_allct.f newfft.f \
  orbanly_part_f.f sd_inputs3.f rarr3.f bannerSD.f \
  potextr.f sddiag3_f_YY.f pack.f ortho.f smatchk2.f \
  gga_lib_3_PBE.f omp_clock.f \
  $LDFLAGS
