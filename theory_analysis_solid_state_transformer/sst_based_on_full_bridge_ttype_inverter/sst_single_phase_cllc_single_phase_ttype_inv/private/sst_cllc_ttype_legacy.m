function sst_cllc_ttype_legacy(param)
%SST_CLLC_TTYPE_LEGACY  Flat names of the old init in the base workspace, as sst_cllc_ttype_inv.slx still reads them.
%
%   sst_cllc_ttype_legacy(param)
%
%   Called by init_model.m while param.sim.export_legacy_names = 1. update_sst_cllc_ttype_inv('migrate') rewrites
%   every name of the left column in the model with the param.* name of the right column (same table in that
%   file): afterwards set param.sim.export_legacy_names = 0 in init_model.m and delete this file.
%   Being in ./private it is seen only by the files of this folder.

    v.glb_time = param.glb_time;                                % glb_time.*                -> param.glb_time.*
    v.simlength = param.sim.simlength;                          % simlength (StopTime)      -> param.sim.simlength
    v.tc = param.glb_time.tc;                                   % tc (FixedStep)            -> param.glb_time.tc
    v.nonlinear_iterations = param.sim.nonlinear_iterations;    % nonlinear_iterations      -> param.sim.nonlinear_iterations
    v.hwdata.single_phase_inverter = param.spinv.hw;            % hwdata.single_phase_inverter.* -> param.spinv.hw.*
    v.hwdata.cllc.udc1_nom = param.cllc.udc1_nom;               % hwdata.cllc.udc1_bez/nom  -> param.cllc.udc1_nom
    v.hwdata.cllc.udc1_bez = param.cllc.udc1_nom;
    v.hwdata.cllc.udc2_nom = param.cllc.udc2_nom;               % hwdata.cllc.udc2_bez/nom  -> param.cllc.udc2_nom
    v.hwdata.cllc.udc2_bez = param.cllc.udc2_nom;
    v.mosfet.inv = param.spinv.mosfet;                          % mosfet.inv.*              -> param.spinv.mosfet.*
    v.ideal_switch = param.spinv.ideal_switch;                  % ideal_switch.*            -> param.spinv.ideal_switch.*
    v.heatsink = param.thermal.heatsink;                        % heatsink.*                -> param.thermal.heatsink.*
    v.lithium_ion_battery_1 = param.battery.pack_1;             % lithium_ion_battery_1.*   -> param.battery.pack_1.*
    v.lithium_ion_battery_2 = param.battery.pack_2;             % lithium_ion_battery_2.*   -> param.battery.pack_2.*
    v.single_phase_inverter_ctrl = param.spinv.ctrl;            % single_phase_inverter_ctrl.* -> param.spinv.ctrl.*
    v.afe_ctrl.di_obs = param.spinv.ctrl.di_obs;                % afe_ctrl.di_obs.*         -> param.spinv.ctrl.di_obs.*
    v.sogi = param.spinv.sogi;                                  % sogi.flt.beta             -> param.spinv.sogi.flt.beta
    v.grid_emu.u2bez = param.grid.u_pk_module;                  % grid_emu.u2bez            -> param.grid.u_pk_module
    v.grid_emu.omega_grid_nom = param.grid.omega_nom;           % grid_emu.omega_grid_nom   -> param.grid.omega_nom
    v.grid_emu.trafo.Ld2 = param.grid.L_line;                   % grid_emu.trafo.Ld2        -> param.grid.L_line
    v.grid_emu.trafo.Rd2 = param.grid.R_line;                   % grid_emu.trafo.Rd2        -> param.grid.R_line
    v.omega_set = param.grid.omega_nom;                         % omega_set                 -> param.grid.omega_nom
    v.sst_num_of_modules = param.sst.n_modules;                 % sst_num_of_modules        -> param.sst.n_modules
    v.adc12_quantization = param.meas.adc12_quantization;       % adc12_quantization        -> param.meas.adc12_quantization
    v.adc11_quantization = param.meas.adc11_quantization;       % adc11_quantization        -> param.meas.adc11_quantization
    v.CTRPIFF_CLIP_RELEASE = param.ctrl.clip_release;           % CTRPIFF_CLIP_RELEASE      -> param.ctrl.clip_release

    names = fieldnames(v);
    for k = 1:numel(names)
        assignin('base', names{k}, v.(names{k}));
    end
end
