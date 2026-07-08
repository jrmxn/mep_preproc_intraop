function [column_grouping, vec_group] = get_condition_groups(info, varargin)
d.ephys_mode = "";
d.participant = [];
d.group_by_participant = false;  % n.b. default false
d.group_by_mode = true;
d.group_by_sc_level = true;
d.group_by_sc_laterality = true;
d.group_by_sc_count = true;
d.group_by_sc_electrode_type = true;
d.group_by_sc_electrode_configuration = true;
d.group_by_sc_approach = true;
d.group_by_sc_frequency = true;
d.group_by_cortical = true;
d.group_by_peripheral = true;
d.group_by_depth = true;
d.group_by_sc_polarity = false;
d.verbose = true;
d.d_overwrite = struct;
%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
if v.ephys_mode == "research_mep"
    v.group_by_sc_level = false;
    v.group_by_sc_laterality = false;
    v.group_by_sc_count = false;
    v.group_by_sc_electrode_type = false;
    v.group_by_sc_electrode_configuration = false;
    v.group_by_sc_approach = false;
    v.group_by_sc_frequency = false;
    v.group_by_depth = false;
end
if v.ephys_mode == "research_peripheral"
    v.group_by_sc_level = false;
    v.group_by_sc_laterality = false;
    v.group_by_sc_count = false;
    v.group_by_sc_electrode_type = false;
    v.group_by_sc_electrode_configuration = false;
    v.group_by_sc_approach = false;
    v.group_by_sc_frequency = false;
    v.group_by_depth = false;
end
if v.ephys_mode == "research_lcswap"
    v.group_by_sc_polarity = true;
    v.group_by_sc_level = false;
end

info.sc_electrode_type = strrep(info.sc_electrode_type, 'CEDL-4PDINX-100', '4PDINX');
%%
column_grouping = repmat("G_", height(info), 1);
if v.group_by_mode
    local_mode = info.mode;
    local_mode = strrep(local_mode, 'research_mep', 'rmep');
    local_mode = strrep(local_mode, 'research_paired_averaged', 'rpa');
    local_mode = strrep(local_mode, 'research_paired_repeat', 'rpr');
    local_mode = strrep(local_mode, 'research_peripheral', 'rpe');
    local_mode = strrep(local_mode, 'research_lcswap', 'rls');
    column_grouping = column_grouping + local_mode + "_";
end

if v.group_by_participant
    column_grouping = column_grouping + info.participant + "_";
end
if v.group_by_sc_level
    column_grouping = column_grouping + info.sc_level + "_";
end
if v.group_by_sc_laterality
    column_grouping = column_grouping + info.sc_laterality + "_";
end
if v.group_by_sc_count
    column_grouping = column_grouping + "ct" + info.sc_count + "_";
end
if v.group_by_sc_electrode_type
    column_grouping = column_grouping + info.sc_electrode_type + "_";
end
if v.group_by_sc_electrode_configuration
    column_grouping = column_grouping + info.sc_electrode_configuration + "_";
end
if v.group_by_sc_approach
    column_grouping = column_grouping + info.sc_approach + "_";
end
if v.group_by_sc_frequency
    column_grouping = column_grouping + "f" + string(round(info.sc_frequency)) + "" + "_";
end
if v.group_by_sc_polarity
    sc_pol = erase(strrep(strrep(strrep(strrep(info.sc_polarity, "[", ""), "]", ""), '-', 't'), ',', 'x'), ' ');
    column_grouping = column_grouping + "p" + sc_pol + "_";
end

if v.group_by_cortical
    column_grouping = column_grouping + "cx_" + replace(info.cx_stimulation_type, "electrical-needle", "en") + info.cx_laterality;
end
if v.group_by_peripheral
    pe_group = "pe_" + info.pe_nerve.extractBefore(2) + info.pe_laterality;
    pe_group(ismissing(pe_group)) = "";
    column_grouping = column_grouping + pe_group;
end
if v.group_by_depth
    column_grouping = column_grouping + replace(replace(info.sc_depth, "epidural", ""), "subdural", "_sub");
end
column_grouping = column_grouping + "_G";

if not(v.ephys_mode == "")
    % you can do other modes but you have to set it in v
    column_grouping(not(info.mode == v.ephys_mode)) = missing;
end

if not(isempty(v.participant))
    case_participant = false(height(info), 1);
    for ix_participant = 1:length(v.participant)
        case_participant_local = info.participant == v.participant(ix_participant);
        case_participant = case_participant | case_participant_local;
    end
    column_grouping(not(case_participant)) = missing;
end

vec_group = column_grouping;
vec_group(ismissing(vec_group)) = [];
vec_group = unique(vec_group);


end