#!/bin/sh
set -eu

# Build a local FFTW3 installation for FPSEID21 Intel/FFTW builds.
#
# Defaults:
#   VERSION=3.3.11
#   PREFIX=<repo>/tools/fftw-3.3.11/install
#   CC=icx if available, otherwise icc, otherwise cc
#   FC=ifort if available, otherwise empty. Set FC=none to disable Fortran.
#   F77 defaults to FC when FC is set.
#
# Override examples:
#   CC=icx FC=ifx F77=ifx ./tools/build_fftw3.sh
#   PREFIX=/opt/fftw-3.3.11 CC=gcc FC=gfortran F77=gfortran ./tools/build_fftw3.sh

VERSION=${VERSION:-3.3.11}
URL=${URL:-https://www.fftw.org/fftw-${VERSION}.tar.gz}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
WORK_DIR=${WORK_DIR:-"$ROOT_DIR/tools/build"}
PREFIX=${PREFIX:-"$ROOT_DIR/tools/fftw-${VERSION}/install"}
TARBALL="$WORK_DIR/fftw-${VERSION}.tar.gz"
SRC_DIR="$WORK_DIR/fftw-${VERSION}"

if command -v icx >/dev/null 2>&1; then
  DEFAULT_CC=icx
elif command -v icc >/dev/null 2>&1; then
  DEFAULT_CC=icc
else
  DEFAULT_CC=cc
fi
CC=${CC:-$DEFAULT_CC}

if command -v ifort >/dev/null 2>&1; then
  DEFAULT_FC=ifort
else
  DEFAULT_FC=
fi
FC=${FC:-$DEFAULT_FC}
case "$FC" in
  none|NONE|no|NO)
    FC=
    ;;
esac
F77=${F77:-$FC}
case "$F77" in
  none|NONE|no|NO)
    F77=
    ;;
esac

if command -v getconf >/dev/null 2>&1; then
  JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}
else
  JOBS=${JOBS:-4}
fi

mkdir -p "$WORK_DIR"

if [ ! -f "$TARBALL" ]; then
  curl -L -o "$TARBALL" "$URL"
fi

rm -rf "$SRC_DIR"
tar xzf "$TARBALL" -C "$WORK_DIR"

cd "$SRC_DIR"

set -x
if [ -n "$FC" ]; then
  CC="$CC" FC="$FC" F77="$F77" ./configure \
    --prefix="$PREFIX" \
    --enable-threads \
    --enable-openmp \
    --with-pic
else
  CC="$CC" FC= F77= ./configure \
    --prefix="$PREFIX" \
    --enable-threads \
    --enable-openmp \
    --with-pic
fi
make -j"$JOBS"
make install

set +x
echo "FFTW3 installed under: $PREFIX"
echo "Use it with:"
echo "  cd FPSEID21/tddft_2022October"
echo "  FFTW_ROOT=$PREFIX ./mk_ifort.sh"
