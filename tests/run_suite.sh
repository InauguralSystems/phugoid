#!/usr/bin/env bash
# The CI suite runner (hq#58 phug-s5): every tests/test_*.sh, verdict from
# each script's exit code, nothing skipped.
#
#   bash tests/run_suite.sh EXPECTED_COUNT [ROOT]
#
# Order: the non-timing scripts run in parallel ($JOBS at a time, default
# nproc), each into its own log; then the two timing-ratio gates run
# serially and alone, with nothing else on the box, because they measure
# wall-clock ratios (SM-PHUG-2). Every script runs even after a failure, so
# a red run names every failing script, not just the first.
#
# What makes this red:
#   - any script exits nonzero (named, with its rc and log);
#   - a script that was launched but left no rc record (named NOT RUN);
#   - the glob finds a count other than EXPECTED_COUNT (a dropped or
#     unglobbed script stays loud, as the inline loop's pin did);
#   - a name in SERIAL is missing from the glob (a renamed timing gate
#     would otherwise run in the parallel pool under load).
# tests/test_suite_runner.sh plants each of these and requires red.
set -uo pipefail

EXPECT="${1:?usage: run_suite.sh EXPECTED_COUNT [ROOT]}"
ROOT="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || { echo "FAIL: cannot cd to $ROOT"; exit 1; }
export EIGENSCRIPT="${EIGENSCRIPT:-eigenscript}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"

# Timing-ratio gates: measured alone, after the pool has drained.
SERIAL="tests/test_ap_profile.sh tests/test_swarm_profile.sh"
read -r -a SER <<< "$SERIAL"

ALL=(tests/test_*.sh)
[ -e "${ALL[0]}" ] || ALL=()
N=${#ALL[@]}
[ "$N" -eq "$EXPECT" ] || { echo "FAIL: expected exactly $EXPECT test scripts, found $N"; exit 1; }

PAR=()
for t in "${ALL[@]}"; do
    case " $SERIAL " in *" $t "*) ;; *) PAR+=("$t") ;; esac
done
for s in $SERIAL; do
    [ -f "$s" ] || { echo "FAIL: timing gate $s is not in the glob (renamed? it would no longer run alone)"; exit 1; }
done

LOGD=$(mktemp -d); trap 'rm -rf "$LOGD"' EXIT
export LOGD
# One record per script: "<rc> <seconds>". The wrapper always exits 0 so
# xargs never stops the pool early; the verdict is read from the records.
# START/DONE go to stdout live, so a hung script is named in the CI log
# while the pool is still running (the per-script logs print only after it
# drains, and the EXIT trap removes them).
run_one() {
    local t=$1 n s rc secs
    n=$(basename "$t" .sh); s=$(date +%s)
    echo "START $t"
    bash "$t" > "$LOGD/$n.log" 2>&1; rc=$?
    secs=$(( $(date +%s) - s ))
    echo "$rc $secs" > "$LOGD/$n.rc"
    echo "DONE $t rc=$rc (${secs}s)"
}
export -f run_one

T0=$(date +%s)
echo "=== parallel: ${#PAR[@]} scripts, $JOBS at a time"
printf '%s\0' "${PAR[@]}" | xargs -0 -n1 -P "$JOBS" bash -c 'run_one "$1"' _
T1=$(date +%s)
for t in "${PAR[@]}"; do
    echo "=== $t"
    cat "$LOGD/$(basename "$t" .sh).log" 2>/dev/null
done

echo "=== serial (timing gates, run alone): $SERIAL"
for t in $SERIAL; do
    echo "=== $t"
    run_one "$t"
    cat "$LOGD/$(basename "$t" .sh).log"
done
T2=$(date +%s)

echo "=== summary (parallel ${#PAR[@]} in $((T1-T0))s, serial ${#SER[@]} in $((T2-T1))s)"
FAILED=0
for t in "${PAR[@]}" $SERIAL; do
    r="$LOGD/$(basename "$t" .sh).rc"
    if [ ! -s "$r" ]; then
        echo "NOT RUN $t"; FAILED=$((FAILED+1)); continue
    fi
    read -r rc secs < "$r"
    if [ "$rc" -eq 0 ]; then
        echo "PASS $t (${secs}s)"
    else
        echo "FAIL $t rc=$rc (${secs}s)"; FAILED=$((FAILED+1))
    fi
done
[ "$FAILED" -eq 0 ] || { echo "FAIL: $FAILED of $N test scripts failed"; exit 1; }
echo "PASS: all $N test scripts"
