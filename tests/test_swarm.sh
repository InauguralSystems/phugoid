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
NP3=$(grep -c '^p3 ac=' "$OUT" || true)
[ "$NP3" = "12" ] || { echo "FAIL: P3 sweep produced $NP3 rows, expected 12"; exit 1; }
NT=$(grep -c '^p3truth ac=' "$OUT" || true)
[ "$NT" = "4" ] || { echo "FAIL: P3 truth table produced $NT rows, expected 4"; exit 1; }
while read -r want; do
    grep -qxF "$want" "$OUT" || { echo "FAIL: P3 row drifted: $want"; grep -E '^p3(truth| ac=|n )' "$OUT"; exit 1; }
done <<'P3ROWS'
p3truth ac=0 sp=0.02 u_pp_first=337 u_pp_last=181 q_pp_first=1057 q_pp_last=103
p3truth ac=0 sp=0.05 u_pp_first=844 u_pp_last=452 q_pp_first=2643 q_pp_last=257
p3truth ac=1 sp=0.02 u_pp_first=656 u_pp_last=352 q_pp_first=2055 q_pp_last=200
p3truth ac=1 sp=0.05 u_pp_first=1641 u_pp_last=880 q_pp_first=5134 q_pp_last=501
p3 ac=0 sp=0.02 cad=74 reads=109 conv=98 osc=1 moving=9 stable=1 equil=0 improving=0 diverging=0 other=0 div=108
p3 ac=0 sp=0.02 cad=94 reads=86 conv=75 osc=1 moving=9 stable=1 equil=0 improving=0 diverging=0 other=0 div=85
p3 ac=0 sp=0.02 cad=148 reads=55 conv=44 osc=1 moving=0 stable=10 equil=0 improving=0 diverging=0 other=0 div=54
p3 ac=0 sp=0.05 cad=74 reads=109 conv=73 osc=1 moving=10 stable=0 equil=25 improving=0 diverging=0 other=0 div=108
p3 ac=0 sp=0.05 cad=94 reads=86 conv=25 osc=41 moving=10 stable=1 equil=9 improving=0 diverging=0 other=0 div=45
p3 ac=0 sp=0.05 cad=148 reads=55 conv=0 osc=36 moving=10 stable=6 equil=3 improving=0 diverging=0 other=0 div=19
p3 ac=1 sp=0.02 cad=74 reads=109 conv=97 osc=1 moving=10 stable=0 equil=1 improving=0 diverging=0 other=0 div=108
p3 ac=1 sp=0.02 cad=94 reads=86 conv=55 osc=17 moving=10 stable=0 equil=4 improving=0 diverging=0 other=0 div=69
p3 ac=1 sp=0.02 cad=148 reads=55 conv=0 osc=36 moving=10 stable=2 equil=7 improving=0 diverging=0 other=0 div=19
p3 ac=1 sp=0.05 cad=74 reads=109 conv=0 osc=1 moving=11 stable=65 equil=32 improving=0 diverging=0 other=0 div=108
p3 ac=1 sp=0.05 cad=94 reads=86 conv=0 osc=61 moving=10 stable=15 equil=0 improving=0 diverging=0 other=0 div=25
p3 ac=1 sp=0.05 cad=148 reads=55 conv=0 osc=36 moving=13 stable=6 equil=0 improving=0 diverging=0 other=0 div=19
p3n n=2 sp=0.05 cad=94 reads=172 alerts=102 per_ac_permille=593 sweeps=86 firing=61 fleet_permille=709 first=9 last=85 per=[41, 61]
p3n n=4 sp=0.05 cad=94 reads=344 alerts=208 per_ac_permille=605 sweeps=86 firing=61 fleet_permille=709 first=9 last=85 per=[41, 61, 61, 45]
p3n n=8 sp=0.05 cad=94 reads=688 alerts=392 per_ac_permille=570 sweeps=86 firing=61 fleet_permille=709 first=9 last=85 per=[41, 61, 61, 45, 1, 61, 61, 61]
p3n n=16 sp=0.05 cad=94 reads=1376 alerts=724 per_ac_permille=526 sweeps=86 firing=61 fleet_permille=709 first=9 last=85 per=[41, 61, 61, 45, 1, 61, 61, 61, 1, 41, 61, 61, 45, 1, 61, 61]
P3ROWS
grep -q '^p3 total reads across the sweep: 1000$' "$OUT" || { echo "FAIL: P3 sweep population changed"; exit 1; }
# `other` is the residual for a label the driver does not model. Round 8's
# header claimed all seven classes and the chain implemented six (no
# `diverging` arm, no residual), so an unmodelled label vanished silently.
grep -E '^p3 .* other=[1-9]' "$OUT" && { echo "FAIL: an unmodelled verdict label appeared in the residual"; exit 1; }
echo "PASS: P3's sixteen pinned rows reproduce (4 physics truth, 12 verdict, 4 N-axis)"
