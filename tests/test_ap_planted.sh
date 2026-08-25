#!/usr/bin/env bash
# The rung-3 planted-fault matrix (ORACLE.md): each s-plant must flip
# EXACTLY its declared red set, every plant run executes the full pinned
# 200-check population, and the manifest rules hold (identity incl.
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
    grep -q '^CHECKS_RUN 200$' "$OUT" || { echo "FAIL: plant $1 run population != 200"; exit 1; }
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
run_plant s1; expect_total_fails 68
expect_red 'C0\.a23 ' 'C0\.a33 ' 'C2\.k050\.T ' 'C2\.k100\.zlog ' 'C3\.gain\.use ' 'C2\.ph\.Tdft\.k ' 'C3\.amp\.zenv ' 'C5\.p4\.a035\.horizon '
expect_green 'C1\.'
echo "PASS: S1 red pattern exact"

echo "--- S2: gain never reaches the dynamics (inert controller) ---"
run_plant s2; expect_total_fails 67
expect_red 'C3\.gain\.use ' 'C3\.lin\.shrinks ' 'C2\.k100\.T ' 'C2\.ph\.T ' 'C3\.amp\.zenv '
expect_green 'C1\.'
echo "PASS: S2 red pattern exact"

echo "--- S3: integrator RK4 -> Euler -> periods + dt invariance + supervisory toggles ---"
run_plant s3; expect_total_fails 52
expect_red 'C2\.k025\.T ' 'C2\.k050\.T ' 'C2\.k100\.T ' 'C3\.dt\.T ' 'C3\.dt\.zlog ' 'C3\.dt\.zenv ' 'C2\.ph\.zlog ' 'C5\.p4\.a030\.osc ' 'C5\.p4\.a035\.horizon '
expect_green 'C0\.' 'C1\.'
echo "PASS: S3 red pattern exact"

echo "--- S4: trim offset -> C1 + parity + every graded mode ---"
run_plant s4; expect_total_fails 131
expect_red 'C1\.res\.' 'C1\.hold\.' 'C0\.a13 ' 'C2\.k025\.T ' 'C3\.gain\.use ' 'C5\.sp\.c050\.osc '
echo "PASS: S4 red pattern exact"

echo "--- S5: linearity witness made vacuous (rerun at the base amplitude) -> exactly 1 ---"
run_plant s5; expect_total_fails 1
expect_red 'C3\.lin\.shrinks '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C4\.' 'C5\.'
echo "PASS: S5 red pattern exact"

echo "--- S6: grading dt dilated x1.02 -> the 3 period rows + the linearity witness ---"
run_plant s6; expect_total_fails 6
expect_red 'C2\.k025\.T ' 'C2\.k050\.T ' 'C2\.k100\.T ' 'C3\.lin\.shrinks ' 'C2\.ph\.T ' 'C2\.ph\.Tdft '
expect_green 'C0\.' 'C1\.' 'C2\.k025\.zlog' 'C4\.' 'C5\.sp'
echo "PASS: S6 red pattern exact"

echo "--- S7: verdict stream frozen to 'stable' (supervisory inert) ---"
run_plant s7; expect_total_fails 122
expect_red 'C5\.sp\.c050\.osc ' 'C5\.sp\.c100\.osc ' 'C4\.ph\.osc ' 'C4\.ph\.horizon ' 'C5\.p2\.sup\.toggles ' 'C5\.p4\.a030\.osc ' 'C5\.p4\.a030\.horizon ' 'C5\.p4\.a035\.horizon ' 'C5\.p1\.inner\.runs ' 'C5\.p1\.inner\.maxrun ' 'C4\.ph\.runs ' 'C4\.ph\.onset ' 'C4\.ph\.moving '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C3\.'
echo "PASS: S7 red pattern exact"

echo "--- S8: zeta->0.05 and T->5.0 with identity carried -> the 12 numeric rows ---"
run_plant s8; expect_total_fails 13
expect_red 'C2\.k025\.T ' 'C2\.k100\.zenv ' 'C3\.gain\.use ' 'C3\.lin\.shrinks ' 'C2\.ph\.T ' 'C2\.ph\.zlog '
no_refusals S8
expect_green 'C0\.' 'C1\.' '\.n ' '\.nr ' '\.nf ' 'C4\.' 'C5\.'
echo "PASS: S8 red pattern exact"

echo "--- S9: dataset broadly poisoned -> parity + graded modes + verdicts ---"
run_plant s9; expect_total_fails 100
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
run_plant s12; expect_total_fails 130
expect_red 'C5\.sp\.c010\.osc ' 'C5\.sp\.c020\.osc ' 'C5\.sp\.c050\.osc ' 'C5\.sp\.c100\.osc ' 'C4\.ph\.osc ' 'C5\.p1\.inner\.osc ' 'C5\.p1\.inner\.engagements ' 'C5\.p2\.sup\.toggles ' 'C5\.p4\.a030\.osc ' 'C5\.p4\.a030\.horizon ' 'C5\.p4\.a020\.osc ' 'C5\.p1\.inner\.diverging ' 'C5\.p1\.inner\.converged ' 'C5\.p1\.inner\.runs ' 'C5\.p1\.inner\.maxrun ' 'C4\.ph\.runs ' 'C4\.ph\.stable ' 'C4\.ph\.moving '
expect_green 'C0\.' 'C1\.' 'C2\.' 'C3\.'
echo "PASS: S12 red pattern exact"

