#!/usr/bin/env bash
# Rung-4 W checks: the swarm is still N of rung 1's aircraft, and the arms
# — which differ only in OBSERVATION — do not differ in physics.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT=$(mktemp); trap 'rm -f "$OUT"' EXIT
echo "--- swarm_check (W1..W4) ---"
"$EIGS" tests/swarm_check.eigs > "$OUT" 2>&1 || { echo "FAIL: swarm_check exited nonzero"; tail -5 "$OUT"; exit 1; }
grep -q '^CHECKS_RUN 60$' "$OUT" || { echo "FAIL: check population not 60"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$'  "$OUT" || { echo "FAIL: swarm_check has failures"; grep '^FAIL' "$OUT"; exit 1; }
grep -q '^FAIL harness' "$OUT" && { echo "FAIL: harness self-check"; grep '^FAIL harness' "$OUT"; exit 1; }
echo "PASS: 60/60 rung-4 checks green"


# ---------------------------------------------------------------------
# P3's evidence table, produced by a shipped driver (round 6 found it
# existing only in ORACLE.md prose -- the third time in this rung that a
# published table had no committed producer).
#
# ORDERING IS LOAD-BEARING. Round 8 added two "this pins the claim"
# assertions and put them AFTER the exact-row pins, which include the
# literals osc=41 and osc=61 and exit 1 on any mismatch. So the claim
# assertions were unreachable: they could only ever evaluate in the world
# where the rows already matched exactly, and they pinned strictly less
# than the pins above them. Round 9: every CLAIM is asserted FIRST, from
# ranges, so it can still fail when a row has drifted; the exact-row pins
# follow as regression detail. A claim check downstream of an exact pin of
# its own inputs is decoration.
# ---------------------------------------------------------------------
"$EIGS" tests/swarm_p3.eigs > "$OUT" 2>&1 || { echo "FAIL: swarm_p3 exited nonzero"; tail -3 "$OUT"; exit 1; }

# shellcheck source=tests/p3claims.sh
. tests/p3claims.sh
p3_claims "$OUT" || { echo "FAIL: P3's claims no longer hold against measured physics"; exit 1; }

# Re-banked at the phugoid#8 re-grade from EigenScript main a7a4ca3's own
# output (44 of 164 lines moved: 31 radian verdict rows, the 8 radian and
# degree monotone-decay rows, 1 noise row and the 4 N-sweep rows; not one
# degree or milliradian verdict row moved -- #1045 made radians read what
# the other units already read). The claims above are what license it.
# --- regression detail: the exact rows. These come AFTER every claim
# above, so a drift here is reported as drift and not as a silent veto on
# the claim checks.
NP3=$(grep -c '^p3 unit=' "$OUT" || true)
[ "$NP3" = "96" ] || { echo "FAIL: P3 sweep produced $NP3 rows, expected 96"; exit 1; }
NT=$(grep -c '^p3truth ac=' "$OUT" || true)
[ "$NT" = "4" ] || { echo "FAIL: P3 truth table produced $NT rows, expected 4"; exit 1; }
EXPECTED_P3_ROWS=0
while read -r want; do
    # Comments document each moved pin; every actual row is still checked.
    [[ "$want" == \#* ]] && continue
    EXPECTED_P3_ROWS=$((EXPECTED_P3_ROWS+1))
    grep -qxF "$want" "$OUT" || { echo "FAIL: P3 row drifted: $want"; grep -E '^p3(truth| unit=|n |ph |nc |mono )' "$OUT"; exit 1; }
done <<'P3ROWS'
p3truth ac=0 sp=0.02 u_pp_first=337 u_pp_last=181 q_pp_first=1057 q_pp_last=103 amp=96
p3truth ac=0 sp=0.05 u_pp_first=844 u_pp_last=452 q_pp_first=2643 q_pp_last=257 amp=240
p3truth ac=1 sp=0.02 u_pp_first=656 u_pp_last=352 q_pp_first=2055 q_pp_last=200 amp=186
p3truth ac=1 sp=0.05 u_pp_first=1641 u_pp_last=880 q_pp_first=5134 q_pp_last=501 amp=466
# p3 unit=rad ac=0 sp=0.02 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=rad ac=0 sp=0.02 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.02 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=rad ac=0 sp=0.02 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=rad ac=0 sp=0.02 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.02 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=rad ac=0 sp=0.02 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.02 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=rad ac=0 sp=0.02 cad=124: moving 13->3, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.02 cad=124 reads=64 conv=0 osc=51 moving=3 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=51 fquiet=0 fnoclaim=3 fother=1
# p3 unit=rad ac=0 sp=0.02 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.02 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=rad ac=0 sp=0.02 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=rad ac=0 sp=0.05 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=rad ac=0 sp=0.05 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.05 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=rad ac=0 sp=0.05 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=rad ac=0 sp=0.05 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.05 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=rad ac=0 sp=0.05 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.05 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=rad ac=0 sp=0.05 cad=124: moving 12->2, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.05 cad=124 reads=64 conv=0 osc=52 moving=2 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=52 fquiet=0 fnoclaim=2 fother=1
# p3 unit=rad ac=0 sp=0.05 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.05 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=rad ac=0 sp=0.05 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=0 sp=0.05 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=rad ac=1 sp=0.02 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=rad ac=1 sp=0.02 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.02 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=rad ac=1 sp=0.02 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=rad ac=1 sp=0.02 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.02 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=rad ac=1 sp=0.02 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.02 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=rad ac=1 sp=0.02 cad=124: moving 12->2, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.02 cad=124 reads=64 conv=0 osc=52 moving=2 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=52 fquiet=0 fnoclaim=2 fother=1
# p3 unit=rad ac=1 sp=0.02 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.02 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=rad ac=1 sp=0.02 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=rad ac=1 sp=0.05 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=rad ac=1 sp=0.05 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.05 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=rad ac=1 sp=0.05 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=rad ac=1 sp=0.05 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.05 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=rad ac=1 sp=0.05 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.05 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=rad ac=1 sp=0.05 cad=124: moving 13->3, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.05 cad=124 reads=64 conv=0 osc=51 moving=3 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=51 fquiet=0 fnoclaim=3 fother=1
# p3 unit=rad ac=1 sp=0.05 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.05 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=rad ac=1 sp=0.05 cad=148: moving 19->9, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=rad ac=1 sp=0.05 cad=148 reads=54 conv=0 osc=35 moving=9 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=35 fquiet=0 fnoclaim=9 fother=1
# p3 unit=deg ac=0 sp=0.02 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=deg ac=0 sp=0.02 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.02 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=deg ac=0 sp=0.02 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=deg ac=0 sp=0.02 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.02 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=deg ac=0 sp=0.02 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.02 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=deg ac=0 sp=0.02 cad=124: moving 13->3, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.02 cad=124 reads=64 conv=0 osc=51 moving=3 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=51 fquiet=0 fnoclaim=3 fother=1
# p3 unit=deg ac=0 sp=0.02 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.02 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=deg ac=0 sp=0.02 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=deg ac=0 sp=0.05 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=deg ac=0 sp=0.05 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.05 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=deg ac=0 sp=0.05 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=deg ac=0 sp=0.05 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.05 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=deg ac=0 sp=0.05 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.05 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=deg ac=0 sp=0.05 cad=124: moving 12->2, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.05 cad=124 reads=64 conv=0 osc=52 moving=2 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=52 fquiet=0 fnoclaim=2 fother=1
# p3 unit=deg ac=0 sp=0.05 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.05 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=deg ac=0 sp=0.05 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=0 sp=0.05 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=deg ac=1 sp=0.02 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=deg ac=1 sp=0.02 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.02 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=deg ac=1 sp=0.02 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=deg ac=1 sp=0.02 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.02 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=deg ac=1 sp=0.02 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.02 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=deg ac=1 sp=0.02 cad=124: moving 12->2, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.02 cad=124 reads=64 conv=0 osc=52 moving=2 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=52 fquiet=0 fnoclaim=2 fother=1
# p3 unit=deg ac=1 sp=0.02 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.02 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=deg ac=1 sp=0.02 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=deg ac=1 sp=0.05 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=deg ac=1 sp=0.05 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.05 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=deg ac=1 sp=0.05 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=deg ac=1 sp=0.05 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.05 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=deg ac=1 sp=0.05 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.05 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=deg ac=1 sp=0.05 cad=124: moving 13->3, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.05 cad=124 reads=64 conv=0 osc=51 moving=3 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=51 fquiet=0 fnoclaim=3 fother=1
# p3 unit=deg ac=1 sp=0.05 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.05 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=deg ac=1 sp=0.05 cad=148: moving 19->9, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=deg ac=1 sp=0.05 cad=148 reads=54 conv=0 osc=35 moving=9 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=35 fquiet=0 fnoclaim=9 fother=1
# p3 unit=mrad ac=0 sp=0.02 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=mrad ac=0 sp=0.02 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.02 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=mrad ac=0 sp=0.02 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=mrad ac=0 sp=0.02 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.02 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=mrad ac=0 sp=0.02 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.02 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=mrad ac=0 sp=0.02 cad=124: moving 13->3, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.02 cad=124 reads=64 conv=0 osc=51 moving=3 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=51 fquiet=0 fnoclaim=3 fother=1
# p3 unit=mrad ac=0 sp=0.02 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.02 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=mrad ac=0 sp=0.02 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=mrad ac=0 sp=0.05 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=mrad ac=0 sp=0.05 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.05 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=mrad ac=0 sp=0.05 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=mrad ac=0 sp=0.05 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.05 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=mrad ac=0 sp=0.05 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.05 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=mrad ac=0 sp=0.05 cad=124: moving 12->2, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.05 cad=124 reads=64 conv=0 osc=52 moving=2 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=52 fquiet=0 fnoclaim=2 fother=1
# p3 unit=mrad ac=0 sp=0.05 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.05 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=mrad ac=0 sp=0.05 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=0 sp=0.05 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=mrad ac=1 sp=0.02 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=mrad ac=1 sp=0.02 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.02 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=mrad ac=1 sp=0.02 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=mrad ac=1 sp=0.02 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.02 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=mrad ac=1 sp=0.02 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.02 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=mrad ac=1 sp=0.02 cad=124: moving 12->2, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.02 cad=124 reads=64 conv=0 osc=52 moving=2 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=52 fquiet=0 fnoclaim=2 fother=1
# p3 unit=mrad ac=1 sp=0.02 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.02 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=mrad ac=1 sp=0.02 cad=148: moving 20->10, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=10 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=10 fother=1
# p3 unit=mrad ac=1 sp=0.05 cad=74: moving 108->98, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=98 stable=0 equil=0 improving=10 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=98 fother=1
# p3 unit=mrad ac=1 sp=0.05 cad=84: moving 43->34, improving 0->9. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.05 cad=84 reads=95 conv=0 osc=52 moving=34 stable=0 equil=0 improving=9 diverging=0 other=0 full=86 fosc=52 fquiet=0 fnoclaim=34 fother=0
# p3 unit=mrad ac=1 sp=0.05 cad=94: moving 23->15, improving 0->8. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=15 stable=0 equil=0 improving=8 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
# p3 unit=mrad ac=1 sp=0.05 cad=104: moving 7->0, improving 0->7. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.05 cad=104 reads=76 conv=0 osc=69 moving=0 stable=0 equil=0 improving=7 diverging=0 other=0 full=67 fosc=67 fquiet=0 fnoclaim=0 fother=0
# p3 unit=mrad ac=1 sp=0.05 cad=114: moving 10->0, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.05 cad=114 reads=70 conv=0 osc=60 moving=0 stable=0 equil=0 improving=10 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=0 fother=1
# p3 unit=mrad ac=1 sp=0.05 cad=124: moving 13->3, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.05 cad=124 reads=64 conv=0 osc=51 moving=3 stable=0 equil=0 improving=10 diverging=0 other=0 full=55 fosc=51 fquiet=0 fnoclaim=3 fother=1
# p3 unit=mrad ac=1 sp=0.05 cad=134: moving 24->14, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.05 cad=134 reads=59 conv=0 osc=35 moving=14 stable=0 equil=0 improving=10 diverging=0 other=0 full=50 fosc=35 fquiet=0 fnoclaim=14 fother=1
# p3 unit=mrad ac=1 sp=0.05 cad=148: moving 19->9, improving 0->10. D2 uses recent significant lower bests; analytical modal truth remains a live oscillation, so these remain regression fingerprints of its finite-window misreads.
p3 unit=mrad ac=1 sp=0.05 cad=148 reads=54 conv=0 osc=35 moving=9 stable=0 equil=0 improving=10 diverging=0 other=0 full=45 fosc=35 fquiet=0 fnoclaim=9 fother=1
# p3mono kind=decay_slow unit=rad cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_slow unit=rad cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=75 diverging=0 equil=0
# p3mono kind=decay_slow unit=rad cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_slow unit=rad cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=66 diverging=0 equil=0
# p3mono kind=decay_slow unit=deg cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_slow unit=deg cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=75 diverging=0 equil=0
# p3mono kind=decay_slow unit=deg cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_slow unit=deg cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=66 diverging=0 equil=0
# p3mono kind=decay_slow unit=mrad cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_slow unit=mrad cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=75 diverging=0 equil=0
# p3mono kind=decay_slow unit=mrad cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_slow unit=mrad cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=66 diverging=0 equil=0
# p3mono kind=decay_fast unit=rad cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_fast unit=rad cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=75 diverging=0 equil=0
# p3mono kind=decay_fast unit=rad cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_fast unit=rad cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=66 diverging=0 equil=0
# p3mono kind=decay_fast unit=deg cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_fast unit=deg cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=75 diverging=0 equil=0
# p3mono kind=decay_fast unit=deg cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_fast unit=deg cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=66 diverging=0 equil=0
# p3mono kind=decay_fast unit=mrad cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_fast unit=mrad cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=75 diverging=0 equil=0
# p3mono kind=decay_fast unit=mrad cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=decay_fast unit=mrad cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=66 diverging=0 equil=0
# p3mono kind=ramp unit=rad cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=ramp unit=rad cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=0 diverging=75 equil=0
# p3mono kind=ramp unit=rad cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=ramp unit=rad cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=0 diverging=66 equil=0
# p3mono kind=ramp unit=deg cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=ramp unit=deg cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=0 diverging=75 equil=0
# p3mono kind=ramp unit=deg cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=ramp unit=deg cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=0 diverging=66 equil=0
# p3mono kind=ramp unit=mrad cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=ramp unit=mrad cad=94 full=75 fosc=0 conv=0 stable=0 moving=0 improving=0 diverging=75 equil=0
# p3mono kind=ramp unit=mrad cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=ramp unit=mrad cad=104 full=66 fosc=0 conv=0 stable=0 moving=0 improving=0 diverging=66 equil=0
# p3mono kind=noise unit=rad cad=74: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=rad cad=74 full=98 fosc=96 conv=0 stable=0 moving=1 improving=1 diverging=0 equil=0
# p3mono kind=noise unit=rad cad=84: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=rad cad=84 full=85 fosc=85 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=rad cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=rad cad=94 full=75 fosc=75 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=rad cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=rad cad=104 full=66 fosc=66 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=rad cad=114: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=rad cad=114 full=60 fosc=60 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=rad cad=124: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=rad cad=124 full=54 fosc=54 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=rad cad=134: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=rad cad=134 full=49 fosc=49 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=rad cad=148: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=rad cad=148 full=44 fosc=44 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=deg cad=74: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=deg cad=74 full=98 fosc=96 conv=0 stable=0 moving=1 improving=1 diverging=0 equil=0
# p3mono kind=noise unit=deg cad=84: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=deg cad=84 full=85 fosc=85 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=deg cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=deg cad=94 full=75 fosc=75 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=deg cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=deg cad=104 full=66 fosc=66 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=deg cad=114: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=deg cad=114 full=60 fosc=60 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=deg cad=124: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=deg cad=124 full=54 fosc=54 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=deg cad=134: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=deg cad=134 full=49 fosc=49 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=deg cad=148: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=deg cad=148 full=44 fosc=44 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=mrad cad=74: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=mrad cad=74 full=98 fosc=96 conv=0 stable=0 moving=1 improving=1 diverging=0 equil=0
# p3mono kind=noise unit=mrad cad=84: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=mrad cad=84 full=85 fosc=85 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=mrad cad=94: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=mrad cad=94 full=75 fosc=75 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=mrad cad=104: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=mrad cad=104 full=66 fosc=66 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=mrad cad=114: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=mrad cad=114 full=60 fosc=60 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=mrad cad=124: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=mrad cad=124 full=54 fosc=54 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=mrad cad=134: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=mrad cad=134 full=49 fosc=49 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
# p3mono kind=noise unit=mrad cad=148: D2 replaces contraction with running lower bests. The exponential controls decay monotonically (improving); the ramp/noise controls retain their independently generated trajectories and their full-window populations.
p3mono kind=noise unit=mrad cad=148 full=44 fosc=44 conv=0 stable=0 moving=0 improving=0 diverging=0 equil=0
p3nc unit=rad cad=94 full=76 fosc=0
p3nc unit=rad cad=104 full=67 fosc=0
p3nc unit=deg cad=94 full=76 fosc=0
p3nc unit=deg cad=104 full=67 fosc=0
p3nc unit=mrad cad=94 full=76 fosc=0
p3nc unit=mrad cad=104 full=67 fosc=0
p3ph ac=0 cad=74 phase=0 full=99 fosc=0
p3ph ac=0 cad=74 phase=7 full=99 fosc=0
p3ph ac=0 cad=74 phase=18 full=98 fosc=0
p3ph ac=0 cad=74 phase=37 full=98 fosc=1
p3ph ac=0 cad=74 phase=55 full=98 fosc=0
p3ph ac=0 cad=74 phase=66 full=98 fosc=0
p3ph ac=1 cad=74 phase=0 full=99 fosc=0
p3ph ac=1 cad=74 phase=7 full=99 fosc=1
p3ph ac=1 cad=74 phase=18 full=98 fosc=0
p3ph ac=1 cad=74 phase=37 full=98 fosc=1
p3ph ac=1 cad=74 phase=55 full=98 fosc=0
p3ph ac=1 cad=74 phase=66 full=98 fosc=0
p3n n=2 sp=0.05 cad=94 reads=170 alerts=124 per_ac_permille=729 sweeps=85 firing=62 fleet_permille=729 fsweeps=76 ffiring=61 ffleet_permille=803 first=8 last=84 per=[62, 62]
p3n n=4 sp=0.05 cad=94 reads=340 alerts=248 per_ac_permille=729 sweeps=85 firing=62 fleet_permille=729 fsweeps=76 ffiring=61 ffleet_permille=803 first=8 last=84 per=[62, 62, 62, 62]
p3n n=8 sp=0.05 cad=94 reads=680 alerts=496 per_ac_permille=729 sweeps=85 firing=62 fleet_permille=729 fsweeps=76 ffiring=61 ffleet_permille=803 first=8 last=84 per=[62, 62, 62, 62, 62, 62, 62, 62]
p3n n=16 sp=0.05 cad=94 reads=1360 alerts=992 per_ac_permille=729 sweeps=85 firing=62 fleet_permille=729 fsweeps=76 ffiring=61 ffleet_permille=803 first=8 last=84 per=[62, 62, 62, 62, 62, 62, 62, 62, 62, 62, 62, 62, 62, 62, 62, 62]
P3ROWS
# Pin the original literal-row population: comments cannot disable an expectation.
[ "$EXPECTED_P3_ROWS" -eq 164 ] || { echo "FAIL: P3 exact-row expectation population $EXPECTED_P3_ROWS, expected 164"; exit 1; }
grep -q '^p3 total reads across the sweep: 7332$' "$OUT" || { echo "FAIL: P3 sweep population changed"; exit 1; }
grep -q '^p3ph total detections across the phase sweep: 3$' "$OUT" || { echo "FAIL: P3 phase-sweep population changed"; exit 1; }
grep -q '^p3nc total detections on the equilibrium aircraft: 0$' "$OUT" || { echo "FAIL: negative-control population changed"; exit 1; }
grep -q '^p3mono total detections on monotone channels: 0$' "$OUT" || { echo "FAIL: monotone-control population changed"; exit 1; }
grep -q '^p3mono minimum detections on the aperiodic-noise channel: 44$' "$OUT" || { echo "FAIL: noise-control detection changed"; exit 1; }
# Raw other must still be zero. Full-window fother also contains documented
# improving/diverging reads, so require coverage by those named raw counts;
# the 164 exact row pins above keep each full-window count independently fixed.
p3_known_labels() {
    awk '
    /^p3 unit=/ {
        count++
        for (k in v) delete v[k]
        for (i=2;i<=NF;i++) { split($i,a,"="); v[a[1]]=a[2] }
        malformed=0
        for (i=1;i<=4;i++) {
            key=(i==1?"other":i==2?"fother":i==3?"improving":"diverging")
            if (!(key in v) || v[key] !~ /^[0-9]+$/) malformed=1
        }
        if (malformed || v["other"]+0 != 0 || v["fother"]+0 > v["improving"]+0+v["diverging"]) {
            print "FAIL: unknown or uncovered P3 verdict: " $0
            bad=1
        }
    }
    END { if(count!=96) {print "FAIL: P3 label population " count ", expected 96"; bad=1}; exit bad }
    ' "$1"
}
p3_known_labels "$OUT" || exit 1
echo "PASS: P3's 164 pinned rows reproduce (4 physics truth, 96 verdict over a uniform 3x2x2x8 grid, 12 phase cells, 6 equilibrium + 18 monotone + 24 noise controls, 4 N-axis)"
