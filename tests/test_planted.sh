#!/usr/bin/env bash
# The planted-fault matrix (ORACLE.md): each plant must flip EXACTLY the
# declared check subset to FAIL while everything else stays green. A checker
# that has never failed has not been shown to work; a plant that flips
# nothing fails this harness itself.
#
# Round-3 review demonstrated that asserting only a SUBSET of each plant's
# red pattern lets whole check families be made vacuous undetected (26 of
# the pinned checks could be hardcoded to pass and this script still said
# OK). So every plant now asserts its FULL measured red set: the exact
# total fail count AND one representative per family, plus the green-side
# exclusions. The counts below were measured on 2026-08-23; a drift in any
# of them is a real change in the checkers' discriminating power and must
# be re-justified, not silently re-pinned.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
WORK="$(mktemp -d)"
trap 'rm -f "$OUT"; rm -rf "$WORK"' EXIT

run_plant() {
    local prog="$1" plant="$2"
    if "$EIGS" "tests/$prog" "$plant" > "$OUT" 2>&1; then
        echo "FAIL: plant $plant did not make $prog exit nonzero — the checker cannot fail"
        exit 1
    fi
    # accumulate the red-set union for the manifest coverage assertion
    grep '^FAIL ' "$OUT" | awk '{print $2}' >> "$WORK/red_${prog%%.eigs}" || true
}

