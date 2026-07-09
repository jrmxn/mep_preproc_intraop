function info_auxf = rejection(participant, varargin)
clearvars -global;
d.fs_lowpass = 100;
d.pc_max = 2;
d.fraction_pc_error = 0.025; % default rejection proportion
d.w_edge = 6; % an error at the edge is counted w_edge times more than anywhere else
d.auc_th = 0.02;  % auc < than this is excluded from pca and assumed to not be art.
% d.log10_auc_th_lower = -3;
d.log10_auc_valid_lower = -3;
d.log10_auc_valid_upper = Inf;
d.stim_diff_threshold = 0.125;
d.sd_norm_plot = false;
d.reject_mode = 'reject_lines'; % plot_lines, reject_lines, update_table
d.p_rej_parameters = '';
d.participant_mapping = 'injury_study';
d.ephys_mode = 'research_scs';
d.reject_at_threshold = false;  % repeat the same rejection style, but after pre-selecting threshold trials
d.outer_is_scloc = false;
d.slider_type = 'fraction_pc_error';
d.o_figures = sprintf('%s', datestr(datetime, 'YYYY-mm-DD'));
d.figformat = 'png';
d.figsave = true;
d.fontsizeAxes = 7;
d.fontsizeText = 6;
% d.subject_alias_filter = {};
d.subject_filter = {};
d.t_min = 6e-3;
d.t_draw_line = [8.5e-3, 75e-3];
d.apply_bandstop = true;  % as all of this - this is just for visualisation!

d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
global SLIDER_OPT
SLIDER_OPT.type = v.slider_type;
SLIDER_OPT.switch = false;
slider_type_options = set_slider_options;

%%
d_preproc = fullfile(getenv('D_PROC'), 'preproc_standard', char(participant), 'ephys');
[~, info, data] = load_data('participant', participant, 'output_type', 'individual_single', ...
    'minimal_processing', true, 'participant_mapping', v.participant_mapping);
info_auxf = modify_auxf(participant, 'mode', 'load', 'overwrite', v.overwrite);

if not(any(info.mode == v.ephys_mode))
    return
end
%%
d_preproc_parameters = fullfile(d_preproc, 'parameters');
if not(exist(d_preproc_parameters, 'dir')==7)
    mkdir(d_preproc_parameters);
end

