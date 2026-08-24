#!/usr/bin/env bash
# Comparator boundary self-test: every tolerance arm in tests/checklib.eigs
# must pass a just-inside value and fail a just-outside value. Exists because
# round-2 blind review widened a comparator tolerance 10x and the whole
# suite (planted matrix included) stayed green — the checkers' own
# discriminating power was unpinned.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

echo "--- comparator_check (tolerance boundaries) ---"
if ! "$EIGS" tests/comparator_check.eigs > "$OUT" 2>&1; then
    echo "FAIL: comparator_check exited nonzero"
    grep '^FAIL' "$OUT" || true
    tail -3 "$OUT"
    exit 1
fi
grep -q '^CHECKS_RUN 13$' "$OUT" || { echo "FAIL: check population not 13"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$' "$OUT" || { echo "FAIL: failures reported"; grep '^FAIL' "$OUT"; exit 1; }
echo "PASS: 13/13 comparator boundary checks green"
