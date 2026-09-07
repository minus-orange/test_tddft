#!/bin/sh
set -eu

# Re-measure two-step cost distributions on the paired Xeon 8468 CPU/FFTW
# and H100 OpenACC/cuFFT paths using one fixed NVFORTRAN-SD state lineage.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ACTION=${1:-}
BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
STATE_REVISION=5917b115d765
STATE_ROOT=$BENCHMARK_ROOT/platforms/nvfortran_cpu_8468_spr21/chains/ifx_cg_nvfortran_sd/$STATE_REVISION/state
CANONICAL_STATE_ROOT=$BENCHMARK_ROOT/work/tddft_600K
CPU_FFTW_ROOT=$BENCHMARK_ROOT/platforms/nvfortran_cpu_8468_spr21/deps/fftw-3.3.11-gcc-pthreads/install

usage() {
  cat <<'EOF'
Usage: ./tools/run_cb3x3x3_2step_cost_remeasure.sh ACTION

Actions:
  preflight-x86  Read-only gate for Xeon 8468 NVFORTRAN CPU/FFTW.
  x86            Run one isolated 2-step 32 MPI x 3 OpenMP measurement.
  preflight-gpu  Read-only gate for H100 NVFORTRAN OpenACC/cuFFT.
  gpu            Run one isolated 2-step 1 GPU x 1 MPI x 1 OpenMP measurement.

Both paths use the reviewed NVFORTRAN-SD state produced at revision
5917b115d765 and require normal plus relaxed comparison with the fixed Xeon
8592+ ifx result. Each run prints the same compact inclusive-timer report.
The x86 path additionally uses a revision-isolated cost-detail build to split
ELECTF/NONLOCF, LOCPOTF/EWALDY, and the forward/reverse S2 nonlocal
traversals. EWALDY communication is split into energy reduction, force
reductions, and force broadcast. Runtime checks and the broad FRPRMN
diagnostic remain off.
The measurements are diagnostic only and cannot establish a baseline.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_nonempty() {
  [ -s "$1" ] || fail "required file is missing or empty: $1"
}

provenance_value() {
  key=$1
  file=$2
  awk -F= -v key="$key" '$1 == key {
    print substr($0, index($0, "=") + 1); exit
  }' "$file"
}

manifest_hash() {
  file=$1
  name=$2
  awk -v name="$name" '$2 == name {print $1; exit}' "$file"
}

verify_state() {
  provenance=$STATE_ROOT/STATE_PROVENANCE.env
  manifest=$STATE_ROOT/STATE_MANIFEST.sha256
  canonical_manifest=$CANONICAL_STATE_ROOT/STATE_MANIFEST.sha256
  require_nonempty "$provenance"
  require_nonempty "$manifest"
  require_nonempty "$canonical_manifest"
  require_nonempty "$STATE_ROOT/rh.dia-cb3x3x3"
  require_nonempty "$STATE_ROOT/wf_fft.dia-cb3x3x3"

  producer_revision=$(provenance_value revision "$provenance")
  case "$producer_revision" in
    "$STATE_REVISION"*) ;;
    *) fail "unexpected state producer revision: ${producer_revision:-MISSING}" ;;
  esac
  [ "$(provenance_value lineage "$provenance")" = IFX_CG_TO_NVFORTRAN_SD ] ||
    fail "unexpected state lineage"
  [ "$(provenance_value sd_normal_check "$provenance")" = PASS ] ||
    fail "NVFORTRAN-SD normal-check provenance is not PASS"
  [ "$(provenance_value sd_relaxed_compare "$provenance")" = PASS ] ||
    fail "NVFORTRAN-SD relaxed-comparison provenance is not PASS"
  [ "$(provenance_value canonical_state_mutated "$provenance")" = NO ] ||
    fail "canonical-state mutation provenance is not NO"

  density_hash=$(manifest_hash "$manifest" rh.dia-cb3x3x3)
  wavefunction_hash=$(manifest_hash "$manifest" wf_fft.dia-cb3x3x3)
  canonical_density_hash=$(manifest_hash "$canonical_manifest" rh.dia-cb3x3x3)
  canonical_wavefunction_hash=$(manifest_hash "$canonical_manifest" wf_fft.dia-cb3x3x3)
  [ -n "$density_hash" ] && [ -n "$wavefunction_hash" ] &&
    [ -n "$canonical_density_hash" ] &&
    [ -n "$canonical_wavefunction_hash" ] ||
    fail "state manifest is incomplete"
  [ "$density_hash" != "$canonical_density_hash" ] ||
    fail "private density unexpectedly matches canonical ifx-SD state"
  [ "$wavefunction_hash" != "$canonical_wavefunction_hash" ] ||
    fail "private wavefunction unexpectedly matches canonical ifx-SD state"
}

