#!/bin/sh
set -eu

# Preflight and bounded two-step startup/memory validation for the official
# diamond cb3x3x3 case on exactly one NVIDIA H100. This helper intentionally
# exposes no 100-step action.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

ACTION=${1:-}
BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
STATE_DIR=${STATE_DIR:-"$BENCHMARK_ROOT/work/tddft_600K"}
H100_PLATFORM_ROOT=${H100_PLATFORM_ROOT:-}
X86_2STEP_REFERENCE=${X86_2STEP_REFERENCE:-"$BENCHMARK_ROOT/platforms/8592p_spr10/runs/cb3x3x3_8592p_spr10_32mpi_4omp_2step_20260827_170605_6ddf5ff11ecc"}
GPU_ID=${CUDA_VISIBLE_DEVICES:-0}
GPU_ARCH=cc90
BASE_FLAGS="-O2 -acc -gpu=$GPU_ARCH -mp -Msave -Mlarge_arrays"
EFFECTIVE_FLAGS="$BASE_FLAGS -gpu=mem:separate:pinnedalloc"
MIN_FREE_PERCENT=90
MIN_HOST_AVAILABLE_GIB=64
OMP_STACKSIZE=${OMP_STACKSIZE:-512M}
MPIRUN=${MPIRUN:-mpirun}
NVFORTRAN=${NVFORTRAN:-nvfortran}
MPI_FC=${MPI_FC:-mpifort}
GPU_CC=${GPU_CC:-nvc}
COST_DISTRIBUTION=${COST_DISTRIBUTION:-0}
COST_PLATFORM=${COST_PLATFORM:-H100_NVFORTRAN_OPENACC_CUFFT_1MPI_1OMP}
COST_DETAIL_TIMERS=${COST_DETAIL_TIMERS:-0}
case "$COST_DETAIL_TIMERS" in
  0) BUILD_VARIANT=standard ;;
  1) BUILD_VARIANT=cost_detail ;;
  *)
    echo "ERROR: COST_DETAIL_TIMERS must be 0 or 1" >&2
    exit 1
    ;;
esac

usage() {
  cat <<'EOF'
Usage: CUDA_VISIBLE_DEVICES=0 ./tools/run_cb3x3x3_h100.sh ACTION

Actions:
  preflight  Read-only Git, input/state, compiler, H100 identity, occupancy,
             and free-memory checks. No build or simulation.
  tddft-2    Re-run preflight, build TDDFT for cc90 pinned separate memory,
             and run one isolated 2-step startup/memory diagnostic.

The fixed execution is 1 H100 / 1 MPI rank / 1 OpenMP thread with diagnostics
off. COST_DETAIL_TIMERS=1 enables the same bounded timer labels used by the
x86 path without enabling broad diagnostics. There is deliberately no
100-step action; review the 2-step result first.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command was not found: $1"
}

require_file() {
  [ -f "$1" ] || fail "required file is missing: $1"
}

require_nonempty() {
  [ -s "$1" ] || fail "required file is missing or empty: $1"
}

copy_text_lf_new() {
  source_file=$1
  destination_file=$2
  [ ! -e "$destination_file" ] && [ ! -L "$destination_file" ] ||
    fail "path already exists; refusing to overwrite: $destination_file"
  LC_ALL=C tr -d '\r' < "$source_file" > "$destination_file"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

git_repo() {
  git -c safe.directory="$ROOT_DIR" -C "$ROOT_DIR" "$@"
}

validate_label() {
  case "$1" in
    ''|*[!A-Za-z0-9._+-]*)
      fail "LABEL may contain only letters, digits, dot, underscore, plus, and hyphen"
      ;;
  esac
}

link_new() {
  target=$1
  link=$2
  [ ! -e "$link" ] && [ ! -L "$link" ] ||
    fail "path already exists; refusing to overwrite: $link"
  ln -s "$target" "$link"
}

