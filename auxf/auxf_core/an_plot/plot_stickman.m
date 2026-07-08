function plot_stickman(T_figure, varargin)
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
cell_sub = unique(T_figure.participant)';

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
layout_muscle = get_layout_muscle;
[layout_scloc, cell_scloc_level] = get_layout_scloc('output_as_string', false);
if all(cellfun(@length, T_figure.str_scloc) == 2)
    % Then we are probably scloc_level (i.e. we don't have M/L/R
    % distinction in these figures
    layout_scloc = [cell_scloc_level(1:2); cell_scloc_level(3:4); cell_scloc_level(5:6)];
end

cell_muscle = unique(layout_muscle(:));
cell_muscle(cellfun(@isempty, cell_muscle)) = [];

cell_scloc = unique(layout_scloc(:));

n_rows_m = size(layout_muscle, 1);
n_cols_m = size(layout_muscle, 2);

n_rows = size(layout_scloc, 1);
n_cols = size(layout_scloc, 2);

op = [0, 0, 0.5, 1];

for ix_cell_sub = 1:length(cell_sub)
    participant = cell_sub{ix_cell_sub};
    %     if isfield(ud.settings_data, participant)
    %         participant = ud.settings_data.(participant).alias;
    v.seed.(participant) = string2hash(participant);
    rng(v.seed.(participant));
    %     else
    %         participant = participant;
    %     end
    fprintf('%s (%s)\n', participant, participant);
    
    h_f_muscle = cell(1, length(cell_muscle));
    for ix_cell_muscle = 1:length(cell_muscle)
        str_muscle = cell_muscle{ix_cell_muscle};
        
        h_f_muscle_local = figure(...
            'Name', sprintf('%s_%s_%s%s', participant, ud.settings_figure.config, str_muscle, fig_es), ...
            'Visible', v.figvisible);
        h_f_muscle{1, ix_cell_muscle} = h_f_muscle_local;
        
        if ud.settings_figure.double_layered
            for ix_cell_scloc = 1:length(cell_scloc)
                str_scloc = cell_scloc{ix_cell_scloc};
                A = strcmpi(str_scloc, layout_scloc)';
                h_f = figure('Name', 'TEMP');
                h_a = subplot(n_rows, n_cols, find(A(:)));
                
                case_sub = T_figure.participant == participant;
                case_scloc = T_figure.str_scloc == str_scloc;
                case_muscle = T_figure.str_muscle == str_muscle;
                case_merge = case_muscle & case_sub & case_scloc;
                if sum(case_merge) == 0
                    warning('missing something?');
                    continue;
                elseif sum(case_merge) > 1
                    error('?');
                end
                f = T_figure.filename(case_merge);
                
                h_temp = openfig(fullfile(p_fig_subplots, sprintf('%s.fig', f)));
                h_child = copyobj(findall(h_temp.Children, 'Type', 'Axes'), h_f_muscle_local);
                %                 h_child = copyobj(h_temp, h_f_muscle_local);
                %                 if length(h_child)>1
                %
                %                 end
                h_child.Position = h_a.Position;
                
                is_inverse = false;  % by the nature of this function
                ud.stickman_configuration(h_child, str_scloc, str_muscle, ...
                    ud.settings_figure.stickman_configuration_info, is_inverse);
                
                close(h_temp);
                close(h_f);
            end
        else
            h_f = figure('Name', 'TEMP');
            
            str_scloc = 'all';
            case_sub = T_figure.participant == participant;
            case_scloc = T_figure.str_scloc == str_scloc;
            case_muscle = T_figure.str_muscle == str_muscle;
            case_merge = case_muscle & case_sub & case_scloc;
            if not(sum(case_merge)==1)
                disp('figure case not specified correctly');
                keyboard;
            end
            f = T_figure.filename(case_merge);
            
            h_temp = openfig(fullfile(p_fig_subplots, sprintf('%s.fig', f)));
            h_child = copyobj(h_temp.Children, h_f_muscle_local);
            %             h_child.Position = h_child.Position;
            
            is_inverse = false;
            ud.stickman_configuration(h_child, str_scloc, str_muscle, ...
                ud.settings_figure.stickman_configuration_info, is_inverse);
            
            close(h_temp);
            close(h_f);
        end
    end
    
    h_f = figure('Name', 'TEMP');
    h_f.Units = 'normalized';h_f.OuterPosition = op;
    h_ax = cell(length(cell_muscle), 1);
    for ix_cell_muscle = 1:length(cell_muscle)
        str_muscle = cell_muscle{ix_cell_muscle};
        A = strcmpi(str_muscle, layout_muscle)';
        ax = subplot(n_rows_m, n_cols_m, find(A(:)));
        h_ax{ix_cell_muscle} = get(ax);
        title(str_muscle);
    end
    
    %
    ax_color = subplot(n_rows_m, n_cols_m, [n_rows_m * n_cols_m]);
    imagesc(0, linspace(range_cmap(1), range_cmap(2), size(cmap, 1)), reshape(cmap, [size(cmap, 1), 1, 3]));
    if ud.settings_figure.colorbar.cla_first, cla;end
    ax_color.YLabel.String = ud.settings_figure.colorbar.YLabel.String;
    colorbar_width =  ud.settings_figure.colorbar.width;
    
    if any(isfinite(ud.settings_figure.colorbar.xlim))
        xlim(ud.settings_figure.colorbar.xlim);
    end
    if any(isfinite(ud.settings_figure.colorbar.ylim))
        ylim(ud.settings_figure.colorbar.ylim);
    end
    
    if not(isempty(ud.settings_figure.colorbar.text.String))
        t_local = text(ud.settings_figure.colorbar.text.x, ...
            ud.settings_figure.colorbar.text.y, ...
            ud.settings_figure.colorbar.text.String, ...
            'FontSize', 7);
        t_local.Rotation = ud.settings_figure.colorbar.text.Rotation;
    end
    ax_color.Visible = ud.settings_figure.colorbar.Visible;
    
    set(gca, 'Ydir', 'Normal');
    drawnow;
    
    % % % %
    f_name = sprintf('%s_%s%s', participant, ud.settings_figure.config, fig_es);
    h_f = figure('Name', f_name);
    h_f.Units = 'normalized';h_f.OuterPosition = op;
    colormap(cmap);
    for ix_cell_muscle = 1:length(cell_muscle)
        figure(ix_cell_muscle)
        h = get(h_f_muscle{ix_cell_muscle}, 'Children');
        newh = copyobj(h, h_f);
        for j = 1:length(newh)
            h_child = newh(j);
            h_parent = h_ax{ix_cell_muscle};
            pos_child = h_child.Position;
            pos_parent  = h_parent.OuterPosition;
            d = pos_parent(3:4)*0.05;  % 5% increase in dim
            pos_parent = pos_parent + [d(1)/2, +d(2)/2, d(1), d(2)];
            x = [pos_parent(1) + pos_parent(3) * pos_child(1), pos_parent(2) + pos_parent(4) * pos_child(2), ...
                pos_parent(3) * pos_child(3), pos_parent(4) * pos_child(4)];
            
            h_child.Position = x;
            
        end
        
        % turn this into a callback:
        %                 if ix_cell_muscle == length(cell_muscle)
        %                     g_mid = copyobj(g, h_f);
        %                     pos_child = g_mid.Position;
        %                     g_mid.Position = ax_m.Position;
        %                 end
        
        if ix_cell_muscle == length(cell_muscle)
            g_col = copyobj(ax_color, h_f);
            g_col.Position = [ax_color.Position(1) + colorbar_width*2, ax_color.Position(2), ...
                colorbar_width, ax_color.Position(4)];
            g_col.XAxis.Visible = 'off';
        end
        
        %         delete(h_ax{ix_cell_muscle});  % you should uncomment this
        close(h_f_muscle{ix_cell_muscle});
    end
    %     mat_outer_pos = cell2mat(arrayfun(@(ix) h_f.Children(ix).OuterPosition, 1:length(h_f.Children), 'UniformOutput', false)');
    %     mat_outer_pos(:, 3) = mat_outer_pos(:, 1) + mat_outer_pos(:, 3);
    %     mat_outer_pos(:, 4) = mat_outer_pos(:, 2) + mat_outer_pos(:, 4);
    %     for ix_children = 1:length(h_f.Children)
    %         h_f.Children(ix).OuterPosition(:, [1, 2]) = h_f.Children(ix).OuterPosition(:, [1, 2]) - min(mat_outer_pos(:, 1:2));
    %     end
    figure(h_f);
    drawnow; % not sure if needed
    print_local(h_f, v.figure_dim, v.p_fig);
    
    %     close all;
end
end