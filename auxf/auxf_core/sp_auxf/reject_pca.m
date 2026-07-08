function y_e_out = reject_pca(y_e_out, y_ep, t, valid_t, auc_th, n_pc, fraction_reject, w_edge)
if isempty(y_e_out)
    y_e_out = false(size(y_ep, 1), 1);
end
auc = trapz(t(valid_t), abs(y_ep(:, valid_t)'));
y_ep_valid_tr = y_ep(:, valid_t).';
y_error = nan(size(y_ep, 1), 1);
if size(y_ep_valid_tr, 2)<n_pc, n_pc = size(y_ep_valid_tr, 2);end
for ix_record = 1:size(y_ep, 1)
    y_local = y_ep(ix_record, valid_t).';
    case_valid = false(size(y_ep, 1), 1);
    case_valid(setdiff(1:size(y_ep, 1), ix_record)) = true;
    [~, ix_similar] = sort(pdist2(y_ep_valid_tr', y_local'));
    case_valid(ix_similar<=3) = false;  % don't include the most similar traces to the one in question (in case stereotypical artifcat)
    case_valid(y_e_out) = false;
    n_pc_local = n_pc;
    if n_pc_local>sum(case_valid), n_pc_local = sum(case_valid);end
    [~, G] = pca(y_ep_valid_tr(:, case_valid), ...
        'Centered', true, 'NumComponents', n_pc_local);
    b = regress(y_local, G);
    e = G*b - y_ep_valid_tr(:, ix_record);
    w = 1 + w_edge * [1 - tukeywin(length(e), 0.1)];  % weight error at edges
    abs_e = abs(e).*w;
    y_error(ix_record, 1) = mean(abs_e);
end

candidate_threshold_max = max(y_error);
candidate_threshold_step = candidate_threshold_max/1000;
candidate_threshold = 0:candidate_threshold_step:candidate_threshold_max + candidate_threshold_step;
y_error(auc<=auc_th) = nan;  % if we have a small auc don't count them as part of the error calculation (probably not captured by a PC)
x_e_prog = arrayfun(@(x) sum(y_error > x), candidate_threshold);  %
assert(x_e_prog(end)==0, 'Please increase x_max!');
ix_th = find(x_e_prog <= ceil((fraction_reject * size(y_ep, 1))), 1, 'first');
if isempty(ix_th), ix_th = length(candidate_threshold);end
th_local = candidate_threshold(ix_th);
y_e_out = or(y_e_out, y_error > th_local);
end