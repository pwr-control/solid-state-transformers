% Count of the nonvirtual blocks of sst_cllc_dcx.slx, referenced models included (MATLAB Home licence:
% at most 1000 nonvirtual blocks per model, library links and masks included).
clc

mdl = 'sst_cllc_dcx.slx';
load_system(mdl);

% referenced models (Model Reference), if any
mdlRefs = find_mdlrefs(mdl);
cellfun(@load_system, mdlRefs);

nNV = cellfun(@(m) numel(find_system(m, ...
    'LookUnderMasks','all', ...
    'FollowLinks','on', ...
    'Virtual','off')), mdlRefs);

table(mdlRefs, nNV(:), 'VariableNames', {'Model','NonVirtualBlocks'})
fprintf('Total nonvirtual blocks: %d\n', sum(nNV));
