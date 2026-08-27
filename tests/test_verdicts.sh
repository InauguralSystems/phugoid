#!/usr/bin/env bash
# The PREDICTIONS' verdicts, gated.
#
# Round 22: exit gate item 7 ("every prediction carries a VERDICT and a
# gate") was added by round 21 -- in a commit that left P1 ungated. P1's
# verdict could be inverted from CONFIRMED to REFUTED, its mechanism
# declared resolved, and its impossible negative read-shares replaced with
# a clean monotone +91/+92/+93, with the entire rung-4 suite still green.
# A rule violated by the commit that introduces it is worth more than the
# rule, so both P1 and P2 are gated here.
#
# Round 21 found P2 was the only one of the four predictions with NO
# verdict, no claim ID and no planted fault anywhere in the repo — while
# BOTH clauses of its registered refutation condition were met by ORACLE's
# own numbers. Twenty rounds went at P3, which had a gate from round 1.
# P2 had none, and nothing looked at it after round 3. That ordering is
# not a coincidence: the component without an oracle is the one that goes
# wrong quietly.
#
# The timing itself cannot be gated deterministically on a contended
# 2-core box — that is `tests/test_swarm_profile.sh`'s job, and it asserts
# ratios. What IS deterministic is the arithmetic that turns the banked
# sweep into P2's verdict, and that is what this file pins: the two OLS
# fits, the C6 comparison, and the two refutation clauses. It catches a
# silent edit to the table, to the C6 constant, or to the hand count.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# The banked 3000-frame sweep, exactly as published in ORACLE.md. Kept
# here as data so the fits are recomputed rather than transcribed —
# transcription is how the 33.5 µs "slope" (round 3) and the 41.6 µs
# figure (round 8) entered the write-up as numbers nobody could reproduce.
# Both turned out to be single POINTS of this table: 33.5 is N=1 of the
# observer column, 41.6 is N=16.
TABLE="1 0.399 0.297
2 0.750 0.524
4 1.456 1.022
8 2.829 1.983
16 6.090 4.093
32 13.011 8.741"
FRAMES=3000
C6_PER_WRITE=0.154   # µs per observed scalar write, measured at rung 3
HAND_COUNT=150       # observed assignments per aircraft-frame, hand count

fit() {  # fit <col: 2=ceiling 3=floor 0=observer> -> "slope intercept r2"
    echo "$TABLE" | awk -v col="$1" '
    { n=$1; y=(col==0) ? ($2-$3) : $col; X[NR]=n; Y[NR]=y; sx+=n; sy+=y; sxx+=n*n; sxy+=n*y; k++ }
    END {
        m=(k*sxy-sx*sy)/(k*sxx-sx*sx); b=(sy-m*sx)/k; ybar=sy/k
        for (i=1;i<=k;i++) { ss+=(Y[i]-ybar)^2; rs+=(Y[i]-(m*X[i]+b))^2 }
        printf "%.5f %.5f %.5f", m, b, 1-rs/ss
    }'
}
per_ac() {  # per_ac <col> <N> -> µs per aircraft-frame
    echo "$TABLE" | awk -v col="$1" -v want="$2" -v fr="$FRAMES" \
        '$1==want { y=(col==0) ? ($2-$3) : $col; printf "%.1f", 1e6*y/(want*fr) }'
}

fail=0
chk() { if [ "$1" = "1" ]; then echo "PASS $2"; else echo "FAIL $2"; fail=1; fi; }

# The banked table must BE the published one. Round 22: the header claimed
# this file "catches a silent edit to the table" while it only protected
# its own private copy -- editing ORACLE's N=32 row (which moves the
# headline ratio, the 45.0 us slope and the +26% drift) left the gate
# green. It guards the published number now.
while read -r n c f; do
    grep -qF "| $n | $c | $f |" ORACLE.md \
        || { echo "FAIL P2.banked: row N=$n ($c, $f) is not the row published in ORACLE.md"; fail=1; }
    :
done <<<"$TABLE"
[ "$fail" -eq 0 ] && chk 1 "P2.banked: all six sweep rows match ORACLE's published table"

read -r OM OB OR2 <<<"$(fit 0)"
read -r FM FB FR2 <<<"$(fit 3)"

