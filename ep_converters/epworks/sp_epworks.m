function sp_epworks(participant, varargin)
d.saveas_type = "ss_json";
d.sweep_delay = 0;
d.plot_shock_channel = nan;
d.load_amplitudes = true;
d.figvisible = 'off';
d.figformat = 'png';
d.config = 'epworks';
d.show_parameters = false;
d.figsave = true; % for pdf/png only
d.fontsizeAxes = 7;
d.fontsizeText = 6;
d.overwrite_stimamp_extract = false;
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);

%%
d_root = fullfile(getenv('D_DATA_SCAP'), participant, 'ephys');
d_device = fullfile(d_root, 'xltek-protektor32');
p_template = fullfile(getenv('D_PROC'), 'auxillary', 'template_core.json');

p_events = fullfile(d_device, sprintf('%s_events.csv', participant));
p_properties = fullfile(d_device, sprintf('%s_properties.json', participant));
p_exceptions = fullfile(d_device, sprintf('%s_exceptions.json', participant));
p_stimamp_zip = fullfile(d_device, sprintf('%s_stimamp.zip', participant));
p_stimamp_out = fullfile(d_device, sprintf('%s_stimamp.csv', participant));
p_extracted_traces_zip = fullfile(d_device, sprintf('%s_extracted_traces.zip', participant));
if strcmpi(v.saveas_type, 'ss_json')  % surgical studio json
    format_dat = 'json';
else
    format_dat = 'mat';
end
p_out_ephys_json = fullfile(d_root, sprintf('%s_data.%s', participant, format_dat));
p_out_ephys_mat = fullfile(d_root, sprintf('%s_datmat.%s', participant, format_dat));
p_out_ephys_info = fullfile(d_root, sprintf('%s_info.mat', participant));

str_redcapiid = sp_check_redcapid(fullfile(getenv('D_DATA_SCAP'), participant));

if v.load_amplitudes
    T_amp = sp_stimamp_extract(p_stimamp_zip, p_stimamp_out, 'overwrite', v.overwrite_stimamp_extract);
end

properties = loadjson(p_properties);
properties.muscles = string(properties.muscles);
properties.device = string(properties.device);
v.device = properties.device;
t_min = 0;

