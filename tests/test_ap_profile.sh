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
#   write/floor = 1.44   -> NOT intrinsic write cost; see below
# CORRECTION, TWICE OVER. An earlier probe reported "observed scalar writes
# are essentially free (0.31s vs a 0.30s floor)". Round 1 could not
# reproduce it here (writes measured +44% over the floor) and withdrew it.
# Round 10 showed the WITHDRAWAL was the error: against a read-free module
# an observed write is indistinguishable from the unobserved floor
# (noread/floor 1.02-1.11 quiet). The +44% is #915's arming penalty, not
# write cost. Round 10 then published the wrong MECHANISM for that penalty
# ("per-module"), and round 11 refuted it from the source and the runtime:
# `obs_needed` is one monotonic flag on EigsState, so arming is
# PER-INTERPRETER-STATE (one per process for the CLI) -- a verdict read
# in a dead function, in a different file,
# or as a bare string constant `"report"` arms bookkeeping for every
# assignment in every module. GAPS.md G7, EigenScript#1046. Decomposed:
# Round 13: "intrinsic writes ~0" is CIRCULAR -- noread and floor are both
# states where the entropy walk does not run, so their ratio is a
# tautology, not a measurement. For a program that reads verdicts at all
# (an autopilot does) the split is reads-direct ~75% / observed-write
# bookkeeping ~25%; #915 elides the 25% only in a program with no reads
# anywhere. Three correct measurements in different regimes; the regime
# variable went unnamed for six rounds and the mechanism was invented
# twice.
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
med_file() {  # median of 5 for a single-variant file
    for _ in 1 2 3 4 5; do
        local t0 t1
        t0=$(date +%s%N)
        "$EIGS" "$1" >/dev/null 2>&1
        t1=$(date +%s%N)
        awk -v a="$t0" -v b="$t1" 'BEGIN{ printf "%.3f\n", (b-a)/1000000000 }'
    done | sort -n | sed -n 3p
}
expect_out_file() {
    got=$("$EIGS" "$1" $2)
    [ "$got" = "$3" ] || { echo "FAIL: $1 did not execute its declared work"; echo "  expected: $3"; echo "  got:      $got"; exit 1; }
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
# The ARMING penalty (GAPS.md G7): write/noread. Round 10 measured that
# `write/floor` does not isolate the observed write path at all -- neutering
# only the four predicate reads inside run_read, a function the `write`
# variant never enters, drops write/floor from ~1.45 to ~1.03. #915's gate
# arms PER-INTERPRETER-STATE and monotonically, so one verdict read anywhere in the
# program re-arms entropy bookkeeping for every assignment in it. This
# bound is the penalty itself, measured against a separate program that is
# read-free by construction. NOTE (round 15): because noread/floor is ~1.0
# by construction, write/noread and write/floor are near-duplicates of one
# measurement, not two independent arms -- they measured 1.42 and 1.40 in
# the same run. write/noread is kept because it names the regime (its
# denominator is an UNARMED program, not an unobserved block) and so its
# failure is diagnostic of the upstream fix; it is not extra coverage. What the file pin has to defend for that
# control is "reader-opcode-free AND reader-NAME-free" -- the gate also
# scans the constant pool, so a bare string `"report"` arms it.
WA_BOUND=1.15

# The bounds are DATA and get the manifest treatment every tolerance
# argument in this repo gets. Round-5 review widened both literals
# (1.5 -> 1.05, 1.15 -> 1.02) and the suite stayed green, because each
# bound's planted fault sits at ratio 1.00 — the very bottom of the
# rejection region — so the entire margin the bound buys was unexercised
# and the value itself was free. A bound-derived plant cannot fix this
# (it tracks the widening); the declared value has to be pinned.
[ "$RW_BOUND" = "1.5" ]  || { echo "FAIL: RW_BOUND is $RW_BOUND, declared 1.5 — a widened bound must be re-justified in ORACLE.md, not edited in place"; exit 1; }
[ "$WA_BOUND" = "1.15" ] || { echo "FAIL: WA_BOUND is $WA_BOUND, declared 1.15 — a widened bound must be re-justified in ORACLE.md, not edited in place"; exit 1; }
[ "$WF_CEIL" = "3.0" ]   || { echo "FAIL: WF_CEIL is $WF_CEIL, declared 3.0 — a widened bound must be re-justified in ORACLE.md, not edited in place"; exit 1; }
[ "$WF_BOUND" = "1.15" ] || { echo "FAIL: WF_BOUND is $WF_BOUND, declared 1.15 — a widened bound must be re-justified in ORACLE.md, not edited in place"; exit 1; }

# below_ceiling <value> <ceiling> -> 0 if value < ceiling. Shared by the
# real check and its planted fault: round 4's rule is that a gate and the
# fault validating it use the same constant, and round 9 showed the same
# applies to the same COMPARISON -- two copies of the expression let one be
# flipped with the plant still passing.
below_ceiling() {
    awk -v x="$1" -v c="$2" 'BEGIN{ exit !(x < c) }'
}

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
# Round-7/8/9 review walked this outward three more times: the body pins
# bound the loop bodies but not the call site, the call-site argument
# (`run_floor of (0)` kept every layer matching while the floor became
# 0.008s of interpreter startup and write/floor read 28.75), and then the
# module level around it (eight lines of `unobserved:` busywork before the
# dispatch moved read/write 2.13 -> 3.47 with every pin matching).
#
# Round 10 replaced four awk programs with one. A comment- and
# blank-stripped WHOLE-FILE hash is strictly stronger than per-body plus
# per-module hashes -- it also pins the `define` headers those left free --
# and cannot hash to nothing, so the anti-vacuity line counts come along
# for free rather than being a separate layer.
file_pin() {
    got=$(grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' | md5sum | cut -c1-12)
    gotn=$(grep -v '^[[:space:]]*#' "$1" | grep -v -c '^[[:space:]]*$')
    [ "$gotn" = "$3" ] || { echo "FAIL: $1 has $gotn code lines, declared $3 — C6 times a DIFFERENT workload than ORACLE.md publishes; re-measure every variant and re-pin"; exit 1; }
    [ "$got"  = "$2" ] || { echo "FAIL: $1 changed (identity $got, declared $2) — C6 times a DIFFERENT workload than ORACLE.md publishes; re-measure every variant and re-pin"; exit 1; }
}
# PLANTED FAULT for file_pin itself (round 22). C6's four other plants all
# synthesise a ratio and feed it to the comparator; NONE touches the .eigs
# files, so the layer that actually stops "the measured workload silently
# became a different workload" -- the defect rounds 5, 8 and 9 found -- had
# never been shown able to fail. Round 21's lesson, applied here: plants
# must come from the defect class the gate exists to stop.
FP_TMP=$(mktemp -d)
sed 's/^N is 120000$/N is 60000/' tests/ap_profile.eigs > "$FP_TMP/mut.eigs"
FP_GOT=$(grep -v '^[[:space:]]*#' "$FP_TMP/mut.eigs" | grep -v '^[[:space:]]*$' | md5sum | cut -c1-12)
rm -rf "$FP_TMP"
[ "$FP_GOT" != "f674b4b84476" ] || { echo "FAIL: file_pin's identity is blind to halving the frame count — the pin cannot fail"; exit 1; }
echo "PASS: C6 file_pin planted fault rejected (halved N hashes to $FP_GOT, not f674b4b84476)"
file_pin tests/ap_profile.eigs        f674b4b84476 61
file_pin tests/ap_profile_noread.eigs 743df838d495 15
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
# published 1.44, fabricating the exact attribution the bound exists to
# support. An exact match also rejects a fabricated extra line, which
# `grep -q` would have accepted.
expect_out() {
    got=$("$EIGS" tests/ap_profile.eigs "$1")
    [ "$got" = "$2" ] || { echo "FAIL: $1 variant did not execute its declared work"; echo "  expected: $2"; echo "  got:      $got"; exit 1; }
}
expect_out_file tests/ap_profile_noread.eigs "" "noread 120000"
expect_out read  "read 133286 480000"
expect_out write "write 120000"
expect_out floor "floor 120000"
R=$(med read); W=$(med write); F=$(med floor); NR=$(med_file tests/ap_profile_noread.eigs)
echo "read=${R}s  write=${W}s  floor=${F}s  (120k frames, median of 5)"
RATIO=$(awk -v r="$R" -v w="$W" 'BEGIN{ if (w<=0) w=0.001; printf "%.2f", r/w }')
echo "read/write ratio = ${RATIO}  (bound: > ${RW_BOUND})"
check_ratio read/write "$RATIO" "$RW_BOUND" || {
    echo "FAIL: the read path no longer dominates (ratio ${RATIO} <= ${RW_BOUND})."
    echo "      If reads were made O(1) this is EXPECTED — re-measure, update"
    echo "      ORACLE.md's C6 numbers, and re-justify the bound."
    exit 1; }
echo "PASS: the read-bearing program costs ${RATIO}x the write-only one — #915's write-path gate cannot help this shape (for a verdict-reading program: reads-direct ~75%, observed-write bookkeeping ~25% — see GAPS G7)"

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
    check_ratio write/floor "$WF" "$WF_BOUND" || { echo "FAIL: observed writes now cost no more than the unobserved floor (${WF} on both readings) — re-measure and re-justify the read/write attribution"; exit 1; }
fi
below_ceiling "$WF" "$WF_CEIL" || { echo "FAIL: write/floor is ${WF}, above the ${WF_CEIL} ceiling — either the unobserved floor collapsed or the write path inflated; both read identically here and both are measurement faults, not speedups"; exit 1; }
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

# ...and the CEILING gets one too. Round 9: it shipped as the only arm in
# this file with no planted fault, in a script whose own rule is that a
# gate never shown able to fail does not ship. A floor collapsed to a
# tenth of the write time is what `run_floor of (0)` measured (0.008s
# against 0.230s) before the exact-output pin closed that door; the
# ceiling is what remains if a RUNTIME change, rather than a source edit,
# collapses it.
PLANTED3=$(awk -v w="$W" 'BEGIN{ printf "%.2f", w/(w/10) }')
if below_ceiling "$PLANTED3" "$WF_CEIL"; then
    echo "FAIL: the C6 write/floor ceiling accepted a planted ratio of ${PLANTED3} — that ceiling cannot fail"; exit 1
fi
echo "PASS: C6 write/floor ceiling planted fault rejected (ratio ${PLANTED3} >= ${WF_CEIL})"

# The arming penalty, and the attribution it corrects.
WA=$(awk -v w="$W" -v n="$NR" 'BEGIN{ if (n<=0) n=0.001; printf "%.2f", w/n }')
NF_=$(awk -v n="$NR" -v f="$F" 'BEGIN{ if (f<=0) f=0.001; printf "%.2f", n/f }')
echo "noread=${NR}s   write/noread = ${WA}  (bound: > ${WA_BOUND})   noread/floor = ${NF_}"
# Same treatment write/floor gets: this pair is the noisiest in the gate
# (measured 1.21-1.59 across five quiet rounds, and the two modules are
# separate processes), so a first failure re-measures and the second
# reading decides. The planted fault below is deterministic and reds
# through both.
if ! check_ratio write/noread "$WA" "$WA_BOUND"; then
    echo "NOTE: write/noread ${WA} <= ${WA_BOUND} on the first reading — re-measuring once"
    W=$(med write); NR=$(med_file tests/ap_profile_noread.eigs)
    WA=$(awk -v w="$W" -v n="$NR" 'BEGIN{ if (n<=0) n=0.001; printf "%.2f", w/n }')
    echo "write/noread = ${WA}  (re-measured, decisive)"
    check_ratio write/noread "$WA" "$WA_BOUND" || {
        echo "FAIL: an observed write in a read-bearing module now costs no more"
        echo "      than the same write in a read-free one (${WA} on both readings) —"
        echo "      either #915's arming became per-binding upstream (GAPS.md G7"
        echo "      fixed: re-measure, re-attribute, and close G7) or this control"
        echo "      stopped being read-free."
        exit 1; }
fi
echo "PASS: C6 per-state arming penalty present at ${WA}x (G7) — the write cost C6 attributes to writes is mostly this"
PLANTED4=$(awk -v w="$W" 'BEGIN{ printf "%.2f", w/w }')
if check_ratio planted4 "$PLANTED4" "$WA_BOUND"; then
    echo "FAIL: the C6 arming bound accepted a planted ratio of ${PLANTED4} — that bound cannot fail"; exit 1
fi
echo "PASS: C6 arming planted fault rejected (ratio ${PLANTED4} <= ${WA_BOUND})"
