%[text] # sst\_cllc\_ttype\_inv: model initialization (param structure by subsystem)
% Rev. 02, 2026-10-24: two-module SST, battery -> CLLC-DCX 800 V/800 V (library block cllc_dcx/cllc_dcx_mod1) ->
% single-phase three-level T-type inverter, 2 x 50 kW, the two inverters in series on a single-phase line.
% Everything the model needs is in the struct "param", one group per subsystem (the numbers of the bench are in
% ./private/sst_cllc_ttype_param.m, those of the DCX stage in cllc_dcx_param_example.m of the library):
%   param.sim       simulation settings (stop time, Simscape local solver step, iterations, legacy names)
%   param.time      timing settings shared by all stages, and the PWM data of the stages not in this model
%   param.cllc      DCX stage: .p_mod1, .p_mod2 (mask parameter p of the two cllc_dcx_mod1 blocks), udc1_nom,
%                   udc2_nom, pwr_nom, interleave, mode, .idx (indices of the ctrl_log vector)
%   param.sst       modules;                            param.grid  single-phase line (line_source)
%   param.spinv     T-type inverter of one module: .hw_in / .hw (hw_single_phase_inverter_setup object),
%                   .ctrl_in / .ctrl (ctrl_single_phase_inverter_setup, the PLL reads its .di_obs), .sogi,
%                   .mosfet, .ideal_switch, .i_ref, .t_ref, .i_ref_slew
%   param.glb_time  timing_setup object (built from param.time and the DCX PWM)
%   param.battery   battery inputs;                    param.battery.pack_1, .pack_2  lithium_ion_battery_setup structs
%   param.meas      ADC quantization;                  param.ctrl  clip release of the PI blocks
%   param.thermal   heatsink inputs;                   param.thermal.heatsink  liquid_cooled_plate_2kw_setup object
%   param.dev       names of the semiconductor datasets
%
% Model and names. sst_cllc_ttype_inv.slx of 2026-10-24 (the old CLLC stage replaced by two library DCX blocks)
% still reads the flat names of the old init: hwdata, glb_time, mosfet, ideal_switch, heatsink,
% lithium_ion_battery_1/2, single_phase_inverter_ctrl, afe_ctrl, sogi, grid_emu, omega_set, sst_num_of_modules,
% adc12/adc11_quantization, CTRPIFF_CLIP_RELEASE, nonlinear_iterations, simlength, tc. The last section of this
% script exports them from param while param.sim.export_legacy_names = 1, so the model runs as it is.
% update_sst_cllc_ttype_inv.m (same folder) fixes the model: mask p of the two DCX blocks (param.cllc.p_mod1/2, the
% model has cllc_dcx_param_example() there, tc = 50 ns against the solver step), battery_2, the logging of the
% DCX vectors, the blocks left dangling by the removed stage; with the argument 'migrate' it also rewrites every
% legacy name to param.* (then set export_legacy_names = 0).
%
% Library dependence: classes and functions (init_environment, timing_setup, hw_single_phase_inverter_setup,
% ctrl_single_phase_inverter_setup, sogi_filter, device_mosfet_setup, device_ideal_switch_setting,
% lithium_ion_battery_setup, liquid_cooled_plate_2kw_setup, cllc_dcx_param_example, cllc_dcx_log_index) and the
% blocks of the model (cllc_dcx_mod1, lithium_ion_battery, dclink, mosfet_based_three_level_inverter_ttype,
% single_phase_three_levels_PWM_generator_with_global_TRGO, dq_vector_pi, discrete-time-low-pass-filter). The
% numbers of this bench stay in this folder. A function that must be frozen or changed for this model only goes
% in ./private with the same name (MATLAB resolves private functions before the path, for the files of this folder
% only; the list of ./private is printed at every run). The first command, library_setup (./private/library_setup.m),
% adds the library to the path with its subfolders: the copy already on the path, else the folder "library" next to
% this repository (or the one named by the environment variable PWR_CONTROL_LIBRARY), cloned from
% https://github.com/pwr-control/library when neither exists.

clear;
library_setup;              % pwr-control/library on the path, cloned next to this repository when missing (./private/library_setup.m)
[model, options] = init_environment('sst_cllc_ttype_inv');
s = tf('s');
param = struct();

