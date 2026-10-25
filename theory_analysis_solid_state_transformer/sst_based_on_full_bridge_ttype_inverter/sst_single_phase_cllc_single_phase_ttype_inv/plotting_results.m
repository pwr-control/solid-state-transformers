%[text] # plotting\_results: SST quantities (battery bus, CLLC-DCX modules, T-type inverters, line)
% Rev. 02, 2026-10-24: two-module SST, battery -> CLLC-DCX 800 V/800 V (library block cllc_dcx_mod1) -> single-phase
% T-type inverters in series on the line. Reads param.*; uses the logs that update_sst_cllc_ttype_inv.m adds to
% storage_data_sst (DCX vectors m and ctrl_log, module B, battery 2, switch losses of module A): the traces of a
% missing log are skipped, the figures that need it are not drawn.
% Figure 1: DC side over the logged window (bus, DCX side 2 and inverter DC link voltages; battery and DCX
% currents; DCX outputs; acquisitions of the DCX control). Figure 2: AC side over the window (line and module
% voltages, line current, DC link ripple). Figure 3: last grid period (line voltage and current, module voltages,
% inverter-side voltage and current of module A). Figure 4: last three switching periods of the DCX (bridge
% voltages, tank currents, magnetizing current, resonant capacitor voltages; module 1 solid, module 2 dashed).
% Figure 5: switch losses of module A (leg u). Run after the simulation or after load('sim_results_xx.mat');
% the EPS files go to ./figures (SST_dc_side, SST_ac_side, SST_ac_zoom, SST_dcx_zoom, SST_inv_losses).

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
land = @() set(gcf, 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0 0 1 1]);
eps_out = @(name) print(gcf, fullfile('figures', name), '-depsc');

idx = param.cllc.idx;
hwd = param.cllc.p_mod1.hw;                 % both DCX read the same hardware (udc_nom, idc_nom for the pu vectors)
t = sig(time_tc_sim);
t0 = t(1);
t2 = t(end);
tg = 1/param.grid.f_nom;                    % grid period
tsw = 1/param.cllc.fpwm;                    % DCX switching period
u_pk_line = param.sst.n_modules*param.grid.u_pk_module;
has_m1 = exist('cllc_dcx_m_mod1_sim', 'var') == 1;
has_m2 = exist('cllc_dcx_m_mod2_sim', 'var') == 1;
if has_m1, m1 = sig(cllc_dcx_m_mod1_sim); end
if has_m2, m2 = sig(cllc_dcx_m_mod2_sim); end
if ~has_m1
    fprintf('plotting_results: cllc_dcx_m_mod1_sim not logged, run update_sst_cllc_ttype_inv and simulate again for the DCX traces\n');
end

%[text] ## Figure 1: DC side over the logged window
figure;
subplot 221
plot(t, sig(voltage_battery_sim), '-', 'LineWidth', tratto2, 'Color', colore1); hold on
leg = {'$u_{bat1}$'};
if exist('voltage_battery_2_sim', 'var')
    plot(t, sig(voltage_battery_2_sim), '--', 'LineWidth', tratto2, 'Color', colore1);
    leg{end+1} = '$u_{bat2}$';
end
if has_m1
    plot(t, m1(:, 3)*hwd.udc_nom, '-', 'LineWidth', tratto1, 'Color', colore2);
    leg{end+1} = '$u_{dc2,1}$';
end
if has_m2
    plot(t, m2(:, 3)*hwd.udc_nom, '--', 'LineWidth', tratto1, 'Color', colore2);
    leg{end+1} = '$u_{dc2,2}$';
end
plot(t, sig(dclink_voltage_modA_sim), '-', 'LineWidth', tratto1, 'Color', colore3);
leg{end+1} = '$u_{dc,A}$';
if exist('dclink_inverter_modB_sim', 'var')
    plot(t, sig(dclink_inverter_modB_sim), '--', 'LineWidth', tratto1, 'Color', colore3);
    leg{end+1} = '$u_{dc,B}$';
