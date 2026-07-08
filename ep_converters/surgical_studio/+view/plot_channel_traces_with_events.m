function [fig, out] = plot_channel_traces_with_events(ephys_in, ix_channel, varargin)
% Plot traces for a channel on an absolute time axis with event lines.
% Optional: restrict to a TimeWindow and choose containment rule.
%
% Name-Value:
%   'TimeZone'  (char) default 'America/New_York'
%   'Colors'    'lines' (default) or 'turbo' (string)
%   'TimeWindow' [t_start, t_end] as datetime with a timezone (default [])
%   'Containment' 'start-in' | 'fully' | 'any'  (default 'start-in')
%   'PlotEventsWithinWindowOnly' logical (default false)
%
% Returns:
%   fig : figure handle
%   out : struct with t0_vec, t_end_vec, t_cell, y_cell, trial_no,
%         ev_times, ev_msgs, time_zone

p = inputParser;
addParameter(p, 'TimeZone', 'America/New_York', @(s)ischar(s) || isstring(s));
addParameter(p, 'Colors', 'lines', @(s)ischar(s) || isstring(s));
addParameter(p, 'TimeWindow', [], @(x) isempty(x) || (isdatetime(x) && numel(x)==2));
addParameter(p, 'Containment', 'start-in', @(s) any(strcmpi(string(s), ["start-in","fully","any"])));
addParameter(p, 'PlotEventsWithinWindowOnly', false, @(x)islogical(x) || isnumeric(x));
parse(p, varargin{:});

time_zone  = char(p.Results.TimeZone);
colorspec  = lower(string(p.Results.Colors));
time_window = p.Results.TimeWindow;
containment = lower(string(p.Results.Containment));
plot_events_in_window_only = logical(p.Results.PlotEventsWithinWindowOnly);

try
trials = ephys_in.Modes{end}.Trials;
catch
trials = ephys_in.Trials;
end
n_trials = numel(trials);

% Collect traces
t0_cell  = cell(1, n_trials);
tend_cell= cell(1, n_trials);
t_cell   = cell(1, n_trials);
y_cell   = cell(1, n_trials);
trial_no = nan(1, n_trials);