% functions overridden for this model: ./private takes precedence over the library
overrides = dir(fullfile(fileparts(mfilename('fullpath')), 'private', '*.m'));
if ~isempty(overrides)
    fprintf('%s init: local functions in private/ (precedence over the library): %s\n', model, strjoin({overrides.name}, ', '));
end
clear overrides

% save('sim_results_01.mat', '-v7.3', '-regexp', '_sim$', '^param$');
%[text] ## Simulation
param.sim.simlength = 1.25;                 % [s] model StopTime: current reference step at t_ref = 0.35 s, 1 pu reached
%     at 0.85 s (slew 2 pu/s), the last t_measure = 0.2 s logged in steady state
param.sim.tc = 100e-9;                      % [s] model FixedStep and MaxStep, Simscape local solver step, logging base
%     (glb_time.tc, and sample time of the two DCX blocks through p.pwm.tc). 500 ns = 500 steps per PWM period of
%     the inverters (4 kHz) and 40 per switching period of the DCX (50 kHz, dead time 300 ns below one step).
%     Backward Euler adds a numerical damping of about 2 (w^2 Lr1 tc/2 + tc/(2 Cr1)) to each resonant tank,
%     proportional to tc: 1.25 Ohm at 500 ns, about 6 kW at full load and 95 V less on side 2 of each DCX (the
%     790 V -> 700 V seen on 2026-10-24 on the DCX bench); 0.125 Ohm and 0.63 kW at 50 ns. 500 ns for the
%     structural checks and the grid-side loops, 50 to 100 ns for the DCX voltages and losses (run time ~ 1/tc).
%     The old value of this bench, ts_afe/200 = 625 ns, gives 32 steps per DCX period and 1.56 Ohm.
param.sim.nonlinear_iterations = 5;         % Simscape solver (Solver Configuration block of battery_1, the only one
%     of the model: the DCX blocks connect the two sides in one physical network)
param.sim.export_legacy_names = 1;          % 1: export the flat names the model reads (last section); 0 after
%     update_sst_cllc_ttype_inv('migrate')
%[text] ## CLLC-DCX stages (library block cllc_dcx/cllc_dcx_mod1)
% The two blocks read everything from their mask parameter p: param.cllc.p_mod1 and param.cllc.p_mod2
% (update_sst_cllc_ttype_inv.m writes the two names into the masks). cllc_dcx_param_example(tc): 800 V -> 800 V,
% 50 kW, 50 kHz (fn = 0.95), mode 0 = open-loop DCX, bridge 1 in PWM at 50 % and bridge 2 synchronous rectifier,
% sample time of the block = tc. Power flows from side 1 (battery) to side 2 (inverter) only: for the reverse
% direction swap the roles, p.ctrl.sr_mode_1 = 1, p.ctrl.sr_mode_2 = 0 (header of the library function).
p = cllc_dcx_param_example(param.sim.tc);
bench = sst_cllc_ttype_param(p);            % the numbers of this bench (./private), operating point from p
param.sst = bench.sst;
param.grid = bench.grid;
param.cllc = bench.cllc;
param.spinv.hw_in = bench.spinv.hw_in;
param.spinv.ctrl_in = bench.spinv.ctrl_in;
param.battery = bench.battery;
clear bench

p.ctrl.mode = param.cllc.mode;
p.hw.Vdc10 = param.cllc.udc1_nom;           % [V] initial voltages of the DC links of the block: the run starts
p.hw.Vdc20 = param.cllc.udc2_nom;           %     near the steady state (the dclink block of the inverter too)
param.cllc.p_mod1 = p;
param.cllc.p_mod2 = p;
if param.cllc.interleave
    param.cllc.p_mod2.pwm.phase = pi/2;     % [rad] carrier of module 2 a quarter of the period behind module 1
end
param.cllc.fpwm = p.pwm.fpwm;               % [Hz] 50 kHz, also fPWM_CLLC of the timing object
param.cllc.trgo = p.pwm.double_update;      % 0: control once per period
param.cllc.dead_time = p.pwm.dead_time;     % [s] 300 ns
param.cllc.idx = cllc_dcx_log_index();      % indices of the ctrl_log vector (cllc_dcx_ctrl_log_mod1/2_sim)
fprintf('DCX: %d modules, %.0f V -> %.0f V, %.0f kW each, fs = %.0f kHz, mode %d, interleave %d, block tc = %.0f ns\n', ...
    param.sst.n_modules, param.cllc.udc1_nom, param.cllc.udc2_nom, param.cllc.pwr_nom/1e3, param.cllc.fpwm/1e3, ...
    param.cllc.mode, param.cllc.interleave, param.cllc.p_mod1.pwm.tc*1e9);
