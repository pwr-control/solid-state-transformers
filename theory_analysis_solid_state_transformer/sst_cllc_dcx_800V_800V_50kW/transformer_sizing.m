%[text] # transformer_sizing: first sizing of the 1:1 transformer of the CLLC-DCX 800 V -> 800 V, 50 kW
% Rev. 01, 2026-10-24. Same method as ../magnetics_sizing/single_phaseDAB_TRsizing.m (Faraday's law with
% fixed turns, current density, copper loss, specific core loss, leakage estimate), with the numbers of the
% DCX (cllc_dcx_sizing.md): 800 V square wave on both windings, 50 kHz, 71.5 A rms (resonant half sines of
% 103 A peak plus the magnetizing triangle of 10 A peak). The core is a stack of three standard UU93/152/30
% ferrite sets (N87 class), the windings are litz wire in one layer each (two stacked sets would need two
% layers per winding, which do not fit the 37 mm window). The result gives the model numbers of
% private/cllc_dcx_param.m: n1 = n2, Lm (air gap), Rs1 = Rs2, Rfe, and the leakage that is part of Lr1 + Lr2.

clc
mu0 = 4*pi*1e-7;
rho_cu = 1.72e-8*(1 + 0.0039*(100 - 20));          % [Ohm m] copper at 100 degC

%% 1. Electrical inputs (from the DCX sizing)
udc = 800;                  % [V] DC link voltage, both sides (square wave of +/- udc on the windings)
P = 50e3;                   % [W]
fs = 50e3;                  % [Hz] switching frequency
fn = 0.95;                  % fs/fr
Lm = 400e-6;                % [H] magnetizing inductance of the ZVS sizing (Im peak = udc/(4 Lm fs) = 10 A)
Lr_tot = 2*12e-6;           % [H] series inductance of the whole tank (Lr1 + Lr2, n = 1)
idc = P/udc;                % [A] 62.5 A
i_pk = pi/2*idc/fn;         % [A] 103 A, resonant half sine of period 1/fr carrying idc per half period
i_res = i_pk*sqrt(fn/2);    % [A] 71.2 A rms
im_pk = udc/(4*Lm*fs);      % [A] 10 A
i_rms = sqrt(i_res^2 + im_pk^2/3);      % [A] 71.5 A rms, both windings (n = 1)
fprintf('--- ELECTRICAL INPUTS ---\n');
fprintf('Voltage %.0f V square wave, %.0f kHz, %.1f A rms per winding (%.0f A peak), Lm = %.0f uH\n', ...
    udc, fs/1e3, i_rms, i_pk + im_pk, Lm*1e6);

%% 2. Core: stack of UU93/152/30 sets (2 x U93/76/30, ferrite N87 class)
n_stack = 3;                % sets stacked in depth
Ae_set = 840e-6;            % [m^2] core area of one set
le = 354e-3;                % [m] mean magnetic path length
Ve_set = 297e-6;            % [m^3] core volume of one set
m_set = 1.5;                % [kg] mass of one set (two U93)
leg_w = 28e-3;              % [m] leg width
leg_d = 30e-3;              % [m] leg depth of one set
win_w = 37e-3;              % [m] window width (space for both windings and the insulation)
win_h = 96e-3;              % [m] window height (UU: two legs of 48 mm)
Bmax = 0.15;                % [T] peak flux density (ferrite at 50 kHz: core loss, not saturation, sets it)
Ae = n_stack*Ae_set;
n1 = ceil(udc/(4*fs*Bmax*Ae));          % Faraday, square wave: udc = 4 n1 Ae Bpk fs
n2 = n1;                                % 1:1
Bpk = udc/(4*fs*n1*Ae);                 % [T] with the integer number of turns
B_first_pulse = 2*Bpk;                  % [T] first half period from zero flux (no soft start): check against Bsat
fprintf('\n--- CORE: %d x UU93/152/30, Ae = %.1f cm^2 ---\n', n_stack, Ae*1e4);
fprintf('Turns n1 = n2 = %d, Bpk = %.3f T (first pulse from zero flux %.2f T, Bsat about 0.39 T at 100 degC)\n', ...
    n1, Bpk, B_first_pulse);

% magnetizing inductance and air gap: Lm = n1^2 AL, AL = mu0 Ae/(gap + le/mur)
mur = 2200;
gap_tot = mu0*Ae*n1^2/Lm - le/mur;      % [m] total air gap in the magnetic path (two legs)
fprintf('Air gap for Lm = %.0f uH: %.2f mm in total, %.2f mm per leg (ungapped Lm would be %.1f mH)\n', ...
    Lm*1e6, gap_tot*1e3, gap_tot/2*1e3, mu0*mur*Ae*n1^2/le*1e3);

