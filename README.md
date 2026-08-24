# phugoid

A fixed-wing flight-mode lab in [EigenScript](https://github.com/InauguralSystems/EigenScript),
named for the slowest longitudinal mode it grades. phugoid is the consumer
that stresses the half of the observer nothing else in the fleet touches:
**the cost and correctness of observation *while observing*, at a frame
deadline** — live predicate reads (stall warning, trim detection, oscillation
onset) inside a hot real-time loop. The proposal and contract live at
`hq/proposals/flight-simulator.md`; the falsifiable prediction recorded there
is that the physics will *not* be what breaks first.

## Oracle-first: what exists at rung 0

There is deliberately **no flight model yet**. Rung 0 is the grader:

- **`DERIVATIVES.md` / `data/b747_approach.eigs`** — a complete public
  airframe dataset (Boeing 747, Mach 0.25 powered approach; Caughey 2011 ←
  Nelson ← NASA CR-2144) whose source publishes *every link* of the
  derivation chain.
- **`modes.eigs`** — nondimensional coefficients → dimensional stability
  derivatives → state matrices → characteristic quartic (Faddeev–LeVerrier)
  → complex roots (Durand–Kerner) → mode quantities (ωn, ζ, T, t½, N½).
  Every stage is checked against the published values: 105 pinned checks.
- **`measure.eigs`** — the estimators that will grade rung-1+ trajectories:
  period by peak-spacing and by Hann-windowed DFT peak, damping by log
  decrement and by envelope fit (both baseline-free, on peak-to-trough
  spans), aperiodic t½ by exponential fit. 44 pinned checks against
  synthetic truth, with every refusal path pinned — the estimators must
  *refuse* rather than answer when a window can't support the estimate.
- **`ORACLE.md`** — the quality bar itself: published numbers, stated
  tolerances (with written justifications for every widening), a seven-plant
  fault matrix proving each checker can fail, and a boundary self-test of
  the comparators so a widened tolerance cannot pass silently.

## Run it

```sh
bash tests/test_lint.sh        # every .eigs lints clean (planted-fault validated)
bash tests/test_comparator.sh  # 12 tolerance boundary self-tests
bash tests/test_modes.sh       # 105 chain checks vs published values
bash tests/test_measure.sh     # 44 estimator checks vs synthetic truth
bash tests/test_planted.sh     # 7 plants must each flip exactly their checks
```

Requires `eigenscript` on PATH (or `EIGENSCRIPT=/path/to/binary`), pinned in
CI at the version in `.devcontainer/Dockerfile`.

## The rung ladder

| Rung | Scope | Status |
|---|---|---|
| 0 | Oracle before code: dataset, mode predictions, measurement scripts | **this repo** |
| 1 | Longitudinal 3-DOF, trimmed; elevator step → phugoid + short period graded against rung 0 | next |
| 2 | Lateral 3-DOF: Dutch roll, spiral, roll subsidence (the level-set/value-channel stress) | — |
| 3 | 6-DOF + control tapes, byte-exact replay gate | — |
| 4 | The swarm: N aircraft, three-arm observer cost curve (ceiling/disciplined/floor), VM-vs-AOT | — |

Headless by contract through rung 4; any instrument-panel phase comes after
and rides the fleet UI-oracle standard.

Gap ledger: [GAPS.md](GAPS.md) — upstream findings, never silent workarounds.

## License

MIT — see [LICENSE](LICENSE).
