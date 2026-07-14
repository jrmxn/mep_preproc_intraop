function standardise_modes(varargin)
p_standardise_path = mfilename('fullpath');
d_load_data = fileparts(fileparts(p_standardise_path));
addpath(d_load_data);
set_env;

%%
d.participant = [];
d.verbose = false;
d.participant_mapping = 'injury_study';
d.do_save = true;
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);
v = inputParserStructureOverwrite(v);

%%
p_par_list_json = fullfile(getenv('D_PARTICIPANT_MAPPING'), sprintf('%s.json', v.participant_mapping));
p_par_list_toml = fullfile(getenv('D_PARTICIPANT_MAPPING'), sprintf('%s.toml', v.participant_mapping));
if exist(p_par_list_json, 'file') == 2
    s_participant = loadjson(p_par_list_json);
elseif exist(p_par_list_toml, 'file') == 2
    s_participant = toml.read(p_par_list_toml);
    s_participant = toml.map_to_struct(s_participant);
end

cell_participant = fieldnames(s_participant.participant);
cell_participant = cell_participant(:).';
if not(isempty(v.participant))
    cell_participant = intersect(v.participant, cell_participant);
end

%%
proto_muscle_set = ["Trapezius", "Deltoid", "Biceps", "Triceps", "ECR", "FCR", "APB", "ADM", "TA", "EDB", "AH"];
muscle_set = ["L" + proto_muscle_set, "R" + proto_muscle_set].';
eeg_set = ["C3-C4"; "Fpz-Cervical"; "C4-Fpz"; "C3-Fpz"; "Cz-Fpz";"C3-Cervical";"C3-Cz";"C4-Cervical";"C4-Cz";"C4-C3"];
cdp_set = ["D-Rost"; "D-Caud"];
channel_set = [muscle_set; eeg_set; cdp_set];
channel_type = [repmat("EMG", size(muscle_set)); repmat("EEG", size(eeg_set)); repmat("CDP", size(cdp_set))];

proto_muscle_ignore_set = ["EHL", "Quad", "VL", "Psoas"];
muscle_ignore_set = ["L" + proto_muscle_ignore_set, "R" + proto_muscle_ignore_set].';
muscle_ignore_set = [muscle_ignore_set; "Test1-Test2"];
eeg_ignore_set = [];
channel_ignore_set = [muscle_ignore_set; eeg_ignore_set];
%%
d_standardised = fullfile(getenv('D_PROC'), 'preproc_standard');

vec_mode = ["research_scs", "research_multipulse", "research_doublepulse", ...
    "research_paired_averaged", "research_paired_repeat", "research_mep", "research_dwave", "eeg", ...
    "clinical_mep", "research_peripheral", "research_lcswap", "research_scs_pairs", ...
    "research_scs_train", "research_multipulse_brain"];

ep_delay_proto = -0.03;
ep_fs_proto = 6000;
ep_duration_proto = 0.15;


for ix_cell_sub = 1:length(cell_participant)
    participant = cell_participant{ix_cell_sub};

    p_info = fullfile(d_standardised, participant, 'ephys', sprintf('%s_info.mat', participant));
    p_data = fullfile(d_standardised, participant, 'ephys', sprintf('%s_data.mat', participant));

    do_standardise = generate_check(p_data, v.overwrite) || generate_check(p_info, v.overwrite);
    if v.verbose
        fprintf('\n--------\n%s:\n\n', participant);
    end
    if do_standardise
        try
            [participant_check, info_flat, ephys] = load_data('output_type', 'individual_single', ...
                'input_type', 'preproc_flattened', ...
                'calculate_auc', false, ...
                'participant', participant, 'participant_mapping', v.participant_mapping, ...
                'minimal_processing', true);
        catch
            keyboard;
        end
        for ix_mode = 1:length(vec_mode)
            mode = vec_mode(ix_mode);
            if v.verbose
                fprintf('%s\n', mode);
            end
            if (mode == "research_scs") || (mode == "research_mep") || (mode == "clinical_mep") || ...
                    (mode == "research_lcswap") || (mode == "research_scs_pairs") || (mode == "research_peripheral")
                t_proto = [-fliplr(1/ep_fs_proto:1/ep_fs_proto:-ep_delay_proto), 0:1/ep_fs_proto:ep_duration_proto + ep_delay_proto];
                assert(any(t_proto==0), 'I think it is convenient if the proto t has a true 0');
                assert(range(t_proto) == ep_duration_proto, 'range and duration of t_proto do not match');

                did_verbose = false;
                for ix_row = 1:length(ephys.trials_flat(:))
                    if not(info_flat.mode(ix_row) == mode), continue;end

                    trial = ephys.trials_flat{ix_row};
                    hash = hash_trial(trial);
                    try
                        trial = adjust_timebase(trial, ep_fs_proto, t_proto, ep_duration_proto, did_verbose, v);
                    catch
                        keyboard;
                    end
                    info_flat.fs(ix_row) = ep_fs_proto;
