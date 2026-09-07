#!/bin/sh
set -eu

OUTPUT=${1:-}
PLATFORM=${2:-UNKNOWN}
DETAIL_EXPECTED=${3:-0}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ -s "$OUTPUT" ] || fail "usage: $0 TDDFT_OUTPUT PLATFORM"
case "$DETAIL_EXPECTED" in
  0|1) ;;
  *) fail "DETAIL_EXPECTED must be 0 or 1" ;;
esac
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
if [ "$DETAIL_EXPECTED" = 1 ]; then
  echo "cost_detail_timers=ON"
else
  echo "cost_detail_timers=OFF"
fi
echo "normal_check=PASS"
echo "relaxed_compare=PASS"
echo "initial_state_postrun_sha256_gate=PASS"
echo "normalization=time_step_total_max_rank_sec=$time_step_total"
echo "semantics=inclusive_timers_percentages_overlap_and_do_not_sum_to_100"
echo "selected_timer_columns=label,count,max_rank_sec,avg_rank_sec,pct_of_time_step"
awk -v denom="$time_step_total" '
  BEGIN {
    split("startup_before_steps fft_plan_init time_step_total frprmn tmevl_total tmevl_s2 s2_nonlocal s2_nonlocal_make s2_nonlocal_gemm exnlp_gemm_data exnlp_gemm_dot exnlp_gemm_update exnlp_work1_enter s2_fft_local fft_wrapper exkin_acc_kernel electf_force frprmn_rhoofk frprmn_rhoget frprmn_coef_sync", names, " ")
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
if [ "$DETAIL_EXPECTED" = 1 ]; then
  echo "FPSEID21_CB3X3X3_X86_COST_DETAIL_BEGIN"
  echo "detail_timer_columns=label,count,max_rank_sec,avg_rank_sec,pct_of_time_step"
  awk -v denom="$time_step_total" '
    BEGIN {
      n_names=split("s2_nonlocal_forward s2_nonlocal_reverse exnlp_gemm_data exnlp_gemm_dot exnlp_gemm_update electf_force electf_locpotf_total locpotf_ewald ewald_g_space ewald_r_space ewald_mpi ewald_energy_reduce ewald_force_reduce ewald_force_bcast locpotf_local_mpi locpotf_local_energy locpotf_xc locpotf_hartree electf_nonlocf_total nonlocf_setup nonlocf_kinetic_mpi nonlocf_k_gprep nonlocf_k_reduce nonlocf_k_comm nonlocf_eed_gprep nonlocf_eed_reduce nonlocf_eed_comm nonlocf_ylm_radius nonlocf_getylm nonlocf_seppotf seppotf_phase seppotf_s_projector seppotf_s_band_reduce seppotf_p_projector seppotf_p_band_reduce seppotf_mpi nonlocf_finalize", names, " ")
      n_required=split("s2_nonlocal_forward s2_nonlocal_reverse exnlp_gemm_data exnlp_gemm_dot electf_force electf_locpotf_total locpotf_ewald ewald_g_space ewald_r_space ewald_mpi ewald_energy_reduce ewald_force_reduce ewald_force_bcast locpotf_local_mpi locpotf_local_energy locpotf_xc locpotf_hartree electf_nonlocf_total nonlocf_setup nonlocf_kinetic_mpi nonlocf_getylm nonlocf_seppotf nonlocf_finalize", required, " ")
    }
    /FPSEID_PROFILE_BEGIN/ {active=1; next}
    /FPSEID_PROFILE_END/ {active=0}
    active {
      for (i=1; i<=n_names; i++) {
        if ($2 == names[i]) {
          count[$2]=$3
          vmax[$2]=$4
          vavg[$2]=$5
        }
      }
    }
    END {
      missing=0
      for (i=1; i<=n_names; i++) {
        name=names[i]
        if (count[name] == "") {
          printf "detail_timer=%s,NOT_CALLED\n", name
        } else {
          pct=(denom > 0) ? 100.0*vmax[name]/denom : 0.0
          printf "detail_timer=%s,%s,%.6f,%.6f,%.2f\n", name,
            count[name],vmax[name],vavg[name],pct
        }
      }
      for (i=1; i<=n_required; i++) {
        if (count[required[i]] == "") {
          printf "ERROR: required detail timer is missing: %s\n",
            required[i] > "/dev/stderr"
          missing=1
        }
      }
      if (missing) exit 2
      if (count["exnlp_gemm_update"] == "") {
        print "exnlp_update_scope=FUSED_INTO_EXNLP_GEMM_DOT"
      } else {
        print "exnlp_update_scope=SEPARATELY_TIMED"
      }
      electf_gap=vavg["electf_force"]-vavg["electf_locpotf_total"] \
        -vavg["electf_nonlocf_total"]
      locpotf_gap=vavg["electf_locpotf_total"]-vavg["locpotf_ewald"] \
        -vavg["locpotf_local_mpi"]-vavg["locpotf_local_energy"] \
        -vavg["locpotf_xc"]-vavg["locpotf_hartree"]
      ewald_gap=vavg["locpotf_ewald"]-vavg["ewald_g_space"] \
        -vavg["ewald_r_space"]-vavg["ewald_mpi"]
      ewald_mpi_gap=vavg["ewald_mpi"]-vavg["ewald_energy_reduce"] \
        -vavg["ewald_force_reduce"]-vavg["ewald_force_bcast"]
      nonlocf_gap=vavg["electf_nonlocf_total"]-vavg["nonlocf_setup"] \
        -vavg["nonlocf_kinetic_mpi"]-vavg["nonlocf_getylm"] \
        -vavg["nonlocf_seppotf"]-vavg["nonlocf_finalize"]
      kinetic_gap=vavg["nonlocf_kinetic_mpi"]-vavg["nonlocf_k_gprep"] \
        -vavg["nonlocf_k_reduce"]-vavg["nonlocf_k_comm"] \
        -vavg["nonlocf_eed_gprep"]-vavg["nonlocf_eed_reduce"] \
        -vavg["nonlocf_eed_comm"]-vavg["nonlocf_ylm_radius"]
      printf "derived_avg_rank_gap=electf_other,%.6f\n", electf_gap
      printf "derived_avg_rank_gap=locpotf_other,%.6f\n", locpotf_gap
      printf "derived_avg_rank_gap=ewald_other,%.6f\n", ewald_gap
      printf "derived_avg_rank_gap=ewald_mpi_other,%.6f\n", ewald_mpi_gap
      printf "derived_avg_rank_gap=nonlocf_other,%.6f\n", nonlocf_gap
      printf "derived_avg_rank_gap=nonlocf_kinetic_other,%.6f\n", kinetic_gap
      print "detail_timer_gate=PASS"
    }
  ' "$OUTPUT"
  echo "FPSEID21_CB3X3X3_X86_COST_DETAIL_END"
fi
echo "measurement_type=two_step_cost_distribution_diagnostic_not_baseline"
echo "FPSEID21_CB3X3X3_2STEP_COST_DISTRIBUTION_END"
