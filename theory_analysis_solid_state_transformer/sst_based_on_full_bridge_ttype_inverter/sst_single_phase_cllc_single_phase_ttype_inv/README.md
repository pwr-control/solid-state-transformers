# SST bench: battery → 2 × CLLC-DCX 800 V / 800 V → 2 × single-phase T-type inverter

Simulink/Simscape bench of a two-module solid-state transformer: two lithium-ion packs in
parallel on an 800 V bus, one isolated CLLC DC transformer per module (the library block
`cllc_dcx/cllc_dcx_mod1`, 800 V → 800 V, 50 kW, 50 kHz, open loop), one single-phase
three-level T-type full bridge per module on the 800 V isolated DC link, the two inverters in
series on a single-phase line (2 × 398 V rms = 797 V rms, 125 A). Module A runs the current
loop (PLL on the line voltage, virtual dq frame, dq vector PI), module B applies the same
voltage command. 2026-10-24: the old CLLC stage was replaced by the library DCX blocks; this
folder was re-done around them (`init_model.m`, `update_sst_cllc_ttype_inv.m`, the scripts).
2026-10-25: the two T-type modules get their compact version too, the library block
`afe_single_phase_ttype/afe_single_phase_ttype_mod1` (power stage in Simscape language, control
in a MATLAB Function, module B slave of module A) in the wrappers
`single_phase_inverter_modA_cmp` / `modB_cmp`. The folder keeps two models of the same bench:
`sst_cllc_ttype_inv.slx` with the compact modules and `sst_cllc_ttype_inv_discrete.slx` with the
modules built from the discrete blocks of the library (switch losses and thermal model); the
init, the parameters and the scripts are shared, `param.sim.model` chooses the model.

## Numbers in short (`private/sst_cllc_ttype_param.m`, `cllc_dcx_param_example.m` of the library)

| Quantity | Value |
|---|---|
| Modules | 2, DC sides in parallel, AC sides in series, 50 kW each |
| Battery bus | 2 packs × 800 V, 50 kW, 62.5 Ah (1C), SOC 0.85; R0, R1 halved and C1/100 for the run |
| DCX (per module) | 800 V → 800 V (11 : 11), 62.5 A, fs = 50 kHz (fn = 0.95), Lr 12 µH, Cr 0.762 µF, Lm 400 µH, dead time 300 ns, mode 0 (bridge 1 PWM 50 %, bridge 2 synchronous rectifier) |
| Inverter (per module) | udc 800 V, ubez = 0.9 udc = 720 V, is_nom 125.5 A, fpwm 4 kHz double update, dead time 300 ns, CFi 3 mF (CFi1 = CFi2 = 6 mF), LFu 500 µH, CFu 50 µF + 50 mΩ, `wolfspeed_SiC_MOSFET_CAB006M12GM3` with thermal model |
| Line | 690/√3 = 398.4 V rms per module (563.4 V peak, `param.grid.u_pk_module`), 796.7 V rms in total, 50 Hz, 0.5 mH + 10 mΩ per inductor (5 %) |
| Control | old modules: dq PI kp 0.5, ki 45 at ts_inv = 125 µs; compact modules: kp 0.1, ki 20 (`ctrl_in.kp_i`, `ki_i`: 0.5 / 45 are unstable with the first harmonic tracker in the feedback and the 1.4 kHz filter resonance, see `afe_single_phase_ttype_param_example.m`), gates on from 0.1 s; reference 1 pu from 0.35 s with 2 pu/s; CTRPIFF_CLIP_RELEASE 0.001 |
| Run | 1.25 s, tc = `param.sim.tc` (100 ns since 2026-10-25, 1 µs for the structural checks; Backward Euler, see Numerical settings), last 0.2 s logged at tc |

Values marked TBC in the parameter file (DC link bank, filter, line impedance, devices) are
placeholders of the first run.

## Files