%                     if any(trial.vec_channel == "LPsoas")
%     keyboard
% end
                    [trial, did_verbose] = adjust_channels(trial, channel_set, channel_ignore_set, did_verbose, participant, v, hash);

                    ephys.trials_flat{ix_row} = trial;
                end

                info_flat.Properties.UserData.(mode).t = t_proto;
                info_flat.Properties.UserData.(mode).fs = ep_fs_proto;
            elseif (mode == "research_multipulse") || (mode == "research_doublepulse") || (mode == "research_multipulse_brain")
                latch_trial = true;
                for ix_row = 1:length(ephys.trials_flat(:))
                    if not(info_flat.mode(ix_row) == mode), continue;end

                    trial = ephys.trials_flat{ix_row};
                    hash = hash_trial(trial);
                    if latch_trial
                        t_used = linspace(0, trial.sweep, size(trial.data, 2));
                        t_used = t_used + trial.Stimuli.DataSweepTriggerDelayCustom;
                        fs_used = 1./mean(diff(t_used));
                        latch_trial = false;
                    end

                    % do not modify the timing
                    [trial, did_verbose] = adjust_channels(trial, channel_set, channel_ignore_set, did_verbose, participant, v, hash);

                    ephys.trials_flat{ix_row} = trial;

                    ds = [trial.Stimuli.DiscreteStimuli{:}];
                    if isfield(ds, 'SensedCurrent')
                        ds_current = [ds.SensedCurrent];
                    else
                        ds_current = arrayfun(@(i) ds(i).ElectricalPulses{1}.Intensity, 1:length(ds));
                    end
                    ds_current_average = mean(ds_current(ds_current > 1e-4));
                    info_flat.sc_current(ix_row) = ds_current_average;

                    if mode == "research_multipulse_brain"
                        fprintf('Resume wokring here! for loading scap135')
                        keyboard;
                    end
                end

                if latch_trial
                    t_used = [];
                    fs_used = [];
                end
                info_flat.Properties.UserData.(mode).t = t_used;
                info_flat.Properties.UserData.(mode).fs = fs_used;
            elseif (mode == "research_scs_train")
                latch_trial = true;
                for ix_row = 1:length(ephys.trials_flat(:))
                    if not(info_flat.mode(ix_row) == mode), continue;end

                    trial = ephys.trials_flat{ix_row};
                    hash = hash_trial(trial);

                    if latch_trial
                        assert(trial.Stimuli.Duration == 0.5);
                        ep_fs_proto_train = 1000;
                        ep_duration_proto_train = 0.75;
                        ep_delay_proto_train = -0.15;
                        t_proto_train = [-fliplr(1/ep_fs_proto_train:1/ep_fs_proto_train:-ep_delay_proto_train), 0:1/ep_fs_proto_train:ep_duration_proto_train + ep_delay_proto_train];
                        latch_trial = false;

                    end

                    trial = adjust_timebase(trial, ep_fs_proto_train, t_proto_train, ep_duration_proto_train, did_verbose, v);
                    info_flat.fs(ix_row) = ep_fs_proto_train;

                    % do not modify the timing
                    [trial, did_verbose] = adjust_channels(trial, channel_set, channel_ignore_set, did_verbose, participant, v, hash);

                    ephys.trials_flat{ix_row} = trial;
                end

                if latch_trial
                    t_used = [];
                    fs_used = [];
                else
                    t_used = t_proto_train;
                    fs_used = ep_fs_proto_train;
                end
                % if isfield(info_flat.Properties.UserData, mode)
                % end
                info_flat.Properties.UserData.(mode).t = t_used;
                info_flat.Properties.UserData.(mode).fs = fs_used;
            elseif mode == "research_paired_averaged"
                t_proto = [-fliplr(1/ep_fs_proto:1/ep_fs_proto:-ep_delay_proto), 0:1/ep_fs_proto:ep_duration_proto + ep_delay_proto];
                assert(any(t_proto==0), 'I think it is convenient if the proto t has a true 0');
                assert(range(t_proto) == ep_duration_proto, 'range and duration of t_proto do not match');

                did_verbose = false;
                for ix_row = 1:length(ephys.trials_flat(:))
                    if not(info_flat.mode(ix_row) == mode), continue;end

                    trial = ephys.trials_flat{ix_row};
                    hash = hash_trial(trial);
                    trial = adjust_timebase(trial, ep_fs_proto, t_proto, ep_duration_proto, did_verbose, v);
                    info_flat.fs(ix_row) = ep_fs_proto;

                    [trial, did_verbose] = adjust_channels(trial, channel_set, channel_ignore_set, did_verbose, participant, v, hash);

                    [trial, cx_displacement, sc_displacement] = adjust_pairing_latency(trial, ep_fs_proto);
                    info_flat.cx_displacement(ix_row) = cx_displacement;
                    info_flat.sc_displacement(ix_row) = sc_displacement;

                    ephys.trials_flat{ix_row} = trial;
                end

                info_flat.Properties.UserData.(mode).t = t_proto;
                info_flat.Properties.UserData.(mode).fs = ep_fs_proto;
            elseif mode == "research_paired_repeat"
                t_proto = [-fliplr(1/ep_fs_proto:1/ep_fs_proto:-ep_delay_proto), 0:1/ep_fs_proto:ep_duration_proto + ep_delay_proto];
                assert(any(t_proto==0), 'I think it is convenient if the proto t has a true 0');
                assert(range(t_proto) == ep_duration_proto, 'range and duration of t_proto do not match');

                did_verbose = false;
                for ix_row = 1:length(ephys.trials_flat(:))
                    if not(info_flat.mode(ix_row) == mode), continue;end
                    %                     if ix_row == 700,
                    %                         keyboard;
                    %                     end
                    trial = ephys.trials_flat{ix_row};
                    hash = hash_trial(trial);
                    trial = adjust_timebase(trial, ep_fs_proto, t_proto, ep_duration_proto, did_verbose, v);
                    info_flat.fs(ix_row) = ep_fs_proto;

                    [trial, did_verbose] = adjust_channels(trial, channel_set, channel_ignore_set, did_verbose, participant, v, hash);

                    [trial, cx_displacement, sc_displacement] = adjust_pairing_latency(trial, ep_fs_proto);
                    info_flat.cx_displacement(ix_row) = cx_displacement;
                    info_flat.sc_displacement(ix_row) = sc_displacement;

                    ephys.trials_flat{ix_row} = trial;
                end

                info_flat.Properties.UserData.(mode).t = t_proto;
                info_flat.Properties.UserData.(mode).fs = ep_fs_proto;
                % elseif mode == "research_peripheral"
                % it seems that this referred to a pairing peripheral mode, but
                % I am not using research_peripheral as pure peripheral stim
                %     % have given this implementation 0 thought and it may well
                %     % be wrong... I wanted to skip it, but then other bits of
                %     % code complain that I don't have the hash...
                %     t_proto = [-fliplr(1/ep_fs_proto:1/ep_fs_proto:-ep_delay_proto), 0:1/ep_fs_proto:ep_duration_proto + ep_delay_proto];
                %     assert(any(t_proto==0), 'I think it is convenient if the proto t has a true 0');
                %     assert(range(t_proto) == ep_duration_proto, 'range and duration of t_proto do not match');
                %
                %     did_verbose = false;
                %     for ix_row = 1:length(ephys.trials_flat(:))
                %         if not(info_flat.mode(ix_row) == mode), continue;end
                %
                %         trial = ephys.trials_flat{ix_row};
                %         hash = hash_trial(trial);
                %         trial = adjust_timebase(trial, ep_fs_proto, t_proto, ep_duration_proto, did_verbose, v);
                %         info_flat.fs(ix_row) = ep_fs_proto;
                %
                %         [trial, did_verbose] = adjust_channels(trial, channel_set, channel_ignore_set, did_verbose, participant, v, hash);
                %
                %         [trial, cx_displacement, sc_displacement] = adjust_pairing_latency(trial, ep_fs_proto);
                %         info_flat.cx_displacement(ix_row) = cx_displacement;
                %         info_flat.sc_displacement(ix_row) = sc_displacement;
                %
                %         ephys.trials_flat{ix_row} = trial;
                %     end
                %
                %     info_flat.Properties.UserData.(mode).t = t_proto;
                %     info_flat.Properties.UserData.(mode).fs = ep_fs_proto;
            elseif mode == "research_dwave"
                % we might need to up the fs, but it probably makes the
                % data loading much more messy.
                t_proto = [-fliplr(1/ep_fs_proto:1/ep_fs_proto:-ep_delay_proto), 0:1/ep_fs_proto:ep_duration_proto + ep_delay_proto];
                assert(any(t_proto==0), 'I think it is convenient if the proto t has a true 0');
                assert(range(t_proto) == ep_duration_proto, 'range and duration of t_proto do not match');

                did_verbose = false;
                for ix_row = 1:length(ephys.trials_flat(:))
                    if not(info_flat.mode(ix_row) == mode), continue;end

                    trial = ephys.trials_flat{ix_row};
                    hash = hash_trial(trial);
                    trial = adjust_timebase(trial, ep_fs_proto, t_proto, ep_duration_proto, did_verbose, v);
                    info_flat.fs(ix_row) = ep_fs_proto;

                    [trial, did_verbose] = adjust_channels(trial, channel_set, channel_ignore_set, did_verbose, participant, v, hash);

                    ephys.trials_flat{ix_row} = trial;
                end

            elseif mode == "eeg"
                did_verbose = false;
                vec_fs = nan(length(ephys.trials_flat(:)), 1);
                for ix_row = 1:length(ephys.trials_flat(:))
                    if not(info_flat.mode(ix_row) == mode), continue;end

                    trial = ephys.trials_flat{ix_row};
                    hash = hash_trial(trial);
                    [trial, did_verbose] = adjust_channels(trial, channel_set, channel_ignore_set, did_verbose, participant, v, hash);
                    vec_fs(ix_row) = info_flat.fs(ix_row);
                    ephys.trials_flat{ix_row} = trial;
                end
                vec_fs_mode = vec_fs(isfinite(vec_fs));
                if not(isempty(vec_fs_mode))
                    fs_mode = vec_fs_mode(1);
                else
                    fs_mode = [];
                end

                assert(all(abs(vec_fs_mode - fs_mode) < 1e-5), 'Mixed frequencies?!');
  
                info_flat.Properties.UserData.(mode).t = nan;
                info_flat.Properties.UserData.(mode).fs = fs_mode;
            end

            info_flat.Properties.UserData.(mode).channels_muscles_half = proto_muscle_set;
            info_flat.Properties.UserData.(mode).channels = channel_set;
            info_flat.Properties.UserData.(mode).channel_type = channel_type;
        end

        info_flat.Properties.UserData.vec_mode = string(arrayfun(@(ix) ephys.Modes{ix}.Name, 1:length(ephys.Modes), 'UniformOutput', false));

        % sort the columns alphabetically
        sortedNames = sort(info_flat.Properties.VariableNames(3:end));
        info_flat = [info_flat(:,1:2), info_flat(:,sortedNames)];

        % take an event from one time, and place it at another time.
        % this is usder very sparingly, but it fixes situations where a
        % baseline happened in a section of data that cannot be easily
        % included near where it needs to be used (e.g. because some other section happened in
        % the middle)
        [info_flat, ephys] = trial_injector(info_flat, ephys, participant);

        if v.do_save
            save(p_data, '-struct', 'ephys');
            save(p_info, 'info_flat');
        end

    end
