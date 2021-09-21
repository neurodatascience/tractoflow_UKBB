#!/bin/bash
#set -e -u

# This  script is intended to be run from within a singularity shell session
# started with tractoflow_UKB/tf_shell_symtree.sh
# Once it is finished the resulting symlink farm can be squashed up and overlayed 
# onto the tractoflow singularity container to run the pipeline.
#
## TODO:
## Error control:
### 1. check for existing symlinktree directory, only create if needed
### 2. Do something more inteligent with the subjects with missing PA_dwi.json files
## NiceToHaves:
### 1. include this script into a singularity image that also includes
### scil_extract_b0.py

workDIR="/symtree"
bidsIN="/neurohub/ukbb/imaging"
bidsOUT="${workDIR}/neurohub/ukbb/imaging"

#mkdir -p ${workDIR}

# Create symlinktree
#echo "Creating symlink tree"
# cp -rs /neurohub ${workDIR}

# Clean up subs that are missing the PA_dwi.json files
# (Once the DTI BIDS is cleaned up this shoudn't be needed)
#
## disabling the following check so I can run the scil_extract_b0.py after an interuption
# echo "removing links to subjects with missing PA_dwi.json files ..."
# for sub in $(find ${bidsOUT} -maxdepth 1 -type d -iname "sub-*" -printf %P"\n" )
# do
# 	if [ ! -f "${bidsIN}/${sub}/ses-2/dwi/${sub}_ses-2_acq-PA_dwi.json" ] ; then
# 		rm -r ${bidsOUT}/"${sub}"
# 		echo "Removed ${sub}"
# 	fi
# done

# Main loop

## disabling this search so I can run scil_extract_b0.py after an interuption:
# for sub in $(find ${bidsOUT} -maxdepth 1 -type d -iname "sub-*" -printf %P"\n" )
# 

for sub in `grep sub-$1 /TF_RUN/sanity_out/b0_notdone.txt`
do
	echo "working on ${sub}"
	[ ! -d "${bidsOUT}/${sub}/ses-2/fmap" ]
	echo "making ${bidsOUT}/${sub}/ses-2/fmap"
	mkdir -p "${bidsOUT}/${sub}/ses-2/fmap"

        [ ! -f "${bidsOUT}/"${sub}"/ses-2/fmap/"${sub}"_ses-2_acq-PA_epi.nii.gz" ]
	# Do the b0 extraction
		echo "Doing the b0 extraction on ${sub} ..."
		scil_extract_b0.py --mean   --b0_thr 50 \
			${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi.nii.gz \
			${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi.bval  \
			${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi.bvec  \
			${bidsOUT}/"${sub}"/ses-2/fmap/"${sub}"_ses-2_acq-PA_epi.nii.gz

	# Create the epi.json file
		cp ${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi.json ${bidsOUT}/"${sub}"/ses-2/fmap/"${sub}"_ses-2_acq-PA_epi.json
	
	# Add the "IntendedFor: key to the epi.json
		sed -i "s/{/{\n\t\"IntendedFor\":\ \"ses-2\/dwi\/${sub}_ses-2_acq-AP_dwi.nii.gz\",/g"  ${bidsOUT}/"${sub}"/ses-2/fmap/"${sub}"_ses-2_acq-PA_epi.json

	# Remove PA symlinks
		rm ${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi*
		echo "${sub}" >> /TF_RUN/sanity_out/b0_done_$1.txt
	# After this script is run be sure to  run scil_validate_bids.py to make sure it comes up clean.
done 
