#!/usr/bin/env bash
# W1 must cover correct solves that converge more closely or from another basin-local start.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp -R "$ROOT/." "$WORK/repo"
rm -rf "$WORK/repo/.git" "$WORK/repo/evidence"
short_w1() {
  python3 - "$WORK/repo/tests/swarm_check.eigs" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1]);s=p.read_text()
if '# W2 —' in s: s=s[:s.index('# W2 —')]+ '\nprint of f"FAILURES {failures}"\n'
p.write_text(s)
PY
  (cd "$WORK/repo" && "$EIGS" tests/swarm_check.eigs)
}
# Control A: a correct solve takes the extra Newton step that exposed the missing stored-root term.
sed 's/rmag < 1e-13/rmag < 1e-15/' "$ROOT/sim.eigs" > "$WORK/repo/sim.eigs"
out=$(short_w1); printf '%s\n' "$out" | grep '^W1_ALLOWANCES '; printf '%s\n' "$out" | grep -q '^FAILURES 0$'
echo 'PASS: W1 covers the 1e-15 converged solve'
# The AP manifest consumes exactly this W1 allowance; its complete identity gate must stay green.
ap=$(cd "$WORK/repo" && EIGENSCRIPT="$EIGS" bash tests/test_ap_planted.sh --identity-only)
printf '%s\n' "$ap" | grep '^PASS: run-parameter set matches manifest under W1 allowance$'
echo 'PASS: AP input identity accepts the 1e-15 converged solve'
# Control B: the same correct root approached from the independent review's start.
cp "$ROOT/sim.eigs" "$WORK/repo/sim.eigs"
python3 - "$WORK/repo/sim.eigs" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1]);s=p.read_text();s=s.replace('local x is [0.0, 0.0, 0.0]','local x is [0.0 - 0.05, 0.01, 1000.0]',1);p.write_text(s)
PY
out=$(short_w1); printf '%s\n' "$out" | grep '^W1_ALLOWANCES '; printf '%s\n' "$out" | grep -q '^FAILURES 0$'
echo 'PASS: W1 covers the [-0.05, 0.01, 1000] start'
