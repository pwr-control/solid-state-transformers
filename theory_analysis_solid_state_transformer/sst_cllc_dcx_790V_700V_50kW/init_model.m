%[text] # sst\_cllc\_dcx\_35kHz: model initialization (param structure by subsystem)
% 2026-10-24: 35 kHz variant of the SST CLLC-DCX stage, 790 V -> 700 V, 50 kW (the 800 V -> 800 V, 50 kHz bench
% is ../sst_cllc_dcx_800V_800V_50kW; numbers in ./private/cllc_dcx_param.m,
% sizing in cllc_dcx_sizing.md). Everything the model needs is in the struct "param", one group per
% subsystem:
%   param.sim       simulation settings (stop time, Simscape local solver step, bench mode, Coss option)
%   param.time      timing settings shared by all stages, and the PWM data of the stages not in this model
%   param.cllc      CLLC converter: pwr_nom, fres, .pwm, .hw_in (the hardware numbers, kept here and not in the
%                   library), .tank, .sr, .sr1, .sink, .ic, .hw (hw_cllc_single_phase_setup object), .ctrl,
%                   .mosfet (bridge 1), .mosfet_sr (bridge 2)
%   param.glb_time  timing_setup object (built from param.time and param.cllc.pwm)
%   param.dcdc      PI gains shared by the DC/DC stages (ctrl_cllc_setup)
%   param.battery   battery inputs;                    param.battery.pack_1  lithium_ion_battery_setup struct
%   param.meas      ADC quantization
%   param.thermal   heatsink inputs;                   param.thermal.heatsink  liquid_cooled_plate_2kw_setup object
%   param.dev       names of the semiconductor datasets
%
% Library dependence: the library provides classes and algorithms (timing_setup, hw_cllc_single_phase_setup,
% ctrl_cllc_setup, device_mosfet_setup, device_mosfet_parallel, lithium_ion_battery_setup,
% liquid_cooled_plate_2kw_setup) and the blocks of sst_cllc_dcx_35kHz.slx (mos_simple_2th, single_phase_transformer,
% dab_single_phase_pwm_modulator, lithium_ion_battery, discrete_time_low_pass_filter); the model's numbers stay
% in this folder. A function that must be frozen or changed for this model only goes in ./private with the
% same name: MATLAB resolves private functions before the path, for the files of this folder only, and the
% list of the files of ./private is printed at every run. The first command of the script, library_setup
% (./private/library_setup.m), adds the library to the path with its subfolders: it uses the copy already on the
% path, else the folder "library" next to this repository (or the one named by the environment variable
% PWR_CONTROL_LIBRARY), and clones https://github.com/pwr-control/library when neither exists.

clear;
library_setup;              % pwr-control/library on the path, cloned next to this repository when missing (./private/library_setup.m)
[model, options] = init_environment('sst_cllc_dcx_35kHz');
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
param.sim.simlength = 0.25;                 % [s] model StopTime
param.sim.tc = 500e-9;                      % [s] logging base, model MaxStep and Simscape local solver step
%     (glb_time.tc). Backward Euler adds a numerical damping of about 2 (w^2 Lr1 tc/2 + tc/(2 Cr1)) to the
%     tank, proportional to tc (printed by power_loss_calculus.m): 50 ns = 571 steps per switching period,
%     dead time 6 steps, 0.082 Ohm (0.42 kW at full load, Sec. 8 of the sizing note); 500 ns = 57 steps per
%     period, dead time below one step, 0.82 Ohm (about 4.3 kW at full load and 50 V less on side 2). 500 ns
%     for quick structural checks, 50 to 100 ns for the loss and ZVS numbers; the run time scales with 1/tc
param.sim.nonlinear_iterations = 5;         % Simscape solver (Solver Configuration block of the model)

% power flow: 0 = load, side 1 -> side 2; sink, side 2 -> side 1: 1 = battery + current source,
% 2 = mirror bench R1 + voltage source U2. It sets the modes of the two bridges (sr.mode, sr1.mode) and the
% bench values (param.cllc.sink, .ic); the bench blocks of the .slx are swapped by hand (README.md)
param.sim.sink = 0;

% output capacitance of the switches: 0 = library ZVS snubber across each MOSFET (in practice open: the
% dead-time transitions are done by the diodes in one step), 1 = Coss of the device with a small series
% resistance (time constant tau_coss << dead time), to see the ZVS transitions and the ringing
param.sim.use_coss = 1;
param.sim.tau_coss = 10e-9;                 % [s] Rsnubber_zvs*Csnubber_zvs when use_coss = 1
%[text] ## Timing
param.time.fpwm = 4e3;                              % [Hz] base PWM frequency of the shared timing object
param.time.t_measure = param.sim.simlength/5;       % [s] logged window: the last 50 ms of the run
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
%[text] ### CLLC PWM and bench
% 790 V -> 700 V, 50 kW: the local numbers (pwr_nom, fres, pwm, hw_in, tank, sr, sr1, sink, ic) are in
% ./private/cllc_dcx_param.m (fs = 35 kHz, fr = 36.8 kHz, dead time 300 ns, 9:8 transformer)
param.cllc = cllc_dcx_param(param.sim.sink);
flow = {'load', 'sink, battery + current source', 'sink, mirror bench'};
fprintf('Power flow: %s, sr.mode = %d (bridge 2), sr1.mode = %d (bridge 1)\n', ...
    flow{param.sim.sink + 1}, param.cllc.sr.mode, param.cllc.sr1.mode);
