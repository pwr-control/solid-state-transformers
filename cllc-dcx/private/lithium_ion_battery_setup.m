function data = lithium_ion_battery_setup(nominal_voltage, nominal_power, charge_capacity, soc_init, ts)
%LITHIUM_ION_BATTERY_SETUP  Local copy for single_phase_cllc (resonant_cllc/private).
%
%   Copied on 2026-09-30 from library/setup_files/batteries_initialization/lithium_ion_battery_setup.m
%   (five-argument signature: the charge capacity [Ah] is the third argument).
%   Changes with respect to the library version: none. This copy freezes the function for this model:
%   a later change of the library one (as the signature change that broke the legacy init) does not
%   reach single_phase_cllc. Being in ./private it is seen only by the files of resonant_cllc, and
%   init_model.m prints the list of such overrides at every run.

    data.ubattery = nominal_voltage;
    data.pnom = nominal_power;
    data.nominal_current = data.pnom/data.ubattery;
    data.nominal_efficiency = 0.95;

    data.typical_cell_voltage = 3.6;
    data.number_of_cells = floor(nominal_voltage/data.typical_cell_voltage)-1; % nominal is 100

    % stato of charge init
    data.soc_init = soc_init;

    data.R = 8.3143;
    data.F = 96487;
    data.T = 273.15+40;
    data.Q = charge_capacity; %Hr*A

    data.Vbattery_nom = data.ubattery;
    data.Pbattery_nom = data.pnom;
    data.Ibattery_nom = data.Pbattery_nom/data.Vbattery_nom;
    data.Rmax = data.Vbattery_nom^2/(data.Pbattery_nom*0.1);
    data.Rmin = data.Vbattery_nom^2/(data.Pbattery_nom);

    data.E_1 = -1.031;
    data.E0 = 3.485;
    data.E1 = 0.2156;
    data.E2 = 0;
    data.E3 = 0;
    data.Elog = -0.05;
    data.alpha = 35;

    data.R0 = 1/2 * data.pnom*(1-data.nominal_efficiency)/data.nominal_current^2;
    data.R1 = data.R0;
    data.C1 = 0.5;
    data.M = 125;

    data.q1Kalman = ts^2;
    data.q2Kalman = ts^1;
    data.q3Kalman = 0;
    data.rKalman = 1;

    Zmodel = (0:1e-3:1);
    data.ocv_model = data.E_1*exp(-Zmodel*data.alpha) + data.E0 + data.E1*Zmodel + data.E2*Zmodel.^2 +...
        data.E3*Zmodel.^3 + data.Elog*log(1-Zmodel+ts);
    figure;
    plot(Zmodel,data.ocv_model,'LineWidth',2);
    xlabel('state of charge [p.u.]');
    ylabel('open circuit voltage [V]');
    title('open circuit voltage(state of charge)');
    grid on

end
