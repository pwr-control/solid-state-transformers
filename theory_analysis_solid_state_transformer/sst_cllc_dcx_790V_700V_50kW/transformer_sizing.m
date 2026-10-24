%[text] # transformer_sizing: first sizing of the 9:8 transformer of the CLLC-DCX 790 V -> 700 V, 50 kW, 35 kHz
% 2026-10-24: 790 V -> 700 V, 35 kHz (the 800 V -> 800 V, 50 kHz, 1:1 sizing on three stacked UU93/152/30 sets is
% ../sst_cllc_dcx_800V_800V_50kW/transformer_sizing.m). Same method as ../magnetics_sizing/single_phaseDAB_TRsizing.m
% (Faraday's law with fixed turns, current density, copper loss, specific core loss, leakage estimate), with the
% numbers of the DCX (cllc_dcx_sizing.md): 790 V square wave on the primary, 35 kHz, 72 A rms on the primary and
% 81 A rms on the secondary (resonant half sines of 105 / 118 A peak, plus the magnetizing triangle of 10 A peak
% on the primary). At 35 kHz the volt-seconds per half period are 43 % more than at 50 kHz: the ratio 700/790 is
% made with 9:8 turns in one layer of litz each, which needs five stacked UU93/152/30 ferrite sets (N87 class)
% to stay at 0.15 T; more turns (18:16, 17:15) fit the 37 mm window only in two layers per winding at 4 A/mm^2
% (Sec. 6). The result gives the model numbers of private/cllc_dcx_param.m: n1, n2, Lm (air gap), Rs1
% (Rs2 = Rs1/n^2), Rfe, and the leakage that is part of Lr1 + Lr2.

clc
mu0 = 4*pi*1e-7;
rho_cu = 1.72e-8*(1 + 0.0039*(100 - 20));          % [Ohm m] copper at 100 degC

%% 1. Electrical inputs (from the DCX sizing)
udc1 = 790;                 % [V] DC link voltage of side 1 (square wave of +/- udc1 on the primary)
udc2 = 700;                 % [V] DC link voltage of side 2, nominal (the DCX gives udc1 n2/n1 at no load)
P = 50e3;                   % [W]
fs = 35e3;                  % [Hz] switching frequency
fn = 0.95;                  % fs/fr
Lm = 560e-6;                % [H] magnetizing inductance of the ZVS sizing (Im peak = udc1/(4 Lm fs) = 10 A)
Lr_tot = 2*16e-6;           % [H] series inductance of the whole tank referred to the primary (Lr1 + n^2 Lr2)
idc1 = P/udc1;              % [A] 63.3 A
i1_pk = pi/2*idc1/fn;       % [A] 105 A, resonant half sine of period 1/fr carrying idc1 per half period
i1_res = i1_pk*sqrt(fn/2);  % [A] 72.1 A rms
im_pk = udc1/(4*Lm*fs);     % [A] 10 A
i1_rms = sqrt(i1_res^2 + im_pk^2/3);    % [A] 72.4 A rms, primary (resonant current plus magnetizing triangle)
fprintf('--- ELECTRICAL INPUTS ---\n');
fprintf('Primary %.0f V square wave, %.0f kHz, %.1f A rms (%.0f A peak), Lm = %.0f uH\n', ...
    udc1, fs/1e3, i1_rms, i1_pk + im_pk, Lm*1e6);

%% 2. Core: stack of UU93/152/30 sets (2 x U93/76/30, ferrite N87 class)
n_stack = 5;                % sets stacked in depth
Ae_set = 840e-6;            % [m^2] core area of one set
le = 354e-3;                % [m] mean magnetic path length
Ve_set = 297e-6;            % [m^3] core volume of one set
m_set = 1.5;                % [kg] mass of one set (two U93)
leg_w = 28e-3;              % [m] leg width
leg_d = 30e-3;              % [m] leg depth of one set
win_w = 37e-3;              % [m] window width (space for both windings and the insulation)
win_h = 96e-3;              % [m] window height (UU: two legs of 48 mm)
Bmax = 0.15;                % [T] peak flux density (ferrite at 35 kHz: core loss, not saturation, sets it)
Ae = n_stack*Ae_set;
n1 = ceil(udc1/(4*fs*Bmax*Ae));         % Faraday, square wave: udc1 = 4 n1 Ae Bpk fs -> 9
n2 = round(n1*udc2/udc1);               % the DCX ratio: 8, u2 = 702 V at no load
n12 = n1/n2;
i2_rms = i1_res*n12;                    % [A] 81 A rms, secondary (no magnetizing current)
Bpk = udc1/(4*fs*n1*Ae);                % [T] with the integer number of turns
B_first_pulse = 2*Bpk;                  % [T] first half period from zero flux (no soft start): check against Bsat
fprintf('\n--- CORE: %d x UU93/152/30, Ae = %.1f cm^2 ---\n', n_stack, Ae*1e4);
fprintf('Turns n1 : n2 = %d : %d (u2 = %.0f V at no load, %.1f A rms on the secondary)\n', n1, n2, udc1*n2/n1, i2_rms);
fprintf('Bpk = %.3f T (first pulse from zero flux %.2f T, Bsat about 0.39 T at 100 degC)\n', Bpk, B_first_pulse);

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
Rfe = udc1^2/P_fe;                      % [Ohm] parallel resistance of the model (square wave of +/- udc1, primary side)
fprintf('Core losses: Pv = %.0f kW/m^3, P_fe = %.0f W (%.1f kg of ferrite), Rfe = %.1f kOhm\n', ...
    Pv/1e3, P_fe, n_stack*m_set, Rfe/1e3);

%% 3. Windings: litz wire, 0.1 mm strands (skin depth at 35 kHz about 0.35 mm), one bundle size per winding
J = 3.0;                                % [A/mm^2]
d_strand = 0.1e-3;                      % [m]
k_litz = 0.45;                          % copper fraction of the litz bundle (strand insulation, serving, bundling)
A_cu1 = i1_rms/J;                       % [mm^2] copper of the primary
A_cu2 = i2_rms/J;                       % [mm^2] copper of the secondary
d_litz1 = sqrt(4*A_cu1*1e-6/k_litz/pi); % [m] outer diameter of the bundles
d_litz2 = sqrt(4*A_cu2*1e-6/k_litz/pi);
tpl1 = floor(0.95*win_h/d_litz1);       % turns per layer
tpl2 = floor(0.95*win_h/d_litz2);
n_layers1 = ceil(n1/tpl1);
n_layers2 = ceil(n2/tpl2);
h_wind1 = n_layers1*d_litz1;            % [m] radial build of each winding
h_wind2 = n_layers2*d_litz2;
h_ins = 3e-3;                           % [m] insulation + shield between primary and secondary (DC isolation of the links)
h_bob = 2e-3;                           % [m] bobbin / wall insulation
build = h_bob + h_wind1 + h_ins + h_wind2;          % [m] radial build of both windings, no interleaving (P-S)
MLT = 2*(leg_w + n_stack*leg_d) + pi*build;         % [m] mean length per turn around the stacked leg
R_dc1 = rho_cu*n1*MLT/(A_cu1*1e-6);     % [Ohm]
R_dc2 = rho_cu*n2*MLT/(A_cu2*1e-6);
Fr = 1.5;                               % AC resistance factor (litz in one layer, ASSUMPTION)
R_ac1 = Fr*R_dc1;
R_ac2 = Fr*R_dc2;
P_cu = R_ac1*i1_rms^2 + R_ac2*i2_rms^2; % [W] both windings
fprintf('\n--- WINDINGS: litz %.0f x %.1f mm (%.1f mm^2 Cu, %.1f mm OD) primary, %.0f x %.1f mm (%.1f mm^2, %.1f mm OD) secondary ---\n', ...
    A_cu1*1e-6/(pi*d_strand^2/4), d_strand*1e3, A_cu1, d_litz1*1e3, A_cu2*1e-6/(pi*d_strand^2/4), d_strand*1e3, A_cu2, d_litz2*1e3);
fprintf('Primary %d turns in %d layer(s) of %d, secondary %d turns in %d layer(s) of %d\n', n1, n_layers1, tpl1, n2, n_layers2, tpl2);
fprintf('Radial build %.1f mm of the %.0f mm window (fill %.0f %%), MLT = %.0f mm\n', build*1e3, win_w*1e3, 100*build/win_w, MLT*1e3);
fprintf('Primary R_dc = %.2f mOhm, R_ac = %.2f mOhm (Fr = %.1f), %.0f W; secondary R_dc = %.2f mOhm, R_ac = %.2f mOhm, %.0f W; P_cu = %.0f W\n', ...
    R_dc1*1e3, R_ac1*1e3, Fr, R_ac1*i1_rms^2, R_dc2*1e3, R_ac2*1e3, R_ac2*i2_rms^2, P_cu);
fprintf('Model: Rs1 = R_ac1 plus terminations and the discrete inductor; the class sets Rs2 = Rs1/n^2 = %.2f mOhm for Rs1 = 7 mOhm (R_ac2 = %.2f mOhm)\n', ...
    7/n12^2, R_ac2*1e3);

%% 4. Leakage inductance (concentric windings P-S, no interleaving) and resonant inductors
h_eff = h_wind_eff(win_h, max(n_layers1, n_layers2), min(tpl1, tpl2), max(d_litz1, d_litz2));
L_sigma = mu0*n1^2*MLT/h_eff*(h_ins + (h_wind1 + h_wind2)/3);   % [H] total, referred to the primary
L_discrete = Lr_tot - L_sigma;          % [H] to add as discrete inductors (half per side, referred to the primary)
fprintf('\n--- LEAKAGE ---\n');
fprintf('L_sigma = %.1f uH (total, referred to the primary: measured from side 1 with side 2 shorted)\n', L_sigma*1e6);
if L_discrete > 0
    fprintf('Tank needs Lr1 + n^2 Lr2 = %.0f uH: %.1f uH discrete, %.1f uH per side referred to the primary (%.1f uH on side 2)\n', ...
        Lr_tot*1e6, L_discrete*1e6, L_discrete/2*1e6, L_discrete/2/n12^2*1e6);
else
    fprintf('L_sigma exceeds Lr1 + n^2 Lr2 = %.0f uH: interleave the windings (S-P-S) to reduce it\n', Lr_tot*1e6);
end
fprintf('Split of the model: Ld1 = Lr1 = %.0f uH, Ld2 = Lr2 = Lr1/n^2 = %.1f uH (leakage + discrete), Cr2 = n^2 Cr1\n', ...
    Lr_tot/2*1e6, Lr_tot/2/n12^2*1e6);

%% 5. Losses and efficiency of the transformer alone
P_tot = P_fe + P_cu;
m_cu = (n1*A_cu1 + n2*A_cu2)*1e-6*MLT*8900;
fprintf('\n--- TRANSFORMER LOSSES ---\n');
fprintf('Core %.0f W + copper %.0f W = %.0f W, %.2f %% of %.0f kW (%.1f kg core, about %.1f kg copper)\n', ...
    P_fe, P_cu, P_tot, 100*P_tot/P, P/1e3, n_stack*m_set, m_cu);

%% 6. Alternatives on the same core family (one line each)
% 9:8 keeps one layer per winding (11 turns of 8.3 mm litz fit the 96 mm window) and needs five sets for 0.15 T;
% four sets run at 0.187 T; 18:16 on three sets keeps the ratio with a low flux density but needs two layers per
% winding, which fit the 37 mm window only at 4 A/mm^2 (fill 93 %), with more copper loss and leakage.
fprintf('\n--- ALTERNATIVES (core sets, turns, J, Fr: Bpk, core + copper loss, window fill, leakage) ---\n');
trafo_option(5, 9, 8, 3.0, 1.5, udc1, fs, i1_rms, i1_res, Lm, Pv0, f0, B0, alpha, beta, Ae_set, Ve_set, m_set, le, mur, leg_w, leg_d, win_w, win_h, k_litz, h_ins, h_bob, rho_cu, mu0);
trafo_option(4, 9, 8, 3.0, 1.5, udc1, fs, i1_rms, i1_res, Lm, Pv0, f0, B0, alpha, beta, Ae_set, Ve_set, m_set, le, mur, leg_w, leg_d, win_w, win_h, k_litz, h_ins, h_bob, rho_cu, mu0);
trafo_option(3, 18, 16, 4.0, 2.0, udc1, fs, i1_rms, i1_res, Lm, Pv0, f0, B0, alpha, beta, Ae_set, Ve_set, m_set, le, mur, leg_w, leg_d, win_w, win_h, k_litz, h_ins, h_bob, rho_cu, mu0);
trafo_option(3, 17, 15, 4.0, 2.0, udc1, fs, i1_rms, i1_res, Lm, Pv0, f0, B0, alpha, beta, Ae_set, Ve_set, m_set, le, mur, leg_w, leg_d, win_w, win_h, k_litz, h_ins, h_bob, rho_cu, mu0);

function h = h_wind_eff(win_h, n_layers, turns_per_layer, d_litz)
    % axial length of the winding that carries the leakage field: the turns of the fullest layer
    h = min(win_h, turns_per_layer*d_litz);
    if n_layers < 1, h = win_h; end
end

function trafo_option(n_stack, n1, n2, J, Fr, udc1, fs, i1_rms, i1_res, Lm, Pv0, f0, B0, alpha, beta, ...
        Ae_set, Ve_set, m_set, le, mur, leg_w, leg_d, win_w, win_h, k_litz, h_ins, h_bob, rho_cu, mu0)
    % one design option of Sec. 6 with the same formulas as Secs. 2-4
    Ae = n_stack*Ae_set;
    Bpk = udc1/(4*fs*n1*Ae);
    P_fe = Pv0*(fs/f0)^alpha*(Bpk/B0)^beta*n_stack*Ve_set;
    n12 = n1/n2;
    i2_rms = i1_res*n12;
    A1 = i1_rms/J; A2 = i2_rms/J;
    d1 = sqrt(4*A1*1e-6/k_litz/pi); d2 = sqrt(4*A2*1e-6/k_litz/pi);
    tpl1 = floor(0.95*win_h/d1); tpl2 = floor(0.95*win_h/d2);
    nl1 = ceil(n1/tpl1); nl2 = ceil(n2/tpl2);
    hw1 = nl1*d1; hw2 = nl2*d2;
    build = h_bob + hw1 + h_ins + hw2;
    MLT = 2*(leg_w + n_stack*leg_d) + pi*build;
    P_cu = Fr*rho_cu*MLT*(n1*i1_rms^2/(A1*1e-6) + n2*i2_rms^2/(A2*1e-6));
    L_sigma = mu0*n1^2*MLT/h_wind_eff(win_h, max(nl1, nl2), min(tpl1, tpl2), max(d1, d2))*(h_ins + (hw1 + hw2)/3);
    gap_tot = mu0*Ae*n1^2/Lm - le/mur;      % [m] air gap for the same Lm
    fprintf('%d sets, %2d:%2d, J = %.1f, Fr = %.1f: Bpk = %.3f T, %3.0f W core + %3.0f W copper = %3.0f W, %d/%d layers, fill %3.0f %%, L_sigma = %4.1f uH, gap %.2f mm, %.1f kg ferrite\n', ...
        n_stack, n1, n2, J, Fr, Bpk, P_fe, P_cu, P_fe + P_cu, nl1, nl2, 100*build/win_w, L_sigma*1e6, gap_tot*1e3, n_stack*m_set);
end
