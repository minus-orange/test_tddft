#!/bin/sh
set -eu

# Download the AIST Si111-H sample input files and prepare a local run
# directory without committing the sample data or generated wavefunctions.
#
# Defaults:
#   CACHE_DIR=<repo>/.cache/fpseid21-samples
#   RUN_DIR=<repo>/run/Si111-H
#   TDDFT_STEPS="2 50 100"
#
# Override examples:
#   RUN_DIR=/tmp/fpseid21-run TDDFT_STEPS="10" ./tools/prepare_si111_h_sample.sh
#   CACHE_DIR=/tmp/fpseid21-samples ./tools/prepare_si111_h_sample.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

CACHE_DIR=${CACHE_DIR:-"$ROOT_DIR/.cache/fpseid21-samples"}
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H"}
TDDFT_STEPS=${TDDFT_STEPS:-"2 50 100"}

SI_BASE=${SI_BASE:-"https://staff.aist.go.jp/yoshi-miyamoto/en/examples/Si111-H"}
TR_BASE=${TR_BASE:-"https://staff.aist.go.jp/yoshi-miyamoto/en/TR"}

download_file() {
  url=$1
  dest=$2

  if [ -f "$dest" ]; then
    echo "Using cached: $dest"
    return
  fi

  mkdir -p "$(dirname -- "$dest")"
  echo "Downloading: $url"
  curl -L -f -o "$dest" "$url"
}

copy_file() {
  src=$1
  dest=$2

  if [ ! -f "$src" ]; then
    echo "ERROR: missing required file: $src" >&2
    exit 1
  fi

  cp "$src" "$dest"
}

link_file() {
  link_name=$1
  target_name=$2

  rm -f "$RUN_DIR/$link_name"
  ln -s "$target_name" "$RUN_DIR/$link_name"
}

write_if_missing() {
  dest=$1
  value=$2

  if [ ! -f "$dest" ]; then
    printf "%s\n" "$value" > "$dest"
  fi
}

make_tddft_input() {
  steps=$1
  src=$RUN_DIR/Si111-H_tm.in_1000steps
  dest=$RUN_DIR/Si111-H_tm.in_${steps}steps

  if [ "$steps" -le 2 ]; then
    tmod=1
  else
    tmod=$steps
  fi

  sed "s/tstep=[0-9][0-9]*/tstep=$steps/; s/TMOD=[0-9][0-9]*/TMOD=$tmod/" \
    "$src" > "$dest"
}

mkdir -p "$CACHE_DIR/Si111-H/Xpol-FWHM=2fs-800nm-2.0VpA" "$CACHE_DIR/TR"
mkdir -p "$RUN_DIR"

download_file "$SI_BASE/Si111-H.in" "$CACHE_DIR/Si111-H/Si111-H.in"
download_file "$SI_BASE/Si111-H_sd.in" "$CACHE_DIR/Si111-H/Si111-H_sd.in"
download_file "$SI_BASE/Si111-H_tm.in_1000steps" "$CACHE_DIR/Si111-H/Si111-H_tm.in_1000steps"
download_file "$SI_BASE/size.dat" "$CACHE_DIR/Si111-H/size.dat"
download_file "$SI_BASE/sym.C1" "$CACHE_DIR/Si111-H/sym.C1"
download_file "$SI_BASE/Xpol-FWHM=2fs-800nm-2.0VpA/laser.dat" \
  "$CACHE_DIR/Si111-H/Xpol-FWHM=2fs-800nm-2.0VpA/laser.dat"
download_file "$TR_BASE/TR.Si93g_asci" "$CACHE_DIR/TR/TR.Si93g_asci"
download_file "$TR_BASE/TR.Si93e_asci" "$CACHE_DIR/TR/TR.Si93e_asci"
download_file "$TR_BASE/TR.H99g_asc" "$CACHE_DIR/TR/TR.H99g_asc"

