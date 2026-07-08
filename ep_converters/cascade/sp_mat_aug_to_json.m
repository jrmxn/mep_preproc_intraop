function vec_participant = sp_mat_aug_to_json(varargin)
% d.ts_scaling = 1e-6;  % this is actually a constant
% d.split_records = true;
d.participant = [];
d.str_polarity = 'normal';
d.institute = 'NYP-WCMC';
d.is_biphasic = true;
d.str_approach = 'posterior';
d.str_depth = "epidural";  % assume that for all for cascade
d.show_parameters = false;
% d.do_deid = true;
d.merge_json = true;
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);

%%
d_data_coded = fullfile(getenvc('D_DATA_MAPPING'));

cell_sub = dir(d_data_coded);
cell_sub = cell_sub([cell_sub.isdir]);
cell_sub(strcmpi({cell_sub.name}, '.')) = [];
cell_sub(strcmpi({cell_sub.name}, '..')) = [];
cell_sub = {cell_sub.name};
cell_sub = cell_sub(~strcmpi(cell_sub, 'auxf'));
if not(isempty(v.participant))
    cell_sub = intersect(v.participant, cell_sub);
end
%%
if isempty(cell_sub)
    fprintf('Raw data not present - skipping.\n')
    fprintf('Was looking here:\n%s\n', d_data_noncoded);
    if v.overwrite
        error('But overwrite flag is on!');
    end
