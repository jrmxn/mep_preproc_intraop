function [record_core, record_data] = sp_edf_reader_faker(p_template_edf, d_stacked_emg)
template_annotation = @(del) sprintf('+%d   +%d Stim: 0/0mA, 250µs, 3, 2ms, 0.5Hz                                                                                                                                                                                                                                                                                                                                                                                                                                                                      ', del, del);
template_prefilter = @(hp, lp) sprintf('HP:%dHz LP:%dHz                                                               ', hp, lp);

d_emg = dir(d_stacked_emg);
d_emg = d_emg(contains({d_emg.name}, 'csv'));
f_muscles = {d_emg.name};
%%
T_temp = readtable(fullfile(d_stacked_emg, d_emg(1).name));
[~, vec_time_within] = merge_data_columns(T_temp);
%%
[record_core, ~] = edfread_cascade(p_template_edf);

time = arrayfun(@(ix) datetime(...
    sprintf('%d', T_temp.Time(ix)), ...
    'InputFormat', 'yyyyMMddHHmmss'), 1:height(T_temp));

record_core.datetime = time;
record_core.delay = seconds(time-time(1));
record_core.annotation = arrayfun(template_annotation, record_core.delay, 'UniformOutput', false);
record_core.records = length(time);
record_core.patientID = '';
record_core.recordID = '';

%%
record_data_single = zeros(length(record_core.label), length(vec_time_within));
record_data = repmat({record_data_single}, [1, record_core.records]);
%%
for ix_label = 1:length(record_core.label)
    
    lat = record_core.label{ix_label}(1);
    muscle = record_core.label{ix_label}(2:end);
    str_file = sprintf('%s.%s', lat, muscle);
    str_f_muscles = f_muscles{contains(f_muscles, str_file)};
    T = readtable(fullfile(d_stacked_emg, str_f_muscles));
    
    [data_merged, ~] = merge_data_columns(T);
    for ix_record = 1:height(T)
        record_data{ix_record}(ix_label, :) = data_merged(ix_record, :);
    end
    
    record_core.prefilter{ix_label} = template_prefilter(T.Highcut(1), T.Lowcut(1));
    record_core.samples(ix_label) = size(data_merged, 2);
    
    % record_core.frequency(ix_label) = nan;  % assume correct from template
    % record_core.physicalMin(ix_label) = nan;  % assume correct from template
    % record_core.physicalMax(ix_label) = nan;  % assume correct from template
    % record_core.digitalMin(ix_label) = nan;  % assume correct from template
    % record_core.digitalMax(ix_label) = nan;  % assume correct from template
    % record_core.transducer{ix_label} = nan;  % assume correct from template
    % record_core.units{ix_label} = nan;  % assume correct from template
end
end
%%
function [data_merged, time_within] = merge_data_columns(T_temp)
time_within = cellfun(@(x) str2double(extractAfter(x, 'Data')), T_temp.Properties.VariableNames, 'UniformOutput', true);
time_within = time_within(isfinite(time_within));
data_merged = nan(height(T_temp), length(time_within));
for ix_time_within = 1:length(time_within)
    ix_t = T_temp.(sprintf('Data%d', time_within(ix_time_within)));
    data_merged(:, ix_time_within) = ix_t;
end
end