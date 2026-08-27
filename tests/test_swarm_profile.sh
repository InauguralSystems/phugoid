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
if ( file_pin "$FP/mut.eigs" d937845d4045 55 ) >/dev/null 2>&1; then
    rm -rf "$FP"; echo "FAIL: file_pin ACCEPTED a halved frame count"; exit 1
fi
rm -rf "$FP"
echo "PASS: file_pin planted fault rejected (the real file_pin rejects a halved FRAMES)"

file_pin tests/swarm_profile.eigs         d937845d4045 55
file_pin tests/swarm_profile_unarmed.eigs ec298d5e32df 14
file_pin swarm.eigs                       7e9ade956d8b 283
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
file_pin swarm_unarmed.eigs               dba0a0d91cc7 58

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
    # ...and it must have run the arm we ASKED for. Round 28: this grepped
    # `^profiled $arm n=$nn`, which the driver prints from the REQUESTED
    # name -- so it could not catch a dispatch that substitutes, which is
    # the exact property round 26 identified as making substitution
    # invisible. The comment here claimed the opposite.
    #
    # Every arm FUNCTION self-reports its own name as the first token of
    # its own print line (`ceiling0pb 16 1500 0 <digest>`), and that is
    # what changes under substitution. Repointing ceiling0pb's dispatch at
    # run_floor -- the exact copy/paste hazard of a seven-branch elif chain
    # -- left the whole suite green, reporting floor/floor ~1.02 as "per-
    # binding arming collapses". It reds here now.
    local self="$arm"
    [ -n "$self" ] || self=unarmed
    # THE READ WITNESS. Round 32: the `hits` witness added at round 31
    # closed the hole at N=1 ONLY. Above N=1 it EXPECTS hits=0 -- because
    # P4's shared-binding collapse zeroes it -- which is exactly what a
    # gutted arm produces. So an N-scoped gutting (guts for n>1, keeps
    # n==1 intact) reproduced the pristine arm's self-report bit for bit
    # at every ladder point, and `disciplined` at N=16, the N where the DU
    # claim is asserted, was still witnessed by nothing. Both its guards
    # failed the same way: the timing ratio is one-sided so gutting the
    # DENOMINATOR raises it, and ORACLE itself says that arm measures
    # within noise of the floor, so a disciplined arm that IS the floor is
    # unfalsifiable by timing.
    #
    # `reads` is a counter the collapse cannot zero. Every arm increments
    # it once per channel read, inside `unobserved:` so it pays no entropy
    # walk. It is added to every arm, but the block cost is NOT common and
    # does NOT cancel: measured, ceiling/disciplined execute 2 blocks per
    # read, ceiling0/ceiling0pb 1, floor/unarmed 0. ORACLE retracts that
    # sentence; round 37 found this file still asserting it in the present
    # tense, which is round 24's own lesson recurring -- a claim retracted
    # in ORACLE stays alive in the file nobody greps. That instrumentation
    # is a deliberate cost --
    # it changed the pinned workload identity and the numbers were
    # re-banked against it, which is a decision rather than an accident.
    #
    #   n-reading arms  (ceiling, disciplined, floor, ceiling0, ceiling0pb)
    #                   -> reads == n * frames, at every N
    #   single-channel  (ceiling1, onereader) -> reads == frames
    #
    # `hits` is still checked, because it pins P4's collapse: 877 at N=1
    # for the N-reading observing arms and 0 above, 877 always for the
    # single-channel ones.
    # The frame count comes from the ARM'S OWN report, not a constant.
    # Round 32: the first version used a PROF_FRAMES=1500 literal and red
    # on the fixed-cost probe, which runs ONE frame -- the constant was
    # true of the ladder and false of the other caller. Reading it from
    # the line makes the witness self-describing and correct for both.
    local h rd ev fr
    fr=$(grep -oP "^$self $nn \K[0-9]+" "$out" | head -1)
    h=$(grep -oP "^$self $nn [0-9]+ \K[0-9]+" "$out" | head -1)
    rd=$(grep -oP "^$self $nn [0-9]+ [0-9]+ [0-9]+ \K[0-9]+" "$out" | head -1)
    ev=$(grep -oP "^$self $nn [0-9]+ [0-9]+ [0-9]+ [0-9]+ \K[0-9]+" "$out" | head -1)
    [ -n "$fr" ] && [ -n "$h" ] && [ -n "$rd" ] && [ -n "$ev" ] || { echo "FAIL: arm '$self' at N=$nn printed no frames/hits/reads/evals fields" >&2; sed -n '1,2p' "$out" >&2; exit 1; }
    local want_reads
    case "$self" in
        ceiling1|onereader) want_reads=$(( fr )) ;;
        *)                  want_reads=$(( nn * fr )) ;;
    esac
    [ "$rd" = "$want_reads" ] || {
        echo "FAIL: arm '$self' at N=$nn performed $rd channel reads, expected $want_reads —" >&2
        echo "      the arm has stopped reading its channel, and every ratio built on it is a null result." >&2
        sed -n '1,2p' "$out" >&2; exit 1; }
    # `reads` alone is not enough: round 32's N-scoped mutant kept the read
    # loop and moved it inside `unobserved:`, so it read the channel the
    # right number of times while OBSERVING none of them, and passed. What
    # distinguishes an observing arm is that its PREDICATE RAN. `evals`
    # counts predicate evaluations from inside BOTH branches of a
    # conditional on the predicate, so deleting the predicate deletes the
    # counter with it -- and unlike `hits` it is invariant to P4's
    # collapse, because a predicate that returns false has still run.
    local want_evals
    case "$self" in
        ceiling|disciplined|ceiling1|onereader) want_evals=$want_reads ;;
        floor|ceiling0|ceiling0pb|unarmed)      want_evals=0 ;;
        # NO PERMISSIVE DEFAULT. Round 36: `*) want_evals=0` meant any arm
        # outside the allowlist was expected to evaluate its predicate ZERO
        # times -- exactly what a gutted observing arm produces -- so a new
        # observing arm added to the driver would inherit "unwitnessed" as
        # its default. Round 34 removed this from `want_hits` twelve lines
        # down and left it here.
        *) echo "FAIL: arm '$self' is not classified as observing or silent, so its predicate count is unwitnessed" >&2; exit 1 ;;
    esac
    [ "$ev" = "$want_evals" ] || {
        echo "FAIL: arm '$self' at N=$nn evaluated its predicate $ev times, expected $want_evals —" >&2
        echo "      an observing arm whose predicate does not run is not observing, whatever it reads." >&2
        sed -n '1,2p' "$out" >&2; exit 1; }
    # THE VERDICT WITNESS — a BANKED value, not a formula.
    #
    # Round 33 defeated the previous witness: `evals` counted the branches
    # of the `if`, and the gate published its own target (`n * frames`), so
    # a mutant that got the read count right already knew the eval count,
    # and preserving it cost one line inside an `unobserved:` block the
    # gutting already opens. A counter whose expected value the gate can
    # DERIVE is a target, not a witness.
    #
    # The arms therefore read `oscillating`, not `diverging`. Two reasons,
    # both measured. (a) `diverging` COLLAPSES to 0 above N=1 under P4's
    # shared-binding interleave, so at N=4 and N=16 -- the ladder points
    # where the DU claim is actually asserted -- the healthy value and the
    # gutted value were the same number. `oscillating` does not collapse:
    # it MANUFACTURES verdicts on the interleave, which is round 1's
    # original P4 finding, giving 0 / 5533 / 19850 across the ladder.
    # (b) Those are not derivable from n and frames. A gutted arm can only
    # reproduce them by hard-coding three constants copied from a pristine
    # run -- a categorically louder mutation than a `+1`.
    #
    # Same call count as before, so no new cost bias: this is a swap, not
    # an addition.
    #
    # RESIDUAL, stated rather than papered over: at N=1 there is no
    # interleave, the channel is clean and a decaying phugoid produces
    # `oscillating` 0 -- so the healthy and gutted values coincide there,
    # exactly as they did above N=1 before. N=1 is covered instead by the
    # CF timing gate (a gutted ceiling collapses ceiling/floor toward 1.0
    # and reds) and by `reads`. The single-channel arms read one clean
    # channel and so report 0 at every N; they are executed by no gate
    # here, and their branch is kept only so a future caller inherits the
    # check rather than silently getting none.
    # THE PHYSICS WITNESS, for the DENOMINATOR arms.
    #
    # Round 35: rounds 31-34 closed the gutted-arm hole on the NUMERATOR
    # arms only. Every assertion here is one-sided with the observing arm
    # on top, and for `floor`/`ceiling0`/`ceiling0pb`/`unarmed` all three
    # counters expect exactly what a gutted arm produces -- hits=0,
    # evals=0, and `reads == nn*fr` where `fr` is read from the arm's OWN
    # self-report, so it is self-consistent at any frame count. That is
    # round 33's rule ("a counter whose expected value the gate can DERIVE
    # is a target, not a witness") applied to the numerator and never to
    # the denominator.
    #
    # Demonstrated: an `unarmed` control integrating every OTHER frame
    # above N=7 kept every inspected field bit-identical and was ACCEPTED
    # -- and it did not merely evade the gate, it DOUBLED the headline
    # (ceiling/unarmed 1.47 -> 2.86). A halved FRAMES was accepted the
    # same way. That is plant w2's own defect class, in the arm ORACLE
    # records as having already once silently flown a different aircraft.
    #
    # The discriminator was on the same line and being parsed past: field
    # 5, the fleet digest, moved 4466955440 -> 4458131063. The comment
    # further down is right that arm-invariance makes the digest useless
    # for proving ONE arm differs only in observation shape -- and that is
    # exactly what makes it the correct CROSS-ARM witness here. Banked per
    # (N, frames), with the same no-silent-default discipline as the
    # verdict counts.
    local want_digest
    case "$nn $fr" in
        "1 1500")  want_digest=279590118 ;;
        "2 1500")  want_digest=559690091 ;;
        "4 1500")  want_digest=1119436234 ;;
        "16 1500") want_digest=4466955440 ;;
        "1 1")     want_digest=279212764 ;;
        *)         want_digest=UNBANKED ;;
    esac
    local dg; dg=$(grep -oP "^$self $nn [0-9]+ [0-9]+ \K[0-9]+" "$out" | head -1)
    if [ "$want_digest" = "UNBANKED" ]; then
        echo "FAIL: no banked fleet digest for N=$nn, frames=$fr — the ladder or the frame count moved" >&2
        echo "      and every arm at this point is now unwitnessed on physics. Bank it from a pristine run." >&2
        exit 1
    fi
    [ "$dg" = "$want_digest" ] || {
        echo "FAIL: arm '$self' at N=$nn flew a different fleet (digest $dg, banked $want_digest) —" >&2
        echo "      the arms differ only in OBSERVATION, so a digest that moves means this arm is" >&2
        echo "      doing different physics: fewer frames, a different fleet, or a skipped step." >&2
        sed -n '1,2p' "$out" >&2; exit 1; }

    local want_hits
    case "$self $nn $fr" in
        "ceiling 1 1500"|"disciplined 1 1500")   want_hits=0 ;;
        "ceiling 4 1500"|"disciplined 4 1500")   want_hits=5533 ;;
        "ceiling 16 1500"|"disciplined 16 1500") want_hits=19850 ;;
        "ceiling1 "*|"onereader "*)              want_hits=0 ;;
        "floor "*|"ceiling0 "*|"ceiling0pb "*|"unarmed "*) want_hits=0 ;;
        # NO SILENT DEFAULT. Round 34: this was `want_hits=""` plus an
        # `[ -n "$want_hits" ]` guard, so any (arm, N, frames) triple not
        # in the rows above skipped the witness WITHOUT SAYING SO. Since
        # `want_reads`/`want_evals` are computed they stayed total, and
        # the only non-derivable check -- the only real witness -- was the
        # one with a lookup and a silent fallback.
        #
        # That is a live edit path in this rung's own history: ORACLE
        # records a round-4 note that the ladder moved to 4/16/32 which
        # was never applied. Making that one-line edit leaves LADDER_N
        # correct and every timing bound intact, and silently unwitnesses
        # `disciplined` at all three points -- the hole rounds 31-33 spent
        # three rounds closing. Demonstrated: a fully gutted `disciplined`
        # was ACCEPTED at N=32 (hits=0, reads and evals and digest all
        # intact) purely because 32 is not a banked row.
        *) want_hits="UNBANKED" ;;
    esac
    case "$self:$want_hits" in
        ceiling:UNBANKED|disciplined:UNBANKED)
            echo "FAIL: no banked verdict count for arm '$self' at N=$nn, frames=$fr —" >&2
            echo "      the ladder moved and this arm is now unwitnessed. Bank the count from a" >&2
            echo "      pristine run before gating on it; a lookup miss must not be a pass." >&2
            exit 1 ;;
    esac
    if [ "$want_hits" != "UNBANKED" ] && [ "$h" != "$want_hits" ]; then
        echo "FAIL: arm '$self' at N=$nn fired its predicate $h times, expected the banked $want_hits —" >&2
        echo "      DO NOT RE-BANK THIS WITHOUT READING THE NEXT TWO LINES. file_pin ran before this" >&2
        echo "      check and passed, which proves swarm.eigs and the drivers are BYTE-IDENTICAL to" >&2
        echo "      the versions these counts were taken from. The physics therefore cannot have" >&2
        echo "      changed, so a mismatch here is either an upstream runtime change (re-bank, and say" >&2
        echo "      which upstream change in the commit) or a real regression in observation (do not)." >&2
        sed -n '1,2p' "$out" >&2; exit 1
    fi
    if ! grep -q "^$self $nn " "$out"; then
        echo "FAIL: arm '$self' at N=$nn did not report itself as executed — a different arm ran:" >&2
        sed -n '1,3p' "$out" >&2; exit 1
    fi
}

