function cllc = cllc_dcx_param(sink)
%CLLC_DCX_PARAM  Numbers of the SST CLLC-DCX stage: 790 V -> 700 V, 50 kW, 35 kHz, 9:8 transformer.
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
%   The sizing is in ../cllc_dcx_sizing.md: fixed-ratio DC transformer (DCX) between a 790 V DC link and an
%   isolated 700 V DC link, 50 kW, both directions, 1200 V SiC MOSFETs on both bridges.
%   Values marked "TBC" are placeholders of the first run, to be confirmed with the hardware.
%
%   2026-10-24: 35 kHz variant of the 800 V -> 800 V, 50 kHz, 1:1 bench (../sst_cllc_dcx_800V_800V_50kW):
%   790 V -> 700 V, 9:8 transformer on five
%   stacked UU93/152/30 sets, Lm = 560 uH, Lr1 = 16 uH, Cr1 = 1.17 uF.

    if nargin < 1
        sink = 0;
    end

    % ------------------------------------------------------------------ operating point and PWM
    cllc.pwr_nom = 50e3;                        % [W] nominal power at the DCX input
    cllc.pwm.fpwm = 35e3;                       % [Hz] switching frequency
    cllc.pwm.trgo = 0;                          % single update (control trigger once per period)
    cllc.pwm.dead_time = 300e-9;                % [s] driving bridge, ZVS with Im = 10 A in 124 ns (see init_model.m)
    cllc.fres = cllc.pwm.fpwm/0.95;             % [Hz] series resonance 36.8 kHz, fn = fs/fr = 0.95: the resonant
                                                % half sine ends before the commutation, the SR turn off at zero
                                                % current and the driving bridge switches the magnetizing current only

    % ------------------------------------------------------------------ DC sides
    h.name = 'SST_CLLC_DCX_790V_700V_50kW';
    h.n1 = 9;                                   % turns: 9:8 = 0.889 gives 702 V at no load from 790 V, 700 V with the
    h.n2 = 8;                                   % drop at 50 kW; one layer of litz per winding on five stacked
                                                % UU93/152/30 ferrite sets, Bpk 0.15 T (transformer_sizing.m)
    h.udc1 = 790;                               % [V] side 1, design point of the 35 kHz variant
    h.udc2 = 700;                               % [V] isolated DC link, nominal (udc1*n2/n1 = 702 V at no load)
    h.uac1 = h.udc1;                            % [V] square-wave amplitude on the tank
    h.uac2 = h.udc2;
    h.idc1 = cllc.pwr_nom/h.udc1;               % [A] 63.3 A, normalization and end scale (Idc_FS)
    h.idc2 = cllc.pwr_nom/h.udc2;               % [A] 71.4 A

    % ------------------------------------------------------------------ transformer
    h.Lm = 560e-6;                              % [H] primary side: Im peak = udc1/(4 Lm fs) = 10 A at 35 kHz,
                                                % ZVS of the primary leg (2 x Coss = 1.6 nF) in 124 ns < dead time
    h.Rfe = h.udc1^2/66;                        % [Ohm] 9.5 kOhm: 66 W core losses at 790 V square wave (transformer_sizing.m)
    h.Rs1 = 7e-3;                               % [Ohm] 37 W at 72 A rms: winding (about 5.4 mOhm AC with litz wire,
                                                % transformer_sizing.m), terminations and the discrete part of Lr1;
                                                % Rs2 = Rs1/n^2 = 5.5 mOhm gives 36 W on side 2 (81 A rms)
    h.core_length = 1;                          % [m] TBC
    h.core_mur = 75;                            % TBC

    % ------------------------------------------------------------------ DC links
    % Both DC links are film banks. The DCX ripple current is sqrt(Irms^2 - Idc^2) = 35 A rms on side 1 and 39 A rms
    % on side 2 at 2 fs = 70 kHz, 190 / 214 uC per half period: 0.38 / 0.43 V p-p with 500 uF. In the SST module the
    % 790 V link of side 1 is shared with the single-phase inverter and is sized on its 100 Hz ripple (mF range):
    % 500 uF is the bench value.
    h.Cdc_dc1 = 500e-6;                         % [F] TBC
    h.Cdc1_dc1 = 2*h.Cdc_dc1;
    h.Cdc2_dc1 = 2*h.Cdc_dc1;
    h.Cdc_dc2 = 500e-6;                         % [F] TBC, isolated DC link
    h.Cdc1_dc2 = 2*h.Cdc_dc2;
    h.Cdc2_dc2 = 2*h.Cdc_dc2;
    h.RCdc_dc1 = 1e-3;                          % [Ohm] TBC, ESR of the bank (about 1.2 W at 35 A rms)
    h.RCdc1_dc1 = h.RCdc_dc1/2;
    h.RCdc2_dc1 = h.RCdc_dc1/2;
    h.RCdc_dc2 = 1e-3;                          % [Ohm] TBC (about 1.5 W at 39 A rms)
    h.RCdc1_dc2 = h.RCdc_dc2/2;
    h.RCdc2_dc2 = h.RCdc_dc2/2;

    % ------------------------------------------------------------------ DC input/output inductors
    h.Ldc_dc1 = 250e-6;                         % [H] TBC, 450 Hz with 500 uF
    h.RLdc_dc1 = 157*0.05*h.Ldc_dc1;            % [Ohm] TBC, 2 mOhm (8 W at 63 A)
    h.Ldc_dc2 = 250e-6;                         % [H] TBC (10 W at 71 A with 2 mOhm)
    if sink == 2
        % mirror bench, stiff source on side 2: the DC inductor of side 2 resonates with Cdc_dc1 seen through
        % the DCX (n^2 Cdc_dc1); Ldc_dc1 (n2/n1)^2 = 198 uH keeps the resonance of the load bench
        h.Ldc_dc2 = h.Ldc_dc1*(h.n2/h.n1)^2;    % [H]
    end
    h.RLdc_dc2 = 157*0.05*h.Ldc_dc2;            % [Ohm] TBC
    cllc.hw_in = h;

    % ------------------------------------------------------------------ resonant tank (symmetrical CLLC)
    % hw_cllc_single_phase_setup derives the tank by itself with Q = 1 and the nominal power; the DCX tank
    % of the sizing is different (Q = 0.37, Ln = 35) and init_model.m writes these values over it.
    % Rac = 8 n^2 udc2^2/(pi^2 P) = 10.0 Ohm (n = n1/n2), Z0 = sqrt(Lr1/Cr1) = 3.7 Ohm, Q = Z0/Rac.
    n12 = h.n1/h.n2;
    t.Lr1 = 16e-6;                              % [H] primary: transformer leakage (about 2 uH per side) + discrete inductor
    t.Cr1 = 1/((2*pi*cllc.fres)^2*t.Lr1);       % [F] 1.17 uF, film, 390 V peak and 72 A rms at full load
    t.Lr2 = t.Lr1/n12^2;                        % [H] 12.6 uH, secondary leakage + discrete inductor
    t.Cr2 = t.Cr1*n12^2;                        % [F] 1.48 uF, 345 V peak and 81 A rms
    t.Z0 = sqrt(t.Lr1/t.Cr1);                   % [Ohm] 3.7 Ohm
    t.Rac = 8*n12^2*h.udc2^2/(pi^2*cllc.pwr_nom);   % [Ohm] FHA load seen from the primary, 10.0 Ohm
    t.Q = t.Z0/t.Rac;                           % 0.37
    t.Ln = h.Lm/t.Lr1;                          % 35
    cllc.tank = t;

    % ------------------------------------------------------------------ secondary bridge: synchronous rectifier
    % Used by the block sr_gate_logic in front of full-bridge 2.
    % mode 0: full-bridge 2 driven by the phase-shift modulator (both bridges by the PWM)
    % mode 1: SR driven by the sign of i2 (i2_cllc_transformer_modA, > 0 into the uac(+) leg):
    %         i2 > 0 -> Q1 + Q4 on, i2 < 0 -> Q2 + Q3 on. The device turns on when |i2| > i_on and
    %         turns off when |i2| < i_off: between the two the body diodes conduct (this is the dead time).
    %         At full load di2/dt at the zero crossing is about 27 A/us: 5.7 A = 210 ns after the zero
    %         (4 steps of 50 ns), 2.1 A = 79 ns before it.
    % mode 2: all gates off, diode rectifier (reference case)
    cllc.sr.mode = 1;                           % load; in sink it is set to 0 at the end of this file
    cllc.sr.i_on = 0.08*h.idc2;                 % [A] 5.7 A, turn-on threshold on |i2|
    cllc.sr.i_off = 0.03*h.idc2;                % [A] 2.1 A, turn-off threshold on |i2| (must be < i_on)
    cllc.sr.v_on = 18;                          % [V] gate on, same as the modulator (pos_cmd_gate)
    cllc.sr.v_off = -3;                         % [V] gate off, same as the modulator (neg_cmd_gate)
    % SR devices: the same 1200 V SiC half-bridge module of the primary (790 V and 700 V), one device per
    % switch. With n_par > 1 init_model.m builds the equivalent switch with device_mosfet_parallel.
    cllc.sr.n_par = 1;

    % ------------------------------------------------------------------ primary bridge: synchronous rectifier (sink)
    % Used by the block sr1_gate_logic in front of full-bridge 1, the mirror of sr_gate_logic, on i1
    % (i1_cllc_transformer_modA, > 0 out of uac(+) of bridge 1 into the tank).
    % mode 0: full-bridge 1 driven by the modulator (load)
    % mode 1: SR driven by the sign of i1: i1 > 0 -> Q2 + Q3 on, i1 < 0 -> Q1 + Q4 on (opposite of bridge 2,
    %         because i1 is taken out of the bridge). Thresholds = secondary thresholds / n (5.1 A and 1.9 A),
    %         same timing (24 A/us at the zero crossing).
    % mode 2: all gates off, rectifier with the body diodes of the SiC (reference case)
    cllc.sr1.mode = 0;
    cllc.sr1.i_on = cllc.sr.i_on/n12;           % [A] 5.1 A
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
        cllc.sink.I2 = h.idc2;                  % [A] load: current drawn from DC link 2, 71.4 A at 50 kW
    end
    cllc.sink.t_ramp = 20e-3;                   % [s] ramp of the current source, 0 -> I2 (load and sink)
    cllc.sink.R_eq = 0.10;                      % [Ohm] series resistance of the DCX seen from side 2: estimate of the
                                                % sizing, 38 mOhm physical (2 Rds_on + Rs2 + RLdc2, plus 2 Rds_on + Rs1 +
                                                % RLdc1 over n^2) + 64 mOhm of Backward Euler damping at tc = 50 ns.
                                                % Update with the load run.
    cllc.sink.R1 = h.udc1^2/cllc.pwr_nom;       % [Ohm] sink = 2: 12.5 Ohm, side 1 load, 50 kW at 790 V
    cllc.sink.U2 = h.udc2*(1 + n12^2*cllc.sink.R_eq/cllc.sink.R1);   % [V] sink = 2: 707 V, u1 = 790 V on R1
    cllc.sink.U1 = h.udc1;                      % [V] sink = 1, option: 790 V DC source (the AFE) in place of battery_1
    % initial voltages of CFi_dc1 and CFi_dc2 (Initial Targets of the two capacitors, priority High): the
    % run starts near the steady state, without the inrush of the empty DC links
    cllc.ic.vc_dc1 = h.udc1;                    % [V] 790 V
    cllc.ic.vc_dc2 = h.udc2;                    % [V] 700 V
    if sink
        cllc.sr.mode = 0;
        cllc.sr1.mode = 1;
    end
    if sink == 2
        cllc.ic.vc_dc2 = cllc.sink.U2;          % [V] 707 V
    end
end