clear p
%[text] ## Timing
param.time.fpwm = param.spinv.hw_in.fpwm;           % [Hz] 4 kHz, carrier of the T-type inverters, base of the timing object
param.time.t_measure = 0.2;                         % [s] logged window: the last 0.2 s of the run
param.time.tc_factor = round(1/param.time.fpwm/param.sim.tc/2);    % ts_afe/tc (double update: ts_afe = 1/(2 fpwm)), so that glb_time.tc = param.sim.tc
param.time.tc_decimation = 1;
param.time.delay_pwm = 0;

% the T-type modulators read fPWM_INV, dead_time_AFE and TRGO_AFE_double_update, the PI blocks ts_inv: AFE and
% INV are set alike. The battery blocks sample at ts_dab. The other stages are needed by the shared timing object only.
param.time.fpwm_afe = param.time.fpwm;
param.time.trgo_afe = 1;                            % double update
param.time.dead_time_afe = 3e-6;                    % [s] dead time of the T-type bridges
param.time.fpwm_inv = param.time.fpwm;
param.time.trgo_inv = 1;
param.time.dead_time_inv = 3e-6;
param.time.fpwm_single_phase_inv = param.time.fpwm;
param.time.trgo_single_phase_inv = 1;
param.time.dead_time_single_phase_inv = 3e-6;
param.time.fpwm_dab = 3*param.time.fpwm;
param.time.trgo_dab = 1;
param.time.dead_time_dab = 2e-6;
param.time.fpwm_psfbc = param.time.fpwm;
param.time.trgo_psfbc = 1;
param.time.dead_time_psfbc = 3e-6;
param.time.fpwm_isop_rail = param.time.fpwm;
param.time.trgo_isop_rail = 1;
param.time.dead_time_isop_rail = 3e-6;
%[text] ### Global timing object
t = param.time;
c = param.cllc;
param.glb_time = timing_setup(t.fpwm_afe, t.trgo_afe, t.fpwm_inv, t.trgo_inv, ...
    t.fpwm_single_phase_inv, t.trgo_single_phase_inv, t.fpwm_dab, t.trgo_dab, ...
    t.fpwm_psfbc, t.trgo_psfbc, t.fpwm_isop_rail, t.trgo_isop_rail, c.fpwm, c.trgo, ...
    t.t_measure, t.tc_factor, t.tc_decimation, t.delay_pwm, t.dead_time_afe, t.dead_time_inv, ...
    t.dead_time_single_phase_inv, t.dead_time_dab, t.dead_time_psfbc, t.dead_time_isop_rail, c.dead_time);
clear t c
if abs(param.glb_time.tc - param.sim.tc) > 1e-12*param.sim.tc
    error('init_model: glb_time.tc = %.6g s differs from param.sim.tc = %.6g s (tc_factor = %g): check param.time.tc_factor', ...
        param.glb_time.tc, param.sim.tc, param.time.tc_factor);
end
fprintf('Timing: fpwm = %.0f Hz (ts_inv = %.0f us), tc = %.0f ns, %d logged samples in the last %.2f s\n', ...
    param.glb_time.fPWM_INV, param.glb_time.ts_inv*1e6, param.glb_time.tc*1e9, param.glb_time.Nc, param.glb_time.t_measure);
%[text] ## Single-phase T-type inverters (both modules read param.spinv)
%[text] ### Hardware
% The numbers are the model's own (param.spinv.hw_in, 800 V DC link, 125.5 A), the library provides the setup
% class hw_single_phase_inverter_setup (normalization: ubez = us_nom sqrt(2) = 720 V, ibez = is_nom sqrt(2),
% udc_bez = udc_nom); the generic single_phase_inverter_hwdata of the library sizes 690 V / 1239 V stages.
h = param.spinv.hw_in;
param.spinv.hw = hw_single_phase_inverter_setup(param.grid.u_ll_ref, h.pwr_nom, h.us_nom, h.is_nom, h.f_nom, ...
    h.udc_nom, h.fpwm, h.CFi, h.RCFi, h.CFi1, h.RCFi1, h.CFi2, h.RCFi2, h.LFu, h.RLFu, h.LFu_cm, h.RLFu_cm, ...
    h.CFu, h.RCFu, h.Rbrake);
