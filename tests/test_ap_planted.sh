#!/usr/bin/env bash
# The rung-3 planted-fault matrix (ORACLE.md): each s-plant must flip
# EXACTLY its declared red set, every plant run executes the full pinned
# 217-check population, and the manifest rules hold (identity incl.
# tolerance tokens and ROW parameters; every plantable name in some red
# set; structural names in none; unknown class tokens FAIL).
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$(mktemp)"; WORK="$(mktemp -d)"; trap 'rm -f "$OUT"; rm -rf "$WORK"' EXIT

run_plant() {
    if "$EIGS" tests/ap_check.eigs "$1" > "$OUT" 2>&1; then
        echo "FAIL: plant $1 did not make ap_check exit nonzero — the checker cannot fail"; exit 1
    fi
    grep '^FAIL ' "$OUT" | awk '{print $2}' >> "$WORK/red_union" || true
    grep -q '^CHECKS_RUN 217$' "$OUT" || { echo "FAIL: plant $1 run population != 217"; exit 1; }
}
expect_total_fails() {
    got=$(grep -c '^FAIL ' "$OUT" || true)
    [ "$got" -eq "$1" ] || { echo "FAIL: expected exactly $1 FAIL lines, got $got"; grep '^FAIL ' "$OUT"; exit 1; }
    echo "    reds: $got"
}
expect_red() { for pat in "$@"; do grep -Eq "^FAIL $pat" "$OUT" || { echo "FAIL: expected red '$pat' did not flip"; grep '^FAIL ' "$OUT" || true; exit 1; }; done; }
expect_green() { for pat in "$@"; do if grep '^FAIL ' "$OUT" | grep -Eq "$pat"; then echo "FAIL: '$pat' flipped but should stay green"; grep '^FAIL ' "$OUT"; exit 1; fi; done; }
no_refusals() { grep '^FAIL ' "$OUT" | grep -q 'refused' && { echo "FAIL: $1 reds must use the numeric arm, found a refusal"; exit 1; }; return 0; }

echo "--- S1: gain sign flipped -> pitch rows + every zeta + the gain witnesses ---"
run_plant s1; expect_total_fails 73
expect_red 'C0\.a23 ' 'C0\.a33 ' 'C2\.k050\.T ' 'C2\.k100\.zlog ' 'C3\.gain\.use ' 'C2\.ph\.Tdft\.k ' 'C3\.amp\.zenv ' 'C5\.p4\.a035\.horizon '
expect_green 'C1\.'
echo "PASS: S1 red pattern exact"

echo "--- S2: gain never reaches the dynamics (inert controller) ---"
run_plant s2; expect_total_fails 71
expect_red 'C3\.gain\.use ' 'C3\.lin\.shrinks ' 'C2\.k100\.T ' 'C2\.ph\.T ' 'C3\.amp\.zenv '
expect_green 'C1\.'
echo "PASS: S2 red pattern exact"

echo "--- S3: integrator RK4 -> Euler -> periods + dt invariance + supervisory toggles ---"
run_plant s3; expect_total_fails 60
expect_red 'C2\.k025\.T ' 'C2\.k050\.T ' 'C2\.k100\.T ' 'C3\.dt\.T ' 'C3\.dt\.zlog ' 'C3\.dt\.zenv ' 'C2\.ph\.zlog ' 'C5\.p4\.a030\.osc ' 'C5\.p4\.a035\.horizon '
expect_green 'C0\.' 'C1\.'
echo "PASS: S3 red pattern exact"

echo "--- S4: trim offset -> C1 + parity + every graded mode ---"
run_plant s4; expect_total_fails 133
expect_red 'C1\.res\.' 'C1\.hold\.' 'C0\.a13 ' 'C2\.k025\.T ' 'C3\.gain\.use ' 'C5\.sp\.c050\.osc '
echo "PASS: S4 red pattern exact"