# The unarmed control lives in its OWN driver, so an arm name has to pick
# the driver. This was inlined for the b-arm only, which made `unarmed`
# usable as the second arm and nowhere else -- and the second headline's
# gate needs it as the FIRST.
_run_one() { # _run_one <arm> <n> <out>
    if [ "$1" = "unarmed" ]; then run_arm tests/swarm_profile_unarmed.eigs "" "$2" "$3"
    else run_arm tests/swarm_profile.eigs "$1" "$2" "$3"; fi
}

paired_ratio() {
    local a_arm="$1" b_arm="$2" nn="$3" t=$(mktemp) ao=$(mktemp) bo=$(mktemp)
    local _r p0 p1 q0 q1
    for _r in 1 2 3 4 5; do
        p0=$(date +%s%N); _run_one "$a_arm" "$nn" "$ao"; p1=$(date +%s%N)
        # NOTE: OVH is measured on the ARMED driver, which imports linalg and
        # solves the trim; the unarmed control does neither, so subtracting
        # the same constant from it inflates ceiling/unarmed slightly in the
        # PASS direction (~0.7% at N=16, far below the margin). Recorded
        # rather than corrected -- correcting it needs a second overhead
        # probe, and the bias is one-directional and an order of magnitude
        # under the bound.
        q0=$(date +%s%N); _run_one "$b_arm" "$nn" "$bo"; q1=$(date +%s%N)
        awk -v a="$p0" -v b="$p1" -v c="$q0" -v d="$q1" -v o="$OVH" \
            'BEGIN{ x=(b-a)/1e9-o; y=(d-c)/1e9-o;
                    # REFUSE a non-positive denominator instead of clamping
                    # it. Round 30: `if (y<=0) y=0.001` manufactured a
                    # ~1000x ratio in the PASS direction whenever the fixed
                    # cost met or exceeded the measured arm -- the
                    # OVH-dominates case the comment below says the gate
                    # "should say so instead of reporting a ratio", which
                    # nothing implemented. One-sided fudges are how a gate
                    # stops being able to fail.
                    if (y<=0 || x<=0) { print "NONPOSITIVE"; exit 0 }
                    printf "%.4f\n", x/y }' >> "$t"
    done
    if grep -q NONPOSITIVE "$t"; then
        echo "FAIL: the fixed cost (${OVH}s) met or exceeded a measured arm at N=$nn — subtracting it is amplifying noise, not removing a bias, so there is no ratio to report" >&2
        rm -f "$t" "$ao" "$bo"; exit 1
    fi
    sort -n "$t" | sed -n 3p; rm -f "$t" "$ao" "$bo"
}

