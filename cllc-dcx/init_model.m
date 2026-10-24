%[text] # single\_phase\_cllc: model initialization (param structure by subsystem)
% Rev. 02, 2026-10-06: FBK CLLC-DCX 660 V -> 73.3 V, 61 kW (numbers in ./private/cllc_fbk_dcx_param.m).
% Rev. 01, 2026-09-30. Replaces the flat-workspace init_model.m (kept as init_model_legacy.m).
% Same convention as afe_inv_psm/init_model.m: everything the model needs is in the struct "param",
% one group per subsystem:
%   param.sim       simulation settings (stop time, fixed step / logging base, power stage model choice)
%   param.time      timing settings shared by all stages, and the PWM data of the stages not in this model
%   param.cllc      CLLC converter: application_voltage, pwr_nom, fres, .pwm, .hw_in (the hardware numbers,
%                   kept here and not in the library), .hw (hw_cllc_single_phase_setup object), .ctrl .igbt .mosfet .ideal_switch
%   param.glb_time  timing_setup object (built from param.time and param.cllc.pwm)
%   param.dcdc      PI gains shared by the DC/DC stages (ctrl_cllc_setup, ctrl_dab_setup, ...)
%   param.afe       AFE hardware object only (param.afe.hw): the batteries take its DC-link voltage
%   param.battery   battery inputs;                    param.battery.pack_1 / .pack_2  lithium_ion_battery_setup structs
%   param.meas      ADC end scale and quantization
%   param.ctrl      control settings common to all modules (time alignment, filters, PI clip release)
%   param.thermal   heatsink inputs;                   param.thermal.heatsink  liquid_cooled_plate_2kw_setup object
%   param.dev       names of the semiconductor datasets
%
% Naming rule: the leaf name of the old workspace variable is kept (adc12_quantization ->
% param.meas.adc12_quantization), except that inside param.cllc the cllc_ tag becomes redundant and is
% dropped (fpwm_cllc -> param.cllc.pwm.fpwm, cllc_pwr_nom -> param.cllc.pwr_nom, fres_cllc -> param.cllc.fres).
% Library objects keep their name as a field: hwdata.cllc -> param.cllc.hw, cllc_ctrl -> param.cllc.ctrl,
% mosfet.dab -> param.cllc.mosfet (the full bridges of the model read the DAB device data: same device,
% same PWM frequency and same DC-link voltage as the CLLC one, so the data are identical),
% ideal_switch.dab -> param.cllc.ideal_switch, heatsink -> param.thermal.heatsink,
% lithium_ion_battery_1 -> param.battery.pack_1, glb_time -> param.glb_time.
%
% Library dependence: the library provides classes and algorithms (timing_setup, hw_cllc_single_phase_setup,
% ctrl_cllc_setup, device_*_setup, liquid_cooled_plate_2kw_setup...), the model's numbers stay in this
% file. A function that must be frozen or changed for this model only goes in ./private with the same
% name: MATLAB resolves private functions before the path, for the files of this folder only, and
% the list of such overrides is printed at every run (see below). Each private copy states in its
% header where it comes from and what was changed.
%
% The last code section ("Transition: legacy workspace names") exports the old names still read by
% single_phase_cllc.slx. migrate_single_phase_cllc.m rewrites the model to param.*; once done, set
% export_legacy_names = false and delete that section.

clear;
[model, options] = init_environment('single_phase_cllc_param');   % 'single_phase_cllc_param' once migrated
s = tf('s');
param = struct();

% functions overridden for this model: ./private takes precedence over the library
overrides = dir(fullfile(fileparts(mfilename('fullpath')), 'private', '*.m'));
if ~isempty(overrides)
    fprintf('%s init: local overrides in private/: %s\n', model, strjoin({overrides.name}, ', '));
end
clear overrides

% save('sim_results_07.mat', '-v7.3', '-regexp', '_sim$', '^param$');
%[text] ## Simulation
param.sim.simlength = 0.25;                 % [s] model StopTime
% param.sim.tc = 0.625e-6;                    % [s] logging base and model MaxStep (glb_time.tc); FixedStep is not used (ode23tb)
param.sim.tc = 62.5e-9;                    % [s] logging base and model MaxStep (glb_time.tc); FixedStep is not used (ode23tb)
%     same value as the legacy init: ts_afe/200 with fpwm = 4 kHz, double update

% power stage model of the two full bridges: MOSFET with thermal model (with or without the ZVS snubber)
% or ideal switch. The legacy init had both flags at 0 while the active bridges in the .slx were the
% MOSFET thermal ZVS ones: the flags now reflect the model and drive the commented state (see Model setup).
param.sim.use_mosfet_thermal_model = 1;
param.sim.use_zvs_snubber = 1;              % Csnubber_zvs, Rsnubber_zvs across each MOSFET

param.sim.nonlinear_iterations = 3;         % Simscape solver (the Solver Configuration blocks of this model have 5 hard-coded)
if param.sim.use_mosfet_thermal_model
    param.sim.nonlinear_iterations = 5;
end

% white noise power used by the module behaviour settings (clock and PWM phase noise)
param.sim.wnp = 0;

% template settings not read by single_phase_cllc.slx, kept with the same names as in afe_inv_psm
param.sim.load_step_time = 1.25;            % [s]
param.sim.transmission_delay = 125e-6*2;    % [s]
param.sim.sst_num_of_modules = 2;
param.sim.time_aux_power_supply_fault = 1e3;    % [s] never, in this run
param.sim.number_of_modules = 1;
param.sim.enable_two_modules = param.sim.number_of_modules;

% stages of the shared init template not present in single_phase_cllc.slx (grid, FRT, AFE control,
% inverter, PSM, IM, single-phase inverter, DAB, PSFBC, ISOP rail, UPQC, diode rectifier, load
% transformer, DC-link stray inductance): see add_template_extras at the end
param.sim.build_template_extras = false;
%[text] ## Timing
param.time.fpwm = 4e3;                              % [Hz] base PWM frequency
% param.time.t_measure = param.sim.simlength;         % [s]
param.time.t_measure = param.sim.simlength/5;         % [s]
param.time.tc_factor = 1/param.time.fpwm/param.sim.tc/2;    % ts_afe/tc, so that glb_time.tc = param.sim.tc
param.time.tc_decimation = 1;
param.time.delay_pwm = 0;
param.time.trgo_th_generator = 0.025;

