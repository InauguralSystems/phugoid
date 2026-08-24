#!/usr/bin/env bash
# The rung-1 planted-fault matrix (ORACLE.md): each q-plant must flip
# EXACTLY its declared red set while everything else stays green, every
# plant run must execute the full pinned 64-check population, and the
# manifest rules hold (identity incl. tolerance tokens; every plantable
# name in some red set; structural names in none). Counts measured
# 2026-08-24; a drift in any of them is a real change in the checkers'
# discriminating power and must be re-justified, not silently re-pinned.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
WORK="$(mktemp -d)"
trap 'rm -f "$OUT"; rm -rf "$WORK"' EXIT

run_plant() {
    local plant="$1"
    if "$EIGS" tests/sim_check.eigs "$plant" > "$OUT" 2>&1; then
        echo "FAIL: plant $plant did not make sim_check exit nonzero — the checker cannot fail"
        exit 1
    fi
    grep '^FAIL ' "$OUT" | awk '{print $2}' >> "$WORK/red_union" || true
    grep -q '^CHECKS_RUN 64$' "$OUT" || { echo "FAIL: plant $plant run population != 64"; exit 1; }
}

expect_total_fails() {
    local want="$1" got
    got=$(grep -c '^FAIL ' "$OUT" || true)
    [ "$got" -eq "$want" ] || { echo "FAIL: expected exactly $want FAIL lines, got $got"; grep '^FAIL ' "$OUT"; exit 1; }
}

expect_red() {
    local pat
    for pat in "$@"; do
        grep -Eq "^FAIL $pat" "$OUT" || { echo "FAIL: expected red family '$pat' did not flip"; grep '^FAIL ' "$OUT" || true; exit 1; }
    done
}

expect_green() {
    local pat
    for pat in "$@"; do
        if grep '^FAIL ' "$OUT" | grep -Eq "$pat"; then
            echo "FAIL: family '$pat' flipped but should stay green"; grep '^FAIL ' "$OUT"; exit 1
        fi
    done
}

echo "--- Q1: Cma x1.05 in the sim's dataset copy -> a32 + SP period + phugoid set (5) ---"
run_plant q1
expect_total_fails 5
expect_red 'S0\.a32 ' 'S2\.T ' 'S3\.Tpeaks ' 'S3\.Tdft ' 'S3\.z '
expect_green 'S1\.' 'S4\.' 'M1X\.' 'S2\.z'
echo "PASS: Q1 red pattern exact"

echo "--- Q2: alpha-dot terms zeroed in the sim copy -> folded rows + SP set (10) ---"
run_plant q2
expect_total_fails 10
expect_red 'S0\.a21 ' 'S0\.a22 ' 'S0\.a23 ' 'S0\.a31 ' 'S0\.a32 ' 'S0\.a33 ' 'S2\.T ' 'S2\.zlog ' 'S2\.zenv ' 'S3\.z '
expect_green 'S1\.' 'S3\.T' 'S4\.' 'M1X\.'
echo "PASS: Q2 red pattern exact"

echo "--- Q3: integrator RK4 -> Euler -> phugoid damping + dt-invariance set (6) ---"
run_plant q3
expect_total_fails 6
expect_red 'S2\.T ' 'S3\.z ' 'S4\.dt\.spT ' 'S4\.dt\.spzl ' 'S4\.dt\.spze ' 'S4\.dt\.phz '
expect_green 'S0\.' 'S1\.' 'S4\.amp\.' 'S4\.ctl\.' 'M1X\.'
echo "PASS: Q3 red pattern exact"

echo "--- Q4: trim alpha offset +0.01 rad -> S1 + parity + SP set (19) ---"
run_plant q4
expect_total_fails 19
expect_red 'S1\.res\.' 'S1\.hold\.' 'S0\.a12 ' 'S0\.a13 ' 'S0\.a21 ' 'S0\.a22 ' 'S0\.a24 ' 'S0\.a31 ' 'S2\.T ' 'S2\.zenv ' 'S2\.zlog\.nr ' 'S2\.zenv\.nf '
expect_green 'S3\.' 'M1X\.'
echo "PASS: Q4 red pattern exact"

echo "--- Q5: thrust dropped -> S1 + every sim-graded mode (18) ---"
run_plant q5
expect_total_fails 18
expect_red 'S1\.res\.' 'S1\.hold\.' 'S2\.' 'S3\.' 'S2\.zlog\.nr ' 'S2\.zenv\.nf ' 'S4\.amp\.spT '
expect_green 'S0\.' 'M1X\.'
echo "PASS: Q5 red pattern exact"

echo "--- Q6: grading timeline dilated x1.02 -> exactly the sim period checks (3) ---"
run_plant q6
expect_total_fails 3
expect_red 'S2\.T ' 'S3\.Tpeaks ' 'S3\.Tdft '
expect_green 'S0\.' 'S1\.' 'S2\.z' 'S3\.z' 'S4\.' 'M1X\.'
echo "PASS: Q6 red pattern exact"

echo "--- Q7: M1X generator time-dilated x1.05 -> exactly the 5 bridge period checks ---"
run_plant q7
expect_total_fails 5
expect_red 'M1X\.sp\.phi20\.T ' 'M1X\.sp\.phi45\.T ' 'M1X\.sp2\.T ' 'M1X\.ph2\.Tpeaks ' 'M1X\.ph2\.Tdft '
expect_green 'S[0-4]\.' 'M1X\..*z'
echo "PASS: Q7 red pattern exact"

