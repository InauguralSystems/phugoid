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
# µs per observed scalar write, DERIVED FROM THE SOURCE.
#
# Round 37 replaced a bare literal with a derivation "so the derivation is
# pinned rather than the number" -- and round 38 found the derivation was
# reverse-engineered to reproduce the number. It used C6_WRITES=480000,
# which is not a write count at all: it is `i * READ_SITES` = 120000 x 4,
# printed by `run_read`, a DIFFERENT variant, and published in ORACLE only
# as "read 133286 480000". The gate then asserted the result equalled
# 0.154, so it certified the conclusion and nothing else -- this rung's
# own round-33 rule ("a counter whose expected value the gate can DERIVE
# is a target, not a witness") applied to the newest gate, one level down.
#
# What 0.243 - 0.169 actually buys is the observer walk on the assignments
# `run_floor`'s `unobserved:` removes. `run_write` and `run_floor` in
# tests/ap_profile.eigs are byte-identical loops differing only in the
# wrapper, and the body is FIVE assignments -- u, w, q, th, and `i is
# i + 1` -- over N. The five `local ... is ...` declarations sit outside
# the block in both arms and cancel. So the count is 5N, and it is read
# from the source rather than typed here.
C6_HI=0.243          # s, C6's observed arm  (ORACLE: "write 0.243 s")
C6_LO=0.169          # s, C6's unobserved arm (ORACLE: "floor 0.169 s")
C6_N=$(grep -oP '^N is \K[0-9]+' tests/ap_profile.eigs | head -1)
# assignments inside run_write's loop body, counted from the file
C6_ASSIGN=$(awk '/^define run_write/,/^    print of/' tests/ap_profile.eigs \
            | sed -n '/loop while/,/^    print of/p' | grep -cE '^[[:space:]]+[a-z_]+ is ')
[ -n "$C6_N" ] && [ "$C6_ASSIGN" -gt 0 ] || { echo "FAIL: cannot read N or the assignment count from tests/ap_profile.eigs"; exit 1; }
[ "$C6_ASSIGN" = "5" ] || { echo "FAIL: run_write's loop body has $C6_ASSIGN observed assignments, not the 5 C6's per-write cost is divided by — recount before trusting P2's slope comparison"; exit 1; }
C6_WRITES=$(( C6_N * C6_ASSIGN ))
C6_PER_WRITE=$(awk -v a="$C6_HI" -v b="$C6_LO" -v w="$C6_WRITES" 'BEGIN{ printf "%.3f", (a-b)*1e6/w }')
echo "C6: (${C6_HI}s - ${C6_LO}s) / (${C6_N} x ${C6_ASSIGN} assignments) = ${C6_PER_WRITE} us per observed write"
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

# ...and ORACLE must PUBLISH what this computes. Round 39: round 38 pinned
# the C6 DERIVATION and left its published answer pinned by nothing, so
# reverting ORACLE to the exact values round 38 had just refuted
# (0.154 / 23.1 / 1.95x) passed with the gate printing 0.123 / 18.4 /
# 2.45x beside it. Nothing compared the two. That is the `P2.banked`
# shape -- "it guards the published number now" -- one paragraph over,
# never applied.
#
# The INPUTS were free in the same way: C6_HI and C6_LO are hand
# transcriptions of ORACLE's rung-3 line, and a 16% edit to one of them
# passed while ORACLE published the old chain. They are checked against
# that line now.
for pubv in "$C6_PER_WRITE µs" "$C6_US µs" "${MISS}× miss"; do
    grep -qF -- "$pubv" ORACLE.md \
        || chk 0 "P2.c6published: ORACLE does not publish '$pubv' — the gate computes the C6 chain and the write-up states a different one"
done
chk "$(grep -cF -- "$C6_PER_WRITE µs" ORACLE.md | awk '{print ($1>=1)?1:0}')" \
    "P2.c6published: ORACLE publishes the C6 chain this gate computes (${C6_PER_WRITE} µs → ${C6_US} µs → ${MISS}×)"