clear h
fprintf('Inverter module: udc %.0f V, ubez %.0f V peak (us_nom %.1f V rms), ibez %.1f A peak (is_nom %.1f A rms), fpwm %.0f Hz\n', ...
    param.spinv.hw.udc_nom, param.spinv.hw.ubez, param.spinv.hw.us_nom, param.spinv.hw.ibez, param.spinv.hw.is_nom, param.spinv.hw.fpwm_base);
fprintf('AC line: %.0f V rms (%d x %.0f V rms), %.1f A rms, L_line %.2f mH + R_line %.0f mOhm per inductor; grid base %.0f V peak = %.2f pu of ubez\n', ...
    param.grid.u_rms, param.sst.n_modules, param.grid.u_rms_module, param.grid.i_nom, param.grid.L_line*1e3, ...
    param.grid.R_line*1e3, param.grid.u_pk_module, param.grid.u_pk_module/param.spinv.hw.ubez);
% DC link ripple of the single-phase module: energy swing P/omega on the bank CFi at udc_nom
du_dc = param.spinv.hw.pwr_nom/param.grid.omega_nom/(param.spinv.hw.CFi*param.spinv.hw.udc_nom);
fprintf('DC link of the module: CFi = %.1f mF (CFi1 = CFi2 = %.0f mF), 100 Hz ripple about %.0f V peak-peak (%.1f %%)\n', ...
    param.spinv.hw.CFi*1e3, param.spinv.hw.CFi1*1e3, du_dc, 100*du_dc/param.spinv.hw.udc_nom);
clear du_dc
%[text] ### Control
% dq vector PI on the line current in the virtual dq frame of the single-phase PLL (first harmonic tracker);
% module A runs the loop and module B applies the same voltage command (udq_ctrl_out_modA): the modules are in
% series and carry the same current. The resonant PI and the observers of the class are kept for the library
% blocks; the PLL reads the double-integrator observer param.spinv.ctrl.di_obs (afe_ctrl.di_obs in the model of
% 2026-10-24, the same matrices: ctrl_afe_setup and ctrl_single_phase_inverter_setup build it alike).
c = param.spinv.ctrl_in;
param.spinv.ctrl = ctrl_single_phase_inverter_setup(param.glb_time.ts_inv, param.grid.omega_nom, ...
    c.kp_inv, c.ki_inv, c.kp_rpi, c.ki_rpi, c.delta_rpi);
param.spinv.ctrl.u_lim = c.u_lim;
param.spinv.sogi = sogi_filter(param.grid.omega_nom, c.sogi_delta, c.kepsilon, param.glb_time.ts_inv);
param.spinv.i_ref = c.i_ref;                % [pu of ibez] reference of the line current (Step block of module A)
param.spinv.t_ref = c.t_ref;                % [s]
param.spinv.i_ref_slew = c.i_ref_slew;      % [pu/s] Rate Limiter after the step
param.ctrl.clip_release = c.clip_release;   % CTRPIFF_CLIP_RELEASE of the PI blocks
clear c
fprintf('Current loop: kp = %.2f, ki = %.0f, ts = %.0f us, reference %.2f pu (%.1f A rms) from t = %.2f s with %.1f pu/s\n', ...
    param.spinv.ctrl.kp_inv, param.spinv.ctrl.ki_inv, param.spinv.ctrl.ts*1e6, param.spinv.i_ref, ...
    param.spinv.i_ref*param.spinv.hw.is_nom, param.spinv.t_ref, param.spinv.i_ref_slew);
