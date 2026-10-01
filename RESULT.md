# SUMMARY

Round 2 corrected 30 fabricated observer/workload seeds; the complete
file/line audit is in ORACLE.md. With physical seeds, c042/c050 have no
oscillating reads, c100 has 6 starting at read 12, and c102 has 2 starting
at read 16. All 88 SP verdict assertions are explicitly BELOW-FLOOR and
excluded from physics grading. All 17 AP streams were varied at ×1000
and half excitation; only C4.ph, p365, a035 and a040 preserve both full
streams. Other affected claims are empirical or instrument checks.

Restored all 23 round-1 exemptions. Every AP assertion fires under an
executed plant: 250/250 sites across 20 plants. Candidate CI is 18/19
green; the unchanged swarm timing gate remains red. Full swarm plant
coverage completed in 924 seconds. No push.

# FINAL TABLE

All 19 scripts completed on both runtimes: pin 10/19, candidate 18/19.
Pin v0.43.0 a6c50fb; candidate a7a4ca3. Exact CI invocation per script:
`EIGENSCRIPT=eigenscript bash "$t"`, one at a time under `nice -n 10`,
`ulimit -v 1500000`, `EIGS_STRICT=1`, runtime src first on PATH.
Timeout: 900s normally, 2100s for the full swarm plant matrix (sized from
14 checker invocations at about 99s plus margin), 60s for lint.
Exit 124 is named HANG; no completed run hung. Final-attempt table:

| Script (`tests/`) | Pin rc | Candidate rc | Candidate last line |
|---|---:|---:|---|
| `test_ap.sh` | 1 | 0 | PASS: 250/250 rung-3 checks green |
| `test_ap_planted.sh` | 1 | 0 | PASS: all 20 rung-3 plants flip exactly their declared checks |
| `test_ap_profile.sh` | 1 | 0 | PASS: C6 arming planted fault rejected (ratio 1.00 <= 1.15) |
| `test_comparator.sh` | 0 | 0 | PASS: 15/15 comparator boundary checks green |
| `test_latsim.sh` | 0 | 0 | PASS: 76/76 rung-2 checks green |
| `test_latsim_planted.sh` | 0 | 0 | PASS: all 22 rung-2 plants flip exactly their declared checks |
| `test_lint.sh` | 0 | 0 | PASS: planted fault (unused variable) is caught |
| `test_measure.sh` | 0 | 0 | PASS: 126/126 estimator checks green |
| `test_modes.sh` | 0 | 0 | PASS: 180/180 oracle checks green |
| `test_observer.sh` | 1 | 0 | PASS: observer layer graded; both plants flip exactly their declared checks |
| `test_observer_lat.sh` | 1 | 0 | PASS: rung-2 observer layer graded; both plants flip exactly their declared checks |
| `test_planted.sh` | 0 | 0 | PASS: all 18 plants flip exactly their declared checks |
| `test_sim.sh` | 0 | 0 | PASS: 79/79 rung-1 checks green |
| `test_sim_planted.sh` | 0 | 0 | PASS: all 22 rung-1 plants flip exactly their declared checks |
| `test_swarm.sh` | 1 | 0 | PASS: P3's 164 pinned rows reproduce (4 physics truth, 96 verdict over a uniform 3x2x2x8 grid, 12 phase cells, 6 equilibrium + 18 monotone + 24 noise controls, 4 N-axis) |
| `test_swarm_p3_planted.sh` | 1 | 0 | PASS: all 64 P3 claim plants red exactly their own claim set and count, every tagged witness has a plant, and the claims precede the row pins |
| `test_swarm_planted.sh` | 1 | 0 | PASS: all 12 rung-4 plants flip exactly their declared checks, and every check is red under some plant |
| `test_swarm_profile.sh` | 1 | 1 |       loop, bisected to 2eabdd5, EigenScript#1443) on top of #1442. Not re-banked. |
| `test_verdicts.sh` | 0 | 0 | PASS: P2's refutation clauses fire with plants; P1's verdict text is pinned and its measurement lives in test_swarm_profile.sh |

Full timings and logs: `/tmp/phugoid-8-r2/ci.tsv`, `logs/`.

# COMMITS

Created on `regrade-main` in `/tmp/phugoid-8-r2/committed`, based on f1910ba:

- `ca2febe` — A: physical seeds, corrected banks, complete plant coverage, unused swarm estimator work removed.
- `8aac87c` — C: below-floor qualifications, physical variation grades and ORACLE corrections.
- This RESULT commit — C: final verification report.

All commit messages end with
`Co-Authored-By: GPT-6.1 Sol <noreply@openai.com>`.
Delivery: `/tmp/phugoid-8-r2/phugoid-8-r2.bundle`.
The worktree's external Git metadata is read-only: its HEAD remains f1910ba
with the completed edits. The bundle carries the class commits.

# FILED ISSUES

None. The owner explicitly chose #1045's absolute 0.001 floor and limited
unit independence to values above it. See
[the owner decision](https://github.com/InauguralSystems/EigenScript/issues/1045#issuecomment-5575612700).
The import-free physical replay gives stable / moving / stable for rad /
mrad / mrad with its floor also converted. Per the brief, no new issue was
filed for the deliberate policy. BELOW-FLOOR rows cite #1045.

# PLANTS

AP clean: 250 checks, zero failures. S1–S20 red counts:
64,65,40,125,1,6,135,13,128,1,16,131,21,19,2,1,58,154,126,210.
Union: all 250 sites. S17 falsely seeds the real supervisor and rejects
all seven named seed checks. S18 rejects every formerly exempt row;
S19 forces improving; S20 calibrates all 210 exact comparators.
The gate compares complete red identities against `tests/ap_plant_reds.txt`
and forbids structural exemptions. Substituting one unlisted identity
while retaining 64 reds makes the real gate red.

Swarm: all 12 plants completed; reds 1,6,6,9,1,24,1,4,8,4,4,4;
all 60 sites enrolled. P3: all 64 plants, all 72 tagged witness sites.

# CAVEATS

The sole candidate red is `test_swarm_profile.sh`: final ceiling/floor
ratios 1.15, 1.11, 1.14 at N=1/4/16 fail the unchanged >1.15 requirement.
Existing EigenScript#1442/#1443 remain open; their earlier bisects were
not repeated. Nine pin failures reflect main-only banks.

SP ×1000/half differences are 113/8 of 300, 45/40 of 150, 21/11 of 75,
20/9 of 71, 18/8 of 60, 8/0 of 30 and 10/0 of 29. Runtime pins do not
certify modal physics. O.sp.t29 and O.ph1s.t120 are empirical after
half-excitation failures; mirror.mag calibrates an absolute instrument.
The physical-seed W5 probe returns 62 per aircraft at base, ×1000 and
half excitation; this validates counts, not full label streams.

An initial swarm attempt exhausted the cap in W9 after 532s. The fixture
now chooses planted estimators before computing, avoiding discarded DFT
work while preserving W9's eight and W11's four required failures.
The final full matrix is green under the same cap. The failed log and an
earlier interrupted budget-sizing attempt are retained.
Git metadata is read-only; import the delivered bundle to advance HEAD.

# OUT OF SCOPE

No runtime changes, release pin bump, push or merge. The default observer
floor and existing timing regressions were not changed. No global skill or
memory files were edited; the distillation is recorded in ORACLE.md and
enforced by physical seed plants and full red-set enrollment.
