#!/usr/bin/env bash
# Rung-4 planted faults. Round 1 found rung 4 shipping FIVE declared plants
# of which two had no implementation and three were never run by any
# script — a declared plant that cannot fail, which is the defect this
# repo's manifest rules exist to catch. Every plant runs here, and the
# gate asserts its exact red set.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
: > "$WORK/red_union"

NPLANTS=0
run_plant() {
    NPLANTS=$((NPLANTS+1))
    "$EIGS" tests/swarm_check.eigs "$1" > "$WORK/out" 2>&1 || true
    grep -q '^CHECKS_RUN 60$' "$WORK/out" || { echo "FAIL: plant $1 ran a different population"; tail -3 "$WORK/out"; exit 1; }
    grep '^FAIL ' "$WORK/out" | awk '{print $2}' >> "$WORK/red_union"
}
expect_reds() {
    got=$(grep -c '^FAIL ' "$WORK/out" || true)
    [ "$got" -eq "$1" ] || { echo "FAIL: expected exactly $1 reds, got $got"; grep '^FAIL ' "$WORK/out"; exit 1; }
    echo "    reds: $got"
}
expect_red() { for p in "$@"; do grep -Eq "^FAIL $p" "$WORK/out" || { echo "FAIL: expected red '$p' did not flip"; exit 1; }; done; }

echo "--- W1: fleet dispersion collapsed (a swarm that is one trajectory) ---"
run_plant w1; expect_reds 1; expect_red 'W3\.dispersion'
echo "--- W2: one arm integrates fewer frames (a variant that measures LESS) ---"
run_plant w2; expect_reds 6; expect_red 'W2\.arm1\.digest'
echo "--- W3: the pinned trim literals drift from the solver ---"
run_plant w3; expect_reds 6; expect_red 'W1\.trim0' 'W1\.de' 'W1\.thrust'
echo "--- W4: the verdict stream read through ONE shared binding again ---"
# w4 now also reds the four W6 closure-vs-named rows: the shared-binding
# defect makes run_named4 disagree with BOTH its solo oracle and the
# closure form, which is the stronger statement.
run_plant w4; expect_reds 9; expect_red 'W5\.fleet\.eq\.solo\.a0' 'W5\.fleet\.eq\.solo\.a3' 'W5\.stream\.live' 'W6\.closure\.eq\.named\.a0'
echo "--- W5: the digest saturates to a constant ---"
run_plant w5; expect_reds 1; expect_red 'W2\.digest\.live'
echo "--- W6: the fleet the W4 checks read drifts from the trim state ---"
run_plant w6; expect_reds 24; expect_red 'W4\.trim\.a0s0' 'W4\.trim\.a5s3'

# W7's plants. Round 43: exit-gate item 1 -- "each one's free response
# still grades to rung 0's chain quantities through the same estimators"
# -- had NO GATE ANYWHERE, and no rung-4 file even loaded measure.eigs or
# modes.eigs. w7 is the transversality plant for the per-aircraft reading
# (the fleet collapsed to one channel copied N times, which passes every
# numeric row); w8 is the estimator-alias plant rung 1 bought as q12/q13,
# invisible numerically because the two period estimators agree on the
# phugoid to within a tenth of the tolerance.
run_plant w7; expect_reds 1; expect_red 'W7\.distinct'
run_plant w8; expect_reds 4; expect_red 'W7\.Tdft\.a0' 'W7\.Tdft\.a3'
# w9/w10 exist because the enrollment set-difference below reported
# W7.Tpeaks.* and W7.zeta.* as red by NO plant on W7's first run: eight
# numeric rows that could have been deleted with this harness green.
run_plant w9;  expect_reds 8; expect_red 'W7\.Tpeaks\.a0' 'W7\.Tdft\.a3'
run_plant w10; expect_reds 4; expect_red 'W7\.zeta\.a0' 'W7\.zeta\.a3'
# w11/w12: round 44 gutted as_tp7 and as_zl7 to `return res` and every
# plant still flipped exactly its declared count -- only as_td7 had a
# plant (w8), so two thirds of W7's identity defense was decoration. These
# are its mirror aliases, invisible numerically because the estimator
# pairs agree on the phugoid to within a fraction of the tolerance.
run_plant w11; expect_reds 4; expect_red 'W7\.Tpeaks\.a0' 'W7\.Tpeaks\.a3'
run_plant w12; expect_reds 4; expect_red 'W7\.zeta\.a0' 'W7\.zeta\.a3'

# Every check that CAN be planted must have been red by something.
"$EIGS" tests/swarm_check.eigs > "$WORK/clean" 2>&1
sort -u "$WORK/red_union" > "$WORK/redu"
# EVERY check must be reddened by SOME plant. Round 2 found the four
# fleet-vs-solo checks -- this rung's DECLARED HEADLINE ORACLE -- reddened
# by nothing, while a `>= 5` union threshold passed vacuously (w3 alone
# reds 30). A threshold on the union size cannot see which checks are
# missing; only a set difference can.
"$EIGS" tests/swarm_check.eigs > "$WORK/clean" 2>&1 || true
grep -E '^(PASS|FAIL) ' "$WORK/clean" | awk '{print $2}' | sort -u > "$WORK/all"
sort -u "$WORK/red_union" > "$WORK/redu"
comm -23 "$WORK/all" "$WORK/redu" > "$WORK/never"
if [ -s "$WORK/never" ]; then
    echo "FAIL: these checks are reddened by NO plant, so nothing has shown they can fail:"
    sed 's/^/         /' "$WORK/never"
    exit 1
fi
# COUNTED, not transcribed: this said "6" while ten plants ran. Same shape
# as the P3 harness's "38" against 42, which round 43 found.
echo "PASS: all $NPLANTS rung-4 plants flip exactly their declared checks, and every check is red under some plant"
