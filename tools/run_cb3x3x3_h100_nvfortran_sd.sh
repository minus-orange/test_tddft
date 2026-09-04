#!/bin/sh
set -eu

# H100 two-step diagnostic using the reviewed cb3x3x3 state produced by the
# isolated ifx-CG -> NVFORTRAN-SD chain at revision 5917b115d765. This wrapper
# exposes no long-run action and never reuses the earlier canonical-state H100
# result directory.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

ACTION=${1:-}
BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
STATE_REVISION=5917b115d765
STATE_ROOT=$BENCHMARK_ROOT/platforms/nvfortran_cpu_8468_spr21/chains/ifx_cg_nvfortran_sd/$STATE_REVISION/state
CANONICAL_STATE_ROOT=$BENCHMARK_ROOT/work/tddft_600K

usage() {
  cat <<'EOF'
Usage: CUDA_VISIBLE_DEVICES=0 ./tools/run_cb3x3x3_h100_nvfortran_sd.sh ACTION

Actions:
  preflight  Verify the reviewed NVFORTRAN-SD state, confirm that it differs
             from the canonical ifx-SD state, then run the H100 preflight.
  tddft-2    Re-run preflight, build in an isolated lineage/source-revision
             platform tree, run exactly two steps on 1 H100 / 1 MPI / 1 OMP,
             and relaxed-compare with the fixed Xeon 8592+ ifx result.

There is deliberately no 100-step or baseline-adoption action. Review the
preflight before tddft-2 and review tddft-2 before any longer experiment.
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

require_provenance_value() {
  file=$1
  key=$2
  expected=$3
  actual=$(provenance_value "$key" "$file")
  [ "$actual" = "$expected" ] ||
    fail "$file has $key=${actual:-MISSING}; expected $expected"
}

manifest_hash() {
  file=$1
  name=$2
  awk -v name="$name" '$2 == name {print $1; exit}' "$file"
}

verify_lineage_state() {
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
    *) fail "unexpected NVFORTRAN-SD state revision: ${producer_revision:-MISSING}" ;;
  esac
  require_provenance_value "$provenance" lineage IFX_CG_TO_NVFORTRAN_SD
  require_provenance_value "$provenance" sd_normal_check PASS
  require_provenance_value "$provenance" sd_relaxed_compare PASS
  require_provenance_value "$provenance" canonical_state_mutated NO

  density_hash=$(manifest_hash "$manifest" rh.dia-cb3x3x3)
  wavefunction_hash=$(manifest_hash "$manifest" wf_fft.dia-cb3x3x3)
  canonical_density_hash=$(manifest_hash "$canonical_manifest" rh.dia-cb3x3x3)
  canonical_wavefunction_hash=$(manifest_hash "$canonical_manifest" wf_fft.dia-cb3x3x3)
  [ -n "$density_hash" ] && [ -n "$wavefunction_hash" ] &&
    [ -n "$canonical_density_hash" ] && [ -n "$canonical_wavefunction_hash" ] ||
    fail "state manifest is incomplete"
  [ "$density_hash" != "$canonical_density_hash" ] ||
    fail "NVFORTRAN-SD density unexpectedly matches the canonical ifx state"
  [ "$wavefunction_hash" != "$canonical_wavefunction_hash" ] ||
    fail "NVFORTRAN-SD wavefunction unexpectedly matches the canonical ifx state"
}

case "$ACTION" in
  -h|--help|help|'')
    usage
    [ -n "$ACTION" ] || exit 2
    exit 0
    ;;
  preflight|tddft-2) ;;
  *) usage >&2; fail "unknown action: $ACTION" ;;
esac

verify_lineage_state

source_revision=$(git -c safe.directory="$ROOT_DIR" -C "$ROOT_DIR" rev-parse HEAD)
source_short_revision=$(git -c safe.directory="$ROOT_DIR" -C "$ROOT_DIR" \
  rev-parse --short=12 HEAD)
host_name=$(hostname -s 2>/dev/null || hostname)
platform_id=$(printf 'h100_%s' "$host_name" |
  tr '[:upper:]' '[:lower:]' | tr '+.' 'pp')
platform_root=$BENCHMARK_ROOT/platforms/$platform_id/chains/ifx_cg_nvfortran_sd_$STATE_REVISION/source_$source_short_revision
timestamp=$(date '+%Y%m%d_%H%M%S')
label="cb3x3x3_${platform_id}_nvfortran_sd_${STATE_REVISION}_1gpu_1mpi_1omp_2step_${timestamp}_${source_short_revision}"

echo "FPSEID21_CB3X3X3_H100_NVFORTRAN_SD_STATE_BEGIN"
echo "source_revision=$source_revision"
echo "accepted_numerical_source=c46cfa9"
echo "pending_correctness_candidate=bb5cb58"
echo "state_producer_revision=$producer_revision"
echo "state_lineage=IFX_CG_TO_NVFORTRAN_SD"
echo "state_dir=$STATE_ROOT"
echo "density_sha256=$density_hash"
echo "wf_fft_sha256=$wavefunction_hash"
echo "canonical_density_sha256=$canonical_density_hash"
echo "canonical_wf_fft_sha256=$canonical_wavefunction_hash"
echo "state_differs_from_canonical_ifx=YES"
echo "platform_root=$platform_root"
echo "action=$ACTION"
echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
echo "lineage_provenance_gate=PASS"
echo "FPSEID21_CB3X3X3_H100_NVFORTRAN_SD_STATE_END"

STATE_DIR="$STATE_ROOT" H100_PLATFORM_ROOT="$platform_root" \
  BENCHMARK_ROOT="$BENCHMARK_ROOT" LABEL="$label" \
  "$SCRIPT_DIR/run_cb3x3x3_h100.sh" "$ACTION"