end
%%
str_d_spinal = 'd-Spinal Cord (SCS)';
%%
for ix_cell_sub = 1:length(cell_sub)

    participant = cell_sub{ix_cell_sub};
    d_root = fullfile(d_data_coded, participant, 'ephys');
    [d_device, str_device, skip] = get_device(d_root);

    p_in_data_mat_aug = fullfile(d_device, 'data_deid_mat_aug', participant);
    p_out_ephys_json = fullfile(d_root, sprintf('%s_data.%s', participant, 'json'));
    p_out_ephys_info = fullfile(d_root, sprintf('%s_info.mat', participant));
    p_template = fullfile(getenv('D_PROC'), 'auxillary', 'template_core.json');
    p_properties = fullfile(d_device, sprintf('%s_properties.json', participant));

    str_redcapiid = sp_check_redcapid(fullfile(d_data_coded, participant));

    if not(exist(sprintf('%s.mat', p_in_data_mat_aug), 'file')==2)
        fprintf('data_deid_mat_aug does not exist for %s, skipping\n', participant);
        skip = true;
    end
    if skip
        continue;
    end

    do_convert = generate_check(p_out_ephys_json, v.overwrite);
    if do_convert
        s = load(p_in_data_mat_aug);
        data_in = s.record;

        X_template = loadjson(p_template);
        X_template = X_template.iomaxtemplate;
        X = X_template;
        X.HardwareType = data_in(1).str_device;
        % X.PatientGender = ?;
        X.PatientID = participant;
        X.ProcedureName = 'mapping';

        vec_mode = {data_in.ep_type};
        vec_mode = unique(vec_mode(not(cellfun(@isempty, vec_mode))));

        for ix_ep = 1:length(data_in)
            if isempty(data_in(ix_ep).ep_type)
                data_in(ix_ep).ep_type = 'ev';
            end
        end

        ephys_info = struct;

        vec_mode = vec_mode(strcmpi(vec_mode, str_d_spinal));  % temporary - you can also include MEPs and d-waves in the new framework...
        vec_mode_out = cell(size(vec_mode));

        for ix_vec_mode = 1:length(vec_mode)
            str_mode_in = vec_mode{ix_vec_mode};
            if strcmpi(str_mode_in, str_d_spinal)
                str_mode_out = 'research_scs';
                stim_delay = -s.v.stim_delay * 1e-3;
            else
                str_mode_out = strrep(lower(strrep(str_mode_in, '-', '')), ' ', '_');
                stim_delay = 0;
            end
            vec_mode_out{ix_vec_mode} = str_mode_out;

            ephys_trial = data_in(strcmpi({data_in.ep_type}, str_mode_in));
            %             fprintf('%s\n', participant);disp(ephys_trial(1).label(1:3));
            X.Modes{ix_vec_mode}.Name = str_mode_out;
            %%
            if exist(p_properties, 'file') == 2
                corrections_list = loadjson(p_properties);

            else
                corrections_list = struct;
                corrections_list.(str_mode_out) = struct;

            end
            clear correction;
            correction(length(ephys_trial)) = struct;

            for ix_trial = 1:length(ephys_trial)
                fn_corr = fieldnames(corrections_list.(str_mode_out));
                for ix_fn = 1:length(fn_corr)
                    % assuming we don't have any experiments that cross the
                    % midnight boundary...
                    c = corrections_list.(str_mode_out).(fn_corr{ix_fn});
                    t_from = datetime([datestr(ephys_trial(ix_trial).datetime, 'yyyy-mm-dd'), 'T', c.from], 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
                    t_to = datetime([datestr(ephys_trial(ix_trial).datetime, 'yyyy-mm-dd'), 'T', c.to], 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
                    if (ephys_trial(ix_trial).datetime >= t_from) && ( ephys_trial(ix_trial).datetime <= t_to)
                        fn_corr_local = fieldnames(c);
                        fn_corr_local(strcmpi(fn_corr_local, 'from') | strcmpi(fn_corr_local, 'to')) = [];

                        for ix_fn_local = 1:length(fn_corr_local)
                            correction(ix_trial).(fn_corr_local{ix_fn_local}) = c.(fn_corr_local{ix_fn_local});
                        end
                    end
                end
            end
            %%

            ephys_info_mode = array2table(zeros(length(ephys_trial), 1)); % grow it, we don't know how many
            ephys_info_mode.Properties.VariableNames = {'set'};

            rm_trial = false(length(ephys_trial), 1);
            for ix_trial = 1:length(ephys_trial)
                trial = X_template.Modes{ix_vec_mode}.Trials{1};
                trial.TrialNumber = ix_trial;

                if isfield(ephys_trial(ix_trial).stim_sc, 'stim_corrupted')
                    trial.custom.stim_corrupted = ephys_trial(ix_trial).stim_sc.stim_corrupted;
                else
                    trial.custom.stim_corrupted = true;
                end
                if not(isfinite(ephys_trial(ix_trial).stim_sc.count)), trial.custom.stim_corrupted = true;end
                if trial.custom.stim_corrupted, rm_trial(ix_trial) = true;                X.Modes{ix_vec_mode}.Trials{ix_trial} = trial;continue;end

                trial.RequestedRepRate = 1/ephys_trial(ix_trial).stim_sc.rep_rate;
                trial.ActualRepRate = trial.RequestedRepRate;
                trial.Timestamp = posixtime(ephys_trial(ix_trial).datetime) * 1e6;
                trial.Stimuli.DataSweepTriggerDelay = 0;
                trial.Stimuli.DataSweepTriggerDelayCustom = stim_delay;
                trial.Stimuli.DiscreteStimuli{1}.Train1PulseCount = ephys_trial(ix_trial).stim_sc.count;

                trial.Stimuli.DiscreteStimuli{1}.SensedCurrent = ephys_trial(ix_trial).stim_sc.amplitude;
                trial.Stimuli.DiscreteStimuli{1}.SensedVoltage = nan;

                [sc_ipi, sc_pw, sc_count, sc_frequency, pw_disp_multiplier] = get_coreparams(ephys_trial(ix_trial), correction(ix_trial), v);

                for ix_pulse = 1:sc_count
                    trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.Displacement = (pw_disp_multiplier * sc_pw + sc_ipi) * (ix_pulse - 1);
                    trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.Intensity = ephys_trial(ix_trial).stim_sc.amplitude;
                    trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.IntensityUnits = 'mA';
                    trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.PulseWidth = sc_pw;
                    trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.Polarity = v.str_polarity;
                    trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.Biphasic = v.is_biphasic;
                end
                n_chan_actual = length(ephys_trial(ix_trial).label);

                trial.Traces(end-(length(trial.Traces) - n_chan_actual) + 1:end) = [];
                for ix_channel = 1:n_chan_actual
                    str_prefilter = ephys_trial(ix_trial).prefilter{ix_channel};
                    str_expression = '.*HP:(?<str_hp>\d*)Hz\sLP:(?<str_lp>\d*)Hz(\sN:(?<str_n>\d*)Hz)*.*';
                    tokens = regexp(str_prefilter, str_expression,'names');

                    trial.Traces{ix_channel}.Timestamp = posixtime(ephys_trial(ix_trial).datetime) * 1e6;
                    trial.Traces{ix_channel}.Channel.Name = ephys_trial(ix_trial).label{ix_channel};

                    trial.Traces{ix_channel}.Channel.HighCut = str2double(tokens.str_hp);
                    trial.Traces{ix_channel}.Channel.LowCut = str2double(tokens.str_lp);
                    if isfield(tokens, 'str_n')
                        trial.Traces{ix_channel}.Channel.Notch = str2double(tokens.str_n);
                    else
                        trial.Traces{ix_channel}.Channel.Notch = nan;
                    end
                    trial.Traces{ix_channel}.Sweep = ephys_trial(ix_trial).duration;

                    trial.Traces{ix_channel}.TraceDataLength = ephys_trial(ix_trial).samples(ix_channel);
                    trial.Traces{ix_channel}.TraceDataScalar = 1;
                    trial.Traces{ix_channel}.TraceData = ephys_trial(ix_trial).data(ix_channel, :);
                    trial.Traces{ix_channel}.Cursors = cell(0, 1);
                end
                trial.custom = struct;
                X.Modes{ix_vec_mode}.Trials{ix_trial} = trial;
            end

            for ix_trial = 1:length(ephys_trial)

                ephys_info_mode.ix(ix_trial) = ix_trial;
                ephys_info_mode.datetime(ix_trial) = ephys_trial(ix_trial).datetime;

                if isfield(ephys_trial(ix_trial).stim_sc, 'stim_corrupted')
                    ephys_info_mode.is_valid(ix_trial) = not(ephys_trial(ix_trial).stim_sc.stim_corrupted);
                else
                    ephys_info_mode.is_valid(ix_trial) = false;
                end
                ephys_info_mode.is_valid(ix_trial) = ephys_info_mode.is_valid(ix_trial) & not(ephys_trial(ix_trial).stim_sc.stim_corrupted);
                if isfield(ephys_trial(ix_trial).stim_sc, 'flag')
                    ephys_info_mode.is_valid(ix_trial) = ephys_info_mode.is_valid(ix_trial) & ephys_trial(ix_trial).stim_sc.flag;
                end
                ephys_info_mode.is_valid(ix_trial) = ephys_info_mode.is_valid(ix_trial) & isfinite(ephys_trial(ix_trial).stim_sc.amplitude);

                if ephys_info_mode.is_valid(ix_trial)
                    ephys_info_mode.is_valid(ix_trial) = ephys_info_mode.is_valid(ix_trial) & isfield(X.Modes{ix_vec_mode}.Trials{ix_trial}, 'Traces');
                end
                if ephys_info_mode.is_valid(ix_trial)
                    ephys_info_mode.is_valid(ix_trial) = ephys_info_mode.is_valid(ix_trial) & ...
                        any(arrayfun(@(gg) any(isfinite(X.Modes{ix_vec_mode}.Trials{ix_trial}.Traces{gg}.TraceData)), [1:length(X.Modes{ix_vec_mode}.Trials{ix_trial}.Traces)]));
                end
                if not(ephys_info_mode.is_valid(ix_trial)), continue;end

                ephys_info_mode.sc_level(ix_trial) = string(ephys_trial(ix_trial).stim_sc.vertical);
                ephys_info_mode.sc_laterality(ix_trial) = string(ephys_trial(ix_trial).stim_sc.horizontal);
                ephys_info_mode.sc_misc(ix_trial) = string(missing);
                ephys_info_mode.sc_electrode(ix_trial) = string(ephys_trial(ix_trial).stim_sc.electrode);
                ephys_info_mode.sc_electrode_type(ix_trial) = string(ephys_trial(ix_trial).stim_sc.electrode_type);
                ephys_info_mode.sc_electrode_configuration(ix_trial) = string(ephys_trial(ix_trial).stim_sc.electrode_configuration);

                ephys_info_mode.iti(ix_trial) = 1/ephys_trial(ix_trial).stim_sc.rep_rate;

                [sc_ipi, sc_pw, sc_count, sc_frequency, pw_disp_multiplier] = get_coreparams(ephys_trial(ix_trial), correction(ix_trial), v);

                ephys_info_mode.sc_count(ix_trial) = sc_count;
                ephys_info_mode.sc_ipi(ix_trial) = sc_ipi;
                ephys_info_mode.sc_pw(ix_trial) = sc_pw;
                ephys_info_mode.sc_frequency(ix_trial) = sc_frequency;
                ephys_info_mode.sc_displacement(ix_trial) = 0;
                ephys_info_mode.sc_approach(ix_trial) = string(v.str_approach);
                ephys_info_mode.sc_polarity(ix_trial) = string(v.str_polarity);
                ephys_info_mode.sc_depth(ix_trial) = string(v.str_depth);
                ephys_info_mode.sc_current(ix_trial) = ephys_trial(ix_trial).stim_sc.amplitude * 1e-3;
                ephys_info_mode.sc_voltage(ix_trial) = 0;

                ephys_info_mode.pe_count(ix_trial) = 0;
                ephys_info_mode.pe_ipi(ix_trial) = 0;
                ephys_info_mode.pe_pw(ix_trial) = 0;
                ephys_info_mode.pe_polarity(ix_trial) = string(missing);
                ephys_info_mode.pe_biphasic(ix_trial) = true;  % default to true because missing is not allowed
                ephys_info_mode.pe_voltage(ix_trial) = 0;
                ephys_info_mode.pe_current(ix_trial) = 0;
                ephys_info_mode.pe_frequency(ix_trial) = 0;
                ephys_info_mode.pe_displacement(ix_trial) = 0;

                ephys_info_mode.pe_laterality(ix_trial) = string(missing);
                ephys_info_mode.pe_nerve(ix_trial) = string(missing);

                ephys_info_mode.cx_count(ix_trial) = 0;
                ephys_info_mode.cx_laterality(ix_trial) = "";
                ephys_info_mode.cx_stimulation_type(ix_trial) = "none";
                ephys_info_mode.cx_stimulation_mep_side(ix_trial) = string(missing);
                ephys_info_mode.cx_stimulation_configuration(ix_trial) = string(missing);
                ephys_info_mode.cx_ipi(ix_trial) = 0;
                ephys_info_mode.cx_frequency(ix_trial) = 0;
                ephys_info_mode.cx_displacement(ix_trial) = 0;
                ephys_info_mode.cx_pw(ix_trial) = 0;
                ephys_info_mode.cx_polarity(ix_trial) = string(missing);
                ephys_info_mode.cx_biphasic(ix_trial) = false;
                ephys_info_mode.cx_current(ix_trial) = 0;
                ephys_info_mode.cx_voltage(ix_trial) = 0;

                ephys_info_mode.sweep(ix_trial) = ephys_trial(ix_trial).duration;
                ephys_info_mode.device(ix_trial) = X.HardwareType;

                ephys_info_mode.set_sequence(ix_trial) = string(missing);
                ephys_info_mode.set_group(ix_trial) = string(missing);
                ephys_info_mode.cx_pct(ix_trial) = double(missing);
                ephys_info_mode.sc_pct(ix_trial) = double(missing);
                ephys_info_mode.moi(ix_trial) = string(missing);
                ephys_info_mode.muscle_targeted(ix_trial) = string(missing);

            end

            ephys_info_mode(rm_trial, :) = [];
            X.Modes{ix_vec_mode}.Trials(:, rm_trial) = [];

            ephys_info_mode.set = [];
            ephys_info_mode.non_summarised(:) = false;
            ephys_info_mode.sc_biphasic(:) = v.is_biphasic;
            ephys_info_mode.institute(:) = string(v.institute);
            ephys_info_mode.main_targeted_side(:) = "";
            ephys_info_mode.misc(:) = "";
            ephys_info_mode.sc_misc(:) = "";
            ephys_info_mode.fs(:) = nan;  % if you ever need it you can put it in...
            ephys_info_mode.average_count(:) = 1;

            ephys_info_mode.sc_impedance1(:) = nan;
            ephys_info_mode.sc_impedance2(:) = nan;
            

            ephys_info_mode.participant(:) = string(participant);

            ephys_info.Modes{ix_vec_mode} = ephys_info_mode;


            if v.show_parameters
                for ix_trial = 1:height(ephys_info_mode)
                    clf;
                    try
                        ix = 1;trial = X.Modes{ix_vec_mode}.Trials{ix_trial};
                    catch
                        keyboard;
                    end
                    if ephys_info_mode.is_valid(ix_trial)
                        plot(linspace(0, trial.Traces{ix}.Sweep, trial.Traces{ix}.TraceDataLength), trial.Traces{ix}.TraceData);
                        g = trial.Stimuli.DataSweepTriggerDelayCustom;
                        hold on;
                        for ix_count = 1:ephys_info_mode.sc_count(ix_trial)
                            plot(ones(1, 2) * (ephys_info_mode.sc_ipi(ix_trial) + 2 * ephys_info_mode.sc_pw(ix_trial)) * (ix_count - 1) - g, get(gca, 'ylim'), 'k-');
                        end
                        title(sprintf('%s %s    %s', string(ephys_info_mode.datetime(ix_trial)), participant, string(ephys_info_mode.sc_count(ix_trial))));
                        xlim([-1e-3, 10e-3] - g);
                        grid on;
                        drawnow;pause(25e-3);
                    end
                    clear trial;
                end
            end


        end


        %% Anon the rest of timestamps
        if isfield(ephys_info, 'Modes')
            dt_day = min(ephys_info.Modes{1}.datetime);
            dt_day = dateshift(dt_day, 'start', 'day');
            X.StartDate = Inf;
            for ix_vec_mode = 1:length(ephys_info.Modes)
                ephys_info.Modes{ix_vec_mode}.datetime = anon_datetime(ephys_info.Modes{ix_vec_mode}.datetime, dt_day);
                for ix_trial = 1:length(X.Modes{ix_vec_mode}.Trials)
                    X.Modes{ix_vec_mode}.Trials{ix_trial}.Timestamp = ...
                        anon_timestamp(X.Modes{ix_vec_mode}.Trials{ix_trial}.Timestamp, dt_day);
                end
                if X.StartDate > X.Modes{ix_vec_mode}.Trials{1}.Timestamp
                    X.StartDate = X.Modes{ix_vec_mode}.Trials{1}.Timestamp;
                end
            end
        end
        %%
        % add a single custom field
        X.etc = s.v;

        ephys_info.etc = v;
        ephys_info.etc.vec_str_mode = [string(vec_mode_out)];

        ephys_info.etc.redcap_id = str_redcapiid;

        % now save as json
        savejson('Cases', {X}, p_out_ephys_json);  %  surgical studio format
        save(p_out_ephys_info, 'ephys_info');  % helper table for eeglab format
    end
end
vec_participant = string(cell_sub);
end


function [sc_ipi, sc_pw, sc_count, sc_frequency, pw_disp_multiplier] = get_coreparams(ephys_trial, correction, v)

if v.is_biphasic
    pw_disp_multiplier = 2;
else
    pw_disp_multiplier = 1;
end
sc_ipi = ephys_trial.stim_sc.pulse_sep * 1e-3;
sc_pw = ephys_trial.stim_sc.pulse_width * 1e-6;
sc_count = ephys_trial.stim_sc.count;
if isfield(correction, 'sc_ipi')
    if not(isempty(correction.sc_ipi))
        sc_ipi = correction.sc_ipi;
    end
end
if isfield(correction, 'sc_pw')
    if not(isempty(correction.sc_pw))
        sc_pw = correction.sc_pw;
    end
end
if isfield(correction, 'sc_count')
    if not(isempty(correction.sc_count))
        sc_count = correction.sc_count;
    end
end
if sc_count > 1
    sc_frequency = 1/((sc_pw * pw_disp_multiplier) + sc_ipi);
else
    sc_ipi = 0;
    sc_frequency = 0;
end

end