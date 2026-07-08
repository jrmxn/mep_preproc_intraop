addpath(fullfile('..', '..', '..'));
addpath(fullfile('..'));
set_env;
clearvars;
% addpath(fullfile(getenvc('D_GIT'), 'intraop_preproc'));
% addpath(fullfile(getenvc('D_GIT'), 'run_cfg'));

project = getenvc('PROJECT');

%%
config_struct = load_configurations('cfg_surgical_studio_augment.json', 'open_config_file', true);

%%
augment_op = config_struct.augment_op;overwrite = config_struct.overwrite;
participant_ix = config_struct.participant_ix;
participant_ix_str = string(arrayfun(@(x) sprintf('%03d', x), participant_ix, 'UniformOutput', false)).';
vec_participant = config_struct.participant_prefix + participant_ix_str; 
d_data = fullfile(getenvc(config_struct.data_directory));

for ix_vec_participant = 1:length(vec_participant)
    participant = vec_participant(ix_vec_participant);
    disp(participant);
    sp_surgical_studio_augment(participant, d_data,...
        'operation', augment_op, 'overwrite', overwrite);
    if strcmpi(augment_op, 'write')
        return;
    end
    pause(5);
    convert_json_to_flatmat(d_data, 'participant', participant, 'overwrite', overwrite, 'check_notch', false, ...
        'check_lowcut', false);
end

fprintf('Now edit: \n%s\n', fullfile(getenv('D_PROC'), '/auxillary/participant_mapping/'));
