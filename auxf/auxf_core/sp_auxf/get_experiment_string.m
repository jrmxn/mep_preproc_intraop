function str_data_specific = get_experiment_string(v_in, varargin)
d.d_overwrite = struct;
%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
if strcmpi(v_in.sc_count, 'auto_participant')
    error('sc_count must come into this function as numeric');
end
if isfield(v_in, 'sc_count'), str_sc_count = sprintf('_pc%d', v_in.sc_count); else str_sc_count = '';end
if isfield(v_in, 'sc_depth')
    if strcmpi(v_in.sc_depth, 'subdural')
        str_sc_subdural = sprintf('%s', '_subdural');
    elseif strcmpi(v_in.sc_depth, 'epidural')
        str_sc_subdural = sprintf('%s', '');  % leave blank as deault
    else
        error('?');
    end
else
    str_sc_subdural = sprintf('%s', '');  % leave blank as deault
end
str_data_specific = sprintf('%s_%s_%s%s%s', v_in.sc_approach, v_in.sc_electrode_type, v_in.sc_electrode_configuration, str_sc_count, str_sc_subdural);

% if isfield(v_in, 'participant')
%     % not sure about this...
%     if not(v_in.participant == "")
%         str_data_specific = v_in.participant + "_" + str_data_specific;
%     end
% end
end