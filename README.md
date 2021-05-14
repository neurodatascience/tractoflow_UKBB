# Tractoflow UKBB
Workflow and utilities to prepare the UKBB dataset for [Tractoflow](https://github.com/scilus/tractoflow) pre-processing

## Scripts
### [tf_run.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_run.sh)
Workflow `slurm` wrapper script for writing output directly to the host filesystem, (depricated)
### [tf_run_ext3.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_run_ext3.sh)
Workflow `slurm` wrapper script for writing into ext3 loopback mounted disk images
### [tf_shell_ext3.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_shell_ext3.sh)
Debugging wrapper script that is identical to [tf_run_ext3.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_run_ext3.sh), except that it initiates a singularity shell session and does not run Nextflow, and thus Tractoflow does not run
### [tf_ukbb_bids_prep.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_ukbb_bids_prep.sh) *To be run inside a singularity shell session using the Tractoflow container* 
Prepares a working environment in the format that Tractoflow expects.  Specifically, it creates a symlink tree that is populated with links to the (squashfs overlayed) Neurohub UKB BIDS directories, which is to be used as the BIDS directory, it runs [scil_extract_b0.py](https://github.com/scilus/scilpy/blob/master/scripts/scil_extract_b0.py) , and creates `fmap/"${sub}"_ses-2_acq-PA_epi.json` 

## Background
### Issues and Solutions
On beluga the UKBiobank dataset is stored in squashfs files and are accessed by *overlay* mounting them within a singularity container.  The Tractoflow pipeline requires [Nextflow](https://www.nextflow.io) to manage the pipeline.  In the default configuration Tractoflow runs within a singularity container that is launched by nextflow.  This was impossible to run with the UKBB squashed dataset.  Nextflow would not pass the `--overlay` directives down to the singularithy instance.  Our solution is to invert the relationship: we run a Tractoflow singularity container that includes Nextflow within it.  In this way we can overlay the squashfs files onto the container instance, define a Tractoflow friendly BIDS compliant directory at the root, and then run the Tractoflow pipeline on that.

#### DWI Correction
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
There are about 8,000 subjects in the UKBB dataset without `*PA_dwi.json` files.  In our initial runs we simply ignored these subjects by removing the symlinks that point to their BIDS directory.  When the dwi dataset has been cleaned up by Lex the `tf_ukbb_bids_prep.sh` script will need to be re-run.  A check for already existing files could (should?) be run so we're not duplicating effort.  Note: it is also possible (likely?) that `scil_extract_b0.py`will have different results each time it's run, this shouldn't be an issue as long as the derivitives and the b0 extractions are from matched runs.

### inode Limits
beluga uses the Lustre distributed file system. File system performance suffers significantly with lots of files and so inode quotas are strictly enforced.  Tractoflow generartes 109 files for each subject.  A complete run of all 40,000 subjects would have an adverse effect on the performance of the file system, as well as running us over quota eventually.

### Process Run Time
beluga enforces a strict 7 day limit on process run time.  This will kill any process that runs for more than 7 days. Tractoflow has implemented a "resume" routine and we could resubmit the process when it gets killed.  This is not only inelegant additionally the method leaves orphaned files when it is resumed after being killed.  In my testing the file count and bit count exploded drastically with only a few killed runs.  There is no on the fly garbage cleanup built in and so a routine would need to be implemented to take care of the cruft.  There is no slurm style checkpointing and so running it with slurm arrays is not useful.

#### ext3 writable file system images
For each run of 4 subjects I create a 20GB ext3 filesystem image to be used to capture the output from the run. 

From inside an ubuntu singularity image this command is run to create 240 initial 20GB ext3 images:

`for i in {00000..00239}; do echo "mkfs.ext3 -d top -F -m 0 -b 4096 -N 100000 ./TF-raw-$i.img 20g"; done`


Approximately 80 2TB ext3 images will eventually be created, one for every 480 subjects (120 runs).  When 120 runs have been completed the 120 ext3 images get mounted into a singularity container along with an empty 2TB ext3 image.  The derivative files will be rsynced from the 20GB images into the 2TB image.  This will then be saved as a squashfs image as described below: NOTE: *Describe it*

rsync is run to move the files out of the work directory from each subject and into the 2TB image.  At the minimum the following file and paths need to be retained:

```
/neurohub
 └─ ukbb
    └─ imaging
       └─ derivatives
         └─ tractoflow
            ├── sub-XXXX-sess-YYY
            │   ├── DTI_Metrics/*
            │   ├── Eddy/sub__bval_eddy
            │   ├── Eddy/sub__dwi_eddy_corrected.bvec
            │   ├── FODF_Metrics/*
            │   ├── Local_Seeding_Mask/*
            │   ├── Local_Tracking/*
            │   ├── Local_Tracking_Mask/*
            │   ├── Register_T1/sub__t1_warped.nii.gz
            │   ├── Resample_B0/*
            │   ├── Resample_DWI/sub__dwi_resampled.nii.gz
            │   └── Segment_Tissues/*
            │
            ├── sub-ZZZ-sess-YYY
            │   ├── DTI_Metrics/*
            │   ├── ....
            ....
```
### Initial Sanity Check
A very simple check was run on a set of 4 subjects.  I ran the same 4 subjects twice and then rsynced the files from their work directories into the beluga filesystem.  In the root of each set of output files I ran this simple find:

`find -type f -printf %h"/"%f\\t%s\\n | sort > zaaa_f_sizes.tsv`

`find -type f -printf %h"/"%f\\t%s\\n | sort > zaaa-test_f_sizes.tsv`
Producing output similar to this:
```
./derivatives/tractoflow/sub-XXX_ses-2/DTI_Metrics/sub-XXX_ses-2__evecs_v1.nii.gz       18759868
./derivatives/tractoflow/sub-XXX_ses-2/DTI_Metrics/sub-XXX_ses-2__evecs_v2.nii.gz       18813128
...
```
I then ran a UNIX `comm` , (compare) to pull out any disimilar lines:

`comm -3 zaaa_f_sizes.tsv zaaa-test_f_sizes.tsv`

I found that there are 38 files for each subject that differs in bit size.  See [zaaa-f_differ.tsv](zaaa-f_differ.tsv) for the list.

Guillaume confirmed the irreproducibility problem and found an error in the way the random seed was being set and updated the `main.nf` file with:

`export ANTS_RANDOM_SEED=1234` https://github.com/scilus/tractoflow/pull/46

Guillaume ran four subjects twice and confirmed that there the runs were identical. Adam ran a similar test with an updated container supplied by Arnaud and there were no differences in file size between the two runs. 
## Running Environment Setup
Simple bash loop is used to submit sbatch tf_run_ext3.sh jobs:
```
for i in {00002..00239} ; do sbatch --job-name=TFUKBB-$i bin/tf_run_ext3.sh $i ; done
```
NOTES: 

To create a 2.2TB ext3 image file:
```
/usr/sbin/mke2fs -t ext3 -F -m 0 -N 2200000 neurohub_ukbb_tractoflow_00_derivatives.ext3 2200G
```
Check the image, fixing any problems:
```
e2fsck -yf neurohub_ukbb_tractoflow_00_derivatives.ext3
```

In order to rsync the individual runs into the 2.2TB image set the `SINGULARITY_BIND` variable like this, changing the $M setting to the range of the runs being worked on:
```
export SINGULARITY_BIND=home_atrefo.img:/home/atrefo:image-src=/upper/atrefo,\
neurohub_ukbb_tractoflow_00_derivatives.ext3:/neurohub:image-src=/upper,\
`for M in {00000..00119}; do echo "TF-raw-${M}.img:/TF_OUT/${M}:image-src=/upper/${M},ro" | tr '\n' ',' ; done`
```
This is how to rsync the data:
```
rsync -vaL /TF_OUT/*/sub-* /neurohub/ukbb/imaging/derivatives/tractoflow/ --log-file=/ext3_images/neurohub_ukbb_tractoflow_00_derivatives.ext3.log
```
It can be sped up by making it parallel-ish:
```
rsync -aL /TF_OUT/{00120..00159}/sub-*  /neurohub/ukbb/imaging/derivatives/tractoflow/ --log-file=/ext3_images/neurohub_ukbb_tractoflow_01a_derivatives.log &
rsync -aL /TF_OUT/{00160..00199}/sub-*  /neurohub/ukbb/imaging/derivatives/tractoflow/ --log-file=/ext3_images/neurohub_ukbb_tractoflow_01b_derivatives.log &
rsync -aL /TF_OUT/{00200..00239}/sub-*  /neurohub/ukbb/imaging/derivatives/tractoflow/ --log-file=/ext3_images/neurohub_ukbb_tractoflow_01c_derivatives.log &
```
### Programatic Sanity Checks
`sanity_check_example.sh` is an example of running the first level of a simple sanity check using the script written by Etienne St-Onge called `scil_compute_avg_in_maps.py` on the TF output.  It generates a comma delimited set of results from an analysis of the derived images  *I need Etienne to fill out some details here*

This sets `SINGULARITY_BIND` to mount the 2TB ext3 image and a directory on the host that is used for the sanity check output: 
```
$ cd /lustre03/project/6008063/atrefo/sherbrooke/TF_RUN

$ export SINGULARITY_BIND= \
ext3_images/neurohub_ukbb_tractoflow_00_derivatives.ext3:/neurohub_00:image-src=/upper,ro\
/lustre03/project/6008063/atrefo/sherbrooke/TF_RUN/sanity_out:/OUT_DIR:rw

$ singularity -v shell --cleanenv tractoflow.sif
```
To run the `sanity_check_example.sh` You may need to get this directory in your path:
```
Singularity> PATH=$PATH:/home/atrefo/bin/tractoflow_UKBB
Singularity> sanity_check_example.sh SID00.list
```
This oneliner cats the output from all the sanity checks into a single file, inserting a linefeed between subjects:
```
Singularity> while read SID ; do cat /OUT_DIR/${SID}__avg.txt >> SID_all00.lf; echo  >> SID_all00.lf ;done < SID00.list
```

From Etienne:
I managed to get some time and created a script to compute outliers :
https://github.com/StongeEtienne/scilpy/blob/avg_in_roi/scripts/scil_compute_outliers_from_avg.py

For simplicity, the input is the list of .txt files.
It was the safest/easiest way to manage empty lines (missing subjects).
It sadly requires to be launched after the previous "scil_compute_avg_in_maps.py",
but it's very fast, so it can be computed on an interactive node (single core).
(The output/print is a list of outliers)


```python scil_compute_outliers_from_avg.py Sanity_Out/*.txt  \
    --masks_name   map_wm  map_csf  map_gm \
    --metrics_name  ad  fa  md  afd_total  volume
```
The "--masks_name " and "--metrics_name" needs to be in the same order (from the previous script)
(+ the "volume", if it was used with "--masks_sum"
```scil_compute_avg_in_maps.py \
  ${SID}/Segment_Tissues/${SID}__map_wm.nii.gz \
  ${SID}/Segment_Tissues/${SID}__map_csf.nii.gz \
  ${SID}/Segment_Tissues/${SID}__map_gm.nii.gz \
  --metrics \
    ${SID}/DTI_Metrics/${SID}__ad.nii.gz \
    ${SID}/DTI_Metrics/${SID}__fa.nii.gz \
    ${SID}/DTI_Metrics/${SID}__md.nii.gz \
    ${SID}/FODF_Metrics/${SID}__afd_total.nii.gz \
  --indent 4 --masks_sum \
  --save_avg ${SID}__avg.txt
```

### Logs
*Stuff about logging here, ie.: some logs are going into the ext3 image, some are being written to the filesystem, there is method to the madness, document it*

Nextflow logs
slurm.out

### Performance and Scalability
*stuff about why 4 subjects is sweet sweet majik*
#### Slurm Resource Allocation
#### Sweet Spot
