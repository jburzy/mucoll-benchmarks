#!/bin/bash
#SBATCH -A m5197
#SBATCH -J mucoll_sim
#SBATCH -n 1
#SBATCH -c 2
#SBATCH -t 24:00:00
#SBATCH -C cpu
#SBATCH -q shared 
#SBATCH -o sim_%A_%a.out
#SBATCH -e sim_%A_%a.err

OUTFILE="sim_output_10k.edm4hep.root"

shifter --image=ghcr.io/muoncollidersoft/mucoll-sim-ubuntu24:v3.0 -- /bin/bash <<CONTAINER_CMDS
cd /global/u2/j/jburzyns/muC/mucoll-benchmarks/k4MuCPlayground
source /opt/setup_mucoll.sh
source ../setup_config.sh ../ MAIA_v0
ddsim --steeringFile ../simulation/steer_baseline.py \
	--inputFiles /global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/gen_output_single_mu_10k.edm4hep.root \
	--outputFile /global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/${OUTFILE} \
	--numberOfEvents 10000
CONTAINER_CMDS
