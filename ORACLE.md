# The rung-0 oracle — written before any code

This file is the quality bar for rung 0 (grader-first: the oracle exists and is
validated before any flight model is written). Every check below is inspectable
by an outside critic: a published number, a stated tolerance, and a planted
fault that proves the check can fail. **Tolerances may not be widened without a
written justification in this file recording the measured discrepancy and why
it is print-rounding rather than a defect.**

## Source of truth

Caughey, David A., *Introduction to Aircraft Stability and Control*, Course
Notes for M&AE 5070, Cornell University, 2011.
<https://courses.cit.cornell.edu/mae5070/Caughey_2011_04.pdf>
§5.2–5.3 (equations 5.48–5.101). Caughey's data is from Nelson, *Flight
Stability and Automatic Control*, 2nd ed. (his ref [2]), whose 747 tables trace
to Heffley & Jewell, *Aircraft Handling Qualities Data*, NASA CR-2144 (1972).

Airframe: **Boeing 747, Mach 0.25 powered-approach configuration, standard sea
level** (Caughey eq. 5.48). Chosen over the proposal's example airframes
(Navion / Cessna-182) because this is the one public dataset where the source
publishes *every link of the chain* — nondimensional coefficients, dimensional
derivatives, the assembled state matrices, the characteristic quartics, their
roots, and the derived mode quantities — so each stage of our pipeline has an
independent printed answer, not just the endpoints. The full input data is in
`DERIVATIVES.md` and `data/b747_approach.eigs`.

## The pipeline under test

```
nondimensional coefficients + flight condition       (primary data, exact)
  → dimensional stability derivatives                (L1)
  → longitudinal / lateral state matrices A          (L2)
  → characteristic quartic coefficients              (L3)
  → roots (complex)                                  (L4)
  → mode quantities: ωn, ζ, T, t_half, N_half        (L5)
```

and, independently, the **measurement scripts** that will grade rung-1+
trajectories (M1–M3 below).

## Checks and tolerances

Printed values are rounded; the source computed later stages from unrounded
intermediates (verified by hand for A33: rebuilding from the printed Mẇ =
−0.0002 gives −0.4906, from the unrounded −0.000241 gives the printed
−0.5015). So each stage is computed from **our own unrounded chain** and
compared against the printed value at that stage, with tolerance = print
rounding plus a small margin.

Per-value tolerance rule, used by every L-check: with d = number of decimal
places in the printed value, pass iff
`|ours − printed| ≤ 0.7·10⁻ᵈ` **or** `|ours − printed| ≤ 0.0015·|printed|`.

### L1 — dimensional derivatives (vs Caughey eq. 5.51 and 5.91)

Longitudinal: Xu=−0.0212, Xw=0.0466, Zu=−0.2306, Zw=−0.6038, Zẇ=−0.0341,
Zq=−7.674, Mu=0.0, Mw=−0.0019, Mẇ=−0.0002, Mq=−0.4381.
Lateral: Yv=−0.0999, Yp=0.0, Yr=0.0, Lv=−0.0055, Lp=−1.0994, Lr=0.2468,
Nv=0.0012, Np=−0.0933, Nr=−0.2314; ix=−0.1559, iz=−0.0492.

### L2 — state matrices (vs eq. 5.52 and 5.93)

All 16 entries of each printed A, same per-value rule. The folding conventions
(Zẇ and Mẇ absorption in the longitudinal rows; Ixz cross-inertia priming in
the lateral rows) are exactly what these entries pin down.

### L1U/L2U — formula-term unit checks on a synthetic all-nonzero dataset

53 checks driving `dim_derivs_*` and `a_*` with a SYNTHETIC dataset in which
every coefficient is nonzero and θ₀ = 0.2, compared at **10⁻⁹ relative**
against expectations computed by an independent double-precision
implementation of the same published formulas (Python; generated, not
hand-transcribed). Exists because round-6 review multiplied a wrong moment
arm into the Mu term and swapped tan θ₀ → sin θ₀ and the whole suite stayed
green: the 747 dataset has zeros exactly where those terms live
(C_mu = C_Lu = C_Du = C_yp = C_yr = 0, θ₀ = 0), and P8 cannot help — a wrong
formula on poisoned data fails against the published values exactly like a
right one. P8 additionally poisons the synthetic dataset (including the
u₀-cancelling C_Lα̇/C_mα̇ terms, whose independence from u₀ was itself
measured here) so the family is red-coverable; its 10 structural entries
join the manifest exemption list.

### CU / L5.unit extensions (rounds 6–7)

Direct unit checks on the numeric internals that the chain oracles are
structurally blind to, each bought by a survived mutation:

- **CU (11 checks):** `cadd`/`csub`/`cdiv`/`cmul`/`cmag`/`poly4_eval` against hand-computed
  values at 10⁻⁹ — round-7 review HALVED cdiv's denominator and everything
  stayed green, because Durand–Kerner self-corrects under delta scaling, so
  residual/Vieta/root-match oracles never see the helpers. (This also makes
  GAPS.md's "validated here" claim for the complex helpers true directly,
  not just transitively.) Inputs scale under P8 while the wants stay fixed —
  an expectation written in terms of the plant's scale would track it and
  never fail (measured on the first attempt, then rewritten).
- **L5.unit.thresh (4 checks):** the oscillatory/real classification
  threshold (`osc_im_threshold`, 10⁻⁶) pinned from BOTH sides — a pair at
  im = 2·10⁻⁶ must classify oscillatory, at 5·10⁻⁷ real. Round-7 drifted
  the inline constant 10⁵× with every check green. Literal-fed, no data
  plant can move them: manifest class structural.
- **L5.unit stability contract (4 checks):** stable entries carry
  t_half = ln2/(−re), unstable ones t_double = ln2/re (both mode kinds),
  ζ < 0 for an unstable pair — round-7 gutted `t_double` to 999.0 and no
  check ever exercised an unstable root; the modes_of doc-comment also
  described a t_half<0 encoding the code never implemented (fixed).

### L3 — characteristic quartics (vs eq. 5.53 and 5.94)

Longitudinal: λ⁴ + 1.1066λ³ + 0.7994λ² + 0.0225λ + 0.0139.
Lateral:      λ⁴ + 1.4385λ³ + 0.8222λ² + 0.7232λ + 0.0319.
Same per-value rule, applied to each coefficient.

### L4 — roots (vs eq. 5.54 and 5.95)

Longitudinal: short period −0.5515 ± 0.6880i; phugoid −0.00178 ± 0.1339i.
Lateral: Dutch roll −0.08066 ± 0.7433i; roll −1.2308; spiral −0.04641.
Per-value rule on each real and imaginary part, from OUR quartic.

Additionally the root finder alone is checked on the PUBLISHED quartic
coefficients three ways:
1. **Residuals**: |p(z)| ≤ 10⁻¹⁰ for every returned root — exact, no
   rounding dependence.
2. **Vieta**: Σroots = −c1 and Πroots = c4, each to 10⁻¹⁰ — exact.
3. Match to the published roots with **5·10⁻⁴ absolute** per component.
   *Justification for the wider tolerance (measured 2026-08-23, first run):*
   the published roots were computed from unrounded coefficients; rooting the
   printed (rounded) quartic shifts the phugoid pair by up to 2.1·10⁻⁴ on the
   imaginary part (0.13368934 vs printed 0.1339) and 9.1·10⁻⁶ on the real
   part — c4 alone is printed 0.29% off its unrounded value and the small
   phugoid pair absorbs most of that. 5·10⁻⁴ covers the measured rounding
   shift with ~2× margin while still flipping on plant P2's +1% coefficient
   perturbation (which moves the Dutch-roll pair by ~10⁻²).

### L5 — mode quantities (vs eq. 5.55–5.56, 5.96–5.101)

ζ_sp=0.6255, ωn_sp=0.882 s⁻¹, T_sp=9.13 s; ζ_ph=0.0133, ωn_ph=0.134 s⁻¹,
T_ph=46.9 s; ζ_DR=0.1079, ωn_DR=0.7477 s⁻¹, T_DR=8.45 s, N½_DR=1.016;
t½_roll=0.563 s, t½_spiral=14.93 s. Same per-value rule.

### M1 — period estimators on synthetic signals

Two independent estimators (extrema-spacing with parabolic refinement —
round 18 replaced positive-peaks-of-detrended after demonstrating a false
REFUSAL inside the 2% claim at ζ=0.30, φ near 2π, 3.2–4.6-cycle windows:
the envelope mean that detrend subtracts pushed decayed peaks under the
amplitude floor; extrema of the raw signal are baseline-free, the same
cure the damping estimators got in round 1, and the failing corner is now
grid row z30_phi60;
Hann-windowed DFT with the peak taken as the largest LOCAL spectral maximum,
sub-bin interpolated, via `lib/engineering.dft`) on synthetic damped
sinusoids `e^(−ζωn t)·cos(ωd t + φ)` with known truth, over a grid covering
the published regimes: ζ ∈ {0.013, 0.107, 0.30}, phases φ ∈ {0, 1.0, 2.0,
4.5} at ζ = 0.107 and φ ∈ {0, 1.5, 2.5, 5.0} at ζ = 0.30, a DC offset case, and
DC offset cases of BOTH signs (historical: they were added when round-8
gutted `detrend` under the old positive-peaks estimator; since the
round-18 extrema rewrite the period estimator is baseline-free by
construction, and `detrend` — now serving only the DFT path — was
re-measured in round 19 as genuinely clean-signal-invisible there, within
0.07% even at dc=100, so it moved to the known-unpinned ledger), and an
off-grid window length (n=360). Pass: measured T within **1%** of truth
for ζ ≤ 0.11, **2%** at ζ = 0.30 (both estimators).

*History (all bought by measurement, 2026-08-23):* the first DFT
implementation used a rectangular window; it carried a −4.0% image-leakage
bias at ζ = 0.30, and round-1 blind review then demonstrated it breaking the
1% claim *inside* the stated regime at off-grid phases (+1.09% at φ=4.5) and
window lengths (−1.33% at n=360) — the original grid's two phases sat in
good pockets, so the written claim was wider than the tested claim. The
Hann window fixed both (worst off-grid error 0.043%; ζ = 0.30 bias +0.23%).
Round-3 review then found the same claim-wider-than-grid vice one regime
over: at ζ = 0.30 with φ ∈ {1.5, 2.5, 5.0} the *global*-peak picker falsely
REFUSED ("fewer than 3 cycles" with 6.07 cycles in window) because the
decaying envelope's monotone leakage skirt at bin 1 (mag 2.25) beat the mode
peak at bin 6 (mag 1.80). The picker now takes the largest LOCAL spectral
maximum — a skirt has no local max, a mode does — measured to 0.25% worst
across the full phase sweep at ζ = 0.30 with every refusal pin intact. Each
review round's breaking phases became permanent grid rows.

### M2 — damping estimators on synthetic signals

Log-decrement (successive half-period spans) for ζ ≤ 0.30: the estimator's
stated guarantee is **5%** relative, but the grid checks run at **0.5%** —
round-5 review gutted the exact conversion `δ/√(4π²+δ²)` to its small-angle
approximation `δ/2π` (a systematic +4.83% at ζ = 0.30) and the 5% rows let
it through while this file claimed 0.01% capability; measured estimator
error is ≤ 0.013%, so 0.5% pins the exact formula with 38× margin. Envelope
least-squares fit for the heavy case ζ = 0.6255 (log-decrement runs out of
usable ratios): ζ within **10%** relative (its own small-angle mutant is
+28% at this ζ and is caught). Aperiodic: exponential-fit t½ within **2%**
on pure decays with the published roll/spiral rates, including near-boundary accepting rows
at exactly the declared minimums — 8 usable samples for the exponential
fit and 2 spans for log-decrement (round-11 raised the 8 to 400 and
round-12 to 12 and the 2-span floor to 4, and round-15 the DFT length
floor to 100 — all all-green, because every accepting row sat far above
the minimum; the dr_n50 row now pins the DFT length floor too; the exact-boundary rows pin the
declared constants against RAISING, and a 7-sample refusal row pins the
8-sample floor against LOWERING — round-13 dropped it to 6 all-green
between the 5-sample refusal and 8-sample acceptance rows; the round-8
bin-3 lesson applied to acceptance minimums, both directions).

