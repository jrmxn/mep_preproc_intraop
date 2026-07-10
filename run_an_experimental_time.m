clearvars -except rapid_info rapid_ephys rapid_v;
set_env;
% addpath(fullfile(getenvc('D_GIT'), 'intraop_preproc'));
addpath(fullfile(getenvc('D_GIT'), 'run_cfg'));

% d_data_mat_aug = fullfile(getenvc('D_DATA_MAT'), 'mat_files_aug');
% p_data_rejection = fullfile(getenvc('D_DATA'), 'proc_records', 'T_rejected');

close all; %% TEMPORARY!!!

%%
config_struct = load_configurations('cfg_experimental_time.json', 'open_config_file', true);

%%
participant_filter = config_struct.participant_filter;
participant_mapping = config_struct.participant_mapping;
v.ephys_mode = config_struct.ephys_mode;
[vec_participant, info, ephys, ~, vec_alias] = load_data('participant', participant_filter, ...
    'participant_mapping', participant_mapping);
vec_participant = cellstr(vec_participant);
case_emg = info.Properties.UserData.(v.ephys_mode).channel_type == "EMG";
cell_muscle = info.Properties.UserData.(v.ephys_mode).channels(case_emg);
% cell_scloc = unique(T.position);
% cell_scloc(strcmpi(cell_scloc, 'x_x')) = [];
[layout_scloc, cell_scloc_level, ~, ~, ~, vec_scloc_level] = get_layout_scloc('output_as_string', false);
cell_scloc = unique(layout_scloc(:));

fs = info.Properties.UserData.(v.ephys_mode).fs;
t = info.Properties.UserData.(v.ephys_mode).t;
t_min = 7e-3;
t_max = 75e-3;
case_t = (t >= t_min) & (t <= t_max);
case_tlt0 = t < 0;

manuscript_config = false;

v.config = 'exp_stats_auc';
v.describe_sections = true;
v.show_clusters = true;

v.es = '';
v.figformat = 'png';
v.figsave = true;
v.fontsizeAxes = 7;
v.fontsizeText = 6;

%%
th_pkpk = 50;

%%
[s_p, print_local] = get_figure_paths(v, 'es_fig', participant_mapping);

%%
% cell_muscle = info.Properties.UserData.channels;
n_ch = length(cell_muscle);

[c_map_pos, cell_side, vec_level] = get_cmap_sc(cell_scloc);
[c_map_ch, c_arm, c_hand, c_lower, ch_groups] = get_cmap_muscles;
cmap_L = [1, 0, 0];
cmap_R = [0, 0, 1];

