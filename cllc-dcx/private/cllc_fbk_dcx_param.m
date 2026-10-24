function cllc = cllc_fbk_dcx_param(sink)
%CLLC_FBK_DCX_PARAM  Local numbers of the CLLC-DCX of PROP-2026-011-FBK-BIDCDC (base unit, isolated stage).
%
%   cllc = cllc_fbk_dcx_param()        load: power from side 1 (660 V) to side 2 (73.3 V)
%   cllc = cllc_fbk_dcx_param(sink)    power from side 2 to side 1: sink = 1 battery + current source
%                                      (run 07), sink = 2 mirror bench R1 + voltage source U2 (run 04)
%
%   Returns the CLLC part of "param" used by init_model.m: pwr_nom, fres, .pwm and .hw_in (the inputs of
%   hw_cllc_single_phase_setup), plus .tank, the resonant tank of the sizing. Being in ./private it is
%   seen only by the files of this folder.
%
%   Source: intro_report/PROP-2026-011-FBK-BIDCDC_rev1.tex, Sec. 4 "CLLC-DCX design: first sizing"
%   (2026-09-30). Fixed-ratio DCX 660 V -> 73.3 V (n = 9), 60 kW at the unit output, 61 kW at the DCX
%   input; the 1000 A of the unit are at the output of the interleaved buck downstream.
%   Values marked "TBC" are not fixed by the report: they are the values of the previous init, kept.
%
%   Created 2026-10-06. 2026-10-07: sink mode (sr1, the two sink benches, initial voltages).

    if nargin < 1
        sink = 0;
    end

    % ------------------------------------------------------------------ operating point and PWM
    cllc.pwr_nom = 61e3;                        % [W] at the DCX input (60 kW unit + buck losses)
    cllc.pwm.fpwm = 35e3;                       % [Hz] switching frequency
    cllc.pwm.trgo = 0;                          % single update (as before)
    cllc.pwm.dead_time = 300e-9;                % [s] report: td = 300 ns for the ZVS with Im = 12 A
    cllc.fres = 37e3;                           % [Hz] series resonance, fn = fs/fr = 0.95

    % ------------------------------------------------------------------ DC sides
    h.name = 'CLLC_DCX_660V_73V_FBK';
    h.n1 = 36;                                  % two cells 18:4, primaries in series ...
    h.n2 = 4;                                   % ... secondaries in parallel: n = 36/4 = 9
    h.udc1 = 660;                               % [V] common DC bus
    h.udc2 = h.udc1*h.n2/h.n1;                  % [V] 73.3 V, intermediate voltage u_i (buck input)
    h.uac1 = h.udc1;                            % [V] square-wave amplitude on the tank
    h.uac2 = h.udc2;
    h.idc2 = 1000;                              % [A] secondary DC current: normalization and end scale (Idc_FS)
    h.idc1 = h.idc2*h.n2/h.n1;                  % [A] 111 A, same scale seen from the primary

    % ------------------------------------------------------------------ transformer (two cells, seen as one)
    h.Lm = 390e-6;                              % [H] primary side (195 uH per cell), Im peak 12 A at 35 kHz
    h.Rfe = h.udc1^2/60;                        % [Ohm] 7.26 kOhm: 60 W core losses (30 W per cell)
    h.Rs1 = 6.2e-3;                             % [Ohm] 70 W at 106 A rms; Rs2 = Rs1/n^2 gives the other 70 W
    h.core_length = 1;                          % [m] TBC
    h.core_mur = 75;                            % TBC

    % ------------------------------------------------------------------ DC links
    h.Cdc_dc1 = 3.6e-3;                         % [F] TBC: input capacitor of the unit on the 660 V bus
    h.Cdc1_dc1 = 2*h.Cdc_dc1;
    h.Cdc2_dc1 = 2*h.Cdc_dc1;
    h.Cdc_dc2 = 2e-3;                           % [F] intermediate capacitor C_i, film bank of about 20 x 100 uF / 100 V:
                                                % the count comes from the ripple current (about 460 A rms at 70 kHz),
                                                % ripple about 1.5 V p-p. Runs 01-07 used 500 uF (6 V p-p)
    h.Cdc1_dc2 = 2*h.Cdc_dc2;
    h.Cdc2_dc2 = 2*h.Cdc_dc2;
    h.RCdc_dc1 = 1e-3;                          % [Ohm] TBC
    h.RCdc1_dc1 = h.RCdc_dc1/2;
    h.RCdc2_dc1 = h.RCdc_dc1/2;
    h.RCdc_dc2 = 0.15e-3;                       % [Ohm] TBC: about 3 mOhm per film capacitor / 20 (about 30 W at 460 A rms).
                                                % Runs 01-07 used 1 mOhm (210 W)
    h.RCdc1_dc2 = h.RCdc_dc2/2;
    h.RCdc2_dc2 = h.RCdc_dc2/2;

    % ------------------------------------------------------------------ DC input/output inductors
    h.Ldc_dc1 = 250e-6;                         % [H] TBC
    h.RLdc_dc1 = 157*0.05*h.Ldc_dc1;            % [Ohm] TBC
    h.Ldc_dc2 = 250e-6;                         % [H] TBC
    if sink == 2
        % mirror bench, stiff source on side 2: with 250 uH, LFi_dc2 resonates with Cdc_dc1 seen through the
        % DCX (n^2*3.6 mF = 292 mF) at 19 Hz, too slow for a 0.25 s run. LFi_dc1 seen from side 2 gives
        % 167 Hz, the same as LFi_dc1 with Cdc_dc1 in load.
        h.Ldc_dc2 = h.Ldc_dc1*(h.n2/h.n1)^2;    % [H] 3.1 uH
    end
    h.RLdc_dc2 = 157*0.05*h.Ldc_dc2;            % [Ohm] TBC
    cllc.hw_in = h;

    % ------------------------------------------------------------------ resonant tank (symmetrical CLLC)
    % hw_cllc_single_phase_setup derives the tank by itself with Q = 1 and the nominal power; the DCX tank
    % of the sizing is different (Q = 0.4, Ln = 39) and init_model.m writes these values over it.
    n12 = h.n1/h.n2;
    t.Lr1 = 10e-6;                              % [H] primary: leakage (3-5 uH per cell) + discrete inductor
    t.Cr1 = 1/((2*pi*cllc.fres)^2*t.Lr1);       % [F] 1.85 uF, film, peak 360 V at full load
    t.Lr2 = t.Lr1/n12^2;                        % [H] 123 nH, secondary leakage + busbar
    t.Cr2 = t.Cr1*n12^2;                        % [F] 150 uF, film, 950 A rms
    t.Z0 = sqrt(t.Lr1/t.Cr1);                   % [Ohm] 2.3 Ohm
    t.Rac = 8*n12^2*h.udc2^2/(pi^2*cllc.pwr_nom);   % [Ohm] FHA load seen from the primary, 5.7 Ohm
    t.Q = t.Z0/t.Rac;                           % 0.40
    t.Ln = h.Lm/t.Lr1;                          % 39
    cllc.tank = t;

    % ------------------------------------------------------------------ secondary bridge: synchronous rectifier
    % Used by the block sr_gate_logic in front of full-bridge 2 (added by add_sr_current_sync.m).
    % mode 0: full-bridge 2 driven by the phase-shift modulator (old behaviour)
    % mode 1: SR driven by the sign of i2 (i2_cllc_transformer_modA, > 0 into the uac(+) leg):
    %         i2 > 0 -> Q1 + Q4 on, i2 < 0 -> Q2 + Q3 on. The device turns on when |i2| > i_on and
    %         turns off when |i2| < i_off: between the two the body diodes conduct (this is the dead time).
    %         At full load di2/dt at the zero crossing is about 300 A/us: 50 A = 170 ns after the zero,
    %         20 A = 70 ns before it.
    % mode 2: all gates off, diode rectifier (reference case)
    cllc.sr.mode = 1;                           % load; in sink it is set to 0 at the end of this file
    cllc.sr.i_on = 0.05*h.idc2;                 % [A] 50 A, turn-on threshold on |i2|
    cllc.sr.i_off = 0.02*h.idc2;                % [A] 20 A, turn-off threshold on |i2| (must be < i_on)
    cllc.sr.v_on = 18;                          % [V] gate on, same as the modulator (pos_cmd_gate)
    cllc.sr.v_off = -3;                         % [V] gate off, same as the modulator (neg_cmd_gate)
    % SR devices: Infineon IPT025N15NM6 (150 V, TOLL, 2.5 mOhm typ at 25 degC, ~3.2 mOhm hot). The model has
    % one full bridge for the two transformer cells, so one model switch = the same switch of both cells:
    % 2 x 8 devices = 16 in parallel, 0.2 mOhm hot (the value of the sizing in the report).
    cllc.sr.n_par = 16;

    % ------------------------------------------------------------------ primary bridge: synchronous rectifier (sink)
    % Used by the block sr1_gate_logic in front of full-bridge 1 (added by add_sr1_current_sync.m), the
    % mirror of sr_gate_logic, on i1 (i1_cllc_transformer_modA, > 0 out of uac(+) of bridge 1 into the tank).
    % mode 0: full-bridge 1 driven by the modulator (load)
    % mode 1: SR driven by the sign of i1: i1 > 0 -> Q2 + Q3 on, i1 < 0 -> Q1 + Q4 on (opposite of bridge 2,
    %         because i1 is taken out of the bridge). Thresholds = secondary thresholds / n, same timing:
    %         at full load di1/dt at the zero crossing is about 33 A/us, 5.6 A = 170 ns after the zero,
    %         2.2 A = 70 ns before it.
    % mode 2: all gates off, rectifier with the body diodes of the SiC (reference case)
    cllc.sr1.mode = 0;
    cllc.sr1.i_on = cllc.sr.i_on/n12;           % [A] 5.6 A
    cllc.sr1.i_off = cllc.sr.i_off/n12;         % [A] 2.2 A
    cllc.sr1.v_on = cllc.sr.v_on;               % [V] 18 V
    cllc.sr1.v_off = cllc.sr.v_off;             % [V] -3 V

    % ------------------------------------------------------------------ power flow: load or sink
    % load (sink = 0): battery_1 feeds side 1, Controlled Current Source on side 2 (load), I2 > 0 drawn from the
    %   DCX with the same ramp (runs up to the first 06 used the resistor 0.088 Ohm of load/passive load).
    %   Bridge 1 driven by the modulator (sr1.mode 0), bridge 2 SR on i2 (sr.mode 1).
    % sink = 1 (run 07): power from side 2 to side 1. In the model battery_1 stays on side 1 (it is charged)
    %   and the resistor of load/passive load is replaced by a Controlled Current Source, + on load(+) as
    %   the resistor: a positive current is drawn from the DCX (load), a negative one is pushed into it.
    %   It is the buck of the unit working in sink, which pushes current into C_i. The source follows a
    %   ramp from 0 to I2 in t_ramp, so the inductor LFi_dc2 in series starts at 0 A without a jump.
    %   The bridges swap their roles: bridge 2 is driven by the modulator at 50 % duty (sr.mode 0; the
    %   phase shift of the modulator has no effect, because bridge 1 does not drive), bridge 1 rectifies
    %   (sr1.mode 1, or 2 for the diodes). With sr.mode 1 nothing drives the tank.
    % sink = 2 (run 04): mirror bench, same modes. DC voltage source U2 in place of the resistor of
    %   load/passive load, resistor R1 in place of the battery of battery_1, LFi_dc2 = 3.1 uH (see above).
    cllc.sink.on = sink;
    if sink
        cllc.sink.I2 = -790;                       % [A] sink: current pushed into C_i, same |i_out| as the load run
    else
        cllc.sink.I2 = 790;                        % [A] load: current drawn from C_i (about 791 A of the first run 06)
    end
    cllc.sink.t_ramp = 20e-3;                   % [s] ramp of the current source, 0 -> I2 (load and sink)
    cllc.sink.R_eq = 2.1e-3;                    % [Ohm] series resistance of the DCX seen from side 2 (runs 05, 06)
    cllc.sink.R1 = h.udc1^2/cllc.pwr_nom;       % [Ohm] sink = 2: 7.14 Ohm, side 1 load, 61 kW at 660 V
    cllc.sink.U2 = h.udc2*(1 + n12^2*cllc.sink.R_eq/cllc.sink.R1);   % [V] sink = 2: 75.1 V, u1 = 660 V on R1
    cllc.sink.U1 = h.udc1;                      % [V] sink = 1, option: 660 V DC source (the AFE) in place of battery_1
    % initial voltages of CFi_dc1 and CFi_dc2 (Initial Targets of the two capacitors, priority High): the
    % run starts near the steady state, without the inrush of the empty DC links
    cllc.ic.vc_dc1 = h.udc1;                    % [V] 660 V (battery_1 about 656 V in run 06)
    cllc.ic.vc_dc2 = h.udc2;                    % [V] 73.3 V
    if sink
        cllc.sr.mode = 0;
        cllc.sr1.mode = 1;
    end
    if sink == 2
        cllc.ic.vc_dc2 = cllc.sink.U2;          % [V] 75.1 V
    end
end
