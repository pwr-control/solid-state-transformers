%[text] # spectrum: spectra of the tank current and of the DC link ripple
% Rev. 01, 2026-10-24: SST CLLC-DCX 800 V -> 800 V, 50 kW. Run after the simulation or after
% load('sim_results_xx.mat'): FFT over the last n_per switching periods of i1 (tank, side 1), of the DC link 2
% voltage and of the DC link 1 current. The DCX ripple is at 2 fs (rectified half sines) and its multiples;
% the tank current is at fs and its odd multiples. The EPS file goes to ./figures.

close all
n_per = 50;
fs = param.glb_time.fPWM_CLLC;
t = time_tc_sim(:);
w = t >= t(end) - n_per/fs;
tsamp = t(2) - t(1);
sig = {i1_cllc_transformer_modA_sim(w), cllc_voltage_output_modA_sim(w), cllc_current_input_modA_sim(w)};
lab = {'$\hat{i}_1 / A$', '$\hat{u}_{2}^{dc} / V$', '$\hat{i}_{1}^{dc} / A$'};
ttl = {'tank current $i_1$ (side 1)', 'DC link 2 voltage ripple', 'DC link 1 current ripple'};
figure;
for k = 1:3
    x = sig{k}(:);  x = x - mean(x);
    Nf = numel(x);
    fr = (0:floor(Nf/2)-1)'/(Nf*tsamp);
    X = abs(fft(x))/Nf*2;
    subplot(3, 1, k)
    bar(fr/1e3, X(1:numel(fr)), 'FaceColor', [0.25 0.25 0.25], 'EdgeColor', [0.25 0.25 0.25]); grid on
    set(gca, 'xlim', [0 12*fs/1e3]);
    ylabel(lab{k}, 'Interpreter', 'latex'); xlabel('$f / kHz$', 'Interpreter', 'latex');
    title(sprintf('Spectrum of the %s, last %d periods (fs = %.0f kHz).', ttl{k}, n_per, fs/1e3), 'Interpreter', 'latex');
    [~, im] = max(X(2:numel(fr)));
    fprintf('%s: main line %.1f at %.1f kHz\n', ttl{k}, X(im + 1), fr(im + 1)/1e3);
end
set(gcf, 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0 0 1 1]);
print(gcf, fullfile('figures', 'CLLC_spectra'), '-depsc');
clear n_per fs t w tsamp sig lab ttl k x Nf fr X im