% stages not in this model, needed by the shared timing object only
param.time.fpwm_afe = param.time.fpwm;
param.time.trgo_afe = 1;                            % double update
param.time.dead_time_afe = 3e-6;
param.time.fpwm_inv = param.time.fpwm;
param.time.trgo_inv = 1;                            % double update
param.time.dead_time_inv = 3e-6;
param.time.fpwm_single_phase_inv = param.time.fpwm;
param.time.trgo_single_phase_inv = 1;               % double update
param.time.dead_time_single_phase_inv = 3e-6;
param.time.fpwm_dab = 3*param.time.fpwm;
param.time.trgo_dab = 1;                            % double update
param.time.dead_time_dab = 2e-6;
param.time.fpwm_psfbc = param.time.fpwm;
param.time.trgo_psfbc = 1;                          % double update
param.time.dead_time_psfbc = 3e-6;
param.time.fpwm_isop_rail = param.time.fpwm;
param.time.trgo_isop_rail = 1;                      % double update
param.time.dead_time_isop_rail = 3e-6;
%[text] ### CLLC PWM
% FBK CLLC-DCX 660 V -> 73.3 V, 61 kW: the local numbers (pwr_nom, fres, pwm, hw_in, tank) are in
% ./private/cllc_fbk_dcx_param.m (fs = 35 kHz, fr = 37 kHz, dead time 300 ns)
% power flow: 0 = load, side 1 -> side 2 (runs up to 06); sink, side 2 -> side 1: 1 = battery + current
% source (run 07), 2 = mirror bench R1 + voltage source U2 (run 04). It sets the modes of the two bridges
% (sr.mode, sr1.mode) and the bench values (param.cllc.sink, .ic), but the bench of the .slx is changed by
% hand: see the private file.
param.sim.sink = 0;
param.cllc = cllc_fbk_dcx_param(param.sim.sink); %[output:48e2cb2f]
flow = {'load', 'sink, battery + current source', 'sink, mirror bench'};
fprintf('Power flow: %s, sr.mode = %d (bridge 2), sr1.mode = %d (bridge 1)\n', ...
    flow{param.sim.sink + 1}, param.cllc.sr.mode, param.cllc.sr1.mode);
clear flow
param.cllc.application_voltage = 400;               % [V] FBK grid; now it only sets the AFE object (Batteries)
%[text] ### Global timing object
t = param.time;
c = param.cllc.pwm;
param.glb_time = timing_setup(t.fpwm_afe, t.trgo_afe, t.fpwm_inv, t.trgo_inv, ...
    t.fpwm_single_phase_inv, t.trgo_single_phase_inv, t.fpwm_dab, t.trgo_dab, ...
    t.fpwm_psfbc, t.trgo_psfbc, t.fpwm_isop_rail, t.trgo_isop_rail, c.fpwm, c.trgo, ...
    t.t_measure, t.tc_factor, t.tc_decimation, t.delay_pwm, t.dead_time_afe, t.dead_time_inv, ...
    t.dead_time_single_phase_inv, t.dead_time_dab, t.dead_time_psfbc, t.dead_time_isop_rail, c.dead_time);
clear t c
%[text] ## CLLC
%[text] ### Hardware
% The numbers are the model's own (param.cllc.hw_in), the library provides only the setup class
% hw_cllc_single_phase_setup, which derives the tank (Q = 1: Rac, Ls, Cs, Ls1/2, Cs1/2, Ld1/2) and the
% normalization data. Same data sets as single_phase_cllc_hwdata of the library: 1200 V for the 690 V
% application, 800 V for 480 V and 400 V (there RCdc1_dc2 = Cdc_dc2/2 was a typo, corrected here).
% FBK: fres and hw_in come from ./private/cllc_fbk_dcx_param.m (set in CLLC PWM); the 1200 V / 800 V
% data sets of the library are no longer used.
h = param.cllc.hw_in;
param.cllc.hw = hw_cllc_single_phase_setup(h.name, param.cllc.pwr_nom, h.udc1, h.udc2, h.uac1, h.uac2, ...
    h.idc1, h.idc2, param.glb_time.fPWM_CLLC, param.cllc.fres, ...
    h.n1, h.n2, h.Lm, h.Rfe, h.Rs1, h.core_length, h.core_mur, h.Cdc_dc1, h.Cdc1_dc1, h.Cdc2_dc1, h.Cdc_dc2, ...
    h.Cdc1_dc2, h.Cdc2_dc2, h.RCdc_dc1, h.RCdc1_dc1, h.RCdc2_dc1, h.RCdc_dc2, h.RCdc1_dc2, h.RCdc2_dc2, ...
    h.Ldc_dc1, h.Ldc_dc2, h.RLdc_dc1, h.RLdc_dc2);
clear h
% DCX tank of the sizing (Lr1 = 10 uH, Cr1 = 1.85 uF, Q = 0.4, Ln = 39) written over the Q = 1 tank that
% hw_cllc_single_phase_setup derives by itself. Same symmetrical layout as the class: Ls1 = Ld1 on the
% primary, Ls2 = Ld2 = Ld1/n^2 and Cs2 = n^2*Cs1 on the secondary, Ls and Cs the series totals.
t = param.cllc.tank;
param.cllc.hw.Q = t.Q;
param.cllc.hw.Rac = t.Rac;
param.cllc.hw.Ld1 = t.Lr1;
param.cllc.hw.Ls1 = t.Lr1;
param.cllc.hw.Cs1 = t.Cr1;
param.cllc.hw.Ld2 = t.Lr2;
param.cllc.hw.Ls2 = t.Lr2;
param.cllc.hw.Cs2 = t.Cr2;
param.cllc.hw.Ls = 2*t.Lr1;
param.cllc.hw.Cs = t.Cr1/2;
clear t
% the current loop controls the primary DC current (normalization 1/Idc_FS): the class takes
% Idc_FS = max(idc1, idc2) = 1000 A, which made 1 pu = 1000 A on the primary (run sim_results_01)
param.cllc.hw.Idc_FS = param.cllc.hw.idc1_nom;     % [A] 111 A
param.cllc.hw.displayInfo();
%[text] ### Control
% PI gains shared by the DC/DC stages of the template (the model reads param.cllc.ctrl.kp_idc and .ki_idc)
param.dcdc.kp_udc = 0.5;
param.dcdc.ki_udc = 18.0;
param.dcdc.kp_idc = 0.5;
param.dcdc.ki_idc = 18.0;
param.cllc.ctrl = ctrl_cllc_setup(param.dcdc.kp_udc, param.dcdc.ki_udc, param.dcdc.kp_idc, param.dcdc.ki_idc);
%[text] ### Power semiconductors
param.dev.used_device_igbt = 'mitsubishi_CM1200DW_34T';
% param.dev.used_device_mosfet = 'danfoss_SKM1700MB20R4S2I4';
param.dev.used_device_mosfet = 'wolfspeed_SiC_MOSFET_CAB006M12GM3';   % primary bridge, SiC 1200 V half-bridge, 6.6 mOhm at 100 degC
param.dev.used_device_ideal_switch = 'silicon_high_power_ideal_switch';
param.dev.used_device_mosfet_sr = 'infineon_MOSFET_IPT025N15NM6';    % secondary bridge (SR), Si 150 V, single device

% the full bridges of single_phase_cllc.slx read mosfet.dab / ideal_switch.dab in the legacy init: same
% device, fPWM_DAB = fPWM_CLLC and hwdata.dab.udc1_nom = hwdata.cllc.udc1_nom, so the data are identical
param.cllc.igbt = device_igbt_setup(param.dev.used_device_igbt, param.glb_time.fPWM_CLLC, param.cllc.hw.udc1_nom);
param.cllc.mosfet = device_mosfet_setup(param.dev.used_device_mosfet, param.glb_time.fPWM_CLLC, param.cllc.hw.udc1_nom);
param.cllc.ideal_switch = device_ideal_switch_setting(param.dev.used_device_ideal_switch, param.glb_time.fPWM_CLLC, param.cllc.hw.udc1_nom);
% FBK: full-bridge 2 (SR, 73 V / 950 A rms) reads param.cllc.mosfet_sr, a bank of param.cllc.sr.n_par
% devices in parallel per switch (set_sr_device_in_model.m points the bridge masks to it); full-bridge 1
% keeps param.cllc.mosfet
param.cllc.mosfet_sr = device_mosfet_parallel( ...
    device_mosfet_setup(param.dev.used_device_mosfet_sr, param.glb_time.fPWM_CLLC, param.cllc.hw.udc2_nom), ...
    param.cllc.sr.n_par, param.glb_time.fPWM_CLLC, param.cllc.hw.udc2_nom);
