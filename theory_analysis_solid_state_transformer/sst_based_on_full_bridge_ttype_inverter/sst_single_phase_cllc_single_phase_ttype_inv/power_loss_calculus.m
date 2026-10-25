%[text] # power_loss_calculus: powers, losses and efficiency of the two-module SST
% Rev. 02, 2026-10-24: battery -> 2 x CLLC-DCX (library block cllc_dcx_mod1) -> 2 x single-phase T-type inverter in
% series on the line. Run after the simulation, or after load('sim_results_xx.mat'): averages over the last n_per
% grid periods of the logged window (steady state: the current reference is at 1 pu from 0.85 s). Uses the logs that
% update_sst_cllc_ttype_inv.m adds to storage_data_sst (cllc_dcx_m_mod1/2_sim, battery 2, module B, the four
% switch losses of module A); what is missing is skipped with a note.
% Sign conventions: battery current > 0 when the battery delivers; DCX vector m (pu of p.hw.udc_nom, idc_nom):
% i_dc1 positive into dc1(+), i_dc2 positive out of dc2(+); ac_grid_current as the Current Sensor of line_source
% logs it, so the grid power is printed with its sign and the efficiency uses its absolute value.

clc
n_per = 5;                                              % grid periods in the averaging window
fg = param.grid.f_nom;
t = sig(time_tc_sim);
w = t >= t(end) - n_per/fg;
avg = @(x) mean(x(w, :), 1);
rms_ = @(x) sqrt(mean(x(w, :).^2, 1));
idx = param.cllc.idx;
hwd = param.cllc.p_mod1.hw;                             % both DCX read the same hardware
fs = param.cllc.fpwm;
fprintf('Window: last %d grid periods (%.3f to %.3f s), %d samples at tc = %.0f ns\n\n', n_per, t(find(w, 1)), t(end), ...
    sum(w), param.glb_time.tc*1e9);

%[text] ## Battery side (800 V bus)
u_b1 = sig(voltage_battery_sim);  i_b1 = sig(current_battery_sim);
p_bat = avg(u_b1.*i_b1);
fprintf('Battery 1: %7.1f V %8.1f A %8.2f kW (delivered)\n', avg(u_b1), avg(i_b1), p_bat/1e3);
if exist('voltage_battery_2_sim', 'var')
    u_b2 = sig(voltage_battery_2_sim);  i_b2 = sig(current_battery_2_sim);
    p_bat2 = avg(u_b2.*i_b2);
    fprintf('Battery 2: %7.1f V %8.1f A %8.2f kW (delivered)\n', avg(u_b2), avg(i_b2), p_bat2/1e3);
    p_bat = p_bat + p_bat2;
else
    fprintf('Battery 2 not logged (run update_sst_cllc_ttype_inv): bus power taken as 2 x battery 1\n');
    p_bat = 2*p_bat;
end
fprintf('Bus: %.2f kW delivered by the batteries\n\n', p_bat/1e3);

%[text] ## DCX modules (vector m of the library block)
p_dcx_in = 0;  p_dcx_out = 0;  p_dcx_loss = 0;  p_num = 0;
wh = 2*pi*fs;  h = param.glb_time.tc;
r_num = 2*(wh^2*hwd.Lr1*h/2 + h/(2*hwd.Cr1));            % Backward Euler damping of each tank, referred to side 1
for k = 1:2
    name = sprintf('cllc_dcx_m_mod%d_sim', k);
    if ~exist(name, 'var')
        fprintf('DCX %d: %s not logged (run update_sst_cllc_ttype_inv)\n', k, name);
        continue
    end
    m = sig(eval(name));
    u1 = m(:, 1)*hwd.udc_nom;  i1 = m(:, 2)*hwd.idc_nom;
    u2 = m(:, 3)*hwd.udc_nom;  i2 = m(:, 4)*hwd.idc_nom;
    p_in = avg(u1.*i1);  p_out = avg(u2.*i2);
    p_dcx_in = p_dcx_in + p_in;  p_dcx_out = p_dcx_out + p_out;  p_dcx_loss = p_dcx_loss + p_in - p_out;
    p_num = p_num + r_num*(rms_(m(:, 5))*hwd.idc_nom)^2;    % numerical damping of this tank at its current
    fprintf('DCX %d: side 1 %7.1f V %7.1f A %7.2f kW | side 2 %7.1f V %7.1f A %7.2f kW | loss %6.0f W, eff %.2f %%\n', ...
        k, avg(u1), avg(i1), p_in/1e3, avg(u2), avg(i2), p_out/1e3, p_in - p_out, 100*p_out/max(p_in, 1));
    fprintf('       tank i_r1 %.1f A rms (%.1f A peak), i_r2 %.1f A rms, u_cr1 %.0f V peak, i_m %.1f A peak\n', ...
        rms_(m(:, 5))*hwd.idc_nom, max(abs(m(w, 5)))*hwd.idc_nom, rms_(m(:, 6))*hwd.idc_nom, ...
        max(abs(m(w, 9)))*hwd.udc_nom, max(abs(m(w, 13)))*hwd.idc_nom);
    fprintf('       drop u_dc1 - n u_dc2 = %.1f V (%.3f Ohm seen from side 2 at %.1f A; Backward Euler alone: %.3f Ohm, %.0f W at this tank current)\n', ...
        avg(u1) - hwd.n1/hwd.n2*avg(u2), (avg(u1)*hwd.n2/hwd.n1 - avg(u2))/max(abs(avg(i2)), 1e-3), avg(i2), ...
        r_num, r_num*(rms_(m(:, 5))*hwd.idc_nom)^2);
    lname = sprintf('cllc_dcx_ctrl_log_mod%d_sim', k);
    if exist(lname, 'var')
        l = sig(eval(lname));
        fprintf('       control: mode %d, enable %d, f_c %.1f kHz, phi %.3f rad, i_dc2 acquired %.3f pu\n', ...
            l(end, idx.mode), l(end, idx.enable), l(end, idx.f_c)/1e3, l(end, idx.phi), l(end, idx.i_dc2));
    end
