function case_valid = get_case_valid(info, varargin)
%%
d.mode = 'research_scs';
d.sc_electrode_type = 'any';
d.misc = 'any';
d.sc_electrode_configuration = 'any';
d.sc_count = 'any';
d.sc_depth = 'epidural';
d.sc_approach = 'any';
d.sc_polarity = 'any';
d.sc_approach = 'any';
d.sc_laterality = 'any';
d.sc_level = 'any';
d.sc_misc = 'any';
d.sc_iti = 'any';
d.cx_count = 'any';
d.participant = 'any';
d.set_sequence_type = 'any';
d.visualise_validity = false;
d.misc_exact_check = true;

d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);

%%
if length(char(v.sc_approach)) == 1
    if upper(v.sc_approach) == "P"
        v.sc_approach = 'posterior';
    elseif upper(v.sc_approach) == "A"
        v.sc_approach = 'anterior';
    else
        error('>??');
    end
end
%%
case_valid = info.is_valid & isfinite(info.sc_current);
if v.visualise_validity
    mat_case_valid = case_valid;
    vec_validity = ["valid"];
end

%%
if ischar(v.sc_count)
    if strcmpi(v.sc_count, 'any')
        % do nothing
    elseif strcmpi(v.sc_count, 'auto_participant')
        % most common pulse count per subject
        case_valid_local = false(size(case_valid));
        cell_sub = unique(info.participant);
        for ix_cell_sub = 1:length(cell_sub)
            case_sub = strcmpi(cell_sub{ix_cell_sub}, info.participant);
            case_valid_local(case_sub) = info.sc_count(case_sub) == nanmedian(info.sc_count(case_sub));
        end
        case_valid = case_valid & case_valid_local;
    elseif strcmpi(v.sc_count, 'auto_group')
        % most common pulse count over entire group
        case_valid_local = info.sc_count == median(info.sc_count);
        case_valid = case_valid & case_valid_local;
    else
        error('?');
    end
elseif isfinite(v.sc_count)
    case_valid = case_valid & (info.sc_count == v.sc_count);
end
if v.visualise_validity
    mat_case_valid = [mat_case_valid, case_valid];
    vec_validity = [vec_validity, "count"];
end

%

if not(strcmpi(v.sc_iti, 'any'))
    if length(v.sc_iti)==1
        case_valid = case_valid & (info.sc_iti == v.sc_iti);
    else
        case_valid = case_valid & ((info.sc_iti > v.sc_iti(1)) & (info.sc_iti < v.sc_iti(2)));
    end
    
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "sc_iti"];
    end
end

if not(strcmpi(v.cx_count, 'any'))
    if length(v.cx_count) == 1
        case_valid = case_valid & (info.cx_count == v.cx_count);
    else
        case_valid = case_valid & ((info.cx_count > v.cx_count(1)) & (info.cx_count < v.cx_count(2)));
    end
    
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "cx_count"];
    end
end

if not(strcmpi(v.sc_depth, 'any'))
    case_valid = case_valid & (info.sc_depth == v.sc_depth);
    
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "sc_depth"];
    end
end

if not(strcmpi(v.misc, 'any'))
    if v.misc_exact_check
        case_valid = case_valid & (info.misc == v.misc);
    else
        case_valid = case_valid & contains(info.misc, v.misc);
    end
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "misc"];
    end
end

if not(v.participant == 'any')
    case_valid = case_valid & info.participant == v.participant;
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "participant"];
    end
end

if not(strcmpi(v.sc_approach, 'any'))
    case_valid = case_valid & contains(info.sc_approach, v.sc_approach);
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "sc_approach"];
    end
end

if not(strcmpi(v.sc_misc, 'any'))
    case_valid = case_valid & contains(info.sc_misc, v.sc_misc);
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "sc_misc"];
    end
end

if all(not(strcmpi(v.mode, 'any')))
    if ischar(v.mode)
        case_valid = case_valid & contains(info.mode, v.mode);
    elseif isstring(v.mode)
        case_valid_local = false(size(case_valid));
        for ix_mode = 1:length(v.mode)
            case_valid_local = case_valid_local | contains(info.mode, v.mode(ix_mode));
        end
        case_valid = case_valid & case_valid_local;
    end
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "mode"];
    end
end

if not(strcmpi(v.sc_laterality, 'any'))
    case_valid = case_valid & contains(info.sc_laterality, v.sc_laterality);
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "sc_laterality"];
    end
    
end
if not(strcmpi(v.sc_polarity, 'any'))
    case_valid = case_valid & contains(info.sc_polarity, v.sc_polarity);
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "sc_polarity"];
    end
end

if not(strcmpi(v.sc_level, 'any'))
    case_valid = case_valid & contains(info.sc_level, v.sc_level);
    if v.visualise_validity
        mat_case_valid = [mat_case_valid, case_valid];
        vec_validity = [vec_validity, "sc_level"];
    end
end


if strcmpi(v.sc_electrode_type, 'auto_participant')
    % most common per subject
    case_valid_local = false(size(case_valid));
    cell_sub = unique(info.participant);
    for ix_cell_sub = 1:length(cell_sub)
        case_sub = strcmpi(cell_sub{ix_cell_sub}, info.participant);
        [vec_common, ~, ix_common] = unique(info.sc_electrode_type(case_sub));
        case_valid_local(case_sub) = info.sc_electrode_type(case_sub) == vec_common(mode(ix_common));
    end
    case_valid = case_valid & case_valid_local;
elseif not(strcmpi(v.sc_electrode_type, 'any'))
    case_valid = case_valid & (info.sc_electrode_type == v.sc_electrode_type);
end
if v.visualise_validity
    mat_case_valid = [mat_case_valid, case_valid];
    vec_validity = [vec_validity, "sc_electrode_type"];
end

if strcmpi(v.sc_electrode_configuration, 'auto_participant')
    % most common per subject
    case_valid_local = false(size(case_valid));
    cell_sub = unique(info.participant);
    for ix_cell_sub = 1:length(cell_sub)
        case_sub = strcmpi(cell_sub{ix_cell_sub}, info.participant);
        [vec_common, ~, ix_common] = unique(info.sc_electrode_configuration(case_sub));
        case_valid_local(case_sub) = info.sc_electrode_configuration(case_sub) == vec_common(mode(ix_common));
    end
    case_valid = case_valid & case_valid_local;
elseif not(strcmpi(v.sc_electrode_configuration, 'any'))
    case_valid = case_valid & (info.sc_electrode_configuration == v.sc_electrode_configuration);
end
if v.visualise_validity
    mat_case_valid = [mat_case_valid, case_valid];
    vec_validity = [vec_validity, "sc_electrode_configuration"];
end

if not(strcmpi(v.set_sequence_type, 'any'))
    error('not written');
%     case_valid = case_valid & contains(info.sc_level, v.sc_level);
%     if v.visualise_validity
%         mat_case_valid = [mat_case_valid, case_valid];
%         vec_validity = [vec_validity, "sc_level"];
%     end
end

%
if v.visualise_validity
    figure(1);
    imagesc(mat_case_valid.');
    h_a = gca;
    h_a.YTick = [1:size(mat_case_valid, 2)];
    h_a.YTickLabel = vec_validity;
end
end