#!/usr/bin/env bash
# Rung-4 cost curve: the observer's marginal cost vs N, in arms that differ
# only in observation.
#
# The measurement discipline is rung 3's C6, inherited wholesale and NOT
# re-derived: ratios rather than wall times (absolute budgets flake on
# shared runners), minima rather than medians (the fastest of five is the
# least-contended sample; the spread here reached 28% under load), the
# executed workload pinned by whole-file hash so it cannot silently become
# a different workload, and bound literals identity-pinned.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# --- workload identity. Round 1 shipped this rung with NO hash pin at all,
# while swarm_unarmed.eigs's own header claimed this file pinned it.
file_pin() {
    got=$(grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' | md5sum | cut -c1-12)
    gotn=$(grep -v '^[[:space:]]*#' "$1" | grep -v -c '^[[:space:]]*$')
    [ "$gotn" = "$3" ] || { echo "FAIL: $1 has $gotn code lines, declared $3 — the measured workload changed"; exit 1; }
    [ "$got"  = "$2" ] || { echo "FAIL: $1 changed (identity $got, declared $2) — the measured workload changed"; exit 1; }
}
# PLANTED FAULT for file_pin, calling the REAL function on a dirty input
# (mechanical-gates §99: a plant that re-implements its gate is the same
# point drawn twice).
FP=$(mktemp -d)
sed 's/^FRAMES is 1500$/FRAMES is 750/' tests/swarm_profile.eigs > "$FP/mut.eigs"
cmp -s tests/swarm_profile.eigs "$FP/mut.eigs" && { rm -rf "$FP"; echo "FAIL: the file_pin plant did not apply"; exit 1; }
if ( file_pin "$FP/mut.eigs" 27b48d89472b 28 ) >/dev/null 2>&1; then
    rm -rf "$FP"; echo "FAIL: file_pin ACCEPTED a halved frame count"; exit 1
fi
rm -rf "$FP"
echo "PASS: file_pin planted fault rejected (the real file_pin rejects a halved FRAMES)"

file_pin tests/swarm_profile.eigs         27b48d89472b 28
file_pin tests/swarm_profile_unarmed.eigs 646088f6531a 14
file_pin swarm.eigs                       5133f8995d0b 207
# sim_core.eigs holds `deriv` and `rk4_step`, where essentially ALL the
# measured time goes -- round 3 found the pin covering the four swarm files
# and missing the dominant term, so the stated purpose ("the measurement
# cannot silently become a different measurement") was not met for the part
# that dominates it. The dataset is pinned for the same reason.
file_pin sim_core.eigs                    6c6d2044c43c 123
file_pin data/b747_approach.eigs          e71ab4f72fad 41
file_pin swarm_unarmed.eigs               11e3d43c59ca 56

# --- the control must be UNARMED, which is the whole point of it existing.
# Derived from the runtime's own gate verdict, not asserted.
GS=$(EIGS_OBS_GATE_STATS=1 "$EIGS" tests/swarm_profile_unarmed.eigs 2 2>&1 >/dev/null | sort -u)
case "$GS" in
    *observed*) [ "${GS#*unobserved}" != "$GS" ] || { echo "FAIL: the unarmed control compiled ARMED — it is not a control: $GS"; exit 1; };;
esac
echo "$GS" | grep -q 'unobserved' || { echo "FAIL: no gate verdict from the control"; exit 1; }
echo "$GS" | grep -qx 'obs-gate: observed <module>' && { echo "FAIL: the unarmed control has an armed unit: $GS"; exit 1; }
echo "PASS: the unarmed control compiles unobserved (derived from EIGS_OBS_GATE_STATS)"

# ratio_ok <value> <bound> -> 0 if value > bound. ONE implementation, shared
# by every arm and by every plant that validates one. Round 3: the DU and CF
# plants each re-typed the awk expression instead of calling the gate --
# mechanical-gates SS99, in the same file whose file_pin plant does it right.
ratio_ok() { awk -v x="$1" -v b="$2" 'BEGIN{ exit !(x > b) }'; }

mins() {  # minimum of 5 wall-clock seconds
    for _ in 1 2 3 4 5; do
        local t0 t1
        t0=$(date +%s%N)
        "$EIGS" "$@" >/dev/null 2>&1
        t1=$(date +%s%N)
        awk -v a="$t0" -v b="$t1" 'BEGIN{ printf "%.3f\n", (b-a)/1000000000 }'
    done | sort -n | head -1
}

CF_BOUND=1.15
[ "$CF_BOUND" = "1.15" ] || { echo "FAIL: CF_BOUND is $CF_BOUND, declared 1.15 — a widened bound must be re-justified in ORACLE.md"; exit 1; }

