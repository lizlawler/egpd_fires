#!/bin/bash
# shell script to call sbatch
#
# cycle through loop and launch sbatch for every combination
#
trap '' HUP
stanc_exe="/data/accounts/lawler/.conda/envs/stan/bin/cmdstan/bin/stanc"
modtype="burns"
modname="g3"
# for params in "all-reg" "xi-ri"
for params in "all-reg_nu" "xi-ri_nu"
do
# compile model and link c++ 
inc_path="full-model/fire-sims/${modtype}/stan/"
object="full-model/fire-sims/${modtype}/${modname}/stan/${modname}_${params}"
${stanc_exe} ${object}.stan --include-paths=${inc_path}
cmdstan_model ${object}
for dataset in "erc_fwi" "fwi" "erc" "climate"
do
sttime=$(date +"%d%b%Y_%H%M")
export modtype modname params dataset sttime
nohup ./shell-scripts/miss-piggy/burn_sampling_mp.sh > full-model/output/${modname}_${dataset}_${params}_${sttime}_mp.txt 2>&1 &
sleep 1
done
done
