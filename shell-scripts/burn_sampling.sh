#!/bin/bash
# model run 

source /curc/sw/anaconda3/2022.10/etc/profile.d/conda.sh
conda activate stan

datafile="../../../data/stan_data_${suffix}.json"
basedir="./full-model/fire-sims/${modtype}/${modname}/"
diagexe="/projects/eslawler@colostate.edu/software/anaconda/envs/stan/bin/cmdstan/bin/diagnose"
cd ${basedir}
model="stan/${modname}_${params}"
outbase="csv-fits/${modname}_${suffix}_${params}_${delta}_${sttime}"

# run model with 3 chains
./${model} sample num_chains=3 num_warmup=1500 num_samples=1500 \
                  adapt delta=${delta} \
                  data file=${datafile} \
                  init=0.01 \
                  output file=${outbase}.csv \
                  num_threads=3

# return diagnostics
${diagexe} ${outbase}_*.csv