verify_state() {
  require_nonempty "$STATE_DIR/rh.dia-cb3x3x3"
  require_nonempty "$STATE_DIR/wf_fft.dia-cb3x3x3"
  require_nonempty "$STATE_DIR/STATE_MANIFEST.sha256"
  require_file "$STATE_DIR/STATE_PROVENANCE.env"
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$STATE_DIR" && sha256sum -c STATE_MANIFEST.sha256 >/dev/null) ||
      fail "TDDFT initial-state SHA-256 validation failed"
  else
    (cd "$STATE_DIR" && shasum -a 256 -c STATE_MANIFEST.sha256 >/dev/null) ||
      fail "TDDFT initial-state SHA-256 validation failed"
  fi
}

release_build_lock() {
  if [ -n "${build_lock:-}" ] && [ -d "$build_lock" ]; then
    rmdir "$build_lock" 2>/dev/null || true
  fi
}

preflight() {
  require_command git
  require_command awk
  require_command python3
  require_command tr
  require_command nvidia-smi
  require_command "$NVFORTRAN"
  require_command "$MPI_FC"
  require_command "$GPU_CC"
  require_command "$MPIRUN"

  [ "$(uname -s)" = Linux ] || fail "H100 execution requires Linux"
  [ -r /proc/meminfo ] || fail "/proc/meminfo is not readable"
  host_memory_total_kib=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
  host_memory_available_kib=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
  [ -n "$host_memory_total_kib" ] && [ -n "$host_memory_available_kib" ] ||
    fail "MemTotal or MemAvailable is missing from /proc/meminfo"
  host_memory_total_gib=$(awk -v kib="$host_memory_total_kib" \
    'BEGIN {printf "%.2f", kib/1048576}')
  host_memory_available_gib=$(awk -v kib="$host_memory_available_kib" \
    'BEGIN {printf "%.2f", kib/1048576}')
  awk -v have="$host_memory_available_gib" -v need="$MIN_HOST_AVAILABLE_GIB" \
    'BEGIN {exit !(have >= need)}' ||
    fail "host MemAvailable is ${host_memory_available_gib} GiB; require at least ${MIN_HOST_AVAILABLE_GIB} GiB"

  case "$GPU_ID" in
    ''|*,*) fail "expose exactly one H100 through CUDA_VISIBLE_DEVICES" ;;
  esac

  [ "$(git_repo branch --show-current)" = tddft-openacc-residency ] ||
    fail "checkout tddft-openacc-residency first"
  git_repo diff --quiet || fail "tracked worktree is not clean"
  git_repo diff --cached --quiet || fail "Git index is not clean"
  set -- $(git_repo rev-list --left-right --count \
    origin/tddft-openacc-residency...HEAD)
  [ "$1" = 0 ] && [ "$2" = 0 ] ||
    fail "local branch and origin/tddft-openacc-residency are not synchronized"

  "$SCRIPT_DIR/check_cb3x3x3_benchmark.sh" >/dev/null
  require_file "$STATE_DIR/dia-cb3x3x3_tm.in_2steps"
  grep -Eq 'tstep=2([[:space:]]|$)' \
    "$STATE_DIR/dia-cb3x3x3_tm.in_2steps" ||
    fail "2-step input has the wrong tstep"
  verify_state
  require_nonempty "$X86_2STEP_REFERENCE/dia-cb3x3x3_tm.out"

  device_row=$(nvidia-smi -i "$GPU_ID" \
    --query-gpu=name,compute_cap,memory.total,memory.free,memory.used,driver_version \
    --format=csv,noheader,nounits 2>/dev/null | sed -n '1p' || true)
  [ -n "$device_row" ] || fail "unable to query GPU $GPU_ID"
  gpu_name=$(printf '%s\n' "$device_row" | awk -F, '{gsub(/^ +| +$/, "", $1); print $1}')
  compute_cap=$(printf '%s\n' "$device_row" | awk -F, '{gsub(/^ +| +$/, "", $2); print $2}')
  memory_total_mib=$(printf '%s\n' "$device_row" | awk -F, '{gsub(/^ +| +$/, "", $3); print $3}')
  memory_free_mib=$(printf '%s\n' "$device_row" | awk -F, '{gsub(/^ +| +$/, "", $4); print $4}')
  memory_used_mib=$(printf '%s\n' "$device_row" | awk -F, '{gsub(/^ +| +$/, "", $5); print $5}')
  driver_version=$(printf '%s\n' "$device_row" | awk -F, '{gsub(/^ +| +$/, "", $6); print $6}')
  case "$gpu_name" in
    *H100*) ;;
    *) fail "expected an NVIDIA H100, detected: $gpu_name" ;;
  esac
  case "$compute_cap" in
    9.0|9.0*) ;;
    *) fail "expected H100 compute capability 9.0, detected: $compute_cap" ;;
  esac
  case "$memory_total_mib:$memory_free_mib:$memory_used_mib" in
    *[!0-9.:]*) fail "unexpected nvidia-smi memory values: $device_row" ;;
  esac

  gpu_processes=$(nvidia-smi -i "$GPU_ID" \
    --query-compute-apps=pid,process_name,used_memory \
    --format=csv,noheader 2>/dev/null || true)
  if [ -n "$gpu_processes" ]; then
    echo "$gpu_processes" >&2
    fail "H100 has an active compute process"
  fi

  memory_free_percent=$(awk -v free="$memory_free_mib" -v total="$memory_total_mib" \
    'BEGIN {if (total <= 0) exit 1; printf "%.2f", 100.0*free/total}') ||
    fail "unable to calculate free GPU memory percentage"
  free_gate=$(awk -v free="$memory_free_percent" -v minimum="$MIN_FREE_PERCENT" \
    'BEGIN {print (free >= minimum) ? "PASS" : "BLOCK"}')
  [ "$free_gate" = PASS ] ||
    fail "free GPU memory is ${memory_free_percent}%; require at least ${MIN_FREE_PERCENT}%"

  revision=$(git_repo rev-parse HEAD)
  short_revision=$(git_repo rev-parse --short=12 HEAD)
  host_name=$(hostname -s 2>/dev/null || hostname)
  platform_id=$(printf 'h100_%s' "$host_name" |
    tr '[:upper:]' '[:lower:]' | tr '+.' 'pp')
  if [ -n "$H100_PLATFORM_ROOT" ]; then
    PLATFORM_ROOT=$H100_PLATFORM_ROOT
  else
    PLATFORM_ROOT=$BENCHMARK_ROOT/platforms/$platform_id
  fi
  if [ "$BUILD_VARIANT" = cost_detail ]; then
    PLATFORM_BIN=$PLATFORM_ROOT/bin/cost_detail
    PLATFORM_RUNS=$PLATFORM_ROOT/runs/cost_detail
  else
    PLATFORM_BIN=$PLATFORM_ROOT/bin
    PLATFORM_RUNS=$PLATFORM_ROOT/runs
  fi
  state_producer_revision=$(awk -F= '$1 == "revision" {
    print substr($0, index($0, "=") + 1); exit
  }' "$STATE_DIR/STATE_PROVENANCE.env")
  state_lineage=$(awk -F= '$1 == "lineage" {
    print substr($0, index($0, "=") + 1); exit
  }' "$STATE_DIR/STATE_PROVENANCE.env")
  compiler=$("$NVFORTRAN" -V 2>&1 | sed -n '/[^[:space:]]/{p;q;}' || true)
  mpi_compiler=$("$MPI_FC" --version 2>&1 | sed -n '/[^[:space:]]/{p;q;}' || true)
  mpirun_version=$("$MPIRUN" --version 2>&1 | sed -n '/[^[:space:]]/{p;q;}' || true)

  echo "FPSEID21_CB3X3X3_H100_PREFLIGHT_BEGIN"
  echo "revision=$revision"
  echo "accepted_numerical_source=c46cfa9"
  echo "pending_correctness_candidate=bb5cb58"
  echo "hostname=$host_name"
  echo "gpu_id=$GPU_ID"
  echo "gpu_name=$gpu_name"
  echo "compute_capability=$compute_cap"
  echo "driver_version=$driver_version"
  echo "host_memory_total_gib=$host_memory_total_gib"
  echo "host_memory_available_gib=$host_memory_available_gib"
  echo "memory_total_mib=$memory_total_mib"
  echo "memory_free_mib=$memory_free_mib"
  echo "memory_used_mib=$memory_used_mib"
  echo "memory_free_percent=$memory_free_percent"
  echo "active_compute_processes=0"
  echo "compiler=$compiler"
  echo "mpi_compiler=$mpi_compiler"
  echo "mpirun=$mpirun_version"
  echo "flags=$EFFECTIVE_FLAGS"
  echo "build_variant=$BUILD_VARIANT"
  echo "cost_detail_timers=$COST_DETAIL_TIMERS"
  echo "configuration=1_H100_1_MPI_1_OpenMP_diagnostic_OFF"
  echo "state_dir=$STATE_DIR"
  echo "state_producer_revision=${state_producer_revision:-NOT_RECORDED}"
  echo "state_lineage=${state_lineage:-NOT_RECORDED}"
  echo "platform_root=$PLATFORM_ROOT"
  echo "x86_2step_reference=$X86_2STEP_REFERENCE"
  echo "fortran_text_input_line_endings=LF_normalized_in_isolated_run"
  echo "official_input_gate=PASS"
  echo "initial_state_sha256_gate=PASS"
  echo "reference_gate=PASS"
  echo "gpu_occupancy_gate=PASS"
  echo "gpu_free_memory_gate=PASS"
  echo "host_memory_gate=PASS"
  echo "capacity_gate=REQUIRES_TDDFT_2STEP"
  echo "preflight_gate=PASS"
  echo "FPSEID21_CB3X3X3_H100_PREFLIGHT_END"
}

