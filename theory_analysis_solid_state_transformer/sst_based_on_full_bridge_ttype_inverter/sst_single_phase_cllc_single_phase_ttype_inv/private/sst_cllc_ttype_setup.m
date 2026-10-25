function param = sst_cllc_ttype_setup(param)
%SST_CLLC_TTYPE_SETUP  Complete "param" of sst_cllc_ttype_inv: numbers of the bench and library objects.
%
%   param = sst_cllc_ttype_setup(param)
%
%   param.sim (simlength, tc, nonlinear_iterations) is set by init_model.m; everything else is added here, one
%   group per subsystem (the model reads them as param.*, or through the flat names of sst_cllc_ttype_legacy.m
%   until it is migrated):
%     .sst .grid .battery .meas .thermal .dev .time   numbers of the bench (sst_cllc_ttype_param.m)
%     .cllc       operating point of the DCX stage; .p_mod1, .p_mod2 mask parameter p of the two library blocks
%                 cllc_dcx/cllc_dcx_mod1 (cllc_dcx_param_example(tc) of the library); .idx indices of ctrl_log
%     .glb_time   timing_setup object: tc, ts_inv, ts_dab, Nc, fPWM_INV, dead_time_AFE, ... read by the model
%     .spinv      T-type inverter of one module (both modules read it): .hw (hw_single_phase_inverter_setup),
%                 .ctrl (ctrl_single_phase_inverter_setup, the PLL reads .di_obs), .sogi (sogi_filter), .mosfet
%                 (device_mosfet_setup), .ideal_switch (device_ideal_switch_setting), .i_ref, .t_ref, .i_ref_slew;
%                 compact modules (library block afe_single_phase_ttype/afe_single_phase_ttype_mod1): .p_modA,
%                 .p_modB mask parameter p of the two blocks (afe_single_phase_ttype_param_example(tc) with the numbers
%                 of the bench, B slave of A), .idx indices of ctrl_log, .m_to_legacy_modA/B [5 x 13] gains of the
%                 old log tags from the m output ('compact' mode of update_sst_cllc_ttype_inv)
%     .ctrl       .clip_release of the PI blocks (CTRPIFF_CLIP_RELEASE)
%     .battery    .pack_1, .pack_2 lithium_ion_battery_setup structs, stiffer for the simulation
%     .thermal    .heatsink liquid_cooled_plate_2kw_setup object
%   Being in ./private it is seen only by the files of this folder.
%
%   Rev. 01, 2026-10-24: the construction part of the former init_model.m.
%   Rev. 02, 2026-10-25: mask structs of the compact modules (p_modA, p_modB, idx, m_to_legacy).

    % ------------------------------------------------------------------ DCX stage and numbers of the bench
    % cllc_dcx_param_example(tc): 800 V -> 800 V, 50 kW, 50 kHz (fn = 0.95), mode 0 = open-loop DCX, bridge 1 in PWM
    % at 50 % and bridge 2 synchronous rectifier, sample time of the block = tc. Power from side 1 (battery) to
    % side 2 (inverter) only: for the reverse direction swap the roles, p.ctrl.sr_mode_1 = 1, p.ctrl.sr_mode_2 = 0.
    p = cllc_dcx_param_example(param.sim.tc);
    bench = sst_cllc_ttype_param(p);
    for f = fieldnames(bench)'
        param.(f{1}) = bench.(f{1});
    end

    p.ctrl.mode = param.cllc.mode;
    p.hw.Vdc10 = param.cllc.udc1_nom;               % [V] initial voltages of the DC links of the block: the run starts
    p.hw.Vdc20 = param.cllc.udc2_nom;               %     near the steady state (the dclink block of the inverter too)
    param.cllc.p_mod1 = p;
    param.cllc.p_mod2 = p;
    if param.cllc.interleave
        param.cllc.p_mod2.pwm.phase = pi/2;         % [rad] carrier of module 2 a quarter of the period behind module 1
    end
    param.cllc.fpwm = p.pwm.fpwm;                   % [Hz] 50 kHz, also fPWM_CLLC of the timing object
    param.cllc.trgo = p.pwm.double_update;          % 0: control once per period
    param.cllc.dead_time = p.pwm.dead_time;         % [s] 300 ns
    param.cllc.idx = cllc_dcx_log_index();          % indices of the ctrl_log vector (cllc_dcx_ctrl_log_mod1/2_sim)

    % ------------------------------------------------------------------ timing object
    % AFE, INV and SINGLE_PHASE_INV are the T-type inverters (the modulators read the AFE names, the control ts_inv);
    % the battery blocks sample at ts_dab; PSFBC and ISOP_RAIL are needed by the class only.
    t = param.time;
    ts_afe = 1/t.fpwm/(1 + t.trgo);                 % [s] 125 us with double update
    tc_factor = round(ts_afe/param.sim.tc);         % glb_time.tc = ts_afe/tc_factor = param.sim.tc
    param.glb_time = timing_setup(t.fpwm, t.trgo, t.fpwm, t.trgo, t.fpwm, t.trgo, t.fpwm_battery, 1, ...
        t.fpwm, 1, t.fpwm, 1, param.cllc.fpwm, param.cllc.trgo, t.t_measure, tc_factor, t.tc_decimation, ...
        t.delay_pwm, t.dead_time, t.dead_time, t.dead_time, 2e-6, 3e-6, 3e-6, param.cllc.dead_time);
    if abs(param.glb_time.tc - param.sim.tc) > 1e-12*param.sim.tc
        error('sst_cllc_ttype_setup: glb_time.tc = %.6g s differs from param.sim.tc = %.6g s: param.sim.tc must divide ts_inv = %.6g s', ...
            param.glb_time.tc, param.sim.tc, param.glb_time.ts_inv);
    end

    % ------------------------------------------------------------------ single-phase T-type inverter (both modules)
    % hardware: hw_single_phase_inverter_setup normalizes with ubez = us_nom sqrt(2) = 720 V, ibez = is_nom sqrt(2),
    % udc_bez = udc_nom
    h = param.spinv.hw_in;
    param.spinv.hw = hw_single_phase_inverter_setup(param.grid.u_ll_ref, h.pwr_nom, h.us_nom, h.is_nom, h.f_nom, ...
        h.udc_nom, h.fpwm, h.CFi, h.RCFi, h.CFi1, h.RCFi1, h.CFi2, h.RCFi2, h.LFu, h.RLFu, h.LFu_cm, h.RLFu_cm, ...
        h.CFu, h.RCFu, h.Rbrake);
    % control: dq vector PI on the line current in the virtual dq frame of the single-phase PLL (first harmonic
    % tracker); the PLL reads the double-integrator observer .di_obs of the class (afe_ctrl.di_obs in the model,
    % same matrices as ctrl_afe_setup)
    c = param.spinv.ctrl_in;
    param.spinv.ctrl = ctrl_single_phase_inverter_setup(param.glb_time.ts_inv, param.grid.omega_nom, ...
        c.kp_inv, c.ki_inv, c.kp_rpi, c.ki_rpi, c.delta_rpi);
    param.spinv.ctrl.u_lim = c.u_lim;
    param.spinv.sogi = sogi_filter(param.grid.omega_nom, c.sogi_delta, c.kepsilon, param.glb_time.ts_inv);
    param.spinv.i_ref = c.i_ref;                    % [pu of ibez] reference of the line current (Step block of module A)
    param.spinv.t_ref = c.t_ref;                    % [s]
    param.spinv.i_ref_slew = c.i_ref_slew;          % [pu/s] Rate Limiter after the step
    param.ctrl.clip_release = c.clip_release;       % CTRPIFF_CLIP_RELEASE of the PI blocks
    % power semiconductors
    param.spinv.mosfet = device_mosfet_setup(param.dev.used_device_mosfet, param.glb_time.fPWM_INV, param.spinv.hw.udc_nom);
    param.spinv.ideal_switch = device_ideal_switch_setting(param.dev.used_device_ideal_switch, param.glb_time.fPWM_INV, ...
        param.spinv.hw.udc_nom);

    % ------------------------------------------------------------------ compact modules (library block afe_single_phase_ttype)
    % One block per module in the wrappers single_phase_inverter_modA_cmp / modB_cmp of the model: T-type bridge, split
    % DC link and LC filter in Simscape language, the control in a MATLAB Function at p.pwm.tc. Start from
    % afe_single_phase_ttype_param_example(tc) (the bench of 2026-10-24 as the library knows it) and write the numbers
    % of this folder over it, so that a change in sst_cllc_ttype_param.m reaches the old and the compact modules alike.
    pa = afe_single_phase_ttype_param_example(param.sim.tc);
    % power stage: the device of param.spinv.mosfet as a conduction drop (Vth, Rds_on; no switching losses nor
    % thermal model in the block), the DC link bank and the output filter of hw_in, LFu in two halves, the DC link
    % started at the voltage of side 2 of the DCX
    pa.hw.Vth = param.spinv.mosfet.Vth;             % [V]
    pa.hw.Ron = param.spinv.mosfet.Rds_on;          % [Ohm]
    pa.hw.Cdc1 = h.CFi1;    pa.hw.Rdc1 = h.RCFi1;   % upper bank
    pa.hw.Cdc2 = h.CFi2;    pa.hw.Rdc2 = h.RCFi2;   % lower bank
    pa.hw.Vdc0 = param.cllc.udc2_nom;               % [V]
    pa.hw.L1 = h.LFu/2;     pa.hw.R1 = h.RLFu/2;    % line a (leg u)
    pa.hw.L2 = h.LFu/2;     pa.hw.R2 = h.RLFu/2;    % line b (leg v)
    pa.hw.Cf = h.CFu;       pa.hw.Rcf = h.RCFu;
    pa.hw.ubez = h.ubez;                            % [V] bases of the measurements, as the old modules
    pa.hw.ibez = h.is_nom*sqrt(2);                  % [A]
    pa.hw.udc_nom = h.udc_nom;                      % [V]
    % carrier and gates: the timing of the bench (glb_time), the same carrier phase on both modules (in series)
    pa.pwm.fpwm = param.time.fpwm;                  % [Hz]
    pa.pwm.double_update = param.time.trgo;
    pa.pwm.dead_time = param.time.dead_time;        % [s]
    pa.pwm.phase = 0;                               % [rad]
    pa.pwm.t_enable = c.t_enable;                   % [s]
    % control: the period and the grid of the bench, the acquisition (11-bit quantization, Gaussian noise of rms
    % c.i_noise_std on the current sample), the observers placed again on ts_inv and omega_nom
    pa.ctrl.ts = param.glb_time.ts_inv;             % [s] 125 us
    pa.ctrl.omega_nom = param.grid.omega_nom;       % [rad/s]
    pa.ctrl.fht_omega = param.grid.omega_nom;
    pa.ctrl.ug_nom = param.grid.u_pk_module/pa.hw.ubez;     % [pu] 0.78
    pa.ctrl.pll_tau = 2/param.grid.omega_nom;       % [s]
    pa.ctrl.adc_q = param.meas.adc11_quantization;
    pa.ctrl.i_noise_std = c.i_noise_std;            % [pu]
    [pa.ctrl.obs_l1, pa.ctrl.obs_l2] = afe_obs_gains(pa.ctrl.omega_nom, pa.ctrl.ts);
    [pa.ctrl.fht_l1, pa.ctrl.fht_l2] = afe_fht_gains(pa.ctrl.fht_omega, pa.ctrl.fht_delta, pa.ctrl.ts);
    % current loop (kp_i / ki_i of the parameter file, not kp_inv / ki_inv: see there) and references of the bench
    pa.ctrl.mode = 0;                               % current references (1: DC-link voltage loop, not on this bench)
    pa.ctrl.kp_i = c.kp_i;
    pa.ctrl.ki_i = c.ki_i;
    pa.ctrl.u_lim = c.u_lim;
    pa.ctrl.clip_release = c.clip_release;
    pa.ctrl.i_ref = c.i_ref;                        % [pu of ibez]
    pa.ctrl.t_ref = c.t_ref;                        % [s]
    pa.ctrl.i_ref_slew = c.i_ref_slew;              % [pu/s]
    pa.ctrl.iq_ref = 0;
    % module A master (its own PLL and current loop, sync_out = [theta_hat; m_d; m_q] on the Goto synch_AFE_mtos of the
    % model), module B slave: applies the angle and the modulation vector of A (the modules are in series and carry the
    % same current, as udq_ctrl_out_modA of the old modules)
    pa.ctrl.slave = 0;
    param.spinv.p_modA = pa;
    pb = pa;
    pb.ctrl.slave = 1;
    param.spinv.p_modB = pb;
    param.spinv.idx = afe_single_phase_ttype_log_index();      % indices of ctrl_log (afe_cmp_ctrl_log_modA/B_sim)
    % the old log tags in physical units from the m output of the blocks (Gain m_to_legacy of each wrapper, added by
    % update_sst_cllc_ttype_inv('compact')): afe_current_output_modX, afe_voltage_output_modX, afe_is_modX, afe_us_modX,
    % dclink_voltage_modX
    param.spinv.m_to_legacy_modA = afe_m_to_legacy(pa.hw);
    param.spinv.m_to_legacy_modB = afe_m_to_legacy(pb.hw);

    % ------------------------------------------------------------------ batteries (side 1)
    % battery_1 and battery_2 in parallel on the 800 V bus with the side 1 of both DCX; Kalman sample time ts_dab
    b = param.battery;
    param.battery.pack_1 = lithium_ion_battery_setup(b.nominal_battery_voltage_1, b.nominal_battery_power, ...
        b.charge_capacity_1, b.initial_battery_soc, param.glb_time.ts_dab);
    param.battery.pack_2 = lithium_ion_battery_setup(b.nominal_battery_voltage_2, b.nominal_battery_power, ...
        b.charge_capacity_2, b.initial_battery_soc, param.glb_time.ts_dab);
    % special settings for simulation: stiffer packs, faster RC branch (the masks read the pack values as they are)
    for k = 1:2
        pk = sprintf('pack_%d', k);
        param.battery.(pk).R0 = param.battery.(pk).R0/2;
        param.battery.(pk).R1 = param.battery.(pk).R1/2;
        param.battery.(pk).C1 = param.battery.(pk).C1/100;
    end

    % ------------------------------------------------------------------ heatsink of the T-type bridges
    t = param.thermal;
    param.thermal.heatsink = liquid_cooled_plate_2kw_setup(t.weight, t.no_weight, t.cp_al, t.heat_capacity_hs, ...
        t.thermal_conductivity_al, t.Rth_switch_HA, t.Rth_mosfet_HA, t.Rth_diode_HA, t.Tambient, t.DThs_init);
