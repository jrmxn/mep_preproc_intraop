clear;
addpath('..');
addpath(fullfile('..', '..', '..'));
set_env;
overwrite = true;  % !!!
% vec_participant = "scapptio001"; plot_shock_channel = nan;
% vec_participant = "scapptio003"; plot_shock_channel = nan;  %10;  % or 7
% vec_participant = "scapptio004"; plot_shock_channel = nan;
% vec_participant = "scapptio005"; plot_shock_channel = 9;  % or 6
% vec_participant = "scapptio006"; plot_shock_channel = 6;
% vec_participant = "scapptio007"; plot_shock_channel = nan;
% vec_participant = "scapptio010"; plot_shock_channel = nan;
vec_participant = "scapptio0" + ["01", "03", "04", "05", "06", "07", "08", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21"]; plot_shock_channel = nan;
% vec_participant = "scapptio0" + ["12"]; plot_shock_channel = nan;

for ix_vec_participant = 1:length(vec_participant)
    participant = vec_participant(ix_vec_participant);
    sp_epworks(participant, 'overwrite', overwrite, 'plot_shock_channel', plot_shock_channel, 'overwrite_stimamp_extract', false);
end
pause(2.5);
for ix_vec_participant = 1:length(vec_participant)
    participant = vec_participant(ix_vec_participant);
    convert_json_to_flatmat(getenv('D_DATA_SCAP'), 'participant', participant, 'overwrite', overwrite);
end