# --- which N are VALID measurement points, derived rather than chosen.
# Round 3's gate failed at 1.12 on a loaded box, all of it at N=1: the
# fixed cost (interpreter start, parse, trim solve) is 11% of an N=1 run
# against 1% at N=16, so contention jitter swamps the signal there. The
# valid range is measured, not declared -- a one-frame run gives the fixed
# cost, and any N where it exceeds OVH_MAX of the floor run is excluded
# and SAID SO (a gate that silently drops points reads as covering them).
OVH_MAX=5
[ "$OVH_MAX" = "5" ] || { echo "FAIL: OVH_MAX is $OVH_MAX, declared 5"; exit 1; }
OVT=$(mktemp -d); sed 's/^FRAMES is 1500$/FRAMES is 1/' tests/swarm_profile.eigs > "$OVT/ovh.eigs"
cmp -s tests/swarm_profile.eigs "$OVT/ovh.eigs" && { rm -rf "$OVT"; echo "FAIL: the overhead probe did not apply"; exit 1; }
OVH=$(mins "$OVT/ovh.eigs" floor 1)
rm -rf "$OVT"
echo "fixed overhead (1 frame): ${OVH}s — N with overhead above ${OVH_MAX}% of the run are excluded"

echo "--- swarm cost curve (1500 frames, minima of 5) ---"
printf "%4s %9s %12s %8s %9s %9s\n" N ceiling disciplined floor unarmed "ceil/floor"
WORST=99
NVALID=0
SKIPPED=""
for n in 1 4 16; do
    c=$(mins tests/swarm_profile.eigs ceiling "$n")
    d=$(mins tests/swarm_profile.eigs disciplined "$n")
    f=$(mins tests/swarm_profile.eigs floor "$n")
    u=$(mins tests/swarm_profile_unarmed.eigs "$n")
    r=$(awk -v a="$c" -v b="$f" 'BEGIN{ if (b<=0) b=0.001; printf "%.2f", a/b }')
    share=$(awk -v o="$OVH" -v f="$f" 'BEGIN{ if (f<=0) f=0.001; printf "%.0f", 100*o/f }')
    if [ "$share" -gt "$OVH_MAX" ]; then
        printf "%4s %9s %12s %8s %9s %9s   (excluded: fixed cost is %s%% of the run)\n" "$n" "$c" "$d" "$f" "$u" "$r" "$share"
        SKIPPED="$SKIPPED $n"
        continue
    fi
    printf "%4s %9s %12s %8s %9s %9s\n" "$n" "$c" "$d" "$f" "$u" "$r"
    NVALID=$((NVALID+1))
    WORST=$(awk -v w="$WORST" -v r="$r" 'BEGIN{ print (r<w)?r:w }')
done
[ -n "$SKIPPED" ] && echo "excluded N:$SKIPPED (fixed cost above ${OVH_MAX}% — not silently dropped)"
[ "$NVALID" -ge 2 ] || { echo "FAIL: only $NVALID valid measurement points survived the overhead filter — the curve is not measurable on this box"; exit 1; }
echo "worst ceiling/floor across N = $WORST  (bound: > $CF_BOUND)"
ratio_ok "$WORST" "$CF_BOUND" || {
    echo "FAIL: naive all-on observation no longer costs meaningfully more than the"
    echo "      unobserved floor ($WORST). Either #915's gate got much better — in"
    echo "      which case re-measure and re-justify the curve in ORACLE.md — or an"
    echo "      arm stopped doing its work."
    exit 1; }
echo "PASS: the ceiling arm costs ${WORST}x the floor at its weakest N"

# The disciplined and unarmed arms were PRINTED AND NEVER ASSERTED (round
# 2) -- the same defect class round 1 found in `hits`. What can honestly be
# asserted is bounded by this box: round 2 measured disciplined 8% BELOW
# floor at one N, so the noise floor is ~10% and "indistinguishable" is not
# resolvable. The defensible claim is that BOTH sit far below the ceiling,
# i.e. `unobserved:` bought the penalty back; that is what is gated.
DU_BOUND=1.20
[ "$DU_BOUND" = "1.20" ] || { echo "FAIL: DU_BOUND is $DU_BOUND, declared 1.20"; exit 1; }
for n in 4 16; do
    c=$(mins tests/swarm_profile.eigs ceiling "$n")
    d=$(mins tests/swarm_profile.eigs disciplined "$n")
    u=$(mins tests/swarm_profile_unarmed.eigs "$n")
    for pair in "disciplined:$d" "unarmed:$u"; do
        nm=${pair%%:*}; v=${pair##*:}
        ratio_ok "$(awk -v a="$c" -v d="$v" 'BEGIN{printf "%.4f", a/d}')" "$DU_BOUND" || {
            echo "FAIL: at N=$n the $nm arm ($v) is within ${DU_BOUND}x of the ceiling ($c) —"
            echo "      either it stopped eliding observation, or the ceiling stopped paying for it."
            exit 1; }
    done
done
echo "PASS: disciplined and unarmed both sit >${DU_BOUND}x below the ceiling at every N"
# ...and the bound must be able to fail: a ratio of 1.00 is what "unobserved:
# buys nothing" would look like.
ratio_ok 1.00 "$DU_BOUND" && { echo "FAIL: the DU bound accepted 1.00 — it cannot fail"; exit 1; }
echo "PASS: DU planted fault rejected (ratio 1.00 <= $DU_BOUND)"
# PLANTED FAULT for the bound: a ratio of 1.00 is what "observation is free"
# would look like, and 1.15 must reject it.
PLANTED=$(awk 'BEGIN{ printf "%.2f", 1.0 }')
ratio_ok "$PLANTED" "$CF_BOUND" && { echo "FAIL: the CF bound accepted a planted ratio of $PLANTED — it cannot fail"; exit 1; }
echo "PASS: CF planted fault rejected (ratio $PLANTED <= $CF_BOUND)"
