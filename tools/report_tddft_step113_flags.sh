#!/bin/sh
set -eu

# Compare existing Step 113 option-screen archives with the same-session build.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ARCHIVE_ROOT=${ARCHIVE_ROOT:-"$ROOT_DIR/run/tddft_archives"}
MPI_FC=${MPI_FC:-mpifort}
NVFORTRAN=${NVFORTRAN:-nvfortran}
SOURCE_REVISION=05fd3c4f58847417c9e62d14cdcf7981939935a9
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

validate_archive() {
  tag=$1
  expected_flags=$2
  archive_dir=$ARCHIVE_ROOT/nvhpc_cufft_1rank_02_STEP113_FLAGS_${tag}_01
  metadata=$archive_dir/step113.env

  if [ ! -f "$archive_dir/tddft.out" ] ||
     [ ! -f "$archive_dir/tddft.err" ] ||
     [ ! -f "$metadata" ]; then
    echo "ERROR: incomplete Step 113 archive: $archive_dir" >&2
    exit 1
  fi
  archived_revision=$(sed -n 's/^revision=//p' "$metadata")
  archived_flags=$(sed -n 's/^flags=//p' "$metadata")
  if [ "$archived_revision" != "$SOURCE_REVISION" ] ||
     [ "$archived_flags" != "$expected_flags" ]; then
    echo "ERROR: Step 113 archive provenance mismatch: $tag" >&2
    exit 1
  fi
}

validate_archive BASELINE \
  "$BASE_FLAGS -gpu=mem:separate:pinnedalloc"
validate_archive O3 \
  "-O3 -acc -gpu=cc80 -mp -Msave -Mlarge_arrays -gpu=mem:separate:pinnedalloc"
validate_archive IPA \
  "$BASE_FLAGS -Mipa=fast,inline -gpu=mem:separate:pinnedalloc"
validate_archive FASTMATH \
  "-O2 -acc -gpu=cc80,fastmath -mp -Msave -Mlarge_arrays -gpu=mem:separate:pinnedalloc"

reference=$ARCHIVE_ROOT/nvhpc_cufft_1rank_02_STEP113_FLAGS_BASELINE_01
summary_lines=

compare_variant() {
  tag=$1
  test_dir=$ARCHIVE_ROOT/nvhpc_cufft_1rank_02_STEP113_FLAGS_${tag}_01

  if ! python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$reference/tddft.out" "$test_dir/tddft.out" \
      --ref-err "$reference/tddft.err" \
      --test-err "$test_dir/tddft.err" \
      --expected-steps 100 >/dev/null; then
    echo "ERROR: pairwise relaxed comparison failed: $tag" >&2
    python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$reference/tddft.out" "$test_dir/tddft.out" \
      --ref-err "$reference/tddft.err" \
      --test-err "$test_dir/tddft.err" \
      --expected-steps 100 || true
    exit 1
  fi

  strict=PASS
  if strict_output=$(python3 "$SCRIPT_DIR/check_tddft_result.py" compare \
      "$reference/tddft.out" "$test_dir/tddft.out" \
      --ref-err "$reference/tddft.err" \
      --test-err "$test_dir/tddft.err" \
      --expected-steps 100 --strict 2>&1); then
    :
  else
    strict=FAIL
  fi

  metrics=$(printf '%s\n' "$strict_output" | awk '
    $1 == "ETOT:" {
      split($2,value,"=")
      etot=value[2]
    }
    $1 ~ /^Eelec\+Enucl-Eext-Ework:/ {
      split($2,value,"=")
      energy=value[2]
    }
    $1 == "force:" {
      split($2,value,"=")
      force=value[2]
    }
    $1 == "positions:" {
      split($2,value,"=")
      position=value[2]
    }
    $1 == "velocities:" {
      split($2,value,"=")
      velocity=value[2]
    }
    END {
      printf "%s %s %s %s %s", etot, energy, force, position, velocity
    }
  ')
  summary_lines="${summary_lines}
$tag PASS $strict $metrics"
}

compare_variant O3
compare_variant IPA
compare_variant FASTMATH

compiler=$("$NVFORTRAN" -V 2>&1 |
  sed -n '/[^[:space:]]/{p;q;}' || true)
mpi_driver=$("$MPI_FC" -show 2>&1 | sed -n '1p' || true)
device=$(nvidia-smi --query-gpu=name,driver_version \
  --format=csv,noheader 2>/dev/null | sed -n '1p' || true)

echo
echo "FPSEID21 STEP113 EXISTING-ARCHIVE PAIRWISE SUMMARY"
echo "archive_revision=$SOURCE_REVISION"
echo "reference=BASELINE"
echo "compiler=$compiler"
echo "mpi_driver=$mpi_driver"
echo "device=$device"
echo "FPSEID_FLAGS_PAIRWISE_BEGIN"
echo "variant relaxed strict etot_diff energy_diff force_diff position_diff velocity_diff"
printf '%s\n' "$summary_lines" | sed '/^[[:space:]]*$/d'
echo "FPSEID_FLAGS_PAIRWISE_END"
echo "Values compare each option directly with the same-session BASELINE archive."
echo "No build or simulation was run; the official baseline is unchanged."