build_tddft() {
  mkdir -p "$ROOT_DIR/.cache" "$PLATFORM_BIN" "$PLATFORM_RUNS"
  build_lock=$ROOT_DIR/.cache/cb3x3x3_h100_build.lock
  if ! mkdir "$build_lock" 2>/dev/null; then
    fail "another cb3x3x3 H100 build appears active: $build_lock"
  fi
  trap release_build_lock EXIT HUP INT TERM

  echo "Building cb3x3x3 TDDFT for H100 cc90"
  FPSEID_FRPRMN_DIAGNOSTIC=0 \
  FPSEID_COST_DETAIL_TIMERS="$COST_DETAIL_TIMERS" \
  TDDFT_FFLAGS="$BASE_FLAGS" \
  TDDFT_ONLY=1 ENABLE_GPU_FFT=1 ENABLE_PINNED_ALLOC=1 \
  NVFORTRAN="$NVFORTRAN" MPI_FC="$MPI_FC" GPU_CC="$GPU_CC" \
    "$SCRIPT_DIR/build_nvhpc.sh"

  source_exe=$ROOT_DIR/FPSEID21/tddft_2022October/tddft_exe
  require_nonempty "$source_exe"
  executable_part=$PLATFORM_BIN/tddft_exe.part.$$
  cp -p "$source_exe" "$executable_part"
  mv -f "$executable_part" "$PLATFORM_BIN/tddft_exe"
  chmod a-w "$PLATFORM_BIN/tddft_exe"
  {
    echo "revision=$revision"
    echo "accepted_numerical_source=c46cfa9"
    echo "pending_correctness_candidate=bb5cb58"
    echo "hostname=$host_name"
    echo "gpu_name=$gpu_name"
    echo "compute_capability=$compute_cap"
    echo "driver_version=$driver_version"
    echo "compiler=$compiler"
    echo "mpi_compiler=$mpi_compiler"
    echo "flags=$EFFECTIVE_FLAGS"
    echo "build_variant=$BUILD_VARIANT"
    echo "cost_detail_timers=$COST_DETAIL_TIMERS"
    echo "diagnostic=OFF"
    echo "tddft_executable_sha256=$(sha256_file "$PLATFORM_BIN/tddft_exe")"
  } > "$PLATFORM_BIN/BUILD_PROVENANCE.env"

  release_build_lock
  trap - EXIT HUP INT TERM
  echo "build_gate=PASS"
  echo "platform_bin=$PLATFORM_BIN"
}