%%
for ix_cell_sub = 1:length(vec_participant)
    participant = vec_participant{ix_cell_sub};
    [str_alias] = vec_alias(ix_cell_sub);
    case_sub = strcmpi(info.participant, participant);
    v.seed.(participant) = string2hash(participant);
    rng(v.seed.(participant));
    fprintf('%s (%s)\n', participant, str_alias);

    p_exp_timing = fullfile(getenvc('D_PROC'), sprintf('/auxillary/experimental_timings/%s/%s_summary.json', participant_mapping, participant));
    if exist(p_exp_timing, 'file') == 2
        set_xlim_from_file = true;
        timing_edges = loadjson(p_exp_timing);
        [time_from, time_to] = get_set_time(timing_edges, info, 'set01', participant);
    else
        fprintf('Timing file can be made here:\n%s\n', p_exp_timing);
        set_xlim_from_file = false;
    end

    f_name = sprintf('%s_%s_%s', str_alias, participant, v.config);
    h_f = figure('Name', f_name);
    %     h_f_dauc.Units = 'normalized';h_f_dauc.OuterPosition = [0 0 1 1];

    T_local = info(case_sub, :);
    is_cx = any(contains(T_local.mode, 'research_paired_repeat') | contains(T_local.mode, 'research_paired_average') | contains(T_local.mode, 'research_mep'));
    if strcmpi(v.config, 'exp_stats')
        prc = [1 + is_cx, 1, 1];
        FaceAlpha = 0.5;
        ylabel_auc = '';
        height_str_pos = 0.05;
    elseif strcmpi(v.config, 'exp_stats_auc')
        prc = [3 + is_cx, 1, 1];
        FaceAlpha = 0.1;
        ylabel_auc = 'log(AUC)';
        height_str_pos = 0.05;
    elseif strcmpi(v.config, 'exp_stats_auc_grouped')
        prc = [3 + is_cx, 1, 1];
        FaceAlpha = 0.1;
        ylabel_auc = 'log(\mu_{AUC})';
        height_str_pos = 0.05;
    else
        error('?');
    end
    %     T_local_multipulse = T_local;

    case_valid = get_case_valid(T_local, 'mode', 'any', 'sc_depth', 'any');

    %     case_valid_multipulse = get_case_valid(T_local, 'mode', 'research_multipulse');

    T_local(not(case_valid), :) = [];
    %     T_local_multipulse(not(case_valid_multipulse), :) = [];

    [c_block, str_block] = kblock_conditions(T_local, c_map_pos);
    figure(h_f);

    if is_cx
        h0 = subplot(prc(1), prc(2), is_cx);hold on;
        %     h_p1 = plot(T_local.datetime, T_local.sc_current * 1e3, '-');
        %     ylim_ = get(gca, 'ylim');
        %     ylim_(1) = 0;
        %     h_p1.Visible = 'off';
        %     plot_blocks(T_local, c_block, str_block, ylim_, FaceAlpha, height_str_pos);

        %     plot(T_local.datetime, T_local.amplitude, 'k-');

        %     case_plot = (T_local.is_valid);
        plot(T_local.datetime, T_local.cx_voltage, 'o', ...
            'MarkerEdgeColor', [1, 1, 1], ...
            'MarkerFaceColor', [0, 0, 0], 'MarkerSize', 5);
        plot(T_local.datetime(T_local.cx_count == 1), T_local.cx_voltage(T_local.cx_count == 1), 'o', ...
            'MarkerEdgeColor', [0.8, 0.5, 0.5], ...
            'MarkerFaceColor', [0, 0, 0], 'MarkerSize', 5);

        ylabel('Voltage (V)')

        [case_5hz] = get_trials_at_frequency(T_local, 5.0);
        if sum(case_5hz)
            yyaxis right;
            case_digitimer_base = isnan(T_local.cx_voltage) & not(case_5hz);
            plot(T_local.datetime(case_digitimer_base), T_local.cx_current(case_digitimer_base) * 1e3, 'o', ...
                'MarkerEdgeColor', 'w', ...
                'MarkerFaceColor', [0, 0.5, 0], 'MarkerSize', 5);
            plot(T_local.datetime(case_5hz), T_local.cx_current(case_5hz) * 1e3, 'o', ...
                'MarkerEdgeColor', 'None', ...
                'MarkerFaceColor', [0, 0.5, 0], 'MarkerSize', 3);
            ylabel('Current (mA)');
            hy = gca;
            hy.YAxis(2).Color = [0, 0.5, 0];
        end

    else
        h0 = [];
    end

    ylim_ = get(gca, 'ylim');
    ylim(ylim_);
    for ix_row = 1:height(T_local)
        is_eeg = T_local.mode(ix_row) == "eeg";
        if is_eeg
            plot(T_local.datetime(ix_row) + [0, T_local.sweep(ix_row)*seconds], ones(1, 2) * ylim_(2) - rand*range(ylim) * 0.1, 'r-');
        end
    end

    h1 = subplot(prc(1), prc(2), is_cx + 1);hold on;
    if is_cx
        yyaxis(h1,'left')
    end



    h_p1 = plot(T_local.datetime, T_local.sc_current * 1e3, '-');
    ylim_ = get(gca, 'ylim');
    ylim_(1) = 0;
    h_p1.Visible = 'off';
    plot_blocks(T_local, c_block, str_block, ylim_, FaceAlpha, height_str_pos);

    %     plot(T_local.datetime, T_local.amplitude, 'k-');

    case_plot = (T_local.sc_count==3) & (T_local.is_valid);
    plot(T_local.datetime(case_plot), T_local.sc_current(case_plot) * 1e3, 'o', ...
        'MarkerEdgeColor', [1, 1, 1], ...
        'MarkerFaceColor', [0, 0, 0], 'MarkerSize', 5);

    case_plot = and(T_local.sc_count==1, T_local.is_valid);
    plot(T_local.datetime(case_plot), T_local.sc_current(case_plot) * 1e3, 's', ...
        'MarkerEdgeColor', [1, 1, 1], ...
        'MarkerFaceColor', 0.5*[1, 1, 1], 'MarkerSize', 5);

    case_plot = not(T_local.is_valid);
    plot(T_local.datetime(case_plot), T_local.sc_current(case_plot) * 1e3, 'd', ...
        'MarkerEdgeColor', [1, 1, 1], ...
        'MarkerFaceColor', [1, 0, 0], 'MarkerSize', 5);


    case_plot = T_local.mode == "research_multipulse";
    plot(T_local.datetime(case_plot), T_local.sc_current(case_plot) * 1e3, 'v', ...
        'MarkerEdgeColor', [1, 1, 1], ...
        'MarkerFaceColor', 0.5*[1, 1, 1], 'MarkerSize', 4);

    ylim(ylim_);


    if v.describe_sections
        set_sequence_local = T_local.set_sequence;
        set_sequence_local(ismissing(set_sequence_local)) = "";
        text_diff = T_local.sc_electrode_type + T_local.sc_electrode_configuration + ...
            T_local.sc_count +  T_local.sc_polarity + T_local.sc_biphasic + T_local.sc_frequency + T_local.sc_pw + ...
            T_local.sc_approach + T_local.sc_depth + set_sequence_local;
        text_diff(T_local.mode == "eeg") = "eeg";
        text_diff(ismissing(text_diff)) = "offcord";
        % if you recorded eeg just set that entry the same as the previous
        % one
        for ix_text_diff = 2:size(text_diff, 1)
            if text_diff(ix_text_diff) == "eeg"
                text_diff(ix_text_diff) = text_diff(ix_text_diff - 1);
            end
        end
        vec_ev = find([1; any(diff(char(text_diff), 1, 1), 2)]);

        summary_conditions = table;

        for ix_vec_ev = 1:length(vec_ev(:).')
            ix_ev = vec_ev(ix_vec_ev);
            t_x = T_local.datetime(ix_ev);
            plot(repmat(t_x, 1, 2), ylim_, 'k--');
            try
                str_block_desc = sprintf('%s\n%s\nct:%d\n%s\n%s', ...
                    T_local.sc_electrode_type(ix_ev), T_local.sc_electrode_configuration(ix_ev), T_local.sc_count(ix_ev), ...
                    T_local.sc_polarity(ix_ev), T_local.sc_approach(ix_ev));
                if T_local.sc_depth(ix_ev) == "subdural"
                    str_block_desc = sprintf('%s\n%s', str_block_desc, T_local.sc_depth(ix_ev));
                end
                if not(ismissing(T_local.set_sequence(ix_ev)))
                    if ismissing(T_local.set_group(ix_ev))
                        set_group_ = "";
                    else
                        set_group_ = sprintf(', %s', T_local.set_group(ix_ev));
                    end
                    str_block_desc = sprintf('%s\n%s%s', str_block_desc, ...
                        T_local.set_sequence(ix_ev), set_group_);
                end
                if not(isnan(T_local.cx_pct(ix_ev))) || not(isnan(T_local.sc_pct(ix_ev)))
                    cx_pct_ = sprintf('C%d%%', T_local.cx_pct(ix_ev));
                    sc_pct_ = sprintf('S%d%%', T_local.sc_pct(ix_ev));
                    str_block_desc = sprintf('%s\n%s, %s', str_block_desc, ...
                        cx_pct_, sc_pct_);
                end
                if T_local.sc_count(ix_ev) > 3
                    str_block_desc = sprintf('%s\n%s', str_block_desc, 'multipulse');
                end
                if not(T_local.sc_pw(ix_ev) == 0.00025)
                    str_block_desc = sprintf('%s\n%0.2fus', str_block_desc, T_local.sc_pw(ix_ev) * 1e6);
                end
                if not(T_local.sc_frequency(ix_ev) == 0)
                    str_block_desc = sprintf('%s\n%0.2fHz', str_block_desc, T_local.sc_frequency(ix_ev));
                end
                if not(T_local.sc_biphasic(ix_ev))
                    str_block_desc = sprintf('%s\n%s', str_block_desc, 'monophasic');
                else
                    str_block_desc = sprintf('%s\n%s', str_block_desc, 'biphasic');
                end
                text(t_x, ylim_(end), str_block_desc, 'VerticalAlignment', 'top');

                summary_conditions_ = table;
                summary_conditions_.datetime = t_x;
                summary_conditions_.description = string(strrep(str_block_desc, sprintf('\n'), ', '));
                summary_conditions_.ix_ev = ix_ev;

                summary_conditions = [summary_conditions; summary_conditions_];

            catch
                1;
            end
        end
        disp(summary_conditions);
    end
    h_a = gca;

    %     h_a.XTick = linspace(T_local.datetime(1), T_local.datetime(end), 5);
    h_a.XTick = T_local.datetime(1):5*minutes:T_local.datetime(end);
    xlim([T_local.datetime(1) - 15*seconds, T_local.datetime(end) + 15*seconds]);
    ylabel('Stim. amp. (mA)');
    xlabel('Time');
    xlim_ = h_a.XLim;
    h_a.TickLength = [0, 0];

    dur = h_a.XTick - T_local.datetime(1);dur.Format = 'mm:ss';
    h_a.XTickLabel = string(dur);
    h_a.XTickLabelRotation = 30;

    if strcmpi(participant, 'sub-16')
        tmark = datetime(datenum8601('2021-08-09T11:48:44'), 'ConvertFrom', 'datenum');
    elseif strcmpi(participant, 'sub-17')
        tmark = datetime(datenum8601('2021-08-09T15:24:13'), 'ConvertFrom', 'datenum');
    else
        tmark = T_local.datetime(1);
    end
    plot(repmat(tmark, 1, 2), get(gca, 'ylim'), 'k--');

    v.stim_diff_threshold = 0.125 * 1e-3;
    if contains(table2array(unique(rmmissing(info(info.participant==participant,"sc_level")))), cell_scloc)
        stimamp_th = get_stimamp_th(info(info.participant==participant,:), cell_scloc, v.stim_diff_threshold, case_valid);

        %     catch
        %         keyboard;
        %     end
        %     try
        %     case_above = T_local.sc_current(case_plot) * 1e3 > (stimamp_th(1) - v.stim_diff_threshold);
        %     case_below = T_local.sc_current(case_plot) * 1e3 < (stimamp_th(1) + v.stim_diff_threshold);
        %     case_a_th = and(case_above, case_below);
        %
        %     catch
        %         keyboard
        %     end
    else
        % not used anyway...
    end
    auc_th = zeros(1, n_ch);
    for ix = 1:n_ch
        case_rej = T_local.(sprintf('reject_%s', v.ephys_mode))(:, ix);
        if sum(not(case_rej) & isfinite(T_local.pkpk(:, ix))) >=3
            try
                f = fitlm(T_local.pkpk(not(case_rej), ix), T_local.auc(not(case_rej), ix), 'RobustOpts', 'on');
            catch
                keyboard;
            end
            if mean(T_local.pkpk(:, ix) > th_pkpk) > 0.05 %% > if more than 5% is above th then est. auc version of th
                auc_th(ix) = feval(f, th_pkpk);
            else
                auc_th(ix) = nan;
            end
        else
            auc_th(ix) = nan;
        end
    end
    %     if strcmpi(v.show_highlights, 'threshold_selections')
    %         case_plot = case_a_th;
    %         plot(T_local.datetime(case_plot), T_local.sc_current(case_plot) * 1e3, 'o', ...
    %             'MarkerEdgeColor', [0, 0, 1], ...
    %             'MarkerFaceColor', 'none', 'MarkerSize', 6);
    %     elseif strcmpi(v.show_highlights, 'cluster_threshold')||strcmpi(v.show_highlights, 'cluster_as')
    %         if strcmpi(v.show_highlights, 'cluster_threshold')
    %             str_cluster_field = 'cluster';
    %             case_a_th_local = case_a_th;
    %         else
    %             str_cluster_field = v.show_highlights;
    if v.show_clusters
        %         case_a_th_local = true(size(case_a_th));
        %         end
        str_cluster_field = 'sc_cluster_fa';
        n_cluster = max(T_local.(str_cluster_field));
        vec_cluster_u = unique(T_local.(str_cluster_field));
        vec_cluster_u = vec_cluster_u(isfinite(vec_cluster_u));

        cmap_cluster = parula(length(vec_cluster_u));
        rng(v.seed.(participant));
        cmap_cluster = cmap_cluster(randperm(length(vec_cluster_u)), :);  % make it a bit easier to distinguish

        for ix_vec_cluster_u = 1:length(vec_cluster_u)
            ix_cluster = vec_cluster_u(ix_vec_cluster_u);
            case_cluster = T_local.(str_cluster_field) == ix_cluster;
            c = cmap_cluster(ix_vec_cluster_u, :);

            case_plot = case_cluster;% & case_a_th_local;
            plot(T_local.datetime(case_plot), T_local.sc_current(case_plot) * 1e3, 'o', ...
                'MarkerEdgeColor', c, ...
                'MarkerFaceColor', 'none', 'MarkerSize', 6);
            x_text = nanmean(T_local.datetime(case_plot));
            y_text = nanmean(T_local.sc_current(case_plot) * 1e3);
            text(x_text, y_text-1, ....
                sprintf('n=%d', nansum(case_plot)), 'Color', 'r');
        end
    end

    if is_cx
        yyaxis(h1,'right');
        lat_color = [0.25, 0.75, 0.25];
        plot(T_local.datetime, T_local.sccx_latency, 'o', ...
            'MarkerSize', 3, 'MarkerEdgeColor', 'w', 'MarkerFaceColor', lat_color);ylim([0, 0.03*1000]);
        h1.YAxis(2).Color = lat_color;
        ylabel('Pairing latency (ms)');
    end
    %     elseif isempty(v.show_highlights)
    %     else
    %         error('show_highlights must be set correctly or empty');
    %     end


    auc = T_local.auc;
    t = T_local.datetime;

    if strcmpi(v.config, 'exp_stats_auc_grouped')||strcmpi(v.config, 'exp_stats_auc')
        clear hp;
        if strcmpi(v.config, 'exp_stats_auc')
            for ix = 1:n_ch
                str_ch = cell_muscle{ix};

                if strcmpi(str_ch(1), 'L')
                    ix_sp = 1;
                    str_title = 'Left muscles';
                    h2 = subplot(prc(1), prc(2), 1 + is_cx + ix_sp);
                elseif strcmpi(str_ch(1), 'R')
                    ix_sp = 2;
                    str_title = 'Right muscles';
                    h3 = subplot(prc(1), prc(2), 1 + is_cx + ix_sp);
                end
                hold on;
                if all(auc(:, ix)==0)
                    g = not(case_rej);
                    gix = find(g, 1, 'first');
                    hp{ix_sp}(ix - (ix_sp-1) * n_ch/2) =  plot(t(gix), 1e-3, 'o', ...
                        'MarkerEdgeColor', [1, 1, 1], 'DisplayName', str_ch, ...
                        'MarkerFaceColor', c_map_ch.(str_ch), 'MarkerSize', 3);
                    hp{ix_sp}(ix - (ix_sp-1) * n_ch/2).Visible = 'off';
                else
                    case_rej = T_local.(sprintf('reject_%s', v.ephys_mode))(:, ix);
                    y = log(auc(:, ix));

                    plot(t(case_rej), y(case_rej), 'd', ...
                        'MarkerEdgeColor', [0, 0, 0], 'DisplayName', str_ch, ...
                        'MarkerFaceColor', c_map_ch.(str_ch), 'MarkerSize', 3);
                    if sum(not(case_rej))>0
                        hp{ix_sp}(ix - (ix_sp-1) * n_ch/2) = plot(t(not(case_rej)), y(not(case_rej)), 'o', ...
                            'MarkerEdgeColor', [1, 1, 1], 'DisplayName', str_ch, ...
                            'MarkerFaceColor', c_map_ch.(str_ch), 'MarkerSize', 3);
                    else
                        hp{ix_sp}(ix - (ix_sp-1) * n_ch/2) = plot(t(1), 0, '.', ...
                            'MarkerEdgeColor', [1, 1, 1], 'DisplayName', str_ch, ...
                            'MarkerFaceColor', c_map_ch.(str_ch), 'MarkerSize', 3);
                        %                     end

                    end
                    plot(get(gca, 'xlim'), log(nanmedian(auc_th)) * ones(1, 2), 'color', c_map_ch.(str_ch));


                    plot(repmat(tmark, 1, 2), get(gca, 'ylim'), 'k--');
                    title(str_title);
                    ylabel('log(AUC)');
                    %                     xlim([time_from, time_to]);
                end
            end
        elseif strcmpi(v.config, 'exp_stats_auc_grouped')
            fn_ch_groups = fieldnames(ch_groups);
            for ix = 1:length(fn_ch_groups)
                str_group = fn_ch_groups{ix};
                cell_ch_local = ch_groups.(str_group);
                case_ch_local = false(size(cell_muscle));
                for ix_cell_ch_local = 1:length(cell_ch_local)
                    case_ch_local = case_ch_local | strcmpi(cell_muscle, cell_ch_local{ix_cell_ch_local});
                end
                if strcmpi(str_group(1), 'L')
                    ix_sp = 1;
                    str_title = 'Left muscles';
                    h2 = subplot(prc(1), prc(2), 1 + is_cx + ix_sp);
                elseif strcmpi(str_group(1), 'R')
                    ix_sp = 2;
                    str_title = 'Right muscles';
                    h3 = subplot(prc(1), prc(2), 1 + is_cx + ix_sp);
                end
                hold on;
                y = log(mean(auc(:, case_ch_local), 2));
                hp{ix_sp}(ix - (ix_sp-1) * length(fn_ch_groups)/2) = plot(t, y, 'o', ...
                    'MarkerEdgeColor', [1, 1, 1], 'DisplayName', str_group, ...
                    'MarkerFaceColor', c_map_ch.(str_group), 'MarkerSize', 3);
                title(str_title);
            end
        end

        h2 = subplot(prc(1), prc(2), 1 + is_cx + 1);
        ylim_ =  get(gca, 'ylim');
        ylim_(1) = -4;
        plot_blocks(T_local, c_block, str_block, ylim_, FaceAlpha, nan);
        legend(hp{1}, 'orientation', 'horizontal', 'box', 'on', 'Location', 'BestOutside');
        xlim(xlim_);
        ylabel(ylabel_auc)
        xlabel('Time');
        ylim(ylim_);

        h3 = subplot(prc(1), prc(2), 1 + is_cx + 2);
        ylim_ =  get(gca, 'ylim');
        ylim_(1) = -4;
        plot_blocks(T_local, c_block, str_block, ylim_, FaceAlpha, nan);
        legend(hp{2}, 'orientation', 'horizontal', 'box', 'on', 'Location', 'BestOutside');
        xlim(xlim_);
        ylabel(ylabel_auc)
        xlabel('Time');
        ylim(ylim_);
        linkaxes([h0, h1, h2, h3], 'x');
        if set_xlim_from_file
            xlim([time_from, time_to]);
        end
        print_local(h_f, [50, 25], s_p.p_fig);
    else
        print_local(h_f, [25, 4], s_p.p_fig);
    end
end


%%
function plot_blocks(T_local, c_block, str_block, ylim_, FaceAlpha, text_height)
if nargin <= 5
    text_height = 0.05;
end
if nargin<=4
    FaceAlpha = 0.5;
end

for ix_c_block = 1:size(c_block, 1)
    xs = c_block(ix_c_block, 1);
    xe = c_block(ix_c_block, 2);
    color = c_block(ix_c_block, 3:end);
    xsq = T_local.datetime([xs, xs, xe, xe]);
    ysq = [ylim_(1), ylim_(2), ylim_(2), ylim_(1)];
    h_P = fill(xsq, ysq, color);
    h_P.FaceAlpha = FaceAlpha;
    h_P.LineStyle = 'none';
    uistack(h_P, 'bottom');

    if not(isnan(text_height))
        str_local = str_block{ix_c_block};
        str_local = strrep(str_local, '_', ' ');
        text(xsq(1) + (xsq(end) - xsq(1))/2, ylim_(1) + range(ylim_) * text_height, ...
            str_local, 'HorizontalAlignment', 'Center')
    end
end
end