% Output capacitance of the switches (Czvs block across each MOSFET of the two bridges, mask parameters
% Csnubber_m / Rsnubber_m = Csnubber_zvs / Rsnubber_zvs). mos_simple_2th has no Coss, and the library ZVS
% snubber has Rsnubber_zvs = 1/(Csnubber_zvs*fpwm)/5 in series (4.6 kOhm primary, 23 kOhm SR bank): in
% practice open, so the dead-time transitions are done by the diodes in one step. With use_coss = 1 the
% Czvs blocks become Coss of the device (of the bank for the SR) with a small series resistance, time
% constant tau_coss << dead time. Coss from the datasets: CAB006 0.79 nF, IPT025N15NM6 x 16 = 36.8 nF.
param.sim.use_coss = 1;                     % 0: library ZVS snubber (runs up to 05), 1: Coss (run 06)
param.sim.tau_coss = 10e-9;                 % [s] Rsnubber_zvs*Csnubber_zvs when use_coss = 1
if param.sim.use_coss
    param.cllc.mosfet.Csnubber_zvs = param.cllc.mosfet.Coss;
    param.cllc.mosfet.Rsnubber_zvs = param.sim.tau_coss/param.cllc.mosfet.Coss;
    param.cllc.mosfet_sr.Csnubber_zvs = param.cllc.mosfet_sr.Coss;
    param.cllc.mosfet_sr.Rsnubber_zvs = param.sim.tau_coss/param.cllc.mosfet_sr.Coss;
end
fprintf('Czvs primary %.2f nF + %.3g Ohm, SR bank %.2f nF + %.3g Ohm (use_coss = %d)\n', ...
    param.cllc.mosfet.Csnubber_zvs*1e9, param.cllc.mosfet.Rsnubber_zvs, ...
    param.cllc.mosfet_sr.Csnubber_zvs*1e9, param.cllc.mosfet_sr.Rsnubber_zvs, param.sim.use_coss);
% ZVS of the primary: at the switching instant the primary current is the magnetizing peak (fs < fr), and it
% must charge and discharge the capacitances of one leg (2 x (Coss + Csnubber_zvs)) within the dead time
im_pk = param.cllc.hw.udc1_nom/(4*param.cllc.hw_in.Lm*param.glb_time.fPWM_CLLC);   % [A] 12 A
if param.sim.use_coss
    c_leg = 2*param.cllc.mosfet.Csnubber_zvs;                                     % [F] Czvs = Coss
else
    c_leg = 2*(param.cllc.mosfet.Coss + param.cllc.mosfet.Csnubber_zvs);          % [F]
end
t_zvs = c_leg*param.cllc.hw.udc1_nom/im_pk;                                        % [s]
fprintf('Primary ZVS: im_pk = %.1f A, C_leg = %.2f nF, transition %.0f ns, dead time %.0f ns\n', ...
    im_pk, c_leg*1e9, t_zvs*1e9, param.cllc.pwm.dead_time*1e9);
if t_zvs > param.cllc.pwm.dead_time
    warning('Primary ZVS not complete: the transition (%.0f ns) is longer than the dead time.', t_zvs*1e9);
end
clear im_pk c_leg t_zvs
%[text] ## Batteries
% FBK: battery 1 at the 660 V bus and battery 2 at the intermediate voltage (73.3 V), sized on the CLLC
% power. Before, both were at the AFE DC-link voltage (hwdata.afe.udc_nom, 1070 V for 690 V); the AFE
% object is still built, but no longer read here.
param.afe.pwr_nom = 250e3;                          % [W]
param.afe.hw = three_phase_afe_hwdata(param.cllc.application_voltage, param.afe.pwr_nom, param.glb_time.fPWM_AFE);

param.battery.nominal_battery_voltage_1 = param.cllc.hw.udc1_nom;  % [V] 660 V
param.battery.nominal_battery_voltage_2 = param.cllc.hw.udc2_nom;  % [V] 73.3 V
param.battery.nominal_battery_power = param.cllc.pwr_nom;           % [W]
param.battery.initial_battery_soc = 0.85;
% lithium_ion_battery_setup takes the charge capacity [Ah] as third argument (the legacy init used the
% old four-argument signature). ASSUMPTION: 1C rating, capacity = rated current x 1 h
param.battery.charge_capacity_1 = param.battery.nominal_battery_power/param.battery.nominal_battery_voltage_1;
param.battery.charge_capacity_2 = param.battery.nominal_battery_power/param.battery.nominal_battery_voltage_2;

% Kalman sample time: the legacy init uses ts_dab for both packs; in the model battery_1 reads
% glb_time.ts_dab and battery_2 reads glb_time.ts_cllc (single update: twice ts_dab).
% lithium_ion_battery_setup is the copy in ./private (frozen for this model), not the library one.
b = param.battery;
param.battery.pack_1 = lithium_ion_battery_setup(b.nominal_battery_voltage_1, b.nominal_battery_power, ...
    b.charge_capacity_1, b.initial_battery_soc, param.glb_time.ts_dab);
param.battery.pack_2 = lithium_ion_battery_setup(b.nominal_battery_voltage_2, b.nominal_battery_power, ...
    b.charge_capacity_2, b.initial_battery_soc, param.glb_time.ts_dab);
clear b

% special settings for simulation
param.battery.pack_1.R0 = param.battery.pack_1.R0/2;
param.battery.pack_1.R1 = param.battery.pack_1.R1/2;
param.battery.pack_2.R0 = param.battery.pack_2.R0/2;
param.battery.pack_2.R1 = param.battery.pack_2.R1/2;
param.battery.pack_1.C1 = param.battery.pack_1.C1/50;
param.battery.pack_2.C1 = param.battery.pack_2.C1/50;
%[text] ## Sensors end scale and quantization
param.meas.adc_quantization = 1/2^11;
param.meas.adc12_quantization = param.meas.adc_quantization;
param.meas.adc16_quantization = 1/2^15;

param.meas.Imax_adc = 1049.835;             % [A]
param.meas.CurrentQuantization = param.meas.Imax_adc/2^11;

param.meas.Umax_adc = 1500;                 % [V]
param.meas.VoltageQuantization = param.meas.Umax_adc/2^11;
%[text] ## Control settings common to all modules
% not read by single_phase_cllc.slx, same group as in afe_inv_psm
% local time alignment to master time
param.ctrl.kp_align = 0.25;
param.ctrl.ki_align = 18;
param.ctrl.lim_up_align = 0.05;
param.ctrl.lim_down_align = -0.05;

