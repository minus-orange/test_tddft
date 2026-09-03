#!/bin/sh
set -eu

# Isolated cb3x3x3 lineage diagnostic:
#
#   existing validated ifx CG state
#     -> NVFORTRAN SD (-O1 -Kieee, one OpenMP thread)
#     -> NVFORTRAN CPU/FFTW TDDFT (two steps only)
#
# The canonical ifx SD state and every existing platform result are read-only.
# Each expensive stage remains a separate human-review gate.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

ACTION=${1:-}
EXPECTED_SKU=${EXPECTED_SKU:-8468}
BENCHMARK_ROOT=${BENCHMARK_ROOT:-"$ROOT_DIR/run/benchmarks/cb3x3x3"}
WORK_ROOT=$BENCHMARK_ROOT/work
CG_DIR=$WORK_ROOT/cg
IFX_SD_DIR=$WORK_ROOT/sd
CANONICAL_STATE_DIR=$WORK_ROOT/tddft_600K
NVFORTRAN=${NVFORTRAN:-nvfortran}
SD_OMP_NUM_THREADS=1
OMP_STACKSIZE=${OMP_STACKSIZE:-512M}
SD_FLAGS="-O1 -mp -Msave -Mlarge_arrays -Kieee"

usage() {
  cat <<'EOF'
Usage: ./tools/run_cb3x3x3_nvfortran_sd_chain.sh ACTION

Actions:
  preflight  Read-only validation of Git, the Xeon 8468 host, NVFORTRAN,
             official inputs, existing ifx CG state, and ifx SD reference.
  sd         Re-run preflight, build isolated NVFORTRAN SD with the historical
             validated -O1/-Kieee flags, run from a private copy of the ifx CG
             state, relaxed-compare with ifx SD, and create a private TDDFT
             state only if the comparison passes.
  tddft-2    Require the private SD state, then run the existing isolated
             NVFORTRAN CPU/FFTW TDDFT diagnostic for exactly two steps.

SD is fixed to one OpenMP thread to match the previously validated Si111-H
compiler-lineage experiment. TDDFT remains fixed to 32 MPI x 3 OpenMP on the
dual-socket Xeon 8468. There is no 100-step or baseline-adoption action.
Run and review each action separately. Existing CG, canonical SD/TDDFT state,
and platform results are never replaced.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    fail "required command was not found: $1"
}

require_file() {
  [ -f "$1" ] || fail "required file is missing: $1"
}

