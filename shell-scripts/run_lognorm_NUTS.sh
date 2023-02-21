#!/bin/bash

#
# modules
#
source /curc/sw/anaconda3/2020.11/etc/profile.d/conda.sh
conda activate /projects/eslawler@colostate.edu/software/anaconda/envs/lawler

#
# run scripts
#
for suffix in "sqrt" "og"
do
for params in "all-reg" "sigma-ri" "mu-ri"
do
sbatch --job-name lognorm_$(printf %s $suffix "_" $params) \
--chdir=/scratch/alpine/eslawler@colostate.edu/egpd-fires/ \
--output='./full-model/output/%x_%j.txt' --qos=long --nodes=1 --ntasks-per-node=30 \
--time=120:00:00 --mail-type=ALL --mail-user=eslawler@colostate.edu \
--export=suffix=$suffix,params=$params shell-scripts/call_lognorm_NUTS_sampler.sh
done
done