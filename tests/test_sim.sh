#!/usr/bin/env bash
# Rung-1 S0..S4 + M1X checks (ORACLE.md). Green means: the nonlinear
# 3-DOF model's Jacobian at its solved trim matches the rung-0 A matrix,
# trim is a true equilibrium through the integrator, the SP-subspace IC
# and elevator-pulse runs grade to the chain's mode quantities inside the
# declared arms, the dt/amplitude/control invariances hold, the estimator
# bridge is valid in the sim's regimes, and exactly 59 checks ran.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

echo "--- sim_check (S0..S4, M1X) ---"
if ! "$EIGS" tests/sim_check.eigs > "$OUT" 2>&1; then
    echo "FAIL: sim_check exited nonzero"
    grep '^FAIL' "$OUT" || true
    tail -3 "$OUT"
    exit 1
fi
grep -q '^CHECKS_RUN 59$' "$OUT" || { echo "FAIL: check population not 59"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$' "$OUT" || { echo "FAIL: failures reported"; grep '^FAIL' "$OUT"; exit 1; }
echo "PASS: 59/59 rung-1 checks green"
