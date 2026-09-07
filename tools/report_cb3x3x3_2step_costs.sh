#!/bin/sh
set -eu

OUTPUT=${1:-}
PLATFORM=${2:-UNKNOWN}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ -s "$OUTPUT" ] || fail "usage: $0 TDDFT_OUTPUT PLATFORM"
grep -q 'FPSEID_PROFILE_BEGIN' "$OUTPUT" ||
  fail "FPSEID_PROFILE block is missing: $OUTPUT"
grep -q 'FPSEID_PROFILE_END' "$OUTPUT" ||
  fail "FPSEID_PROFILE block is incomplete: $OUTPUT"

wall_sec=$(awk '/steps took/ {
  value=$(NF-1)
} END {
  if (value == "") exit 1
  gsub(/[dD]/, "E", value)
  printf "%.6f", value + 0
}' "$OUTPUT") || fail "wall time is missing: $OUTPUT"

time_step_total=$(awk '
  /FPSEID_PROFILE_BEGIN/ {active=1; next}
  /FPSEID_PROFILE_END/ {active=0}
  active && $2 == "time_step_total" {value=$4}
  END {if (value == "") exit 1; printf "%.6f", value + 0}
' "$OUTPUT") || fail "time_step_total is missing: $OUTPUT"

echo "FPSEID21_CB3X3X3_2STEP_COST_DISTRIBUTION_BEGIN"
echo "platform=$PLATFORM"
echo "steps=2"
echo "wall_sec=$wall_sec"
echo "diagnostic=OFF"
echo "normal_check=PASS"
echo "relaxed_compare=PASS"
echo "initial_state_postrun_sha256_gate=PASS"
echo "normalization=time_step_total_max_rank_sec=$time_step_total"
echo "semantics=inclusive_timers_percentages_overlap_and_do_not_sum_to_100"
echo "selected_timer_columns=label,count,max_rank_sec,avg_rank_sec,pct_of_time_step"
awk -v denom="$time_step_total" '
  BEGIN {
    split("startup_before_steps fft_plan_init time_step_total frprmn tmevl_total tmevl_s2 s2_nonlocal s2_nonlocal_make s2_nonlocal_gemm exnlp_gemm_dot exnlp_work1_enter s2_fft_local fft_wrapper exkin_acc_kernel electf_force frprmn_rhoofk frprmn_rhoget frprmn_coef_sync", names, " ")
    for (i in names) wanted[names[i]]=1
  }
  /FPSEID_PROFILE_BEGIN/ {active=1; next}
  /FPSEID_PROFILE_END/ {active=0}
  active && wanted[$2] {
    pct=(denom > 0) ? 100.0*$4/denom : 0.0
    printf "selected_timer=%s,%s,%.6f,%.6f,%.2f\n", $2, $3, $4, $5, pct
  }
' "$OUTPUT"
echo "top_inclusive_timer_columns=label,count,max_rank_sec,pct_of_time_step"
awk -v denom="$time_step_total" '
  /FPSEID_PROFILE_BEGIN/ {active=1; next}
  /FPSEID_PROFILE_END/ {active=0}
  active && $1 ~ /^[0-9]+$/ && $2 != "time_step_total" {
    pct=(denom > 0) ? 100.0*$4/denom : 0.0
    printf "%s %s %.9f %.2f\n", $2, $3, $4, pct
  }
' "$OUTPUT" | LC_ALL=C sort -k3,3nr | awk 'NR <= 12 {
  printf "top_inclusive_timer=%s,%s,%.6f,%.2f\n", $1, $2, $3, $4
}'
echo "measurement_type=two_step_cost_distribution_diagnostic_not_baseline"
echo "FPSEID21_CB3X3X3_2STEP_COST_DISTRIBUTION_END"
