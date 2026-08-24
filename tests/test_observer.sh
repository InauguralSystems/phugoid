#!/usr/bin/env bash
# Rung-1 O checks (ORACLE.md): observer verdicts graded against physics
# ground truth on the graded trajectories — 8 physics-agreement pins plus
# 3 pinned, measured divergences (the fixed 10-sample value-channel
# window vs a 47 s mode at 1 Hz; GAPS.md G4). Both observer plants must
# flip exactly their declared sets; population pinned at 11.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

echo "--- observer_check (O) ---"
if ! "$EIGS" tests/observer_check.eigs > "$OUT" 2>&1; then
    echo "FAIL: observer_check exited nonzero"
    grep '^FAIL' "$OUT" || true
    tail -3 "$OUT"
    exit 1
fi
grep -q '^CHECKS_RUN 11$' "$OUT" || { echo "FAIL: check population not 11"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$' "$OUT" || { echo "FAIL: failures reported"; grep '^FAIL' "$OUT"; exit 1; }
echo "PASS: 11/11 observer checks green"

echo "--- O1: replay frozen at first sample -> the 9 motion-expecting checks red ---"
if "$EIGS" tests/observer_check.eigs o1 > "$OUT" 2>&1; then
    echo "FAIL: plant o1 did not make observer_check exit nonzero"; exit 1
fi
grep -q '^CHECKS_RUN 11$' "$OUT" || { echo "FAIL: o1 population != 11"; exit 1; }
[ "$(grep -c '^FAIL ' "$OUT")" -eq 9 ] || { echo "FAIL: o1 expected 9 FAILs"; grep '^FAIL ' "$OUT"; exit 1; }
for name in 'O\.sp\.t10 ' 'O\.sp\.t15 ' 'O\.ph5s\.t120 ' 'O\.ph5s\.t200 ' 'O\.ph5s\.t280 ' 'O\.ph5s\.named ' 'O\.ph1s\.t120 ' 'O\.ph1s\.t200 ' 'O\.ph1s\.t280 '; do
    grep -Eq "^FAIL $name" "$OUT" || { echo "FAIL: o1 expected red '$name'"; exit 1; }
done
grep '^FAIL ' "$OUT" | grep -Eq 'O\.hold |O\.sp\.t29 ' && { echo "FAIL: o1 reddened a settledness check"; exit 1; }
echo "PASS: O1 red pattern exact"

echo "--- O2: replay replaced by a large alternation -> the 5 non-oscillating pins red ---"
if "$EIGS" tests/observer_check.eigs o2 > "$OUT" 2>&1; then
    echo "FAIL: plant o2 did not make observer_check exit nonzero"; exit 1
fi
grep -q '^CHECKS_RUN 11$' "$OUT" || { echo "FAIL: o2 population != 11"; exit 1; }
[ "$(grep -c '^FAIL ' "$OUT")" -eq 5 ] || { echo "FAIL: o2 expected 5 FAILs"; grep '^FAIL ' "$OUT"; exit 1; }
for name in 'O\.hold ' 'O\.sp\.t29 ' 'O\.ph1s\.t120 ' 'O\.ph1s\.t200 ' 'O\.ph1s\.t280 '; do
    grep -Eq "^FAIL $name" "$OUT" || { echo "FAIL: o2 expected red '$name'"; exit 1; }
done
echo "PASS: O2 red pattern exact"

echo "PASS: observer layer graded; both plants flip exactly their declared checks"
