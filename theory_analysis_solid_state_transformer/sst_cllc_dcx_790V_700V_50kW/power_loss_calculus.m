%[text] # power_loss_calculus: check of a CLLC-DCX run against the sizing
% 2026-10-24: SST CLLC-DCX 790 V -> 700 V, 50 kW, 35 kHz (variant of the 800 V -> 800 V, 50 kHz bench). Run after the simulation, or after
% load('sim_results_xx.mat'). Steady-state window: the last n_per periods of the switching frequency.
% Design values from param (cllc_dcx_sizing.md): I1 peak = pi/2 Idc/fn, I1 rms = I1 peak sqrt(fn/2).
% Sign convention of the model: current_battery_1 > 0 when the battery delivers power.
% Works with the current source or the resistor on side 2, with or without the current loop logged.

clc
n_per = 50;                                         % periods in the averaging window
fs = param.glb_time.fPWM_CLLC;
hw = param.cllc.hw;
n12 = hw.n1/hw.n2;
fn = fs/param.cllc.fres;
t = time_tc_sim(:);
w = t >= t(end) - n_per/fs;
tw = t(w);
avg = @(x) mean(x(w));
rms_ = @(x) sqrt(mean(x(w).^2));
pk = @(x) max(abs(x(w)));
fund = @(x) 2*mean(x(w).*exp(-1i*2*pi*fs*tw));     % first harmonic, complex amplitude

%[text] ## DC side
% two benches: battery 2 on side 2 (voltage_battery_2_sim logged) or a load (current source or resistor) through Ldc_dc2
udc_1 = avg(voltage_battery_1_sim);   idc_1 = avg(current_battery_1_sim);
p1 = avg(voltage_battery_1_sim.*current_battery_1_sim);     % delivered by battery 1
p_conv_1 = avg(cllc_voltage_input_modA_sim.*cllc_current_input_modA_sim);
p_conv_2 = avg(cllc_voltage_output_modA_sim.*cllc_current_output_modA_sim);
fprintf('Battery 1: %7.1f V %8.1f A %8.1f kW (delivered)\n', udc_1, idc_1, p1/1e3);
if exist('voltage_battery_2_sim', 'var')
    udc_2 = avg(voltage_battery_2_sim);   idc_2 = avg(current_battery_2_sim);
    p2 = avg(voltage_battery_2_sim.*current_battery_2_sim);     % delivered by battery 2
    fprintf('Battery 2: %7.1f V %8.1f A %8.1f kW (delivered)\n', udc_2, idc_2, p2/1e3);
    fprintf('Voltage ratio udc1/udc2 = %.3f (n = %.3f): %.1f V of mismatch seen from the primary\n', ...
        udc_1/udc_2, n12, udc_1 - n12*udc_2);
    p_out = -p2;
    if sign(p1) == sign(p2)
        fprintf('  <-- both batteries deliver power: no transfer, the converter only dissipates\n');
    end
else
    % load behind Ldc_dc2: its voltage is the DC link 2 voltage minus the drop on RLdc_dc2
    idc_2 = avg(cllc_current_output_modA_sim);
    p_out = p_conv_2 - hw.RLdc_dc2*avg(cllc_current_output_modA_sim.^2);
    udc_2 = avg(cllc_voltage_output_modA_sim) - hw.RLdc_dc2*idc_2;
    fprintf('Load:      %7.1f V %8.1f A %8.1f kW (absorbed, %.3f Ohm)\n', udc_2, idc_2, p_out/1e3, udc_2/idc_2);
    fprintf('Ideal DCX output udc1/n = %.1f V: %.1f V of drop (%.2f %%), R_eq = %.1f mOhm seen from side 2\n', ...
        udc_1/n12, udc_1/n12 - udc_2, 100*(1 - n12*udc_2/udc_1), 1e3*(udc_1/n12 - udc_2)/idc_2);
