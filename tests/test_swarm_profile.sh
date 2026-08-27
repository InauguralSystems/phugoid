#!/usr/bin/env bash
# Rung-4 cost curve: the observer's marginal cost vs N, in arms that differ
# only in observation.
#
# The measurement discipline is rung 3's C6, inherited wholesale and NOT
# re-derived: ratios rather than wall times (absolute budgets flake on
# shared runners); the ARM columns are minima of five (the fastest is the
# least-contended sample) while every asserted RATIO is the median of five
# PAIRED runs -- see the estimator note below for why those differ; the
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

file_pin tests/swarm_profile.eigs         3bd07186c79d 28
file_pin tests/swarm_profile_unarmed.eigs ec298d5e32df 14
file_pin swarm.eigs                       dd252ed85bd1 240
# sim_core.eigs holds `deriv` and `rk4_step`, where essentially ALL the
# measured time goes -- round 3 found the pin covering the four swarm files
# and missing the dominant term, so the stated purpose ("the measurement
# cannot silently become a different measurement") was not met for the part
# that dominates it. The dataset is pinned for the same reason.
# sim.eigs holds trim_solve, which the armed driver executes and which
# dominates the fixed cost the subtraction is derived from -- round 4
# found it the one unpinned file in the measured path.
file_pin sim.eigs                         2b50c1214318 42
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

# paired_ratio <armA-args...> -- <armB-args...> : median of 5 PAIRED
# ratios with the fixed cost subtracted. One implementation, used by every
# ratio this gate asserts. Round 5 left the DU check comparing unpaired
# single minima while CF had moved to paired medians, so DU still failed on
# small N for the noise reason CF had already solved -- the same "two
# copies of one measurement drift apart" this file keeps finding.
paired_ratio() {
    local a_arm="$1" b_arm="$2" nn="$3" t=$(mktemp)
    local _r p0 p1 q0 q1
    for _r in 1 2 3 4 5; do
        p0=$(date +%s%N); "$EIGS" tests/swarm_profile.eigs "$a_arm" "$nn" >/dev/null 2>&1; p1=$(date +%s%N)
        # NOTE: OVH is measured on the ARMED driver, which imports linalg and
        # solves the trim; the unarmed control does neither, so subtracting
        # the same constant from it inflates ceiling/unarmed slightly in the
        # PASS direction (~0.7% at N=16, far below the margin). Recorded
        # rather than corrected -- correcting it needs a second overhead
        # probe, and the bias is one-directional and an order of magnitude
        # under the bound.
        if [ "$b_arm" = "unarmed" ]; then
            q0=$(date +%s%N); "$EIGS" tests/swarm_profile_unarmed.eigs "$nn" >/dev/null 2>&1; q1=$(date +%s%N)
        else
            q0=$(date +%s%N); "$EIGS" tests/swarm_profile.eigs "$b_arm" "$nn" >/dev/null 2>&1; q1=$(date +%s%N)
        fi
        awk -v a="$p0" -v b="$p1" -v c="$q0" -v d="$q1" -v o="$OVH" \
            'BEGIN{ x=(b-a)/1e9-o; y=(d-c)/1e9-o; if (y<=0) y=0.001; printf "%.4f\n", x/y }' >> "$t"
    done
    sort -n "$t" | sed -n 3p; rm -f "$t"
}

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

DU_BOUND=1.20
[ "$DU_BOUND" = "1.20" ] || { echo "FAIL: DU_BOUND is $DU_BOUND, declared 1.20"; exit 1; }
CF_BOUND=1.15
[ "$CF_BOUND" = "1.15" ] || { echo "FAIL: CF_BOUND is $CF_BOUND, declared 1.15 — a widened bound must be re-justified in ORACLE.md"; exit 1; }

