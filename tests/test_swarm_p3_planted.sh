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
plant c1 'P3.truth.alive P3.truth.unit' 2 f_sed 's/^(p3truth ac=0 sp=0\.05 .*)u_pp_last=[0-9]+/\1u_pp_last=120/'
# c2: cadence 74 starts detecting the live mode -- the unit-invariant
# window/period failure would be gone.
plant c2 'P3.blind74 P3.noise P3.profile' 5 f_mvdetect '^p3 unit=rad ac=0 sp=0\.05 cad=74 ' 50

# c3: the FALSE ALL-CLEAR shrinks below the bound on EVERY radian row.
# The dangerous direction is what makes P3 a safety finding rather than a
# curiosity. Round 16: this used to zero cadence 74 alone, which no longer
# refutes anything now the claim ranges over the whole grid -- the other
# seven radian cadences still carry it. A claim over 96 rows needs a plant
# over 96 rows.
plant c3 'P3.profile P3.tail P3.unitdep' 3 f_setbucket '^p3 unit=rad ' fquiet 10
# c4: a false all-clear appears in a NON-radian unit, which would refute
# the deadband attribution (EigenScript#1045) the write-up now rests on.
plant c4 'P3.unitdep P3.unitid' 2 f_setbucket '^p3 unit=deg ac=0 sp=0\.05 cad=74 ' fquiet 50
# c5: the detector stops firing on healthy aircraft at EVERY cadence --
# P3's registered refutation condition ("a clean verdict stream") actually
# firing. Caps only the high-detection cadences, so the cadence-74
# blindness claim must stay green and only P3.nuisance may move.
plant c5 'P3.nuisance P3.profile' 5 f_setbucket '^p3 unit=[a-z]+ ac=[01] sp=0\.0[25] cad=(104|114|124|134|148) ' fosc 10
# c6: the fleet alert rate falls with N -- channels sharing state again,
# which is rung 4's P4 defect returning.
plant c6 P3.nfleet 1 f_sed 's/^(p3n n=16 .*)fleet_permille=[0-9]+/\1fleet_permille=400/'
# c7/c8: vacuity. A field or a whole table that vanishes must FAIL, never
# pass quietly.
plant c7 'P3.truth.alive P3.truth.unit' 3 f_sed '/^p3truth ac=0 sp=0\.05 /d'
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
plant c9 'P3.blind74 P3.profile P3.unitdep P3.unitid' 12 f_sed '/^p3 unit=(deg|mrad) /d'
# c10: THE SEED REGRESSION. Restore the one `oscillating` per cadence-74
# row that reverting the channel seed to 0.0 produces. Round 14 found the
# previous bound (`fosc -gt 1`, inherited from round 12's withdrawn "1 of
# 100 is a real detection") could not fail on exactly this, and that the
# `flate` column it had been moved onto was structurally blind to it --
# `flate` is `fosc` minus precisely the one read the artifact lands on.
# Twelve plants existed and none used the value that actually occurred.
plant c10 'P3.blind74 P3.noise P3.profile' 19 f_mvdetect 'cad=74 ' 1

