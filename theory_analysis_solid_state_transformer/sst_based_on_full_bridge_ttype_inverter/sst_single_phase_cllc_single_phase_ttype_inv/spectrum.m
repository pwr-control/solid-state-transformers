%[text] # spectrum: spectra of the line current, of the module A output voltage and of the battery current
% Rev. 02, 2026-10-24: two-module SST (battery -> CLLC-DCX -> T-type inverters in series). Run after the simulation
% or after load('sim_results_xx.mat'): FFT over the last n_per grid periods of the logged window (an integer number
% of periods, so that the 50 Hz lines fall on bins). Line current: harmonics of 50 Hz and the switching sidebands
% at 2 fpwm = 8 kHz (five-level output voltage, the carriers of the two modules in phase); module A output
% voltage: the same; battery 1 current: the 100 Hz pulsation of the single-phase inverters that the DCX pass to the
% bus, and the 2 fs = 100 kHz ripple of the DCX (param.cllc.interleave = 1 puts the two DCX in opposition). Prints
% the main line of each spectrum and the THD of the line current (harmonics up to the 50th). EPS in ./figures.

close all
n_per = 5;
fg = param.grid.f_nom;
fpwm = param.glb_time.fPWM_INV;
fs = param.cllc.fpwm;
t = sig(time_tc_sim);
w = t >= t(end) - n_per/fg;
tsamp = t(2) - t(1);
x_all = {sig(ac_grid_current_sim), sig(afe_voltage_output_modA_sim), sig(current_battery_sim)};
lab = {'$\hat{i}_{line} / A$', '$\hat{u}_{A} / V$', '$\hat{i}_{bat1} / A$'};
ttl = {'line current', 'module A output voltage', 'battery 1 current'};
fmax = [3*fpwm, 3*fpwm, 2.5*fs];
figure;
for k = 1:3
    x = x_all{k}(w);  x = x - mean(x);
    Nf = numel(x);
    fr = (0:floor(Nf/2)-1)'/(Nf*tsamp);
    X = abs(fft(x))/Nf*2;
    X = X(1:numel(fr));
    subplot(3, 1, k)
    bar(fr/1e3, X, 'FaceColor', [0.25 0.25 0.25], 'EdgeColor', [0.25 0.25 0.25]); grid on
    set(gca, 'xlim', [0 fmax(k)/1e3]);
    ylabel(lab{k}, 'Interpreter', 'latex'); xlabel('$f / kHz$', 'Interpreter', 'latex');
    title(sprintf('Spectrum of the %s, last %d grid periods (fpwm = %.0f kHz, fs = %.0f kHz).', ttl{k}, n_per, ...
        fpwm/1e3, fs/1e3), 'Interpreter', 'latex');
    [~, im] = max(X(2:end));
    fprintf('%s: main line %.2f at %.3f kHz\n', ttl{k}, X(im + 1), fr(im + 1)/1e3);
    if k == 1
        % bins of the harmonics: Nf*tsamp = n_per/fg, so the h-th harmonic is at index h*n_per + 1
        ib = @(h) round(h*fg*Nf*tsamp) + 1;
        h1 = X(ib(1));
        hh = 2:50;
        thd = sqrt(sum(X(ib(hh)).^2))/h1;
        fprintf('  fundamental %.2f A peak (%.2f A rms), THD up to the 50th harmonic %.2f %%\n', h1, h1/sqrt(2), 100*thd);
        [~, ih] = max(X(ib(hh)));
        fprintf('  largest harmonic: %d-th, %.3f A (%.2f %% of the fundamental)\n', hh(ih), X(ib(hh(ih))), 100*X(ib(hh(ih)))/h1);
    end
end
set(gcf, 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0 0 1 1]);
print(gcf, fullfile('figures', 'SST_spectra'), '-depsc');
clear n_per fg fpwm fs t w tsamp x_all lab ttl fmax k x Nf fr X im ib h1 hh thd ih

function y = sig(x)
%SIG  logged signal as a numeric array (To Workspace in Array or Timeseries format), time along the first dimension
    if isa(x, 'timeseries')
        y = squeeze(x.Data);
        if size(y, 1) ~= numel(x.Time)
            y = y.';
        end
    else
        y = x;
    end
    if isvector(y)
        y = y(:);
    end
end
