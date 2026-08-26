#!/usr/bin/env bash
# Planted faults for P3's four CLAIM assertions.
#
# Round 8 shipped two assertions described in their own comment as "this
# pins the claim". They were unreachable: placed after exact-row pins that
# exit 1 on any mismatch, they could only ever evaluate in the world where
# every row already matched. No plant existed, so nothing showed they
# could fail -- the §99/§100 shape this repo has now fixed six times.
#
# Each plant below mutates the driver's REAL output and runs the REAL
# claim implementation (tests/p3claims.sh, the same one tests/test_swarm.sh
# calls -- not a copy). Transversality: a plant must red its own claim and
# ONLY its own claim.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
# shellcheck source=tests/p3claims.sh
. tests/p3claims.sh

"$EIGS" tests/swarm_p3.eigs > "$WORK/clean" 2>&1

# The control. A plant harness whose clean run is not green is measuring
# its own noise.
p3_claims "$WORK/clean" > "$WORK/r" 2>&1 || { echo "FAIL: clean output does not satisfy P3's claims"; cat "$WORK/r"; exit 1; }
echo "--- control: clean output satisfies all four claims"

plant() { # plant <name> <expected-claim> <expected-red-count> <sed-script>
    local name="$1" want="$2" wantn="$3" script="$4"
    sed -E "$script" "$WORK/clean" > "$WORK/p"
    cmp -s "$WORK/clean" "$WORK/p" && { echo "FAIL: plant $name changed nothing (vacuous plant)"; exit 1; }
    if p3_claims "$WORK/p" > "$WORK/r" 2>&1; then
        echo "FAIL: plant $name did not red any claim — $want cannot fail"; cat "$WORK/r"; exit 1
    fi
    local got n
    got=$(grep -oP '^CLAIMFAIL \K[A-Za-z0-9.]+' "$WORK/r" | sort -u | tr '\n' ' ' | sed 's/ $//')
    n=$(grep -c '^CLAIMFAIL ' "$WORK/r")
    [ "$got" = "$want" ] || { echo "FAIL: plant $name red '$got', expected exactly '$want'"; cat "$WORK/r"; exit 1; }
    [ "$n" -eq "$wantn" ] || { echo "FAIL: plant $name produced $n CLAIMFAIL lines, expected $wantn"; cat "$WORK/r"; exit 1; }
    echo "--- $name -> $got ($n)"
}

# c1: the phugoid dies before the run ends. Every divergence count in the
# rung is void if this is true, so it must red loudest.
plant c1 P3.truth.alive 1 's/^(p3truth ac=0 sp=0\.05 .*)u_pp_last=[0-9]+/\1u_pp_last=120/'
# c2: a clean verdict row appears at the cadence where the oracle binds.
# This is P3's registered refutation condition actually firing.
plant c2 P3.noclean 1 's/^(p3 ac=[01] sp=0\.05 cad=94 .*) div=[0-9]+$/\1 div=10/'
# c3: cadence 74 stops being the blind regime -- but stays above the
# no-clean floor, so ONLY the blindness claim may move.
plant c3 P3.blind74 2 's/^(p3 ac=[01] sp=0\.05 cad=74 .*) div=[0-9]+$/\1 div=50/'
# c4: the fleet alert rate falls as the fleet grows. P3's N half.
plant c4 P3.nfleet 1 's/^(p3n n=16 .*)fleet_permille=[0-9]+/\1fleet_permille=400/'
# c5/c6: vacuity. A field that vanishes must FAIL, never pass quietly.
plant c5 P3.truth.alive 1 '/^p3truth ac=0 sp=0\.05 /d'
plant c6 P3.nfleet 1 '/^p3n /d'

# The round-8 defect itself, checked mechanically: the claim assertions
# must run BEFORE the exact-row pins. If the pins come first they exit 1
# on drift and the claims never evaluate -- which is precisely how two
# assertions shipped that could not speak.
CL=$(grep -n 'p3_claims "\$OUT"' tests/test_swarm.sh | head -1 | cut -d: -f1)
PN=$(grep -n "^P3ROWS$" tests/test_swarm.sh | head -1 | cut -d: -f1)
[ -n "$CL" ] && [ -n "$PN" ] || { echo "FAIL: could not locate the claim call or the row pins in tests/test_swarm.sh"; exit 1; }
[ "$CL" -lt "$PN" ] || { echo "FAIL: P3's claim assertions (line $CL) run AFTER the exact-row pins (line $PN) — they are unreachable, which is the round-8 defect"; exit 1; }
echo "--- ordering: claims at line $CL precede the row pins at line $PN"

echo "PASS: all 6 P3 claim plants red exactly their own claim, and the claims precede the row pins"
