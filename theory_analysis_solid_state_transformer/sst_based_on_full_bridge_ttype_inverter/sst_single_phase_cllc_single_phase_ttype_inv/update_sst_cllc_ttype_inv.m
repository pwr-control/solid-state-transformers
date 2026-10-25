function update_sst_cllc_ttype_inv(mode)
%UPDATE_SST_CLLC_TTYPE_INV  Fix sst_cllc_ttype_inv.slx after the change to the library CLLC-DCX blocks (2026-10-24).
%
%   update_sst_cllc_ttype_inv             fixes only: the model keeps reading the legacy flat names, which
%                                         private/sst_cllc_ttype_legacy.m exports while
%                                         param.sim.export_legacy_names = 1 in init_model.m
%   update_sst_cllc_ttype_inv('migrate')  fixes, then every legacy name in the model rewritten to param.*
%                                         (afterwards set param.sim.export_legacy_names = 0 in init_model.m and
%                                         delete private/sst_cllc_ttype_legacy.m)
%
%   Run from this folder, after init_model (param in the base workspace; the function runs init_model by itself
%   when param is missing). Idempotent: what is already right is left alone, so it can be run again after a change
%   of the model. The model is saved at the end: open it, check the Diagnostic Viewer, simulate, commit the .slx.
%
%   What it does (the model of 2026-10-24 has the old CLLC stage replaced by two library blocks cllc_dcx/cllc_dcx_mod1
%   inside the wrappers cllc_dcx_mod1 and cllc_dcx_mod2, but the rest of the diagram was not updated):
%     1. mask parameter p of the two DCX blocks: param.cllc.p_mod1 / param.cllc.p_mod2 (the model has
%        cllc_dcx_param_example() in both, whose p.pwm.tc = 50 ns is not the solver step: a 50 ns block in a 500 ns
%        fixed-step model does not compile, and the two carriers could not be interleaved)
%     2. battery_2 aligned to battery_1: ts_battery = glb_time.ts_dab (was ts_cllc), battery_voltage_init_m =
%        param.battery.nominal_battery_voltage_2 (was ..._1); the masks of both read C1 of the pack as it is (the
%        /100 of battery_1 is in private/sst_cllc_ttype_setup.m)
%     3. scopes of the removed stage deleted: scopes_dcdc_modA, scopes_dcdc_modB, "CLLCs input current/voltage",
%        "CLLCs output current/voltage", "dcdc input/output voltages"
%     4. every From block whose tag has no Goto left in the model (cllc_* and *_cllc_transformer_* signals of the
%        old stage in storage_data_sst and scopes, inverter_*_cllc_mosfet_zvs_*, CFi_dc1/2_current_modA,
%        local_time_corr_* of global timing): deleted with its line; a To Workspace or Terminator fed by it only
%        goes too (12 stale To Workspace pairs, the two commented modB ones included); any other destination gets a
%        Ground block in its place, so no input is left unconnected
%     5. storage_data_sst: afe_us_modA renamed afe_us_modA_sim; new From -> To Workspace pairs for the outputs of
%        the DCX blocks, cllc_dcx_m_mod1_sim / _mod2_sim ([Nc x 15] measurements of the power stage, pu) and
%        cllc_dcx_ctrl_log_mod1_sim / _mod2_sim ([Nc x 24], indices in param.cllc.idx); for module B
%        afe_voltage_output_modB_sim, afe_current_output_modB_sim, afe_us_modB_sim; for battery_2 voltage_battery_2_sim,
%        current_battery_2_sim; for the T-type bridge of module A (leg u, Gotos of "single phase afe/references")
%        mosfet_ploss_invQ1_sim .. mosfet_ploss_invQ4_sim. SaveFormat Array on every To Workspace of the subsystem
%        (the scripts of this folder index the logs as arrays)
%     6. current reference of module A (inverter_current_output_pu_reference): Step time param.spinv.t_ref, after
%        param.spinv.i_ref; Rate Limiter +/- param.spinv.i_ref_slew; the Constant of module B param.spinv.i_ref
%        (module B applies the voltage command of module A, the constant is kept for its own loop)
%     7. 'migrate' only: every parameter of every block (masks and library instances included) and the solver
%        settings of the model (StopTime, FixedStep, MaxStep) rewritten with the table of legacy_table (same
%        table as private/sst_cllc_ttype_legacy.m), whole names only, names already param.* untouched
%   Not touched: the library blocks inside (links), the control, the wiring of the power stage, the configuration
%   set apart from the three solver parameters of 'migrate'.

    if nargin < 1 || isempty(mode)
        mode = 'fix';
    end
    migrate = strcmpi(mode, 'migrate');
    assert(migrate || strcmpi(mode, 'fix'), 'update_sst_cllc_ttype_inv: mode is ''fix'' or ''migrate''');
    mdl = 'sst_cllc_ttype_inv';

    % param in the base workspace: the masks evaluate there
    if ~evalin('base', 'exist(''param'', ''var'')')
        fprintf('%s: param not found in the base workspace, running init_model first\n', mfilename);
        evalin('base', 'init_model');
    end
    load_system(mdl);
    n = 0;
    fprintf('%s: mode %s\n', mfilename, mode);

    % ---- 1. DCX blocks: mask parameter p
    dcx = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'IncludeCommented', 'on', ...
        'ReferenceBlock', 'cllc_dcx/cllc_dcx_mod1');
    assert(numel(dcx) == 2, '%s: %d blocks cllc_dcx/cllc_dcx_mod1 found, 2 expected', mfilename, numel(dcx));
    for k = 1:numel(dcx)
        if contains(get_param(dcx{k}, 'Parent'), 'mod2')
            n = n + set_once(dcx{k}, 'p', 'param.cllc.p_mod2');
        else
            n = n + set_once(dcx{k}, 'p', 'param.cllc.p_mod1');
        end
    end

    % ---- 2. batteries: same settings on both, pack values as they are
    for k = 1:2
        blk = sprintf('%s/battery_%d/lithium_ion_battery', mdl, k);
        if migrate
            pack = sprintf('param.battery.pack_%d', k);
            ts_name = 'param.glb_time.ts_dab';
        else
            pack = sprintf('lithium_ion_battery_%d', k);
            ts_name = 'glb_time.ts_dab';
        end
        n = n + set_once(blk, 'C1', [pack '.C1']);
        n = n + set_once(blk, 'ts_battery', ts_name);
        n = n + set_once(blk, 'battery_voltage_init_m', sprintf('param.battery.nominal_battery_voltage_%d', k));
    end

    % ---- 3. scopes of the removed stage ("/" inside a block name is written "//" in the path)
    stale = {[mdl '/scopes/scopes_dcdc_modA'], [mdl '/scopes/scopes_dcdc_modB'], ...
        [mdl '/scopes/CLLCs input current//voltage'], [mdl '/scopes/CLLCs output current//voltage'], ...
        [mdl '/scopes/dcdc input//output voltages']};
    for k = 1:numel(stale)
        if getSimulinkBlockHandle(stale{k}) ~= -1
            delete_with_lines(stale{k});
            fprintf('  deleted %s\n', stale{k});
            n = n + 1;
        end
    end

    % ---- 4. From blocks whose tag has no Goto anywhere in the model
    gotos = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'IncludeCommented', 'on', 'BlockType', 'Goto');
    goto_tags = unique(cellfun(@(b) get_param(b, 'GotoTag'), gotos, 'UniformOutput', false));
    froms = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'off', 'IncludeCommented', 'on', 'BlockType', 'From');
    for k = 1:numel(froms)
        if getSimulinkBlockHandle(froms{k}) == -1          % already gone with a scope of step 3
            continue
        end
        if ~any(strcmp(get_param(froms{k}, 'GotoTag'), goto_tags))
            n = n + remove_dangling_from(froms{k});
        end
    end

    % ---- 5. storage_data_sst
    sto = [mdl '/storage_data_sst'];
    tw = find_system(sto, 'SearchDepth', 1, 'BlockType', 'ToWorkspace', 'VariableName', 'afe_us_modA');
    for k = 1:numel(tw)
        n = n + set_once(tw{k}, 'VariableName', 'afe_us_modA_sim');
    end
    new_logs = {'cllc_dcx_m_mod1', 'cllc_dcx_m_mod2', 'cllc_dcx_ctrl_log_mod1', 'cllc_dcx_ctrl_log_mod2', ...
        'afe_voltage_output_modB', 'afe_current_output_modB', 'afe_us_modB', 'voltage_battery_2', 'current_battery_2', ...
        'mosfet_ploss_invQ1', 'mosfet_ploss_invQ2', 'mosfet_ploss_invQ3', 'mosfet_ploss_invQ4'};
    if migrate
        pre = 'param.glb_time.';
    else
        pre = 'glb_time.';
    end
    tws = find_system(sto, 'SearchDepth', 1, 'BlockType', 'ToWorkspace');
    vars = cellfun(@(b) get_param(b, 'VariableName'), tws, 'UniformOutput', false);
    blks = setdiff(find_system(sto, 'SearchDepth', 1, 'Type', 'block'), {sto});
    y = 0;
    for k = 1:numel(blks)
        pos = get_param(blks{k}, 'Position');
        y = max(y, pos(4));
    end
    for k = 1:numel(new_logs)
        tag = new_logs{k};
        v = [tag '_sim'];
        if any(strcmp(v, vars))
            continue
        end
        y = y + 45;
        f = add_block('simulink/Signal Routing/From', [sto '/From_' tag], 'MakeNameUnique', 'on', ...
            'GotoTag', tag, 'Position', [40 y 190 y + 20]);
        w = add_block('simulink/Sinks/To Workspace', [sto '/' tag '_sim'], 'MakeNameUnique', 'on', ...
            'VariableName', v, 'Position', [260 y 420 y + 20]);
        set_param(w, 'MaxDataPoints', [pre 'Nc'], 'Decimation', [pre 'decimation_tc'], 'SampleTime', [pre 'tc']);
        fp = get_param(f, 'PortHandles');
        wp = get_param(w, 'PortHandles');
        add_line(sto, fp.Outport(1), wp.Inport(1));
        fprintf('  added From %s -> To Workspace %s\n', tag, v);
        n = n + 1;
    end
    tws = find_system(sto, 'SearchDepth', 1, 'IncludeCommented', 'on', 'BlockType', 'ToWorkspace');
    for k = 1:numel(tws)
        try
            n = n + set_once(tws{k}, 'SaveFormat', 'Array');
        catch ME
            fprintf('  !! %s: SaveFormat not set (%s)\n', tws{k}, ME.message);
        end
    end

    % ---- 6. current reference of the two modules
    ref_a = [mdl '/single_phase_inverter_modA/single phase inverter control/inverter_current_output_pu_reference'];
    if getSimulinkBlockHandle([ref_a '/Step']) ~= -1
        n = n + set_once([ref_a '/Step'], 'Time', 'param.spinv.t_ref');
        n = n + set_once([ref_a '/Step'], 'Before', '0');
        n = n + set_once([ref_a '/Step'], 'After', 'param.spinv.i_ref');
    else
        fprintf('  !! %s/Step not found, current reference of module A not set\n', ref_a);
    end
    if getSimulinkBlockHandle([ref_a '/Rate Limiter']) ~= -1
        n = n + set_once([ref_a '/Rate Limiter'], 'RisingSlewLimit', 'param.spinv.i_ref_slew');
        n = n + set_once([ref_a '/Rate Limiter'], 'FallingSlewLimit', '-param.spinv.i_ref_slew');
    end
    ref_b = [mdl '/single_phase_inverter_modB/single phase inverter control/inverter_current_output_pu_reference/Constant'];
    if getSimulinkBlockHandle(ref_b) ~= -1
        n = n + set_once(ref_b, 'Value', 'param.spinv.i_ref');
    end

    % ---- 7. migration of the legacy names
    if migrate
        n_mig = 0;
        skip = {'GotoTag', 'VariableName', 'Name', 'Description', 'Tag', 'AttributesFormatString', 'MaskDisplay', ...
            'Priority', 'BlockType', 'Parent', 'Position', 'Orientation', 'ForegroundColor', 'BackgroundColor', ...
            'SampleTimeDisplay', 'ReferenceBlock', 'SourceBlock', 'SourceType', 'InitialBlockCM', 'OutputSignalNames', ...
            'InputSignalNames', 'SignalName'};
        blks = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'off', 'IncludeCommented', 'on', 'Type', 'block');
        for k = 1:numel(blks)
            dp = get_param(blks{k}, 'DialogParameters');
            if ~isstruct(dp)
                continue
            end
            names = fieldnames(dp);
            for j = 1:numel(names)
                if any(strcmp(names{j}, skip))
                    continue
                end
                try
                    v = get_param(blks{k}, names{j});
                catch
                    continue
                end
                if ~ischar(v) || isempty(v)
                    continue
                end
                v2 = legacy_to_param(v);
                if ~strcmp(v, v2)
                    try
                        set_param(blks{k}, names{j}, v2);
                        n_mig = n_mig + 1;
                    catch ME
                        fprintf('  !! %s | %s: ''%s'' -> ''%s'' not set (%s)\n', blks{k}, names{j}, v, v2, ME.message);
                    end
                end
            end
        end
        % solver settings of the active configuration
        n_mig = n_mig + set_once(mdl, 'StopTime', 'param.sim.simlength');
        n_mig = n_mig + set_once(mdl, 'FixedStep', 'param.glb_time.tc');
        n_mig = n_mig + set_once(mdl, 'MaxStep', 'param.glb_time.tc');
        fprintf(['  migration: %d parameters rewritten to param.*; set param.sim.export_legacy_names = 0 in init_model.m ' ...
            'and delete private/sst_cllc_ttype_legacy.m\n'], n_mig);
        n = n + n_mig;
    end

    % ---- save
    if n > 0
        save_system(mdl);
        fprintf('%s: %d changes, %s.slx saved. Open the model, check the Diagnostic Viewer and simulate.\n', mfilename, n, mdl);
    else
        fprintf('%s: nothing to change.\n', mfilename);
    end
