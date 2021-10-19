#!/bin/bash

export PATH=$PATH:~/bin
OUT_DIR=/sanity_chk/scil_compute_avg_in_maps
for SID in $(find / -maxdepth 1 -type d -iname "sub-*" -printf %P"\n" )
 do
 echo "Checking ${SID}"
  scil_compute_avg_in_maps.py \
    /${SID}/Segment_Tissues/${SID}__map_wm.nii.gz \
    /${SID}/Segment_Tissues/${SID}__map_csf.nii.gz \
    /${SID}/Segment_Tissues/${SID}__map_gm.nii.gz \
    --metrics \
      /${SID}/DTI_Metrics/${SID}__ad.nii.gz \
      /${SID}/DTI_Metrics/${SID}__fa.nii.gz \
      /${SID}/DTI_Metrics/${SID}__md.nii.gz \
      /${SID}/FODF_Metrics/${SID}__afd_total.nii.gz \
    --indent 4 --masks_sum \
    --save_avg ${OUT_DIR}/${SID}__avg.txt
done 
