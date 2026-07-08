function injury = return_injury
p_injury = fullfile(getenv('D_PROC'), 'auxillary', 'injury', 't2_levels.json');
% disp(p_injury);
assert(exist(p_injury, 'file') == 2, 'injury file gone?');
injury = loadjson(p_injury);
injury = injury.injury;

% convert cell arrays to string arrays
cell_participant = fieldnames(injury);
for ix_p = 1:length(cell_participant)
    participant = cell_participant{ix_p};
    injury.(participant) = string(injury.(participant));
end
end