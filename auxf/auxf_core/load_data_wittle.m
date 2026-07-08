function [vec_participant, info, ephys, vec_alias] = load_data_wittle(vec_participant, info, ephys, vec_alias, varargin)
% once data is loaded reduce it based on some conditions
% this means that you can rely on the quick load functions
% but it has to be used with extreme caution
d.must_contain_mode = 'any';
d.must_contain_sc_approach = 'any';
d.overwrite = false;
d.d_overwrite = struct;

%%
[v, d] = inputParserCustom(d, varargin);
v = inputParserStructureOverwrite(v);

%%
local_partcipant_filter = unique(info.participant);
kick_out_set = [];
if not(v.must_contain_mode == "any")
    keep_these = unique(info.participant(info.mode == v.must_contain_mode));
    kick_out_set_local = setdiff(local_partcipant_filter, keep_these);
    kick_out_set = unique([kick_out_set(:); kick_out_set_local(:)]);
    if v.must_contain_mode == "research_paired_repeat" || v.must_contain_mode == "research_paired_averaged"
        % this is a special case because in one case we were in repeat mode but
        % we did not do any actual pairing
        keep_these = unique(info.participant(not(info.sccx_latency == 0)));
        k = setdiff(local_partcipant_filter, keep_these);
        kick_out_set_local = unique([kick_out_set_local(:); k(:)]);
    end
    fprintf('Kicking out due to lack of pairing:\n');disp(kick_out_set_local.');
    kick_out_set = unique([kick_out_set(:); kick_out_set_local(:)]);
end

if not(v.must_contain_sc_approach == "any")
    keep_these = unique(info.participant(info.sc_approach == v.must_contain_sc_approach));
    kick_out_set_local = setdiff(local_partcipant_filter, keep_these);
    fprintf('Kicking out due to non-%s SC approach:\n', v.must_contain_sc_approach);disp(kick_out_set_local.');
    kick_out_set = unique([kick_out_set(:); kick_out_set_local(:)]);
end
case_rm_info = contains(info.participant, kick_out_set);
info(case_rm_info, :) = [];
ephys(case_rm_info) = [];
case_rm_participant = contains(vec_participant, kick_out_set);
vec_participant(case_rm_participant) = [];
vec_alias(case_rm_participant) = [];
end