require_nonempty() {
  [ -s "$1" ] || fail "required file is missing or empty: $1"
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

verify_provenance_hash() {
  file=$1
  key=$2
  payload=$3
  expected=$(provenance_value "$key" "$file")
  [ -n "$expected" ] || fail "$file does not record $key"
  actual=$(sha256_file "$payload")
  [ "$actual" = "$expected" ] ||
    fail "$key does not match $payload"
}

copy_text_lf_new() {
  source_file=$1
  destination_file=$2
  [ ! -e "$destination_file" ] && [ ! -L "$destination_file" ] ||
    fail "path already exists; refusing to overwrite: $destination_file"
  LC_ALL=C tr -d '\r' < "$source_file" > "$destination_file"
}

copy_binary_new() {
  source_file=$1
  destination_file=$2
  [ ! -e "$destination_file" ] && [ ! -L "$destination_file" ] ||
    fail "path already exists; refusing to overwrite: $destination_file"
  partial=$destination_file.part.$$
  [ ! -e "$partial" ] || fail "stale partial file exists: $partial"
  cp -p "$source_file" "$partial"
  mv "$partial" "$destination_file"
}

link_new() {
  target=$1
  link=$2
  [ ! -e "$link" ] && [ ! -L "$link" ] ||
    fail "path already exists; refusing to overwrite: $link"
  ln -s "$target" "$link"
}

release_build_lock() {
  if [ -n "${build_lock:-}" ] && [ -d "$build_lock" ]; then
    rmdir "$build_lock" 2>/dev/null || true
  fi
}

set_paths() {
  revision=$(git_repo rev-parse HEAD)
  short_revision=$(git_repo rev-parse --short=12 HEAD)
  host_name=$(hostname -s 2>/dev/null || hostname)
  platform_id=$(printf 'nvfortran_cpu_%s_%s' "$EXPECTED_SKU" "$host_name" |
    tr '[:upper:]' '[:lower:]' | tr '+.' 'pp')
  CHAIN_ROOT=$BENCHMARK_ROOT/platforms/$platform_id/chains/ifx_cg_nvfortran_sd/$short_revision
  STANDARD_FFTW_ROOT=$BENCHMARK_ROOT/platforms/$platform_id/deps/fftw-3.3.11-gcc-pthreads/install
  SD_BIN_DIR=$CHAIN_ROOT/bin
  SD_BUILD_ROOT=$CHAIN_ROOT/build
  SD_RUN_DIR=$CHAIN_ROOT/sd
  CHAIN_STATE_DIR=$CHAIN_ROOT/state
  CHAIN_TDDFT_ROOT=$CHAIN_ROOT/tddft
}

verify_ifx_cg() {
  cg_provenance=$CG_DIR/CG_PROVENANCE.env
  require_nonempty "$cg_provenance"
  require_provenance_value "$cg_provenance" cg_check PASS
  require_nonempty "$CG_DIR/rh.dia-cb3x3x3_new"
  require_nonempty "$CG_DIR/wf_fft.dia-cb3x3x3_new"
  require_nonempty "$CG_DIR/wf_real.dia-cb3x3x3"
  require_nonempty "$CG_DIR/dia-cb3x3x3.in"
  verify_provenance_hash "$cg_provenance" input_sha256 \
    "$CG_DIR/dia-cb3x3x3.in"
  verify_provenance_hash "$cg_provenance" density_sha256 \
    "$CG_DIR/rh.dia-cb3x3x3_new"
  verify_provenance_hash "$cg_provenance" wf_fft_sha256 \
    "$CG_DIR/wf_fft.dia-cb3x3x3_new"
  verify_provenance_hash "$cg_provenance" wf_real_sha256 \
    "$CG_DIR/wf_real.dia-cb3x3x3"

  cg_host=$(provenance_value hostname "$cg_provenance")
  cg_sku=$(provenance_value sku "$cg_provenance")
  [ -n "$cg_host" ] && [ -n "$cg_sku" ] ||
    fail "CG provenance does not identify its host and SKU"
  cg_platform_id=$(printf '%s_%s' "$cg_sku" "$cg_host" |
    tr '[:upper:]' '[:lower:]' | tr '+.' 'pp')
  cg_platform_bin=$BENCHMARK_ROOT/platforms/$cg_platform_id/bin
  cg_platform_provenance=$cg_platform_bin/BUILD_PROVENANCE.env
  require_nonempty "$cg_platform_provenance"
  ifx_version=$(provenance_value ifx "$cg_platform_provenance")
  case "$ifx_version" in
    *ifx*|*IFX*|*Intel*) ;;
    *) fail "CG platform build is not identified as ifx: ${ifx_version:-MISSING}" ;;
  esac
  require_nonempty "$cg_platform_bin/cg_exe"
  verify_provenance_hash "$cg_provenance" executable_sha256 \
    "$cg_platform_bin/cg_exe"
  verify_provenance_hash "$cg_platform_provenance" cg_exe_sha256 \
    "$cg_platform_bin/cg_exe"
}

sd_force_count() {
  awk '
    /TOTAL FORCE:/ {in_force=1; next}
    in_force && NF == 4 && $1 ~ /^[0-9]+$/ {count++; next}
    in_force && count > 0 && NF != 4 {exit}
    END {print count + 0}
  ' "$1"
}