%[text] ### Power semiconductors
% T-type leg at 800 V: the vertical switches see the whole DC link, the neutral switches half of it. First run with
% the 1200 V SiC half-bridge module of the DCX bridges on all positions (TBC: a 650 V device fits the neutral
% switches). The ideal-switch variant of the bridge (commented out in the model) reads param.spinv.ideal_switch.
param.dev.used_device_mosfet = 'wolfspeed_SiC_MOSFET_CAB006M12GM3';
param.dev.used_device_ideal_switch = 'silicon_high_power_ideal_switch';
param.spinv.mosfet = device_mosfet_setup(param.dev.used_device_mosfet, param.glb_time.fPWM_INV, param.spinv.hw.udc_nom);
param.spinv.ideal_switch = device_ideal_switch_setting(param.dev.used_device_ideal_switch, param.glb_time.fPWM_INV, ...
    param.spinv.hw.udc_nom);
%[text] ## Batteries (side 1)
% battery_1 and battery_2 are in parallel on the 800 V bus with the side 1 of both DCX; each pack is sized on the
% module power. Kalman sample time of the battery blocks: glb_time.ts_dab (battery_2 had ts_cllc in the model of
% 2026-10-24, update_sst_cllc_ttype_inv.m aligns it).
b = param.battery;
param.battery.pack_1 = lithium_ion_battery_setup(b.nominal_battery_voltage_1, b.nominal_battery_power, ...
    b.charge_capacity_1, b.initial_battery_soc, param.glb_time.ts_dab);
param.battery.pack_2 = lithium_ion_battery_setup(b.nominal_battery_voltage_2, b.nominal_battery_power, ...
    b.charge_capacity_2, b.initial_battery_soc, param.glb_time.ts_dab);
clear b

% special settings for simulation: stiffer packs, faster RC branch (the masks of the two battery blocks read the
% pack values as they are; the /100 of battery_1 was in the mask of the model of 2026-10-24 and is here now)
for k = 1:2
    pk = sprintf('pack_%d', k);
    param.battery.(pk).R0 = param.battery.(pk).R0/2;
    param.battery.(pk).R1 = param.battery.(pk).R1/2;
    param.battery.(pk).C1 = param.battery.(pk).C1/100;
end
clear k pk
fprintf('Batteries: 2 x %.0f V, %.0f kW, %.1f Ah, SOC %.2f, R0 = %.1f mOhm each\n', param.battery.nominal_battery_voltage_1, ...
    param.battery.nominal_battery_power/1e3, param.battery.charge_capacity_1, param.battery.initial_battery_soc, ...
    param.battery.pack_1.R0*1e3);
%[text] ## Sensors quantization
param.meas.adc_quantization = 1/2^11;
param.meas.adc12_quantization = param.meas.adc_quantization;    % 12-bit ADC, signed
param.meas.adc11_quantization = 1/2^10;                         % 11-bit (current acquisition of the model)
param.meas.adc16_quantization = 1/2^15;
%[text] ## Thermal model
% aluminium plate, liquid cooled; "A" (ambient) is the water: HA is the temperature rise from water to
% heatsink surface; water in/out rise max 5 K with 2 kW total losses
param.thermal.weight = 0.150;                                   % [kg]
param.thermal.no_weight = 0.150/10;                             % [kg] /10: thermal inertia not accounted
param.thermal.cp_al = 900;                                      % [J/(kg K)] specific heat, aluminium
param.thermal.heat_capacity_hs = param.thermal.cp_al * param.thermal.weight;   % [J/K]
param.thermal.thermal_conductivity_al = 160;                    % [W/(m K)] aluminium
param.thermal.Rth_switch_HA = 15/1000;                          % [K/W]
param.thermal.Rth_mosfet_HA = param.thermal.Rth_switch_HA;      % [K/W]
param.thermal.Rth_diode_HA = param.thermal.Rth_switch_HA;       % [K/W]
param.thermal.Tambient = 40;                                    % [degC] water temperature
param.thermal.DThs_init = 0;                                    % [K]

t = param.thermal;
param.thermal.heatsink = liquid_cooled_plate_2kw_setup(t.weight, t.no_weight, t.cp_al, t.heat_capacity_hs, ...
    t.thermal_conductivity_al, t.Rth_switch_HA, t.Rth_mosfet_HA, t.Rth_diode_HA, t.Tambient, t.DThs_init);