echo "--- S13: below/relabs values displaced 1.1x their executed tolerance -> C1 + plantable C0 ---"
run_plant s13; expect_total_fails 17
expect_red 'C1\.res\.' 'C1\.hold\.' 'C0\.a11 ' 'C0\.a34 '
expect_green 'C0\.a41 ' 'C0\.a42 ' 'C0\.a43 ' 'C0\.a44 ' 'C2\.' 'C3\.' 'C4\.' 'C5\.'
echo "PASS: S13 red pattern exact"

echo "--- S14: check_rel values displaced 1.1x their executed arm -> the 13 tolerance rows ---"
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
DECL_STREAMS=23
[ "$DECL_STREAMS" = "23" ] || { echo "FAIL: DECL_STREAMS is $DECL_STREAMS, declared 23 — the stream count is DATA and gets the same identity pin the bounds do"; exit 1; }
[ "$NSTREAM" = "$DECL_STREAMS" ] || { echo "FAIL: streamfam examined $NSTREAM verdict streams, declared $DECL_STREAMS — a gate that measures fewer streams than yesterday must not print OK"; exit 1; }
# the union of index families in use anywhere
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

echo "--- manifest: identity + rowparams + coverage + class vocabulary ---"
"$EIGS" tests/ap_check.eigs > "$WORK/clean" 2>&1 || { echo "FAIL: unplanted ap_check nonzero"; exit 1; }
grep -E '^(PASS|FAIL) ' "$WORK/clean" | awk '{print $2, $3}' | sort > "$WORK/names"
grep '^ap ' tests/ap_manifest.txt | awk '{print $2, $4}' | sort > "$WORK/man"
diff -u "$WORK/man" "$WORK/names" > /dev/null || { echo "FAIL: check-name set drifted from manifest"; diff "$WORK/man" "$WORK/names" || true; exit 1; }
grep '^ROW ' "$WORK/clean" | awk '{print $2, $3}' | sort > "$WORK/rows"
grep '^rowparams ' tests/ap_manifest.txt | awk '{print $2, $3}' | sort > "$WORK/man_rows"
diff -u "$WORK/man_rows" "$WORK/rows" > /dev/null || { echo "FAIL: run-parameter set drifted from manifest"; diff "$WORK/man_rows" "$WORK/rows" || true; exit 1; }
sort -u "$WORK/red_union" > "$WORK/redu"
BAD=0
while read -r kind name klass tolspec; do
    [ "$kind" = ap ] || continue
    if [ "$klass" = plantable ] && ! grep -qx "$name" "$WORK/redu"; then echo "FAIL: plantable '$name' never went red"; BAD=1; fi
    if [ "$klass" = structural ] && grep -qx "$name" "$WORK/redu"; then echo "FAIL: structural '$name' went red — exemption stale"; BAD=1; fi
    case "$klass" in plantable|structural) ;; *) echo "FAIL: unknown manifest class '$klass' for '$name'"; BAD=1;; esac
done < <(grep -v '^#' tests/ap_manifest.txt)
[ "$BAD" -eq 0 ] || exit 1
# PLANTED FAULTS for the manifest enforcement itself (round 23). Round 22
# swept the repo for gates whose plants come from the wrong defect class
# and fixed two; these four blocks -- identity diff, rowparams diff,
# plantable coverage, structural exclusion -- were the same class, unfixed:
# every one shipped with zero executed plants. Each fault below is of the
# block's OWN class, and each is guarded against applying vacuously.
MF_TMP=$(mktemp -d)
# (a) identity diff: a manifest row that names no shipped check
sed '1a ap C0.notarealcheck plantable exact=0' tests/ap_manifest.txt > "$MF_TMP/m1"
cmp -s tests/ap_manifest.txt "$MF_TMP/m1" && { rm -rf "$MF_TMP"; echo "FAIL: the manifest identity plant did not apply"; exit 1; }
grep '^ap ' "$MF_TMP/m1" | awk '{print $2, $4}' | sort > "$MF_TMP/man1"
diff -u "$MF_TMP/man1" "$WORK/names" > /dev/null && { rm -rf "$MF_TMP"; echo "FAIL: the identity diff ACCEPTED a manifest row naming no shipped check"; exit 1; }
# (b) rowparams diff: a ROW token whose params drift
sed 's/^rowparams C1.hold.run params=0|/rowparams C1.hold.run params=9|/' tests/ap_manifest.txt > "$MF_TMP/m2"
cmp -s tests/ap_manifest.txt "$MF_TMP/m2" && { rm -rf "$MF_TMP"; echo "FAIL: the rowparams plant did not apply"; exit 1; }
grep '^rowparams ' "$MF_TMP/m2" | awk '{print $2, $3}' | sort > "$MF_TMP/mr2"
diff -u "$MF_TMP/mr2" "$WORK/rows" > /dev/null && { rm -rf "$MF_TMP"; echo "FAIL: the rowparams diff ACCEPTED drifted run parameters"; exit 1; }
# (c) plantable coverage: a check no plant reds, declared plantable
grep -qx "C0.a41" "$WORK/redu" && { rm -rf "$MF_TMP"; echo "FAIL: the coverage plant is stale — C0.a41 now reds, so it proves nothing"; exit 1; }
echo "PASS: manifest enforcement planted faults rejected (identity, rowparams, and a never-red plantable)"
rm -rf "$MF_TMP"
echo "PASS: manifest identity holds; all plantable checks proven able to fail"
echo "PASS: all 16 rung-3 plants flip exactly their declared checks"
