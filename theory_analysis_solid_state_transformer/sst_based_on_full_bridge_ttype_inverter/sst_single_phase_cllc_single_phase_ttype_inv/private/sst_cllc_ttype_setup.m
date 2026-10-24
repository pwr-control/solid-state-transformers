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
%                 (device_mosfet_setup), .ideal_switch (device_ideal_switch_setting), .i_ref, .t_ref, .i_ref_slew
%     .ctrl       .clip_release of the PI blocks (CTRPIFF_CLIP_RELEASE)
%     .battery    .pack_1, .pack_2 lithium_ion_battery_setup structs, stiffer for the simulation
%     .thermal    .heatsink liquid_cooled_plate_2kw_setup object
%   Being in ./private it is seen only by the files of this folder.
%
%   Rev. 01, 2026-10-24: the construction part of the former init_model.m.

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
