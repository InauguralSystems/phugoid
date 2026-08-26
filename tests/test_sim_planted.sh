#!/usr/bin/env bash
# The rung-1 planted-fault matrix (ORACLE.md): each q-plant must flip
# EXACTLY its declared red set while everything else stays green, every
# plant run must execute the full pinned 79-check population, and the
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
    grep -q '^CHECKS_RUN 79$' "$OUT" || { echo "FAIL: plant $plant run population != 79"; exit 1; }
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

echo "--- Q4: trim alpha offset +0.01 rad -> S1 + parity + SP set + gain rows (21) ---"
run_plant q4
expect_total_fails 21
expect_red 'S4\.amp\.gain\.sp ' 'S4\.amp\.gain\.ph '
expect_red 'S1\.res\.' 'S1\.hold\.' 'S0\.a12 ' 'S0\.a13 ' 'S0\.a21 ' 'S0\.a22 ' 'S0\.a24 ' 'S0\.a31 ' 'S2\.T ' 'S2\.zenv ' 'S2\.zlog\.nr ' 'S2\.zenv\.nf '
expect_green 'S3\.' 'M1X\.'
echo "PASS: Q4 red pattern exact"

echo "--- Q5: thrust dropped -> S1 + every sim-graded mode + gain rows (21) ---"
run_plant q5
expect_total_fails 21
expect_red 'S4\.amp\.gain\.sp ' 'S4\.amp\.gain\.ph ' 'S4\.ctl\.gain '
expect_red 'S1\.res\.' 'S1\.hold\.' 'S2\.' 'S3\.' 'S2\.zlog\.nr ' 'S2\.zenv\.nf ' 'S4\.amp\.spT '
expect_green 'S0\.' 'M1X\.'
echo "PASS: Q5 red pattern exact"

echo "--- Q6: grading timeline dilated x1.02 -> exactly the sim period checks (3) ---"
run_plant q6
expect_total_fails 3
expect_red 'S2\.T ' 'S3\.Tpeaks ' 'S3\.Tdft '
expect_green 'S0\.' 'S1\.' 'S2\.z' 'S3\.z' 'S4\.' 'M1X\.'
echo "PASS: Q6 red pattern exact"

echo "--- Q7: M1X generator time-dilated x1.05 -> the 5 bridge period checks + the 4 gen.s1 identities (9) ---"
run_plant q7
expect_total_fails 9
expect_red 'M1X\.sp\.phi20\.T ' 'M1X\.sp\.phi45\.T ' 'M1X\.sp2\.T ' 'M1X\.ph2\.Tpeaks ' 'M1X\.ph2\.Tdft ' 'M1X\.sp\.phi20\.gen\.s1 ' 'M1X\.sp\.phi45\.gen\.s1 ' 'M1X\.sp2\.gen\.s1 ' 'M1X\.ph2\.gen\.s1 '
expect_green 'S[0-4]\.' 'M1X\..*z' '\.gen\.s0 ' '\.gen\.len '
echo "PASS: Q7 red pattern exact"

echo "--- Q8: graded zeta replaced by 0.05 (identity fields carried) -> exactly the 10 zeta checks through the NUMERIC arm ---"
run_plant q8
expect_total_fails 10
expect_red 'S2\.zlog ' 'S2\.zenv ' 'S3\.z ' 'M1X\.sp\.phi20\.zlog ' 'M1X\.sp\.phi20\.zenv ' 'M1X\.sp\.phi45\.zlog ' 'M1X\.sp\.phi45\.zenv ' 'M1X\.sp2\.zlog ' 'M1X\.sp2\.zenv ' 'M1X\.ph2\.z '
# Round 7: these must red through the numeric comparator, NOT the accessor
# refusal — a field-less fabrication red through the refusal arm and left
# 12 checks' truth wiring unexecuted by any plant.
grep '^FAIL ' "$OUT" | grep -q 'refused' && { echo "FAIL: Q8 reds must use the numeric arm, found a refusal"; exit 1; }
expect_green 'S0\.' 'S1\.' 'S2\.T ' 'S3\.T' 'S4\.' '\.nr ' '\.nf '
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
# Round 8: q10's reds must ALL be numeric — the round-7 no-refusals rule
# was applied only to the Q8 block, and dropping q10's carried identity
# fields silently moved 6 reds onto the accessor refusal arm, leaving
# S4.amp.spze / S4.ctl.spzl / S4.ctl.spze with no numeric plant at all.
grep '^FAIL ' "$OUT" | grep -q 'refused' && { echo "FAIL: Q10 reds must use the numeric arm, found a refusal"; exit 1; }
expect_green 'S[0-3]\.' 'M1X\.'
echo "PASS: Q10 red pattern exact"

