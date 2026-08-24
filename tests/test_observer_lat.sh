#!/usr/bin/env bash
# Rung-2 O2 checks (ORACLE.md): the level-set stress — 8 agreement pins
# (value channel classifying zero-symmetric motion; the mirror identity
# why==0 across a +5 -> -5 flip with a live-instrument control; the
# matched-window roll verdict) and 5 pinned divergences (the G5 unit
# triplet: one trajectory, three units, three verdicts; the fast-mode
# window misread; the sub-milliradian converged tail). Both plants must
# flip exactly their declared sets; population pinned at 13.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

echo "--- observer_lat_check (O2) ---"
if ! "$EIGS" tests/observer_lat_check.eigs > "$OUT" 2>&1; then
    echo "FAIL: observer_lat_check exited nonzero"
    grep '^FAIL' "$OUT" || true
    tail -3 "$OUT"
    exit 1
fi
grep -q '^CHECKS_RUN 13$' "$OUT" || { echo "FAIL: check population not 13"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$' "$OUT" || { echo "FAIL: failures reported"; grep '^FAIL' "$OUT"; exit 1; }
echo "PASS: 13/13 rung-2 observer checks green"

echo "--- O1: replay frozen at first sample -> the 10 motion-expecting checks red ---"
if "$EIGS" tests/observer_lat_check.eigs o1 > "$OUT" 2>&1; then
    echo "FAIL: plant o1 did not make observer_lat_check exit nonzero"; exit 1
fi
grep -q '^CHECKS_RUN 13$' "$OUT" || { echo "FAIL: o1 population != 13"; exit 1; }
[ "$(grep -c '^FAIL ' "$OUT")" -eq 10 ] || { echo "FAIL: o1 expected 10 FAILs"; grep '^FAIL ' "$OUT"; exit 1; }
for name in 'O2\.dr\.t15 ' 'O2\.dr\.t30 ' 'O2\.dr\.t44 ' 'O2\.mirror\.mag ' 'O2\.units\.deg ' 'O2\.units\.mrad ' 'O2\.roll\.fast ' 'O2\.roll\.matched ' 'O2\.phi\.t10 ' 'O2\.phi\.t20 '; do
    grep -Eq "^FAIL $name" "$OUT" || { echo "FAIL: o1 expected red '$name'"; exit 1; }
done
grep '^FAIL ' "$OUT" | grep -Eq 'O2\.mirror\.flip |O2\.units\.rad |O2\.phi\.t35 ' && { echo "FAIL: o1 reddened a frozen-compatible check"; exit 1; }
echo "PASS: O1 red pattern exact"

echo "--- O2: unequal-magnitude alternation -> the 7 non-oscillating pins red ---"
if "$EIGS" tests/observer_lat_check.eigs o2 > "$OUT" 2>&1; then
    echo "FAIL: plant o2 did not make observer_lat_check exit nonzero"; exit 1
fi
grep -q '^CHECKS_RUN 13$' "$OUT" || { echo "FAIL: o2 population != 13"; exit 1; }
[ "$(grep -c '^FAIL ' "$OUT")" -eq 7 ] || { echo "FAIL: o2 expected 7 FAILs"; grep '^FAIL ' "$OUT"; exit 1; }
for name in 'O2\.mirror\.flip ' 'O2\.units\.rad ' 'O2\.units\.deg ' 'O2\.units\.mrad ' 'O2\.roll\.fast ' 'O2\.roll\.matched ' 'O2\.phi\.t35 '; do
    grep -Eq "^FAIL $name" "$OUT" || { echo "FAIL: o2 expected red '$name'"; exit 1; }
done
echo "PASS: O2-plant red pattern exact"

echo "PASS: rung-2 observer layer graded; both plants flip exactly their declared checks"
