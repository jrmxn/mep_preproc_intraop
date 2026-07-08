function sp_cascade_edf2mat(d_data_noncoded, d_data_coded, varargin)
d.ts_scaling = 1e-6;  % this is actually a constant
d.split_records = true;
% d.do_deid = true;
d.merge_json = true;
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);

%%
cell_sub = dir(d_data_noncoded);
cell_sub = cell_sub([cell_sub.isdir]);
cell_sub(strcmpi({cell_sub.name}, '.')) = [];
cell_sub(strcmpi({cell_sub.name}, '..')) = [];
cell_sub = {cell_sub.name};
cell_sub = cell_sub(~strcmpi(cell_sub, 'auxf'));

%%
if isempty(cell_sub)
    fprintf('Raw data not present - skipping.\n')
    fprintf('Was looking here:\n%s\n', d_data_noncoded);
    if v.overwrite
        error('But overwrite flag is on!');
    end
end
%%
str_d_spinal = 'd-Spinal Cord (SCS)';
%%
for ix_cell_sub = 1:length(cell_sub)
    
    str_sub = cell_sub{ix_cell_sub};
    
    d_sub_ephys = fullfile(d_data_noncoded, str_sub, 'ephys');
    [d_sub_device, str_device, skip] = get_device(d_sub_ephys);
    check_export_type_edf = length(glob(fullfile(d_sub_device, '*.edf')))>1;

    if skip || not(check_export_type_edf)
        continue;
    end
    v.str_device = str_device;
    
    %     if v.do_deid
    %         str_sub = sp_deidentify_string(str_sub);
    %     end
    %     f_out = fullfile(d_data_mat, sprintf('%s', str_sub));
    f_out = fullfile(d_data_coded, str_sub, 'ephys', str_device, 'data_deid_mat', str_sub);
    d_stack_emg = fullfile(d_data_coded, str_sub, 'ephys', str_device, 'data_stacked_emg');
    data_stacked_emg_without_amplitude = fullfile(d_data_coded, str_sub, 'ephys', str_device, 'data_stacked_emg_without_amplitude');
    d_stack_dwave = fullfile(d_data_coded, str_sub, 'ephys', str_device, 'data_stacked_dwave');
    
    do_convert = generate_check_mat(f_out, v.overwrite);
    if do_convert
        fprintf('Processing %s\n', str_sub);
        
        f_json_sub = glob(fullfile(d_sub_device, '**.json'));
        
        %         if exist(fullfile(d_sub, 'iomax'), 'file') == 2
        %             v.is_iomax = true;
        %             str_device = 'cadwell-iomax';
        %         elseif exist(fullfile(d_sub, 'cascade'), 'file') == 2
        %             v.is_iomax = false;
        %             str_device = 'cadwell-pro/elite';
        %         else
        %             warning('Uknown if pro/elite or iomax - assuming it is iomax!!!');
        %             v.is_iomax = true;
        %             str_device = 'cadwell-iomax';
        %         end
        
        f_stim_delay = 'stim_delay.csv';
        if exist(fullfile(d_sub_device, f_stim_delay), 'file') == 2
            stim_delay = readtable(fullfile(d_sub_device, f_stim_delay));
            v.stim_delay = stim_delay.delay_ms;
        else
            v.stim_delay = 0;
        end
        
        if length(f_json_sub)>1
            error('Only one json file please! %s\n', f_json_sub{end})
        elseif length(f_json_sub)==0
            warning('MISSING JSON FILE for %s\n', str_sub);
            v.merge_json = false;
            fprintf('Continue with care!!!\n');
            jaf = glob(fullfile(d_sub_device, '**.edf'));
            for ix_edf = 1:length(jaf)
                [~, jaf{ix_edf}, ext]= fileparts(jaf{ix_edf});
                jaf{ix_edf} = sprintf('%s%s', jaf{ix_edf}, ext);
            end
            
        else
            json_sub = jsondecode(fileread(f_json_sub{1}));
            jaf = json_sub.AssociatedFiles;
        end
        
        [~, ix_order_jaf] = sort(lower(jaf));
        jaf = jaf(ix_order_jaf);
        cell_sub_edf = cellfun(@(x) fullfile(d_sub_device, x), jaf, 'UniformOutput', false);
        record_core = cell(size(cell_sub_edf));
        
        cell_ep_type = cell(1, length(cell_sub_edf));
        for ix_cell_sub_edf = 1:length(cell_sub_edf)
            [~, ep_type, ~] = fileparts(cell_sub_edf{ix_cell_sub_edf});
            cell_ep_type{1, ix_cell_sub_edf} = ep_type;
            try
                [record_core{ix_cell_sub_edf}, record_data] = edfread_cascade(cell_sub_edf{ix_cell_sub_edf});
                record_core{ix_cell_sub_edf}.data = record_data;
                record_core{ix_cell_sub_edf}.ep_type = ep_type;
                record_core{ix_cell_sub_edf}.entry_type = 'record';
                record_core{ix_cell_sub_edf}.str_device = str_device;
                record_core{ix_cell_sub_edf}.ix_record = ix_cell_sub_edf;
            catch
                warning('Failed to load CASCADE EDF file:\n%s\n', cell_sub_edf{ix_cell_sub_edf});
            end
            %             end
        end
        record_core(cellfun(@isempty, record_core)) = []; % if try-catch triggered
        
        %%
        t_start = min(arrayfun(@(ix) min(record_core{ix}.datetime), 1:length(record_core), 'UniformOutput', true));
        t_end = max(arrayfun(@(ix) max(record_core{ix}.datetime), 1:length(record_core), 'UniformOutput', true));
        fprintf('---X: %s\n', t_end - t_start);
        %%
        clear cell_sub_edf;  % keep this.
        ep_type = str_d_spinal;
        if not(any(strcmpi(cell_ep_type, ep_type)))
            %             d_stacked_emg = strrep(d_sub, 'data_edf+D', 'data_stacked_emg_without_amplitude');
            d_stacked_emg = data_stacked_emg_without_amplitude;
            if (exist(d_stacked_emg, 'dir')==7)
                warning('EDF export of SCS failed... falling back on hack to load data from stacked EMG...');
                str_sub_template = cell_sub{contains(cell_sub, 'cornptio010')};
                p_template_edf = fullfile(d_data_noncoded, str_sub_template, 'ephys', str_device, [ep_type, '.edf']);
                
                ix_cell_sub_edf = length(record_core) + 1;
                record_core = [record_core; {}];
                
                [record_core{ix_cell_sub_edf}, record_data] = sp_edf_reader_faker(p_template_edf, d_stacked_emg);
                record_core{ix_cell_sub_edf}.data = record_data;
                record_core{ix_cell_sub_edf}.ep_type = ep_type;
                record_core{ix_cell_sub_edf}.entry_type = 'record';
                record_core{ix_cell_sub_edf}.str_device = str_device;
                record_core{ix_cell_sub_edf}.ix_record = ix_cell_sub_edf;
            end
        end
        %% split records
        if v.split_records
            init_rec_split = false;
            for ix_rec = 1:length(record_core)
                entry_type = record_core{ix_rec}.entry_type;
                if strcmpi(entry_type, 'record')
                    rec_temp = repmat(record_core{ix_rec}, record_core{ix_rec}.records, 1);
                    for ix_rec_temp = 1:record_core{ix_rec}.records
                        rec_temp_inst = rec_temp(ix_rec_temp);
                        
                        rec_temp_inst.data = record_core{ix_rec}.data{ix_rec_temp};
                        rec_temp_inst.annotation = record_core{ix_rec}.annotation{ix_rec_temp};
                        rec_temp_inst.datetime = record_core{ix_rec}.datetime(ix_rec_temp);
                        rec_temp_inst.delay = record_core{ix_rec}.delay(ix_rec_temp);
                        rec_temp_inst.bytes = nan;
                        rec_temp_inst.records = 1;
                        
                        rec_temp(ix_rec_temp) = rec_temp_inst;
                    end
                    if init_rec_split
                        rec_split = cat(1, rec_split, rec_temp);
                    else
                        init_rec_split = true;
                        rec_split = rec_temp;
                    end
                end
            end
            record_core = rec_split;
        else
            record_core = cell2mat(record_core);
            
        end
        %%
        [~, ix_sort_rec] = sort([record_core.datetime]);
        record_core = record_core(ix_sort_rec);
        %%
        if v.merge_json
            % add fields to json
            for ix_ev = 1:length(json_sub.Events)
                t = datetime(json_sub.Events(ix_ev).Timestamp * v.ts_scaling, 'ConvertFrom', 'posixtime');
                json_sub.Events(ix_ev).datetime = t;
                json_sub.Events(ix_ev).entry_type = 'event';
                json_sub.Events(ix_ev).ix_event = ix_ev;
                json_sub.Events(ix_ev).str_device = str_device;
                msg = json_sub.Events(ix_ev).Message;
                msg(msg == 20) = 32; % convert dec 20 (HEX 14) to dec 32 (HEX 20)
                json_sub.Events(ix_ev).message = native2unicode(msg);
            end
            json_sub.Events = rmfield(json_sub.Events, 'Message');
            
            % add fields to json
            for ix_modes = 1:length(json_sub.Modes)
                cell_chan = json_sub.Modes{ix_modes}.Channels;
                if isfield(json_sub.Modes{ix_modes}, 'Annotations')
                    annot = json_sub.Modes{ix_modes}.Annotations;
                    for ix_annot = 1:length(annot)
                        t = datetime(annot(ix_annot).Timestamp * v.ts_scaling, 'ConvertFrom', 'posixtime');
                        json_sub.Modes{ix_modes}.Annotations(ix_annot).datetime = t;
                        json_sub.Modes{ix_modes}.Annotations(ix_annot).label = json_sub.Modes{ix_modes}.Channels;
                        json_sub.Modes{ix_modes}.Annotations(ix_annot).ep_type = json_sub.Modes{ix_modes}.Name;
                        json_sub.Modes{ix_modes}.Annotations(ix_annot).entry_type = 'annotation';
                        json_sub.Modes{ix_modes}.Annotations(ix_annot).str_device = str_device;
                    end
                end
            end
            
            record = record_core(1);
            for ix = 2:length(record_core)
                record = [record; record_core(ix)];
            end
            ev = json_sub.Events;
            
            record = insert_fields(record, ev);
            ev = insert_fields(ev, record);
            record = [record; ev ];
        else
            record = record_core;
        end
        [~, ix_sort_time] = sort([record.datetime]);
        record = record(ix_sort_time);
        
        %% merge from stacked emg (i.e. manually exported from cadwell software
        % because their normal export completely messes up with
        % stimulation amplitudes
        if exist(d_stack_emg, 'dir') == 7
            cell_d_stack = dir(d_stack_emg);
            cell_d_stack = cell_d_stack(not([cell_d_stack.isdir]));
            if isempty(cell_d_stack)
                warning('We wanted stimamp, but there is no stacked emg from which to get it... continuing without');
                for ix_record = 1:length(record)
                    record(ix_record).amplitude_from_stack = nan;
                end
            else
                % the dataset exported as ASCII tables from cascade is
                % a complete mess. So sometimes you need to save the
                % csv back as an xlsx (e.g. after correcting the column
                % names). In that case we prioritise loading the xlsx.
                if any(contains({cell_d_stack.name}, 'xlsx'))
                    ix_cell_d_stack = find(contains({cell_d_stack.name}, 'xlsx'));
                    ix_cell_d_stack = ix_cell_d_stack(1);
                    f_d_stack = cell_d_stack(ix_cell_d_stack).name;
                else
                    f_d_stack = cell_d_stack(1).name;  % Each file contains stim settings so... just get the first one
                end
                
                %                     Pre- 2020-08-19
                %                     T_emg_cell = readtable(fullfile(d_stack, f_d_stack));
                %2020-08-19 matlab must have modified readtable because
                %it is interpreting all stimamp cells as nans...
                opts = detectImportOptions(fullfile(d_stack_emg, f_d_stack));
                opts.PreserveVariableNames = false;
                opts = setvartype(opts,'char');
                T_emg_cell = readtable(fullfile(d_stack_emg, f_d_stack), ...
                    opts);
                %                                         T_emg_cell = readtable(fullfile(d_stack, f_d_stack), ...
                %                     'Format', 'auto', 'PreserveVariableNames', true);
                
                col_name = T_emg_cell{:, 1};
                
                T_emg = table;
                for ix_col = 1:length(col_name)
                    try
                        c = T_emg_cell{ix_col, 2:end};
                    catch
                        error('manually make sure that the entries for stimamp will be read as strings');
                    end
                    [c, u] = convert_to_usable_column(c, col_name{ix_col});
                    T_emg.(col_name{ix_col}) = c;
                    T_emg.Properties.VariableUnits{ix_col} = u;
                end
                T_emg.datetime = T_emg.Time;
                for ix_record = 1:length(record)
                    record(ix_record).amplitude_from_stack = nan;
                    record(ix_record).rep_rate_from_stack = nan;
                    if strcmpi(record(ix_record).ep_type, str_d_spinal)
                        
                        [d, ix_min] = min(abs(record(ix_record).datetime - T_emg.datetime));
                        if seconds(d)<=2 %
                            record(ix_record).amplitude_from_stack = T_emg.Stimamp(ix_min);
                            record(ix_record).rep_rate_from_stack = T_emg.("Rep Rate (Hz)")(ix_min);
                        else
                            error('skipped match with a distance of %0.1fs...', d);
                        end
                    end
                end
            end
        elseif strcmpi(v.str_device, 'cadwell-iomax')
            % well... we don't need stacked emg here...
            1;
        else
            warning('Folder does not exist for stacked emg - from which we get stimamp');
        end
        %% merge from stacked dwave (i.e. manually exported from cadwell software
        % because their normal export completely messes up with
        % stimulation amplitudes
        f_rc_decode = 'rc.json';
        
        assert(exist(d_stack_dwave, 'dir') == 7,  'Folder does not exist for stacked d-waves - check other folders for how to configure.');

        rc_decode = loadjson(fullfile(d_stack_dwave, f_rc_decode));
        disp(rc_decode);
        %
        T_dwave = [];
        cell_rc = {'rostral', 'caudal'};
        for ix_cell_rc = 1:length(cell_rc)
            rc = rc_decode.(cell_rc{ix_cell_rc});
            if not(strcmpi(rc, 'none'))
                f_in = fullfile(d_stack_dwave, rc);
                opts = detectImportOptions(f_in);
                opts.PreserveVariableNames = false;
                opts = setvartype(opts,'char');
                T_dwave_cell = readtable(f_in, ...
                    opts);
                col_names = table2cell(T_dwave_cell(:, 1)).';
                T_dwave_cell(:, 1) = [];
                T_dwave_cell = table2cell(T_dwave_cell).';
                T_dwave_cell(all(cellfun(@isempty, T_dwave_cell), 2), :) = [];
                T_dwave = cell2table(T_dwave_cell);
                T_dwave.Properties.VariableNames = col_names;
            end
        end
        
        if not(isempty(T_dwave))
            % the loop above cycles over rostral and caudal, but here we just
            % take whichever of the two loop iterations worked. Since stimamp
            % and time should be the same for both.
            case_col_stim = contains(col_names, 'Stim');
            str_col_stim = col_names{find(case_col_stim, 1, 'first')};
            T_dwave.datetime = datetime(T_dwave.Time, 'InputFormat', 'yyyyMMddHHmmss');
            
            ix_d_wave = 0;
            for ix_record = 1:length(record)
                if strcmpi(record(ix_record).ep_type, 'd-wave')
                    ix_d_wave = ix_d_wave + 1;
                    
                    str_stimamp_local = T_dwave.(str_col_stim){ix_d_wave};
                    record(ix_record).annotation = strrep(record(ix_record).annotation, '0V/0mA', str_stimamp_local);
                    stimamp_local = str2double(extractBefore(str_stimamp_local, 'V'));
                    record(ix_record).amplitude_from_stack = stimamp_local;
                end
            end
            assert(height(T_dwave)==ix_d_wave, ...
                "For augmenting bad cadwell export, I merge two data streams ", ...
                "but the timestamps don't even match.\n", ...
                "So this is a check based on the total number of d-wave recordings. \n", ...
                "If this throws an error - the two streams failed to match");
        end
        % TODO: THE LABELS STILL NEED FIXING
        % some subjects have EEG labels instead of DCaudal and DRostral
        % As far as I can tell, they have two eeg labels, even when they only have
        % a single caudal recording - so not sure how to fix that immediately.
        %%
        datetime_laminectomy_mid = datetime(rc_decode.laminectomy_mid,'Format','yyyy-MM-dd''T''HH:mm:ss''Z''');
        for ix_record = 1:length(record)
            if record(ix_record).datetime>datetime_laminectomy_mid
                record(ix_record).decompression_flag = true;
            else
                record(ix_record).decompression_flag = false;
            end
        end
        %% some final tidying
        for ix_record = 1:length(record)
            if isfield(record(ix_record), 'ix_event')
                if isempty(record(ix_record).ix_event)
                    record(ix_record).ix_event = nan;
                end
            else
                record(ix_record).ix_event = nan;
            end
        end
        %% some new re-org if iomax
        %         if v.is_iomax
        %             reg_stim_amp_current = 'Intensity:\s(\d+\.?\d*)\s\/\s(\d+\.?\d*)\smA\s\((\d+\.?\d*\sV)\)';
        %             reg_stim_amp_voltage = 'Intensity:\s(\d+\.?\d*)\s\/\s(\d+\.?\d*)\sV\s\((\d+\.?\d*\smA)\)';
        %             reg_stim_pulse_count = 'Pulse Count:\s(\d+\.?\d*).*';
        %             reg_stim_rep_rate = 'Rep\sRate\s\(Hz\):\s(\d+\.?\d*).*';
        %
        %             for ix_record = 1:length(record)
        %                 record(ix_record).amplitude_from_annotation = nan;
        %                 record(ix_record).rep_rate_from_annotation = nan;
        %                 tokens_stim_amp = [];
        %
        %                 % v. similar code is in sp_augment_events... not sure why
        %                 % the duplication...
        %                 if not(isempty(record(ix_record).annotation))
        %                     tokens_stim_amp_current = regexp(record(ix_record).annotation, reg_stim_amp_current, 'tokens');
        %                     tokens_stim_amp_voltage = regexp(record(ix_record).annotation, reg_stim_amp_voltage, 'tokens');
        %                     tokens_pulse_count = regexp(record(ix_record).annotation, reg_stim_pulse_count, 'tokens');
        %                     tokens_stim_rep_rate = regexp(record(ix_record).annotation, reg_stim_rep_rate, 'tokens');
        %                     if not(isempty(tokens_stim_amp_current))
        %                         tokens_stim_amp = tokens_stim_amp_current;
        %                     else
        %                         tokens_stim_amp = tokens_stim_amp_voltage;  % can be empty
        %                     end
        %                 end
        %
        %                 if not(isempty(tokens_stim_amp))
        %                     try
        %                     pulse_count_from_annotation = str2double(tokens_pulse_count{1}{1});
        %                     catch
        %                         keyboard;
        %                     end
        %                     rep_rate_from_annotation = str2double(tokens_stim_rep_rate{1}{1});
        %                     amplitude_from_annotation = str2double(tokens_stim_amp{1}{1});
        %                     % think the second number is what we wanted (rather than what we did)
        %                     % third number - voltage could tell us if we saturate
        %
        %                     record(ix_record).amplitude_from_annotation = amplitude_from_annotation;
        %                     record(ix_record).rep_rate_from_annotation = rep_rate_from_annotation;
        %
        %                     record(ix_record).pulse_count_from_annotation = pulse_count_from_annotation;
        %                 end
        %             end
        %         end
        
        %%
        for ix_record = 1:length(record)
            record(ix_record).patientID = [];
            record(ix_record).subject = str_sub;
        end
        save(f_out, 'record', 'v');
    else
        fprintf('.');
    end
end
fprintf('\n');
end
%%
function record2 = insert_fields(record2, ev)
f = fieldnames(ev);
for i = 1:length(f)
    if not(any(strcmpi(fieldnames(record2), f{i})))
        if isa(ev(1).(f{i}), 'double')
            record2(1).(f{i}) = nan;
        elseif isa(ev(1).(f{i}), 'char')
            record2(1).(f{i}) = '';
        else
            record2(1).(f{i}) = [];
        end
    end
end
end

function [c, u] = convert_to_usable_column(c, col_name_s)
c = c.';
u = '';
assert_th = 0.8;
if strcmpi(col_name_s, 'Name')
    
elseif strcmpi(col_name_s, 'Int (mA)')||strcmpi(col_name_s, 'Stimamp')
    % this should be stim amp. If == Stimamp it was made manually
    u = 'mA';
    assert(mean(contains(c, u))>assert_th, 'This is not a stim amp column...');
    c_o = c;
    c = nan(size(c));
    for ix_c = 1:length(c)
        if contains(c_o{ix_c}, u)
            c_temp = extractBetween(c_o{ix_c}, '/', u);
            c_temp = str2double(c_temp{1});
            c(ix_c) = c_temp;
        else
            c(ix_c) = nan;
        end
    end
elseif strcmpi(col_name_s, 'Time')
    c_o = c;
    c = NaT(size(c));
    for ix_c = 1:length(c)
        c_temp = c_o{ix_c};
        c(ix_c) = datetime(c_temp, 'InputFormat', 'yyyyMMddHHmmss');
    end
elseif strcmpi(col_name_s, 'Pulse Width (�s)')
    % this should be pulse width
    u = char([65533, 115]);
    
    assert(mean(contains(c, u))>assert_th, 'This is not correct column...');
    c_o = c;
    c = nan(size(c));
    for ix_c = 1:length(c)
        if contains(c_o{ix_c}, u)
            c_temp = extractBefore(c_o{ix_c}, u);
            c_temp = str2double(c_temp);
            c(ix_c) = c_temp;
        else
            c(ix_c) = nan;
        end
    end
    %         u = 'mu_s';
elseif strcmpi(col_name_s, 'Train Length')
    %this should be pulse count
    c_o = c;
    c = str2double(c);
    %     so if it is not an int make it a nan
    c(not(mod(c, 1)==0)) = nan;
    u = '';
elseif strcmpi(col_name_s, 'ISI (ms)')
    % this should be ... ? 2ms
    u = 'ms';
    try
        assert(mean(contains(c, u))>assert_th, 'This is not an expected column...');
    catch
        keyboard;
    end
    c_o = c;
    c = nan(size(c));
    for ix_c = 1:length(c)
        if contains(c_o{ix_c}, u)
            c_temp = extractBefore(c_o{ix_c}, u);
            c_temp = str2double(c_temp);
            c(ix_c) = c_temp;
        else
            c(ix_c) = nan;
        end
    end
elseif strcmpi(col_name_s, 'Rep Rate (Hz)')
    u = 'Hz';
    % this should be rep-rate
    try
        assert(mean(contains(c, u))>assert_th, 'This is not a expected column...');
    catch
        keyboard
    end;
    c_o = c;
    c = nan(size(c));
    for ix_c = 1:length(c)
        if contains(c_o{ix_c}, u)
            c_temp = extractBefore(c_o{ix_c}, u);
            c_temp = str2double(c_temp);
            c(ix_c) = c_temp;
        else
            c(ix_c) = nan;
        end
    end
else
    %it's a number
    c = cellfun(@(x) str2double(x), c, 'UniformOutput', false);
    c = cell2mat(c);
    u = 'uV_maybe_need_to_check';
end
end