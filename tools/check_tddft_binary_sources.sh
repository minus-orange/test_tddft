#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
EXE=${1:-"$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe"}

if [ ! -x "$EXE" ]; then
  echo "ERROR: executable not found or not executable: $EXE" >&2
  exit 1
fi

echo "TDDFT executable: $EXE"
echo

if command -v strings >/dev/null 2>&1; then
  found=0
  echo "Embedded source-name check:"
  for name in \
    tm_inputs_gnu.f \
    pspw_tm11_Vext_Avec_v4_alloc_gnu.f \
    tm_inputs.f \
    pspw_tm11_Vext_Avec_v4_alloc.f
  do
    if strings "$EXE" | grep -F "$name" >/dev/null 2>&1; then
      printf "  FOUND     %s\n" "$name"
      found=1
    else
      printf "  not found %s\n" "$name"
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "  No source names found. The compiler may not embed them."
  fi
else
  echo "WARNING: strings command not found; skipping embedded source-name check."
fi

echo
echo "Expected for NVHPC/GNU TDDFT builds:"
echo "  FOUND     tm_inputs_gnu.f"
echo "  FOUND     pspw_tm11_Vext_Avec_v4_alloc_gnu.f"
