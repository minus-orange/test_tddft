#!/bin/sh
set -eu

# Check whether the Si111-H run directory has the fort.* unit files needed by
# each execution stage. This is useful on compilers such as NVHPC, where a
# missing implicit unit file is reported as a Fortran runtime error.
#
# Usage:
#   ./tools/check_si111_h_unit_files.sh cg
#   ./tools/check_si111_h_unit_files.sh sd
#   ./tools/check_si111_h_unit_files.sh tddft Si111-H_tm.in_100steps
#
# Defaults:
#   RUN_DIR=<repo>/run/Si111-H
#   TDDFT_INPUT=Si111-H_tm.in_2steps

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H"}
STAGE=${1:-cg}
TDDFT_INPUT=${2:-${TDDFT_INPUT:-Si111-H_tm.in_2steps}}
missing=0

check_file() {
  path=$1
  label=$2

  if [ -e "$RUN_DIR/$path" ]; then
    printf "OK      %-10s %s\n" "$path" "$label"
  else
    printf "MISSING %-10s %s\n" "$path" "$label"
    missing=1
  fi
}

check_numeric_records() {
  path=$1
  label=$2

  if [ ! -e "$RUN_DIR/$path" ]; then
    return
  fi

  if awk -v file="$path" -v label="$label" '
    function fail(message) {
      printf("BADFMT  %-10s %s (%s)\n", file, label, message)
      bad = 1
      exit
    }
    /^[[:space:]]*$/ { next }
    {
      record++
      gsub(/,/, " ")
      for (i = 1; i <= NF; i++) {
        if ($i !~ /[0-9]/ || $i ~ /[^0-9+.dDeE-]/) {
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
        printf("BADFMT  %-10s %s (file is too short)\n", file, label)
        exit 1
      }
    }
  ' "$RUN_DIR/$path"; then
    printf "OKFMT   %-10s %s\n" "$path" "$label"
  else
    missing=1
  fi
}

check_pseudopotentials() {
  check_numeric_records fort.41 "Si pseudopotential ground state"
  check_numeric_records fort.42 "H pseudopotential"
  check_numeric_records fort.46 "Si pseudopotential excited state"
}

check_common_units() {
  check_file fort.41 "Si pseudopotential: TR.Si93g_asci"
  check_file fort.42 "H pseudopotential: TR.H99g_asc"
  check_file fort.46 "Si pseudopotential: TR.Si93e_asci"
  check_file fort.54 "mesh and size metadata: size.dat"
  check_file fort.55 "symmetry metadata: sym.C1"
  check_pseudopotentials
}

check_cg() {
  check_file Si111-H.in "CG standard input"
  check_common_units
}

check_sd() {
  check_file Si111-H_sd.in "SD standard input"
  check_common_units
  check_file fort.20 "density from CG: rh.Si111-H"
  check_file fort.22 "reciprocal wavefunction from CG: wf_fft.Si111-H"
  check_file fort.88 "real-space wavefunction from CG: wf_real.Si111-H"
}

check_tddft() {
  check_file "$TDDFT_INPUT" "TDDFT standard input"
  check_common_units
  check_file fort.18 "external field state: Eext"
  check_file fort.20 "density from SD: rh.Si111-H"
  check_file fort.22 "wavefunction from SD: wf_fft.Si111-H"
  check_file fort.28 "previous total energy: Etot"
  check_file fort.32 "wavefunction alias: wf_fft.Si111-H"
  check_file fort.53 "laser pulse parameters: laser.dat"
  check_file fort.60 "previous vector potential: Avec"
  check_file fort.62 "work accumulator: Ework"
}

case "$STAGE" in
  cg)
    check_cg
    ;;
  sd)
    check_sd
    ;;
  tddft)
    check_tddft
    ;;
  all)
    echo "[CG]"
    check_cg
    echo
    echo "[SD]"
    check_sd
    echo
    echo "[TDDFT]"
    check_tddft
    ;;
  *)
    echo "ERROR: unknown stage: $STAGE" >&2
    echo "Usage: $0 {cg|sd|tddft|all} [TDDFT_INPUT]" >&2
    exit 2
    ;;
esac

if [ "$missing" -ne 0 ]; then
  echo
  echo "Some required files are missing or invalid in $RUN_DIR" >&2
  exit 1
fi

echo
echo "All required files are present in $RUN_DIR"
