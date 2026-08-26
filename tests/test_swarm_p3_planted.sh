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
echo "--- control: clean output satisfies all five claims"

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

# c1: the phugoid dies before the run ends. Every rate in the rung is
# void if this is true, so it must red loudest.
plant c1 P3.truth.alive 1 's/^(p3truth ac=0 sp=0\.05 .*)u_pp_last=[0-9]+/\1u_pp_last=120/'
# c2: cadence 74 starts detecting the live mode -- the unit-invariant
# window/period failure would be gone.
plant c2 P3.blind74 1 's/^(p3 unit=rad ac=0 sp=0\.05 cad=74 .*)fosc=[0-9]+/\1fosc=50/'
# c3: the FALSE ALL-CLEAR vanishes from the radian rows. The dangerous
# direction is what makes P3 a safety finding rather than a curiosity.
plant c3 P3.unitdep 1 's/^(p3 unit=rad .* cad=74 .*)fquiet=[0-9]+/\1fquiet=10/'
# c4: a false all-clear appears in a NON-radian unit, which would refute
# the deadband attribution (EigenScript#1045) the write-up now rests on.
plant c4 P3.unitdep 1 's/^(p3 unit=deg ac=0 sp=0\.05 cad=74 .*)fquiet=[0-9]+/\1fquiet=50/'
# c5: the detector stops firing on healthy aircraft at EVERY cadence --
# P3's registered refutation condition ("a clean verdict stream") actually
# firing. Caps only the high-detection cadences, so the cadence-74
# blindness claim must stay green and only P3.nuisance may move.
plant c5 P3.nuisance 1 's/^(p3 unit=rad ac=[01] sp=0\.05 cad=(104|114|124) .*)fosc=[0-9]+/\1fosc=10/'
# c6: the fleet alert rate falls with N -- channels sharing state again,
# which is rung 4's P4 defect returning.
plant c6 P3.nfleet 1 's/^(p3n n=16 .*)fleet_permille=[0-9]+/\1fleet_permille=400/'
# c7/c8: vacuity. A field or a whole table that vanishes must FAIL, never
# pass quietly.
plant c7 P3.truth.alive 1 '/^p3truth ac=0 sp=0\.05 /d'
plant c8 P3.rows 1 '/^p3 unit=/d'
# c9: THE ROUND-10 REGRESSION GUARD. It reds TWO claims and that is
# correct: without the deg/mrad rows there are also too few cadence-74
# rows left for P3.blind74's population check, so the sweep fails on
# coverage as well as on the axis. Drop the unit axis and keep only the
# shipped radian rows -- which is exactly the state rung 4 shipped for ten
# rounds. The claims must refuse to certify a sweep that cannot see the
# axis the verdict depends on. Rung 3 already swept rad/deg/mrad
# (tests/observer_lat_check.eigs); rung 4 did not carry it forward, and
# nothing noticed until a critic re-expressed the channel in degrees and
# watched every substantive claim invert while the gate still printed OK.
plant c9 'P3.blind74 P3.unitdep' 2 '/^p3 unit=(deg|mrad) /d'
# c10: THE BLINDNESS REGRESSION. Make the observer detect the mode in the
# STEADY stream at cadence 74, after the first full window. That is the
# claim's whole content: the detector fires once on the largest cycle and
# then never again while the aircraft is still swinging. Graded on
# `flate` rather than on `fosc` because the fosc bound has now been wrong
# three ways across rounds 10, 11 and 12 -- twice from an artifact of the
# harness's own channel priming.
plant c10 P3.blind74 12 's/^(p3 unit=[a-z]+ ac=[01] sp=0\.0[25] cad=74 .*)flate=0/\1flate=3/'

# c11/c12: the long-cadence tail. Round 11 read both of these off the
# `fosc` column alone and got both wrong.
plant c11 P3.tail 1 's/^(p3 unit=rad ac=0 sp=0\.05 cad=134 .*)fquiet=[0-9]+/\1fquiet=0/'
plant c12 P3.tail 1 's/^(p3 unit=rad ac=0 sp=0\.05 cad=148 .*fosc=)[0-9]+/\150/'

# The round-8 defect itself, checked mechanically: the claim assertions
# must run BEFORE the exact-row pins. If the pins come first they exit 1
# on drift and the claims never evaluate -- which is precisely how two
# assertions shipped that could not speak.
CL=$(grep -n 'p3_claims "\$OUT"' tests/test_swarm.sh | head -1 | cut -d: -f1)
PN=$(grep -n "^P3ROWS$" tests/test_swarm.sh | head -1 | cut -d: -f1)
[ -n "$CL" ] && [ -n "$PN" ] || { echo "FAIL: could not locate the claim call or the row pins in tests/test_swarm.sh"; exit 1; }
[ "$CL" -lt "$PN" ] || { echo "FAIL: P3's claim assertions (line $CL) run AFTER the exact-row pins (line $PN) — they are unreachable, which is the round-8 defect"; exit 1; }
echo "--- ordering: claims at line $CL precede the row pins at line $PN"

echo "PASS: all 12 P3 claim plants red exactly their own claim set, and the claims precede the row pins"
