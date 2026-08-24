#!/usr/bin/env bash
# L1..L5 oracle checks (ORACLE.md) against the published Caughey values.
# Green means: the full chain from nondimensional coefficients to mode
# quantities reproduces every printed value within the stated tolerances,
# and exactly 158 checks ran (the pinned population — fewer means a
# silently-skipped section, which is a harness failure, not a pass).
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

echo "--- modes_check (L1..L5) ---"
if ! "$EIGS" tests/modes_check.eigs > "$OUT" 2>&1; then
    echo "FAIL: modes_check exited nonzero"
    grep '^FAIL' "$OUT" || true
    tail -3 "$OUT"
    exit 1
fi
grep -q '^CHECKS_RUN 158$' "$OUT" || { echo "FAIL: check population not 158"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$' "$OUT" || { echo "FAIL: failures reported"; grep '^FAIL' "$OUT"; exit 1; }
echo "PASS: 158/158 oracle checks green"
