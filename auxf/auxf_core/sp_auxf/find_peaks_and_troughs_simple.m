function [cell_peaks] = find_peaks_and_troughs_simple(y_ep, t, ...
    fp_MinPeakProminence, fp_MinPeakHeight, fp_MinPeakWidth, t_min)
case_finite = all(isfinite(y_ep), 1);

if all(not(case_finite)), cell_peaks = {};return;end

assert(sum(diff(case_finite) == +1) == 1, 'must be boxcar');
assert(sum(diff(case_finite) == -1) == 1, 'must be boxcar');

y_ep_valid = y_ep(:, case_finite);
t_valid = t(case_finite);

cell_peaks = cell(1, size(y_ep_valid, 1));

for ix_ep = 1:size(y_ep_valid, 1)
    [ty_u, tx_u] = findpeaks(+y_ep_valid(ix_ep, :), t_valid, ...
        'MinPeakProminence', fp_MinPeakProminence, ...
        'MinPeakHeight', fp_MinPeakHeight, ...
        'MinPeakWidth', fp_MinPeakWidth);
    
    [ty_d, tx_d] = findpeaks(-y_ep_valid(ix_ep, :), t_valid, ...
        'MinPeakProminence', fp_MinPeakProminence, ...
        'MinPeakHeight', fp_MinPeakHeight, ...
        'MinPeakWidth', fp_MinPeakWidth);
    
    tx = [tx_u, tx_d];
    ty = [ty_u, ty_d];
    tud = [+ones(size(ty_u)), zeros(size(ty_d))];
    
    tx = tx(:);
    ty = ty(:) .* (2 * tud(:) - 1);
    tud = tud(:);
    T = array2table([tx, ty, tud]);
    T.Properties.VariableNames = {'x', 'y', 'is_up'};
    T(T.x< t_min + 2e-3, :) = [];
    cell_peaks{1, ix_ep} = T;
end

end