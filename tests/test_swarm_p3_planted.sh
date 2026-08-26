#!/usr/bin/env bash
# Planted faults for P3's CLAIM assertions (tests/p3claims.sh).
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
echo "--- control: clean output satisfies every claim"

# The filters are FUNCTIONS, not eval'd strings. An earlier version passed
# awk programs through `eval`, which re-expanded their `$0`/`$i`/`$NF` as
# shell variables under `set -u`. Functions read stdin and write stdout.

f_sed() { sed -E "$1"; }

# Move k full-window reads out of the largest non-oscillating bucket into
# `fosc`, on rows matching pat. Keeps the buckets partitioning `full`
# (claim P3.partition) -- round 14: a real detection regression MOVES a
# read between buckets, it does not invent one, and a plant that invents
# one stops being a test of a single claim.
f_mvdetect() {
    awk -v pat="$1" -v k="$2" '
    $0 ~ pat && /^p3 unit=/ {
      # A field with no "=" (the leading `p3`) is passed through
      # verbatim; rewriting it as "p3=" corrupted the row and made the
      # whole unit axis unparseable downstream.
      for (i=1;i<=NF;i++) { if (split($i,a,"=") < 2) { bare[i]=1; o[i]=$i } else { v[a[1]]=a[2]; o[i]=a[1] } }
      donor = (v["fquiet"] >= v["fnoclaim"]) ? "fquiet" : "fnoclaim"
      if (v[donor] >= k) { v["fosc"]+=k; v[donor]-=k }
      s=""
      for (i=1;i<=NF;i++) s = s (i>1?" ":"") (bare[i] ? o[i] : o[i] "=" v[o[i]])
      print s; next
    } { print }'
}

# Set one bucket to a target on matching rows, taking the difference out
# of (or returning it to) `fnoclaim`. Same partition reason.
f_setbucket() {
    awk -v pat="$1" -v fld="$2" -v val="$3" '
    $0 ~ pat && /^p3 unit=/ {
      for (i=1;i<=NF;i++) { if (split($i,a,"=") < 2) { bare[i]=1; o[i]=$i } else { v[a[1]]=a[2]; o[i]=a[1] } }
      d = val - v[fld]
      if (v["fnoclaim"] - d >= 0) { v[fld] = val; v["fnoclaim"] -= d }
      s=""
      for (i=1;i<=NF;i++) s = s (i>1?" ":"") (bare[i] ? o[i] : o[i] "=" v[o[i]])
      print s; next
    } { print }'
}

plant() { # plant <name> <expected-claims> <expected-red-count> <fn> [args...]
    local name="$1" want="$2" wantn="$3"; shift 3
    "$@" < "$WORK/clean" > "$WORK/p"
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
plant c1 P3.truth.alive 1 f_sed 's/^(p3truth ac=0 sp=0\.05 .*)u_pp_last=[0-9]+/\1u_pp_last=120/'
# c2: cadence 74 starts detecting the live mode -- the unit-invariant
# window/period failure would be gone.
plant c2 P3.blind74 1 f_mvdetect '^p3 unit=rad ac=0 sp=0\.05 cad=74 ' 50

# c3: the FALSE ALL-CLEAR vanishes from the radian rows. The dangerous
# direction is what makes P3 a safety finding rather than a curiosity.
plant c3 P3.unitdep 1 f_setbucket '^p3 unit=rad .* cad=74 ' fquiet 10
# c4: a false all-clear appears in a NON-radian unit, which would refute
# the deadband attribution (EigenScript#1045) the write-up now rests on.
plant c4 P3.unitdep 1 f_setbucket '^p3 unit=deg ac=0 sp=0\.05 cad=74 ' fquiet 50
# c5: the detector stops firing on healthy aircraft at EVERY cadence --
# P3's registered refutation condition ("a clean verdict stream") actually
# firing. Caps only the high-detection cadences, so the cadence-74
# blindness claim must stay green and only P3.nuisance may move.
plant c5 P3.nuisance 1 f_setbucket '^p3 unit=rad ac=[01] sp=0\.05 cad=(104|114|124) ' fosc 10
# c6: the fleet alert rate falls with N -- channels sharing state again,
# which is rung 4's P4 defect returning.
plant c6 P3.nfleet 1 f_sed 's/^(p3n n=16 .*)fleet_permille=[0-9]+/\1fleet_permille=400/'
# c7/c8: vacuity. A field or a whole table that vanishes must FAIL, never
# pass quietly.
plant c7 P3.truth.alive 1 f_sed '/^p3truth ac=0 sp=0\.05 /d'
plant c8 P3.rows 1 f_sed '/^p3 unit=/d'
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
plant c9 'P3.blind74 P3.unitdep' 2 f_sed '/^p3 unit=(deg|mrad) /d'
# c10: THE SEED REGRESSION. Restore the one `oscillating` per cadence-74
# row that reverting the channel seed to 0.0 produces. Round 14 found the
# previous bound (`fosc -gt 1`, inherited from round 12's withdrawn "1 of
# 100 is a real detection") could not fail on exactly this, and that the
# `flate` column it had been moved onto was structurally blind to it --
# `flate` is `fosc` minus precisely the one read the artifact lands on.
# Twelve plants existed and none used the value that actually occurred.
plant c10 P3.blind74 12 f_mvdetect 'cad=74 ' 1

# c13: the phase axis must not be droppable, and the phase claim must be
# able to fail. Round 14 found phase was the fifth unswept hidden variable
# in this row.
plant c13 P3.phase 1 f_sed 's/^(p3ph ac=1 cad=74 phase=7 .*)fosc=[0-9]+/\1fosc=4/'
plant c14 P3.phase 1 f_sed '/^p3ph ac=0 /d'
# c15: the buckets must partition the full-window count.
plant c15 P3.partition 1 f_sed 's/^(p3 unit=rad ac=0 sp=0\.05 cad=94 .*)fother=[0-9]+/\1fother=7/'

# c11/c12: the long-cadence tail. The claim is that the amplitude
# dependence survives at long cadence IN THE FALSE-ALL-CLEAR COLUMN.
# Round 11 read the tail off `fosc` alone and concluded the dependence
# vanished; round 13 showed the two assertions that replaced it were true
# only at the shipped run length.
plant c11 P3.tail 1 f_setbucket '^p3 unit=rad ac=0 sp=0\.05 cad=134 ' fquiet 2
# c12: the same collapse from the other side -- the large-amplitude
# aircraft catching up rather than the small one dropping.
plant c12 P3.tail 1 f_setbucket '^p3 unit=rad ac=1 sp=0\.05 cad=134 ' fquiet 12

# The round-8 defect itself, checked mechanically: the claim assertions
# must run BEFORE the exact-row pins. If the pins come first they exit 1
# on drift and the claims never evaluate -- which is precisely how two
# assertions shipped that could not speak.
CL=$(grep -n 'p3_claims "\$OUT"' tests/test_swarm.sh | head -1 | cut -d: -f1)
PN=$(grep -n "^P3ROWS$" tests/test_swarm.sh | head -1 | cut -d: -f1)
[ -n "$CL" ] && [ -n "$PN" ] || { echo "FAIL: could not locate the claim call or the row pins in tests/test_swarm.sh"; exit 1; }
[ "$CL" -lt "$PN" ] || { echo "FAIL: P3's claim assertions (line $CL) run AFTER the exact-row pins (line $PN) — they are unreachable, which is the round-8 defect"; exit 1; }
echo "--- ordering: claims at line $CL precede the row pins at line $PN"

echo "PASS: all 15 P3 claim plants red exactly their own claim set, and the claims precede the row pins"
