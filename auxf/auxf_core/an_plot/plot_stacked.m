function plot_stacked(T_figure, varargin)
%%
d.figvisible = 'off';
d.figformat = '';
d.figsave = true;
d.fontsizeAxes = [];
d.fontsizeText = [];
d.figure_dim = [];
d.p_fig = '';
d.d_overwrite = struct;
%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
ud = T_figure.Properties.UserData;
p_fig = ud.settings_figure.p_fig;
p_fig_subplots = ud.settings_figure.p_fig_subplots;
cmap = ud.settings_figure.cmap;
range_cmap = ud.settings_figure.range_cmap;
fig_es = ud.settings_figure.fig_es;
% cell_sub = ud.settings_data.cell_sub;
cell_sub = unique(T_figure.str_sub)';
%%
if isempty(v.p_fig), v.p_fig = p_fig;end
if isempty(v.fontsizeAxes), v.fontsizeAxes = ud.settings_figure.fontsizeAxes;end
if isempty(v.fontsizeText), v.fontsizeText = ud.settings_figure.fontsizeText;end
if isempty(v.figformat), v.figformat = ud.settings_figure.figformat;end
if isempty(v.figure_dim), v.figure_dim = ud.settings_figure.dim_stickman;end
%%
if isfield(ud.settings_figure, 'stickman_skip')
    if ud.settings_figure.stickman_skip
        return;
    end
end

%%
p_notes_general = fullfile(getenvc('D_PROC'), 'auxillary', 'old_notes', 'notes_general.json');
notes_general = loadjson(p_notes_general);

%%
FIGFORMAT = getenv('FIGFORMAT');
if not(isempty(FIGFORMAT))
    v.figformat = FIGFORMAT;
    warning('Grabbing figure format from environment variable.');
end

% es = '';
% if not(isempty(v.image_type))
%     es = sprintf('%s_%s', es, v.image_type);
% end
print_local = @(h, dim, figdir) printForPub(h, sprintf('%s', h.Name), 'doPrint', v.figsave,...
    'fformat', v.figformat , 'physicalSizeCM', dim, 'saveDir', figdir, ...
    'fontsizeText', v.fontsizeText, 'fontsizeAxes', v.fontsizeAxes, 'append_format_to_dir', true);
%%

% end
%
[layout_muscle, layout_muscle_unsided] = get_layout_muscle;
[layout_scloc, cell_scloc_level, ~, ~, ~, vec_scloc_level] = get_layout_scloc;

cell_muscle = unique(layout_muscle(:));
cell_muscle(cellfun(@isempty, cell_muscle)) = [];
cell_muscle_unsided = layout_muscle_unsided.';
cell_muscle_unsided = cell_muscle_unsided(:);
cell_muscle_unsided(cellfun(@isempty, cell_muscle_unsided)) = [];
% cell_muscle_unsided = cellfun(@(x) x(2:end), cell_muscle_unsided, 'UniformOutput', false);
% vec_scloc_level = cellfun(@(x) str2double(x(2:end)), cell_scloc_level, 'UniformOutput', true);
T_figure.str_muscle_unsided = cellfun(@(x) x(2:end), T_figure.str_muscle, 'UniformOutput', false);

cell_scloc = unique(layout_scloc(:));

n_rows_m = size(layout_muscle, 1);
n_cols_m = size(layout_muscle, 2);

n_rows = 1;%size(layout_scloc, 1);
n_cols = size(cell_muscle_unsided, 1);

op = [0, 0, 0.5, 1];
cmap_scloc = lines(length(cell_scloc_level));