% filters and PI clip release
param.ctrl.CTRPIFF_CLIP_RELEASE = 0.001;
param.ctrl.mavarage_filter_frequency_base_order = 2;   % 2 means 100 Hz, 1 means 50 Hz
param.ctrl.dmavg_filter_enable_time = 0.025;           % [s]
param.ctrl.filters = setup_global_filters(param.glb_time.ts_afe, param.glb_time.ts_inv, param.glb_time.ts_dab, param.glb_time.tc);
%[text] ## Thermal model
% aluminium plate, liquid cooled, sized for PrimePACK2; liquid flow > 28 l/min
% "A" (ambient) is the water: HA is the temperature rise from water to heatsink surface;
% water in/out rise max 5 K with 2 kW total losses
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
% Inside the thermal bridges of the library (masked_models/semiconductors_bridges/*.slx) the temperature
% source has T = DThs_init+Tambient and the initial temperatures read Tambient, instead of the mask
% parameters DThs_init_m / Tambient_m that the instance sets: the two flat names must exist in the base
% workspace. Delete this section once the library is fixed (tools/fix_library_thermal_source_refs.m).
Tambient = param.thermal.Tambient;
DThs_init = param.thermal.DThs_init;
%[text] ## Template extras (not used by single\_phase\_cllc.slx)
if param.sim.build_template_extras
    param = add_template_extras(param, options);
end
%[text] ## Model setup
open_system(model);
%[text] ### C-Caller types
% kept from the shared template (single_phase_cllc.slx has no C Caller block)
ctypes = {'mavgflt_output_t', 'dsmavgflt_output_t', 'mavgflts_output_t', 'bemf_obsv_output_t', ...
    'bemf_obsv_load_est_output_t', 'dqvector_pi_output_t', 'sv_pwm_output_t', 'sv_pwm_cm_output_t', ...
    'global_state_machine_output_t', 'first_harmonic_tracker_output_t', 'dqpll_thyr_output_t', ...
    'dqpll_grid_output_t', 'rpi_output_t', 'phase_shift_flt_output_t', 'sogi_flt_output_t', ...
    'linear_double_integrator_observer_output_t'};
for k = 1:numel(ctypes)
    Simulink.importExternalCTypes(model, 'Names', ctypes(k));
end
clear ctypes k
%[text] ### Scopes closed at start
open_scopes = find_system(model, 'BlockType', 'Scope');
for k = 1:numel(open_scopes)
    set_param(open_scopes{k}, 'Open', 'off');
end
clear open_scopes k
%[text] ### Enable/disable subsystems
% % power stage model of the two full bridges: MOSFET thermal with ZVS snubber, MOSFET thermal, or ideal
% % switch (the other two are commented out), and the matching scope subsystem. New with respect to the
% % legacy init, which left the choice to the model: the defaults reproduce the state saved in the .slx.
% if param.sim.use_mosfet_thermal_model && param.sim.use_zvs_snubber
%     active_bridge = 'full-bridge_mosfet_based_with_thermal_model_zvs';
%     active_scopes = 'thermal_analysis_inverters_mosfet_zvs';
% elseif param.sim.use_mosfet_thermal_model
%     active_bridge = 'full-bridge_mosfet_based_with_thermal_model';
%     active_scopes = 'thermal_analysis_inverters_mosfet';
% else
%     active_bridge = 'full-bridge_ideal_switch_based';
%     active_scopes = 'analysis_inverters_ideal_switches';
% end
% bridge_models = {'full-bridge_mosfet_based_with_thermal_model_zvs', ...
%                  'full-bridge_mosfet_based_with_thermal_model', ...
%                  'full-bridge_ideal_switch_based'};
% scope_models = {'thermal_analysis_inverters_mosfet_zvs', ...
%                 'thermal_analysis_inverters_mosfet', ...
%                 'analysis_inverters_ideal_switches'};
% % "dc/dc with galvanic isolation" has a slash in its name: "//" in the block path
% bridge_paths = {[model '/dcdc_cllc_modA/dc//dc with galvanic isolation/full-bridge 1/'], ...
%                 [model '/dcdc_cllc_modA/dc//dc with galvanic isolation/full-bridge 2/']};
% commented = {'on', 'off'};                  % index 2 (off) for the active block
% for ip = 1:numel(bridge_paths)
%     for ib = 1:numel(bridge_models)
%         set_param([bridge_paths{ip} bridge_models{ib}], 'Commented', ...
%             commented{1 + strcmp(bridge_models{ib}, active_bridge)});
%     end
% end
% for ib = 1:numel(scope_models)
%     set_param([model '/scopes/' scope_models{ib}], 'Commented', ...
%         commented{1 + strcmp(scope_models{ib}, active_scopes)});
% end
% clear active_bridge active_scopes bridge_models scope_models bridge_paths commented ip ib
%[text] ## Local functions
function param = add_template_extras(param, options)
% Parts of the shared init template not used by single_phase_cllc.slx, kept so that nothing of the
% legacy init_model.m is lost. Enabled by param.sim.build_template_extras = true.
% Same convention: one group per stage (param.grid, param.frt, param.afe, param.inv, param.psm,
% param.load, param.spinv, param.dab, param.psfbc, param.isop_rail, param.upqc, param.im, param.diode,
% param.trafo_load, param.dclink), each with .hw, .ctrl, devices.

s = tf('s');
ts = param.glb_time.ts_inv;
uapp = param.cllc.application_voltage;
dev = param.dev;

% ---------------------------------------------------------------- grid emulator
param.grid.grid_nominal_power = 1000e3;             % [W]
param.grid.application_voltage = uapp;              % [V] 690, 480 or 400
param.grid.grid_nominal_current = param.grid.grid_nominal_power/param.grid.application_voltage/sqrt(3);

% coupling transformer Dyn11
param.grid.delta_star = 1;

if param.grid.application_voltage == 690
    param.grid.us1 = 690; param.grid.us2 = 690; param.grid.fgrid = 50;
    param.grid.eta = 95; param.grid.ucc = 5;
    param.grid.p_iron = 1800;
elseif param.grid.application_voltage == 480
    param.grid.us1 = 480; param.grid.us2 = 480; param.grid.fgrid = 60;
    param.grid.eta = 95; param.grid.ucc = 5;
    param.grid.p_iron = 1400;
else
    param.grid.us1 = 400; param.grid.us2 = 400; param.grid.fgrid = 50;
    param.grid.eta = 95; param.grid.ucc = 5;
    param.grid.p_iron = 1000;
end

param.grid.n2 = 14;
param.grid.n1 = floor(param.grid.n2*sqrt(3));
param.grid.core_area = 0.05;                        % [m^2]
param.grid.core_length = 2.5;                       % [m]
param.grid.mu0 = 4*pi*1e-7;
param.grid.mur = 10e3;

% magnetizing inductance from the core geometry, no-load current from it
param.grid.Lm1 = (param.grid.n1^2 * param.grid.mu0 * param.grid.mur * param.grid.core_area) / param.grid.core_length;
param.grid.i1m = param.grid.us1/sqrt(3)/param.grid.Lm1/(2*pi*param.grid.fgrid);

% reference for the voltage sequences
param.grid.up_xi_pu_ref = 1;
param.grid.up_eta_pu_ref = 0;
param.grid.un_xi_pu_ref = 0;
param.grid.un_eta_pu_ref = 0;

% grid impedance
param.grid.Lgrid_base = param.grid.us1/sqrt(3)*param.grid.ucc/100/2/pi/param.grid.fgrid/param.grid.grid_nominal_current;
param.grid.ucc_factor = 1;
param.grid.eq_grid_inductance = param.grid.Lgrid_base*param.grid.ucc_factor;    % [H]
param.grid.eq_grid_resistance = 2e-3;                                             % [Ohm]

g = param.grid;
param.grid.emu = grid_three_phase_emulator('Dyn11', g.delta_star, g.grid_nominal_power, g.application_voltage, ...
    g.us1, g.us2, g.fgrid, g.eq_grid_inductance, g.eq_grid_resistance, g.eta, g.ucc, g.i1m, g.p_iron, ...
    g.n1, g.n2, g.core_area, g.core_length, g.mur, ...
    g.up_xi_pu_ref, g.up_eta_pu_ref, g.un_xi_pu_ref, g.un_eta_pu_ref);

% ---------------------------------------------------------------- FRT
param.frt.test_index = 25;                  % type of fault: index
param.frt.test_subindex = 4;                % type of fault: subindex
param.frt.enable_frt_1 = 0;                 % faults generated from abc
param.frt.enable_frt_2 = 0;                 % faults generated from xi_eta_pos and xi_eta_neg
param.frt.start_time_LVRT = 0.75;           % [s]
param.frt.asymmetric_error_type = 1;        % 0: variant C (two-phase), 1: variant D (single-phase)
param.frt.deepPOSxi = 1;
param.frt.deepPOSeta = -0.4;
param.frt.deepNEGxi = 0.4;
param.frt.deepNEGeta = 0.4;

f = param.frt;
param.frt.data = frt_settings(f.test_index, f.test_subindex, f.asymmetric_error_type, ...
    f.enable_frt_1, f.enable_frt_2, f.start_time_LVRT, f.deepPOSxi, f.deepPOSeta, f.deepNEGxi, f.deepNEGeta);

% grid_fault_generator is a function: it returns the fault waveform data (amplitudes, phase shift,
% error_length, end_time_LVRT, t_ramp, k_lvrt, load levels), merged here into param.frt.data
frt_gen = grid_fault_generator(param.frt.data, f.start_time_LVRT);
for fn = fieldnames(frt_gen)'
    param.frt.data.(fn{1}) = frt_gen.(fn{1});
end

% ---------------------------------------------------------------- AFE (param.afe.hw already built)
param.afe.ctrl = ctrl_afe_setup(param.glb_time.ts_afe, param.grid.emu.omega_grid_nom);
param.afe.ctrl.kp_udc_ctrl = 2;
% resonant PI gains for weak grids: kp_rpi 0.5, ki_rpi 18; for LVRT (the values in use):
param.afe.ctrl.res_pi.kp_rpi = 0.6;
param.afe.ctrl.res_pi.ki_rpi = 35;

% dqPLL selection
param.afe.pll.use_dq_pll_fht_pll = 1;
param.afe.pll.use_dq_pll_fht_simulink_pll = 0;
param.afe.pll.use_dq_pll_mod1 = 0;
param.afe.pll.use_dq_pll_ccaller_mod1 = 0;
param.afe.pll.use_dq_pll_ccaller_mod2 = 0;
param.afe.pll.use_dq_pll_mode1 = param.afe.pll.use_dq_pll_mod1;                 % simulink dqPLL
param.afe.pll.use_dq_pll_mode2 = param.afe.pll.use_dq_pll_ccaller_mod1;         % ccaller dqPLL
param.afe.pll.use_dq_pll_mode3 = param.afe.pll.use_dq_pll_fht_simulink_pll;     % fht simulink dqPLL
param.afe.pll.use_dq_pll_mode4 = param.afe.pll.use_dq_pll_fht_pll;              % fht ccaller dqPLL
param.afe.pll.use_dq_pll_mode1_modn = 0;    % simulink dqPLL
param.afe.pll.use_dq_pll_mode2_modn = 0;    % ccaller dqPLL
param.afe.pll.use_dq_pll_mode3_modn = 1;    % fht simulink dqPLL
param.afe.pll.use_dq_pll_mode4_modn = 0;    % fht ccaller dqPLL

% C-caller versus Simulink implementation
param.afe.impl.use_moving_average_from_ccaller_mod1 = 1;
param.afe.impl.use_moving_average_from_ccaller_mod2 = 0;
param.afe.impl.use_moving_average_from_ccaller_mod3 = 0;
param.afe.impl.use_moving_average_from_ccaller_mod4 = 0;

% current references: four modules in parallel connected to a dc microgrid
param.afe.ref.ixi_ref_mod1 = -0.85;
param.afe.ref.ixi_ref_mod2 = -0.85;
param.afe.ref.ixi_ref_mod3 = -0.85;
param.afe.ref.ixi_ref_mod4 = -0.85;

% common mode voltage control for hard parallelization
param.afe.ref.en_parallel_mode = 1;
param.afe.ref.u_cm_comp_mod1 = 0;
param.afe.ref.u_cm_comp_mod2 = 0;
param.afe.ref.u_cm_comp_mod3 = 0;
param.afe.ref.u_cm_comp_mod4 = 0;
if param.afe.ref.en_parallel_mode
    param.afe.ref.u_cm_comp_mod2 = -1;
    param.afe.ref.u_cm_comp_mod3 = -1;
    param.afe.ref.u_cm_comp_mod4 = -1;
end

% reactive current steps after the LVRT
param.afe.ref.enable_i_react_pos_steps = 1;
param.afe.ref.time_i_react_pos_ref_1 = 0;   % default
param.afe.ref.time_i_react_pos_ref_2 = 0;   % default
param.afe.ref.i_react_pos_ref_1 = 0;        % default
param.afe.ref.i_react_pos_ref_2 = 0;        % default
param.afe.ref.i_react_pos_ref_3 = 0;        % default
if param.afe.ref.enable_i_react_pos_steps
    param.afe.ref.time_i_react_pos_ref_1 = param.frt.data.start_time_LVRT + param.frt.data.error_length + 0.335;
    param.afe.ref.time_i_react_pos_ref_2 = param.afe.ref.time_i_react_pos_ref_1 + 0.5;
    param.afe.ref.i_react_pos_ref_2 = -param.afe.ref.ixi_ref_mod1*tan(acos(0.95));   % cos(phi) = 0.95
    param.afe.ref.i_react_pos_ref_3 =  param.afe.ref.ixi_ref_mod1*tan(acos(0.95));   % cos(phi) = 0.95
end

% module behaviour (clock mismatch, noise, PWM phase shift)
param.afe.behav.time_gain_module_1 = 1.0002;
param.afe.behav.time_gain_module_2 = 1.0015;
param.afe.behav.time_gain_module_3 = 0.9988;
param.afe.behav.time_gain_module_4 = 1.0020;
param.afe.behav.white_noise_power_mod1 = param.sim.wnp;
param.afe.behav.white_noise_power_mod2 = param.sim.wnp;
param.afe.behav.pwm_phase_shift_mod1 = 0;
param.afe.behav.white_noise_power_pwm_phase_shift_mod1 = 0.0;
param.afe.behav.pwm_phase_shift_mod2 = 0;
param.afe.behav.white_noise_power_pwm_phase_shift_mod2 = 0.0;
param.afe.behav.pwm_phase_shift_mod3 = 0;
param.afe.behav.white_noise_power_pwm_phase_shift_mod3 = 0.0;
param.afe.behav.pwm_phase_shift_mod4 = 0;
param.afe.behav.white_noise_power_pwm_phase_shift_mod4 = 0.0;

% ---------------------------------------------------------------- inverter
param.inv.pwr_nom = 250e3;
param.inv.hw = three_phase_inverter_hwdata(uapp, param.inv.pwr_nom, param.glb_time.fPWM_INV);

param.inv.behav.time_gain_module_1 = 1.0005;
param.inv.behav.time_gain_module_2 = 1.001;
param.inv.behav.white_noise_power_mod1 = param.sim.wnp;
param.inv.behav.white_noise_power_mod2 = param.sim.wnp;
param.inv.behav.pwm_phase_shift_mod1 = 0;
param.inv.behav.white_noise_power_pwm_phase_shift_mod1 = 0.0;
param.inv.behav.pwm_phase_shift_mod2 = 0;
param.inv.behav.white_noise_power_pwm_phase_shift_mod2 = 0.0;
param.inv.behav.pwm_phase_shift_mod3 = 0;
param.inv.behav.white_noise_power_pwm_phase_shift_mod3 = 0.0;
param.inv.behav.pwm_phase_shift_mod4 = 0;
param.inv.behav.white_noise_power_pwm_phase_shift_mod4 = 0.0;

% ---------------------------------------------------------------- PSM and its control
param.psm.machine = psm_calculus();
param.psm.n_sys = param.psm.machine.number_of_systems;
param.psm.u_psm_scale = 2/3*param.inv.hw.udc_nom/param.psm.machine.ubez;
param.psm.u_psm_scale_ekf = sqrt(3)/2 * 2/3 * param.inv.hw.udc_nom/param.psm.machine.ubez;

param.psm.mode.use_torque_curve = 1;                                        % energy production
param.psm.mode.use_speed_control = 1 - param.psm.mode.use_torque_curve;     % drive
param.psm.mode.use_mtpa = 1;
param.psm.mode.use_psm_encoder = 0;
param.psm.mode.use_im_encoder = 1;
param.psm.mode.use_load_estimator = 0;
param.psm.mode.use_estimator_from_mb = 0;                                   % mb: model based
param.psm.mode.use_motor_speed_control_mode = 0;
param.psm.mode.motor_torque_mode = 1 - param.psm.mode.use_motor_speed_control_mode;   % torque curve for wind application
param.psm.mode.time_start_motor_control = 0.25;                             % [s]

param.psm.impl.use_ekf_bemf_module_1 = 1;
param.psm.impl.use_ekf_bemf_module_2 = 1;
param.psm.impl.use_observer_from_simulink_module_1 = 0;
param.psm.impl.use_observer_from_ccaller_module_1 = 0;
param.psm.impl.use_observer_from_simulink_module_2 = 0;
param.psm.impl.use_observer_from_ccaller_module_2 = 0;
param.psm.impl.use_current_controller_from_simulink_module_1 = 0;
param.psm.impl.use_current_controller_from_ccaller_module_1 = 1;
param.psm.impl.use_current_controller_from_simulink_module_2 = 0;
param.psm.impl.use_current_controller_from_ccaller_module_2 = 0;

param.psm.ctrl = ctrl_pmsm_setup(ts, param.psm.machine.omega_bez, param.psm.u_psm_scale, param.psm.machine.Jm_norm);
% alternative: ekf_pmsm_setup(Rs_norm, Ls_norm, Jm_norm, ts)
param.psm.ctrl.ekf = ekf_pmsm_setup(param.psm.machine.Rs_norm, param.psm.machine.Ls_norm, 1e6, ts);
param.psm.ctrl.kp_i = 0.25;
param.psm.ctrl.ki_i = 35;

% ---------------------------------------------------------------- mechanical load, speed reference, torque curve
param.load.b = param.psm.machine.load_friction_m;
param.load.external_load_inertia = 1;       % alternative: 6*param.psm.machine.Jm_m

% energy production: torque curve (the library script reads n_sys, writes rpm_base, torque_base;
% the two outputs are declared first so that the script can overwrite them inside this function)
n_sys = param.psm.n_sys; %#ok<NASGU>
rpm_base = []; torque_base = [];
run('n_sys_generic_1M5W_torque_curve');
param.load.rpm_base = rpm_base;
param.load.torque_base = torque_base;
param.load.torque_overload_factor = 1;

% drive application: speed reference and load torque
param.load.rpm_sim = 17.8;                  % alternatives: 3000, 15.2
param.load.omega_m_sim = param.psm.machine.omega_m_bez;
param.load.omega_sim = param.load.omega_m_sim*param.psm.machine.number_poles/2;
param.load.tau_load_sim = param.psm.machine.tau_bez/5;  % [N*m]
param.load.b_square = 0;

% ---------------------------------------------------------------- induction machine
param.im.machine = im_calculus();
param.im.u_im_scale = 2/3*param.inv.hw.udc_nom/param.im.machine.ubez;
param.im.u_im_scale_ekf = (2/3)^2 * param.inv.hw.udc_nom/param.im.machine.ubez;
param.im.ctrl = ctrl_im_setup(ts, param.im.machine.omega_bez, param.im.u_im_scale, param.im.machine.Jm_norm);
param.im.ctrl.ekf = ekf_im_setup(param.im.machine.alpha_norm, param.im.machine.beta_norm, param.im.machine.gamma_norm, ...
    param.im.machine.sigma_norm, param.im.machine.mu_norm, param.im.machine.Lm_norm, param.im.machine.Jm_norm, ts);

% ---------------------------------------------------------------- single-phase inverter
% global behaviour: system identification versus normal operation
param.spinv.system_identification_enable = 0;
param.spinv.frequency_set = 50;             % default
if param.spinv.system_identification_enable
    param.spinv.frequency_set = 300;
end
param.spinv.omega_set = param.spinv.frequency_set*2*pi;

param.spinv.rpi_enable = 0;                 % use RPI otherwise DQ PI
param.spinv.impl.use_current_controller_from_ccaller_mod1 = 1;
param.spinv.impl.use_phase_shift_filter_from_ccaller_mod1 = 1;
param.spinv.impl.use_sogi_from_ccaller_mod1 = 1;

param.spinv.impl.use_single_phase_inverter_based_FHT = 0;
param.spinv.impl.use_single_phase_inverter_based_SOGI = 0;
param.spinv.impl.use_single_phase_inverter_based_PHSH = 0;
param.spinv.impl.use_single_phase_inverter_based_SOGI_ccaller = 1;
param.spinv.impl.use_single_phase_inverter_based_PHSH_ccaller = 0;

param.spinv.impl.use_system_identification_based_FHT = 0;
param.spinv.impl.use_system_identification_based_SOGI = 0;
param.spinv.impl.use_system_identification_based_PHSH = 0;
param.spinv.impl.use_system_identification_based_SOGI_ccaller = 0;
param.spinv.impl.use_system_identification_based_PHSH_ccaller = 1;

% current references
param.spinv.ref.iph_grid_pu_ref_1 = 1/3;
param.spinv.ref.iph_grid_pu_ref_2 = 1/3;
param.spinv.ref.iph_grid_pu_ref_3 = 1/3;
param.spinv.ref.time_step_ref_1 = 0.025;
param.spinv.ref.time_step_ref_2 = 0.5;
param.spinv.ref.time_step_ref_3 = 1;

param.spinv.pwr_nom = 225e3;
param.spinv.hw = single_phase_inverter_hwdata(uapp, param.spinv.pwr_nom, param.glb_time.fPWM_INV);

% ---------------------------------------------------------------- rail catenary and ISOP rail
param.isop_rail.catenary_nominal_power = 2*5.4e6;   % per 12 km
param.isop_rail.catenary_nominal_voltage = 3000;
param.isop_rail.catenary_maximum_voltage = 4000;
param.isop_rail.catenary_nominal_current = param.isop_rail.catenary_nominal_power/param.isop_rail.catenary_nominal_voltage;
param.isop_rail.pwr_nom = 250e3;                    % nominal per system
param.isop_rail.number_of_systems = 4;
param.isop_rail.full_bridge_application_voltage = param.isop_rail.catenary_maximum_voltage/param.isop_rail.number_of_systems;
param.isop_rail.hw = isop_rail_aux_application(param.isop_rail.full_bridge_application_voltage, ...
    param.isop_rail.pwr_nom, param.glb_time.fPWM_ISOP_RAIL);

% ---------------------------------------------------------------- isolated DC/DC stages
param.dab.pwr_nom = 250e3;
param.dab.fres = param.glb_time.fPWM_DAB/5;
param.dab.hw = single_phase_dab_hwdata(uapp, param.dab.pwr_nom, param.glb_time.fPWM_DAB, param.dab.fres);
param.three_phase_dab.pwr_nom = param.dab.pwr_nom;
param.three_phase_dab.hw = three_phase_dab_hwdata(uapp, param.three_phase_dab.pwr_nom, param.glb_time.fPWM_DAB, param.dab.fres);
param.psfbc.pwr_nom = 275e3;
param.psfbc.hw = single_phase_psfbc_hwdata(uapp, param.psfbc.pwr_nom, param.glb_time.fPWM_PSFBC);
% modification of the legacy init
param.afe.hw.CFi = 2 * param.psfbc.hw.Cdc_dc1;

% ---------------------------------------------------------------- UPQC series transformer
param.upqc.name = 'UPQC Series Transformer';
param.upqc.pwr_nom = 3*125e3;
param.upqc.u1_nom = 400;
param.upqc.u2_nom = 690;
param.upqc.f_nom = 50;
param.upqc.eta = 98;
param.upqc.ucc = 4;
param.upqc.p_iron = 5e3;
param.upqc.n12 = param.upqc.u1_nom/param.upqc.u2_nom;
param.upqc.n2 = 8;
param.upqc.n1 = param.upqc.n12*param.upqc.n2;
param.upqc.core_area = 0.04;
param.upqc.core_length = 0.25;
param.upqc.mur = 35e3;
param.upqc.Lm1 = (param.upqc.n1^2 * param.grid.mu0 * param.upqc.mur * param.upqc.core_area) / param.upqc.core_length;
param.upqc.i1m = param.upqc.u1_nom/sqrt(3)/param.upqc.Lm1/param.upqc.f_nom/2/pi;
param.upqc.delta_star = 0;

u = param.upqc;
param.upqc.st = three_phase_transformer_setup(u.name, u.delta_star, u.pwr_nom, u.u1_nom, u.u2_nom, u.f_nom, ...
    u.eta, u.ucc, u.i1m, u.p_iron, u.n1, u.n2, u.core_area, u.core_length, u.mur);
param.upqc.ctrl.kp_p = 1;
param.upqc.ctrl.ki_p = 35;
param.upqc.ctrl.kp_n = 1;
param.upqc.ctrl.ki_n = 35;
param.upqc.ctrl.lim = 4;

% ---------------------------------------------------------------- DC/DC control of the other stages
d = param.dcdc;
param.dab.ctrl = ctrl_dab_setup(d.kp_udc, d.ki_udc, d.kp_idc, d.ki_idc);
param.psfbc.ctrl = ctrl_dab_setup(d.kp_udc, d.ki_udc, d.kp_idc, d.ki_idc);
param.isop_rail.ctrl = ctrl_isop_rail_setup(d.kp_udc, d.ki_udc, d.kp_idc, d.ki_idc);
% special settings
param.psfbc.ctrl.kp_idc = 1;
param.dab.ctrl.ki_udc = 35;

% ---------------------------------------------------------------- resonant PI
param.spinv.pres_ctrl.kp_rpi = 0.75;
param.spinv.pres_ctrl.ki_rpi = 45;
param.spinv.pres_ctrl.delta_rpi = 0.025;
param.spinv.pres_ctrl.omega_set = param.spinv.omega_set;
w = param.spinv.pres_ctrl.omega_set;
dr = param.spinv.pres_ctrl.delta_rpi;
param.spinv.pres_ctrl.res_nom = s/(s^2 + 2*dr*w*s + w^2);
param.spinv.pres_ctrl.Ares_nom = [0 1; -w^2 -2*dr*w];
param.spinv.pres_ctrl.Aresd_nom = eye(2) + param.spinv.pres_ctrl.Ares_nom*ts;
param.spinv.pres_ctrl.a11d = 1;
param.spinv.pres_ctrl.a12d = ts;
param.spinv.pres_ctrl.a21d = -w^2*ts;
param.spinv.pres_ctrl.a22d = 1 - 2*dr*w*ts;         % legacy init writes it to apres_ctrl (typo)
param.spinv.pres_ctrl.Bres = [0; 1];
param.spinv.pres_ctrl.Cres = [0 1];
param.spinv.pres_ctrl.Bresd = param.spinv.pres_ctrl.Bres*ts;
param.spinv.pres_ctrl.Cresd = param.spinv.pres_ctrl.Cres;

% ---------------------------------------------------------------- SOGI
param.spinv.sogi_delta = 1;
param.spinv.kepsilon = 2;
param.spinv.sogi = sogi_filter(param.spinv.omega_set, param.spinv.sogi_delta, param.spinv.kepsilon, param.glb_time.ts_afe);

% ---------------------------------------------------------------- DQ PI current control
param.spinv.dqvector_pi.kp_inv = 0.5;
param.spinv.dqvector_pi.ki_inv = 45;
param.spinv.dqvector_pi.pi_ctrl = param.spinv.dqvector_pi.kp_inv + param.spinv.dqvector_pi.ki_inv/s;
param.spinv.dqvector_pi.pid_ctrl = c2d(param.spinv.dqvector_pi.pi_ctrl, ts);
param.spinv.dqvector_pi.plant = 1/(s*param.grid.emu.trafo.Ld1 + 1);
param.spinv.dqvector_pi.plantd = c2d(param.spinv.dqvector_pi.plant, ts);
param.spinv.dqvector_pi.G = param.spinv.sogi.fltd.alpha * param.spinv.dqvector_pi.pid_ctrl * param.spinv.dqvector_pi.plantd;
figure; margin(param.spinv.dqvector_pi.G, options); grid on

% ---------------------------------------------------------------- single-phase inverter control
param.spinv.ctrl = ctrl_single_phase_inverter_setup(ts, param.spinv.pres_ctrl.omega_set, ...
    param.spinv.dqvector_pi.kp_inv, param.spinv.dqvector_pi.ki_inv, param.spinv.pres_ctrl.kp_rpi, ...
    param.spinv.pres_ctrl.ki_rpi, param.spinv.pres_ctrl.delta_rpi);

% ---------------------------------------------------------------- devices of the other stages
param.afe.igbt = device_igbt_setup(dev.used_device_igbt, param.glb_time.fPWM_AFE, param.afe.hw.udc_nom);
param.inv.igbt = device_igbt_setup(dev.used_device_igbt, param.glb_time.fPWM_INV, param.inv.hw.udc_nom);
param.dab.igbt = device_igbt_setup(dev.used_device_igbt, param.glb_time.fPWM_DAB, param.dab.hw.udc1_nom);
param.psfbc.igbt = device_igbt_setup(dev.used_device_igbt, param.glb_time.fPWM_PSFBC, param.psfbc.hw.udc1_nom);
param.isop_rail.igbt = device_igbt_setup(dev.used_device_igbt, param.glb_time.fPWM_ISOP_RAIL, param.isop_rail.hw.udc1_nom);

param.afe.mosfet = device_mosfet_setup(dev.used_device_mosfet, param.glb_time.fPWM_AFE, param.afe.hw.udc_nom);
param.inv.mosfet = device_mosfet_setup(dev.used_device_mosfet, param.glb_time.fPWM_INV, param.inv.hw.udc_nom);
param.dab.mosfet = device_mosfet_setup(dev.used_device_mosfet, param.glb_time.fPWM_DAB, param.dab.hw.udc1_nom);
param.psfbc.mosfet = device_mosfet_setup(dev.used_device_mosfet, param.glb_time.fPWM_PSFBC, param.psfbc.hw.udc1_nom);
param.isop_rail.mosfet = device_mosfet_setup(dev.used_device_mosfet, param.glb_time.fPWM_ISOP_RAIL, param.isop_rail.hw.udc1_nom);

param.afe.ideal_switch = device_ideal_switch_setting(dev.used_device_ideal_switch, param.glb_time.fPWM_AFE, param.afe.hw.udc_nom);
param.inv.ideal_switch = device_ideal_switch_setting(dev.used_device_ideal_switch, param.glb_time.fPWM_INV, param.inv.hw.udc_nom);
param.dab.ideal_switch = device_ideal_switch_setting(dev.used_device_ideal_switch, param.glb_time.fPWM_DAB, param.dab.hw.udc1_nom);
param.psfbc.ideal_switch = device_ideal_switch_setting(dev.used_device_ideal_switch, param.glb_time.fPWM_PSFBC, param.psfbc.hw.udc1_nom);
param.isop_rail.ideal_switch = device_ideal_switch_setting(dev.used_device_ideal_switch, param.glb_time.fPWM_ISOP_RAIL, param.isop_rail.hw.udc1_nom);

% ---------------------------------------------------------------- diode rectifier
% ABB 5SDF 0131Z0401 (slow recovery)
param.diode.rectifier.Vf = 0.977;           % [V]
param.diode.rectifier.Rdon = 22e-6;         % [Ohm]
param.diode.rectifier.Cj = 0;               % [F]
param.diode.rectifier.Irm = -75;            % [A]
param.diode.rectifier.didt = -30;           % [A/us]
param.diode.rectifier.trr = 5;              % [us]
param.diode.rectifier.Qrr = 325e-6;         % [C]
param.diode.rectifier.Ifm = 2000;           % [A]
param.diode.rectifier.Vr = -50;             % [V]
param.diode.rectifier.Err = 15e-3;          % [J]
param.diode.rectifier.Rth_JC = 0.004;       % [K/W]
param.diode.rectifier.Rth_CH = 0.003;       % [K/W]
param.diode.rectifier.Rsnubber = 1e4;       % [Ohm]
param.diode.rectifier.Csnubber = 1e-12;     % [F]

% ---------------------------------------------------------------- load transformer and RL load
param.trafo_load.name = 'Load Single Phase Transformer';
param.trafo_load.pwr_nom = 225e3;
param.trafo_load.u1_nom = 400;
param.trafo_load.n1 = 50;
param.trafo_load.n2 = 1;
param.trafo_load.u2_nom = param.trafo_load.u1_nom/param.trafo_load.n1*param.trafo_load.n2;
param.trafo_load.f_nom = param.spinv.frequency_set;     % alternative: 50
param.trafo_load.eta = 98;
param.trafo_load.ucc = 5;
param.trafo_load.i1m = 10;
param.trafo_load.p_iron = 2e3;

tl = param.trafo_load;
param.trafo_load.output_transformer = single_phase_transformer_setup(tl.name, tl.pwr_nom, tl.u1_nom, ...
    tl.u2_nom, tl.n1, tl.n2, tl.f_nom, tl.eta, tl.ucc, tl.i1m, tl.p_iron);

param.trafo_load.uload = 2;
param.trafo_load.rload = param.trafo_load.uload / param.trafo_load.output_transformer.i2_nom;
param.trafo_load.lload = 250e-6 / param.trafo_load.output_transformer.n12^2;
% alternative: rload = 0.86/m12_load_trafo^2; lload = 3e-3/m12_load_trafo^2;

% ---------------------------------------------------------------- DC-link stray inductance (partial loop inductance)
% same data as the library script parasitic_dclink_data.m; Bode check only
param.dclink.Lstray_dclink = 100e-9;                            % [H]
param.dclink.RLstray_dclink = 10e-3;                            % [Ohm]
param.dclink.C_HF_Lstray_dclink = 15e-6;                        % [F]
param.dclink.R_HF_Lstray_dclink = 22000;                        % [Ohm]
param.dclink.Z_HF_Lstray_dclink = 1/s/param.dclink.C_HF_Lstray_dclink + param.dclink.R_HF_Lstray_dclink;
param.dclink.Z_LF_Lstray_dclink = s*param.dclink.Lstray_dclink + param.dclink.RLstray_dclink;
param.dclink.Z_Lstray_dclink = param.dclink.Z_HF_Lstray_dclink*param.dclink.Z_LF_Lstray_dclink/ ...
    (param.dclink.Z_HF_Lstray_dclink + param.dclink.Z_LF_Lstray_dclink);
param.dclink.ZCFi = 7/s/param.afe.hw.CFi;
param.dclink.sys_dclink = minreal(param.dclink.ZCFi/(param.dclink.ZCFi + param.dclink.Z_Lstray_dclink));
figure; bode(param.dclink.sys_dclink, param.dclink.Z_Lstray_dclink, options); grid on
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":33.8}
%---
%[output:48e2cb2f]
%   data: {"dataType":"error","outputData":{"errorType":"runtime","text":"cllc_fbk_dcx_param is not found in the current folder or on the MATLAB path, but exists in:\n    C:\\github\\secom-development\\PROP-2026-011-FBK-BIDCDC\\matlab_model\\cllc\\private\n\n<a href = \"matlab:internal.matlab.desktop.commandwindow.executeCommandForUser('cd ''C:\\github\\secom-development\\PROP-2026-011-FBK-BIDCDC\\matlab_model\\cllc\\private''')\">Change the MATLAB current folder<\/a>."}}
%---
