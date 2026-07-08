#!/bin/sh
set -eu

# Sanity-check one FPSEID21 CG run. This checks the CG stdout/stderr and the
# density/wavefunction files that the next SD stage consumes.
#
# Usage:
#   ./tools/check_cg_result.sh
#   RUN_DIR=/path/to/run ./tools/check_cg_result.sh
#   ./tools/check_cg_result.sh /path/to/Si111-H.out /path/to/Si111-H.err

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H"}

OUT=${1:-"$RUN_DIR/Si111-H.out"}
ERR=${2:-"$RUN_DIR/Si111-H.err"}
fail=0

ok() {
  printf "OK      %s\n" "$1"
}

bad() {
  printf "FAIL    %s\n" "$1"
  fail=1
}

warn() {
  printf "WARN    %s\n" "$1"
}

check_file_nonempty() {
  path=$1
  label=$2
  if [ -s "$path" ]; then
    ok "$label: $path"
  else
    bad "$label missing or empty: $path"
  fi
}

check_optional_output_file() {
  path=$1
  label=$2
  if [ -s "$RUN_DIR/$path" ]; then
    ok "$label: $path"
  else
    warn "$label not found: $path"
  fi
}

if [ ! -f "$OUT" ]; then
  bad "CG stdout not found: $OUT"
else
  ok "CG stdout found: $OUT"
fi

if [ -f "$ERR" ] && [ -s "$ERR" ]; then
  if grep -Eiq '(^|[^A-Z])(error|fatal|segmentation|sigsegv|traceback|cannot|failed|invalid|badfmt)' "$ERR"; then
    bad "CG stderr contains error-like text: $ERR"
  elif awk '
    /^[[:space:]]*$/ { next }
    /Warning: ieee_inexact is signaling/ { next }
    /^FORTRAN STOP$/ { next }
    { unexpected = 1 }
    END { exit unexpected ? 1 : 0 }
  ' "$ERR"; then
    ok "CG stderr contains only known benign NVHPC termination messages"
  else
    warn "CG stderr is not empty: $ERR"
  fi
else
  ok "CG stderr is empty or absent"
fi

if [ -f "$OUT" ]; then
  if grep -q 'CPU TIME END OF PSPW' "$OUT"; then
    ok "CG completed PSPW section"
  else
    bad "missing completion marker: CPU TIME END OF PSPW"
  fi

  if grep -q 'TOTAL ENERGY: ETOT' "$OUT"; then
    etot=$(awk '/TOTAL ENERGY: ETOT/ {print $(NF-1); exit}' "$OUT")
    printf "INFO    ETOT(HR)=%s\n" "$etot"
  else
    bad "missing total energy line"
  fi

  force_count=$(awk '
    /TOTAL FORCE:/ {in_force=1; next}
    in_force && NF == 4 && $1 ~ /^[0-9]+$/ {count++; next}
    in_force && count > 0 && NF != 4 {exit}
    END {print count + 0}
  ' "$OUT")
  if [ "$force_count" -gt 0 ]; then
    ok "force lines found: $force_count atoms"
  else
    bad "missing total force block"
  fi

  if grep -Eiq 'NaN|Infinity|SIGSEGV|segmentation|fatal|traceback|cannot|failed|invalid|BADFMT' "$OUT"; then
    bad "CG stdout contains suspicious text"
  else
    ok "CG stdout has no obvious error markers"
  fi
fi

check_optional_output_file fort.24 "new density unit"
check_optional_output_file fort.23 "new reciprocal wavefunction unit"
check_optional_output_file fort.88 "real-space wavefunction unit"
check_optional_output_file rh.Si111-H_new "promoted density candidate"
check_optional_output_file wf_fft.Si111-H_new "promoted wavefunction candidate"

if [ -s "$RUN_DIR/fort.24" ] || [ -s "$RUN_DIR/rh.Si111-H_new" ]; then
  ok "density output is available for SD promotion"
else
  bad "density output is missing: expected fort.24 or rh.Si111-H_new"
fi

if [ -s "$RUN_DIR/fort.23" ] || [ -s "$RUN_DIR/wf_fft.Si111-H_new" ]; then
  ok "wavefunction output is available for SD promotion"
else
  bad "wavefunction output is missing: expected fort.23 or wf_fft.Si111-H_new"
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "CG result check: FAIL"
  exit 1
fi

echo
echo "CG result check: PASS"
