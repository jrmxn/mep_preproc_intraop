function y_e_out = reject_auc(y_e_out, y_ep, t, valid_t, auc_bound_lower, auc_bound_upper)
if isempty(y_e_out)
    y_e_out = false(size(y_ep, 1), 1);
end
auc = trapz(t(valid_t), abs(y_ep(:, valid_t)'));
log10_auc = log10(auc);
y_e_out(log10_auc < auc_bound_lower) = true;  % this one
y_e_out(log10_auc > auc_bound_upper) = true;
end