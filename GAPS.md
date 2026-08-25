# Upstream gaps surfaced by phugoid

The forcing-function ledger (fleet standard): language/runtime/stdlib gaps
this consumer hits get RECORDED here and upstreamed — never silently worked
around. Each entry says what was needed, what exists today, and what was done
locally in the meantime.

## Open

### G1 — no polynomial root-finder or general eigenvalue routine in the stdlib
**Upstreamed: EigenScript#1042 (2026-08-24).**
**Hit at rung 0 (2026-08-23).** Extracting flight modes needs the eigenvalues
of a 4×4 state matrix (equivalently the roots of its characteristic quartic).
`lib/linalg.eigs` stops at `eigenvalues_2x2`; `lib/numerics.eigs` has
`power_iteration` (dominant eigenvalue only, and not complex). phugoid
hand-rolled Faddeev–LeVerrier (characteristic polynomial from a matrix) and
a Durand–Kerner complex root-finder in `modes.eigs` — both are generic and
belong in `lib/linalg`/`lib/numerics`, validated here against published
eigenvalues (Caughey eq. 5.54/5.95) and by residual/Vieta identities.
**Candidate upstream API:** `charpoly of A` and `poly_roots of coeffs`
(complex roots as [re, im] pairs), or a direct `eigenvalues of A`.

### G2 — no complex-number support in the stdlib
**Upstreamed: EigenScript#1043 (2026-08-24).**
**Hit at rung 0 (2026-08-23).** Mode analysis is intrinsically complex-valued.
phugoid represents complex numbers as `[re, im]` lists with hand-rolled
`cadd/csub/cmul/cdiv/cmag` (`modes.eigs`), all five unit-checked directly against
hand-computed values (the CU check family — the root-finding oracles alone
are structurally blind to these helpers; a halved cdiv survived them). Workable, but every consumer doing
signal processing or root-finding will re-roll the same five functions
(lib/engineering.eigs's own `dft` already returns `[re, im]` pairs with no
shared arithmetic on them). **Candidate upstream API:** a `lib/complex.eigs`
with the arithmetic + polar helpers, adopted by `engineering.dft`.

### G3 — `log` builtin saturates below 1e-10, silently
**Upstreamed: EigenScript#1041 (2026-08-24).**
**Hit at rung 0 (2026-08-23, round-15 blind review).** The runtime clamps
`log` inputs below 1e-10 to ln(1e-10) = -23.0259 (verified:
`log of 1e-15 == log of 1e-10`; 2e-10 and up compute correctly). This is
presumably the finite-by-construction design (no -inf), but it is a SILENT
plateau: numeric code fitting log-domain data (our exponential-decay
estimator) got a confidently wrong answer — 4-14% off, measured — when a
small-amplitude signal decayed through the clamp range, because the
relative sample floor admitted clamped samples. Local mitigation: an
absolute 1e-9 sample floor in `t_half_exp` plus an amplitude-0.001 grid
row. **Upstream question:** is the clamp documented semantics, and should
it be? A lint hint or doc note for log-of-tiny would have saved the hunt;
consumers doing likelihoods or entropies in log space will hit the same
plateau.

