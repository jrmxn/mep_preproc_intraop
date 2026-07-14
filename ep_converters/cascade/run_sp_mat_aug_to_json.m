addpath(fullfile('..', '..', '..'));
addpath('..');
set_env;
clearvars;
project = getenvc('PROJECT');

overwrite = true;
%%

participant = [];
% participant = "sub_xy";
vec_participant = sp_mat_aug_to_json('participant', participant, 'overwrite', overwrite);
% convert_json_to_flatmat(getenv('D_DATA_MAPPING'), 'participant', vec_participant, 'overwrite', overwrite, 'check_notch', false);
convert_json_to_flatmat(getenv('D_DATA_MAPPING'), 'overwrite', overwrite, 'check_notch', false);
