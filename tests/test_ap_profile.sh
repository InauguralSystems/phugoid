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
# property of the runtime. Measured 2026-08-25 on the dev box: read 0.87s,
# write 0.31s, floor 0.30s over 200k frames (n=5 medians) — ratio 2.8.
# The bound below is 1.5, roughly half the measured ratio, so it fails
# loudly if the read path stops dominating (e.g. if reads become O(1))
# without flaking on runner noise.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Portable timer: `date +%s%N`, NOT /usr/bin/time. The first version of
# this script used /usr/bin/time, which exists on the dev box but is not
# installed in the devcontainer — CI died with exit 127 while all 14
# suites were green locally. No other script in this repo needs an
# external binary; this one must not either.
med() {  # median of 3 wall-clock seconds for one variant
    for _ in 1 2 3; do
        local t0 t1
        t0=$(date +%s%N)
        "$EIGS" tests/ap_profile.eigs "$1" >/dev/null 2>&1
        t1=$(date +%s%N)
        awk -v a="$t0" -v b="$t1" 'BEGIN{ printf "%.3f\n", (b-a)/1000000000 }'
    done | sort -n | sed -n 2p
}
echo "--- ap_profile (C6: observer read-path cost) ---"
"$EIGS" tests/ap_profile.eigs read  | grep -q '^read '  || { echo "FAIL: read variant did not run"; exit 1; }
"$EIGS" tests/ap_profile.eigs write | grep -q '^write ' || { echo "FAIL: write variant did not run"; exit 1; }
"$EIGS" tests/ap_profile.eigs floor | grep -q '^floor ' || { echo "FAIL: floor variant did not run"; exit 1; }
R=$(med read); W=$(med write); F=$(med floor)
echo "read=${R}s  write=${W}s  floor=${F}s  (120k frames, median of 3)"
RATIO=$(awk -v r="$R" -v w="$W" 'BEGIN{ if (w<=0) w=0.001; printf "%.2f", r/w }')
echo "read/write ratio = ${RATIO}  (bound: > 1.5)"
awk -v x="$RATIO" 'BEGIN{ exit !(x > 1.5) }' || {
    echo "FAIL: the read path no longer dominates (ratio ${RATIO} <= 1.5)."
    echo "      If reads were made O(1) this is EXPECTED — re-measure, update"
    echo "      ORACLE.md's C6 numbers, and re-justify the bound."
    exit 1; }
echo "PASS: read path dominates at ${RATIO}x — #915's write-path gate cannot help this shape"
