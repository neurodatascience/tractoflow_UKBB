#!/bin/bash

OUT_DIR=/OUT_DIR
BASE_DIR=/neurohub_01/ukbb/imaging/derivatives/tractoflow
SID_LIST=$1

while read SID 
 do

# Typical path example:
# /neurohub_00/ukbb/imaging/derivatives/tractoflow/sub-1000011_ses-2/Segment_Tissuess/sub-1000011_ses-2__mask_wm.nii.gz

scil_compute_avg_in_maps.py \
  ${BASE_DIR}/${SID}/Segment_Tissues/${SID}__map_wm.nii.gz \
  ${BASE_DIR}/${SID}/Segment_Tissues/${SID}__map_csf.nii.gz \
  ${BASE_DIR}/${SID}/Segment_Tissues/${SID}__map_gm.nii.gz \
  --metrics \
    ${BASE_DIR}/${SID}/DTI_Metrics/${SID}__ad.nii.gz \
    ${BASE_DIR}/${SID}/DTI_Metrics/${SID}__fa.nii.gz \
    ${BASE_DIR}/${SID}/DTI_Metrics/${SID}__md.nii.gz \
    ${BASE_DIR}/${SID}/FODF_Metrics/${SID}__afd_total.nii.gz \
  --indent 4 --masks_sum \
  --save_avg ${OUT_DIR}/${SID}__avg.txt

done < ${SID_LIST}
