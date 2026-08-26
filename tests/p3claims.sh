#!/usr/bin/env bash
# p3claims.sh -- P3's six CLAIM assertions, as one shared implementation.
# IDs: P3.truth.alive, P3.rows, P3.blind74, P3.unitdep, P3.nuisance,
# P3.tail, P3.nfleet.
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
    local ul0 ul1
    ul0=$(_num '^p3truth ac=0 sp=0.05 .* u_pp_last=\K[0-9-]+')
    ul1=$(_num '^p3truth ac=1 sp=0.05 .* u_pp_last=\K[0-9-]+')
    if [ -z "$ul0" ] || [ -z "$ul1" ]; then
        _cf P3.truth.alive "physics truth row absent from driver output (vacuous check)"
    elif [ "$ul0" -lt 300 ] || [ "$ul1" -lt 600 ]; then
        _cf P3.truth.alive "the phugoid is no longer swinging in the final period (u_pp_last ac0=$ul0 ac1=$ul1 hundredths m/s); P3's truth table has changed"
    fi

    # Pull every row as "unit ac sp cad full fosc fquiet".
    local rowfile
    rowfile=$(mktemp)
    grep -oP '^p3 unit=\K\S+(?=.*)' "$out" >/dev/null 2>&1
    sed -n 's/^p3 unit=\([a-z]*\) ac=\([0-9]*\) sp=\([0-9.]*\) cad=\([0-9]*\) .*full=\([0-9]*\) fosc=\([0-9]*\) fquiet=\([0-9]*\) fnoclaim=[0-9]* flate=\([0-9]*\).*/\1 \2 \3 \4 \5 \6 \7 \8/p' "$out" > "$rowfile"
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
    local u a s c full fosc fq flate det fac worstdet=-1 nb74=0
    while read -r u a s c full fosc fq flate; do
        [ "$c" = "74" ] || continue
        nb74=$((nb74+1))
        # Graded on LATE reads -- strictly after the first full window.
        #
        # The bound has now been wrong three ways. Round 10 used "<=5%"
        # and reported 1.0% detection that was really the unprimed
        # `local q is 0.0` initialiser. Round 11 primed, measured 0, and
        # asserted EXACTLY zero -- but its priming sat one FRAME before
        # the first read while every later gap is one CADENCE, and that
        # uneven gap suppressed the one true detection. Round 12 primes
        # from inside the loop so every gap is a cadence, and the honest
        # number is 1 of 100: the observer fires once, at asn=10, the
        # first window that is full, which spans the run's
        # largest-amplitude cycle. That is a REAL detection.
        #
        # The finding is that it never fires again. `flate` counts
        # detections after that first full window, and it must be 0 while
        # the aircraft is still swinging 4.5-8.8 m/s peak-to-peak. This
        # bound is about the physics rather than about an artifact, so it
        # cannot be re-tuned by a future priming change.
        if [ "$flate" -ne 0 ]; then
            _cf P3.blind74 "cadence 74 is no longer blind for unit=$u ac=$a sp=$s ($flate detections after the first full window, on a mode the window cannot span)"
        fi
        if [ "$fosc" -gt 1 ]; then
            _cf P3.blind74 "cadence 74 detects $fosc of $full full-window reads for unit=$u ac=$a sp=$s (expected at most the single first-full-window read)"
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
    while read -r u a s c full fosc fq flate; do
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
    local u a s c full fosc fq flate det fac best=-1 bestrow=""
    while read -r u a s c full fosc fq flate; do
        [ "$full" -gt 0 ] || { _cf P3.nuisance "row unit=$u ac=$a sp=$s cad=$c has zero full-window reads (vacuous check)"; continue; }
        det=$(( fosc * 100 / full ))
        if [ "$det" -gt "$best" ]; then best=$det; bestrow="unit=$u ac=$a sp=$s cad=$c"; fi
    done < "$rowfile"
    [ "$best" -ge 90 ] || _cf P3.nuisance "no cadence makes the detector fire on 90%+ of reads of a healthy aircraft (best ${best}% at $bestrow) — re-grade the rung; note this bound is a strong-form check, and P3 is only truly refuted by a stream that is quiet at EVERY cadence"

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
        _cf P3.tail "the amplitude dependence has left the false-all-clear column at cadence 134 (ac0 $t0q vs ac1 $t1q); round 11's retracted claim that it vanishes at long cadence would be right"
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