verify_ifx_sd_reference() {
  require_nonempty "$IFX_SD_DIR/dia-cb3x3x3_sd.out"
  require_file "$IFX_SD_DIR/dia-cb3x3x3_sd.err"
  require_nonempty "$IFX_SD_DIR/SD_PROVENANCE.env"
  require_provenance_value "$IFX_SD_DIR/SD_PROVENANCE.env" sd_check PASS
  verify_provenance_hash "$IFX_SD_DIR/SD_PROVENANCE.env" input_sha256 \
    "$IFX_SD_DIR/dia-cb3x3x3_sd.in"
  verify_provenance_hash "$IFX_SD_DIR/SD_PROVENANCE.env" \
    cg_provenance_sha256 "$CG_DIR/CG_PROVENANCE.env"
  cg_revision=$(provenance_value revision "$CG_DIR/CG_PROVENANCE.env")
  sd_revision=$(provenance_value revision "$IFX_SD_DIR/SD_PROVENANCE.env")
  [ "$sd_revision" = "$cg_revision" ] ||
    fail "ifx CG and SD reference revisions differ: CG=$cg_revision SD=$sd_revision"
  python3 "$SCRIPT_DIR/compare_sd_result.py" check \
    "$IFX_SD_DIR/dia-cb3x3x3_sd.out" \
    --err "$IFX_SD_DIR/dia-cb3x3x3_sd.err" >/dev/null
  force_count=$(sd_force_count "$IFX_SD_DIR/dia-cb3x3x3_sd.out")
  [ "$force_count" -eq 216 ] ||
    fail "ifx SD reference has $force_count force rows; expected 216"

  sd_host=$(provenance_value hostname "$IFX_SD_DIR/SD_PROVENANCE.env")
  sd_sku=$(provenance_value sku "$IFX_SD_DIR/SD_PROVENANCE.env")
  [ -n "$sd_host" ] && [ -n "$sd_sku" ] ||
    fail "SD provenance does not identify its host and SKU"
  sd_platform_id=$(printf '%s_%s' "$sd_sku" "$sd_host" |
    tr '[:upper:]' '[:lower:]' | tr '+.' 'pp')
  sd_platform_bin=$BENCHMARK_ROOT/platforms/$sd_platform_id/bin
  sd_platform_provenance=$sd_platform_bin/BUILD_PROVENANCE.env
  require_nonempty "$sd_platform_provenance"
  ifx_version=$(provenance_value ifx "$sd_platform_provenance")
  case "$ifx_version" in
    *ifx*|*IFX*|*Intel*) ;;
    *) fail "SD platform build is not identified as ifx: ${ifx_version:-MISSING}" ;;
  esac
  require_nonempty "$sd_platform_bin/sd_exe"
  verify_provenance_hash "$IFX_SD_DIR/SD_PROVENANCE.env" executable_sha256 \
    "$sd_platform_bin/sd_exe"
  verify_provenance_hash "$sd_platform_provenance" sd_exe_sha256 \
    "$sd_platform_bin/sd_exe"
}

verify_chain_state() {
  require_nonempty "$CHAIN_STATE_DIR/rh.dia-cb3x3x3"
  require_nonempty "$CHAIN_STATE_DIR/wf_fft.dia-cb3x3x3"
  require_nonempty "$CHAIN_STATE_DIR/STATE_MANIFEST.sha256"
  require_nonempty "$CHAIN_STATE_DIR/STATE_PROVENANCE.env"
  require_provenance_value "$CHAIN_STATE_DIR/STATE_PROVENANCE.env" \
    sd_normal_check PASS
  require_provenance_value "$CHAIN_STATE_DIR/STATE_PROVENANCE.env" \
    sd_relaxed_compare PASS
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$CHAIN_STATE_DIR" && sha256sum -c STATE_MANIFEST.sha256 >/dev/null) ||
      fail "private TDDFT state SHA-256 validation failed"
  else
    (cd "$CHAIN_STATE_DIR" && shasum -a 256 -c STATE_MANIFEST.sha256 >/dev/null) ||
      fail "private TDDFT state SHA-256 validation failed"
  fi
}

