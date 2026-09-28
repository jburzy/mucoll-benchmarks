#!/bin/bash
#SBATCH -A m5197
#SBATCH -J mucoll_paramscan
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH -t 12:00:00
#SBATCH --mem-per-cpu=8G
#SBATCH -C cpu
#SBATCH -q shared
#SBATCH -o paramscan_%A_%a.out
#SBATCH -e paramscan_%A_%a.err
#SBATCH --array=0-49

# Cumulative parameter scan of the tracking changes, over the first 10 digi files.
#
# Five configurations, each ADDING one change on top of the previous one:
#   0  nominal      default CKF before any of our changes:
#                     measurement chi2 < 10, NO outlier cut (never a hole),
#                     no branch stopper, no 4D time, no seed time cut, and the
#                     downstream MaxHoles filter disabled (there are no holes)
#   1  +outlier25   add the outlier chi2 cut at 25 (hits above -> holes) and, since
#                     holes now exist, enable the FilterTracksAlg MaxHoles=2 cut
#   2  +branchstop  add the CKF branch stopper
#   3  +4D          add 4D tracking (hit time as a CKF measurement); the extra
#                     time DoF widens the measurement chi2 cut 10 -> 12
#   4  +doublet0p1  add the seed doublet time-of-flight cut at 0.10 ns
#
# Only the listed knobs change. The rest of FilterTracksAlg stays fixed, so
# NHitsTotal>=8 is applied in every config (including nominal) -- SiTracks is not
# a bit-exact pre-change baseline, but AllTracks and CKF CPU are.
#
# 5 configs x 10 digi chunks = 50 array tasks, one full file per task:
#   CONFIG = TASK_ID / 10     ->  which cumulative configuration
#   CHUNK  = TASK_ID % 10     ->  which digi file (0..9)
# One file per task keeps even the expensive nominal config (~130 s/event with no
# branch stopper -> ~4 h for 100 events) inside the walltime, and lets all configs
# run in parallel. Single-threaded (OMP_NUM_THREADS=1) so the ChronoAuditor CPU
# times reflect one core and are comparable across configs.

# Events per file. -1 = all 100. The nominal config is very slow (no branch
# stopper); set e.g. NEVENTS=20 for a faster first pass.
NEVENTS=-1

STUDYDIR=/global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy
OUTDIR=${STUDYDIR}/param_scan_10f
mkdir -p "${OUTDIR}"

# --- cumulative configuration table (index 0..4) --------------------------
#            0        1          2           3        4
TAGS=(     nominal  outlier25  branchstop  fourD    doublet0p1 )
CHI2=(     10       10         10          12       12         )   # measurement chi2 (10 -> 12 with 4D)
OUTLIER=(  1e30     25         25          25       25         )   # outlier chi2 (1e30 = disabled)
MAXHOLES=( -1       2          2           2        2          )   # FilterTracksAlg MaxHoles (-1 = off; on with the outlier cut)
BS=(       0        0          1           1        1          )   # USE_BRANCHSTOPPER
CKF4D=(    0        0          0           1        1          )   # USE_HITTIME_CKF
DT=(       -1       -1         -1          -1       0.10       )   # SEED_DELTATMAX (-1 = off)

CONFIG=$(( SLURM_ARRAY_TASK_ID / 10 ))
CHUNK=$((  SLURM_ARRAY_TASK_ID % 10 ))

TAG=${TAGS[$CONFIG]}
c_chi2=${CHI2[$CONFIG]}
c_outlier=${OUTLIER[$CONFIG]}
c_maxholes=${MAXHOLES[$CONFIG]}
c_bs=${BS[$CONFIG]}
c_4d=${CKF4D[$CONFIG]}
c_dt=${DT[$CONFIG]}

INFILE=${STUDYDIR}/digi_output_full_bib_100_${CHUNK}.edm4hep.root
OUTFILE=${OUTDIR}/reco_${CONFIG}_${TAG}_${CHUNK}.edm4hep.root
CHRONO=${OUTDIR}/chrono_${CONFIG}_${TAG}_${CHUNK}.txt
LOG=${OUTDIR}/reco_${CONFIG}_${TAG}_${CHUNK}.log

echo "=================================================================="
echo "config ${CONFIG} (${TAG})  chunk ${CHUNK}"
echo "  CKF_CHI2=${c_chi2}  CKF_CHI2_OUTLIER=${c_outlier}  FILTER_MAXHOLES=${c_maxholes}  USE_BRANCHSTOPPER=${c_bs}  USE_HITTIME_CKF=${c_4d}  SEED_DELTATMAX=${c_dt}"
echo "  in=${INFILE}"
echo "=================================================================="

shifter --image=ghcr.io/muoncollidersoft/mucoll-sim-ubuntu24:v3.0 -- /bin/bash <<CONTAINER_CMDS
cd /global/u2/j/jburzyns/muC/mucoll-benchmarks/k4MuCPlayground
source /opt/setup_mucoll.sh
source ../../setup_env.sh
source ../setup_config.sh ../ MAIA_v0

# single-threaded so the ChronoAuditor CPU times reflect one core
export OMP_NUM_THREADS=1

# cumulative scan knobs (all read by MAIAConfig/Tracking/CKF_tracking.py)
export CKF_CHI2=${c_chi2}
export CKF_CHI2_OUTLIER=${c_outlier}
export FILTER_MAXHOLES=${c_maxholes}
export USE_BRANCHSTOPPER=${c_bs}
export USE_HITTIME_CKF=${c_4d}
export SEED_DELTATMAX=${c_dt}

k4run -n ${NEVENTS} "\$MUCOLL_CONFIG/\$MUCOLL_CONFIG_NAME/reco_steer.py" \
    --IOSvc.Input ${INFILE} \
    --IOSvc.Output ${OUTFILE} \
    --ChronoStatSvc.AsciiStatsOutputFile ${CHRONO} \
    --doTrackPerf 2>&1 | tee ${LOG}
CONTAINER_CMDS
