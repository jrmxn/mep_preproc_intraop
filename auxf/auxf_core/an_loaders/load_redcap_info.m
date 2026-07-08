function redcap_events = load_redcap_info(varargin)
d.redcap_path = "local_data";
d.filename_must_contain = [""];
d.augment_with_old_wcm_data = false;
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
p_rc = v.redcap_path;
if p_rc == "latest_downloads"
    p_rc = fullfile(getuserdir, 'Downloads');
end
if p_rc == "local_data"
    p_rc = fullfile(getuserdir, 'Local', 'data', 'redcap_participants');
end
p_rc = glob(fullfile(p_rc, '**.csv'));
p_rc = p_rc(contains(p_rc, v.filename_must_contain));
assert(not(isempty(p_rc)), 'Cannot find redcap CSV file?');
for ix_p_rc_instance = 1:length(p_rc)
    p_rc_instance = p_rc{ix_p_rc_instance};
    if not(contains(p_rc, v.filename_must_contain))
        continue
    end
    if not(exist(p_rc_instance, 'file') == 2)
        error('Missing redcap file - checking here:\n%s', p_rc_instance);
    end
    opts = detectImportOptions(p_rc_instance, 'Delimiter', ',');
    should_be_double = contains(opts.VariableNames, 'lfor') |...
        contains(opts.VariableNames, 'rfor') | ...
        contains(opts.VariableNames, 'sten');

    opts.VariableTypes(should_be_double) = repmat({'double'}, 1, sum(should_be_double));
    % opts.VariableTypes = strrep(opts.VariableTypes, 'char', 'string');
    redcap_events_local = readtable(p_rc_instance, opts);

    case_t1 = strcmpi(redcap_events_local.Properties.VariableNames, 't1');
    if sum(case_t1) == 1
        % old bug?
        redcap_events_local.Properties.VariableNames{case_t1} = 'im_lfor_t1';
    elseif sum(case_t1) == 0
        % ok
    else
        error('?');
    end

    redcap_events_local = clean_up_foraminalstenosis_data(redcap_events_local);

    redcap_events_local = clean_up_centralstenosis_data(redcap_events_local);

    redcap_events_local = clean_up_reflex_data(redcap_events_local);

    redcap_events_local.record_id_custom = string(redcap_events_local.record_id_custom);

    redcap_events_local = clean_up_strength_data(redcap_events_local);

    p_redcap_vn_mappings = fullfile(getenvc('D_PROC'), 'auxillary', 'REDcap', 'redcap_variable_name_mappings.json');
    redcap_vn_mappings = loadjson(p_redcap_vn_mappings);
    redcap_events_local.Properties.UserData.mapping_sex = redcap_vn_mappings.sex;
    redcap_events_local.Properties.UserData.mapping_ethnicity = redcap_vn_mappings.ethnicity;
    redcap_events_local.Properties.UserData.mapping_race = redcap_vn_mappings.race;
    redcap_events_local.Properties.UserData.mapping_pain = redcap_vn_mappings.pain;
    redcap_events_local.Properties.UserData.mapping_onset = redcap_vn_mappings.onset;
    redcap_events_local.Properties.UserData.mapping_default_radial = redcap_vn_mappings.default_radial;

    if v.augment_with_old_wcm_data && contains(p_rc_instance, 'PairedBrainAndSpinal')
        redcap_events_local = augment_with_wcm_data(redcap_events_local);
    end

    followup_timestamp =NaT(size(redcap_events_local.followup_timestamp));
    for ix_row = 1:height(redcap_events_local)
        if iscell(        redcap_events_local.followup_timestamp(ix_row))
            % do nothing probably blank
        else
          followup_timestamp(ix_row) = redcap_events_local.followup_timestamp(ix_row);
        end
    end
    redcap_events_local.followup_timestamp = followup_timestamp;
    redcap_events_local.mjoa = redcap_events_local.mjoa_le + redcap_events_local.mjoa_ue + redcap_events_local.mjoa_sensory_sd + redcap_events_local.mjoa_sensory_ue;

    redcap_events_local(:, contains(redcap_events_local.Properties.VariableNames, '_pm')) = [];  % TEMPORARY - DELETE +/- strength data

    if ix_p_rc_instance == 1
        redcap_events = redcap_events_local;
    else
        redcap_events = [redcap_events; redcap_events_local];
    end
end
end

function redcap_events = clean_up_foraminalstenosis_data(redcap_events)
p_redcap_vn_mappings = fullfile(getenvc('D_PROC'), 'auxillary', 'REDcap', 'redcap_variable_name_mappings.json');
redcap_vn_mappings = loadjson(p_redcap_vn_mappings);


