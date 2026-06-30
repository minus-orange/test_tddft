#!/bin/sh
set -eu

# Run the prepared Si111-H sample in the required CG -> SD -> TDDFT order.
# CG/SD write new density and wavefunction files either with a *_new suffix or
# as raw fort.* unit files. This script promotes them before the next stage so
# fort.20 and fort.22 resolve. Unit 23 is the reciprocal-space wavefunction for
# TDDFT, while unit 88 is a real-space intermediate read by SD.
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
  label=${2:-}
  if [ ! -e "$path" ]; then
    if [ -n "$label" ]; then
      echo "ERROR: required file is missing for $label: $path" >&2
    else
      echo "ERROR: required file is missing: $path" >&2
    fi
    exit 1
  fi
}

require_stage_files() {
  stage=$1
  shift
  for path in "$@"; do
    require_file "$path" "$stage"
  done
}

require_numeric_records() {
  path=$1
  label=$2

  awk -v file="$path" -v label="$label" '
    function fail(message) {
      printf("ERROR: %s is not a valid numeric text file for %s: %s\n",
             file, label, message) > "/dev/stderr"
      bad = 1
      exit
    }
    /^[[:space:]]*$/ { next }
    {
      record++
      gsub(/,/, " ")
      for (i = 1; i <= NF; i++) {
        token = $i
        gsub(/[0-9+.dDeE-]/, "", token)
        if ($i !~ /[0-9]/ || token != "") {
          fail("record " record " has non-numeric token " $i)
        }
      }
      if (record >= 3) {
        checked = 1
        exit
      }
    }
    END {
      if (bad) {
        exit 1
      }
      if (!checked) {
        printf("ERROR: %s is too short for %s\n", file, label) > "/dev/stderr"
        exit 1
      }
    }
  ' "$path"
}

require_pseudopotentials() {
  require_numeric_records fort.41 "Si pseudopotential ground state"
  require_numeric_records fort.42 "H pseudopotential"
  require_numeric_records fort.46 "Si pseudopotential excited state"
}

link_if_present() {
  link=$1
  target=$2
  if [ ! -e "$link" ] && [ -e "$target" ]; then
    ln -sf "$target" "$link"
  fi
}

ensure_sample_links() {
  link_if_present fort.18 Eext
  link_if_present fort.20 rh.Si111-H
  link_if_present fort.22 wf_fft.Si111-H
  link_if_present fort.28 Etot
  link_if_present fort.32 wf_fft.Si111-H
  link_if_present fort.41 TR.Si93g_asci
  link_if_present fort.42 TR.H99g_asc
  link_if_present fort.46 TR.Si93e_asci
  link_if_present fort.53 laser.dat
  link_if_present fort.54 size.dat
  link_if_present fort.55 sym.C1
  link_if_present fort.60 Avec
  link_if_present fort.62 Ework
}

ensure_sd_links() {
  link_if_present fort.88 wf_real.Si111-H
}

require_cg_inputs() {
  require_stage_files CG \
    Si111-H.in \
    fort.41 fort.42 fort.46 \
    fort.54 fort.55
  require_pseudopotentials
}

require_sd_inputs() {
  require_stage_files SD \
    Si111-H_sd.in \
    fort.20 fort.22 fort.88 \
    fort.41 fort.42 fort.46 \
    fort.54 fort.55
  require_pseudopotentials
}

require_tddft_inputs() {
  require_stage_files TDDFT \
    "$TDDFT_INPUT" \
    fort.18 fort.20 fort.22 fort.28 fort.32 \
    fort.41 fort.42 fort.46 \
    fort.53 fort.54 fort.55 fort.60 fort.62
  require_pseudopotentials
}

promote_state() {
  stage=$1

  if [ -f fort.24 ]; then
    cp fort.24 rh.Si111-H_new
  fi
  if [ -f fort.23 ]; then
    cp fort.23 wf_fft.Si111-H_new
  fi
  if [ -f fort.88 ]; then
    cp fort.88 wf_real.Si111-H
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

prepare_tddft_control_files() {
  printf "0.0 0.0\n" > Eext
  printf "0.0\n" > Etot
  printf "0.0 0.0 0.0\n" > Avec
  printf "0.0\n" > Ework
}

clear_stage_outputs() {
  rm -f fort.23 fort.24 fort.90
}

require_file "$RUN_DIR"
require_file "$CG_EXE"
require_file "$SD_EXE"
require_file "$TDDFT_EXE"

cd "$RUN_DIR"

ulimit -s unlimited 2>/dev/null || true
export OMP_STACKSIZE=${OMP_STACKSIZE:-512M}

ensure_sample_links
require_cg_inputs

echo "Running CG in $RUN_DIR"
clear_stage_outputs
"$CG_EXE" < Si111-H.in > Si111-H.out 2> Si111-H.err
promote_state CG

echo "Running SD in $RUN_DIR"
ensure_sample_links
ensure_sd_links
require_sd_inputs
clear_stage_outputs
"$SD_EXE" < Si111-H_sd.in > Si111-H_sd.out 2> Si111-H_sd.err
promote_state SD
cp rh.Si111-H_new rh.Si111-H_new.sd

prepare_tddft_control_files
ensure_sample_links
require_tddft_inputs

echo "Running TDDFT in $RUN_DIR with $TDDFT_INPUT"
clear_stage_outputs
"$MPIRUN" -np "$NPROCS" "$TDDFT_EXE" < "$TDDFT_INPUT" > Si111-H_tm.out 2> Si111-H_tm.err

echo "Done. Logs:"
echo "  $RUN_DIR/Si111-H.out"
echo "  $RUN_DIR/Si111-H_sd.out"
echo "  $RUN_DIR/Si111-H_tm.out"
