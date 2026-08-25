#!/usr/bin/env bash
# Rung-3 C6: the observer READ-path profile (ORACLE.md).
#
# Claim under test: on the autopilot shape the observer's cost is
# dominated by the READ path (verdict polling), not the WRITE path
# (entropy bookkeeping per assignment) — which is why EigenScript#915's
# gate, which targets writes, cannot help this consumer.
#
# The gate is a RATIO with margin, not an absolute time: absolute budgets
# are unreliable on shared CI runners, whereas the read/write ratio is a
# property of the runtime. Measured 2026-08-25 on the dev box, n=5 medians
# over this program's 120k frames: read 0.501s, write 0.243s, floor 0.169s.
#   read/write  = 2.06   -> the bound below is 1.5 (~23% margin)
#   write/floor = 1.44   -> the observed WRITE path is not free either
#   of the 0.332s of observer cost, 78% is reads and 22% is writes
# CORRECTION (round-1 review): an earlier ad-hoc probe reported "observed
# scalar writes are essentially free (0.31s vs a 0.30s floor)". That does
# NOT reproduce on the shipped program — writes cost +44% over the floor.
# The number published first was wrong; these are the ones this gate uses.
set -euo pipefail
EIGS="${EIGENSCRIPT:-eigenscript}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Portable timer: `date +%s%N`, NOT /usr/bin/time. The first version of
# this script used /usr/bin/time, which exists on the dev box but is not
# installed in the devcontainer — CI died with exit 127 while all 14
# suites were green locally. No other script in this repo needs an
# external binary; this one must not either.
med() {  # median of 5 wall-clock seconds for one variant. Round-2 review
         # caught a median-of-3 write/floor pair reading 0.96 — below the
         # 1.15 bound — on UNMUTATED code. Three samples is not enough
         # insulation for a 20% margin on a shared runner; five is.
    for _ in 1 2 3 4 5; do
        local t0 t1
        t0=$(date +%s%N)
        "$EIGS" tests/ap_profile.eigs "$1" >/dev/null 2>&1
        t1=$(date +%s%N)
        awk -v a="$t0" -v b="$t1" 'BEGIN{ printf "%.3f\n", (b-a)/1000000000 }'
    done | sort -n | sed -n 3p
}
# Bounds live in ONE place each. Round 4 found the gate comparing against
# a literal while its planted fault cited a second copy: editing only the
# gate's bound to 0.4 left the whole suite green, with the gate accepting
# a runtime where reads cost LESS than writes. A gate and the fault that
# validates it must share the constant.
RW_BOUND=1.5
WF_BOUND=1.15
# A CEILING on write/floor, added at round 8. The read/write ratio
# deliberately has none (load INFLATES it -- 3.38 measured on unmutated
# code), but load DEFLATES write/floor (0.98 measured at round 7), so a
# ceiling here cannot flake in the direction load pushes. It catches the
# floor collapsing, which is how every fabrication of this ratio so far
# has presented.
WF_CEIL=3.0

# The bounds are DATA and get the manifest treatment every tolerance
# argument in this repo gets. Round-5 review widened both literals
# (1.5 -> 1.05, 1.15 -> 1.02) and the suite stayed green, because each
# bound's planted fault sits at ratio 1.00 — the very bottom of the
# rejection region — so the entire margin the bound buys was unexercised
# and the value itself was free. A bound-derived plant cannot fix this
# (it tracks the widening); the declared value has to be pinned.
[ "$RW_BOUND" = "1.5" ]  || { echo "FAIL: RW_BOUND is $RW_BOUND, declared 1.5 — a widened bound must be re-justified in ORACLE.md, not edited in place"; exit 1; }
[ "$WF_CEIL" = "3.0" ]   || { echo "FAIL: WF_CEIL is $WF_CEIL, declared 3.0 — a widened bound must be re-justified in ORACLE.md, not edited in place"; exit 1; }
[ "$WF_BOUND" = "1.15" ] || { echo "FAIL: WF_BOUND is $WF_BOUND, declared 1.15 — a widened bound must be re-justified in ORACLE.md, not edited in place"; exit 1; }

# check_ratio <label> <value> <bound> -> 0 if value > bound
check_ratio() {
    awk -v x="$2" -v b="$3" 'BEGIN{ exit !(x > b) }'
}

