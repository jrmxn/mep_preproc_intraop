function stimamp_th = get_stimamp_th(info, cell_scloc, stim_diff_threshold, case_valid)
assert(islogical(case_valid), '?');
participant = unique(info.participant);
assert(length(participant), 'Works on a single subject.');
assert(stim_diff_threshold<1e-3, 'maybe you forgot to x1e-3?');
stimamp_div = 0.01 * 1e-3;
stimamp_candidate = [0:stimamp_div:20*1e-3];
A = nan(length(cell_scloc), length(stimamp_candidate));
%     prc = numSubplots(length(cell_pos));
vec_position = cellstr(info.sc_level + "_" + info.sc_laterality);
if not(sum(case_valid)>=1)
    warning('no matches');
    stimamp_th = nan;
    return;
end
for ix_cell_pos = 1:length(cell_scloc)
    %         subplot(prc(1), prc(2), ix_cell_pos);
    case_pos = strcmpi(cell_scloc{ix_cell_pos}, vec_position);
    %     case_sub = strcmpi(T.subject, participant);
    %     case_merged = get_case_merged_local(T, participant);
    
    case_merged =  case_valid & case_pos;
    stimamp = info.sc_current(case_merged);
    v_q = arrayfun(@(a) ...
        sum(and(...
        stimamp > (a - stim_diff_threshold), ...
        stimamp < (a + stim_diff_threshold))), ...
        stimamp_candidate);
    %         X = abs(stimamp_candidate - stimamp);
    %         [v_q, ~] = min(X, [], 1);
    
    if isempty(stimamp), v_q = nan(size(stimamp_candidate));end
    A(ix_cell_pos, :) = v_q;
    %         imagesc(stimamp_candidate, size(X, 1), X)
end

p_dist = nanmedian(A, 1);
%% old version < 2020-06-22
% p_dist = p_dist./trapz(stimamp_candidate, p_dist);
% [~, ix] = max(p_dist); % there might be better metric than this!!!
% stimamp_th = stimamp_candidate(ix);
%% new version > 2020-06-22
sm_sd = 0.1*1e-3;  % mA
b = normpdf(-3 * sm_sd:stimamp_div:3 * sm_sd, 0, sm_sd);
b = b./nansum(b);
if all(isnan(p_dist))
    stimamp_th = nan;
    return;
end
p_dist_smooth = filtfilt(b, 1, p_dist);
p_dist_smooth = p_dist_smooth./trapz(stimamp_candidate, p_dist_smooth);
% clf; hold on;
% findpeaks(p_dist_smooth, stimamp_candidate);
% plot(stimamp_candidate, p_dist, 'r');

[val_max, stimamp_peak] = findpeaks(p_dist_smooth, stimamp_candidate);
[val_max, ix_val_max] = sort(val_max, 'descend');
stimamp_th = stimamp_peak(ix_val_max);

if numel(stimamp_th)>1
    if (val_max(2)/val_max(1)) > 0.75
        % secondary threshold available -
        stimamp_th = stimamp_th(1:2);
    else
        stimamp_th = stimamp_th(1);
    end
end
%%
if strcmpi(participant, 'cornptio001')
    fprintf('For %s, switching primary and secondary stim. threshold!\n', participant);
    stimamp_th = fliplr(stimamp_th);
end
%%
end


% function case_merged = get_case_merged_local(T, participant)
% % you need to be a bit careful about using this function
% % since it collapses rejection over all muscles
% case_sub = strcmpi(T.subject, participant);
% if any(strcmpi(T.Properties.VariableNames, 'reject'))
%     case_keep1 = not(all(T.reject, 2));
% else
%     error('T does not contain the base rejection');
% end
% if any(strcmpi(T.Properties.VariableNames, 'reject_th'))
%     case_keep2 = not(all(T.reject_th, 2));
% else
%     case_keep2 = true(height(T), 1);
% end
% case_valid1 = not(isnan(T.amplitude));
% case_valid2 = not(strcmpi(T.horizontal, 'B'));
% case_merged = case_sub & case_keep1 & case_valid1 & case_valid2;
% end