echo "--- S5: linearity witness made vacuous (rerun at the base amplitude) -> exactly 1 ---"
run_plant s5; expect_total_fails 1
expect_red 'C3\.lin\.shrinks '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C4\.' 'C5\.'
echo "PASS: S5 red pattern exact"

echo "--- S6: grading dt dilated x1.02 -> the period rows + the dt-invariance rows ---"
run_plant s6; expect_total_fails 6
expect_red 'C2\.k025\.T ' 'C2\.k050\.T ' 'C2\.k100\.T ' 'C3\.lin\.shrinks ' 'C2\.ph\.T ' 'C2\.ph\.Tdft '
expect_green 'C0\.' 'C1\.' 'C2\.k025\.zlog' 'C4\.' 'C5\.sp'
echo "PASS: S6 red pattern exact"

echo "--- S7: verdict stream frozen to 'stable' (supervisory inert) ---"
run_plant s7; expect_total_fails 132
expect_red 'C5\.sp\.c050\.osc ' 'C5\.sp\.c100\.osc ' 'C4\.ph\.osc ' 'C4\.ph\.horizon ' 'C5\.p2\.sup\.toggles ' 'C5\.p4\.a030\.osc ' 'C5\.p4\.a030\.horizon ' 'C5\.p4\.a035\.horizon ' 'C5\.p1\.inner\.runs ' 'C5\.p1\.inner\.maxrun ' 'C4\.ph\.runs ' 'C4\.ph\.onset ' 'C4\.ph\.moving '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C3\.'
echo "PASS: S7 red pattern exact"

echo "--- S8: zeta->0.05 and T->5.0 with identity carried -> the numeric rows ---"
run_plant s8; expect_total_fails 13
expect_red 'C2\.k025\.T ' 'C2\.k100\.zenv ' 'C3\.gain\.use ' 'C3\.lin\.shrinks ' 'C2\.ph\.T ' 'C2\.ph\.zlog '
no_refusals S8
expect_green 'C0\.' 'C1\.' '\.n ' '\.nr ' '\.nf ' 'C4\.' 'C5\.'
echo "PASS: S8 red pattern exact"

echo "--- S9: dataset broadly poisoned -> parity + graded modes + verdicts ---"
run_plant s9; expect_total_fails 110
expect_red 'C0\.a11 ' 'C0\.a33 ' 'C2\.k050\.zlog ' 'C3\.gain\.use ' 'C4\.ph\.osc ' 'C2\.ph\.Tdft ' 'C5\.p4\.a030\.osc '
expect_green 'C1\.'
echo "PASS: S9 red pattern exact"

echo "--- S10: dt-rerun grading separator -> exactly C3.dt.T ---"
run_plant s10; expect_total_fails 1
expect_red 'C3\.dt\.T '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C4\.' 'C5\.'
echo "PASS: S10 red pattern exact"

echo "--- S11: zeta slots swapped -> the zeta rows and their identity pins ---"
run_plant s11; expect_total_fails 16
expect_red 'C2\.k025\.zl\.nr ' 'C2\.k025\.ze\.nf ' 'C2\.k100\.zlog ' 'C3\.dt\.zenv ' 'C3\.amp\.zlog '
expect_green 'C0\.' 'C1\.' 'C2\.k025\.T ' 'C4\.' 'C5\.'
echo "PASS: S11 red pattern exact"

echo "--- S12: verdicts forced to 'oscillating' (the dual of S7) ---"
run_plant s12; expect_total_fails 141
expect_red 'C5\.sp\.c010\.osc ' 'C5\.sp\.c020\.osc ' 'C5\.sp\.c050\.osc ' 'C5\.sp\.c100\.osc ' 'C4\.ph\.osc ' 'C5\.p1\.inner\.osc ' 'C5\.p1\.inner\.engagements ' 'C5\.p2\.sup\.toggles ' 'C5\.p4\.a030\.osc ' 'C5\.p4\.a030\.horizon ' 'C5\.p4\.a020\.osc ' 'C5\.p1\.inner\.diverging ' 'C5\.p1\.inner\.converged ' 'C5\.p1\.inner\.runs ' 'C5\.p1\.inner\.maxrun ' 'C4\.ph\.runs ' 'C4\.ph\.stable ' 'C4\.ph\.moving '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C3\.'
echo "PASS: S12 red pattern exact"