end

% ------------------------------------------------------------------------------------------------------
% Observer gains of the compact modules, the same closed forms as afe_single_phase_ttype_param_example.m of the library
% (local functions there), computed again here on ts_inv and omega_nom of the bench: poles at z = exp([-1 -4]*omega*ts).
function [l1, l2] = afe_obs_gains(omega, ts)
%AFE_OBS_GAINS  double integrator observer x(k+1) = A x + L (y - C x), A = [1 ts; 0 1], C = [1 0]:
%   det(zI - A + L C) = z^2 - (2 - l1) z + (1 - l1) + ts l2
    z1 = exp(-omega*ts);
    z2 = exp(-4*omega*ts);
    l1 = 2 - (z1 + z2);
    l2 = (z1*z2 - (1 - l1))/ts;
end

function [l1, l2] = afe_fht_gains(omega, delta, ts)
%AFE_FHT_GAINS  first harmonic tracker x(k+1) = A x + L (y - C x), A = I + [0 1; -omega^2 -delta*omega]*ts, C = [1 0]:
%   det(zI - A + L C) = z^2 - (2 - l1 - delta*omega*ts) z + (1 - l1)(1 - delta*omega*ts) + ts^2 omega^2 + ts l2
    z1 = exp(-omega*ts);
    z2 = exp(-4*omega*ts);
    d  = delta*omega*ts;
    l1 = 2 - d - (z1 + z2);
    l2 = (z1*z2 - (1 - l1)*(1 - d) - ts^2*omega^2)/ts;
end

function K = afe_m_to_legacy(hw)
%AFE_M_TO_LEGACY  [5 x 13] gain of the old log tags from the m output of the compact block (pu -> physical units):
%   m = [i_s i_a u_ac u_s udc udc_p udc_n i_dc i_np i_c1 i_c2 i_cf i_s2] (afe_ttype_ssc.afe_single_phase_ttype)
    K = zeros(5, 13);
    K(1, 2) = hw.ibez;          % afe_current_output_modX  i_a   terminal current, out of a      [A]
    K(2, 3) = hw.ubez;          % afe_voltage_output_modX  u_ac  terminal voltage a - b          [V]
    K(3, 1) = hw.ibez;          % afe_is_modX              i_s   converter current (L1)          [A]
    K(4, 4) = hw.ubez;          % afe_us_modX              u_s   bridge voltage                  [V]
    K(5, 5) = hw.udc_nom;       % dclink_voltage_modX      udc   DC-link voltage                 [V]
end
