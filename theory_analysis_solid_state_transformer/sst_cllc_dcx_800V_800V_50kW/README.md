# CLLC-DCX 800 V → 800 V, 50 kW

Simulink/Simscape bench of the isolated DC/DC stage of one SST module as a **DC transformer** (DCX):
a symmetrical CLLC resonant converter with fixed ratio 1:1 between the 800 V DC link of the module
(side 1, the DC link of the single-phase T-type inverter) and the isolated 800 V DC link (side 2),
50 kW in both directions, 50 kHz, 1200 V SiC MOSFETs on both bridges. The sizing and the design
choices are in [`cllc_dcx_sizing.md`](cllc_dcx_sizing.md); this file describes the model and how to
run it.

## Sizing in short

| Quantity | Value |
|---|---|
| DC voltages | 800 V / 800 V, n = 1 (11 : 11) |
| Power, DC current | 50 kW, 62.5 A |
| fs, fr, dead time | 50 kHz, 52.6 kHz (fn = 0.95), 300 ns |
| Tank, per side | Lr = 12 µH (4 µH leakage + discrete), Cr = 0.762 µF, Z0 = 4.0 Ω, Q = 0.38 |
| Magnetizing inductance | 400 µH (Im = 10 A peak, ZVS in 126 ns), Ln = 33 |
| Tank currents | 71.5 A rms, 113 A peak on both sides; 410 V peak on Cr |
| Transformer | 3 stacked UU93/152/30 ferrite sets, 11 turns of litz per winding, 0.14 T, about 110 W |
| DC links, chokes | 500 µF / 1 mΩ and 250 µH / 2 mΩ per side (bench values) |
| Devices | `wolfspeed_SiC_MOSFET_CAB006M12GM3` on both bridges, 6.6 mΩ, Coss 0.79 nF |
| Loss budget | about 365 W, η ≈ 99.3 % (the model adds 0.63 kW of numerical damping at tc = 50 ns) |

## Model `sst_cllc_dcx.slx`

Root: `battery_1` (800 V source of side 1, library block `lithium_ion_battery` with the capacitor at
its terminals, `battery_voltage_init_m`), `dcdc_cllc_modA`, `global timing` (local clock
`time_cllc_module_1` and `time_master`), `load` (Controlled Current Source of side 2 with a ramp,
`param.cllc.sink.I2` and `.t_ramp`; a resistor and a DC voltage source are kept commented out for the
mirror bench), `scopes`, `storage_data` (logs every `*_sim` variable at `param.glb_time.tc` in the last
`t_measure` seconds). Solver Configuration: local solver, Backward Euler, step `param.glb_time.tc`,
`param.sim.nonlinear_iterations`.

`dcdc_cllc_modA/dc/dc with galvanic isolation`: DC chokes `LFi_dc1/2`, DC link capacitors `CFi_dc1/2`
(initial voltages `param.cllc.ic.vc_dc1/2`, priority High), the tank with the library
`single_phase_transformer` (leakages `Ld1`, `Ld2` are `Lr1`, `Lr2`; `Cs1`, `Cs2` are `Cr1`, `Cr2`), the
two full bridges of `mos_simple_2th` switches with the `Czvs` capacitor across each (Coss when
`param.sim.use_coss = 1`), and the gate logic: `sr1_gate_logic` in front of bridge 1 and
`sr_gate_logic` in front of bridge 2 select, with `param.cllc.sr1.mode` / `param.cllc.sr.mode`, between
the modulator (mode 0), the synchronous rectifier driven by the sign of the own current (mode 1) and
the diode rectifier (mode 2). `dcdc_cllc_modA/input_current_control` holds the modulator
(`dab_single_phase_pwm_modulator`, 50 % duty on both bridges, phase displacement from the current
loop, which is commented out: the DCX runs open loop with phase 0) and the normalization.

Both bridges read their device from `param`: bridge 1 `param.cllc.mosfet`, bridge 2
`param.cllc.mosfet_sr` (one device per switch, or a bank of `param.cllc.sr.n_par` devices with
`device_mosfet_parallel`).

## How to run

1. `init_model.m`: first puts the companion library on the path (`private/library_setup.m`: the copy
   already on the path, else the folder `library` next to this repository or the one named by the
   environment variable `PWR_CONTROL_LIBRARY`, cloned from GitHub when it does not exist; for this
   session only, `savepath` to keep it), then builds `param` (one group per subsystem, numbers in
   `private/cllc_dcx_param.m`), prints the tank, the ZVS check of the driving bridge and the bench
   mode, opens the model.
2. Simulate: 0.25 s (`param.sim.simlength`), the last 50 ms logged at `tc = 50 ns`
   (`param.time.t_measure`). The run starts near the steady state (initial voltages of the DC links),
   the current source ramps to 62.5 A in 20 ms.
