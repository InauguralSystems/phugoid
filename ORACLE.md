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

Two independent estimators (peak-spacing with parabolic refinement;
Hann-windowed DFT with the peak taken as the largest LOCAL spectral maximum,
sub-bin interpolated, via `lib/engineering.dft`) on synthetic damped
sinusoids `e^(−ζωn t)·cos(ωd t + φ)` with known truth, over a grid covering
the published regimes: ζ ∈ {0.013, 0.107, 0.30}, phases φ ∈ {0, 1.0, 2.0,
4.5} at ζ = 0.107 and φ ∈ {0, 1.5, 2.5, 5.0} at ζ = 0.30, a DC offset case, and
DC offset cases of BOTH signs (round-8 review gutted `detrend` to identity
and the dc=+2 row stayed green — the positive amplitude floor in
`find_peaks` tolerates a positive offset undetrended, a negative one it
does not), and an off-grid window length (n=360). Pass: measured T within **1%** of truth
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
(b) the parabolic AMPLITUDE and TIME refinements in `find_extrema`
(round-14 removed the time half alone, all-green), and
(c) the amplitude floors (`1e-3` in `find_peaks`, `1e-6·hmax` in
`half_spans`, `1e-9·m` in `t_half_exp`) and the `abs` in `sig_absmax` — rounds 9-10 removed all four
all-green on clean synthetics. Removing any of these moves clean-signal
errors 10–50× but keeps them ≤ 0.03%, far under any honest tolerance.
All earn their keep on noisy signals, which enter the grid at rung 1; pin
them then with noise rows rather than pretending a clean-signal tolerance
can see them.

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
the three oscillatory estimators, growing-signal AND zero-signal rows
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
| P4 | synthetic generator detuned: time-dilated so period AND decay rates are +5% vs declared truth (ζ preserved) | M1: all checks, both estimators; all six M2 t½ checks; M2.logdec.minspans through the refusal arm (the dilated window drops below 3 extrema) |
| P5 | the ζ result is replaced by a constant 0.05 after the estimator runs (validates the comparator; estimator-wiring faults are covered by the mutation requirement below) | M2 ζ checks (all grid ζ values are >5% away from 0.05 by construction) |
| P6 | folding dropped: Mẇ terms omitted from longitudinal A | L2 (A31/A32/A33), L3, L4 phugoid/sp |
| P7 | every refusal result forced to ok=1 before its check | all 12 M3 refusal checks, nothing else |
| P8 | every dataset input poisoned (nonzero values scaled, zeros made nonzero, inertias scaled unevenly, θ₀ tilted, unit-check root lists scaled) | every data-derived check — 135 of 179 (the synthetic unit dataset and the CU/stability unit inputs are poisoned too) — leaving green only the pub-literal solver/exact checks (P2/P3's territory) and the structural constants |
| P10 | every DFT result forced into a refusal before its check | the 16 M1.dft checks, red THROUGH the refusal arm of `check_result` — which round-8 review gutted to print PASS with nothing noticing (no clean run or plant had ever driven a refusal through it) |
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
`selftest`), and `test_planted.sh` enforces (a) the unplanted
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
`modes_check.eigs` runs exactly 179 checks; `measure_check.eigs` exactly 69;
`comparator_check.eigs` exactly 13. Check *identities* are pinned by the
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

1. All L and M checks green, all eleven plants red in exactly the declared way.
2. Blind-critic rounds dry (two consecutive rounds with no actionable gap).
3. CI green on the pushed repo (devcontainer, pinned EIGS_REF=v0.41.0).