end
end

function case_channel = match_channel(channel_to_match, muscle_set, muscle_ignore_set, verbose)
if nargin < 4
    verbose = false;
end

muscle_set_local = [muscle_set; muscle_ignore_set];

channel_to_match = channel_to_match.replace('Left', 'L');
channel_to_match = channel_to_match.replace('Right', 'R');
channel_to_match = channel_to_match.replace(' ', '').replace('.', '');
channel_to_match = channel_to_match.replace('Cerv2', 'Cervical');  % v. arb.
channel_to_match = channel_to_match.replace('AbductorDigitiMinimi', 'ADM');  % v. arb.
channel_to_match = channel_to_match.replace('AbductorPollicisBrevis', 'APB');  % v. arb.
channel_to_match = channel_to_match.replace('TibialisAnterior', 'TA');  % v. arb.
channel_to_match = channel_to_match.replace('AbductorHallucis', 'AH');  % v. arb.
channel_to_match = channel_to_match.replace("LErb'sPoint-RErb'sPoint", 'D-Caud');  % v. arb.
channel_to_match = channel_to_match.replace("Dwave", 'D-Caud');  % v. arb.
channel_to_match = channel_to_match.replace("D-wave", 'D-Caud');  % v. arb.
channel_to_match = channel_to_match.replace("ExtensorCarpiRadialisLongus", 'ECR');  % v. arb.
channel_to_match = channel_to_match.replace("VastusLateralis", 'VL');
channel_to_match = channel_to_match.replace("Lbiceps", 'LBiceps');
channel_to_match = channel_to_match.replace("Rbiceps", 'RBiceps');
channel_to_match = channel_to_match.replace("Ltriceps", 'LTriceps');
channel_to_match = channel_to_match.replace("Rtriceps", 'RTriceps');
channel_to_match = channel_to_match.replace("RExtensorDigitorumBrevis", 'REDB');
channel_to_match = channel_to_match.replace("LExtensorDigitorumBrevis", 'LEDB');
channel_to_match(channel_to_match == "Lbicep") = "LBiceps";
channel_to_match(channel_to_match == "Rbicep") = "RBiceps";
channel_to_match(channel_to_match == "Ltricep") = "LTriceps";
channel_to_match(channel_to_match == "Rtricep") = "RTriceps";
if length(char(channel_to_match)) <=4  % v. arbitrary but ok.
    channel_to_match = upper(channel_to_match);
