#!/bin/sh
set -eu

# Run the prepared Si111-H sample in the required CG -> SD -> TDDFT order.
# CG/SD write new density and wavefunction files either with a *_new suffix or
# as raw fort.* unit files. This script promotes them before the next stage so
# fort.20 and fort.22 resolve.
#
# Defaults:
#   RUN_DIR=<repo>/run/Si111-H
#   TDDFT_INPUT=Si111-H_tm.in_2steps
#   NPROCS=1
#
# Example:
#   ./tools/prepare_si111_h_sample.sh
#   ./tools/run_si111_h_sample.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H"}
TDDFT_INPUT=${TDDFT_INPUT:-Si111-H_tm.in_2steps}
NPROCS=${NPROCS:-1}
OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
export OMP_NUM_THREADS

CG_EXE=${CG_EXE:-"$ROOT_DIR/FPSEID21/cg_GGA_f_code/cg_exe"}
SD_EXE=${SD_EXE:-"$ROOT_DIR/FPSEID21/sd_GGA_f_compact_code/sd_exe"}
TDDFT_EXE=${TDDFT_EXE:-"$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe"}
MPIRUN=${MPIRUN:-mpirun}

require_file() {
  path=$1
  if [ ! -e "$path" ]; then
    echo "ERROR: required file is missing: $path" >&2
    exit 1
  fi
}

promote_state() {
  stage=$1

  if [ -f fort.24 ]; then
    cp fort.24 rh.Si111-H_new
  fi
  if [ -f fort.88 ]; then
    cp fort.88 wf_fft.Si111-H_new
  fi
  if [ -f fort.23 ]; then
    cp fort.23 wf.Si111-H_new
  fi

  require_file rh.Si111-H_new
  cp rh.Si111-H_new rh.Si111-H

  if [ -f wf_fft.Si111-H_new ]; then
    cp wf_fft.Si111-H_new wf_fft.Si111-H
  elif [ -f wf_fft.Si111-H ]; then
    :
  else
    echo "ERROR: missing wavefunction after $stage: wf_fft.Si111-H_new" >&2
    exit 1
  fi
}

require_file "$RUN_DIR"
require_file "$CG_EXE"
require_file "$SD_EXE"
require_file "$TDDFT_EXE"

cd "$RUN_DIR"

ulimit -s unlimited 2>/dev/null || true
export OMP_STACKSIZE=${OMP_STACKSIZE:-512M}

echo "Running CG in $RUN_DIR"
"$CG_EXE" < Si111-H.in > Si111-H.out 2> Si111-H.err
promote_state CG

echo "Running SD in $RUN_DIR"
"$SD_EXE" < Si111-H_sd.in > Si111-H_sd.out 2> Si111-H_sd.err
promote_state SD
cp rh.Si111-H_new rh.Si111-H_new.sd

echo "Running TDDFT in $RUN_DIR with $TDDFT_INPUT"
"$MPIRUN" -np "$NPROCS" "$TDDFT_EXE" < "$TDDFT_INPUT" > Si111-H_tm.out 2> Si111-H_tm.err

echo "Done. Logs:"
echo "  $RUN_DIR/Si111-H.out"
echo "  $RUN_DIR/Si111-H_sd.out"
echo "  $RUN_DIR/Si111-H_tm.out"