end
fprintf('\n');

%[text] ## Inverters and line
udc_a = sig(dclink_voltage_modA_sim);
fprintf('DC link A: mean %.1f V, ripple %.1f V peak-peak (%.1f %%)\n', avg(udc_a), max(udc_a(w)) - min(udc_a(w)), ...
    100*(max(udc_a(w)) - min(udc_a(w)))/avg(udc_a));
if exist('dclink_inverter_modB_sim', 'var')
    udc_b = sig(dclink_inverter_modB_sim);
    fprintf('DC link B: mean %.1f V, ripple %.1f V peak-peak\n', avg(udc_b), max(udc_b(w)) - min(udc_b(w)));
end
u_a = sig(afe_voltage_output_modA_sim);  i_a = sig(afe_current_output_modA_sim);
p_mod_a = avg(u_a.*i_a);
fprintf('Module A output: %.1f V rms, %.1f A rms, %.2f kW\n', rms_(u_a), rms_(i_a), p_mod_a/1e3);
p_mod = p_mod_a;
if exist('afe_voltage_output_modB_sim', 'var')
    u_b = sig(afe_voltage_output_modB_sim);
    if exist('afe_current_output_modB_sim', 'var')
        i_b = sig(afe_current_output_modB_sim);
    else
        i_b = i_a;                                      % series connection: the same current
    end
    p_mod_b = avg(u_b.*i_b);
    fprintf('Module B output: %.1f V rms, %.1f A rms, %.2f kW\n', rms_(u_b), rms_(i_b), p_mod_b/1e3);
    p_mod = p_mod + p_mod_b;
else
    fprintf('Module B output not logged (run update_sst_cllc_ttype_inv): taken as module A\n');
    p_mod = 2*p_mod;
end
u_g = sig(ac_grid_voltage_sim);  i_g = sig(ac_grid_current_sim);
p_grid = avg(u_g.*i_g);
s_grid = rms_(u_g)*rms_(i_g);
fprintf('Line: %.1f V rms (%.1f V nominal), %.1f A rms (%.1f A nominal), P = %.2f kW (sign as logged), PF = %.3f\n', ...
    rms_(u_g), param.grid.u_rms, rms_(i_g), param.grid.i_nom, p_grid/1e3, abs(p_grid)/max(s_grid, 1));
fprintf('Line current: %.3f pu of ibez (reference %.2f pu on module A)\n\n', sqrt(2)*rms_(i_g)/param.spinv.hw.ibez, param.spinv.i_ref);

%[text] ## T-type devices of module A (leg u, Gotos of "single phase afe/references")
if exist('mosfet_ploss_invQ1_sim', 'var')
    p_q = [avg(sig(mosfet_ploss_invQ1_sim)), avg(sig(mosfet_ploss_invQ2_sim)), ...
           avg(sig(mosfet_ploss_invQ3_sim)), avg(sig(mosfet_ploss_invQ4_sim))];
    fprintf('Leg u of module A: Q1 %.0f W, Q2 %.0f W, Q3 %.0f W, Q4 %.0f W, %.0f W per leg\n', p_q, sum(p_q));
    p_inv_est = 2*2*sum(p_q);                           % two legs per module, two modules with the same current
    fprintf('Estimate for the two inverters (2 legs x 2 modules): %.2f kW (device %s)\n\n', p_inv_est/1e3, ...
        param.dev.used_device_mosfet);
else
    p_inv_est = NaN;
    fprintf('Switch losses not logged (run update_sst_cllc_ttype_inv)\n\n');
end

%[text] ## Balance
fprintf('%-34s %9.2f kW\n', 'Batteries', p_bat/1e3);
fprintf('%-34s %9.2f kW\n', 'DCX inputs (2 modules)', p_dcx_in/1e3);
fprintf('%-34s %9.2f kW\n', 'DCX outputs', p_dcx_out/1e3);
fprintf('%-34s %9.2f kW\n', 'Module outputs (after the filters)', p_mod/1e3);
fprintf('%-34s %9.2f kW\n', 'Line', abs(p_grid)/1e3);
fprintf('%-34s %9.0f W  (Backward Euler damping alone about %.0f W)\n', 'DCX losses', p_dcx_loss, p_num);
fprintf('%-34s %9.0f W\n', 'Inverters + DC links + filters', p_dcx_out - abs(p_grid));
if ~isnan(p_inv_est)
    fprintf('%-34s %9.0f W\n', '  of which switches (estimate)', p_inv_est);
end
fprintf('%-34s %9.2f %%\n', 'Efficiency battery -> line', 100*abs(p_grid)/max(p_bat, 1));
clear n_per fg t w avg rms_ idx hwd fs wh h r_num p_num u_b1 i_b1 u_b2 i_b2 p_bat2 k name m u1 i1 u2 i2 p_in p_out lname l ...
    udc_a udc_b u_a i_a u_b i_b p_mod_a p_mod_b u_g i_g s_grid p_q

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
