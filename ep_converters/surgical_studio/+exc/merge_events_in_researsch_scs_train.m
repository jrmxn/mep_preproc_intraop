function [ephys_info_local_new, ephys_out_local_new] = merge_events_in_researsch_scs_train(ephys_info_local, ephys_out_local)
% I wrote this for cdmrp participant 3 that scs_train data where each stim
% event was split into three sections. Hopefully that's fixed in future
% experiments. It's not perfect - the time overlap between the traces has a
% little shift so there may be a little jump. This could be solved by
% trying to find the ideal overlap, but not worth it if it's just for one
% participant.
%%
vec_group = zeros(height(ephys_info_local), 1);
ix_counter = 0;
vec_group(1) = 1;
ts = 0;
Sweep = [];
TraceDataLength = [];
for ix_trial = 1:length(ephys_out_local.Trials)
    trial = ephys_out_local.Trials{ix_trial};
    ts_prev = ts;
    ts = trial.Timestamp;
    measure = abs(ts - ts_prev)/1e6;
    if measure > 1
        ix_counter = ix_counter + 1;
    end
    vec_group(ix_trial) = ix_counter;

    for ix_trace = 1:length(trial.Traces)
        if trial.Traces{ix_trace}.TraceDataLength == 0
            continue
        end
        if isempty(Sweep)
            Sweep = trial.Traces{ix_trace}.Sweep;
        end
        if isempty(TraceDataLength)
            TraceDataLength = trial.Traces{ix_trace}.TraceDataLength;
        end
        assert(trial.Traces{ix_trace}.Sweep == Sweep, 'Not all the same');
        assert(trial.Traces{ix_trace}.TraceDataLength == TraceDataLength, 'Not all the same');
    end
end

fs = TraceDataLength/Sweep;

%%
ephys_info_local_new = table;
ephys_out_local_new = ephys_out_local;
ephys_out_local_new.Trials = {};
u_vec_group  = unique(vec_group);

num_failures = 0;

for ix_group = 1:numel(u_vec_group)
    g = u_vec_group(ix_group);
    ix_case_group = find(vec_group == g);  % these are already in chronological order

    merged_t    = {};
    merged_data = {};

    for k = 1:numel(ix_case_group)
        ix_trial = ix_case_group(k);
        trial    = ephys_out_local.Trials{ix_trial};

        for ix_trace = 1:length(trial.Traces)

            [t, data] = get_data_trace(trial, ix_trace);
            if length(merged_t) < ix_trace
                if isempty(data)
                    % hack because of missing data in some random traces
                    % (... not even trials, bits of trials in individual
                    % channels ...)
                    for ix_trace_temp = 1:length(trial.Traces)
                        [t_alt, data_alt] = get_data_trace(trial, ix_trace_temp);
                        if not(isempty(t_alt)), break;end
                    end
                    t = t_alt;
                    data = nan(size(data_alt));
                end
                merged_t{ix_trace}    = t;
                merged_data{ix_trace} = data;
            else
                try
                    idx_new = t > merged_t{ix_trace}(end);
                catch
                    keyboard
                end
                t_ = t(idx_new);
                if isempty(data) | isempty(merged_t{ix_trace})
                    fprintf('Some tracedata in freuqency stim is empty - not sure if I am handling it correctly.\n');
                    data_ = nan(1, sum(idx_new));
                else
                    data_ = data(:, idx_new);
                end
                merged_data{ix_trace} = [merged_data{ix_trace}, data_];
                merged_t{ix_trace}    = [merged_t{ix_trace},    t_  ];

            end
        end
    end

    L = median(cellfun(@length, merged_data));

    % THIS LINE IS A BIT OF A HACK. IF THE MERGER LOOKS WEIRD THEN CHECK
    % WHY THIS IS NEEDED.
    merged_data = cellfun(@(v) [v(:).' nan*ones(1, L - numel(v))], ...
        merged_data, 'UniformOutput', false);

    merged_data = cell2mat(merged_data.');
    merged_t = cellfun(@(v) [v(:).' nan*ones(1, L - numel(v))], ...
        merged_t, 'UniformOutput', false);
    merged_t = cell2mat(merged_t.');

    try
        assert(all((merged_t(1, :) == merged_t) | isnan(merged_t), [1, 2]), "?");
    catch ME
        warning(ME.identifier, '%s', ME.message);
        num_failures = num_failures + 1;
    end

    merged_t = merged_t(1, :);
    if any(isnan(merged_t)), error('Adapt code to pick a row without nans');end

    nan_rows = all(not(isfinite(merged_data)), 2);
    merged_data(nan_rows, :) = 1;
    [merged_data_rs, merged_t_rs, c] = resample(merged_data.', merged_t*1e-6, fs);
    merged_data_rs = merged_data_rs.';
    merged_data_rs(nan_rows, :) = nan;


    ix_trial = ix_case_group(1);
    ephys_info_local_new = [ephys_info_local_new; ephys_info_local(ix_trial, :)];

    ephys_trial = ephys_out_local.Trials{ix_trial};
    for ix_trace = 1:length(ephys_trial.Traces)
        ephys_trial.Traces{ix_trace}.TraceData = merged_data_rs(ix_trace, :);
        ephys_trial.Traces{ix_trace}.Sweep = (merged_t(end) - merged_t(1)) * 1e-6;
        ephys_trial.Traces{ix_trace}.TraceDataLength = size(merged_data_rs, 2);
    end

    ephys_out_local_new.Trials = [ephys_out_local_new.Trials, ephys_trial];

end

if (num_failures/numel(u_vec_group))>0.5
    error('Too many failures of timing.')
end

end


function [t, data] = get_data_trace(trial, ix_trace)
trace     = trial.Traces{ix_trace};
data = trace.TraceData;
t        = linspace(trial.Timestamp, trial.Timestamp + trace.Sweep*1e6, trace.TraceDataLength);
end