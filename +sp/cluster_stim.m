function [info_sc_cluster_fa, info_sc_cluster_as] = cluster_stim(participant, participant_mapping, varargin)
%%
% d.sc_count = 3;
d.stim_diff_threshold_fa = 0.125 * 1e-3;
d.stim_diff_threshold_as = 0.175 * 1e-3;
d.save_to_auxf = false;
d.ephys_mode = 'research_scs';
% d.merge_met = 'sc_threshold';
d.regress_shock = true;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);

%%
[~, info, data] = load_data('participant', participant, 'output_type', 'individual_single', ...
    'participant_mapping', participant_mapping, ...
    'apply_rejection', false, 'apply_clustering', false);
if v.save_to_auxf
    info_auxf = modify_auxf(participant, 'mode', 'load');
end

%%
layout_scloc = get_layout_scloc('output_as_string', false);
cell_scloc = unique(layout_scloc(:));

%%
% if strcmpi(v.merge_met, 'sc_threshold')
%     label_cluster = 'cluster';  % this should really be cluster_th
% elseif strcmpi(v.merge_met, 'none')
%     label_cluster = 'cluster_all';
% elseif strcmpi(v.merge_met, 'sc_current_sweep')
%     label_cluster = 'cluster_as';
% else
%     error('merge_met not correctly specified?');
% end
% label_cluster = sprintf('%s_pc%d', label_cluster, v.sc_count);
info_sc_cluster_fa = nan(height(info), 1);
info_sc_cluster_as = nan(height(info), 1);
%%
% for ix_cell_sub = 1:length(cell_sub)
%     str_sub = cell_sub{ix_cell_sub};
%     str_alias = T.Properties.UserData.(str_sub).alias;
%     case_sub = strcmpi(T.participant, str_sub);
v.seed.(participant) = string2hash(participant);
rng(v.seed.(participant));
%     fprintf('%s (%s)\n', str_sub, str_alias);
%%
case_valid = get_case_valid(info);  % the most general
% N.B. you are at the json character limit here!!!
[column_grouping, vec_group] = get_condition_groups(info, 'ephys_mode', v.ephys_mode);
column_grouping_parent = get_condition_groups(info, 'ephys_mode', v.ephys_mode, ...
    'group_by_sc_level', false, 'group_by_sc_laterality', false);