end

function n = set_once(blk, prm, val)
%SET_ONCE  set_param when the value differs; returns 1 when something was written
    cur = get_param(blk, prm);
    if ischar(cur) && strcmp(cur, val)
        n = 0;
    else
        set_param(blk, prm, val);
        fprintf('  %s | %s = %s\n', blk, prm, val);
        n = 1;
    end
end

function delete_with_lines(blk)
%DELETE_WITH_LINES  delete a block with every line attached to its ports
    ph = get_param(blk, 'PortHandles');
    ports = [ph.Inport, ph.Outport, ph.Enable, ph.Trigger, ph.Ifaction, ph.LConn, ph.RConn];
    for k = 1:numel(ports)
        l = get_param(ports(k), 'Line');
        if l ~= -1
            delete_line(l);
        end
    end
    delete_block(blk);
end

function n = remove_dangling_from(f)
%REMOVE_DANGLING_FROM  From block whose tag has no Goto: deleted with its line; a To Workspace or Terminator fed
%   by it only goes too; any other destination gets a Ground block in its place
    tag = get_param(f, 'GotoTag');
    sys = get_param(f, 'Parent');
    pos = get_param(f, 'Position');
    ph = get_param(f, 'PortHandles');
    l = get_param(ph.Outport(1), 'Line');
    n = 1;
    if l == -1
        delete_block(f);
        fprintf('  deleted From ''%s'' in %s (no Goto, no line)\n', tag, sys);
        return
    end
    dst_blk = get_param(l, 'DstBlockHandle');
    dst_prt = get_param(l, 'DstPortHandle');
    keep = dst_blk > 0;
    dst_blk = dst_blk(keep);
    dst_prt = dst_prt(keep);
    delete_line(l);
    delete_block(f);
    for j = 1:numel(dst_blk)
        bt = get_param(dst_blk(j), 'BlockType');
        name = get_param(dst_blk(j), 'Name');
        if any(strcmp(bt, {'ToWorkspace', 'Terminator'}))
            delete_block(dst_blk(j));
            fprintf('  deleted From ''%s'' and %s ''%s'' in %s (no Goto)\n', tag, bt, name, sys);
        else
            g = add_block('simulink/Sources/Ground', [sys '/Ground_' tag], 'MakeNameUnique', 'on', 'Position', pos);
            gp = get_param(g, 'PortHandles');
            add_line(sys, gp.Outport(1), dst_prt(j), 'autorouting', 'on');
            fprintf('  deleted From ''%s'' in %s (no Goto): Ground in its place at %s ''%s''\n', tag, sys, bt, name);
        end
    end
