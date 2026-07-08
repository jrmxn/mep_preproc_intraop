function t_onset_th = get_valid_onset(y_mep, t, latency_est_auc, t_onset_bounds, fs, th_onset_sd, wiggle_percentage_cutoff, th_onset_uv)
t_onset_th = nan;

t_stable_excursion = 2e-3;

case_invalid = t < t_onset_bounds(1);
y_mep_blanked = y_mep;
y_mep_blanked(case_invalid) = 0;
y_abs_blanked = abs(y_mep_blanked);

ix_first_valid = find(y_abs_blanked, 1, 'first');

sd_baseline = std(abs(y_mep(t < -1e-3)), 'omitnan');  % you need the start to be non-blanked
ix_onset_th = get_onset_from_stable_excursion(y_mep_blanked, sd_baseline * th_onset_sd, t_stable_excursion * fs, fs, wiggle_percentage_cutoff);

% y_mep_blanked2 = y_mep_blanked;
% y_mep_blanked2(case_invalid) = nan;
% y_mep_blanked2(ix_onset_th:end) = nan;
% is_valid_estimate_new = std(y_mep_blanked2, 'omitnan') < 2.5 * sd_baseline;

% make sure that when data first comes in after stim, that it
% has returned to baseline
is_valid_estimate = true;
is_valid_estimate = is_valid_estimate & y_abs_blanked(ix_first_valid) < th_onset_uv;
% is_valid_estimate = is_valid_estimate & latency_est_auc > 0;  % need to set this...
% is_valid_estimate = is_valid_estimate & range(y_mep_blanked) > 1.25 * v.th_onset_sd;
% is_valid_estimate = is_valid_estimate & is_valid_estimate_new;
is_valid_estimate = is_valid_estimate & t(ix_onset_th) * 1e3 < 50; % a late artifact
is_valid_estimate = is_valid_estimate & abs(y_mep_blanked(find(y_mep_blanked, 1, 'first'))) < 2.0;

% tm
if not(isempty(ix_onset_th)) && is_valid_estimate
    t_onset_th = t(ix_onset_th) * 1e3;
end
end

function ix_onset = get_onset_from_stable_excursion(y, threshold, n_stable_excursion, fs, wiggle_percentage_cutoff)
% n_stable_excursion: number of samples that should be stably above
% threshold for the first part of that excursion to be considered onset
% y_abs: just the abs of whatever mep you want to detect the onset of. Make
% sure you 0 out anything that could trigger the onset before you where you
% want to look (e.g. stim artifact)

% now check for excursion above threshold
y_abs = abs(y);
case_excursion = y_abs > threshold;
vec_onset = find(case_excursion);

% the excursion should last a few ms before returning to 0
vec_excursion_lasting = filter(ones(1, n_stable_excursion)/n_stable_excursion, 1, case_excursion);
vec_onset_lasting = find(vec_excursion_lasting > 1 - eps);

if isempty(vec_onset_lasting)
    ix_onset = [];
    vec_onset = [];
end

for ix_vec_onset = 1:length(vec_onset)
    ix_onset = vec_onset(ix_vec_onset);
    ix_lasting = vec_onset_lasting(vec_onset_lasting > ix_onset);
    ix_lasting = ix_lasting(1);
    % this checks that the excursion was stable from ix_onset until
    % ix_lasting
    if all(vec_excursion_lasting(ix_onset:ix_lasting) > 0)
        break;
    end
end

if not(isempty(vec_onset_lasting))
    % now traceback to where this deflection started
    ix_onset = onset_traceback(y_abs, ix_onset, fs);
end

% if not(isempty(ix_onset))
%     ix_onset_out = skip_wiggle(y, ix_onset, wiggle_percentage_cutoff);
%     ix_onset = ix_onset_out;
% end

if not(isempty(ix_onset))
    max_wiggle_skip = 5;
    ix_wiggle_skip = 0;
    carry_on = true;
    while carry_on
        ix_onset_out = skip_wiggle(y, ix_onset, wiggle_percentage_cutoff);
        if (ix_onset_out == ix_onset) || (ix_wiggle_skip > max_wiggle_skip)
            carry_on = false;
        else
            ix_onset = ix_onset_out;
            ix_wiggle_skip = ix_wiggle_skip + 1;
        end
    end
end

if ix_onset >= (length(y_abs) - n_stable_excursion)
    % just a guess that this might be needed - maybe should be
    % n_stable_excursion/2
    ix_onset = [];
end
end


function ix_onset = skip_wiggle(y, ix_onset, wiggle_percentage_cutoff)
if isfinite(wiggle_percentage_cutoff)
    dyf = diff(sign(y));
    dyf(1:ix_onset+1) = nan;

    ix_second_onset_th = find(abs(dyf) > 0, 1, 'first');

    max_initial_deflect = max(abs(y(ix_onset:ix_second_onset_th)));
    proportion_of_max = max_initial_deflect/max(abs(y));

    if proportion_of_max < wiggle_percentage_cutoff * 1e-2
        ix_onset = ix_second_onset_th;
    end
end
end

% function ix_onset = skip_wiggle(y, ix_onset, fs, wiggle_percentage_cutoff)
% if isfinite(wiggle_percentage_cutoff)
%     n = round(fs * 2.5e-3);
%     yf = filtfilt_smooth(y, n); % get rid of tiny bumps (filtfilt,  but has nans)
%     dyf = diff(sign(yf));
%     dyf(1:ix_onset-1) = nan;
%
%     if dyf(ix_onset) == 0
%         dyf(ix_onset) = sign(yf(ix_onset));
%     end
%     try
%         sign_change_near_threshold = dyf(ix_onset + [0]);
%     catch
%         keyboard;
%     end
%     if any(sign_change_near_threshold > 0)
%         ix_second_onset_th = find(dyf < 0, 1, 'first');
%     elseif any(sign_change_near_threshold < 0)
%         ix_second_onset_th = find(dyf > 0, 1, 'first');
%     else
%         keyboard;
%     end
%     max_initial_deflect = max(abs(y(ix_onset:ix_second_onset_th)));
%     proportion_of_max = max_initial_deflect/max(y);
%
%     if proportion_of_max < wiggle_percentage_cutoff * 1e-2
%         ix_onset = ix_second_onset_th;
%     end
% end
% end

function ix_onset_early = onset_traceback(y, ix_onset, fs)
n = round(fs * 0.5e-3);
yf = filtfilt_smooth(y, n); % get rid of tiny bumps (filtfilt,  but has nans)
y_man2 = sign([0, diff(yf)]);
y_man2(ix_onset:end) = 0;
y_man2 = fliplr(filter([+1, -1], 1, fliplr(y_man2)));
y_man2 = y_man2 == -2;
ix_onset_early = find(y_man2, 1, 'last');
end

function yf = filtfilt_smooth(y, n)
yf = fliplr(filter(ones(n, 1)/n, 1, fliplr(filter(ones(n, 1)/n, 1, y)))); % get rid of tiny bumps (filtfilt,  but has nans)
end
