# manifestlib.sh — the manifest-enforcement arms, shared by all four
# planted suites.
#
# Round 25 found rungs 0, 1 and 2 carrying near-identical copies of these
# arms with ZERO executed plants — 17 arms that could all be gutted with
# their suites green. Round 24 had fixed rung 3 only.
#
# Four copies of a check is itself the defect class this repo keeps
# finding, so this is one implementation with one set of plants, not four
# more copies. Each arm is a function returning nonzero on a defect, so a
# plant can build a dirty input and require failure — and `mf_validate`
# below runs those plants against the REAL functions every time, which is
# the transversality test: delete an arm and its plant must red. A plant
# that re-implements its arm is the same point drawn twice and detects
# nothing (rounds 23, 24).

# mf_identity <manifest> <kind> <names-file> <workdir>
#   the manifest's <kind> rows must name exactly the shipped checks, with
#   their per-site tolerance tokens (rung-0 round 11: a 100x-widened
#   decimals argument was invisible to a name-only manifest).
mf_identity() {
    grep "^$2 " "$1" | awk '{print $2, $4}' | sort > "$4/_mfi"
    diff -u "$4/_mfi" "$3" > /dev/null
}

# mf_rowparams <manifest> <rows-file> <workdir>
#   emitted generator parameters must match the manifest (rung-0 round 20:
#   a corner row's parameters swapped wholesale under an intact name).
mf_rowparams() {
    grep '^rowparams ' "$1" | awk '{print $2, $3}' | sort > "$3/_mfr"
    diff -u "$3/_mfr" "$2" > /dev/null
}

# mf_coverage <manifest> <kind> <red-union>
#   every check declared plantable must have gone red under some plant.
mf_coverage() {
    local kind name klass tolspec
    while read -r kind name klass tolspec; do
        [ "$kind" = "$2" ] || continue
        [ "$klass" = plantable ] || continue
        grep -qx "$name" "$3" || return 1
    done < <(grep -v '^#' "$1")
    return 0
}

# mf_structural <manifest> <kind> <red-union>
#   no check declared structural may go red — a stale exemption is a
#   coverage hole wearing a label.
mf_structural() {
    local kind name klass tolspec
    while read -r kind name klass tolspec; do
        [ "$kind" = "$2" ] || continue
        [ "$klass" = structural ] || continue
        grep -qx "$name" "$3" && return 1
    done < <(grep -v '^#' "$1")
    return 0
}

# mf_class <manifest> <check-kinds-csv> <non-check-kinds-csv> <allowed-classes...>
#   the class column is the one column the identity arms do not cover, so
#   an unknown token silently exempts a check from coverage (rung-1 round
#   8: `plantable` -> `plantablee` passed the whole matrix). Round 25:
#   rung 0's copy `continue`d on any kind but modes/measure, so its
#   comparator rows never reached this arm at all.
#   Rows whose KIND is a declared non-check kind (rowparams, selftest) are
#   skipped because a different arm consumes them — but that exemption is
#   declared here and any OTHER unexpected kind is a failure, so a new kind
#   cannot escape the way `comparator` did.
mf_class() {
    local mf="$1" checkkinds=",$2," noncheck=",$3," ; shift 3
    local kind name klass tolspec ok a
    while read -r kind name klass tolspec; do
        [ -n "$kind" ] || continue
        case "$noncheck" in *",$kind,"*) continue;; esac
        # An unexpected KIND is a failure, not a skip. Round 25: rung 0's
        # copy skipped every kind but two, so its comparator rows never
        # reached the class check at all.
        case "$checkkinds" in *",$kind,"*) ;; *) return 1;; esac
        [ -n "$klass" ] || return 1
        ok=0
        for a in "$@"; do [ "$klass" = "$a" ] && ok=1; done
        [ "$ok" = 1 ] || return 1
    done < <(grep -v '^#' "$mf")
    return 0
}