echo "--- S13: below/relabs values displaced 1.1x their executed tolerance -> C1 + plantable C0 ---"
run_plant s13; expect_total_fails 17
expect_red 'C1\.res\.' 'C1\.hold\.' 'C0\.a11 ' 'C0\.a34 '
expect_green 'C0\.a41 ' 'C0\.a42 ' 'C0\.a43 ' 'C0\.a44 ' 'C2\.' 'C3\.' 'C4\.' 'C5\.'
echo "PASS: S13 red pattern exact"

echo "--- S14: check_rel values displaced 1.1x their executed arm -> the tolerance rows ---"
run_plant s14; expect_total_fails 19
expect_red 'C2\.k025\.T ' 'C2\.k100\.zenv ' 'C3\.dt\.T ' 'C3\.amp\.T ' 'C3\.gain\.use ' 'C2\.ph\.Tdft '
no_refusals S14
expect_green 'C0\.' 'C1\.' '\.n ' '\.nr ' '\.nf ' 'C4\.' 'C5\.'
echo "PASS: S14 red pattern exact"

echo "--- S15: the phugoid DFT slot aliased to period_peaks -> exactly the 2 Tdft rows ---"
run_plant s15; expect_total_fails 2
expect_red 'C2\.ph\.Tdft ' 'C2\.ph\.Tdft\.k '
expect_green 'C2\.ph\.T ' 'C2\.ph\.zlog ' 'C0\.' 'C1\.' 'C3\.' 'C4\.' 'C5\.'
echo "PASS: S15 red pattern exact (round-1 review: as_td/as_tp were dead armor with only one period estimator; the phugoid window supports a DFT, so the accessors are now live)"

echo "--- S16: the phugoid extrema slot fed by the DFT (mirror of S15) -> exactly C2.ph.T ---"
run_plant s16; expect_total_fails 1
expect_red 'C2\.ph\.T '
expect_green 'C2\.ph\.Tdft ' 'C0\.' 'C1\.' 'C3\.' 'C4\.' 'C5\.'
echo "PASS: S16 red pattern exact (round-3 review: as_tp was the one accessor with no plant driving its refusal arm — gutting it passed 73/73 and all 15 plants)"

# ------------------------------------------------------------------
# peer_ok <streamfam line> <idx families> -> 0 if every family a PEER
# carries is either carried here or named in a skip=<fam>:<why> token.
# Extracted at round 23 so its planted fault calls the REAL rule.
peer_ok() {
    pline="$1"; fams="$2"
    for pf in $fams; do
        case "$pline" in
            *"idx=$pf"*|*",$pf "*|*",$pf,"*) continue;;
        esac
        echo "$pline" | tr ' ' '\n' | grep -q "^skip=$pf:" || return 1
    done
    return 0
}