# --- the OBSERVER's slope, which is what P2 is about. Round 3 found the
# published fit (0.272 N − 0.083) was the FLOOR column — the arm with no
# observer in it — and round 21 found the linearity VERDICT was still
# being read off that same floor fit eighteen rounds later.
OBS_US=$(awk -v m="$OM" -v fr="$FRAMES" 'BEGIN{ printf "%.1f", 1e6*m/fr }')
chk "$(awk -v x="$OBS_US" 'BEGIN{print (x>44.0 && x<46.0)?1:0}')" \
    "P2.slope: observer marginal cost is ${OBS_US} µs/aircraft-frame (fit of ceiling−floor, not floor)"
chk "$(awk -v x="$FM" 'BEGIN{print (x>0.2720 && x<0.2726)?1:0}')" \
    "P2.floorfit: the floor arm still fits ${FM} N — the number ORACLE must NOT use for the observer verdict"

# --- CLAUSE 2: does the slope miss the C6-derived prediction?
C6_US=$(awk -v p="$C6_PER_WRITE" -v h="$HAND_COUNT" 'BEGIN{ printf "%.1f", p*h }')
MISS=$(awk -v a="$OBS_US" -v b="$C6_US" 'BEGIN{ printf "%.2f", a/b }')
chk "$(awk -v m="$MISS" 'BEGIN{print (m>=1.5)?1:0}')" \
    "P2.c6miss: measured slope ${OBS_US} µs vs C6-derived ${C6_US} µs = ${MISS}x — clause 2 of P2's refutation FIRES"

# --- CLAUSE 1: is the observer arm superlinear? Per-aircraft cost must
# rise with N once past the small-N overhead. The floor drifts too, which
# is why the comparison matters: ORACLE called the floor's drift "small"
# and assessed linearity on it.
O8=$(per_ac 0 8);  O32=$(per_ac 0 32)
F8=$(per_ac 3 8);  F32=$(per_ac 3 32)
ODRIFT=$(awk -v a="$O8" -v b="$O32" 'BEGIN{ printf "%.0f", 100*(b-a)/a }')
FDRIFT=$(awk -v a="$F8" -v b="$F32" 'BEGIN{ printf "%.0f", 100*(b-a)/a }')
chk "$(awk -v d="$ODRIFT" 'BEGIN{print (d>=20)?1:0}')" \
    "P2.superlinear: observer per-aircraft cost drifts ${ODRIFT}% from N=8 to N=32 — clause 1 of P2's refutation FIRES"
chk "$(awk -v o="$ODRIFT" -v f="$FDRIFT" 'BEGIN{print (o>=2*f)?1:0}')" \
    "P2.drift: the observer arm drifts ${ODRIFT}% against the floor's ${FDRIFT}% — the arm ORACLE fitted understates it by >=2x"

# --- the verdict must be STATED. Exit gate item 3 requires every
# prediction reported with its measurement and any refuted one stated as
# refuted. P1, P3 and P4 carried verdicts; P2 carried a description.
grep -q '^\*\*P2 — REFUTED' ORACLE.md \
    && chk 1 "P2.verdict: ORACLE states P2's verdict" \
    || chk 0 "P2.verdict: ORACLE does not state P2 as REFUTED (exit gate item 3)"

# =====================================================================
# P1 -- "reducing readers buys ~nothing, and the MECHANISM IS NOT
# RESOLVED". Round 22 found this was the last ungated prediction, and that
# its verdict could be inverted with the whole suite green.
#
# P1's evidence is a read-share decomposition: the fraction of the
# observer's marginal cost attributable to READS rather than to arming,
# obtained by differencing the ceiling arm against ceiling1/ceiling0.
# Round 23 RETRACTED the framing this paragraph used to carry. It said
# the decomposition was "a one-off with no committed producer" and that
# what was gateable was therefore "the ARGUMENT it carries". Both halves
# were false: tests/swarm_profile.eigs is the producer and is hash-pinned,
# and the argument's premise (a negative read share is impossible) was an
# ordinary sign flip. Round 24 found this comment still asserting the
# retracted version in the present tense, twenty lines above the block
# retracting it -- and P3.producer greps ORACLE.md only, so it certified
# "the false justification is gone" from the one file where it was not.
# The banked shares, as re-measured at round 23. The N=32 point is the
# unstable one: three runs gave +5.2, +1.7, -2.8, so its SIGN is not a
# property of the system. It is banked as a record, not as a pin on a
# conclusion -- round 22 made `a negative share is impossible` the pin on
# P1's verdict, and that premise was false.
P1_SHARES="8 -21.5
16 -4.8
32 1.7"