clear flow
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
% normalization data.
h = param.cllc.hw_in;
param.cllc.hw = hw_cllc_single_phase_setup(h.name, param.cllc.pwr_nom, h.udc1, h.udc2, h.uac1, h.uac2, ...
    h.idc1, h.idc2, param.glb_time.fPWM_CLLC, param.cllc.fres, ...
    h.n1, h.n2, h.Lm, h.Rfe, h.Rs1, h.core_length, h.core_mur, h.Cdc_dc1, h.Cdc1_dc1, h.Cdc2_dc1, h.Cdc_dc2, ...
    h.Cdc1_dc2, h.Cdc2_dc2, h.RCdc_dc1, h.RCdc1_dc1, h.RCdc2_dc1, h.RCdc_dc2, h.RCdc1_dc2, h.RCdc2_dc2, ...
    h.Ldc_dc1, h.Ldc_dc2, h.RLdc_dc1, h.RLdc_dc2);
clear h
% DCX tank of the sizing (Lr1 = 16 uH, Cr1 = 1.17 uF, Q = 0.37, Ln = 35) written over the Q = 1 tank that
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
% the current loop (commented out in the model: the DCX runs open loop) normalizes the primary DC current
param.cllc.hw.Idc_FS = param.cllc.hw.idc1_nom;     % [A] 63.3 A
param.cllc.hw.displayInfo();
fprintf('DCX tank: Lr1 = %.1f uH, Cr1 = %.3f uF, Lr2 = %.1f uH, Cr2 = %.3f uF, Lm = %.0f uH\n', ...
    1e6*param.cllc.hw.Ls1, 1e6*param.cllc.hw.Cs1, 1e6*param.cllc.hw.Ls2, 1e6*param.cllc.hw.Cs2, 1e6*param.cllc.hw.Lm);
fprintf('          fs = %.1f kHz, fr = %.1f kHz, fn = %.3f, Z0 = %.2f Ohm, Rac = %.2f Ohm, Q = %.3f, Ln = %.1f\n', ...
    1e-3*param.glb_time.fPWM_CLLC, 1e-3*param.cllc.fres, param.glb_time.fPWM_CLLC/param.cllc.fres, ...
    param.cllc.tank.Z0, param.cllc.tank.Rac, param.cllc.tank.Q, param.cllc.tank.Ln);
%[text] ### Control
% PI gains shared by the DC/DC stages (the model reads param.cllc.ctrl.kp_idc and .ki_idc; the loop is
% commented out, the DCX runs open loop with the two bridges in phase)
param.dcdc.kp_udc = 0.5;
param.dcdc.ki_udc = 18.0;
param.dcdc.kp_idc = 0.5;
param.dcdc.ki_idc = 18.0;
param.cllc.ctrl = ctrl_cllc_setup(param.dcdc.kp_udc, param.dcdc.ki_udc, param.dcdc.kp_idc, param.dcdc.ki_idc);
%[text] ### Power semiconductors
% 790 V and 700 V: the same 1200 V SiC half-bridge module on both bridges (Wolfspeed CAB006M12GM3,
% 6.6 mOhm at 100 degC, Coss 0.79 nF). It has margin at 72 A rms on side 1 and 81 A rms on side 2 (about
% 69 W and 87 W of conduction losses); a smaller module of about 13-16 mOhm is the cost option, with twice
% the conduction losses.
param.dev.used_device_mosfet = 'wolfspeed_SiC_MOSFET_CAB006M12GM3';      % bridge 1 (side 1)
param.dev.used_device_mosfet_sr = 'wolfspeed_SiC_MOSFET_CAB006M12GM3';   % bridge 2 (side 2, synchronous rectifier in load)

param.cllc.mosfet = device_mosfet_setup(param.dev.used_device_mosfet, param.glb_time.fPWM_CLLC, param.cllc.hw.udc1_nom);
% full-bridge 2 reads param.cllc.mosfet_sr: one device per switch, or a bank of param.cllc.sr.n_par devices in
% parallel (device_mosfet_parallel); full-bridge 1 reads param.cllc.mosfet
param.cllc.mosfet_sr = device_mosfet_setup(param.dev.used_device_mosfet_sr, param.glb_time.fPWM_CLLC, param.cllc.hw.udc2_nom);
if param.cllc.sr.n_par > 1
    param.cllc.mosfet_sr = device_mosfet_parallel(param.cllc.mosfet_sr, param.cllc.sr.n_par, ...
        param.glb_time.fPWM_CLLC, param.cllc.hw.udc2_nom);