# Every plant run must still execute the full pinned check population —
# a plant that silently skips checks would fake its red pattern.
expect_population() {
    grep -q "^CHECKS_RUN $1\$" "$OUT" || { echo "FAIL: plant run population != $1"; exit 1; }
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

echo "--- P1: Cma sign flip -> full longitudinal chain red (15), rest green ---"
run_plant modes_check.eigs p1
expect_population 180
expect_total_fails 15
expect_red 'L1\.lon\.Mw ' 'L2\.lon\.' 'L3\.lon\.' 'L4\.chain\.lon\.ph' 'L4\.chain\.lon\.sp' 'L5\.ph\.' 'L5\.sp\.'
expect_green '\.lat\.' 'L4\.(solver|exact)\.' 'L5\.unit\.'
echo "PASS: P1 red pattern exact"

echo "--- P2: lateral quartic c1 +1% -> only solver-alone lateral red (3) ---"
run_plant modes_check.eigs p2
expect_population 180
expect_total_fails 3
expect_red 'L4\.solver\.lat\.dr' 'L4\.solver\.lat\.roll'
expect_green 'L[123]\.' 'L4\.chain\.' 'L4\.exact\.' 'L4\.solver\.lon\.' 'L5\.'
echo "PASS: P2 red pattern exact"

echo "--- P3: solver gutted -> every root-dependent check red (40), L1-L3 + unit green ---"
run_plant modes_check.eigs p3
expect_population 180
expect_total_fails 40
expect_red 'L4\.chain\.lon\.' 'L4\.chain\.lat\.' 'L4\.solver\.lon\.' 'L4\.solver\.lat\.' 'L4\.exact\.lon\.' 'L4\.exact\.lat\.' 'L5\.ph\.' 'L5\.sp\.' 'L5\.dr\.' 'L5\.roll\.' 'L5\.spiral\.'
expect_green 'L[123]\.' 'L5\.unit\.'
echo "PASS: P3 red pattern exact"

echo "--- P6: Mwdot folding dropped -> longitudinal A/quartic/roots red (12), L1 + lat green ---"
run_plant modes_check.eigs p6
expect_population 180
expect_total_fails 12
expect_red 'L2\.lon\.a31 ' 'L2\.lon\.a32 ' 'L2\.lon\.a33 ' 'L3\.lon\.' 'L4\.chain\.lon\.' 'L5\.ph\.' 'L5\.sp\.'
expect_green 'L1\.' '\.lat\.' 'L4\.(solver|exact)\.' 'L5\.unit\.'
echo "PASS: P6 red pattern exact"

echo "--- P4: generator time-dilated +5% -> all period + t_half checks red (42, incl. minspans through the refusal arm: the dilated window drops below 3 extrema), damping green ---"
run_plant measure_check.eigs p4
expect_population 126
expect_total_fails 42
expect_red 'M1\.peaks\.' 'M1\.dft\.' 'M2\.thalf\.roll' 'M2\.thalf\.spiral'
[ "$(grep -c '^FAIL M1\.peaks\.' "$OUT")" -eq 18 ] || { echo "FAIL: P4 peaks count != 18"; exit 1; }
[ "$(grep -c '^FAIL M1\.dft\.' "$OUT")" -eq 17 ] || { echo "FAIL: P4 dft count != 17"; exit 1; }
expect_green 'M2\.envelope\.' 'M3\.'
[ "$(grep -c '^FAIL M2\.logdec\.' "$OUT")" -eq 1 ] || { echo "FAIL: P4 logdec reds != 1 (only minspans should)"; exit 1; }
echo "PASS: P4 red pattern exact"

echo "--- P5: damping estimate replaced by constant 0.05 -> all zeta checks red (19) ---"
run_plant measure_check.eigs p5
expect_population 126
expect_total_fails 19
expect_red 'M2\.logdec\.' 'M2\.envelope\.heavy '
[ "$(grep -c '^FAIL M2\.logdec\.' "$OUT")" -eq 17 ] || { echo "FAIL: P5 logdec count != 17"; exit 1; }
expect_green 'M1\.' 'M2\.thalf\.' 'M3\.'
echo "PASS: P5 red pattern exact"

echo "--- P7: refusal results forced to ok=1 -> all 13 M3 checks red, rest green ---"
run_plant measure_check.eigs p7
expect_population 126
expect_total_fails 13
expect_red 'M3\.refuse\.peaks_2extrema ' 'M3\.refuse\.envelope_2spans ' 'M3\.refuse\.thalf_seven ' 'M3\.refuse\.thalf_zero ' 'M3\.refuse\.peaks ' 'M3\.refuse\.dft ' 'M3\.refuse\.logdec ' 'M3\.refuse\.dft_2cycles ' 'M3\.refuse\.dft_short ' 'M3\.refuse\.envelope ' 'M3\.refuse\.envelope_growing ' 'M3\.refuse\.thalf_short ' 'M3\.refuse\.thalf_growing '
expect_green 'M1\.' 'M2\.'
echo "PASS: P7 red pattern exact"

echo "--- P8: every input poisoned -> every data-derived check red (136), structural + pub-literal green ---"
run_plant modes_check.eigs p8
expect_population 180
expect_total_fails 136
expect_red 'L1\.lon\.' 'L1\.lat\.' 'L2\.lon\.a11 ' 'L2\.lat\.a11 ' 'L3\.lon\.' 'L3\.lat\.' 'L4\.chain\.' 'L5\.unit\.'
expect_green 'L4\.(solver|exact)\.'
echo "PASS: P8 red pattern exact"

echo "--- P9: solver roots nudged 3e-8 -> exactly the 12 exact-arm checks red ---"
run_plant modes_check.eigs p9
expect_population 180
expect_total_fails 12
expect_red 'L4\.exact\.lon\.resid' 'L4\.exact\.lon\.vieta' 'L4\.exact\.lat\.resid' 'L4\.exact\.lat\.vieta'
expect_green 'L[1235]\.' 'L4\.chain\.' 'L4\.solver\.'
echo "PASS: P9 red pattern exact"

echo "--- P10: every DFT result forced into a refusal -> the 18 dft checks red via the refusal arm ---"
run_plant measure_check.eigs p10
expect_population 126
expect_total_fails 18
expect_red 'M1\.dft\.'
[ "$(grep -c '^FAIL M1\.dft\.' "$OUT")" -eq 18 ] || { echo "FAIL: P10 dft count != 18"; exit 1; }
expect_green 'M1\.peaks\.' 'M2\.' 'M3\.'
echo "PASS: P10 red pattern exact"

echo "--- P13: time dilation x1.0011 (~1.1x the 0.1% arm) -> exactly the 18 peaks checks red ---"
run_plant measure_check.eigs p13
expect_population 126
expect_total_fails 18
[ "$(grep -c '^FAIL M1\.peaks\.' "$OUT")" -eq 18 ] || { echo "FAIL: P13 peaks count != 18"; exit 1; }
expect_green 'M0\.' 'M1\.dft\.' 'M2\.' 'M3\.'
echo "PASS: P13 red pattern exact"

echo "--- P14: zeta inflated x1.0055 (~1.1x the 0.5% arm) -> exactly the 18 logdec checks red ---"
run_plant measure_check.eigs p14
expect_population 126
expect_total_fails 18
[ "$(grep -c '^FAIL M2\.logdec\.' "$OUT")" -eq 18 ] || { echo "FAIL: P14 logdec count != 18"; exit 1; }
expect_green 'M0\.' 'M1\.' 'M2\.thalf\.' 'M2\.envelope\.' 'M3\.'
echo "PASS: P14 red pattern exact"

echo "--- P15: unit inputs x(1+1.1e-9) (~1.1x the 1e-9 arm) -> the 51 tight-arm checks red ---"
run_plant modes_check.eigs p15
expect_population 180
expect_total_fails 51
expect_red 'L1U\.' 'L2U\.' 'CU\.' 'L5\.unit\.'
expect_green 'L[1-5]\.lon\.' 'L[1-5]\.lat\.' 'L4\.' 'L5\.ph' 'L5\.sp' 'L5\.dr'
echo "PASS: P15 red pattern exact"

echo "--- P17: check_abs values displaced 1.1x their site tolerance -> the 24 nonzero-abs-arm checks red ---"
run_plant modes_check.eigs p17
expect_population 180
expect_total_fails 24
expect_red 'L4\.exact\.' 'L4\.solver\.' 'L5\.unit\.osc_sorted' 'CU\.poly4_eval\.root '
expect_green 'L[123]\.' 'L4\.chain\.' 'L5\.ph' 'L5\.sp' 'L5\.dr'
echo "PASS: P17 red pattern exact"

echo "--- P18: check_pub values displaced 1.1x the effective bound -> all 81 published-chain checks red ---"
run_plant modes_check.eigs p18
expect_population 180
expect_total_fails 81
expect_red 'L1\.' 'L2\.' 'L3\.' 'L4\.chain\.' 'L5\.ph' 'L5\.sp' 'L5\.dr'
expect_green 'L4\.(solver|exact)\.' 'L5\.unit\.' 'L1U\.' 'L2U\.' 'CU\.'
echo "PASS: P18 red pattern exact"

echo "--- P16: M0.gen checked value x(1+1.1e-9) (~1.1x its 1e-9 arm) -> all 51 wiring checks red ---"
run_plant measure_check.eigs p16
expect_population 126
expect_total_fails 51
[ "$(grep -Ec '^FAIL M0\.gen' "$OUT")" -eq 51 ] || { echo "FAIL: P16 wiring count != 51"; exit 1; }
expect_green 'M1\.' 'M2\.' 'M3\.'
echo "PASS: P16 red pattern exact"

echo "--- P12: generator phase+dc zeroed -> the 20 nonzero-wiring M0.gen/M0.gen1 checks red ---"
run_plant measure_check.eigs p12
expect_population 126
expect_total_fails 20
expect_red 'M0\.gen\.' 'M0\.gen1\.'
[ "$(grep -Ec '^FAIL M0\.gen1?\.' "$OUT")" -eq 20 ] || { echo "FAIL: P12 wiring count != 20"; exit 1; }
expect_green 'M1\.' 'M2\.' 'M3\.'
echo "PASS: P12 red pattern exact"

echo "--- P11: expect() fed two deliberately-wrong pairs -> both must FAIL ---"
run_plant comparator_check.eigs p11
expect_population 17
expect_total_fails 2
expect_red 'cal\.must_fail_ne ' 'cal\.must_fail_zero '
expect_green 'pub\.' 'rel\.' 'abs\.'
echo "PASS: P11 red pattern exact"

# ------------------------------------------------------------------
# Manifest enforcement (round-4 review): (a) the unplanted check-name set
# must EQUAL tests/check_manifest.txt exactly — identity, not count, so a
# deleted check hidden by a double-counted one cannot keep the pin green;
# (b) every plantable name must appear in some plant's red set — a check
# outside every red set has never been shown able to fail; (c) a
# structural name in a red set means the exemption list is stale.
echo "--- manifest: identity + full red-set coverage + class vocabulary ---"
. "$(dirname "$0")/manifestlib.sh"
"$EIGS" tests/modes_check.eigs      > "$WORK/clean_modes" 2>&1      || { echo "FAIL: unplanted modes_check nonzero"; exit 1; }
"$EIGS" tests/measure_check.eigs    > "$WORK/clean_measure" 2>&1    || { echo "FAIL: unplanted measure_check nonzero"; exit 1; }
"$EIGS" tests/comparator_check.eigs > "$WORK/clean_comparator" 2>&1 || { echo "FAIL: unplanted comparator_check nonzero"; exit 1; }
grep -E '^(PASS|FAIL) ' "$WORK/clean_modes"   | awk '{print $2, $3}' | sort > "$WORK/names_modes"
grep -E '^(PASS|FAIL) ' "$WORK/clean_measure" | awk '{print $2, $3}' | sort > "$WORK/names_measure"
grep -E '^(PASS|FAIL) ' "$WORK/clean_comparator" | awk 'NF >= 3 {print $2, $3}' | sort > "$WORK/names_comparator"
grep '^ROW ' "$WORK/clean_measure" | awk '{print $2, $3}' | sort > "$WORK/rows_measure"
sort -u "$WORK/red_modes_check"   > "$WORK/redu_modes"   2>/dev/null || : > "$WORK/redu_modes"
sort -u "$WORK/red_measure_check" > "$WORK/redu_measure" 2>/dev/null || : > "$WORK/redu_measure"

# Round 25/26: rung 0's seven arms shipped with NO executed plants, and
# its class arm `continue`d on every kind but modes/measure -- so the 15
# comparator rows never reached it at all, which is the derived-exemption
# failure one layer down. One shared implementation now; mf_validate
# plants each arm against the REAL function, and mf_class rejects an
# unexpected KIND as well as an unexpected class.
CK=modes,measure,comparator
mf_validate tests/check_manifest.txt modes   "$WORK/names_modes"   "$WORK/rows_measure" "$WORK/redu_modes"   "$WORK" "$CK" rowparams plantable structural selftest || exit 1
mf_validate tests/check_manifest.txt measure "$WORK/names_measure" ""                   "$WORK/redu_measure" "$WORK" "$CK" rowparams plantable structural selftest || exit 1
echo "PASS: all manifest-enforcement arms rejected an in-class planted fault"

mf_identity   tests/check_manifest.txt modes      "$WORK/names_modes" "$WORK"      || { echo "FAIL: modes check-name set drifted from manifest"; diff "$WORK/_mfi" "$WORK/names_modes" || true; exit 1; }
mf_identity   tests/check_manifest.txt measure    "$WORK/names_measure" "$WORK"    || { echo "FAIL: measure check-name set drifted from manifest"; diff "$WORK/_mfi" "$WORK/names_measure" || true; exit 1; }
mf_identity   tests/check_manifest.txt comparator "$WORK/names_comparator" "$WORK" || { echo "FAIL: comparator probe set drifted from manifest"; diff "$WORK/_mfi" "$WORK/names_comparator" || true; exit 1; }
mf_rowparams  tests/check_manifest.txt "$WORK/rows_measure" "$WORK"                || { echo "FAIL: grid-row parameter set drifted from manifest"; diff "$WORK/_mfr" "$WORK/rows_measure" || true; exit 1; }
mf_coverage   tests/check_manifest.txt modes   "$WORK/redu_modes"                  || { echo "FAIL: a plantable modes check never went red under any plant"; exit 1; }
mf_coverage   tests/check_manifest.txt measure "$WORK/redu_measure"                || { echo "FAIL: a plantable measure check never went red under any plant"; exit 1; }
mf_structural tests/check_manifest.txt modes   "$WORK/redu_modes"                  || { echo "FAIL: a structural modes check went red — exemption list is stale"; exit 1; }
mf_structural tests/check_manifest.txt measure "$WORK/redu_measure"                || { echo "FAIL: a structural measure check went red — exemption list is stale"; exit 1; }
mf_class      tests/check_manifest.txt "$CK" rowparams plantable structural selftest || { echo "FAIL: unknown manifest class or kind token"; exit 1; }
echo "PASS: manifest identity holds; all plantable checks proven able to fail"

echo "PASS: all 18 plants flip exactly their declared checks"
