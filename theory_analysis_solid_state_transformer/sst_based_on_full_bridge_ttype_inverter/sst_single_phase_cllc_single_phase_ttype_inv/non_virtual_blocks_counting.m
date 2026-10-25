clc

% model to count: the one chosen in init_model (param.sim.model), else the compact one
if exist('param', 'var') && isfield(param, 'sim') && isfield(param.sim, 'model')
    mdl = param.sim.model;
else
    mdl = 'sst_cllc_ttype_inv';
end
load_system(mdl);

% conta anche i modelli referenziati (Model Reference), se ce ne sono
mdlRefs = find_mdlrefs(mdl);
cellfun(@load_system, mdlRefs);

nNV = cellfun(@(m) numel(find_system(m, ...
    'LookUnderMasks','all', ...
    'FollowLinks','on', ...
    'Virtual','off')), mdlRefs);

table(mdlRefs, nNV(:), 'VariableNames', {'Model','NonVirtualBlocks'})
fprintf('Totale blocchi non-virtuali: %d\n', sum(nNV));