#!/bin/bash
bidsIN=$1
bidsOUT=$2

# Create symlinktree
cp -rs ${bidsIN} ${bidsOUT}

# Clean up subs that are missing the PA_dwi.json files
for sub in $(find ${bidsOUT} -maxdepth 1 -type d -iname "sub-*" -printf %P"\n" )
do
	if [ ! -f "${bidsIN}/${sub}/ses-2/dwi/${sub}_ses-2_acq-PA_dwi.json" ] ; then
		rm -r ${bidsOUT}/"${sub}"
	fi
done
# Main loop
for sub in $(find ${bidsOUT} -maxdepth 1 -type d -iname "sub-*" -printf %P"\n" )
do
	echo "working on ${sub}"
	[ ! -d "${bidsOUT}/${sub}/ses-2/fmap" ]
	echo "making ${bidsOUT}/${sub}/ses-2/fmap"
	mkdir -p "${bidsOUT}/${sub}/ses-2/fmap"

	# Do the b0 extraction
	scil_extract_b0.py \
		${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi.nii.gz \
		${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi.bval  \
		${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi.bvec  \
		${bidsOUT}/"${sub}"/ses-2/fmap/"${sub}"_ses-2_acq-PA_epi.nii.gz

	# Create the epi.json file
	cp ${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi.json ${bidsOUT}/"${sub}"/ses-2/fmap/"${sub}"_ses-2_acq-PA_epi.json

	# Add the "IntendedFor: key to the epi.json
	sed -i "s/{/{\n\t\"IntendedFor\":\ \"ses-2\/dwi\/${sub}_ses-2_acq-AP_dwi.nii.gz\",/g"  ${bidsOUT}/"${sub}"/ses-2/fmap/"${sub}"_ses-2_acq-PA_epi.json

	# Remove PA symlinks
	rm "${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi*
	# After this script is run be sure to  run scil_validate_bids.py to make sure it comes up clean.
done