# c13: the phase axis must not be droppable, and the phase claim must be
# able to fail. Round 14 found phase was the fifth unswept hidden variable
# in this row.
plant c13 P3.phase 1 f_sed 's/^(p3ph ac=1 cad=74 phase=7 .*)fosc=[0-9]+/\1fosc=4/'
plant c14 P3.phase 1 f_sed '/^p3ph ac=0 /d'
# c16/c17: the unit-collapse claim -- the sole evidence for the round-6/7
# downgrade, mis-stated twice from partial sweeps.
plant c16 P3.unitid 2 f_setbucket '^p3 unit=deg ac=0 sp=0\.02 cad=94 ' fosc 20
plant c17 'P3.unitdep P3.unitid' 2 f_sed '/^p3 unit=deg .* cad=134 /d'
# c18: the physics truth must cover BOTH dispersions.
plant c18 P3.truth.alive 1 f_sed 's/^(p3truth ac=1 sp=0\.02 .*)u_pp_last=[0-9]+/\1u_pp_last=10/'
# c19/c20: the phase claim's denominator and its distinctness.
plant c19 P3.phase 1 f_sed 's/^(p3ph ac=[01] cad=74 phase=[0-9]+ )full=[0-9]+/\1full=3/'
plant c20 P3.phase 1 f_sed 's/^p3ph ac=1 cad=74 phase=[0-9]+ /p3ph ac=1 cad=74 phase=7 /'
# c21: THE ROUND-16 MUTANT. Give every non-radian row at every cadence
# except 74 a false all-clear, by moving its whole `fnoclaim` bucket into
# `fquiet`. Partition preserved, detection untouched, cadence 74
# untouched -- and the pre-round-16 claim, which read cadence 74 only,
# certified 634 reads of false all-clear while printing nonrad_max=0%.
f_nonrad_fac() {
    awk '/^p3 unit=(deg|mrad) / && !/cad=74 / {
      for (i=1;i<=NF;i++) { if (split($i,a,"=") < 2) { bare[i]=1; o[i]=$i } else { v[a[1]]=a[2]; o[i]=a[1] } }
      if (v["fnoclaim"]+0 > 0) { v["fquiet"] = v["fnoclaim"]; v["fnoclaim"] = 0 }
      s=""
      for (i=1;i<=NF;i++) s = s (i>1?" ":"") (bare[i] ? o[i] : o[i] "=" v[o[i]])
      print s; next
    } { print }'
}
plant c21 P3.unitdep 48 f_nonrad_fac
# c22/c23: the vacuity guards P3.unitid was missing -- population, then
# distinctness. Both are the shape round 15 fixed for P3.phase and did
# not apply here.
plant c22 'P3.profile P3.unitdep P3.unitid' 13 f_sed '/^p3 unit=deg ac=[01] sp=0\.02 cad=(84|94|104|114|124|134|148) /d'
plant c23 'P3.profile P3.unitid' 12 f_sed 's/^p3 unit=deg ac=1 sp=0\.0[25] (cad=(84|94|104|114|124|134|148) )/p3 unit=deg ac=0 sp=0.02 \1/'
# c24: the OBSERVED channel (pitch rate) must be graded, not only airspeed.
plant c24 P3.truth.alive 4 f_sed 's/^(p3truth .*)q_pp_last=[0-9-]+/\1q_pp_last=0/'
# c25/c26: the negative control must exist and must be able to fail.
plant c25 P3.control 1 f_sed 's/^(p3nc unit=deg cad=104 .*)fosc=[0-9]+/\1fosc=9/'
plant c26 P3.control 1 f_sed '/^p3nc /d'
# c27: the RADIAN half of unitdep, per row. Erase the false all-clear
# from 22 of the 32 radian rows -- 1045 of 1285 dangerous-direction reads,
# partition preserved -- which the pre-round-17 max-plus-existence bounds
# certified with the headline number unchanged.
f_erase_rad_fac() {
    awk '/^p3 unit=rad (ac=0 sp=0.02|ac=1 sp=0.02|ac=1 sp=0.05) / {
      for (i=1;i<=NF;i++) { if (split($i,a,"=") < 2) { bare[i]=1; o[i]=$i } else { v[a[1]]=a[2]; o[i]=a[1] } }
      v["fnoclaim"] += v["fquiet"]; v["fquiet"] = 0
      s=""
      for (i=1;i<=NF;i++) s = s (i>1?" ":"") (bare[i] ? o[i] : o[i] "=" v[o[i]])
      print s; next
    } { print }'
}
plant c27 'P3.profile P3.unitdep' 10 f_erase_rad_fac
# c28: radian rows deleted -- the nrad population guard was unplanted.
plant c28 P3.unitdep 1 f_sed '/^p3 unit=rad ac=1 sp=0\.05 cad=(84|104) /d'
# c29/c30: the MONOTONE control -- a moving, non-oscillating channel at
# the phugoid's own amplitude. The equilibrium control it replaces was
# degenerate (channel span 3.3e-17, and 0.0 x 57.3 == 0.0 x 1000, so its
# three units were one measurement).
plant c29 P3.monotone 1 f_sed 's/^(p3mono kind=decay_fast unit=deg cad=104 .*)fosc=[0-9]+/\1fosc=6/'
plant c30 'P3.monoclass P3.monotone' 2 f_sed '/^p3mono kind=ramp unit=mrad /d'
# c31/c32: the three-unit verdict divergence, and the ramp's contrasting
# unit-INVARIANCE.
plant c31 P3.monoclass 1 f_sed 's/^(p3mono kind=decay_slow unit=deg cad=94 .*)stable=[0-9]+/\1stable=2/'
plant c32 P3.monoclass 1 f_sed 's/^(p3mono kind=ramp unit=rad .*)diverging=[0-9]+/\1diverging=3/'
# c33/c34: THE DISCRIMINATING CONTROL. Aperiodic noise at the phugoid's
# own amplitude has no mode and no period, and the observer reports
# `oscillating` on essentially every read of it -- at the same cell where
# the fleet reads 100%. That is what refutes "detection is evidence of a
# mode". Round 17's monotone control could not have found it: every arm of
# obs_num_oscillating needs sign flips, which a monotone channel never has,
# so its 0 was invariant over 1176 cells.
plant c33 'P3.noise P3.profile' 2 f_sed 's/^(p3mono kind=noise unit=deg cad=104 .*)fosc=[0-9]+/\1fosc=4/'
plant c34 P3.noise 1 f_sed '/^p3mono kind=noise unit=mrad /d'
# c35/c36: the PROFILE contrast -- the thing that actually distinguishes a
# mode from noise, since at cadence 104 the two are both at 100%.
plant c35 'P3.noise P3.profile' 3 f_sed 's/^(p3mono kind=noise unit=deg cad=(84|94) .*)fosc=[0-9]+/\1fosc=9/'
# c36 reds four claims and all four are genuine: blind74, the unit
# collapse, the noise inversion and the profile contrast ALL rest on the
# fleet reading 0 at cadence 74. Partition-preserving so the arithmetic
# claim does not fire spuriously on top.
plant c36 'P3.blind74 P3.noise P3.profile P3.unitid' 7 f_setbucket '^p3 unit=deg ac=0 sp=0\.05 cad=74 ' fosc 90
# c37: a fleet cell goes flat WITHOUT being deadband-killed. Round 20: the
# profile claim used to read one hand-picked cell -- the maximum-spread
# one of twelve -- and the shipped unit contains a cell that is flat at 0%
# across all eight cadences, which refutes the mechanism it stated.
f_flatten_cell() {
    awk '/^p3 unit=deg ac=1 sp=0.05 / {
      for (i=1;i<=NF;i++) { if (split($i,a,"=") < 2) { bare[i]=1; o[i]=$i } else { v[a[1]]=a[2]; o[i]=a[1] } }
      v["fnoclaim"] += v["fosc"]; v["fosc"] = 0
      s=""
      for (i=1;i<=NF;i++) s = s (i>1?" ":"") (bare[i] ? o[i] : o[i] "=" v[o[i]])
      print s; next
    } { print }'
}
plant c37 'P3.profile P3.unitid' 12 f_flatten_cell
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