# Every share must be the published one.
# Round 25: this was an unanchored grep over the whole 2500-line file, so
# the (N, share) ASSOCIATION -- the entire content of a decomposition --
# was unpinned: putting N=32's value at N=8 still passed. And the summary
# line below printed PASS unconditionally, so a real failure was followed
# immediately by "matches ORACLE". The triple was also SPLICED -- two
# points from the banked run plus a median of three later re-runs -- and
# appears nowhere in ORACLE as a triple, so it is no longer banked as one.
P1_RANGE_OK=1
grep -q 'ranges \*\*-5.6% to +27.6%\*\*' ORACLE.md || P1_RANGE_OK=0
chk "$P1_RANGE_OK" "P1.banked: ORACLE publishes the read share as a RANGE over interleaved replicates, not a spliced triple"

# THE ARGUMENT IS RETRACTED. Round 22 gated the impossibility of a
# negative read share -- "it says the arm that does fewer reads took
# longer" -- and made `NEG >= 1` the pin on P1's verdict. Round 23 showed
# the premise is false: the read share is a ~1.5%-of-total quantity taken
# as the difference of two ~5 s wall times, and the SAME N=32 measurement
# came out -2.8% and +5.2% ninety seconds apart. A negative share is not
# impossible, it is an ordinary sign flip, so `NEG >= 1` pinned which
# sample got banked rather than a property of the system. Worse, the
# justification for gating an argument at all -- "no committed producer"
# -- was itself false: tests/swarm_profile.eigs dispatches
# ceiling1/ceiling0/onereader and is hash-pinned.
#
# P1 is now MEASURED, in tests/test_swarm_profile.sh, as ceiling0/floor at
# the largest ladder point -- the zero-verdict-read arm against the
# unobserved floor. (Round 25: this said disciplined/onereader, the pair
# round 24 REMOVED because swarm.eigs says it cannot test arming. Round 24
# fixed one stale present-tense comment in this file and introduced two.) What remains here is the check that the verdict text
# still says what the measurement supports, and that the retracted
# justification does not creep back.
# Pinned on the verdict's SUBSTANCE, not on a figure. Round 25: this
# grepped an exact-string match on "31 of 32" -- a number the same ORACLE
# section calls wrong -- so correcting the error FAILED the suite while
# the retracted premise sitting beside it was invisible. A gate that
# enforces the one clause which must not change is worse than no gate.
grep -q 'the ARMING half is settled, the READ half is not' ORACLE.md \
    && chk 1 "P1.verdict: ORACLE states which half of P1's mechanism resolves" \
    || chk 0 "P1.verdict: ORACLE no longer distinguishes the resolved arming half from the unresolved read half (exit gate item 7)"

# ...and the retracted premise must not come back. Matched in ASSERTION
# form: the retraction quotes it, so a bare grep reds on its own fix.
grep -q 'negative share is impossible, so the split is noise' ORACLE.md \
    && chk 0 "P1.premise: the retracted 'a negative share is impossible' argument is asserted again" \
    || chk 1 "P1.premise: the retracted impossibility argument stays retracted"

# Matched in ASSERTION form only. The retraction quotes the phrase, so a
# bare grep cannot tell a claim from its withdrawal -- it reds on the
# paragraph that fixes it.
grep -q 'with no committed producer' ORACLE.md \
    && chk 0 "P1.producer: ORACLE still claims the read-share decomposition has no committed producer — tests/swarm_profile.eigs is that producer and is hash-pinned" \
    || chk 1 "P1.producer: the false 'no committed producer' justification is gone"

grep -qE '^N = 8, 16, 32 the read share came out .*\+29\.8' ORACLE.md \
    && chk 0 "P1.reproduce: ORACLE still publishes +29.8% at N=32, which three re-runs did not reproduce (+5.2, +1.7, -2.8)" \
    || chk 1 "P1.reproduce: the unreproducible +29.8% figure is retracted"

