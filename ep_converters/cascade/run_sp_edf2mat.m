addpath(fullfile('..', '..', '..'));
set_env;
clearvars;
addpath(fullfile(getenvc('D_GIT'), 'intraop_preproc'));
project = getenvc('PROJECT');
d_data_noncoded = fullfile(getenvc('D_DATA_MAPPING_SECURE'), 'data_non-coded');
d_data_coded = fullfile(getenvc('D_DATA_MAPPING'));

overwrite = false;

%%
% Reads in EDF+D data and turns it into mat files after combining it with
% stimulation amplitude extracted from EMG stacked data if it exists.

% note that when you extract stack emg (from d-spinal cord mode), when you
% have the stimamp box (which you need) it usually fails - but it does
% export one muscle as a csv. But that one muscle file is actually enough. You need
% to save it as augmented.xlsx - see how other augmented files are constructed for guidance.
sp_cascade_edf2mat(d_data_noncoded, d_data_coded, 'overwrite', overwrite);

%%
% Now we try to augment the mat files in d_data_mat, the output gets
% stored in d_data_mat.
% The augmenting process will initially 'write' out events
% (e.g. P_S00496549_events_write.xlsx).
% These files must then be copied into an augmented file
% (e.g. P_S00496549_events_augment.xlsx) which must be edited/corrected by
% hand to reflect properities of interest (e.g. stim side).
% The augmented file is read in (with the 'augment' flag and re-combined
% with the records. Augmentation will also read data from data_cascade_event_ss
% which stores stimulation amp. extracted by OCR on the cascade program
% (see run_get_stimamp_ocr.m).

% usually should be 'augment' but can be switched to 'write',
% and rename files after manually augmenting if necessary
% augment_op = 'write';overwrite = true;
augment_op = 'augment';overwrite = true;
% additional note: this does not currently deal with T1 automatically...
% so I handle that manually in augmentation (but should integrate that)
sp_augment_events(d_data_coded, ...
    'subject_filter', {}, ...  % OPTIONAL
    'operation', augment_op, 'overwrite', overwrite);
if strcmpi(augment_op, 'write')
    return;
end

%%

% overwrite = true;
% str_sub = [];
% sp_mat_aug_to_json('str_sub', str_sub, 'overwrite', overwrite);
% convert_json_to_mat(getenv('D_DATA_MAPPING'), 'str_sub', str_sub, 'overwrite', overwrite, 'check_notch', false);
% 
% 
% 
% 