### G4 — observer value-channel window is a fixed 10 samples; a slow mode under a fast cadence reads `diverging`, confidently
**Upstreamed: EigenScript#1044 (2026-08-24).**
**Hit at rung 1 (2026-08-24, observer grading layer).** The value-channel
predicates classify over a window of the last **10 observed samples**
(docs/PREDICATES.md), with no per-binding control. A mode slower than ~10
samples of the consumer's cadence cannot fold inside the window, so the
verdict is not merely insensitive — it is **confidently wrong**: the
phugoid (T = 46.9 s) replayed at 1 Hz reads `diverging` on its rising
quarter-cycles, `stable`/`improving` elsewhere (measured; the pinned
divergence rows in `tests/observer_check.eigs`). The same signal decimated
to 5 s cadence (9.4 samples/cycle) reads `oscillating` correctly at every
probe point. `dynamics` already documents the entropy-channel cadence
sensitivity ("sampling every step … everything reads equilibrium",
physics.eigs header); the value-channel version is sharper because
`diverging` is an alarm verdict a consumer would act on. A frame-locked
consumer (this repo's whole premise: verdicts at a frame deadline) cannot
decimate per binding without hand-building shadow bindings per timescale —
exactly the multi-timescale gray band the proposal predicted would break
first. **Upstream question:** should the window be per-binding
configurable (samples or seconds), or should a slow-fold detector widen it
adaptively? A time-aware window (seconds, not samples) matches how flight
modes are specified. Local mitigation: the O checks pin today's misreads
as `divergence`-class rows so an upstream windowing change flips them
loudly and rung 1 re-grades.

### G5 — value-channel verdicts are unit-dependent below |v| ≈ 1
**Upstreamed: EigenScript#1045 (2026-08-24).**
**Hit at rung 2 (2026-08-24, observer grading layer).** The value channel's
relative step `rel = Δv/(1+|v|)` degenerates to an ABSOLUTE deadband for
sub-unit magnitudes, so the verdict depends on the binding's UNIT.
Measured (the `O2.units.*` triplet in `tests/observer_lat_check.eigs`):
one physical trajectory — the spiral mode's bank angle, 0.05 rad decaying
with t½ = 14.9 s, probed while still halving every 15 s — reads
`converged` in radians and `moving` in degrees or milliradians. The
radians verdict is also wrong on its own terms (0.7° off wings-level and
actively rolling), but the inconsistency is the sharper defect: no
physical semantics can depend on a representation choice. First exposed
here because phugoid is the first consumer carrying sub-unit AND
super-unit bindings for the same physics (`dynamics`' oscillators are
O(1) by construction). Same family as G4: verdict correctness currently
depends on the sampling cadence (G4) and the unit (G5), neither of which
is physics. A fast-mode sibling of G4 was also measured (not separately
upstreamed — it is the same window mechanism from the other side): the
roll mode (t½ = 0.56 s) reads `stable` mid-decay when the 10-sample
window spans only 0.36 t½, and `improving` correctly when the cadence
puts ~3.6 t½ in the window (`O2.roll.fast` / `O2.roll.matched`).

### G6 — `linalg.solve_linear` returns null on a singular system, silently
**Hit at rung 3 (2026-08-25).** Building the "controller inert" plant by
zeroing the sim's control derivatives crashed the rung-1 trim solver with
`cannot index null` at `x[j] is x[j] + step[j]` — three frames away from
the cause. Root: with the elevator column of the trim Jacobian identically
zero the system is singular, and `lib/linalg.solve_linear` returns **null**
rather than raising (verified directly: a 3x3 with a zero row returns null,
no error). The caller then indexes it. Same silent-null family as W4, but
in a numeric routine where the caller cannot distinguish "singular" from
"bug in my matrix construction". **Candidate upstream API:** raise, or
return a result carrying an `ok` flag like this repo's own estimators do —
a solver that cannot say "singular" forces every caller to re-detect it.
Local mitigation: the plant was rebuilt to zero the GAIN instead (which is
the more faithful inert-controller fault anyway); `trim_solve` still does
not check, which is recorded here rather than silently patched, because
the honest fix is upstream.

## Watch (not yet blocking)

### W1 — `dft` is O(n²); fine at rung 0, will not scale to swarm telemetry
`lib/engineering.dft` at n≈470 costs ~1s of the rung-0 suite. Rung 4's
N-aircraft telemetry grading will want a real FFT (radix-2 is ~60 lines of
EigenScript). Upstream when the need is measured, not before.

### W2 — `^` is bitwise XOR, not power
Not a bug — documented behavior, and `pow of [a, b]` exists. Recorded because
numeric-code authors habitually write `x ^ 2` and get a silent wrong number
(caught here in the first probe script). A lint hint for `^` between float
operands might be worth an upstream issue if it bites again.

### W3 — no ODE integrator in the stdlib; second consumer re-roll
`lib/calculus.eigs` has quadrature only. `dynamics` hand-rolled
semi-implicit Euler (`physics.eigs step`); phugoid has now hand-rolled
RK4 + Euler twice (`sim.eigs`, and `latsim.eigs` at rung 2 — the
integrator can't be shared without function-valued plumbing the rungs
don't otherwise need), validated by the S0/T0 parity and dt-invariance
checks. Two consumers re-rolling the same numerics is the G1/G2 shape one
rung earlier. Candidate upstream API: `lib/ode.eigs` with `rk4_step` /
`semi_implicit_step` over a user derivative function. Upstream when a
third consumer rolls one, or when rung 4's swarm makes integrator cost a
measured concern.

### W4 — missing dict-field access is a silent null
`d.k` on a dict without `k` returns null silently (v0.41.0; exit 0).
Bit in round 2 of the rung-1 review: a checker copying `res.k` off the
WRONG estimator's result (which has `n_extrema`, not `k`) tripped
nothing, letting an estimator-alias mutation survive — the anti-alias
k-pins had to be designed around comparing against null instead of
relying on field access erroring. Likely intended fail-soft semantics
(the #971/#975 reform track owns the policy); recorded so rung-2+
checkers keep the pattern: pin a field only via a comparison a null
cannot pass.

### G7 — #915's write-path gate arms per MODULE, and a single verdict read defeats it
Found at rung-3 blind-critic round 10, 2026-08-25, `eigenscript` v0.41.0.
Upstreamed as **EigenScript#1046**.
EigenScript#915's optimisation makes observed *scalar writes* nearly free.
The arming is module-granular: **one predicate read anywhere in a module —
including in a function that is never called — re-arms full entropy
bookkeeping for every assignment in that module.**

Minimal reproduction. A write loop of 200k frames, alone in its module,
against the same module plus a dead four-line function. n=5 medians, three
independent rounds:

| module | 1 | 2 | 3 |
|---|---|---|---|
| write loop alone | 0.163 | 0.150 | 0.149 |
| + a never-called `if oscillating of z:` | 0.217 | 0.222 | 0.213 |
| + a never-called `if z > 0.0:` (control) | 0.169 | 0.156 | 0.145 |

The predicate read costs ~42% on code that never runs it; the numeric
comparison in the same position costs nothing.

Consequences measured in this repo's own C6 gate (`tests/test_ap_profile.sh`):
- `write/floor` was read as "observed writes cost +44% over the unobserved
  floor". It is not measuring intrinsic write cost at all. Neutering only
  the four predicate reads inside `run_read` — a function the `write`
  variant never enters — drops it from ~1.45 to ~1.03.
- Against a read-free control module (`tests/ap_profile_noread.eigs`),
  `noread/floor` measures **1.07**: an observed scalar write really is
  ~free, as the pre-rung-3 probe reported. Rung 3's round-1 review
  withdrew that claim as unreproducible. **The claim was true and the
  withdrawal was wrong** — nobody had identified the regime variable.
- So of this shape's observer cost, the intrinsic write share is a few
  percent, not the 22% published; most of the "write" cost is this
  arming penalty. Pinned live as `write/noread > 1.15` with a planted
  fault, so the day upstream makes arming per-binding, C6 fails and says
  to re-attribute and close G7.

This strengthens rung 3's upstream argument rather than weakening it: the
reason #915's gate cannot help an autopilot is not only that reads
dominate, but that the consumer's reads *disarm the write optimisation for
the whole module they live in*. `unobserved:` is the existing workaround
and is what rung 3's `sup_run` already does; the gap is that a consumer
which legitimately reads verdicts pays on every unrelated assignment in
the same file.
