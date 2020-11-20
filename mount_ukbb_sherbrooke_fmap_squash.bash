#!/bin/bash
# ------------------------------------------
module load singularity/3.6
export BASEDIR=$HOME/projects/rpp-aevans-ab
export PROCDIR="${BASEDIR}/atrefo/sherbrooke/code_tractoflow"
imaging=${BASEDIR}/neurohub/ukbb/imaging 
tractoDir="/lustre04/scratch/atrefo/sherbrooke"
singularity shell \
        -B /home -B /project -B /scratch -B /localscratch \
        --overlay ${imaging}/neurohub_ukbb_dwi_ses2_0_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_dwi_ses2_1_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_dwi_ses2_2_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_dwi_ses2_3_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_dwi_ses2_4_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_dwi_ses2_5_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_dwi_ses2_6_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_dwi_ses2_7_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_t1_ses2_0_bids.squashfs:ro \
	--overlay ${imaging}/neurohub_ukbb_t1_ses3_0_bids.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_t1_ses2_0_jsonpatch.squashfs:ro \
        --overlay ${tractoDir}/dwipipeline_ukbb_efi_ses2_bids_linkfarm.squashfs:ro \
        --overlay ${imaging}/neurohub_ukbb_participants.squashfs:ro \
	${PROCDIR}/tractoflow_2.1.0_feb64b9_2020-05-29.img
