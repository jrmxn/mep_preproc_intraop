function [s_p, print_local] = get_figure_paths(v_in, varargin)
d.es_fig = '';
d.make_tempdir = false;
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
if ischar(v_in) || isstring(v_in)
    str_config = v_in;
    v_in = struct;
    v_in.config = str_config;
end
if isfield(v_in, 'plotting')
    v_in = v_in.plotting;
end
if not(isfield(v_in, 'figsave'))
    v_in.figsave = true;
end
if not(isfield(v_in, 'figformat'))
    v_in.figformat = 'png';
end
if not(isfield(v_in, 'fontsizeText'))
    v_in.fontsizeText = 7;
end
if not(isfield(v_in, 'fontsizeAxes'))
    v_in.fontsizeAxes = 6;
end
if not(isfield(v_in, 'autoclose'))
    v_in.autoclose = false;
end
if not(isfield(v_in, 'es_fig'))
    v_in.es_fig = v.es_fig;
end

%%
FIGFORMAT = getenv('FIGFORMAT');
if not(isempty(FIGFORMAT))
    v_in.figformat = FIGFORMAT;
%     fprintf('Grabbing figure format from environment variable.\n');
end
datestr_now = getenvc('DATETIME_SESSION');

o_lower_folder = sprintf('%s', v_in.es_fig);
p_fig = fullfile(getenvc('D_REPORTS'), sprintf('%s_%s', datestr_now, v_in.config), ...
    o_lower_folder);
p_fig_subplots = fullfile(getenvc('D_REPORTS'), sprintf('%s_%s', datestr_now, v_in.config), ...
    o_lower_folder, 'subplots');

% if not(isempty(v.image_type))
%     es = sprintf('%s_%s', es, v.image_type);
% end
s_p.p_fig = p_fig;
s_p.p_fig_subplots = p_fig_subplots;
s_p.p_fig_subplots1 = sprintf('%s1', p_fig_subplots);
s_p.p_fig_subplots2 = sprintf('%s2', p_fig_subplots);

print_local = @(h, dim, figdir) printForPub(h, sprintf('%s', h.Name), 'doPrint', v_in.figsave,...
    'fformat', v_in.figformat , 'physicalSizeCM', dim, 'saveDir', figdir, 'autoclose', v_in.autoclose, ...
    'fontsizeText', v_in.fontsizeText, 'fontsizeAxes', v_in.fontsizeAxes, 'append_format_to_dir', true);

if v.make_tempdir
    p_fig_subplots_temp = fullfile(getenvc('D_TEMP'), sprintf('%s_%s', 'DATETIME', v_in.config), ...
        o_lower_folder, 'subplots');
    if not(exist(p_fig_subplots_temp, 'dir')==7), mkdir(p_fig_subplots_temp);end
    s_p.p_fig_subplots_temp = p_fig_subplots_temp;
end

s_p.p_figure_index = fullfile(s_p.p_fig, 'figure_index');
end