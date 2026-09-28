#!/bin/bash
#SBATCH -A m5197
#SBATCH -J mucoll_gen
#SBATCH -n 1
#SBATCH -c 1
#SBATCH -t 02:00:00
#SBATCH -C cpu
#SBATCH -q shared 
#SBATCH -o gen_%j.out
#SBATCH -e gen_%j.err

shifter --image=ghcr.io/muoncollidersoft/mucoll-sim-ubuntu24:v3.0 -- /bin/bash <<'CONTAINER_CMDS'
cd /global/u2/j/jburzyns/muC/mucoll-benchmarks/k4MuCPlayground
source /opt/setup_mucoll.sh
source ../setup_config.sh ../ MAIA_v0
python ../generation/pgun/pgun_edm4hep.py \
    -p 1 -e 10000 --pdg 13 --pt 1 100 --theta 10 170 -- /global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/gen_output_single_mu_10k.edm4hep.root
CONTAINER_CMDS
