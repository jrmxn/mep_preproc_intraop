clearvars -except rapid_info rapid_ephys rapid_v;
addpath('..');
set_env;
% p_data_rejection = fullfile(getenvc('D_DATA'), 'proc_records', 'T_rejected');

close all;

d.sc_approach = 'posterior';  %'any', 'anterior', 'posterior'

d.participant_filter = [];

d.es_fig = '';
d.config = 'immediate';
d.ephys_mode = 'research_paired_repeat';

d.figvisible = 'on';
d.figformat = 'png';
d.figsave = true; % for pdf/png only
d.fontsizeAxes = 7;
d.fontsizeText = 6;

v = d;

% [vec_participant1, info1, ephys1, ~, vec_alias1] = load_data('participant', v.participant_filter, ...
%     'apply_clustering', false, ...
%     'apply_regress_shock', false, ...
%     'participant_mapping', 'scap_study');

[vec_participant, info, ephys, ~, vec_alias] = load_data('participant', v.participant_filter, ...
    'apply_clustering', false, ...
    'apply_regress_shock', false, ...
    'participant_mapping', 'mapping_all_study');
% vec_participant = [vec_participant1, vec_participant2];
% vec_alias = [vec_alias1, vec_alias2];
% info = [info1; info2];
% ephys = [ephys1; ephys2];
%%
case_valid = get_case_valid(info, 'sc_depth', 'any');

%%
vec_muscle = info.Properties.UserData.(v.ephys_mode).channels(info.Properties.UserData.(v.ephys_mode).channel_type == "EMG");
vec_channel = info.Properties.UserData.(v.ephys_mode).channels;
vec_muscle_unsided = info.Properties.UserData.(v.ephys_mode).channels_muscles_half;
t = info.Properties.UserData.(v.ephys_mode).t;
vec_displacement = [-2:0.5:22];

%%

v.t_auc_min = 0;  % ms
v.t_auc_max = 65;  % ms
case_t_auc = (t > v.t_auc_min*1e-3) & (t < (v.t_auc_min + v.t_auc_max)*1e-3);
X = [];
%     Y_ = info.reject_research_mep | info.reject_research_paired_averaged | info.reject_research_paired_repeat | info.reject_research_scs;
Y_ = info.reject_research_scs;
Y = [];
case_valid_channel = cell2mat(arrayfun(@(x) ephys{x}.custom.matched_channel.', 1:height(info), 'UniformOutput', false).');

for ix_vec_muscle = 1:length(vec_muscle)
    str_muscle =  vec_muscle(ix_vec_muscle);
    case_ch = str_muscle == vec_channel;
    
    case_valid_ch_local = case_valid_channel(:, case_ch) & case_valid;
    if sum(case_valid_ch_local) == 0, continue, end;
    y = Y_(case_valid_ch_local, case_ch);
    x_mep = cell2mat(cellfun(@(x) x.data(case_ch, :), ephys(case_valid_ch_local, :), 'UniformOutput', false));
    
    x_mep = x_mep(:, case_t_auc);
    
    x_mep = downsample(x_mep.', 5).';
    
    X = [X; x_mep];
    Y = [Y; y];
    
end

X = num2cell(X, 2);
Y = categorical(logical(Y));
%%
sum(Y == categorical(true))/length(Y)
%%
ntest = round(length(Y) * 0.1);
ix_test = randi(ntest, [ntest, 1]);
ix_train = 1:length(Y);
ix_train = setdiff(ix_train, ix_test);
YTest = Y(ix_test);
XTest = X(ix_test);
XTrain = X(ix_train);
YTrain = Y(ix_train);

case_false = YTrain==categorical(false);
case_true = YTrain==categorical(true);
ix_case_false = find(case_false);
ix_case_true = find(case_true);

frac_true = (sum(case_true)/length(YTrain));

use_focal_loss = true;
if use_focal_loss
    false_to_true_ratio = 5;
else
    false_to_true_ratio = 2; % downsample non-reject training data
end
n_true_downsampled = round(frac_true * length(YTrain) * false_to_true_ratio);

ix_randperm = randperm(length(ix_case_false));

ix_case_false_ds = ix_case_false(ix_randperm(1:n_true_downsampled));

ix_case_ds = [ix_case_true(:).', ix_case_false_ds(:).'];
ix_case_ds = ix_case_ds(randperm(length(ix_case_ds)));

XTrain_ds = XTrain(ix_case_ds);
YTrain_ds = YTrain(ix_case_ds);

ValidationData={XTest,YTest};
if use_focal_loss
    % no idea about this - just thought I would try it
    size_type = "medium";
    if size_type == "medium"
        layers = [
            sequenceInputLayer(1,"Name","sequence")
            gruLayer(3,"Name","gru_1")
            dropoutLayer(0.5)
            gruLayer(1,"Name","gru_2",'OutputMode','last')
            dropoutLayer(0.5)
            fullyConnectedLayer(2,"Name","fc")
            softmaxLayer("Name","softmax")
            focalLossLayer("Name","focalloss")];
    elseif size_type == "large"
        layers = [
            sequenceInputLayer(1,"Name","sequence")
            gruLayer(10,"Name","gru_1")
            dropoutLayer(0.5)
            gruLayer(2,"Name","gru_2",'OutputMode','last')
            dropoutLayer(0.5)
            fullyConnectedLayer(2,"Name","fc")
            softmaxLayer("Name","softmax")
            focalLossLayer("Name","focalloss")];
    else
        layers = [
            sequenceInputLayer(1,"Name","sequence")
            gruLayer(1,"Name","gru_1",'OutputMode','last')
            dropoutLayer(0.5)
            fullyConnectedLayer(2,"Name","fc")
            softmaxLayer("Name","softmax")
            focalLossLayer("Name","focalloss")];
    end
else
    layers = [
        sequenceInputLayer(1,"Name","sequence")
        gruLayer(1,"Name","gru_1",'OutputMode','last')
        dropoutLayer(0.5)
        fullyConnectedLayer(2,"Name","fc")
        softmaxLayer("Name","softmax")
        classificationLayer("Name","classoutput")];
end

options = trainingOptions('adam', ...
    'ExecutionEnvironment','gpu', ...
    'Shuffle','every-epoch', ...
    'Verbose',0, ...
    'MaxEpoch', 10000, ...
    'ValidationData', ValidationData, ...%ValidationData={XValidation,YValidation}, ...
    'Plots','training-progress');

% miniBatchSize = 30;
% options = trainingOptions('adam', ...
%     'ExecutionEnvironment','gpu', ...
%     'Shuffle','every-epoch', ...
%     'Verbose',0, ...
%     'MaxEpoch', 1000, ...
%     'ValidationData', ValidationData, ...%ValidationData={XValidation,YValidation}, ...
%     'MiniBatchSize',miniBatchSize, ...
%     'Plots','training-progress');

%%
net = trainNetwork(XTrain_ds,YTrain_ds,layers,options);
% does not work very well - one reason is the imbalanced data set
% not sure if that is the only reason. Not feeding the network with info
% about condition which is a big part of how a human does the rejection I
% think.

%%

y_p = net.classify(XTest);
sum(y_p == categorical(true))
%%
for ix_y_p = 1:length(y_p)
    if y_p(ix_y_p) == categorical(true)
        plot(XTest{ix_y_p});
        title(ix_y_p);
        drawnow;
        pause(0.5);
    end
end
