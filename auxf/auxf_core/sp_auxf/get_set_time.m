function [time_from, time_to] = get_set_time(s_multipulse_splits, info, str_set, participant)
case_sub = strcmpi(info.participant, participant);
str_dos = datestr((min(info.datetime(case_sub))), 'yyyy-mm-dd');
time_from = s_multipulse_splits.(participant).(str_set).time_from;
time_to = s_multipulse_splits.(participant).(str_set).time_to;
time_from = datetime([str_dos, ' ', time_from], 'InputFormat','yyyy-MM-dd HH:mm:ss');
time_to = datetime([str_dos, ' ', time_to], 'InputFormat','yyyy-MM-dd HH:mm:ss');
end