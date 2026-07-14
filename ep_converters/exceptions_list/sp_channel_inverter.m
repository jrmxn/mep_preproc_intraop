clearvars -except rapid_info rapid_ephys rapid_v;
addpath('..');
set_env;
%
%%
v.participant_mapping = 'mapping_all_study';  % update this to 'injury_study' in future
participant = "scapptio008";
v.ephys_mode = 'research_scs';
v.sc_depth = 'epidural';
v.sc_level = 'C5';
v.sc_electrode_type = 'handheld';

[vec_participant, info, ephys, v_load, vec_alias] = load_data('participant', participant, ...
    'participant_mapping', v.participant_mapping, ...
    'apply_regress_shock', false);

vec_channels = info.Properties.UserData.(v.ephys_mode).channels;
t = info.Properties.UserData.(v.ephys_mode).t;

LDeltoid = -1;
LBiceps = 1;
LTriceps = 1;


sc_approach = 'anterior';
case_valid_ant = get_case_valid(info, ...
    'sc_electrode_type', v.sc_electrode_type, ...
    'sc_level', v.sc_level, ...
    'sc_approach', sc_approach, ...  % yes - set externally
    'sc_depth', v.sc_depth);

sc_approach = 'posterior';
case_valid_pos = get_case_valid(info, ...
    'sc_electrode_type', v.sc_electrode_type, ...
    'sc_level', v.sc_level, ...
    'sc_approach', sc_approach, ...  % yes - set externally
    'sc_depth', v.sc_depth);

case_t = t < 2e-3;
vec_r = zeros(size(vec_channels));
flip_struct = struct;
for ix_vec_channels = 1:length(vec_channels)
    str_ch = vec_channels(ix_vec_channels);
    %     str_ch = "RBiceps";
    case_channel = vec_channels == str_ch;
    y_ep_ant = cell2mat(cellfun(@(x) x.data(case_channel, :), ephys(case_valid_ant), 'UniformOutput', false));
    y_ep_pos = cell2mat(cellfun(@(x) x.data(case_channel, :), ephys(case_valid_pos), 'UniformOutput', false));
    x = nanmean(y_ep_ant);
    y = nanmean(y_ep_pos);
    case_m = isfinite(x) & isfinite(y) & case_t;
    
    r = corrcoef(x(case_m), y(case_m));
    vec_r(ix_vec_channels) = r(1, 2);
    str_ch_nice = replace(str_ch, '-', '_');
    flip_struct.(str_ch_nice) = sign(r(1, 2));
    
end

disp(savejson(flip_struct))

% figure(1);clf;
% subplot(1, 1, 1);hold on;
%
% plot(t, y_ep_ant.', 'r');
%
% plot(t, y_ep_pos.', 'b');
% plot(t, -y_ep_pos.', 'g');
% xlim([0, 0.002])

%



