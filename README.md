# Tractoflow UKBB
Workflow and utilities to prepare the UKBB dataset for [Tractoflow](https://github.com/scilus/tractoflow) pre-processing and to submit jobs to process the dataset

## Scripts
### [tf_run.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_run.sh)
Workflow `slurm` wrapper script for writing into ext3 loop mounted disk images
### [tf_run_ext3.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_run_ext3.sh) (deprecated don't use)
Workflow `slurm` wrapper script for writing into ext3 loop mounted disk images
### [tf_shell_ext3.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_shell_ext3.sh)
Debugging wrapper script that is identical to [tf_run_ext3.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_run_ext3.sh), except that it initiates a singularity shell session and does not run Nextflow, and thus Tractoflow does not run
### [tf_ukbb_bids_prep.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_ukbb_bids_prep.sh) *To be run inside a singularity shell session using the Tractoflow container* 
Prepares a working environment in the format that Tractoflow expects.  Specifically, it creates a symlink tree that is populated with links to the (squashfs overlayed) Neurohub UKB BIDS directories, which is to be used as the BIDS directory, it runs [scil_extract_b0.py](https://github.com/scilus/scilpy/blob/master/scripts/scil_extract_b0.py) , and creates `fmap/"${sub}"_ses-2_acq-PA_epi.json` 

## Background
### Issues and Solutions
On beluga the UKBiobank dataset is stored in squashfs files and are accessed by *overlay* mounting them within a singularity container, see [NeuroHub documentation](https://github.com/neurohub/neurohub_documentation/wiki/5.2.Accessing-Data#singularity-image).  The Tractoflow pipeline requires [Nextflow](https://www.nextflow.io) to manage the pipeline.  In the default configuration Tractoflow runs within a singularity container that is launched by nextflow.  This was impossible to run with the UKBB squashed dataset.  Nextflow would not pass the `--overlay` directives down to the singularity instance.  My solution is to invert the relationship: I run a Tractoflow singularity container that includes Nextflow within it.  In this way I can overlay the squashfs files onto the container instance, define a Tractoflow friendly BIDS compliant directory at the root, and then run the Tractoflow pipeline on that.

#### DWI Correction
Initially I was not able to get a complete run of Tractoflow on the UKBB BIDS dataset.  It failed, according to Arnaud, because tractoflow is not ready yet for a full AP/PA dwi correction and ends up with conflicts. He suggested that I do the following:
	
Choose which direction (AP or PA) will be the "main" direction.
1. use `scil_extract_b0.py` that's included in the Tractoflow singularity container to extract the file called `fmap/sub-*_epi.nii.gz`. 
2. Remove the "old", `PA` direction files from `/dwi`
3. Create a json file for this new file with the `IntendedFor` key pointing to the subject's `/dwi`

Squashfs files are by design read-only, so to make this work I created the symlink tree `/scratch/atrefo/sherbrooke/symtree`, illustrated below, and performed those operations into that tree using the `tf_ukbb_bids_prep.sh` script.

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

#### Missing PA_dwi.json files [Needs update]
There are about 8,000 subjects in the UKBB dataset without `*PA_dwi.json` files.  In our initial runs I simply ignored these subjects by removing the symlinks that point to their BIDS directory.  When the dwi dataset has been cleaned up by Lex the `tf_ukbb_bids_prep.sh` script will need to be re-run.  A check for already existing files could (should?) be run so we're not duplicating effort.  Note: it is also possible (likely?) that `scil_extract_b0.py`will have different results each time it's run, this shouldn't be an issue as long as the derivitives and the b0 extractions are from matched runs.

### inode Limits
beluga uses the Lustre distributed file system. File system performance suffers significantly with lots of files and so inode quotas are strictly enforced.  Tractoflow generartes 109 files for each subject.  A complete run of all 45,000 subjects would have an adverse effect on the performance of the file system, as well as running us over quota eventually.

### Process Run Time
beluga enforces a strict 7 day limit on process run time.  This will kill any process that runs for more than 7 days. Tractoflow has implemented a "resume" routine and we could resubmit the process when it gets killed.  This is not only inelegant but additionally the method leaves orphaned files when it is resumed after being killed.  In my testing the file count and bit count exploded drastically with only a few killed runs.  There is no on-the-fly garbage cleanup built in and so a routine would need to be implemented to take care of the cruft.

#### Mitigation:  ext3 writable file system images
For each run of 4 subjects I create a 20GB ext3 filesystem image to be used to capture the output from the run. 
The data from the ext3 images will need to be written out into squashfs images for publication for the Neurohub platform.  Below is the file structure that the final squashfs image should contain:

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
There are data produced by the pipeline that is used within the pipeline but is not neccessarily required for tractometry.  At the minimum the above can be used to determine the minimum set of files and paths that need to be retained.

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

## Running The Pipeline 
### Environment Setup
#### squashfs mounts
The followig UKBB squashfs inages are used for this pipeline:
```
  neurohub_ukbb_dwi_ses2_0_bids.squashfs
  neurohub_ukbb_dwi_ses2_1_bids.squashfs
  neurohub_ukbb_dwi_ses2_2_bids.squashfs
  neurohub_ukbb_t1_ses2_0_bids.squashfs
  neurohub_ukbb_t1_ses3_0_bids.squashfs
  neurohub_ukbb_participants.squashfs
  neurohub_ukbb_t1_ses2_0_jsonpatch.squashfs
  ```
#### symlink farms
There are two primary "symlink farms", `/dwipipeline` and `fakebids`.  These are file trees made up primarily of symlinks that point into the UKBiobank BIDS file tree. `/dwipipeline` is a symlink tree that only includes links to the subject files that have all the image data that tractoflow requires.  `/dwipipeline` is stored in a squashfs image at `/lustre03/project/6008063/atrefo/sherbrooke/TF_RUN/ext3_images/symtree.squashfs` that is overlayed in the tractoflow container.  `fakebids` is a file tree at `/lustre03/project/6008063/atrefo/sherbrooke/TF_RUN/fake_bids`   This could have been simplified in a number of ways, but this works.
##### creating
The logic for creating the symlink farms is in the [tf_ukbb_bids_prep.sh](https://github.com/neurodatascience/tractoflow_UKBB/blob/main/tf_ukbb_bids_prep.sh) script
#### ext3 images
The ext3 writable images are in /lustre03/project/6008063/atrefo/sherbrooke/TF_RUN/ext3_images/TF_raw. They are named by chunk, thus: `TF-raw-${chunk}.img` In order to be able to overlay mount the ext3 images they must be created with a file structre like this:
```
/top
 ├─ uppper
 └─ work
```
##### creating
Use a version of `mkfs.ext3` that supports the `-d directory` option. This command was run to create 9,581 initial 20GB ext3 images:
```
$ cd /lustre03/project/6008063/atrefo/sherbrooke/TF_RUN/ext3_images/TF_raw 
$ for i in {00000..09581}; do mkfs.ext3 -d top -F -m 0 -b 4096 -N 100000 ./TF-raw-$i.img 20g; done
```
It is important to set permissions on the `top` and `top/upper` directories, specifically they need to be world rw and must not have any extended ACLs applied.

### Submitting the batch job
	(*Lex: could you flesh this out, please?*)
### Monitoring
#### Checking on what's running
`sacct -u ahutton -S 10/16 -o Jobid%21,Start,End,Elapsed,State%20`
#### counting how many subjects have completed
```
$ cd projects/rpp-aevans-ab/atrefo/sherbrooke/TF_RUN/logs/
$ grep -w PFT_Tracking */trace.txt| wc -l
```

#### Programatic Sanity Checks
(*Etienne, please put some details in here, thanks*)

Etienne St-Onge wrote a set of scripts, one to gather data about the subjects, `scil_compute_avg_in_maps.pl` and one to calculate averages and find outliers
Here is an example comandline for runing [scil_compute_avg_in_maps.pl](https://github.com/StongeEtienne/scilpy/blob/avg_in_roi/scripts/scil_compute_avg_in_maps.pl)
```
for chunk in {00100..00999} ; 
 do echo Doing ${chunk} ;
  singularity exec --cleanenv \
  -B ext3_images/TF-OUT_symlink.img:/TF_OUT:image-src=/upper,ro \
  --overlay ext3_images/TF_raw/TF-raw-${chunk}.img:ro \
  -H /lustre03/project/6008063/atrefo/sherbrooke/TF_RUN \
  -B /lustre04/scratch/atrefo/sherbrooke/sanity_chk:/sanity_chk \
  tractoflow.sif \
  bin/tractoflow_UKB/sanity_check.sh; 
 done >> sanity_out/logs/scil_compute_avg_in_maps_1.log 2>&1  &
```
The log file is so you can monitor how it's running.  This should/could be keyed off the subjectIDs, but you will need to know the `chunk` number, because all the ext3 images are keyted off that number.  It should/could also be turned into either a slurm batch job or tacked on to the end of the tractoflow run.

I've done a preliminary run of that script, the results can be found in:
```
/lustre04/scratch/atrefo/sherbrooke/sanity_chk/scil_compute_avg_in_maps
```

This is a script to compute outliers:
[scil_compute_outliers_from_avg.py](https://github.com/StongeEtienne/scilpy/blob/avg_in_roi/scripts/scil_compute_outliers_from_avg.py)

The "--masks_name " and "--metrics_name" needs to be in the same order (from the scil_compute_avg_in_maps.py script)
(+ the "volume", if it was used with "--masks_sum"

For simplicity, the input is the list of .txt files.
It was the safest/easiest way to manage empty lines (missing subjects).
It sadly requires to be launched after the previous "scil_compute_avg_in_maps.py",
but it's very fast, so it can be computed on an interactive node (single core).
(The output/print is a list of outliers)

Example, it needs to be run in a tractoflow container (see below):
```
scil_compute_outliers_from_avg.py Sanity_Out/*.txt  \
    --masks_name   map_wm  map_csf  map_gm \
    --metrics_name  ad  fa  md  afd_total  volume
```
## Post Processing the output
### Collating Produced Data Into Squashfs Images
#### ext3 staging and rsyncing
The data needs to be packaged into squashfs images of about 2TB each.  To do this I propose the following process:

0. Create a 2.2T ext3 image
1. Mount as many 20G ext3 images as possible (I've successfully mounted 120 at a time, YMMV) along with a writable 2TB ext3 image into a singularity container with rsync installed.
2. rsync the data from the 20G ext3 images into the 2.2T image
3. Rinse repeat until the 2.2T image is full
4. go to 0

To create a 2.2TB ext3 image file:
```
mke2fs -t ext3 -d top -F -m 0 -N 2200000 neurohub_ukbb_tractoflow_00_derivatives.ext3 2200G
```
Check the image, fixing any problems:
```
e2fsck -yf neurohub_ukbb_tractoflow_00_derivatives.ext3
```

In order to rsync the individual runs into the 2.2TB image set the `SINGULARITY_BIND` variable like this, changing the $M setting to the range of the runs being worked on:
```
$ cd /lustre03/project/6008063/atrefo/sherbrooke/TF_RUN/ext3_images
$ export SINGULARITY_BIND=neurohub_ukbb_tractoflow_00_derivatives.ext3:/neurohub:image-src=/upper,\
`for M in {00000..00119}; do echo "TF-raw-${M}.img:/TF_OUT/${M}:image-src=/upper/${M},ro" | tr '\n' ',' ; done`
```
This is how to rsync the data:
```
$ singularity exec --cleanenv ubuntu_V20.sif \
  rsync -vaL /TF_OUT/*/sub-* /neurohub/ukbb/imaging/derivatives/tractoflow/ \
  --log-file=/ext3_images/neurohub_ukbb_tractoflow_00_derivatives.ext3.log
```

It can be sped up by making it parallel-ish:
```
rsync -aL /TF_OUT/{00120..00159}/sub-*  /neurohub/ukbb/imaging/derivatives/tractoflow/ --log-file=/ext3_images/neurohub_ukbb_tractoflow_01a_derivatives.log &
rsync -aL /TF_OUT/{00160..00199}/sub-*  /neurohub/ukbb/imaging/derivatives/tractoflow/ --log-file=/ext3_images/neurohub_ukbb_tractoflow_01b_derivatives.log &
rsync -aL /TF_OUT/{00200..00239}/sub-*  /neurohub/ukbb/imaging/derivatives/tractoflow/ --log-file=/ext3_images/neurohub_ukbb_tractoflow_01c_derivatives.log &
```
#### Creating Final squashfs images
 (*Lex,could you help with this part, please?*)

### Logs

Nextflow by default saves working logs in the directory from which it's launched, doing this will avoid clobbering.

```
LOG_DIR="${TASK_ROOT}/logs/${chunk}"
mkdir -p ${LOG_DIR}
TRACE_FILE="${LOG_DIR}/trace.txt"
cd ${LOG_DIR}
```
The nextflow trace logs can be found at:

```
/lustre03/project/6008063/atrefo/sherbrooke/TF_RUN/logs/<chunk>/trace.txt
```
To get a count of the successful tractoflow runs do this from within the `logs` directory:

`grep -w PFT_Tracking */trace.txt| wc -l`

The slurm logs are saved into the following directory (Lex is running the job so it's writing into his space):
```
/lustre04/scratch/ahutton/tractoflow_UKBB/slurm_out
```
The slurm logs can be consulted for runtime errors.

### After initial run - Cleanup
I've identified a number of reasons that a run could could fail:
#### Timeouts
In my initial testing it took between 12 and 18 hours clock-time to run a single subject or 4 subjects.  More than 4 subjects in a simgle run could take significantly more clock time.  We began runs using 20 hour runtime requests and noted 178 TIMEOUT errors out of 1000 chunks.  We increased the runtime request to 30 hours. As of this writing (oct 20, 2021) we've seen 66 more timeouts in 2,585 runs.  All of the chunks that timed out should be rerun with a longer runtime requested.  This could be done at the end of the initial run, or could be done in parallel.  NOTE: Before rerunning a chunk the ext3 images will need to be reset and the logs from the initial run moved out of the way.

Here is some example comandline code for resetting the ext3 image files for chunks that timed out (EXAMPLE ONLY! not fully tested, please confirm this makes sense before you run this):
```
$ cd TF_RUN
$ sacct -u ahutton -S 10/16 -o Jobid%21,Start,End,Elapsed,State%20| grep TIME | awk '{print $1}' | awk -F _ '{ printf "%05d \n", $2 }' >> timeout_chunks.txt
$ while read chunk; do mkfs.ext3 -d top -F -m 0 -b 4096 -N 100000 ext3_images/TF_raw/TF-raw-${chunk}.img 20g ; done < timeout_chunks.txt 
$ while read chunk; do e2fsck -yf ext3_images/TF_raw//TF-raw-${chunk}.img ; done < timeout_chunks.txt
```
You can find a list of the failures in a similar way:
```
$ sacct -u ahutton -S 10/16 -o Jobid%21,Start,End,Elapsed,State%20| grep FAILURE
```

Failures will need to be investigated to determine the actual reason for the failure.  It's likely that only a subset of the subjects in a given chunk will have failed, in which case it may make more sense to segregate the failed subject output from the successfull subjects, and then create new ext3 images with new chunk numbers and new fakebids directories for the subjects you want to re-run.
