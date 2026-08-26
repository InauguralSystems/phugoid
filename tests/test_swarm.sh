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
# a published table had no committed producer. The six rows are pinned:
# the `converged` column is what three write-ups got wrong, so it is the
# column that must not drift silently.
"$EIGS" tests/swarm_p3.eigs > "$OUT" 2>&1 || { echo "FAIL: swarm_p3 exited nonzero"; tail -3 "$OUT"; exit 1; }
grep -q '^p3 spread=0.02 cadence=74 reads=109 converged=97 oscillating=1 other=11$'  "$OUT" || { echo "FAIL: P3 row (0.02,74) drifted";  grep '^p3 ' "$OUT"; exit 1; }
grep -q '^p3 spread=0.02 cadence=148 reads=55 converged=0 oscillating=36 other=19$'  "$OUT" || { echo "FAIL: P3 row (0.02,148) drifted"; grep '^p3 ' "$OUT"; exit 1; }
grep -q '^p3 spread=0.05 cadence=74 reads=109 converged=0 oscillating=1 other=108$'  "$OUT" || { echo "FAIL: P3 row (0.05,74) drifted";  grep '^p3 ' "$OUT"; exit 1; }
grep -q '^p3 spread=0.05 cadence=94 reads=86 converged=0 oscillating=61 other=25$'   "$OUT" || { echo "FAIL: P3 row (0.05,94) drifted";   grep '^p3 ' "$OUT"; exit 1; }
grep -q '^p3 total reads across the sweep: 500$' "$OUT" || { echo "FAIL: P3 sweep population changed"; exit 1; }
echo "PASS: P3's six-row evidence table reproduces from the shipped driver"
