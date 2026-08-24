#!/usr/bin/env bash
# The planted-fault matrix (ORACLE.md): each plant must flip EXACTLY the
# declared check subset to FAIL while everything else stays green. A checker
# that has never failed has not been shown to work; a plant that flips
# nothing fails this harness itself. The expected-red patterns below were
# measured on 2026-08-23 and are asserted, not assumed.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

fails() { grep -c '^FAIL ' "$OUT" || true; }

run_plant() {
    local prog="$1" plant="$2"
    if "$EIGS" "tests/$prog" "$plant" > "$OUT" 2>&1; then
        echo "FAIL: plant $plant did not make $prog exit nonzero — the checker cannot fail"
        exit 1
    fi
}

# Every plant run must still execute the full pinned check population —
# a plant that silently skips checks would fake its red pattern.
expect_population() {
    grep -q "^CHECKS_RUN $1\$" "$OUT" || { echo "FAIL: plant run population != $1"; exit 1; }
}

echo "--- P1: Cma sign flip -> longitudinal chain red, lateral+solver green ---"
run_plant modes_check.eigs p1
expect_population 101
grep -q '^FAIL L1\.lon\.Mw ' "$OUT" || { echo "FAIL: P1 did not flip L1.lon.Mw"; exit 1; }
if grep '^FAIL ' "$OUT" | grep -q '\.lat\.'; then echo "FAIL: P1 leaked into lateral checks"; exit 1; fi
if grep '^FAIL ' "$OUT" | grep -Eq 'L4\.(solver|exact)\.'; then echo "FAIL: P1 leaked into solver-alone checks"; exit 1; fi
echo "PASS: P1 red pattern exact ($(fails) longitudinal fails)"

echo "--- P2: lateral quartic c1 +1% -> only solver-alone lateral red ---"
run_plant modes_check.eigs p2
expect_population 101
grep -q '^FAIL L4\.solver\.lat\.dr' "$OUT" || { echo "FAIL: P2 did not flip the Dutch-roll match"; exit 1; }
BAD=$(grep '^FAIL ' "$OUT" | grep -cv '^FAIL L4\.solver\.lat\.' || true)
[ "$BAD" -eq 0 ] || { echo "FAIL: P2 flipped checks outside L4.solver.lat"; grep '^FAIL ' "$OUT"; exit 1; }
echo "PASS: P2 red pattern exact ($(fails) solver-lat fails)"

echo "--- P3: solver gutted -> all root-dependent checks red, L1-L3 green ---"
run_plant modes_check.eigs p3
expect_population 101
grep -q '^FAIL L4\.' "$OUT" || { echo "FAIL: P3 did not flip L4"; exit 1; }
grep -q '^FAIL L5\.' "$OUT" || { echo "FAIL: P3 did not flip L5"; exit 1; }
if grep -Eq '^FAIL L[123]\.' "$OUT"; then echo "FAIL: P3 leaked into pre-root checks"; exit 1; fi
echo "PASS: P3 red pattern exact ($(fails) root-dependent fails)"

echo "--- P6: Mwdot folding dropped -> longitudinal A/quartic/roots red ---"
run_plant modes_check.eigs p6
expect_population 101
grep -q '^FAIL L2\.lon\.a33 ' "$OUT" || { echo "FAIL: P6 did not flip A33"; exit 1; }
grep -q '^FAIL L2\.lon\.a32 ' "$OUT" || { echo "FAIL: P6 did not flip A32"; exit 1; }
if grep '^FAIL ' "$OUT" | grep -q '\.lat\.'; then echo "FAIL: P6 leaked into lateral checks"; exit 1; fi
if grep -q '^FAIL L1\.' "$OUT"; then echo "FAIL: P6 flipped L1 (plant applied too early)"; exit 1; fi
if grep '^FAIL ' "$OUT" | grep -Eq 'L4\.(solver|exact)\.'; then echo "FAIL: P6 leaked into solver-alone checks"; exit 1; fi
echo "PASS: P6 red pattern exact ($(fails) longitudinal fails)"

echo "--- P4: generator time-dilated +5% -> period checks red, damping green ---"
run_plant measure_check.eigs p4
expect_population 24
PEAKS=$(grep -c '^FAIL M1\.peaks\.' "$OUT" || true)
[ "$PEAKS" -eq 6 ] || { echo "FAIL: P4 flipped $PEAKS/6 peak-spacing checks"; exit 1; }
DFT=$(grep -c '^FAIL M1\.dft\.' "$OUT" || true)
[ "$DFT" -ge 5 ] || { echo "FAIL: P4 flipped only $DFT DFT checks (expected >= 5)"; exit 1; }
if grep -Eq '^FAIL M[23]\.' "$OUT"; then echo "FAIL: P4 leaked into damping/honesty checks"; exit 1; fi
echo "PASS: P4 red pattern exact ($(fails) period fails)"

echo "--- P5: damping estimate replaced by constant 0.05 -> all zeta checks red ---"
run_plant measure_check.eigs p5
expect_population 24
ZL=$(grep -c '^FAIL M2\.logdec\.' "$OUT" || true)
[ "$ZL" -eq 6 ] || { echo "FAIL: P5 flipped $ZL/6 log-decrement checks"; exit 1; }
grep -q '^FAIL M2\.envelope\.heavy ' "$OUT" || { echo "FAIL: P5 did not flip the envelope check"; exit 1; }
if grep -Eq '^FAIL (M1|M3)\.' "$OUT"; then echo "FAIL: P5 leaked into period/honesty checks"; exit 1; fi
if grep -q '^FAIL M2\.thalf\.' "$OUT"; then echo "FAIL: P5 leaked into aperiodic checks"; exit 1; fi
echo "PASS: P5 red pattern exact ($(fails) damping fails)"

echo "PASS: all 6 plants flip exactly their declared checks"