echo "--- streamfam: row-family x verdict-stream coverage (round 20, rebuilt rounds 21-23) ---"
# Eight consecutive rounds found the same defect -- a row family added to
# one verdict stream and not its siblings. Round 20 made it a gate. Round
# 21 showed that gate did NOT bind the defect: it checked each line against
# the manifest in isolation and never compared a stream to its PEERS, so
# adding `cidx` to one of five converged-bearing streams passed fully
# green. Its three validating plants were all declaration-consistency
# faults; none was a twinning fault, so the gate had never been tested
# against its own defect class. Rebuilt to be a matrix:
#   1. the stream list is pinned (a gate that examines fewer streams than
#      it did yesterday must not still print OK);
#   2. every ROW token must end `.run`, so a stream cannot leave the
#      enumeration by being renamed;
#   3. for every index family used by ANY stream, every stream must either
#      carry it or name it in a `skip=<fam>:<why>` token -- an absence
#      inside a comma list is otherwise silent by construction, which is
#      exactly how the cidx hole hid.
"$EIGS" tests/ap_check.eigs > "$OUT" 2>&1 || true
BADTOK=$(grep -o '^ROW [A-Za-z0-9_.]*' "$OUT" | sed 's/^ROW //' | grep -v '\.run$' || true)
[ -z "$BADTOK" ] || { echo "FAIL: ROW token(s) not ending in .run, so the streamfam enumeration would silently skip them: $BADTOK"; exit 1; }
STREAMS=$(grep -o '^ROW [A-Za-z0-9_.]*\.run ' "$OUT" | sed 's/^ROW //; s/\.run $//' | sort -u || true)
NSTREAM=$(echo "$STREAMS" | grep -c . || true)
DECL_STREAMS=25
[ "$DECL_STREAMS" = "25" ] || { echo "FAIL: DECL_STREAMS is $DECL_STREAMS, declared 25 — the stream count is DATA and gets the same identity pin the bounds do"; exit 1; }
[ "$NSTREAM" = "$DECL_STREAMS" ] || { echo "FAIL: streamfam examined $NSTREAM verdict streams, declared $DECL_STREAMS — a gate that measures fewer streams than yesterday must not print OK"; exit 1; }
# The union of PEER-COMPARED families. Round 25: this was built from
# `idx=` tokens only, so the position families (at/onset/horizon) sat
# outside the matrix -- and round 24 shipped a defect straight through that
# blind spot one round after ORACLE declared it. `at` is now peer-compared
# for every stream that oscillates, derived from the manifest's own
# `.osc` row rather than declared.
IDXFAMS=$(grep '^streamfam ' tests/ap_manifest.txt | tr ' ' '\n' | grep '^idx=' | sed 's/^idx=//' | tr ',' '\n' | grep -v '^none$' | sort -u)
for st in $STREAMS; do
    line=$(grep "^streamfam $st " tests/ap_manifest.txt || true)
    [ -n "$line" ] || { echo "FAIL: verdict stream '$st' has no streamfam line in tests/ap_manifest.txt — a new stream must declare which row families it carries, and justify any it does not (this gate exists because that was missed eight rounds running)"; exit 1; }
    for fam in $(echo "$line" | tr ' ' '\n' | grep '=' ); do
        key=${fam%%=*}; val=${fam#*=}
        [ "$key" = "skip" ] && continue
        [ "$val" = "none" ] || [ "$val" = "equiv" ] || [ "$val" = "justified" ] && continue
        if [ "$key" = "runs" ] || [ "$key" = "maxrun" ]; then
            grep -q "^ap $st\.$key " tests/ap_manifest.txt || { echo "FAIL: $st declares $key=$val but has no 'ap $st.$key' row in the manifest"; exit 1; }
            continue
        fi
        for f in $(echo "$val" | tr ',' ' '); do
            grep -q "^ap $st\.$f " tests/ap_manifest.txt || { echo "FAIL: $st declares $key including '$f' but has no 'ap $st.$f' row in the manifest"; exit 1; }
        done
    done
    # PEER check: the one round 20 omitted, and the reason its gate did not
    # bind. Round 22 found the SECOND reason it did not bind: `dist=none`
    # was both the blanket exemption AND the truthful declaration of an
    # under-covered stream, so the seven C5.sp rows that emitted verdicts
    # and pinned nothing skipped the rule by the very token that declared
    # the gap -- the rule ran on exactly the eight streams already covered.
    # The exemption is now DERIVED, not declared: a cl_run ROW token
    # carries 8 pipe-separated params and a sup_run token 9, so a stream
    # that emits verdicts cannot claim `dist=none` however its line reads.
    NP=$(grep -m1 "^ROW $st\.run params=" "$OUT" | sed 's/.*params=//' | tr '|' '\n' | grep -c . || true)
    case "$line" in
        *"dist=none"*)
            [ "$NP" = "8" ] || { echo "FAIL: $st declares dist=none but its ROW token carries $NP params, which is the sup_run arity — a stream that EMITS verdicts cannot declare itself exempt from the peer rule (round 22: this exemption was hiding seven streams and a live defect)"; exit 1; }
            continue;;
    esac
    [ "$NP" = "9" ] || { echo "FAIL: $st declares verdict families but its ROW token carries $NP params, not the sup_run arity 9"; exit 1; }
    peer_ok "$line" "$IDXFAMS" || { echo "FAIL: $st carries neither some index family a PEER stream carries, nor a 'skip=<fam>:<why>' token for it — an absence inside a comma list is silent, which is how the cidx hole hid for a full round"; exit 1; }
    # Every skip must be DERIVABLE from this manifest's own rows, not
    # asserted in free text. Round 22 made `dist=none` derivable and round
    # 25 found the same failure mode alive under this token: a
    # `skip=cidx:no-converged-reads` sitting beside a `conv=157` row passed.
    for sk in $(echo "$line" | tr ' ' '\n' | grep '^skip='); do
        fam=${sk#skip=}; fam=${fam%%:*}
        case "$fam" in
            didx) CLS=div;    ALT=diverging;;
            cidx) CLS=conv;   ALT=converged;;
            oidx) CLS=osc;    ALT=osc;;
            *) echo "FAIL: $st skips unknown family '$fam'"; exit 1;;
        esac
        CNT=$(grep -m1 "^ap $st\.$CLS " tests/ap_manifest.txt | sed 's/.*exact=//' || true)
        [ -n "$CNT" ] || CNT=$(grep -m1 "^ap $st\.$ALT " tests/ap_manifest.txt | sed 's/.*exact=//' || true)
        if [ -z "$CNT" ]; then
            # No row for the class at all. That is derivable IF the stream's
            # declared distribution CLOSES against its pinned `reads`: a
            # closed distribution proves every unlisted class is absent.
            SUMD=0
            for dc in $(echo "$line" | tr ' ' '\n' | grep '^dist=' | sed 's/^dist=//' | tr ',' ' '); do
                [ "$dc" = none ] && continue
                DV=$(grep -m1 "^ap $st\.$dc " tests/ap_manifest.txt | sed 's/.*exact=//' || true)
                [ -n "$DV" ] || { echo "FAIL: $st declares dist class '$dc' with no manifest row"; exit 1; }
                SUMD=$((SUMD + DV))
            done
            OSCV=$(grep -m1 "^ap $st\.osc " tests/ap_manifest.txt | sed 's/.*exact=//' || echo 0)
            RD=$(grep -m1 "^ap $st\.reads " tests/ap_manifest.txt | sed 's/.*exact=//' || true)
            [ -n "$RD" ] || { echo "FAIL: $st skips '$fam' with no $CLS row and no reads row — nothing can derive the skip"; exit 1; }
            [ $((SUMD + OSCV)) = "$RD" ] || { echo "FAIL: $st skips '$fam' with no $CLS row, and its distribution does NOT close ($SUMD + osc $OSCV != reads $RD) — so nothing proves that class is absent"; exit 1; }
            CNT=0
        fi
        if [ "$fam" = oidx ]; then
            # osc=0 is vacuous; osc>0 needs a position pin to carry it
            [ "$CNT" = "0" ] || grep -q "^ap $st\.at " tests/ap_manifest.txt || { echo "FAIL: $st skips oidx with osc=$CNT and has no '.at' row — the sighting's POSITION is pinned by nothing (round 25: p370's single sighting moved 111 s with the whole suite byte-identical)"; exit 1; }
        else
            [ "$CNT" = "0" ] || { echo "FAIL: $st skips '$fam' claiming that class is absent, but its manifest row says exact=$CNT — a skip reason must be derivable from the rows, not asserted"; exit 1; }
        fi
    done
