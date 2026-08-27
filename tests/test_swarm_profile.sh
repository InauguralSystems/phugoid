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
if ( file_pin "$FP/mut.eigs" a3c522851b0c 53 ) >/dev/null 2>&1; then
    rm -rf "$FP"; echo "FAIL: file_pin ACCEPTED a halved frame count"; exit 1
fi
rm -rf "$FP"
echo "PASS: file_pin planted fault rejected (the real file_pin rejects a halved FRAMES)"

file_pin tests/swarm_profile.eigs         a3c522851b0c 53
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
# run_arm <driver> <arm> <n> <outfile> -- runs one arm and REFUSES to
# return a timing for a run that did not happen. Round 27: every arm was
# run as `>/dev/null 2>&1` with the exit status never checked, and bash
# does not inherit errexit into `$( )`, so `set -e` did not fire either. A
# crashed arm returned in ~0.02 s, OVH subtraction drove the ratio
# negative, and the one-sided plant check accepted it: renaming the
# counterfactual to `ceiling0pbXX` gave `-0.0001` and the gate printed
# "PASS: P1 planted fault rejected". The same hole greened the headline
# from the other side -- a crashed DENOMINATOR gave `ceiling/floorXX =
# 180.5` and "PASS: the ceiling arm costs 180.5x the floor".
#
# That is exit-gate item 8's own defect class (a check a TOTAL FAILURE
# satisfies) sitting inside the plant that is P1's only mechanism
# evidence. Round 26's `throw` on an unknown arm was real and never
# reached the harness.
run_arm() {
    local drv="$1" arm="$2" nn="$3" out="$4"
    if ! "$EIGS" "$drv" $arm "$nn" > "$out" 2>&1; then
        # stderr, not stdout: run_arm is called from inside `$( )`, so a
        # message on stdout is captured into the ratio variable and never
        # seen. The failure fires either way, but silently.
        echo "FAIL: arm '$arm' at N=$nn exited nonzero — a timing for a run that did not happen is not a measurement" >&2
        sed -n '1,3p' "$out" >&2; exit 1
    fi
    # ...and it must have run the arm we ASKED for. The driver prints the
    # requested name, so this also catches a dispatch that substitutes.
    if [ -n "$arm" ] && ! grep -q "^profiled $arm n=$nn " "$out"; then
        echo "FAIL: arm '$arm' at N=$nn did not report itself as executed:" >&2
        sed -n '1,3p' "$out" >&2; exit 1
    fi
}

