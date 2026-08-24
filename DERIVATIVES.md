# Boeing 747 — Mach 0.25 powered approach, standard sea level

The rung-0 dataset, with sources. The machine-readable copy is
`data/b747_approach.eigs`; this file is the human-auditable table. See
`ORACLE.md` for why this airframe was chosen (the source publishes every link
of the derivation chain, so each pipeline stage has an independent printed
answer) and for the tolerances used when checking against the printed values.

**Source:** Caughey, D. A., *Introduction to Aircraft Stability and Control*,
M&AE 5070 course notes, Cornell University, 2011, §5.2–5.3, eqs. 5.48–5.101.
<https://courses.cit.cornell.edu/mae5070/Caughey_2011_04.pdf>
Caughey's data is from Nelson, *Flight Stability and Automatic Control* (2nd
ed.), whose 747 tables trace to Heffley & Jewell, *Aircraft Handling Qualities
Data*, NASA CR-2144, 1972. Units: English engineering (ft, s, slug, lbf).

## Flight condition and mass properties (eq. 5.48, 5.89, §5.3.1)

| Quantity | Value | Units |
|---|---|---|
| u₀ (trim speed V) | 279.1 | ft/s |
| ρ (sea-level density) | 0.002377 | slug/ft³ |
| S (wing area) | 5500.0 | ft² |
| c̄ (mean chord) | 27.3 | ft |
| b (span) | 195.7 | ft |
| W (weight) | 564032.0 | lbf |
| g | 32.174 | ft/s² |
| Θ₀ (trim pitch) | 0 | rad |
| I_y | 32.3×10⁶ | slug·ft² |
| I_x | 14.3×10⁶ | slug·ft² |
| I_z | 45.3×10⁶ | slug·ft² |
| I_xz | −2.23×10⁶ | slug·ft² |

## Nondimensional coefficients — the primary data

Longitudinal (eq. 5.49–5.50): C_L = 1.108, C_D = 0.102, C_Lα = 5.70,
C_Dα = 0.66, C_mα = −1.26, C_Lα̇ = 6.7, C_mα̇ = −3.2, C_Lq = 5.4,
C_mq = −20.8, and the Mach-derivative terms C_LM = C_DM = C_mM = 0 (so
C_Lu = C_Du = C_mu = 0 at this condition).

Lateral/directional (eq. 5.90): C_yβ = −0.96, C_yp = 0, C_yr = 0,
C_lβ = −0.221, C_lp = −0.45, C_lr = 0.101, C_nβ = 0.15, C_np = −0.121,
C_nr = −0.30.

## Printed dimensional derivatives (eq. 5.51, 5.91) — used as CHECK values

These are the source's own conversions, printed rounded; our pipeline derives
them from the coefficients above and must reproduce them within the ORACLE.md
tolerance rule. Longitudinal (s⁻¹ unless noted): Xu=−0.0212, Xw=0.0466,
Zu=−0.2306, Zw=−0.6038, Zẇ=−0.0341 (dimensionless), Zq=−7.674 ft/s,
Mu=0.0, Mw=−0.0019 (ft·s)⁻¹, Mẇ=−0.0002 ft⁻¹, Mq=−0.4381.
Lateral: Yv=−0.0999, Yp=0.0, Yr=0.0, Lv=−0.0055, Lp=−1.0994, Lr=0.2468,
Nv=0.0012, Np=−0.0933, Nr=−0.2314; inertia ratios i_x = I_xz/I_x = −0.1559,
i_z = I_xz/I_z = −0.0492.

## Published downstream values (check targets)

State matrices: eq. 5.52 (longitudinal, state [u, w, q, θ]) and eq. 5.93
(lateral, state [v, p, φ, r]) — all 32 entries are check targets, reproduced
in `tests/modes_check.eigs`.

Characteristic quartics (eq. 5.53, 5.94):
λ⁴ + 1.1066λ³ + 0.7994λ² + 0.0225λ + 0.0139 (longitudinal);
λ⁴ + 1.4385λ³ + 0.8222λ² + 0.7232λ + 0.0319 (lateral).

Roots (eq. 5.54, 5.95): short period −0.5515 ± 0.6880i; phugoid
−0.00178 ± 0.1339i; Dutch roll −0.08066 ± 0.7433i; roll −1.2308; spiral
−0.04641.

Mode quantities (eq. 5.55–5.56, 5.96–5.101): ζ_sp = 0.6255,
ωn_sp = 0.882 s⁻¹, T_sp = 9.13 s; ζ_ph = 0.0133, ωn_ph = 0.134 s⁻¹,
T_ph = 46.9 s; ζ_DR = 0.1079, ωn_DR = 0.7477 s⁻¹, T_DR = 8.45 s,
N½_DR = 1.016 cycles; t½_roll = 0.563 s, t½_spiral = 14.93 s.
