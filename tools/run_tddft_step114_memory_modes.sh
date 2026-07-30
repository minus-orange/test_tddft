#!/bin/sh
set -eu

# Screen NVHPC memory modes against the accepted pinned-separate mode.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUN_DIR=${RUN_DIR:-"$ROOT_DIR/run/Si111-H_nvhpc"}
NVFORTRAN=${NVFORTRAN:-nvfortran}
OFFICIAL_MEDIAN=63.2135219574
BASE_FLAGS="-O2 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays"

cd "$ROOT_DIR"
if [ "$(git branch --show-current)" != tddft-openacc-residency ]; then
  echo "ERROR: checkout tddft-openacc-residency first." >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: tracked worktree or index is not clean." >&2
  exit 1
fi
set -- $(git rev-list --left-right --count \
  origin/tddft-openacc-residency...HEAD)
if [ "$1" != 0 ] || [ "$2" != 0 ]; then
  echo "ERROR: local branch and origin are not synchronized." >&2
  exit 1
fi
if [ ! -f "$RUN_DIR/Si111-H_tm.in_100steps" ]; then
  echo "ERROR: prepared 100-step run directory is missing: $RUN_DIR" >&2
  exit 1
fi

CURRENT_REVISION=$(git rev-parse HEAD)
summary_lines=
screen_control=
current_tag=
current_flags=

print_failure() {
  stage=$1
  echo
  echo "FPSEID21 STEP114 NVHPC MEMORY-MODE SCREEN FAILURE"
  echo "revision=$CURRENT_REVISION"
  echo "variant=$current_tag stage=$stage"
  echo "flags=$current_flags"
  if [ -n "$summary_lines" ]; then
    echo "FPSEID_STEP114_COMPLETED_BEGIN"
    echo "variant wall_sec vs_control_sec vs_control_pct vs_official_pct check relaxed pairwise_strict"
    printf '%s\n' "$summary_lines" | sed '/^[[:space:]]*$/d'
    echo "FPSEID_STEP114_COMPLETED_END"
  fi
  case "$stage" in
    run|archive)
      error_file=$RUN_DIR/Si111-H_tm.err
      ;;
    check|relaxed_compare)
      error_file=$archive_dir/tddft.err
      ;;
    *)
      error_file=
      ;;
  esac
  case "$stage" in
    run|archive|check|relaxed_compare)
      if [ -f "$error_file" ]; then
        echo "FPSEID_STEP114_ERROR_TAIL_BEGIN"
        tail -n 8 "$error_file"
        echo "FPSEID_STEP114_ERROR_TAIL_END"
      fi
      ;;
  esac
  echo "Stop here; do not run another memory mode."
  exit 1
}

run_variant() {
  tag=$1
  flags=$2
  label=nvhpc_cufft_1rank_02_STEP114_MEM_${tag}_01
  archive_dir=$ROOT_DIR/run/tddft_archives/$label
  current_tag=$tag
  current_flags=$flags

  if [ -e "$archive_dir" ]; then
    metadata=$archive_dir/step114.env
    if [ ! -f "$metadata" ]; then
      echo "ERROR: existing archive lacks Step 114 metadata: $label" >&2
      exit 1
    fi
    archived_revision=$(sed -n 's/^revision=//p' "$metadata")
    archived_flags=$(sed -n 's/^flags=//p' "$metadata")
    if [ "$archived_revision" != "$CURRENT_REVISION" ] ||
       [ "$archived_flags" != "$flags" ]; then
      echo "ERROR: existing archive provenance mismatch: $label" >&2
      exit 1
    fi
    echo
    echo "STEP114 reusing validated archive variant=$tag"
  else
    echo
    echo "STEP114 building variant=$tag"
    if ! FPSEID_FRPRMN_DIAGNOSTIC=0 \
        TDDFT_FFLAGS="$flags" \
        TDDFT_ONLY=1 ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=0 \
        "$SCRIPT_DIR/build_nvhpc.sh"; then
      print_failure build
    fi

    cd "$RUN_DIR"
    ulimit -s unlimited 2>/dev/null || true
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=512M
    export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}
    if ! mpirun -np 1 \
        "$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe" \
        < Si111-H_tm.in_100steps \
        > Si111-H_tm.out_100steps \
        2> Si111-H_tm.err; then
      cd "$ROOT_DIR"
      print_failure run
    fi

    cd "$ROOT_DIR"
    if ! LABEL="$label" TDDFT_OUTPUT=Si111-H_tm.out_100steps \
        TDDFT_ERR=Si111-H_tm.err \
        "$SCRIPT_DIR/archive_tddft_result.sh" "$RUN_DIR" >/dev/null; then
      print_failure archive
    fi

    {
      echo "revision=$CURRENT_REVISION"
      echo "flags=$flags"
    } > "$archive_dir/step114.env"
  fi

  if ! python3 "$SCRIPT_DIR/check_tddft_result.py" check \
      "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" \
      --expected-steps 100 >/dev/null; then
    python3 "$SCRIPT_DIR/check_tddft_result.py" check \
      "$archive_dir/tddft.out" --err "$archive_dir/tddft.err" \
      --expected-steps 100 || true
    print_failure check
  fi
  if ! python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$archive_dir/tddft.out" --test-err "$archive_dir/tddft.err" \
      --expected-steps 100 >/dev/null; then
    python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$archive_dir/tddft.out" --test-err "$archive_dir/tddft.err" \
      --expected-steps 100 || true
    print_failure relaxed_compare
  fi

  pairwise_strict=PASS
  if [ "$tag" != CONTROL ]; then
    reference=$ROOT_DIR/run/tddft_archives/\
