clear;
addpath('..');
addpath(fullfile('..', '..', '..'));
set_env;

participant = 'subxy'; plot_shock_channel = nan;

overwrite = false;

sp_epworks(participant, 'overwrite', overwrite, 'plot_shock_channel', plot_shock_channel);
pause(2);
convert_json_to_flatmat(getenv('D_DATA_SCAP'), 'participant', participant, 'overwrite', overwrite);