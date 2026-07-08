function [c_map_pos, vec_side, cell_level, cmap] = get_cmap_sc(cell_pos, varargin)
d.color_by = 'color_by_level';
d.cmap_sc_type = 'lines';
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);

%%
vec_missing_underscore = find(not(contains(cell_pos, '_')));
for ix = 1:length(vec_missing_underscore)
    cell_pos{ix} = sprintf('%s_B', cell_pos{ix});
end
cell_level = cellfun(@(x) strsplit(x, '_'), cell_pos, 'UniformOutput', false);
cell_level = unique(cellfun(@(x) str2double(x{1}(end)), cell_level));
cell_level(isnan(cell_level)) = [];

vec_side = {'B', 'L', 'M', 'R'};

if strcmpi(v.color_by, 'color_by_level')
        mat_map = [...
    ["C4", 1];
    ["C5", 2]
    ["C6", 3]
    ["C7", 4]
    ["C8", 5]
    ["T1", 6];
    ];
    
if strcmpi(v.cmap_sc_type, 'lines')
    c = [ ...
         0    0.4470    0.7410;
    0.8500    0.3250    0.0980;
    0.9290    0.6940    0.1250;
    0.4940    0.1840    0.5560;
    0.4660    0.6740    0.1880;
    0.3010    0.7450    0.9330;
        ];
elseif strcmpi(v.cmap_sc_type, 'grayscale')
        c = ones(size(mat_map, 1), 3) .* [linspace(200, 25, size(mat_map, 1))/255].';
end
    
%     for ix_cell_side = 1:length(vec_side)
%         c_side.(vec_side{ix_cell_side}) = c(ix_cell_side, :);
%     end
       
    c_map_pos = struct;
    cmap = zeros(length(cell_pos), 3);
    for ix_cell_pos = 1:length(cell_pos)
        pos = cell_pos{ix_cell_pos};
        
        split_pos = strsplit(pos, '_');
        
        if strcmpi(split_pos{2}, 'M')
            h = 0.7;
        else
            h = 1.0;
        end
        c_ = rgb2hsv(c(find(mat_map(:, 1) == split_pos{1}), :));
        c_(3) = c_(3) * h;
        c_map_pos.(pos) = hsv2rgb(c_);
        cmap(ix_cell_pos, :) = c_map_pos.(pos);
    end
elseif strcmpi(v.color_by, 'color_by_side')
    c = [ ...
        [0, 0, 250]/255; ...
        [00, 250, 00]/255; ...
        [250, 250, 00]/255; ...
        [1, 0, 0];...
        ];
    
    for ix_cell_side = 1:length(vec_side)
        c_side.(vec_side{ix_cell_side}) = c(ix_cell_side, :);
    end
    
    c_map_pos = struct;
    cmap = zeros(length(cell_pos), 3);
    for ix_cell_pos = 1:length(cell_pos)
        pos = cell_pos{ix_cell_pos};
        
        
        split_pos = strsplit(pos, '_');
        h = 0.3 + 0.7 * find(mat_map(:, 1) == split_pos{1})/size(mat_map, 1);
        
        
        c_ = rgb2hsv(c_side.(split_pos{2}));
        c_(3) = h;
        c_map_pos.(pos) = hsv2rgb(c_);
        cmap(ix_cell_pos, :) = c_map_pos.(pos);
    end
end
end