paired_ratio() {
    local a_arm="$1" b_arm="$2" nn="$3" t=$(mktemp) ao=$(mktemp) bo=$(mktemp)
    local _r p0 p1 q0 q1
    for _r in 1 2 3 4 5; do
        p0=$(date +%s%N); run_arm tests/swarm_profile.eigs "$a_arm" "$nn" "$ao"; p1=$(date +%s%N)
        # NOTE: OVH is measured on the ARMED driver, which imports linalg and
        # solves the trim; the unarmed control does neither, so subtracting
        # the same constant from it inflates ceiling/unarmed slightly in the
        # PASS direction (~0.7% at N=16, far below the margin). Recorded
        # rather than corrected -- correcting it needs a second overhead
        # probe, and the bias is one-directional and an order of magnitude
        # under the bound.
        if [ "$b_arm" = "unarmed" ]; then
            q0=$(date +%s%N); run_arm tests/swarm_profile_unarmed.eigs "" "$nn" "$bo"; q1=$(date +%s%N)
        else
            q0=$(date +%s%N); run_arm tests/swarm_profile.eigs "$b_arm" "$nn" "$bo"; q1=$(date +%s%N)
        fi
        awk -v a="$p0" -v b="$p1" -v c="$q0" -v d="$q1" -v o="$OVH" \
            'BEGIN{ x=(b-a)/1e9-o; y=(d-c)/1e9-o; if (y<=0) y=0.001; printf "%.4f\n", x/y }' >> "$t"
    done
    sort -n "$t" | sed -n 3p; rm -f "$t" "$ao" "$bo"
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

# P1's MECHANISM, gated on the one comparison that can discriminate.
#
# Round 24 found round 23's gate was the same non-discriminating pair the
# rung had just condemned: `disciplined/onereader`, where swarm.eigs says
# in a comment this very file hash-pins that "comparing DISCIPLINED
# against ONEREADER cannot test arming, because both wrap the integration,
# so neither pays write cost whatever the arming granularity is". It was
# also one-sided and flaky -- three runs of the same ratio on this box gave
# 0.9889, 1.0432 and 1.2135, and the 1.2135 run FAILED the 1.20 bound. A
# gate whose own subject reports 0.99 and 1.21 is measuring the box.
#
# `ceiling0/floor` is different in kind. ceiling0 is the unwrapped ceiling
# shape with ZERO verdict reads, so if arming were per-binding or
# liveness-scoped it would collapse onto the floor. It does not: measured
# 1.2428 and 1.4173 on two runs, both far above 1. That is
# EigenScript#1046's per-EigsState arming, paid by a hot loop that reads
# no verdict at all, and it is what P1's mechanism half is about. The
# bound is wide because the spread above is wide; what it tests is the
# COLLAPSE, which is a factor-of-two effect, not a percentage.
# 1.20, not 1.10. Round 26 measured the counterfactual's spread across
# nine medians-of-five (0.898-1.041) and warned the 1.10 bound left ~6%
# headroom on a HARD FAIL in the red direction; the next run came in at
# 1.0599, 4% away. A plant that can red spuriously is a flake installed as
# a gate -- the defect round 24 removed from the previous P1 gate.
#
# 1.20 sits between the two populations with margin on BOTH sides:
# per-EigsState arming measures 1.38-1.53 (15%+ above), per-binding
# measures 0.90-1.06 (13%+ below). Widening it does not weaken the
# discrimination, because what the gate tests is a factor-of-1.4 collapse,
# not a percentage.
P1_BOUND=1.20
[ "$P1_BOUND" = "1.20" ] || { echo "FAIL: P1_BOUND is $P1_BOUND, declared 1.20 — a widened bound must be re-justified in ORACLE.md"; exit 1; }
p1r=$(paired_ratio ceiling0 floor "$LASTN")
printf "  ceiling0/floor at N=%s : %s  (bound: > %s)\n" "$LASTN" "$p1r" "$P1_BOUND"
ratio_ok "$p1r" "$P1_BOUND" || {
    echo "FAIL: a hot loop with ZERO verdict reads now costs <=${P1_BOUND}x the floor (ratio $p1r) —"
    echo "      arming has become finer than per-EigsState and EigenScript#1046 needs re-grading."
    exit 1; }
echo "PASS: P1 mechanism — zero-reader arming still costs ${p1r}x the floor at N=$LASTN"
# ...and the bound must be able to fail. The plant is a MEASUREMENT, not a
# literal: `ceiling0pb` is run_ceiling0 with every assignment individually
# wrapped in `unobserved:` and the loops left observed -- what per-binding
# or liveness-scoped arming would produce -- and it returns the IDENTICAL
# fleet digest, so only the observation shape differs. Round 25: the plant
# had been `ratio_ok 1.00`, which proves the bound can fail but not that
# the ARM can produce the failing value.
# The counterfactual's warrant is that it differs from ceiling0 ONLY in
# observation shape, and the evidence for that is an identical fleet
# digest. Round 27: that identity was asserted in three places and checked
# in none -- so a ceiling0pb that had silently drifted into a different
# workload would still have produced a plausible collapse. It is the same
# arm-differential this rung's W2 checks apply to the other six arms, and
# ceiling0pb was excluded from those because it lives in the driver.
D0=$(mktemp); DP=$(mktemp)
run_arm tests/swarm_profile.eigs ceiling0   2 "$D0"
run_arm tests/swarm_profile.eigs ceiling0pb 2 "$DP"
d0=$(grep -oP 'digest=\K\S+' "$D0"); dp=$(grep -oP 'digest=\K\S+' "$DP")
rm -f "$D0" "$DP"
[ -n "$d0" ] && [ "$d0" = "$dp" ] || {
    echo "FAIL: the per-binding counterfactual no longer flies the same fleet as ceiling0 ($d0 vs $dp) —"
    echo "      it differs in more than observation shape, so its collapse is not evidence about arming."
    exit 1; }
echo "PASS: counterfactual holds the physics fixed (digest $d0 == ceiling0's)"
pbr=$(paired_ratio ceiling0pb floor "$LASTN")
printf "  ceiling0pb/floor (per-binding counterfactual) at N=%s : %s\n" "$LASTN" "$pbr"
ratio_ok "$pbr" "$P1_BOUND" && {
    echo "FAIL: the per-binding counterfactual measured ${pbr}x, above the ${P1_BOUND} bound —"
    echo "      the gate cannot distinguish per-EigsState arming from per-binding arming."
    exit 1; }
echo "PASS: P1 planted fault rejected — per-binding arming collapses to ${pbr}x (<= $P1_BOUND)"
# The READ share is NOT gated, and that is the finding rather than a gap.
# Differencing ceiling against ceiling0 on this box does not resolve: one
# run gives a 36% read share, another 0.6%, and on the first ceiling1 (ONE
# reader) measured MORE than ceiling (sixteen), which is impossible. The
# arms are within noise of each other here, which is exactly what P1's
# verdict says.
# ...and the bound must be able to fail: a ratio of 1.00 is what "unobserved:
# buys nothing" would look like.
ratio_ok 1.00 "$DU_BOUND" && { echo "FAIL: the DU bound accepted 1.00 — it cannot fail"; exit 1; }
echo "PASS: DU planted fault rejected (ratio 1.00 <= $DU_BOUND)"
# PLANTED FAULT for the bound: a ratio of 1.00 is what "observation is free"
# would look like, and 1.15 must reject it.
PLANTED=$(awk 'BEGIN{ printf "%.2f", 1.0 }')
ratio_ok "$PLANTED" "$CF_BOUND" && { echo "FAIL: the CF bound accepted a planted ratio of $PLANTED — it cannot fail"; exit 1; }
echo "PASS: CF planted fault rejected (ratio $PLANTED <= $CF_BOUND)"
