#!/usr/bin/env bash
# LINT GATE — every .eigs in the repo must pass `--lint` with no issues.
# (Fleet pattern; see dynamics for the failure that bought it: warnings sat
# unseen in the tree because nothing ran --lint.) A deliberate suppression
# is a `# lint: allow WNNN -- reason` comment, visible in review.
# Validated with a planted fault: an unused variable must be REJECTED.
set -euo pipefail

EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

lint_tree() {
    local dir="$1" quiet="${2:-}" bad=0 f out
    for f in "$dir"/*.eigs "$dir"/data/*.eigs "$dir"/tests/*.eigs; do
        [ -e "$f" ] || continue
        out=$("$EIGS" --lint "$f" 2>&1) || true
        if ! echo "$out" | grep -q "no issues found"; then
            [ -n "$quiet" ] || { echo "FAIL: $f"; echo "$out" | sed 's/^/    /'; }
            bad=1
        fi
    done
    return $bad
}

N=$(ls -1 ./*.eigs data/*.eigs tests/*.eigs 2>/dev/null | wc -l)
[ "$N" -ge 5 ] || { echo "FAIL: lint saw only $N files — glob broken"; exit 1; }
echo "--- --lint over $N .eigs files ---"
lint_tree "$ROOT" || exit 1
echo "PASS: all $N .eigs files lint clean"

echo "--- planted fault: an unused variable ---"
mkdir -p "$TMP/fault/data" "$TMP/fault/tests"
cp ./*.eigs "$TMP/fault/" 2>/dev/null || true
printf 'DEAD_CONSTANT is 42\nprint of "hi"\n' > "$TMP/fault/planted.eigs"
if lint_tree "$TMP/fault" quiet; then
    echo "FAIL: an unused variable passed the lint gate — the gate isn't running"
    exit 1
fi
echo "PASS: planted fault (unused variable) is caught"
