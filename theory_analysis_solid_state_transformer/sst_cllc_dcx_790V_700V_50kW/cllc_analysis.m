%[text] # cllc_analysis: first-harmonic analysis of the CLLC-DCX tank
% 2026-10-24: SST CLLC-DCX 790 V -> 700 V, 50 kW, 35 kHz (variant of the 800 V -> 800 V, 50 kHz bench). Reads param (init_model.m or sim_results_xx.mat).
% Secondary elements reflected to the primary (n = n1/n2, 9/8 for this stage; the script is general).
% Load: FHA resistance Rac = 8 n^2 u2^2/(pi^2 P) at 10, 50, 100 % load.
% Last part: power versus phase displacement of the two bridges (the modulator of the model can drive the
% bridges with a phase shift, as a DAB with resonant tank; the DCX runs with phase 0).

close all
s = tf('s');
hw = param.cllc.hw;
fs = param.glb_time.fPWM_CLLC;
n12 = hw.n1/hw.n2;

ZLs1 = s*hw.Ls1;
ZCs1 = 1/s/hw.Cs1;
ZLm  = s*hw.Lm;
ZLs2 = s*hw.Ls2*n12^2;                  % reflected to the primary
ZCs2 = 1/s/(hw.Cs2/n12^2);              % reflected to the primary

fr = 1/(2*pi*sqrt(hw.Ls1*hw.Cs1));
fprintf('fs = %.2f kHz, fr = %.2f kHz, fn = %.3f\n', fs/1e3, fr/1e3, fs/fr);
fprintf('Z0 = %.3f Ohm, Rac(Pnom) = %.3f Ohm, Q = %.3f, Ln = %.1f\n', ...
    sqrt(hw.Ls1/hw.Cs1), param.cllc.tank.Rac, param.cllc.tank.Q, hw.Lm/hw.Ls1);

load_pu = [0.1 0.5 1];
H = cell(size(load_pu)); Zin = cell(size(load_pu));
for k = 1:numel(load_pu)
    Rload = param.cllc.tank.Rac/load_pu(k);
    ZLout = ZLs2 + ZCs2 + Rload;
    Zpout = ZLout*ZLm/(ZLout + ZLm);
    Zin{k} = minreal(ZLs1 + ZCs1 + Zpout);
    H{k} = minreal(Zpout/Zin{k} * Rload/ZLout);     % n*u2/u1, first harmonic
    Hf = evalfr(H{k}, 1i*2*pi*fs);
    Zf = evalfr(Zin{k}, 1i*2*pi*fs);
    fprintf('load %3.0f %%: |M(fs)| = %.4f, phase %6.2f deg | Zin(fs) = %.3f Ohm, %6.2f deg\n', ...
        100*load_pu(k), abs(Hf), rad2deg(angle(Hf)), abs(Zf), rad2deg(angle(Zf)));
end

bopt = bodeoptions; bopt.FreqUnits = 'Hz'; bopt.Grid = 'on';
figure; bode(H{:}, {2*pi*fs/4, 2*pi*fs*4}, bopt);
legend('10 %', '50 %', '100 %'); title('CLLC-DCX gain n u_2 / u_1 (FHA)');
figure; bode(Zin{:}, {2*pi*fs/4, 2*pi*fs*4}, bopt);
legend('10 %', '50 %', '100 %'); title('CLLC-DCX input impedance (FHA)');

% power versus phase displacement (lossless, Lm neglected): P = V1 V2 sin(phi)/(2 X)
w = 2*pi*fs;
X = w*(hw.Ls1 + n12^2*hw.Ls2) - 1/(w*hw.Cs1) - 1/(w*hw.Cs2/n12^2);
V1 = 4/pi*hw.udc1_nom;  V2 = 4/pi*hw.udc2_nom*n12;
Pmax = V1*V2/2/abs(X);
phi = linspace(-90, 90, 361);
fprintf('Tank reactance at fs: X = %.3f Ohm (negative: capacitive, fs < fr)\n', X);
fprintf('Phase-shift transfer: Pmax = %.0f kW at 90 deg; %.0f kW need %.1f deg\n', ...
    Pmax/1e3, param.cllc.pwr_nom/1e3, asind(param.cllc.pwr_nom/Pmax));
fprintf('(a loop on the phase shift would have a huge gain and would push the DCX into capacitive mode)\n');
figure; plot(phi, V1*V2*sind(phi)/2/X/1e3, 'k', 'LineWidth', 2); grid on
xlabel('phase lag of u_2 on u_1 / deg'); ylabel('P_{1 \rightarrow 2} / kW');
title('Power versus phase displacement (FHA, lossless)');
clear hw fs n12 ZLs1 ZCs1 ZLm ZLs2 ZCs2 fr load_pu H Zin Rload ZLout Zpout Hf Zf bopt w X V1 V2 Pmax phi k
