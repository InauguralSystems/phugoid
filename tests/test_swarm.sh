#!/usr/bin/env bash
# Rung-4 W checks: the swarm is still N of rung 1's aircraft, and the arms
# — which differ only in OBSERVATION — do not differ in physics.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT=$(mktemp); trap 'rm -f "$OUT"' EXIT
echo "--- swarm_check (W1..W4) ---"
"$EIGS" tests/swarm_check.eigs > "$OUT" 2>&1 || { echo "FAIL: swarm_check exited nonzero"; tail -5 "$OUT"; exit 1; }
grep -q '^CHECKS_RUN 47$' "$OUT" || { echo "FAIL: check population not 47"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$'  "$OUT" || { echo "FAIL: swarm_check has failures"; grep '^FAIL' "$OUT"; exit 1; }
grep -q '^FAIL harness' "$OUT" && { echo "FAIL: harness self-check"; grep '^FAIL harness' "$OUT"; exit 1; }
echo "PASS: 47/47 rung-4 checks green"

# P3's evidence table is produced by a shipped driver, not by prose. Round
# 6 found it existing only in ORACLE.md -- the third time in this rung that
# a published table had no committed producer. Round 7 then found the
# driver sampling ONE arbitrary aircraft while ORACLE reported the row as a
# property of the dispersion, so ALL TWELVE rows are pinned now, across
# both the amplitude and cadence axes. The pins protect the disagreement
# BETWEEN aircraft, which is the finding; pinning one index protected the
# index choice instead.
"$EIGS" tests/swarm_p3.eigs > "$OUT" 2>&1 || { echo "FAIL: swarm_p3 exited nonzero"; tail -3 "$OUT"; exit 1; }
NP3=$(grep -c '^p3 ac=' "$OUT" || true)
[ "$NP3" = "12" ] || { echo "FAIL: P3 sweep produced $NP3 rows, expected 12"; exit 1; }
while read -r want; do
    grep -qxF "$want" "$OUT" || { echo "FAIL: P3 row drifted: $want"; grep '^p3 ' "$OUT"; exit 1; }
done <<'P3ROWS'
p3 ac=0 sp=0.02 cad=74 reads=109 conv=98 osc=1 moving=9 stable=1 equil=0 improving=0
p3 ac=0 sp=0.02 cad=94 reads=86 conv=75 osc=1 moving=9 stable=1 equil=0 improving=0
p3 ac=0 sp=0.02 cad=148 reads=55 conv=44 osc=1 moving=0 stable=10 equil=0 improving=0
p3 ac=0 sp=0.05 cad=74 reads=109 conv=73 osc=1 moving=10 stable=0 equil=25 improving=0
p3 ac=0 sp=0.05 cad=94 reads=86 conv=25 osc=41 moving=10 stable=1 equil=9 improving=0
p3 ac=0 sp=0.05 cad=148 reads=55 conv=0 osc=36 moving=10 stable=6 equil=3 improving=0
p3 ac=1 sp=0.02 cad=74 reads=109 conv=97 osc=1 moving=10 stable=0 equil=1 improving=0
p3 ac=1 sp=0.02 cad=94 reads=86 conv=55 osc=17 moving=10 stable=0 equil=4 improving=0
p3 ac=1 sp=0.02 cad=148 reads=55 conv=0 osc=36 moving=10 stable=2 equil=7 improving=0
p3 ac=1 sp=0.05 cad=74 reads=109 conv=0 osc=1 moving=11 stable=65 equil=32 improving=0
p3 ac=1 sp=0.05 cad=94 reads=86 conv=0 osc=61 moving=10 stable=15 equil=0 improving=0
p3 ac=1 sp=0.05 cad=148 reads=55 conv=0 osc=36 moving=13 stable=6 equil=0 improving=0
P3ROWS
grep -q '^p3 total reads across the sweep: 1000$' "$OUT" || { echo "FAIL: P3 sweep population changed"; exit 1; }
# The finding IS the disagreement, so it gets its own assertion: at cadence
# 74 and the shipped dispersion, the two aircraft must differ by a lot.
# P3's claim is that a verdict-driven detector FIRES on healthy aircraft,
# and that lives at cadence 94. Round 8: the previous assertion pinned the
# `converged` column at cadence 74 and would have passed identically
# whether aircraft 1 read `stable` 97 times or `diverging` 97 times -- it
# pinned a number, not the claim. This pins the claim.
O0=$(grep -oP '^p3 ac=0 sp=0.05 cad=94 .* osc=\K[0-9]+' "$OUT")
O1=$(grep -oP '^p3 ac=1 sp=0.05 cad=94 .* osc=\K[0-9]+' "$OUT")
[ "$O0" -ge 30 ] && [ "$O1" -ge 30 ] || { echo "FAIL: P3's registered prediction is gone — a healthy phugoid no longer reads oscillating at cadence 94 (ac0=$O0 ac1=$O1)"; exit 1; }
# ...and at cadence 74 BOTH aircraft must be quiescent, which is what round
# 8 found the headline had inverted.
Q0=$(grep -oP '^p3 ac=0 sp=0.05 cad=74 .* osc=\K[0-9]+' "$OUT")
Q1=$(grep -oP '^p3 ac=1 sp=0.05 cad=74 .* osc=\K[0-9]+' "$OUT")
[ "$Q0" -le 2 ] && [ "$Q1" -le 2 ] || { echo "FAIL: cadence 74 is no longer the quiescent regime (ac0=$Q0 ac1=$Q1)"; exit 1; }
echo "PASS: P3's twelve-row seven-class table reproduces; quiescent at cadence 74, oscillating at 94 ($O0/$O1)"
