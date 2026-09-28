#!/bin/bash
# Submit the full gen -> sim -> digi -> reco workflow as a dependency chain.
# Nothing here runs the physics; it just queues the jobs so that each waits
# for the one it depends on. Run this from a login node:
#   ./submit_chain.sh
set -euo pipefail
cd /global/u2/j/jburzyns/muC/mucoll-benchmarks/k4MuCPlayground

# 1) Generation (single job). Produces the one gen_output_10k file that every
#    sim chunk reads via --skipNEvents. No dependency: starts as soon as it can.
GEN_JID=$(sbatch --parsable submit_gen.sh)
echo "submitted gen   : $GEN_JID"

# 2) Simulation array (chunks 0-9).
#    gen is a single job (not an array), so aftercorr doesn't apply: every sim
#    chunk waits for the one gen job to finish OK before splitting its events.
SIM_JID=$(sbatch --parsable --dependency=afterok:${GEN_JID} submit_sim_array.sh)
echo "submitted sim   : $SIM_JID  (afterok:${GEN_JID})"

# 3) Digitization array (chunks 0-9).
#    aftercorr = element-wise: digi chunk N starts as soon as sim chunk N
#    finishes OK, instead of waiting for the whole sim array. This needs the
#    two arrays to share the same index range (both 0-9 here).
DIGI_JID=$(sbatch --parsable --dependency=aftercorr:${SIM_JID} submit_digi.sh)
echo "submitted digi  : $DIGI_JID  (aftercorr:${SIM_JID})"

# 4) Reco array (50 tasks: 5 cuts x 10 chunks).
#    Its index range (0-49) does NOT line up with digi's (0-9) -- reco task i
#    needs digi chunk i%10 -- so aftercorr can't map it. Use afterok on the
#    whole digi array: all 50 reco tasks wait until every digi chunk is done.
RECO_JID=$(sbatch --parsable --dependency=afterok:${DIGI_JID} submit_reco_array.sh)
echo "submitted reco  : $RECO_JID  (afterok:${DIGI_JID})"

echo
echo "Chain queued. Watch it with:"
echo "  squeue --me -j ${GEN_JID},${SIM_JID},${DIGI_JID},${RECO_JID}"
