#!/usr/bin/env bash
# The rung-3 planted-fault matrix (ORACLE.md): each s-plant must flip
# EXACTLY its declared red set, every plant run executes the full pinned
# 56-check population, and the manifest rules hold (identity incl.
# tolerance tokens and ROW parameters; every plantable name in some red
# set; structural names in none; unknown class tokens FAIL).
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$(mktemp)"; WORK="$(mktemp -d)"; trap 'rm -f "$OUT"; rm -rf "$WORK"' EXIT

run_plant() {
    if "$EIGS" tests/ap_check.eigs "$1" > "$OUT" 2>&1; then
        echo "FAIL: plant $1 did not make ap_check exit nonzero — the checker cannot fail"; exit 1
    fi
    grep '^FAIL ' "$OUT" | awk '{print $2}' >> "$WORK/red_union" || true
    grep -q '^CHECKS_RUN 56$' "$OUT" || { echo "FAIL: plant $1 run population != 56"; exit 1; }
}
expect_total_fails() {
    got=$(grep -c '^FAIL ' "$OUT" || true)
    [ "$got" -eq "$1" ] || { echo "FAIL: expected exactly $1 FAIL lines, got $got"; grep '^FAIL ' "$OUT"; exit 1; }
}
expect_red() { for pat in "$@"; do grep -Eq "^FAIL $pat" "$OUT" || { echo "FAIL: expected red '$pat' did not flip"; grep '^FAIL ' "$OUT" || true; exit 1; }; done; }
expect_green() { for pat in "$@"; do if grep '^FAIL ' "$OUT" | grep -Eq "$pat"; then echo "FAIL: '$pat' flipped but should stay green"; grep '^FAIL ' "$OUT"; exit 1; fi; done; }
no_refusals() { grep '^FAIL ' "$OUT" | grep -q 'refused' && { echo "FAIL: $1 reds must use the numeric arm, found a refusal"; exit 1; }; return 0; }

echo "--- S1: gain sign flipped -> pitch rows + every zeta + the gain witnesses (21) ---"
run_plant s1; expect_total_fails 21
expect_red 'C0\.a23 ' 'C0\.a33 ' 'C2\.k050\.T ' 'C2\.k100\.zlog ' 'C3\.gain\.use ' 'C3\.gain\.dir '
expect_green 'C1\.'
echo "PASS: S1 red pattern exact"

echo "--- S2: gain never reaches the dynamics (inert controller) -> 22 ---"
run_plant s2; expect_total_fails 22
expect_red 'C3\.gain\.use ' 'C3\.gain\.dir ' 'C3\.lin\.shrinks ' 'C2\.k100\.T '
expect_green 'C1\.'
echo "PASS: S2 red pattern exact"

echo "--- S3: integrator RK4 -> Euler -> periods + dt invariance + supervisory toggles (7) ---"
run_plant s3; expect_total_fails 7
expect_red 'C2\.k025\.T ' 'C2\.k050\.T ' 'C2\.k100\.T ' 'C3\.dt\.T ' 'C3\.dt\.zlog ' 'C3\.dt\.zenv ' 'C5\.p2\.sup\.toggles '
expect_green 'C0\.' 'C1\.'
echo "PASS: S3 red pattern exact"

echo "--- S4: trim offset -> C1 + parity + every graded mode (36) ---"
run_plant s4; expect_total_fails 36
expect_red 'C1\.res\.' 'C1\.hold\.' 'C0\.a13 ' 'C2\.k025\.T ' 'C3\.gain\.use ' 'C5\.sp\.c050\.osc '
echo "PASS: S4 red pattern exact"

echo "--- S5: linearity witness made vacuous (rerun at the base amplitude) -> exactly 1 ---"
run_plant s5; expect_total_fails 1
expect_red 'C3\.lin\.shrinks '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C4\.' 'C5\.'
echo "PASS: S5 red pattern exact"

echo "--- S6: grading dt dilated x1.02 -> the 3 period rows + the linearity witness (4) ---"
run_plant s6; expect_total_fails 4
expect_red 'C2\.k025\.T ' 'C2\.k050\.T ' 'C2\.k100\.T ' 'C3\.lin\.shrinks '
expect_green 'C0\.' 'C1\.' 'C2\..*zlog' 'C4\.' 'C5\.sp'
echo "PASS: S6 red pattern exact"

echo "--- S7: verdict stream frozen to 'stable' (supervisory inert) -> 5 ---"
run_plant s7; expect_total_fails 5
expect_red 'C5\.sp\.c050\.osc ' 'C5\.sp\.c100\.osc ' 'C4\.ph\.osc ' 'C4\.ph\.sustained ' 'C5\.p2\.sup\.toggles '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C3\.'
echo "PASS: S7 red pattern exact"

echo "--- S8: zeta->0.05 and T->5.0 with identity carried -> the 12 numeric rows ---"
run_plant s8; expect_total_fails 12
expect_red 'C2\.k025\.T ' 'C2\.k100\.zenv ' 'C3\.gain\.use ' 'C3\.lin\.shrinks '
no_refusals S8
expect_green 'C0\.' 'C1\.' '\.n ' '\.nr ' '\.nf ' 'C4\.' 'C5\.'
echo "PASS: S8 red pattern exact"

