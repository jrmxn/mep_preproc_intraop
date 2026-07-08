function [r, opt_shift] = calculate_correlation(y_ep_ontarget, y_ep_offtarget, ...
    t, corr_method, corr_type, adjust_for_latency, output_r2, max_absr, limit_window, t_window)
dt = median(diff(t), 'omitnan');
if adjust_for_latency
    ix_shiftmax = round(t_window./dt);
else
    ix_shiftmax = 0;
end
if max_absr
    r = 0;
else
    r = -Inf;
end
opt_shift = nan;
if limit_window
    y_ep_ontarget(:, (t > 50e-3)) = nan;
end

for ix_shift = -ix_shiftmax:ix_shiftmax
    y_ep_local = circshift(y_ep_offtarget, ix_shift, 2);
    if corr_method == "average"
        x_comp = nanmean(y_ep_local, 1).';
        y_comp = nanmean(y_ep_ontarget, 1).';
    elseif corr_method == "full"
        x_comp = y_ep_local.';
        y_comp = y_ep_ontarget.';
    else
        error('Badly specified corr_method');
    end
    case_valid = isfinite(x_comp) & isfinite(y_comp);
    x_comp = x_comp(case_valid, :);
    y_comp = y_comp(case_valid, :);
    X = corr(x_comp, y_comp, 'Type', corr_type);
    r_ = median(X(:), 'omitnan');

    if max_absr
        if abs(r_) > abs(r)
            r = r_;
            opt_shift = ix_shift * dt;
        end
    else
        if r_ > r
            r = r_;
            opt_shift = ix_shift * dt;
        end
    end

end

if output_r2
    r = r.^2;
end
end