for ix_cell_sub = 1:length(cell_sub)
    str_sub = cell_sub{ix_cell_sub};
    if isfield(ud.settings_data, str_sub)
        str_alias = ud.settings_data.(str_sub).alias;
        v.seed.(str_sub) = string2hash(str_sub);
        rng(v.seed.(str_sub));
    else
        str_alias = str_sub;
    end
    fprintf('%s (%s)\n', str_sub, str_alias);
    
    str_alias_n = strrep(str_alias, '-', '');
    notes_sub = notes_general.target.(str_alias_n);
    if length(notes_sub) > 1
        notes_sub = notes_sub{1};
        %                                 notes_sub = notes_sub{end}; % this is the alt selection
    end
    muscle_target = notes_sub.muscle;
    str_side_target = muscle_target(1);
    
    % individual subject ---
    h_f_sub = figure(...
        'Name', sprintf('%s_%s_%s%s', str_alias, ud.settings_figure.config, '_th_abs', fig_es), ...
        'Visible', v.figvisible);
    
    for ix_cell_muscle = 1:length(cell_muscle_unsided)
        str_muscle_unsided = cell_muscle_unsided{ix_cell_muscle};
        str_muscle = sprintf('%s%s', str_side_target, str_muscle_unsided);
        h_a = subplot(n_rows, n_cols, ix_cell_muscle);cla;hold on;
        
        vec_t_grid = [0:0.005:0.055];
        for ix_vec_t_grid = 1:length(vec_t_grid)
            plot(vec_t_grid(ix_vec_t_grid) * ones(1, 2), [3, 9], 'k:');
        end
        com = nan(1, length(cell_scloc_level));
        init_lat = nan(1, length(cell_scloc_level));
        for ix_cell_scloc = 1:length(cell_scloc_level)
            str_scloc_level = cell_scloc_level{ix_cell_scloc};
            str_scloc = sprintf('%s_%s', str_scloc_level, str_side_target);
            A = strcmpi(str_scloc, layout_scloc)';
            
            case_muscle = strcmpi(T_figure.str_muscle, str_muscle);
            case_sub = strcmpi(T_figure.str_sub, str_sub);
            case_scloc = strcmpi(T_figure.str_scloc, str_scloc);
            case_merge = case_muscle & case_sub & case_scloc;
            
            f = T_figure.filename(case_merge);
            
            h_temp = openfig(fullfile(p_fig_subplots, sprintf('%s.fig', f)));
            if not(isempty(h_temp.Children.Children))
                y = h_temp.Children.Children.YData;
                y_max = max(y);
                y_scaled = y./y_max;
                x = h_temp.Children.Children.XData;
                % the -y is because you reverse the plot ydir!!!
                plot(h_a, x, vec_scloc_level(ix_cell_scloc) - y_scaled, 'Color', cmap_scloc(ix_cell_scloc, :));
                plot(h_a, x, ones(size(x)) * vec_scloc_level(ix_cell_scloc), 'Color', cmap_scloc(ix_cell_scloc, :), 'lineWidth', 0.5);
                text(h_a, 0.06, vec_scloc_level(ix_cell_scloc) - 0.5, ...
                    sprintf('x%0.0f', y_max));
                
                [com(1, ix_cell_scloc), init_lat(1, ix_cell_scloc)] = ...
                    f_comlat(x, y);
            end
            
            close(h_temp);
            
            ylim([min(vec_scloc_level)-1, max(vec_scloc_level) + 0])
            xlabel('Time (s)');
            ylabel('Root levels');
        end
        h_a.YDir = 'reverse';
        title(cell_muscle_unsided{ix_cell_muscle});
        try
        h_a.YTick = vec_scloc_level;
        catch
            keyboard;
        end
        
        c = [0, 0, 0];
        plot(h_a, com, vec_scloc_level - 0.5, '-o', ...
            'Color', c, ...
            'MarkerFaceColor', c, 'MarkerEdgeColor', 'None', 'MarkerSize', 4);
        
        init_lat = nanmedian(init_lat);
        vec_lat = [0, 25e-3; 25e-3, 55e-3; 55e-3, 85e-3];
        cmap_back = lines(size(vec_lat, 1));
        for ix_lat = 1:3
            h_fill = fill([init_lat + vec_lat(ix_lat, 1); init_lat + vec_lat(ix_lat, 2); init_lat + vec_lat(ix_lat, 2); init_lat + vec_lat(ix_lat, 1)], ...
                [min(vec_scloc_level)-1; min(vec_scloc_level)-1; max(vec_scloc_level) + 0; max(vec_scloc_level) + 0],...
                cmap_back(ix_lat, :));
            h_fill.FaceAlpha = 0.075;
            h_fill.EdgeColor = 'None';
            uistack(h_fill, 'bottom');
        end
        xlim([0, 0.075]);
    end
    
    sgtitle(str_alias);
    figure(h_f_sub);
    drawnow; % not sure if needed
    print_local(h_f_sub, [40, 10], v.p_fig);
    
    close all;
end

h_f = figure(...
    'Name', sprintf('%s_%s_%s%s', 'all', ud.settings_figure.config, '_th_abs', fig_es), ...
    'Visible', v.figvisible);
cmap_sub = parula(length(cell_sub));
cell_text = cell(length(cell_sub), length(cell_muscle_unsided), length(cell_scloc_level));

com = nan(length(cell_sub), length(cell_muscle_unsided), length(cell_scloc_level));

