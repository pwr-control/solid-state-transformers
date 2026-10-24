%[text] # plotting\_results: CLLC-DCX quantities
% Rev. 01, 2026-10-24: SST CLLC-DCX 800 V -> 800 V, 50 kW. Reads param.*, axes scaled on param.cllc.hw,
% secondary quantities also shown referred to the primary (x n or / n; n = 1 for this stage).
% Figure 1: whole run (DC side, current loop, device losses). Figure 2: last three switching periods
% (tank, transformer, switches of the two bridges). Figures 3-7: start-up, magnetizing current and DC link 2
% ripple, losses per switch, spectra, switching edges. Run after the simulation or after
% load('sim_results_xx.mat'); the EPS files go to ./figures, with the power direction in the name
% (pdir: side 1 -> side 2, ndir: side 2 -> side 1).
% Works with battery 2 or with the current source / load resistor on side 2, with or without the current loop.

close all
tratto1 = 1;
tratto2 = 2;
colore1 = [0.25 0.25 0.25];
colore2 = [0.5 0.5 0.5];
colore3 = [0.75 0.75 0.75];
fontsize_plotting = 12;
lx = @(s) xlabel(s, 'Interpreter', 'latex', 'FontSize', fontsize_plotting);
ly = @(s) ylabel(s, 'Interpreter', 'latex', 'FontSize', fontsize_plotting);
tl = @(s) title(s, 'Interpreter', 'latex', 'FontSize', fontsize_plotting);
lg = @(varargin) legend(varargin{:}, 'Location', 'northeast', 'Interpreter', 'latex', 'FontSize', fontsize_plotting-2);

hw = param.cllc.hw;
n12 = hw.n1/hw.n2;
tpwm = param.glb_time.tPWM_CLLC;
t = time_tc_sim(:);
t2c = t(end);
t1c = t2c - 3*tpwm;
t0c = t(1);
if ~exist('run_tag', 'var')
    if mean(current_battery_1_sim(t > t2c - 50*tpwm)) >= 0
        run_tag = 'pdir';                       % power from side 1 to side 2
    else
        run_tag = 'ndir';
    end
end
Iac = 1.5*sqrt(2)*param.cllc.pwr_nom/hw.udc1_nom*pi/2;      % about 1.5 x the design peak of i1

%[text] ## Figure 1: whole run
figure;
subplot 221
plot(t, voltage_battery_1_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, cllc_voltage_input_modA_sim, '-', 'LineWidth', tratto1, 'Color', colore2);
plot(t, n12*cllc_voltage_output_modA_sim, '-', 'LineWidth', tratto1, 'Color', colore3);
leg = {'$u_{bat1}$', '$u_{1}^{dc}$', '$n\,u_{2}^{dc}$'};
if exist('voltage_battery_2_sim', 'var')         % bench with battery 2 (otherwise load resistor)
    plot(t, n12*voltage_battery_2_sim, '--', 'LineWidth', tratto2, 'Color', colore1);
    leg{end+1} = '$n\,u_{bat2}$';
end
hold off
ly('$u/V$'); lx('$t/s$'); grid on
set(gca, 'ylim', [0 1.25*hw.udc1_nom], 'xlim', [t0c t2c]);
tl('DC voltages, side 2 referred to the primary.');
lg(leg{:});

