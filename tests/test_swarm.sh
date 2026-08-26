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
    grep -qxF "$want" "$OUT" || { echo "FAIL: P3 row drifted: $want"; grep -E '^p3(truth| unit=|n )' "$OUT"; exit 1; }
done <<'P3ROWS'
p3truth ac=0 sp=0.02 u_pp_first=337 u_pp_last=181 q_pp_first=1057 q_pp_last=103
p3truth ac=0 sp=0.05 u_pp_first=844 u_pp_last=452 q_pp_first=2643 q_pp_last=257
p3truth ac=1 sp=0.02 u_pp_first=656 u_pp_last=352 q_pp_first=2055 q_pp_last=200
p3truth ac=1 sp=0.05 u_pp_first=1641 u_pp_last=880 q_pp_first=5134 q_pp_last=501
p3 unit=rad ac=0 sp=0.02 cad=74 reads=109 conv=98 osc=0 moving=10 stable=1 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=98 fnoclaim=2
p3 unit=rad ac=0 sp=0.02 cad=94 reads=86 conv=75 osc=0 moving=10 stable=1 equil=0 improving=0 diverging=0 other=0 full=77 fosc=0 fquiet=75 fnoclaim=2
p3 unit=rad ac=0 sp=0.02 cad=148 reads=55 conv=44 osc=0 moving=0 stable=11 equil=0 improving=0 diverging=0 other=0 full=46 fosc=0 fquiet=46 fnoclaim=0
p3 unit=rad ac=0 sp=0.05 cad=74 reads=109 conv=73 osc=0 moving=10 stable=1 equil=25 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=98 fnoclaim=2
p3 unit=rad ac=0 sp=0.05 cad=94 reads=86 conv=25 osc=40 moving=10 stable=2 equil=9 improving=0 diverging=0 other=0 full=77 fosc=40 fquiet=35 fnoclaim=2
p3 unit=rad ac=0 sp=0.05 cad=148 reads=55 conv=0 osc=35 moving=10 stable=7 equil=3 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=9 fnoclaim=2
p3 unit=rad ac=1 sp=0.02 cad=74 reads=109 conv=97 osc=0 moving=10 stable=1 equil=1 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=98 fnoclaim=2
p3 unit=rad ac=1 sp=0.02 cad=94 reads=86 conv=55 osc=16 moving=10 stable=1 equil=4 improving=0 diverging=0 other=0 full=77 fosc=16 fquiet=59 fnoclaim=2
p3 unit=rad ac=1 sp=0.02 cad=148 reads=55 conv=0 osc=35 moving=10 stable=3 equil=7 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=9 fnoclaim=2
p3 unit=rad ac=1 sp=0.05 cad=74 reads=109 conv=0 osc=0 moving=11 stable=66 equil=32 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=97 fnoclaim=3
p3 unit=rad ac=1 sp=0.05 cad=94 reads=86 conv=0 osc=60 moving=10 stable=16 equil=0 improving=0 diverging=0 other=0 full=77 fosc=60 fquiet=15 fnoclaim=2
p3 unit=rad ac=1 sp=0.05 cad=148 reads=55 conv=0 osc=35 moving=13 stable=7 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=6 fnoclaim=5
p3 unit=deg ac=0 sp=0.02 cad=74 reads=109 conv=0 osc=0 moving=108 stable=1 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=0 fnoclaim=100
p3 unit=mrad ac=0 sp=0.02 cad=74 reads=109 conv=0 osc=0 moving=109 stable=0 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=0 fnoclaim=100
p3 unit=deg ac=0 sp=0.02 cad=94 reads=86 conv=0 osc=62 moving=23 stable=1 equil=0 improving=0 diverging=0 other=0 full=77 fosc=62 fquiet=0 fnoclaim=15
p3 unit=mrad ac=0 sp=0.02 cad=94 reads=86 conv=0 osc=62 moving=24 stable=0 equil=0 improving=0 diverging=0 other=0 full=77 fosc=62 fquiet=0 fnoclaim=15
p3 unit=deg ac=0 sp=0.02 cad=148 reads=55 conv=0 osc=35 moving=19 stable=1 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=0 fnoclaim=11
p3 unit=mrad ac=0 sp=0.02 cad=148 reads=55 conv=0 osc=35 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=0 fnoclaim=11
p3 unit=deg ac=0 sp=0.05 cad=74 reads=109 conv=0 osc=0 moving=109 stable=0 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=0 fnoclaim=100
p3 unit=mrad ac=0 sp=0.05 cad=74 reads=109 conv=0 osc=0 moving=109 stable=0 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=0 fnoclaim=100
p3 unit=deg ac=0 sp=0.05 cad=94 reads=86 conv=0 osc=62 moving=24 stable=0 equil=0 improving=0 diverging=0 other=0 full=77 fosc=62 fquiet=0 fnoclaim=15
p3 unit=mrad ac=0 sp=0.05 cad=94 reads=86 conv=0 osc=62 moving=24 stable=0 equil=0 improving=0 diverging=0 other=0 full=77 fosc=62 fquiet=0 fnoclaim=15
p3 unit=deg ac=0 sp=0.05 cad=148 reads=55 conv=0 osc=35 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=0 fnoclaim=11
p3 unit=mrad ac=0 sp=0.05 cad=148 reads=55 conv=0 osc=35 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=0 fnoclaim=11
p3 unit=deg ac=1 sp=0.02 cad=74 reads=109 conv=0 osc=0 moving=109 stable=0 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=0 fnoclaim=100
p3 unit=mrad ac=1 sp=0.02 cad=74 reads=109 conv=0 osc=0 moving=109 stable=0 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=0 fnoclaim=100
p3 unit=deg ac=1 sp=0.02 cad=94 reads=86 conv=0 osc=62 moving=24 stable=0 equil=0 improving=0 diverging=0 other=0 full=77 fosc=62 fquiet=0 fnoclaim=15
p3 unit=mrad ac=1 sp=0.02 cad=94 reads=86 conv=0 osc=62 moving=24 stable=0 equil=0 improving=0 diverging=0 other=0 full=77 fosc=62 fquiet=0 fnoclaim=15
p3 unit=deg ac=1 sp=0.02 cad=148 reads=55 conv=0 osc=35 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=0 fnoclaim=11
p3 unit=mrad ac=1 sp=0.02 cad=148 reads=55 conv=0 osc=35 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=0 fnoclaim=11
p3 unit=deg ac=1 sp=0.05 cad=74 reads=109 conv=0 osc=0 moving=109 stable=0 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=0 fnoclaim=100
p3 unit=mrad ac=1 sp=0.05 cad=74 reads=109 conv=0 osc=0 moving=109 stable=0 equil=0 improving=0 diverging=0 other=0 full=100 fosc=0 fquiet=0 fnoclaim=100
p3 unit=deg ac=1 sp=0.05 cad=94 reads=86 conv=0 osc=62 moving=24 stable=0 equil=0 improving=0 diverging=0 other=0 full=77 fosc=62 fquiet=0 fnoclaim=15
p3 unit=mrad ac=1 sp=0.05 cad=94 reads=86 conv=0 osc=62 moving=24 stable=0 equil=0 improving=0 diverging=0 other=0 full=77 fosc=62 fquiet=0 fnoclaim=15
p3 unit=deg ac=1 sp=0.05 cad=148 reads=55 conv=0 osc=35 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=0 fnoclaim=11
p3 unit=mrad ac=1 sp=0.05 cad=148 reads=55 conv=0 osc=35 moving=20 stable=0 equil=0 improving=0 diverging=0 other=0 full=46 fosc=35 fquiet=0 fnoclaim=11
p3 unit=rad ac=0 sp=0.05 cad=84 reads=96 conv=46 osc=23 moving=10 stable=1 equil=16 improving=0 diverging=0 other=0 full=87 fosc=23 fquiet=62 fnoclaim=2
p3 unit=rad ac=0 sp=0.05 cad=104 reads=77 conv=12 osc=54 moving=10 stable=1 equil=0 improving=0 diverging=0 other=0 full=68 fosc=54 fquiet=12 fnoclaim=2
p3 unit=rad ac=0 sp=0.05 cad=114 reads=71 conv=7 osc=53 moving=10 stable=1 equil=0 improving=0 diverging=0 other=0 full=62 fosc=53 fquiet=7 fnoclaim=2
p3 unit=rad ac=0 sp=0.05 cad=124 reads=65 conv=0 osc=52 moving=10 stable=2 equil=1 improving=0 diverging=0 other=0 full=56 fosc=52 fquiet=2 fnoclaim=2
p3 unit=rad ac=0 sp=0.05 cad=134 reads=60 conv=0 osc=35 moving=10 stable=9 equil=6 improving=0 diverging=0 other=0 full=51 fosc=35 fquiet=14 fnoclaim=2
p3 unit=rad ac=1 sp=0.05 cad=84 reads=96 conv=0 osc=51 moving=11 stable=34 equil=0 improving=0 diverging=0 other=0 full=87 fosc=51 fquiet=33 fnoclaim=3
p3 unit=rad ac=1 sp=0.05 cad=104 reads=77 conv=0 osc=66 moving=10 stable=1 equil=0 improving=0 diverging=0 other=0 full=68 fosc=66 fquiet=0 fnoclaim=2
p3 unit=rad ac=1 sp=0.05 cad=114 reads=71 conv=0 osc=60 moving=10 stable=1 equil=0 improving=0 diverging=0 other=0 full=62 fosc=60 fquiet=0 fnoclaim=2
p3 unit=rad ac=1 sp=0.05 cad=124 reads=65 conv=0 osc=51 moving=11 stable=3 equil=0 improving=0 diverging=0 other=0 full=56 fosc=51 fquiet=2 fnoclaim=3
p3 unit=rad ac=1 sp=0.05 cad=134 reads=60 conv=0 osc=35 moving=24 stable=1 equil=0 improving=0 diverging=0 other=0 full=51 fosc=35 fquiet=0 fnoclaim=16
p3n n=2 sp=0.05 cad=94 reads=172 alerts=100 per_ac_permille=581 sweeps=86 firing=60 fleet_permille=698 fsweeps=77 ffiring=60 ffleet_permille=779 first=11 last=85 per=[40, 60]
p3n n=4 sp=0.05 cad=94 reads=344 alerts=204 per_ac_permille=593 sweeps=86 firing=60 fleet_permille=698 fsweeps=77 ffiring=60 ffleet_permille=779 first=11 last=85 per=[40, 60, 60, 44]
p3n n=8 sp=0.05 cad=94 reads=688 alerts=384 per_ac_permille=558 sweeps=86 firing=60 fleet_permille=698 fsweeps=77 ffiring=60 ffleet_permille=779 first=11 last=85 per=[40, 60, 60, 44, 0, 60, 60, 60]
p3n n=16 sp=0.05 cad=94 reads=1376 alerts=708 per_ac_permille=515 sweeps=86 firing=60 fleet_permille=698 fsweeps=77 ffiring=60 ffleet_permille=779 first=11 last=85 per=[40, 60, 60, 44, 0, 60, 60, 60, 0, 40, 60, 60, 44, 0, 60, 60]
P3ROWS
grep -q '^p3 total reads across the sweep: 3000$' "$OUT" || { echo "FAIL: P3 sweep population changed"; exit 1; }
grep -q '^p3cad total full-window reads across the cadence sweep: 648$' "$OUT" || { echo "FAIL: P3 cadence-sweep population changed"; exit 1; }
# `other` is the residual for a label the driver does not model. Round 8's
# header claimed all seven classes and the chain implemented six (no
# `diverging` arm, no residual), so an unmodelled label vanished silently.
grep -E '^p3 unit=.* other=[1-9]' "$OUT" && { echo "FAIL: an unmodelled verdict label appeared in the residual"; exit 1; }
echo "PASS: P3's 54 pinned rows reproduce (4 physics truth, 46 verdict across 3 units and 8 cadences, 4 N-axis)"