%%
% N.B. you are at the json character limit here!!!
[column_grouping, vec_group] = get_condition_groups(info, 'ephys_mode', v.ephys_mode);
cell_group = cellstr(vec_group(:).');
char_length = cellfun(@length, cell_group);disp(char_length);

%%
vec_ch = info.Properties.UserData.(v.ephys_mode).channels;
vec_emg_ch = vec_ch(info.Properties.UserData.(v.ephys_mode).channel_type == "EMG");
cell_ch_muscle = cellstr(vec_emg_ch(:).');

fs = info.Properties.UserData.(v.ephys_mode).fs;
t = info.Properties.UserData.(v.ephys_mode).t;
case_t = t >= v.t_min;

%%
if isempty(v.p_rej_parameters)
    if v.reject_at_threshold
        str_reject = sprintf('reject_th_%s', v.ephys_mode);
    else
        str_reject = sprintf('reject_%s', v.ephys_mode);
    end
    v.p_rej_parameters = fullfile(d_preproc_parameters, sprintf('%s_%s.json', participant, str_reject));

end

%%
% if v.outer_is_scloc
%     str_view = 'sc_view';
% else
str_view = 'muscle_view';
% end

%%
if any(strcmpi(info_auxf.Properties.VariableNames, str_reject))
    info_auxf.(str_reject)(:) = false;
else
    info_auxf.(str_reject) = false(height(info_auxf), length(vec_ch));
end

%%
% if not(isempty(v.subject_alias_filter))
%     if not(iscell(v.subject_alias_filter))
%         v.subject_alias_filter = {v.subject_alias_filter};
%     end
%     error('not implemented - use v.subject_filter instead for now...');
% end
% if not(isempty(v.subject_filter))
%     if not(iscell(v.subject_filter))
%         v.subject_filter = {v.subject_filter};
%     end
%     case_sub_f = false(size(cell_sub));
%     for ix_sub_f = 1:length(v.subject_filter)
%         case_sub_f(contains(cell_sub, v.subject_filter{ix_sub_f})) = true;
%     end
%     cell_sub = cell_sub(case_sub_f);
%     if isempty(cell_sub)
%         return;
%     end
% end
%%
FIGFORMAT = getenv('FIGFORMAT');
if not(isempty(FIGFORMAT))
    v.figformat = FIGFORMAT;
    warning('Grabbing figure format from environment variable.');
end
p_fig = fullfile(getenv('D_REPORTS'), sprintf('%s_%s', v.o_figures, str_reject), str_view, v.figformat);
if not(exist(p_fig, 'dir')==7), mkdir(p_fig);end
if not(v.figsave)
    warning('Not saving figures!');
end
es = '';
v.figdir = p_fig;
print_local = @(h, dim, figdir) printForPub(h, sprintf('f_%s_%s%s', v.reject_mode, h.Name, es), 'doPrint', v.figsave,...
    'fformat', v.figformat , 'physicalSizeCM', dim, 'saveDir', figdir, ...
    'fontsizeText', v.fontsizeText, 'fontsizeAxes', v.fontsizeAxes);

%%
clear REJ_STRUCT;
global REJ_STRUCT;
if exist(v.p_rej_parameters, 'file') == 2
    if contains(v.reject_mode, 'reject')
        [d_, f_, ext_] = fileparts(v.p_rej_parameters);
        d_ = fullfile(d_, 'backup');
        if not(exist(d_, 'dir')==7), mkdir(d_);end
        p_ = fullfile(d_, sprintf('%s%s%s', f_, datestr(datetime, 'YYYY-mm-DDTHH'), ext_));
        copyfile(v.p_rej_parameters, p_, 'f');  % just make a backup
    end
    REJ_STRUCT = loadjson(v.p_rej_parameters);
    REJ_STRUCT = REJ_STRUCT.REJ_STRUCT;
else
    REJ_STRUCT = struct;
end

%%
% only used if v.apply_bandstop
d_bandstop = designfilt('bandstopiir','FilterOrder',6, ...
    'HalfPowerFrequency1',58,'HalfPowerFrequency2',62, ...
    'SampleRate',fs);

%%
% for ix_cell_sub = 1:length(cell_sub)

%     participant = cell_sub{ix_cell_sub};
%     participant = T.Properties.UserData.(participant).alias;
% case_sub = strcmpi(T.subject, participant);
%     prc = numSubplots(length(cell_pos));

% if v.outer_is_scloc
%     layout_inner = get_layout_scloc;
%     layout_inner = layout_inner';
%     cell_outer = cell_ch;
%     cell_inner = cell_pos;
% else
layout_inner = get_layout_muscle;
layout_inner = layout_inner';
cell_outer = cell_group;
cell_inner = cell_ch_muscle;
% end

assert(all(cellfun(@(x) ismember(x, layout_inner), cell_inner)), ...
    'cell_pos does not match layout contents?');
prc = size(layout_inner);
n_rows = prc(1);n_cols = prc(2);

disp(participant);
% stimamp_th = get_stimamp_th(T, participant, cell_pos, v.stim_diff_threshold, v.sc_count);

ix_outer = 1;
while ix_outer <= length(cell_outer)
    for ix_inner = 1:length(cell_inner)
        generate_figure = ix_inner == 1;
        %         if v.outer_is_scloc
        %             ix_ch = ix_outer;
        %             ix_pos = ix_inner;
        %         else
        ix_pos = ix_outer;
        ix_muscle = ix_inner;
        case_channel = strcmpi(vec_ch, cell_inner{ix_inner});
        %         end
        %             str_pos = cell_pos{ix_pos};
        A = strcmpi(cell_inner{ix_inner}, layout_inner)';
        title_ = strrep(cell_inner{ix_inner}, '_', ' ');
        str_outer = cell_outer{ix_outer};
        str_inner = cell_inner{ix_inner};
        if generate_figure
            clear HSLIDER; global HSLIDER;
            f_name = sprintf('%s_ep_%s_sd%s', participant, str_outer, num2str(v.sd_norm_plot));
            if strcmpi(v.reject_mode, 'update_table')
                %
            elseif contains(v.reject_mode, 'plot')
                h_f = figure('Name', f_name);
                h_f.Units = 'normalized';h_f.OuterPosition = [0 0 1 1];
            else
                %                 if v.outer_is_scloc
                %                     h_f = figure('Name', f_name, 'CloseRequestFcn', ...
                %                         @(src, callbackdata, v1, v2, v3, f1) ...
                %                         close_figure(src, callbackdata, participant, cell_ch{ix_ch}, cell_pos));
                %                     h_dropdown = uicontrol(h_f,'Style','popupmenu');
                %                     h_dropdown.Callback = @(src, event) selection(src, event, participant, cell_ch{ix_ch}, cell_pos);
                %                 else
                h_f = figure('Name', f_name, 'CloseRequestFcn', ...
                    @(src, callbackdata, v1, v2, v3, f1) ...
                    close_figure(src, callbackdata, participant, cell_ch_muscle, cell_group{ix_pos}));
                h_dropdown = uicontrol(h_f,'Style','popupmenu');
                h_dropdown.Callback = @(src, event) selection(src, event, participant, cell_ch_muscle, cell_group{ix_pos});
                %                 end
                h_f.Units = 'normalized';h_f.OuterPosition = [0 0 1 1];
                h_dropdown.Position = [25 75 150 25];
                h_dropdown.String = slider_type_options;
                h_dropdown.Value = find(strcmpi(slider_type_options, SLIDER_OPT.type));
                SLIDER_OPT.switch = false;
            end
        end

        str_group = cell_group{ix_pos};
        p_rej.fraction_pc_error = update_struct(REJ_STRUCT, participant, cell_ch_muscle{ix_muscle}, str_group, 'fraction_pc_error', v.fraction_pc_error);  % only one that is modifiable by slider
        p_rej.pc_max = update_struct(REJ_STRUCT, participant, cell_ch_muscle{ix_muscle}, str_group, 'pc_max', v.pc_max);
        p_rej.auc_th = update_struct(REJ_STRUCT, participant, cell_ch_muscle{ix_muscle}, str_group, 'auc_th', v.auc_th);
        p_rej.w_edge = update_struct(REJ_STRUCT, participant, cell_ch_muscle{ix_muscle}, str_group, 'w_edge', v.w_edge);
        p_rej.log10_auc_valid_lower = update_struct(REJ_STRUCT, participant, cell_ch_muscle{ix_muscle}, str_group, 'log10_auc_valid_lower', v.log10_auc_valid_lower);
        p_rej.log10_auc_valid_upper = update_struct(REJ_STRUCT, participant, cell_ch_muscle{ix_muscle}, str_group, 'log10_auc_valid_upper', v.log10_auc_valid_upper);

        case_pos = strcmpi(column_grouping, str_group);
        case_merged = case_pos;
        %         if v.reject_at_threshold
        %             case_above = T.amplitude > (stimamp_th(1) - v.stim_diff_threshold);
        %             case_below = T.amplitude < (stimamp_th(1) + v.stim_diff_threshold);
        %             case_a_th = and(case_above, case_below);
        %             case_merged = case_merged & case_a_th;
        %             case_merged = case_merged & not(T.reject(:, ix_ch));  % also exclude things we rejected already
        %         end

        if sum(case_merged)>3
            d = data.trials_flat(case_merged).';
            [b, a] = butter(5, v.fs_lowpass/(fs/2));
            y_ep = cell2mat(cellfun(@(x) x.data(case_channel, :), d, 'UniformOutput', false));

            case_ignore = y_ep == 0 | not(isfinite(y_ep));
            y_e_out = all(case_ignore, 2);
            y_ep(case_ignore) = 0;

            vec_a = info(case_merged, :).sc_current;
            stim_corrupted = not(info.is_valid(case_merged));
            datetime_rec = info(case_merged, :).datetime;

            %             if all(y_e_out==0)
            if sum(y_e_out==0) > 3  % swapped from all(y_e_out==0) 2022-03-17
                y_ep = filtfilt(b, a, y_ep.').';
                if v.apply_bandstop
                    y_ep = filtfilt(d_bandstop, y_ep.').';
                end
                y_ep(:, not(case_t)) = nan;

                %                 y_e_out = false(size(y_ep, 1), 1);
                y_e_out = reject_corrupted(y_e_out, stim_corrupted);
                y_e_out = reject_pca(y_e_out, y_ep, t, case_t, p_rej.auc_th, p_rej.pc_max, p_rej.fraction_pc_error, p_rej.w_edge);
                y_e_out = reject_auc(y_e_out, y_ep, t, case_t, p_rej.log10_auc_valid_lower, p_rej.log10_auc_valid_upper);
            else
            end
            if strcmpi(v.reject_mode, 'reject_lines')||strcmpi(v.reject_mode, 'plot_lines')
                clear h_a;
                h_a = subplot(n_rows, n_cols, find(A(:)));hold on;
                p = h_a.Position;
                p2 = [p(1)+p(3), p(2), 0.01, p(4)];

                plot_lines(h_a, y_ep, t, vec_a, y_e_out, p_rej.(SLIDER_OPT.type), title_, v.sd_norm_plot, datetime_rec)
                for ix_draw_line = 1:length(v.t_draw_line)
                    plot(v.t_draw_line(ix_draw_line) * ones(1, 2), get(gca, 'ylim'), 'k--');
                end
                if strcmpi(v.reject_mode, 'reject_lines')
                    HSLIDER.(str_inner) = uicontrol( h_f, 'Style', 'slider', ...
                        'Units', 'normalized', 'Position', p2, 'Min', SLIDER_OPT.min, 'Max', SLIDER_OPT.max, ...
                        'SliderStep', SLIDER_OPT.step(y_ep), ...
                        'Value', p_rej.(SLIDER_OPT.type), ...
                        'Callback', @(src,evt) slider_callback_lines( src, h_a, y_ep, t, vec_a, title_, case_t, stim_corrupted, p_rej, v.sd_norm_plot, datetime_rec, SLIDER_OPT.type));
                    %                     if not(v.outer_is_scloc),xlabel('');end
                    xlabel('');
                end

            elseif strcmpi(v.reject_mode, 'reject_heatmap')||strcmpi(v.reject_mode, 'plot_heatmap')
                clear h_a;
                h_a = subplot(n_rows, n_cols, find(A(:)));hold on;
                p = h_a.Position;
                p2 = [p(1)+p(3), p(2), 0.01, p(4)];

                plot_heatmap(h_a, y_ep, t, vec_a, y_e_out, p_rej.(SLIDER_OPT.type), title_, v.sd_norm_plot, datetime_rec)
                if strcmpi(v.reject_mode, 'reject_heatmap')
                    HSLIDER.(str_inner) = uicontrol( h_f, 'Style', 'slider', ...
                        'Units', 'normalized', 'Position', p2, 'Min', SLIDER_OPT.min, 'Max', SLIDER_OPT.max, ...
                        'SliderStep', SLIDER_OPT.step(y_ep), ...
                        'Value', p_rej.(SLIDER_OPT.type), ...
                        'Callback', @(src,evt) slider_callback_heatmap( src, h_a, y_ep, t, vec_a, title_ , case_t, stim_corrupted, p_rej, v.sd_norm_plot, datetime_rec, SLIDER_OPT.type));
                    %                     if not(v.outer_is_scloc),xlabel('');end
                    xlabel('');
                end

            elseif strcmpi(v.reject_mode, 'update_table')
                info_auxf.(str_reject)(case_merged, case_channel) = y_e_out;
            end
        end
    end
    f_rej = v.p_rej_parameters;


    if strcmpi(v.reject_mode, 'update_table')
        %
    elseif contains(v.reject_mode, 'plot')
        if length(h_f.Children)>1
            p_fig_sub = fullfile(p_fig, participant);
            if not(exist(p_fig_sub, 'dir')==7), mkdir(p_fig_sub);end
            print_local(h_f, [50, 30], p_fig_sub);
        end
        close all;
    else
        try
            if length(h_f.Children)>1
                waitfor(h_f);  % close to figure to save
                savejson('REJ_STRUCT', REJ_STRUCT, f_rej);
            else
                delete(findall(0));
            end
        catch
            delete(findall(0));
        end
    end

    if SLIDER_OPT.switch
        % don't iterate the while loop if you change the slider type
        SLIDER_OPT.switch = false;
        SLIDER_OPT.type = SLIDER_OPT.type_next;
    else
        % iterate the while loop
        ix_outer = ix_outer + 1;
    end
end
% end

try
    delete(findall(0));
catch
    close all;
end

if v.reject_at_threshold
    info_auxf.Properties.UserData.rejection_at_threshold = v;
else
    info_auxf.Properties.UserData.rejection = v;
end


if strcmpi(v.reject_mode, 'update_table')
    modify_auxf(participant, 'info_auxf', info_auxf, 'mode', 'save');
end
REJ_STRUCT_info(REJ_STRUCT);
end

function selection(src, event, participant, cell_ch, cell_pos)
slider_type_next = src.String{src.Value};
set_slider_options(slider_type_next, participant, cell_ch, cell_pos);
fprintf('Selection: %s\n', slider_type_next);
end

function slider_type_options = set_slider_options(slider_type_next, participant, cell_ch, cell_pos)
global SLIDER_OPT;
if nargin<1
    SLIDER_OPT.type_next = SLIDER_OPT.type;
else
    close_figure([], [], participant, cell_ch, cell_pos);
    % you could set the type directly but there might be a race so use
    % type_next
    SLIDER_OPT.type_next = slider_type_next;
end
slider_type_options = {'fraction_pc_error', 'log10_auc_valid_lower'};
if strcmpi(SLIDER_OPT.type_next, 'fraction_pc_error')
    SLIDER_OPT.min = 0.00;
    SLIDER_OPT.max = 1.00;
    SLIDER_OPT.step = @(x) (1/size(x, 1)) * [1, 2];
elseif strcmpi(SLIDER_OPT.type_next, 'log10_auc_valid_lower')
    SLIDER_OPT.min = -3;
    SLIDER_OPT.max = 2;
    SLIDER_OPT.step = @(y_ep) [(SLIDER_OPT.max - SLIDER_OPT.min)/100, 0.1];
else
    error('default slider values not yet set for %s', SLIDER_OPT.type_next);
end
SLIDER_OPT.switch = true;
end
%%
function slider_callback_lines( hSlider, h_a, y_ep, t, vec_a, title_ , case_t, stim_corrupted, p_rej, sd_norm_plot, datetime_rec, slider_type)

p_rej.(slider_type) = hSlider.Value;
y_e_out = false(size(y_ep, 1), 1);
y_e_out = reject_corrupted(y_e_out, stim_corrupted);
y_e_out = reject_pca(y_e_out, y_ep, t, case_t, p_rej.auc_th, p_rej.pc_max, p_rej.fraction_pc_error, p_rej.w_edge);
y_e_out = reject_auc(y_e_out, y_ep, t, case_t, p_rej.log10_auc_valid_lower, p_rej.log10_auc_valid_upper);
plot_lines(h_a, y_ep, t, vec_a, y_e_out, p_rej.(slider_type), title_, sd_norm_plot, datetime_rec);
end

function slider_callback_heatmap( hSlider, h_a, y_ep, t, vec_a, title_ , case_t, stim_corrupted, p_rej, sd_norm_plot, datetime_rec, slider_type)

p_rej.(slider_type) = hSlider.Value;
y_e_out = false(size(y_ep, 1), 1);
y_e_out = reject_corrupted(y_e_out, stim_corrupted);
y_e_out = reject_pca(y_e_out, y_ep, t, case_t, p_rej.auc_th, p_rej.pc_max, p_rej.fraction_pc_error, p_rej.w_edge);
y_e_out = reject_auc(y_e_out, y_ep, t, case_t, p_rej.log10_auc_valid_lower, p_rej.log10_auc_valid_upper);
plot_heatmap(h_a, y_ep, t, vec_a, y_e_out, p_rej.(slider_type), title_, sd_norm_plot, datetime_rec)
end

function y_e_out = reject_corrupted(y_e_out, stim_corrupted)
if isempty(y_e_out)
    y_e_out = false(size(y_ep, 1), 1);
end
y_e_out = or(y_e_out, stim_corrupted);
end

function plot_lines(h_a, y, t, vec_a, y_e_out, slider_val, title_, sd_norm_plot, datetime_rec)
vec_a_mod = vec_a;
n_cmap = 256;
cmap = parula(n_cmap);cmap = flipud(cmap);
colormap(cmap);
amp_lower = min(vec_a_mod);
amp_upper = max(vec_a_mod);
colorscale = 'local';
if strcmpi(colorscale, 'local')
    vec_a_mod = discretize(vec_a_mod, 256);
elseif strcmpi(colorscale, 'global')
    vec_a_mod = round((vec_a_mod * (1/max_amp)) * n_cmap);
    amp_lower = 0;
    amp_upper = 12;
else
    error('bad colorscale')
end

axes(h_a);
cla;

[vec_a_mod, ix_vec_a] = sort(vec_a_mod, 'descend');
y_mod = y(ix_vec_a, :);
if sd_norm_plot
    y_mod = y_mod./nanstd(y_mod, 0, 2);
end
y_e_out_mod = y_e_out(ix_vec_a);

for ix_r = 1:size(y_mod, 1)
    if not(isnan(vec_a_mod(ix_r)))
        plot(t, y_mod(ix_r, :), '-', 'Color', cmap(vec_a_mod(ix_r), :));
    end
end
for ix_r = 1:size(y_mod, 1)
    if and(y_e_out_mod(ix_r), not(isnan(vec_a_mod(ix_r))))
        plot(t, y_mod(ix_r, :), '--', 'Color', 'r');
    end
end



axis tight;

y_temp = y_mod(not(y_e_out_mod), :);

if not(isempty(y_temp))
    ylim([min(y_temp(:)), max(y_temp(:))]);
end
ylim_ = get(gca, 'ylim');
xlabel('Time (s)');
if sd_norm_plot
    ylabel('EP (Arb.)');
else
    ylabel('EP (\muV)');
end
% c = colorbar;
% try
if amp_upper>=amp_lower
    amp_upper = amp_lower + 1e-3;
end
if not(isfinite(amp_lower))
    amp_lower = 0;
end
if not(isfinite(amp_upper))
    amp_upper = amp_lower + 1;
end
set(gca,'Clim',[amp_lower amp_upper])
% catch
%     keyboard
% end
xlim([t(1), t(end)]);
c = colorbar;
% ax_hidden = axes('Parent', h_a);

x_patch = [t(1), t(end), t(end), t(1)];
y_patch = [ylim_(1), ylim_(1), ylim_(2), ylim_(2)];
h_p = patch(x_patch, y_patch, 'r');
set(h_p, 'FaceAlpha', 0.01, 'FaceColor', 0.01 * [1, 1, 1]);

plot_heatmap_local = @(src, callbackdata) plot_heatmap(h_a, y, t, vec_a, y_e_out, slider_val, title_, sd_norm_plot, datetime_rec);
set(h_p,'ButtonDownFcn', @(src, callbackdata) plot_heatmap_local(src, callbackdata))

title_ = sprintf('%s, %0.3f', title_, slider_val);
title(title_);
end

function plot_heatmap(h_a, y, t, vec_a, y_e_out, slider_val, title_, sd_norm_plot, datetime_rec)
axes(h_a);
n_cmap = 256;
cmap = viridis(n_cmap);cmap = flipud(cmap);
colormap(cmap);
cla;
[vec_a_mod, ix_vec_a] = sort(vec_a, 'descend');
y_mod = y(ix_vec_a, :);
y_e_out = y_e_out(ix_vec_a);
if sd_norm_plot
    y_mod = y_mod./nanstd(y_mod, 0, 2);
end
imagesc(t, 1:size(y_mod, 1), y_mod);
axis tight;
set(gca,'Clim', [nanmin(y_mod(:)), nanmax(y_mod(:))])
colorbar;
hold on;
%                         xx = x * t(end) / x(end);
%                         plot(xx, x_e_prog, 'r.');
for ix = 1:length(y_e_out)
    if y_e_out(ix)
        plot(get(gca, 'xlim'), ones(1, 2) * (ix), 'k--');
    end
end
xlim([t(1), t(end)]);
ylim([0.5, Inf]);

plot_lines_local = @(src, callbackdata) plot_lines(h_a, y, t, vec_a, y_e_out, slider_val, title_, sd_norm_plot, datetime_rec);
ix_im = strcmpi(arrayfun(@(ix)  h_a.Children(ix).Type, 1:length(h_a.Children), 'UniformOutput', false), 'image');
set(h_a.Children(ix_im),'ButtonDownFcn', @(src, callbackdata) plot_lines_local(src, callbackdata));

title_ = sprintf('%s, %0.3f', title_, slider_val);
title(title_);

datetime_rec.Format = 'HH:mm:ss';
FontSize = 160/length(y_e_out);
FontSize(FontSize>8) = 8;
if FontSize<4
    vec_ix_time = 1:ceil(4/FontSize):length(datetime_rec);
    FontSize = 4;
else
    vec_ix_time = 1:length(datetime_rec);
end
for ix_time = vec_ix_time
    str_time = sprintf('%s', datetime_rec(ix_time));
    t_ = text(t(end), ix_time, str_time, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    t_.FontUnits = 'points';
    t_.FontSize = FontSize;
end

xlabel('Time (s)');
ylabel('Index');

end

function close_figure(src, callbackdata, sub, cell_ch, cell_pos)
% Close request function
try
    global REJ_STRUCT;
    global HSLIDER;
    global SLIDER_OPT;
    assert(xor(iscell(cell_ch), iscell(cell_pos)), 'One of these inputs should be a cell.');
    sub_safe = matlab.lang.makeValidName(sub);
    opt_safe = matlab.lang.makeValidName(SLIDER_OPT.type);
    if not(iscell(cell_ch))
        ch_safe = matlab.lang.makeValidName(cell_ch);
        for ix_pos = 1:length(cell_pos)
            if isfield(HSLIDER, cell_pos{ix_pos})
                h = HSLIDER.(cell_pos{ix_pos});
                if isvalid(h)
                    pos_safe = matlab.lang.makeValidName(cell_pos{ix_pos});
                    REJ_STRUCT.(sub_safe).(ch_safe).(pos_safe).(opt_safe) = h.Value;
                end
            end
        end
    elseif not(iscell(cell_pos))
        pos_safe = matlab.lang.makeValidName(cell_pos);
        for ix_ch = 1:length(cell_ch)
            if isfield(HSLIDER, cell_ch{ix_ch})
                h = HSLIDER.(cell_ch{ix_ch});
                if isvalid(h)
                    ch_safe = matlab.lang.makeValidName(cell_ch{ix_ch});
                    REJ_STRUCT.(sub_safe).(ch_safe).(pos_safe).(opt_safe) = h.Value;
                end
            end
        end
    end
catch ME
    warning('Error in close_figure: %s', ME.message);
end

if isempty(src)
    return;
end

try
    delete(src);
catch
    delete(gcf);
end
return
end

function REJ_STRUCT_info(REJ_STRUCT)
sub = fieldnames(REJ_STRUCT);
cell_param = cell(1, length(sub));
for ix_sub = 1:length(sub)
    REJ_STRUCT_sub = REJ_STRUCT.(sub{ix_sub});
    mus = fieldnames(REJ_STRUCT_sub);
    cell_param{ix_sub} = [];
    for ix_mus = 1:length(mus)
        REJ_STRUCT_sub_mus = REJ_STRUCT.(sub{ix_sub}).(mus{ix_mus});
        loc = fieldnames(REJ_STRUCT_sub_mus);
        for ix_loc = 1:length(loc)
            specific_param = 'fraction_pc_error';
            if any(strcmpi(fieldnames(REJ_STRUCT.(sub{ix_sub}).(mus{ix_mus})), specific_param))
                REJ_STRUCT_sub_mus_loc = REJ_STRUCT.(sub{ix_sub}).(mus{ix_mus}).(specific_param);
                cell_param{ix_sub} = [cell_param{ix_sub}, REJ_STRUCT_sub_mus_loc.(specific_param)];
            end
        end
    end
end
fprintf('Average rejection based on fraction_pc_error is %0.1f%%\n', ...
    100*mean(cellfun(@(x) mean(x), cell_param)));
end