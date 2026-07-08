function [psc_rc_o, psc_rc_slope, psc_rc_th, psc_rc_roof, psc_rc_k, ...
    psc_rc_rmsel, psc_rc_c_support, psc_rc_stim_std, psc_rc_stim_pct, psc_rc_max_amp] = ...
    interrogate_p_struct(p_struct, participant, str_muscle, str_scloc)

if not(isfield(p_struct, participant))
    % probably anterior model but only posterior data or
    % vice versa.
    p_struct.(participant) = struct; % then everything should get set to nan later
end

if isfield( p_struct.(participant), str_muscle)
    cell_scloc_p = p_struct.cell_scloc{1};
    psc_rc_o = p_struct.(participant).(str_muscle).o;
    psc_rc_slope = p_struct.(participant).(str_muscle).b(strcmpi(cell_scloc_p, str_scloc));
    psc_rc_th = p_struct.(participant).(str_muscle).c(strcmpi(cell_scloc_p, str_scloc));
    psc_rc_roof = p_struct.(participant).(str_muscle).r(strcmpi(cell_scloc_p, str_scloc));
    psc_rc_k = p_struct.(participant).(str_muscle).k;
    psc_rc_rmsel = p_struct.(participant).(str_muscle).rmsel_specific(strcmpi(cell_scloc_p, str_scloc));
    psc_rc_c_support = p_struct.(participant).(str_muscle).c_support(strcmpi(cell_scloc_p, str_scloc));
    psc_rc_stim_std = p_struct.(participant).(str_muscle).stim_std(strcmpi(cell_scloc_p, str_scloc));
    psc_rc_stim_pct = p_struct.(participant).(str_muscle).stim_pct(strcmpi(cell_scloc_p, str_scloc));
    psc_rc_max_amp = p_struct.(participant).(str_muscle).max_amp(strcmpi(cell_scloc_p, str_scloc));
else
    psc_rc_o = nan;
    psc_rc_slope = nan;
    psc_rc_th = nan;
    psc_rc_roof = nan;
    psc_rc_k = nan;
    psc_rc_rmsel = nan;
    psc_rc_c_support = nan;
    psc_rc_stim_std = nan;
    psc_rc_stim_pct = nan;
    psc_rc_max_amp = nan;
end
end