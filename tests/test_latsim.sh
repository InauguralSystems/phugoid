#!/usr/bin/env bash
# Rung-2 T0..T3 + M2X checks (ORACLE.md). Green means: the lateral
# model's Jacobian at the exact-origin trim matches the rung-0 a_lat to
# machine-epsilon-scale arms, the origin is a true equilibrium through
# the integrator, the three mode-pure IC runs grade to the chain's
# Dutch-roll/roll/spiral quantities inside the declared arms, the
# dt/amplitude/control invariances hold, the M2X bridge is valid in
# rung-2's exact windows, and exactly 76 checks ran.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

echo "--- latsim_check (T0..T3, M2X) ---"
if ! "$EIGS" tests/latsim_check.eigs > "$OUT" 2>&1; then
    echo "FAIL: latsim_check exited nonzero"
    grep '^FAIL' "$OUT" || true
    tail -3 "$OUT"
    exit 1
fi
grep -q '^CHECKS_RUN 76$' "$OUT" || { echo "FAIL: check population not 76"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$' "$OUT" || { echo "FAIL: failures reported"; grep '^FAIL' "$OUT"; exit 1; }
echo "PASS: 76/76 rung-2 checks green"
