#!/bin/bash

#SBATCH --partition=amilan
#SBATCH --account=csu54_alpine1
#SBATCH --chdir=/scratch/alpine/eslawler@colostate.edu/egpd_fires/
#SBATCH --qos=normal
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=30
#SBATCH --time=2:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=eslawler@colostate.edu

export TMPDIR=/scratch/alpine/$USER/tmp/
export TMP=${TMPDIR}
export TEMP=${TMPDIR}
export TEMPDIR=${TMPDIR}
mkdir -p $TMPDIR

source /curc/sw/anaconda3/2022.10/etc/profile.d/conda.sh
conda activate lawler

Rscript --vanilla ./scores_traceplots/submodel_traceplots_scores.R \
${modtype} ${modname} ${params} ${dataset} ${sttime}