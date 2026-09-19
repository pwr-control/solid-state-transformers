# solid-state-transformers

Simulink/Simscape study of solid-state transformer (SST) architectures built from
*modules*, where a module is a galvanically isolated DC-DC converter followed by a
single-phase inverter: modules are paralleled on the DC side and their inverters are
series-connected on the AC side. The repository compares the isolated DC-DC stage
(single-phase DAB vs. resonant CLLC) feeding a three-level T-type single-phase inverter,
and includes first-cut sizing scripts for the medium-frequency transformers.

Earlier variants with two-level and NPC inverters and with a three-phase DAB were removed
from the tree in March 2026 (still in the git history); the three-phase DAB study lives in
[advanced-dcdc-converters](https://github.com/pwr-control/advanced-dcdc-converters).
Simulation results are discussed in the *solid_state_transformers* document published on
the organization page (`pwr-control/docs/solid_state_transformers`).

## Prerequisites

- MATLAB with Simulink, Simscape and Simscape Electrical.
- The companion [library](https://github.com/pwr-control/library) repository on the MATLAB
  path **with subfolders**: masked power stages (full bridges with ideal switch / MOSFET
  thermal / MOSFET ZVS models, three-level T-type inverter, DAB and three-level PWM
  modulators with global TRGO, DC link, lithium-ion battery, single-phase transformer),
  C-Caller control code, and the setup functions used by `init_model.m`
  (`init_environment`, `timing_setup`, `*_hwdata`, `ctrl_dab_setup`, `ctrl_cllc_setup`,
  `device_mosfet_setup`, ...).

## How to use a project

1. Run `init_model.m` in the project folder: global timing (`fpwm = 4 kHz` for the
   inverters with double update, `12 kHz` for DAB and CLLC), 690 V application voltage,
   250 kW per DC-DC stage, `sst_num_of_modules = 2`, hardware data, controllers, device set
   (SiC MOSFET `danfoss_SKM1700MB20R4S2I4` with thermal model enabled by default), battery
   models; the model is opened at the end.
2. Simulate the `.slx` (`simlength = 1.25 s`).
3. Post-process with `plotting_results.m`, `power_loss_calculus.m` and `spectrum.m`;
   figures go to `figures/` (EPS, ignored by git).

Each converter runs on its own local time base (`time_master`, `time_afe_A/B`,
`time_cllc_A/B` in the model): modulators generate the control triggers, and the local
clocks can be detuned to study the effect of time sliding between modules.

## Repository layout

| Folder | Content |
|---|---|
| [`theory_analysis_solid_state_transformer`](theory_analysis_solid_state_transformer) | The two SST benches (DAB + T-type inverter, CLLC + T-type inverter) and the transformer sizing scripts |

The folder has its own README with the project descriptions.