done
# PLANTED FAULT for the peer rule itself. Round 22 added one; round 23
# showed it re-implemented the rule against a synthetic string instead of
# calling it, so replacing the real rule with `:` gutted the gate while the
# plant still printed PASS -- verbatim the failure round 22 claimed to
# close, one round later. It now calls the REAL peer_ok, the shape
# tests/test_lint.sh has used all along.
SF_PROBE=$(grep '^streamfam C5.p1.inner ' tests/ap_manifest.txt | sed 's/idx=didx,cidx/idx=didx/')
case "$SF_PROBE" in
    *"idx=didx,cidx"*) echo "FAIL: the streamfam peer-rule plant did not apply — it would certify nothing"; exit 1;;
esac
peer_ok "$SF_PROBE" "$IDXFAMS" && { echo "FAIL: peer_ok ACCEPTED a stream missing an index family a sibling carries — the peer rule cannot fail on its own defect class"; exit 1; }
peer_ok "$(grep '^streamfam C5.p1.inner ' tests/ap_manifest.txt)" "$IDXFAMS" || { echo "FAIL: peer_ok REJECTED the unmutated line — the plant proves nothing about the rule"; exit 1; }
echo "PASS: streamfam peer-rule planted fault rejected by the real rule (a sibling-only index family is caught, the clean line is not)"
echo "PASS: all $NSTREAM verdict streams declare their row families, every declared family has its manifest rows, and every peer index family is carried or explicitly skipped"

