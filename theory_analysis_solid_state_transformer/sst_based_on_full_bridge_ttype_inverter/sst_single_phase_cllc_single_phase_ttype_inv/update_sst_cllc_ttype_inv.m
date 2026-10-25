function update_sst_cllc_ttype_inv(mode)
%UPDATE_SST_CLLC_TTYPE_INV  Fix sst_cllc_ttype_inv.slx after the changes to the library blocks (DCX 2026-10-24, AFE 2026-10-25).
%
%   update_sst_cllc_ttype_inv             'fix': the old T-type modules single_phase_inverter_modA/B active and the
%                                         wrappers of the compact modules single_phase_inverter_modA_cmp/modB_cmp
%                                         commented out; the model keeps reading the legacy flat names, which
%                                         private/sst_cllc_ttype_legacy.m exports while
%                                         param.sim.export_legacy_names = 1 in init_model.m
%   update_sst_cllc_ttype_inv('compact')  the compact modules (library block afe_single_phase_ttype/
%                                         afe_single_phase_ttype_mod1, power stage in Simscape language and control
%                                         in a MATLAB Function) in place of the old modules, which are deleted: step 4
%   update_sst_cllc_ttype_inv('migrate')  fixes, then every legacy name in the model rewritten to param.*
%                                         (afterwards set param.sim.export_legacy_names = 0 in init_model.m and
%                                         delete private/sst_cllc_ttype_legacy.m)
%
%   Run from this folder, after init_model (param in the base workspace; the function runs init_model by itself
%   when param is missing). Idempotent: what is already right is left alone, so it can be run again after a change
%   of the model. The model is saved at the end: open it, check the Diagnostic Viewer, simulate, commit the .slx.
%
%   What it does:
%     1. mask parameter p of the two DCX blocks: param.cllc.p_mod1 / param.cllc.p_mod2 (the model had
%        cllc_dcx_param_example() in both, whose p.pwm.tc = 50 ns is not the solver step: a 50 ns block in a 500 ns
%        fixed-step model does not compile, and the two carriers could not be interleaved)
%     2. battery_2 aligned to battery_1: ts_battery = glb_time.ts_dab (was ts_cllc), battery_voltage_init_m =
%        param.battery.nominal_battery_voltage_2 (was ..._1); the masks of both read C1 of the pack as it is (the
%        /100 of battery_1 is in private/sst_cllc_ttype_setup.m)
%     3. scopes of the removed CLLC stage deleted: scopes_dcdc_modA, scopes_dcdc_modB, "CLLCs input current/voltage",
%        "CLLCs output current/voltage", "dcdc input/output voltages"
%     4. compact modules. The model of 2026-10-25 has the wrappers single_phase_inverter_modA_cmp and modB_cmp around
%        the library block, both with the default mask afe_single_phase_ttype_param_example() (tc = 500 ns, not the
%        solver step; no slave), modA_cmp connected to nothing (a physical network without Solver Configuration),
%        modB_cmp in parallel with the old module B, the sync input of the master open, m and ctrl_log not logged, the
%        old modules and storage_data_sst commented out. Done in both modes:
%        - mask p = param.spinv.p_modA / p_modB (built in private/sst_cllc_ttype_setup.m from the numbers of the bench,
%          tc of the run, module B slave of module A), the blocks renamed afe_single_phase_ttype_modA / modB
%        - inside the wrappers: Ground on the sync input of A (a master reads no sync), From synch_AFE_mtos on the
%          sync input of B and Goto synch_AFE_mtos on the sync_out of A when missing, Terminator on the sync_out of B,
%          Gotos afe_cmp_m_modA/B and afe_cmp_ctrl_log_modA/B on the outputs m and ctrl_log
%        - root wiring of the active pair of modules: DC link on side 2 of cllc_dcx_mod1/2, AC sides in series with
%          line_source (u1 - module A - module B - u2); the ports of the inactive pair isolated
%        - storage_data_sst un-commented
%        'fix' (old modules present): the old modules active, the wrappers commented out. 'compact': the wrappers
%        active, the old modules deleted with their lines, scopes/scopes_inv_modA (device currents, voltages,
%        temperatures: the compact block has no switching loss nor thermal model) deleted, and in each wrapper the
%        Gain m_to_legacy (param.spinv.m_to_legacy_modA/B, [5 x 13]) with a Demux and five Gotos rebuilds the old
%        log tags in physical units from m: afe_current_output_modX [A], afe_voltage_output_modX [V], afe_is_modX [A],
%        afe_us_modX [V], dclink_voltage_modX [V], so that storage_data_sst, the scopes and the scripts of this folder
%        keep working. Once the old modules are gone, every mode keeps the compact ones active.
%     5. every From block whose tag has no Goto left in the model (cllc_* and *_cllc_transformer_* signals of the
%        old stage in storage_data_sst and scopes, inverter_*_cllc_mosfet_zvs_*, CFi_dc1/2_current_modA,
%        local_time_corr_* of global timing; after 'compact' also mosfet_ploss_invQ1..4 of storage_data_sst and
%        afe_phase_grid_hat_modA/B of the phase scope of line_source): deleted with its line; a To Workspace or
%        Terminator fed by it only goes too; any other destination gets a Ground block in its place, so no input is
%        left unconnected
%     6. storage_data_sst: afe_us_modA renamed afe_us_modA_sim; new From -> To Workspace pairs (only for tags that
%        have a Goto) for the outputs of the DCX blocks, cllc_dcx_m_mod1_sim / _mod2_sim ([Nc x 15] measurements of
%        the power stage, pu) and cllc_dcx_ctrl_log_mod1_sim / _mod2_sim ([Nc x 24], indices in param.cllc.idx); for
%        module B afe_voltage_output_modB_sim, afe_current_output_modB_sim, afe_us_modB_sim; for battery_2
%        voltage_battery_2_sim, current_battery_2_sim; for the T-type bridge of the old module A (leg u, Gotos of
%        "single phase afe/references") mosfet_ploss_invQ1_sim .. mosfet_ploss_invQ4_sim; with the compact modules
%        afe_cmp_m_modA/B_sim ([Nc x 13], the m output of the block, pu: i_s, i_a, u_ac, u_s, udc, udc_p, udc_n,
%        i_dc, i_np, i_c1, i_c2, i_cf, i_s2) and afe_cmp_ctrl_log_modA/B_sim ([Nc x 32], indices in param.spinv.idx).
%        SaveFormat Array on every To Workspace of the subsystem (the scripts of this folder index the logs as arrays)
%     7. current reference of the old module A (inverter_current_output_pu_reference): Step time param.spinv.t_ref,
%        after param.spinv.i_ref; Rate Limiter +/- param.spinv.i_ref_slew; the Constant of module B param.spinv.i_ref
%        (the compact modules read p.ctrl.i_ref, t_ref, i_ref_slew of their mask)
%     8. 'migrate' only: every parameter of every block (masks and library instances included) and the solver
%        settings of the model (StopTime, FixedStep, MaxStep) rewritten with the table of legacy_table (same
%        table as private/sst_cllc_ttype_legacy.m), whole names only, names already param.* untouched
%   Not touched: the library blocks inside (links), the control of the old modules, the configuration set apart from
%   the three solver parameters of 'migrate'.

    if nargin < 1 || isempty(mode)
        mode = 'fix';
    end
    migrate = strcmpi(mode, 'migrate');
    compact = strcmpi(mode, 'compact');
    assert(migrate || compact || strcmpi(mode, 'fix'), ...
        'update_sst_cllc_ttype_inv: mode is ''fix'', ''compact'' or ''migrate''');
    mdl = 'sst_cllc_ttype_inv';

    % param in the base workspace: the masks evaluate there
    if ~evalin('base', 'exist(''param'', ''var'')')
        fprintf('%s: param not found in the base workspace, running init_model first\n', mfilename);
        evalin('base', 'init_model');
    end
    load_system(mdl);
    n = 0;
    fprintf('%s: mode %s\n', mfilename, mode);
    % legacy names or param.* in the blocks added here: as the rest of the model
    migrated = migrate || strcmp(get_param(mdl, 'StopTime'), 'param.sim.simlength');
    if migrated
        pre = 'param.glb_time.';
    else
        pre = 'glb_time.';
    end

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
        if migrated
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

    % ---- 4. compact modules
    old_mod = {[mdl '/single_phase_inverter_modA'], [mdl '/single_phase_inverter_modB']};
    cmp_mod = {[mdl '/single_phase_inverter_modA_cmp'], [mdl '/single_phase_inverter_modB_cmp']};
    sto = [mdl '/storage_data_sst'];
    have_old = all(cellfun(@(b) getSimulinkBlockHandle(b) ~= -1, old_mod));
    have_cmp = all(cellfun(@(b) getSimulinkBlockHandle(b) ~= -1, cmp_mod));
    if compact && ~have_cmp
        error('%s: wrappers single_phase_inverter_modA_cmp / modB_cmp not found, mode ''compact'' needs them', mfilename);
    end
    use_cmp = have_cmp && (compact || ~have_old);       % the compact modules are the active pair
    if have_cmp
        % 4a. the library blocks inside the wrappers
        sides = 'AB';
        for k = 1:2
            w = cmp_mod{k};
            blk = find_system(w, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'IncludeCommented', 'on', ...
                'ReferenceBlock', 'afe_single_phase_ttype/afe_single_phase_ttype_mod1');
            assert(numel(blk) == 1, '%s: %d blocks afe_single_phase_ttype_mod1 in %s, 1 expected', mfilename, numel(blk), w);
            bh = get_param(blk{1}, 'Handle');
            n = n + set_once(bh, 'p', sprintf('param.spinv.p_mod%c', sides(k)));
            n = n + set_once(bh, 'Name', sprintf('afe_single_phase_ttype_mod%c', sides(k)));
            ph = get_param(bh, 'PortHandles');
            pos = get_param(bh, 'Position');
            if get_param(ph.Inport(2), 'Line') == -1
                if k == 1               % master: p.ctrl.slave = 0, the sync input is not read
                    g = add_block('simulink/Sources/Ground', [w '/sync_none'], 'MakeNameUnique', 'on', ...
                        'Position', [pos(1) - 110, pos(2) + 50, pos(1) - 80, pos(2) + 80]);
                else                    % slave: angle and modulation vector of module A
                    g = add_block('simulink/Signal Routing/From', [w '/From_sync'], 'MakeNameUnique', 'on', ...
                        'GotoTag', 'synch_AFE_mtos', 'Position', [pos(1) - 200, pos(2) + 50, pos(1) - 60, pos(2) + 70]);
                end
                gp = get_param(g, 'PortHandles');
                add_line(w, gp.Outport(1), ph.Inport(2), 'autorouting', 'on');
                fprintf('  %s: sync input connected (%s)\n', w, get_param(g, 'BlockType'));
                n = n + 1;
            end
            if k == 1
                n = n + ensure_goto(w, ph.Outport(3), 'synch_AFE_mtos', [pos(3) + 60, pos(4) - 10, pos(3) + 200, pos(4) + 10]);
            else
                n = n + ensure_terminator(w, ph.Outport(3), [pos(3) + 60, pos(4) - 10, pos(3) + 80, pos(4) + 10]);
            end
            n = n + ensure_goto(w, ph.Outport(1), sprintf('afe_cmp_m_mod%c', sides(k)), ...
                [pos(3) + 60, pos(2) - 10, pos(3) + 200, pos(2) + 10]);
            n = n + ensure_goto(w, ph.Outport(2), sprintf('afe_cmp_ctrl_log_mod%c', sides(k)), ...
                [pos(3) + 60, pos(2) + 30, pos(3) + 200, pos(2) + 50]);
            if use_cmp
                n = n + ensure_legacy_tags(w, ph.Outport(1), sides(k), pos);
            end
        end

        % 4b. root wiring: LConn 1/2 = udc(+)/udc(-) and RConn 1/2 = uac(+)/uac(-) of every module (old and wrapper),
        %     RConn 1/2 = dc2+/dc2- of the DCX wrappers, LConn 1/2 = u1/u2 of line_source
        if use_cmp
            act = cmp_mod;
            off = old_mod;
        else
            act = old_mod;
            off = cmp_mod;
        end
        pa = get_param(act{1}, 'PortHandles');
        pb = get_param(act{2}, 'PortHandles');
        pd1 = get_param([mdl '/cllc_dcx_mod1'], 'PortHandles');
        pd2 = get_param([mdl '/cllc_dcx_mod2'], 'PortHandles');
        pls = get_param([mdl '/line_source'], 'PortHandles');
        assert(numel(pa.LConn) == 2 && numel(pa.RConn) == 2 && numel(pb.LConn) == 2 && numel(pb.RConn) == 2, ...
            '%s: the modules must have 2 left (DC) and 2 right (AC) physical ports', mfilename);
        want = [pd1.RConn(1), pa.LConn(1); pd1.RConn(2), pa.LConn(2); ...      % DCX 1 side 2 -> DC link of A
                pd2.RConn(1), pb.LConn(1); pd2.RConn(2), pb.LConn(2); ...      % DCX 2 side 2 -> DC link of B
                pls.LConn(1), pa.RConn(1); pa.RConn(2), pb.RConn(1); pb.RConn(2), pls.LConn(2)];   % u1 - A - B - u2
        isolate = [];
        for k = 1:2
            if getSimulinkBlockHandle(off{k}) ~= -1
                po = get_param(off{k}, 'PortHandles');
                isolate = [isolate, po.LConn, po.RConn];   %#ok<AGROW>
            end
        end
        if ~wired(want, isolate)
            for k = 1:numel(want)
                clear_port_lines(want(k));
            end
            for k = 1:numel(isolate)
                clear_port_lines(isolate(k));
            end
            for k = 1:size(want, 1)
                add_line(mdl, want(k, 1), want(k, 2), 'autorouting', 'on');
            end
            fprintf('  root: %s and %s wired (DC links on side 2 of the DCX, AC sides in series with line_source)\n', ...
                act{1}, act{2});
            n = n + 1;
        end

        % 4c. the inactive pair
        if use_cmp
            for k = 1:2
                n = n + set_once(cmp_mod{k}, 'Commented', 'off');
                if getSimulinkBlockHandle(old_mod{k}) ~= -1
                    delete_with_lines(old_mod{k});
                    fprintf('  deleted %s (replaced by %s)\n', old_mod{k}, cmp_mod{k});
                    n = n + 1;
                end
            end
            sc = [mdl '/scopes/scopes_inv_modA'];
            if getSimulinkBlockHandle(sc) ~= -1
                delete_with_lines(sc);
                fprintf('  deleted %s (device quantities of the old module)\n', sc);
                n = n + 1;
            end
        else
            for k = 1:2
                n = n + set_once(old_mod{k}, 'Commented', 'off');
                n = n + set_once(cmp_mod{k}, 'Commented', 'on');
            end
        end
    end
    if getSimulinkBlockHandle(sto) ~= -1
        n = n + set_once(sto, 'Commented', 'off');
    end

    % ---- 5. From blocks whose tag has no Goto anywhere in the model
    gotos = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'IncludeCommented', 'on', 'BlockType', 'Goto');
    goto_tags = unique(cellfun(@(b) get_param(b, 'GotoTag'), gotos, 'UniformOutput', false));
    froms = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'off', 'IncludeCommented', 'on', 'BlockType', 'From');
    for k = 1:numel(froms)
        if getSimulinkBlockHandle(froms{k}) == -1          % already gone with a block deleted above
            continue
        end
        if ~any(strcmp(get_param(froms{k}, 'GotoTag'), goto_tags))
            n = n + remove_dangling_from(froms{k});
        end
    end

    % ---- 6. storage_data_sst
    tw = find_system(sto, 'SearchDepth', 1, 'IncludeCommented', 'on', 'BlockType', 'ToWorkspace', 'VariableName', 'afe_us_modA');
    for k = 1:numel(tw)
        n = n + set_once(tw{k}, 'VariableName', 'afe_us_modA_sim');
    end
    new_logs = {'cllc_dcx_m_mod1', 'cllc_dcx_m_mod2', 'cllc_dcx_ctrl_log_mod1', 'cllc_dcx_ctrl_log_mod2', ...
        'afe_voltage_output_modB', 'afe_current_output_modB', 'afe_us_modB', 'voltage_battery_2', 'current_battery_2', ...
        'mosfet_ploss_invQ1', 'mosfet_ploss_invQ2', 'mosfet_ploss_invQ3', 'mosfet_ploss_invQ4'};
    if use_cmp
        new_logs = [new_logs, {'afe_cmp_m_modA', 'afe_cmp_ctrl_log_modA', 'afe_cmp_m_modB', 'afe_cmp_ctrl_log_modB'}];
    end
    tws = find_system(sto, 'SearchDepth', 1, 'IncludeCommented', 'on', 'BlockType', 'ToWorkspace');
    vars = cellfun(@(b) get_param(b, 'VariableName'), tws, 'UniformOutput', false);
    blks = setdiff(find_system(sto, 'SearchDepth', 1, 'IncludeCommented', 'on', 'Type', 'block'), {sto});
    y = 0;
    for k = 1:numel(blks)
        pos = get_param(blks{k}, 'Position');
        y = max(y, pos(4));
    end
    for k = 1:numel(new_logs)
        tag = new_logs{k};
        v = [tag '_sim'];
        if any(strcmp(v, vars)) || ~any(strcmp(tag, goto_tags))    % present, or no Goto of this tag in the model
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

    % ---- 7. current reference of the old modules
    ref_a = [old_mod{1} '/single phase inverter control/inverter_current_output_pu_reference'];
    if getSimulinkBlockHandle(old_mod{1}) == -1
        fprintf('  old modules not in the model: current reference of the compact modules in param.spinv.p_modA.ctrl\n');
    elseif getSimulinkBlockHandle([ref_a '/Step']) ~= -1
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
    ref_b = [old_mod{2} '/single phase inverter control/inverter_current_output_pu_reference/Constant'];
    if getSimulinkBlockHandle(ref_b) ~= -1
        n = n + set_once(ref_b, 'Value', 'param.spinv.i_ref');
    end

    % ---- 8. migration of the legacy names
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
        if ischar(blk)
            name = blk;
        else
            name = getfullname(blk);
        end
        fprintf('  %s | %s = %s\n', name, prm, val);
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

