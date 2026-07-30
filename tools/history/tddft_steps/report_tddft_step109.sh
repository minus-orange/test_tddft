#!/bin/sh
set -eu

# Read the existing Step 109 archive without rebuilding or rerunning.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
LABEL=${LABEL:-nvhpc_cufft_1rank_02_STEP109_STEP107_SEPPOTF_ACC_SPLIT_01}
ARCHIVE_DIR=$ROOT_DIR/run/tddft_archives/$LABEL

if [ ! -f "$ARCHIVE_DIR/tddft.out" ]; then
  echo "ERROR: Step 109 archive is missing: $ARCHIVE_DIR" >&2
  exit 1
fi

echo
echo "FPSEID21 STEP109 EXISTING-ARCHIVE TIMER DEBUG"
echo "source_revision=f3d6082"
echo "label=$LABEL"
echo "No build or rerun; values come from the existing Step 109 archive."
echo "FPSEID_STEP109_DEBUG_BEGIN"
awk '
  /FPSEID_PROFILE_BEGIN/ { active=1; next }
  /FPSEID_PROFILE_END/ { active=0 }
  active && ($1 >= 132 && $1 <= 144) {
    print
    count[$2]=$3
  }
  END {
    legacy=count["seppotf_phase"]
    legacy+=count["seppotf_s_projector"]
    legacy+=count["seppotf_s_band_reduce"]
    legacy+=count["seppotf_p_projector"]
    legacy+=count["seppotf_p_band_reduce"]
    batch=count["seppotf_acc_project"]
    batch+=count["seppotf_acc_s_batch"]
    batch+=count["seppotf_acc_p_batch"]
    batch+=count["seppotf_acc_final"]
    batch+=count["seppotf_acc_download"]
    if (batch > 0) {
      print "derived observed_path batched"
    } else if (legacy > 0) {
      print "derived observed_path legacy"
    } else {
      print "derived observed_path unresolved"
    }
  }
' "$ARCHIVE_DIR/tddft.out"
echo "FPSEID_STEP109_DEBUG_END"