%%
ix_cluster_th = 0;
ix_cluster_as = 0;
for ix_vec_group = 1:length(vec_group)
    
    fprintf('%s %s\n', participant, vec_group(ix_vec_group));
    case_group = column_grouping == vec_group(ix_vec_group);
    parent_group = unique(column_grouping_parent(case_group));
    assert(length(parent_group)==1, 'something wrong');
    
    case_parent_group = (parent_group == column_grouping_parent) & case_valid;
    
    stimamp_th = get_stimamp_th(info, cell_scloc, v.stim_diff_threshold_fa, case_parent_group);
    case_above = info.sc_current > (stimamp_th(1) - v.stim_diff_threshold_fa);
    case_below = info.sc_current < (stimamp_th(1) + v.stim_diff_threshold_fa);
    case_a_th = and(case_above, case_below);
    
    % cluster threshold
    case_merged = case_group & case_valid & case_a_th;
    to = info.datetime(case_merged);
    if not(isempty(to))
        dt = to - to(1);
        dt = seconds(dt);
        assert(issorted(dt), 'dt not sorted??!');
        vec_dt_cluster = auto_gm_cluster(dt);
        n_clusters = max(vec_dt_cluster);
        vec_dt_cluster = ix_cluster_th + vec_dt_cluster;
        ix_cluster_th = ix_cluster_th + n_clusters;
        info_sc_cluster_fa(case_merged) = vec_dt_cluster;
    end
    
    stimamp_th = get_stimamp_th(info, cell_scloc, v.stim_diff_threshold_as, case_parent_group);
    case_above = info.sc_current > (stimamp_th(1) - v.stim_diff_threshold_as);
    case_below = info.sc_current < (stimamp_th(1) + v.stim_diff_threshold_as);
    case_a_th = and(case_above, case_below);
    
    % cluster sweeps
    case_merged = case_group & case_valid;
    to = info.datetime(case_merged);
    if not(isempty(to))
        dt = to - to(1);
        dt = seconds(dt);
        assert(issorted(dt), 'dt not sorted??!');
        vec_dt_cluster = auto_gm_cluster(dt);
        n_clusters = max(vec_dt_cluster);
        vec_dt_cluster = ix_cluster_as + vec_dt_cluster;
        ix_cluster_as = ix_cluster_as + n_clusters;
        info_sc_cluster_as(case_merged) = vec_dt_cluster;
    end
    if any(isfinite(info_sc_cluster_as))
        % you need to merge nearby clusters here
        info_sc_cluster_as = merge_clusters(info_sc_cluster_as, info.datetime);
        mad_amp = mad(1e3 * info.sc_current(isfinite(info_sc_cluster_as)), 1);
        if mad_amp < 0.051
            info_sc_cluster_as= info_sc_cluster_as * nan;
        end
        u_temp_cluster = unique(info_sc_cluster_as);
        u_temp_cluster = u_temp_cluster(isfinite(u_temp_cluster));
        
        for ix_u_temp_cluster = 1:length(u_temp_cluster)
            case_cluster = info_sc_cluster_as == u_temp_cluster(ix_u_temp_cluster);
            
            int_sc_currents = unique(round(1e3 * info.sc_current(case_cluster)));
            is_sc_current_sweep = length(int_sc_currents) >= 3;
            if not(is_sc_current_sweep)
                info_sc_cluster_as(case_cluster) = nan;
            end
        end
    end
    info_sc_cluster_as(case_merged) = info_sc_cluster_as(case_merged);
    
    
    
    
    
    % end
end



if v.save_to_auxf
    info_auxf.('sc_cluster_as') = info_sc_cluster_as;
    info_auxf.('sc_cluster_fa') = info_sc_cluster_fa;
    modify_auxf(participant, 'mode', 'save', 'info_auxf', info_auxf);
end
end

function [temp_cluster] = merge_clusters(temp_cluster, T_datetime)
th_time_diff = 20;
stop = false;
while not(stop)
    [temp_cluster, stop] = merge_clusters_core(temp_cluster, T_datetime, th_time_diff);
end


end

function [temp_cluster, stop] = merge_clusters_core(temp_cluster, T_datetime, th_time_diff)
stop = false;
u_temp_cluster = unique(temp_cluster);
u_temp_cluster = u_temp_cluster(isfinite(u_temp_cluster));

min_cluster_time = NaT(length(u_temp_cluster), 1);
max_cluster_time = min_cluster_time;
for ix_u_temp_cluster = 1:length(u_temp_cluster)
    case_cluster = temp_cluster == u_temp_cluster(ix_u_temp_cluster);
    min_cluster_time(ix_u_temp_cluster, :) = min(T_datetime(case_cluster));
    max_cluster_time(ix_u_temp_cluster, :) = max(T_datetime(case_cluster));
end


for ix_u_temp_cluster = 1:length(u_temp_cluster)
    dt = min_cluster_time(ix_u_temp_cluster) - max_cluster_time;
    dt(dt <= 0 * seconds) = Inf;
    is_neighbour = false(size(dt));
    [val_min, ix_min] = min(dt);
    if val_min < th_time_diff * seconds
        is_neighbour(ix_min) = true;
    end
    
    if any(is_neighbour)
        neighbour_cluster = u_temp_cluster(is_neighbour);
        temp_cluster(temp_cluster == u_temp_cluster(ix_u_temp_cluster)) = neighbour_cluster;
        return;
    end
end
stop = true;
end