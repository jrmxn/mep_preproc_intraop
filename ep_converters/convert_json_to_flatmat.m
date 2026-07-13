function convert_json_to_flatmat(d_data_coded, varargin)
addpath(fullfile(fileparts(mfilename('fullpath')), 'exceptions_list'));
d_preproc_flattened = fullfile(getenv('D_PROC'), 'preproc_flattened');

% this function is here just because loading the jsons directly is pretty
% slow. So convert to mat and load that instead.
d.check_notch = true;
d.check_lowcut = true;
d.skip_hash_check = true;
d.participant = [];
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);

%%
cell_sub = dir(d_data_coded);
cell_sub = cell_sub([cell_sub.isdir]);
cell_sub(strcmpi({cell_sub.name}, '.')) = [];
cell_sub(strcmpi({cell_sub.name}, '..')) = [];
cell_sub = {cell_sub.name};
cell_sub = cell_sub(~strcmpi(cell_sub, 'auxf'));
if not(isempty(v.participant))
    cell_sub = intersect(v.participant, cell_sub);
end

for ix_cell_dir_sub = 1:length(cell_sub)
    participant = cell_sub{ix_cell_dir_sub};
    cell_glob = glob(fullfile(d_data_coded, participant, 'ephys', '*data.json'));
    if isempty(cell_glob)
        warning('GLOB for %s is empty - perhaps you forgot to run sp_epworks first?', participant);
    end
    for ix_glob = 1:length(cell_glob)
        p_phys_in = cell_glob{ix_glob};
        p_phys_out = strrep(p_phys_in, d_data_coded, d_preproc_flattened);
        p_phys_out = strrep(p_phys_out, '.json', '.mat');
        if v.skip_hash_check
            v_hash = nan;
        else
            error('not written');
        end
        do_convert = generate_check(p_phys_out, v.overwrite, v_hash, v.skip_hash_check);
        if do_convert
            ephys = loadjson(p_phys_in);ephys = ephys.Cases{1};

            p_info_in = strrep(p_phys_in, '_data.json', '_info.mat');
            p_info_out = strrep(p_info_in, d_data_coded, d_preproc_flattened);

            n_modes = length(ephys.Modes);

            if exist(p_info_in, 'file') == 2
                ephys_info = load(p_info_in);
                ephys_info = ephys_info.ephys_info;
            else
                ephys_info = struct;
                ephys_info.Modes = repmat({table}, 1, n_modes);
                ephys_info.etc = [];
            end

            [ephys, ephys_info] = fix_exceptions(ephys, ephys_info);

            % flatten the modes for both data and info
            % for each mode...
            trials_flat = [];
            info_flat = table;
            info_flat.Properties.UserData = ephys_info.etc;
            for ix_modes = 1:n_modes
                if isfield(ephys.Modes{ix_modes}, 'Trials')
                    trial_local = ephys.Modes{ix_modes}.Trials;
                elseif isfield(ephys.Modes{ix_modes}, 'StreamingTrials')
                    trial_local = ephys.Modes{ix_modes}.StreamingTrials;
                end
                if not(isfield(ephys_info, 'Modes'))
                    fprintf('no modes found for %s\n', participant);
                    continue;
                end
                info_local = ephys_info.Modes{ix_modes};
                str_mode = string(ephys.Modes{ix_modes}.Name);
                info_local.mode = repmat(str_mode, height(info_local), 1);
                for ix_trial_local = 1:length(trial_local)
                    trial_local{ix_trial_local}.mode = str_mode;
                end
                trials_flat = [trials_flat, trial_local];
                info_flat = [info_flat; info_local];

            end
            ephys.trials_flat = trials_flat;

            % clean up the trial data
            for ix_trial = 1:length(ephys.trials_flat)
                trial = ephys.trials_flat{ix_trial};

                n_traces = length(trial.Traces);

                vec_channel = strings(n_traces, 1);
                vec_timestamp = zeros(n_traces, 1);
                vec_highcut = zeros(n_traces, 1);
                vec_lowcut = zeros(n_traces, 1);
                vec_notch = zeros(n_traces, 1);
                vec_sweep = zeros(n_traces, 1);
                vec_tracedatalength = zeros(n_traces, 1);
                vec_tracedatascalar = zeros(n_traces, 1);
                cell_tracedata = cell(n_traces, 1);

                for ix_traces = 1:n_traces
                    vec_timestamp(ix_traces) = trial.Traces{ix_traces}.Timestamp;
                    vec_channel(ix_traces) = trial.Traces{ix_traces}.Channel.Name;
                    vec_highcut(ix_traces) = trial.Traces{ix_traces}.Channel.HighCut;
                    vec_lowcut(ix_traces) = trial.Traces{ix_traces}.Channel.LowCut;
                    vec_notch(ix_traces) = trial.Traces{ix_traces}.Channel.Notch;

                    vec_sweep(ix_traces) = trial.Traces{ix_traces}.Sweep;

                    vec_tracedatalength(ix_traces) = trial.Traces{ix_traces}.TraceDataLength;
                    vec_tracedatascalar(ix_traces) = trial.Traces{ix_traces}.TraceDataScalar;

                    cell_tracedata{ix_traces} = trial.Traces{ix_traces}.TraceData;
                    %                     disp(trial.Traces{ix_traces}.Channel.Gain)
                end


                [val_timestamp, val_highcut, val_lowcut, val_notch, val_sweep, val_tracedatalength] = ...
                    checkfix_collapsing_validity(trial, vec_timestamp, vec_highcut, vec_lowcut, vec_notch, vec_sweep, vec_tracedatalength, ...
                    v.check_notch, v.check_lowcut);

                trial.timestamp = val_timestamp;
                trial.vec_channel = vec_channel;
                trial.highcut = val_highcut;
                trial.lowcut = val_lowcut;
                trial.notch = val_notch;
                trial.sweep = val_sweep;
                trial.datalength = val_tracedatalength;

                trial_data = cell(size(cell_tracedata));
                n_local = max(cellfun(@length, cell_tracedata));
                for i = 1:numel(cell_tracedata)
                    if isempty(cell_tracedata{i})
                        trial_data{i} = nan(1, n_local);  % Set to NaN when there is no data
                    else
                        trial_data{i} = cell_tracedata{i};
                    end
                end
                trial.data = cell2mat(trial_data) .* vec_tracedatascalar;


                if isfield(trial, 'ActualRepRate')
                    trial.reprate = trial.ActualRepRate;
                else
                    trial.reprate = nan;
                end
                trial = rmfield_cell(trial, {'RequestedRepRate', 'Highlighted', 'Timestamp'}); % n.b. capital T in Timestamp
                trial = rmfield(trial, 'Traces');  % the original stuff is anyway in the mode field

                ephys.trials_flat{ix_trial} = trial;
            end

            ephys.hardware = ephys.HardwareType;
            % ephys.particpant_id = ephys.PatientID;
            ephys = rmfield_cell(ephys, {'PulseOximeters', 'PulseOximetryHeartRates', ...
                'PulseOximetryTimestamps', 'Simulated', 'Reviewers', 'Recorders', ...
                'CaseFields', 'PatientBirthDate', 'PatientGender', ...
                'PatientMiddleInitial', 'PatientFirstName', 'PatientLastName', ...
                'StateLastUpdatedBy', 'State', 'ID', 'PatientID', 'HardwareType' ...
                });

            %%
            if not(isempty(info_flat))
                [~, ix] = sort(info_flat.datetime);
                info_flat = info_flat(ix, :);
                ephys.trials_flat = ephys.trials_flat(ix);
                info_flat.TrialNumberOriginal = info_flat.ix;

                %re-number (this breaks the link to the orginal trial number in ephys.Modes)
                % ix_m = 2;a = arrayfun(@(x) ephys.Modes{ix_m}.Trials{x}.TrialNumber, [1:length(ephys.Modes{ix_m}.Trials)])
                assert(height(info_flat) == length(ephys.trials_flat), 'Must be same length!');
                for ix = 1:max(height(info_flat))
                    info_flat.ix(ix) = ix;
                    ephys.trials_flat{ix}.TrialNumber(ix) = ix;
                end
            end
            %%
            disp(p_info_out);
            save(p_phys_out, '-struct', 'ephys');
            save(p_info_out, 'info_flat');
            %%
        end
    end
