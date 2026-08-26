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
grep -q '^CHECKS_RUN 47$' "$OUT" || { echo "FAIL: check population not 47"; tail -3 "$OUT"; exit 1; }
grep -q '^FAILURES 0$'  "$OUT" || { echo "FAIL: swarm_check has failures"; grep '^FAIL' "$OUT"; exit 1; }
grep -q '^FAIL harness' "$OUT" && { echo "FAIL: harness self-check"; grep '^FAIL harness' "$OUT"; exit 1; }
echo "PASS: 47/47 rung-4 checks green"


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

# --- regression detail: the exact rows. These come AFTER every claim
# above, so a drift here is reported as drift and not as a silent veto on
# the claim checks.
NP3=$(grep -c '^p3 unit=' "$OUT" || true)
[ "$NP3" = "46" ] || { echo "FAIL: P3 sweep produced $NP3 rows, expected 46"; exit 1; }
NT=$(grep -c '^p3truth ac=' "$OUT" || true)
[ "$NT" = "4" ] || { echo "FAIL: P3 truth table produced $NT rows, expected 4"; exit 1; }
while read -r want; do
    grep -qxF "$want" "$OUT" || { echo "FAIL: P3 row drifted: $want"; grep -E '^p3(truth| unit=|n |ph )' "$OUT"; exit 1; }
