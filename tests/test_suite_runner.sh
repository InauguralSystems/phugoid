#!/usr/bin/env bash
# Planted faults for tests/run_suite.sh (hq#58 phug-s5), the runner CI uses.
# A parallel runner can lie in ways the serial `set -e` loop could not: a
# failing script's rc lost in the pool, a script never launched, a timing
# gate sharing the box with the pool. Each plant below builds a stub tree,
# runs the REAL runner on it, and requires the exact verdict.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tests/run_suite.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
export JOBS=2

# Stub tree: two pool scripts that must overlap (each waits, bounded, for
# the other to be running), and the two named timing gates, which fail if
# any pool script, or the other gate, is still running when they start.
mktree() {
    local d="$WORK/$1"
    rm -rf "$d"; mkdir -p "$d/tests" "$d/run"
    for n in a b; do
        o=$([ "$n" = a ] && echo b || echo a)
        cat > "$d/tests/test_pool_$n.sh" <<EOF
#!/usr/bin/env bash
cd "\$(dirname "\$0")/.."
touch run/pool_$n
for i in \$(seq 1 50); do [ -e run/pool_$o ] || [ -e run/done_$o ] && break; sleep 0.1; done
[ -e run/pool_$o ] || [ -e run/done_$o ] || { echo "pool_$n ran alone: the pool is not parallel"; rm -f run/pool_$n; exit 7; }
sleep 0.3
rm -f run/pool_$n; touch run/done_$n
echo "pool_$n ok"
EOF
    done
    for n in ap swarm; do
        cat > "$d/tests/test_${n}_profile.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/.."
ls run | grep -q '^pool_\|^timing_' && { echo "timing gate shares the box: $(ls run)"; exit 8; }
touch "run/timing_$$"; sleep 0.2; rm -f "run/timing_$$"
echo "timing ok"
EOF
    done
    echo "$d"
}

PASS=0
run() {  # run <tree> <expect> -> sets RC, output in $WORK/out
    set +e; bash "$RUNNER" "$2" "$1" > "$WORK/out" 2>&1; RC=$?; set -e
}
must_red() {  # must_red <label> <anchored line regex>...
    local label=$1; shift
    [ "$RC" -ne 0 ] || { echo "FAIL: $label: runner exited 0"; cat "$WORK/out"; exit 1; }
    for re in "$@"; do
        grep -Eqx "$re" "$WORK/out" || { echo "FAIL: $label: no line matching '$re'"; cat "$WORK/out"; exit 1; }
    done
    echo "ok  $label (rc=$RC)"; PASS=$((PASS+1))
}

echo "--- R0: clean stub tree -> green, pool parallel, timing gates alone ---"
T=$(mktree clean); run "$T" 4
[ "$RC" -eq 0 ] || { echo "FAIL: R0: clean tree is red (rc=$RC)"; cat "$WORK/out"; exit 1; }
for re in 'PASS tests/test_pool_a\.sh \([0-9]+s\)' 'PASS tests/test_pool_b\.sh \([0-9]+s\)' \
          'PASS tests/test_ap_profile\.sh \([0-9]+s\)' 'PASS tests/test_swarm_profile\.sh \([0-9]+s\)' \
          'PASS: all 4 test scripts' 'START tests/test_pool_a\.sh' \
          'DONE tests/test_pool_b\.sh rc=0 \([0-9]+s\)' 'DONE tests/test_swarm_profile\.sh rc=0 \([0-9]+s\)' \
          '=== summary \(parallel 2 in [0-9]+s, serial 2 in [0-9]+s\)'; do
    grep -Eqx "$re" "$WORK/out" || { echo "FAIL: R0: no line matching '$re'"; cat "$WORK/out"; exit 1; }
done
echo "ok  R0 (rc=0)"; PASS=$((PASS+1))

echo "--- R1: one pool script fails -> red, named with its rc, the rest still run ---"
T=$(mktree r1); printf 'echo planted; exit 3\n' >> "$T/tests/test_pool_b.sh"
run "$T" 4
must_red R1 'FAIL tests/test_pool_b\.sh rc=3 \([0-9]+s\)' 'PASS tests/test_pool_a\.sh \([0-9]+s\)' \
    'PASS tests/test_swarm_profile\.sh \([0-9]+s\)' 'FAIL: 1 of 4 test scripts failed'

echo "--- R2: a timing gate fails -> red, named ---"
T=$(mktree r2); printf 'exit 5\n' >> "$T/tests/test_ap_profile.sh"
run "$T" 4
must_red R2 'FAIL tests/test_ap_profile\.sh rc=5 \([0-9]+s\)' 'FAIL: 1 of 4 test scripts failed'

echo "--- R3: a pool script dies with its wrapper (no rc record) -> NOT RUN, red ---"
T=$(mktree r3); f="$T/tests/test_pool_a.sh"
{ head -n 1 "$f"; echo 'kill -9 $PPID'; tail -n +2 "$f"; } > "$f.new" && mv "$f.new" "$f"
run "$T" 4
must_red R3 'NOT RUN tests/test_pool_a\.sh'

echo "--- R4: a script dropped from the glob -> the count pin is red ---"
T=$(mktree r4); rm "$T/tests/test_pool_b.sh"
run "$T" 4
must_red R4 'FAIL: expected exactly 4 test scripts, found 3'

echo "--- R5: a timing gate renamed (count kept) -> red, not silently pooled ---"
T=$(mktree r5); mv "$T/tests/test_ap_profile.sh" "$T/tests/test_ap_prof.sh"
run "$T" 4
must_red R5 'FAIL: timing gate tests/test_ap_profile\.sh is not in the glob .*'

echo "--- R6: a pool script still running when the timing gates start -> red ---"
T=$(mktree r6); printf '#!/usr/bin/env bash\ncd "$(dirname "$0")/.."\ntouch run/pool_bg run/done_c\n(sleep 3; rm -f run/pool_bg) >/dev/null 2>&1 &\nexit 0\n' > "$T/tests/test_pool_c.sh"
rm "$T/tests/test_pool_b.sh"; f="$T/tests/test_pool_a.sh"
sed 's/pool_b/pool_c/g; s/done_b/done_c/g' "$f" > "$f.new" && mv "$f.new" "$f"
run "$T" 4
must_red R6 'FAIL tests/test_(ap|swarm)_profile\.sh rc=8 \([0-9]+s\)'

[ "$PASS" -eq 7 ] || { echo "FAIL: expected 7 runner verdicts, got $PASS"; exit 1; }
echo "PASS: run_suite.sh: 7 verdicts (1 green, 6 planted reds)"
