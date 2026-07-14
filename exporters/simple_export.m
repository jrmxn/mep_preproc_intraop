clearvars;
addpath(fullfile('..'))
set_env;
d_proc = getenvc('D_PROC');

%%
d_out = fullfile('export_folder');
participant_mapping = "cdmrp_study";  % must match name of the mapping file
str_prepend = "cdmrpptsc";
%%
v.ephys_mode = "research_lcswap";
t_min = 5e-3;
t_win = 70e-3;
t_min_pe = 2e-3;
participant_ix = [25];
cdmrpstc_ix_str = string(arrayfun(@(x) sprintf('%03d', x), participant_ix, 'UniformOutput', false)).';
vec_participant = str_prepend + cdmrpstc_ix_str;

%%
for ix_vec_participant = 1:length(vec_participant)
    str_participant = vec_participant(ix_vec_participant);
    disp(str_participant);

    [~, info, ephys, ~, vec_alias] = load_data('participant', str_participant, ...
        'participant_mapping', participant_mapping, ...
        't_min', t_min, 't_max', t_min + t_win);

    case_table = (info.mode == "research_lcswap") | (info.mode == "research_scs") | (info.mode == "research_scs_train") | (info.mode == "research_peripheral");
    info_local = info(case_table, :);
    ephys_local = ephys(case_table, :);
    %%
    col_reject = string(info_local.Properties.VariableNames(string(info_local.Properties.VariableNames).startsWith('reject_')));
    for ix_col_reject = 1:length(col_reject)
        reject_ = info_local.(col_reject(ix_col_reject));
        if ix_col_reject == 1
            reject = reject_;
        else
            reject = reject | reject_;
        end
    end

    for ix_row = 1:size(reject, 1)
        ephys_local{ix_row}.data(reject(ix_row, :), :) = nan;
    end

    %%
    case_local_single = (info_local.mode == "research_lcswap") | (info_local.mode == "research_scs") | (info_local.mode == "research_peripheral");

    t_sliced = info_local.Properties.UserData.(v.ephys_mode).t;
    channels = info_local.Properties.UserData.(v.ephys_mode).channels;

    ep_sliced = nan(size(ephys_local, 1), size(ephys_local{1}.data, 2), size(ephys_local{1}.data, 1));
    for ix_ch = 1:length(channels)
        ep_sliced(case_local_single, :, ix_ch) = cell2mat(cellfun(@(x) x.data(ix_ch, :), ephys_local(case_local_single), 'UniformOutput', false));
    end


    %%
    % Perhaps if a row is full nan it causes trouble so...
    case_rm = all(isnan(info_local.auc), 2);
    info_local(case_rm, :) = [];
    ep_sliced(case_rm, :, :) = [];

    %%
    % Sanitize (move into its own function later)
    c = struct;
    c.st = struct;
    c.st.channel = arrayfun(@(x) char(x), info_local.Properties.UserData.(v.ephys_mode).channels, 'UniformOutput', false);
    c.st.channel_type = arrayfun(@(x) char(x), info_local.Properties.UserData.(v.ephys_mode).channel_type, 'UniformOutput', false);
    c.st.fs = info_local.Properties.UserData.(v.ephys_mode).fs;
    c.st.units_ep = 'µV';
    c.auc = struct;
    c.auc.units_auc = 'µV⋅s';
    c.auc.units_pkpk = 'µV';
    c.auc.t_slice_win = t_win;
    c.auc.t_slice_min = t_min;
    c.sp = struct;
    c.sp.t_slice_minmax = [t_sliced(1), t_sliced(end)];

    info_local.sc_current = info_local.sc_current * 1e4;
    info_local.pe_current = info_local.pe_current * 1e4;
    c.auc.sc_units_intensity = '0.1 x mA';
    c.auc.pe_units_intensity = '0.1 x mA';

    info_local.datetime_posix = posixtime(info_local.datetime);  % re-gen the posixtime

    cfg_proc_local = c;

    f_pregen = str_participant;

    d_proc_local = fullfile(d_proc, 'preproc_tables', d_out, str_participant);
    if not(exist(d_proc_local, 'dir') == 7), mkdir(d_proc_local); end

    % [info_local_temp, cfg_proc_local, ep_sliced, t_sliced] = ...
    % sanitize_for_export(info_local, info_local.Properties.UserData, ep_sliced);
    p = fullfile(d_proc_local, sprintf('%s_table.csv', f_pregen));
    disp(p);
    writetable(info_local, p);
    toml.write(fullfile(d_proc_local, sprintf('%s_cfg_proc.toml', f_pregen)), cfg_proc_local);
    save(fullfile(d_proc_local, sprintf('%s_ep_matrix.mat', f_pregen)), 'ep_sliced', 't_sliced', 'cfg_proc_local');

end