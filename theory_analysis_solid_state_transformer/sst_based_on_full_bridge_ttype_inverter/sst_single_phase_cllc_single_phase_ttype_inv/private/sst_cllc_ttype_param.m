function bench = sst_cllc_ttype_param(p_dcx)
%SST_CLLC_TTYPE_PARAM  Numbers of the two-module SST bench: battery -> CLLC-DCX 800 V/800 V -> T-type inverter.
%
%   bench = sst_cllc_ttype_param(p_dcx)
%
%   p_dcx is the parameter struct of the library DCX block (cllc_dcx_param_example(tc)): the operating point of
%   the isolated stage (udc_nom, idc_nom, n1, n2) is taken from it, so that the bench follows the library block.
%   Returns the bench part of "param" built by init_model.m:
%     .sst      modules (n_modules, pwr_module, pwr_nom)
%     .grid     single-phase line the two inverters are series-connected to (line_source of the model)
%     .cllc     operating point of the DCX stage, interleaving and mode of the two blocks
%     .spinv    single-phase three-level T-type inverter of one module: .hw_in (inputs of
%               hw_single_phase_inverter_setup), .ctrl_in (gains and reference of the control)
%     .battery  the two packs in parallel on the 800 V bus
%   Being in ./private it is seen only by the files of this folder. Values marked TBC are placeholders of the
%   first run, to be confirmed with the hardware.
%
%   Rev. 01, 2026-10-24.

    % ------------------------------------------------------------------ modules
    bench.sst.n_modules = 2;                                % two modules, DC sides in parallel, AC sides in series
    bench.sst.pwr_module = p_dcx.hw.udc_nom*p_dcx.hw.idc_nom;   % [W] 50 kW, the DCX of the library
    bench.sst.pwr_nom = bench.sst.n_modules*bench.sst.pwr_module;   % [W] 100 kW

    % ------------------------------------------------------------------ DCX stage (library block cllc_dcx/cllc_dcx_mod1)
    % The numbers of the stage (tank, transformer, DC links, devices, control) are in cllc_dcx_param_example.m of
    % the library: 800 V -> 800 V, 50 kW, 50 kHz, open-loop DCX. Here only what the bench decides.
    bench.cllc.udc1_nom = p_dcx.hw.udc_nom;                 % [V] 800 V, side 1 = battery bus
    bench.cllc.udc2_nom = p_dcx.hw.udc_nom*p_dcx.hw.n2/p_dcx.hw.n1;   % [V] 800 V, side 2 = DC link of the inverter
    bench.cllc.pwr_nom = bench.sst.pwr_module;              % [W]
    bench.cllc.mode = 0;                                    % p.ctrl.mode of both blocks: 0 open-loop DCX, 1 current loop, 2 voltage loop
    bench.cllc.interleave = 0;                              % 1: carrier of module 2 shifted by a quarter of the switching period, the
                                                            % 2 fs ripples of the two DCX in opposition on the battery bus; 0: both in
                                                            % phase, as in the model of 2026-10-24

    % ------------------------------------------------------------------ AC line (single phase)
    % The two inverters are in series: each carries the line current and produces 1/n_modules of the line
    % voltage. Per module one phase of a 690 V three-phase system, 398.4 V rms (563.4 V peak); 796.7 V rms in total.
    bench.grid.u_ll_ref = 690;                              % [V] reference three-phase system, line to line
    bench.grid.u_rms_module = bench.grid.u_ll_ref/sqrt(3);  % [V] 398.4 V rms, AC voltage of one module
    bench.grid.u_pk_module = bench.grid.u_rms_module*sqrt(2);   % [V] 563.4 V: amplitude per module of line_source (the two
                                                            % Controlled Voltage Sources get u_pk_module*n_modules/2 each) and
                                                            % base of the grid voltage measurement of the control (was grid_emu.u2bez)
    bench.grid.u_rms = bench.sst.n_modules*bench.grid.u_rms_module;   % [V] 796.7 V rms, line voltage
    bench.grid.f_nom = 50;                                  % [Hz]
    bench.grid.omega_nom = 2*pi*bench.grid.f_nom;           % [rad/s]
    bench.grid.i_nom = bench.sst.pwr_nom/bench.grid.u_rms;  % [A] 125.5 A rms, line current at nominal power
    % line impedance: two inductors in the model (Ld_grid_1, Ld_grid_2), each L_line + R_line. 5 % of the base
    % impedance of the series connection u_rms/i_nom = 6.35 Ohm: 1.0 mH in total, 0.5 mH per inductor
    bench.grid.ucc = 0.05;
    bench.grid.L_line = bench.grid.ucc*bench.grid.u_rms/bench.grid.i_nom/bench.grid.omega_nom/2;   % [H] 0.5 mH (TBC)
    bench.grid.R_line = 10e-3;                              % [Ohm] per inductor (TBC)

    % ------------------------------------------------------------------ single-phase three-level T-type inverter (one module)
    % Both modules read the same hardware and control data (param.spinv). Inputs of hw_single_phase_inverter_setup.
    h.pwr_nom = bench.sst.pwr_module;                       % [W]
    h.udc_nom = bench.cllc.udc2_nom;                        % [V] 800 V, DC link = side 2 of the DCX
    h.f_nom = bench.grid.f_nom;                             % [Hz]
    % normalization of the inverter voltage: 90 % of the DC link, the end of the linear modulation range (the
    % rule of single_phase_inverter_hwdata of the library, 0.9 x the rectified application voltage); the grid
    % voltage of the module is 0.78 pu of it
    h.ubez = 0.9*h.udc_nom;                                 % [V] 720 V peak
    h.us_nom = h.ubez/sqrt(2);                              % [V] 509 V rms (the class sets ubez = us_nom*sqrt(2))
    h.is_nom = bench.grid.i_nom;                            % [A] 125.5 A rms, the line current (ibez = 177.5 A peak)
    h.fpwm = 4e3;                                           % [Hz] carrier; control at 2 fpwm (double update)
    % DC link: split bank CFi1 + CFi2 in series (dclink_for_three_levels), CFi1 = CFi2 = 2 CFi, CFi the total.
    % Single phase: the 100 Hz pulsating power swings the stored energy by P/omega = 159 J per module, 66 V
    % peak-peak (8 %) with 3 mF at 800 V (TBC: the bank of the module)
    h.CFi = 3e-3;                                           % [F]
    h.RCFi = 1e-3;                                          % [Ohm] ESR of the bank (TBC)
    h.CFi1 = 2*h.CFi;   h.RCFi1 = h.RCFi/2;
    h.CFi2 = 2*h.CFi;   h.RCFi2 = h.RCFi/2;
    % output filter: LFu in two halves (LFu1, LFu2) in the model, CFu + RCFu across the output
    h.LFu = 500e-6;                                         % [H] about 25 A peak-peak of ripple (udc/2 steps at 2 fpwm), 14 % of the
                                                            % peak current (TBC)
    h.RLFu = 157*0.05*h.LFu;                                % [Ohm] 3.9 mOhm, library rule (TBC)
    h.LFu_cm = 500e-6;   h.RLFu_cm = 157*0.05*h.LFu_cm;     % common mode, not in this model
    h.CFu = 50e-6;                                          % [F] 1.0 kHz with LFu; 6.3 A (5 %) of capacitive current at 398 V (TBC)
    h.RCFu = 50e-3;                                         % [Ohm] damping of the filter capacitor (TBC)
    h.Rbrake = h.udc_nom^2/h.pwr_nom;                       % [Ohm] 12.8 Ohm, 50 kW at 800 V (not in this model)
    bench.spinv.hw_in = h;

    % control of the inverter: FHT/PLL on the grid voltage, virtual dq frame, dq vector PI on the current (module A
    % runs the loop, module B applies the same voltage command udq_ctrl_out_modA: the modules are in series and
    % carry the same current), resonant PI data kept for the library class
    c.kp_inv = 0.5;                                         % dq vector PI of the current loop (pu)
    c.ki_inv = 45;                                          % [1/s]
    c.u_lim = 1.0;                                          % [pu] limit of the control output (default of the class)
    c.kp_rpi = 0.75;                                        % resonant PI (not in the loop of this model)
    c.ki_rpi = 45;
    c.delta_rpi = 0.025;
    c.sogi_delta = 1;                                       % SOGI filter of the measurements (sogi_filter)
    c.kepsilon = 2;
    c.i_ref = 1;                                            % [pu of ibez] current reference of the line current after t_ref
    c.t_ref = 0.35;                                         % [s] step time of the reference
    c.i_ref_slew = 2;                                       % [pu/s] rate limiter: 1 pu reached 0.5 s after the step
    c.clip_release = 0.001;                                 % CTRPIFF_CLIP_RELEASE of the PI blocks (dq_vector_pi)
    bench.spinv.ctrl_in = c;

    % ------------------------------------------------------------------ batteries
    % two packs in parallel on the 800 V bus, one per module, each sized on the module power
    bench.battery.nominal_battery_voltage_1 = bench.cllc.udc1_nom;    % [V] 800 V
    bench.battery.nominal_battery_voltage_2 = bench.cllc.udc1_nom;    % [V] 800 V
    bench.battery.nominal_battery_power = bench.sst.pwr_module;       % [W] 50 kW per pack
    bench.battery.initial_battery_soc = 0.85;
    % charge capacity [Ah], third argument of lithium_ion_battery_setup. ASSUMPTION: 1C rating, capacity = rated current x 1 h
    bench.battery.charge_capacity_1 = bench.battery.nominal_battery_power/bench.battery.nominal_battery_voltage_1;   % [Ah] 62.5 Ah
    bench.battery.charge_capacity_2 = bench.battery.nominal_battery_power/bench.battery.nominal_battery_voltage_2;   % [Ah] 62.5 Ah
end
