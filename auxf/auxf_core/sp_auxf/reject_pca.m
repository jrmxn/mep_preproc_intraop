function y_e_out = reject_pca(y_e_out, y_ep, t, valid_t, auc_th, n_pc, fraction_reject, w_edge)
if isempty(y_e_out)
    y_e_out = false(size(y_ep, 1), 1);
end
auc = trapz(t(valid_t), abs(y_ep(:, valid_t)'));
y_ep_valid_tr = y_ep(:, valid_t).';
y_error = nan(size(y_ep, 1), 1);
num_records = size(y_ep, 1);
num_timepoints = size(y_ep_valid_tr, 1);
if num_records < n_pc
    n_pc = num_records;
end

% Precompute distance matrix to avoid pdist2 in loop
D = pdist2(y_ep_valid_tr', y_ep_valid_tr');

% Precompute Tukey window
w = 1 + w_edge * (1 - tukeywin(num_timepoints, 0.1));

% Center columns for PCA once outside the loop
Y_c = bsxfun(@minus, y_ep_valid_tr, mean(y_ep_valid_tr, 1));

for ix_record = 1:num_records
    y_local = y_ep_valid_tr(:, ix_record);
    case_valid = false(num_records, 1);
    case_valid(setdiff(1:num_records, ix_record)) = true;
    
    [~, ix_similar] = sort(D(:, ix_record));
    case_valid(ix_similar<=3) = false;  % don't include the most similar traces to the one in question (in case stereotypical artifcat)
    case_valid(y_e_out) = false;
    
    n_pc_local = n_pc;
    if n_pc_local > sum(case_valid)
        n_pc_local = sum(case_valid);
    end
    
    % Equivalent to PCA and regression, but much faster using SVD.
    % The original code was:
    %   [~, G] = pca(y_ep_valid_tr(:, case_valid), 'Centered', true, 'NumComponents', n_pc_local);
    %   b = regress(y_local, G);
    %   e = G*b - y_ep_valid_tr(:, ix_record);
    % This is mathematically identical to an orthogonal projection onto the principal 
    % component basis. Since G is the score matrix (which spans the exact same subspace 
    % as the left singular vectors U from SVD), G*b is just U*U'*y_local. By directly 
    % computing the economic SVD on the pre-centered data and projecting, we bypass 
    % the heavy overhead of pca and regress.
    X0 = Y_c(:, case_valid);
    [U, S, ~] = svd(X0, 'econ');
    s = diag(S);
    if isempty(s)
        r = 0;
    else
        tol = max(size(X0)) * eps(full(s(1)));
        r = sum(s > tol);
    end
    n_pc_actual = min(n_pc_local, r);
    
    U = U(:, 1:n_pc_actual);
    y_proj = U * (U' * y_local);
    e = y_proj - y_local;
    
    abs_e = abs(e) .* w;
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