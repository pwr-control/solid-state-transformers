# Theory analysis — solid-state transformer

## `sst_based_on_full_bridge_ttype_inverter`

Two-module SST: two isolated DC-DC converters paralleled on the battery/DC side, each
feeding a three-level T-type single-phase full bridge; the two inverters are series-connected
on the AC side (blocks `dab_modA/modB`, `single_phase_inverter_modA/modB`, `battery_1/2`).
Grid-side control: FHT-based single-phase PLL, virtual dq frame, dq vector PI current
control, output voltage controller and DC-link control; DC-DC control from `ctrl_dab_setup` /
`ctrl_cllc_setup`.

### `sst_single_phase_dab_single_phase_ttype_inv`
- `init_model.m` — `init_environment('sst_dab_ttype_inv')`, Simscape step `ts/100`.
- `sst_dab_ttype_inv.slx` — single-phase DAB (constant 12 kHz, power flow by phase shift
  between the bridges, ZVS-capable MOSFET bridge model) + T-type inverter.
- `plotting_results.m` — DAB input/output and transformer quantities, DC grid (battery) and
  AC grid quantities, inverter output and Q1/Q2 losses and waveforms, DAB primary and
  secondary device losses and waveforms; EPS output.
- `power_loss_calculus.m` — mean losses of the DAB bridges and of the inverter over the last
  0.5 s, AC/DC powers, efficiency from both sides.
- `spectrum.m` — FFT of the AC-side current.

### `sst_single_phase_cllc_single_phase_ttype_inv`
- `init_model.m` — `init_environment('sst_cllc_ttype_inv')`, Simscape step `ts/200`; the
  CLLC DC capacitors are reduced to `Cdc/5` with respect to the library default.
- `sst_cllc_ttype_inv.slx` — resonant CLLC (constant 12 kHz, tank tuned at
  `1.2 × fPWM_CLLC`, power flow by phase shift between primary and secondary bridges) +
  T-type inverter.
- Same `plotting_results.m`, `power_loss_calculus.m`, `spectrum.m` set as the DAB bench.

## `magnetics_sizing`

First-cut design of the medium-frequency transformers with nanocrystalline cut cores
(Faraday's-law core area with fixed primary turns, copper band winding, Litz-wire copper
loss, core loss from a specific-loss scaling, efficiency, leakage inductance and
short-circuit voltage estimate):

- `single_phaseDAB_TRsizing.m` — 800 V / 375 A, 12 kHz, 1:1, `Bmax = 0.5 T`, AMMET AM-NC-412
  cores.
- `three_phaseDAB_TRsizing.m` — 400 V / 275 A, 4 kHz, 1:1, `Bmax = 0.8 T`, AMMET AM-NC-320C
  cores (transformer of the three-phase DAB variant, kept here for reference).
