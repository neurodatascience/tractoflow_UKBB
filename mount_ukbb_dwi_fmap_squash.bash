#!/bin/bash
# ------------------------------------------
module load singularity/3.6
export BASE_DIR=/projects/rpp-aevans-ab
export CMD_DIR="${BASEDIR}/atrefo/sherbrooke/code_tractoflow"
export UKB_SQSH=${BASEDIR}/neurohub/ukbb/imaging 
export DWI_SQSH="/lustre04/scratch/atrefo/sherbrooke"
export SUB_LIST="subs_${1}"
export BIDS_DIR=${SUB_LIST}

singularity shell \
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
        --overlay ${DWI_SQSH}/${SUB_LIST}.squashfs:ro \
	${CMD_DIR}/tractoflow_2.1.0_feb64b9_2020-05-29.img

