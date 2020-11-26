#!/bin/bash

#SBATCH --account=rpp-aevans-ab
#SBATCH --mail-user=adam.trefonides@mcgill.ca
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-type=REQUEUE
#SBATCH --mail-type=ALL
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=160G
#SBATCH --time=100:00:00
#SBATCH --output=${CMD_DIR}/%x-%j.out

export NXF_CLUSTER_SEED=$(shuf -i 0-16777216 -n 1)

export BASE_DIR="/project/rpp-aevans-ab"
export CMD_DIR="${BASE_DIR}/atrefo/sherbrooke/code_tractoflow"
export UKB_SQSH="${BASE_DIR}/neurohub/ukbb/imaging"
export DWI_SQSH="/lustre04/scratch/atrefo/sherbrooke/squash_tractoflow"
export SUB_LIST="00"
export BIDS_DIR=/scratch/UKBBIDS

module load java/1.8.0_192
module load nextflow/20.04.1
module load singularity/3.6

srun nextflow run tractoflow-2.1.1/main.nf \
	--bids ${BIDS_DIR} \
	--dti_shells "0 1000" \
	--fodf_shells "0 1000 2000" \
	-with-singularity \
	-B /home -B /project -B /scratch -B /localscratch \
	--overlay ${UKB_SQSH}/neurohub_ukbb_dwi_ses2_0_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_dwi_ses2_1_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_dwi_ses2_2_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_dwi_ses2_3_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_dwi_ses2_4_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_dwi_ses2_5_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_dwi_ses2_6_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_dwi_ses2_7_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_t1_ses2_0_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_t1_ses3_0_bids.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_t1_ses2_0_jsonpatch.squashfs:ro \
	--overlay ${UKB_SQSH}/neurohub_ukbb_participants.squashfs:ro \
	--overlay ${DWI_SQSH}/dwipipeline.squashfs:ro \
	--overlay ${DWI_SQSH}/subs_${SUB_LIST}.squashfs:ro \
	${PROCDIR}/tractoflow_2.1.0_feb64b9_2020-05-29.img \
	-resume \
	-with-report report.html \
	--step 0.5 \
	--mean_frf false \
	--set_frf true \
	-profile fully_reproducible \
	-with-mpi \
	--save_seeds false
