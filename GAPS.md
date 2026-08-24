# Upstream gaps surfaced by phugoid

The forcing-function ledger (fleet standard): language/runtime/stdlib gaps
this consumer hits get RECORDED here and upstreamed — never silently worked
around. Each entry says what was needed, what exists today, and what was done
locally in the meantime.

## Open

### G1 — no polynomial root-finder or general eigenvalue routine in the stdlib
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
**Hit at rung 0 (2026-08-23).** Mode analysis is intrinsically complex-valued.
phugoid represents complex numbers as `[re, im]` lists with hand-rolled
`cadd/csub/cmul/cdiv/cmag` (`modes.eigs`), unit-checked directly against
hand-computed values (the CU check family — the root-finding oracles alone
are structurally blind to these helpers; a halved cdiv survived them). Workable, but every consumer doing
signal processing or root-finding will re-roll the same five functions
(lib/engineering.eigs's own `dft` already returns `[re, im]` pairs with no
shared arithmetic on them). **Candidate upstream API:** a `lib/complex.eigs`
with the arithmetic + polar helpers, adopted by `engineering.dft`.

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
