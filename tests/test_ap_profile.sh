#!/usr/bin/env bash
# Rung-3 C6: the observer READ-path profile (ORACLE.md).
#
# Claim under test: on the autopilot shape the observer's cost is
# dominated by the READ path (verdict polling), not the WRITE path
# (entropy bookkeeping per assignment) — which is why EigenScript#915's
# gate, which targets writes, cannot help this consumer.
#
# The gate is a RATIO with margin, not an absolute time: absolute budgets
# are unreliable on shared CI runners, whereas the read/write ratio is a
# property of the runtime. Measured 2026-08-25 on the dev box, n=5 medians
# over this program's 120k frames: read 0.501s, write 0.243s, floor 0.169s.
#   read/write  = 2.06   -> the bound below is 1.5 (27% margin)
#   write/floor = 1.44   -> the observed WRITE path is not free either
#   of the 0.332s of observer cost, 78% is reads and 22% is writes
# CORRECTION (round-1 review): an earlier ad-hoc probe reported "observed
# scalar writes are essentially free (0.31s vs a 0.30s floor)". That does
# NOT reproduce on the shipped program — writes cost +44% over the floor.
# The number published first was wrong; these are the ones this gate uses.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Portable timer: `date +%s%N`, NOT /usr/bin/time. The first version of
# this script used /usr/bin/time, which exists on the dev box but is not
# installed in the devcontainer — CI died with exit 127 while all 14
# suites were green locally. No other script in this repo needs an
# external binary; this one must not either.
med() {  # median of 5 wall-clock seconds for one variant. Round-2 review
         # caught a median-of-3 write/floor pair reading 0.96 — below the
         # 1.15 bound — on UNMUTATED code. Three samples is not enough
         # insulation for a 20% margin on a shared runner; five is.
    for _ in 1 2 3 4 5; do
        local t0 t1
        t0=$(date +%s%N)
        "$EIGS" tests/ap_profile.eigs "$1" >/dev/null 2>&1
        t1=$(date +%s%N)
        awk -v a="$t0" -v b="$t1" 'BEGIN{ printf "%.3f\n", (b-a)/1000000000 }'
    done | sort -n | sed -n 3p
}
echo "--- ap_profile (C6: observer read-path cost) ---"
"$EIGS" tests/ap_profile.eigs read  | grep -q '^read '  || { echo "FAIL: read variant did not run"; exit 1; }
"$EIGS" tests/ap_profile.eigs write | grep -q '^write ' || { echo "FAIL: write variant did not run"; exit 1; }
"$EIGS" tests/ap_profile.eigs floor | grep -q '^floor ' || { echo "FAIL: floor variant did not run"; exit 1; }
R=$(med read); W=$(med write); F=$(med floor)
echo "read=${R}s  write=${W}s  floor=${F}s  (120k frames, median of 5)"
RATIO=$(awk -v r="$R" -v w="$W" 'BEGIN{ if (w<=0) w=0.001; printf "%.2f", r/w }')
echo "read/write ratio = ${RATIO}  (bound: > 1.5)"
awk -v x="$RATIO" 'BEGIN{ exit !(x > 1.5) }' || {
    echo "FAIL: the read path no longer dominates (ratio ${RATIO} <= 1.5)."
    echo "      If reads were made O(1) this is EXPECTED — re-measure, update"
    echo "      ORACLE.md's C6 numbers, and re-justify the bound."
    exit 1; }
echo "PASS: read path dominates at ${RATIO}x — #915's write-path gate cannot help this shape"

# The observed WRITE path must cost something too, or `floor` is a number
# nobody reads and the "78% reads / 22% writes" split is unsupported.
WF=$(awk -v w="$W" -v f="$F" 'BEGIN{ if (f<=0) f=0.001; printf "%.2f", w/f }')
echo "write/floor ratio = ${WF}  (bound: > 1.15)"
awk -v x="$WF" 'BEGIN{ exit !(x > 1.15) }' || { echo "FAIL: observed writes now cost no more than the unobserved floor (${WF}) — re-measure and re-justify the 78/22 split"; exit 1; }
echo "PASS: observed write path costs ${WF}x the unobserved floor"

# PLANTED FAULT for this gate (rungs 0-2 refuse to ship a gate never shown
# able to fail). Feed the bound a ratio built from the write variant on
# BOTH sides — what the measurement would look like if reads became free —
# and require the bound to reject it. This validates the bound logic, which
# is the part that could silently accept anything; the variants themselves
# are validated by having just been run above.
PLANTED=$(awk -v r="$W" -v w="$W" 'BEGIN{ printf "%.2f", r/w }')
if awk -v x="$PLANTED" 'BEGIN{ exit !(x > 1.5) }'; then
    echo "FAIL: the C6 bound accepted a planted ratio of ${PLANTED} — this gate cannot fail"; exit 1
fi
echo "PASS: C6 planted fault rejected (ratio ${PLANTED} <= 1.5)"
