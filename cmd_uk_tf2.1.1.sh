#!/bin/sh

#SBATCH --mail-user=maxime.descoteaux@gmail.com
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-type=REQUEUE
#SBATCH --mail-type=ALL

#SBATCH --nodes=3
#SBATCH --cpus-per-task=40
#SBATCH --mem=185G
#SBATCH --time=200:00:00

export NXF_CLUSTER_SEED=$(shuf -i 0-16777216 -n 1)

srun nextflow run tractoflow-2.1.1/main.nf --bids ~/projects/rrg-descotea/datasets/ukb34138 --dti_shells "0 1000" --fodf_shells "0 1000 2000" -with-singularity tractoflow_2.1.0_feb64b9_2020-05-29.img -resume -with-report report.html --step 0.5 --mean_frf false --set_frf true -profile fully_reproducible -with-mpi --save_seeds false













