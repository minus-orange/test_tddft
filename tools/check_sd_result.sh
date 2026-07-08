#!/bin/sh
set -eu

# Sanity-check one FPSEID21 SD run. This checks the SD stdout/stderr and the
# density/wavefunction files that the TDDFT stage consumes.
#
# Usage:
#   ./tools/check_sd_result.sh
#   RUN_DIR=/path/to/run ./tools/check_sd_result.sh
#   ./tools/check_sd_result.sh /path/to/run
#   ./tools/check_sd_result.sh /path/to/Si111-H_sd.out /path/to/Si111-H_sd.err

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_sd"}

if [ "${1:-}" ] && [ -d "${1:-}" ]; then
  RUN_DIR=$1
  OUT=$RUN_DIR/Si111-H_sd.out
  ERR=$RUN_DIR/Si111-H_sd.err
else
  OUT=${1:-"$RUN_DIR/Si111-H_sd.out"}
  ERR=${2:-"$RUN_DIR/Si111-H_sd.err"}
  RUN_DIR=$(CDPATH= cd -- "$(dirname -- "$OUT")" 2>/dev/null && pwd || printf '%s\n' "$RUN_DIR")
fi

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

info() {
  printf "INFO    %s\n" "$1"
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
  bad "SD stdout not found: $OUT"
else
  ok "SD stdout found: $OUT"
fi

if [ -f "$ERR" ] && [ -s "$ERR" ]; then
  if grep -Eiq '(^|[^A-Z])(error|fatal|segmentation|sigsegv|traceback|cannot|failed|invalid|badfmt)' "$ERR"; then
    bad "SD stderr contains error-like text: $ERR"
  elif awk '
    /^[[:space:]]*$/ { next }
    /IEEE_UNDERFLOW_FLAG/ { next }
    /IEEE_INEXACT/ { next }
    /ieee_inexact is signaling/ { next }
    /^FORTRAN STOP$/ { next }
    /^Note: The following floating-point exceptions are signalling:/ { next }
    { unexpected = 1 }
    END { exit unexpected ? 1 : 0 }
  ' "$ERR"; then
    ok "SD stderr contains only known benign floating-point/termination messages"
  else
    warn "SD stderr is not empty: $ERR"
  fi
else
  ok "SD stderr is empty or absent"
fi

if [ -f "$OUT" ]; then
  if grep -q 'CPU TIME END OF PSPW' "$OUT"; then
    ok "SD completed PSPW section"
  else
    bad "missing completion marker: CPU TIME END OF PSPW"
  fi

  if grep -q 'Local SCF potential has been stored' "$OUT"; then
    ok "local SCF potential was stored"
  else
    warn "local SCF potential store marker not found"
  fi

  if grep -q 'TOTAL ENERGY: ETOT' "$OUT"; then
    etot=$(awk '/TOTAL ENERGY: ETOT/ {print $(NF-1); exit}' "$OUT")
    info "ETOT(HR)=$etot"
  else
    bad "missing total energy line"
  fi

  conv_count=$(awk '/CONVERGENCE OF THE POTENTIAL IS/ {count++} END {print count + 0}' "$OUT")
  if [ "$conv_count" -gt 0 ]; then
    last_conv=$(awk '/CONVERGENCE OF THE POTENTIAL IS/ {value=$NF} END {print value}' "$OUT")
    ok "SCF convergence lines found: $conv_count"
    info "last_potential_convergence=$last_conv"
  else
    bad "missing SCF convergence lines"
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

  band_count=$(awk '/BAND \(EV\)/ {count++} END {print count + 0}' "$OUT")
  if [ "$band_count" -gt 0 ]; then
    ok "band energy lines found: $band_count"
  else
    warn "band energy lines not found"
  fi

  if grep -Eiq 'NaN|Infinity|SIGSEGV|segmentation|fatal|traceback|cannot|failed|invalid|BADFMT|FIO-F-[0-9]+' "$OUT"; then
    bad "SD stdout contains suspicious text"
  else
    ok "SD stdout has no obvious error markers"
  fi
fi

check_optional_output_file fort.24 "new density unit"
check_optional_output_file fort.23 "new reciprocal wavefunction unit"
check_optional_output_file fort.88 "real-space wavefunction unit"
check_optional_output_file rh.Si111-H_new "promoted density candidate"
check_optional_output_file wf_fft.Si111-H_new "promoted wavefunction candidate"

if [ -s "$RUN_DIR/fort.24" ] || [ -s "$RUN_DIR/rh.Si111-H_new" ]; then
  ok "density output is available for TDDFT promotion"
else
  bad "density output is missing: expected fort.24 or rh.Si111-H_new"
fi

if [ -s "$RUN_DIR/fort.23" ] || [ -s "$RUN_DIR/wf_fft.Si111-H_new" ]; then
  ok "wavefunction output is available for TDDFT promotion"
else
  bad "wavefunction output is missing: expected fort.23 or wf_fft.Si111-H_new"
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "SD result check: FAIL"
  exit 1
fi

echo
echo "SD result check: PASS"