preflight() {
  for command_name in git awk grep tr tar ldd lscpu python3 cp mv df stat "$NVFORTRAN"; do
    require_command "$command_name"
  done
  [ "$EXPECTED_SKU" = 8468 ] ||
    fail "this diagnostic is fixed to EXPECTED_SKU=8468"

  # Reuse the established read-only host, memory, MPI, FFTW, reference, state,
  # and synchronized-Git checks. Its normal output is folded into this chain's
  # smaller photograph-friendly summary.
  EXPECTED_SKU="$EXPECTED_SKU" BENCHMARK_ROOT="$BENCHMARK_ROOT" \
    "$SCRIPT_DIR/run_cb3x3x3_nvfortran_cpu.sh" preflight >/dev/null

  set_paths
  verify_ifx_cg
  verify_ifx_sd_reference
  require_nonempty "$STANDARD_FFTW_ROOT/include/fftw3.f"
  if [ ! -f "$STANDARD_FFTW_ROOT/lib/libfftw3.a" ] &&
     [ ! -f "$STANDARD_FFTW_ROOT/lib/libfftw3.so" ]; then
    fail "controlled FFTW root does not contain libfftw3: $STANDARD_FFTW_ROOT"
  fi
  if [ ! -f "$STANDARD_FFTW_ROOT/lib/libfftw3_threads.a" ] &&
     [ ! -f "$STANDARD_FFTW_ROOT/lib/libfftw3_threads.so" ]; then
    fail "controlled FFTW root does not contain libfftw3_threads: $STANDARD_FFTW_ROOT"
  fi

  for rel in \
    dia-cb3x3x3_sd.in TR.C95g_asci Avec Eext Etot Ework laser.dat size.dat sym.C1
  do
    require_file "$IFX_SD_DIR/$rel"
  done
  for rel in \
    dia-cb3x3x3_tm.in_2steps SOURCE_MANIFEST.env TR.C95g_asci \
    Avec Cartesian.velo Eext Etot Ework laser.dat size.dat sym.C1
  do
    require_file "$CANONICAL_STATE_DIR/$rel"
  done

  cg_state_bytes=$(stat -c '%s' \
    "$CG_DIR/rh.dia-cb3x3x3_new" \
    "$CG_DIR/wf_fft.dia-cb3x3x3_new" \
    "$CG_DIR/wf_real.dia-cb3x3x3" | awk '{sum += $1} END {print sum}')
  disk_available_kib=$(df -Pk "$BENCHMARK_ROOT" | awk 'END {print $4}')
  disk_available_bytes=$(awk -v kib="$disk_available_kib" \
    'BEGIN {printf "%.0f", kib*1024}')
  required_workspace_bytes=$(awk -v bytes="$cg_state_bytes" \
    'BEGIN {printf "%.0f", bytes*3}')
  awk -v have="$disk_available_bytes" -v need="$required_workspace_bytes" \
    'BEGIN {exit !(have >= need)}' ||
    fail "insufficient disk space for private SD inputs and outputs"

  nvfortran_version=$("$NVFORTRAN" -V 2>&1 | awk 'NF {print; exit}')
  cg_revision=$(provenance_value revision "$CG_DIR/CG_PROVENANCE.env")
  cg_hostname=$(provenance_value hostname "$CG_DIR/CG_PROVENANCE.env")
  ifx_sd_revision=$(provenance_value revision "$IFX_SD_DIR/SD_PROVENANCE.env")

  echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_CHAIN_PREFLIGHT_BEGIN"
  echo "revision=$revision"
  echo "accepted_numerical_source=c46cfa9"
  echo "pending_correctness_candidate=bb5cb58"
  echo "hostname=$host_name"
  echo "sku=$EXPECTED_SKU"
  echo "compiler=$nvfortran_version"
  echo "sd_flags=$SD_FLAGS"
  echo "sd_omp_num_threads=$SD_OMP_NUM_THREADS"
  echo "lineage=IFX_CG_TO_NVFORTRAN_SD_TO_NVFORTRAN_CPU_TDDFT"
  echo "ifx_cg_revision=$cg_revision"
  echo "ifx_cg_hostname=$cg_hostname"
  echo "ifx_cg_platform_provenance=$cg_platform_provenance"
  echo "ifx_cg_state_gate=PASS"
  echo "ifx_sd_reference_revision=$ifx_sd_revision"
  echo "ifx_sd_platform_provenance=$sd_platform_provenance"
  echo "ifx_sd_reference_gate=PASS"
  echo "private_chain_root=$CHAIN_ROOT"
  echo "private_chain_state=$CHAIN_STATE_DIR"
  echo "controlled_fftw_root=$STANDARD_FFTW_ROOT"
  echo "controlled_fftw_gate=PASS"
  echo "cg_state_bytes=$cg_state_bytes"
  echo "required_workspace_bytes=$required_workspace_bytes"
  echo "disk_available_bytes=$disk_available_bytes"
  echo "canonical_state_mutation=FORBIDDEN"
  echo "existing_platform_result_mutation=FORBIDDEN"
  echo "next_action=REVIEW_THEN_RUN_SD"
  echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
  echo "preflight_gate=PASS"
  echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_CHAIN_PREFLIGHT_END"
}

