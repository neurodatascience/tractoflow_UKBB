# Tractoflow UKBB
Workflow and utilities to prepare the UKBB dataset for [Tractoflow](https://github.com/scilus/tractoflow) pre-processing

On beluga the UKBiobank dataset is stored in squashfs files and are accessed by *overlay* mounting them within a singularity container.  The Tractoflow pipeline requires [Nextflow](https://www.nextflow.io) to manage the pipeline.  In the default configuration Tractoflow runs within a singularity container that is launched by nextflow.  This was impossible to run with the UKBB squashed dataset.  Nextflow would not pass the --overlay directives down to the singularithy instance.  My solution is to invert the relationship: I run a Tractoflow singularity container that includes Nextflow in it.  In this way I can get the squashfs files overlayed onto the container instance, define a BIDS compliant directory at the root, and run the Tractoflow pipeline on that.
## Scripts
### `tf_ukbb_bids_prep.sh`
(To be run inside a singularity shell session using the Tractoflow container) Prepares a symlink tree to use as the BIDS directory in the format that Tractoflow expects.  Specifically, it creates a symlink tree that is populated with links to the (squashfs overlayed) Neurohub UKB BIDS directories, runs [scil_extract_b0.py](https://github.com/scilus/scilpy/blob/master/scripts/scil_extract_b0.py) , and creates `fmap/"${sub}"_ses-2_acq-PA_epi.json` 
### Issues and Solutions
#### dwi correction
I was not able to get a complete run of Tractoflow on the UKBB BIDS dataset.  It failed, according to Arnaud, because tractoflow is not ready yet for a full AP/PA dwi correction and ends up with conflicts. He suggested that we do the following:
	
Choose which direction (AP or PA) will be the "main" direction.
1. use `scil_extract_b0.py` that's included in the Tractoflow singularity container to extract the file called `fmap/sub-*_epi.nii.gz`. 
2. Remove the "old", `PA` direction files from `/dwi`
3. Create a json file for this new file with the `IntendedFor` key pointing to the subject's `/dwi`

Squashfs files are, by design read-only, and of course we don't want to mess with the UKBB raw files, so to make this work I created the symlink tree `/scratch/atrefo/sherbrooke/symtree`, illustrated below, and performed those operations into that tree using the `tf_ukbb_bids_prep.sh` script.

``` 
/neurohub/ukbb/imaging/sub-*/ses-2/
.
├── anat
│   ├── sub-*_ses-2_T1w.json -> /neurohub/ukbb/imaging/sub-*/ses-2/anat/sub-*_ses-2_T1w.json
│   └── sub-*_ses-2_T1w.nii.gz -> /neurohub/ukbb/imaging/sub-*/ses-2/anat/sub-*_ses-2_T1w.nii.gz
│   
├──dwi
│   ├── sub-*_ses-2_acq-AP_dwi.bval -> /neurohub/ukbb/imaging/sub-*/ses-2/dwi/sub-*_ses-2_acq-AP_dwi.bval
│   ├── sub-*_ses-2_acq-AP_dwi.bvec -> /neurohub/ukbb/imaging/sub-*/ses-2/dwi/sub-*_ses-2_acq-AP_dwi.bvec
│   ├── sub-*_ses-2_acq-AP_dwi.json -> /neurohub/ukbb/imaging/sub-*/ses-2/dwi/sub-*_ses-2_acq-AP_dwi.json
│   └── sub-*_ses-2_acq-AP_dwi.nii.gz -> /neurohub/ukbb/imaging/sub-*/ses-2/dwi/sub-*_ses-2_acq-AP_dwi.nii.gz
└──fmap
    ├── sub-*_ses-2_acq-PA_epi.json
    └── sub-*_ses-2_acq-PA_epi.nii.gz
```
I deleted the symlinks that pointed to the PA direction files and saved that as a squashfs image.  By overlaying that squashfs onto the contianer along with the UKBB squashfs images I can point at the file tree in it 
#### Missing PA_dwi.json files
There are about 8,000 subjects in the UKBB dataset without `*PA_dwi.json` files.  I simply ignored these subjects by removing the symlinks that point to their BIDS directory.  When the dwi dataset has been cleaned up by Lex the `tf_ukbb_bids_prep.sh` script will need to be re-run.  A check for already existing files could (should?) be run so we're not duplicating effort and also it's possible (likely?) that `scil_extract_b0.py`will have different results each time it's run.

### inode Limits
#### ext3 writable file system images
### Performance and Scalability
#### Slurm Resource Allocation
#### Sweet Spot
