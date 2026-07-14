clearvars -except rapid_info rapid_ephys rapid_v;
addpath('..');
set_env;
% addpath(fullfile(getenv('D_GIT'), 'intraop_preproc'));
addpath(fullfile(getenvc('D_GIT'), 'run_cfg'));

% pne_data_merged = fullfile(getenvc('D_DATA'), 'proc_records', 'T_merged');
% pne_data_merged = fullfile(getenvc('D_DATA'), 'proc_records', 'T_merged_augmented');
% pne_data_rejection = fullfile(getenvc('D_DATA'), 'proc_records', 'T_rejected');

%% to fully kill all figures:
% delete(findall(0));
config_struct = load_configurations('cfg_rejection.json', 'open_config_file', true);

%%
participant = config_struct.participant;
participant_mapping = config_struct.participant_mapping;
vec_ephys_mode = config_struct.vec_ephys_mode;
fs_lowpass = config_struct.fs_lowpass;  % n.b. this used to be 100Hz

%%
rejection_summary = false;
if not(rejection_summary)
    for ix_vec_ephys_mode = 1:length(vec_ephys_mode)
        ephys_mode = vec_ephys_mode(ix_vec_ephys_mode);
        disp(ephys_mode);
        
        %% only run on specific subjects:
        reject_mode = 'reject_lines';
        if any(strcmpi(config_struct.reject_mode, reject_mode))
            fraction_pc_error = 0.0;  % better default
            sp.rejection(participant, 'reject_mode', reject_mode, ...
                'ephys_mode', ephys_mode, 'fs_lowpass', fs_lowpass, ...
                'fraction_pc_error', fraction_pc_error, 'participant_mapping', participant_mapping)
        end

        %% apply configuration into table
        reject_mode = 'update_table';
        if any(strcmpi(config_struct.reject_mode, reject_mode))
            sp.rejection(participant, ...
                'ephys_mode', ephys_mode, 'fs_lowpass', fs_lowpass, ...
                'reject_mode', reject_mode, 'participant_mapping', participant_mapping, 'overwrite', true);
        end

        %%
        % and now save figures:
        reject_mode = 'plot_lines';
        if any(strcmpi(config_struct.reject_mode, reject_mode))
            sp.rejection(pne_data_merged, pne_data_rejection, 'reject_mode', reject_mode, ...
                'sd_norm_plot', false, 'outer_is_scloc', true);
            sp.rejection(pne_data_merged, pne_data_rejection, 'reject_mode', reject_mode, ...
                'sd_norm_plot', false, 'outer_is_scloc', false);
        end

        %
        reject_mode = 'plot_heatmap';
        if any(strcmpi(config_struct.reject_mode, reject_mode))
            sp.rejection(pne_data_merged, pne_data_rejection, 'reject_mode', reject_mode, ...
                'sd_norm_plot', false, 'outer_is_scloc', true);
            sp.rejection(pne_data_merged, pne_data_rejection, 'reject_mode', reject_mode, ...
                'sd_norm_plot', false, 'outer_is_scloc', false);
        end

    end
    %% update table for all (e.g. if you add new channels)
    % v.participant_mapping = 'scap_study';
    % reject_mode = 'update_table';
    %
    % p_par_list_json = fullfile(getenv('D_PARTICIPANT_MAPPING'), sprintf('%s.json', v.participant_mapping));
    % p_par_list_toml = fullfile(getenv('D_PARTICIPANT_MAPPING'), sprintf('%s.toml', v.participant_mapping));
    % if exist(p_par_list_json, 'file') == 2
    %     s_participant = loadjson(p_par_list_json);
    % elseif exist(p_par_list_toml, 'file') == 2
    %     s_participant = toml.read(p_par_list_toml);
    %     s_participant = toml.map_to_struct(s_participant);
    % end
    % vec_participant = string(fieldnames(s_participant.participant));
    %
    % vec_mode = ["research_scs", "research_mep", "research_paired_averaged", "research_paired_repeat"];
    % for ix_vec_mode = 1:length(vec_mode)
    %     str_mode = vec_mode(ix_vec_mode);
    %     for ix_vec_participant = 1:length(vec_participant)
    %         participant = vec_participant(ix_vec_participant);
    %         sp.rejection(participant, ...
    %             'ephys_mode', str_mode, ...
    %             'reject_mode', reject_mode, 'overwrite', true, ...
    %             'participant_mapping', v.participant_mapping)
    %     end
    % end

    %% second round of rejection for threshold
    % pc_max = 1;
    % reject_at_threshold = true;
    % reject_mode = 'reject_lines';
    % fraction_pc_error = 0.0;
    % overwrite = true;

    %% second round of rejection for threshold
    % reject_mode = 'reject_lines';
    % sp.rejection(pne_data_rejection, pne_data_rejection, 'reject_mode', reject_mode, ...
    %     'pc_max', pc_max, 'reject_at_threshold', true, 'fraction_pc_error', fraction_pc_error, ...
    %     'subject_filter', {'P_...'});
    %      'slider_type', 'log10_auc_valid_lower', ...
    %%

    % sp.rejection(pne_data_rejection, pne_data_rejection, 'reject_mode', reject_mode, ...
    %     'pc_max', pc_max, 'reject_at_threshold', reject_at_threshold, ...
    %     'fraction_pc_error', fraction_pc_error, 'slider_type', 'log10_auc_valid_lower', ...
    %     'subject_filter', {'P_S07291681'});

    % sp.rejection(pne_data_rejection, pne_data_rejection, 'reject_mode', reject_mode, ...
    %     'pc_max', pc_max, 'reject_at_threshold', reject_at_threshold, ...
    %     'fraction_pc_error', fraction_pc_error, 'slider_type', 'log10_auc_valid_lower');

    % apply configuration into table

    % reject_mode = 'update_table';
    % sp.rejection(pne_data_rejection, pne_data_rejection, 'reject_mode', reject_mode, ...
    %     'pc_max', pc_max, 'reject_at_threshold', reject_at_threshold, ...
    %     'fraction_pc_error', fraction_pc_error, 'slider_type', 'log10_auc_valid_lower', ...
    %     'overwrite', overwrite);

    % and now save figures:
    %
    % reject_mode = 'plot_lines';
    % sp.rejection(pne_data_rejection, pne_data_rejection, 'reject_mode', reject_mode, ...
    %     'pc_max', pc_max, 'reject_at_threshold', reject_at_threshold, ...
    %     'fraction_pc_error', fraction_pc_error, 'outer_is_scloc', true);
    %
    % sp.rejection(pne_data_rejection, pne_data_rejection, 'reject_mode', reject_mode, ...
    %     'pc_max', pc_max, 'reject_at_threshold', reject_at_threshold, ...
    %     'fraction_pc_error', fraction_pc_error, 'outer_is_scloc', false);
    %
    % reject_mode = 'plot_heatmap';
    % sp.rejection(pne_data_rejection, pne_data_rejection, 'reject_mode', reject_mode, ...
    %     'pc_max', pc_max, 'reject_at_threshold', reject_at_threshold, ...
    %     'fraction_pc_error', fraction_pc_error, 'outer_is_scloc', true);

    % sp.rejection(pne_data_rejection, pne_data_rejection, 'reject_mode', reject_mode, ...
    %     'pc_max', pc_max, 'reject_at_threshold', reject_at_threshold, ...
    %     'fraction_pc_error', fraction_pc_error, 'outer_is_scloc', false);

    %%
