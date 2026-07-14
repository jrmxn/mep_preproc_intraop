function [vec_participant, info, ephys, v, vec_alias] = load_data(varargin)
% p_ = mfilename('fullpath');
% p_ = fileparts(p_);
% addpath(fullfile(p_, 'intraop_preproc'));
d.participant = [];
d.participant_exclude = [];
d.t_min = 7e-3;
d.t_max = 75e-3;
d.calculate_auc = true;
d.output_type = "stacked";
d.input_type = 'preproc_standard';
d.participant_mapping = 'injury_study';
d.minimal_processing = false;
d.quick_load = true;
d.info_only_load = false;
d.apply_regress_shock = true;
d.apply_clustering = true;
d.apply_rejection = true;
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);
v = inputParserStructureOverwrite(v);
if v.minimal_processing
    v.apply_regress_shock = false;
    v.apply_clustering = false;
    v.apply_rejection = false;
end
%%
d_preproc = fullfile(getenv('D_PROC'), v.input_type);
p_par_list_json = fullfile(getenv('D_PARTICIPANT_MAPPING'), sprintf('%s.json', v.participant_mapping));
p_par_list_toml = fullfile(getenv('D_PARTICIPANT_MAPPING'), sprintf('%s.toml', v.participant_mapping));
if exist(p_par_list_json, 'file') == 2
    s_participant = loadjson(p_par_list_json);
elseif exist(p_par_list_toml, 'file') == 2
    s_participant = toml.read(p_par_list_toml);
    s_participant = toml.map_to_struct(s_participant);
end


s_participant.reject_modes = string(s_participant.reject_modes);
cell_participant = fieldnames(s_participant.participant);
cell_participant = cell_participant(:).';
ix_alias = cellfun(@(x) s_participant.participant.(x), cell_participant, 'UniformOutput', true);
ib = 1:length(cell_participant);
if isempty(v.participant)
    % do nothing
