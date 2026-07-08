#!/bin/sh
set -eu

# Compare two Si111-H CG run directories before comparing CG output logs.
# This catches false-comparison causes such as different CG input files,
# pseudopotentials, mesh/symmetry metadata, or fort.* links.
#
# Usage:
#   ./tools/compare_cg_run_inputs.sh REF_RUN_DIR TEST_RUN_DIR

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 REF_RUN_DIR TEST_RUN_DIR" >&2
  exit 2
fi

REF_DIR=$1
TEST_DIR=$2
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

text_equal_ignore_cr() {
  ref=$1
  test=$2
  awk '{ sub(/\r$/, ""); print }' "$ref" > "${TMPDIR:-/tmp}/fpseid_ref_text_$$"
  awk '{ sub(/\r$/, ""); print }' "$test" > "${TMPDIR:-/tmp}/fpseid_test_text_$$"
  if cmp -s "${TMPDIR:-/tmp}/fpseid_ref_text_$$" "${TMPDIR:-/tmp}/fpseid_test_text_$$"; then
    rm -f "${TMPDIR:-/tmp}/fpseid_ref_text_$$" "${TMPDIR:-/tmp}/fpseid_test_text_$$"
    return 0
  fi
  rm -f "${TMPDIR:-/tmp}/fpseid_ref_text_$$" "${TMPDIR:-/tmp}/fpseid_test_text_$$"
  return 1
}

compare_path() {
  rel=$1
  label=$2
  ref=$REF_DIR/$rel
  test=$TEST_DIR/$rel

  if [ ! -e "$ref" ] && [ ! -e "$test" ]; then
    printf "MISSING BOTH %-20s %s\n" "$rel" "$label"
    return
  fi
  if [ ! -e "$ref" ]; then
    printf "MISSING REF  %-20s %s\n" "$rel" "$label"
    printf "  test: "
    print_file_info "$test"
    printf "\n"
    mark_fail
    return
  fi
  if [ ! -e "$test" ]; then
    printf "MISSING TEST %-20s %s\n" "$rel" "$label"
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
      printf "OKLINK       %-20s %s -> %s\n" "$rel" "$label" "$ref_target"
    else
      printf "DIFFLINK     %-20s %s\n" "$rel" "$label"
      printf "  ref:  %s\n" "$ref_target"
      printf "  test: %s\n" "$test_target"
      mark_fail
    fi
    return
  fi

  if cmp -s "$ref" "$test"; then
    printf "OK           %-20s %s\n" "$rel" "$label"
  elif text_equal_ignore_cr "$ref" "$test"; then
    printf "OKTEXT       %-20s %s (differs only by CRLF/LF)\n" "$rel" "$label"
  else
    printf "DIFF         %-20s %s\n" "$rel" "$label"
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

echo "CG input-state comparison"
echo "  reference: $REF_DIR"
echo "  test:      $TEST_DIR"
echo

compare_path Si111-H.in "CG standard input"
compare_path size.dat "mesh and size metadata"
compare_path sym.C1 "symmetry metadata"
compare_path TR.Si93g_asci "Si pseudopotential ground state"
compare_path TR.H99g_asc "H pseudopotential"
compare_path TR.Si93e_asci "Si pseudopotential excited state"

echo
echo "Fortran unit links/files"
compare_path fort.41 "Si pseudopotential ground unit"
compare_path fort.42 "H pseudopotential unit"
compare_path fort.46 "Si pseudopotential excited unit"
compare_path fort.54 "size unit"
compare_path fort.55 "symmetry unit"

echo
if [ "$failed" -ne 0 ]; then
  echo "FAIL: CG input states differ."
  exit 1
fi

echo "PASS: CG input states match."
