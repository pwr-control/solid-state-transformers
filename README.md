# solid-state-transformers

Simulink/Simscape study of solid-state transformer (SST) architectures built from
*modules*, where a module is a galvanically isolated DC-DC converter followed by a
single-phase inverter: modules are paralleled on the DC side and their inverters are
series-connected on the AC side. The repository holds the two-module SST bench (two CLLC
DC transformers of the library feeding two three-level T-type single-phase inverters in series
on the line), the bench of the isolated stage alone as a CLLC DC transformer (DCX, 800 V / 800 V,
50 kW, 50 kHz, SiC, with a 35 kHz variant at 790 V / 700 V) and first-cut sizing scripts for the
medium-frequency transformers. The single-phase DAB variant of the SST bench was removed on
2026-10-24 (still in the git history).

Earlier variants with two-level and NPC inverters and with a three-phase DAB were removed
from the tree in March 2026 (still in the git history); the three-phase DAB study lives in
[advanced-dcdc-converters](https://github.com/pwr-control/advanced-dcdc-converters).
Simulation results are discussed in the *solid_state_transformers* document published on
the organization page (`pwr-control/docs/solid_state_transformers`).

## Prerequisites

- MATLAB with Simulink, Simscape and Simscape Electrical.
- The companion [library](https://github.com/pwr-control/library) repository on the MATLAB
  path **with subfolders** (every `init_model.m` of this repository does it by itself through
  its `private/library_setup.m`, cloning the library next to this repository when it is missing):
  the CLLC-DCX block `cllc_dcx/cllc_dcx_mod1` (Simscape-language power stage `cllc_ssc`, to be
  built once with `ssc_build cllc_ssc` from `library/foundation/pwr_electronics`), masked power
  stages (three-level T-type inverter with thermal model, three-level PWM modulator with global
  TRGO, DC link, lithium-ion battery, single-phase transformer, `mos_simple_2th`), the
  `dq_vector_pi` control block, and the setup classes and functions used by `init_model.m`
  (`init_environment`, `timing_setup`, `hw_single_phase_inverter_setup`,
  `ctrl_single_phase_inverter_setup`, `hw_cllc_single_phase_setup`, `ctrl_cllc_setup`,
  `device_mosfet_setup`, `lithium_ion_battery_setup`, `cllc_dcx_param_example`, ...).

## How to use a project

1. Run `init_model.m` in the project folder: it builds the `param` structure (one group per
   subsystem: `param.sim`, `.time`, `.glb_time`, `.cllc`, `.spinv`, `.grid`, `.battery`,
   `.thermal`, ...; the numbers of the bench are in `private/*_param.m`, those of the DCX in
   `cllc_dcx_param_example.m` of the library), prints the operating point and opens the model.
   The SST bench runs 1.25 s with the inverters at 4 kHz (double update) and the DCX at 50 kHz,
   2 × 50 kW, two 800 V packs, `wolfspeed_SiC_MOSFET_CAB006M12GM3` with thermal model (its
   `init_model.m` holds the simulation settings only, the rest is built in `private/`); the
   CLLC-DCX benches run 0.25 s with the last 50 ms logged. All of them use the Simscape
   Backward Euler local solver with the fixed step `param.sim.tc` (1 µs in the SST bench,
   50 to 500 ns in the DCX benches: the method damps the resonant tank in proportion to tc,
   see the READMEs).
2. Simulate the `.slx`. In the SST bench, the first time, run `update_sst_cllc_ttype_inv.m`
   before simulating (it fixes the model around the library DCX blocks and saves it).
3. Post-process with `power_loss_calculus.m`, `plotting_results.m` and `spectrum.m`;
   figures go to `figures/` (EPS, ignored by git).

Each converter runs on its own local time base (`time_master`, `time_afe_module_A/B`,
`time_cllc_module_A/B` in the SST model, the local clock of the DCX block): the modulators
generate the control triggers, and the local clocks can be detuned to study the effect of time
sliding between modules.

## Repository layout

| Folder | Content |
|---|---|
| [`theory_analysis_solid_state_transformer`](theory_analysis_solid_state_transformer) | The two-module SST bench (CLLC-DCX + T-type inverters), the CLLC-DCX benches of the isolated stage (800 V / 800 V at 50 kHz, and a 35 kHz variant at 790 V / 700 V) and the transformer sizing scripts |

The folder has its own README with the project descriptions.