build_sd() {
  mkdir -p "$ROOT_DIR/.cache" "$SD_BIN_DIR" "$SD_BUILD_ROOT"
  executable=$SD_BIN_DIR/sd_exe
  provenance=$SD_BIN_DIR/BUILD_PROVENANCE.env
  nvfortran_version=$("$NVFORTRAN" -V 2>&1 | awk 'NF {print; exit}')
  if [ -s "$executable" ] && [ -s "$provenance" ] &&
     grep -Fqx "revision=$revision" "$provenance" &&
     grep -Fqx "compiler=$nvfortran_version" "$provenance" &&
     grep -Fqx "flags=$SD_FLAGS" "$provenance"; then
    echo "Reusing revision-specific NVFORTRAN SD executable: $executable"
    return 0
  fi
  [ ! -e "$executable" ] && [ ! -e "$provenance" ] ||
    fail "incomplete or mismatched SD build exists: $SD_BIN_DIR"

  build_lock=$ROOT_DIR/.cache/cb3x3x3_nvfortran_sd_chain_build.lock
  if ! mkdir "$build_lock" 2>/dev/null; then
    fail "another cb3x3x3 NVFORTRAN SD chain build appears active"
  fi
  trap release_build_lock EXIT HUP INT TERM

  stamp=$(date '+%Y%m%d_%H%M%S')
  build_tree=$SD_BUILD_ROOT/${short_revision}_${stamp}_$$
  mkdir -p "$build_tree"
  git_repo archive HEAD FPSEID21/sd_GGA_f_compact_code | tar -x -C "$build_tree"
  source_dir=$build_tree/FPSEID21/sd_GGA_f_compact_code
  build_log=$build_tree/build.log
  echo "Building isolated NVFORTRAN SD: $SD_FLAGS"
  build_status=0
  (
    cd "$source_dir"
    FC="$NVFORTRAN" FFLAGS="$SD_FLAGS" OUT="$executable.part.$$" \
      ./mk_ifort.sh
  ) >"$build_log" 2>&1 || build_status=$?
  if [ "$build_status" -ne 0 ]; then
    echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_BEGIN"
    echo "stage=build"
    echo "outcome=BUILD_FAILURE"
    echo "exit_status=$build_status"
    echo "build_log=$build_log"
    echo "build_log_tail_begin"
    tail -n 30 "$build_log" 2>/dev/null || true
    echo "build_log_tail_end"
    echo "simulation_started=NO"
    echo "next_action=STOP_AND_REVIEW"
    echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_END"
    exit 1
  fi
  require_nonempty "$executable.part.$$"
  mv "$executable.part.$$" "$executable"
  chmod a-w "$executable"

  ldd_output=$(ldd "$executable" 2>&1)
  if printf '%s\n' "$ldd_output" | grep -q 'not found'; then
    printf '%s\n' "$ldd_output" >&2
    fail "NVFORTRAN SD executable has an unresolved shared library"
  fi
  if printf '%s\n' "$ldd_output" | grep -q 'libgomp'; then
    printf '%s\n' "$ldd_output" >&2
    fail "NVFORTRAN SD executable unexpectedly links GCC libgomp"
  fi
  printf '%s\n' "$ldd_output" | grep -q 'libnvomp' ||
    fail "NVFORTRAN SD executable does not link NVHPC libnvomp"

  {
    echo "revision=$revision"
    echo "accepted_numerical_source=c46cfa9"
    echo "compiler=$nvfortran_version"
    echo "flags=$SD_FLAGS"
    echo "omp_num_threads=$SD_OMP_NUM_THREADS"
    echo "openmp_runtime=NVHPC_LIBNVOMP_ONLY"
    echo "executable_sha256=$(sha256_file "$executable")"
    echo "build_source_tree=$build_tree"
    echo "build_log=$build_log"
  } > "$provenance"
  chmod a-w "$provenance"

  release_build_lock
  trap - EXIT HUP INT TERM
  echo "sd_build_gate=PASS"
  echo "sd_executable=$executable"
}

