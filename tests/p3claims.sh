#!/usr/bin/env bash
# p3claims.sh -- P3's CLAIM assertions, as one shared implementation.
# IDs: P3.truth.alive, P3.rows, P3.blind74, P3.unitdep, P3.phase,
# P3.partition, P3.nuisance, P3.tail, P3.nfleet.
#
# Why this is a library and not inline in test_swarm.sh: round 8 wrote two
# claim assertions inline and placed them AFTER the exact-row pins, which
# exit 1 on any mismatch. The assertions were therefore unreachable --
# they could only evaluate in the world where every pinned row already
# matched, which is the world where they have nothing to say. Nothing
# caught that, because a gate with no planted fault has never been shown
# to be able to fail. These run against planted output in
# test_swarm_p3_planted.sh, which is what makes the reachability claim
# checkable rather than asserted.
#
# ROUND 10: the claims are stated over the FULL-WINDOW reads and over the
# SPLIT labels, because round 9's single `div = reads - osc` scalar could
# not see an inversion of the finding:
#
#   * `div` counted the first 9 reads of every channel, which are a
#     partial observer window (OBSERVER_WINDOW_N = 10) where the observer
#     by spec cannot claim anything yet. Excluding them moves the
#     published "best cell 29% divergent" to 20.8% -- onto the 20%
#     boundary the claim itself used.
#   * `div` lumped `converged`/`stable`/`equilibrium` (a FALSE ALL-CLEAR:
#     the observer affirmatively says "settled" about an aircraft that is
#     swinging) with `moving` (the documented no-claim label). Those are
#     different failures with different severity, and re-expressing the
#     same channel in DEGREES turns the first into the second while
#     leaving the physics identical. Round 9's gate passed unchanged on
#     that output.
#
# So: `detect` (fosc/full) is what the observer got RIGHT; `fac`
# (fquiet/full) is the dangerous direction. Both are graded, and the unit
# is a first-class axis.
#
# ROUND 11: the channel is PRIMED with the aircraft's real initial value.
# An unprimed `local q is 0.0` injects a fictitious 0 -> trim transient
# that the oscillation family reads as a reversal, manufacturing exactly
# one `oscillating` per channel at the read where the window fills. That
# artifact was round 10's headline "1.0% detection". Primed, cadence-74
# detection is 0 in every unit -- so claim 2 asserts EXACTLY zero, which
# is what makes the regression visible.
#
# Every claim reports independently (no early exit) so a planted fault can
# assert an EXACT red set rather than "something failed".
#
# Vacuity: a missing field is a FAIL, never a pass.