# u1-u4: THE UNIT CLAIM. Round 37 found P3.truth.unit was the only claim
# ID in the rung with no planted fault, and structurally unplantable --
# `plant()` filters the driver's STDOUT, while this claim reads ORACLE.md
# and the dataset. `p3claims.sh` now takes ORACLE's path from $P3_ORACLE
# so it can be pointed at a mutated copy, and these are round 37's own
# four mutants, all of which passed the string-grep version.
oplant() { # oplant <name> <expected-claims> <sed-or-cmd on a copy of ORACLE>
    local name="$1" want="$2"; shift 2
    local oc; oc=$(mktemp)
    if [ "$1" = "--unreadable" ]; then rm -f "$oc"; oc=/nonexistent/ORACLE.md
    else "$@" < ORACLE.md > "$oc"
         cmp -s ORACLE.md "$oc" && { echo "FAIL: oplant $name changed nothing (vacuous plant)"; exit 1; }
    fi
    local got
    if P3_ORACLE="$oc" p3_claims "$WORK/clean" > "$WORK/r" 2>&1; then
        echo "FAIL: oplant $name did not red any claim — $want cannot fail"; cat "$WORK/r"; rm -f "$oc"; exit 1
    fi
    got=$(grep -oP '^CLAIMFAIL \K[A-Za-z0-9.]+' "$WORK/r" | sort -u | tr '\n' ' ' | sed 's/ $//')
    [ "$got" = "$want" ] || { echo "FAIL: oplant $name red '$got', expected '$want'"; cat "$WORK/r"; rm -f "$oc"; exit 1; }
    echo "--- $name -> $got"
    [ "$oc" = "/nonexistent/ORACLE.md" ] || rm -f "$oc"
}
# the unit moved to a column header, cells left bare
oplant u1 P3.truth.unit sed -E 's/^\| ([01]) \(amp \.[0-9]+\) \| ([0-9.]+) ft\/s \| \*\*([0-9.]+) ft\/s\*\* \|/| \1 | \2 | **\3** |/'
# a different WRONG unit -- not metric, so a bare m/s grep never sees it
oplant u2 P3.truth.unit sed 's| ft/s| kt|g'
# ORACLE unreadable: the string-grep version returned 2, the `if` was
# false, and NOTHING fired -- a vacuous pass.
oplant u3 P3.truth.unit --unreadable
# the table transcribed 10x wrong while the driver prints the right numbers
oplant u4 P3.truth.unit sed -E 's/8\.44 ft\/s/84.4 ft\/s/; s/4\.52 ft\/s/45.2 ft\/s/'