*Known-unpinned implementation details (recorded rounds 5–6, deliberate):*
(a) the span-AVERAGING inside both period and damping estimators,
(b) the parabolic AMPLITUDE refinement in `find_extrema` (the TIME half
graduated to PINNED with the round-18 extrema rewrite — its removal now
reds the 0.1% peaks rows; round-14 had measured it unpinnable under the
old estimator),
(c) the `1e-6·hmax` floor in `half_spans` and the `abs` in `sig_absmax`
(the old `find_peaks` 1e-3 floor left with the round-18 rewrite; the
`t_half_exp` 1e-9 floor graduated to pinned in round 15), and
(d) `detrend` on the DFT path (round-19: gutting it stays within 0.07%
even at dc=100 — the Hann window concentrates the offset in bins 0–2 and
local-max picking ignores it),
(e) `find_extrema`'s one-sample edge exclusion width, (g) the RELATIVE
arm of `t_half_exp`'s sample floor (`1e-9·m` — the absolute arm is the
load-bearing clamp guard; the relative arm is noise-domain hygiene,
round-26), and (f) the span
midpoint-vs-endpoint timestamp convention in `half_spans` (round-23:
both survive mutation on clean signals — a uniform time shift cancels in
every slope/ratio consumer; noise rows at rung 1 are the honest pin).
Removing any of these moves clean-signal errors but keeps them far under
any honest tolerance. All earn their keep on noisy signals, which enter
the grid at rung 1; pin them then with noise rows rather than pretending a
clean-signal tolerance can see them.

*Design note bought by measurement (2026-08-23):* the first implementation
detrended by the window mean and took ratios of positive-peak amplitudes; on
a *decaying* signal the mean is a phase-dependent baseline and biased ζ by
+21% (φ=0) to −37% (φ=1) at ζ = 0.107. Both damping estimators therefore
work on **peak-to-trough spans of the raw signal** — successive-extrema
differences are exactly self-similar for a damped sinusoid and any constant
baseline cancels, which is also what lets the heavy-damping case keep three
usable spans where the |detrended| envelope had lost its tail to the
baseline shift. After the change the grid measures ζ to better than 0.01%.

### M3 — estimator honesty

