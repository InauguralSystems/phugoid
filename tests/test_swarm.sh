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
p3 ac=0 spread=0.02 cadence=74 reads=109 converged=98 oscillating=1 other=10
p3 ac=0 spread=0.02 cadence=94 reads=86 converged=75 oscillating=1 other=10
p3 ac=0 spread=0.02 cadence=148 reads=55 converged=44 oscillating=1 other=10
p3 ac=0 spread=0.05 cadence=74 reads=109 converged=73 oscillating=1 other=35
p3 ac=0 spread=0.05 cadence=94 reads=86 converged=25 oscillating=41 other=20
p3 ac=0 spread=0.05 cadence=148 reads=55 converged=0 oscillating=36 other=19
p3 ac=1 spread=0.02 cadence=74 reads=109 converged=97 oscillating=1 other=11
p3 ac=1 spread=0.02 cadence=94 reads=86 converged=55 oscillating=17 other=14
p3 ac=1 spread=0.02 cadence=148 reads=55 converged=0 oscillating=36 other=19
p3 ac=1 spread=0.05 cadence=74 reads=109 converged=0 oscillating=1 other=108
p3 ac=1 spread=0.05 cadence=94 reads=86 converged=0 oscillating=61 other=25
p3 ac=1 spread=0.05 cadence=148 reads=55 converged=0 oscillating=36 other=19
P3ROWS
grep -q '^p3 total reads across the sweep: 1000$' "$OUT" || { echo "FAIL: P3 sweep population changed"; exit 1; }
# The finding IS the disagreement, so it gets its own assertion: at cadence
# 74 and the shipped dispersion, the two aircraft must differ by a lot.
A0=$(grep -oP '^p3 ac=0 spread=0.05 cadence=74 .*converged=\K[0-9]+' "$OUT")
A1=$(grep -oP '^p3 ac=1 spread=0.05 cadence=74 .*converged=\K[0-9]+' "$OUT")
[ "$A0" -gt 50 ] && [ "$A1" -eq 0 ] || { echo "FAIL: the per-aircraft disagreement P3 rests on is gone (ac0=$A0 ac1=$A1)"; exit 1; }
echo "PASS: P3's twelve-row table reproduces, and two aircraft in one fleet disagree ($A0 vs $A1 converged)"
