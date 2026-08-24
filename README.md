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
  0.15% (arms in ORACLE.md, seventeen-plant fault matrix in
  `tests/test_sim_planted.sh`).
- **`tests/observer_check.eigs`** — the observer's verdicts graded against
  the same physics: 8 agreement pins, and 3 pinned *divergences* — the
  fixed 10-sample predicate window reads a 47 s mode at 1 Hz as
  `diverging` on its quarter-cycles (GAPS.md G4, the first measured
  instance of the proposal's two-timescale prediction).

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
bash tests/test_sim.sh         # 64 rung-1 model checks vs the rung-0 chain
bash tests/test_sim_planted.sh # 17 rung-1 plants, exact red sets + manifest
bash tests/test_observer.sh    # 11 observer-verdict checks + 2 plants
bash tests/test_latsim.sh      # 56 rung-2 model checks vs the rung-0 chain
bash tests/test_latsim_planted.sh # 16 rung-2 plants, exact red sets + manifest
bash tests/test_observer_lat.sh   # 13 rung-2 observer checks + 2 plants
```

Requires `eigenscript` on PATH (or `EIGENSCRIPT=/path/to/binary`), pinned in
CI at the version in `.devcontainer/Dockerfile`.

## The rung ladder

| Rung | Scope | Status |
|---|---|---|
| 0 | Oracle before code: dataset, mode predictions, measurement scripts | done |
| 1 | Longitudinal 3-DOF, trimmed; elevator pulse → phugoid, SP-subspace IC → short period, graded against rung 0; observer verdicts graded second | **done** |
| 2 | Lateral 3-DOF: Dutch roll, spiral, roll subsidence via mode-pure annihilator ICs; the level-set/value-channel stress graded | **done** |
| 3 | 6-DOF + control tapes, byte-exact replay gate | — |
| 4 | The swarm: N aircraft, three-arm observer cost curve (ceiling/disciplined/floor), VM-vs-AOT | — |

Headless by contract through rung 4; any instrument-panel phase comes after
and rides the fleet UI-oracle standard.

Gap ledger: [GAPS.md](GAPS.md) — upstream findings, never silent workarounds.

## License

MIT — see [LICENSE](LICENSE).