end

m_set = char(muscle_set_local);
l = max([length(char(channel_to_match)), size(m_set, 2)]);
if size(m_set, 2) < l
    m_set = [m_set, repmat(' ', size(m_set, 1), l - size(m_set, 2))];
end
char_match = repmat(' ', 1, l);
char_match(1:length(char(channel_to_match))) = char(channel_to_match);

diff_mat = true(size(m_set, 1), size(m_set, 2) + 1);
try
    diff_mat(:, 1:end-1) = abs(m_set - char_match)>0;
catch
    keyboard;
end

[~,B]=max(diff_mat,[],2);
case_channel = B == max(B);
if verbose
    fprintf('%s -> %s', channel_to_match, muscle_set_local(case_channel));
    if any(case_channel(length(muscle_set)+1:end))
        % it means it is in the ignore set
        fprintf(' --- but ignoring!');
    end
    fprintf('\n');
end

% ignore what was matched in the ignore set
case_channel = case_channel(1:length(muscle_set));

try
    assert(sum(case_channel) <= 1, 'Maybe you recorded from a new muscle?');
catch
    disp(channel_to_match)
    keyboard
end
end

function trial = adjust_timebase(trial, fs_proto, t_proto, duration_proto, did_verbose, v)
% the point of this is to bring data of the same mode into the same
% sampling rate
% and to make sure that channels are the same (even some channels have
% to become blanks)

