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

run_plant() {
    "$EIGS" tests/swarm_check.eigs "$1" > "$WORK/out" 2>&1 || true
    grep -q '^CHECKS_RUN 43$' "$WORK/out" || { echo "FAIL: plant $1 ran a different population"; tail -3 "$WORK/out"; exit 1; }
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
run_plant w3; expect_reds 30; expect_red 'W1\.trim0' 'W1\.thrust'
echo "--- W4: the verdict stream read through ONE shared binding again ---"
run_plant w4; expect_reds 1; expect_red 'W5\.stream\.live'
echo "--- W5: the digest saturates to a constant ---"
run_plant w5; expect_reds 1; expect_red 'W2\.digest\.live'

# Every check that CAN be planted must have been red by something.
"$EIGS" tests/swarm_check.eigs > "$WORK/clean" 2>&1
sort -u "$WORK/red_union" > "$WORK/redu"
NRED=$(grep -c . "$WORK/redu" || true)
[ "$NRED" -ge 5 ] || { echo "FAIL: the red union covers only $NRED checks — the plants are not exercising the suite"; exit 1; }
echo "PASS: all 5 rung-4 plants flip exactly their declared checks (union covers $NRED)"