end
% Output capacitance of the switches (Czvs block across each MOSFET of the two bridges, mask parameters
% Csnubber_m / Rsnubber_m = Csnubber_zvs / Rsnubber_zvs). mos_simple_2th has no Coss, and the library ZVS
% snubber has Rsnubber_zvs = 1/(Csnubber_zvs*fpwm)/5 in series: in practice open, so the dead-time
% transitions are done by the diodes in one step. With use_coss = 1 the Czvs blocks become Coss of the
% device with a small series resistance, time constant tau_coss << dead time.
if param.sim.use_coss
    param.cllc.mosfet.Csnubber_zvs = param.cllc.mosfet.Coss;
    param.cllc.mosfet.Rsnubber_zvs = param.sim.tau_coss/param.cllc.mosfet.Coss;
    param.cllc.mosfet_sr.Csnubber_zvs = param.cllc.mosfet_sr.Coss;
    param.cllc.mosfet_sr.Rsnubber_zvs = param.sim.tau_coss/param.cllc.mosfet_sr.Coss;
end
fprintf('Czvs bridge 1 %.2f nF + %.3g Ohm, bridge 2 %.2f nF + %.3g Ohm (use_coss = %d)\n', ...
    param.cllc.mosfet.Csnubber_zvs*1e9, param.cllc.mosfet.Rsnubber_zvs, ...
    param.cllc.mosfet_sr.Csnubber_zvs*1e9, param.cllc.mosfet_sr.Rsnubber_zvs, param.sim.use_coss);
% ZVS of the driving bridge: at the switching instant (fs < fr) its current is the magnetizing peak, and it
% must charge and discharge the capacitances of one leg (2 x (Coss + Csnubber_zvs)) within the dead time
im_pk = param.cllc.hw.udc1_nom/(4*param.cllc.hw_in.Lm*param.glb_time.fPWM_CLLC);   % [A] 10 A
if param.sim.use_coss
    c_leg = 2*param.cllc.mosfet.Csnubber_zvs;                                     % [F] Czvs = Coss
else
    c_leg = 2*(param.cllc.mosfet.Coss + param.cllc.mosfet.Csnubber_zvs);          % [F]
end
t_zvs = c_leg*param.cllc.hw.udc1_nom/im_pk;                                        % [s]
fprintf('Driving bridge ZVS: im_pk = %.1f A, C_leg = %.2f nF, transition %.0f ns, dead time %.0f ns\n', ...
    im_pk, c_leg*1e9, t_zvs*1e9, param.cllc.pwm.dead_time*1e9);
if t_zvs > param.cllc.pwm.dead_time
    warning('ZVS not complete: the transition (%.0f ns) is longer than the dead time.', t_zvs*1e9);
end
clear im_pk c_leg t_zvs
%[text] ## Battery (side 1)
% battery_1 is the 790 V source of side 1, sized on the DCX power; side 2
% has the current source of the bench (param.cllc.sink), no battery
param.battery.nominal_battery_voltage_1 = param.cllc.hw.udc1_nom;  % [V] 790 V
param.battery.nominal_battery_power = param.cllc.pwr_nom;           % [W]
param.battery.initial_battery_soc = 0.85;
% lithium_ion_battery_setup takes the charge capacity [Ah] as third argument. ASSUMPTION: 1C rating,
% capacity = rated current x 1 h
param.battery.charge_capacity_1 = param.battery.nominal_battery_power/param.battery.nominal_battery_voltage_1;

% Kalman sample time of the battery block: in the model battery_1 reads glb_time.ts_dab
b = param.battery;
param.battery.pack_1 = lithium_ion_battery_setup(b.nominal_battery_voltage_1, b.nominal_battery_power, ...
    b.charge_capacity_1, b.initial_battery_soc, param.glb_time.ts_dab);
clear b

% special settings for simulation: stiffer battery, faster RC branch
param.battery.pack_1.R0 = param.battery.pack_1.R0/2;
param.battery.pack_1.R1 = param.battery.pack_1.R1/2;
param.battery.pack_1.C1 = param.battery.pack_1.C1/50;
%[text] ## Sensors quantization
param.meas.adc_quantization = 1/2^11;
param.meas.adc12_quantization = param.meas.adc_quantization;
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
% Inside the thermal bridges of the library (masked_models/semiconductors_bridges/*.slx) the temperature
% source has T = DThs_init+Tambient and the initial temperatures read Tambient, instead of the mask
% parameters DThs_init_m / Tambient_m that the instance sets: the two flat names must exist in the base
% workspace. This model drives mos_simple_2th blocks directly and reads param.thermal.*; the two names are
% kept for the library blocks that may be added. Delete this section once the library is fixed.
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
