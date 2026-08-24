#!/usr/bin/env bash
# M1..M3 estimator checks (ORACLE.md) on synthetic signals with known truth.
# Green means: both period estimators and both damping estimators are inside
# their stated tolerances across the grid, the aperiodic fits hit the
# published roll/spiral half-times, the honesty refusals fire, and exactly
# 44 checks ran (the pinned population).
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

echo "--- measure_check (M1..M3) ---"
if ! "$EIGS" tests/measure_check.eigs > "$OUT" 2>&1; then
    echo "FAIL: measure_check exited nonzero"
    grep '^FAIL' "$OUT" || true
    tail -3 "$OUT"
    exit 1
fi
grep -q '^CHECKS_RUN 44$' "$OUT" || { echo "FAIL: check population not 44"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$' "$OUT" || { echo "FAIL: failures reported"; grep '^FAIL' "$OUT"; exit 1; }
echo "PASS: 44/44 estimator checks green"