grep -q 'P1 — its registered condition is UNSATISFIABLE' ORACLE.md \
    && chk 1 "P1.item8: P1's registered condition is recorded as defective (exit gate item 8)" \
    || chk 0 "P1.item8: P1's registered condition is not recorded as defective — it compares two arms that BOTH wrap the integration, so the difference it reads is zero whether P1 is true or false"

# --- PLANTED FAULTS. A gate that has never failed has not been shown to
# work, and this one is new.
# Re-run the same arithmetic against a mutated table and require the
# clause to STOP firing. A refutation clause that fires on every possible
# table is not a measurement -- which is the defect rounds 17 and 18 found
# in two controls in a row.
mutant_check() { # mutant_check <name> <sed-expr> <clause>
    local T
    T=$(echo "$TABLE" | sed -E "$2")
    [ "$T" != "$TABLE" ] || { echo "FAIL: plant $1 changed nothing (vacuous plant)"; fail=1; return; }
    local m i r us miss d8 d32 drift
    read -r m i r <<<"$(TABLE="$T" ; echo "$T" | awk '
        { n=$1; y=$2-$3; X[NR]=n; Y[NR]=y; sx+=n; sy+=y; sxx+=n*n; sxy+=n*y; k++ }
        END { m=(k*sxy-sx*sy)/(k*sxx-sx*sx); b=(sy-m*sx)/k; ybar=sy/k
              for (j=1;j<=k;j++){ ss+=(Y[j]-ybar)^2; rs+=(Y[j]-(m*X[j]+b))^2 }
              printf "%.5f %.5f %.5f", m, b, 1-rs/ss }')"
    us=$(awk -v mm="$m" -v fr="$FRAMES" 'BEGIN{ printf "%.1f", 1e6*mm/fr }')
    miss=$(awk -v a="$us" -v b="$C6_US" 'BEGIN{ printf "%.2f", a/b }')
    d8=$(echo "$T" | awk -v fr="$FRAMES" '$1==8 { printf "%.1f", 1e6*($2-$3)/(8*fr) }')
    d32=$(echo "$T" | awk -v fr="$FRAMES" '$1==32 { printf "%.1f", 1e6*($2-$3)/(32*fr) }')
    drift=$(awk -v a="$d8" -v b="$d32" 'BEGIN{ printf "%.0f", 100*(b-a)/a }')
    case "$3" in
        c6miss)      [ "$(awk -v m="$miss" 'BEGIN{print (m>=1.5)?1:0}')" = "0" ] \
                       && echo "PASS plant $1: clause 2 stops firing (${miss}x)" \
                       || { echo "FAIL plant $1: clause 2 still fires at ${miss}x"; fail=1; } ;;
        superlinear) [ "$(awk -v d="$drift" 'BEGIN{print (d>=20)?1:0}')" = "0" ] \
                       && echo "PASS plant $1: clause 1 stops firing (${drift}%)" \
                       || { echo "FAIL plant $1: clause 1 still fires at ${drift}%"; fail=1; } ;;
    esac
}
# p1: halve the observer's cost at every N -> the C6 comparison closes.
mutant_check p1 's/^([0-9]+) ([0-9.]+) ([0-9.]+)$/\1 \2 \3/; s/^1 0.399/1 0.348/; s/^2 0.750/2 0.637/; s/^4 1.456/4 1.239/; s/^8 2.829/8 2.406/; s/^16 6.090/16 5.092/; s/^32 13.011/32 10.876/' c6miss
# p2: flatten the top of the observer curve -> superlinearity vanishes.
mutant_check p2 's/^32 13.011/32 12.155/' superlinear
# The p3 plant is GONE with the argument it validated. It exercised
# P1.impossible and P1.unresolved, both retracted at round 23 -- a plant
# for a withdrawn claim proves nothing and reads as coverage. P1's
# replacement gate is a MEASUREMENT in tests/test_swarm_profile.sh, with
# its own planted fault (a ratio of 1.00, which the 1.10 bound rejects --
# a collapsed ratio is what per-binding arming would look like).

[ "$fail" -eq 0 ] || { echo "VERDICT GATE FAILED"; exit 1; }
echo "PASS: P2's refutation clauses fire with plants; P1's verdict text is pinned and its measurement lives in test_swarm_profile.sh"
