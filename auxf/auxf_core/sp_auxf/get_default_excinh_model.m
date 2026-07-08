function [p_struct, o_fit, v_fit, struct_recruitment_parameters] = get_default_excinh_model(str_exp, varargin)
d.participant = "";
d.struct_recruitment_parameters = '';
d.error_if_not_exist = true;
d.f_model_structure = 'default';
d.model_type = 'excinh';
d.es_model = '';
d.fix_tau_val = nan;

d.d_overwrite = struct;
%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
p_model = fullfile(getenv('D_PROC'), 'auxillary', 'model_structure', v.model_type, sprintf('%s.json', v.f_model_structure));
v_fit = loadjson(p_model);v_fit = v_fit.parameters;

%%
if v_fit.fix_tau
    str_tau_val = sprintf('_%d', round(v.fix_tau_val * 1000));
    str_fix_tau = sprintf('_fix_tau%s', str_tau_val);
else
    str_fix_tau = '';
end
str_lb = sprintf('_%0.1f', v_fit.lb);
str_lb = sprintf('_lb%s', str_lb);
str_ub = sprintf('_%0.1f', v_fit.ub);
str_ub = sprintf('_ub%s', str_ub);
str_lb = strrep(strrep(str_lb, '-', 'm'), '.', 'p');
str_ub = strrep(strrep(str_ub, '-', 'm'), '.', 'p');

if strcmpi(v_fit.eval_exp, 'eval_exp_nonlinear')
    str_exp_eval = '';
else
    str_exp_eval = sprintf('_%s', v_fit.eval_exp);
end

str_params = sprintf('n%d%s%s%s%s', ...
    v_fit.n_rep, str_fix_tau, str_lb, str_ub, str_exp_eval);


%%
% str_data_specific = get_experiment_string(v);
o_fit = sprintf('%s%s', str_params, v.es_model);  % for model

%%
if isfield(v, 'participant')
    if not(v.participant == "")
        str_sub = v.participant;
    else
        str_sub = "all_";
    end
end
d_parameters = fullfile(getenvc('D_PROC'), 'preproc_standard', str_sub, 'ephys', 'parameters', 'excinh');

if isempty(v.struct_recruitment_parameters)
    v.struct_recruitment_parameters = fullfile(d_parameters, ...
        sprintf('%s_%s_%s_%s.json', v.f_model_structure, v.model_type, str_exp, o_fit));
end

if not(exist(fileparts(v.struct_recruitment_parameters), 'dir') == 7)
    mkdir(fileparts(v.struct_recruitment_parameters));
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