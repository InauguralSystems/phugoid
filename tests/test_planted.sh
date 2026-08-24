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
expect_population 177
expect_total_fails 15
expect_red 'L1\.lon\.Mw ' 'L2\.lon\.' 'L3\.lon\.' 'L4\.chain\.lon\.ph' 'L4\.chain\.lon\.sp' 'L5\.ph\.' 'L5\.sp\.'
expect_green '\.lat\.' 'L4\.(solver|exact)\.' 'L5\.unit\.'
echo "PASS: P1 red pattern exact"

echo "--- P2: lateral quartic c1 +1% -> only solver-alone lateral red (3) ---"
run_plant modes_check.eigs p2
expect_population 177
expect_total_fails 3
expect_red 'L4\.solver\.lat\.dr' 'L4\.solver\.lat\.roll'
expect_green 'L[123]\.' 'L4\.chain\.' 'L4\.exact\.' 'L4\.solver\.lon\.' 'L5\.'
echo "PASS: P2 red pattern exact"

echo "--- P3: solver gutted -> every root-dependent check red (40), L1-L3 + unit green ---"
run_plant modes_check.eigs p3
expect_population 177
expect_total_fails 40
expect_red 'L4\.chain\.lon\.' 'L4\.chain\.lat\.' 'L4\.solver\.lon\.' 'L4\.solver\.lat\.' 'L4\.exact\.lon\.' 'L4\.exact\.lat\.' 'L5\.ph\.' 'L5\.sp\.' 'L5\.dr\.' 'L5\.roll\.' 'L5\.spiral\.'
expect_green 'L[123]\.' 'L5\.unit\.'
echo "PASS: P3 red pattern exact"

echo "--- P6: Mwdot folding dropped -> longitudinal A/quartic/roots red (12), L1 + lat green ---"
run_plant modes_check.eigs p6
expect_population 177
expect_total_fails 12
expect_red 'L2\.lon\.a31 ' 'L2\.lon\.a32 ' 'L2\.lon\.a33 ' 'L3\.lon\.' 'L4\.chain\.lon\.' 'L5\.ph\.' 'L5\.sp\.'
expect_green 'L1\.' '\.lat\.' 'L4\.(solver|exact)\.' 'L5\.unit\.'
echo "PASS: P6 red pattern exact"

echo "--- P4: generator time-dilated +5% -> all period + t_half checks red (35, incl. minspans through the refusal arm: the dilated window drops below 3 extrema), damping green ---"
run_plant measure_check.eigs p4
expect_population 62
expect_total_fails 35
expect_red 'M1\.peaks\.' 'M1\.dft\.' 'M2\.thalf\.roll' 'M2\.thalf\.spiral'
[ "$(grep -c '^FAIL M1\.peaks\.' "$OUT")" -eq 15 ] || { echo "FAIL: P4 peaks count != 15"; exit 1; }
[ "$(grep -c '^FAIL M1\.dft\.' "$OUT")" -eq 15 ] || { echo "FAIL: P4 dft count != 15"; exit 1; }
expect_green 'M2\.envelope\.' 'M3\.'
[ "$(grep -c '^FAIL M2\.logdec\.' "$OUT")" -eq 1 ] || { echo "FAIL: P4 logdec reds != 1 (only minspans should)"; exit 1; }
echo "PASS: P4 red pattern exact"

echo "--- P5: damping estimate replaced by constant 0.05 -> all zeta checks red (16) ---"
run_plant measure_check.eigs p5
expect_population 62
expect_total_fails 16
expect_red 'M2\.logdec\.' 'M2\.envelope\.heavy '
[ "$(grep -c '^FAIL M2\.logdec\.' "$OUT")" -eq 15 ] || { echo "FAIL: P5 logdec count != 15"; exit 1; }
expect_green 'M1\.' 'M2\.thalf\.' 'M3\.'
echo "PASS: P5 red pattern exact"

echo "--- P7: refusal results forced to ok=1 -> all 11 M3 checks red, rest green ---"
run_plant measure_check.eigs p7
expect_population 62
expect_total_fails 11
expect_red 'M3\.refuse\.thalf_seven ' 'M3\.refuse\.thalf_zero ' 'M3\.refuse\.peaks ' 'M3\.refuse\.dft ' 'M3\.refuse\.logdec ' 'M3\.refuse\.dft_2cycles ' 'M3\.refuse\.dft_short ' 'M3\.refuse\.envelope ' 'M3\.refuse\.envelope_growing ' 'M3\.refuse\.thalf_short ' 'M3\.refuse\.thalf_growing '
expect_green 'M1\.' 'M2\.'
echo "PASS: P7 red pattern exact"

