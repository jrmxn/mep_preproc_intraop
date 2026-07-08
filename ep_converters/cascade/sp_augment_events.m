function  vec_participant = sp_augment_events(d_data_coded, varargin)
% AUGMENT THE RECORD WITH EVENTS THAT HAVE BEEN HAND TWEAKED
% AND
% AUGMENT THE RECORD WITH STIMULATION CURRENTS
d.operation = 'augment';  % or write
d.augment_events = true;
d.visualise_records = false;
d.subject_filter = {};
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%
% if not(isempty(v.d_data_stim_amp_ocr))
v.augment_stimamp = true;
% else
%     warning('STIMAMP DATA IS NOT BEING EXTRACTED FROM OCR PROCESSING!');
%
%     v.augment_stimamp = false;
% end
%%

% d_data_stim_amp_ocr = fullfile(getenvc('D_DATA_SECURE'), 'data_cascade_event_ss');
% f_out = fullfile(d_data_coded, str_sub, 'ephys', 'data_deid_mat', str_sub);
% d_stack_emg = fullfile(d_data_coded, str_sub, 'ephys', 'data_stacked_emg');
% data_stacked_emg_without_amplitude = fullfile(d_data_coded, str_sub, 'ephys', 'data_stacked_emg_without_amplitude');
% d_stack_dwave = fullfile(d_data_coded, str_sub, 'ephys', 'data_stacked_dwave');

cell_sub = dir(d_data_coded);
cell_sub = cell_sub([cell_sub.isdir]);
cell_sub(strcmpi({cell_sub.name}, '.')) = [];
cell_sub(strcmpi({cell_sub.name}, '..')) = [];
cell_sub = {cell_sub.name};
cell_sub = cell_sub(~strcmpi(cell_sub, 'auxf'));
% f_data_mat = f_data_mat(contains({f_data_mat.name}, '.mat'));
% f_data_mat = f_data_mat(not([f_data_mat.isdir]));
% cell_sub = {f_data_mat.name};

if not(isempty(v.subject_filter))
    cell_sub = cell_sub(contains(cell_sub, v.subject_filter));
end

if strcmpi(v.operation, 'write')
    if v.overwrite
        warning('overwrite flag does nothing in write mode!');
    end
    for ix_cell_sub = 1:length(cell_sub)
        str_sub = cell_sub{ix_cell_sub};
        
        d_sub_ephys = fullfile(d_data_coded, str_sub, 'ephys');
        [d_sub_device, str_device, skip] = get_device(d_sub_ephys);
        
        f_records = fullfile(d_sub_ephys, str_device, 'data_deid_mat', [str_sub, '.mat']);
        if skip || not(exist(f_records, 'file')==2)
            fprintf('data_deid_mat missing for %s - skipping\n', str_sub);
            continue;
        end
        tempX = load(f_records);
        record = tempX.record;
        
        manual_override = false;  % this should always be false
        if manual_override
            warning('MANUAL OVERRIDE IS ON! SHOULD BE OFF!!!');
            f_events = strrep(f_records, '.mat', '_events_augment.xlsx');
        else
            f_events = strrep(f_records, '.mat', sprintf('_events_%s.xlsx', v.operation));
        end
        %%
        ev_table = struct;
        ix_count = 1;
        for ix_record = 1:length(record)
            entry_type = record(ix_record).entry_type;
            if strcmpi(entry_type, 'event')
                current_event = record(ix_record).message;
                
                [sc_hor, sc_ver] = convert_event(current_event);
                
                % 2020-10-07 new parsing with faster logging format:
                % i.e. C7M, C8L etc.
                curr_ev_parsed = regexp(upper(current_event), '([C,T]\d)([A-Z])', 'tokens');
                if and(strcmpi(sc_hor, '-'), strcmpi(sc_ver, '-'))
                    if not(isempty(curr_ev_parsed))
                        curr_ev_parsed = curr_ev_parsed{1};
                        sc_ver = curr_ev_parsed{1};
                        sc_hor = curr_ev_parsed{2};
                    end
                end
                
                fprintf('%04d\t', ix_record);
                cprintf('*Red', '%s ', datestr(record(ix_record).datetime, 'HH:MM:SS:FFF'));
                fprintf('%s ', entry_type);
                fprintf('%s ', record(ix_record).ep_type);
                fprintf('%s ', record(ix_record).message);
                fprintf('\n');
                ev_table(ix_count).ix_record = ix_record;
                ev_table(ix_count).datetime = record(ix_record).datetime;
                ev_table(ix_count).message = record(ix_record).message;
                ev_table(ix_count).ix_event = record(ix_record).ix_event;
                
                ev_table(ix_count).stim_sc_amplitude = NaN;
                ev_table(ix_count).stim_sc_extra = missing;
                ev_table(ix_count).stim_sc_count = NaN;
                ev_table(ix_count).stim_sc_vertical = sc_ver;
                ev_table(ix_count).stim_sc_horizontal = sc_hor;
                ev_table(ix_count).stim_sc_electrode = missing;
                ev_table(ix_count).stim_sc_electrode_configuration = missing;
                ev_table(ix_count).stim_sc_misc = missing;
                
                ev_table(ix_count).stim_sc_flag = not(strcmpi(sc_ver, '-')|strcmpi(sc_hor, '-'));
                
                %                 ev_table(ix_count).decompression_flag = false;
                
                ev_table(ix_count).message_length = length(record(ix_record).message);
                
                ix_count = ix_count + 1;
            end
        end
        ev_table = struct2table(ev_table);
        if isfield(ev_table, 'datetime')
            ev_table.datetime_real = ev_table.datetime;  % added 2020-05-16
        end
        writetable(ev_table, f_events);
    end
    f_out = [];