% core losses: Steinmetz law anchored to one datasheet point of the material at 100 degC
% ASSUMPTION: Pv0 = 49.5 kW/m^3 at 35 kHz and 0.156 T (N87 class), alpha = 1.5, beta = 2.5 in the 20-100 kHz range
Pv0 = 49.5e3; f0 = 35e3; B0 = 0.156; alpha = 1.5; beta = 2.5;
Pv = Pv0*(fs/f0)^alpha*(Bpk/B0)^beta;   % [W/m^3]
P_fe = Pv*n_stack*Ve_set;               % [W]
Rfe = udc^2/P_fe;                       % [Ohm] parallel resistance of the model (square wave of +/- udc)
fprintf('Core losses: Pv = %.0f kW/m^3, P_fe = %.0f W (%.1f kg of ferrite), Rfe = %.1f kOhm\n', ...
    Pv/1e3, P_fe, n_stack*m_set, Rfe/1e3);

%% 3. Windings: litz wire, 0.1 mm strands (skin depth at 50 kHz about 0.3 mm)
J = 3.0;                                % [A/mm^2]
A_cu = i_rms/J;                         % [mm^2] copper per winding
d_strand = 0.1e-3;                      % [m]
k_litz = 0.45;                          % copper fraction of the litz bundle (strand insulation, serving, bundling)
d_litz = sqrt(4*A_cu*1e-6/k_litz/pi);   % [m] outer diameter of the bundle
turns_per_layer = floor(0.95*win_h/d_litz);
n_layers = ceil(n1/turns_per_layer);    % per winding
h_wind = n_layers*d_litz;               % [m] radial build of one winding
h_ins = 3e-3;                           % [m] insulation + shield between primary and secondary (800 V DC isolation)
h_bob = 2e-3;                           % [m] bobbin / wall insulation
build = h_bob + 2*h_wind + h_ins;       % [m] radial build of both windings, no interleaving (P-S)
MLT = 2*(leg_w + n_stack*leg_d) + pi*build;         % [m] mean length per turn around the stacked leg
R_dc = rho_cu*n1*MLT/(A_cu*1e-6);       % [Ohm] per winding
Fr = 1.5;                               % AC resistance factor (litz, proximity of 2 layers, ASSUMPTION)
R_ac = Fr*R_dc;
P_cu = 2*R_ac*i_rms^2;                  % [W] both windings
fprintf('\n--- WINDINGS: litz %.0f x %.1f mm (%.1f mm^2 Cu, %.1f mm OD) ---\n', A_cu*1e-6/(pi*d_strand^2/4), d_strand*1e3, A_cu, d_litz*1e3);
fprintf('%d turns in %d layers of %d, radial build %.1f mm of the %.0f mm window (fill %.0f %%)\n', ...
    n1, n_layers, turns_per_layer, build*1e3, win_w*1e3, 100*build/win_w);
fprintf('MLT = %.0f mm, R_dc = %.2f mOhm, R_ac = %.2f mOhm per winding (Fr = %.1f), P_cu = %.0f W\n', ...
    MLT*1e3, R_dc*1e3, R_ac*1e3, Fr, P_cu);
fprintf('Model: Rs1 = Rs2 = R_ac plus terminations and the discrete part of the resonant inductor\n');

%% 4. Leakage inductance (concentric windings P-S, no interleaving) and resonant inductor
L_sigma = mu0*n1^2*MLT/h_wind_eff(win_h, n_layers, turns_per_layer, d_litz)*(h_ins + 2*h_wind/3);   % [H] total, both windings
L_discrete = Lr_tot - L_sigma;          % [H] to add as discrete inductors (half per side for the symmetrical tank)
fprintf('\n--- LEAKAGE ---\n');
fprintf('L_sigma = %.1f uH (total, measured from one side with the other shorted)\n', L_sigma*1e6);
if L_discrete > 0
    fprintf('Tank needs Lr1 + Lr2 = %.0f uH: %.1f uH discrete, %.1f uH per side\n', Lr_tot*1e6, L_discrete*1e6, L_discrete/2*1e6);
else
    fprintf('L_sigma exceeds Lr1 + Lr2 = %.0f uH: interleave the windings (S-P-S) to reduce it\n', Lr_tot*1e6);
end
fprintf('Split of the model: Ld1 = Ld2 = Lr1 = %.0f uH (leakage + discrete), Cr1 = Cr2 on the two sides\n', Lr_tot/2*1e6);

%% 5. Losses and efficiency of the transformer alone
P_tot = P_fe + P_cu;
fprintf('\n--- TRANSFORMER LOSSES ---\n');
fprintf('Core %.0f W + copper %.0f W = %.0f W, %.2f %% of %.0f kW (%.1f kg core, about %.1f kg copper)\n', ...
    P_fe, P_cu, P_tot, 100*P_tot/P, P/1e3, n_stack*m_set, 2*n1*MLT*A_cu*1e-6*8900);

function h = h_wind_eff(win_h, n_layers, turns_per_layer, d_litz)
    % axial length of the winding that carries the leakage field: the turns of the fullest layer
    h = min(win_h, turns_per_layer*d_litz);
    if n_layers < 1, h = win_h; end
end