prepare_sd_run() {
  [ ! -e "$SD_RUN_DIR" ] ||
    fail "private SD run already exists; refusing to overwrite: $SD_RUN_DIR"
  mkdir -p "$SD_RUN_DIR"
  for rel in \
    dia-cb3x3x3_sd.in TR.C95g_asci Avec Eext Etot Ework laser.dat size.dat sym.C1
  do
    copy_text_lf_new "$IFX_SD_DIR/$rel" "$SD_RUN_DIR/$rel"
  done

  echo "Copying the validated ifx CG state into the private SD run"
  copy_binary_new "$CG_DIR/rh.dia-cb3x3x3_new" \
    "$SD_RUN_DIR/rh.dia-cb3x3x3"
  copy_binary_new "$CG_DIR/wf_fft.dia-cb3x3x3_new" \
    "$SD_RUN_DIR/wf_fft.dia-cb3x3x3"
  copy_binary_new "$CG_DIR/wf_real.dia-cb3x3x3" \
    "$SD_RUN_DIR/wf_real.dia-cb3x3x3"
  chmod a-w \
    "$SD_RUN_DIR/rh.dia-cb3x3x3" \
    "$SD_RUN_DIR/wf_fft.dia-cb3x3x3" \
    "$SD_RUN_DIR/wf_real.dia-cb3x3x3"

  link_new rh.dia-cb3x3x3 "$SD_RUN_DIR/fort.20"
  link_new wf_fft.dia-cb3x3x3 "$SD_RUN_DIR/fort.22"
  link_new wf_real.dia-cb3x3x3 "$SD_RUN_DIR/fort.88"
  link_new TR.C95g_asci "$SD_RUN_DIR/fort.41"
  link_new laser.dat "$SD_RUN_DIR/fort.53"
  link_new size.dat "$SD_RUN_DIR/fort.54"
  link_new sym.C1 "$SD_RUN_DIR/fort.55"
}