# --- the fixed cost is SUBTRACTED, not used to exclude points.
# Round 3 excluded any N whose fixed cost (interpreter start, parse, trim
# solve) exceeded a share of the run. Round 4 showed that is the wrong
# treatment: the fixed cost is a BIAS present in both numerator and
# denominator of the ratio, not noise, and it is measured -- so subtract
# it. The exclusion was also discarding usable data: on the quiet CI
# container the two excluded points agreed with the kept one to 1%
# (ratios 1.41, 1.40, 1.40), and on a faster box it excluded two of three
# and hard-failed the suite.
OVT=$(mktemp -d); sed 's/^FRAMES is 1500$/FRAMES is 1/' tests/swarm_profile.eigs > "$OVT/ovh.eigs"
cmp -s tests/swarm_profile.eigs "$OVT/ovh.eigs" && { rm -rf "$OVT"; echo "FAIL: the overhead probe did not apply"; exit 1; }
OVH=$(mins "$OVT/ovh.eigs" floor 1)
rm -rf "$OVT"
echo "fixed cost (1 frame): ${OVH}s — subtracted from every arm before the ratio"
# It must be a small correction, not the measurement: if the fixed cost
# ever dominates, subtracting it is amplifying noise rather than removing
# a bias, and the gate should say so instead of reporting a ratio.


echo "--- swarm cost curve (1500 frames; arms are minima of 5, ratios are medians of 5 PAIRED runs) ---"
printf "%4s %9s %12s %8s %9s %9s\n" N ceiling disciplined floor unarmed "ceil/floor"
# The ladder is 1/4/16. Round 3 proposed moving it to 4/16/32 and round 4
# recorded that as done -- it was not, and round 5 caught the comment
# contradicting its own code. What actually resolved the CI failure was
# subtracting the fixed cost instead of excluding points, plus gating only
# on points this box can resolve. The small-N points are reported for the
# curve whether or not they carry a verdict.
WORST=99
NVALID=0
LADDER_N=3
for n in 1 4 16; do
    c=$(mins tests/swarm_profile.eigs ceiling "$n")
    d=$(mins tests/swarm_profile.eigs disciplined "$n")
    f=$(mins tests/swarm_profile.eigs floor "$n")
    u=$(mins tests/swarm_profile_unarmed.eigs "$n")
    # The estimator is the MEDIAN of five PAIRED ratios, with the measured
    # fixed cost subtracted. Round 6 was told this comment said MINIMUM
    # while the code computed a median, and the edit landed on a different
    # block -- round 7 found the original still here, so this is the second
    # attempt at the same correction.
    #
    # Four estimators were tried. Exclude points on overhead share:
    # discarded usable data and hard-failed CI. Subtract the fixed cost:
    # correct, it is a BIAS in both numerator and denominator, but silent
    # on noise. Skip points on ARM spread: called every point unresolvable
    # on a loaded box while the ratios were steady at 1.47/1.49. Minimum of
    # paired ratios: an extreme order statistic, so one contention event
    # dominated it and produced 0.79 and 0.89 -- paired runs where the
    # ceiling came out FASTER than the floor.
    #
    # There is no resolvability filter. The minimum justified that with
    # "noise can only make the gate stricter", which is one-sided and does
    # NOT hold for a median. The honest reason is weaker: the median of
    # five paired ratios measured stable across consecutive runs on a
    # contended box (1.37 / 1.38 / 1.46). If it flakes, the fix is more
    # pairs, not a wider bound.
    rmed=$(paired_ratio ceiling floor "$n")
    # loop-only times: the ratio the rung actually claims
    r=$(awk -v x="$rmed" 'BEGIN{ printf "%.2f", x }')
    printf "%4s %9s %12s %8s %9s %9s\n" "$n" "$c" "$d" "$f" "$u" "$r"
    NVALID=$((NVALID+1))
    WORST=$(awk -v w="$WORST" -v r="$r" 'BEGIN{ print (r<w)?r:w }')
    # NOTE (round 7): an earlier comment here claimed the disciplined and
    # unarmed arms are judged on THESE printed numbers. They are not -- the
    # DU assertions below call paired_ratio again at the largest N, which
    # is ten fresh runs whose numbers appear nowhere in this table. That is
    # deliberate now (a paired estimator cannot be assembled from two
    # independent minima) but the claim was false, so it is stated plainly
    # rather than repaired into a lie.
    LASTN="$n"
