#!/bin/bash
#SBATCH -A m5197
#SBATCH -J mucoll_recotime
#SBATCH -N 1
#SBATCH -t 12:00:00
#SBATCH -C cpu
#SBATCH -q regular
#SBATCH --exclusive
#SBATCH -o recotime_%j.out
#SBATCH -e recotime_%j.err

# CPU-timing benchmark for the 4D seed-time-cut scan.
#
# Runs reconstruction on the SAME single digi file, NEVENTS events, once per
# seed-level time cut, SEQUENTIALLY on an exclusive full node. The exclusive node
# means nothing else is running on the hardware, so the per-algorithm CPU numbers
# the ChronoAuditor records aren't perturbed by co-scheduled work -- that is the
# whole point of asking for a full node here even though reco itself is
# single-threaded. Running the cuts one after another (not in parallel) keeps
# them from contending for cache / memory bandwidth.
#
# reco_steer.py already enables the ChronoAuditor + ChronoStatSvc at INFO, so each
# run prints a "Final CPU consumption (Chrono) Table". We capture timing two ways:
#   * tee the full run to reco_timing_<TAG>.log  (human-readable, but MessageSvc
#     truncates the algorithm-name column to ~18 chars)
#   * override ChronoStatSvc.AsciiStatsOutputFile so the FULL, untruncated table
#     is written to chrono_<TAG>.txt -- parse this one.
# Each table's "#=" column is the number of Execute calls (= NEVENTS), so the
# per-event average = Tot / NEVENTS.

NEVENTS=20
CHUNK=0
STUDYDIR=/global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy
INFILE=${STUDYDIR}/digi_output_full_bib_100_${CHUNK}.edm4hep.root

# throwaway reco outputs + timing logs (only the timing tables matter here)
BENCHDIR=${STUDYDIR}/timing_bench
mkdir -p "${BENCHDIR}"

shifter --image=ghcr.io/muoncollidersoft/mucoll-sim-ubuntu24:v3.0 -- /bin/bash <<CONTAINER_CMDS
cd /global/u2/j/jburzyns/muC/mucoll-benchmarks/k4MuCPlayground
source /opt/setup_mucoll.sh
source ../../setup_env.sh
source ../setup_config.sh ../ MAIA_v0

# Keep every math/threading library single-threaded so the ChronoAuditor CPU
# times reflect one core and are directly comparable across cuts.
export OMP_NUM_THREADS=1

CUTS=(noCut 0.10 0.15 0.20 0.25)   # SEED_DELTATMAX values ("noCut" = unset)
TAGS=(noCut t0p10 t0p15 t0p20 t0p25)
CKF_MODES=(0 1)                    # USE_HITTIME_CKF: 0 = 3D CKF, 1 = 4D CKF
CKF_TAGS=(ckf3d ckf4d)

# Outer loop: 3D vs 4D CKF.  Inner loop: the five seed-time cuts.
# 2 x 5 = 10 sequential runs, each writing its own chrono_<CKFTAG>_<TAG>.txt.
for c in 0 1; do
  export USE_HITTIME_CKF=\${CKF_MODES[\$c]}
  CKFTAG=\${CKF_TAGS[\$c]}
  for i in 0 1 2 3 4; do
    CUT=\${CUTS[\$i]}
    TAG=\${TAGS[\$i]}
    LOG=${BENCHDIR}/reco_timing_\${CKFTAG}_\${TAG}.log
    CHRONO=${BENCHDIR}/chrono_\${CKFTAG}_\${TAG}.txt
    OUT=${BENCHDIR}/reco_timing_\${CKFTAG}_\${TAG}.edm4hep.root

    if [ "\$CUT" = "noCut" ]; then
        unset SEED_DELTATMAX
    else
        export SEED_DELTATMAX=\$CUT
    fi

    echo "================================================================"
    echo "BENCHMARK ckf=\${CKFTAG} (USE_HITTIME_CKF=\${USE_HITTIME_CKF})  cut=\${TAG}  SEED_DELTATMAX=\${SEED_DELTATMAX:-unset}  nevents=${NEVENTS}"
    echo "================================================================"
    k4run -n ${NEVENTS} "\$MUCOLL_CONFIG/\$MUCOLL_CONFIG_NAME/reco_steer.py" \
        --IOSvc.Input ${INFILE} \
        --IOSvc.Output \${OUT} \
        --ChronoStatSvc.AsciiStatsOutputFile \${CHRONO} \
        --doTrackPerf 2>&1 | tee "\${LOG}"
  done
done
CONTAINER_CMDS