nvhpc_cufft_1rank_02_STEP114_MEM_CONTROL_01
    if ! python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
        "$reference/tddft.out" "$archive_dir/tddft.out" \
        --ref-err "$reference/tddft.err" \
        --test-err "$archive_dir/tddft.err" \
        --expected-steps 100 --strict >/dev/null; then
      pairwise_strict=FAIL
    fi
  fi

  wall=$(awk '
    /steps took/ {
      value=$(NF-1)
      gsub(/[dD]/,"E",value)
    }
    END { printf "%.10f", value+0.0 }
  ' "$archive_dir/tddft.out")
  if [ "$tag" = CONTROL ]; then
    screen_control=$wall
  fi
  screen_delta=$(awk -v wall="$wall" -v base="$screen_control" \
    'BEGIN { printf "%.10f", wall-base }')
  screen_pct=$(awk -v wall="$wall" -v base="$screen_control" \
    'BEGIN { printf "%.6f", 100.0*(wall-base)/base }')
  official_pct=$(awk -v wall="$wall" -v base="$OFFICIAL_MEDIAN" \
    'BEGIN { printf "%.6f", 100.0*(wall-base)/base }')
  summary_lines="${summary_lines}
$tag $wall $screen_delta $screen_pct $official_pct PASS PASS $pairwise_strict"
}

run_variant CONTROL \
  "$BASE_FLAGS -gpu=mem:separate:pinnedalloc"
run_variant MANAGED \
  "$BASE_FLAGS -gpu=mem:managed"
run_variant UNIFIED \
  "$BASE_FLAGS -gpu=mem:unified"

compiler=$("$NVFORTRAN" -V 2>&1 |
  sed -n '/[^[:space:]]/{p;q;}' || true)
device=$(nvidia-smi --query-gpu=name,driver_version \
  --format=csv,noheader 2>/dev/null | sed -n '1p' || true)

echo
echo "FPSEID21 STEP114 NVHPC MEMORY-MODE SCREEN SUMMARY"
echo "revision=$CURRENT_REVISION"
echo "source_baseline=c46cfa9"
echo "official_step107_median_sec=$OFFICIAL_MEDIAN"
echo "diagnostic=OFF gpu=A100 mpi_ranks=1 steps=100"
echo "compiler=$compiler"
echo "device=$device"
echo "kernel=$(uname -r)"
echo "FPSEID_MEMORY_MODES_BEGIN"
echo "variant wall_sec vs_control_sec vs_control_pct vs_official_pct check relaxed pairwise_strict"
printf '%s\n' "$summary_lines" | sed '/^[[:space:]]*$/d'
echo "FPSEID_MEMORY_MODES_END"
echo "CONTROL_FLAGS=$BASE_FLAGS -gpu=mem:separate:pinnedalloc"
echo "MANAGED_FLAGS=$BASE_FLAGS -gpu=mem:managed"
echo "UNIFIED_FLAGS=$BASE_FLAGS -gpu=mem:unified"
echo "One-run screening only; the official flags and baseline are unchanged."