# mf_validate <manifest> <kind> <names-file> <rows-file> <red-union> <workdir> <check-kinds-csv> <non-check-kinds-csv> <allowed-classes...>
#   Plants one in-class fault per arm, each calling the REAL arm on a
#   dirty input, each guarded against applying vacuously. Run every time.
mf_validate() {
    local mf="$1" kind="$2" names="$3" rows="$4" redu="$5" wd="$6" CHECKKINDS="$7" NONCHECK="$8"; shift 8
    local T; T=$(mktemp -d)
    # (a) identity: a manifest row naming no shipped check
    sed "1a $kind mf.notarealcheck plantable exact=0" "$mf" > "$T/m1"
    cmp -s "$mf" "$T/m1" && { rm -rf "$T"; echo "FAIL: mf identity plant did not apply"; return 1; }
    mf_identity "$T/m1" "$kind" "$names" "$wd" && { rm -rf "$T"; echo "FAIL: mf_identity ACCEPTED a row naming no shipped check"; return 1; }
    # (b) rowparams: drifted generator parameters
    if [ -s "$rows" ]; then
        sed 's/^rowparams \([^ ]*\) params=/rowparams \1 params=999|/' "$mf" > "$T/m2"
        cmp -s "$mf" "$T/m2" && { rm -rf "$T"; echo "FAIL: mf rowparams plant did not apply"; return 1; }
        mf_rowparams "$T/m2" "$rows" "$wd" && { rm -rf "$T"; echo "FAIL: mf_rowparams ACCEPTED drifted generator parameters"; return 1; }
    fi
    # (c) coverage: a structural row relabelled plantable that no plant reds
    local SNAME
    SNAME=$(grep -v '^#' "$mf" | awk -v k="$kind" '$1==k && $3=="structural" {print $2; exit}')
    if [ -n "$SNAME" ]; then
        sed "s/^$kind $SNAME structural /$kind $SNAME plantable /" "$mf" > "$T/m3"
        cmp -s "$mf" "$T/m3" && { rm -rf "$T"; echo "FAIL: mf coverage plant did not apply"; return 1; }
        mf_coverage "$T/m3" "$kind" "$redu" && { rm -rf "$T"; echo "FAIL: mf_coverage ACCEPTED a plantable no plant reds"; return 1; }
    fi
    # (d) structural: a plantable row that DOES red, relabelled structural
    local PNAME
    PNAME=$(grep -v '^#' "$mf" | awk -v k="$kind" '$1==k && $3=="plantable" {print $2}' | while read -r n; do grep -qx "$n" "$redu" && { echo "$n"; break; }; done)
    if [ -n "$PNAME" ]; then
        sed "s/^$kind $PNAME plantable /$kind $PNAME structural /" "$mf" > "$T/m4"
        cmp -s "$mf" "$T/m4" && { rm -rf "$T"; echo "FAIL: mf structural plant did not apply"; return 1; }
        mf_structural "$T/m4" "$kind" "$redu" && { rm -rf "$T"; echo "FAIL: mf_structural ACCEPTED a structural row that plants do red"; return 1; }
    fi
    # (e) class vocabulary: an unknown token
    sed "0,/^$kind /s/^\($kind [^ ]*\) \(plantable\|structural\) /\1 mystery /" "$mf" > "$T/m5"
    cmp -s "$mf" "$T/m5" && { rm -rf "$T"; echo "FAIL: mf class plant did not apply"; return 1; }
    mf_class "$T/m5" "$CHECKKINDS" "$NONCHECK" "$@" && { rm -rf "$T"; echo "FAIL: mf_class ACCEPTED an unknown manifest class"; return 1; }
    # ...and an unexpected KIND must not escape either (round 25: rung 0's
    # comparator rows never reached the class arm at all).
    sed "1a mysterykind mf.row plantable exact=0" "$mf" > "$T/m6"
    mf_class "$T/m6" "$CHECKKINDS" "$NONCHECK" "$@" && { rm -rf "$T"; echo "FAIL: mf_class ACCEPTED an unknown manifest KIND"; return 1; }
    rm -rf "$T"
    return 0
}
