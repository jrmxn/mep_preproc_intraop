function T_notes = get_notes_mri(str_alias, cell_levels)

p_notes_mri = fullfile(getenvc('D_PROC'), 'auxillary', 'old_notes', 'notes_mri.json');
notes_mri = loadjson(p_notes_mri);

str_alias_n = strrep(str_alias, '-', '');
if isfield(notes_mri, str_alias_n)
    n_notes = length(notes_mri.(str_alias_n));
else
    n_notes = 0;
end

T_notes = array2table(nan(n_notes, 1));
T_notes.Properties.VariableNames = {'ix_level'};
T_notes.is_stenosis(:) = false;
T_notes.is_T2(:) = false;
T_notes.is_L(:) = false;
T_notes.is_M(:) = false;
T_notes.is_R(:) = false;
T_notes.c_ind = zeros(height(T_notes), 3);

if n_notes>0
    if not(iscell(notes_mri.(str_alias_n)))
        % single level entries are not stored as cells so fix that
        temp_note = {notes_mri.(str_alias_n)};
        notes_mri.(str_alias_n) = temp_note;
    end
end

for ix = 1:n_notes
    if not(isempty(notes_mri.(str_alias_n){ix}.level))
        level = strsplit(notes_mri.(str_alias_n){ix}.level, '-');
        ix_level = find(strcmpi(strrep(level{end}, 'VC', 'C'), cell_levels));
        if not(isempty(ix_level))
            T_notes.ix_level(ix) = ix_level;
        end
        indication = notes_mri.(str_alias_n){ix}.type;  % replace word 'injury'
        T_notes.is_stenosis(ix) = any(strcmpi('stenosis', indication));
        T_notes.is_T2(ix) = any(strcmpi('T2', indication));
        
        indication_laterality = notes_mri.(str_alias_n){ix}.laterality;
        if all(cellfun(@isempty, indication_laterality))
            % if laterality not specified then assume across all -
            indication_laterality = {'L', 'M', 'R'};
        end
        T_notes.is_L(ix) = any(strcmpi('L', indication_laterality));
        T_notes.is_M(ix) = any(strcmpi('M', indication_laterality));
        T_notes.is_R(ix) = any(strcmpi('R', indication_laterality));
        
        if and(T_notes.is_stenosis(ix), T_notes.is_T2(ix))
            T_notes.c_ind(ix, :) = [1, 0, 1];
        elseif T_notes.is_stenosis(ix)
            T_notes.c_ind(ix, :) = [1, 0, 0];
        elseif T_notes.is_T2(ix)
            T_notes.c_ind(ix, :) = [0, 0, 1];
        else
            T_notes.c_ind(ix, :) = [1, 1, 1];
        end
    else
        warning('no notes for this subject');
        break;
    end
end
cell_is_lat = {'is_L', 'is_M', 'is_R'};
T_notes.Properties.UserData.cell_is_lat = cell_is_lat;
end