copy_file "$CACHE_DIR/Si111-H/Si111-H.in" "$RUN_DIR/Si111-H.in"
copy_file "$CACHE_DIR/Si111-H/Si111-H_sd.in" "$RUN_DIR/Si111-H_sd.in"
copy_file "$CACHE_DIR/Si111-H/Si111-H_tm.in_1000steps" "$RUN_DIR/Si111-H_tm.in_1000steps"
copy_file "$CACHE_DIR/Si111-H/size.dat" "$RUN_DIR/size.dat"
copy_file "$CACHE_DIR/Si111-H/sym.C1" "$RUN_DIR/sym.C1"
copy_file "$CACHE_DIR/Si111-H/Xpol-FWHM=2fs-800nm-2.0VpA/laser.dat" "$RUN_DIR/laser.dat"
copy_file "$CACHE_DIR/TR/TR.Si93g_asci" "$RUN_DIR/TR.Si93g_asci"
copy_file "$CACHE_DIR/TR/TR.Si93e_asci" "$RUN_DIR/TR.Si93e_asci"
copy_file "$CACHE_DIR/TR/TR.H99g_asc" "$RUN_DIR/TR.H99g_asc"

for steps in $TDDFT_STEPS; do
  make_tddft_input "$steps"
done

write_if_missing "$RUN_DIR/Eext" "0.0 0.0"
write_if_missing "$RUN_DIR/Etot" "0.0"
write_if_missing "$RUN_DIR/Avec" "0.0 0.0 0.0"
write_if_missing "$RUN_DIR/Ework" "0.0"

link_file fort.18 Eext
link_file fort.20 rh.Si111-H
link_file fort.22 wf_fft.Si111-H
link_file fort.28 Etot
link_file fort.32 wf_fft.Si111-H
link_file fort.41 TR.Si93g_asci
link_file fort.42 TR.H99g_asc
link_file fort.46 TR.Si93e_asci
link_file fort.53 laser.dat
link_file fort.54 size.dat
link_file fort.55 sym.C1
link_file fort.60 Avec
link_file fort.62 Ework

echo "Prepared Si111-H run directory:"
echo "  $RUN_DIR"
echo
echo "Run order after building executables:"
echo "  cd $RUN_DIR"
echo "  ulimit -s unlimited"
echo "  export OMP_STACKSIZE=512M"
echo "  rm -f fort.23 fort.24 fort.90"
echo "  OMP_NUM_THREADS=1 $ROOT_DIR/FPSEID21/cg_GGA_f_code/cg_exe < Si111-H.in > Si111-H.out 2> Si111-H.err"
echo "  cp fort.24 rh.Si111-H_new"
echo "  cp fort.23 wf_fft.Si111-H_new"
echo "  cp fort.88 wf_real.Si111-H"
echo "  cp rh.Si111-H_new rh.Si111-H && cp wf_fft.Si111-H_new wf_fft.Si111-H"
echo "  rm -f fort.23 fort.24 fort.90"
echo "  OMP_NUM_THREADS=1 $ROOT_DIR/FPSEID21/sd_GGA_f_compact_code/sd_exe < Si111-H_sd.in > Si111-H_sd.out 2> Si111-H_sd.err"
echo "  cp fort.24 rh.Si111-H_new"
echo "  cp fort.23 wf_fft.Si111-H_new"
echo "  cp fort.88 wf_real.Si111-H"
echo "  cp rh.Si111-H_new rh.Si111-H && cp wf_fft.Si111-H_new wf_fft.Si111-H"
echo "  echo '0.0 0.0' > Eext && echo '0.0' > Etot"
echo "  echo '0.0 0.0 0.0' > Avec && echo '0.0' > Ework"
echo "  rm -f fort.23 fort.24 fort.90"
echo "  OMP_NUM_THREADS=1 mpirun -np 1 $ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe < Si111-H_tm.in_2steps > Si111-H_tm.out_2steps 2> Si111-H_tm.err"
echo
echo "Or run the prepared sample automatically:"
echo "  RUN_DIR=$RUN_DIR $ROOT_DIR/tools/run_si111_h_sample.sh"
