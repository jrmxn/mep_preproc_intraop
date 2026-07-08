function [case_rm, reject_all, p_struct_condition, reject_condition] = reject_as_fit(stimamp, p_struct, str_sub, str_muscle, str_scloc, varargin)
% attempting to standardise the rejection the recruitment curves when they
% are poor

d.th_multiplier = 1.2;
d.slope_threshold = 1e-2;
d.th_threshold = 1e-2;
d.rmsel_threshold = 0.5;  % root mean suqare of difference in logs
d.c_support_threshold = 1.5; % we need points that are this much above threshold
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%

assert(iscell(p_struct.cell_scloc), 'p_struct is oddly formatted?');
cell_scloc = p_struct.cell_scloc;
if length(cell_scloc)==1
    cell_scloc = p_struct.cell_scloc{1};
end

psc = struct;
psc.rc_th = p_struct.(str_sub).(str_muscle).c(strcmpi(cell_scloc, str_scloc));
psc.rc_slope = p_struct.(str_sub).(str_muscle).b(strcmpi(cell_scloc, str_scloc));
psc.rc_rmsel = p_struct.(str_sub).(str_muscle).rmsel_specific(strcmpi(cell_scloc, str_scloc));
psc.rc_c_support = p_struct.(str_sub).(str_muscle).c_support(strcmpi(cell_scloc, str_scloc));

assert(not(isempty(psc.rc_th)), 'Something wrong with cell_scloc?');

v.stimamp_minimum = v.th_multiplier * psc.rc_th;
case_rm = false(size(stimamp));
case_rm = case_rm | stimamp < v.stimamp_minimum;
case_rm = case_rm | psc.rc_slope < v.slope_threshold;
case_rm = case_rm | psc.rc_th < v.th_threshold;
case_rm = case_rm | psc.rc_rmsel > v.rmsel_threshold;
case_rm = case_rm | psc.rc_c_support < v.c_support_threshold;

reject_all = all(case_rm);
p_struct_condition = psc;
reject_condition = v;

end