end

function v2 = legacy_to_param(v)
%LEGACY_TO_PARAM  rewrite the legacy flat names of a parameter string to param.* (whole names only)
    tbl = legacy_table();
    v2 = v;
    for k = 1:size(tbl, 1)
        v2 = regexprep(v2, tbl{k, 1}, tbl{k, 2});
    end
end

function tbl = legacy_table()
%LEGACY_TABLE  legacy name (regular expression) -> param.* name; the same table as private/sst_cllc_ttype_legacy.m.
%   nb: not preceded by a word character or a dot (a name already under param.* is left alone); ne: whole name.
    nb = '(?<![\w.])';
    ne = '(?![\w.])';
    tbl = { ...
        [nb 'hwdata\.single_phase_inverter\.'],     'param.spinv.hw.'; ...
        [nb 'hwdata\.cllc\.udc1_(bez|nom)' ne],     'param.cllc.udc1_nom'; ...
        [nb 'hwdata\.cllc\.udc2_(bez|nom)' ne],     'param.cllc.udc2_nom'; ...
        [nb 'glb_time\.'],                          'param.glb_time.'; ...
        [nb 'mosfet\.inv\.'],                       'param.spinv.mosfet.'; ...
        [nb 'ideal_switch\.'],                      'param.spinv.ideal_switch.'; ...
        [nb 'heatsink\.'],                          'param.thermal.heatsink.'; ...
        [nb 'lithium_ion_battery_1\.'],             'param.battery.pack_1.'; ...
        [nb 'lithium_ion_battery_2\.'],             'param.battery.pack_2.'; ...
        [nb 'single_phase_inverter_ctrl\.'],        'param.spinv.ctrl.'; ...
        [nb 'afe_ctrl\.di_obs\.'],                  'param.spinv.ctrl.di_obs.'; ...
        [nb 'sogi\.'],                              'param.spinv.sogi.'; ...
        [nb 'grid_emu\.u2bez' ne],                  'param.grid.u_pk_module'; ...
        [nb 'grid_emu\.omega_grid_nom' ne],         'param.grid.omega_nom'; ...
        [nb 'grid_emu\.trafo\.Ld2' ne],             'param.grid.L_line'; ...
        [nb 'grid_emu\.trafo\.Rd2' ne],             'param.grid.R_line'; ...
        [nb 'omega_set' ne],                        'param.grid.omega_nom'; ...
        [nb 'sst_num_of_modules' ne],               'param.sst.n_modules'; ...
        [nb 'adc12_quantization' ne],               'param.meas.adc12_quantization'; ...
        [nb 'adc11_quantization' ne],               'param.meas.adc11_quantization'; ...
        [nb 'CTRPIFF_CLIP_RELEASE' ne],             'param.ctrl.clip_release'; ...
        [nb 'nonlinear_iterations' ne],             'param.sim.nonlinear_iterations'; ...
        [nb 'simlength' ne],                        'param.sim.simlength'; ...
        [nb 'tc' ne],                               'param.glb_time.tc'};
end
