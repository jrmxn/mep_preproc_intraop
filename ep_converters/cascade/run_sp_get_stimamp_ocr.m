addpath(fullfile('..', '..', '..'));

set_env;
clearvars;
d_data_coded = fullfile(getenvc('D_DATA_MAPPING'));
overwrite = false;
%%
% this is a secondary layer of augmentation - 
% stim-amp can be extracted from stacked emg, but sometimes data is
% corrupted or incomplete.

% this method takes control of the keyboard and moves time along in the
% cascade program, combined with OCR to read the stimulation amplitude.

%%
% this makes all the appropriate screen shots - 
% manually put in the anonymous subject ID as sub =

sub = 'P_...';  % 'P_...'  % goes here
sp_scade_ss(d_data_coded, sub);
% keyboard;  % not sure if you need this...

%%
% this then extracts the information from the screenshots -
% n.b. the output are files like '[str_sub]_write.xslx', but they should
% then be copied to augmented files (e.g. '[str_sub]_augmented.xlsx')
% which are what get read when you use run_edf2mat (specifically
% sp_augment_events.m)
sp_cascade_ss2stimamp(d_data_coded, 'overwrite', overwrite);

