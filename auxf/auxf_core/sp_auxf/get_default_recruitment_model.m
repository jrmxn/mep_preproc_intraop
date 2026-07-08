function [p_struct, o_fit, v_fit, struct_recruitment_parameters] = get_default_recruitment_model(varargin)
d.participant = "";
d.struct_recruitment_parameters = '';
d.error_if_not_exist = true;
d.f_model_structure = 'default';
d.model_type = 'recruitment';
d.es_model = '';

d.sc_count = 3;
d.sc_approach = 'posterior';
d.sc_electrode_type = 'handheld';
d.sc_electrode_configuration = 'RC';
d.sc_depth = 'epidural';

d.d_overwrite = struct;
%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
p_model = fullfile(getenv('D_PROC'), 'auxillary', 'model_structure', v.model_type, sprintf('%s.json', v.f_model_structure));
v_fit = loadjson(p_model);v_fit = v_fit.parameters;

%%
if strcmpi(v_fit.noise_model, 'none')
    str_lambda = strrep(strrep(sprintf('l%0.1e', v_fit.lambda), '.', 'p'), '-', 'm');
    v_fit.fix_noise = true;
    v_fit.fix_erroroutlier = true;
else
    str_lambda = '';
    v_fit.fix_noise = false;
end
if v_fit.fix_offset, v_fit.merge_offset = true;end
if v_fit.fix_erroroutlier, v_fit.merge_erroroutlier = true;end
if strcmpi(v_fit.roof_type, 'none'), v_fit.fix_roof = true;end
if mod(v_fit.w_roof, 1) < eps  % is integer (not integer type though)
    str_w_roof = sprintf('%d', v_fit.w_roof);
else
    str_w_roof = strrep(sprintf('%0.2f', v_fit.w_roof), '.', 'p');
end


str_params = sprintf('%d%d%d%d%d%d%d%d%d%s%s%s%s', ...
    v_fit.fix_offset, v_fit.fix_roof, v_fit.fix_noise, v_fit.fix_knee, v_fit.fix_erroroutlier, ...
    v_fit.merge_offset, v_fit.merge_knee, v_fit.merge_erroroutlier, v_fit.max_auc, str_w_roof, v_fit.roof_type, str_lambda);


%%
str_data_specific = get_experiment_string(v);
o_fit = sprintf('%s%s_%s_l%s%s', v_fit.merge_met_fit, v_fit.noise_model, str_params, v.es_model);  % for model

%%
if isfield(v, 'participant')
    if not(v.participant == "")
        str_sub = v.participant;
    else
        str_sub = "all_";
    end
end
d_parameters = fullfile(getenvc('D_PROC'), 'preproc_standard', str_sub, 'ephys', 'parameters');

if isempty(v.struct_recruitment_parameters)
    v.struct_recruitment_parameters = fullfile(d_parameters, ...
        sprintf('%s_asweep_%s_%s.json', str_sub, str_data_specific, o_fit));
end

clear p_struct;
if exist(v.struct_recruitment_parameters, 'file') == 2
    [d_, f_, ext_] = fileparts(v.struct_recruitment_parameters);
    d_ = fullfile(d_, 'backup');
    if not(exist(d_, 'dir')==7), mkdir(d_);end
    p_ = fullfile(d_, sprintf('%s%s%s', f_, datestr(datetime, 'YYYY-mm-DDTHH'), ext_));
    copyfile(v.struct_recruitment_parameters, p_);  % just make a backup
    p_struct = loadjson(v.struct_recruitment_parameters);
    p_struct = p_struct.p_struct;
else
    if v.error_if_not_exist
        [a, b, c] = fileparts(v.struct_recruitment_parameters);
        fprintf('Looking for:\n%s%s in \n%s\n', b, c, a);
        error('p_struct should exist to run this function!')
    else
        % generally you want to do this if calling from an_recruitment
        p_struct = struct;
        p_struct.v_fit = v;  % it is weird to call this v_fit since v does not contain v_fit
    end
end

struct_recruitment_parameters = v.struct_recruitment_parameters;

end