grep -qF -- "write $C6_HI s, floor $C6_LO s" ORACLE.md \
    && chk 1 "P2.c6inputs: C6_HI/C6_LO match ORACLE's rung-3 measurement line" \
    || chk 0 "P2.c6inputs: C6_HI=$C6_HI / C6_LO=$C6_LO are not ORACLE's rung-3 figures — the constant under P2's verdict is a free-floating transcription"

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
# EVERY prediction's VERDICT WORD, at EVERY site that states one, matched
# on the WORD and not on the punctuation around it.
#
# Round 26 added these after finding three of four verdicts flippable.
# Round 27 found the replacement wrong in both directions: a
# verdict-PRESERVING reword ("**P3 — CONFIRMED. The mechanism splits in
# two.") RED it, so it locked formatting rather than verdicts; and a
# verdict-INVERTING edit PASSED, because ORACLE states P1's verdict at two
# sites and only one was pinned (2012 and 2064), and P3's N-half carries a
# third at 2413. That is R25's own lesson -- a gate that enforces the one
# clause which must not change -- reintroduced by the fix for it.
#
# So: enumerate the sites, count them, and require each to still assert
# its verdict word. Counting is what catches a site being deleted or a new
# one appearing unpinned.
verdict_sites() { # verdict_sites <regex-for-the-claim-lead>
    grep -cE "$1" ORACLE.md
}
verdict_word_ok() { # verdict_word_ok <label> <lead-regex> <expected-word> <expected-count>
    local lbl="$1" lead="$2" word="$3" want="$4" n bad
    n=$(verdict_sites "$lead")
    if [ "$n" -ne "$want" ]; then
        chk 0 "$lbl.word: found $n verdict site(s) for $lbl, expected $want (a site was added, removed or reworded past the matcher)"
        return
    fi
    # The word must sit ADJACENT to the lead, not merely somewhere on the
    # line. Round 28: `grep -cv "$word"` matched the word anywhere, so
    # "**P3 — REFUTED, and the mechanism (previously CONFIRMED) splits in
    # two." passed. That is not contrived -- P1 and P4 both already carry
    # "condition REFUTED / claim CONFIRMED" leads, so the shape is house
    # style here.
    # The word must sit ADJACENT to the lead, not merely somewhere on the
    # line. Round 28: `grep -cv "$word"` matched the word anywhere, so
    # "**P3 — REFUTED, and the mechanism (previously CONFIRMED) splits in
    # two." passed. Not contrived -- P1 and P4 both carry "condition
    # REFUTED / claim CONFIRMED" leads, so that shape is house style here.
    #
    # Some leads already END with the word (P4's, P4cond's); for those the
    # lead IS the lead-plus-word, so the two counts coincide.
    # Append the word to EVERY branch of the alternation, not to the whole
    # string. Round 28 caught the mutant a second time here: with
    # lead="^A|^B", `${lead}${word}` is "^A|^B$word", so the FIRST branch
    # still matches any line -- and the P3 mutant passed again. Leads that
    # already end with the word are left alone.
    # `set -f` because `$lead` is unquoted for the IFS split and would
    # otherwise also undergo pathname expansion (round 29 -- inert today
    # only because no file in ROOT matches a verdict lead).
    local leadword="" br
    local IFS='|'
    set -f
    for br in $lead; do
        case "$br" in *"$word") : ;; *) br="${br}${word}" ;; esac
        leadword="${leadword:+$leadword|}$br"
    done
    set +f
    unset IFS
    local m; m=$(grep -cE "$leadword" ORACLE.md)
    [ "$m" -eq "$n" ] \
        && chk 1 "$lbl.word: all $n verdict site(s) say $word adjacent to the lead" \
        || chk 0 "$lbl.word: only $m of $n verdict site(s) for $lbl say $word at the lead (exit gate item 7)"
}
verdict_word_ok P1 "^\\*\\*P1('s practical claim)? is " CONFIRMED 2
verdict_word_ok P2 "^\\*\\*P2 — "                        REFUTED   1
verdict_word_ok P3 "^\\*\\*P3 — |^\\*\\*The N half — " CONFIRMED 2
# P4 has two lead lines: the item-8 paragraph (VACUOUS condition) and the
# verdict itself (CONFIRMED). Both must keep their word.
verdict_word_ok P4 "^\\*\\*P4 — CONFIRMED" CONFIRMED 1
verdict_word_ok P4cond "^\\*\\*P4 — its registered condition is " VACUOUS 1



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
# Round 26: the banked P1_SHARES triple is GONE. Round 25 replaced the
# loop that consumed it with the range pin below and left the data in
# place under a twelve-line comment still presenting it as banked -- dead
# data that reads as coverage, which is the pattern ORACLE records at its
# own line 1469. What P1's read half supports is a RANGE, so that is what
# is pinned.
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
        # NO SILENT DEFAULT. Round 36: any clause string other than the two
        # above executed NO assertion, set nothing, returned 0, and the file
        # still printed "all plants fire". Third instance of this shape in
        # this rung's lookups, after `want_hits` (round 34) and p3claims'
        # truth `case` (round 35) -- a plant that proves nothing is worse
        # than no plant, because it reads as coverage.
        *) echo "FAIL: plant $1 names an unknown clause '$3' — it asserted nothing"; fail=1 ;;
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
# its own planted fault -- the ceiling0pb per-binding counterfactual,
# MEASURED against a 1.20 bound, with its digest checked equal to
# ceiling0's so the collapse is evidence about observation shape and not
# about a drifted workload.

[ "$fail" -eq 0 ] || { echo "VERDICT GATE FAILED"; exit 1; }
echo "PASS: P2's refutation clauses fire with plants; P1's verdict text is pinned and its measurement lives in test_swarm_profile.sh"