| File | Content |
|---|---|
| `sst_cllc_ttype_inv.slx` | Simulink/Simscape model with the compact T-type modules (library block `afe_single_phase_ttype`, one nonvirtual block per converter) |
| `sst_cllc_ttype_inv_discrete.slx` | the same bench with the T-type modules built from the discrete blocks of the library (`dclink`, `output_filter`, T-type bridge with switch losses and thermal model, `single phase inverter control`): the model of 2026-10-24, before the compact modules |
| `init_model.m` | simulation settings only (`param.sim`: `model`, `simlength`, `tc`, `nonlinear_iterations`, `export_legacy_names`), then `param = sst_cllc_ttype_setup(param)`, opens the chosen model, exports the legacy names |
| `private/sst_cllc_ttype_param.m` | the numbers of the bench: modules, DCX operating point (`mode`, `interleave`), line, inverter hardware and control (the compact modules included: `kp_i`, `ki_i`, `t_enable`, `i_noise_std`), timing, batteries, ADC, heatsink, device names |
| `private/sst_cllc_ttype_setup.m` | builds `param` from the numbers: DCX mask structs `param.cllc.p_mod1/2`, `param.glb_time`, inverter `hw`/`ctrl`/`sogi`/`mosfet`, mask structs of the compact modules `param.spinv.p_modA/B` (from `afe_single_phase_ttype_param_example(tc)`), battery packs, heatsink |
| `private/sst_cllc_ttype_legacy.m` | the flat names of the old init in the base workspace (table legacy name → `param.*`); delete it after the migration of the model |
| `private/library_setup.m` | library on the path (clone when missing) |
| `legacy/update_sst_cllc_ttype_inv.m` | archived: the script that updated the models after the changes to the library blocks (DCX, AFE), already applied to both; `'migrate'` (legacy names → `param.*`) is the only mode left to use |
| `power_loss_calculus.m` | powers, losses, efficiency, Backward Euler estimate |
| `plotting_results.m`, `spectrum.m` | figures of a run (EPS in `figures/`) |
| `non_virtual_blocks_counting.m` | nonvirtual block count of the model |

`param`, one group per subsystem: `param.sim` (simulation, `.model`), `.time` (inputs of the timing object),
`.glb_time` (`timing_setup`), `.cllc` (DCX stage, `.p_mod1/2` mask structs, `.idx`), `.sst`
(modules), `.grid` (line), `.spinv` (T-type inverter of one module: `.hw_in`/`.hw`,
`.ctrl_in`/`.ctrl`, `.sogi`, `.mosfet`, `.ideal_switch`, `.i_ref`, `.t_ref`, `.i_ref_slew`; compact
modules: `.p_modA`, `.p_modB` mask structs, `.idx` indices of their `ctrl_log`, `.m_to_legacy_modA/B`
gains of the old log tags), `.ctrl` (`.clip_release`), `.battery` (`.pack_1/2`), `.meas` (ADC),
`.thermal` (`.heatsink`), `.dev` (dataset names). The scripts read `param.*` only.

`param.spinv.p_modA` / `p_modB` start from `afe_single_phase_ttype_param_example(param.sim.tc)` of
the library and take the numbers of this folder: `hw` (Vth and Rds_on of `param.spinv.mosfet` as a
conduction drop, CFi1/CFi2 banks, LFu/2 per line, CFu, bases ubez 720 V / ibez 177.5 A / 800 V,
DC link started at 800 V), `pwm` (fpwm, double update, dead time of `param.time`, `tc` of the run,
`t_enable`), `ctrl` (ts_inv, omega_nom, u_pk_module, 11-bit quantization, current noise of rms
`i_noise_std`, observer gains placed again on ts_inv, kp_i / ki_i, references). Module A
is the master (its own PLL and current loop, `sync_out` = [theta_hat; m_d; m_q] on the Goto
`synch_AFE_mtos`), module B the slave (`p.ctrl.slave = 1`, it applies the angle and the modulation
vector of A, as `udq_ctrl_out_modA` did for the old modules).

## Models `sst_cllc_ttype_inv.slx` and `sst_cllc_ttype_inv_discrete.slx`

Root, common to both: `battery_1`, `battery_2` (library `lithium_ion_battery`; one Solver
Configuration in the model, in `line_source`: the DCX blocks connect the two sides in one
physical network), `cllc_dcx_mod1`, `cllc_dcx_mod2` (wrappers around `cllc_dcx/cllc_dcx_mod1`,
Gotos `cllc_dcx_m_mod1/2` [15×1] and `cllc_dcx_ctrl_log_mod1/2` [24×1]), `global timing`
(`time_master`, `time_afe_module_A/B`, `time_cllc_module_A/B`), `line_source` (two Controlled
Voltage Sources of `u_pk_module · n_modules / 2` each, two line inductors, voltage and current
sensors), `scopes`, `storage_data_sst` (every `*_sim` log at `glb_time.tc`, last `t_measure` s).
The T-type modules, DC link on side 2 of `cllc_dcx_mod1/2` and AC sides in series between `u1`
and `u2` of `line_source`:

- `sst_cllc_ttype_inv.slx`: `single_phase_inverter_modA_cmp/modB_cmp`, wrappers around
  `afe_single_phase_ttype/afe_single_phase_ttype_mod1` (`udc(+)/udc(-)` left, `uac(+)/uac(-)`
  right; inside, From `time_master` on `t_master`, the sync link `synch_AFE_mtos` from A to B,
  Gotos `afe_cmp_m_modX` [13×1] and `afe_cmp_ctrl_log_modX` [32×1], the Gain `m_to_legacy` that
  rebuilds the old log tags in physical units). Mask `p` = `param.spinv.p_modA` / `p_modB`. No
  switching losses nor thermal model: the conduction drop (Vth, Rds_on) is in the block.
- `sst_cllc_ttype_inv_discrete.slx`: `single_phase_inverter_modA/B` (`dclink` block of the
  library, `output_filter`, `single phase afe` with the T-type bridge
  `mosfet_based_three_level_inverter_ttype` and its thermal model, `single phase inverter
  control` with the dq vector PI at kp 0.5 / ki 45; module B applies `udq_ctrl_out_modA`).
  Logs `mosfet_ploss_invQ1..4_sim` and the device scopes exist here only.

The two models share the init, the parameters and the scripts: `param.sim.model` in
`init_model.m` chooses the one to open and simulate; the log names are the same, so
`power_loss_calculus.m`, `plotting_results.m` and `spectrum.m` work on either run (they skip the
logs a model does not have).

### `legacy/update_sst_cllc_ttype_inv.m` (archived: what it did to the models)

The model of 2026-10-24 had the new DCX blocks and the one of 2026-10-25 the wrappers of the
compact T-type modules, but the rest of the diagram was not updated. The script (after
`init_model`; modes `'fix'` default, `'compact'`, `'migrate'`; second argument the model name)
did the following, idempotently, and saved the model. Both models are already updated:
`sst_cllc_ttype_inv.slx` is the result of `'compact'` (2026-10-25),
`sst_cllc_ttype_inv_discrete.slx` the model after `'fix'` (2026-10-24, before the wrappers).
Only `'migrate'` is left to use, from the project folder: `addpath('legacy')`, then
`update_sst_cllc_ttype_inv('migrate', param.sim.model)`.

1. mask `p` of the two DCX blocks → `param.cllc.p_mod1` / `param.cllc.p_mod2` (it was
   `cllc_dcx_param_example()`, i.e. a 50 ns block in a fixed-step model with a longer step: it
   does not compile, and the two carriers could not be interleaved);
2. `battery_2` like `battery_1`: `ts_battery = glb_time.ts_dab` (was `ts_cllc`), initial voltage
   `param.battery.nominal_battery_voltage_2` (was `_1`), `C1` of both read the pack value (the
   /100 is in `private/sst_cllc_ttype_setup.m`);
