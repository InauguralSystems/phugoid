#!/usr/bin/env bash
# p3claims.sh -- the four CLAIM assertions behind P3, as one shared
# implementation.
#
# Why this is a library and not inline in test_swarm.sh: round 8 wrote two
# claim assertions inline and placed them AFTER the exact-row pins, which
# exit 1 on any mismatch. The assertions were therefore unreachable --
# they could only evaluate in the world where every pinned row already
# matched, which is the world where they have nothing to say. Nothing
# caught that, because a gate with no planted fault has never been shown
# to be able to fail. These now run against planted output in
# test_swarm_p3_planted.sh, which is what makes the reachability claim
# checkable rather than asserted.
#
# Every claim reports independently (no early exit) so a planted fault can
# assert an EXACT red set rather than "something failed".
#
# Vacuity: a missing field is a FAIL, never a pass. Round 1 of this rung
# found declared plants that could not fail; the same shape at the field
# level is a claim that silently examined nothing.

p3_claims() {
    local out="$1"
    local failed=0
    local v

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
    # the end of the run. If it is not, "the observer contradicts the
    # aircraft" is meaningless and every divergence count below is void.
    # This is the row rung 4 lacked for eight rounds: five successive
    # write-ups graded the verdict columns against nothing and inverted
    # the classification each time.
    local ul0 ul1
    ul0=$(_num '^p3truth ac=0 sp=0.05 .* u_pp_last=\K[0-9-]+')
    ul1=$(_num '^p3truth ac=1 sp=0.05 .* u_pp_last=\K[0-9-]+')
    if [ -z "$ul0" ] || [ -z "$ul1" ]; then
        _cf P3.truth.alive "physics truth row absent from driver output (vacuous check)"
    elif [ "$ul0" -lt 300 ] || [ "$ul1" -lt 600 ]; then
        _cf P3.truth.alive "the phugoid is no longer swinging in the final period (u_pp_last ac0=$ul0 ac1=$ul1 hundredths m/s); P3's truth table has changed"
    fi

    # --- claim 2: no clean verdict row exists anywhere in the sweep.
    # P3's registered refutation condition is "a clean verdict stream".
    # Truth is `oscillating` at every read, so div = reads - osc.
    local worst=1000 spec rd dv pct
    for spec in "ac=0 sp=0.05 cad=74" "ac=1 sp=0.05 cad=74" \
                "ac=0 sp=0.05 cad=94" "ac=1 sp=0.05 cad=94" \
                "ac=0 sp=0.05 cad=148" "ac=1 sp=0.05 cad=148"; do
        rd=$(grep -oP "^p3 $spec reads=\K[0-9]+" "$out" 2>/dev/null | head -1)
        dv=$(grep -oP "^p3 $spec .* div=\K[0-9]+" "$out" 2>/dev/null | head -1)
        if [ -z "$rd" ] || [ -z "$dv" ] || [ "$rd" -eq 0 ]; then
            _cf P3.noclean "row '$spec' absent or empty (vacuous check)"
            worst=-1
            break
        fi
        pct=$(( dv * 100 / rd ))
        [ "$pct" -lt "$worst" ] && worst=$pct
    done
    if [ "$worst" -ge 0 ] && [ "$worst" -lt 20 ]; then
        _cf P3.noclean "a clean verdict row has appeared (best cell diverges on only ${worst}% of reads); P3 is REFUTED, re-grade the rung"
    fi

    # --- claim 3: cadence 74 is the BLIND regime. The observer must be
    # contradicting the physics on essentially every read there. Round 8
    # asserted the opposite -- that `oscillating` stays <= 2 -- and read
    # that as the AIRCRAFT being quiescent. It is true of the verdict
    # stream and false about the aircraft, which is still swinging
    # 4.5-8.8 m/s peak-to-peak at that point.
    local ac
    for ac in 0 1; do
        rd=$(grep -oP "^p3 ac=$ac sp=0.05 cad=74 reads=\K[0-9]+" "$out" 2>/dev/null | head -1)
        dv=$(grep -oP "^p3 ac=$ac sp=0.05 cad=74 .* div=\K[0-9]+" "$out" 2>/dev/null | head -1)
        if [ -z "$rd" ] || [ -z "$dv" ] || [ "$rd" -eq 0 ]; then
            _cf P3.blind74 "row ac=$ac cad=74 absent or empty (vacuous check)"
        elif [ "$(( dv * 100 / rd ))" -lt 95 ]; then
            _cf P3.blind74 "cadence 74 is no longer the blind regime for ac=$ac ($dv/$rd divergences)"
        fi
    done

    # --- claim 4: the fleet alert rate does not FALL with N. This is the
    # half of P3 that had NO measurement at all until round 9 -- p3_row
    # hardcodes a fleet of 4 -- and was reported CONFIRMED regardless.
    # Asserted as non-decreasing, not as the constant it currently is,
    # because the registered prediction is "does not fall with N".
    local np=() n
    for n in 2 4 8 16; do
        v=$(grep -oP "^p3n n=$n .* fleet_permille=\K[0-9]+" "$out" 2>/dev/null | head -1)
        [ -n "$v" ] && np+=("$v")
    done
    if [ "${#np[@]}" -ne 4 ]; then
        _cf P3.nfleet "N sweep produced ${#np[@]} of 4 rows (vacuous check)"
    else
        if [ "${np[0]}" -lt 500 ]; then
            _cf P3.nfleet "the detector no longer fires on a healthy fleet at N=2 (${np[0]} permille)"
        fi
        if [ "${np[1]}" -lt "${np[0]}" ] || [ "${np[2]}" -lt "${np[1]}" ] || [ "${np[3]}" -lt "${np[2]}" ]; then
            _cf P3.nfleet "the fleet alert rate FALLS with N (${np[*]} permille); P3's N-invariance claim is refuted"
        fi
    fi

    if [ "$failed" -eq 0 ]; then
        echo "P3CLAIMS OK worst_clean=${worst}% fleet_permille=${np[*]:-?}"
        return 0
    fi
    return 1
}
