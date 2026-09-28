#!/bin/bash
#SBATCH -A m5197
#SBATCH -J mucoll_digi
#SBATCH -n 1
#SBATCH -c 24
#SBATCH -t 4:00:00
#SBATCH --mem-per-cpu=4G
#SBATCH -C cpu
#SBATCH -q shared 
#SBATCH -o digi_%A_%a.out
#SBATCH -e digi_%A_%a.err
#SBATCH --array=0-99

# Run digitization as a SLURM job array, one task per simulation chunk.
# The only thing that differs between tasks is the input/output file.
#
# Each task runs multi-threaded (NTHREADS). On Perlmutter CPU nodes every
# physical core exposes 2 hyperthreads and -c counts logical CPUs, so we
# request -c = 2 * NTHREADS above to give each worker thread its own core.
NTHREADS=12
# Number of events to process. The steering file defaults to 10 events, so we
# must override it with k4run's -n. Matches the per-chunk sim event count.
NEVENTS=100
FIRSTEVENT=$((SLURM_ARRAY_TASK_ID * 100))
INFILE="sim_output_10k.edm4hep.root"
OUTFILE="digi_output_full_bib_100_${SLURM_ARRAY_TASK_ID}.edm4hep.root"

shifter --image=ghcr.io/muoncollidersoft/mucoll-sim-ubuntu24:v3.0 -- /bin/bash <<CONTAINER_CMDS
cd /global/u2/j/jburzyns/muC/mucoll-benchmarks/k4MuCPlayground
source /opt/setup_mucoll.sh
source ../setup_config.sh ../ MAIA_v0
k4run -n ${NEVENTS} "\$MUCOLL_CONFIG/\$MUCOLL_CONFIG_NAME/digi_steer.py" \
	--IOSvc.Input /global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/${INFILE} \
	--IOSvc.Output /global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/${OUTFILE} \
	--IOSvc.FirstEventEntry ${FIRSTEVENT} \
	--doOverlayFull \
	--OverlayFullNumberBackground 812 \
	--OverlayFullPathToMuPlus /global/cfs/cdirs/m5197/data/bib/10TeV_MAIA_edm4hep/MUPLUS \
	--OverlayFullPathToMuMinus /global/cfs/cdirs/m5197/data/bib/10TeV_MAIA_edm4hep/MUMINUS \
	--numThreads ${NTHREADS} \
	--RandSeed ${FIRSTEVENT}
CONTAINER_CMDS