p3_claims() {
    local out="$1"
    local failed=0

    _cf() { echo "CLAIMFAIL $1: $2"; failed=1; }
    # _num <regex>; echoes the value or nothing. It must NOT report its own
    # vacuity: it is called in a command substitution, so anything it
    # echoes lands in the caller's variable and any `failed=1` it sets is
    # lost with the subshell. The first version did exactly that, and the
    # c5 plant caught it -- a vacuous field passed the claim silently
    # while printing its own failure message into the value. Vacuity is
    # reported by the CALLER, in the caller's shell.
    _num() { grep -oP "$1" "$out" 2>/dev/null | head -1; }

    # --- claim 1: the PHYSICS truth. The phugoid must still be alive at
    # the end of the run, or "the observer contradicts the aircraft" is
    # meaningless and every rate below is void. This is the row rung 4
    # lacked for eight rounds: five successive write-ups graded the
    # verdict columns against nothing and inverted the classification
    # each time.
    # ALL FOUR truth rows, not just sp=0.05. Round 15: this read only the
    # two sp=0.05 rows while the claims below grade rows at BOTH
    # dispersions -- six of the twelve cadence-74 rows P3.blind74 pins,
    # and the radmax P3.unitdep reads, come from sp=0.02. Zeroing both
    # sp=0.02 truth rows left every claim green. A truth check must cover
    # the population it licenses.
    #
    # The bounds are per-dispersion because the aircraft genuinely swing
    # different amounts: at sp=0.02 the final-period swing is 1.81 and
    # 3.52 m/s, at sp=0.05 it is 4.52 and 8.80. ORACLE attached "4.5-8.8
    # m/s" to all twelve cadence-74 rows; that is true of six of them.
    local nt=0 tv ta tsp
    while read -r ta tsp tv; do
        nt=$((nt+1))
        case "$ta/$tsp" in
            0/0.02) [ "$tv" -ge 120 ] || _cf P3.truth.alive "ac0 sp=0.02 phugoid has died (u_pp_last=$tv)" ;;
            1/0.02) [ "$tv" -ge 240 ] || _cf P3.truth.alive "ac1 sp=0.02 phugoid has died (u_pp_last=$tv)" ;;
            0/0.05) [ "$tv" -ge 300 ] || _cf P3.truth.alive "ac0 sp=0.05 phugoid has died (u_pp_last=$tv)" ;;
            1/0.05) [ "$tv" -ge 600 ] || _cf P3.truth.alive "ac1 sp=0.05 phugoid has died (u_pp_last=$tv)" ;;
        esac
    done < <(sed -n 's/^p3truth ac=\([0-9]*\) sp=\([0-9.]*\) .* u_pp_last=\([0-9-]*\).*/\1 \2 \3/p' "$out")
    [ "$nt" -eq 4 ] || _cf P3.truth.alive "$nt of 4 physics truth rows found (vacuous check)"

    # Pull every row as "unit ac sp cad full fosc fquiet".
    local rowfile
    rowfile=$(mktemp)
    grep -oP '^p3 unit=\K\S+(?=.*)' "$out" >/dev/null 2>&1
    sed -n 's/^p3 unit=\([a-z]*\) ac=\([0-9]*\) sp=\([0-9.]*\) cad=\([0-9]*\) .*full=\([0-9]*\) fosc=\([0-9]*\) fquiet=\([0-9]*\) fnoclaim=\([0-9]*\) fother=\([0-9]*\).*/\1 \2 \3 \4 \5 \6 \7 \8 \9/p' "$out" > "$rowfile"
    local nrows
    nrows=$(wc -l < "$rowfile")

    if [ "$nrows" -lt 12 ]; then
        _cf P3.rows "only $nrows verdict rows parsed from driver output (vacuous check)"
        rm -f "$rowfile"; [ "$failed" -eq 0 ] && return 0; return 1
    fi

    # --- claim 2: at cadence 74 the observer FAILS TO DETECT the live
    # mode, in EVERY unit. This is the unit-INVARIANT half, and it is the
    # one the window/period argument actually explains: a 10-sample window
    # at cadence 74 spans 0.79 of a phugoid period, so `oscillating`
    # cannot fire whatever the numbers are scaled to.
    local u a s c full fosc fq fnc fot det fac worstdet=-1 nb74=0
    while read -r u a s c full fosc fq fnc fot; do
        [ "$c" = "74" ] || continue
        nb74=$((nb74+1))
        # EXACTLY zero, and graded on `fosc` itself.
        #
        # This bound has now been wrong in four rounds running, and the
        # last time it was wrong it could not fail on the very regression
        # it was written for. Round 12 set `fosc -gt 1` while publishing
        # "1 of 100 is a real detection"; round 13 withdrew that and made
        # detection 0, but left the bound at `-gt 1` and moved the
        # assertion onto `flate` -- which is `fosc` minus exactly the one
        # read the artifact ever lands on, i.e. structurally blind to it.
        # Reverting round 13's seed restored the artifact in all twelve
        # cadence-74 rows and every claim stayed green. `flate` is gone;
        # the assertion is on the number ORACLE actually states.
        if [ "$fosc" -ne 0 ]; then
            _cf P3.blind74 "cadence 74 is no longer blind for unit=$u ac=$a sp=$s ($fosc of $full full-window reads detect a live mode; if this is 1 per row, the channel seed has been reverted to 0.0)"
        fi
    done < "$rowfile"
    # EXACT population. A ">= 6" bound tolerated losing both mrad rows
    # silently, which is the same shape as a check that examined zero
    # items and passed. The sweep produces 2 aircraft x 2 dispersions x 3
    # units = 12 cadence-74 rows.
    [ "$nb74" -eq 12 ] || _cf P3.blind74 "$nb74 cadence-74 rows found, expected 12 (vacuous check)"

    # --- claim 3: the SEVERITY of that failure is unit-dependent, and the
    # dangerous direction exists in the shipped unit. In radians the
    # observer issues a FALSE ALL-CLEAR; rescaled to degrees or
    # milliradians -- identical physics, identical cadence -- it declines
    # to claim instead. This is EigenScript#1045's absolute zero-band, and
    # it is why a claim about the observer is not a claim until its unit
    # is stated. Round 9 published the false-all-clear as if it were a
    # property of the observer rather than of the radian scaling.
    local radmax=-1 degmax=-1 nrad=0 nnonrad=0
    while read -r u a s c full fosc fq fnc fot; do
        [ "$c" = "74" ] || continue
        fac=$(( fq * 100 / full ))
        if [ "$u" = "rad" ]; then
            nrad=$((nrad+1)); [ "$fac" -gt "$radmax" ] && radmax=$fac
        else
            nnonrad=$((nnonrad+1)); [ "$fac" -gt "$degmax" ] && degmax=$fac
        fi
    done < "$rowfile"
    if [ "$nrad" -lt 2 ] || [ "$nnonrad" -lt 2 ]; then
        _cf P3.unitdep "unit axis missing from the sweep (rad rows=$nrad, non-rad rows=$nnonrad) — the claim cannot be evaluated"
    else
        [ "$radmax" -ge 90 ] || _cf P3.unitdep "the false all-clear is gone from the radian rows at cadence 74 (max ${radmax}%)"
        [ "$degmax" -eq 0 ] || _cf P3.unitdep "a false all-clear has appeared in a non-radian unit (max ${degmax}%) — the deadband attribution is wrong"
    fi

    # --- claim 4: P3's REGISTERED CONFIRMATION, restated at round 11.
    #
    # P3 predicts "a detector built on verdicts FIRES ON HEALTHY AIRCRAFT",
    # refutable by "a clean verdict stream" -- i.e. by the detector NOT
    # firing on a healthy aircraft. Truth is `oscillating`, so the
    # detection rate and the alert-on-healthy rate are the SAME number.
    #
    # Round 10 asserted the opposite inequality (max detect < 90%, "no
    # clean row") because the sweep stopped at 148 and nothing had
    # exceeded 80%. That threshold was tuned to the data, not to the
    # claim: extending the cadence sweep to 104 and 124 -- which round 11
    # forced by demanding a committed producer -- puts detection at 97.1%,
    # which would have "refuted" P3 while actually being its strongest
    # confirmation. The aircraft is measured healthy (claim 1), and a
    # verdict-driven detector alerts on 97% of its reads.
    local u a s c full fosc fq fnc fot det fac best=-1 bestrow=""
    while read -r u a s c full fosc fq fnc fot; do
        [ "$full" -gt 0 ] || { _cf P3.nuisance "row unit=$u ac=$a sp=$s cad=$c has zero full-window reads (vacuous check)"; continue; }
        det=$(( fosc * 100 / full ))
        if [ "$det" -gt "$best" ]; then best=$det; bestrow="unit=$u ac=$a sp=$s cad=$c"; fi
    done < "$rowfile"
    [ "$best" -ge 90 ] || _cf P3.nuisance "no cadence makes the detector fire on 90%+ of reads of a healthy aircraft (best ${best}% at $bestrow) — re-grade the rung; note this bound is a strong-form check, and P3 is only truly refuted by a stream that is quiet at EVERY cadence"

    # --- claim: the PHASE axis. Round 14 found that "cadence 74 detects
    # nothing" is phase-specific: holding the seed and the even spacing
    # exactly as shipped and moving only where the sample grid starts,
    # `oscillating` fires in 3 of 12 cells (ac0 at phase 37; ac1 at 7 and
    # 37). Phase is the FIFTH hidden variable found in this one row, after
    # cadence, dispersion, aircraft and unit -- and each of the previous
    # four inverted a published claim when it was finally swept.
    #
    # So the strong form ("`oscillating` cannot fire at this cadence") is
    # false and is not asserted. What is true at every phase tested is
    # that the observer detects AT MOST ONE read out of ~99 while the
    # aircraft swings 4.5-8.8 m/s peak-to-peak. That is the claim.
    local nph=0 phmax=-1 phminfull=999999 pa pc pp pfull pfosc
    local phkeys=""
    while read -r pa pc pp pfull pfosc; do
        nph=$((nph+1))
        phkeys="$phkeys $pa:$pp"
        [ "$pc" = "74" ] || _cf P3.phase "phase cell ac=$pa phase=$pp is at cadence $pc, not 74"
        [ "$pfosc" -gt "$phmax" ] && phmax=$pfosc
        [ "$pfull" -lt "$phminfull" ] && phminfull=$pfull
    done < <(sed -n 's/^p3ph ac=\([0-9]*\) cad=\([0-9]*\) phase=\([0-9]*\) full=\([0-9]*\) fosc=\([0-9]*\).*/\1 \2 \3 \4 \5/p' "$out")
    # The DENOMINATOR is asserted too. Round 15: the claim checked only the
    # numerator, so zeroing every `full` on the phase rows left it green --
    # "at most one detection in ~99 reads" with no reads at all. And the
    # twelve cells must be twelve DISTINCT (aircraft, phase) pairs: twelve
    # copies of phase 0 would have certified the claim about all phases.
    local nuniq
    nuniq=$(printf '%s\n' $phkeys | sort -u | wc -l)
    if [ "$nph" -ne 12 ]; then
        _cf P3.phase "$nph of 12 phase cells found (vacuous check)"
    elif [ "$nuniq" -ne 12 ]; then
        _cf P3.phase "the 12 phase cells cover only $nuniq distinct (aircraft, phase) pairs — the sweep is not sweeping"
    elif [ "$phminfull" -lt 90 ]; then
        _cf P3.phase "a phase cell has only $phminfull full-window reads; 'at most one detection in ~99' is not supported by that denominator"
    elif [ "$phmax" -gt 1 ]; then
        _cf P3.phase "at some grid phase the observer detects $phmax reads at cadence 74; it is no longer blind independently of phase"
    fi

    # --- claim: in a NON-RADIAN unit the aircraft and dispersion axes
    # collapse. This is the evidence for the round-6/7 downgrade, and it
    # has now been mis-stated twice from partial sweeps.
    #
    # Round 6 read the band difference as a property of the dispersion;
    # round 7 as a property of which aircraft; round 10 showed both are
    # the channel's MAGNITUDE entering an absolute deadband, so in a unit
    # far from the deadband they should collapse. Round 14 then claimed
    # they collapse only at cadence 74 and "the amplitude axis survives
    # the rescaling once the cadence is long enough" -- generalised from
    # two cells of a sweep covering one dispensation at three cadences.
    #
    # Measured over the uniform grid (round 15): in degrees the four
    # (aircraft x dispersion) cells are BYTE-IDENTICAL at six of eight
    # cadences -- 74, 84, 94, 104, 114 and 134 -- and at the other two
    # (124, 148) they differ by exactly ONE read. Cadence 134 is longer
    # than 124 and identical, so there is no "long enough" boundary. The
    # collapse is near-universal; round 14 had it backwards.
    local ncad=0 nident=0 cd lo hi spread
    for cd in 74 84 94 104 114 124 134 148; do
        lo=$(awk -v c="$cd" '$1=="deg" && $4==c {print $6}' "$rowfile" | sort -n | head -1)
        hi=$(awk -v c="$cd" '$1=="deg" && $4==c {print $6}' "$rowfile" | sort -n | tail -1)
        [ -n "$lo" ] && [ -n "$hi" ] || continue
        ncad=$((ncad+1))
        spread=$(( hi - lo ))
        [ "$spread" -eq 0 ] && nident=$((nident+1))
        [ "$spread" -le 1 ] || _cf P3.unitid "in degrees at cadence $cd the four aircraft/dispersion cells span $spread reads; rescaling no longer collapses the amplitude axis"
    done
    if [ "$ncad" -lt 8 ]; then
        _cf P3.unitid "only $ncad of 8 cadences have degree rows (vacuous check)"
    elif [ "$nident" -lt 6 ]; then
        _cf P3.unitid "the four degree cells are identical at only $nident of 8 cadences (expected at least 6)"
    fi

    # --- claim 5: the full-window buckets must PARTITION `full`.
    # Round 14 found `fosc` graded at asn>9 and `fquiet`/`fnoclaim` at
    # asn>10 -- a vestige of an artifact-eviction boundary that round 13
    # had already made unnecessary. The buckets failed to partition in 38
    # of 46 rows, and the false-all-clear RATE (the dangerous direction,
    # the number ORACLE quotes as 97-98%) was a numerator over asn>=11
    # divided by a denominator over asn>=10. A rate whose numerator and
    # denominator range over different populations is not a rate.
    local nbad=0
    while read -r u a s c full fosc fq fnc fot; do
        [ "$(( fosc + fq + fnc + fot ))" -eq "$full" ] || nbad=$((nbad+1))
    done < "$rowfile"
    [ "$nbad" -eq 0 ] || _cf P3.partition "$nbad of $nrows rows have buckets that do not sum to the full-window count; every rate below is over mismatched populations"

    # --- claim 5: the long-cadence tail. Round 11 concluded "from cadence
    # 134 on, ac0 and ac1 are identical -- the amplitude dependence
    # vanishes once the step clears the deadband, the same mechanism as
    # the unit axis". Round 12 refuted the mechanism but kept two
    # assertions that round 13 then showed were RUN-LENGTH COINCIDENCES,
    # true at 8000 frames and nowhere else:
    #
    #   frames        6000      8000      10000     12000
    #   fosc ac0/ac1  24/24     35/35     45/46     45/56    <- "equal"
    #   fquiet        10/0      14/2      19/6      34/11    <- the real one
    #
    # "Equal detection" and "frozen detection count from 134 to 148" both
    # dissolve as the run lengthens; only ONE thing survives every run
    # length tested, and it is the thing that matters: at long cadence the
    # SMALL-amplitude aircraft issues far more false all-clears than the
    # large one. The amplitude dependence did not vanish -- it moved into
    # the dangerous column. That is what is pinned, with a margin chosen
    # from the smallest gap measured (10), not from the shipped run.
    local t0q t1q
    t0q=$(awk '$1=="rad" && $2=="0" && $3=="0.05" && $4=="134" {print $7}' "$rowfile")
    t1q=$(awk '$1=="rad" && $2=="1" && $3=="0.05" && $4=="134" {print $7}' "$rowfile")
    if [ -z "$t0q" ] || [ -z "$t1q" ]; then
        _cf P3.tail "cadence 134 rows absent from the sweep (vacuous check)"
    elif [ "$(( t0q - t1q ))" -lt 5 ]; then
        _cf P3.tail "the amplitude dependence has left the false-all-clear column at cadence 134 IN RADIANS (ac0 $t0q vs ac1 $t1q); round 11's retracted claim that it vanishes at long cadence would be right"
    fi

    # --- claim 6: the fleet alert rate does not FALL with N.
    #
    # HONESTY NOTE, round 10: as built this is close to a theorem of the
    # construction rather than an empirical result. `fleet_ic` gives
    # aircraft i an N-independent initial condition, `frame_step` has no
    # inter-aircraft coupling, and each aircraft has its own channel --
    # so each aircraft's alert set is N-independent and the union is
    # monotone in N. It is kept as a REGRESSION guard (it would fire if
    # channels started sharing state, which is exactly rung 4's P4
    # defect) and it is reported in ORACLE.md as construction-bound, not
    # as evidence about observers at scale.
    local np=() n v
    for n in 2 4 8 16; do
        v=$(grep -oP "^p3n n=$n .* ffleet_permille=\K[0-9]+" "$out" 2>/dev/null | head -1)
        [ -n "$v" ] && np+=("$v")
    done
    if [ "${#np[@]}" -ne 4 ]; then
        _cf P3.nfleet "N sweep produced ${#np[@]} of 4 rows (vacuous check)"
    else
        if [ "${np[0]}" -lt 500 ]; then
            _cf P3.nfleet "the detector no longer fires on a healthy fleet at N=2 (${np[0]} permille)"
        fi
        if [ "${np[1]}" -lt "${np[0]}" ] || [ "${np[2]}" -lt "${np[1]}" ] || [ "${np[3]}" -lt "${np[2]}" ]; then
            _cf P3.nfleet "the fleet alert rate FALLS with N (${np[*]} permille); channels are no longer independent"
        fi
    fi

    rm -f "$rowfile"
    if [ "$failed" -eq 0 ]; then
        echo "P3CLAIMS OK rows=$nrows best_detect=${best}% (at $bestrow) rad_falseallclear_max=${radmax}% nonrad_max=${degmax}% fleet=${np[*]:-?}"
        return 0
    fi
    return 1
}