clear t
%[text] ### Library workaround: thermal sources read the base workspace
% Inside the thermal bridges of the library (masked_models/semiconductors_bridges/*.slx, the T-type bridge of this
% model included) the temperature source has T = DThs_init+Tambient and the initial temperatures read Tambient,
% instead of the mask parameters DThs_init_m / Tambient_m that the instance sets: the two flat names must exist in
% the base workspace. Delete this section once the library is fixed.
Tambient = param.thermal.Tambient;
DThs_init = param.thermal.DThs_init;
%[text] ## Model setup
open_system(model);
%[text] ### Scopes closed at start
open_scopes = find_system(model, 'BlockType', 'Scope');
for k = 1:numel(open_scopes)
    set_param(open_scopes{k}, 'Open', 'off');
end
clear open_scopes k
%[text] ## Transition: legacy workspace names
% The model of 2026-10-24 reads the flat names below; update_sst_cllc_ttype_inv('migrate') replaces them with the
% param.* names of the right column (same table in that file). Exported while param.sim.export_legacy_names = 1.
if param.sim.export_legacy_names
    glb_time = param.glb_time;                                      % glb_time.*               -> param.glb_time.*
    simlength = param.sim.simlength;                                % simlength                -> param.sim.simlength
    tc = param.glb_time.tc;                                         % tc (FixedStep)           -> param.glb_time.tc
    nonlinear_iterations = param.sim.nonlinear_iterations;          %                          -> param.sim.nonlinear_iterations
    hwdata.single_phase_inverter = param.spinv.hw;                  % hwdata.single_phase_inverter.* -> param.spinv.hw.*
    hwdata.cllc.udc1_nom = param.cllc.udc1_nom;                     % hwdata.cllc.udc1_bez/nom -> param.cllc.udc1_nom
    hwdata.cllc.udc1_bez = param.cllc.udc1_nom;
    hwdata.cllc.udc2_nom = param.cllc.udc2_nom;                     % hwdata.cllc.udc2_bez/nom -> param.cllc.udc2_nom
    hwdata.cllc.udc2_bez = param.cllc.udc2_nom;
    mosfet.inv = param.spinv.mosfet;                                % mosfet.inv.*             -> param.spinv.mosfet.*
    ideal_switch = param.spinv.ideal_switch;                        % ideal_switch.*           -> param.spinv.ideal_switch.*
    heatsink = param.thermal.heatsink;                              % heatsink.*               -> param.thermal.heatsink.*
    lithium_ion_battery_1 = param.battery.pack_1;                   % lithium_ion_battery_1.*  -> param.battery.pack_1.*
    lithium_ion_battery_2 = param.battery.pack_2;                   % lithium_ion_battery_2.*  -> param.battery.pack_2.*
    single_phase_inverter_ctrl = param.spinv.ctrl;                  % single_phase_inverter_ctrl.* -> param.spinv.ctrl.*
    afe_ctrl.di_obs = param.spinv.ctrl.di_obs;                      % afe_ctrl.di_obs.*        -> param.spinv.ctrl.di_obs.*
    sogi = param.spinv.sogi;                                        % sogi.flt.beta            -> param.spinv.sogi.flt.beta
    grid_emu.u2bez = param.grid.u_pk_module;                        % grid_emu.u2bez           -> param.grid.u_pk_module
    grid_emu.omega_grid_nom = param.grid.omega_nom;                 % grid_emu.omega_grid_nom  -> param.grid.omega_nom
    grid_emu.trafo.Ld2 = param.grid.L_line;                         % grid_emu.trafo.Ld2       -> param.grid.L_line
    grid_emu.trafo.Rd2 = param.grid.R_line;                         % grid_emu.trafo.Rd2       -> param.grid.R_line
    omega_set = param.grid.omega_nom;                               % omega_set                -> param.grid.omega_nom
    sst_num_of_modules = param.sst.n_modules;                       % sst_num_of_modules       -> param.sst.n_modules
    adc12_quantization = param.meas.adc12_quantization;             %                          -> param.meas.adc12_quantization
    adc11_quantization = param.meas.adc11_quantization;             %                          -> param.meas.adc11_quantization
    CTRPIFF_CLIP_RELEASE = param.ctrl.clip_release;                 % CTRPIFF_CLIP_RELEASE     -> param.ctrl.clip_release
    fprintf('Legacy names exported for the model (param.sim.export_legacy_names = 1): run update_sst_cllc_ttype_inv(''migrate'') to drop them\n');
end
