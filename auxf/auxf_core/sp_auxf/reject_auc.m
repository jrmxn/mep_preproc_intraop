function y_e_out = reject_auc(y_e_out, y_ep, t, valid_t, auc_bound_lower, auc_bound_upper)
if isempty(y_e_out)
    y_e_out = false(size(y_ep, 1), 1);
end

% Fast vectorized trapezoidal integration using matrix multiplication
% This avoids transpose overhead and leverages optimized BLAS routines
t_val = t(valid_t);
if length(t_val) < 2
    auc = zeros(size(y_ep, 1), 1);
else
    dt = diff(t_val(:));
    w = 0.5 * [dt(1); dt(1:end-1) + dt(2:end); dt(end)];
    auc = abs(y_ep(:, valid_t)) * w;
end

log10_auc = log10(auc);
y_e_out(log10_auc < auc_bound_lower | log10_auc > auc_bound_upper) = true;
end