opts = detectImportOptions(p_events, "ReadRowNames", true);
opts.VariableTypes = strrep(opts.VariableTypes, 'char', 'string');
events = readtable(p_events, opts);
events.datetime = datetime(events.datetime, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');

str_dos = '1972-01-01';  % for anon -

datetime_experiment_start = datetime([str_dos, ' ', properties.experiment_start], 'InputFormat','yyyy-MM-dd HH:mm:ss');

%%
if (exist(p_exceptions, 'file') == 2)
    exceptions = loadjson(p_exceptions);
else
    exceptions = struct;
end
%%
% 2022-03-07 add default that if we do not specificy, we assume stim type
% is epidural.
if not(any(strcmpi(events.Properties.VariableNames, 'stim_sc_depth')))
    events.stim_sc_depth(:) = "epidural";
end

%%
es = '';
if isfinite(v.plot_shock_channel)
    es = string(v.plot_shock_channel);
    es = es.join('_');
    es = sprintf('_sc%s', es);
end

%%
FIGFORMAT = getenv('FIGFORMAT');
if not(isempty(FIGFORMAT))
    v.figformat = FIGFORMAT;
    warning('Grabbing figure format from environment variable.');
end
p_fig = fullfile(getenvc('D_REPORTS'), sprintf('%s_%s_%s%s', datestr(datetime, 'YYYY-mm-DD'), v.config, participant, es));
if not(exist(p_fig, 'dir')==7), mkdir(p_fig);end

print_local = @(h, dim) printForPub(h, sprintf('%s', h.Name), 'doPrint', v.figsave,...
    'fformat', v.figformat , 'physicalSizeCM', dim, 'saveDir', p_fig, ...
    'fontsizeText', v.fontsizeText, 'fontsizeAxes', v.fontsizeAxes, 'append_format_to_dir', true);

%%
muscles = properties.muscles;
muscles = strrep(muscles, 'LAHB', 'LAH');
muscles = strrep(muscles, 'RAHB', 'RAH');
muscles = strrep(muscles, 'LTricep', 'LTric');
muscles = strrep(muscles, 'RTricep', 'RTric');

%%
do_ephys_extract = generate_check(p_out_ephys_json, v.overwrite);
if do_ephys_extract
    d_temp = tempname;
    mkdir(tempname);
    try
        unzip(p_extracted_traces_zip, d_temp);
        l_p = glob(fullfile(d_temp, '**.csv'));

        str_file_expression = 'stim\s\[(?<str_muscle>.+)\]\s-\sSet\s#(?<str_set>\d+)\s\((?<str_time>\d+_\d+_\d+)\).*';
        max_n_set = 0;

        for ix = 1:length(l_p)
            p = l_p{ix};
            [~, f, ~] = fileparts(p);
            tokens = regexp(f,str_file_expression,'names');
            n_set = str2double(tokens.str_set);
            max_n_set(n_set>=max_n_set) = n_set;
        end

        for ix = 1:length(l_p)
            p = l_p{ix};

            opts = detectImportOptions(p, "ReadRowNames", false, 'NumHeaderLines',  0);
            opts.VariableTypes = strrep(opts.VariableTypes, 'char', 'string');
            y = readtable(p, opts);
            y = table2array(y);
            n_samples = length(y);

            if ix == 1  % init
                ephys = struct;
                for ix_local = 1:max_n_set
                    ephys.trial(ix_local).data = nan(n_samples, length(muscles));
                end
            end

            [~, f, ~] = fileparts(p);

            tokens = regexp(f,str_file_expression,'names');
            tokens.str_muscle = string(strrep(tokens.str_muscle, ' ', ''));
            tokens.n_set = str2double(tokens.str_set);

            tokens.datetime = datetime([str_dos, ' ', tokens.str_time], 'InputFormat','yyyy-MM-dd HH_mm_ss');

            case_muscle = properties.muscles == tokens.str_muscle;
            if isfield(exceptions, 'channel_invert')  % intorduced for ant-post flip in scapptio008
                channel_invert_after = datetime([str_dos, ' ', exceptions.channel_invert_after], 'InputFormat','yyyy-MM-dd HH:mm:ss');
                if (tokens.datetime > channel_invert_after)
                    if isfield(exceptions.channel_invert, tokens.str_muscle)
                        invert_sign = exceptions.channel_invert.(tokens.str_muscle);
                        y = y * invert_sign;
                    else
                        keyboard;  % just fix manually in the json
                    end
                end
            end

            try
                assert(sum(case_muscle)==1, 'Channel label inconsistency');
            catch
                keyboard;
            end
            ephys.trial(tokens.n_set).nbchan = length(properties.muscles);
            ephys.trial(tokens.n_set).pnts = length(y);
            ephys.trial(tokens.n_set).xmin = t_min;

            ephys.trial(tokens.n_set).chanlocs.labels = muscles;
            try
                ephys.trial(tokens.n_set).data(:, case_muscle) = y(:);
            catch
                % Maybe the muscles are mislabeled in EPworks. Correct by
                % fixing the traces file names: 1) unzip 2) rename, e.g.:
                % 's/AHB/EHL/g' * 3) zip
                keyboard
            end
            ephys.trial(tokens.n_set).times = [];
            ephys.trial(tokens.n_set).srate = [];
            ephys.trial(tokens.n_set).xmax = [];
            ephys.trial(tokens.n_set).ns = n_samples;
            ephys.trial(tokens.n_set).datetime = tokens.datetime;
        end

        ephys_info_core = struct;
        ephys_info_mode = array2table(zeros(length(ephys.trial), 1)); % grow it, we don't know how many
        ephys_info_mode.Properties.VariableNames = {'set'};

        ix_count = 1;
        for ix_set = 1:length(ephys.trial)

            if not(isempty(ephys.trial(ix_set).datetime))
                dt_diff = ephys.trial(ix_set).datetime - events.datetime;
                dt_diff(dt_diff<0) = NaT - NaT;
                [check_me, ix_min] = min(dt_diff);
                ephys_info_mode.set(ix_set) = ix_set;

                ephys_info_mode.ix(ix_set) = ix_count;
                ephys_info_mode.datetime(ix_set) = ephys.trial(ix_set).datetime;

                ephys_info_mode.sc_count(ix_set) = events.stim_sc_count(ix_min);
                ephys_info_mode.sc_level(ix_set) = string(events.stim_sc_level(ix_min));
                ephys_info_mode.sc_laterality(ix_set) = string(events.stim_sc_laterality(ix_min));
                ephys_info_mode.sc_misc(ix_set) = string(missing);
                ephys_info_mode.sc_electrode(ix_set) = string(events.stim_sc_electrode(ix_min));
                ephys_info_mode.sc_electrode_type(ix_set) = group_electrodes(string(events.stim_sc_electrode(ix_min)));
                ephys_info_mode.sc_electrode_configuration(ix_set) = string(events.stim_sc_electrode_configuration(ix_min));

                ephys_info_mode.iti(ix_set) = events.stim_sc_iti(ix_min);

                ephys_info_mode.sc_depth(ix_set) = events.stim_sc_depth(ix_min);
                sc_ipi = events.stim_sc_ipi(ix_min);
                sc_frequency = events.stim_sc_frequency(ix_min);
                if events.stim_sc_count(ix_min) == 1
                    sc_ipi = 0;
                    sc_frequency = 0;
                end
                ephys_info_mode.sc_frequency(ix_set) = sc_frequency;
                ephys_info_mode.sc_ipi(ix_set) = sc_ipi;
                ephys_info_mode.sc_pw(ix_set) = events.stim_sc_pw(ix_min);
                ephys_info_mode.sc_approach(ix_set) = string(events.stim_sc_approach(ix_min));
                ephys_info_mode.sc_polarity(ix_set) = string(events.stim_sc_polarity(ix_min));

                ephys_info_mode.pe_count(ix_set) = 0;
                ephys_info_mode.pe_ipi(ix_set) = 0;
                ephys_info_mode.pe_pw(ix_set) = 0;
                ephys_info_mode.pe_polarity(ix_set) = string(missing);
                ephys_info_mode.pe_biphasic(ix_set) = true;  % default to true because missing is not allowed
                ephys_info_mode.pe_voltage(ix_set) = 0;
                ephys_info_mode.pe_current(ix_set) = 0;
                ephys_info_mode.pe_frequency(ix_set) = 0;
                ephys_info_mode.pe_displacement(ix_set) = 0;

                ephys_info_mode.pe_laterality(ix_set) = string(missing);
                ephys_info_mode.pe_nerve(ix_set) = string(missing);

                ephys_info_mode.cx_count(ix_set) = nan;
                ephys_info_mode.cx_laterality(ix_set) = "";
                ephys_info_mode.cx_stimulation_type(ix_set) = "none";
                ephys_info_mode.cx_stimulation_configuration(ix_set) = string(missing);
                ephys_info_mode.cx_stimulation_mep_side(ix_set) = string(missing);
                ephys_info_mode.cx_ipi(ix_set) = 0;
                ephys_info_mode.cx_frequency(ix_set) = 0;

                ephys_info_mode.set_sequence(ix_set) = string(missing);
                ephys_info_mode.set_group(ix_set) = string(missing);
                ephys_info_mode.cx_pct(ix_set) = double(missing);
                ephys_info_mode.sc_pct(ix_set) = double(missing);
                ephys_info_mode.moi(ix_set) = string(missing);
                ephys_info_mode.muscle_targeted(ix_set) = string(missing);

                ephys_info_mode.cx_pw(ix_set) = 0;
                ephys_info_mode.cx_polarity(ix_set) = string(missing);

                ephys_info_mode.cx_biphasic(ix_set) = false;
                ephys_info_mode.cx_current(ix_set) = 0;
                ephys_info_mode.cx_voltage(ix_set) = 0;

                ephys_info_mode.sweep(ix_set) = (events.timebase(ix_min) * properties.divisions) * 1e-3;  % this is also in T_amp (as timebase but it is sometimes wrong there - due to xltek bugs)
                %                 ephys_info_mode.sweep_delay(ix_set) = v.sweep_delay;

                ephys_info_mode.device(:) = string(properties.device);
                ephys_info_mode.mode(ix_set) = events.mode(ix_min);
                ephys_info_mode.is_valid(ix_set) = logical(events.is_valid(ix_min));

                if v.load_amplitudes
                    case_stimamp = T_amp.set == ix_set;
                    assert(sum(case_stimamp)<=1, '?');
                    ephys_info_mode.sc_voltage(ix_set) = nan;
                    if sum(case_stimamp) == 1
                        ephys_info_mode.sc_current(ix_set) = T_amp.stimamp(case_stimamp) * 1e-3;
                    else
                        ephys_info_mode.sc_current(ix_set) = nan;
                    end
                else
                    ephys_info_mode.sc_current(ix_set) = nan;
                end
                ix_count = ix_count + 1;
            end
        end

        case_rm = ephys_info_mode.ix == 0;
        case_rm = case_rm | ephys_info_mode.datetime < datetime_experiment_start;
        ephys_info_mode(case_rm, :) = [];
        ephys.trial(case_rm) = [];

        for ix_trial = 1:height(ephys_info_mode)
            n_samples = ephys.trial(ix_trial).ns;
            t_max = ephys_info_mode.sweep(ix_trial);
            t = 0:t_max/n_samples:t_max - t_max/n_samples;
            srate = n_samples/t_max;
            ephys.trial(ix_trial).times = t;
            ephys.trial(ix_trial).srate = srate;
            ephys.trial(ix_trial).xmax = t_max;
        end

        % if length(unique(cellfun(@length, ephys.time))) == 1
        %     time_unique = unique(cell2mat(ephys.time.'), 'rows');
        %     if size(time_unique, 1) == 1
        %         ephys.time_unique = time_unique;
        %     end
        % end


        if isfinite(v.plot_shock_channel)
            % this is nice code... so keep it.
            %             hd = struct;
            %             vec_fs = unique([ephys.trial.srate]);
            %             for ix_vec_fs = 1:length(vec_fs)
            %                 fs = vec_fs(ix_vec_fs);
            %                 hd.(sprintf('f%d', fs)) = get_filter(fs);
            %             end

            for ix_trial = 1:height(ephys_info_mode)
                h_f = figure( ...
                    'Name', sprintf('%s_%04d', participant, ix_trial), ...
                    'Visible', v.figvisible);

                fs = ephys.trial(ix_trial).srate;
                y = ephys.trial(ix_trial).data(:, v.plot_shock_channel);
                y = nanmean(y, 2);
                y = y.^2;
                if not(all(isfinite(y(:)))); continue;end
                %                 yf = filtfilt(hd.(sprintf('f%d', fs)), y);
                [pxx,f] = pwelch(y, length(y), [], [], fs);
                y_th = 10;
                di = diff(find(y>y_th));di(di<=2) = [];di = median(di);
                f_set = 1/ephys_info_mode.sc_ipi(ix_trial);
                f_est = 1/((1/fs)*di);

                h_a = subplot(2, 1, 1);cla;hold on;
                plot(ephys.trial(ix_trial).times * 1000, y);
                title(datestr(ephys_info_mode.datetime(ix_trial)));
                %                 subplot(3, 1, 2);
                %                 plot(ephys.trial(ix_trial).times, yf);
                h_a.XTick = [0:10:100, 150:50:500];h_a.XTickLabelRotation = 90;
                grid on;

                h_b = subplot(2, 1, 2);cla;hold on;
                plot(f, pxx);xlim([8, 112]);
                plot(f_set * ones(1, 2), get(gca, 'ylim'), 'k--');
                plot(f_est * ones(1, 2), get(gca, 'ylim'), 'r--');
                title(sprintf('%d, f = %0.0fHz, f_{est} = %0.0fHz', ix_trial, f_set, f_est));
                h_b.XTick = [10:10:110];h_b.XTickLabelRotation = 90;
                grid on;

                drawnow;

                print_local(h_f, [25, 8]);
                close all;
            end
        end

        ephys.setname = "";
        ephys.filename = "";
        ephys.subject = participant;
        ephys.group = "intraop-mapping";
        ephys.comments = "";
        ephys.etc = v;
        ephys.trials = height(ephys_info_mode);


        assert(length(ephys_info_mode.set) == ephys.trials, '?');

        [status, message, messageid] = rmdir(d_temp, 's');
    catch errt
        [status, message, messageid] = rmdir(d_temp, 's');
        rethrow(errt);
    end

    % ok - that's great and all, but I actually want this to be in a
    % structure like the iomax data now so...
    ephys_template = loadjson(p_template);
    ephys_template = ephys_template.iomaxtemplate;
    ephys_out = ephys_template;
    ix_mode = 1;
    ephys_out.HardwareType = properties.device;
    % X.PatientGender = ?;
    ephys_out.PatientID = participant;
    ephys_out.ProcedureName = ephys.group;
    ephys_out.Modes{ix_mode}.Name = 'research_scs';
    % technically there should be a separate mode for multipulse to match
    % the surgical studio json output

    ephys_out.StartDate = posixtime(datetime_experiment_start) * 1e6;

    for ix_trial = 1:ephys.trials
        trial = ephys_template.Modes{ix_mode}.Trials{1};  % yes, it should be 1
        trial.TrialNumber = ix_trial;
        trial.RequestedRepRate = 1/ephys_info_mode.iti(ix_trial);
        trial.ActualRepRate = 1/ephys_info_mode.iti(ix_trial);
        trial.Timestamp = posixtime(ephys_info_mode.datetime(ix_trial)) * 1e6;
        trial.Stimuli.DataSweepTriggerDelay = 0;
        trial.Stimuli.DataSweepTriggerDelayCustom = v.sweep_delay;
        trial.Stimuli.DiscreteStimuli{1}.Train1PulseCount = ephys_info_mode.sc_count(ix_trial);

        trial.Stimuli.DiscreteStimuli{1}.SensedCurrent = ephys_info_mode.sc_current(ix_trial);
        trial.Stimuli.DiscreteStimuli{1}.SensedVoltage = ephys_info_mode.sc_voltage(ix_trial);
        sc_pw = ephys_info_mode.sc_pw(ix_trial);
        sc_ipi = ephys_info_mode.sc_ipi(ix_trial);
        if trial.Stimuli.DiscreteStimuli{1}.Train1PulseCount== 1
            sc_ipi = 0;  % in case it is nan;
        end
        for ix_pulse = 1:trial.Stimuli.DiscreteStimuli{1}.Train1PulseCount
            try
                assert(isfinite(sc_ipi), 'if ipi is not finite, single pulse displacement is off');
            catch
                keyboard;
            end
            if properties.biphasic
                pw_disp_multiplier = 2;
            else
                pw_disp_multiplier = 1;
            end
            trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.Displacement = (pw_disp_multiplier * sc_pw + sc_ipi) * (ix_pulse - 1);
            trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.Intensity = ephys_info_mode.sc_current(ix_trial);
            trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.IntensityUnits = properties.units;
            trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.PulseWidth = sc_pw;
            trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.Polarity = ephys_info_mode.sc_polarity(ix_trial);
            trial.Stimuli.DiscreteStimuli{1}.ElectricalPulses{ix_pulse}.Biphasic = properties.biphasic;
        end

        n_chan_actual = length(ephys.trial(ix_trial).chanlocs.labels);

        trial.Traces(end-(length(trial.Traces) - n_chan_actual) + 1:end) = [];
        for ix_channel = 1:n_chan_actual
            trial.Traces{ix_channel}.Timestamp = posixtime(ephys.trial(ix_trial).datetime) * 1e6;
            trial.Traces{ix_channel}.Channel.Name = char(ephys.trial(ix_trial).chanlocs.labels(ix_channel));
            trial.Traces{ix_channel}.Channel.HighCut = properties.hff;
            trial.Traces{ix_channel}.Channel.LowCut = properties.lff;
            trial.Traces{ix_channel}.Channel.Notch = properties.notch;
            trial.Traces{ix_channel}.Sweep = ephys.trial(ix_trial).xmax - ephys.trial(ix_trial).xmin;
            trial.Traces{ix_channel}.TraceDataLength = ephys.trial(ix_trial).pnts;
            trial.Traces{ix_channel}.TraceDataScalar = 1;
            trial.Traces{ix_channel}.TraceData = ephys.trial(ix_trial).data(:, ix_channel).';
            trial.Traces{ix_channel}.Cursors = cell(0, 1);
        end
        ephys.trial(ix_trial).nbchan = n_chan_actual;
        trial.custom.stim_corrupted = false;
        trial.custom.TrialNumberOriginal = ephys_info_mode.ix(ix_trial);
        trial.custom.SetOriginal = ephys_info_mode.set(ix_trial);

        ephys_out.Modes{ix_mode}.Trials{ix_trial} = trial;
    end

    % figure out neighbor sets groupings if they belong to the same trigger
    try
        assert(all(diff(ephys_info_mode.set) == 1), 'The following funciton assumes monotonic set increases...');
    catch
        % I could not extract traces at one set for one file and so this
        % triggered. 'Fixed' by making a fake entry for one muscle (all set to 0)
        % with the missing set index.
        keyboard;
    end
    required_sweep = (1./ephys_info_mode.sc_frequency) .* ephys_info_mode.sc_count;
    required_sweep(not(isfinite(required_sweep))) = ephys_info_mode.sweep(not(isfinite(required_sweep)));
    case_problems = (required_sweep./ephys_info_mode.sweep) > 1;  % for understanding
    required_successive_trials = ceil((required_sweep./ephys_info_mode.sweep) - 1);
    required_successive_trials_fixed = required_successive_trials;
    set_new = ephys_info_mode.set;
    for ix_row = 1:height(ephys_info_mode)
        for ix_row_internal = ix_row + 1:ix_row + required_successive_trials_fixed(ix_row)
            required_successive_trials_fixed(ix_row_internal) = 0;  % this is important!
            set_new(ix_row_internal) = ephys_info_mode.set(ix_row);
        end
    end

    % now merge neighbor sets if they are grouped
    assert(required_successive_trials_fixed(1)==0, 'Next line is flawed if this is true -');
    ephys_info_mode_merged = ephys_info_mode(1, :);
    ephys_trials_merged = ephys_out.Modes{ix_mode}.Trials(1);
    for ix_row = 2:height(ephys_info_mode)
        ix_set = ephys_info_mode.set(ix_row);
        ix_set_new = set_new(ix_row);
        if ix_set == ix_set_new
            % just rebuild the table
            ephys_info_mode_merged = [ephys_info_mode_merged; ephys_info_mode(ix_row, :)];
            ephys_trials_merged = [ephys_trials_merged, ephys_out.Modes{ix_mode}.Trials(ix_row)];
        else
            % append to entry instead of adding as new trial;
            for ix_channel = 1:length(ephys_trials_merged{end}.Traces)
                trace_temp = ephys_trials_merged{end}.Traces{ix_channel};
                trace_temp.Sweep = trace_temp.Sweep + ephys_out.Modes{ix_mode}.Trials{ix_row}.Traces{ix_channel}.Sweep;
                trace_temp.TraceDataLength = trace_temp.TraceDataLength + ephys_out.Modes{ix_mode}.Trials{ix_row}.Traces{ix_channel}.TraceDataLength;
                trace_temp.TraceData = [trace_temp.TraceData, ephys_out.Modes{ix_mode}.Trials{ix_row}.Traces{ix_channel}.TraceData];

                ephys_trials_merged{end}.Traces{ix_channel} = trace_temp;
            end
            ephys_info_mode_merged.sweep(end) = ephys_info_mode_merged.sweep(end) + ephys_info_mode.sweep(ix_row);
        end
    end

    ephys_out.Modes{ix_mode}.Trials = ephys_trials_merged;
    ephys_info_mode = ephys_info_mode_merged;

    ephys_info_core.Modes{ix_mode} = ephys_info_mode;

    % add a single custom field
    ephys_out.etc = ephys.etc;

    ephys_info_core.Modes{ix_mode}.set = [];
    ephys_info_core.Modes{ix_mode}.non_summarised(:) = false;
    ephys_info_core.Modes{ix_mode}.sc_biphasic(:) = properties.biphasic;
    ephys_info_core.Modes{ix_mode}.sc_voltage(:) = nan;
    ephys_info_core.Modes{ix_mode}.participant(:) = string(participant);
    ephys_info_core.Modes{ix_mode}.institute(:) = string(properties.institute);
    ephys_info_core.Modes{ix_mode}.main_targeted_side(:) = "";
    ephys_info_core.Modes{ix_mode}.misc(:) = "";
    ephys_info_core.Modes{ix_mode}.sc_misc(:) = "";
    ephys_info_core.Modes{ix_mode}.sc_displacement(:) = 0;
    ephys_info_core.Modes{ix_mode}.cx_displacement(:) = 0;
    ephys_info_core.Modes{ix_mode}.fs(:) = nan;  % if you ever need it you can put it in...
    ephys_info_core.Modes{ix_mode}.average_count(:) = 1;

    ephys_info_core.Modes{ix_mode}.sc_impedance1(:) = nan;
    ephys_info_core.Modes{ix_mode}.sc_impedance2(:) = nan;

    %
    ephys_info_core.etc = v;
    ephys_info_core.etc.vec_mode = [string(ephys_out.Modes{ix_mode}.Name)];

    %         % even though they get stuck back together later...
    %         % this way the hd mode gets labeled as such
    ephys_out_temp = ephys_out;
    vec_mode = unique(ephys_info_core.Modes{1}.mode); vec_mode = vec_mode(:).';
    ephys_info.etc = ephys_info_core.etc;
    for ix_vec_mode = 1:length(vec_mode)
        case_mode = ephys_info_core.Modes{1}.mode == vec_mode(ix_vec_mode);
        ephys_info.Modes{ix_vec_mode} = ephys_info_core.Modes{1}(case_mode, :);
        ephys_info.Modes{ix_vec_mode}.ix = [1:length(ephys_info.Modes{ix_vec_mode}.ix)].';

        ephys_out_temp.Modes{ix_vec_mode}.Trials = ephys_out.Modes{1}.Trials(1, case_mode);
        ephys_out_temp.Modes{ix_vec_mode}.Name = vec_mode(ix_vec_mode);

    end
    ephys_out = ephys_out_temp;
    ephys_info.etc.vec_mode = vec_mode;

    %     2022-02-28 written more generally in previous block
    %     case_hd = (ephys_info_core.Modes{1}.sc_count>3) & (ephys_info_core.Modes{1}.sc_ipi > 0.005);
    %     ephys_info = ephys_info_core;
    %     if sum(case_hd)>1
    %         % even though they get stuck back together later...
    %         % this way the hd mode gets labeled as such
    %         ephys_info.Modes{2} = ephys_info.Modes{1}(case_hd, :);
    %         ephys_info.Modes{1} = ephys_info.Modes{1}(not(case_hd), :);
    %         ephys_info.Modes{1}.ix = [1:length(ephys_info.Modes{1}.ix)].';
    %         ephys_info.Modes{2}.ix = [1:length(ephys_info.Modes{2}.ix)].';
    %
    %         ephys_out.Modes{2} = ephys_out.Modes{1};
    %         ephys_out.Modes{2}.Trials = ephys_out.Modes{1}.Trials(1, case_hd);
    %         ephys_out.Modes{1}.Trials = ephys_out.Modes{1}.Trials(1, not(case_hd));
    %         ephys_out.Modes{2}.Name = 'research_multipulse';
    %     end

    if v.show_parameters
        ix_vec_mode = 1;
        for ix_trial = 1:length(ephys_out.Modes{ix_vec_mode}.Trials)
            clf;
            trial = ephys_out.Modes{ix_vec_mode}.Trials{ix_trial};
            ephys_info_mode = ephys_info.Modes{ix_vec_mode};
            if ephys_info_mode.is_valid(ix_trial)
                for ix = 1:length(trial.Traces)
                    plot(linspace(0, trial.Traces{ix}.Sweep, trial.Traces{ix}.TraceDataLength), trial.Traces{ix}.TraceData);
                end
                g = trial.Stimuli.DataSweepTriggerDelayCustom;
                hold on;
                for ix_count = 1:ephys_info_mode.sc_count(ix_trial)
                    plot(ones(1, 2) * (ephys_info_mode.sc_ipi(ix_trial) + 1 * ephys_info_mode.sc_pw(ix_trial)) * (ix_count - 1) - g, get(gca, 'ylim'), 'k-');
                end
                title(sprintf('%s %s    %s', string(ephys_info_mode.datetime(ix_trial)), participant, string(ephys_info_mode.sc_count(ix_trial))));
                xlim([-1e-3, 10e-3] - g);
                grid on;
                drawnow;pause(25e-3);
                ylim([-15, 15]);
            end
            clear trial;
        end
    end

    ephys_info.etc.redcap_id = str_redcapiid;

    if strcmpi(v.saveas_type, 'eeglab')
        save(p_out_ephys_mat, 'ephys');
        save(p_out_ephys_info, 'ephys_info');  % helper table for eeglab format
    elseif strcmpi(v.saveas_type, 'ss_json')  % surgical studio json
        savejson('Cases', {ephys_out}, char(p_out_ephys_json));  %  surgical studio format
        save(p_out_ephys_info, 'ephys_info');  % helper table
    else
        error('?');
    end
else
    % you could load here, or do nothing...
end
end

% function hd = get_filter(fs)
% hd = designfilt('bandpassfir','FilterOrder',20, ...
%     'CutoffFrequency1',8,'CutoffFrequency2',120, ...
%     'SampleRate',fs);
% end

function hd = get_filter(fs)
hd = designfilt('highpassiir','FilterOrder',8, ...
    'PassbandFrequency', 110, 'PassbandRipple',0.2, ...
    'SampleRate', fs);
end