end
end

function op = rmfield_cell(op, cell_field)
for ix_cell_field = 1:length(cell_field)
    str_field = cell_field(ix_cell_field);
    if isfield(op, str_field)
        op = rmfield(op, str_field);
    end
end
end

function [val_timestamp, val_highcut, val_lowcut, val_notch, val_sweep, val_tracedatalength] = ...
    checkfix_collapsing_validity(trial, vec_timestamp, vec_highcut, vec_lowcut, vec_notch, vec_sweep, vec_tracedatalength, ...
    check_notch, check_lowcut)
% do the traces fit together?
match_timestamp = all(vec_timestamp==vec_timestamp(1));
match_parent_timestamp = trial.Timestamp == vec_timestamp(1);
match_highcut = all(vec_highcut==vec_highcut(1));
match_lowcut = all(vec_lowcut==vec_lowcut(1));
match_notch = all(vec_notch==vec_notch(1));
match_sweep = all(vec_sweep==vec_sweep(1));
match_tracedatalength = all(vec_tracedatalength==vec_tracedatalength(1));

if not(match_highcut)
    % in one instance in a non-research mode, one of the filters was off.
    % just set it all to 0 for now. 2021-10-17
    % in future, you should just remove this and just deal with it in the
    % exceptions list to keep this code clutter free.
    match_highcut = true;
    vec_highcut = vec_highcut * 0;
end

val_timestamp = vec_timestamp(1);
val_highcut = vec_highcut(1);
val_lowcut = vec_lowcut(1);
val_notch = vec_notch(1);
val_sweep = vec_sweep(1);
val_tracedatalength = vec_tracedatalength(1);

if not(check_notch)
    match_notch = true;
end
if not(check_lowcut)
    match_lowcut = true;
end

vec_check = [match_timestamp, match_parent_timestamp, match_highcut, match_lowcut, match_notch, match_sweep, match_tracedatalength];


try
    assert(all(vec_check), 'Cannot collapse within trial trace data - values differ.');
catch
    %     keyboard;
end
end
