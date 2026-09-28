#!/bin/bash
#SBATCH -A m5197
#SBATCH -J mucoll_ntuple_ps
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 20
#SBATCH -t 08:00:00
#SBATCH --mem-per-cpu=4G
#SBATCH -C cpu
#SBATCH -q shared
#SBATCH -o ntuple_ps_%A_%a.out
#SBATCH -e ntuple_ps_%A_%a.err
#SBATCH --array=0-4

# NTuple production for the cumulative parameter scan (submit_param_scan.sh).
#   1 task per cumulative configuration = 5 tasks.
# Each task globs that config's 10 reco chunks
#   (param_scan_10f/reco_<CONFIG>_<TAG>_*.edm4hep.root) via WriteAllMT's
#   <prefix>*.root glob, and writes tracks/seeds/hits ntuples into a per-config
#   output directory.
#
# The array index is the configuration index (matches submit_param_scan.sh):
#   CONFIG = SLURM_ARRAY_TASK_ID ;  TAG = TAGS[CONFIG]
# The analysis selection below is IDENTICAL for every config, so the only thing
# varying across the scan is the reconstruction configuration itself.
NTHREADS=10          # WriteAllMT parallelises across files; 10 chunks -> 10 threads

TAGS=(nominal outlier25 branchstop fourD doublet0p1)
CONFIG=${SLURM_ARRAY_TASK_ID}
TAG=${TAGS[$CONFIG]}

STUDYDIR=/global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy
INPREFIX=${STUDYDIR}/param_scan_10f/reco_${CONFIG}_${TAG}_
OUTDIR=${STUDYDIR}/param_scan_10f/ntuples/${CONFIG}_${TAG}
CONF=${STUDYDIR}/param_scan_10f/ntuples/RunAnalysis_${CONFIG}_${TAG}.conf

PLOTDIR=/global/u2/j/jburzyns/muC/mucoll-benchmarks/plotting/TrackingPlots/PlottingScripts

shifter --image=ghcr.io/muoncollidersoft/mucoll-sim-ubuntu24:v3.0 -- /bin/bash <<CONTAINER_CMDS
source /opt/setup_mucoll.sh

mkdir -p "${OUTDIR}"

# Per-config analysis config. Selection is identical for every config so that the
# only thing varying across the scan is the reconstruction; keep these in sync
# with PlottingScripts/RunAnalysis.conf if the reference selection changes.
cat > "${CONF}" <<CONF_EOF
io.inputFilePrefix: ${INPREFIX}
io.outputDir: ${OUTDIR}
io.nThreads: ${NTHREADS}
io.nThreadsTracks: ${NTHREADS}
io.nThreadsSeeds: ${NTHREADS}
io.nThreadsHits: ${NTHREADS}
io.trackBranch: SiTrack
io.isSubsetCollection: 1
io.seedBranch: SeedTracks

event.ptMin: 0.0
event.ptMax: 3.4028235e+38
event.thetaMin: 0.0
event.thetaMax: 3.141592653589793
event.absEtaMin: 0.0
event.absEtaMax: 3.4028235e+38

track.ptMin: 0.5
track.ptMax: 3.4028235e+38
track.thetaMin: 0.0
track.thetaMax: 3.141592653589793
track.absEtaMin: 0.0
track.absEtaMax: 3.4028235e+38
track.phiMin: -3.141592653589793
track.phiMax: 3.141592653589793
track.d0Min: -3.4028235e+38
track.d0Max: 3.4028235e+38
track.z0Min: -3.4028235e+38
track.z0Max: 3.4028235e+38
track.chi2Min: 0.0
track.chi2Max: 3.4028235e+38
track.nHitsMin: 8
track.nHolesMax: 2
CONF_EOF

# RunAnalysis.C #includes WriteAllMT.C by relative path, so run from its dir.
cd "${PLOTDIR}"
root -l -b -q "RunAnalysis.C(\"${CONF}\")"
CONTAINER_CMDS
