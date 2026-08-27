#!/usr/bin/env bash
# P2's verdict, gated.
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

[ "$fail" -eq 0 ] || { echo "P2 FIT GATE FAILED"; exit 1; }
echo "PASS: P2's verdict arithmetic reproduces and both refutation clauses fire, with plants"
