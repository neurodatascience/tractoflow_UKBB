#!/bin/bash
set -e -u

# This  script is intended to be run from within a singularity shell session that
# mounts the neurohub UKBB squash images, the shell script "tf_shell_ext3.sh" can
# be used for this.
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
### 2. Add routine
## ARGH!  really bad variable.  Need to turn these into CL arguments.

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
echo "removing links to subjects with missing PA_dwi.json files ..."
for sub in $(find ${bidsOUT} -maxdepth 1 -type d -iname "sub-*" -printf %P"\n" )
do
	if [ ! -f "${bidsIN}/${sub}/ses-2/dwi/${sub}_ses-2_acq-PA_dwi.json" ] ; then
		rm -r ${bidsOUT}/"${sub}"
		echo "Removed ${sub}"
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
	echo "Doing the b0 extraction on ${sub} ..."
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
	rm ${bidsOUT}/"${sub}"/ses-2/dwi/"${sub}"_ses-2_acq-PA_dwi*

	# After this script is run be sure to  run scil_validate_bids.py to make sure it comes up clean.
done