vec_fsten_labels = fieldnames(redcap_vn_mappings.foraminal_stenosis);
vec_fsten_labels_in = string(vec_fsten_labels(:).');
vec_fsten_labels = vec_fsten_labels_in;
for ix_vec_fsten_labels = 1:length(vec_fsten_labels_in)
    str_label = vec_fsten_labels_in{ix_vec_fsten_labels};
    ix_label = redcap_vn_mappings.foraminal_stenosis.(str_label) + 1;
    vec_fsten_labels(ix_label) = str_label;
end

vec_fsten_grading = nan(size(vec_fsten_labels));
for ix_vec_fsten_labels = 1:length(vec_fsten_labels)
    str_label = vec_fsten_labels{ix_vec_fsten_labels};
    grading_value =  redcap_vn_mappings.foraminal_stenosis_grading.(str_label);
    if isempty(grading_value), grading_value = nan;end
    vec_fsten_grading(ix_vec_fsten_labels) =grading_value;
end

vec_fsten_labels(vec_fsten_labels == "missing") = string(missing);

redcap_events.Properties.UserData.vec_fsten_labels = vec_fsten_labels;
redcap_events.Properties.UserData.vec_fsten_grading = vec_fsten_grading;

for ix_col = 1:size(redcap_events, 2)
    str_col = redcap_events.Properties.VariableNames{ix_col};

    if contains(str_col, 'im_lfor') || contains(str_col, 'im_rfor')
        vec_for = redcap_events.(str_col);
        vec_for = vec_for + 1;  % change matlab indexing
        vec_for(not(isfinite(vec_for))) = find(ismissing(vec_fsten_labels));

        vec_for = vec_fsten_labels(vec_for);

        redcap_events.(str_col) = vec_for(:);
    end
end
end

function redcap_events = clean_up_centralstenosis_data(redcap_events)
p_redcap_vn_mappings = fullfile(getenvc('D_PROC'), 'auxillary', 'REDcap', 'redcap_variable_name_mappings.json');
redcap_vn_mappings = loadjson(p_redcap_vn_mappings);


vec_sten_labels = fieldnames(redcap_vn_mappings.central_stenosis);
vec_sten_labels_in = string(vec_sten_labels(:).');
vec_sten_labels = vec_sten_labels_in;
for ix_vec_sten_labels = 1:length(vec_sten_labels_in)
    str_label = vec_sten_labels_in{ix_vec_sten_labels};
    ix_label = redcap_vn_mappings.central_stenosis.(str_label) + 1;
    vec_sten_labels(ix_label) = str_label;
end

vec_sten_grading = nan(size(vec_sten_labels));
for ix_vec_sten_labels = 1:length(vec_sten_labels)
    str_label = vec_sten_labels{ix_vec_sten_labels};
    grading_value =  redcap_vn_mappings.central_stenosis_grading.(str_label);
    if isempty(grading_value), grading_value = nan;end
    vec_sten_grading(ix_vec_sten_labels) =grading_value;
end

vec_sten_labels(vec_sten_labels == "missing") = string(missing);

redcap_events.Properties.UserData.vec_csten_labels = vec_sten_labels;
redcap_events.Properties.UserData.vec_csten_grading = vec_sten_grading;

for ix_col = 1:size(redcap_events, 2)
    str_col = redcap_events.Properties.VariableNames{ix_col};

    if contains(str_col, 'im_sten')
        vec_sten = redcap_events.(str_col);
        vec_sten = vec_sten + 1;  % change matlab indexing
        vec_sten(not(isfinite(vec_sten))) = find(ismissing(vec_sten_labels));

        vec_sten = vec_sten_labels(vec_sten);

        redcap_events.(str_col) = vec_sten(:);
    end
end
end

function redcap_events = clean_up_strength_data(redcap_events)
p_redcap_vn_mappings = fullfile(getenvc('D_PROC'), 'auxillary', 'REDcap', 'redcap_variable_name_mappings.json');
redcap_vn_mappings = loadjson(p_redcap_vn_mappings);

% uppers
vec_mtst_uppers_muscle = string(fieldnames(redcap_vn_mappings.strength_uppers.nice));
vec_mtst_uppers_labels = redcap_vn_mappings.strength_uppers.labels;
redcap_events.Properties.UserData.vec_mtst_uppers_muscle = vec_mtst_uppers_muscle(:).';
redcap_events.Properties.UserData.vec_mtst_uppers_labels = vec_mtst_uppers_labels(:).';
redcap_events.Properties.UserData.nice_mtst_uppers = char_val_to_string(redcap_vn_mappings.strength_uppers.nice);

% lowers (were not as nicely set up in redcap so rely more on vn_mappings)
fn = fieldnames(redcap_vn_mappings.strength_lowers.forward_var);
for ix_fn = 1:length(fn)
    case_fn = redcap_events.Properties.VariableNames == string(fn{ix_fn});
    assert(sum(case_fn) == 1, 'Bad redcap vn mapping in config file?');
    redcap_events.Properties.VariableNames{case_fn} = redcap_vn_mappings.strength_lowers.forward_var.(fn{ix_fn});
end

vec_mtst_lowers_muscle = string(fieldnames(redcap_vn_mappings.strength_lowers.nice));
vec_mtst_lowers_labels = redcap_vn_mappings.strength_lowers.labels;
redcap_events.Properties.UserData.vec_mtst_lowers_muscle = vec_mtst_lowers_muscle(:).';
redcap_events.Properties.UserData.vec_mtst_lowers_labels = vec_mtst_lowers_labels(:).';
redcap_events.Properties.UserData.nice_mtst_lowers = char_val_to_string(redcap_vn_mappings.strength_lowers.nice);

% Correct for zero indexing - so that now the indeces correspond to the
% labels
for ix_col = 1:size(redcap_events, 2)
    str_col = redcap_events.Properties.VariableNames{ix_col};
    if contains(str_col, 'med_mtst_') && not(contains(str_col, '_pm'))  %N.B. NOT USING PLUS MINUS DATA FOR NOW
        redcap_events.(str_col) = redcap_events.(str_col) + 1;
    end
end

end

function redcap_events = clean_up_reflex_data(redcap_events)
p_redcap_vn_mappings = fullfile(getenvc('D_PROC'), 'auxillary', 'REDcap', 'redcap_variable_name_mappings.json');
redcap_vn_mappings = loadjson(p_redcap_vn_mappings);

vec_reflexes_muscle = string(fieldnames(redcap_vn_mappings.reflexes.nice));
vec_reflexes_muscle = vec_reflexes_muscle(:);
vec_reflexes_labels = string(redcap_vn_mappings.reflexes.labels);
vec_reflexes_labels(vec_reflexes_labels == "missing") = missing;

redcap_events.Properties.UserData.vec_reflexes_muscle = vec_reflexes_muscle(:).';
redcap_events.Properties.UserData.vec_reflexes_labels = vec_reflexes_labels(:).';
redcap_events.Properties.UserData.nice_reflexes = char_val_to_string(redcap_vn_mappings.reflexes.nice);

for ix_col = 1:size(redcap_events, 2)
    str_col = redcap_events.Properties.VariableNames{ix_col};

    if contains(str_col, 'med_reflex_l_') || contains(str_col, 'med_reflex_r_')
        %         vn_ix = strsplit(str_col, '_');vn_ix = vn_ix{end};
        %         str_muscle = redcap_vn_mapping_local.(sprintf('vn_%s', vn_ix));
        str_col_out = redcap_vn_mappings.reflexes.forward_var.(str_col);
        redcap_events.Properties.VariableNames{ix_col} = str_col_out;

        vec_ref = redcap_events.(str_col_out);
        vec_ref = vec_ref + 1;  % change matlab indexing
        vec_ref(not(isfinite(vec_ref))) = length(vec_reflexes_labels);

        redcap_events.(str_col_out) = vec_ref;
    end
end
end

function redcap_events = augment_with_wcm_data(redcap_events)
error('you need to do away with this function... and insert the spreadsheet data into the redcap');
p_redcap_vn_mappings = fullfile(getenvc('D_PROC'), 'auxillary', 'REDcap', 'redcap_variable_name_mappings.json');
redcap_vn_mappings = loadjson(p_redcap_vn_mappings);

p_clin = fullfile(getenvc('D_DATA_MAPPING'), 'auxf', 'clinical_info.xlsx');


opts = detectImportOptions(p_clin, "ReadRowNames", true, 'Sheet', 'Imaging characteristics', 'VariableNamesRange', 'B1');
opts.VariableTypes = strrep(opts.VariableTypes, 'char', 'string');
T_clin_imaging = readtable(p_clin, opts);

opts = detectImportOptions(p_clin, "ReadRowNames", false, 'Sheet', 'Strength Reflexes', 'VariableNamesRange', 'A1');
opts.VariableTypes = strrep(opts.VariableTypes, 'char', 'string');
T_clin_strref = readtable(p_clin, opts);

assert(height(T_clin_imaging) == height(T_clin_strref), 'Sheets are not the same height?!');

% rename the columns from disc levels to segments
vn  = T_clin_imaging.Properties.VariableNames;
vn_out = repmat(string, size(vn));
for ix_vn = 1:length(vn)
    vn_split = strsplit(vn{ix_vn}, '_');
    if length(vn_split) > 2
        vn_split = vn_split(2:end);
        vn_split = strrep(vn_split, 'T1', 'C8');
    end
    vn_out(ix_vn) = string(join(vn_split, '_'));
end
T_clin_imaging.Properties.VariableNames = vn_out;

% augment the foraminotomy data (other parameters not dealt with)
warning('off', 'MATLAB:table:RowsAddedExistingVars');  % cannot find a great way to append to a complex table like this
for ix_clin = 1:height(T_clin_imaging)
    ix_redcap_events = height(redcap_events) + 1;
    redcap_events.record_id(ix_redcap_events) = nan;
    for ix_col = 1:size(redcap_events, 2)
        val_temp = redcap_events{ix_redcap_events, ix_col}; % isnumeric(val_temp)
        if iscell(val_temp)
            fill_missing = {missing};
        else
            fill_missing = missing;
        end
        redcap_events{ix_redcap_events, ix_col} = fill_missing;
    end
    redcap_events.record_id_custom(ix_redcap_events) = T_clin_imaging.redcap_id(ix_clin);
    for str_side = ["l", "r"]
        for str_level = ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "t1"]
            str_old_table = sprintf('%s_foraminal_%s', upper(str_level), upper(str_side));
            str_redcap_events = sprintf('im_%sfor_%s', str_side, str_level);
            if any(contains(vn_out, str_old_table))
                redcap_events.(str_redcap_events)(ix_redcap_events) = T_clin_imaging.(str_old_table)(ix_clin);
            end
        end
    end
end
warning('on', 'MATLAB:table:RowsAddedExistingVars');

vec_muscle = fieldnames(redcap_vn_mappings.strength_uppers.nice);

isue = contains(vec_muscle, redcap_vn_mappings.isue);

% insert upper strengths
for ix_clin = 1:height(T_clin_strref)
    case_redcap_table = redcap_events.record_id_custom == T_clin_strref.redcap_id(ix_clin);
    fn_ue = fieldnames(redcap_vn_mappings.strength_uppers.forward_var);
    for ix_fn = 1:length(fn_ue)
        str_fn = redcap_vn_mappings.strength_uppers.forward_var.(fn_ue{ix_fn});
        val = T_clin_strref.(str_fn)(ix_clin);  % n.b. the actual values are written
        % while in the redcap table we have the index so need to convert...
        if isnan(val)
            ix_val = find(isnan(redcap_events.Properties.UserData.vec_mtst_uppers_labels)) - 1;
        else
            ix_val = find(redcap_events.Properties.UserData.vec_mtst_uppers_labels == val) - 1;
        end
        redcap_events.(str_fn)(case_redcap_table) = ix_val;
    end
end

% insert lower strengths
for ix_clin = 1:height(T_clin_strref)
    case_redcap_table = redcap_events.record_id_custom == T_clin_strref.redcap_id(ix_clin);
    fn_le = fieldnames(redcap_vn_mappings.strength_lowers.forward_var);
    for ix_fn = 1:length(fn_le)
        str_fn = redcap_vn_mappings.strength_lowers.forward_var.(fn_le{ix_fn});
        val = T_clin_strref.(str_fn)(ix_clin);  % n.b. the actual values are written
        % while in the redcap table we have the index so need to convert...
        if isnan(val)
            ix_val = find(isnan(redcap_events.Properties.UserData.vec_mtst_lowers_labels)) - 1;
        else
            ix_val = find(redcap_events.Properties.UserData.vec_mtst_lowers_labels == val) - 1;
        end
        redcap_events.(str_fn)(case_redcap_table) = ix_val;
    end
end

% insert reflexes
for ix_clin = 1:height(T_clin_strref)
    case_redcap_table = redcap_events.record_id_custom == T_clin_strref.redcap_id(ix_clin);
    fn_ref = fieldnames(redcap_vn_mappings.reflexes.forward_var);
    for ix_fn = 1:length(fn_ref)
        str_fn = redcap_vn_mappings.reflexes.forward_var.(fn_ref{ix_fn});
        val = T_clin_strref.(str_fn)(ix_clin);
        if ismissing(val)
            ix_val = find(ismissing(redcap_events.Properties.UserData.vec_reflexes_labels));
        else
            ix_val = find(redcap_events.Properties.UserData.vec_reflexes_labels == val);
        end
        redcap_events.(str_fn)(case_redcap_table) = ix_val;
    end
end

end

function s = char_val_to_string(s)
fn = fieldnames(s);
for ix_fn = 1:length(fn)
    s.(fn{ix_fn}) = string(s.(fn{ix_fn}));
end
end