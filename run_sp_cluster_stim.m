% run_an_testing.m
clear;
addpath('..');
set_env;

% p_data_rejection = fullfile(getenvc('D_DATA'), 'proc_records', 'T_rejected');

config_struct = struct;ix = 0;
%%
% this is just for testing - call them live in functions as needed
str_sub = 'cornptio014';
sp_cluster_stim(str_sub);

