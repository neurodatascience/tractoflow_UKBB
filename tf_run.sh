#!/bin/bash
#SBATCH --account=rpp-aevans-ab
#SBATCH --mail-user=adam.trefonides@mcgill.ca
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-type=REQUEUE
#SBATCH --mail-type=ALL
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=2G
#SBATCH --time=1-12:00:00

# --time is set with the assumption that these runs should take 21 hours
# with some slop
# This version of the script writes to the host filesystem


 if test $# -lt 1 ; then
    echo "Usage: $0 dwi_subs-[X] where X is a 2 to 4 character string"
    echo "      corresponding to the fake_BIDS directory name"
     exit 2
   fi

export FB=$1

# Work directory 
TASK_ROOT=/lustre03/project/6008063/atrefo/sherbrooke/TF_RUN

# Ouput directory
OUT_ROOT=/lustre03/project/6008063/atrefo/sherbrooke/TF_OUT/${FB}
mkdir ${OUT_ROOT}

# Current fake BIDS
BIDS_DIR="$TASK_ROOT/fake_bids/${FB}"

cd $TASK_ROOT || exit
cd $OUT_ROOT || exit
cd $BIDS_DIR || exit
cd $OUT_ROOT

SING_TF_IMAGE=$TASK_ROOT/tractoflow_2.1.0_feb64b9_2020-05-29.img

# UKBB squashfs files
UKBB_SQUASHFS_DIR=/project/6008063/neurohub/ukbb/imaging
UKBB_SQUASHFS="
  neurohub_ukbb_dwi_ses2_0_bids.squashfs
  neurohub_ukbb_dwi_ses2_1_bids.squashfs
  neurohub_ukbb_dwi_ses2_2_bids.squashfs
  neurohub_ukbb_dwi_ses2_3_bids.squashfs
  neurohub_ukbb_dwi_ses2_4_bids.squashfs
  neurohub_ukbb_dwi_ses2_5_bids.squashfs
  neurohub_ukbb_dwi_ses2_6_bids.squashfs
  neurohub_ukbb_dwi_ses2_7_bids.squashfs
  neurohub_ukbb_flair_ses2_0_bids.squashfs
  neurohub_ukbb_rfmri_ses2_0_bids.squashfs
  neurohub_ukbb_rfmri_ses2_1_bids.squashfs
  neurohub_ukbb_rfmri_ses2_2_bids.squashfs
  neurohub_ukbb_rfmri_ses2_3_bids.squashfs
  neurohub_ukbb_rfmri_ses2_4_bids.squashfs
  neurohub_ukbb_rfmri_ses2_5_bids.squashfs
  neurohub_ukbb_rfmri_ses2_6_bids.squashfs
  neurohub_ukbb_t1_ses2_0_bids.squashfs
  neurohub_ukbb_t1_ses3_0_bids.squashfs
  neurohub_ukbb_participants.squashfs
  neurohub_ukbb_t1_ses2_0_jsonpatch.squashfs
"
DWI_SQUASHFS_DIR=/lustre04/scratch/atrefo/sherbrooke/squash_tractoflow
DWI_SQUASHFS="
  dwipipeline.squashfs
"
SING_BINDS="-B $DWI_SQUASHFS_DIR -B $TASK_ROOT -H $TASK_ROOT"
UKBB_OVERLAYS=$(echo "" $UKBB_SQUASHFS | sed -e "s# # --overlay $UKBB_SQUASHFS_DIR/#g")
DWI_OVERLAYS=$(echo "" $DWI_SQUASHFS | sed -e "s# # --overlay $DWI_SQUASHFS_DIR/#g")

module load singularity

SINGULARITYENV_NXF_CLUSTER_SEED=$(shuf -i 0-16777216 -n 1) singularity exec --cleanenv -B ${OUT_ROOT} -H ${OUT_ROOT} $SING_BINDS $UKBB_OVERLAYS $DWI_OVERLAYS $SING_TF_IMAGE \
  nextflow run /tractoflow/main.nf        \
  --bids          ${BIDS_DIR}             \
  --output_dir    ${OUT_ROOT}             \
  -w              ${OUT_ROOT}/work        \
  --dti_shells    "1 1000"                \
  --fodf_shells   "0 1000 2000"           \
  --step          0.5                     \
  --mean_frf      false                   \
  --set_frf       true                    \
  --save_seeds    false                   \
  -profile        fully_reproducible      \
  -resume                                 \
  -with-report    report.html             \
  -with-timeline  timeline.html           \
  --processes     4                       \
  --processes_brain_extraction_t1 1       \
  --processes_denoise_dwi         2       \
  --processes_denoise_t1          2       \
  --processes_eddy                1       \
  --processes_fodf                2       \
  --processes_registration        1       \

# previous blank line intentional