echo "--- S9: dataset broadly poisoned -> parity + graded modes + verdicts (21) ---"
run_plant s9; expect_total_fails 21
expect_red 'C0\.a11 ' 'C0\.a33 ' 'C2\.k050\.zlog ' 'C3\.gain\.use ' 'C4\.ph\.osc '
expect_green 'C1\.'
echo "PASS: S9 red pattern exact"

echo "--- S10: dt-rerun grading separator -> exactly C3.dt.T ---"
run_plant s10; expect_total_fails 1
expect_red 'C3\.dt\.T '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C4\.' 'C5\.'
echo "PASS: S10 red pattern exact"

echo "--- S11: zeta slots swapped -> the zeta rows and their identity pins (14) ---"
run_plant s11; expect_total_fails 14
expect_red 'C2\.k025\.zl\.nr ' 'C2\.k025\.ze\.nf ' 'C2\.k100\.zlog ' 'C3\.dt\.zenv '
expect_green 'C0\.' 'C1\.' 'C2\..*\.T ' 'C4\.' 'C5\.'
echo "PASS: S11 red pattern exact"

echo "--- S12: verdicts forced to 'oscillating' (the dual of S7) -> 8 ---"
run_plant s12; expect_total_fails 8
expect_red 'C5\.sp\.c010\.osc ' 'C5\.sp\.c020\.osc ' 'C5\.sp\.c050\.osc ' 'C5\.sp\.c100\.osc ' 'C4\.ph\.osc ' 'C5\.p1\.inner\.osc ' 'C5\.p1\.inner\.engagements ' 'C5\.p2\.sup\.toggles '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C3\.'
echo "PASS: S12 red pattern exact"

echo "--- S13: below/relabs values displaced 1.1x their executed tolerance -> C1 + plantable C0 (17) ---"
run_plant s13; expect_total_fails 17
expect_red 'C1\.res\.' 'C1\.hold\.' 'C0\.a11 ' 'C0\.a34 '
expect_green 'C0\.a41 ' 'C0\.a42 ' 'C0\.a43 ' 'C0\.a44 ' 'C2\.' 'C3\.' 'C4\.' 'C5\.'
echo "PASS: S13 red pattern exact"

echo "--- S14: check_rel values displaced 1.1x their executed arm -> the 13 tolerance rows ---"
run_plant s14; expect_total_fails 13
expect_red 'C2\.k025\.T ' 'C2\.k100\.zenv ' 'C3\.dt\.T ' 'C3\.gain\.use '
no_refusals S14
expect_green 'C0\.' 'C1\.' '\.n ' '\.nr ' '\.nf ' 'C4\.' 'C5\.'
echo "PASS: S14 red pattern exact"

# ------------------------------------------------------------------
echo "--- manifest: identity + rowparams + coverage + class vocabulary ---"
"$EIGS" tests/ap_check.eigs > "$WORK/clean" 2>&1 || { echo "FAIL: unplanted ap_check nonzero"; exit 1; }
grep -E '^(PASS|FAIL) ' "$WORK/clean" | awk '{print $2, $3}' | sort > "$WORK/names"
grep '^ap ' tests/ap_manifest.txt | awk '{print $2, $4}' | sort > "$WORK/man"
diff -u "$WORK/man" "$WORK/names" > /dev/null || { echo "FAIL: check-name set drifted from manifest"; diff "$WORK/man" "$WORK/names" || true; exit 1; }
grep '^ROW ' "$WORK/clean" | awk '{print $2, $3}' | sort > "$WORK/rows"
grep '^rowparams ' tests/ap_manifest.txt | awk '{print $2, $3}' | sort > "$WORK/man_rows"
diff -u "$WORK/man_rows" "$WORK/rows" > /dev/null || { echo "FAIL: run-parameter set drifted from manifest"; diff "$WORK/man_rows" "$WORK/rows" || true; exit 1; }
sort -u "$WORK/red_union" > "$WORK/redu"
BAD=0
while read -r kind name klass tolspec; do
    [ "$kind" = ap ] || continue
    if [ "$klass" = plantable ] && ! grep -qx "$name" "$WORK/redu"; then echo "FAIL: plantable '$name' never went red"; BAD=1; fi
    if [ "$klass" = structural ] && grep -qx "$name" "$WORK/redu"; then echo "FAIL: structural '$name' went red — exemption stale"; BAD=1; fi
    case "$klass" in plantable|structural) ;; *) echo "FAIL: unknown manifest class '$klass' for '$name'"; BAD=1;; esac
done < <(grep -v '^#' tests/ap_manifest.txt)
[ "$BAD" -eq 0 ] || exit 1
echo "PASS: manifest identity holds; all plantable checks proven able to fail"
echo "PASS: all 14 rung-3 plants flip exactly their declared checks"