done <<'P3ROWS'
p3truth ac=0 sp=0.02 u_pp_first=337 u_pp_last=181 q_pp_first=1057 q_pp_last=103
p3truth ac=0 sp=0.05 u_pp_first=844 u_pp_last=452 q_pp_first=2643 q_pp_last=257
p3truth ac=1 sp=0.02 u_pp_first=656 u_pp_last=352 q_pp_first=2055 q_pp_last=200
p3truth ac=1 sp=0.05 u_pp_first=1641 u_pp_last=880 q_pp_first=5134 q_pp_last=501
p3 unit=rad ac=0 sp=0.02 cad=74 reads=108 conv=98 osc=0 moving=10 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=98 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.02 cad=94 reads=85 conv=75 osc=0 moving=10 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=0 fquiet=75 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.02 cad=148 reads=54 conv=44 osc=0 moving=10 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=0 fquiet=44 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.05 cad=74 reads=108 conv=73 osc=0 moving=10 stable=0 equil=25 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=98 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.05 cad=94 reads=85 conv=25 osc=40 moving=10 stable=1 equil=9 improving=0 diverging=0 other=0 full=76 fosc=40 fquiet=35 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.05 cad=148 reads=54 conv=0 osc=34 moving=10 stable=6 equil=4 improving=0 diverging=0 other=0 full=45 fosc=34 fquiet=10 fnoclaim=1 fother=0
p3 unit=rad ac=1 sp=0.02 cad=74 reads=108 conv=97 osc=0 moving=10 stable=0 equil=1 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=98 fnoclaim=1 fother=0
p3 unit=rad ac=1 sp=0.02 cad=94 reads=85 conv=55 osc=16 moving=10 stable=0 equil=4 improving=0 diverging=0 other=0 full=76 fosc=16 fquiet=59 fnoclaim=1 fother=0
p3 unit=rad ac=1 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=10 stable=2 equil=8 improving=0 diverging=0 other=0 full=45 fosc=34 fquiet=10 fnoclaim=1 fother=0
p3 unit=rad ac=1 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=11 stable=65 equil=32 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=97 fnoclaim=2 fother=0
p3 unit=rad ac=1 sp=0.05 cad=94 reads=85 conv=0 osc=60 moving=10 stable=15 equil=0 improving=0 diverging=0 other=0 full=76 fosc=60 fquiet=15 fnoclaim=1 fother=0
p3 unit=rad ac=1 sp=0.05 cad=148 reads=54 conv=0 osc=35 moving=13 stable=6 equil=0 improving=0 diverging=0 other=0 full=45 fosc=35 fquiet=6 fnoclaim=4 fother=0
p3 unit=deg ac=0 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=108 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=99 fother=0
p3 unit=mrad ac=0 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=108 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=99 fother=0
p3 unit=deg ac=0 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=23 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
p3 unit=mrad ac=0 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=23 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
p3 unit=deg ac=0 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=11 fother=0
p3 unit=mrad ac=0 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=11 fother=0
p3 unit=deg ac=0 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=108 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=99 fother=0
p3 unit=mrad ac=0 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=108 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=99 fother=0
p3 unit=deg ac=0 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=23 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
p3 unit=mrad ac=0 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=23 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
p3 unit=deg ac=0 sp=0.05 cad=148 reads=54 conv=0 osc=34 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=11 fother=0
p3 unit=mrad ac=0 sp=0.05 cad=148 reads=54 conv=0 osc=34 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=11 fother=0
p3 unit=deg ac=1 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=108 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=99 fother=0
p3 unit=mrad ac=1 sp=0.02 cad=74 reads=108 conv=0 osc=0 moving=108 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=99 fother=0
p3 unit=deg ac=1 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=23 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
p3 unit=mrad ac=1 sp=0.02 cad=94 reads=85 conv=0 osc=62 moving=23 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
p3 unit=deg ac=1 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=11 fother=0
p3 unit=mrad ac=1 sp=0.02 cad=148 reads=54 conv=0 osc=34 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=34 fquiet=0 fnoclaim=11 fother=0
p3 unit=deg ac=1 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=108 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=99 fother=0
p3 unit=mrad ac=1 sp=0.05 cad=74 reads=108 conv=0 osc=0 moving=108 stable=0 equil=0 improving=0 diverging=0 other=0 full=99 fosc=0 fquiet=0 fnoclaim=99 fother=0
p3 unit=deg ac=1 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=23 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
p3 unit=mrad ac=1 sp=0.05 cad=94 reads=85 conv=0 osc=62 moving=23 stable=0 equil=0 improving=0 diverging=0 other=0 full=76 fosc=61 fquiet=0 fnoclaim=15 fother=0
p3 unit=deg ac=1 sp=0.05 cad=148 reads=54 conv=0 osc=35 moving=19 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=35 fquiet=0 fnoclaim=10 fother=0
p3 unit=mrad ac=1 sp=0.05 cad=148 reads=54 conv=0 osc=35 moving=19 stable=0 equil=0 improving=0 diverging=0 other=0 full=45 fosc=35 fquiet=0 fnoclaim=10 fother=0
p3 unit=rad ac=0 sp=0.05 cad=84 reads=95 conv=46 osc=23 moving=10 stable=0 equil=16 improving=0 diverging=0 other=0 full=86 fosc=23 fquiet=62 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.05 cad=104 reads=76 conv=12 osc=54 moving=10 stable=0 equil=0 improving=0 diverging=0 other=0 full=67 fosc=54 fquiet=12 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.05 cad=114 reads=70 conv=7 osc=53 moving=10 stable=0 equil=0 improving=0 diverging=0 other=0 full=61 fosc=53 fquiet=7 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.05 cad=124 reads=64 conv=0 osc=52 moving=10 stable=1 equil=1 improving=0 diverging=0 other=0 full=55 fosc=52 fquiet=2 fnoclaim=1 fother=0
p3 unit=rad ac=0 sp=0.05 cad=134 reads=59 conv=0 osc=35 moving=10 stable=8 equil=6 improving=0 diverging=0 other=0 full=50 fosc=35 fquiet=14 fnoclaim=1 fother=0
p3 unit=rad ac=1 sp=0.05 cad=84 reads=95 conv=0 osc=51 moving=11 stable=33 equil=0 improving=0 diverging=0 other=0 full=86 fosc=51 fquiet=33 fnoclaim=2 fother=0
p3 unit=rad ac=1 sp=0.05 cad=104 reads=76 conv=0 osc=66 moving=10 stable=0 equil=0 improving=0 diverging=0 other=0 full=67 fosc=66 fquiet=0 fnoclaim=1 fother=0
p3 unit=rad ac=1 sp=0.05 cad=114 reads=70 conv=0 osc=60 moving=10 stable=0 equil=0 improving=0 diverging=0 other=0 full=61 fosc=60 fquiet=0 fnoclaim=1 fother=0
p3 unit=rad ac=1 sp=0.05 cad=124 reads=64 conv=0 osc=51 moving=11 stable=2 equil=0 improving=0 diverging=0 other=0 full=55 fosc=51 fquiet=2 fnoclaim=2 fother=0
p3 unit=rad ac=1 sp=0.05 cad=134 reads=59 conv=0 osc=35 moving=22 stable=2 equil=0 improving=0 diverging=0 other=0 full=50 fosc=35 fquiet=2 fnoclaim=13 fother=0
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
p3n n=2 sp=0.05 cad=94 reads=170 alerts=100 per_ac_permille=588 sweeps=85 firing=60 fleet_permille=706 fsweeps=76 ffiring=60 ffleet_permille=789 first=10 last=84 per=[40, 60]
p3n n=4 sp=0.05 cad=94 reads=340 alerts=204 per_ac_permille=600 sweeps=85 firing=60 fleet_permille=706 fsweeps=76 ffiring=60 ffleet_permille=789 first=10 last=84 per=[40, 60, 60, 44]
p3n n=8 sp=0.05 cad=94 reads=680 alerts=384 per_ac_permille=565 sweeps=85 firing=60 fleet_permille=706 fsweeps=76 ffiring=60 ffleet_permille=789 first=10 last=84 per=[40, 60, 60, 44, 0, 60, 60, 60]
p3n n=16 sp=0.05 cad=94 reads=1360 alerts=708 per_ac_permille=521 sweeps=85 firing=60 fleet_permille=706 fsweeps=76 ffiring=60 ffleet_permille=789 first=10 last=84 per=[40, 60, 60, 44, 0, 60, 60, 60, 0, 40, 60, 60, 44, 0, 60, 60]
P3ROWS
grep -q '^p3 total reads across the sweep: 2964$' "$OUT" || { echo "FAIL: P3 sweep population changed"; exit 1; }
grep -q '^p3cad total full-window reads across the cadence sweep: 638$' "$OUT" || { echo "FAIL: P3 cadence-sweep population changed"; exit 1; }
grep -q '^p3ph total detections across the phase sweep: 3$' "$OUT" || { echo "FAIL: P3 phase-sweep population changed"; exit 1; }
# `other` is the residual for a label the driver does not model. Round 8's
# header claimed all seven classes and the chain implemented six (no
# `diverging` arm, no residual), so an unmodelled label vanished silently.
grep -E '^p3 unit=.* other=[1-9]|^p3 unit=.* fother=[1-9]' "$OUT" && { echo "FAIL: an unmodelled verdict label appeared in the residual"; exit 1; }
echo "PASS: P3's 66 pinned rows reproduce (4 physics truth, 46 verdict across 3 units and 8 cadences, 12 phase cells, 4 N-axis)"