end
hold off
ly('$u/V$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t0 t2], 'ylim', [0.8 1.1]*hwd.udc_nom);
tl('Battery bus, DCX side 2 and inverter DC link voltages.');
lg(leg{:});

subplot 222
plot(t, sig(current_battery_sim), '-', 'LineWidth', tratto2, 'Color', colore1); hold on
leg = {'$i_{bat1}$'};
if exist('current_battery_2_sim', 'var')
    plot(t, sig(current_battery_2_sim), '--', 'LineWidth', tratto2, 'Color', colore1);
    leg{end+1} = '$i_{bat2}$';
end
if has_m1
    plot(t, m1(:, 2)*hwd.idc_nom, '-', 'LineWidth', tratto1, 'Color', colore2);
    leg{end+1} = '$i_{dc1,1}$';
end
if has_m2
    plot(t, m2(:, 2)*hwd.idc_nom, '--', 'LineWidth', tratto1, 'Color', colore2);
    leg{end+1} = '$i_{dc1,2}$';
end
hold off
ly('$i/A$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t0 t2]);
tl('Battery currents and DCX input currents.');
lg(leg{:});

subplot 223
if has_m1
    plot(t, m1(:, 4)*hwd.idc_nom, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
    leg = {'$i_{dc2,1}$'};
    if has_m2
        plot(t, m2(:, 4)*hwd.idc_nom, '--', 'LineWidth', tratto2, 'Color', colore2);
        leg{end+1} = '$i_{dc2,2}$';
    end
    hold off
    ly('$i/A$'); lx('$t/s$'); grid on
    set(gca, 'xlim', [t0 t2]);
    tl('DCX output currents (into the inverter DC links).');
    lg(leg{:});
end

subplot 224
if exist('cllc_dcx_ctrl_log_mod1_sim', 'var')
    l1 = sig(cllc_dcx_ctrl_log_mod1_sim);
    plot(t, l1(:, idx.u_dc1), '-', 'LineWidth', tratto2, 'Color', colore1); hold on
    plot(t, l1(:, idx.u_dc2), '--', 'LineWidth', tratto2, 'Color', colore1);
    plot(t, l1(:, idx.i_dc1), '-', 'LineWidth', tratto1, 'Color', colore2);
    plot(t, l1(:, idx.i_dc2), '--', 'LineWidth', tratto1, 'Color', colore2);
    plot(t, l1(:, idx.enable), ':', 'LineWidth', tratto1, 'Color', colore3); hold off
    ly('$p.u.$'); lx('$t/s$'); grid on
    set(gca, 'xlim', [t0 t2]);
    tl(sprintf('DCX 1 control: acquisitions (mode %d, $f_c$ = %.1f kHz).', l1(end, idx.mode), l1(end, idx.f_c)/1e3));
    lg('$u_{dc1}$', '$u_{dc2}$', '$i_{dc1}$', '$i_{dc2}$', 'enable');
end
land();
eps_out('SST_dc_side');

%[text] ## Figure 2: AC side over the logged window
u_g = sig(ac_grid_voltage_sim);
i_g = sig(ac_grid_current_sim);
u_a = sig(afe_voltage_output_modA_sim);
figure;
subplot 311
plot(t, u_g, '-', 'LineWidth', tratto1, 'Color', colore3); hold on
plot(t, u_a, '-', 'LineWidth', tratto1, 'Color', colore1);
leg = {'$u_{line}$', '$u_{A}$'};
if exist('afe_voltage_output_modB_sim', 'var')
    plot(t, sig(afe_voltage_output_modB_sim), '--', 'LineWidth', tratto1, 'Color', colore2);
    leg{end+1} = '$u_{B}$';
end
hold off
ly('$u/V$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t0 t2], 'ylim', [-1.3 1.3]*u_pk_line);
tl('Line voltage and module output voltages.');
lg(leg{:});

subplot 312
plot(t, i_g, '-', 'LineWidth', tratto1, 'Color', colore1); hold on
plot(t, sig(afe_current_output_modA_sim), '--', 'LineWidth', tratto1, 'Color', colore2); hold off
ly('$i/A$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t0 t2], 'ylim', [-1.5 1.5]*param.spinv.hw.ibez);
tl(sprintf('Line current (%.2f pu reference on module A, $i_{bez}$ = %.0f A).', param.spinv.i_ref, param.spinv.hw.ibez));
lg('$i_{line}$', '$i_{A}$');

subplot 313
udc_a = sig(dclink_voltage_modA_sim);
plot(t, udc_a, '-', 'LineWidth', tratto1, 'Color', colore1); hold on
leg = {'$u_{dc,A}$'};
if exist('dclink_inverter_modB_sim', 'var')
    plot(t, sig(dclink_inverter_modB_sim), '--', 'LineWidth', tratto1, 'Color', colore2);
    leg{end+1} = '$u_{dc,B}$';
end
hold off
ly('$u/V$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t0 t2]);
tl(sprintf('Inverter DC links: 100 Hz ripple on $C_{Fi}$ = %.1f mF (mean %.0f V).', param.spinv.hw.CFi*1e3, mean(udc_a)));
lg(leg{:});
land();
eps_out('SST_ac_side');

%[text] ## Figure 3: last grid period
t1 = t2 - tg;
wz = t >= t1;
figure;
subplot 311
plot(t(wz), u_g(wz), '-', 'LineWidth', tratto2, 'Color', colore3); hold on
plot(t(wz), u_a(wz), '-', 'LineWidth', tratto1, 'Color', colore1);
leg = {'$u_{line}$', '$u_{A}$'};
if exist('afe_voltage_output_modB_sim', 'var')
    u_b = sig(afe_voltage_output_modB_sim);
    plot(t(wz), u_b(wz), '--', 'LineWidth', tratto1, 'Color', colore2);
    leg{end+1} = '$u_{B}$';
end
hold off
ly('$u/V$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t1 t2], 'ylim', [-1.3 1.3]*u_pk_line);
tl('Last grid period: line voltage and module output voltages.');
lg(leg{:});

subplot 312
u_sa = sig(afe_us_modA_sim);
plot(t(wz), u_sa(wz), '-', 'LineWidth', tratto1, 'Color', colore2); hold on
plot(t(wz), u_a(wz), '-', 'LineWidth', tratto2, 'Color', colore1); hold off
ly('$u/V$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t1 t2], 'ylim', [-1.3 1.3]*param.spinv.hw.udc_nom);
tl('Module A: inverter-side voltage (five levels, $\pm u_{dc}$) and output voltage.');
lg('$u_{s,A}$', '$u_{A}$');

subplot 313
i_sa = sig(afe_is_modA_sim);
plot(t(wz), i_sa(wz), '-', 'LineWidth', tratto1, 'Color', colore2); hold on
plot(t(wz), i_g(wz), '-', 'LineWidth', tratto2, 'Color', colore1); hold off
ly('$i/A$'); lx('$t/s$'); grid on
set(gca, 'xlim', [t1 t2]);
tl('Module A: inverter-side current (with the switching ripple) and line current.');
lg('$i_{s,A}$', '$i_{line}$');
land();
eps_out('SST_ac_zoom');

%[text] ## Figure 4: last three switching periods of the DCX (module 1 solid, module 2 dashed)
if has_m1
    t1 = t2 - 3*tsw;
    wz = t >= t1;
    figure;
    subplot 221
    plot(t(wz), m1(wz, 7)*hwd.udc_nom, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
    plot(t(wz), m1(wz, 8)*hwd.udc_nom, '-', 'LineWidth', tratto1, 'Color', colore2);
    leg = {'$u_{b1,1}$', '$u_{b2,1}$'};
    if has_m2
        plot(t(wz), m2(wz, 7)*hwd.udc_nom, '--', 'LineWidth', tratto2, 'Color', colore1);
        plot(t(wz), m2(wz, 8)*hwd.udc_nom, '--', 'LineWidth', tratto1, 'Color', colore2);
        leg = [leg, {'$u_{b1,2}$', '$u_{b2,2}$'}];
    end
    hold off
    ly('$u/V$'); lx('$t/s$'); grid on
    set(gca, 'xlim', [t1 t2], 'ylim', [-1.3 1.3]*hwd.udc_nom);
    tl('Bridge voltages (bridge 1 driving, bridge 2 synchronous rectifier).');
    lg(leg{:});

    subplot 222
    plot(t(wz), m1(wz, 5)*hwd.idc_nom, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
    plot(t(wz), m1(wz, 6)*hwd.idc_nom, '-', 'LineWidth', tratto1, 'Color', colore2);
    leg = {'$i_{r1,1}$', '$i_{r2,1}$'};
    if has_m2
        plot(t(wz), m2(wz, 5)*hwd.idc_nom, '--', 'LineWidth', tratto2, 'Color', colore1);
        plot(t(wz), m2(wz, 6)*hwd.idc_nom, '--', 'LineWidth', tratto1, 'Color', colore2);
        leg = [leg, {'$i_{r1,2}$', '$i_{r2,2}$'}];
    end
    hold off
    ly('$i/A$'); lx('$t/s$'); grid on
    set(gca, 'xlim', [t1 t2]);
    tl(sprintf('Tank currents ($f_s$ = %.0f kHz, $I_{dc}$ = %.1f A).', param.cllc.fpwm/1e3, hwd.idc_nom));
    lg(leg{:});

    subplot 223
    plot(t(wz), m1(wz, 13)*hwd.idc_nom, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
    plot(t(wz), m1(wz, 2)*hwd.idc_nom, '-', 'LineWidth', tratto1, 'Color', colore2);
    leg = {'$i_{m,1}$', '$i_{dc1,1}$'};
    if has_m2
        plot(t(wz), m2(wz, 13)*hwd.idc_nom, '--', 'LineWidth', tratto2, 'Color', colore1);
        plot(t(wz), m2(wz, 2)*hwd.idc_nom, '--', 'LineWidth', tratto1, 'Color', colore2);
        leg = [leg, {'$i_{m,2}$', '$i_{dc1,2}$'}];
    end
    hold off
    ly('$i/A$'); lx('$t/s$'); grid on
    set(gca, 'xlim', [t1 t2]);
    tl('Magnetizing current (referred to side 1) and side 1 terminal current.');
    lg(leg{:});

    subplot 224
    plot(t(wz), m1(wz, 9)*hwd.udc_nom, '-', 'LineWidth', tratto2, 'Color', colore1); hold on
    plot(t(wz), m1(wz, 10)*hwd.udc_nom, '-', 'LineWidth', tratto1, 'Color', colore2);
    leg = {'$u_{Cr1,1}$', '$u_{Cr2,1}$'};
    if has_m2
        plot(t(wz), m2(wz, 9)*hwd.udc_nom, '--', 'LineWidth', tratto2, 'Color', colore1);
        plot(t(wz), m2(wz, 10)*hwd.udc_nom, '--', 'LineWidth', tratto1, 'Color', colore2);
        leg = [leg, {'$u_{Cr1,2}$', '$u_{Cr2,2}$'}];
    end
    hold off
    ly('$u/V$'); lx('$t/s$'); grid on
    set(gca, 'xlim', [t1 t2]);
    tl('Resonant capacitor voltages.');
    lg(leg{:});
    land();
    eps_out('SST_dcx_zoom');
end

%[text] ## Figure 5: switch losses of module A (leg u)
if exist('mosfet_ploss_invQ1_sim', 'var')
    pq = [sig(mosfet_ploss_invQ1_sim), sig(mosfet_ploss_invQ2_sim), sig(mosfet_ploss_invQ3_sim), sig(mosfet_ploss_invQ4_sim)];
    figure;
    plot(t, pq(:, 1), '-', 'LineWidth', tratto2, 'Color', colore1); hold on
    plot(t, pq(:, 2), '--', 'LineWidth', tratto2, 'Color', colore1);
    plot(t, pq(:, 3), '-', 'LineWidth', tratto1, 'Color', colore2);
    plot(t, pq(:, 4), '--', 'LineWidth', tratto1, 'Color', colore2); hold off
    ly('$p/W$'); lx('$t/s$'); grid on
    set(gca, 'xlim', [t0 t2]);
    tl(sprintf('Module A, leg u: switch losses, mean %.0f / %.0f / %.0f / %.0f W (%s).', mean(pq), ...
        strrep(param.dev.used_device_mosfet, '_', '\_')));
    lg('$Q_1$', '$Q_2$', '$Q_3$', '$Q_4$');
    land();
    eps_out('SST_inv_losses');
end
clear tratto1 tratto2 colore1 colore2 colore3 fontsize_plotting lx ly tl lg land eps_out idx hwd t t0 t1 t2 tg tsw ...
    u_pk_line has_m1 has_m2 m1 m2 leg l1 u_g i_g u_a u_b udc_a wz u_sa i_sa pq

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