# ratio_ok <value> <bound> -> 0 if value > bound. ONE implementation, shared
# by every arm and by every plant that validates one. Round 3: the DU and CF
# plants each re-typed the awk expression instead of calling the gate --
# mechanical-gates SS99, in the same file whose file_pin plant does it right.
ratio_ok() { awk -v x="$1" -v b="$2" 'BEGIN{ exit !(x > b) }'; }

mins() {  # minimum of 5 wall-clock seconds
    # Round 29: the round-28 status check here PRINTED FAIL AND EXITED 0.
    # The timing loop was the left-hand side of `done | sort -n | head -1`,
    # so `exit 1` killed only the loop subshell, `head` returned 0, and the
    # trailing `rm -f` reset the status -- so `mins` returned SUCCESS with
    # empty stdout and the caller's `OVH=$(mins ...)` never tripped
    # errexit. Measured end-to-end with a wrapper that kills the
    # fixed-cost probe: the gate printed "a timing for a run that did not
    # happen is not a measurement", then printed "fixed cost (1 frame): s",
    # then reported every ratio and exited 0. OVH became the empty string,
    # which `awk -v o=` reads as 0 -- so the estimator ORACLE describes
    # (fixed cost subtracted from every arm) was not the estimator that
    # ran, and nothing noticed.
    #
    # This is the same swallow round 27 removed from paired_ratio, one
    # function down, and it is the "prints FAIL, exits 0" shape this
    # repo's own guard hook exists to catch. No pipeline in the path now:
    # the tempfile idiom paired_ratio already uses.
    # Two call shapes: `mins <driver> <arm> <n>` for the armed driver and
    # `mins <unarmed-driver> <n>` for the control, which takes N as its
    # only argument. Normalised here so run_arm gets (driver, arm, n) in
    # both cases and the control's self-report is checked too -- round 29
    # noted mins was the only producer with no substitution guard, and the
    # four PRINTED columns plus OVH are mins-only.
    local drv="$1" arm nn
    if [ "$#" -ge 3 ]; then arm="$2"; nn="$3"; else arm=""; nn="$2"; fi
    local tf; tf=$(mktemp); local mo; mo=$(mktemp)
    local _i t0 t1
    for _i in 1 2 3 4 5; do
        t0=$(date +%s%N)
        run_arm "$drv" "$arm" "$nn" "$mo"
        t1=$(date +%s%N)
        awk -v a="$t0" -v b="$t1" 'BEGIN{ printf "%.3f\n", (b-a)/1000000000 }' >> "$tf"
    done
    sort -n "$tf" | head -1
    rm -f "$tf" "$mo"
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
    # EVERY ladder point carries a verdict again, and a sub-bound point is
    # RE-MEASURED rather than excused.
    #
    # Round 29 moved this assertion from the ladder's worst point to its
    # largest, on the argument that small N is unresolvable under load.
    # Round 30 proved that was a RELAXATION: a mutant that guts the
    # ceiling arm's observation for n < 8 -- identical fleet digests,
    # identical self-report, only the observation shape changed -- passed
    # at 0.92 and 0.99, and had been fatal before the change. Worse, the
    # argument was backwards on this rung's own data: ORACLE's table has
    # the ratio SMALLEST at small N (1.343 at N=1 against 1.489 at N=32),
    # so small N is exactly where a partial loss of observation shows
    # first. Dropping the verdict there dropped the two most sensitive
    # points.
    #
    # A sub-bound point is either contention or a dead arm, and the old
    # gate could not tell them apart -- which is what made it flake AND
    # what made the relaxation tempting. It can tell them apart now:
    # contention does not reproduce, a gutted arm does. Re-measure twice
    # more and gate on the median of the three. Costs nothing on a healthy
    # run and ~2 s when the box is loaded.
    # SYMMETRIC about the decision. Round 31: re-measuring only BELOW the
    # bound is a one-sided filter -- it can move a verdict FAIL->PASS and
    # never the reverse, lifting the escape probability for an arm sitting
    # exactly at the bound from 0.50 to 0.75. That is the shape this file
    # condemns 140 lines up, in the commit that removed the last one. Any
    # first reading inside the ambiguous band (within 20% above the bound,
    # or anywhere below it) gets three shots, whichever side it started.
    #
    # The band is 10%, not the 20% round 31 first used: measured, the
    # healthy population on this box is 1.33-1.50 and 1.15*1.20 = 1.38
    # sits inside it, so N=4 and N=16 re-measured on a CLEAN run and cost
    # ~26 s. 1.15*1.10 = 1.265 clears the observed minimum with margin
    # while still covering the ambiguous zone around the bound. The
    # "costs nothing on a healthy run" claim was written for round 30's
    # below-bound-only trigger and was false for a full round.
    if awk -v x="$rmed" -v b="$CF_BOUND" 'BEGIN{ exit !(x <= b * 1.10) }'; then
        echo "  N=$n came in at $rmed, inside the ambiguous band around $CF_BOUND — re-measuring, because contention does not reproduce and a dead arm does"
        r2=$(paired_ratio ceiling floor "$n")
        r3=$(paired_ratio ceiling floor "$n")
        rmed=$(printf '%s\n%s\n%s\n' "$rmed" "$r2" "$r3" | sort -n | sed -n 2p)
        echo "  N=$n re-measured: median of three is $rmed"
    fi
    # loop-only times: the ratio the rung actually claims
    r=$(awk -v x="$rmed" 'BEGIN{ printf "%.2f", x }')
    printf "%4s %9s %12s %8s %9s %9s\n" "$n" "$c" "$d" "$f" "$u" "$r"
    NVALID=$((NVALID+1))
    # WORST tracks the RAW median, not the 2-decimal printed value -- round
    # 30: the gated quantity and the reported one differed in the last
    # digit.
    WORST=$(awk -v w="$WORST" -v x="$rmed" 'BEGIN{ print (x<w)?x:w }')
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
# GATED ON THE WORST LADDER POINT, restored at round 30 after round 29's
# move to the largest N was shown to be a relaxation (see the loop above).
# The flake that motivated the move is handled by re-measurement, not by
# dropping the verdict.
echo "worst ceiling/floor across the ladder = $WORST at its weakest N  (bound: > $CF_BOUND)"
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

# THE SECOND HEADLINE, gated at last (round 45).
#
# ORACLE's second headline is that `unobserved:` buys back essentially the
# whole penalty -- the disciplined arm within noise of the floor and of the
# unarmed control AT EVERY N -- and "What is being measured" calls
# `disciplined - floor` the number that justifies or kills #915's natural
# successor. That number was published at NO N and gated at NO N. The only
# assertion touching the arm was `ceiling/disciplined > 1.20` above: ONE
# SIDED, against the ceiling, at the largest ladder point only. With
# ceiling/floor measured at 1.40-1.46 that permits disciplined/floor up to
# ~1.17-1.22 -- an ungated band roughly DOUBLE the +-10% the residual
# itself calls unresolvable.
#
# Demonstrated before this existed: make the disciplined arm integrate one
# frame in three in OBSERVED context -- the exact regression the headline
# says does not happen, and the shape of a plausible edit that leaves one
# branch of a conditional unwrapped. Its self-report is BIT-IDENTICAL to
# pristine on every field rounds 31-37 built: banked hits, fleet digest,
# reads, evals, frames. All four witnesses hold, because every one of them
# detects an arm doing LESS work and this arm does MORE. The suite passed
# twice while disciplined/floor at N=16 went 1.0327 -> 1.2663.
#
# So the residual is gated TWO-SIDED, at every ladder point, with the same
# paired estimator. The band is +-10%: not a number invented here, but the
# noise floor ORACLE already publishes, so the gate enforces the claim as
# stated rather than one tuned to today's measurement. Measured on this box
# the six ratios span 0.9855..1.0342, ~3x inside it.
DF_LO=0.90
DF_HI=1.10
in_band() { awk -v x="$1" -v lo="$2" -v hi="$3" 'BEGIN{ exit !(x >= lo && x <= hi) }'; }
for nm in disciplined unarmed; do
    for n in 1 4 16; do
        dfr=$(paired_ratio "$nm" floor "$n")
        printf "  %-11s/floor at N=%-2s : %s  (band: %s..%s)\n" "$nm" "$n" "$dfr" "$DF_LO" "$DF_HI"
        in_band "$dfr" "$DF_LO" "$DF_HI" || {
            echo "FAIL: $nm/floor at N=$n is $dfr, outside [$DF_LO, $DF_HI] —"
            echo "      the second headline says this arm sits within noise of the floor at EVERY N."
            echo "      Above the band, \`unobserved:\` stopped eliding the work; below it, the floor did."
            exit 1; }
    done
done
echo "PASS: disciplined and unarmed both sit within [$DF_LO, $DF_HI] of the floor at every ladder point"

# ...and the band must be able to fail, in BOTH directions. 1.2663 is not a
# round number: it is what round 45's mutant actually measured.
in_band 1.2663 "$DF_LO" "$DF_HI" && { echo "FAIL: the residual band accepted 1.2663 — round 45's mutant would pass"; exit 1; }
in_band 0.80   "$DF_LO" "$DF_HI" && { echo "FAIL: the residual band accepted 0.80 — a collapsed floor would pass"; exit 1; }
in_band 1.00   "$DF_LO" "$DF_HI" || { echo "FAIL: the residual band rejected 1.00 — it cannot pass"; exit 1; }
echo "PASS: residual band planted faults rejected (1.2663 high, 0.80 low) and 1.00 accepted"

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
# per-EigsState arming measures 1.41-1.57 across sessions and per-binding
# 0.90-1.07, so 1.20 separates them. The margin is NOT uniform, and the
# comment used to claim "15%+ above": one earlier session measured
# ceiling0/floor at 1.2428, which is 3.6% above the bound. ORACLE records
# that residual rather than smoothing it, and so does this file now.
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
# The digest agreement, kept as a REGRESSION check and no longer claimed
# as the counterfactual's warrant.
#
# Round 28: the digest is arm-INVARIANT -- every arm in the rung prints
# 559690091 at N=2, which is P4's own gated finding ("the arms differ only
# in observation and their fleet digests match exactly"). An agreement
# shared by all seven arms cannot be the evidence that one of them differs
# only in observation shape, and round 27 installed it as exactly that.
# `fleet_digest` sums fleet state only; `acc` -- the inner per-aircraft
# loop the counterfactual is about -- never enters it.
#
# What discriminates is the executed arm's SELF-REPORT, checked in
# run_arm above. This stays because a digest that stopped matching would
# mean the driver had diverged from the workload, which is worth knowing.
D0=$(mktemp); DP=$(mktemp)
run_arm tests/swarm_profile.eigs ceiling0   2 "$D0"
run_arm tests/swarm_profile.eigs ceiling0pb 2 "$DP"
d0=$(grep -oP 'digest=\K\S+' "$D0"); dp=$(grep -oP 'digest=\K\S+' "$DP")
rm -f "$D0" "$DP"
[ -n "$d0" ] && [ "$d0" = "$dp" ] || {
    echo "FAIL: the per-binding counterfactual no longer flies the same fleet as ceiling0 ($d0 vs $dp) —"
    echo "      it differs in more than observation shape, so its collapse is not evidence about arming."
    exit 1; }
echo "PASS: driver and workload agree on the fleet (digest $d0; arm-invariant, so not a discriminator)"
pbr=$(paired_ratio ceiling0pb floor "$LASTN")
printf "  ceiling0pb/floor (per-binding counterfactual) at N=%s : %s\n" "$LASTN" "$pbr"
# TWO-SIDED. Round 31: this was `ratio_ok pbr 1.20 && FAIL`, so any
# DEGRADATION of the counterfactual lowered its ratio and made the plant
# "succeed" more easily -- a plant that gets easier to pass as its own arm
# gets worse is not a plant. ORACLE's measured population for this arm is
# 0.898-1.041, so a floor of 0.85 admits the spread while rejecting an arm
# that has stopped doing the work.
P1_PLANT_FLOOR=0.85
awk -v x="$pbr" -v lo="$P1_PLANT_FLOOR" -v hi="$P1_BOUND" 'BEGIN{ exit !(x > lo && x <= hi) }' || {
    echo "FAIL: the per-binding counterfactual measured ${pbr}x, outside [${P1_PLANT_FLOOR}, ${P1_BOUND}] —"
    echo "      above the bound it cannot distinguish per-EigsState from per-binding arming;"
    echo "      below the floor the counterfactual arm has itself stopped doing the work."
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
