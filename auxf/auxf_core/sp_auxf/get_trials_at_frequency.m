function [case_xhz] = get_trials_at_frequency(info, target_frequency)
case_xhz = all([seconds(diff(info.datetime)) > (0.9 * (1/target_frequency)), seconds(diff(info.datetime)) < (1.1 * (1/target_frequency))], 2);
case_xhz = [case_xhz; false];
end