echo "--- ap_profile (C6: observer read-path cost) ---"
# Pin the WORK each variant executes, not merely that it printed. Round-5
# review halved run_floor's loop: the gate reported "120k frames" while a
# third of the measurement ran 60k, turned write/floor from 1.51 into
# 2.52 — a GREENER number — and every suite stayed green, because the
# greps matched only the line prefix. This is the repo's own rule (a gate
# that silently measures LESS still prints OK) applied to the one
# measurement whose executed population was not pinned.
#
# The hit total is not enough on its own. Round-6 review measured the
# per-predicate split -- osc(u)=0, conv(w)=11563, stable(q)=65157,
# div(th)=56566 -- so `oscillating of u` contributes NOTHING to 133286.
# Deleting it (read path -25%, ratio 1.98 -> 1.67, below anything measured
# on unmutated code) and adding three more copies of it (+75%,
# ratio -> 2.91) both left the pin matching and the whole suite green.
# A hit count cannot pin a zero-hit read, so the read POPULATION is pinned
# structurally too, against the source.
#
# Round-7 review then showed BOTH of those layers bind something other
# than the executed loop body, and that round 6 fixed only run_read while
# run_write and run_floor kept the counter-only pin (the repo's own
# twin-the-fix rule, broken by the fix for the finding that motivated it):
#   * deleting TWO of run_floor's four per-frame writes left `floor 120000`
#     matching, collapsed the floor 45%, and turned write/floor from 1.44
#     into 2.59 -- round 5's defect through the other door, halving the
#     WORK instead of the count;
#   * moving the zero-hit read OUT of run_read's loop and into run_write
#     left the site count and the hit total matching, at ratio 1.70;
#   * `if not (oscillating of q):` adds a read the anchored grep cannot
#     see at all -- as can `elif`, `while`, and `x is converged of u`.
# So the measured loop bodies are pinned by IDENTITY, the way every other
# tolerance argument in this repo is. Comment and blank lines are stripped
# first (they do not change the work); anything else that edits a measured
# body fails loudly and demands a re-measure. Note the strip is by LINE: a
# comment appended to a code line still reds the gate. That is the
# fail-safe direction, but it is not what "comments are ignored" implies.
body_hash() {
    awk -v fn="define $1(" '
        index($0, fn) == 1 { inbody = 1; next }
        inbody && /^[^[:space:]]/ { inbody = 0 }
        inbody { line = $0; sub(/^[[:space:]]+/, "", line)
                 if (line != "" && substr(line, 1, 1) != "#") print $0 }
    ' tests/ap_profile.eigs | md5sum | cut -c1-12
}
body_lines() {
    awk -v fn="define $1(" '
        index($0, fn) == 1 { inbody = 1; next }
        inbody && /^[^[:space:]]/ { inbody = 0 }
        inbody { line = $0; sub(/^[[:space:]]+/, "", line)
                 if (line != "" && substr(line, 1, 1) != "#") n++ }
        END { print n + 0 }
    ' tests/ap_profile.eigs
}
# A body that hashed to nothing would pass vacuously, so each body's line
# count is pinned alongside its identity (the repo's no-vacuous-check rule).
for spec in "run_read:d2e2942f112e:21" "run_write:514b678f699a:12" "run_floor:82a98c4d1216:13"; do
    fn=${spec%%:*}; rest=${spec#*:}; want=${rest%%:*}; wantn=${rest##*:}
    got=$(body_hash "$fn"); gotn=$(body_lines "$fn")
    [ "$gotn" = "$wantn" ] || { echo "FAIL: $fn's measured body is $gotn lines, declared $wantn — C6 times a DIFFERENT workload than ORACLE.md publishes; re-measure all three variants and re-pin"; exit 1; }
    [ "$got" = "$want" ]   || { echo "FAIL: $fn's measured body changed (identity $got, declared $want) — C6 times a DIFFERENT workload than ORACLE.md publishes; re-measure all three variants and re-pin"; exit 1; }
done
# Round 8 retired the site grep that round 6 added: any read added to or
# removed from a measured loop already changes that loop's body hash, so
# the grep caught nothing the hashes miss and could only false-alarm on a
# module-level predicate read. One layer, not two.
#
# The variants print their OWN line now, from their own loop counters, and
# the whole output is matched EXACTLY rather than grepped. Round 8 found
# the call site to be the last unpinned surface: `run_floor of (0)` kept
# every layer matching -- body hash, line count, site count, and
# `floor 120000` via `0 + N` -- while the measured floor collapsed to
# 0.008 s of interpreter startup and write/floor reported 28.75 against a
# published 1.44, fabricating the exact 78/22 split the bound exists to
# support. An exact match also rejects a fabricated extra line, which
# `grep -q` would have accepted.
expect_out() {
    got=$("$EIGS" tests/ap_profile.eigs "$1")
    [ "$got" = "$2" ] || { echo "FAIL: $1 variant did not execute its declared work"; echo "  expected: $2"; echo "  got:      $got"; exit 1; }
}
expect_out read  "read 133286 480000"
expect_out write "write 120000"
expect_out floor "floor 120000"
R=$(med read); W=$(med write); F=$(med floor)
echo "read=${R}s  write=${W}s  floor=${F}s  (120k frames, median of 5)"
RATIO=$(awk -v r="$R" -v w="$W" 'BEGIN{ if (w<=0) w=0.001; printf "%.2f", r/w }')
echo "read/write ratio = ${RATIO}  (bound: > ${RW_BOUND})"
check_ratio read/write "$RATIO" "$RW_BOUND" || {
    echo "FAIL: the read path no longer dominates (ratio ${RATIO} <= ${RW_BOUND})."
    echo "      If reads were made O(1) this is EXPECTED — re-measure, update"
    echo "      ORACLE.md's C6 numbers, and re-justify the bound."
    exit 1; }
echo "PASS: read path dominates at ${RATIO}x — #915's write-path gate cannot help this shape"

# The observed WRITE path must cost something too, or `floor` is a number
# nobody reads and the "78% reads / 22% writes" split is unsupported.
WF=$(awk -v w="$W" -v f="$F" 'BEGIN{ if (f<=0) f=0.001; printf "%.2f", w/f }')
echo "write/floor ratio = ${WF}  (bound: > ${WF_BOUND})"
# Round-7 review measured write/floor = 0.98 on UNMUTATED code while
# tests/test_ap_planted.sh ran concurrently — one observation, not
# reproducible with CPU spinners, but enough to show this ratio can be
# deflated toward 1.0 by load the same way read/write is inflated by it
# (3.38 measured). A fault is deterministic and a loaded runner is not, so
# a first failure re-measures once and the SECOND reading decides. Both
# planted faults below are verified to still red through this path.
if ! check_ratio write/floor "$WF" "$WF_BOUND"; then
    echo "NOTE: write/floor ${WF} <= ${WF_BOUND} on the first reading — re-measuring once (a loaded runner deflates this ratio; a real regression will not)"
    W=$(med write); F=$(med floor)
    WF=$(awk -v w="$W" -v f="$F" 'BEGIN{ if (f<=0) f=0.001; printf "%.2f", w/f }')
    echo "write/floor ratio = ${WF}  (re-measured, decisive)"
    check_ratio write/floor "$WF" "$WF_BOUND" || { echo "FAIL: observed writes now cost no more than the unobserved floor (${WF} on both readings) — re-measure and re-justify the 78/22 split"; exit 1; }
fi
awk -v x="$WF" -v c="$WF_CEIL" 'BEGIN{ exit !(x < c) }' || { echo "FAIL: write/floor is ${WF}, above the ${WF_CEIL} ceiling — the unobserved floor has collapsed (it is the denominator), so this is a measurement fault, not a speedup"; exit 1; }
echo "PASS: observed write path costs ${WF}x the unobserved floor"

# PLANTED FAULT for this gate (rungs 0-2 refuse to ship a gate never shown
# able to fail). Feed the bound a ratio built from the write variant on
# BOTH sides — what the measurement would look like if reads became free —
# and require the bound to reject it. This validates the bound logic, which
# is the part that could silently accept anything; the variants themselves
# are validated by having just been run above.
PLANTED=$(awk -v r="$W" -v w="$W" 'BEGIN{ printf "%.2f", r/w }')
if check_ratio planted "$PLANTED" "$RW_BOUND"; then
    echo "FAIL: the C6 bound accepted a planted ratio of ${PLANTED} — this gate cannot fail"; exit 1
fi
echo "PASS: C6 read/write planted fault rejected (ratio ${PLANTED} <= ${RW_BOUND})"

# The same for the SECOND bound: a floor equal to the write time is what
# "observed writes are free" would look like, and 1.15 must reject it.
PLANTED2=$(awk -v w="$W" -v f="$W" 'BEGIN{ printf "%.2f", w/f }')
if check_ratio planted2 "$PLANTED2" "$WF_BOUND"; then
    echo "FAIL: the C6 write/floor bound accepted a planted ratio of ${PLANTED2} — that bound cannot fail"; exit 1
fi
echo "PASS: C6 write/floor planted fault rejected (ratio ${PLANTED2} <= ${WF_BOUND})"