end
fprintf('DC link 2: mean %.1f V, min %.1f V, max %.1f V\n', avg(cllc_voltage_output_modA_sim), ...
    min(cllc_voltage_output_modA_sim(w)), max(cllc_voltage_output_modA_sim(w)));
p_loss_total = p1 - p_out;
fprintf('Total losses: %.2f kW, efficiency %.2f %% (converter terminals only: %.2f %%)\n', ...
    p_loss_total/1e3, 100*p_out/p1, 100*p_conv_2/p_conv_1);
fprintf('Converter terminals: %.1f kW (side 1), %.1f kW (side 2)\n\n', p_conv_1/1e3, p_conv_2/1e3);

%[text] ## Tank and transformer
i1 = i1_cllc_transformer_modA_sim;  i2 = i2_cllc_transformer_modA_sim;
u1 = u1_cllc_transformer_modA_sim;  u2 = u2_cllc_transformer_modA_sim;
p_scale = max(abs(p_conv_1), 1)/param.cllc.pwr_nom;     % design currents scaled to the actual power
design.i1_pk = pi/2*hw.idc1_nom/fn*p_scale;             % resonant half sine of period 1/fr carrying Idc per half period
design.i1_rms = design.i1_pk*sqrt(fn/2);
design.i2_rms = design.i1_rms*n12;
design.ucr1_pk = design.i1_pk/(2*pi*param.cllc.fres*hw.Cs1);
phi_u = rad2deg(angle(fund(u1)) - angle(fund(u2)));     % lag of u2 on u1
phi_u = mod(phi_u + 180, 360) - 180;
fprintf('%-28s %12s %12s\n', 'quantity', 'simulation', 'design*');
fprintf('%-28s %12.1f %12.1f\n', 'i1 rms / A', rms_(i1), design.i1_rms);
fprintf('%-28s %12.1f %12.1f\n', 'i1 peak / A', pk(i1), design.i1_pk);
fprintf('%-28s %12.1f %12.1f\n', 'i2 rms / A', rms_(i2), design.i2_rms);
fprintf('%-28s %12.1f %12.1f\n', 'u1 fundamental / V', abs(fund(u1)), 4/pi*hw.udc1_nom);
fprintf('%-28s %12.1f %12.1f\n', 'n*u2 fundamental / V', n12*abs(fund(u2)), 4/pi*hw.udc1_nom);
fprintf('%-28s %12.1f %12.1f\n', 'phase lag u2 on u1 / deg', phi_u, 0);
fprintf('%-28s %12.1f %12.1f\n', 'Cr1 peak voltage / V', pk(i1)/(2*pi*fs*hw.Cs1), design.ucr1_pk);
fprintf('* design values of the sizing scaled to the input power (%.1f kW)\n', abs(p_conv_1)/1e3);
fprintf('  (Cr1 voltage estimated from the peak current, the capacitor voltage is not logged)\n\n');
% power balance of the tank: between the u1 and u2 sensors there are only Cs1, the transformer and Cs2,
% so the difference must match Rs1, Rs2 and Rfe. A larger gap is numerical: the Backward Euler local
% solver of Simscape (step h = tc) adds about w^2 L h/2 to each inductor and h/(2 C) to each capacitor.
p_tr_1 = avg(u1.*i1);  p_tr_2 = avg(u2.*i2);
p_tr_phys = hw.Rs1*rms_(i1)^2 + hw.Rs2*rms_(i2)^2 + (abs(fund(u1))/sqrt(2))^2/hw.Rfe;
wh = 2*pi*fs;  h = param.glb_time.tc;
r_num = 2*(wh^2*hw.Ld1*h/2 + h/(2*hw.Cs1));         % both sides, referred to the primary
fprintf('Tank and transformer: %.2f kW lost, physical losses %.2f kW\n', (p_tr_1 - p_tr_2)/1e3, p_tr_phys/1e3);
fprintf('  Backward Euler damping at tc = %.0f ns: about %.3f Ohm on the primary, %.2f kW at this current\n\n', ...
    1e9*h, r_num, r_num*rms_(i1)^2/1e3);