elseif strcmpi(v.operation, 'augment')
    for ix_cell_sub = 1:length(cell_sub)
        assert(v.augment_events, 'Events must get augmented');
        
        str_sub = cell_sub{ix_cell_sub};
        
        d_sub_ephys = fullfile(d_data_coded, str_sub, 'ephys');
        
        [d_sub_device, str_device, skip] = get_device(d_sub_ephys);
        if skip
            continue;
        end
        
        d_data_mat_aug = fullfile(d_sub_ephys, str_device, 'data_deid_mat_aug');
        d_data_stim_amp_ocr = fullfile(d_sub_ephys, str_device, 'data_cascade_event_ss');
        
        f_out = fullfile(d_data_mat_aug, sprintf('%s', str_sub));
        
        do_augment = generate_check_mat(f_out, v.overwrite);
        if do_augment
            fprintf('ix %02d: %s\n', ix_cell_sub, cell_sub{ix_cell_sub})
            %             f_records = fullfile(d_data_mat, cell_sub{ix_cell_sub});
            f_records = fullfile(d_sub_ephys, str_device, 'data_deid_mat', [str_sub, '.mat']);
            if skip || not(exist(f_records, 'file')==2)
                fprintf('data_deid_mat missing for %s - skipping\n', str_sub);
                continue;
            end
            tempX = load(f_records);
            record = tempX.record;
            v_local = tempX.v;
            is_iomax = strcmpi(v_local.str_device, 'cadwell-iomax');
            if isfield(v_local, 'stim_delay')
                v.stim_delay = v_local.stim_delay;
            else
                v.stim_delay = 0;
            end
            %             f_events = strrep(f_records, '.mat', sprintf('_events_%s.xlsx', v.operation));
            f_events = strrep(f_records, '.mat', sprintf('_events_%s.xlsx', v.operation));
            assert(exist(f_events, 'file') == 2, 'Events file for reading needs to be manually created!');
            T = readtable(f_events);
            if isempty(T)
                % if there isn't an events table just write out the records
                % as is
                for ix_record = 1:length(record)
                    record(ix_record).stim_sc.flag = false;
                    record(ix_record).associated_event = nan;
                    
                    % still map the d-wave amplitude...
                    ep_type_local = record(ix_record).ep_type;
                    if strcmpi(ep_type_local, 'd-wave')
                        record(ix_record).stim_sc.amplitude = record(ix_record).amplitude_from_stack;
                    end
                    
                end
                save_local(f_out, record, v_local);
                continue;
            end
            
            %%
            % Apply information from events to subsequent records -
            % changed this to work with time rather than record index
            % 2020-05-16
            stim_sc.flag = false;
            for ix_T_aug = 1:height(T)
                dt_now = T.datetime(ix_T_aug);
                stim_sc_initiated = false;
                for ix_record = 1:length(record)
                    if record(ix_record).datetime>=dt_now
                        if not(stim_sc_initiated)
                            stim_sc.flag = T.stim_sc_flag(ix_T_aug);
                            stim_sc.amplitude = T.stim_sc_amplitude(ix_T_aug);
                            stim_sc.count = T.stim_sc_count(ix_T_aug);
                            stim_sc.extra = T.stim_sc_extra{ix_T_aug};
                            stim_sc.horizontal = T.stim_sc_horizontal{ix_T_aug};
                            stim_sc.vertical = T.stim_sc_vertical{ix_T_aug};
                            
                            default_electrode = "double-ball-tip-302431-000";
                            if any(strcmpi(T.Properties.VariableNames, 'stim_sc_electrode'))
                                stim_sc.electrode = string(T.stim_sc_electrode{ix_T_aug});
                                if isempty(stim_sc.electrode)
                                    stim_sc.electrode = default_electrode;
                                elseif ismissing(stim_sc.electrode)
                                    stim_sc.electrode = default_electrode;
                                end
                            else
                                stim_sc.electrode = default_electrode;
                            end
                            stim_sc.electrode_type = group_electrodes(stim_sc.electrode);
                            
                            default_electrode_configuration = "RC";
                            if any(strcmpi(T.Properties.VariableNames, 'stim_sc_electrode_configuration'))
                                stim_sc.electrode_configuration = string(T.stim_sc_electrode_configuration{ix_T_aug});
                                if isempty(stim_sc.electrode_configuration)
                                    stim_sc.electrode_configuration = default_electrode_configuration;
                                elseif ismissing(stim_sc.electrode_configuration)
                                    stim_sc.electrode_configuration = default_electrode_configuration;
                                end
                            else
                                stim_sc.electrode_configuration = default_electrode_configuration;
                            end
                            
                            default_misc = "";  % currently just using this to store HD flag since will migrate HD to new config
                            if any(strcmpi(T.Properties.VariableNames, 'stim_sc_misc'))
                                stim_sc.misc = T.stim_sc_misc{ix_T_aug};
                                if isempty(stim_sc.misc)
                                    stim_sc.misc = default_misc;
                                elseif ismissing(stim_sc.misc)
                                    stim_sc.misc = default_misc;
                                end
                            else
                                stim_sc.misc = default_misc;
                            end
                            
                            record(ix_record).stim_sc = stim_sc;
                            %                             record(ix_record).decompression_flag = T.decompression_flag(ix_T_aug);
                            record(ix_record).associated_event = T.ix_event(ix_T_aug);
                            stim_sc_initiated = true;
                        else
                            record(ix_record).associated_event = nan;
                            record(ix_record).stim_sc = stim_sc;
                        end
                    end
                end
            end
            
            %%
            % fill in amplitude from emg stack into the correct place...
            %             if not(
            if not(is_iomax)
                for ix_record = 1:length(record)
                    if strcmpi(record(ix_record).ep_type, 'd-Spinal Cord (SCS)')
                        record(ix_record).stim_sc.amplitude = record(ix_record).amplitude_from_stack;
                        record(ix_record).stim_sc.rep_rate = record(ix_record).rep_rate_from_stack;
                    end
                end
            end
            if v.augment_stimamp
                fprintf('Attaching stimamp from SS...\n');
                f_stimamp_augmented = fullfile(d_data_stim_amp_ocr, [str_sub, '_augmented.xlsx']);
                %                 assert(exist(f_stimamp_augmented, 'file') == 2, sprintf('%s is missing!', f_stimamp_augmented));
                if not(exist(f_stimamp_augmented, 'file') == 2)
                    warning('SKIPPING ATTATCHING SS STIM STRENGTH!!!');
                    for ix_record = 1:length(record)
                        record(ix_record).amplitude_from_ss = nan;
                    end
                else
                    T_ss = readtable(f_stimamp_augmented);
                    % now load stimulation currents
                    for ix_record = 1:length(record)
                        record(ix_record).amplitude_from_ss = nan;
                        if strcmpi(record(ix_record).ep_type, 'd-Spinal Cord (SCS)')
                            
                            [d, ix_min] = min(abs(record(ix_record).datetime - T_ss.datetime));
                            if d<=2
                                %                             record(ix_record).message_nearest_ss_event = T_ss.msg_full{ix_min};
                                %                             if not(isnan(T_ss(ix_min, :).sc_stim_amp))
                                % This should be written into sc_stim_amp
                                % but for now, write it into extra to
                                % debug...
                                %                                 es = record(ix_record).stim_sc.extra;
                                %                                 es = sprintf('%s, OCR:%0.1fmA', es, T_ss(ix_min, :).sc_stim_amp);
                                %                                 record(ix_record).stim_sc.extra = es;
                                record(ix_record).amplitude_from_ss = T_ss(ix_min, :).sc_stim_amp;
                                %                             end
                            else
                                warning('skipped match with a distance of %0.1fs...', d);
                            end
                        end
                    end
                end
                
                % convert annotation into accessible info
                % I think this should be in sp_cascade_edf2mat...  instead
                % of here.
                if is_iomax
                    reg_delay = '\+(\d+\.?\d*)\s.+';
                    reg_stim_amp_current = 'Intensity:\s(\d+\.?\d*)\s\/\s(\d+\.?\d*)\smA\s\((\d+\.?\d*\sV)\)';
                    reg_stim_amp_voltage = 'Intensity:\s(\d+\.?\d*)\s\/\s(\d+\.?\d*)\sV\s\((\d+\.?\d*\smA)\)';
                    reg_stim_pulse_count = 'Pulse Count:\s(\d+\.?\d*).*';
                    reg_stim_rep_rate = 'Rep\sRate\s\(Hz\):\s(\d+\.?\d*).*';
                    reg_stim_pulse_width = 'Pulse\sWidth\s\(us\):\s(\d+\.?\d*).+';
                    for ix_record = 1:length(record)
                        record(ix_record).amplitude_from_annotation = nan;
                        record(ix_record).rep_rate_from_annotation = nan;
                        tokens_stim_amp = [];
                        
                        if not(isempty(record(ix_record).annotation))
                            tokens_delay = regexp(record(ix_record).annotation, reg_delay, 'tokens');
                            tokens_stim_amp_current = regexp(record(ix_record).annotation, reg_stim_amp_current, 'tokens');
                            tokens_stim_amp_voltage = regexp(record(ix_record).annotation, reg_stim_amp_voltage, 'tokens');
                            tokens_stim_pulse_width = regexp(record(ix_record).annotation, reg_stim_pulse_width, 'tokens');
                            tokens_pulse_count = regexp(record(ix_record).annotation, reg_stim_pulse_count, 'tokens');
                            % pulse_sep could not be bothered
                            tokens_stim_rep_rate = regexp(record(ix_record).annotation, reg_stim_rep_rate, 'tokens');
                            if not(isempty(tokens_stim_amp_current))
                                tokens_stim_amp = tokens_stim_amp_current;
                            else
                                tokens_stim_amp = tokens_stim_amp_voltage;  % can be empty
                            end
                            
                            %                             if strcmpi(record(ix_record).ep_type, 'L MEP') || strcmpi(record(ix_record).ep_type, 'R MEP')
                            %                                 if not(isempty(tokens_stim_amp))
                            %                                     x = str2double(tokens_stim_amp{1}{1});
                            %                                     disp(x);
                            %                                     1;  % debugging block -
                            %                                 end
                            %                             end
                            
                        end
                        
                        if not(isempty(tokens_stim_amp))
                            delay_from_annotation = str2double(tokens_delay{1}{1});
                            amplitude_from_annotation = str2double(tokens_stim_amp{1}{1});
                            if isempty(tokens_stim_pulse_width)
                                pulse_width_from_annotation = nan;
                            else
                                pulse_width_from_annotation = str2double(tokens_stim_pulse_width{1}{1});
                            end
                            if isempty(tokens_stim_pulse_width)
                                pulse_count_from_annotation = nan;
                            else
                                pulse_count_from_annotation = str2double(tokens_pulse_count{1}{1});
                            end
                            % pulse_sep could not be bothered
                            rep_rate_from_annotation = str2double(tokens_stim_rep_rate{1}{1});
                            
                            annotation_parsed = struct;
                            annotation_parsed.pulse_delay = delay_from_annotation;
                            annotation_parsed.pulse_amplitude = amplitude_from_annotation;
                            annotation_parsed.pulse_width = pulse_width_from_annotation;
                            annotation_parsed.pulse_count = pulse_count_from_annotation;
                            annotation_parsed.pulse_sep = nan;
                            annotation_parsed.rep_rate = rep_rate_from_annotation;
                            
                            record(ix_record).annotation_parsed = annotation_parsed;
                        end
                    end
                else
                    for ix_record = 1:length(record)
                        str_match1 = '.+\+(\d+)\sStim:\s(.+)mA,\s(\d+).+s,\s(\d),\s(.+)ms,\s(.+)Hz';
                        str_match2 = '.+\+(\d+)\sStim:\s(.+)mA,\s(\d+).+s,\s(.+)Hz';  % first subject is missing count info
                        ep_type_local = record(ix_record).ep_type;
                        
                        if strcmpi(ep_type_local, 'd-Spinal Cord (SCS)')
                            cell_match1 = regexp(record(ix_record).annotation, str_match1, 'tokens');
                            if not(isempty(cell_match1)), cell_match1 = cell_match1{1};end
                            cell_match2 = regexp(record(ix_record).annotation, str_match2, 'tokens');
                            if not(isempty(cell_match2)), cell_match2 = cell_match2{1};end
                            if not(isempty(cell_match1))
                                cell_match = cell_match1;
                            else
                                cell_match = cell_match2;
                            end
                            
                            annotation_parsed = struct;  % added 2021-06-03 and untested
                            annotation_parsed.pulse_delay = str2double(cell_match{1});
                            
                            % this is where the stimamp should be... but bugs
                            % in cascade mean that it has to be extracted from
                            % multiple other sources (circus above).
                            annotation_parsed.pulse_amplitude = cell_match{2};
                            annotation_parsed.pulse_width = str2double(cell_match{3});  % us
                            
                            if length(cell_match)==6
                                annotation_parsed.pulse_count = str2double(cell_match{4});
                                annotation_parsed.pulse_sep = str2double(cell_match{5});
                            else
                                annotation_parsed.pulse_count = nan;  % the actual value for the one subject where this fails is 3
                                annotation_parsed.pulse_sep = nan;  % ms
                            end
                            
                            
                            annotation_parsed.rep_rate = str2double(cell_match{end}); % Hz
                            record(ix_record).annotation_parsed = annotation_parsed;
                        end
                    end
                end
                
                % deal with inconsitencies in data that come from multiple
                % methods of extraction for the count and delay (stim amp
                % has been dealt with already)
                for ix_record = 1:length(record)
                    ep_type_local = record(ix_record).ep_type;
                    if strcmpi(ep_type_local, 'd-Spinal Cord (SCS)')
                        % if we haven't extracted a nan from annotation
                        % then replace the count with that.
                        annotation_parsed = record(ix_record).annotation_parsed;
                        
                        % rare case that count does not exist (this can
                        % happen if a d-spinal ev_type is marked before the
                        % actual SCS experiment starts.
                        if is_iomax
                            record(ix_record).stim_sc.count = annotation_parsed.pulse_count;
                        else
                            % use the augmented count - it's usually wrong in
                            % the annotation!
                            if not(isfield(record(ix_record).stim_sc, 'count'))
                                record(ix_record).stim_sc.count = annotation_parsed.pulse_count;
                            end
                        end
                        
                        assert(record(ix_record).delay == annotation_parsed.pulse_delay, 'Delay from annot. does not match delay from other source.')
                        record(ix_record).stim_sc.delay = annotation_parsed.pulse_delay;
                        
                        record(ix_record).stim_sc.pulse_sep = annotation_parsed.pulse_sep;
                        record(ix_record).stim_sc.pulse_width = annotation_parsed.pulse_width;
                        record(ix_record).stim_sc.rep_rate = annotation_parsed.rep_rate;
                        
                        if is_iomax
                            record(ix_record).stim_sc.amplitude = annotation_parsed.pulse_amplitude;
                        end
                        
                        % keep the rep rate from the EMG stack - this one
                        % from the annotation is just plain wrong:
                        %                         record(ix_record).stim_sc.rep_rate = annotation_parsed.rep_rate;
                    elseif strcmpi(ep_type_local, 'd-wave')
                        record(ix_record).stim_sc.amplitude = record(ix_record).amplitude_from_stack;
                    elseif strcmpi(ep_type_local, 'L MEP') || strcmpi(ep_type_local, 'R MEP')
                        if is_iomax
                            annotation_parsed = record(ix_record).annotation_parsed;
                            record(ix_record).stim_sc.count = annotation_parsed.pulse_count;
                            record(ix_record).stim_sc.delay = annotation_parsed.pulse_delay;
                            record(ix_record).stim_sc.pulse_sep = annotation_parsed.pulse_sep;
                            record(ix_record).stim_sc.pulse_width = annotation_parsed.pulse_width;
                            record(ix_record).stim_sc.rep_rate = annotation_parsed.rep_rate;
                            record(ix_record).stim_sc.amplitude = annotation_parsed.pulse_amplitude;
                        else
                            % the stim-amp annotation is broken for classic
                        end
                    end
                end
                
                % to avoid more confusion in record, tidy things up
                rm_field = {'annotation_parsed','amplitude_from_stack', ...
                    'amplitude_from_ss', 'Author', 'Timestamp', ...
                    'annotation', 'delay'};
                for ix_rm_field = 1:length(rm_field)
                    if isfield(record, rm_field{ix_rm_field})
                        record = rmfield(record, rm_field{ix_rm_field});
                    end
                end
                
                f_corrupted = strrep(f_records, '.mat', sprintf('_corrupted_%s.txt', v.operation));
                if exist(f_corrupted, 'file')==2
                    T_corrupted = readtable(f_corrupted, 'Delimiter', '\t');
                    case_corrupted = false(1, length(record));
                    for ix_row = 1:height(T_corrupted)
                        case_corrupted(T_corrupted.corrupted_from(ix_row):T_corrupted.corrupted_to(ix_row)) = true;
                    end
                    for ix_record = 1:length(record)
                        if case_corrupted(ix_record)
                            record(ix_record).stim_sc.stim_corrupted = true;
                        else
                            record(ix_record).stim_sc.stim_corrupted = false;
                        end
                    end
                else
                    fprintf('No list of corrupted records found for %s\n', str_sub);
                    fprintf('See comments in code for how to generate.\n');
                    for ix_record = 1:length(record)
                        record(ix_record).stim_sc.stim_corrupted = false;
                    end
                    % if there are corrupted entries, they can be marked like this.
                    % n.b. you have to re-run this code once they are
                    % written to file:
                    if false
                        M = [...
                            [266, 352]; ...
                            [364, 373]; ...
                            [384, 393]; ...
                            [404, 417]; ...
                            [428, 445]; ...
                            ];
                        T1 = table(M(:, 1));T1.Properties.VariableNames = {'corrupted_from'};
                        T2 = table(M(:, 2));T2.Properties.VariableNames = {'corrupted_to'};
                        T_write = [T1, T2];
                        writetable(T_write, f_corrupted, 'Delimiter', '\t', 'WriteRowNames', true);
                    end
                end
                
                %% check that we have 16 channels only - fix if not
                % based on the fact that extra bogus channels have ==
                % physical min and max
                for ix_record = 1:length(record)
                    ep_type_local = record(ix_record).ep_type;
                    if strcmpi(ep_type_local, 'd-Spinal Cord (SCS)')
                        case_rm = record(ix_record).physicalMax==record(ix_record).physicalMin;
                        fn_record = fieldnames(record(ix_record));
                        for ix_fn_record = 1:length(fn_record)
                            fn = fn_record{ix_fn_record};
                            if size(record(ix_record).(fn), 1) == length(case_rm)
                                record(ix_record).(fn)(case_rm, :) = [];
                            elseif size(record(ix_record).(fn), 2) == length(case_rm)
                                record(ix_record).(fn)(:, case_rm) = [];
                            end
                        end
                    end
                end
                
                %%
                if v.visualise_records
                    % use to investigate raw data and find corrupted
                    % records (which can be written to a file as explained
                    % above)
                    Fstop = 0.20;  % Stopband Frequency
                    Fpass = 0.25;  % Passband Frequency
                    Astop = 200;   % Stopband Attenuation (dB)
                    Apass = 0.01;   % Passband Ripple (dB)
                    h = fdesign.highpass('fst,fp,ast,ap', Fstop, Fpass, Astop, Apass);
                    Hd = design(h, 'cheby1', ...
                        'MatchExactly', 'passband', ...
                        'SOSScaleNorm', 'Linf');
                    for ix_record = 1:length(record)
                        ep_type_local = record(ix_record).ep_type;
                        if strcmpi(ep_type_local, 'd-Spinal Cord (SCS)')
                            
                            clf;hold on;
                            y1 = record(ix_record).data(1, :);
                            yy1 = abs(fliplr(filter(Hd, fliplr(filter(Hd, y1)))));
                            yy1 = smooth(yy1, 5);
                            
                            pulse_sep = record(ix_record).stim_sc.pulse_sep;
                            count = record(ix_record).stim_sc.count;
                            stim_corrupted = record(ix_record).stim_sc.stim_corrupted;
                            subplot(2, 1, 1);cla;hold on;
                            plot(y1./max(y1), 'k');
                            title(sprintf('ix: %d, %0.1fms n:%d, corrupted: %d', ix_record, pulse_sep, count, stim_corrupted));
                            
                            subplot(2, 1, 2);cla;hold on;
                            plot(yy1./max(yy1), 'k');
                            title(sprintf('%s filtered', strrep(str_sub, '_', ' ')));
                            drawnow;
                            pause(1);
                            1;
                        end
                    end
                end
                % and save
                save_local(f_out, record, v_local);
            end
        end
    end
end
vec_participant = string(cell_sub);
end

function save_local(f_out, record, v_local)
% this is just to insulate v from v_local...
v = v_local;
save(f_out, 'record', 'v');
end
function [sc_hor, sc_ver] = convert_event(current_event)
% take a guess at the event content - to cut down on manual work...

current_event = lower(current_event);

str_midline = false;
str_midline = str_midline||contains(current_event, 'medial');
str_midline = str_midline||contains(current_event, 'mid');

str_lateral = contains(current_event, 'lat');

str_right_lateral = false;
str_right_lateral = str_right_lateral||contains(current_event, 'rt');
str_right_lateral = str_right_lateral||contains(current_event, 'right');
str_right_lateral = str_right_lateral&&str_lateral;
str_left_lateral = false;
str_left_lateral = str_left_lateral||contains(current_event, 'lt');
str_left_lateral = str_left_lateral||contains(current_event, 'left');
str_left_lateral = str_left_lateral&&str_lateral;

case_lateral = [str_left_lateral, str_midline, str_right_lateral];
if and(and(str_lateral, not(str_left_lateral)), and(str_lateral, not(str_right_lateral)))
    case_lateral([1, 3]) = true;
end

sc_hor = '-';
sc_ver = '-';
if any(case_lateral)
    if case_lateral(1)&&case_lateral(3)
        sc_hor = 'B'; % both lateral - should not happen
    elseif case_lateral(1)
        sc_hor = 'L';
    elseif case_lateral(3)
        sc_hor = 'R';
    elseif case_lateral(2)
        sc_hor = 'M';
    end
    
    current_event = strtrim(current_event);
    current_event(current_event==32) = [];
    sc_site = regexp(current_event, '.*c(\d).*', 'tokens');
    if not(isempty(sc_site))
        sc_site = str2double(sc_site{1}{1});
        if sc_site>8
            error('C is too high');
        end
        sc_ver = sprintf('C%d', sc_site);
    else
        sc_site = nan;
        sc_ver = '';
    end
    %                 disp(case_lateral);
    %                 disp(sc_site);
end
end