case "$ACTION" in
  -h|--help|help|'')
    usage
    [ -n "$ACTION" ] || exit 2
    exit 0
    ;;
  preflight-x86|x86|preflight-gpu|gpu) ;;
  *) usage >&2; fail "unknown action: $ACTION" ;;
esac

verify_state
source_revision=$(git -c safe.directory="$ROOT_DIR" -C "$ROOT_DIR" rev-parse HEAD)
source_short_revision=$(git -c safe.directory="$ROOT_DIR" -C "$ROOT_DIR" rev-parse --short=12 HEAD)
series_root=$BENCHMARK_ROOT/platforms/comparisons/2step_cost_distribution/state_$STATE_REVISION/source_$source_short_revision
timestamp=$(date '+%Y%m%d_%H%M%S')

echo "FPSEID21_CB3X3X3_2STEP_COST_GATE_BEGIN"
echo "source_revision=$source_revision"
echo "accepted_numerical_source=c46cfa9"
echo "pending_correctness_candidate=bb5cb58"
echo "state_producer_revision=$producer_revision"
echo "state_lineage=IFX_CG_TO_NVFORTRAN_SD"
echo "density_sha256=$density_hash"
echo "wf_fft_sha256=$wavefunction_hash"
echo "action=$ACTION"
echo "measurement=2step_cost_distribution_diagnostic"
echo "baseline=NOT_APPLICABLE"
echo "FPSEID21_CB3X3X3_2STEP_COST_GATE_END"

case "$ACTION" in
  preflight-x86)
    STATE_DIR="$STATE_ROOT" \
      NVFORTRAN_PLATFORM_ROOT="$series_root/x86_nvfortran_cpu_fftw" \
      NVFORTRAN_FFTW_ROOT="$CPU_FFTW_ROOT" \
      COST_DETAIL_TIMERS=1 \
      "$SCRIPT_DIR/run_cb3x3x3_nvfortran_cpu.sh" preflight
    ;;
  x86)
    label="cb3x3x3_x86_nvfortran_sd_cost_2step_${timestamp}_${source_short_revision}"
    STATE_DIR="$STATE_ROOT" \
      NVFORTRAN_PLATFORM_ROOT="$series_root/x86_nvfortran_cpu_fftw" \
      NVFORTRAN_FFTW_ROOT="$CPU_FFTW_ROOT" COST_DISTRIBUTION=1 \
      COST_DETAIL_TIMERS=1 \
      COST_PLATFORM=XEON_8468_NVFORTRAN_CPU_FFTW_32MPI_3OMP LABEL="$label" \
      "$SCRIPT_DIR/run_cb3x3x3_nvfortran_cpu.sh" tddft-2
    ;;
  preflight-gpu)
    CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0} STATE_DIR="$STATE_ROOT" \
      H100_PLATFORM_ROOT="$series_root/h100_nvfortran_openacc_cufft" \
      COST_DETAIL_TIMERS=1 \
      "$SCRIPT_DIR/run_cb3x3x3_h100.sh" preflight
    ;;
  gpu)
    label="cb3x3x3_h100_nvfortran_sd_cost_2step_${timestamp}_${source_short_revision}"
    CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0} STATE_DIR="$STATE_ROOT" \
      H100_PLATFORM_ROOT="$series_root/h100_nvfortran_openacc_cufft" \
      COST_DISTRIBUTION=1 COST_DETAIL_TIMERS=1 \
      COST_PLATFORM=H100_NVFORTRAN_OPENACC_CUFFT_1MPI_1OMP \
      LABEL="$label" "$SCRIPT_DIR/run_cb3x3x3_h100.sh" tddft-2
    ;;
esac