for ix_cell_sub = 1:length(cell_sub)
    str_sub = cell_sub{ix_cell_sub};
    if isfield(ud.settings_data, str_sub)
        str_alias = ud.settings_data.(str_sub).alias;
        v.seed.(str_sub) = string2hash(str_sub);
        rng(v.seed.(str_sub));
    else
        str_alias = str_sub;
    end
    fprintf('%s (%s)\n', str_sub, str_alias);
    
    str_alias_n = strrep(str_alias, '-', '');
    notes_sub = notes_general.target.(str_alias_n);
    if length(notes_sub) > 1
        notes_sub = notes_sub{1};
        %                                 notes_sub = notes_sub{end}; % this is the alt selection
    end
    muscle_target = notes_sub.muscle;
    str_side_target = muscle_target(1);
    
    % individual subject ---
    
    for ix_cell_muscle = 1:length(cell_muscle_unsided)
        str_muscle_unsided = cell_muscle_unsided{ix_cell_muscle};
        str_muscle = sprintf('%s%s', str_side_target, str_muscle_unsided);
        h_a = subplot(n_rows, n_cols, ix_cell_muscle);hold on;
        
        vec_t_grid = [0:0.005:0.055];
        if ix_cell_sub == 1
            for ix_vec_t_grid = 1:length(vec_t_grid)
                plot(vec_t_grid(ix_vec_t_grid) * ones(1, 2), [3, 9], 'k:');
            end
        end
        for ix_cell_scloc = 1:length(cell_scloc_level)
            str_scloc_level = cell_scloc_level{ix_cell_scloc};
            str_scloc = sprintf('%s_%s', str_scloc_level, str_side_target);
            A = strcmpi(str_scloc, layout_scloc)';
            
            case_muscle = strcmpi(T_figure.str_muscle, str_muscle);
            case_sub = strcmpi(T_figure.str_sub, str_sub);
            case_scloc = strcmpi(T_figure.str_scloc, str_scloc);
            case_merge = case_muscle & case_sub & case_scloc;
            
            f = T_figure.filename(case_merge);
            
            h_temp = openfig(fullfile(p_fig_subplots, sprintf('%s.fig', f)));
            if not(isempty(h_temp.Children.Children))
                y = h_temp.Children.Children.YData;
                y_max = max(y);
                if y_max > 1
                    y = y./y_max;
                    x = h_temp.Children.Children.XData;
                    plot(h_a, x, vec_scloc_level(ix_cell_scloc) - y, 'Color', cmap_sub(ix_cell_sub, :));
                    com(ix_cell_sub, ix_cell_muscle, ix_cell_scloc) = f_comlat(x, y);
                end
                cell_text{ix_cell_sub, ix_cell_muscle, ix_cell_scloc} = ...
                    sprintf('x%0.0f', y_max);
            end
            
            close(h_temp);
            
            ylim([min(vec_scloc_level)-1, max(vec_scloc_level) + 0])
            xlabel('Time (s)');
            ylabel('Root levels');
        end
        h_a.YDir = 'reverse';
        title(cell_muscle_unsided{ix_cell_muscle});
        h_a.YTick = vec_scloc_level;
    end
end
%%
% Add text
for ix_cell_sub = 1:length(cell_sub)
    for ix_cell_muscle = 1:length(cell_muscle_unsided)
        for ix_cell_scloc = 1:length(cell_scloc_level)
            subplot(n_rows, n_cols, ix_cell_muscle);
            if not(isempty(cell_text{ix_cell_sub, ix_cell_muscle, ix_cell_scloc}))
                text(0.06, vec_scloc_level(ix_cell_scloc) - ix_cell_sub/(length(cell_sub)+1), ...
                    cell_text{ix_cell_sub, ix_cell_muscle, ix_cell_scloc}, 'Color', cmap_sub(ix_cell_sub, :));
            end
        end
    end
end
%%
%add center of mass
for ix_cell_muscle = 1:length(cell_muscle_unsided)
    
    for ix_cell_sub = 1:length(cell_sub)
        c = [1, 0, 0];
        subplot(n_rows, n_cols, ix_cell_muscle);
        com_ = squeeze(com(ix_cell_sub, ix_cell_muscle, :));
        plot(com_, vec_scloc_level - 0.5, 'o', ...
            'MarkerFaceColor', c, 'MarkerEdgeColor', 'None', 'MarkerSize', 2);
    end
    
    subplot(n_rows, n_cols, ix_cell_muscle);
    com_ = squeeze(nanmean(com(:, ix_cell_muscle, :), 1));
    c = [0, 0, 0];
    plot(com_, vec_scloc_level - 0.5, '-o', ...
        'Color', c, ...
        'MarkerFaceColor', c, 'MarkerEdgeColor', 'None', 'MarkerSize', 4);
end
%%
sgtitle('all');
figure(h_f);
drawnow; % not sure if needed
print_local(h_f, [60, 15], v.p_fig);

close all;
end

function [com, lat] = f_comlat(x, y)
% center of mass
y_m = y - 0.2;  % this -0.2 is very arb.
y_m(y_m<0) = 0;
com = nansum(x.*y_m)./nansum(y_m);
lat = x(find(y > 0.75, 1, 'first'));
if lat > 0.05, lat = nan;end
if isempty(lat), lat = nan;end
end