echo "--- Q11: period_dft result corrupted (T x1.01, k+1) -> exactly the 4 Td checks ---"
run_plant q11
expect_total_fails 4
expect_red 'S3\.Tdft ' 'S3\.Tdft\.k ' 'M1X\.ph2\.Tdft ' 'M1X\.ph2\.Tdft\.k '
expect_green 'S3\.Tpeaks ' 'S4\.' 'S[0-2]\.' 'M1X\.sp'
echo "PASS: Q11 red pattern exact (rounds 1-2: the anti-alias defense is the k-pins, which red the CLEAN run under any period_peaks alias; q11 proves the four Td checks can fail)"

echo "--- Q12: the Td slot fed by period_peaks (the rounds-1/2 alias, installed as a plant) -> the k-pins + accessor-refused Td rows (7) ---"
run_plant q12
expect_total_fails 7
expect_red 'S3\.Tdft ' 'S3\.Tdft\.k ' 'S4\.dt\.phTd ' 'S4\.amp\.phTd ' 'S4\.ctl\.phTd ' 'M1X\.ph2\.Tdft ' 'M1X\.ph2\.Tdft\.k '
expect_green 'S3\.Tpeaks ' 'S4\..*phTp ' 'S[0-2]\.' 'M1X\.sp'
echo "PASS: Q12 red pattern exact (drives a null through check_exact's rejection arm every run — round-3 review widened that arm to tolerate null and nothing executed it)"

echo "--- Q13: the Tp slot fed by period_dft (round-5's MIRROR alias, installed as a plant) -> the n-pins + accessor-refused Tp rows (7) ---"
run_plant q13
expect_total_fails 7
expect_red 'S3\.Tpeaks ' 'S3\.Tpeaks\.n ' 'S4\.dt\.phTp ' 'S4\.amp\.phTp ' 'S4\.ctl\.phTp ' 'M1X\.ph2\.Tpeaks ' 'M1X\.ph2\.Tpeaks\.n '
expect_green 'S3\.Tdft ' 'S4\..*phTd ' 'S[0-2]\.' 'M1X\.sp'
echo "PASS: Q13 red pattern exact (rounds 1-4 hardened only the Td slot; the n_extrema pins are the Tp dual, differing 10 vs 8 per the round-4 one-literal lesson)"

echo "--- Q14: zeta-slot alias (envelope in the log-decrement slot) -> the zl accessor + pin set (6) ---"
run_plant q14
expect_total_fails 6
expect_red 'S3\.z ' 'S3\.z\.nr ' 'S4\.dt\.phz ' 'S4\.amp\.phz ' 'S4\.ctl\.phz ' 'M1X\.ph2\.z '
expect_green 'S2\.' 'S3\.T' 'S4\..*phT' 'M1X\.sp'
echo "PASS: Q14 red pattern exact (round-6: consumer read sites go through identity accessors; q14 exercises as_zl's refusal arm every run)"