elseif any(v.participant == ["SCAPPTIO", "CORNPTIO"].', [1, 2])
    ib = find(contains(cell_participant, lower(v.participant)));
    cell_participant = cell_participant(ib);
elseif not(isempty(v.participant))
    [cell_participant, ~, ib] = intersect(v.participant, cell_participant);
end
ix_alias = ix_alias(ib);
if not(isempty(v.participant_exclude))
    assert(isstring(v.participant_exclude), '!');
    case_exc = false(size(cell_participant));
    for ix_exc = 1:length(v.participant_exclude)
        case_exc_ = strcmpi(v.participant_exclude(ix_exc), cell_participant);
        case_exc = case_exc | case_exc_;
    end
    cell_participant(case_exc) = [];
    ix_alias(case_exc) = [];
end
vec_alias = string(arrayfun(@(ix) sprintf('%s%02d', s_participant.alias_modifier, ix), ix_alias, 'UniformOutput', false));
vec_participant = string(cell_participant);
if isempty(vec_participant)
    warning('No participants selected!');
end
%%
% output in order of alias
[vec_alias, ix_vec_alias] = sort(vec_alias);
vec_participant = vec_participant(ix_vec_alias);

%%
if v.overwrite, v.quick_load = false;end
ws_v_exists = evalin( 'base', 'exist(''rapid_v'',''var'') == 1' );
if and(v.quick_load, ws_v_exists)
    cell_exc = {'quick_load'};
    rapid_v = evalin('base', 'rapid_v');
    rapid_v_hash = generate_ip_hash(rapid_v, cell_exc);
    v_hash = generate_ip_hash(v, cell_exc);
    if v_hash==rapid_v_hash
        try
            info = evalin('base', 'rapid_info');
            ephys = evalin('base', 'rapid_ephys');
            return;
        catch
            warning('Failed to quick-load');
        end
    end
end

info_trial = table;
ephys_trial = {};
ephys_sub = cell(1, length(cell_participant));
info_sub = cell(1, length(cell_participant));

for ix_cell_sub = 1:length(cell_participant)
    participant = cell_participant{ix_cell_sub};
    
    p_info = fullfile(d_preproc, participant, 'ephys', sprintf('%s_info.mat', participant));
    p_data = fullfile(d_preproc, participant, 'ephys', sprintf('%s_data.mat', participant));
    
    if v.info_only_load
        ephys_local.trials_flat = [];
        v.calculate_auc = false;
        v.apply_rejection = false;
    else
        ephys_local = load(p_data);
    end
    info_trial_local = load(p_info);
    info_trial_local = info_trial_local.info_flat;
    ephys_trial_local = ephys_local.trials_flat(:);
    
    if v.apply_rejection
        %         vec_reject_modes = ["research_scs", "research_mep", "research_paired_averaged", "research_paired_repeat"];
        info_auxf = modify_auxf(participant, 'mode', 'load');
        for ix_vec_reject_modes = 1:length(s_participant.reject_modes)
            str_mode_local = s_participant.reject_modes(ix_vec_reject_modes);
            fn_local = "reject_" + str_mode_local;
            if not(any(info_trial_local.mode == str_mode_local))
                info_trial_local.(fn_local) = false(height(info_trial_local), length(info_trial_local.Properties.UserData.research_scs.channels));
                continue;
            end
            
            n_ch = length(info_trial_local.Properties.UserData.(str_mode_local).channels);
            if any(strcmpi(info_auxf.Properties.VariableNames, fn_local))
                try
                    info_trial_local.(fn_local) = logical(info_auxf.(fn_local));
                catch
                    keyboard;
                end
            else
                info_trial_local.(fn_local) = false(height(info_trial_local), n_ch);
                fprintf('Not applying rejection for %s for %s!\n', participant, str_mode_local);
            end
        end
    end
    
    vec_mode_rs = ["research_scs"];
    vec_mode_auc = ["research_scs", "research_paired_averaged", "research_paired_repeat", "research_mep", "research_lcswap"];
    if v.calculate_auc
        vec_mode_in_data = info_trial_local.Properties.UserData.vec_mode;
        channels = info_trial_local.Properties.UserData.(vec_mode_in_data(1)).channels;
        
        info_trial_local.auc = nan(height(info_trial_local), length(channels));
        info_trial_local.auc_bl = nan(height(info_trial_local), length(channels));
        info_trial_local.pkpk = nan(height(info_trial_local), length(channels));
        info_trial_local.rpkmax = nan(height(info_trial_local), length(channels));
        
        for ix_vec_mode = 1:length(vec_mode_in_data)
            str_mode = vec_mode_in_data(ix_vec_mode);
            try
                channels_local = info_trial_local.Properties.UserData.(str_mode).channels;
            catch
                % not sure why there is a mismatch between fields in
                % vec_mode and actual contents of UserData. Should fix one
                % day...
                continue;
            end
            assert(all(channels_local == channels), 'Channels across modes do not match');
            % you can add others here - as long as they have the same
            % number of channels:
            do_auc_calc = false;
            for ix_vec_mode_auc = 1:length(vec_mode_auc)
                do_auc_calc = do_auc_calc || strcmpi(str_mode, vec_mode_auc(ix_vec_mode_auc));
            end
            
            do_regress_shock = false;
            for ix_vec_mode_auc = 1:length(vec_mode_rs)
                do_regress_shock = do_regress_shock || strcmpi(str_mode, vec_mode_rs(ix_vec_mode_auc));
            end
            
            if do_auc_calc
                if do_regress_shock
                    ephys_trial_local_auc = regress_shock(info_trial_local, ephys_trial_local, 't_min', v.t_min, 'ephys_mode', str_mode);
                else
                    ephys_trial_local_auc = ephys_trial_local;
                end
                case_mode = info_trial_local.mode == str_mode;
                
                % for the AUC calc --- you might need to think about
                % adjusting the time window? not sure. Will have to see.
                t = info_trial_local.Properties.UserData.(str_mode).t;
                case_t = (t >= v.t_min) & (t < v.t_max);
                case_tlt0 = t < 0;
                k_auc_baseline = sum(case_t)/sum(case_tlt0);  % scale the AUC of the baseline to match the actual AUC
                
                mat_auc = nan(height(info_trial_local), length(channels));
                mat_auc_bl = nan(height(info_trial_local), length(channels));
                mat_pkpk = nan(height(info_trial_local), length(channels));
                mat_rpkmax = nan(height(info_trial_local), length(channels));
                for ix_ch = 1:length(channels)
                    
                    y_mep = nan(length(ephys_trial_local_auc), length(t));
                    y_mep(case_mode, :) = cell2mat(cellfun(@(x) x.data(ix_ch, :), ephys_trial_local_auc(case_mode, :), 'UniformOutput', false));
                    
                    y_valid = isfinite(y_mep);
                    
                    case_valid_baseline = all(y_valid(:, case_tlt0), 2);
                    
                    mat_auc(:, ix_ch) = trapz(t(case_t), abs(y_mep(:, case_t)), 2);
                    mat_pkpk(:, ix_ch) = range(y_mep(:, case_t), 2);
                    mat_rpkmax(:, ix_ch) = max(abs(y_mep(:, case_t)), [], 2);
                    mat_auc_bl(:, ix_ch) = trapz(t(case_tlt0), abs(y_mep(:, case_tlt0)), 2) * k_auc_baseline;
                    mat_auc_bl(not(case_valid_baseline), ix_ch) = nan;
                end
                info_trial_local.auc(case_mode, :) = mat_auc(case_mode, :);
                info_trial_local.auc_bl(case_mode, :) = mat_auc_bl(case_mode, :);
                info_trial_local.pkpk(case_mode, :) = mat_pkpk(case_mode, :);
                info_trial_local.rpkmax(case_mode, :) = mat_rpkmax(case_mode, :);
            end
        end
    end
    
    if v.apply_regress_shock
        for ix_vec_mode = 1:length(info_trial_local.Properties.UserData.vec_mode)
            str_mode = info_trial_local.Properties.UserData.vec_mode(ix_vec_mode);
            if any(str_mode == vec_mode_rs)
                ephys_trial_local = regress_shock(info_trial_local, ephys_trial_local, ...
                    't_min', v.t_min, 'ephys_mode', str_mode);
            end
        end
    end
    
    info_trial_local.sccx_latency = (info_trial_local.sc_displacement - info_trial_local.cx_displacement) * 1e3;
    
    if v.apply_clustering
        % p_auxf = fullfile(getenv('D_PROC'), 'preproc_standard', participant, 'ephys', sprintf('%s_auxf.mat', participant));
        [info_trial_local.sc_cluster_fa, info_trial_local.sc_cluster_as] = ...
            sp.cluster_stim(participant, v.participant_mapping, 'ephys_mode', 'research_scs');
    end
    
    % avoid using this if you can - here for backward compat:
    info_trial_local.position = info_trial_local.sc_level + "_" + info_trial_local.sc_laterality;
    
    % checks to help debug concatentation failures
    if ix_cell_sub > 1
        sd_ab1 = setdiff(info_trial.Properties.VariableNames, info_trial_local.Properties.VariableNames);
        if not(isempty(sd_ab1))
            fprintf('Things in %s that are not in %s:\n', cell_participant{ix_cell_sub-1}, participant);
            disp(sd_ab1);
        end
        sd_ab2 = setdiff(info_trial_local.Properties.VariableNames, info_trial.Properties.VariableNames);
        if not(isempty(sd_ab2))
            fprintf('Things in %s that are not in %s:\n', participant, cell_participant{ix_cell_sub-1});
            disp(sd_ab2);
        end
        if isempty(sd_ab1) && isempty(sd_ab2)
            fn_v = info_trial.Properties.VariableNames;
            fn_v_diff = true(1, length(fn_v));
            for ix_fn = 1:length(fn_v)
                fn_v_diff(1, ix_fn) = not(strcmpi(class(info_trial{1, fn_v{ix_fn}}), class(info_trial_local{1, fn_v{ix_fn}})));
            end
            diff_list = fn_v(fn_v_diff);
            if not(isempty(diff_list))
                fprintf('Things in %s that are of a different data type to %s:\n', participant, cell_participant{ix_cell_sub-1});
                disp(diff_list);
            end
        end
    end
    
    info_trial = [info_trial; info_trial_local];
    % an error here probably indicates - rejection channel selection is old
    % see " update table for all (e.g. if you add new channels)" in
    % run_sp_rejection
    
    info_trial.Properties.UserData.participant.(participant).UserData = info_trial_local.Properties.UserData;
    ephys_trial = [ephys_trial; ephys_trial_local];
    if v.output_type == "stacked"
    elseif v.output_type == "individual" || v.output_type == "individual_single"
        info_sub{ix_cell_sub} = info_trial_local;
        ephys_sub{ix_cell_sub} = ephys_local;
    end
end

if v.output_type == "stacked"
    info = info_trial;
    ephys = ephys_trial;
elseif v.output_type == "individual"
    info = info_sub;
    ephys = ephys_sub;
elseif v.output_type == "individual_single"
    assert(length(cell_participant)==1, 'Asked for single participant output, but did not filter participants.');
    assert(length(vec_participant)==1, 'Asked for single participant output, but did not filter participants.');
    info = info_sub{1};
    ephys = ephys_sub{1};
else
    error('?');
end

if any(strcmpi(info.Properties.VariableNames, 'sc_misc'))
info.sc_misc(ismissing(info.sc_misc)) = "";
end

if v.quick_load
    assignin('base', 'rapid_info' , info);
    assignin('base', 'rapid_ephys' , ephys);
    assignin('base', 'rapid_v' , v);
end
end
