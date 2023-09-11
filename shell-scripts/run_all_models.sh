#!/bin/bash
# shell script to call sbatch
#
# execute all model run shell scripts 
#

shell-scripts/run_joint_NUTS.sh
sleep 1
shell-scripts/run_g1_g2_NUTS.sh
sleep 1
shell-scripts/run_counts_NUTS.sh
sleep 1
shell-scripts/run_lognorm_NUTS.sh
sleep 1
shell-scripts/run_g3_NUTS.sh
sleep 1
shell-scripts/run_g4_NUTS.sh