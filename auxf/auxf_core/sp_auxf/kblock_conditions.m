function [c_block, str_block] = kblock_conditions(T_local, c_map_pos)
c_block = [];
str_block = {};
ix_block_end = 0;
while not(ix_block_end == height(T_local))
    ix_block_start = ix_block_end + 1;
    str_position = T_local.position(ix_block_start);
        if ismissing(str_position), ix_block_end = ix_block_end + 1;continue;end

    case_position = strcmpi(T_local.position, str_position);
    case_position(1:ix_block_start - 1) = 0;
    d_case_position = [diff(case_position);0];
    d_case_position(end) = -1;
    ix_block_end = find(d_case_position == -1, 1, 'first');
    
    if isfield(c_map_pos, str_position)
        color = c_map_pos.(str_position);
    else
        color = [0, 0, 0];
    end
    c_block = [c_block; [ix_block_start, ix_block_end, color]];
    str_block = [str_block;{str_position}];
end
end