Estimators must REFUSE (return a sentinel, distinct from a number) rather
than returning a garbage number when the signal cannot support the estimate.
**Every refusal path of every estimator is pinned** (round-2 blind review
gutted the unpinned ones — `zeta_envelope` and `t_half_exp` — into
hard-coded answers and the whole suite stayed green): sub-cycle windows for
the three oscillatory estimators (incl. exactly-2-extrema refusal and exactly-3-extrema acceptance rows
pinning the rewritten period estimator's floor from both sides, rounds
19-20, and an n=9 three-cycle row pinning the DFT length guard at <=9), growing-signal AND zero-signal rows
for the exponential fit and a growing-signal row for the envelope fit
(rounds 9 and 11 each found one of these paths guttable all-green) (round 9 deleted the envelope's
"not decaying" branch all-green — the pin list had covered only the
exponential's), the DFT's declared 3-cycle boundary —
pinned from BOTH sides AND at the constant itself: ~2.5 cycles must refuse,
the dr_4cyc row (4.02 cycles, bin 4) must be answered, and the dr_bin3 row
(3.31 cycles, spectral peak in bin 3) must be answered — round-7 drifted
the constant 3 → 5 all-green (accepting rows all sat at 6+ cycles), and
round-8 then drifted it 3 → 4, which dr_4cyc could not see either; only a
bin-3 accepting row pins the declared value exactly — plus the DFT's minimum-length path,
the envelope fit on a truncated heavy-damping window, and the exponential
fit on both a too-short and a growing signal.

## Planted-fault matrix — validates the checkers, not the code

Run by `tests/test_planted.sh`. Each plant must flip **exactly the named
check(s) to FAIL** while the others stay green; a plant that flips nothing
fails the harness itself. A checker that has never failed has not been shown
to work.

| Plant | Injected into | Must go red |
|---|---|---|
| P1 | Cmα sign flipped in the checker's in-memory dataset before derivation | L1 (Mw), L2, L3, L4, L5 longitudinal chain |
| P2 | lateral quartic coefficient c1 perturbed +1% before rooting | L4 lateral root match |
| P3 | root finder gutted (returns its initial guesses) | L4 both |
| P4 | synthetic generator detuned: time-dilated so period AND decay rates are +5% vs declared truth (ζ preserved) | M1: all grid-row checks, both estimators (the hand-rolled n9 row excepted); all six M2 t½ checks; M1.peaks.min3extrema; M2.logdec.minspans through the refusal arm (the dilated window drops below 3 extrema) |
| P5 | the ζ result is replaced by a constant 0.05 after the estimator runs (validates the comparator; estimator-wiring faults are covered by the mutation requirement below) | M2 ζ checks (all grid ζ values are >5% away from 0.05 by construction) |
| P6 | folding dropped: Mẇ terms omitted from longitudinal A | L2 (A31/A32/A33), L3, L4 phugoid/sp |
| P7 | every refusal result forced to ok=1 before its check | all 13 M3 refusal checks, nothing else |
| P8 | every dataset input poisoned (nonzero values scaled, zeros made nonzero, inertias scaled unevenly, θ₀ tilted, unit-check root lists scaled) | every data-derived check — 136 of 180 (the synthetic unit dataset and the CU/stability unit inputs are poisoned too) — leaving green only the pub-literal solver/exact checks (P2/P3's territory) and the structural constants |
| P10 | every DFT result forced into a refusal before its check | the 18 M1.dft checks, red THROUGH the refusal arm of `check_result` — which round-8 review gutted to print PASS with nothing noticing (no clean run or plant had ever driven a refusal through it) |
| P13 | grid time dilation ×1.0011 — ~1.1× the 0.1% peaks arm, inside every other (round-25 measured the original ×1.002 leaving a sub-1.4× widening window on the executed tolerance) | exactly the 18 M1.peaks checks |
| P14 | grid ζ inflated ×1.0055 — ~1.1× the 0.5% damping arm | exactly the 18 M2.logdec checks |
| P17 | every `check_abs` value displaced by 1.1× its own site tolerance | the 24 nonzero-abs-arm checks (residual/Vieta, solver root-match, sort tolerances, the poly4 root check; one near-boundary solver site whose honest discrepancy opposes the displacement stays green — measured and pinned) — round-27 found the abs arm's executed tolerance could widen ~2.4× before any plant noticed |
| P18 | every `check_pub` value displaced by 1.1× the site's effective bound, in the direction of the honest discrepancy | all 81 published-chain checks — the pub arm's effective pin was ~1.43× |
| P16 | the M0.gen checked value ×(1+1.1·10⁻⁹) — ~1.1× its own 10⁻⁹ arm | all 51 M0.gen/M0.gen1/M0.genN wiring checks — round-23 found this comparator was the one arm without a displacement plant at its own scale (P12 displaces at order-1), so an executed-tolerance slack there survived everything and let a real 0.001-rad wiring fault back through |
| P15 | the modes unit-family scale factors (u₀ of the synthetic dataset, `unit_scale`, `cu`) ×(1+1.1·10⁻⁹) — ~1.1× the 10⁻⁹ tight arm | the 51 tight-arm checks (five sub-proportionally scale-sensitive entries sit under the 1.1× displacement and stay covered by P8) (L1U/L2U/CU/L5.unit families, structural and u₀-independent entries excepted) — round-22 added slack to the EXECUTED tolerance at a comparison call site, decoupling it from the printed token; the other plants displace at percent scale, so sub-percent widenings slid under every gate. These three pin each effective tolerance from above at its own scale. |
| P12 | the φ and DC arguments zeroed at the grid generator call | exactly the 20 M0.gen/M0.gen1 wiring checks on rows where either is nonzero — round-21 zeroed φ inside the generator, zeroed DC, and swapped the two call-site arguments, and every gate stayed green: φ and DC are the only row parameters that never enter the expected truth, so only a direct t=0 wiring identity (sig[0] = dc + cos φ, bit-exact) can see them; the both-zero rows are reachable via P16 and carry class plantable |
| P11 | `comparator_check.eigs p11`: the `expect()` helper fed two deliberately-wrong pairs | both must FAIL — round-10 review gutted `expect()` to a tautology and every gate stayed green; with it vacuous, a 2× rel-tolerance widening in checklib slipped every remaining gate |
| P9 | every solver root nudged by 3·10⁻⁸ before the exact-arm checks, putting residual/Vieta errors inside (10⁻¹⁰, 10⁻⁶) — a band no natural run produces (DK residuals jump ~10⁻⁶ → ~10⁻¹¹ between iterations 5 and 6) | exactly the 12 L4.exact checks; a call-site tolerance widened to 10⁻⁶ turns this plant green and is caught |

`tests/test_planted.sh` asserts each plant's **full** measured red set —
the exact total FAIL count, one representative per family, and green-side
exclusions — because round-3 review showed that subset assertions let 26
checks be hardcoded vacuous with the matrix still green.

**Manifest rule (rounds 4, 11 and 12):** `tests/check_manifest.txt` lists every
check NAME with a coverage class AND its per-site tolerance token (column 4,
emitted as the third token of every check line and identity-checked like
the name — round-11 widened one check's `decimals` argument 100× and the
name-only manifest could not see it: tolerance arguments are data too —
and round-12 then edited a comparator PROBE argument into a tautology with
name and count intact, so `comparator_check`'s table-driven probes emit a
full `spec=kind|ours|ref|param|want` token (round-13 flipped a probe's ARM
to a tautology while the argument token stayed intact — the kind is data
too), identity-checked as class
`selftest`; round-20 extended the same rule to the estimator GRID — each
row emits a `params=` token of its generator arguments, identity-checked
as class `rowparams`, after a wholesale row-parameter swap survived under
an intact name+tolerance — and gave the rel arm a tight-scale probe pair
after a +1e-6 absolute slack, invisible at the 0.01/0.05 probe scale,
un-pinned all ~70 1e-9 unit checks), and `test_planted.sh` enforces (a) the unplanted
name set equals the manifest exactly — identity, not count, because round-4
review deleted one check and double-counted another under an intact
population pin; (b) every `plantable` name appears in the red-set union
across all plants — round-4 found 57 checks (the entire lateral chain among
them) outside every red set, so hardcoding them vacuous survived the matrix;
(c) a `structural` name (a builder constant no data plant can move, e.g. the
θ̇ row `[0,0,1,0]` — 10 entries) must never redden, or the exemption is
stale. Regenerating the manifest requires a written justification here.

Additional harness rule (mechanical-gates): every test script counts the
checks it executed and **fails unless the count equals its declared, pinned
population** (the check set is fixed, so the pin is exact, not a floor), so a
broken loader or a silently-skipped section cannot print an OK. Pinned:
`modes_check.eigs` runs exactly 180 checks; `measure_check.eigs` exactly 126;
`comparator_check.eigs` exactly 15. Check *identities* are pinned by the
manifest rule above. The residual/Vieta "exact" tolerance is a named
constant in `tests/checklib.eigs` (`exact_tol`), value-pinned by the
comparator self-test — round-4 review widened an inline call-site copy
10,000× with nothing noticing.

Two further round-3 lessons live in the checks: `modes_of`'s sort branches
are exercised with hand-ordered inputs (`L5.unit.*` — the ordering contract
had been riding on Durand-Kerner's accidental output order; round-14
added a wn/im-DISCORDANT pair row after mutating the sort key wn->im
survived — every prior row had the two orders coincide), and θ₀ is
actually read by the A-matrix builders (gravity terms and the φ̇ row) so a
corrupted trim pitch fails L2 instead of passing silently as a dead value.

The comparator tolerances themselves live in one place
(`tests/checklib.eigs`) and are boundary-self-tested by
`tests/comparator_check.eigs` with just-inside/just-outside pairs on every
arm — because round-2 blind review widened an inline tolerance 10× and the
entire suite, planted matrix included, stayed green. The peak-spacing checks
run at 0.1% (against the estimator's 1% guarantee) to pin the parabolic
refinement, whose removal was measured at +0.33% error.

Blind-review rounds are additionally expected to mutation-test the checkers
themselves (perturb a published value, gut an estimator or a refusal path,
widen a tolerance — in a copy) and treat any mutation the suite survives as
a top-severity finding.

## Exit gate for rung 0

1. All L and M checks green, all eighteen plants red in exactly the declared way.
2. Blind-critic rounds dry (two consecutive rounds with no actionable gap).
3. CI green on the pushed repo (devcontainer, pinned EIGS_REF=v0.41.0).

---

# Rung 1 — the longitudinal 3-DOF model, graded by rung 0

Written before the model, per the grader-first rule. Rung 1's deliverable is
the first actual flight model; rung 0's estimators and chain are the grader.
Tolerances below were claimed first and then pinned against measurement; any
widening needs a written justification here, same rule as rung 0.

## The pipeline under test

```
nonlinear longitudinal 3-DOF model (sim.eigs)
  → trim solver (level flight at the dataset condition)          (S1)
  → numerical Jacobian at trim vs the rung-0 A matrix            (S0)
  → SP-subspace IC free response → w(t) → short-period T, ζ      (S2)
  → elevator pulse → u(t) → phugoid T, ζ (both period estimators)(S3)
  → invariances: dt-halving, amplitude-halving, control-scaling  (S4)
```

**Two excitation designs were replaced by measurement on 2026-08-24 —
the first drafts of this section prescribed an elevator DOUBLET for S2
and a held STEP for S3; both failed honestly and the failures are part
of the rung's yield:**

- **Held step (S3 draft):** the step moves the trim point, so the phugoid
  oscillates about a FASTER equilibrium (u settled ≈ 283 ft/s, +1.4%) and
  both period estimators read T ≈ +1.3% off the original-trim chain value
  — agreeing with each other, disagreeing with the reference, because they
  were measuring a different operating point. Cure: a 20 s return-to-trim
  pulse; the free response then rings about the original trim (measured
  after the change: T within 0.03%).
- **Doublet (S2 draft):** the SP at ζ = 0.6255 leaves only ~2 clean
  extrema before its 3rd (amplitude ratio 0.089 per extremum) drowns in
  the phugoid the doublet co-excites (w-contamination ~0.035 vs the 3rd
  SP extremum's 0.002; measured across 2 s and 0.5 s doublets, q and w
  channels, and a quadratic detrend that the dominant SP itself corrupts).
  The estimator floor is 3 extrema, so the natural-input grading REFUSES —
  the first measured instance of the proposal's two-timescale prediction,
  at the estimator layer. Cure: the S2 excitation is the SP-subspace
  initial condition p_ph(A)·e (Cayley–Hamilton: the phugoid pair's
  quadratic annihilates its own subspace), built entirely from pinned
  chain quantities; the free response is a clean single-mode decay with
  4 usable extrema. The mode quantities being graded are properties of
  the dynamics, not of the excitation — S4 proves that where an elevator
  path exists, and a plant that poisons the sim's dataset still reddens
  every graded quantity under this IC (Q9).

plus **M1X**, the estimator bridge: the rung-0 estimators re-validated on
synthetic single- and two-mode signals built from the rung-0 roots, in the
same windows the sim grading uses, BEFORE any sim signal is graded. Needed
because the rung-0 M1 grid stops at ζ = 0.30 while the short period sits at
ζ = 0.6255, and because every sim signal is mixed-mode where the grid was
single-mode. (Extrema spacing is exactly T/2 for a damped sinusoid at any ζ
— the maxima of e^(σt)cos(ωt+φ) sit at tan(ωt+φ) = σ/ω, a uniform shift —
so the period estimator has no structural ζ limit; M1X measures the
sampling/refinement error actually achieved in the SP regime.)

## Reference values — the two layers stay separate

Every graded quantity is compared against the rung-0 chain **computed
in-harness** (`modes_of ∘ dk_roots ∘ charpoly4 ∘ a_lon` on the same dataset),
never against hardcoded copies of the published numbers. Chain-vs-published
is already pinned by L1–L5; sim-vs-chain is rung 1's own layer. Hardcoding
printed values here would stack the print-rounding tolerance on top of the
estimator tolerance and blur which layer failed.

## The model contract

The nonlinear model must **linearize exactly to the rung-0 A at its own
trim**: aerodynamic coefficients linear in (α, α̇c̄/2V, qc̄/2V, δe) about the
dataset trim point; the α̇ dependence solved in closed form (the nonlinear
counterpart of the Zẇ/Mẇ folds — α̇·(1 + K/V) = α̇₀ with K = QS·C_Lα̇·c̄/(2Vm),
which reduces to the printed 1/(1−Zẇ) factor at trim); constant thrust along
body x (the assumption already embedded in Xu's 2·CD term); level trim θ = α.
Control derivatives C_Lδe/C_mδe are **nominal and excitation-only** (declared
unsourced in sim.eigs — the public dataset has no control column); S4.ctl
scales BOTH by 1.5× (round-6 review caught the first draft scaling only
C_mδe while this sentence claimed the plural) and proves the graded mode
quantities do not depend on them.

## Checks and tolerances

### S0 — linearization parity (16 checks)

Central-difference Jacobian of the sim's derivative function at the solved
trim, per-entry against `a_lon` of the rung-0 chain: relative arm
3·10⁻³, plus a **per-entry absolute arm** sized ~2× that entry's own
measured trim-offset mechanism (`s0_abs` in sim_check.eigs). The first
draft claimed a single `5·10⁻³` absolute arm "sized for the θ-column";
measurement replaced it twice:

1. The solved trim sits at α_trim ≈ −5.4·10⁻⁵ rad (closing the 0.03% gap
   between the printed C_L = 1.108 and W/QS = 1.1084), and the dominant
   offset is **u₀·α_trim, not g·α_trim**: A13 = ∂u̇/∂q picks up −w_trim ≈
   0.0143 — 3× the drafted arm. A13's arm is 0.03; A24 (g·sinθ_trim
   mechanism, 0.00175 measured) gets 0.004.
2. A single wide arm makes every |entry| < arm/reltol unplantable:
   killing Xu outright moves A11 by only 0.021, invisible under a 0.03
   arm (measured against the first draft). Regular entries (worst honest
   diff 6.1·10⁻⁵ at A12) get 10⁻³; the doubly-small folded entries A31/A32
   get 10⁻⁵/10⁻⁶ so the fold-drop plant Q2 and the 5% C_mα plant Q1 are
   visible at their own scales. A34 (= Mẇ·A24, both sides ~0 at a
   near-zero-θ trim) is manifest class structural, with A41–A44 (the
   θ̇ row).

Measured on the first green run: every relative discrepancy ≤ 1.3·10⁻³
(A12), every absolute one inside half its arm.

### S1 — trim (5 checks)

At the solved trim: |u̇| ≤ 10⁻⁹, |ẇ| ≤ 10⁻⁹, |q̇| ≤ 10⁻¹¹ (units ft/s², rad/s²).
Held 60 s through the integrator: max |u − u_trim| ≤ 10⁻⁶ ft/s and
max |q| ≤ 10⁻⁹ rad/s — equilibrium is defined by the equations, so a trim
that drifts is a wrong trim or a broken integrator, not a tolerance case.

### S2 — short period from the SP-subspace IC (5 checks)

Free response from `sp_subspace_ic` (w-displacement 2 ft/s), w-channel,
window [0, 16 s] at 0.02 s cadence — 4 usable extrema. `T_sp` within
**1%** of the chain value; `ζ_sp` within **2%** by BOTH log decrement and
envelope fit (tightened from the drafted 10% after measuring +0.15%; the
envelope's own small-angle mutant is +28% at this ζ, so 2% still pins the
exact conversions with ~13× margin). Measured first green run: T −0.17%,
ζ +0.15% (both estimators). The nonlinear phugoid re-injection at the
graded amplitude (wamp = 2.0) is 2.8·10⁻⁴ of the first extremum,
measured from the 4th extremum's ratio deviation — round-4 review
corrected the first published figure (6.9·10⁻⁵), which had been measured
at wamp = 0.5; re-injection scales linearly with excitation amplitude,
confirming genuine second-order coupling. The M1X bridge bounds ~2.2×
the graded-regime value.

### S3 — phugoid from the elevator pulse (6 checks)

Elevator pulse (+0.005 rad for 20 s, back to trim), u(t) from t = 45 s
(the pulse-edge SP is dead: e^(−0.5515·25) ≈ 10⁻⁶), 1.0 s cadence, 280 s
run (~5 phugoid cycles). `T_ph` within **0.5%** by BOTH period estimators
(tightened from the drafted 1% after measuring −0.002% / −0.03%); `ζ_ph`
within **2%** by log decrement (tightened from 5%; measured −0.19%).

### S4 — invariances (18 checks)

The graded quantities must be properties of the MODEL, not of the numerics
or the excitation. Each invariance re-runs both sims and re-grades all six
quantities (T_sp, ζ_sp×2, T_ph×2, ζ_ph) against the base run:
- **dt** halved (recording cadence preserved via doubled decimation):
  each moves < **0.1%**.
- **amplitude** halved (IC w-displacement 1 ft/s; pulse +0.0025 rad):
  each moves < **0.5%** (bounds the operating point's nonlinearity).
- **ctl**: C_mδe × 1.5, re-trimmed: each moves < **0.2%** — the nominal
  control derivatives are excitation-only.

### M1X — the estimator bridge (14 checks)

Synthetic signals from the chain roots (σ, ω of each mode), truth known,
graded in the exact windows/cadences the sim grading uses:
- **M1X.sp** — single-mode SP at the chain's (σ_sp, ω_sp), S2 sampling,
  phases {2.0, 4.5}: T within 1%, ζ within 2% by both estimators (6).
  The ζ = 0.6255 regime the rung-0 grid never covered. Phases are chosen
  so the 4th extremum sits inside the 16 s window as the sim signal does
  (first extremum ≤ 2.3 s): φ = 0 puts an extremum on find_extrema's
  excluded edge sample and φ ∈ [~0.3, 1.7] pushes the 4th extremum out,
  hitting the envelope's already-pinned refusal (measured on the first
  harness run — both are estimator boundaries recorded at rung 0, not
  sim regimes).
- **M1X.sp2** — SP + phugoid contaminant at 2·10⁻⁴ of the generator
  amplitude (6.2·10⁻⁴ of its first extremum) ≈ 2.2× the graded S2 run's
  measured re-injection: same arms (3). At 10⁻³ the 4th extremum drowns
  and T degrades to −2.3% (measured) — the bridge bounds the sim regime
  with margin; it does not claim an arbitrary stress, and the contaminant
  is not raised to manufacture a rounder margin (~3.6·10⁻⁴ extrapolates
  to −0.8% T error against the 1% arm — too near the cliff).
- **M1X.ph2** — phugoid + 1% second harmonic (the nonlinear residual
  shape of the S3 window; the pulse-edge SP is dead there by
  construction), S3 cadence over a DELIBERATELY different window length
  (190 samples → 4.05 cycles → DFT bin 4, where S3's 236 → bin 5): T
  within 0.5% both estimators, ζ within 2%, k pinned at 4 (see above
  for the count). Round-4
  review showed that with both k-pins on the same literal, an alias plus
  a forged `k: 5` at the one shared call site satisfied both pins and
  survived the full planted matrix; with the bins different, no single
  literal passes both — a forger has to re-implement the peak picker.
  Round 5 added the Tp dual: `n_extrema` pinned at 10 (S3) and 8 (here),
  so the mirror alias (Tp fed by the DFT) reds the clean run too (5).

### O — observer verdicts, graded second (tests/observer_check.eigs, 11 checks)

The graded channels replayed through an observed binding; the physics
truth table written first; each pinned read compared to it, every check
labeled `agree` (verdict matches physics) or `divergence` (verdict
measured to contradict physics — pinned so an upstream change flips it
loudly). Measured 2026-08-24, the first external grading of observer
verdicts against a mode-structure oracle:

- **agree (8):** trim hold → `converged`; SP replay at 1 s cadence
  (~9 samples/cycle) → `oscillating` while the mode lives, `converged`
  once it has died into the re-injection floor; phugoid replay at 5 s
  cadence (9.4 samples/cycle) → `oscillating` at every probe point,
  bare-word and named form.
- **divergence (3):** phugoid replay at 1 s cadence (47 samples/cycle,
  window 10 samples) → `stable` / `diverging` / `improving` at the three
  probe points, physics truth `oscillating` at all three. The verdict is
  confidently wrong on quarter-cycles of a mode slower than the window —
  the multi-timescale prediction landing at the observer layer, upstreamed
  as GAPS.md **G4**. The pins flip the day upstream changes the
  windowing; that flip is the re-grade signal, not a rung-1 bug.

Observer plants o1 (replay frozen at the first sample — must redden the
9 motion-expecting checks and must NOT redden the settledness checks,
which a constant legitimately satisfies) and o2 (replay replaced by a
large alternation — reddens those 5), together covering all 11.

## Rung-1 planted-fault matrix — validates the graders, not the model

Run by `tests/test_sim_planted.sh`, same rules as rung 0: each plant flips
EXACTLY its declared red set (full count + representatives + green-side
exclusions), every plant run executes the full pinned 76-check population,
manifest identity (name + tolerance token) + plantable coverage enforced
against `tests/sim_manifest.txt`. Red sets measured 2026-08-24; the exact
lists are the assertions in the harness.

| Plant | Injected into | Measured red set |
|---|---|---|
| Q1 | C_mα × 1.05 in the SIM's dataset copy only (the chain reference stays clean, so the differential fires) | 5: S0.a32, S2.T, S3 (all — C_mα moves the phugoid too: ~0.6% in T, 4% in ζ) |
| Q2 | α̇ terms zeroed in the sim copy (C_Lα̇ = C_mα̇ = 0) — the nonlinear analog of rung-0's P6 fold-drop | 10: S0 folded rows a21–a23, a31–a33; S2 (all three); S3.ζ |
| Q3 | integrator degraded RK4 → Euler at the same dt | 6: S2.T, S3.ζ (Euler's numerical damping is ~25% of the phugoid's physical σ at dt = 0.05), and 4 of the S4.dt comparisons (Euler is dt-sensitive by construction) |
| Q4 | trim α offset +0.01 rad after the solver | 19: S1 (all 5), S0 a12/a13/a21/a22/a24/a31 (Jacobian at a non-equilibrium point), S2.T, S2.ζenv, the 2 SP ζ identity pins (the corrupted run shifts the extrema counts), 4 S4 spillovers |
| Q5 | thrust term dropped | 18: S1 (all), S2 (all incl. the 2 SP ζ identity pins), S3 (the three tolerance checks — the period identity pins keep their bins), 5 S4 spillovers |
| Q6 | grading timeline dilated ×1.02 (dt handed to the sim-signal estimators only) | exactly the 3 sim period checks; ζ green (dilation preserves ζ); S4 green (both sides dilated) |
| Q7 | M1X generator time-dilated ×1.05 (P4's shape) | exactly the 5 bridge period checks |
| Q8 | every graded ζ replaced by 0.05 after the estimator, identity field CARRIED | exactly the 10 ζ checks, through the NUMERIC arm — enforced by a no-refusals assertion in the harness. History: the round-6 field-less replacement red through the accessors' refusal arm instead, leaving 12 checks' truth wiring unexecuted by any plant; round-7 review demonstrated a truth-argument self-compare mutation surviving where pre-accessor Q8 had caught it. Carrying the field restores the numeric path; the accessor/null arms belong to Q12–Q15. |
| Q9 | sim dataset copy broadly poisoned (C_Lα, C_D, C_mq, C_Lq, C_L, W, g scaled — rung-0 P8's shape, for S0 coverage) | 16: S0 all plantable entries except the Q1/Q2-only a21-fold slot, S2 (all), S3 (the three tolerance checks — the identity pins keep their bins); S1 GREEN — the trim solver correctly finds the poisoned model's own equilibrium, which is the point of S1 |
| Q10 | the RE-RUN side of every S4 grading corrupted (dt ×1.02, ζ ×1.03) after the base gradings are banked | exactly the 18 S4 comparators — which stay green under every model-side plant (both sides move together) and so need their own comparator-validation plant |
| Q11 | the period_dft RESULT corrupted (T ×1.01, k+1) through a wrapper on the true DFT call site (rung-0 P10's estimator-wiring class) | exactly the 4 Td checks: S3.Tdft, S3.Tdft.k, M1X.ph2.Tdft, M1X.ph2.Tdft.k. History: round-1 blind review aliased `period_dft` → `period_peaks` at the grading call site and the whole suite stayed green (every other plant reds the two period estimators together, so nothing separated the "independent" pair — five checks were silent duplicates). The first fix claimed the wrapper itself was the defense ("under an alias Q11 flips nothing"); round-2 review refuted it by aliasing INSIDE the wrapper argument — Q11's result-corruption fired identically because the estimators agree within tolerance, and v0.41.0's silent-null missing-field access (W4) meant copying `res.k` off a peaks result tripped nothing. The load-bearing defense is therefore the two **k-pins** (`check_exact` on the DFT's spectral bin, a field only the real DFT produces): under ANY alias k is null and the CLEAN run goes red — verified against both review mutations. Q11's remaining job is proving the four Td checks can fail. |

| Q12 | the Td slot fed by `period_peaks` — the rounds-1/2 ALIAS itself, permanently installed as a plant | 7: the k-pins, the base and S4 Td rows via the `as_td` accessor refusal, and M1X.ph2.Tdft (the T values agree within tolerance — the very agreement that made the alias invisible; before the round-6 accessors this red set was just the 2 k-pins). Added after round-3 review found the k-pins' null-rejection arm had zero executed coverage: widening `check_exact` to tolerate null ("defensive W4 handling") survived all three suites and silently re-disabled the anti-alias defense. Q12 drives a null through that arm on every planted-matrix run — the round-2 verified-by-hand claim is now a repeatable harness assertion (the guards'-guards pattern: rung-0's P10/P11 class, one level further out). |

| Q13 | the Tp slot fed by `period_dft` — round-5's MIRROR alias, installed as a plant | 7: the n-pins plus the Tp rows through the `as_tp` accessor (2 before the round-6 accessors). Round-5 review found the anti-alias defense was one-sided: rounds 1–4 hardened only the Td slot, so feeding Tp from the DFT survived every suite (five checks silently duplicating the Td family). The dual pins — `check_exact` on `n_extrema`, a field only the real extrema estimator produces, values differing 10 vs 8 per the round-4 one-literal lesson — red the CLEAN run under the mirror alias; Q13 proves their null arm fires. |

**The slot-identity enumeration (closing the rounds-1/2/4/5 class, not its
instances):** every estimator SLOT in the grading helpers now carries a
`check_exact` pin on a field only its true estimator produces, all pinned
values distinct — S3.Tdft.k=5, M1X.ph2.Tdft.k=4 (spectral bin, DFT only);
S3.Tpeaks.n=10, M1X.ph2.Tpeaks.n=8 (`n_extrema`, extrema estimator only);
S2.zlog.nr=2, S3.z.nr=8 (`n_ratios`, log decrement only), S2.zenv.nf=3
(`n_fit`, envelope fit only — the ζ estimators previously returned
identical `{ok, ζ}` shapes, so a ζ-slot alias had no field to trip until
measure.eigs grew the identity fields; rung-0 suites unaffected, additive).
S2's T slot needs no pin: a DFT alias there refuses outright on the
1.75-cycle SP window and reds the clean run through `check_result`.

**Round 6 extended the enumeration one layer out, to the CONSUMER read
sites:** the helper-slot pins could not see a check ROW rewired to the
wrong-but-agreeing result (demonstrated twice: S4's phTd rows fed from
Tp, and the M1X zlog rows fed from zenv — both survived every suite).
Every read of a paired-estimator result now goes through an identity
ACCESSOR (`as_td`/`as_tp`/`as_zl`/`as_ze`) that refuses unless the
result carries its own estimator's identity field, so a cross-wired read
reds its check on the clean run via the refusal arm (both round-6
mutations verified caught). Accessor refusal arms are exercised every
planted run: Q12/Q13 for the period pair, Q14/Q15 for the ζ pair (Q15,
the SP-side slot swap, is round-7's addition — and Q8/Q10's fabricated
dicts deliberately CARRY the identity fields so those plants keep
validating the numeric comparator rather than being absorbed by the
accessors; see the Q8 row). **Declared residual depth limit:** a
simultaneous accessor-gut plus row-alias double mutation on the M1X sp
rows survives (single mutations of either kind are caught); double-fault
depth is beyond the rung-1 armor bar by decision, recorded here so a
later rung can revisit rather than rediscover.

| Q14 | the ζ-slot alias: `zeta_envelope` in grade_ph's log-decrement slot (the two agree within tolerance on the phugoid, so only the identity machinery can see it) | 6: S3.z + S3.z.nr + the three S4 phz rows + M1X.ph2.z, all through `as_zl`'s refusal arm and the nr pin's null arm — the accessor-era plant added with the round-6 read-site fix. |

| Q15 | the SP-side ζ slots SWAPPED (envelope in the log-decrement slot and vice versa) — q14's dual | 16: the S2 ζ rows and pins, the six S4 sp ζ rows, and the six M1X sp ζ rows, all through the accessor refusal / null arms. The only plant driving `as_ze`'s refusal arm with a real wrong-estimator result. |
| Q16 | every check_below/check_relabs value displaced 1.1× its own site's executed tolerance (structural S0 sites exempt, cross-checked by the manifest's never-red rule) | 16: the 5 S1 + 11 plantable S0 checks. Added at rung-2 round 1, which found the executed comparator tolerance unpinned across 6 orders in the rung-2 twin — rung-0's P15/P17 class, inherited by both rungs at once. |

Observer plants o1/o2 are declared in the O section and enforced by
`tests/test_observer.sh`.

## Loop closure (round 8, 2026-08-24) — what the loop certified and what it did not

Eight blind rounds, every round productive (rounds 1–7 each surfaced a
real defect, all in the GRADING APPARATUS, never the physics — round 6
independently re-derived the whole aero model from Caughey's conventions
and confirmed deriv() correct). Round 8's closure audit, recorded per the
evidence-of-absence rule:

**Certified:** the published chain and estimator grids (rung 0, intact);
S0–S4 + M1X with the plant matrix (15 at rung-1 closure, since grown by
the rung-2 loop's cross-rung fixes to 20), slot-identity pins, read-site
accessors (all four refusal arms plant-driven), no-refusals numeric-arm
guards on Q8 and Q10, manifest identity + class-vocabulary enforcement;
the observer layer with both o-plants; CI green on every round's push.

**Known-unexercised (deliberate, bounded):** (a) the shell harnesses' own
FAIL branches (the harness-of-harness regress ends here); (b) accessor-gut
+ row-alias DOUBLE mutations; (c) sim-harness window/cadence parameters
are pinned only through the k/n identity integers — arm-sized drifts are
equivalent mutants; (d) the S2 re-injection magnitude (2.8·10⁻⁴) sizing
the M1X.sp2 bound is a recorded measurement, not a live check — a model
change pushing it toward ~6·10⁻⁴ stales the bridge claim before any arm
reds, so rung 2 should re-measure it when the model grows.

## Exit gate for rung 1

1. All S, M1X and O checks green (76 + 11, populations pinned); all twenty
   Q plants and both o plants red in exactly the declared way; rung-0
   suite untouched and green.

---

# Rung 2 — the lateral 3-DOF model: three timescales, and the level-set stress

Written before the model, per the grader-first rule. The rung-0 lateral
chain (L1–L5: Dutch roll −0.08066 ± 0.7433i, roll −1.2308, spiral
−0.04641) is the reference; the rung-0 estimator grid is ALREADY validated
in exactly these regimes (the `dr_*` rows are the Dutch-roll parameters;
the M2 aperiodic rows are the published roll/spiral rates) — rung 0
anticipated this rung. The genuinely new stress is the proposal's: every
lateral state oscillates symmetrically about ZERO, where
`entropy_of_num` is blind by construction (H(x) = H(−x)), so the observer
verdicts must ride the #294 value channel; and one binding (φ) carries
THREE timescales (roll t½ 0.56 s, DR T 8.45 s, spiral t½ 14.9 s).

## The pipeline under test

```
nonlinear lateral 3-DOF (latsim.eigs), longitudinal state frozen at trim
  → symmetric-flight trim = the origin, exactly            (T1)
  → numerical Jacobian at the origin vs the rung-0 a_lat   (T0)
  → mode-pure annihilator ICs (Cayley–Hamilton products):
      DR-pure  → v(t) → T (both period estimators), ζ      (T2.dr)
      roll-pure → p(t) → t½ by exponential fit             (T2.roll)
      spiral-pure → φ(t) → t½ by exponential fit           (T2.spiral)
  → invariances: dt, amplitude, control-derivative scaling (T3)
  → M2X bridge: the estimators in rung-2's exact windows,
    single-mode and mixed                                  (M2X)
  → observer verdicts incl. the level-set pins             (O2)
```

The excitation design inherits rung 1's measured lesson directly: control
inputs co-excite modes whose timescales defeat the estimator floors, so
precision grading uses mode-pure ICs built from pinned chain quantities —
here the full annihilator products (the lateral quartic factors as
DR-quadratic × roll × spiral; killing two factors leaves the third's
subspace). A rudder-doublet run exists for the OBSERVER layer (the
product-shaped multi-timescale signal), not for precision grading.

## The model contract

`deriv_lat` over [v, p, φ, r] with the longitudinal state frozen at the
rung-1 trim (u = u₀, w = 0, θ = θ₀ — the standard decoupled lateral
model; full coupling is rung 3): coefficients linear in (β, pb/2V, rb/2V,
δa, δr); gravity enters as g·sinφ·cosθ₀; the Ixz cross-inertia handled
EXACTLY by solving the coupled moment pair (Ix·ṗ − Ixz·ṙ = L,
Iz·ṙ − Ixz·ṗ = N — algebraically identical to the chain's primed
ix/iz/(1−ix·iz) form, verified by hand before coding); φ̇ = p + tanθ₀·r.
Its Jacobian at the origin must equal `a_lat` entry-by-entry. Aileron/
rudder derivatives are nominal and excitation-only (the dataset has no
control columns); T3.ctl scales all of them ×1.5.

## Checks and tolerances (claims written first; measurements recorded after)

- **T0 (16):** rel 10⁻⁶ / abs 10⁻⁸ — far tighter than drafted, because
  the exact-origin trim removes every rung-1 offset mechanism: measured
  worst discrepancy on the first run was **2.2·10⁻¹⁶** (machine epsilon;
  the model is exactly linear at h-scale perturbations about the origin),
  so the arms sit 7+ orders above any libm delta while catching faults at
  their own scale. Structural (zero/unit on BOTH sides by construction,
  no data fault can move either): a23, a31, a32, a33, a43. a12 and a34
  are zero only because the DATA has C_yp = 0 and θ₀ = 0 — R9 poisons
  both, so they are plantable.
- **T1 (6):** all four residuals at the origin ≤ 10⁻¹² (measured exactly
  0 — symmetric flight IS the trim, identically); 60 s hold:
  max |v|, max |p| ≤ 10⁻⁹.
- **T2 (8):** DR T within **1%** by both estimators (measured −0.002% /
  −0.10%), ζ within **2%** (measured +0.008%); roll t½ within **1%**
  (tightened from the drafted 2%; measured +0.10% — the grading window is
  2.5 s ≈ 3.5 half-lives, shortened from a 5 s draft after the bridge
  showed a 9-half-life window's tail drowning in any contaminant, see
  M2X); spiral t½ within **1%** (measured +0.002%). Plus the three
  identity pins: Tdft.k = 5, Tpeaks.n = 11, z.nr = 9 (the 45 s / 0.2 s
  window). Round 5 added **T2.ctl (6)**: the dual-surface doublet — the
  only run in which the six control derivatives multiply a nonzero
  deflection — DR graded from its free response against the same chain
  references (measured −0.02% / +0.14% / +0.15%), the response SIGNS
  pinned at mid-doublet (C_lδa > 0 ⇒ p > 0; C_nδr < 0 ⇒ r < 0), and
  max|p| pinned as a gearing regression value. The one-literal rule holds WITHIN this rung's shared call
  path (T2's bin 5 vs M2X's bin 6); T2's k = 5 does repeat rung-1's
  S3 value across programs — safe, because a producer-level forgery in
  the shared measure.eigs still reds the k = 4 and k = 6 windows, but
  the first draft of this sentence claimed distinctness from every
  rung-1 site, which was false (round-1 review).
- **T3 (14):** dt halved < 0.1% and amplitude halved < 0.5% for all
  five graded quantities; ctl (all six control derivatives ×1.5) on the
  CONTROL-EXCITED doublet run: the graded DR moves < 0.2% AND max|p|
  scales by 1.5 within 2% (the measured gain: 1.5000070). The first
  draft ran the ctl invariance on the mode-pure IC runs — which never
  deflect a surface, so all five rows compared bit-identical runs and
  reversed, 1000×-geared controls shipped green (round-5 review). The
  aperiodic modes have no ctl rows now BY DECISION: their graded runs
  are zero-input, so a control invariance there is structurally
  meaningless — the control path is graded where controls actually act.
- **M2X (11):** single-mode DR in a DELIBERATELY different window (52 s →
  6.15 cycles → bin 6, one-literal rule) with its own k/n/nr pins
  (6, 12, 10); DR + spiral-drift contaminant (amplitude 5% — the
  baseline shape the span estimators claim immunity to, and deliver:
  ζ measured +0.46% under it); roll decay + DR contaminant at 10⁻³
  (measured: at 5·10⁻³ over a 5 s window the tail drowned and t½ read
  −4.9% — the 2.5 s window plus measured-scale contaminant keeps the
  bridge inside the sim regime, the rung-1 sp2 discipline); spiral +
  DR contaminant at 5·10⁻³. Sim-signal impurities MEASURED (round 2:
  nonlinear run vs exact-linear RK4, same IC/dt, max channel diff over
  amplitude): roll 2.5·10⁻⁵ (bridge bound 40×), spiral 1.7·10⁻⁴ (29×),
  DR 1.25·10⁻³ (drs 5% bound 40×) — the first draft's "10⁻⁴ scale"
  understated the DR residual ~12×; these are the recorded numbers the
  bounds are judged against, per rung-1's closure item (d).
- **Identity armor, inherited:** the DR trio reuses the rung-1 identity
  fields/pins/accessors (k, n_extrema, n_ratios — distinct pinned values
  from rung 1's sites, per the one-literal rule). Roll and spiral are
  graded by the SAME estimator (t_half_exp) against truths 26× apart, so
  a row swap reds numerically and no identity field exists or is needed;
  cross-kind rewires red via field mismatch. Alias plants replicate the
  rung-1 set for the DR slots only.

## O2 — observer verdicts (the rung's reason to exist)

Written-first physics truths, graded as `agree`/`divergence` rows like
rung 1:

All measured 2026-08-24; 13 checks in `tests/observer_lat_check.eigs`
(8 agree, 5 divergence):

- **The level-set pair (the headline, agree-class):** on the DR replay at
  1 s cadence (v swinging ±5 through zero), `report of v` reads
  **oscillating** at all three probe points — the #294 value channel
  handling exactly the motion the entropy channel cannot see. The
  blindness itself is pinned via the MIRROR identity, not prose: a
  +5 → −5 assignment registers `why == 0` exactly (zero entropy change
  across a full reversal, H(x) = H(−x)), while the 5 → 2.5 control row
  registers |why| ≈ 0.21 — proving the instrument is alive, so the zero
  is the identity, not a dead probe. (The first draft planned to pin
  `how is v == 0`; probing showed `how`'s semantics don't isolate the
  identity — the mirror pair does, cleanly.)
- **The unit triplet (divergence-class — G5, the rung's NEW upstream
  finding, EigenScript#1045):** one physical trajectory (the spiral-pure
  bank-angle decay, still halving every 15 s at the probe) replayed in
  radians reads `converged`, and in degrees or milliradians reads
  `moving` — `rel = Δv/(1+|v|)` degenerates to an absolute deadband
  below |v| ≈ 1, making verdicts depend on the binding's unit. The
  proposal predicted level-set blindness would be the lateral rung's
  stress; the measured surprise one layer deeper is that the VALUE
  channel has its own sub-unit degeneracy.
- **The window-vs-timescale pair (G4's fast side):** the roll decay
  (t½ = 0.56 s) reads `stable` mid-decay at 0.02 s cadence (window spans
  0.36 t½ — `improving`'s contraction test cannot fire; divergence) and
  `improving` correctly at 0.2 s cadence (window ≈ 3.6 t½; agree).
  With G4's slow side, the pair says verdict correctness is
  window-to-timescale relative in both directions.
- **φ carries three timescales** (rudder-doublet run): `oscillating`
  during the DR phase (agree ×2); the sub-milliradian spiral tail reads
  `converged` while still actively decaying (divergence — G5's
  small-magnitude corollary).
- Observer plants: o1 (frozen replay → the 10 motion-expecting checks)
  and o2 (an UNEQUAL-magnitude alternation → the 7 non-oscillating
  pins). o2 deliberately differs from rung 1's: a pure ±A alternation is
  entropy-invisible by the very identity being pinned, so the magnitudes
  must differ for the mirror-flip pin to red (measured before pinning).

## Rung-2 planted-fault matrix

Same rules (exact red sets, full 73-check population every run, manifest
identity + class vocabulary, no-refusals guards on the fabricating
plants R8/R10 from the FIRST commit — rung 1's rounds 7–8 lessons are
load-bearing here, not relearned). Twenty-two plants (fourteen at first
build; R15–R22 added by review rounds 1–8), red sets measured
2026-08-24 and asserted exactly in `tests/test_latsim_planted.sh` —
the counts below are the CURRENT (round-6) reality; the graded control
run added at round 5 grew eleven of them:
R1 C_nβ ×1.05 (7: weathercock rows + DR periods incl. the ctl run's +
spiral), R2 Ixz dropped (14: every primed row + DR incl. ctl + roll),
R3 Euler (5: DR ζ incl. ctl, roll t½, their dt-invariances), R4 all
states offset from the origin (20: T1 complete + parity + ctl +
spillovers), R5 C_lβ ×1.3 (12: dihedral — spiral, DR incl. ctl, roll,
a DFT bin flip), R6 grading-dt ×1.02 (6: all sim periods and t½s; ζ
green), R7 M2X generator dilation (12, incl. the count pins and gen.s1
identities), R8 ζ→0.05 / t½→1.0 with fields carried (8, numeric arm
asserted), R9 broad poison incl. C_yp/C_yr made nonzero and θ₀ tilted
(19), R10 rerun-side corruption (the 13 graded T3 comparisons, numeric
arm asserted — the gain row correctly stays green), R11/R12/R13 the
Td/Tp/ζ slot aliases (9 each: pins + accessor-refused rows incl. ctl),
R14 t½ result ×1.05 (4: exactly the aperiodic rows), R17 generator
body corrupted (12: the wiring identities), R18 controls
reversed/geared (3: exactly the sign and amplitude wiring pins — the
round-5 class), R19 the ctl run's grading dt alone dilated (2: exactly
the ctl period rows — round-6 review rewired those rows to the
mode-pure run's agreeing results and every suite stayed green; the
row-rewire class needs a RUN-SEPARATING plant, since identity pins
read the source object, not the row's wiring, and the ζ row already
had its separator in R4), R20 the M2X.drs grading alone corrupted (3:
exactly the drs rows — round 7 fed them from the agreeing single-mode
grading; r7/r17 corrupt both generators together, so the mixed/pure
pair needed its own separator), R21 the dt-rerun gradings alone
corrupted (5: exactly the T3.dt rows — round 7's cross-rerun swap:
self-compares are caught by R10, dt↔amp swaps by this plant, ctl↔other
swaps by R19; the same round extended the ROW-token mechanism to every
graded RUN's call-site parameters — a rerun whose dt is silently not
halved is the round-3 P12 class again, and the manifest row identity
now sees it in both rungs — with rung-1 twins Q20/Q21), R15 every check_below/
check_relabs value displaced 1.1× its OWN site's executed tolerance,
structural sites exempt (17: the 6 T1 + 11 plantable T0 — added after
round-1 review widened check_below's executed bound ×10⁶ with every
suite green, rung-0's P15/P17 executed-tolerance class; the same fix
went to rung 1 as Q16, whose S1/S0 comparators had the identical
unpinned shape), R16 every check_rel value displaced 1.1× its own
executed rel arm in the DIRECTION of the honest discrepancy (31 as of round 5: all
tolerance rows — round-2 review found round 1's fix two-thirds done:
check_rel, the third comparator, had no displacement plant, and a
single-site ×10 executed widening survived every suite; the direction
rule is rung-0 P18's, added after the same round measured a rung-1 site
whose honest offset absorbed 6% of an always-positive displacement's
margin; rung 1 got the twin as Q17, 36 rows). All three comparators in
both rungs are now pinned at 1.1× their executed scale. Round 3 then
zeroed the M2X.drs contaminant with every suite green — bridge
contaminant amplitudes are P12-class parameters (they never enter any
expected truth, so no tolerance arm can see them) — and rung-0's
round-20 ROWPARAMS class was inherited: every bridge generator call in
BOTH rungs now emits its executed arguments as a `ROW` token,
identity-checked against the manifest's `rowparams` lines (verified:
the zeroed contaminant now fails the row-identity diff). Round 4 then
showed the token pins the PRINT, not the USE — a body-level
decontamination inside the generator kept the token intact and every
suite green — so the OTHER half of rung-0's P12 defense was inherited
too: gen.s0/gen.s1/gen.len wiring identities per bridge row (sig[0]
and sig[1] recomputed bit-exactly from the same arguments; the length
against n), with R17/Q18 (generator body corrupted: a1 nudged
1.1·10⁻⁹, contaminant dropped, one sample short) proving all twelve
can fail in each rung. Populations 56 → 68 and 64 → 76. Round 4 also
retired the rowparams cross-platform risk with evidence (the pinned
devcontainer reproduces the full-precision tokens bit-exactly, CI run
32792297147) and recorded M2X.rollc's executed margin: 1.9× (rel error
5.1·10⁻³ against the 1% arm — the one bridge row inside the 2×
brittleness band; every other row has ≥4.3× headroom).

**Round 8 (final) — the run-USE class and closure.** Round 8 found the
round-4 lesson (the token pins the print, not the use) unapplied to
RUNS: a rerun body ignoring its amplitude argument, or a ctl rerun
built from the unscaled derivatives, made invariance rows compare a run
to itself — three single-line mutants survived every suite (rung-1 ctl
gutted, the rung-1 twin of rung-2's round-5 vacuity that was never
twinned back; rung-1 ph amplitude ignored; rung-2 spiral amplitude
ignored; the sp/dr/roll amplitudes were covered only by plant-spillover
luck). Closed with **run-USE gain rows**: each amp rerun's window
amplitude must be 0.5× its base run's (measured 0.4963–0.5001), and
each ctl rerun's excitation must scale ×1.5 (rung-1 S4.ctl.gain
measured 1.5112; rung-2's T3.ctl.gain already existed) — with vacuity
plants Q22/Q23/R22 proving every gain row can fail, and all three
round-8 mutants verified to red the CLEAN run. Populations 76 → 79
(rung 1) and 73 → 76 (rung 2); plants 22 + 22.

## Loop closure (rung 2, round 8 of 8, cap reached)

Both loops ran to their 8-round caps, every round productive, and every
finding in BOTH loops was in the grading apparatus — the physics was
never faulted (independently re-derived at rung-1 round 6 and rung-2
round 1). **Certified:** the full three-rung differential stack with
plant-driven coverage of every comparator's executed tolerance (1.1×
displacement, both rungs), every estimator slot and consumer read-site
(identity pins + accessors + alias plants), generator and run print AND
use (ROW tokens + gen.s0/s1/len + gain rows + body/vacuity plants),
cross-rerun row-rewire separators (R19–R21, Q20/Q21), the control path
where controls act (signs, gearing, measured ×1.5 gains in both rungs),
manifest identity incl. tolerance tokens, rowparams and class
vocabulary, and the observer layers (24 verdict pins, 4 o-plants, the
mirror identity, the G5 unit triplet). **Known-unexercised, by
decision:** the shell harnesses' own FAIL branches; accessor-gut +
row-alias DOUBLE mutations; O2 channel wiring beyond the incidentally
protected probe; arm-sized window/cadence drifts on runs pinned only
through their identity integers (the ctl doublet's parameters are
pinned via the pamp/gain regression rows only); and the recorded
sim-impurity magnitudes, which are measurements, not live checks —
rung 3 should re-measure them when the model grows.

## Exit gate for rung 2

1. All T, M2X and O2 checks green (populations pinned); every plant red
   in exactly the declared way; rung-0 AND rung-1 suites untouched and
   green.
2. Blind-critic rounds: until dry (two consecutive clean) or 8 rounds —
   the rung-1 cap, with the identity armor arriving pre-built this time.
3. CI green on the pushed branch (devcontainer, EIGS_REF=v0.41.0).


---

# Rung 3 — the autopilot: closed-loop control, and the observer as the supervisory layer

Written before the controller, per the grader-first rule. The reference
values below were computed from the rung-0 chain BEFORE any control code
existed (`A_cl = A + B·K`, then the same `charpoly4 → dk_roots →
modes_of`), so the closed-loop truth table is a prediction, not a
description.

## Scope, and what is deliberately NOT in this rung

The ladder listed rung 3 as "6-DOF + control tapes, byte-exact replay
gate". Two deliberate changes, both recorded so they are decisions rather
than drift:

- **6-DOF is deferred.** None of this rung's three predictions need it;
  the longitudinal 3-DOF plant of rung 1 already carries the modes the
  controller acts on. 6-DOF is a large lift orthogonal to the question
  being asked, and would dilute it.
- **The byte-exact replay gate is deferred, because today it would be
  VACUOUS by construction.** The sim contains no nondeterminism — no RNG,
  no clock, no human input — so a same-seed two-process diff passes
  trivially and would certify nothing. The replay gate arrives with its
  nondeterminism source (sensor noise, or human control input), not
  before. Recorded as known-unexercised rather than shipped as a green
  check that measures nothing.

What this rung IS: the first phugoid model that **acts**. Rungs 0–2 grade
free responses; nothing ever consumed a verdict. Here a controller closes
the loop, and the observer is graded as a component of that loop.

## The pipeline under test

```
longitudinal 3-DOF plant (rung 1, unchanged)
  + elevator control column B from the nominal control derivatives
  → inner loop: classical pitch-rate feedback, de = de_trim + kq·q   (C0, C2)
  → closed-loop Jacobian vs A + B·K                                  (C0)
  → measured closed-loop modes vs predicted eigenvalues, 3 gains     (C2)
  → invariances: dt, amplitude, gain-scaling                         (C3)
  → supervisory layer: damper ENGAGED/DISENGAGED by observer verdict (C4)
  → the three pre-registered predictions                             (C5)
  → observer read-path cost profile                                  (C6)
```

## The closed-loop reference (computed 2026-08-25, before the controller)

`B = [0, −8.4264, −0.5574, 0]` from the nominal C_Lδe/C_mδe, with the same
Zẇ/Mẇ folds as `a_lon`. Law `de = de_trim + kq·q`, so `A_cl = A + B·K`
with `K = [0,0,kq,0]`:

| kq | SP T (s) | SP ζ | phugoid T (s) | phugoid ζ |
|---|---|---|---|---|
| 0.00 | 9.1341 | 0.62542 | 46.918 | 0.013245 |
| 0.25 | 9.1510 | 0.66997 | 49.233 | 0.024916 |
| 0.50 | 9.2681 | 0.71236 | 51.438 | 0.035855 |
| 1.00 | 9.8615 | 0.79164 | 55.580 | 0.055945 |

Monotone in both modes, which is itself a check: a controller that damps
the short period while *degrading* the phugoid has the sign wrong (the
first gain tried during design did exactly that — phugoid ζ went to
−0.045 — and the chain caught it before any sim ran).

## Checks and tolerances (claims first; measurements recorded after)

- **C0 — closed-loop parity (16):** central-difference Jacobian of the
  CONTROLLED derivative function at trim vs `A + B·K`, per-entry, with
  **rung 1's S0 arms, not rung 2's** — corrected after measurement: this
  is the longitudinal plant, whose trim sits at a small non-zero α, so
  the entries that are structurally zero in the chain matrix are
  O(u₀·α_trim) here (worst **0.01405** at a13, measured at kq = 0.5).
  Round 15 corrected two stories attached to that number. It is NOT
  `−w_trim`: measured, `−w_trim = 0.015188` against `J[0][2] = 0.014054`,
  7.5% apart, so the identity was an approximation stated as an equality.
  And `0.01428` is not "rung 1's sibling row" — it is **rung 3's own value
  at kq = 0**. The residual is linearly gain-DEPENDENT (0.014283, 0.014168,
  0.014054, 0.013825, 0.013366 at kq = 0, 0.25, 0.5, 1, 2), because
  `B[0] = 0` makes the *reference* `A_cl[0][2]` gain-free while the
  measured sim Jacobian moves — the elevator reaches `w` and `q`, which
  feed `u̇` through the nonlinear aero. C0 runs at kq = 0.5 only, so the
  residual's gain-dependence is real, small, and unmeasured. Rung
  2 reached machine epsilon only because its lateral trim is the exact
  origin. Arms: rel 3·10⁻³ with per-entry absolute arms as in rung 1.
  This pins that the controller's linearization is the matrix the
  predictions were computed from — without it, C2 could pass against a
  plant that is not the one the oracle describes.
- **C1 — trim preserved (5):** with kq = 0 the closed-loop model must
  reproduce rung 1's S1 exactly (residuals ≤ 1e-9, 60 s hold), proving
  the controller is a no-op at zero gain rather than a new plant.
- **C2 — closed-loop modes graded (22):** nine graded rows plus their
  identity pins and the four separate `C2.ph.*` rows — for kq ∈ {0.25, 0.5, 1.0}, the
  SP-subspace free response of the CLOSED loop, graded by rung-0's
  estimators against the predicted A_cl eigenvalues above: T within
  **1%**, ζ within **2%**, plus the identity pins (k/n_extrema/n_ratios,
  values distinct per site per the one-literal rule). `C2.ph.zlog`, the
  separate phugoid-IC row, ships a **5%** ζ arm — the phugoid's log
  decrement is read off a longer, softer envelope than the three kq rows'
  — and residual 0.16%, so the arm is loose but not load-bearing. It was
  declared nowhere until round 8 found it.
- **C3 — invariances (8):** dt halved < 0.1%; excitation amplitude halved
  < 0.5% (declared here and MISSING from the first draft — added at
  round 1); and a **gain-USE witness** — the measured ζ must MOVE with kq
  in the predicted direction and magnitude (rung-2 round-8's lesson: an
  invariance row is only a test if the varied parameter reaches the
  dynamics; here the gain is the parameter, so its effect is the pin).
- **C4 — supervisory layer (population pinned in harness):** the damper
  is engaged/disengaged by `report of q`, not by a hand-written trigger.
  Physics truth table written first: engaged during the transient,
  disengaged once settled. Rung 3 ships no `agree`/`divergence` manifest labels (rungs 1–2 used them
because those rungs graded verdicts as their deliverable); here the
distinction lives in each pin's own comment, and the DIVERGENT ones —
verdicts that contradict physics — are `C5.p1.inner.{diverging,converged}`
(a decaying mode reported as diverging half the time) and the blind
cadences `C5.sp.{c010,c020}`.
- **C5 — the three pre-registered predictions** (below). Since round 12
  the inner verdict stream is pinned for ORDER as well as content —
  `C5.p1.inner.runs = 37` and `.maxrun = 260`. The counts alone could not
  see it: a count-preserving repack (group by category in first-appearance
  order, so the multiset is exactly what the trajectory produced and every
  plant still reds) turned 37 maximal runs into 4 and left 85/85, all 16
  plants, the manifest and lint green — while "an autopilot would fight a
  healthy mode half the time" silently became "it flips once in 400 s".
  Round 12 justified `maxrun` as "a quarter period — T/4 = 257 samples vs
  260 measured". **Round 13 refuted that, and it was wrong twice in
  cancelling directions.** This stream never engages the gain (`.osc` and
  `.engagements` are both pinned at 0, so `sup_run` holds kq at 0.0 for all
  8000 steps), so the plant flown is `A`, not `A + B·K` — period 46.918 s,
  T/4 = 234.6 samples, not 257. And the segments in a cycle are
  260/220/198/260, so the longest is 0.277 of a period, not 0.25, and it
  *decays* (260, 258, 256, 254…), making it an initial-condition transient
  rather than a period invariant. A wrong plant (−9%) cancelled a wrong
  fraction (+11%) into an agreement that looked exact. `maxrun` is an order
  FINGERPRINT and is labelled as one. What genuinely ties to the physics is
  `runs`: the predicate flips 4× per period, so 4 × 400 s / 46.918 s = 34.1
  transitions plus 3 start-up runs = 37 — verified against the segment
  dump: the first cycle is 260+220+198+260 = 938 against T/dt = 938.35, and
  later cycles sum to 939 — agreement to within a sample, not exact.
  **Round 14 deleted a second false clause from this same sentence.** Round
  13's replacement added "and it tracks gain across the ramp (kq 0.5 → 35,
  kq 1.0 → 31)", which is refuted by the premise six lines above it: if the
  gain never reaches the dynamics, nothing derived from this trajectory can
  track it. Measured — quadrupling `eff_gain` to 2.0 leaves every one of
  the nine `C5.p1.inner` rows bit-identical, and plants s1 (gain sign
  flipped) and s2 (gain inert) red **zero** of them. Three consecutive
  rounds got this one pin's justification wrong.
  What that actually establishes is worth more than the clause it replaces:
  **`kq` is provably inert on this row**, and its inertness is the
  refutation itself — `osc = 0` means the supervisory layer never engages,
  so the gain is never applied. The two rows pinned at 0 (`.osc`,
  `.engagements`) ARE the witness. The row's ROW token still carries
  `params=0.5`; it is carried for identity, not because the run uses it,
  and that is now stated rather than left to look like a USE witness. This is the repack class round 3 closed for `C5.p4`'s onset and
  round 4 for `C4.ph`'s horizon, never applied to the one stream that IS
  the result.
- **C6 — read-path profile (a RATIO gate, not an absolute budget):** the shipped gate asserts
  three ratio FLOORS — read/write, write/floor, and (since round 10)
  write/noread — plus a CEILING on write/floor (3.0). No µs/read and no
  µs/frame is asserted anywhere; the absolutes below are context, not
  arms. Four planted faults, one per arm. read/write has no ceiling deliberately (load
  INFLATES it — 3.38 measured on unmutated code); write/floor can have one
  because load DEFLATES it (0.98 measured at round 7), so the arm cannot
  flake in the direction load pushes. Baseline
  probe measured 2026-08-25 before this rung: **0.70 µs/read**, read path
  = 64% of a write+read workload, and observed *scalar* writes ≈ free
  (0.31 s vs a 0.30 s fully-unobserved floor over 200k frames, n=5
  medians). **Numbers
  corrected at round 1** — n=5 medians on the shipped program (120k
  frames): read 0.501 s, write 0.243 s, floor 0.169 s, so read/write =
  2.06 and write/floor = 1.44; repeated runs land in **1.95–2.13** for
  read/write — the first draft's "2.09–2.8×" was falsified at round 4 and
  round 5 measured 1.94 on a quiet box. Round 8 then measured **1.81** on a
  quiet box, below that floor, so the honest reproduction spread across
  ~20 whole-gate runs here is **1.75–2.50**, plus 3.38 under concurrent
  load. The margin over the 1.5 bound is ~17% at the low end. Both
  bound literals are identity-pinned against their declared values, and
  each variant's EXECUTED work is pinned too (round 5 halved the floor
  variant's loop and the gate reported a greener ratio while every suite
  stayed green). That spread is a REPRODUCTION note, not an arm —
  read/write has no ceiling, deliberately: a concurrent-load run on this box
  measured read/write = 3.38 on unmutated code, so a ratio ceiling there
  would flake on a shared runner. (write/floor's ceiling is safe for the
  opposite reason — load deflates that ratio.) What pins the workload instead is the read
  POPULATION: round 6 measured the per-predicate split and found
  `oscillating of u` fires **0** times in 120k frames (conv 11563, stable
  65157, div 56566 = the pinned 133286), so a hit count cannot see that
  read at all — deleting it (−25% of the read path, ratio 1.98 → 1.67,
  outside this very window) and adding three more copies (+75%, → 2.91)
  both left the pin matching and the suite green. The four read sites are
  also counted against the source, and `READ_SITES` is published in the
  variant's own output as `read 133286 480000`. Round 7 then showed both
  of those layers bind something other than the executed loop body, and
  that round 6 fixed only `run_read` while its two siblings kept the
  counter-only pin — the repo's own twin-the-fix rule (mechanical-gates
  §94) broken by the fix for the finding that motivated it. Deleting TWO
  of `run_floor`'s four per-frame writes left `floor 120000` matching,
  collapsed the floor 45%, and turned write/floor from 1.44 into **2.59**,
  taking the published 78/22 read/write split with it (round 8 re-measured
  the mutant at 57/43 rather than the 67/33 first recorded — a DERIVED
  number that was never itself measured); moving the
  zero-hit read out of the measured loop, and adding a fifth read spelled
  `if not (oscillating of q):`, both evaded the site grep entirely. The
  three measured bodies are now pinned by IDENTITY (comment- and
  blank-stripped hash plus line count, so a body that hashed to nothing
  cannot pass vacuously); round 8 retired the grep, which caught nothing
  the hashes miss. Round 8 also found the CALL SITE free —
  `run_floor of (0)` kept every layer matching while the measured floor
  became 0.008 s of interpreter startup and write/floor read 28.75 against
  a published 1.44 — so each variant now prints its own line from its own
  loop counter and the gate matches the whole output exactly. Round 9 then
  found the pins stop at the three function bodies while the MODULE LEVEL
  stayed free: eight lines of `unobserved:` busywork before the dispatch —
  definitionally not read-path cost — left every body hash, line count and
  exact output matching while moving the published read/write from 2.13 to
  **3.47**. That is the one direction with no arm, since read/write has no
  ceiling, and "the read path dominates" is this rung's whole upstream
  argument; everything outside the three bodies is now pinned by the same
  comment-stripped hash. Verified: all three round-7 mutants, an
  equal-line-count constant swap, `run_floor of (0)`, a fabricated extra
  output line, round 9's warmup insertion and an `N` change all fail
  loudly; a FULL-LINE comment — at module level or inside a body — does
  not (a comment appended to a code line does red the gate: fail-safe, and
  round 8 corrected that claim, which had been stated unscoped). Both bounds are
  single-sourced constants shared with their planted faults, after round
  4 found that editing a gate's literal alone left its own fault citing
  the old value and the suite green. The gate takes **median of 5**, not 3 —
  round-2 review caught an unmutated write/floor pair reading 0.96 under
  median-of-3, which is below the bound; three samples do not insulate a
  20% margin on a shared runner. The first attribution here — "of the 0.332 s of
  observer cost, 78% is reads and 22% is writes" — was **wrong about the
  22%**, and so was this section's withdrawal of the earlier probe.
  Round 10 measured the missing regime variable. Against a read-FREE
  module (`tests/ap_profile_noread.eigs`) an observed scalar write is
  **indistinguishable from the unobserved floor** — noread/floor measured
  0.88, 1.04, 1.11, 1.21, 0.88 across five n=5 rounds, i.e. 1.0 within
  noise — which is what the withdrawn probe reported.
  The +44% is EigenScript#915's arming penalty, and round 10 published the
  wrong MECHANISM for it — "module-granular" — which round 11 refuted from
  the source and the runtime. `obs_needed` is a single flag on `EigsState`
  (`src/eigenscript.h:561`), set in `compile_ast` and documented there as
  monotonic. So arming is scoped to the **interpreter state**: a verdict read in a dead
  function, in a *different file*, or even a bare string constant
  `"report"` arms bookkeeping for every assignment in every module of the
  program (GAPS.md **G7**, upstreamed as EigenScript#1046 — whose first
  version carried round 10's wrong granularity and a workaround, "split
  reads into their own module", that is measurably ineffective).
  Round 13 then showed the "intrinsic write cost is
  indistinguishable from zero" framing is **circular**: `noread` and
  `floor` are BOTH states in which the entropy walk does not run (an
  unarmed program, and an `unobserved:` block), confirmed by
  `EIGS_OBS_GATE_STATS` — read/write/floor compile `observed`, `noread`
  `unobserved`. So `noread − floor ≈ 0` is a tautology of the definition,
  not a measurement about writes, and it invites exactly the wrong
  conclusion for a program like `sup_run`. Stated correctly: **for a
  program that reads verdicts at all — which an autopilot does — the split
  is reads-direct ~75% and observed-write bookkeeping ~25%** (write 0.231
  vs floor 0.160), and #915 can elide that 25% only in a program with no
  reads anywhere, i.e. never here. That is why `sup_run` wraps its
  integrator in `unobserved:`. The 22% first published and the "94/6" round
  10 replaced it with were both wrong; this is the third attribution and
  the first that names its regime. This makes the rung's
  upstream argument stronger: #915's gate cannot help an autopilot not
  merely because reads dominate, but because one read anywhere in the
  program disarms the write optimisation everywhere in it.
  The gate asserts all three ratios plus the ceiling (so `floor` and
  `noread` are load-bearing rather than numbers nobody reads), and each
  arm carries a planted fault proving it can reject. `write/noread` is the
  noisiest pair in the gate (1.21-1.59 across five rounds, two separate
  processes), so it re-measures once before failing, as `write/floor`
  already does. Shipped as
  `tests/ap_profile.eigs` + `tests/test_ap_profile.sh`, gating the
  read/write RATIO (measured 1.75–2.50×, bound 1.5×) rather than a wall
  time, because absolute budgets flake on shared CI runners while the
  ratio is a property of the runtime. If reads are ever made O(1) the
  gate fails BY DESIGN and says so in its own failure message — that is
  the signal to re-measure and re-justify, not a regression.

## The three pre-registered predictions (recorded before the build)

1. **Verdict-driven INNER-loop damping will limit-cycle.** A controller
   that modulates the damper gain continuously on a discrete verdict at
   inner-loop rate will chatter at the band boundary — the same failure
   Eigen-Geometric-Control shows (99% of ticks sign-flipping, 94% of
   control budget spent fighting itself), sourced here from the observer's
   band quantization rather than from the control law. Measurable: command
   sign flips per tick, and the estimators reporting a spurious oscillation
   at the sampling frequency.
2. **Verdict-driven SUPERVISORY control will hold, at a measurable lag.**
   Engagement latency ≈ the window duration; the closed-loop response
   while engaged still matches the C2 predictions.
3. **No single observation cadence serves both longitudinal modes.**
   The window is 10 SAMPLES, so the window's SPAN scales with cadence, and
   the mode is visible only inside a band of spans.
   Short period (T = 9.13 s) and phugoid (T = 46.9 s) differ by 5.1×, so
   the cadence that makes one observable makes the other useless. This is
   G4 escalated from "wrong verdict" to "unsatisfiable requirement", and
   it is the strongest argument EigenScript#1044 will get.

**Both predictions 1 and 2 were REFUTED by measurement, and the
refutations are the rung's main result.** Recorded here in full, since a
pre-registered prediction that survives contact unchanged teaches less
than one that does not:

- **Prediction 1 (inner-loop chatter) — WRONG, and "blind" understated
  it.** At inner-loop rate the 10-sample window spans 1% of a cycle, and
  on a smoothly DECAYING phugoid the classifier never once says
  `oscillating` (0 of 8000 reads). But it is not silent — it alternates
  between **`diverging` (3934, 49%)** and **`converged` (4056, 51%)**,
  because a window that short sees a locally monotone slice of a sinusoid
  and calls it a trend. The ACTUATOR is silent (0 engagements, since only
  `oscillating` triggers it); the OBSERVER is loud and wrong. An autopilot
  acting on this would command corrective action against a healthy
  decaying mode half the time. Pinned as `C5.p1.inner.{osc,diverging,
  converged,engagements}`.
- **Prediction 2 (supervisory holds cleanly) — HALF WRONG.** Supervision
  does act on a persistent regime (**56** `oscillating` verdicts in 80
  reads on the phugoid at a matched cadence), but the engagement
  **flickers 17 times** in a single phugoid episode, because the raw
  verdict carries no hysteresis at the band boundary. A damper cycling on
  and off 17 times is not "holds". A control consumer needs a debounce
  the predicates do not provide. Pinned as `C5.p2.sup.toggles = 17`,
  `C4.ph.osc = 56`, and — since the layer's actual output is the
  actuator timeline — `C4.ph.first_engaged = 19`. Round 4 justified that
  row as "recorded at decim 50 against cadence 100, so it is an
  independent read rather than an alias of the verdict onset"; round 11
  showed the arithmetic does not support it — with `cadence/decim = 2`
  exactly, 19 is the identity `2·onset + 1` = 2·9+1. The row still earns
  its place, but for a different reason than the one published: it is the
  only row that proves the gain reaches `rec.engaged` at all, and plants
  s7 and s12 red it. (These are the
  round-1 re-measurements on the corrected IC; the first draft published
  59 and 15 from the looping trajectory.)
- **Prediction 3 — CONFIRMED; its stated MECHANISM was refuted at round
  15.** The conclusion holds: for the short period there is no usable
  cadence at all. The explanation published with it — "blind because the
  window is shorter than a period" — was falsified by the rung's own
  shipped row. `C5.sp.c050` has a window spanning **0.55** of the SP period
  and reports `oscillating`. Swept, the response is a two-sided BAND, and
  only the lower edge had ever been published:

  | cadence | window span | span / T_sp | verdict |
  |---|---|---|---|
  | 0.4 s (`c040`) | 4 s | 0.43 | blind — last blind |
  | 0.44 s (`c044`) | 4.4 s | 0.47 | **sighted** — visibility starts near HALF a period |
  | 0.5 s (`c050`) | 5 s | 0.55 | sighted |
  | 1.0 s (`c100`) | 10 s | 1.08 | sighted — last sighted |
  | 1.2 s (`c120`) | 12 s | 1.29 | blind again — unpublished until round 15 |

  The two edges have different causes: below, too little of a fold in the
  window to classify; above, the G5 horizon — by the time the window fills
  (9 cadences) the mode is under the deadband. Prediction 3 and the horizon
  law were written up as separate findings and they meet here. All four
  edge rows are now pinned, so no windowing change can restore the monotone
  "fast = blind, slow = too late" story — the same defect round 2 closed
  for `C5.p4`'s ramp, recurring in the neighbouring table.
  The sighted rows all report exactly once, *after* the mode has decayed
  (t ≥ 4.4 s for a mode gone by ~5 s; at the earliest sighted cadence the
  latency is still ~1.9 decay constants). Detection latency and phase lag
  are the same quantity, so a windowed verdict cannot act on a well-damped
  transient. The complement holds
  too: the lightly-damped phugoid (ζ = 0.036, ringing for many periods)
  IS actionable — 56 of 80 reads at a matched cadence.

**The design law, corrected at round 1 — it takes TWO conditions, and the
first draft named only one.** Round-1 review swept the excitation
amplitude and found the verdict fraction moving, which looked like a
refutation of the persistence law. Re-measured on a physically valid
trajectory (see the IC correction below), the truth is sharper than
either version:

| phugoid excitation | onset read | last `oscillating` read | verdicts / 80 |
|---|---|---|---|
| uamp 0.2 | — | — | **0** |
| uamp 0.25 | 9 | 18 | 7 |
| uamp 0.30 | 9 | 38 | 23 |
| uamp 0.35 | 9 | 53 | 34 |
| uamp 0.40 | 9 | 58 | 40 |
| uamp 0.45 | 9 | 78 | 56 |
| uamp 0.50 | 9 | 78 | 56 |
| uamp ≥ 1.0 | 9 | 79 (last read) | 56 |

**Corrected at round 2.** The first draft sampled only the two ends of
this table and called the result a sharp cliff with "no graceful
degradation". Probing the 2.5× interval between them shows a clean
monotone **ramp**, and the mechanism is better than a threshold: the
onset is identical at every amplitude (read 9, the window filling), and
only the CUTOFF moves. The mode decays, |q| falls under the absolute
band, and from that read onward `oscillating` stops for good. The
apparent "flat 56–57 across a 16× range" was never an invariance — it is
**saturation**, the crossing pushed past the end of the 400 s run, so the
count is capped by the window rather than by the physics. So:

> **A verdict is actionable iff (a) the regime persists beyond ~1–2
> observation windows, AND (b) the observed channel still clears the
> deadband — and since a decaying mode's amplitude falls, (b) is a
> HORIZON in time, not a gate. Supervision does not switch off; it runs
> out. Larger excitation buys a later crossing and a longer horizon,
> monotonically.**

For a sub-unit channel like pitch rate the band is absolute
(EigenScript#1045), so that horizon depends on the unit and the
excitation rather than on the dynamics.

That is G5's third independent sighting and the first where it changes
what an actuator does. Pinned as `C5.p4.a0{20,30,35,40}.{osc,horizon,onset}` — twelve rows,
four rows spanning the ramp plus the clean zero, all sited MID-ramp
rather than at the saturated end, since a row at saturation (uamp 0.5:
horizon 78 against a last read of 79) flips by one under any perturbing
plant and measures brittleness rather than signal.

## The round-1 correction: the phugoid IC was flying loops

Recorded because it invalidated the first version of every headline
number. `sp_subspace_ic` (rung 1) normalises the excitation on the **w**
channel — correct for the w-dominant short period it was written for.
Rung 3 reused it for the PHUGOID, which is u-dominant (|v_u/v_w| = 6.75
on the annihilator column used), so normalising on w rather than u
over-scales the excitation by **6.75×**; demanding 5 ft/s of w landed at
a scale factor of 938 only because the raw column's normalisation is
arbitrary. The fix moved both knobs at once — `w=5.0` (scale 938.4) to
`u=2.0` (scale 55.6), a **16.9×** reduction — of which the channel is
6.75× and the remaining 2.5× is the amplitude literal. (Round-5 review:
the first draft called that 938 a component ratio — wrong by ~137×.
Round-6 review: the fix's own text then attributed the whole 16.9× to
the channel. The measured consequences below were right both times; the
stated cause was wrong both times. A causal story is a hypothesis
however precise it sounds.) The
"phugoid episode" started 97° nose-down and flew **7 complete pitch
loops**, with airspeed swinging from −9 to 714 ft/s on a linear-aero
model valid near Mach 0.25. Nothing in the rung could see it — the
supervisory rows graded no mode quantity, and the excitation amplitude
appeared in no ROW token.

Three fixes, all inherited from lessons rungs 1–2 had already paid for:
`mode_ic` now takes a scale CHANNEL (rung 2's `lat_mode_ic` had this
from the start — the twin was never applied to rung 1's helper); the ROW
token carries the whole initial condition, so any change to the
excitation breaks manifest identity; and **C2.ph grades the supervisory
IC at fixed gain against the phugoid prediction** (T +0.036%, ζ −0.16%),
so the run is now proven to be the mode it is named after. On the
corrected trajectory every qualitative finding survived — the numbers
moved (osc 59→56, toggles 15→17) but blindness, flicker and the cadence
law all held.

## Rung-3 planted-fault matrix

Same rules, and the rung-1/2 armor arrives PRE-BUILT from the first
commit (identity pins with distinct values, read-site accessors, ROW
tokens on every generator AND graded run, USE witnesses on every varied
parameter, displacement plants at 1.1× executed tolerance for all three
comparators, no-refusals guards on fabricating plants, manifest identity
+ class vocabulary). Plants planned, red sets measured then pinned:
The SHIPPED matrix, with red counts measured from
`eigenscript tests/ap_check.eigs <plant>` — rung 2's convention, which
this section's first draft did not follow. (Round-8 review: the list here
was the *planned* one and had gone wrong for five plants — s5, s12 and
s13 were mis-described, s15 as written did not exist, and s16 was missing
while the exit gate counted 16. A planned list left in place reads as a
measured one.)

| Plant | Injected into | Reds |
|---|---|---|
| s1 | gain sign flipped (the design error the chain caught before any sim ran) | 43 |
| s2 | gain never reaches the dynamics — controller inert, every row still claiming its gain | 43 |
| s3 | Euler instead of RK4 | 21 |
| s4 | trim offset by 0.01 rad | 60 |
| s5 | amplitude/linearity witness vacuity (`C3.lin.shrinks`) | 1 |
| s6 | grading-dt dilation (estimator side only) | 6 |
| s7 | verdict stream frozen — supervisory layer inert | 36 |
| s8 | ζ/T constant-replaced with the identity field carried | 13 |
| s9 | broad dataset poison (CLa/Cma/Cmq/W) | 46 |
| s10 | dt-rerun grading separator | 1 |
| s11 | ζ estimator slot alias | 16 |
| s12 | verdicts forced to `oscillating` — the dual of s7 | 42 |
| s13 | `check_below`/`check_relabs` displacement at 1.1× the executed tolerance | 17 |
| s14 | `check_rel` displacement at 1.1× the executed tolerance | 19 |
| s15 | phugoid DFT slot aliased to `period_peaks` (makes `as_td` live) | 2 |
| s16 | its mirror — the extrema slot fed by the DFT (makes `as_tp` live) | 1 |

C6's FOUR planted faults live in `tests/test_ap_profile.sh` — one per arm
(read/write floor, write/floor floor, write/floor ceiling, write/noread
floor) — and are counted separately; they are not part of this 16.

**Two arms, one measurement (round 15).** Since `noread/floor` is ~1.0 by
construction, `write/noread` and `write/floor` are near-duplicates — 1.42
and 1.40 in the same run, same bound, both faults at ratio 1.00.
`write/noread` earns its place by naming the regime (its denominator is an
unarmed *program*, not an `unobserved:` block), so its failure is the
diagnostic that says "upstream scoped the arming, re-attribute and close
G7". It is not extra coverage, and the four-arm count should not be read
as four independent facts.

**Instrument confound in the read/write split (round 14).** `run_read`
executes 133,286 more observed assignments than `run_write` — the `hits`
counter, itself pinned — so `(read − write)`, the numerator of the "~75%",
contains write cost. A confound-free variant with an identical assignment
population (bare predicate statements instead of `if …: hits is hits + 1`)
measures 76.7/23.3 against the shipped formula's 81.6/18.4 in the same
session, and the shipped formula's own run-to-run spread is 74–82%. The
published ~75/25 survives, but the instrument is not clean and the number
should be read as "roughly three-quarters", not to a digit.

**Margin note (round 12).** Two arms ship with sub-15% headroom on a
shared runner: `write/floor` (bound 1.15, measured 0.98 once under load at
round 7) and `write/noread` (bound 1.15, measured 1.21–1.59). Each gets
exactly one re-measure before failing. `read/write` was given no ceiling
because load inflates it; these two floors are the mirror risk and the
retry is the whole mitigation. If either flakes on CI, the fix is to widen
with a re-justification here — not to add retries.

**Known-unexercised (deliberate, bounded), rung 3:** (a) the three ratio
arms bound each pair but not the read/write SPLIT they support — with all
of them green the split could in principle move a long way, and it is
published as a measurement, not asserted; (b) C0's gain-independence is
structural (`B[0] = 0`), stated but not measured — all 16 C0 rows run at
kq = 0.5; (c) the C6 absolutes (read/write/floor/noread wall times) are
context and are asserted nowhere; (d) the shell harnesses' own FAIL
branches, as in rungs 1 and 2; (e) the interiors of `C5.sp.*` (four cadence rows) have no
`runs`/`maxrun` twin — the three streams that needed one got it at rounds
12, 13 and 14, and these are short (60 and 30 reads) with `.osc` pinned at
0 or 1, so there is little interior to permute; (f) **prediction 2's
second clause is not measured** — "the closed-loop response while engaged still matches the C2
predictions" was pre-registered, and no shipped check grades the
supervisory trajectory against the C2 predictions (`C2.ph` certifies the
EXCITATION, explicitly, not that run). Round 13 caught it missing from
both the write-up and this list. It is neither confirmed nor refuted; it
is UNMEASURED, and rung 3 ships saying so rather than quietly dropping a
pre-registered clause.

## Exit gate for rung 3

1. All C checks green (96, population pinned); every one of the 16
   plants red in exactly the declared way; the C6 gate green including
   all FOUR of its planted faults (one per arm);
   rungs 0–2 suites untouched and green.
2. Blind-critic rounds: until dry (two consecutive clean) or 8 rounds.
3. CI green on the pushed branch.
4. The three predictions each reported with their measurement — including
   any that failed to reproduce.
