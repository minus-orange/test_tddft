#!/bin/sh
set -eu

# Read-only preflight for the official 2026-08-08 diamond cb3x3x3 package.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
OFFICIAL_DIR=$BENCHMARK_ROOT/official
WORK_ROOT=$BENCHMARK_ROOT/work

PACKAGE_SHA256=793a7754a416c83f00f563a7de3ce49d570f6830db89388d2e3b7b808c2612f9
PSEUDO_SHA256=bc743cb0f8829a2b07c68e1a33ce9a4c44c8cf75cc6503da3707fc9db90a5244

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

check_sha() {
  path=$1
  expected=$2
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$path" | awk '{print $1}')
  else
    actual=$(shasum -a 256 "$path" | awk '{print $1}')
  fi
  [ "$actual" = "$expected" ] || fail "SHA-256 mismatch: $path"
}

require_file "$BENCHMARK_ROOT/downloads/benchmark-cb3x3x3.zip"
require_file "$OFFICIAL_DIR/SOURCE_MANIFEST.env"
require_file "$OFFICIAL_DIR/TR/TR.C95g_asci"
require_file "$OFFICIAL_DIR/600K/dia-cb3x3x3_tm.out_AOBA-S"
require_file "$WORK_ROOT/cg/dia-cb3x3x3.in"
require_file "$WORK_ROOT/sd/dia-cb3x3x3_sd.in"
require_file "$WORK_ROOT/tddft_600K/dia-cb3x3x3_tm.in_2steps"
require_file "$WORK_ROOT/tddft_600K/dia-cb3x3x3_tm.in_1000steps"
require_file "$WORK_ROOT/tddft_600K/dia-cb3x3x3_tm.in_40000steps"
require_file "$WORK_ROOT/tddft_600K/SOURCE_MANIFEST.env"

check_sha "$BENCHMARK_ROOT/downloads/benchmark-cb3x3x3.zip" "$PACKAGE_SHA256"
check_sha "$OFFICIAL_DIR/TR/TR.C95g_asci" "$PSEUDO_SHA256"

python3 "$SCRIPT_DIR/check_tddft_result.py" check \
  "$OFFICIAL_DIR/600K/dia-cb3x3x3_tm.out_AOBA-S" \
  --expected-steps 40000 --no-require-profile >/dev/null

for pair in '2 2' '1000 1000' '40000 40000'; do
  set -- $pair
  file=$WORK_ROOT/tddft_600K/dia-cb3x3x3_tm.in_${1}steps
  grep -Eq "tstep=${2}([[:space:]]|$)" "$file" || \
    fail "wrong tstep in $file"
done

state=NOT_READY
state_dir=$WORK_ROOT/tddft_600K
if [ -e "$state_dir/rh.dia-cb3x3x3" ] || \
   [ -e "$state_dir/wf_fft.dia-cb3x3x3" ] || \
   [ -e "$state_dir/STATE_MANIFEST.sha256" ]; then
  state=INCOMPLETE
  if [ -s "$state_dir/rh.dia-cb3x3x3" ] && \
     [ -s "$state_dir/wf_fft.dia-cb3x3x3" ] && \
     [ -s "$state_dir/STATE_MANIFEST.sha256" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      (cd "$state_dir" && sha256sum -c STATE_MANIFEST.sha256 >/dev/null) || \
        fail "TDDFT initial-state SHA-256 validation failed"
    else
      (cd "$state_dir" && shasum -a 256 -c STATE_MANIFEST.sha256 >/dev/null) || \
        fail "TDDFT initial-state SHA-256 validation failed"
    fi
    state=READY
  fi
fi

echo "CB3X3X3_BENCHMARK_PREFLIGHT"
echo "official_update=2026-08-08"
echo "package_sha256=$PACKAGE_SHA256"
echo "case=diamond_cb3x3x3"
echo "atoms=216"
echo "mesh=105x105x105"
echo "occupied_bands=432"
echo "tddft_empty_bands=48"
echo "tddft_total_bands=480"
echo "official_steps=40000"
echo "official_reference_check=PASS"
echo "tddft_initial_state=$state"
echo "archive_root=$BENCHMARK_ROOT/archives"

if [ "$state" != READY ]; then
  echo "next_gate=CG_AND_SD_INITIAL_STATE_REQUIRED"
fi
