clc

mdl = 'sst_cllc_ttype_inv.slx';
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