3. the scopes of the removed stage (`scopes_dcdc_modA/B`, "CLLCs input/output
   current/voltage", "dcdc input/output voltages") deleted;
4. compact modules. As committed on 2026-10-25 both wrappers had the default mask
   `afe_single_phase_ttype_param_example()` (tc = 500 ns while the run is at 1 µs, neither block
   slave, both named `..._modB`), `modA_cmp` was connected to nothing (a physical network without
   Solver Configuration does not compile), `modB_cmp` was in parallel with the old module B, the
   `sync` input of the master was open, `m` and `ctrl_log` were not logged, the old modules and
   `storage_data_sst` were commented out. In both modes: mask `p` → `param.spinv.p_modA` /
   `p_modB`, blocks renamed `afe_single_phase_ttype_modA/B`, Ground on the `sync` of A (a master
   reads no sync), From/Goto `synch_AFE_mtos` and Terminator where missing, Gotos
   `afe_cmp_m_modA/B` and `afe_cmp_ctrl_log_modA/B`, root wiring of the active pair (DC links on
   side 2 of the DCX blocks, AC sides in series with `line_source`) with the other pair
   isolated, `storage_data_sst` un-commented. `'fix'`: old modules active, wrappers commented
   out. `'compact'`: wrappers active, old modules deleted with their lines,
   `scopes/scopes_inv_modA` (device quantities: the block has no switching loss nor thermal
   model) deleted, Gain `m_to_legacy` (`param.spinv.m_to_legacy_modA/B`, [5×13]) + Demux + five
   Gotos in each wrapper for `afe_current_output_modX` [A], `afe_voltage_output_modX` [V],
   `afe_is_modX` [A], `afe_us_modX` [V], `dclink_voltage_modX` [V] from `m`, so that
   `storage_data_sst`, the scopes and the scripts keep working. Once the old modules are gone,
   every mode keeps the compact ones active;
5. every From block whose tag has no Goto left (the `cllc_*`, `*_cllc_transformer_*`,
   `inverter_*_cllc_mosfet_zvs_*`, `CFi_dc1/2_current_modA` signals of the old stage, the
   `local_time_corr_*` of `global timing`; after `'compact'` also `mosfet_ploss_invQ1..4` of
   `storage_data_sst` and `afe_phase_grid_hat_modA/B` of the phase scope of `line_source`)
   deleted with its line; a To Workspace or Terminator it fed goes too, any other destination
   gets a Ground;
6. `storage_data_sst`: `afe_us_modA` → `afe_us_modA_sim`; new logs (only for tags that have a
   Goto) `cllc_dcx_m_mod1/2_sim`, `cllc_dcx_ctrl_log_mod1/2_sim`, `afe_voltage_output_modB_sim`,
   `afe_current_output_modB_sim`, `afe_us_modB_sim`, `voltage_battery_2_sim`,
   `current_battery_2_sim`, `mosfet_ploss_invQ1..4_sim` (leg u of the old module A); with the
   compact modules `afe_cmp_m_modA/B_sim` ([Nc×13], pu: i_s, i_a, u_ac, u_s, udc, udc_p, udc_n,
   i_dc, i_np, i_c1, i_c2, i_cf, i_s2) and `afe_cmp_ctrl_log_modA/B_sim` ([Nc×32], indices in
   `param.spinv.idx`, e.g. `afe_cmp_ctrl_log_modA_sim(:, param.spinv.idx.i_d)`); SaveFormat
   Array on every To Workspace of the subsystem;
7. current reference of the old module A from `param.spinv.t_ref`, `.i_ref`, `.i_ref_slew` (Step
   and Rate Limiter), the constant of the old module B `param.spinv.i_ref` (the compact modules
   read `p.ctrl.i_ref`, `t_ref`, `i_ref_slew` of their mask);
8. `update_sst_cllc_ttype_inv('migrate')`: every legacy flat name of the model rewritten to
   `param.*` (table in the function and in `private/sst_cllc_ttype_legacy.m`), solver settings
   included; then set `param.sim.export_legacy_names = 0` in `init_model.m` and delete
   `private/sst_cllc_ttype_legacy.m`.

In the compact model the switch losses and temperatures of the T-type bridges are not
available (`mosfet_ploss_invQ1..4_sim` are logged by the discrete model only;
`power_loss_calculus.m` and `plotting_results.m` skip them), the conduction drop of the devices
is in the block (Vth, Rds_on).

Until the migration is run, `private/sst_cllc_ttype_legacy.m` (called by `init_model.m` while
`param.sim.export_legacy_names = 1`) puts in the base workspace the flat names the model reads
(`hwdata`, `glb_time`, `mosfet`, `ideal_switch`, `heatsink`, `lithium_ion_battery_1/2`,
`single_phase_inverter_ctrl`, `afe_ctrl`, `sogi`, `grid_emu`, `omega_set`,
`sst_num_of_modules`, `adc12/11_quantization`, `CTRPIFF_CLIP_RELEASE`, `nonlinear_iterations`,
`simlength`, `tc`), taken from `param`.

## How to run

1. `init_model.m`: puts the companion library on the path (`private/library_setup.m`: the copy
   already on the path, else the folder `library` next to this repository or the one named by
   the environment variable `PWR_CONTROL_LIBRARY`, cloned from GitHub when it does not exist; all
   its subfolders are added at every run, so a folder added to the library after `savepath` is
   seen too), sets `param.sim`, builds the rest of `param` (`private/sst_cllc_ttype_setup.m` on the
   numbers of `private/sst_cllc_ttype_param.m`, `cllc_dcx_param_example(tc)` and
   `afe_single_phase_ttype_param_example(tc)`), opens the model chosen by `param.sim.model`
   (`'sst_cllc_ttype_inv'`, compact modules, or `'sst_cllc_ttype_inv_discrete'`), exports the
   legacy names.
2. Simulate: 1.25 s (`param.sim.simlength`), the last 0.2 s logged at `tc`
   (`param.time.t_measure`). The DC links start at their nominal voltage, the compact modules
   switch from 0.1 s (`t_enable`, PLL locked), the current reference steps at 0.35 s and ramps
   to 1 pu in 0.5 s.
3. `power_loss_calculus.m`: battery, DCX (per module, with the Backward Euler damping),
   inverter and line powers, losses and efficiency over the last 5 grid periods.
   `plotting_results.m`: figures 1-5 (DC side, AC side, last grid period, last DCX periods,
   switch losses), EPS files in `figures/`. `spectrum.m`: spectra of the line current, of the
   module A voltage and of the battery current, THD of the line current.
   `non_virtual_blocks_counting.m`: nonvirtual block count (MATLAB Home licence limit).
4. Save a run with `save('sim_results_01.mat', '-v7.3', '-regexp', '_sim$', '^param$')`
   (`*.mat` are ignored by git) and list it in this file.

## Numerical settings

- Backward Euler local solver at the fixed step `param.sim.tc` (1 µs: 125 steps per PWM
  period of the inverters, 20 per switching period of the DCX, dead times shorter than one
  step). The method adds about 2 (ω² Lr1 tc / 2 + tc / (2 Cr1)) of damping to each resonant
  tank, proportional to tc: 2.5 Ω at 1 µs, 1.25 Ω at 500 ns (about 6 kW at full load and 95 V
  less on side 2 of each DCX, the 790 V → 700 V seen on the DCX bench on 2026-10-24), 0.125 Ω
  and 0.63 kW at 50 ns. 0.5 to 1 µs for the structural checks and the grid-side loops, 50 to
  100 ns for the DCX voltages and losses (run time ~ 1/tc). `param.sim.tc` must divide
  ts_inv = 125 µs (`sst_cllc_ttype_setup.m` stops otherwise). `power_loss_calculus.m` prints
  the estimate next to the measured DCX losses.
- `param.sim.nonlinear_iterations = 5` (thermal switch models of the T-type bridges).
- `param.cllc.interleave = 1` (parameter file) shifts the carrier of module 2 by a quarter
  period: the 2 fs ripples of the two DCX cancel on the battery bus.

## Library dependencies

Blocks: `cllc_dcx/cllc_dcx_mod1` (with `cllc_ssc_lib`),
`afe_single_phase_ttype/afe_single_phase_ttype_mod1` (with `afe_ttype_ssc_lib`),
`lithium_ion_battery`, and for `sst_cllc_ttype_inv_discrete.slx` `dclink_for_three_levels/dclink`,
`full_bridge_three_level_ttype_mosfet_based_model`, `single_phase_three_levels_PWM_modulator`,
`dq_vector_pi`, `discrete_time_low_pass_filter`, `cstblocks_lti`. Functions and classes:
`init_environment`, `timing_setup`, `hw_single_phase_inverter_setup`,
`ctrl_single_phase_inverter_setup`, `sogi_filter`, `device_mosfet_setup`,
`device_ideal_switch_setting`, `lithium_ion_battery_setup`, `liquid_cooled_plate_2kw_setup`,
`cllc_dcx_param_example`, `cllc_dcx_log_index`, `afe_single_phase_ttype_param_example`,
`afe_single_phase_ttype_log_index`, device dataset `wolfspeed_SiC_MOSFET_CAB006M12GM3`. The
T-type bridge of the discrete model reads the heatsink data from its mask (`heatsink.*`): no flat
thermal name is needed in the base workspace.

## Saved runs

None yet.