# The five manifest-enforcement arms, extracted at round 24 so their
# planted faults can call the REAL code. Round 23 added "plants" for three
# of them that re-implemented the arm inline against a mutated file -- the
# very defect round 23 was fixing in file_pin/peer_ok, re-committed in the
# same commit that named it. Gutting all five arms left the suite green
# with all three PASS lines still printing. The coverage "plant" was worse
# than a copy: it grepped a `structural` name against the red union, which
# the plantable branch can never see, so it asserted a precondition and
# executed no gate logic at all.
# Each returns nonzero on a defect, so a plant can build a dirty input and
# require failure -- the tests/test_lint.sh shape.
manifest_identity() {   # <manifest> <names-file>
    grep '^ap ' "$1" | awk '{print $2, $4}' | sort > "$WORK/_mi"
    diff -u "$WORK/_mi" "$2" > /dev/null
}
rowparams_identity() {  # <manifest> <rows-file>
    grep '^rowparams ' "$1" | awk '{print $2, $3}' | sort > "$WORK/_mr"
    diff -u "$WORK/_mr" "$2" > /dev/null
}
coverage_ok() {         # <manifest> <red-union>  -- every plantable must red
    local kind name klass tolspec
    while read -r kind name klass tolspec; do
        [ "$kind" = ap ] || continue
        [ "$klass" = plantable ] || continue
        grep -qx "$name" "$2" || return 1
    done < <(grep -v '^#' "$1")
    return 0
}
structural_ok() {       # <manifest> <red-union>  -- no structural may red
    local kind name klass tolspec
    while read -r kind name klass tolspec; do
        [ "$kind" = ap ] || continue
        [ "$klass" = structural ] || continue
        grep -qx "$name" "$2" && return 1
    done < <(grep -v '^#' "$1")
    return 0
}
class_ok() {            # <manifest> -- vocabulary is exactly {plantable,structural}
    local kind name klass tolspec
    while read -r kind name klass tolspec; do
        [ "$kind" = ap ] || continue
        case "$klass" in plantable|structural) ;; *) return 1;; esac
    done < <(grep -v '^#' "$1")
    return 0
}

