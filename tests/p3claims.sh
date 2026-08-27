#!/usr/bin/env bash
# p3claims.sh -- P3's CLAIM assertions, as one shared implementation.
# IDs: P3.truth.alive, P3.rows, P3.blind74, P3.unitdep, P3.phase,
# P3.partition, P3.control, P3.monotone, P3.noise, P3.profile, P3.nuisance,
# P3.monoclass, P3.unitid, P3.truth.unit, P3.tail, P3.nfleet.
# (Round 37: this list declared 11 while the file emitted 16 -- the
# declared-list-drift shape the CI script count and test_lint's file count
# exist to catch. tests/test_swarm_p3_planted.sh now checks it.)
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

    # SITE-LEVEL enrollment. Round 43 tagged the ten witnesses behind one
    # claim ID; round 44 found the same hole live at 16 of the other 72
    # `_cf` sites -- eight of them the "(vacuous check)" population guards
    # this rung keeps adding, so the vacuity guards were themselves
    # vacuous. Gutting all 16 left the plant harness at PASS.
    #
    # An ID-level or line-COUNT assertion cannot see them: a site that
    # never fires contributes zero CLAIMFAIL lines to every plant. So the
    # firing SITE is recorded, and tests/test_swarm_p3_planted.sh takes a
    # set difference against every site in this file. The tags stay --
    # they name the witness in the failure text -- but enrollment no
    # longer depends on anyone remembering to add one.
    _cf() { echo "CLAIMFAIL $1: $2"; if [ -n "${P3_SITES:-}" ]; then echo "${BASH_LINENO[0]}" >> "$P3_SITES"; fi; failed=1; }
    # (The former `_num` helper is gone -- round 35 found it dead,
    # carrying an eight-line comment about a plant, reading as coverage.)

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
    # 3.52 ft/s, at sp=0.05 it is 4.52 and 8.80. ORACLE attached "4.5-8.8
    # ft/s" to all twelve cadence-74 rows; that is true of six of them.
    local nt=0 tv ta tsp
    while read -r ta tsp tv; do
        nt=$((nt+1))
        case "$ta/$tsp" in
            0/0.02) [ "$tv" -ge 120 ] || _cf P3.truth.alive "ac0 sp=0.02 phugoid has died (u_pp_last=$tv)" ;;
            1/0.02) [ "$tv" -ge 240 ] || _cf P3.truth.alive "ac1 sp=0.02 phugoid has died (u_pp_last=$tv)" ;;
            0/0.05) [ "$tv" -ge 300 ] || _cf P3.truth.alive "ac0 sp=0.05 phugoid has died (u_pp_last=$tv)" ;;
            1/0.05) [ "$tv" -ge 600 ] || _cf P3.truth.alive "ac1 sp=0.05 phugoid has died (u_pp_last=$tv)" ;;
            # NO SILENT DEFAULT (round 35): an unrecognised (aircraft,
            # dispersion) label was graded by NOTHING -- only the count
            # guarded it, so relabelling a row sp=0.05 -> sp=0.06 with every
            # figure zeroed was ACCEPTED, in the check that licenses every
            # rate in P3, in a file whose header says a missing field is a
            # FAIL and never a pass.
            *) _cf P3.truth.alive "unrecognised physics-truth row ac=$ta sp=$tsp — it is graded by nothing" ;;
        esac
    done < <(sed -n 's/^p3truth ac=\([0-9]*\) sp=\([0-9.]*\) .* u_pp_last=\([0-9-]*\).*/\1 \2 \3/p' "$out")
    [ "$nt" -eq 4 ] || _cf P3.truth.alive "$nt of 4 physics truth rows found (vacuous check)"

    # The OBSERVED channel is pitch rate, not airspeed. Round 16: every
    # verdict in this rung is a verdict on s[2], and the deadband
    # mechanism is stated in rad/s -- yet this check read only u_pp_last.
    # Zeroing q_pp_last on all four rows left the gate certifying "the
    # observer says settled about an aircraft that is swinging" while the
    # truth table said the observed channel had flat-lined. Units:
    # hundred-thousandths of a rad/s.
    #
    # (Round 37 deleted this block by accident, with an anchored slice
    # that ate adjacent code -- the fourth such incident in this rung. It
    # was caught only because plant c24 exists and stopped reddening. A
    # plant is what makes a silent deletion loud.)
    local nq=0 qv
    while read -r ta tsp qv; do
        nq=$((nq+1))
        case "$ta/$tsp" in
            0/0.02) [ "$qv" -ge 70 ]  || _cf P3.truth.alive "ac0 sp=0.02 observed channel has flat-lined (q_pp_last=$qv)" ;;
            1/0.02) [ "$qv" -ge 130 ] || _cf P3.truth.alive "ac1 sp=0.02 observed channel has flat-lined (q_pp_last=$qv)" ;;
            0/0.05) [ "$qv" -ge 170 ] || _cf P3.truth.alive "ac0 sp=0.05 observed channel has flat-lined (q_pp_last=$qv)" ;;
            1/0.05) [ "$qv" -ge 330 ] || _cf P3.truth.alive "ac1 sp=0.05 observed channel has flat-lined (q_pp_last=$qv)" ;;
            *) _cf P3.truth.alive "unrecognised observed-channel truth row ac=$ta sp=$tsp — it is graded by nothing" ;;
        esac
    done < <(sed -n 's/^p3truth ac=\([0-9]*\) sp=\([0-9.]*\) .* q_pp_last=\([0-9-]*\).*/\1 \2 \3/p' "$out")
    [ "$nq" -eq 4 ] || _cf P3.truth.alive "$nq of 4 observed-channel truth rows found (vacuous check)"

    # THE UNIT — derived from the driver, not grepped for a string.
    #
    # Round 36 caught this section stating m/s while the model is imperial
    # (3.28x on the central severity claim), inside the exit-gate item that
    # is ABOUT units. Round 37 then caught the FIX: it grepped ORACLE for
    # "N m/s", which is the absence of one string where the claim is "this
    # table is in ft/s". It passed on four re-introductions -- the unit
    # moved to a column header, a different wrong unit (kt, 1.69x), an
    # UNREADABLE ORACLE (grep returns 2, the `if` is false, nothing fires),
    # and the table transcribed 10x wrong while the driver still printed
    # the right numbers.
    #
    # So the rows are DERIVED from `p3truth` and required present in ORACLE
    # with `ft/s` adjacent. That is the shape `P2.banked` already used one
    # table over (round 22: "it guards the published number now"), never
    # applied to the table item 6 is about. ORACLE's path is a variable so
    # the claim can be planted; round 37 found it was the only claim ID in
    # the rung with no planted fault, and structurally unplantable because
    # `plant()` filters the driver's stdout while this reads two files.
    local ORC="${P3_ORACLE:-ORACLE.md}"
    if [ ! -r "$ORC" ]; then
        _cf P3.truth.unit "cannot read $ORC — the published truth table is unverifiable (vacuous check) <w:orc>"
    else
        local tac tsp tf tl tamp want_f want_l want_a nfound=0
        # BOTH dispersions. Round 39: the exact-row match was scoped to
        # sp=0.05, so the sp=0.02 pair -- the rows the radian/ac0/sp0.02
        # dead cell rests on, which is P3's sharpest claim -- were held
        # only by loose `>=` floors while ORACLE publishes them to three
        # digits ("1.81 and 3.52 ft/s").
        while read -r tac tsp tf tl tamp; do
            want_f=$(awk -v x="$tf" 'BEGIN{ printf "%.2f", x/100 }')
            want_l=$(awk -v x="$tl" 'BEGIN{ printf "%.2f", x/100 }')
            nfound=$((nfound+1))
            # THE WHOLE ROW, in order. Round 38: requiring each value to
            # appear ANYWHERE in ORACLE is a proxy -- swapping the two
            # columns (which asserts the phugoid GROWS, inverting
            # "decaying ~7-8% per cycle" and the whole severity claim)
            # passed, as would swapping the rows, as would deleting the
            # table while the values survive in a retraction paragraph.
            # The amp column is DERIVED too. Round 41: it was matched with
            # a wildcard while ORACLE claimed "every cell is matched
            # against the producer", and the amplitudes were hand copies
            # of a comment. `truth_row` prints it now.
            want_a=$(awk -v x="$tamp" 'BEGIN{ printf ".%04d", x }')
            grep -qE "^\| $tac \(amp $want_a\) \| $want_f ft/s \| \*\*$want_l ft/s\*\* \|" "$ORC" \
                || _cf P3.truth.unit "ORACLE's truth-table row for ac=$tac is not '| $tac (amp $want_a) | $want_f ft/s | **$want_l ft/s** |' — the table is hand-transcribed and no longer matches the producer, or its columns/rows/unit moved <w:row>"
            # ...and the mode must DECAY. A first-period swing no larger
            # than the final one is the inverse of what this rung claims,
            # and column order alone would not catch a producer that
            # started reporting them the other way round.
            awk -v f="$want_f" -v l="$want_l" 'BEGIN{ exit !(f > l) }' \
                || _cf P3.truth.unit "ac=$tac's first-period swing ($want_f) is not larger than its final-period swing ($want_l) — the phugoid is not decaying, and every 'still swinging' claim in P3 rests on that <w:decay>"
        done < <(sed -n 's/^p3truth ac=\([0-9]*\) sp=\([0-9.]*\) u_pp_first=\([0-9-]*\) u_pp_last=\([0-9-]*\).* amp=\([0-9]*\).*/\1 \2 \3 \4 \5/p' "$out")
        [ "$nfound" -eq 4 ] || _cf P3.truth.unit "$nfound of 4 truth rows available to check against ORACLE (vacuous check) <w:nrows>"
        grep -qE '[0-9](\.[0-9]+)? m/s' "$ORC" \
            && _cf P3.truth.unit "ORACLE states an airspeed in m/s — the model is imperial, so the figure is out by 3.28x <w:metric>"
    fi

    # The noise control's amplitude is claimed to BE the producer's
    # q_pp_first for ac0 at sp=0.05 -- the amplitude match that makes the
    # phugoid-vs-noise inversion a comparison at all. Round 40: it was a
    # hand transcription in the driver and nothing compared it to the row
    # printed on the same run.
    local amp_src qpf
    amp_src=$(grep -oP '^AMP is \K[0-9.]+' "${P3_PRODUCER:-tests/swarm_p3.eigs}" 2>/dev/null | head -1)
    qpf=$(sed -n 's/^p3truth ac=0 sp=0.05 .* q_pp_first=\([0-9-]*\).*/\1/p' "$out" | head -1)
    if [ -z "$amp_src" ] || [ -z "$qpf" ]; then
        _cf P3.truth.unit "cannot compare the noise amplitude to the producer's q_pp_first (vacuous check) <w:ampv>"
    else
        awk -v a="$amp_src" -v q="$qpf" 'BEGIN{ exit !( (a*100000 - q) < 1 && (q - a*100000) < 1 ) }' \
            || _cf P3.truth.unit "the noise control's amplitude $amp_src does not match ac0's measured q_pp_first ($qpf hundred-thousandths) — the phugoid-vs-noise comparison is no longer amplitude-matched <w:amp>"
    fi

    # The MODEL's imperial-ness, checked against the dataset rather than a
    # comment: a computed-vs-known-constant comparison, which is what makes
    # it a witness and not a restatement.
    # The dataset's path is a variable for the same reason ORACLE's is:
    # round 43 found this witness, and the m/s and amplitude ones beside
    # it, could be DELETED with all 42 plants still green. A witness with
    # no plant has never been shown to be able to fail.
    local u0 gg DAT="${P3_DATA:-data/b747_approach.eigs}"
    u0=$(grep -oP '"u0":\s*\K[0-9.]+' "$DAT" 2>/dev/null | head -1)
    gg=$(grep -oP '"g":\s*\K[0-9.]+' "$DAT" 2>/dev/null | head -1)
    if [ -z "$u0" ] || [ -z "$gg" ]; then
        _cf P3.truth.unit "cannot read u0/g from $DAT (vacuous check) <w:datav>"
    else
        awk -v g="$gg" 'BEGIN{ exit !(g > 32.0 && g < 32.3) }' \
            || _cf P3.truth.unit "g = $gg is not the imperial 32.174 ft/s^2 — every airspeed figure in ORACLE needs re-checking <w:g>"
        awk -v u="$u0" 'BEGIN{ exit !(u > 250 && u < 310) }' \
            || _cf P3.truth.unit "u0 = $u0 is not ~279 ft/s (Mach 0.25 at sea level) <w:u0>"
    fi

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
    # WHOLE GRID, not cadence 74. Round 16: round 15 grew the population
    # from 46 rows to 96 and did not re-scope a single claim to it, so 84
    # of 96 rows were invisible here -- and `fquiet`, the DANGEROUS
    # direction and the whole point of round 10's split, was read by only
    # two claims covering 14 rows. Moving every non-radian row's
    # `fnoclaim` bucket into `fquiet` at every cadence except 74 (634
    # reads, partition preserved) left the gate printing `nonrad_max=0%`
    # and certifying.
    #
    # The shipped data supports the stronger claim for free: 0 of the 64
    # deg/mrad rows carry a false all-clear at ANY of the 8 cadences,
    # while every radian cadence has at least three of four cells
    # carrying one. The finding is not "at cadence 74 the unit decides
    # which wrong answer you get" but "across the whole grid, the false
    # all-clear exists only in radians".
    local radmax=-1 degmax=-1 nrad=0 nnonrad=0 radcad="" ncadr nradfq cd ncell
    while read -r u a s c full fosc fq fnc fot; do
        # GUARDED, because this is the FIRST loop over the rows. Round 44
        # went to plant the zero-full guard further down (the P3.nuisance
        # one at the `det=` division) and found it unreachable: a row with
        # full=0 died here first, "division by 0", with zero CLAIMFAIL
        # lines and the whole claim library silent. A vacuity guard behind
        # an unguarded division is not a guard.
        [ "$full" -gt 0 ] || { _cf P3.unitdep "row unit=$u ac=$a sp=$s cad=$c has zero full-window reads (vacuous check)"; continue; }
        fac=$(( fq * 100 / full ))
        if [ "$u" = "rad" ]; then
            nrad=$((nrad+1)); [ "$fac" -gt "$radmax" ] && radmax=$fac
            [ "$fq" -gt 0 ] && radcad="$radcad $c"
        else
            nnonrad=$((nnonrad+1)); [ "$fac" -gt "$degmax" ] && degmax=$fac
            [ "$fq" -eq 0 ] || _cf P3.unitdep "a false all-clear appeared in unit=$u ac=$a sp=$s cad=$c ($fq of $full reads) — the deadband attribution is wrong"
        fi
    done < "$rowfile"
    # EXACT populations. A ">= 2" bound is the shape this file condemns
    # further up and P3.blind74 already fixed.
    if [ "$nrad" -ne 32 ] || [ "$nnonrad" -ne 64 ]; then
        _cf P3.unitdep "unit axis mis-populated (rad rows=$nrad expected 32, non-rad rows=$nnonrad expected 64)"
    else
        # BOTH ends, at the published values. Round 39 added the ceiling
        # and left the floor at 90 while ORACLE publishes the peak as
        # "98-99%" -- so a drift to 90% would contradict the figure and
        # pass, which is the one-sidedness that commit's own message
        # condemned, in the other direction.
        [ "$radmax" -ge 98 ] || _cf P3.unitdep "the radian false-all-clear peak is ${radmax}%, below the 98-99% ORACLE publishes"
        # ...and a CEILING, because ORACLE publishes the peak as a RANGE
        # ("98-99%"). Round 39: only the floor was asserted, so a drift to
        # 100% would contradict the published figure and pass. A range
        # claim needs both ends.
        [ "$radmax" -le 99 ] || _cf P3.unitdep "the radian false-all-clear peak is ${radmax}%, above the 98-99% ORACLE publishes"
        ncadr=$(printf '%s\n' $radcad | sort -u | grep -c .)
        [ "$ncadr" -eq 8 ] || _cf P3.unitdep "radian rows carry a false all-clear at only $ncadr of 8 cadences"
        # PER-ROW, like its non-radian twin. Round 17: the non-radian half
        # was made per-row and exact at round 16 while the radian half --
        # the one carrying the safety finding -- stayed a max-over-rows
        # plus one-cell-per-cadence. Erasing `fquiet` from 22 of the 32
        # radian rows (1045 of 1285 dangerous-direction reads, partition
        # preserved) left both bounds satisfied and the headline
        # `rad_falseallclear_max=98%` unchanged. Measured, 30 of 32 radian
        # rows carry a false all-clear -- 4 of 4 cells at six cadences and
        # 3 of 4 at cadences 104 and 114 -- so that is what is asserted.
        local nradfq
        nradfq=$(awk '$1=="rad" && $7>0' "$rowfile" | wc -l)
        [ "$nradfq" -ge 30 ] || _cf P3.unitdep "only $nradfq of 32 radian rows carry a false all-clear (expected at least 30); the dangerous direction has largely vanished"
        for cd in 74 84 94 104 114 124 134 148; do
            ncell=$(awk -v c="$cd" '$1=="rad" && $4==c && $7>0' "$rowfile" | wc -l)
            [ "$ncell" -ge 3 ] || _cf P3.unitdep "at cadence $cd only $ncell of 4 radian cells carry a false all-clear (expected at least 3)"
        done
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
    # aircraft swings 4.5-8.8 ft/s peak-to-peak. That is the claim.
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
    # Round 16 added the two vacuity guards this claim was missing -- the
    # same ones round 15 shipped for P3.phase in the very same commit and
    # did not apply here. Without them, deleting three of four cells at
    # seven cadences certified "the FOUR cells are identical" from ONE
    # cell, and four relabelled copies of a single cell certified it too.
    # It also compared `fosc` alone while claiming "byte-identical"; it
    # compares the whole full-window signature now.
    local ncad=0 nident=0 cd ncell npair nsig lo hi
    for cd in 74 84 94 104 114 124 134 148; do
        ncell=$(awk -v c="$cd" '$1=="deg" && $4==c' "$rowfile" | wc -l)
        [ "$ncell" -gt 0 ] || continue
        ncad=$((ncad+1))
        if [ "$ncell" -ne 4 ]; then
            _cf P3.unitid "cadence $cd has $ncell degree cells, expected 4 (vacuous check)"
            continue
        fi
        npair=$(awk -v c="$cd" '$1=="deg" && $4==c {print $2"/"$3}' "$rowfile" | sort -u | wc -l)
        if [ "$npair" -ne 4 ]; then
            _cf P3.unitid "cadence $cd's four degree cells are not four distinct aircraft/dispersion pairs"
            continue
        fi
        nsig=$(awk -v c="$cd" '$1=="deg" && $4==c {print $5,$6,$7,$8,$9}' "$rowfile" | sort -u | wc -l)
        [ "$nsig" -eq 1 ] && nident=$((nident+1))
        [ "$nsig" -le 2 ] || _cf P3.unitid "in degrees at cadence $cd the four cells give $nsig distinct full-window signatures; rescaling no longer collapses the amplitude axis"
        # ...and where they differ, they must differ by ONE read. The
        # signature count alone bounds how many kinds of row there are,
        # not how far apart they are: two signatures 40 reads apart would
        # pass it. Both are asserted.
        lo=$(awk -v c="$cd" '$1=="deg" && $4==c {print $6}' "$rowfile" | sort -n | head -1)
        hi=$(awk -v c="$cd" '$1=="deg" && $4==c {print $6}' "$rowfile" | sort -n | tail -1)
        [ "$(( hi - lo ))" -le 1 ] || _cf P3.unitid "in degrees at cadence $cd the four cells span $(( hi - lo )) detections; the collapse is more than a single-read deadband crossing"
    done
    if [ "$ncad" -lt 8 ]; then
        _cf P3.unitid "only $ncad of 8 cadences have degree rows (vacuous check)"
    elif [ "$nident" -lt 6 ]; then
        _cf P3.unitid "the four degree cells are identical at only $nident of 8 cadences (expected at least 6)"
    fi

    # --- the MONOTONE CONTROL. Round 17: the equilibrium control below is
    # DEGENERATE -- trim pitch rate is exactly 0, so its channel spans
    # 3.3e-17 rad/s (fourteen orders inside dh_zero) and its three "units"
    # are one measurement, since 0.0 x 57.3 == 0.0 x 1000. It excludes an
    # alarm that fires on a FROZEN channel, which was not the hypothesis.
    #
    # The hypothesis is "the observer fires whenever its window exceeds
    # one period". Excluding it needs a channel that MOVES without
    # oscillating, at the phugoid's own magnitude. These do.
    # The monotone arms are an IMPLEMENTATION statement, not evidence
    # about the fleet. Round 18: every arm of `obs_num_oscillating`
    # upstream requires step-sign flips or direction reversals, and a
    # strictly monotone channel has none at any amplitude, tau, cadence or
    # unit -- swept over 1176 cells the answer is 0 everywhere. An outcome
    # invariant to every knob has no discriminating power, so this cannot
    # support "the detector is a detector"; round 17 published it as
    # exactly that. It is kept only to pin that the predicate does not
    # fire on drift, and the claim is named for what it is.
    local nmono=0 nnoise=0 mk mu mc mfull mfosc
    while read -r mk mu mc mfull mfosc; do
        # The >= 40 bound below is not a division guard: it reports and
        # falls through, and the `mfosc * 100 / mfull` divisions further
        # down then die on a zero. Round 44 found the identical shape at
        # the P3.nuisance guard; this is the second instance, and it is
        # why the P3.profile zero-full guard was unreachable.
        [ "$mfull" -gt 0 ] || { _cf P3.monotone "control cell $mk/$mu/cad$mc has zero full-window reads (vacuous check)"; continue; }
        [ "$mfull" -ge 40 ] || _cf P3.monotone "control cell $mk/$mu/cad$mc has only $mfull full-window reads (vacuous check)"
        if [ "$mk" = "noise" ]; then
            nnoise=$((nnoise+1))
            # THE DISCRIMINATING CLAIM. A stationary aperiodic channel at
            # the phugoid's own peak-to-peak amplitude has NO mode and NO
            # period -- and the observer reports `oscillating` on
            # essentially every read of it, at the same cell where the
            # fleet reads 100%. So a positive detection is not evidence of
            # a mode. This is what refutes round 17's conclusion, and it
            # is the only control in three rounds that could have.
            [ "$(( mfosc * 100 / mfull ))" -ge 90 ] || _cf P3.noise "the observer no longer fires on structureless noise ($mfosc of $mfull, $mu, cadence $mc); detection may now carry mode information and P3's nuisance finding needs re-grading"
            # THE CONTRAST, at the cadence where it is total. Round 19:
            # the control had run at cadences 94 and 104 only -- the two
            # cells where the phugoid ALSO reads ~100%, i.e. the only ones
            # where the contrast is invisible -- and the retraction built
            # on it ("cannot distinguish a phugoid from noise") was stated
            # over the whole grid. At cadence 74 the fleet is 0 of 99 and
            # the noise channel is ~98 of 98, in every unit. The streams
            # separate completely there, and in the INVERSE direction: the
            # observer detects the channel with no mode and misses the one
            # with a mode.
            if [ "$mc" = "74" ]; then
                local fleet74
                fleet74=$(awk -v u="$mu" '$1==u && $4=="74" {t+=$6} END{print t+0}' "$rowfile")
                [ "$fleet74" -eq 0 ] || _cf P3.noise "the fleet is no longer blind at cadence 74 in $mu ($fleet74 detections); the phugoid-vs-noise inversion this rung reports has changed"
                [ "$(( mfosc * 100 / mfull ))" -ge 90 ] || _cf P3.noise "noise no longer saturates at cadence 74 in $mu ($mfosc of $mfull); the inversion is gone"
            fi
        else
            nmono=$((nmono+1))
            [ "$mfosc" -eq 0 ] || _cf P3.monotone "the observer reports oscillating $mfosc times on a MONOTONE channel ($mk, $mu, cadence $mc)"
        fi
    done < <(sed -n 's/^p3mono kind=\([a-z_]*\) unit=\([a-z]*\) cad=\([0-9]*\) full=\([0-9]*\) fosc=\([0-9]*\).*/\1 \2 \3 \4 \5/p' "$out")
    [ "$nmono" -eq 18 ] || _cf P3.monotone "$nmono of 18 monotone-control cells found (vacuous check)"
    [ "$nnoise" -eq 24 ] || _cf P3.noise "$nnoise of 24 noise-control cells found (vacuous check)"
    # THE DISCRIMINATING STRUCTURE. A single verdict at a single cadence
    # carries no mode information -- at cadence 104 the phugoid and the
    # noise channel are both at 100%. But their PROFILES over cadence are
    # completely separable, because the phugoid has a period and the noise
    # does not: the fleet swings 0% -> 100% -> 76% across the eight
    # cadences while the noise channel stays pinned near 100% at all of
    # them. Round 19: the round-18 retraction ("cannot distinguish a
    # phugoid from noise") was measured at two cadences, both of which sit
    # where the two agree, and stated over the whole grid.
    # ALL TWELVE fleet cells, not one. Round 20: this hardcoded
    # `unit=deg ac=0 sp=0.05` -- the MAXIMUM-spread cell of the twelve --
    # and the mechanism stated from it is false in the shipped unit.
    #
    # In radians, aircraft 0 at dispersion 0.02 detects 0% at ALL EIGHT
    # cadences while carrying 98-99% false all-clear. That is a channel
    # WITH a period which is perfectly cadence-invariant, so
    # cadence-invariance is NOT the signature of periodlessness. Flatness
    # is what the absolute deadband produces once it swallows the channel:
    # below it, every cadence reads the same because nothing reads at all.
    #
    # The corrected claim: the profile separates a mode from noise only in
    # the cells whose channel CLEARS the deadband. Eleven of twelve do,
    # with spread >= 75; the twelfth is flat-zero and must be flat for the
    # deadband reason, which is checkable -- it has to be simultaneously
    # dead (0 detections) and confidently wrong (>= 95% false all-clear)
    # at every cadence. A cell that went flat for any other reason would
    # fail that pair.
    local nlo=999 nhi=-1 pc
    while read -r mk mu mc mfull mfosc; do
        [ "$mk" = "noise" ] && [ "$mu" = "deg" ] || continue
        [ "$mfull" -gt 0 ] || { _cf P3.profile "noise row $mu cad=$mc has zero full-window reads (vacuous check)"; continue; }
        pc=$(( mfosc * 100 / mfull ))
        [ "$pc" -lt "$nlo" ] && nlo=$pc
        [ "$pc" -gt "$nhi" ] && nhi=$pc
    done < <(sed -n 's/^p3mono kind=\([a-z_]*\) unit=\([a-z]*\) cad=\([0-9]*\) full=\([0-9]*\) fosc=\([0-9]*\).*/\1 \2 \3 \4 \5/p' "$out")
    if [ "$nhi" -lt 0 ]; then
        _cf P3.profile "noise-control rows absent (vacuous check)"
    else
        [ "$(( nhi - nlo ))" -le 5 ] || _cf P3.profile "the noise channel's detection is no longer cadence-invariant (spread $(( nhi - nlo )) points across 8 cadences)"
    fi
    local cu ca csp nshaped=0 nflat=0 clo chi cspread cdead cwrong
    for cu in rad deg mrad; do
        for ca in 0 1; do
            for csp in 0.02 0.05; do
                clo=$(awk -v u="$cu" -v a="$ca" -v s="$csp" '$1==u && $2==a && $3==s {printf "%d\n", $6*100/$5}' "$rowfile" | sort -n | head -1)
                chi=$(awk -v u="$cu" -v a="$ca" -v s="$csp" '$1==u && $2==a && $3==s {printf "%d\n", $6*100/$5}' "$rowfile" | sort -n | tail -1)
                [ -n "$clo" ] && [ -n "$chi" ] || { _cf P3.profile "fleet cell $cu/$ca/$csp absent (vacuous check)"; continue; }
                cspread=$(( chi - clo ))
                if [ "$cspread" -ge 75 ]; then
                    nshaped=$((nshaped+1))
                else
                    nflat=$((nflat+1))
                    # A flat cell must be flat because the deadband killed
                    # it: dead AND confidently wrong at every cadence.
                    cdead=$(awk -v u="$cu" -v a="$ca" -v s="$csp" '$1==u && $2==a && $3==s && $6==0' "$rowfile" | wc -l)
                    cwrong=$(awk -v u="$cu" -v a="$ca" -v s="$csp" '$1==u && $2==a && $3==s && $7*100/$5 >= 95' "$rowfile" | wc -l)
                    { [ "$cdead" -eq 8 ] && [ "$cwrong" -eq 8 ]; } || _cf P3.profile "fleet cell $cu/$ca/$csp has a flat detection profile (spread $cspread) but is not deadband-killed ($cdead of 8 cadences dead, $cwrong of 8 at >=95% false all-clear); the flatness has another cause"
                fi
            done
        done
    done
    [ "$nshaped" -ge 11 ] || _cf P3.profile "only $nshaped of 12 fleet cells have a cadence-shaped detection profile (expected at least 11); the structure that distinguishes a mode from noise has flattened"
    [ "$nflat" -le 1 ] || _cf P3.profile "$nflat fleet cells are flat (expected at most the one deadband-killed cell)"

    # --- the SHARPEST unit-dependence evidence in the rung, found while
    # building the monotone control (round 17).
    #
    # ONE identical monotone decay -- same trajectory, same cadence, same
    # window -- is classified into THREE DIFFERENT verdict classes by the
    # three units: `converged` in radians, `stable` in degrees, `moving`
    # in milliradians. That is a cleaner demonstration than the
    # deg-equals-mrad byte-identity the unit claim had been resting on,
    # because here the units DISAGREE rather than agree, on a channel with
    # no oscillation to argue about.
    #
    # The contrast is pinned too: a monotone RAMP reads `diverging` in all
    # three units. So the unit does not decide everything -- a signal that
    # is growing is detected at any scale, and it is specifically the
    # SMALL-magnitude end of the lattice that the absolute deadband
    # distorts (EigenScript#1045).
    # EXACT, not a range. Round 18: this used `conv=(6[5-9]|7[0-9]|8[0-9])`
    # -- a floor of 85% chosen from nothing, half of whose range is
    # unreachable -- while its sibling P3.unitdep in this same file is
    # exact per row. With the control's seed artifact removed the split is
    # total: the dominant class equals the full-window count exactly.
    local mdom mfull mcls mv2 cd2 mlbl
    for cd2 in 94 104; do
        for mu in rad deg mrad; do
            mdom=$(sed -n "s/^p3mono kind=decay_slow unit=$mu cad=$cd2 .*/&/p" "$out")
            [ -n "$mdom" ] || { _cf P3.monoclass "decay_slow/$mu/cad$cd2 row absent (vacuous check)"; continue; }
            mfull=$(echo "$mdom" | grep -oP 'full=\K[0-9]+')
            case "$mu" in
                rad)  mcls=conv;   mlbl=converged ;;
                deg)  mcls=stable; mlbl=stable ;;
                mrad) mcls=moving; mlbl=moving ;;
            esac
            mv2=$(echo "$mdom" | grep -oP "$mcls=\K[0-9]+")
            [ "$mv2" = "$mfull" ] || _cf P3.monoclass "in $mu a monotone decay no longer reads '$mlbl' on every read ($mv2 of $mfull)"
        done
    done
    local nramp
    nramp=$(sed -n 's/^p3mono kind=ramp unit=[a-z]* cad=[0-9]* .* diverging=\([0-9]*\).*/\1/p' "$out" | awk '$1>=60' | wc -l)
    [ "$nramp" -eq 6 ] || _cf P3.monoclass "a monotone RAMP reads diverging in only $nramp of 6 unit/cadence cells; the unit-invariance of the growing case is gone"

    # --- the NEGATIVE CONTROL. A trimmed aircraft has no phugoid, so
    # `oscillating` must never fire on it -- above all at cadence 104 in
    # degrees, the cell where the live fleet detects on 100% of reads.
    # Round 16: without this, "the observer detects the mode" and "the
    # observer fires whenever its window exceeds one period" are the same
    # measurement, and the 100% cell cannot be told from a stuck alarm.
    local nnc=0 cu cc cfull cfosc
    while read -r cu cc cfull cfosc; do
        nnc=$((nnc+1))
        [ "$cfull" -ge 40 ] || _cf P3.control "control cell unit=$cu cad=$cc has only $cfull full-window reads (vacuous check)"
        [ "$cfosc" -eq 0 ] || _cf P3.control "the observer reports oscillating $cfosc times on an EQUILIBRIUM aircraft (unit=$cu cad=$cc); detection is not evidence of a mode"
    done < <(sed -n 's/^p3nc unit=\([a-z]*\) cad=\([0-9]*\) full=\([0-9]*\) fosc=\([0-9]*\).*/\1 \2 \3 \4/p' "$out")
    [ "$nnc" -eq 6 ] || _cf P3.control "$nnc of 6 negative-control cells found (vacuous check)"

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
        # ORACLE publishes this as "exactly 0.789 from N=2 to N=16", not
        # as "non-decreasing". Round 39: only the weaker property was
        # asserted, so 0.55/0.60/0.65/0.70 would pass while the write-up
        # claimed a constant. Constancy is the claim, so constancy is what
        # is checked.
        if [ "${np[0]}" != "${np[1]}" ] || [ "${np[1]}" != "${np[2]}" ] || [ "${np[2]}" != "${np[3]}" ]; then
            _cf P3.nfleet "the fleet alert rate is not CONSTANT across N (${np[*]} permille); ORACLE publishes it as exactly one value"
        fi
        grep -qF -- "0.$(printf '%03d' "${np[0]}") from N=2 to N=16" "${P3_ORACLE:-ORACLE.md}" \
            || _cf P3.nfleet "ORACLE does not publish the measured fleet rate 0.$(printf '%03d' "${np[0]}") — the constant it states is hand-transcribed and has drifted"
    fi

    rm -f "$rowfile"
    if [ "$failed" -eq 0 ]; then
        echo "P3CLAIMS OK rows=$nrows best_detect=${best}% (at $bestrow) rad_falseallclear_max=${radmax}% nonrad_max=${degmax}% (whole grid) fleet=${np[*]:-?}"
        return 0
    fi
    return 1
}