echo "--- Q8: graded zeta replaced by 0.05 -> the 10 zeta checks + the 3 zeta identity pins (whole-dict replacement drops n_ratios/n_fit) ---"
run_plant q8
expect_total_fails 13
expect_red 'S2\.zlog ' 'S2\.zenv ' 'S2\.zlog\.nr ' 'S2\.zenv\.nf ' 'S3\.z ' 'S3\.z\.nr ' 'M1X\.sp\.phi20\.zlog ' 'M1X\.sp\.phi20\.zenv ' 'M1X\.sp\.phi45\.zlog ' 'M1X\.sp\.phi45\.zenv ' 'M1X\.sp2\.zlog ' 'M1X\.sp2\.zenv ' 'M1X\.ph2\.z '
expect_green 'S0\.' 'S1\.' 'S2\.T' 'S3\.T' 'S4\.'
echo "PASS: Q8 red pattern exact"

echo "--- Q9: sim dataset broadly poisoned -> parity + every sim-graded mode (16) ---"
run_plant q9
expect_total_fails 16
expect_red 'S0\.a11 ' 'S0\.a12 ' 'S0\.a13 ' 'S0\.a14 ' 'S0\.a22 ' 'S0\.a23 ' 'S0\.a24 ' 'S0\.a31 ' 'S0\.a32 ' 'S0\.a33 ' 'S2\.' 'S3\.'
expect_green 'S1\.' 'S4\.' 'M1X\.'
echo "PASS: Q9 red pattern exact"

echo "--- Q10: re-run gradings corrupted (dt x1.02, zeta x1.03) -> all 18 S4 comparators ---"
run_plant q10
expect_total_fails 18
expect_red 'S4\.dt\.' 'S4\.amp\.' 'S4\.ctl\.'
[ "$(grep -c '^FAIL S4\.' "$OUT")" -eq 18 ] || { echo "FAIL: Q10 S4 count != 18"; exit 1; }
expect_green 'S[0-3]\.' 'M1X\.'
echo "PASS: Q10 red pattern exact"

echo "--- Q11: period_dft result corrupted (T x1.01, k+1) -> exactly the 4 Td checks ---"
run_plant q11
expect_total_fails 4
expect_red 'S3\.Tdft ' 'S3\.Tdft\.k ' 'M1X\.ph2\.Tdft ' 'M1X\.ph2\.Tdft\.k '
expect_green 'S3\.Tpeaks ' 'S4\.' 'S[0-2]\.' 'M1X\.sp'
echo "PASS: Q11 red pattern exact (rounds 1-2: the anti-alias defense is the k-pins, which red the CLEAN run under any period_peaks alias; q11 proves the four Td checks can fail)"

echo "--- Q12: the Td slot fed by period_peaks (the rounds-1/2 alias, installed as a plant) -> exactly the 2 k-pins ---"
run_plant q12
expect_total_fails 2
expect_red 'S3\.Tdft\.k ' 'M1X\.ph2\.Tdft\.k '
expect_green 'S3\.Tdft ' 'S3\.Tpeaks ' 'S4\.' 'S[0-2]\.' 'M1X\.sp'
echo "PASS: Q12 red pattern exact (drives a null through check_exact's rejection arm every run — round-3 review widened that arm to tolerate null and nothing executed it)"

echo "--- Q13: the Tp slot fed by period_dft (round-5's MIRROR alias, installed as a plant) -> exactly the 2 n-pins ---"
run_plant q13
expect_total_fails 2
expect_red 'S3\.Tpeaks\.n ' 'M1X\.ph2\.Tpeaks\.n '
expect_green 'S3\.Tpeaks ' 'S3\.Tdft ' 'S4\.' 'S[0-2]\.' 'M1X\.sp'
echo "PASS: Q13 red pattern exact (rounds 1-4 hardened only the Td slot; the n_extrema pins are the Tp dual, differing 10 vs 8 per the round-4 one-literal lesson)"

# ------------------------------------------------------------------
# Manifest enforcement (same rules as test_planted.sh): identity over
# name + tolerance token; plantable coverage; structural exclusion.
echo "--- manifest: identity + full red-set coverage ---"
"$EIGS" tests/sim_check.eigs > "$WORK/clean_sim" 2>&1 || { echo "FAIL: unplanted sim_check nonzero"; exit 1; }
grep -E '^(PASS|FAIL) ' "$WORK/clean_sim" | awk '{print $2, $3}' | sort > "$WORK/names_sim"
grep '^sim ' tests/sim_manifest.txt | awk '{print $2, $4}' | sort > "$WORK/man_sim"
diff -u "$WORK/man_sim" "$WORK/names_sim" > /dev/null || { echo "FAIL: sim check-name set drifted from manifest"; diff "$WORK/man_sim" "$WORK/names_sim" || true; exit 1; }
sort -u "$WORK/red_union" > "$WORK/redu_sim"
BAD=0
while read -r kind name klass tolspec; do
    [ "$kind" = sim ] || continue
    if [ "$klass" = plantable ] && ! grep -qx "$name" "$WORK/redu_sim"; then
        echo "FAIL: plantable check '$name' never went red under any plant"; BAD=1
    fi
    if [ "$klass" = structural ] && grep -qx "$name" "$WORK/redu_sim"; then
        echo "FAIL: structural check '$name' went red — exemption list is stale"; BAD=1
    fi
done < <(grep -v '^#' tests/sim_manifest.txt)
[ "$BAD" -eq 0 ] || exit 1
echo "PASS: manifest identity holds; all plantable checks proven able to fail"

echo "PASS: all 13 rung-1 plants flip exactly their declared checks"
