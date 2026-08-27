# phugoid

A fixed-wing flight-mode lab in [EigenScript](https://github.com/InauguralSystems/EigenScript),
named for the slowest longitudinal mode it grades. phugoid is the consumer
that stresses the half of the observer nothing else in the fleet touches:
**the cost and correctness of observation *while observing*, at a frame
deadline** — live predicate reads (stall warning, trim detection, oscillation
onset) inside a hot real-time loop. The proposal and contract live at
`hq/proposals/flight-simulator.md`; the falsifiable prediction recorded there
is that the physics will *not* be what breaks first.

## Oracle-first: rung 0 is the grader, rung 1 the first flight model

Rung 0 built and adversarially validated the grader before any model:

- **`DERIVATIVES.md` / `data/b747_approach.eigs`** — a complete public
  airframe dataset (Boeing 747, Mach 0.25 powered approach; Caughey 2011 ←
  Nelson ← NASA CR-2144) whose source publishes *every link* of the
  derivation chain.
- **`modes.eigs`** — nondimensional coefficients → dimensional stability
  derivatives → state matrices → characteristic quartic (Faddeev–LeVerrier)
  → complex roots (Durand–Kerner) → mode quantities (ωn, ζ, T, t½, N½).
  Every stage is checked against the published values: 180 pinned checks.
- **`measure.eigs`** — the estimators that will grade rung-1+ trajectories:
  period by extrema-spacing and by Hann-windowed DFT peak, damping by log
  decrement and by envelope fit (both baseline-free, on peak-to-trough
  spans), aperiodic t½ by exponential fit. 126 pinned checks against
  synthetic truth, with every refusal path pinned — the estimators must
  *refuse* rather than answer when a window can't support the estimate.
- **`ORACLE.md`** — the quality bar itself: published numbers, stated
  tolerances (with written justifications for every widening), an eighteen-plant
  fault matrix proving each checker can fail, and a boundary self-test of
  the comparators so a widened tolerance cannot pass silently.

Rung 1 (shipped 2026-08-24) is the first model, graded by rung 0:

- **`sim.eigs`** — the nonlinear longitudinal 3-DOF model: coefficient
  aerodynamics with the α̇ dependence solved in closed form, a Newton trim
  solver, RK4, and the SP-subspace excitation. Its Jacobian at its own
  solved trim must match the rung-0 A matrix entry-by-entry (S0), and its
  free responses grade to the chain's mode quantities: phugoid T within
  0.03% measured, ζ within 0.2%; short period T within 0.17%, ζ within
  0.15% (arms in ORACLE.md, twenty-two-plant fault matrix in
  `tests/test_sim_planted.sh`).
- **`tests/observer_check.eigs`** — the observer's verdicts graded against
  the same physics: 8 agreement pins, and 3 pinned *divergences* — the
  fixed 10-sample predicate window reads a 47 s mode at 1 Hz as
  `diverging` on its quarter-cycles (GAPS.md G4, the first measured
  instance of the proposal's two-timescale prediction).

Rung 3 (shipped 2026-08-25) is the first phugoid model that **acts** —
a closed-loop autopilot, with the observer as its supervisory layer:

- **`autopilot.eigs`** — classical pitch-rate feedback on the rung-1
  plant, graded against closed-loop pole predictions computed from the
  chain BEFORE the controller existed (`A_cl = A + B·K`, then the same
  `charpoly4 → dk_roots → modes_of`). Measured: ζ tracks the prediction
  to 0.0066–0.16% across the three graded gains and the phugoid row, and the whole grading
  apparatus transferred with no new oracle code.
- **The observer in the loop.** Two of three pre-registered predictions
  were **refuted**, which is the rung's main result. At inner-loop rate
  the observer is not noisy — but neither is it merely blind: on a
  smoothly *decaying* phugoid it never says `oscillating` (0 of 8000
  reads) and instead alternates `diverging` (49%) and `converged` (51%),
  so an autopilot would fight a healthy mode half the time. Supervision
  does not hold cleanly either; it *flickers* 17 times in one phugoid
  episode for want of hysteresis. The corrected design law needs two
  conditions: a verdict is actionable only when the regime persists
  beyond ~1–2 observation windows **and** the observed channel still clears
  the deadband. The second condition is a *horizon*, not a gate: the
  onset never moves (the window filling), only the cutoff does, so as a
  mode decays under the band supervision runs out of time rather than
  switching off — EigenScript#1045 changing what an actuator does.
- **`tests/ap_profile.eigs`** — the observer's READ path, which no
  consumer had put under load. The whole read-bearing program costs
  1.75–2.50× the write-only one on this shape; for a program that reads
  verdicts at all, ~75% of the observer cost is the reads themselves and
  ~25% is per-assignment write bookkeeping the reads keep armed. And the rung's second upstream find:
  EigenScript#915's write-path gate arms **per interpreter state** and
  monotonically, so one verdict read anywhere in a program — in a function
  that is never called, in a different file, or as a bare string constant
  — arms bookkeeping for every assignment in every module (+43–48% measured on dead
  code across three independent reproductions; GAPS.md G7,
  EigenScript#1046). It cannot help an autopilot
  by construction.

Rung 2 (shipped 2026-08-24) is the lateral model — three timescales and
the level-set stress:

- **`latsim.eigs`** — the lateral 3-DOF (exact Ixz-coupled moments,
  exact-origin trim, mode-pure annihilator ICs via Cayley–Hamilton).
  Jacobian parity vs the rung-0 lateral A measured at machine epsilon;
  Dutch roll T within 0.1%, ζ 0.01%; roll and spiral t½ within 0.1%.
- **`tests/observer_lat_check.eigs`** — the level-set grading: the value
  channel correctly reads zero-symmetric motion the entropy channel is
  provably blind to (the mirror pin: a +5 → −5 assignment registers
  `why == 0` exactly), and the rung's new find — **verdicts are
  unit-dependent below |v| ≈ 1** (the same still-decaying bank angle
  reads `converged` in radians, `moving` in degrees; GAPS.md G5,
  EigenScript#1045).

## Run it

```sh
bash tests/test_lint.sh        # every .eigs lints clean (planted-fault validated)
bash tests/test_comparator.sh  # 15 tolerance boundary self-tests
bash tests/test_modes.sh       # 180 chain checks vs published values
bash tests/test_measure.sh     # 126 estimator checks vs synthetic truth
bash tests/test_planted.sh     # 18 plants must each flip exactly their checks
bash tests/test_sim.sh         # 79 rung-1 model checks vs the rung-0 chain
bash tests/test_sim_planted.sh # 22 rung-1 plants, exact red sets + manifest
bash tests/test_observer.sh    # 11 observer-verdict checks + 2 plants
bash tests/test_latsim.sh      # 76 rung-2 model checks vs the rung-0 chain
bash tests/test_latsim_planted.sh # 22 rung-2 plants, exact red sets + manifest
bash tests/test_observer_lat.sh   # 13 rung-2 observer checks + 2 plants
bash tests/test_ap.sh          # 217 rung-3 closed-loop checks
bash tests/test_ap_planted.sh  # 16 rung-3 plants, exact red sets + manifest
bash tests/test_ap_profile.sh  # the observer read-path ratio gate
```

Requires `eigenscript` on PATH (or `EIGENSCRIPT=/path/to/binary`), pinned in
CI at the version in `.devcontainer/Dockerfile`.

## The rung ladder

| Rung | Scope | Status |
|---|---|---|
| 0 | Oracle before code: dataset, mode predictions, measurement scripts | done |
| 1 | Longitudinal 3-DOF, trimmed; elevator pulse → phugoid, SP-subspace IC → short period, graded against rung 0; observer verdicts graded second | **done** |
| 2 | Lateral 3-DOF: Dutch roll, spiral, roll subsidence via mode-pure annihilator ICs; the level-set/value-channel stress graded | **done** |
| 3 | The autopilot: closed-loop control graded against closed-loop pole predictions; the observer as supervisory layer | **done** |
| 3b | 6-DOF + control tapes, byte-exact replay gate (deferred from rung 3: no nondeterminism source yet, so the gate would be vacuous) | — |
| 4 | The swarm: N aircraft, three-arm observer cost curve (ceiling/disciplined/floor), VM-only (the AOT arm is BLOCKED on ouroboros#119) | — |

Headless by contract through rung 4; any instrument-panel phase comes after
and rides the fleet UI-oracle standard.

Gap ledger: [GAPS.md](GAPS.md) — upstream findings, never silent workarounds.

## License

MIT — see [LICENSE](LICENSE).