prepare_run_dir() {
  run_dir=$1
  mkdir -p "$run_dir"
  for rel in \
    dia-cb3x3x3_tm.in_2steps TR.C95g_asci Avec Cartesian.velo \
    Eext Etot Ework laser.dat size.dat sym.C1
  do
    require_file "$STATE_DIR/$rel"
    copy_text_lf_new "$STATE_DIR/$rel" "$run_dir/$rel"
  done
  require_file "$STATE_DIR/SOURCE_MANIFEST.env"
  cp -p "$STATE_DIR/SOURCE_MANIFEST.env" "$run_dir/SOURCE_MANIFEST.env"
  cp -p "$STATE_DIR/STATE_MANIFEST.sha256" "$run_dir/STATE_MANIFEST.sha256"
  cp -p "$STATE_DIR/STATE_PROVENANCE.env" \
    "$run_dir/INPUT_STATE_PROVENANCE.env"
  ln "$STATE_DIR/rh.dia-cb3x3x3" "$run_dir/rh.dia-cb3x3x3"
  ln "$STATE_DIR/wf_fft.dia-cb3x3x3" "$run_dir/wf_fft.dia-cb3x3x3"
  link_new rh.dia-cb3x3x3 "$run_dir/fort.20"
  link_new wf_fft.dia-cb3x3x3 "$run_dir/fort.22"
  link_new wf_fft.dia-cb3x3x3 "$run_dir/fort.32"
  link_new TR.C95g_asci "$run_dir/fort.41"
  link_new Eext "$run_dir/fort.18"
  link_new Etot "$run_dir/fort.28"
  link_new laser.dat "$run_dir/fort.53"
  link_new size.dat "$run_dir/fort.54"
  link_new sym.C1 "$run_dir/fort.55"
  link_new Avec "$run_dir/fort.60"
  link_new Ework "$run_dir/fort.62"
}