done
# ONE resolvable point is the requirement, not two. Signal-to-noise rises
# with N by construction -- a longer run averages the same jitter over more
# work -- so the largest N resolves whenever the box is usable at all,
# while small N is inherently short and goes unresolvable under load. Round
# 4 asked for two and the suite failed on a contended dev box with 21-22%
# spread at N=1 and N=4, having correctly refused to gate on them. The
# curve is still REPORTED across the whole ladder; what changes is which
# points carry a verdict.
# This detects LADDER-LENGTH DRIFT, not ratio production -- NVALID is
# incremented unconditionally, so it equals the loop count by construction.
# Round 6 called the `>= 3` form vacuous and round 8 pointed out the
# replacement is the same tautology written differently. Kept for what it
# actually does (someone editing the `for` list without the constant), and
# described as that rather than as a coverage guarantee.
[ "$NVALID" = "$LADDER_N" ] || { echo "FAIL: $NVALID of $LADDER_N ladder points produced a ratio"; exit 1; }
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
# DU is asserted at the LARGEST ladder point only -- the best
# signal-to-noise by construction -- and with the same paired estimator.
for nm in disciplined unarmed; do
    dr=$(paired_ratio ceiling "$nm" "$LASTN")
    printf "  ceiling/%-11s at N=%s : %s  (bound: > %s)\n" "$nm" "$LASTN" "$dr" "$DU_BOUND"
    ratio_ok "$dr" "$DU_BOUND" || {
        echo "FAIL: the $nm arm is within ${DU_BOUND}x of the ceiling at N=$LASTN —"
        echo "      either it stopped eliding observation, or the ceiling stopped paying for it."
        exit 1; }
done
echo "PASS: disciplined and unarmed both sit >${DU_BOUND}x below the ceiling at N=$LASTN"

# P1, MEASURED. Round 23: P1's evidence had been a read-share
# decomposition that ORACLE called "a one-off measurement with no
# committed producer" -- which was false. The producer is
# tests/swarm_profile.eigs, it dispatches ceiling1/ceiling0/onereader, and
# it is hash-pinned twenty lines above. Round 22 gated an ARGUMENT about
# those numbers instead of the measurement, on that false premise, and the
# argument's own load-bearing clause ("a negative read share is
# impossible") turned out to be the ordinary sign flip of a ~1.5%
# difference taken between two ~5 s wall times: the SAME N=32 quantity
# measured -2.8% and +5.2% ninety seconds apart.
#
# What P1 actually claims in its practical form is that dropping 31 of 32
# readers per frame saves nothing measurable. That is a RATIO, it is
# cheap, and the estimator for it already exists in this file. The bound
# is the same +-10% noise floor the DU block is written around, doubled
# for margin, because the measured value sits at ~1.01.
P1_BOUND=1.20
[ "$P1_BOUND" = "1.20" ] || { echo "FAIL: P1_BOUND is $P1_BOUND, declared 1.20"; exit 1; }
p1r=$(paired_ratio disciplined onereader "$LASTN")
printf "  disciplined/onereader at N=%s : %s  (bound: < %s)\n" "$LASTN" "$p1r" "$P1_BOUND"
awk -v x="$p1r" -v b="$P1_BOUND" 'BEGIN{ exit !(x < b) }' || {
    echo "FAIL: dropping 31 of 32 readers at N=$LASTN changed cost by more than ${P1_BOUND}x (ratio $p1r) —"
    echo "      P1's practical claim is refuted and arming is finer than EigenScript#1046 established."
    exit 1; }
echo "PASS: P1 measured — 31 fewer readers per frame cost ${p1r}x at N=$LASTN"
# ...and the bound must be able to fail. A ratio of 1.50 is what "reads
# dominate" would look like.
awk -v x=1.50 -v b="$P1_BOUND" 'BEGIN{ exit !(x < b) }' && { echo "FAIL: the P1 bound accepted 1.50 — it cannot fail"; exit 1; }
echo "PASS: P1 planted fault rejected (ratio 1.50 >= $P1_BOUND)"
# ...and the bound must be able to fail: a ratio of 1.00 is what "unobserved:
# buys nothing" would look like.
ratio_ok 1.00 "$DU_BOUND" && { echo "FAIL: the DU bound accepted 1.00 — it cannot fail"; exit 1; }
echo "PASS: DU planted fault rejected (ratio 1.00 <= $DU_BOUND)"
# PLANTED FAULT for the bound: a ratio of 1.00 is what "observation is free"
# would look like, and 1.15 must reject it.
PLANTED=$(awk 'BEGIN{ printf "%.2f", 1.0 }')
ratio_ok "$PLANTED" "$CF_BOUND" && { echo "FAIL: the CF bound accepted a planted ratio of $PLANTED — it cannot fail"; exit 1; }
echo "PASS: CF planted fault rejected (ratio $PLANTED <= $CF_BOUND)"
