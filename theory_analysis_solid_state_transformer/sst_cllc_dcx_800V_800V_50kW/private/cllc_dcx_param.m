function cllc = cllc_dcx_param(sink)
%CLLC_DCX_PARAM  Numbers of the SST CLLC-DCX stage: 800 V -> 800 V, 50 kW, n = 1.
%
%   cllc = cllc_dcx_param()        load: power from side 1 to side 2
%   cllc = cllc_dcx_param(sink)    power from side 2 to side 1: sink = 1 battery + current source,
%                                  sink = 2 mirror bench, resistor R1 on side 1 + voltage source U2 on side 2
%
%   Returns the CLLC part of "param" used by init_model.m: pwr_nom, fres, .pwm and .hw_in (the inputs of
%   hw_cllc_single_phase_setup), .tank (the resonant tank of the sizing, written over the Q = 1 tank that
%   the class derives), .sr and .sr1 (synchronous rectifier logic of the two bridges), .sink and .ic (the
%   bench). Being in ./private it is seen only by the files of this folder.
%
%   The sizing is in ../cllc_dcx_sizing.md: fixed-ratio DC transformer (DCX) between the 800 V DC link of
%   the SST module and the 800 V isolated DC link, 50 kW, both directions, 1200 V SiC MOSFETs on both
%   bridges. Values marked "TBC" are placeholders of the first run, to be confirmed with the hardware.
%
%   Rev. 01, 2026-10-24.

    if nargin < 1
        sink = 0;
    end

    % ------------------------------------------------------------------ operating point and PWM
    cllc.pwr_nom = 50e3;                        % [W] nominal power at the DCX input
    cllc.pwm.fpwm = 50e3;                       % [Hz] switching frequency
    cllc.pwm.trgo = 0;                          % single update (control trigger once per period)
    cllc.pwm.dead_time = 300e-9;                % [s] primary bridge, ZVS with Im = 10 A (see init_model.m)
    cllc.fres = cllc.pwm.fpwm/0.95;             % [Hz] series resonance 52.6 kHz, fn = fs/fr = 0.95: the resonant
                                                % half sine ends before the commutation, the SR turn off at zero
                                                % current and the primary switches the magnetizing current only

    % ------------------------------------------------------------------ DC sides
    h.name = 'SST_CLLC_DCX_800V_800V_50kW';
    h.n1 = 11;                                  % turns, 1:1 transformer (transformer_sizing.m: three stacked
    h.n2 = 11;                                  % UU93/152/30 ferrite sets, 11 turns in one layer, Bpk 0.14 T)
    h.udc1 = 800;                               % [V] DC link of the SST module (inverter side)
    h.udc2 = h.udc1*h.n2/h.n1;                  % [V] 800 V, isolated DC link
    h.uac1 = h.udc1;                            % [V] square-wave amplitude on the tank
    h.uac2 = h.udc2;
    h.idc1 = cllc.pwr_nom/h.udc1;               % [A] 62.5 A, normalization and end scale (Idc_FS)
    h.idc2 = h.idc1*h.n1/h.n2;                  % [A] 62.5 A

    % ------------------------------------------------------------------ transformer
    h.Lm = 400e-6;                              % [H] primary side: Im peak = udc1/(4 Lm fs) = 10 A at 50 kHz,
                                                % ZVS of the primary leg (2 x Coss = 1.6 nF) in 126 ns < dead time
    h.Rfe = h.udc1^2/60;                        % [Ohm] 10.7 kOhm: 60 W core losses at 800 V square wave (transformer_sizing.m)
    h.Rs1 = 6e-3;                               % [Ohm] 31 W at 71.5 A rms: winding (about 4.7 mOhm AC with litz wire,
                                                % transformer_sizing.m), terminations and the discrete part of Lr1;
                                                % Rs2 = Rs1/n^2 gives the other 31 W on side 2
    h.core_length = 1;                          % [m] TBC
    h.core_mur = 75;                            % TBC

    % ------------------------------------------------------------------ DC links
    % Both DC links are film banks. The DCX ripple current is sqrt(I1rms^2 - Idc^2) = 34 A rms at 2 fs = 100 kHz,
    % 132 uC per half period: 0.26 V p-p with 500 uF. In the SST module the 800 V link of side 1 is shared with
    % the single-phase inverter and is sized on its 100 Hz ripple (mF range): 500 uF is the bench value.
    h.Cdc_dc1 = 500e-6;                         % [F] TBC
    h.Cdc1_dc1 = 2*h.Cdc_dc1;
    h.Cdc2_dc1 = 2*h.Cdc_dc1;
    h.Cdc_dc2 = 500e-6;                         % [F] TBC, isolated DC link
    h.Cdc1_dc2 = 2*h.Cdc_dc2;
    h.Cdc2_dc2 = 2*h.Cdc_dc2;
    h.RCdc_dc1 = 1e-3;                          % [Ohm] TBC, ESR of the bank (about 1 W at 34 A rms)
    h.RCdc1_dc1 = h.RCdc_dc1/2;
    h.RCdc2_dc1 = h.RCdc_dc1/2;
    h.RCdc_dc2 = 1e-3;                          % [Ohm] TBC
    h.RCdc1_dc2 = h.RCdc_dc2/2;
    h.RCdc2_dc2 = h.RCdc_dc2/2;

    % ------------------------------------------------------------------ DC input/output inductors
    h.Ldc_dc1 = 250e-6;                         % [H] TBC, 450 Hz with 500 uF
    h.RLdc_dc1 = 157*0.05*h.Ldc_dc1;            % [Ohm] TBC, 2 mOhm (8 W at 62.5 A)
    h.Ldc_dc2 = 250e-6;                         % [H] TBC
    if sink == 2
        % mirror bench, stiff source on side 2: the DC inductor of side 2 resonates with Cdc_dc1 seen through
        % the DCX (n^2 Cdc_dc1); with n = 1 the value is the same, the line is kept for other ratios
        h.Ldc_dc2 = h.Ldc_dc1*(h.n2/h.n1)^2;    % [H]
    end
    h.RLdc_dc2 = 157*0.05*h.Ldc_dc2;            % [Ohm] TBC
    cllc.hw_in = h;

    % ------------------------------------------------------------------ resonant tank (symmetrical CLLC)
    % hw_cllc_single_phase_setup derives the tank by itself with Q = 1 and the nominal power; the DCX tank
    % of the sizing is different (Q = 0.38, Ln = 33) and init_model.m writes these values over it.
    % Rac = 8 n^2 udc2^2/(pi^2 P) = 10.4 Ohm, Z0 = sqrt(Lr1/Cr1) = 4.0 Ohm, Q = Z0/Rac.
    n12 = h.n1/h.n2;
    t.Lr1 = 12e-6;                              % [H] primary: transformer leakage (3-5 uH) + discrete inductor
    t.Cr1 = 1/((2*pi*cllc.fres)^2*t.Lr1);       % [F] 0.76 uF, film, 410 V peak and 71 A rms at full load
    t.Lr2 = t.Lr1/n12^2;                        % [H] 12 uH, secondary leakage + discrete inductor
    t.Cr2 = t.Cr1*n12^2;                        % [F] 0.76 uF
    t.Z0 = sqrt(t.Lr1/t.Cr1);                   % [Ohm] 4.0 Ohm
    t.Rac = 8*n12^2*h.udc2^2/(pi^2*cllc.pwr_nom);   % [Ohm] FHA load seen from the primary, 10.4 Ohm
    t.Q = t.Z0/t.Rac;                           % 0.38
    t.Ln = h.Lm/t.Lr1;                          % 33
    cllc.tank = t;

    % ------------------------------------------------------------------ secondary bridge: synchronous rectifier
    % Used by the block sr_gate_logic in front of full-bridge 2.
    % mode 0: full-bridge 2 driven by the phase-shift modulator (both bridges by the PWM)
    % mode 1: SR driven by the sign of i2 (i2_cllc_transformer_modA, > 0 into the uac(+) leg):
    %         i2 > 0 -> Q1 + Q4 on, i2 < 0 -> Q2 + Q3 on. The device turns on when |i2| > i_on and
    %         turns off when |i2| < i_off: between the two the body diodes conduct (this is the dead time).
    %         At full load di2/dt at the zero crossing is about 34 A/us: 5 A = 146 ns after the zero
    %         (3 steps of 50 ns), 1.9 A = 55 ns before it.
    % mode 2: all gates off, diode rectifier (reference case)
    cllc.sr.mode = 1;                           % load; in sink it is set to 0 at the end of this file
    cllc.sr.i_on = 0.08*h.idc2;                 % [A] 5 A, turn-on threshold on |i2|
    cllc.sr.i_off = 0.03*h.idc2;                % [A] 1.9 A, turn-off threshold on |i2| (must be < i_on)
    cllc.sr.v_on = 18;                          % [V] gate on, same as the modulator (pos_cmd_gate)
    cllc.sr.v_off = -3;                         % [V] gate off, same as the modulator (neg_cmd_gate)
    % SR devices: the same 1200 V SiC half-bridge module of the primary (800 V on both sides), one device per
    % switch. With n_par > 1 init_model.m builds the equivalent switch with device_mosfet_parallel.
    cllc.sr.n_par = 1;

    % ------------------------------------------------------------------ primary bridge: synchronous rectifier (sink)
    % Used by the block sr1_gate_logic in front of full-bridge 1, the mirror of sr_gate_logic, on i1
    % (i1_cllc_transformer_modA, > 0 out of uac(+) of bridge 1 into the tank).
    % mode 0: full-bridge 1 driven by the modulator (load)
    % mode 1: SR driven by the sign of i1: i1 > 0 -> Q2 + Q3 on, i1 < 0 -> Q1 + Q4 on (opposite of bridge 2,
    %         because i1 is taken out of the bridge). Thresholds = secondary thresholds / n, same timing.
    % mode 2: all gates off, rectifier with the body diodes of the SiC (reference case)
    cllc.sr1.mode = 0;
    cllc.sr1.i_on = cllc.sr.i_on/n12;           % [A] 5 A
    cllc.sr1.i_off = cllc.sr.i_off/n12;         % [A] 1.9 A
    cllc.sr1.v_on = cllc.sr.v_on;               % [V] 18 V
    cllc.sr1.v_off = cllc.sr.v_off;             % [V] -3 V

    % ------------------------------------------------------------------ power flow: load or sink
    % load (sink = 0): battery_1 feeds side 1, Controlled Current Source on side 2 (load), I2 > 0 drawn from the
    %   DCX with a ramp. Bridge 1 driven by the modulator (sr1.mode 0), bridge 2 SR on i2 (sr.mode 1).
    % sink = 1: power from side 2 to side 1. In the model battery_1 stays on side 1 (it is charged) and the
    %   Controlled Current Source of side 2, + on load(+), pushes a negative current into the DCX: it is the
    %   downstream stage working in sink. The source follows a ramp from 0 to I2 in t_ramp, so the inductor
    %   LFi_dc2 in series starts at 0 A without a jump. The bridges swap their roles: bridge 2 is driven by
    %   the modulator at 50 % duty (sr.mode 0; the phase shift of the modulator has no effect, because bridge 1
    %   does not drive), bridge 1 rectifies (sr1.mode 1, or 2 for the diodes). With sr.mode 1 nothing drives
    %   the tank.
    % sink = 2: mirror bench, same modes. DC voltage source U2 in place of the current source of load, resistor
    %   R1 in place of the battery of battery_1 (the blocks are swapped by hand in the model, see README.md).
    cllc.sink.on = sink;
    if sink
        cllc.sink.I2 = -h.idc2;                 % [A] sink: current pushed into DC link 2, same |i_out| as the load run
    else
        cllc.sink.I2 = h.idc2;                  % [A] load: current drawn from DC link 2, 62.5 A at 50 kW
    end
    cllc.sink.t_ramp = 20e-3;                   % [s] ramp of the current source, 0 -> I2 (load and sink)
    cllc.sink.R_eq = 0.17;                      % [Ohm] series resistance of the DCX seen from side 2: estimate of the
                                                % sizing, 43 mOhm physical (4 Rds_on + Rs1 + Rs2 + 2 RLdc) + 125 mOhm
                                                % of Backward Euler damping at tc = 50 ns. Update with the load run.
    cllc.sink.R1 = h.udc1^2/cllc.pwr_nom;       % [Ohm] sink = 2: 12.8 Ohm, side 1 load, 50 kW at 800 V
    cllc.sink.U2 = h.udc2*(1 + n12^2*cllc.sink.R_eq/cllc.sink.R1);   % [V] sink = 2: 811 V, u1 = 800 V on R1
    cllc.sink.U1 = h.udc1;                      % [V] sink = 1, option: 800 V DC source (the AFE) in place of battery_1
    % initial voltages of CFi_dc1 and CFi_dc2 (Initial Targets of the two capacitors, priority High): the
    % run starts near the steady state, without the inrush of the empty DC links
    cllc.ic.vc_dc1 = h.udc1;                    % [V] 800 V
    cllc.ic.vc_dc2 = h.udc2;                    % [V] 800 V
    if sink
        cllc.sr.mode = 0;
        cllc.sr1.mode = 1;
    end
    if sink == 2
        cllc.ic.vc_dc2 = cllc.sink.U2;          % [V] 811 V
    end
end