echo "--- manifest: identity + rowparams + coverage + class vocabulary ---"
"$EIGS" tests/ap_check.eigs > "$WORK/clean" 2>&1 || { echo "FAIL: unplanted ap_check nonzero"; exit 1; }
grep -E '^(PASS|FAIL) ' "$WORK/clean" | awk '{print $2, $3}' | sort > "$WORK/names"
grep '^ROW ' "$WORK/clean" | awk '{print $2, $3}' | sort > "$WORK/rows"
sort -u "$WORK/red_union" > "$WORK/redu"

# PLANTED FAULTS -- each calls the REAL arm on a dirty input, and each is
# guarded against applying vacuously. Five arms, five plants.
MF=$(mktemp -d)
sed '1a ap C0.notarealcheck plantable exact=0' tests/ap_manifest.txt > "$MF/m1"
cmp -s tests/ap_manifest.txt "$MF/m1" && { rm -rf "$MF"; echo "FAIL: identity plant did not apply"; exit 1; }
manifest_identity "$MF/m1" "$WORK/names" && { rm -rf "$MF"; echo "FAIL: manifest_identity ACCEPTED a row naming no shipped check"; exit 1; }
sed 's/^rowparams C1.hold.run params=0|/rowparams C1.hold.run params=9|/' tests/ap_manifest.txt > "$MF/m2"
cmp -s tests/ap_manifest.txt "$MF/m2" && { rm -rf "$MF"; echo "FAIL: rowparams plant did not apply"; exit 1; }
rowparams_identity "$MF/m2" "$WORK/rows" && { rm -rf "$MF"; echo "FAIL: rowparams_identity ACCEPTED drifted run parameters"; exit 1; }
sed 's/^ap C0.a41 structural /ap C0.a41 plantable /' tests/ap_manifest.txt > "$MF/m3"
cmp -s tests/ap_manifest.txt "$MF/m3" && { rm -rf "$MF"; echo "FAIL: coverage plant did not apply"; exit 1; }
coverage_ok "$MF/m3" "$WORK/redu" && { rm -rf "$MF"; echo "FAIL: coverage_ok ACCEPTED a plantable no plant reds"; exit 1; }
sed 's/^ap C5.p1.inner.diverging plantable /ap C5.p1.inner.diverging structural /' tests/ap_manifest.txt > "$MF/m4"
cmp -s tests/ap_manifest.txt "$MF/m4" && { rm -rf "$MF"; echo "FAIL: structural plant did not apply"; exit 1; }
structural_ok "$MF/m4" "$WORK/redu" && { rm -rf "$MF"; echo "FAIL: structural_ok ACCEPTED a structural row that plants do red"; exit 1; }
sed 's/^ap C0.a41 structural /ap C0.a41 mystery /' tests/ap_manifest.txt > "$MF/m5"
cmp -s tests/ap_manifest.txt "$MF/m5" && { rm -rf "$MF"; echo "FAIL: class-vocabulary plant did not apply"; exit 1; }
class_ok "$MF/m5" && { rm -rf "$MF"; echo "FAIL: class_ok ACCEPTED an unknown manifest class"; exit 1; }
rm -rf "$MF"
echo "PASS: all five manifest-enforcement arms rejected an in-class planted fault"

manifest_identity tests/ap_manifest.txt "$WORK/names" || { echo "FAIL: check-name set drifted from manifest"; diff "$WORK/_mi" "$WORK/names" || true; exit 1; }
rowparams_identity tests/ap_manifest.txt "$WORK/rows" || { echo "FAIL: run-parameter set drifted from manifest"; diff "$WORK/_mr" "$WORK/rows" || true; exit 1; }
coverage_ok tests/ap_manifest.txt "$WORK/redu" || { echo "FAIL: a plantable check never went red"; exit 1; }
structural_ok tests/ap_manifest.txt "$WORK/redu" || { echo "FAIL: a structural check went red — exemption stale"; exit 1; }
class_ok tests/ap_manifest.txt || { echo "FAIL: unknown manifest class token"; exit 1; }
echo "PASS: manifest identity holds; all plantable checks proven able to fail"
echo "PASS: all 16 rung-3 plants flip exactly their declared checks"