%[text] ## ZVS of the logged switches
% turn-on = falling edge of uds through 10 % of the DC voltage; ZVS when the MOSFET current is <= 0
% there (body diode conducting, the output capacitance already discharged)
zvs_check('Q1', mosfet_zvs_uds_cllc_Q1_sim, mosfet_zvs_ids_cllc_Q1_sim, hw.udc1_nom, w);
zvs_check('Q2', mosfet_zvs_uds_cllc_Q2_sim, mosfet_zvs_ids_cllc_Q2_sim, hw.udc1_nom, w);
zvs_check('Q5', mosfet_zvs_uds_cllc_Q5_sim, mosfet_zvs_ids_cllc_Q5_sim, hw.udc2_nom, w);
zvs_check('Q6', mosfet_zvs_uds_cllc_Q6_sim, mosfet_zvs_ids_cllc_Q6_sim, hw.udc2_nom, w);
fprintf('\n');

%[text] ## Device losses (columns of each switch: 1 loss [W], 2 mean uds, 3 mean ids, ...)
cols = [1 6 11 16];
p_loss_cllc_1 = mean(inverter_1_cllc_mosfet_zvs_modA_sim(w, cols));
p_loss_cllc_2 = mean(inverter_2_cllc_mosfet_zvs_modA_sim(w, cols));
fprintf('Bridge 1 (side 1): %s W, total %.0f W\n', mat2str(round(p_loss_cllc_1)), sum(p_loss_cllc_1));
fprintf('Bridge 2 (side 2): %s W, total %.0f W\n', mat2str(round(p_loss_cllc_2)), sum(p_loss_cllc_2));
fprintf('Sizing: conduction 2 Rds_on I1rms^2 = %.0f W (bridge 1, %.2f mOhm) and %.0f W (bridge 2, %.2f mOhm) at this current\n', ...
    2*param.cllc.mosfet.Rds_on*rms_(i1)^2, 1e3*param.cllc.mosfet.Rds_on, ...
    2*param.cllc.mosfet_sr.Rds_on*rms_(i2)^2, 1e3*param.cllc.mosfet_sr.Rds_on);
fprintf('Devices: bridge 1 %s, bridge 2 %s\n\n', param.dev.used_device_mosfet, param.dev.used_device_mosfet_sr);
p_loss_cllc = sum(p_loss_cllc_1) + sum(p_loss_cllc_2);

%[text] ## Current loop (if logged)
if exist('cllc_current_ctrl_output_sim', 'var')
    uctrl = cllc_current_ctrl_output_sim(:);  iref = cllc_input_current_ref_sim(:);  imeas = cllc_input_current_sim(:);
    fprintf('Current loop (pu of Idc_FS = %.1f A): ref %.3f, meas %.3f, ctrl output %.3f', ...
        hw.Idc_FS, iref(end), imeas(end), uctrl(end));
    if abs(uctrl(end)) > 0.99
        fprintf('  <-- controller saturated, the loop does not regulate\n');
    else
        fprintf('\n');
    end
else
    fprintf('Current loop not logged (open loop, phase displacement 0)\n');
end
clear n_per fs hw n12 fn t w tw avg rms_ pk fund i1 i2 u1 u2 p_scale design phi_u cols uctrl iref imeas wh h r_num

function zvs_check(name, uds, ids, udc, w)
    uds = uds(:); ids = ids(:);
    k = find(w(2:end) & uds(1:end-1) >= 0.1*udc & uds(2:end) < 0.1*udc) + 1;
    if isempty(k)
        fprintf('%s: no turn-on found in the window\n', name); return
    end
    ok = ids(k) <= 0;
    fprintf('%s: %d turn-on, ZVS in %d (%.0f %%), ids at turn-on from %.1f to %.1f A\n', ...
        name, numel(k), sum(ok), 100*mean(ok), min(ids(k)), max(ids(k)));
end