function r = line_root(port)
%LINE_ROOT  handle of the root line of the line tree a port belongs to, -1 when the port has no line
    r = get_param(port, 'Line');
    while r ~= -1
        up = get_param(r, 'LineParent');
        if up == -1
            break
        end
        r = up;
    end
end

function clear_port_lines(port)
%CLEAR_PORT_LINES  delete the whole line tree (trunk and branches) a port belongs to
    r = line_root(port);
    if r ~= -1
        delete_line(r);
    end
end

function ok = wired(want, isolate)
%WIRED  true when every pair of ports of want [n x 2] shares a line tree and every port of isolate has no line
    ok = false;
    for k = 1:size(want, 1)
        r = line_root(want(k, 1));
        if r == -1 || r ~= line_root(want(k, 2))
            return
        end
    end
    for k = 1:numel(isolate)
        if get_param(isolate(k), 'Line') ~= -1
            return
        end
    end
    ok = true;
end

function n = ensure_goto(sys, outport, tag, pos)
%ENSURE_GOTO  global Goto of the tag fed by outport, added when the subsystem has none (a branch when the port has a line)
    if ~isempty(find_system(sys, 'SearchDepth', 1, 'IncludeCommented', 'on', 'BlockType', 'Goto', 'GotoTag', tag))
        n = 0;
        return
    end
    g = add_block('simulink/Signal Routing/Goto', [sys '/Goto_' tag], 'MakeNameUnique', 'on', 'GotoTag', tag, ...
        'TagVisibility', 'global', 'Position', pos);
    gp = get_param(g, 'PortHandles');
    add_line(sys, outport, gp.Inport(1), 'autorouting', 'on');
    fprintf('  %s: Goto %s added\n', sys, tag);
    n = 1;
