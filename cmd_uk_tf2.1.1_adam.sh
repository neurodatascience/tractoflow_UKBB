#!/bin/bash

#SBATCH --account=rpp-aevans-ab
#SBATCH --mail-user=adam.trefonides@mcgill.ca
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-type=REQUEUE
#SBATCH --mail-type=ALL
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=160G
#SBATCH --time=100:00:00

export NXF_CLUSTER_SEED=$(shuf -i 0-16777216 -n 1)
export BIDS_DIR=/home/atrefo/scratch/UKBBIDS

module load java/1.8.0_192
module load nextflow/20.04.1
module load singularity/3.6

srun nextflow run tractoflow-2.1.1/main.nf \
--bids ${BIDS_DIR} \
--dti_shells "0 1000" \
--fodf_shells "0 1000 2000" \
-with-singularity tractoflow_2.1.0_feb64b9_2020-05-29.img \
-resume \
-with-report report.html \
--step 0.5 \
--mean_frf false \
--set_frf true \
-profile fully_reproducible \
-with-mpi \
--save_seeds false
