#!/bin/bash

#SBATCH --account=rpp-aevans-ab
#SBATCH --mail-user=adam.trefonides@mcgill.ca
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-type=REQUEUE
#SBATCH --mail-type=ALL
#SBATCH --output=slurm_out/%x-%j.out
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4
#SBATCH --time=0-12:00:00
#SBATCH --output=slurm_out/%x-%j.out

set -eu

# This version of the script is to prepare the dwi symtree 

# In case I forgot to clear $SINGULARITY_BIND
export SINGULARITY_BIND=""

# Work directory 
TASK_ROOT=/lustre03/project/6008063/atrefo/sherbrooke/TF_RUN
SYMTREE=${TASK_ROOT}/ext3_images/symtree.ext3
FAKEBIDS=${TASK_ROOT}/ext3_images/fakebids.squashfs
# use the following to create the fakebids image using mk_fakebids.sh
#FAKEBIDS=${TASK_ROOT}/ext3_images/fakebids.ext3

# Check that the working dir is there
cd $TASK_ROOT || exit

SING_TF_IMAGE=$TASK_ROOT/bin/ubuntu.sif
# SING_TF_IMAGE=$TASK_ROOT/tractoflow.sif

# UKBB squashfs files
UKBB_SQUASHFS_DIR=/project/6008063/neurohub/ukbb/imaging
UKBB_SQUASHFS="
  neurohub_ukbb_dwi_ses2_0_bids.squashfs
  neurohub_ukbb_dwi_ses2_1_bids.squashfs
  neurohub_ukbb_dwi_ses2_2_bids.squashfs
  neurohub_ukbb_t1_ses2_0_bids.squashfs
  neurohub_ukbb_t1_ses3_0_bids.squashfs
  neurohub_ukbb_t1_ses2_0_jsonpatch.squashfs
"

SING_BINDS=" -B ${SYMTREE}:/dwipipeline:image-src=/upper/neurohub,rw -B ${TASK_ROOT}:/TF_RUN "

#SING_BINDS=" -B ${FAKEBIDS}:/fakebids:image-src=/upper,ro  -B ${TASK_ROOT}/ext3_images/symtree.ext3:/symtree:image-src=/upper -B ${TASK_ROOT}:/TF_RUN "

UKBB_OVERLAYS=$(echo "" $UKBB_SQUASHFS | sed -e "s# # --overlay $UKBB_SQUASHFS_DIR/#g"),${FAKEBIDS}

module load singularity

singularity -d shell --cleanenv $SING_BINDS $UKBB_OVERLAYS --overlay ${TASK_ROOT}/ext3_images/neurohub_ukbb_dwi_participants.squashfs $SING_TF_IMAGE

#singularity -d shell --cleanenv $SING_BINDS $UKBB_OVERLAYS -B ${TASK_ROOT}/ext3_images/neurohub_ukbb_dwi_participants.ext3:/PARTS:image-src=/upper,rw $SING_TF_IMAGE
