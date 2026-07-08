function [data] = regress_shock(info, data, varargin)
d.th_var_explained = 0.975;
d.t_min = 6.5e-3;
d.ephys_mode = 'research_scs';
d.verbose = true;
%% Parse input
d.d_overwrite = struct;
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
% cell_sub = unique(info.participant);
% case_valid = get_case_valid(info, 'electrode_type', 'any', 'mode', v.ephys_mode, 'electrode_configuration', 'any', 'pulse_count', 'any');
try
case_t_local = (info.Properties.UserData.(v.ephys_mode).t > 0) & (info.Properties.UserData.(v.ephys_mode).t < v.t_min);

catch
keyboard;
end
[column_grouping, vec_group] = get_condition_groups(info, ...
    'group_by_participant', true,...
    'ephys_mode', v.ephys_mode,...
    'group_by_sc_level', false, ...
    'group_by_sc_laterality', false, ...
    'group_by_sc_electrode_type', false, ...
    'group_by_sc_electrode_configuration', false ...
    );


for ix_vec_group = 1:length(vec_group)
    str_group = vec_group(ix_vec_group);
    case_group = str_group == column_grouping;
    data_part = data(case_group);
    try
    Y = cell2mat(cellfun(@(x) x.data, data_part, 'UniformOutput', false));
    catch
        keyboard;
    end
    Y_shock_cut = Y(:, case_t_local);
    Y_shock_cut = Y_shock_cut(all(isfinite(Y_shock_cut), 2), :);
    
    [~, score, latent] = pca(Y_shock_cut.', 'Centered', false);
    
    
    n_pcs = find(cumsum(latent)/sum(latent) > v.th_var_explained, 1, 'first');
    if v.verbose,fprintf('%s, PCs for shock art.: %d\n', str_group, n_pcs);end
    shock_art = score(:, 1:n_pcs);
    %     shock_art = [ones(size(shock_art, 1), 1), shock_art];
    for ix_record = 1:length(data_part)
        rd = data_part{ix_record};
        record_shock = zeros(size(rd.data));
        for ix_muscle = 1:size(rd.data, 1)
            x = rd.data(ix_muscle, case_t_local).';
            if all(not(isfinite(x))), continue;end
            b = regress(x, shock_art);
            record_shock(ix_muscle, case_t_local) = [shock_art * b].';
        end
    
        data_part{ix_record}.data = rd.data - record_shock;
    end
    data(case_group) = data_part;
    
end


end