echo "--- P8: every input poisoned -> every data-derived check red (133), structural + pub-literal green ---"
run_plant modes_check.eigs p8
expect_population 177
expect_total_fails 133
expect_red 'L1\.lon\.' 'L1\.lat\.' 'L2\.lon\.a11 ' 'L2\.lat\.a11 ' 'L3\.lon\.' 'L3\.lat\.' 'L4\.chain\.' 'L5\.unit\.'
expect_green 'L4\.(solver|exact)\.'
echo "PASS: P8 red pattern exact"

echo "--- P9: solver roots nudged 3e-8 -> exactly the 12 exact-arm checks red ---"
run_plant modes_check.eigs p9
expect_population 177
expect_total_fails 12
expect_red 'L4\.exact\.lon\.resid' 'L4\.exact\.lon\.vieta' 'L4\.exact\.lat\.resid' 'L4\.exact\.lat\.vieta'
expect_green 'L[1235]\.' 'L4\.chain\.' 'L4\.solver\.'
echo "PASS: P9 red pattern exact"

echo "--- P10: every DFT result forced into a refusal -> the 15 dft checks red via the refusal arm ---"
run_plant measure_check.eigs p10
expect_population 62
expect_total_fails 15
expect_red 'M1\.dft\.'
[ "$(grep -c '^FAIL M1\.dft\.' "$OUT")" -eq 15 ] || { echo "FAIL: P10 dft count != 15"; exit 1; }
expect_green 'M1\.peaks\.' 'M2\.' 'M3\.'
echo "PASS: P10 red pattern exact"

echo "--- P11: expect() fed two deliberately-wrong pairs -> both must FAIL ---"
run_plant comparator_check.eigs p11
expect_population 15
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
echo "--- manifest: identity + full red-set coverage ---"
"$EIGS" tests/modes_check.eigs > "$WORK/clean_modes" 2>&1 || { echo "FAIL: unplanted modes_check nonzero"; exit 1; }
"$EIGS" tests/measure_check.eigs > "$WORK/clean_measure" 2>&1 || { echo "FAIL: unplanted measure_check nonzero"; exit 1; }
# Identity covers name AND the per-site tolerance token (field 3 of every
# check line): round-11 widened one check's decimals argument 100x and the
# name-only manifest could not see it — tolerances are data too.
grep -E '^(PASS|FAIL) ' "$WORK/clean_modes" | awk '{print $2, $3}' | sort > "$WORK/names_modes"
grep -E '^(PASS|FAIL) ' "$WORK/clean_measure" | awk '{print $2, $3}' | sort > "$WORK/names_measure"
grep '^modes ' tests/check_manifest.txt | awk '{print $2, $4}' | sort > "$WORK/man_modes"
grep '^measure ' tests/check_manifest.txt | awk '{print $2, $4}' | sort > "$WORK/man_measure"
diff -u "$WORK/man_modes" "$WORK/names_modes" > /dev/null || { echo "FAIL: modes check-name set drifted from manifest"; diff "$WORK/man_modes" "$WORK/names_modes" || true; exit 1; }
diff -u "$WORK/man_measure" "$WORK/names_measure" > /dev/null || { echo "FAIL: measure check-name set drifted from manifest"; diff "$WORK/man_measure" "$WORK/names_measure" || true; exit 1; }
sort -u "$WORK/red_modes_check" > "$WORK/redu_modes" 2>/dev/null || : > "$WORK/redu_modes"
sort -u "$WORK/red_measure_check" > "$WORK/redu_measure" 2>/dev/null || : > "$WORK/redu_measure"
"$EIGS" tests/comparator_check.eigs > "$WORK/clean_comparator" 2>&1 || { echo "FAIL: unplanted comparator_check nonzero"; exit 1; }
grep -E '^(PASS|FAIL) ' "$WORK/clean_comparator" | awk 'NF >= 3 {print $2, $3}' | sort > "$WORK/names_comparator"
grep '^comparator ' tests/check_manifest.txt | awk '{print $2, $4}' | sort > "$WORK/man_comparator"
diff -u "$WORK/man_comparator" "$WORK/names_comparator" > /dev/null || { echo "FAIL: comparator probe set drifted from manifest"; diff "$WORK/man_comparator" "$WORK/names_comparator" || true; exit 1; }
BAD=0
while read -r kind name klass tolspec; do
    case "$kind" in modes) U="$WORK/redu_modes";; measure) U="$WORK/redu_measure";; *) continue;; esac
    if [ "$klass" = plantable ] && ! grep -qx "$name" "$U"; then
        echo "FAIL: plantable check '$name' never went red under any plant"; BAD=1
    fi
    if [ "$klass" = structural ] && grep -qx "$name" "$U"; then
        echo "FAIL: structural check '$name' went red — exemption list is stale"; BAD=1
    fi
done < <(grep -v '^#' tests/check_manifest.txt)
[ "$BAD" -eq 0 ] || exit 1
echo "PASS: manifest identity holds; all plantable checks proven able to fail"

echo "PASS: all 11 plants flip exactly their declared checks"
