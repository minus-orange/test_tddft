#!/bin/sh
set -eu

# Compare two Si111-H TDDFT run directories before comparing TDDFT output logs.
# This catches common false-comparison causes: different control files, density,
# wavefunction, or fort.* links.
#
# Usage:
#   ./tools/compare_tddft_run_inputs.sh REF_RUN_DIR TEST_RUN_DIR
#   TDDFT_INPUT=Si111-H_tm.in_100steps ./tools/compare_tddft_run_inputs.sh ref test

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 REF_RUN_DIR TEST_RUN_DIR" >&2
  exit 2
fi

REF_DIR=$1
TEST_DIR=$2
TDDFT_INPUT=${TDDFT_INPUT:-Si111-H_tm.in_100steps}
failed=0

require_dir() {
  dir=$1
  label=$2
  if [ ! -d "$dir" ]; then
    echo "ERROR: missing $label directory: $dir" >&2
    exit 1
  fi
}

mark_fail() {
  failed=1
}

file_size() {
  path=$1
  wc -c < "$path" | awk '{print $1}'
}

file_sha256() {
  path=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    echo "sha256-unavailable"
  fi
}

print_file_info() {
  path=$1
  if [ -L "$path" ]; then
    printf "link->%s" "$(readlink "$path")"
  elif [ -f "$path" ]; then
    printf "size=%s sha256=%s" "$(file_size "$path")" "$(file_sha256 "$path")"
  elif [ -e "$path" ]; then
    printf "exists-non-file"
  else
    printf "missing"
  fi
}

compare_path() {
  rel=$1
  label=$2
  ref=$REF_DIR/$rel
  test=$TEST_DIR/$rel

  if [ ! -e "$ref" ] && [ ! -e "$test" ]; then
    printf "MISSING BOTH %-24s %s\n" "$rel" "$label"
    return
  fi
  if [ ! -e "$ref" ]; then
    printf "MISSING REF  %-24s %s\n" "$rel" "$label"
    printf "  test: "
    print_file_info "$test"
    printf "\n"
    mark_fail
    return
  fi
  if [ ! -e "$test" ]; then
    printf "MISSING TEST %-24s %s\n" "$rel" "$label"
    printf "  ref:  "
    print_file_info "$ref"
    printf "\n"
    mark_fail
    return
  fi

  if [ -L "$ref" ] || [ -L "$test" ]; then
    ref_target=$(readlink "$ref" 2>/dev/null || echo "")
    test_target=$(readlink "$test" 2>/dev/null || echo "")
    if [ "$ref_target" = "$test_target" ]; then
      printf "OKLINK       %-24s %s -> %s\n" "$rel" "$label" "$ref_target"
    else
      printf "DIFFLINK     %-24s %s\n" "$rel" "$label"
      printf "  ref:  %s\n" "$ref_target"
      printf "  test: %s\n" "$test_target"
      mark_fail
    fi
    return
  fi

  if cmp -s "$ref" "$test"; then
    printf "OK           %-24s %s\n" "$rel" "$label"
  else
    printf "DIFF         %-24s %s\n" "$rel" "$label"
    printf "  ref:  "
    print_file_info "$ref"
    printf "\n"
    printf "  test: "
    print_file_info "$test"
    printf "\n"
    mark_fail
  fi
}

require_dir "$REF_DIR" reference
require_dir "$TEST_DIR" test

echo "TDDFT input-state comparison"
echo "  reference: $REF_DIR"
echo "  test:      $TEST_DIR"
echo "  TDDFT input: $TDDFT_INPUT"
echo

compare_path "$TDDFT_INPUT" "TDDFT standard input"
compare_path size.dat "mesh and size metadata"
compare_path sym.C1 "symmetry metadata"
compare_path laser.dat "laser pulse parameters"
compare_path Eext "external field state"
compare_path Etot "previous total energy"
compare_path Avec "previous vector potential"
compare_path Ework "work accumulator"
compare_path rh.Si111-H "density input"
compare_path wf_fft.Si111-H "wavefunction input"
compare_path TR.Si93g_asci "Si pseudopotential ground state"
compare_path TR.H99g_asc "H pseudopotential"
compare_path TR.Si93e_asci "Si pseudopotential excited state"

echo
echo "Fortran unit links/files"
compare_path fort.18 "Eext unit"
compare_path fort.20 "density unit"
compare_path fort.22 "wavefunction unit"
compare_path fort.28 "Etot unit"
compare_path fort.32 "wavefunction alias unit"
compare_path fort.41 "Si pseudopotential ground unit"
compare_path fort.42 "H pseudopotential unit"
compare_path fort.46 "Si pseudopotential excited unit"
compare_path fort.53 "laser unit"
compare_path fort.54 "size unit"
compare_path fort.55 "symmetry unit"
compare_path fort.60 "Avec unit"
compare_path fort.62 "Ework unit"

echo
if [ "$failed" -ne 0 ]; then
  echo "FAIL: TDDFT input states differ."
  exit 1
fi

echo "PASS: TDDFT input states match."