echo "--- Q15: SP-side zeta slots SWAPPED (q14's dual) -> the sp zeta accessor + pin set (16) ---"
run_plant q15
expect_total_fails 16
expect_red 'S2\.zlog ' 'S2\.zenv ' 'S2\.zlog\.nr ' 'S2\.zenv\.nf ' 'S4\.dt\.spzl ' 'S4\.dt\.spze ' 'S4\.amp\.spzl ' 'S4\.amp\.spze ' 'S4\.ctl\.spzl ' 'S4\.ctl\.spze ' 'M1X\.sp\.phi20\.zlog ' 'M1X\.sp\.phi20\.zenv ' 'M1X\.sp\.phi45\.zlog ' 'M1X\.sp\.phi45\.zenv ' 'M1X\.sp2\.zlog ' 'M1X\.sp2\.zenv '
expect_green 'S3\.' 'S4\..*ph' 'S4\..*spT ' 'M1X\.ph2'
echo "PASS: Q15 red pattern exact (the only plant driving as_ze's refusal arm with a real wrong-estimator result; round-7's dual to q14)"

echo "--- Q16: every check_below/check_relabs value displaced 1.1x its own executed tolerance -> the 5 S1 + 11 plantable S0 checks (16) ---"
run_plant q16
expect_total_fails 16
expect_red 'S1\.res\.' 'S1\.hold\.' 'S0\.a11 ' 'S0\.a12 ' 'S0\.a13 ' 'S0\.a14 ' 'S0\.a21 ' 'S0\.a22 ' 'S0\.a23 ' 'S0\.a24 ' 'S0\.a31 ' 'S0\.a32 ' 'S0\.a33 '
expect_green 'S0\.a34 ' 'S0\.a4' 'S[2-4]\.' 'M1X\.'
echo "PASS: Q16 red pattern exact (found at rung-2 round 1: the executed comparator tolerance was unpinned — rung-0's P15/P17 class, now inherited by both rungs)"

echo "--- Q17: every check_rel value displaced 1.1x its own executed rel arm, direction of the honest discrepancy -> all 39 tolerance rows ---"
run_plant q17
expect_total_fails 39
expect_red 'S2\.T ' 'S2\.zlog ' 'S3\.Tpeaks ' 'S3\.z ' 'S4\.dt\.' 'S4\.amp\.' 'S4\.ctl\.' 'M1X\.sp\.' 'M1X\.sp2\.' 'M1X\.ph2\.Tpeaks ' 'M1X\.ph2\.z '
grep '^FAIL ' "$OUT" | grep -q 'refused' && { echo "FAIL: Q17 reds must use the numeric arm, found a refusal"; exit 1; }
expect_green 'S0\.' 'S1\.' '\.k ' '\.n ' '\.nr ' '\.nf '
echo "PASS: Q17 red pattern exact (rung-2 round 2's find, applied to both rungs)"

echo "--- Q20: the dt-rerun gradings alone corrupted -> exactly the 6 S4.dt rows ---"
run_plant q20
expect_total_fails 6
expect_red 'S4\.dt\.spT ' 'S4\.dt\.spzl ' 'S4\.dt\.spze ' 'S4\.dt\.phTp ' 'S4\.dt\.phTd ' 'S4\.dt\.phz '
expect_green 'S4\.amp\.' 'S4\.ctl\.' 'S[0-3]\.' 'M1X\.'
echo "PASS: Q20 red pattern exact (rung-2 round 7's cross-rerun swap class, rung-1 twin)"

echo "--- Q21: the amp-rerun gradings alone corrupted -> exactly the 6 S4.amp rows ---"
run_plant q21
expect_total_fails 6
expect_red 'S4\.amp\.spT ' 'S4\.amp\.spzl ' 'S4\.amp\.spze ' 'S4\.amp\.phTp ' 'S4\.amp\.phTd ' 'S4\.amp\.phz '
expect_green 'S4\.dt\.' 'S4\.ctl\.' 'S[0-3]\.' 'M1X\.'
echo "PASS: Q21 red pattern exact (separates amp from the agreeing ctl/base gradings)"

