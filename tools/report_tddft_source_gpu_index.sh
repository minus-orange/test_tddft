#!/bin/sh
set -eu

# Reproducible source-level OpenACC compute-site coverage index.
# The denominator is the 19 compute constructs in accepted Step 80 source.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

DENOMINATOR=19
FILES="
FPSEID21/tddft_2022October/fft_cufft.f
FPSEID21/tddft_2022October/frprmn_tm12_check_Vext_Avec_v4.f
FPSEID21/tddft_2022October/lib4_ASL_2_check_Vext_SXACE.f
FPSEID21/tddft_2022October/tmevl10_Avec_v4.f
FPSEID21/tddft_2022October/vpj_gen.f
"

printf '%-6s %-9s %8s %10s\n' step commit sites index_pct
printf '%s\n' \
  '21 bad046f' \
  '22 1b98197' \
  '23 f911621' \
  '24 b3559f1' \
  '25 825697a' \
  '28 c3552af' \
  '33 b2a43c9' \
  '34 83a030c' \
  '36 24e1cc3' \
  '37 9cbb6bc' \
  '41 4aaa33c' \
  '52 22aad92' \
  '57 8646707' \
  '62 7475ccb' \
  '67 39a181e' \
  '74 3687243' \
  '80 59686f0' |
while read -r step commit
do
  count=$(
    git grep -E -i \
      '^.{0,6}(!|c)?\$acc[[:space:]]+(parallel|kernels)' \
      "$commit" -- $FILES |
      wc -l |
      tr -d ' '
  )
  percentage=$(awk -v count="$count" -v total="$DENOMINATOR" \
    'BEGIN { printf "%.1f", 100.0 * count / total }')
  printf '%-6s %-9s %8s %9s%%\n' "$step" "$commit" "$count" "$percentage"
done
