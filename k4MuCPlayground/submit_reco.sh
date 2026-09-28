#!/bin/bash
#SBATCH -A m5197
#SBATCH -J mucoll_reco
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH -t 08:00:00
#SBATCH --mem-per-cpu=8G
#SBATCH -C cpu
#SBATCH -q shared
#SBATCH -o reco_%A_%a.out
#SBATCH -e reco_%A_%a.err
#SBATCH --array=0-99

# 3D reconstruction scan as a single SLURM job array:
#   2 CKF modes  x  5 seed-level time cuts  x  10 digi chunks  =  100 tasks.
# The array index decodes to (CKF mode, time-cut, chunk):
#   CKF_IDX = TASK_ID / 50        ->  3D vs 4D CKF (USE_HITTIME_CKF 0/1)
#   REST    = TASK_ID % 50
#   CUT_IDX = REST / 10           ->  which SEED_DELTATMAX value
#   CHUNK   = REST % 10           ->  which digi output chunk
#
# Each task runs multi-threaded (NTHREADS). On Perlmutter CPU nodes every
# physical core exposes 2 hyperthreads and -c counts logical CPUs, so we
# request -c = 2 * NTHREADS above to give each worker thread its own core.
NTHREADS=1
# Number of events to process. The steering file defaults to 10 events, so we
# must override it with k4run's -n. Matches the per-chunk sim event count.
NEVENTS=-1

CUTS=(noCut 0.10 0.15 0.20 0.25)   # SEED_DELTATMAX values ("noCut" = unset)
TAGS=(noCut t0p10 t0p15 t0p20 t0p25)
CKF_MODES=(0 1)                    # USE_HITTIME_CKF: 0 = 3D CKF, 1 = 4D CKF
CKF_TAGS=(ckf3d ckf4d)

CKF_IDX=$(( SLURM_ARRAY_TASK_ID / 50 ))
REST=$(( SLURM_ARRAY_TASK_ID % 50 ))
CUT_IDX=$(( REST / 10 ))
CHUNK=$(( REST % 10 ))
CUT=${CUTS[$CUT_IDX]}
TAG=${TAGS[$CUT_IDX]}
CKF=${CKF_MODES[$CKF_IDX]}
CKFTAG=${CKF_TAGS[$CKF_IDX]}

INFILE="digi_output_full_bib_100_${CHUNK}.edm4hep.root"
OUTFILE="reco_output_full_bib_${CKFTAG}_${TAG}_${CHUNK}.edm4hep.root"

# Only export the time cut for the cut variants; "noCut" leaves it unset.
if [ "$CUT" = "noCut" ]; then
	SEED_EXPORT=""
else
	SEED_EXPORT="export SEED_DELTATMAX=${CUT}"
fi

shifter --image=ghcr.io/muoncollidersoft/mucoll-sim-ubuntu24:v3.0 -- /bin/bash <<CONTAINER_CMDS
cd /global/u2/j/jburzyns/muC/mucoll-benchmarks/k4MuCPlayground
source /opt/setup_mucoll.sh
source ../../setup_env.sh
source ../setup_config.sh ../ MAIA_v0
export USE_HITTIME_CKF=${CKF}
${SEED_EXPORT}
k4run -n ${NEVENTS} "\$MUCOLL_CONFIG/\$MUCOLL_CONFIG_NAME/reco_steer.py" \
	--IOSvc.Input /global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/${INFILE} \
	--IOSvc.Output /global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/${OUTFILE} \
	--doTrackPerf
CONTAINER_CMDS