install_private_state() {
  [ ! -e "$CHAIN_STATE_DIR" ] ||
    fail "private TDDFT state already exists: $CHAIN_STATE_DIR"
  mkdir -p "$CHAIN_STATE_DIR"
  copy_binary_new "$SD_RUN_DIR/fort.24" \
    "$CHAIN_STATE_DIR/rh.dia-cb3x3x3"
  copy_binary_new "$SD_RUN_DIR/fort.23" \
    "$CHAIN_STATE_DIR/wf_fft.dia-cb3x3x3"

  for rel in \
    dia-cb3x3x3_tm.in_2steps SOURCE_MANIFEST.env TR.C95g_asci \
    Avec Cartesian.velo Eext Etot Ework laser.dat size.dat sym.C1
  do
    copy_text_lf_new "$CANONICAL_STATE_DIR/$rel" "$CHAIN_STATE_DIR/$rel"
  done

  (
    cd "$CHAIN_STATE_DIR"
    {
      echo "$(sha256_file rh.dia-cb3x3x3)  rh.dia-cb3x3x3"
      echo "$(sha256_file wf_fft.dia-cb3x3x3)  wf_fft.dia-cb3x3x3"
    } > STATE_MANIFEST.sha256
  )
  {
    echo "revision=$revision"
    echo "accepted_numerical_source=c46cfa9"
    echo "pending_correctness_candidate=bb5cb58"
    echo "lineage=IFX_CG_TO_NVFORTRAN_SD"
    echo "ifx_cg_provenance=$CG_DIR/CG_PROVENANCE.env"
    echo "ifx_cg_provenance_sha256=$(sha256_file "$CG_DIR/CG_PROVENANCE.env")"
    echo "nvfortran_sd_provenance=$SD_RUN_DIR/SD_PROVENANCE.env"
    echo "nvfortran_sd_provenance_sha256=$(sha256_file "$SD_RUN_DIR/SD_PROVENANCE.env")"
    echo "sd_normal_check=PASS"
    echo "sd_relaxed_compare=PASS"
    echo "density_sha256=$(sha256_file "$CHAIN_STATE_DIR/rh.dia-cb3x3x3")"
    echo "wf_fft_sha256=$(sha256_file "$CHAIN_STATE_DIR/wf_fft.dia-cb3x3x3")"
    echo "canonical_state_mutated=NO"
  } > "$CHAIN_STATE_DIR/STATE_PROVENANCE.env"
  chmod a-w "$CHAIN_STATE_DIR"/*
  verify_chain_state
}

run_sd() {
  build_sd
  prepare_sd_run
  executable=$SD_BIN_DIR/sd_exe
  {
    echo "revision=$revision"
    echo "accepted_numerical_source=c46cfa9"
    echo "pending_correctness_candidate=bb5cb58"
    echo "lineage=IFX_CG_TO_NVFORTRAN_SD"
    echo "compiler=$("$NVFORTRAN" -V 2>&1 | awk 'NF {print; exit}')"
    echo "flags=$SD_FLAGS"
    echo "omp_num_threads=$SD_OMP_NUM_THREADS"
    echo "omp_stacksize=$OMP_STACKSIZE"
    echo "input_line_endings=LF_PRIVATE_COPY"
    echo "ifx_cg_provenance=$CG_DIR/CG_PROVENANCE.env"
    echo "ifx_cg_density_sha256=$(sha256_file "$CG_DIR/rh.dia-cb3x3x3_new")"
    echo "ifx_cg_wf_fft_sha256=$(sha256_file "$CG_DIR/wf_fft.dia-cb3x3x3_new")"
    echo "ifx_cg_wf_real_sha256=$(sha256_file "$CG_DIR/wf_real.dia-cb3x3x3")"
    echo "ifx_sd_reference=$IFX_SD_DIR/dia-cb3x3x3_sd.out"
    echo "sd_executable_sha256=$(sha256_file "$executable")"
  } > "$SD_RUN_DIR/SD_PROVENANCE.env"

  echo "Running private cb3x3x3 NVFORTRAN SD with OMP_NUM_THREADS=1"
  run_status=0
  (
    cd "$SD_RUN_DIR"
    ulimit -s unlimited 2>/dev/null || true
    OMP_NUM_THREADS="$SD_OMP_NUM_THREADS" OMP_STACKSIZE="$OMP_STACKSIZE" \
      "$executable" < dia-cb3x3x3_sd.in \
      > dia-cb3x3x3_sd.out 2> dia-cb3x3x3_sd.err
  ) || run_status=$?
  echo "$run_status" > "$SD_RUN_DIR/sd_exit_status.txt"

  for pair in \
    "rh.dia-cb3x3x3_new rh.dia-cb3x3x3" \
    "wf_fft.dia-cb3x3x3_new wf_fft.dia-cb3x3x3" \
    "wf_real.dia-cb3x3x3 wf_real.dia-cb3x3x3"
  do
    set -- $pair
    [ "$(sha256_file "$CG_DIR/$1")" = "$(sha256_file "$SD_RUN_DIR/$2")" ] ||
      fail "private SD input changed during execution: $2"
  done

  if [ "$run_status" -ne 0 ]; then
    echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_BEGIN"
    echo "stage=run"
    echo "outcome=PROCESS_FAILURE"
    echo "exit_status=$run_status"
    echo "run_dir=$SD_RUN_DIR"
    echo "stderr_tail_begin"
    tail -n 30 "$SD_RUN_DIR/dia-cb3x3x3_sd.err" 2>/dev/null || true
    echo "stderr_tail_end"
    echo "ifx_cg_input_postrun_sha256_gate=PASS"
    echo "private_tddft_state=NOT_CREATED"
    echo "next_action=STOP_AND_REVIEW"
    echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_END"
    exit 1
  fi

  require_nonempty "$SD_RUN_DIR/fort.24"
  require_nonempty "$SD_RUN_DIR/fort.23"
  if ! normal_summary=$(python3 "$SCRIPT_DIR/compare_sd_result.py" check \
      "$SD_RUN_DIR/dia-cb3x3x3_sd.out" \
      --err "$SD_RUN_DIR/dia-cb3x3x3_sd.err" 2>&1); then
    echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_BEGIN"
    echo "stage=normal_check"
    echo "outcome=NORMAL_CHECK_FAIL"
    echo "run_dir=$SD_RUN_DIR"
    printf '%s\n' "$normal_summary"
    echo "ifx_cg_input_postrun_sha256_gate=PASS"
    echo "private_tddft_state=NOT_CREATED"
    echo "next_action=STOP_AND_REVIEW"
    echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_END"
    exit 1
  fi
  force_count=$(sd_force_count "$SD_RUN_DIR/dia-cb3x3x3_sd.out")
  [ "$force_count" -eq 216 ] ||
    fail "NVFORTRAN SD has $force_count force rows; expected 216"
  printf '%s\n' "$normal_summary"

  if ! comparison_summary=$(python3 "$SCRIPT_DIR/compare_sd_result.py" compare \
      "$SD_RUN_DIR/dia-cb3x3x3_sd.out" \
      --reference "$IFX_SD_DIR/dia-cb3x3x3_sd.out" \
      --ref-err "$IFX_SD_DIR/dia-cb3x3x3_sd.err" \
      --test-err "$SD_RUN_DIR/dia-cb3x3x3_sd.err" 2>&1); then
    {
      echo "sd_normal_check=PASS"
      echo "sd_relaxed_compare=FAIL"
      echo "ifx_cg_input_postrun_sha256_gate=PASS"
    } >> "$SD_RUN_DIR/SD_PROVENANCE.env"
    echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_BEGIN"
    echo "stage=relaxed_compare"
    echo "outcome=RELAXED_COMPARE_FAIL"
    echo "run_dir=$SD_RUN_DIR"
    echo "comparison_output_begin"
    printf '%s\n' "$comparison_summary"
    echo "comparison_output_end"
    echo "ifx_cg_input_postrun_sha256_gate=PASS"
    echo "private_tddft_state=NOT_CREATED"
    echo "next_action=STOP_AND_REVIEW"
    echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_END"
    exit 1
  fi
  printf '%s\n' "$comparison_summary"
  {
    echo "sd_normal_check=PASS"
    echo "sd_force_atoms=$force_count"
    echo "sd_relaxed_compare=PASS"
    echo "ifx_cg_input_postrun_sha256_gate=PASS"
  } >> "$SD_RUN_DIR/SD_PROVENANCE.env"

  install_private_state
  echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_BEGIN"
  echo "revision=$revision"
  echo "outcome=CORRECTNESS_PASS"
  echo "lineage=IFX_CG_TO_NVFORTRAN_SD"
  echo "configuration=NVFORTRAN_SD_O1_KIEEE_1_OPENMP"
  echo "run_dir=$SD_RUN_DIR"
  echo "state_dir=$CHAIN_STATE_DIR"
  echo "normal_check=PASS"
  echo "force_atoms=$force_count"
  echo "relaxed_compare=PASS"
  echo "ifx_cg_input_postrun_sha256_gate=PASS"
  echo "canonical_state_mutated=NO"
  echo "next_action=REVIEW_THEN_RUN_TDDFT_2"
  echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
  echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_RESULT_END"
}

run_tddft_two_steps() {
  verify_chain_state
  timestamp=$(date '+%Y%m%d_%H%M%S')
  label="cb3x3x3_${platform_id}_ifx_cg_nvfortran_sd_2step_${timestamp}_${short_revision}"
  echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_CHAIN_TDDFT_BEGIN"
  echo "revision=$revision"
  echo "lineage=IFX_CG_TO_NVFORTRAN_SD_TO_NVFORTRAN_CPU_TDDFT"
  echo "state_dir=$CHAIN_STATE_DIR"
  echo "platform_root=$CHAIN_TDDFT_ROOT"
  echo "label=$label"
  echo "steps=2"
  echo "hundred_step_authorization=BLOCKED_DIAGNOSTIC_ONLY"
  echo "FPSEID21_CB3X3X3_NVFORTRAN_SD_CHAIN_TDDFT_END"
  STATE_DIR="$CHAIN_STATE_DIR" \
    NVFORTRAN_PLATFORM_ROOT="$CHAIN_TDDFT_ROOT" \
    NVFORTRAN_FFTW_ROOT="$STANDARD_FFTW_ROOT" \
    EXPECTED_SKU="$EXPECTED_SKU" BENCHMARK_ROOT="$BENCHMARK_ROOT" \
    LABEL="$label" "$SCRIPT_DIR/run_cb3x3x3_nvfortran_cpu.sh" tddft-2
}

case "$ACTION" in
  -h|--help|help|'')
    usage
    [ -n "$ACTION" ] || exit 2
    exit 0
    ;;
  preflight|sd|tddft-2) ;;
  *) usage >&2; fail "unknown action: $ACTION" ;;
esac

preflight

case "$ACTION" in
  preflight) ;;
  sd) run_sd ;;
  tddft-2) run_tddft_two_steps ;;
esac