# ENROLLMENT. Round 37: P3.truth.unit shipped with no plant and nothing
# noticed, because this harness -- unlike its sibling
# test_swarm_planted.sh, which uses a `comm -23` set difference -- had no
# check that every claim the library can emit is covered. A claim without
# a plant has never been shown to be able to fail.
ALLIDS=$(grep -oP '_cf \K[A-Za-z0-9.]+' tests/p3claims.sh | sort -u)
PLANTED=$(grep -oPh "^o?plant \S+ '?\K[A-Za-z0-9. ]+" tests/test_swarm_p3_planted.sh | tr ' ' '\n' | grep '^P3' | sort -u)
MISSING=$(comm -23 <(printf '%s\n' $ALLIDS) <(printf '%s\n' $PLANTED))
if [ -n "$MISSING" ]; then
    echo "FAIL: these claim IDs are reddened by NO plant, so nothing has shown they can fail:"
    printf '         %s\n' $MISSING
    exit 1
fi
echo "--- enrollment: every claim ID p3claims.sh can emit has a plant"
# ...and the header's declared list must match what the file emits.
# Trailing sentence punctuation is not part of an ID (a period after
# "P3.nfleet." was captured as part of the name on the first run).
DECL=$(sed -n '/^# IDs:/,/^# *(Round 37/p' tests/p3claims.sh | grep -oP 'P3\.[A-Za-z0-9.]+' | sed 's/\.$//' | sort -u)
DMISS=$(comm -3 <(printf '%s\n' $ALLIDS) <(printf '%s\n' $DECL))
[ -z "$DMISS" ] || { echo "FAIL: p3claims.sh's declared ID list has drifted from what it emits:"; printf '         %s\n' $DMISS; exit 1; }
echo "--- enrollment: the declared ID list matches the emitted one"

# The round-8 defect itself, checked mechanically: the claim assertions
# must run BEFORE the exact-row pins. If the pins come first they exit 1
# on drift and the claims never evaluate -- which is precisely how two
# assertions shipped that could not speak.
CL=$(grep -n 'p3_claims "\$OUT"' tests/test_swarm.sh | head -1 | cut -d: -f1)
PN=$(grep -n "^P3ROWS$" tests/test_swarm.sh | head -1 | cut -d: -f1)
[ -n "$CL" ] && [ -n "$PN" ] || { echo "FAIL: could not locate the claim call or the row pins in tests/test_swarm.sh"; exit 1; }
[ "$CL" -lt "$PN" ] || { echo "FAIL: P3's claim assertions (line $CL) run AFTER the exact-row pins (line $PN) — they are unreachable, which is the round-8 defect"; exit 1; }
echo "--- ordering: claims at line $CL precede the row pins at line $PN"

echo "PASS: all 37 P3 claim plants red exactly their own claim set, and the claims precede the row pins"
