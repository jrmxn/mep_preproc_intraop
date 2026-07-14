% NO LONGER USED

clear;
addpath(fullfile('..', '..', '..'));
set_env;

p_merged = fullfile(getenvc('D_DATA'), 'proc_records', 'T_merged');
p_merged_augmented = fullfile(getenvc('D_DATA'), 'proc_records', 'T_merged_augmented');
d_preproc_records = fullfile(getenvc('D_DATA'), 'preproc_flattened');
d_cell = dir(d_preproc_records);
d_cell = d_cell([d_cell.isdir]);
d_cell(1:2) = [];
cell_alias = string({d_cell.name});

%%
% n.b. this is a stopgap measure.

%%
T_loaded = load(p_merged);T = T_loaded.T;
row = T(1, :);
row.recordID = {''};

for ix_cell_alias = 1:length(cell_alias)
    str_alias = cell_alias(ix_cell_alias);
    
    ephys_info = load(fullfile(d_preproc_records, str_alias, sprintf('%s_info.mat', str_alias)));
    ephys_info = ephys_info.info_flat;
    if isempty(ephys_info), continue;end  % this is temporary I think
    if not(ephys_info.Properties.UserData.device == "xltek-protektor32"), continue; end
    ephys = load(fullfile(d_preproc_records, str_alias, sprintf('%s.mat', str_alias)));
    
    for ix_ephys_info = 1:height(ephys_info)
        row_in = ephys_info(ix_ephys_info, :);
        ephys_trial = ephys.trials_flat{ix_ephys_info};
        row_out = row;
        
        %% match the labels
        ephys_trial_adjusted = ephys_trial;
        data_temp = zeros(size(ephys_trial_adjusted.data, 2), length(row.label));
        for ix_label = 1:length(row.label)
            
            case_muscle = strcmpi(ephys_trial_adjusted.vec_channel, row.label{ix_label});
            if sum(case_muscle)==1
                data_temp(:, ix_label) = ephys_trial_adjusted.data(case_muscle, :);
            end
        end
        ephys_trial_adjusted.data = data_temp;
        ephys_trial_adjusted.chanlocs.labels = string(row.label);
        
        d = ephys_trial.Stimuli.DataSweepTriggerDelay;  % I think that this is what this is...
        % but it is 0 anyway for the protektor32. It may also be defined
        % positive instead of -ve in genreal. Would need co check, but
        % doesn't matter here.
        assert(d<=0, '???');
        
        srate = ephys_trial.datalength/ephys_trial.sweep;
        t_protektor32 = d + 0:1/srate:d + (ephys_trial.datalength - 1)/srate;
        t_protektor32 = t_protektor32(:);
        
        ephys_trial_adjusted.xmin = -row.stim_delay * 1e-3;
        ephys_trial_adjusted.xmax = row.duration - row.stim_delay * 1e-3;
        
        t_row = [-row.stim_delay * 1e-3:1/row.frequency(1):row.duration - row.stim_delay * 1e-3 - 1/row.frequency(1)];
        data_temp = interp1(t_protektor32, ephys_trial_adjusted.data, t_row);
        data_temp(isnan(data_temp)) = 0;
        ephys_trial_adjusted.data = data_temp;
        
        %%
        cell_electrode = group_electrodes(row_in.electrode);
        
        row_out.duration = ephys_trial_adjusted.xmax - ephys_trial_adjusted.xmin;
        row_out.ns = length(ephys_trial_adjusted.chanlocs.labels);
        row_out.label = cellstr(ephys_trial_adjusted.chanlocs.labels);
        row_out.frequency = repmat(srate, 1, length(ephys_trial_adjusted.chanlocs.labels));
        row_out.datetime = row_in.datetime;
        row_out.data = {ephys_trial_adjusted.data.'};
        % row_out.ep_type
        % row_out.entry_type
        row_out.str_device = cellstr(ephys.etc.device);
        %         row_out.subject = cellstr("P_S0AAAAA" + strrep(ephys.subject, 'sub-', ''));
        row_out.subject = cellstr(ephys.particpant_id);
        row_out.amplitude = ephys_trial_adjusted.Stimuli.DiscreteStimuli{1}.SensedCurrent;
        row_out.count = length(ephys_trial_adjusted.Stimuli.DiscreteStimuli);
        row_out.extra = {'-'};
        row_out.horizontal = {char(row_in.laterality)};
        row_out.vertical = {char(row_in.level)};
        row_out.electrode = row_in.electrode;
        row_out.electrode_type = group_electrodes(row_in.electrode);
        row_out.electrode_configuration = row_in.electrode_configuration;
        row_out.rep_rate = ephys_trial_adjusted.ActualRepRate;
        row_out.pulse_width = ephys_trial_adjusted.Stimuli.DiscreteStimuli{1}.ElectricalPulses{1}.PulseWidth;
        row_out.subject_alias = cellstr(ephys.particpant_id);  % cellstr(ephys.subject);
        row_out.device = ephys_info.Properties.UserData.device;
        
        row_out.stim_delay = - ephys_trial_adjusted.xmin * 1e3;
        row_out.position = {char(row_in.level + '_' + row_in.laterality)};
        row_out.data_valid = {true(size(ephys_trial_adjusted.data.'))};
        
        T(end + 1, :) = row_out;
        
    end
    T.Properties.UserData.cell_sub = [T.Properties.UserData.cell_sub, row_out.subject]';
    T.Properties.UserData.(row_out.subject{1}).alias = row_out.subject_alias{1};
end
v = T_loaded.v;
save(p_merged_augmented, 'T', 'v');