for k = 1:n_trials
    tr_list = trials{k}.Traces;
    if ix_channel <= numel(tr_list) && ~isempty(tr_list{ix_channel})
        tr = tr_list{ix_channel};
        if isfield(tr,'TraceData') && ~isempty(tr.TraceData) && isfield(tr,'Sweep') && ~isempty(tr.Sweep)
            y = double(tr.TraceData(:).');   % row
            n = numel(y);
            sweep_s = double(tr.Sweep);

            if isfield(tr,'Timestamp') && ~isempty(tr.Timestamp)
                t0_us = double(tr.Timestamp);
            else
                t0_us = double(trials{k}.Timestamp);
            end
            t0 = datetime(t0_us/1e6,'ConvertFrom','posixtime','TimeZone',time_zone);
            t  = t0 + seconds(linspace(0, sweep_s, n));
            t_end = t0 + seconds(sweep_s);

            t0_cell{k}   = t0;
            tend_cell{k} = t_end;
            t_cell{k}    = t;
            y_cell{k}    = y;
            trial_no(k)  = trials{k}.TrialNumber;
        end
    end
end

valid = ~cellfun('isempty', y_cell);
t0_cell   = t0_cell(valid);
tend_cell = tend_cell(valid);
t_cell    = t_cell(valid);
y_cell    = y_cell(valid);
trial_no  = trial_no(valid);

if isempty(y_cell)
    warning('No valid traces found for channel %d.', ix_channel);
    fig = [];
    out = struct;
    return
end

% Sort by start time
t0_vec = vertcat(t0_cell{:});
[t0_vec, ord] = sort(t0_vec);
tend_vec = vertcat(tend_cell{:});
tend_vec = tend_vec(ord);
t0_cell  = t0_cell(ord);
t_cell   = t_cell(ord);
y_cell   = y_cell(ord);
trial_no = trial_no(ord);

% Events
ev_times = datetime.empty(0,1); ev_times.TimeZone = time_zone;
ev_msgs  = strings(0,1);
if isfield(ephys_in,'Events') && ~isempty(ephys_in.Events)
    for i = 1:numel(ephys_in.Events)
        ev = ephys_in.Events{i};
        if isfield(ev,'Deleted') && ev.Deleted, continue; end
        if ~isfield(ev,'Timestamp') || isempty(ev.Timestamp), continue; end
        tev = datetime(double(ev.Timestamp)/1e6,'ConvertFrom','posixtime','TimeZone',time_zone);
        msg = "";
        if isfield(ev,'Message') && ~isempty(ev.Message), msg = string(ev.Message); end
        ev_times(end+1,1) = tev; %#ok<AGROW>
        ev_msgs(end+1,1)  = msg; %#ok<AGROW>
    end
end

% Optional time window filtering
keep = true(size(t0_vec));
if ~isempty(time_window)
    % Ensure tz compatibility
    if isempty(time_window(1).TimeZone)
        time_window.TimeZone = time_zone; % in case user passed naive datetimes
    end
    switch containment
        case "fully"
            keep = (t0_vec >= time_window(1)) & (tend_vec <= time_window(2));
        case "start-in"
            keep = (t0_vec >= time_window(1)) & (t0_vec <= time_window(2));
        case "any"
            keep = (tend_vec >= time_window(1)) & (t0_vec <= time_window(2));
    end
    % Apply
    t0_vec   = t0_vec(keep);
    tend_vec = tend_vec(keep);
    t_cell   = t_cell(keep);
    y_cell   = y_cell(keep);
    trial_no = trial_no(keep);
end


%%
% x = ephys_in.Modes{end}.Trials(keep);

%%
if isempty(y_cell)
    warning('No traces in the requested window for channel %d.', ix_channel);
    fig = [];
    out = struct('t0_vec', t0_vec, 't_end_vec', tend_vec, ...
                 't_cell', {t_cell}, 'y_cell', {y_cell}, 'trial_no', trial_no, ...
                 'ev_times', ev_times, 'ev_msgs', ev_msgs, 'time_zone', time_zone);
    return
end

% Plot
fig = figure('Color','w'); hold on;
switch colorspec
    case "turbo"
        cmap = turbo(numel(y_cell));
    otherwise
        cmap = lines(numel(y_cell));    % requested by you
end

for i = 1:numel(y_cell)
    plot(t_cell{i}, y_cell{i}, 'LineWidth', 0.9, 'Color', cmap(i,:));
end

% Choose x-limits
if ~isempty(time_window)
    xlims = [time_window(1), time_window(2)];
else
    x_min = min(t0_vec);
    x_max = max(tend_vec);
    if ~isempty(ev_times)
        x_min = min(x_min, min(ev_times));
        x_max = max(x_max, max(ev_times));
    end
    xlims = [x_min, x_max];
end
xlim(xlims);

% Events (optionally clipped to window)
if ~isempty(ev_times)
    if plot_events_in_window_only
        mask_ev = (ev_times >= xlims(1)) & (ev_times <= xlims(2));
    else
        mask_ev = true(size(ev_times));
    end
    for i = find(mask_ev).'
        xline(ev_times(i), '-', ev_msgs(i), ...
            'Color',[0.25 0.25 0.25], 'LineWidth', 0.75, ...
            'LabelOrientation','horizontal', ...
            'LabelHorizontalAlignment','left', ...
            'LabelVerticalAlignment','top', ...
            'Interpreter','none');
    end
end

grid on
xlabel('Time')
ylabel(sprintf('TraceData (channel %d)', ix_channel))
ttl = 'Channel %d traces';
if ~isempty(time_window)
    ttl = sprintf('%s  [windowed]', ttl);
end
title(sprintf(ttl, ix_channel))
set(gca, 'XMinorGrid','on', 'YMinorGrid','on');

% Outputs
out = struct('t0_vec', t0_vec, 't_end_vec', tend_vec, ...
             't_cell', {t_cell}, 'y_cell', {y_cell}, 'trial_no', trial_no, ...
             'ev_times', ev_times, 'ev_msgs', ev_msgs, 'time_zone', time_zone);
end