else
    %     participant = ["cornptio001", "cornptio003", "cornptio004", "cornptio006", "cornptio007", "cornptio008", "cornptio010", "cornptio011", "cornptio012", ...
    %         "cornptio013", "cornptio014", "cornptio015", "cornptio017", "scapptio001", "cornptio016", "cornptio018", "scapptio004", "scapptio008", ...
    %         "scapptio010"];  % post-2021
    if config_struct.participant == "ALL"
        config_struct.participant = [];
    end
    [vec_participant, info, ephys, ~, vec_alias] = load_data('participant', config_struct.participant, 'participant_mapping', config_struct.participant_mapping);
    case_valid_channel = cell2mat(arrayfun(@(x) ephys{x}.custom.matched_channel.', 1:height(info), 'UniformOutput', false).');
    ch = ["Trapezius",  "Deltoid", "Biceps", "Triceps", "APB", "ADM", "TA", "EDB", "AH"];  % mapping
    ch = ["Deltoid", "Biceps", "Triceps", "ECR", "FCR", "APB", "ADM", "TA", "EDB", "AH"];  % immediate
    ch = ["L" + ch, "R" + ch];
    case_valid_channel = case_valid_channel & contains(info.Properties.UserData.research_scs.channels.', ch);

    vec_mode = ["research_paired_averaged", "research_paired_repeat"];
    case_valid = get_case_valid(info, 'sc_depth', 'any', ...
        'mode', vec_mode);

    %     rej = double(info.reject_research_scs);
    rej = double(info.reject_research_paired_averaged | info.reject_research_paired_repeat);
    n = length(info.Properties.UserData.research_scs.channels_muscles_half);
    rej(not(case_valid_channel & case_valid)) = nan;
    get_percentage_rejected(rej);

end
