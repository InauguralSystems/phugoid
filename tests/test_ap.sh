#!/usr/bin/env bash
# Rung-3 C0..C5 checks (ORACLE.md). Green means: the CONTROLLED model's
# Jacobian at trim matches A + B*K (so the closed-loop eigenvalues the
# oracle predicts belong to the plant actually flown), trim survives at
# zero gain, the measured closed-loop modes match the predicted poles at
# three gains, the dt/gain/linearity witnesses hold, and the observer's
# behaviour in the loop matches the pinned measurements — including the
# two pre-registered predictions this rung REFUTED.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
echo "--- ap_check (C0..C5) ---"
if ! "$EIGS" tests/ap_check.eigs > "$OUT" 2>&1; then
    echo "FAIL: ap_check exited nonzero"; grep '^FAIL' "$OUT" || true; tail -3 "$OUT"; exit 1
fi
grep -q '^CHECKS_RUN 73$' "$OUT" || { echo "FAIL: check population not 73"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$' "$OUT" || { echo "FAIL: failures reported"; grep '^FAIL' "$OUT"; exit 1; }
echo "PASS: 73/73 rung-3 checks green"