end

function n = ensure_terminator(sys, outport, pos)
%ENSURE_TERMINATOR  Terminator on an output port left open
    if get_param(outport, 'Line') ~= -1
        n = 0;
        return
    end
    t = add_block('simulink/Sinks/Terminator', [sys '/Terminator'], 'MakeNameUnique', 'on', 'Position', pos);
    tp = get_param(t, 'PortHandles');
    add_line(sys, outport, tp.Inport(1), 'autorouting', 'on');
    fprintf('  %s: Terminator on output %d\n', sys, get_param(outport, 'PortNumber'));
    n = 1;
end

function n = ensure_legacy_tags(sys, m_port, side, pos)
%ENSURE_LEGACY_TAGS  Gain m_to_legacy (param.spinv.m_to_legacy_modX, [5 x 13]) on the m output of the compact block, a
%   Demux and the five global Gotos of the old log tags in physical units: afe_current_output_modX (i_a [A]),
%   afe_voltage_output_modX (u_ac [V]), afe_is_modX (i_s [A]), afe_us_modX (u_s [V]), dclink_voltage_modX (udc [V])
    if getSimulinkBlockHandle([sys '/m_to_legacy']) ~= -1
        n = 0;
        return
    end
    tags = {'afe_current_output', 'afe_voltage_output', 'afe_is', 'afe_us', 'dclink_voltage'};
    x = pos(3) + 60;
    y = pos(4) + 60;
    g = add_block('simulink/Math Operations/Gain', [sys '/m_to_legacy'], 'Gain', sprintf('param.spinv.m_to_legacy_mod%c', side), ...
        'Multiplication', 'Matrix(K*u)', 'Position', [x, y + 50, x + 110, y + 90]);
    d = add_block('simulink/Signal Routing/Demux', [sys '/m_to_legacy_demux'], 'Outputs', '5', ...
        'Position', [x + 150, y, x + 155, y + 140]);
    gp = get_param(g, 'PortHandles');
    dp = get_param(d, 'PortHandles');
    add_line(sys, m_port, gp.Inport(1), 'autorouting', 'on');
    add_line(sys, gp.Outport(1), dp.Inport(1), 'autorouting', 'on');
    for k = 1:numel(tags)
        tag = sprintf('%s_mod%c', tags{k}, side);
        yk = y + 35*(k - 1);
        t = add_block('simulink/Signal Routing/Goto', [sys '/Goto_' tag], 'MakeNameUnique', 'on', 'GotoTag', tag, ...
            'TagVisibility', 'global', 'Position', [x + 200, yk, x + 380, yk + 20]);
        tp = get_param(t, 'PortHandles');
        add_line(sys, dp.Outport(k), tp.Inport(1), 'autorouting', 'on');
    end
    fprintf('  %s: Gain m_to_legacy, Demux and Gotos %s (_mod%c) added\n', sys, strjoin(tags, ', '), side);
    n = 1;
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
