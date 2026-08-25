#!/usr/bin/env bash
# The rung-2 planted-fault matrix (ORACLE.md): each r-plant must flip
# EXACTLY its declared red set, every plant run must execute the full
# pinned 56-check population, and the manifest rules hold (identity incl.
# tolerance tokens; every plantable name in some red set; structural
# names in none; unknown class tokens FAIL — rung-1 round-8's lesson).
# Fabricating plants (r8, r10) carry identity fields and their blocks
# assert the numeric arm (no-refusals) — rung-1 rounds 7-8's lessons,
# load-bearing from the first commit. Counts measured 2026-08-24.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
WORK="$(mktemp -d)"
trap 'rm -f "$OUT"; rm -rf "$WORK"' EXIT

run_plant() {
    local plant="$1"
    if "$EIGS" tests/latsim_check.eigs "$plant" > "$OUT" 2>&1; then
        echo "FAIL: plant $plant did not make latsim_check exit nonzero — the checker cannot fail"
        exit 1
    fi
    grep '^FAIL ' "$OUT" | awk '{print $2}' >> "$WORK/red_union" || true
    grep -q '^CHECKS_RUN 68$' "$OUT" || { echo "FAIL: plant $plant run population != 68"; exit 1; }
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

no_refusals() {
    grep '^FAIL ' "$OUT" | grep -q 'refused' && { echo "FAIL: $1 reds must use the numeric arm, found a refusal"; exit 1; }
    return 0
}

echo "--- R1: Cnb x1.05 (weathercock) -> DR frequency rows + spiral (5) ---"
run_plant r1
expect_total_fails 5
expect_red 'T0\.a21 ' 'T0\.a41 ' 'T2\.dr\.Tpeaks ' 'T2\.dr\.Tdft ' 'T2\.spiral\.th '
expect_green 'T1\.' 'T3\.' 'M2X\.' 'T2\.dr\.z ' 'T2\.roll'
echo "PASS: R1 red pattern exact"

echo "--- R2: Ixz dropped in the sim copy (the lateral fold-drop) -> primed rows + DR + roll (10) ---"
run_plant r2
expect_total_fails 10
expect_red 'T0\.a21 ' 'T0\.a22 ' 'T0\.a24 ' 'T0\.a41 ' 'T0\.a42 ' 'T0\.a44 ' 'T2\.dr\.Tpeaks ' 'T2\.dr\.Tdft ' 'T2\.dr\.z ' 'T2\.roll\.th '
expect_green 'T1\.' 'T2\.spiral' 'T3\.' 'M2X\.'
echo "PASS: R2 red pattern exact"

echo "--- R3: integrator RK4 -> Euler -> DR damping + roll + their dt-invariances (4) ---"
run_plant r3
expect_total_fails 4
expect_red 'T2\.dr\.z ' 'T2\.roll\.th ' 'T3\.dt\.drz ' 'T3\.dt\.rollth '
expect_green 'T0\.' 'T1\.' 'T2\.dr\.T' 'T2\.spiral' 'T3\.amp' 'T3\.ctl' 'M2X\.'
echo "PASS: R3 red pattern exact"

echo "--- R4: every state offset from the origin -> T1 (all 6) + parity + spillovers (16) ---"
run_plant r4
expect_total_fails 16
expect_red 'T1\.res\.vdot ' 'T1\.res\.pdot ' 'T1\.res\.phidot ' 'T1\.res\.rdot ' 'T1\.hold\.' 'T0\.a11 ' 'T0\.a13 ' 'T0\.a21 ' 'T0\.a22 ' 'T0\.a24 ' 'T0\.a42 ' 'T0\.a44 ' 'T2\.roll\.th '
expect_green 'M2X\.'
echo "PASS: R4 red pattern exact"

echo "--- R5: Clb x1.3 (dihedral) -> spiral + DR + roll + a bin flip (8) ---"
run_plant r5
expect_total_fails 8
expect_red 'T0\.a21 ' 'T0\.a41 ' 'T2\.dr\.Tpeaks ' 'T2\.dr\.Tdft ' 'T2\.dr\.z ' 'T2\.roll\.th ' 'T2\.spiral\.th ' 'T2\.dr\.Tdft\.k '
expect_green 'T1\.' 'T3\.' 'M2X\.'
echo "PASS: R5 red pattern exact"

echo "--- R6: grading dt dilated x1.02 -> the 4 sim period/t-half checks; zeta green (4) ---"
run_plant r6
expect_total_fails 4
expect_red 'T2\.dr\.Tpeaks ' 'T2\.dr\.Tdft ' 'T2\.roll\.th ' 'T2\.spiral\.th '
expect_green 'T0\.' 'T1\.' 'T2\.dr\.z' 'T3\.' 'M2X\.'
echo "PASS: R6 red pattern exact"

echo "--- R7: M2X generator dilated x1.05 -> bridge periods, t-halves, count pins + the 4 gen.s1 identities (12) ---"
run_plant r7
expect_total_fails 12
expect_red 'M2X\.dr\.Tpeaks ' 'M2X\.dr\.Tdft ' 'M2X\.dr\.Tpeaks\.n ' 'M2X\.dr\.z\.nr ' 'M2X\.drs\.Tpeaks ' 'M2X\.drs\.Tdft ' 'M2X\.rollc\.th ' 'M2X\.spiralc\.th ' 'M2X\.dr\.gen\.s1 ' 'M2X\.drs\.gen\.s1 ' 'M2X\.rollc\.gen\.s1 ' 'M2X\.spiralc\.gen\.s1 '
expect_green 'T[0-3]\.' 'M2X\.dr\.z ' 'M2X\.drs\.z ' 'M2X\.dr\.Tdft\.k ' '\.gen\.s0 ' '\.gen\.len '
echo "PASS: R7 red pattern exact"

echo "--- R8: zeta -> 0.05 (n_ratios carried) and t_half -> 1.0 -> the 7 result checks, NUMERIC arm (7) ---"
run_plant r8
expect_total_fails 7
expect_red 'T2\.dr\.z ' 'T2\.roll\.th ' 'T2\.spiral\.th ' 'M2X\.dr\.z ' 'M2X\.drs\.z ' 'M2X\.rollc\.th ' 'M2X\.spiralc\.th '
no_refusals R8
expect_green 'T0\.' 'T1\.' 'T2\.dr\.T' 'T3\.' '\.nr ' '\.k ' '\.n '
echo "PASS: R8 red pattern exact"

echo "--- R9: dataset broadly poisoned (zeros made nonzero, theta0 tilted) -> parity + sim modes (15) ---"
run_plant r9
expect_total_fails 15
expect_red 'T0\.a11 ' 'T0\.a12 ' 'T0\.a13 ' 'T0\.a14 ' 'T0\.a21 ' 'T0\.a22 ' 'T0\.a24 ' 'T0\.a34 ' 'T0\.a41 ' 'T0\.a42 ' 'T0\.a44 ' 'T2\.dr\.Tpeaks ' 'T2\.dr\.Tdft ' 'T2\.dr\.z ' 'T2\.roll\.th '
expect_green 'T1\.' 'T3\.' 'M2X\.'
echo "PASS: R9 red pattern exact"

echo "--- R10: re-run gradings corrupted (dt x1.02, zeta/t-half x1.03, fields carried) -> all 15 T3, NUMERIC arm ---"
run_plant r10
expect_total_fails 15
expect_red 'T3\.dt\.' 'T3\.amp\.' 'T3\.ctl\.'
[ "$(grep -c '^FAIL T3\.' "$OUT")" -eq 15 ] || { echo "FAIL: R10 T3 count != 15"; exit 1; }
no_refusals R10
expect_green 'T[0-2]\.' 'M2X\.'
echo "PASS: R10 red pattern exact"

echo "--- R11: the Td slot fed by period_peaks -> k-pins + accessor-refused Td rows (8) ---"
run_plant r11
expect_total_fails 8
expect_red 'T2\.dr\.Tdft ' 'T2\.dr\.Tdft\.k ' 'T3\.dt\.drTd ' 'T3\.amp\.drTd ' 'T3\.ctl\.drTd ' 'M2X\.dr\.Tdft ' 'M2X\.dr\.Tdft\.k ' 'M2X\.drs\.Tdft '
expect_green 'T2\.dr\.Tpeaks ' 'T3\..*drTp ' 'T2\.roll' 'T2\.spiral'
echo "PASS: R11 red pattern exact"

echo "--- R12: the Tp slot fed by period_dft -> n-pins + accessor-refused Tp rows (8) ---"
run_plant r12
expect_total_fails 8
expect_red 'T2\.dr\.Tpeaks ' 'T2\.dr\.Tpeaks\.n ' 'T3\.dt\.drTp ' 'T3\.amp\.drTp ' 'T3\.ctl\.drTp ' 'M2X\.dr\.Tpeaks ' 'M2X\.dr\.Tpeaks\.n ' 'M2X\.drs\.Tpeaks '
expect_green 'T2\.dr\.Tdft ' 'T3\..*drTd ' 'T2\.roll' 'T2\.spiral'
echo "PASS: R12 red pattern exact"

echo "--- R13: the zeta slot fed by zeta_envelope -> nr-pins + accessor-refused z rows (8) ---"
run_plant r13
expect_total_fails 8
expect_red 'T2\.dr\.z ' 'T2\.dr\.z\.nr ' 'T3\.dt\.drz ' 'T3\.amp\.drz ' 'T3\.ctl\.drz ' 'M2X\.dr\.z ' 'M2X\.dr\.z\.nr ' 'M2X\.drs\.z '
expect_green 'T2\.dr\.T' 'T2\.roll' 'T2\.spiral'
echo "PASS: R13 red pattern exact"

echo "--- R14: t_half result x1.05 at the true call site -> exactly the 4 aperiodic rows ---"
run_plant r14
expect_total_fails 4
expect_red 'T2\.roll\.th ' 'T2\.spiral\.th ' 'M2X\.rollc\.th ' 'M2X\.spiralc\.th '
expect_green 'T2\.dr\.' 'T3\.' 'M2X\.dr' 'M2X\.drs'
echo "PASS: R14 red pattern exact"

echo "--- R15: every check_below/check_relabs value displaced 1.1x its own executed tolerance -> the 6 T1 + 11 plantable T0 checks (17) ---"
run_plant r15
expect_total_fails 17
expect_red 'T1\.res\.' 'T1\.hold\.' 'T0\.a11 ' 'T0\.a12 ' 'T0\.a13 ' 'T0\.a14 ' 'T0\.a21 ' 'T0\.a22 ' 'T0\.a24 ' 'T0\.a34 ' 'T0\.a41 ' 'T0\.a42 ' 'T0\.a44 '
expect_green 'T0\.a23 ' 'T0\.a31 ' 'T0\.a32 ' 'T0\.a33 ' 'T0\.a43 ' 'T2\.' 'T3\.' 'M2X\.'
echo "PASS: R15 red pattern exact (round-1 review: check_below's executed tolerance was widenable x1e6 with every suite green; this pins each comparator at its own scale — rung-0's P15/P17 class inherited)"

echo "--- R17: the generator BODY corrupted (a1 nudged 1.1e-9, contaminant dropped, one sample short) -> exactly the 12 wiring identities ---"
run_plant r17
expect_total_fails 12
expect_red 'M2X\.dr\.gen\.' 'M2X\.drs\.gen\.' 'M2X\.rollc\.gen\.' 'M2X\.spiralc\.gen\.'
[ "$(grep -c '\.gen\.' "$OUT")" -ge 12 ] || { echo "FAIL: R17 gen count"; exit 1; }
expect_green 'T[0-3]\.' 'M2X\.dr\.T' 'M2X\.drs\.T' 'M2X\..*\.th ' 'M2X\..*\.z '
echo "PASS: R17 red pattern exact (round-4 review: the ROW token pins the PRINT, not the USE — a body-level decontamination survived; the gen.s0/s1/len identities see the body)"

echo "--- R16: every check_rel value displaced 1.1x its own executed rel arm, direction of the honest discrepancy -> all 28 tolerance rows ---"
run_plant r16
expect_total_fails 28
expect_red 'T2\.dr\.Tpeaks ' 'T2\.roll\.th ' 'T2\.spiral\.th ' 'T3\.dt\.' 'T3\.amp\.' 'T3\.ctl\.' 'M2X\.dr\.z ' 'M2X\.rollc\.th '
no_refusals R16
expect_green 'T0\.' 'T1\.' '\.k ' '\.n ' '\.nr '
echo "PASS: R16 red pattern exact (round-2 review: check_rel — the third comparator — had no displacement plant; a single-site x10 executed widening survived every suite)"

# ------------------------------------------------------------------
echo "--- manifest: identity + full red-set coverage + class vocabulary ---"
"$EIGS" tests/latsim_check.eigs > "$WORK/clean_lat" 2>&1 || { echo "FAIL: unplanted latsim_check nonzero"; exit 1; }
grep -E '^(PASS|FAIL) ' "$WORK/clean_lat" | awk '{print $2, $3}' | sort > "$WORK/names_lat"
grep '^lat ' tests/latsim_manifest.txt | awk '{print $2, $4}' | sort > "$WORK/man_lat"
diff -u "$WORK/man_lat" "$WORK/names_lat" > /dev/null || { echo "FAIL: lat check-name set drifted from manifest"; diff "$WORK/man_lat" "$WORK/names_lat" || true; exit 1; }
# Bridge-row generator parameters are identity-checked too (rung-0's
# round-20 rowparams class, inherited at rung-2 round 3: a zeroed
# contaminant amplitude never enters any expected truth, so only the
# emitted-args identity can see it).
grep '^ROW ' "$WORK/clean_lat" | awk '{print $2, $3}' | sort > "$WORK/rows_lat"
grep '^rowparams ' tests/latsim_manifest.txt | awk '{print $2, $3}' | sort > "$WORK/man_rows_lat"
diff -u "$WORK/man_rows_lat" "$WORK/rows_lat" > /dev/null || { echo "FAIL: bridge-row parameter set drifted from manifest"; diff "$WORK/man_rows_lat" "$WORK/rows_lat" || true; exit 1; }
sort -u "$WORK/red_union" > "$WORK/redu_lat"
BAD=0
while read -r kind name klass tolspec; do
    [ "$kind" = lat ] || continue
    if [ "$klass" = plantable ] && ! grep -qx "$name" "$WORK/redu_lat"; then
        echo "FAIL: plantable check '$name' never went red under any plant"; BAD=1
    fi
    if [ "$klass" = structural ] && grep -qx "$name" "$WORK/redu_lat"; then
        echo "FAIL: structural check '$name' went red — exemption list is stale"; BAD=1
    fi
    case "$klass" in plantable|structural) ;; *) echo "FAIL: unknown manifest class '$klass' for '$name'"; BAD=1;; esac
done < <(grep -v '^#' tests/latsim_manifest.txt)
[ "$BAD" -eq 0 ] || exit 1
echo "PASS: manifest identity holds; all plantable checks proven able to fail"

echo "PASS: all 17 rung-2 plants flip exactly their declared checks"