echo "--- Q22: the ctl rerun built from UNSCALED derivatives -> exactly the gain row ---"
run_plant q22
expect_total_fails 1
expect_red 'S4\.ctl\.gain '
expect_green 'S4\.ctl\.sp' 'S4\.ctl\.ph' 'S[0-3]\.' 'M1X\.'
echo "PASS: Q22 red pattern exact (round 8: nothing pinned that the x1.5 reaches the dynamics — the rung-1 twin of the rung-2 round-5 vacuity)"

echo "--- Q23: the amp rerun's arguments forced to base -> exactly the 2 amp gain rows ---"
run_plant q23
expect_total_fails 2
expect_red 'S4\.amp\.gain\.sp ' 'S4\.amp\.gain\.ph '
expect_green 'S4\.amp\.sp' 'S4\.amp\.ph' 'S[0-3]\.' 'M1X\.'
echo "PASS: Q23 red pattern exact (the run-USE class: ROW tokens pin the print, gain rows pin the use)"

echo "--- Q18: the generator BODY corrupted (a1 nudged 1.1e-9, contaminant dropped, one sample short) -> exactly the 12 wiring identities ---"
run_plant q18
expect_total_fails 12
expect_red 'M1X\.sp\.phi20\.gen\.' 'M1X\.sp\.phi45\.gen\.' 'M1X\.sp2\.gen\.' 'M1X\.ph2\.gen\.'
expect_green 'S[0-4]\.' 'M1X\.sp\.phi20\.T ' 'M1X\.ph2\.z ' 'M1X\.sp2\.zlog '
echo "PASS: Q18 red pattern exact (rung-2 round 4's find applied to both rungs: the ROW token pins the print, the gen identities pin the use)"

# ------------------------------------------------------------------
# Manifest enforcement (same rules as test_planted.sh): identity over
# name + tolerance token; plantable coverage; structural exclusion.
echo "--- manifest: identity + full red-set coverage + class vocabulary ---"
. "$(dirname "$0")/manifestlib.sh"
"$EIGS" tests/sim_check.eigs > "$WORK/clean_sim" 2>&1 || { echo "FAIL: unplanted sim_check nonzero"; exit 1; }
grep -E '^(PASS|FAIL) ' "$WORK/clean_sim" | awk '{print $2, $3}' | sort > "$WORK/names_sim"
grep '^ROW ' "$WORK/clean_sim" | awk '{print $2, $3}' | sort > "$WORK/rows_sim"
sort -u "$WORK/red_union" > "$WORK/redu_sim"

# Round 25/26: these five arms shipped with NO executed plants. They now
# share one implementation with the other three suites, and mf_validate
# plants each of them against the REAL function every run.
mf_validate tests/sim_manifest.txt sim "$WORK/names_sim" "$WORK/rows_sim" "$WORK/redu_sim" "$WORK" sim rowparams plantable structural || exit 1
echo "PASS: all five manifest-enforcement arms rejected an in-class planted fault"

mf_identity   tests/sim_manifest.txt sim "$WORK/names_sim" "$WORK" || { echo "FAIL: sim check-name set drifted from manifest"; diff "$WORK/_mfi" "$WORK/names_sim" || true; exit 1; }
mf_rowparams  tests/sim_manifest.txt "$WORK/rows_sim" "$WORK"      || { echo "FAIL: bridge-row parameter set drifted from manifest"; diff "$WORK/_mfr" "$WORK/rows_sim" || true; exit 1; }
mf_coverage   tests/sim_manifest.txt sim "$WORK/redu_sim"          || { echo "FAIL: a plantable check never went red under any plant"; exit 1; }
mf_structural tests/sim_manifest.txt sim "$WORK/redu_sim"          || { echo "FAIL: a structural check went red — exemption list is stale"; exit 1; }
mf_class      tests/sim_manifest.txt sim rowparams plantable structural          || { echo "FAIL: unknown manifest class token"; exit 1; }
echo "PASS: manifest identity holds; all plantable checks proven able to fail"

echo "PASS: all 22 rung-1 plants flip exactly their declared checks"