if trial.datalength == 0
    trial.datalength = size(trial.data, 2);  % random SS bug
end

f_local = trial.datalength/trial.sweep;
delay_ms_local = trial.Stimuli.DataSweepTriggerDelayCustom;  % info_flat.sweep_delay(ix_row);
duration_local = trial.sweep;
t_local = [delay_ms_local:1/f_local:duration_local + delay_ms_local - 1/f_local];

if not(did_verbose) && v.verbose
    %     fprintf('\n--------\n%s:\n\n', participant);
    fprintf('%0.1fHz for %0.3fs filted from %0.0f to %0.0fHz\n\n', f_local, duration_local, trial.highcut, trial.lowcut);
end

% deal with loading errors:
case_nonfin = not(all(isfinite(trial.data), 2));
trial.data(case_nonfin, :) = 0;
[y, t_local_rs] = resample(trial.data.', t_local, fs_proto);
y(:, case_nonfin) = nan;

y = y.';
case_rm = t_local_rs>max(t_proto) | t_local_rs<min(t_proto);
y(:, case_rm) = [];
t_local_rs(case_rm) = [];

if length(y) > length(t_proto)
    % longer time series, but lower resolution than max -
    % causes off by one sample
    keyboard;
    assert((length(y) - length(t_proto))==1, 'Was expecting off by 1, but this is worse');
    y(:, end) = [];
end
y_valid = true(size(y));

n_pad1 = sum((t_local_rs(1) - t_proto) > eps);
y_pad1 = nan(size(y, 1), n_pad1);
y_pad1_valid = false(size(y_pad1));

n_pad2 = length(t_proto) - (length(y) + n_pad1);
y_pad2 = nan(size(y, 1), n_pad2);
y_pad2_valid = false(size(y_pad2));

% I think I might be introduce a slight jitter? but <1 sample
% so ignoring since we are at v. high res.
y = [y_pad1, y, y_pad2];
y_valid = [y_pad1_valid, y_valid, y_pad2_valid];

if not(length(t_proto) == length(y))
    keyboard;
end

trial.data = y;
trial.datalength = size(y, 2);
trial.sweep = duration_proto;
end

function [trial, did_verbose, matched_channel] = adjust_channels(trial, muscle_set, muscle_ignore_set, did_verbose, participant, v, hash)
vec_channel_in = trial.vec_channel;
data_out = nan(length(muscle_set), trial.datalength);
hash_out = nan(1, length(muscle_ignore_set));

if not(did_verbose) && v.verbose
    for ix_vec_channel_in = 1:length(vec_channel_in)
        match_channel(vec_channel_in(ix_vec_channel_in), muscle_set, muscle_ignore_set, true);
    end
    did_verbose = true;
end

matched_channel = false(length(muscle_set), 1);
for ix_vec_channel_in = 1:length(vec_channel_in)
    case_channel = match_channel(vec_channel_in(ix_vec_channel_in), muscle_set, muscle_ignore_set);
    matched_channel = matched_channel | case_channel;
    if any(case_channel)
        data_out(case_channel, :) = trial.data(ix_vec_channel_in, :);
        hash_out(1, case_channel) = hash(ix_vec_channel_in);
    else
        % the muscle is probably in the ignore set
    end
end

trial.vec_channel = muscle_set;
trial.data = data_out;
trial.hash = hash_out;
trial.custom.matched_channel = matched_channel;
end


function [trial_out, cx_displacement, sc_displacement] = adjust_pairing_latency(trial_in, fs_proto)
% for cases where we did spinal stim only, but forgot to set the latency to
% 0, so that it looks like spinal responses are late when they are not...

trial_out = trial_in;

cx_displacement_in = trial_in.Stimuli.DiscreteStimuli{1}.Displacement;
sc_displacement_in = trial_in.Stimuli.DiscreteStimuli{2}.Displacement;

if isfield(trial_in.Stimuli.DiscreteStimuli{1}, 'SensedVoltage')
    output_voltage = trial_in.Stimuli.DiscreteStimuli{1}.SensedVoltage;
else
    output_voltage = trial_in.Stimuli.DiscreteStimuli{1}.ElectricalPulses{1}.Intensity;
    fprintf('Voltage not sensed for one stimulation event - using intended voltage of first pulse (%0.1fV).\n', output_voltage);
end
cx_stim_absent =  output_voltage < 10;  % 10 is OK because voltage can't be less than 50 due to hardware
if not(isfinite(output_voltage)) || (output_voltage < 0)
    output_current = trial_in.Stimuli.DiscreteStimuli{1}.SensedCurrent;
    cx_stim_absent =  output_current < 1e-3;
end

if isfield(trial_in.Stimuli.DiscreteStimuli{2}, 'SensedCurrent')
    output_current = trial_in.Stimuli.DiscreteStimuli{2}.SensedCurrent;
else
    output_current = trial_in.Stimuli.DiscreteStimuli{2}.ElectricalPulses{1}.Intensity;
    fprintf('Current not sensed for one stimulation event - using intended current of first pulse (%0.1fmA).\n', output_current * 1e3);
end
sc_stim_present = output_current > 10e-6;

cx_stim_present = not(cx_stim_absent);
sc_stim_absent = not(sc_stim_present);
latency_nz = not(sc_displacement_in==0);

if cx_stim_absent && sc_stim_present && latency_nz
    n_shift = round(sc_displacement_in * fs_proto);
    trial_out.data = circshift(trial_in.data, -n_shift, 2);
    trial_out.data(:, end-n_shift+1:end) = nan;
    cx_displacement = cx_displacement_in;
    sc_displacement = 0;
    trial_out.Stimuli.DiscreteStimuli{1} = cx_displacement;
    trial_out.Stimuli.DiscreteStimuli{2} = sc_displacement;
elseif cx_stim_present && sc_stim_absent && latency_nz
    % cortical stim only, so the latency shift is meaningless
    cx_displacement = cx_displacement_in;
    sc_displacement = 0;
    trial_out.Stimuli.DiscreteStimuli{1} = cx_displacement;
    trial_out.Stimuli.DiscreteStimuli{2} = sc_displacement;
else
    cx_displacement = cx_displacement_in;
    sc_displacement = sc_displacement_in;
    % no need to adjust anything
end

end

function hash = hash_trial(trial)
rescale_by = 255;  % trying to get ints out of the hash... should find a more suitable hash
hash = zeros(1, size(trial.data, 1));
for ix_row = 1:size(trial.data, 1)
    hash(1, ix_row) = vec2hash(trial.data(ix_row, :), [], rescale_by);
end
end

function [info_flat, ephys] = trial_injector(info_flat, ephys, participant)
X = toml.map_to_struct(toml.read(fullfile(getenv("D_PROC"), 'auxillary', 'event_injections', 'event_injections.toml')));
if not(isfield(X, participant))
    return;
end
if not(isfield(X.(participant), 'inject_event_from'))
    return;
end

for ix_time = 1:length(X.(participant).inject_event_from)
    event_at_str = X.(participant).inject_event_from(ix_time);  % '1972-01-01T17:48:20';
    event_to_str = X.(participant).inject_event_to(ix_time);  % '1972-01-01T17:43:20';

    event_at_datetime = datetime(event_at_str, 'InputFormat', "yyyy-MM-dd'T'HH:mm:ss");
    [delta_t_event_at, ix_min_event_at] = min(abs(info_flat.datetime - event_at_datetime));
    assert(delta_t_event_at < 2 * seconds, 'Could not locate intended event.');

    if contains(event_to_str{1}, 'invalid')
        info_flat.is_valid(ix_min_event_at) = false;
    elseif contains(event_to_str{1}, '1count')
        info_flat.cx_count(ix_min_event_at) = 1;
        info_flat.cx_ipi(ix_min_event_at) = 0;
        info_flat.cx_frequency(ix_min_event_at) = 1;
    elseif contains(event_to_str{1}, 'mA')
        info_flat.sc_current(ix_min_event_at) = 1e-3 * str2double(extractBefore(event_to_str{1}, 'mA'));
        info_flat.sc_voltage(ix_min_event_at) = nan;
    elseif event_to_str{1}(end) == 'V'
        info_flat.cx_voltage(ix_min_event_at) = str2double(extractBefore(event_to_str{1}, 'V'));
        info_flat.cx_current(ix_min_event_at) = nan;
    else
        event_to_datetime = datetime(event_to_str, 'InputFormat', "yyyy-MM-dd'T'HH:mm:ss");

        while any(event_to_datetime == info_flat.datetime), event_to_datetime = event_to_datetime + 0.1 * second;end
        ix_min_event_to = find(info_flat.datetime > event_to_datetime, 1, 'first');

        trial = info_flat(ix_min_event_at, :);  % this is the one we are injecting
        trial.datetime = event_to_datetime;
        trial_previous = info_flat(ix_min_event_to-1, :);  % the one just before

        % assume some of the properties of the previous trial:
        trial.set_group = trial_previous.set_group;
        trial.set_sequence = trial_previous.set_sequence;
        trial.cx_pct = trial_previous.cx_pct;
        trial.sc_pct = trial_previous.sc_pct;
        trial.muscle_targeted = trial_previous.muscle_targeted;
        if trial.cx_voltage < 10  % i.e. if it is spine only then you can also assume the cortical properties (since they don't matter)
            cx_properties = ["cx_biphasic", "cx_count", "cx_frequency", "cx_ipi", "cx_laterality", "cx_polarity", "cx_pw", "cx_stimulation_configuration", "cx_stimulation_mep_side", "cx_stimulation_type"];
            for ix_cx_prop = 1:length(cx_properties)
                trial.(cx_properties(ix_cx_prop)) = trial_previous.(cx_properties(ix_cx_prop));
            end
        end

        info_flat = [info_flat(1:ix_min_event_to-1, :); trial; info_flat(ix_min_event_to:end, :)];
        ephys.trials_flat = [ephys.trials_flat(1:ix_min_event_to-1), ephys.trials_flat(ix_min_event_at), ephys.trials_flat(ix_min_event_to:end)];
    end
end
end
