#!/bin/bash

source /global/cfs/cdirs/atlas/sferrar2/TrackMuC/mucoll-benchmarks/k4MuCPlayground/setup_digireco.sh /global/cfs/cdirs/atlas/sferrar2/TrackMuC/mucoll-benchmarks/ MAIA_v0

#Gen-parameters
PARTICLE=${2:-"mu-"}
PT_LOW=${3:-"10"}
PT_HIGH=${4:-"5000"}
THETA_LOW=${5:-"40"}
THETA_HIGH=${6:-"140"}

# BIB overlay files are copied once to scratch before the batch run.
# Set BIB_SCRATCH in sbatch-slr.sh (or export it manually) before submitting.
# Fallback points to the standard pscratch location for sferrar2.
BIB_SCRATCH="${BIB_SCRATCH:-/pscratch/sd/s/sferrar2/BIB}"

if [[ ! -d "${BIB_SCRATCH}/MUPLUS" || ! -d "${BIB_SCRATCH}/MUMINUS" ]]; then
    echo "ERROR: BIB overlay directories not found under ${BIB_SCRATCH}"
    echo "       Run copy_bib_to_scratch.sh first."
    exit 1
fi

INDEX=$1
first_event=$((INDEX * 100))
num_events=100

INPUT_FILE="/global/cfs/cdirs/m5197/sferrar2/TrackingPaper/MC/Mu_pgun_barrel/sim_${PARTICLE}_pt${PT_LOW}-${PT_HIGH}_theta${THETA_LOW}-${THETA_HIGH}.edm4hep.root"
OUTPUT_FILE="/global/cfs/cdirs/m5197/sferrar2/TrackingPaper/MC/Mu_pgun_barrel/digi_${PARTICLE}_pt${PT_LOW}-${PT_HIGH}_theta${THETA_LOW}-${THETA_HIGH}_${INDEX}.edm4hep.root"


k4run /global/cfs/cdirs/atlas/sferrar2/TrackMuC/mucoll-benchmarks/digitization/digi_steer.py \
        --IOSvc.Input $INPUT_FILE \
        --IOSvc.Output $OUTPUT_FILE \
        -n ${num_events} \
        --IOSvc.FirstEventEntry ${first_event} \
        --OverlayFullPathToMuPlus ${BIB_SCRATCH}/MUPLUS \
        --OverlayFullPathToMuMinus ${BIB_SCRATCH}/MUMINUS \
        --OverlayFullNumberBackground 812 \
        --doOverlayFull \
        --RandSeed ${first_event}