#!/bin/bash

#SBATCH --partition=amilan
#SBATCH --account=csu54_alpine1
#SBATCH --chdir=/scratch/alpine/eslawler@colostate.edu/egpd-fires/
#SBATCH --qos=normal
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=3
#SBATCH --mem=90000
#SBATCH --time=24:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=eslawler@colostate.edu

export TMPDIR=/scratch/alpine/$USER/tmp/
export TMP=${TMPDIR}
mkdir -p $TMPDIR

./shell-scripts/burn_sampling.sh ${burn_mod} ${suffix} ${params} ${delta}