run_two_steps() {
  timestamp=$(date '+%Y%m%d_%H%M%S')
  run_label=${LABEL:-"cb3x3x3_${platform_id}_1gpu_1mpi_1omp_2step_${timestamp}_${short_revision}"}
  validate_label "$run_label"
  run_dir=$PLATFORM_RUNS/$run_label
  [ ! -e "$run_dir" ] || fail "run directory already exists: $run_dir"

  build_tddft
  prepare_run_dir "$run_dir"
  {
    echo "revision=$revision"
    echo "accepted_numerical_source=c46cfa9"
    echo "pending_correctness_candidate=bb5cb58"
    echo "hostname=$host_name"
    echo "gpu_name=$gpu_name"
    echo "compute_capability=$compute_cap"
    echo "driver_version=$driver_version"
    echo "memory_total_mib=$memory_total_mib"
    echo "steps=2"
    echo "gpu_count=1"
    echo "mpi_ranks=1"
    echo "omp_num_threads=1"
    echo "flags=$EFFECTIVE_FLAGS"
    echo "build_variant=$BUILD_VARIANT"
    echo "cost_detail_timers=$COST_DETAIL_TIMERS"
    echo "diagnostic=OFF"
    echo "state_dir=$STATE_DIR"
    echo "state_producer_revision=${state_producer_revision:-NOT_RECORDED}"
    echo "state_lineage=${state_lineage:-NOT_RECORDED}"
    echo "platform_root=$PLATFORM_ROOT"
    echo "fortran_text_input_line_endings=LF"
    echo "source_input_sha256=$(sha256_file "$STATE_DIR/dia-cb3x3x3_tm.in_2steps")"
    echo "input_sha256=$(sha256_file "$run_dir/dia-cb3x3x3_tm.in_2steps")"
    echo "source_pseudopotential_sha256=$(sha256_file "$STATE_DIR/TR.C95g_asci")"
    echo "pseudopotential_sha256=$(sha256_file "$run_dir/TR.C95g_asci")"
    echo "state_manifest_sha256=$(sha256_file "$run_dir/STATE_MANIFEST.sha256")"
    echo "state_provenance_sha256=$(sha256_file "$run_dir/INPUT_STATE_PROVENANCE.env")"
    echo "tddft_executable_sha256=$(sha256_file "$PLATFORM_BIN/tddft_exe")"
    echo "reference_output=$X86_2STEP_REFERENCE/dia-cb3x3x3_tm.out"
  } > "$run_dir/RUN_PROVENANCE.env"

  echo "Running cb3x3x3 H100 startup: steps=2 GPU=1 MPI=1 OpenMP=1"
  (
    cd "$run_dir"
    ulimit -s unlimited 2>/dev/null || true
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE
    export CUDA_VISIBLE_DEVICES=$GPU_ID
    "$MPIRUN" -np 1 "$PLATFORM_BIN/tddft_exe" \
      < dia-cb3x3x3_tm.in_2steps \
      > dia-cb3x3x3_tm.out 2> dia-cb3x3x3_tm.err &
    run_pid=$!
    (
      echo "memory_used_mib"
      while kill -0 "$run_pid" 2>/dev/null; do
        nvidia-smi -i "$GPU_ID" --query-gpu=memory.used \
          --format=csv,noheader,nounits 2>/dev/null || true
        sleep 1
      done
      nvidia-smi -i "$GPU_ID" --query-gpu=memory.used \
        --format=csv,noheader,nounits 2>/dev/null || true
    ) > gpu_memory_used_mib.log &
    monitor_pid=$!
    run_status=0
    wait "$run_pid" || run_status=$?
    wait "$monitor_pid" || true
    echo "$run_status" > tddft_exit_status.txt
  )

  run_status=$(sed -n '1p' "$run_dir/tddft_exit_status.txt")
  verify_state
  peak_memory_used_mib=$(awk '
    NR > 1 {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 + 0 > peak) peak=$0 + 0
      samples++
    }
    END {
      if (samples == 0) exit 1
      printf "%.0f", peak
    }
  ' "$run_dir/gpu_memory_used_mib.log") ||
    fail "GPU memory monitor produced no samples: $run_dir/gpu_memory_used_mib.log"
  peak_memory_percent=$(awk -v peak="$peak_memory_used_mib" -v total="$memory_total_mib" \
    'BEGIN {printf "%.2f", 100.0*peak/total}')
  minimum_headroom_mib=$(awk -v peak="$peak_memory_used_mib" -v total="$memory_total_mib" \
    'BEGIN {printf "%.0f", total-peak}')

  if [ "$run_status" != 0 ]; then
    echo "FPSEID21_CB3X3X3_H100_2STEP_FAILURE_BEGIN"
    echo "stage=run exit_status=$run_status"
    echo "run_dir=$run_dir"
    echo "peak_memory_used_mib=$peak_memory_used_mib"
    echo "peak_memory_percent=$peak_memory_percent"
    echo "minimum_headroom_mib=$minimum_headroom_mib"
    echo "initial_state_postrun_sha256_gate=PASS"
    echo "stderr_tail_begin"
    tail -n 16 "$run_dir/dia-cb3x3x3_tm.err" 2>/dev/null || true
    echo "stderr_tail_end"
    echo "Stop here; do not run 100 steps."
    echo "FPSEID21_CB3X3X3_H100_2STEP_FAILURE_END"
    exit 1
  fi

  if ! check_summary=$(python3 "$SCRIPT_DIR/check_tddft_result.py" check \
      "$run_dir/dia-cb3x3x3_tm.out" \
      --err "$run_dir/dia-cb3x3x3_tm.err" \
      --expected-steps 2 --expected-atoms 216 2>&1); then
    echo "FPSEID21_CB3X3X3_H100_2STEP_FAILURE_BEGIN"
    echo "stage=normal_check exit_status=$run_status"
    echo "run_dir=$run_dir"
    echo "peak_memory_used_mib=$peak_memory_used_mib"
    echo "peak_memory_percent=$peak_memory_percent"
    echo "minimum_headroom_mib=$minimum_headroom_mib"
    echo "initial_state_postrun_sha256_gate=PASS"
    echo "normal_check_output_begin"
    printf '%s\n' "$check_summary"
    echo "normal_check_output_end"
    echo "Stop here; do not run 100 steps."
    echo "FPSEID21_CB3X3X3_H100_2STEP_FAILURE_END"
    exit 1
  fi
  printf '%s\n' "$check_summary"
  wall_sec=$(printf '%s\n' "$check_summary" | awk '
    /steps:/ {
      for (i=1; i<NF; i++) if ($i == "wall_sec:") value=$(i+1)
    }
    END {print value}
  ')
  [ -n "$wall_sec" ] || fail "normal-check summary did not contain wall_sec"
  if ! comparison_summary=$(EXPECTED_STEPS=2 EXPECTED_ATOMS=216 \
      REFERENCE_PLATFORM=XEON_8592P_IFX_32MPI_4OMP \
      TEST_PLATFORM=H100_NVFORTRAN_SD_STATE_1GPU_1MPI_1OMP \
      "$SCRIPT_DIR/compare_cb3x3x3_platform_results.sh" \
      "$X86_2STEP_REFERENCE" "$run_dir" 2>&1); then
    {
      echo "wall_sec=$wall_sec"
      echo "peak_memory_used_mib=$peak_memory_used_mib"
      echo "peak_memory_percent=$peak_memory_percent"
      echo "minimum_headroom_mib=$minimum_headroom_mib"
      echo "normal_check=PASS"
      echo "relaxed_compare=FAIL"
      echo "initial_state_postrun_sha256_gate=PASS"
      echo "baseline=NOT_APPLICABLE"
    } >> "$run_dir/RUN_PROVENANCE.env"
    echo "FPSEID21_CB3X3X3_H100_2STEP_FAILURE_BEGIN"
    echo "stage=relaxed_compare exit_status=$run_status"
    echo "run_dir=$run_dir"
    echo "peak_memory_used_mib=$peak_memory_used_mib"
    echo "peak_memory_percent=$peak_memory_percent"
    echo "minimum_headroom_mib=$minimum_headroom_mib"
    echo "comparison_output_begin"
    printf '%s\n' "$comparison_summary"
    echo "comparison_output_end"
    echo "initial_state_postrun_sha256_gate=PASS"
    echo "Stop here; do not run 100 steps."
    echo "FPSEID21_CB3X3X3_H100_2STEP_FAILURE_END"
    exit 1
  fi
  printf '%s\n' "$comparison_summary"
  {
    echo "wall_sec=$wall_sec"
    echo "peak_memory_used_mib=$peak_memory_used_mib"
    echo "peak_memory_percent=$peak_memory_percent"
    echo "minimum_headroom_mib=$minimum_headroom_mib"
    echo "normal_check=PASS"
    echo "relaxed_compare=PASS"
    echo "initial_state_postrun_sha256_gate=PASS"
    echo "baseline=NOT_APPLICABLE"
  } >> "$run_dir/RUN_PROVENANCE.env"

  echo "FPSEID21_CB3X3X3_H100_2STEP_PASS_BEGIN"
  echo "revision=$revision"
  echo "label=$run_label"
  echo "run_dir=$run_dir"
  echo "state_dir=$STATE_DIR"
  echo "state_producer_revision=${state_producer_revision:-NOT_RECORDED}"
  echo "state_lineage=${state_lineage:-NOT_RECORDED}"
  echo "platform_root=$PLATFORM_ROOT"
  echo "device=$gpu_name"
  echo "configuration=1_H100_1_MPI_1_OpenMP_diagnostic_OFF"
  echo "build_variant=$BUILD_VARIANT"
  echo "cost_detail_timers=$COST_DETAIL_TIMERS"
  echo "wall_sec=$wall_sec"
  echo "peak_memory_used_mib=$peak_memory_used_mib"
  echo "peak_memory_percent=$peak_memory_percent"
  echo "minimum_headroom_mib=$minimum_headroom_mib"
  echo "normal_check=PASS"
  echo "relaxed_compare=PASS"
  echo "initial_state_postrun_sha256_gate=PASS"
  echo "two_step_memory_gate=PASS"
  echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
  echo "baseline=NOT_APPLICABLE"
  echo "FPSEID21_CB3X3X3_H100_2STEP_PASS_END"
  if [ "$COST_DISTRIBUTION" = 1 ]; then
    "$SCRIPT_DIR/report_cb3x3x3_2step_costs.sh" \
      "$run_dir/dia-cb3x3x3_tm.out" "$COST_PLATFORM" \
      "$COST_DETAIL_TIMERS" GPU
  fi
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

preflight
case "$ACTION" in
  preflight) ;;
  tddft-2) run_two_steps ;;
esac