subplot 222
plot(t, cllc_current_input_modA_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, cllc_current_output_modA_sim/n12, '--', 'LineWidth', tratto2, 'Color', colore2); hold off
ly('$i/A$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t0c t2c]);
tl('DC currents, side 2 referred to the primary.');
lg('$i_{1}^{dc}$', '$i_{2}^{dc}/n$');

subplot 223
if exist('time_ts_sim', 'var')                 % current loop logged (closed loop only)
    ts = time_ts_sim(:);
    plot(ts, cllc_input_current_ref_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
    plot(ts, cllc_input_current_sim, '--', 'LineWidth', tratto2, 'Color', colore1);
    plot(ts, cllc_current_ctrl_output_sim, '-', 'LineWidth', tratto2, 'Color', colore3); hold off
    ly('$p.u.$'); lx('$t/s$'); grid on
    set(gca, 'ylim', [-1.2 1.2], 'xlim', [t0c t2c]);
    tl(sprintf('Input current loop ($I_{FS}$ = %.0f A).', hw.Idc_FS));
    lg('$i_{1}^{ref}$', '$i_{1}$', 'ctrl output');
else
    axis off; tl('Current loop not logged (open loop).');
end

subplot 224
plot(t, mosfet_zvs_plosses_cllc_Q1_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, mosfet_zvs_plosses_cllc_Q2_sim, '--', 'LineWidth', tratto2, 'Color', colore1);
plot(t, mosfet_zvs_plosses_cllc_Q5_sim, '-', 'LineWidth', tratto2, 'Color', colore2);
plot(t, mosfet_zvs_plosses_cllc_Q6_sim, '--', 'LineWidth', tratto2, 'Color', colore2); hold off
ly('$p/W$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t0c t2c]);
tl('Device power losses.');
lg('$p_{loss}^{Q1}$', '$p_{loss}^{Q2}$', '$p_{loss}^{Q5}$', '$p_{loss}^{Q6}$');
print_landscape(gcf, ['CLLC_dc_side_' run_tag]);

%[text] ## Figure 2: last three switching periods
figure;
subplot 311
yyaxis left
plot(t, i1_cllc_transformer_modA_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, i2_cllc_transformer_modA_sim/n12, ':', 'LineWidth', tratto2, 'Color', colore1); hold off
ly('$i/A$'); set(gca, 'ylim', [-Iac Iac], 'YColor', colore1);
yyaxis right
plot(t, u1_cllc_transformer_modA_sim, '-', 'LineWidth', tratto2, 'Color', colore2); hold on
plot(t, n12*u2_cllc_transformer_modA_sim, '-', 'LineWidth', tratto2, 'Color', colore3); hold off
ly('$u/V$'); set(gca, 'ylim', [-1.5 1.5]*hw.udc1_nom, 'YColor', colore2);
lx('$t/s$'); grid on; set(gca, 'xlim', [t1c t2c]);
tl('Tank quantities, secondary referred to the primary.');
lg('$i_{1}^{ac}$', '$i_{2}^{ac}/n$', '$u_{1}^{ac}$', '$n\,u_{2}^{ac}$');

subplot 312
yyaxis left
plot(t, mosfet_zvs_uds_cllc_Q1_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, mosfet_zvs_uds_cllc_Q2_sim, '--', 'LineWidth', tratto2, 'Color', colore1); hold off
ly('$u/V$'); set(gca, 'ylim', [-0.1 1.3]*hw.udc1_nom, 'YColor', colore1);
yyaxis right
plot(t, mosfet_zvs_ids_cllc_Q1_sim, '-', 'LineWidth', tratto1, 'Color', colore2); hold on
plot(t, mosfet_zvs_ids_cllc_Q2_sim, '--', 'LineWidth', tratto1, 'Color', colore2); hold off
ly('$i/A$'); set(gca, 'ylim', [-Iac Iac], 'YColor', colore2);
lx('$t/s$'); grid on; set(gca, 'xlim', [t1c t2c]);
tl('Primary switches: ZVS when $i_{ds} \le 0$ at the fall of $u_{ds}$.');
lg('$u_{ds}^{Q1}$', '$u_{ds}^{Q2}$', '$i_{ds}^{Q1}$', '$i_{ds}^{Q2}$');

subplot 313
yyaxis left
plot(t, mosfet_zvs_uds_cllc_Q5_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, mosfet_zvs_uds_cllc_Q6_sim, '--', 'LineWidth', tratto2, 'Color', colore1); hold off
ly('$u/V$'); set(gca, 'ylim', [-0.1 1.3]*hw.udc2_nom, 'YColor', colore1);
yyaxis right
plot(t, mosfet_zvs_ids_cllc_Q5_sim, '-', 'LineWidth', tratto1, 'Color', colore2); hold on
plot(t, mosfet_zvs_ids_cllc_Q6_sim, '--', 'LineWidth', tratto1, 'Color', colore2); hold off
ly('$i/A$'); set(gca, 'ylim', [-Iac Iac]*n12, 'YColor', colore2);
lx('$t/s$'); grid on; set(gca, 'xlim', [t1c t2c]);
tl('Secondary switches (synchronous rectifier in a DCX: in phase with the primary).');
lg('$u_{ds}^{Q5}$', '$u_{ds}^{Q6}$', '$i_{ds}^{Q5}$', '$i_{ds}^{Q6}$');
print_landscape(gcf, ['CLLC_quantities_' run_tag]);

%[text] ## Figure 3: start-up (first 2 ms)
t_su = min(t0c + 2e-3, t2c);
figure;
subplot 211
plot(t, cllc_voltage_input_modA_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, n12*cllc_voltage_output_modA_sim, '-', 'LineWidth', tratto1, 'Color', colore2); hold off
ly('$u/V$'); lx('$t/s$'); grid on; set(gca, 'xlim', [t0c t_su], 'ylim', [0 1.25*hw.udc1_nom]);
tl('Start-up: DC voltages, side 2 referred to the primary.');
lg('$u_{1}^{dc}$', '$n\,u_{2}^{dc}$');
subplot 212
plot(t, i1_cllc_transformer_modA_sim, '-', 'LineWidth', tratto1, 'Color', colore1); hold on
plot(t, cllc_current_input_modA_sim, '-', 'LineWidth', tratto2, 'Color', colore2);
plot(t, cllc_current_output_modA_sim/n12, '--', 'LineWidth', tratto2, 'Color', colore3); hold off
ly('$i/A$'); lx('$t/s$'); grid on; set(gca, 'xlim', [t0c t_su]);
tl('Start-up: tank current and DC currents (inrush of $C_i$, no soft start).');
lg('$i_{1}^{ac}$', '$i_{1}^{dc}$', '$i_{2}^{dc}/n$');
print_landscape(gcf, ['CLLC_startup_' run_tag]);

%[text] ## Figure 4: magnetizing current and DC link 2 ripple (last three periods)
% sign convention of the logged currents: i1 into the primary, i2 out of the secondary, so the
% magnetizing current referred to the primary is i1 - i2/n (about 10 A peak by design)
figure;
subplot 211
im = i1_cllc_transformer_modA_sim - i2_cllc_transformer_modA_sim/n12;
plot(t, im, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, u1_cllc_transformer_modA_sim/hw.udc1_nom*max(abs(im(t >= t1c))), ':', 'LineWidth', tratto1, 'Color', colore2); hold off
ly('$i/A$'); lx('$t/s$'); grid on; set(gca, 'xlim', [t1c t2c]);
tl(sprintf('Magnetizing current $i_1 - i_2/n$ (design peak %.0f A); dotted: $u_1$ scaled.', ...
    hw.udc1_nom/(4*hw.Lm*param.glb_time.fPWM_CLLC)));
lg('$i_{m}$', '$u_{1}$ (scaled)');
subplot 212
plot(t, cllc_voltage_output_modA_sim, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
plot(t, CFi_dc2_current_modA_sim/n12/10, ':', 'LineWidth', tratto1, 'Color', colore2); hold off
ly('$u/V$, $i/A$'); lx('$t/s$'); grid on; set(gca, 'xlim', [t1c t2c]);
tl('DC link 2: voltage $u_{2}^{dc}$ and capacitor current $i_{Ci}/(10\,n)$.');
lg('$u_{2}^{dc}$', '$i_{Ci}/(10n)$');
print_landscape(gcf, ['CLLC_magnetizing_ripple_' run_tag]);

%[text] ## Figure 5: average losses per switch (last 50 periods)
w50 = t >= t2c - 50*tpwm;
cols = [1 6 11 16];                             % first column of each switch: power loss [W]
pl1 = mean(inverter_1_cllc_mosfet_zvs_modA_sim(w50, cols));
pl2 = mean(inverter_2_cllc_mosfet_zvs_modA_sim(w50, cols));
figure;
b = bar([pl1; pl2]', 'grouped'); grid on
b(1).FaceColor = colore1; b(2).FaceColor = colore3;
set(gca, 'XTickLabel', {'S1', 'S2', 'S3', 'S4'});
ly('$p/W$'); lx('switch of the bridge');
tl(sprintf('Average loss per switch: bridge 1 %.0f W, bridge 2 %.0f W in total.', sum(pl1), sum(pl2)));
lg('bridge 1 (primary)', 'bridge 2 (secondary)');
print_landscape(gcf, ['CLLC_switch_losses_' run_tag]);

%[text] ## Figure 6: spectra (last 50 periods)
tsamp = t(2) - t(1);
x1 = i1_cllc_transformer_modA_sim(w50);  x1 = x1(:) - mean(x1);
x2 = cllc_voltage_output_modA_sim(w50);  x2 = x2(:) - mean(x2);
Nf = numel(x1);
fr = (0:floor(Nf/2)-1)'/(Nf*tsamp);
X1 = abs(fft(x1))/Nf*2;  X2 = abs(fft(x2))/Nf*2;
figure;
subplot 211
bar(fr/1e3, X1(1:numel(fr)), 'FaceColor', colore1, 'EdgeColor', colore1); grid on
set(gca, 'xlim', [0 12*param.glb_time.fPWM_CLLC/1e3]);
ly('$\hat{i}/A$'); lx('$f/kHz$'); tl('Spectrum of the tank current $i_1$.');
subplot 212
bar(fr/1e3, X2(1:numel(fr)), 'FaceColor', colore2, 'EdgeColor', colore2); grid on
set(gca, 'xlim', [0 12*param.glb_time.fPWM_CLLC/1e3]);
ly('$\hat{u}/V$'); lx('$f/kHz$'); tl('Spectrum of the DC link 2 ripple (mainly $2 f_s$).');
print_landscape(gcf, ['CLLC_spectra_' run_tag]);

%[text] ## Figure 7: switching edges (one primary and one secondary turn-on)
uq1 = mosfet_zvs_uds_cllc_Q1_sim(:);  uq5 = mosfet_zvs_uds_cllc_Q5_sim(:);
k1 = find(w50(2:end) & uq1(1:end-1) >= 0.1*hw.udc1_nom & uq1(2:end) < 0.1*hw.udc1_nom, 1, 'last') + 1;
k5 = find(w50(2:end) & uq5(1:end-1) >= 0.1*hw.udc2_nom & uq5(2:end) < 0.1*hw.udc2_nom, 1, 'last') + 1;
dt_zoom = 3e-6;
figure;
edge_plot(1, t, k1, dt_zoom, mosfet_zvs_uds_cllc_Q1_sim, mosfet_zvs_ids_cllc_Q1_sim, 'Q1', colore1, colore2, tratto2, fontsize_plotting);
edge_plot(2, t, k5, dt_zoom, mosfet_zvs_uds_cllc_Q5_sim, mosfet_zvs_ids_cllc_Q5_sim, 'Q5', colore1, colore2, tratto2, fontsize_plotting);
print_landscape(gcf, ['CLLC_switching_edges_' run_tag]);

clear t_su im w50 cols pl1 pl2 b tsamp x1 x2 Nf fr X1 X2 uq1 uq5 k1 k5 dt_zoom leg tratto1 tratto2 colore1 colore2 colore3 fontsize_plotting lx ly tl lg hw n12 tpwm t t0c t1c t2c ts Iac

function print_landscape(h, name)
    set(h, 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0 0 1 1]);
    print(h, fullfile('figures', name), '-depsc');
end

function edge_plot(row, t, k, dt_zoom, uds, ids, name, c1, c2, lw, fsz)
    subplot(2, 1, row)
    if isempty(k)
        axis off; title(sprintf('%s: no turn-on found', name)); return
    end
    tz = (t - t(k))*1e6;
    yyaxis left
    plot(tz, uds, '-', 'LineWidth', lw, 'Color', c1); ylabel('$u_{ds}/V$', 'Interpreter', 'latex', 'FontSize', fsz);
    set(gca, 'YColor', c1);
    yyaxis right
    plot(tz, ids, '--', 'LineWidth', lw, 'Color', c2); ylabel('$i_{ds}/A$', 'Interpreter', 'latex', 'FontSize', fsz);
    set(gca, 'YColor', c2);
    xlabel('$(t - t_{on})/\mu s$', 'Interpreter', 'latex', 'FontSize', fsz);
    set(gca, 'xlim', [-dt_zoom dt_zoom]*1e6); grid on
    ids_on = ids(k);
    if ids_on <= 0, verdict = 'ZVS'; else, verdict = 'hard turn-on'; end
    title(sprintf('%s turn-on: $i_{ds}$ = %.0f A at the fall of $u_{ds}$ (%s).', name, ids_on, verdict), ...
        'Interpreter', 'latex', 'FontSize', fsz);
end
