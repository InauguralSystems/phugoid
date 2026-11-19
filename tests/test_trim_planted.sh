#!/usr/bin/env bash
# One-unit plants in both directions at the 4th, 8th and 12th significant
# digit of every W1 stored constant. All mutation stays in a temporary copy.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

python3 - "$ROOT" "$WORK" <<'PY'
import pathlib, sys
root, work = map(pathlib.Path, sys.argv[1:])
text = (root/'tests/swarm_check.eigs').read_text()
for name in ('data/b747_approach.eigs','swarm.eigs','tests/checklib.eigs','measure.eigs','modes.eigs','tests/trim_allowance.eigs'):
    text=text.replace(f'load_file of "{name}"', f'load_file of "{root/name}"')
text=text.replace('load_file of "swarm_unarmed.eigs"', f'load_file of "{work}/swarm_unarmed.eigs"')
# Exercise the shipped W1 block without spending each of the 19 fault-matrix
# runs on the unrelated long swarm trajectories below W1.
text=text[:text.index('# W2 —')] + '\nprint of f"CHECKS_RUN {checks_run}"\nprint of f"FAILURES {failures}"\n'
(work/'swarm_check.eigs').write_text(text)
u=(root/'swarm_unarmed.eigs').read_text()
for name in ('data/b747_approach.eigs','sim_core.eigs'):
    u=u.replace(f'load_file of "{name}"', f'load_file of "{root/name}"')
(work/'swarm_unarmed.clean.eigs').write_text(u)
PY

cp "$WORK/swarm_unarmed.clean.eigs" "$WORK/swarm_unarmed.eigs"
if ! "$EIGS" "$WORK/swarm_check.eigs" >"$WORK/out" 2>&1 || ! grep -q '^FAILURES 0$' "$WORK/out"; then
    echo "FAIL: clean control did not pass"; tail -10 "$WORK/out"; exit 1
fi
echo "PASS: clean control"

examined=0
caught_set=""
under_set=""
while read -r field digit delta check; do
    for direction in plus minus; do
        signed=$delta
        [ "$direction" = minus ] && signed="-$delta"
        cp "$WORK/swarm_unarmed.clean.eigs" "$WORK/swarm_unarmed.eigs"
        python3 - "$WORK/swarm_unarmed.eigs" "$field" "$signed" <<'PYPLANT'
from decimal import Decimal
import pathlib, re, sys
p, field, delta = pathlib.Path(sys.argv[1]), sys.argv[2], Decimal(sys.argv[3])
s=p.read_text()
patterns={'trim0':r'279\.09999958677514','trim1':r'0\.015187564279792735','trim2':r'(?<=, )0\.0(?=, 0\.0 - 5\.441621027333612e-05)','trim3':r'5\.441621027333612e-05','de':r'5\.274186534184886e-05','thrust':r'51919\.293822831365'}
m=re.search(patterns[field],s); assert m,field
s=s[:m.start()]+str(Decimal(m.group())+delta)+s[m.end():]
p.write_text(s)
PYPLANT
        "$EIGS" "$WORK/swarm_check.eigs" >"$WORK/out" 2>&1 || true
        line=$(grep "^[A-Z]* $check " "$WORK/out")
        allowance=$(printf '%s\n' "$line" | sed 's/.*below=\([^ ]*\).*/\1/')
        difference=$(printf '%s\n' "$line" | sed 's/.*val=//; s/^-//')
        id="$field.$digit.$direction"
        if printf '%s\n' "$line" | grep -q '^FAIL '; then
            status=CAUGHT; caught_set="$caught_set $id"
        else
            status=UNDER; under_set="$under_set $id"
        fi
        echo "$id allowance=$allowance difference=$difference $status"
        examined=$((examined+1))
    done
done <<'PLANTS'
trim0 4 0.1 W1.trim0
trim0 8 0.00001 W1.trim0
trim0 12 0.000000001 W1.trim0
trim1 4 0.00001 W1.trim1
trim1 8 0.000000001 W1.trim1
trim1 12 0.0000000000001 W1.trim1
trim2 4 0.000001 W1.trim2
trim2 8 0.0000000001 W1.trim2
trim2 12 0.00000000000001 W1.trim2
trim3 4 0.00000001 W1.trim3
trim3 8 0.000000000001 W1.trim3
trim3 12 0.0000000000000001 W1.trim3
de 4 0.00000001 W1.de
de 8 0.000000000001 W1.de
de 12 0.0000000000000001 W1.de
thrust 4 10 W1.thrust
thrust 8 0.001 W1.thrust
thrust 12 0.0000001 W1.thrust
PLANTS
[ "$examined" -eq 36 ] || { echo "FAIL: examined=$examined"; exit 1; }
expected_under="de.12.minus de.12.plus trim3.12.minus trim3.12.plus"
actual_under=$(printf '%s\n' $under_set | sort | tr '\n' ' ' | sed 's/ $//')
expected=$(printf '%s\n' $expected_under | sort | tr '\n' ' ' | sed 's/ $//')
[ "$actual_under" = "$expected" ] || { echo "FAIL: UNDER set drifted: $actual_under"; exit 1; }
[ "$(printf '%s\n' $caught_set | wc -l | tr -d ' ')" -eq 32 ] || { echo "FAIL: caught set drifted"; exit 1; }
echo "examined=36 caught=32 under=4"
echo "PASS: exact bidirectional stored-trim plant sets"