3. `power_loss_calculus.m`: powers, efficiency, R_eq, tank currents against the sizing, numerical
   damping, ZVS of the logged switches, losses per bridge. `plotting_results.m`: figures 1-7 (DC side,
   last three periods, start-up, magnetizing current and ripple, losses per switch, spectra, switching
   edges), EPS files in `figures/`. `spectrum.m`: spectra of the tank current and of the DC link
   ripple. `cllc_analysis.m`: FHA gain and input impedance at 10, 50 and 100 % load, power against
   phase displacement. `transformer_sizing.m`: the transformer of the sizing note.
   `non_virtual_blocks_counting.m`: nonvirtual block count (MATLAB Home licence limit).
4. Save a run with the commented `save(...)` line of `init_model.m` (`sim_results_xx.mat`, `*.mat`
   are ignored by git) and list it in this file.

## Power flow and bench modes (`param.sim.sink`)

- **0, load**: `battery_1` feeds side 1, the current source draws +62.5 A from side 2. Bridge 1 driven
  by the modulator (`sr1.mode = 0`), bridge 2 synchronous rectifier on i2 (`sr.mode = 1`).
- **1, sink with battery and current source**: the current source pushes −62.5 A into side 2 (the
  downstream stage in sink), `battery_1` is charged. Bridge 2 driven by the modulator at 50 % duty
  (`sr.mode = 0`), bridge 1 rectifies on i1 (`sr1.mode = 1`, or 2 for the body diodes). Same model, no
  block to swap.
- **2, sink on the mirror bench**: resistor R1 = 12.8 Ω (`param.cllc.sink.R1`) in place of the
  battery of `battery_1`, DC voltage source U2 = 811 V (`param.cllc.sink.U2`, set so that u1 = 800 V
  on R1 with `R_eq`) in place of the current source of `load`: comment the battery and the current
  source, uncomment the resistor and the voltage source. CFi_dc2 starts at U2.

In both sink modes `init_model.m` sets the two SR modes and the initial voltages. With `sr.mode = 1`
in sink nothing drives the tank.

## Numerical settings

- Backward Euler local solver at tc = 50 ns (400 steps per period, dead time = 6 steps). The method
  adds about 2 (ω² Lr1 tc / 2 + tc / (2 Cr1)) = 0.125 Ω of damping to the tank, 0.63 kW at full load:
  `power_loss_calculus.m` prints it; halve `param.sim.tc` to halve it (twice the run time). The
  trapezoidal method rings on the switching edges, the Partitioning solver chatters on the SR bridge.
- `param.sim.use_coss = 1`: the `Czvs` blocks are the Coss of the devices with a 10 ns time constant,
  to see the dead-time transitions and the ringing of the rectifier nodes. With 0 the library ZVS
  snubber is in practice open and the transitions happen in one step.
- `param.sim.nonlinear_iterations = 5` (the model has thermal-capable switch models).

## Library dependencies

Blocks: `mos_simple_2th` (`foundation/semiconductors`), `single_phase_transformer`,
`dab_single_phase_pwm_modulator`, `lithium_ion_battery` (with the `battery_voltage_init_m`
parameter), `discrete_time_low_pass_filter`. Functions and classes: `init_environment`,
`timing_setup`, `hw_cllc_single_phase_setup`, `ctrl_cllc_setup`, `device_mosfet_setup`,
`device_mosfet_parallel`, `lithium_ion_battery_setup`, `liquid_cooled_plate_2kw_setup`, device dataset
`wolfspeed_SiC_MOSFET_CAB006M12GM3`. The flat names `Tambient` and `DThs_init` are exported to the base
workspace for the thermal sources of the library bridges. `private/library_setup.m` adds the library to
the path (and clones it next to this repository when missing) at the start of `init_model.m`; copy it into
the `private` folder of another project of this repository to reuse it there.

## Files

| File | Content |
|---|---|
| `sst_cllc_dcx.slx` | Simulink/Simscape model |
| `init_model.m` | builds `param`; writes the DCX tank over the library one; `param.sim.sink`, `use_coss`, `tc` |
| `private/cllc_dcx_param.m` | the numbers of this DCX: operating point, tank, transformer, DC links, SR logic, bench |
| `cllc_dcx_sizing.md` | sizing note: principle, tank and Lm, transformer, devices, DC links, loss budget, numerics, checks to do |
| `cllc_analysis.m` | FHA gain, input impedance, power against phase shift |
| `transformer_sizing.m` | first sizing of the 1:1 transformer (core stack, turns, gap, litz, losses, leakage) |
| `power_loss_calculus.m` | checks a run against the sizing (powers, currents, ZVS, losses, numerical damping) |
| `plotting_results.m`, `spectrum.m` | figures of a run (EPS in `figures/`) |
| `non_virtual_blocks_counting.m` | nonvirtual block count of the model |

## Saved runs

None yet. The first runs and the quantities to compare with the sizing are listed in Sec. 9 of
`cllc_dcx_sizing.md`.
