# Theory analysis — solid-state transformer

## `sst_based_on_full_bridge_ttype_inverter`

Two-module SST: two isolated DC-DC converters paralleled on the battery side, each feeding a
three-level T-type single-phase full bridge; the two inverters are series-connected on the AC
side. Grid-side control: FHT-based single-phase PLL, virtual dq frame, dq vector PI current
control on module A, module B applying the same voltage command.

### `sst_single_phase_cllc_single_phase_ttype_inv`

Since 2026-10-24 the isolated stage is the library block `cllc_dcx/cllc_dcx_mod1` (CLLC-DCX
800 V → 800 V, 50 kW, 50 kHz, open loop, one per module), fed by two 800 V packs in parallel;
2 × 50 kW on a 797 V rms single-phase line (398 V per module), T-type inverters at 4 kHz with
double update on 800 V DC links.

- `init_model.m` — simulation settings only (`param.sim`: 1.25 s run, Backward Euler local
  solver at `param.sim.tc`, 1 µs, the last 0.2 s logged); the rest of `param` (one group per
  subsystem) is built by `private/sst_cllc_ttype_setup.m` from the numbers of
  `private/sst_cllc_ttype_param.m` and from `cllc_dcx_param_example(tc)` of the library;
  `private/library_setup.m` adds the library to the path (and clones it if it is missing);
  `private/sst_cllc_ttype_legacy.m` exports the flat names of the old init for the model until
  it is migrated.
- `update_sst_cllc_ttype_inv.m` — fixes the model around the new DCX blocks (mask `p`, battery 2,
  stale scopes and logs of the removed stage, logging of the DCX vectors and of module B, current
  reference) and, with `'migrate'`, rewrites every legacy name of the model to `param.*`.
- `sst_cllc_ttype_inv.slx` — the model: batteries, two DCX wrappers, global timing, line source,
  two inverter modules (DC link, T-type bridge with thermal model, output filter, control),
  scopes, storage.
- `power_loss_calculus.m` — battery, DCX (per module, with the Backward Euler damping estimate),
  inverter and line powers, losses, efficiency. `plotting_results.m` — DC side, AC side, last grid
  period, last DCX periods, switch losses (EPS in `figures/`). `spectrum.m` — line current,
  module voltage and battery current spectra, THD. `README.md` — model, fixes, how to run.

The former DAB bench of this group (`sst_single_phase_dab_single_phase_ttype_inv`) was removed
on 2026-10-24 (still in the git history).

## `sst_cllc_dcx_800V_800V_50kW`

Bench of the isolated DC/DC stage of one SST module alone, as a DC transformer (DCX): symmetrical
CLLC resonant converter, 800 V / 800 V (n = 1), 50 kW in both directions, fs = 50 kHz just below
the series resonance (fn = 0.95), both bridges at 50 % duty in phase, the rectifying bridge as
synchronous rectifier driven by the sign of its own current, ZVS of the driving bridge from the
magnetizing current, 1200 V SiC MOSFETs (`mos_simple_2th` with the Coss of the device) on both
sides. The DCX runs open loop; the bench has a battery on side 1 and a current source on side 2,
with load and sink modes (`param.sim.sink`).

- `init_model.m` — `init_environment('sst_cllc_dcx')`, `param` structure by subsystem, Backward
  Euler local solver at the fixed step `param.sim.tc`; the numbers are in `private/cllc_dcx_param.m`;
  `private/library_setup.m` adds the library to the path (and clones it if it is missing).
- `sst_cllc_dcx.slx` — the model (DC chokes and links, tank with the library transformer, two
  full bridges with the SR gate logic, modulator, logging).
- `cllc_dcx_sizing.md` — sizing note (operating point, principle, tank and Lm, transformer,
  devices, DC links, loss budget, numerical settings, checks to do); `README.md` — model, how to
  run, bench modes, dependencies.
- `cllc_analysis.m` (FHA), `transformer_sizing.m`, `power_loss_calculus.m`, `plotting_results.m`,
  `spectrum.m`, `non_virtual_blocks_counting.m`.

## `sst_cllc_dcx_790V_700V_50kW`

35 kHz variant of the bench above (2026-10-24): 790 V in / 700 V out (n = 9/8), 50 kW, fs = 35 kHz just
below the series resonance (fn = 0.95, fr = 36.8 kHz), Lm = 560 µH, Lr1 = 16 µH, Cr1 = 1.17 µF (Q = 0.37),
transformer on five stacked UU93/152/30 sets with one litz layer per winding. Same diagram
(`sst_cllc_dcx_35kHz.slx`) and script set as `sst_cllc_dcx_800V_800V_50kW`, with its own
`private/cllc_dcx_param.m`, `transformer_sizing.m` (alternatives with four and three sets in Sec. 6),
sizing note and README.

## `magnetics_sizing`

First-cut design of the medium-frequency transformers with nanocrystalline cut cores
(Faraday's-law core area with fixed primary turns, copper band winding, Litz-wire copper
loss, core loss from a specific-loss scaling, efficiency, leakage inductance and
short-circuit voltage estimate):

- `single_phaseDAB_TRsizing.m` — 800 V / 375 A, 12 kHz, 1:1, `Bmax = 0.5 T`, AMMET AM-NC-412
  cores.
- `three_phaseDAB_TRsizing.m` — 400 V / 275 A, 4 kHz, 1:1, `Bmax = 0.8 T`, AMMET AM-NC-320C
  cores (transformer of the three-phase DAB variant, kept here for reference).
