function  sp_surgical_studio_augment(participant, d_data_coded, varargin)
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
d_sub_ephys = fullfile(d_data_coded, participant, 'ephys');
d_sub_device = fullfile(d_sub_ephys, 'cadwell-iomax');
assert(exist(d_sub_device, 'dir') == 7, 'This does not seem to have an IOMAX folder.');

if strcmpi(v.operation, 'write')
    if v.overwrite
        warning('overwrite flag does nothing in write mode!');
    end
    p_in_events = fullfile(d_sub_device, sprintf('%s_events_%s.xlsx', participant, v.operation));
    p_in_json = fullfile(d_sub_device, sprintf('%s_data.json', participant));
    if not(exist(p_in_json, 'file') == 2)
        error('\n%s\ndoes not exist!', p_in_json);
    end
    ephys_in = loadjson(p_in_json);
    ephys_in = ephys_in.Cases{1};

    ev_table = struct;
    ix_count = 1;
    for ix_event = 1:length(ephys_in.Events)
        ev = ephys_in.Events{ix_event};

        ev_table(ix_count).ix_event = ix_event;

        ev_table(ix_count).datetime = datetime(ev.Timestamp * 1e-6, 'ConvertFrom', 'posixtime');
        ev_table(ix_count).message = ev.Message;

        ev_table(ix_count).stim_sc_level = missing;
        ev_table(ix_count).stim_sc_laterality = missing;
        ev_table(ix_count).stim_sc_electrode = missing;
        ev_table(ix_count).stim_sc_electrode_configuration = missing;
        ev_table(ix_count).stim_sc_misc = missing;

        ev_table(ix_count).cx_stimulation_type = "none";
        ev_table(ix_count).cx_stimulation_configuration = string(missing);

        ev_table(ix_count).is_valid = true;

        ev_table(ix_count).stim_sc_approach = missing;
        ev_table(ix_count).set_sequence = missing;
        ev_table(ix_count).set_group = missing;
        ev_table(ix_count).cx_pct = double(missing);
        ev_table(ix_count).sc_pct = double(missing);
        ev_table(ix_count).moi = missing;
        ev_table(ix_count).muscle_targeted = missing;

        ev_table(ix_count).sc_impedance1 = missing;
        ev_table(ix_count).sc_impedance2 = missing;

        ix_count = ix_count + 1;
    end
    ev_table = struct2table(ev_table);
    ev_table.datetime_real = ev_table.datetime;  % kept as a backup in case you need to modify
    writetable(ev_table, p_in_events);
elseif strcmpi(v.operation, 'augment')
    %     for ix_cell_sub = 1:length(cell_sub)
    assert(v.augment_events, 'Events must get augmented');
    p_in_ephys_properties_toml = fullfile(d_sub_device, sprintf('%s_properties.toml', participant));
    p_in_ephys_properties_json = fullfile(d_sub_device, sprintf('%s_properties.json', participant));
    p_in_exceptions = fullfile(d_sub_device, sprintf('%s_exceptions.json', participant));
    p_in_events = fullfile(d_sub_device, sprintf('%s_events_%s.xlsx', participant, v.operation));
    p_in_ephys_data = fullfile(d_sub_device, sprintf('%s_data.json', participant));

    p_out_ephys_data = fullfile(d_sub_ephys, sprintf('%s_data.json', participant));
    p_out_ephys_info = fullfile(d_sub_ephys, sprintf('%s_info.mat', participant));

    str_redcapiid = sp_check_redcapid(fileparts(d_sub_ephys));

    do_augment = generate_check(p_out_ephys_data, v.overwrite);

    if do_augment
        %%
        if exist(p_in_ephys_data, 'file') == 2
            assert(exist(p_in_events, 'file') == 2, 'Events file for reading needs to be manually created!');
        else
            assert(exist(p_in_events, 'file') == 2, 'Maybe not an IOMAX file?');
        end
        if (exist(p_in_ephys_properties_toml, 'file') == 2)
            ephys_properties = toml.read(p_in_ephys_properties_toml);
            ephys_properties = toml.map_to_struct(ephys_properties);
        else
            ephys_properties = loadjson(p_in_ephys_properties_json);
        end
        opts = detectImportOptions(p_in_events);
        opts.VariableTypes = strrep(opts.VariableTypes, 'char', 'string');
        opts.VariableNamesRange = 'A1';
        opts.DataRange = 'A2';
        ephys_events = readtable(p_in_events, opts);
        ephys_in = loadjson(p_in_ephys_data);ephys_in = ephys_in.Cases{1};

        %%
        if (exist(p_in_exceptions, 'file') == 2)
            exceptions = loadjson(p_in_exceptions);
        else
            exceptions = struct;
        end
        %%
        % 2022-03-07 add default that if we do not specificy, we assume stim type
        % is epidural.
        if not(any(strcmpi(ephys_events.Properties.VariableNames, 'stim_sc_depth')))
            ephys_events.stim_sc_depth(:) = "epidural";
        end

        %% Mode reassign exception
        if isfield(exceptions, 'mode_reassign')
            vec_mode_ = string(arrayfun(@(ix) ephys_in.Modes{ix}.Name, [1:length(ephys_in.Modes)], 'UniformOutput', false));
            if isfield(exceptions.mode_reassign, 'delete_original')
                str_mode_in = string(exceptions.mode_reassign.delete_original);
                case_mode = str_mode_in == vec_mode_;
                ephys_in.Modes(case_mode) = [];
                vec_mode_ = string(arrayfun(@(ix) ephys_in.Modes{ix}.Name, [1:length(ephys_in.Modes)], 'UniformOutput', false));
            end
            str_mode_in = string(exceptions.mode_reassign.from);
            case_mode = str_mode_in == vec_mode_;
            ephys_mode = ephys_in.Modes{case_mode};
            vec_reassign = false(length(ephys_mode.Trials), 1);
            for ix_trial = 1:length(ephys_mode.Trials)
                stimuli = arrayfun(@(ix) ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix}.Name,1:length(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli),'UniformOutput',false);
                if any(string(stimuli) == exceptions.mode_reassign.if_contains_stimuli)
                    vec_reassign(ix_trial) = true;
                end
            end
            ephys_in.Modes{end+1} = ephys_mode;
            ephys_in.Modes{end}.Trials = ephys_in.Modes{end}.Trials(vec_reassign);
            ephys_in.Modes{end}.Name = exceptions.mode_reassign.to;
            ephys_in.Modes{case_mode}.Trials = ephys_in.Modes{case_mode}.Trials(not(vec_reassign));
        end

        %%
        vec_mode = string(arrayfun(@(ix) ephys_in.Modes{ix}.Name, [1:length(ephys_in.Modes)], 'UniformOutput', false));
        subselect_modes = ...
            vec_mode == "d-Spinal Cord (SCS)" | ...
            vec_mode == "Research SCS" | ...
            vec_mode == "Research Paired Repeat" | ...
            vec_mode == "Research Paired Averaged" | ...
            vec_mode == "Research D-Wave" | ...
            vec_mode == "Research MEP" | ...
            vec_mode == "Research HD"| ...
            vec_mode == "Research SCS+Cortical"| ...
            vec_mode == "Research Peripheral"| ...
            vec_mode == "Research PA single contact"| ...
            vec_mode == "Research P Repeat Trigger"| ...
            vec_mode == "EEG"|...
            vec_mode == "Research LCSWAP"| ...
            vec_mode == "Research SCS Pairs"| ...
            vec_mode == "SCS Train"| ...
            vec_mode == "Research SCS Train"| ...
            vec_mode == "Research PE Right"| ...
            vec_mode == "Research PE Left"| ...
            vec_mode == "Research HD Brain"| ...
            false;
        %         vec_mode == "Research PProbe"| ...  % need to deal with this
        %         differently since recording is for longer time.

        if isfield(ephys_properties.sweep_info, 'clinical_mep')
            % you need to put the sweep info into the properties file
            % or I am just going to skip loading that data
            subselect_modes = subselect_modes | ...
                vec_mode == "MEP"| ...
                vec_mode == "L MEP"| ...
                vec_mode == "R MEP"| ...
                false;
        end

        %%
        vec_mode_select = vec_mode(subselect_modes);  % temporary!
        % need to exclude if mode is empty here!
        mode_is_empty = false(1, length(vec_mode_select));
        for ix_vec_mode = 1:length(vec_mode_select)
            str_mode_in = vec_mode_select(ix_vec_mode);
            case_mode = str_mode_in == vec_mode;
            ephys_mode = ephys_in.Modes{case_mode};
            if isfield(ephys_mode, 'StreamingTrials')
                ephys_mode.Trials = ephys_mode.StreamingTrials;  % so it can be processed with same code
            end
            if isempty(ephys_mode.Trials)
                mode_is_empty(ix_vec_mode) = true;
            end
        end
        vec_mode_select(mode_is_empty) = [];
        ephys_ev_posix = posixtime(ephys_events.datetime) * 1e6;

        %%
        ephys_out = ephys_in;
        ephys_out.Modes = cell(1, length(vec_mode_select));
        ephys_out.HardwareType = 'cadwell-iomax';
        ephys_info = struct;

        %%
        for ix_vec_mode = 1:length(vec_mode_select)
            str_mode_in = vec_mode_select(ix_vec_mode);
            if str_mode_in == "d-Spinal Cord (SCS)"
                str_mode_out = "research_scs";
            elseif str_mode_in == "Research HD"
                str_mode_out = "research_multipulse";
            elseif str_mode_in == "Research SCS+Cortical"
                str_mode_out = "research_scs";
            elseif str_mode_in == "Research D-Wave"
                str_mode_out = "research_dwave";
            elseif str_mode_in == "Research PA single contact"
                %                 str_mode_out = "research_pa_single_contact";
                str_mode_out = "research_paired_averaged";
            elseif (str_mode_in == "L MEP") || (str_mode_in == "R MEP") || (str_mode_in == "MEP")
                str_mode_out = "clinical_mep";
            elseif str_mode_in == "Research P Repeat Trigger"
                str_mode_out = "research_paired_repeat";
            elseif str_mode_in == "Research LCSWAP"
                str_mode_out = "research_lcswap";
            elseif str_mode_in == "Research SCS Pairs"
                str_mode_out = "research_scs_pairs";
            elseif str_mode_in == "SCS Train"
                str_mode_out = "research_scs_train";
            elseif str_mode_in == "Research PE Left"
                str_mode_out = "research_peripheral";
            elseif str_mode_in == "Research PE Right"
                str_mode_out = "research_peripheral";
            elseif str_mode_in == "Research HD Brain"
                str_mode_out = "research_multipulse_brain";
            else
                str_mode_out = strrep(lower(strrep(str_mode_in, '-', '')), ' ', '_');
            end

            case_mode = str_mode_in == vec_mode;
            ephys_mode = ephys_in.Modes{case_mode};
            if isfield(ephys_mode, 'StreamingTrials')
                ephys_mode.Trials = ephys_mode.StreamingTrials;  % so it can be processed with same code
            end
            ephys_mode.Name = str_mode_out;
            %             if isfield(ephys_mode, 'Trials')
            ephys_info_mode = array2table(zeros(length(ephys_mode.Trials), 1));
            ephys_info_mode.Properties.VariableNames = {'ix'};

            for ix_trial = 1:length(ephys_mode.Trials)

                dt_diff = ephys_mode.Trials{ix_trial}.Timestamp - ephys_ev_posix;
                dt_diff(dt_diff<0) = nan;
                [check_me, ix_min] = min(dt_diff);

                ephys_info_mode.ix(ix_trial) = ix_trial;
                ephys_info_mode.datetime(ix_trial) = datetime(ephys_mode.Trials{ix_trial}.Timestamp * 1e-6, 'ConvertFrom', 'posixtime');

                ephys_info_mode.sc_level(ix_trial) = string(ephys_events.stim_sc_level(ix_min));
                ephys_info_mode.sc_laterality(ix_trial) = string(ephys_events.stim_sc_laterality(ix_min));
                ephys_info_mode.sc_misc(ix_trial) = string(ephys_events.stim_sc_misc(ix_min));
                ephys_info_mode.sc_electrode(ix_trial) = string(ephys_events.stim_sc_electrode(ix_min));
                ephys_info_mode.sc_electrode_type(ix_trial) = group_electrodes(string(ephys_events.stim_sc_electrode(ix_min)));
                ephys_info_mode.sc_electrode_configuration(ix_trial) = string(ephys_events.stim_sc_electrode_configuration(ix_min));
                ephys_info_mode.sc_approach(ix_trial) = string(ephys_events.stim_sc_approach(ix_min));

                % TODO: add the definition for this:
                ephys_info_mode.sc_depth(ix_trial) = string(ephys_events.stim_sc_depth(ix_min));

                %                 ephys_info_mode.pe_laterality(ix_trial) = string(missing);  % delete this line
                %                 ephys_info_mode.pe_nerve(ix_trial) = string(missing);  % delete this line

                ephys_info_mode.cx_laterality(ix_trial) = "";  % think you can get this from the trial info
                ephys_info_mode.cx_stimulation_type(ix_trial) = string(ephys_events.cx_stimulation_type(ix_min));
                ephys_info_mode.cx_stimulation_configuration(ix_trial) = string(ephys_events.cx_stimulation_configuration(ix_min));

                ephys_info_mode.device(ix_trial) = string(ephys_out.HardwareType);

                if any(strcmpi(ephys_events.Properties.VariableNames, 'sc_impedance1'))
                    sc_impedance1 = ephys_events.sc_impedance1(ix_min);
                    sc_impedance2 = ephys_events.sc_impedance2(ix_min);
                else
                    sc_impedance1 = nan;
                    sc_impedance2 = nan;
                end
                ephys_info_mode.sc_impedance1(ix_trial) = sc_impedance1;
                ephys_info_mode.sc_impedance2(ix_trial) = sc_impedance2;

                if any(strcmpi(ephys_events.Properties.VariableNames, 'set_sequence'))
                    set_sequence = lower(string(ephys_events.set_sequence(ix_min)));
                    set_group = lower(string(ephys_events.set_group(ix_min)));
                    cx_pct = ephys_events.cx_pct(ix_min);
                    sc_pct = ephys_events.sc_pct(ix_min);
                    moi = ephys_events.moi(ix_min);
                    muscle_targeted = ephys_events.muscle_targeted(ix_min);
                else
                    set_sequence = string(missing);
                    set_group = string(missing);
                    cx_pct = double(missing);
                    sc_pct = double(missing);
                    moi = string([missing]);
                    muscle_targeted = string([missing]);
                end
                ephys_info_mode.set_sequence(ix_trial) = set_sequence;
                ephys_info_mode.set_group(ix_trial) = set_group;
                ephys_info_mode.cx_pct(ix_trial) = double(cx_pct);
                ephys_info_mode.sc_pct(ix_trial) = double(sc_pct);
                ephys_info_mode.moi(ix_trial) = moi;
                ephys_info_mode.muscle_targeted(ix_trial) = muscle_targeted;

                ephys_info_mode.is_valid(ix_trial) = logical(ephys_events.is_valid(ix_min));

                % for now I might not want to sort all the pure clinical MEPs etc.
                % so add this so that the pure data is kept, but I don't have summary
                % info for it in the table:
                ephys_info_mode.non_summarised(ix_trial) = false;
                %  assume spinal is 1... although that's not right of
                %  course because this could be a pure MEP
                % also assume pw is the same within the train

                if isfield(ephys_mode.Trials{ix_trial}, 'Stimuli')
                    n_stimuli = length(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli);
                else
                    n_stimuli = 0;
                end

                if isfield(ephys_mode.Trials{ix_trial}, 'ActualRepRate')
                    if ephys_mode.Trials{ix_trial}.ActualRepRate == 0
                        if isfield(ephys_mode.Trials{ix_trial}, 'RequestedRepRate')
                            if ephys_mode.Trials{ix_trial}.RequestedRepRate == 0
                                ephys_info_mode.iti(ix_trial) = 0;
                            else
                                RequestedRepRate = ephys_mode.Trials{ix_trial}.RequestedRepRate;
                                ephys_info_mode.iti(ix_trial) = 1/RequestedRepRate;
                                fprintf('ActualRepRate was missing - falling back on RequestedRepRate (%0.1fHz).\n', RequestedRepRate);
                            end
                        else
                            ephys_info_mode.iti(ix_trial) = 0;
                        end
                    else
                        ephys_info_mode.iti(ix_trial) = 1/ephys_mode.Trials{ix_trial}.ActualRepRate;
                    end
                else
                    ephys_info_mode.iti(ix_trial) = 0;
                end

                ix_exemplar_pulse = 1;  % this will fail for more complex trains...
                ix_exemplar_trace = 1;

                sweep_t = ephys_mode.Trials{ix_trial}.Traces{ix_exemplar_trace}.Sweep;
                try
                    if isfield(ephys_mode, 'StreamingTrials')
                        sweep_delay_t = 0;
                        average_count = nan;
                    else
                        sweep_delay_chunks = double(ephys_properties.sweep_info.(str_mode_out).sweep_delay);
                        sweep_mspdiv_from_data = (sweep_t/10) * 1e3;
                        if isfield(ephys_properties.sweep_info.(str_mode_out), 'sweep')
                            % pre 2023-02-03
                            sweep_mspdiv = double(ephys_properties.sweep_info.(str_mode_out).sweep);
                            assert(sweep_mspdiv_from_data == sweep_mspdiv, 'The fact that this is wrong indicates that you MUST refine the sweep_mspdiv_from_data calculation.');
                            assert(sweep_mspdiv * 10 * 1e-3 == sweep_t, 'Properties are messed up - ');
                            sweep_delay_t = (sweep_delay_chunks * sweep_mspdiv * 1e-3);% * sweep_t;
                            average_count = double(ephys_properties.sweep_info.(str_mode_out).average_count);
                        else
                            sweep_mspdiv = sweep_mspdiv_from_data;
                            sweep_delay_t = (sweep_delay_chunks * sweep_mspdiv * 1e-3);% * sweep_t;
                            average_count = double(ephys_properties.sweep_info.(str_mode_out).average_count);
                        end
                    end
                catch
                    % perhaps you are missing the mode in the _properties.json file
                    % or one of the sweep parameters is missing
                    keyboard;
                end

                ephys_info_mode.average_count(ix_trial) = average_count;
                ephys_info_mode.fs(ix_trial) = ephys_mode.Trials{ix_trial}.Traces{ix_exemplar_trace}.TraceDataLength/sweep_t;
                ephys_info_mode.sweep(ix_trial) = sweep_t;
                ephys_mode.Trials{ix_trial}.Stimuli.DataSweepTriggerDelayCustom = sweep_delay_t;

                % if str_mode_out == "research_scs_train"
                %     keyboard;
                % end

                wrote_cortical = false;
                wrote_spinal = false;
                wrote_peripheral = false;

                for ix_stimuli = 1:n_stimuli  % i.e. SC and cortical mainly.
                    % this might fail for HD mode -
                    lcs1 = strcmpi(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, ...
                        'Low Current Stimulator at Cortical Module');
                    lcs2 = strcmpi(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, ...
                        'LCSwap Strip/Grid Stimulator at Cortical Module');
                    per1 = strcmpi(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, ...
                        'Electrical Stimulator at Limb Module 1');
                    per2 = strcmpi(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, ...
                        'Electrical Stimulator at Limb Module 2');
                    cxs = strcmpi(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, ...
                        'TCS-9 Stimulator at Cortical Module');
                    cxs_trigger = strcmpi(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, ...
                        'Trigger Out');
                    if lcs1||lcs2
                        sc_count = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Train1PulseCount;
                        ephys_info_mode.sc_count(ix_trial) = sc_count;

                        ephys_info_mode.sc_pw(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.PulseWidth;
                        sc_polarity = string(lower(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.Polarity));
                        if lcs1
                            ephys_info_mode.sc_polarity(ix_trial) = sc_polarity;
                        elseif lcs2
                            assert(sc_polarity == "normal", 'Not sure what to do here...');
                            lcswap_polarity = string(cellfun(@(y) y.Usage, ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs, 'UniformOutput', false));
                            case_anode = lcswap_polarity == "Anode";
                            cell_anode = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs(case_anode);
                            cell_cathode = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs(not(case_anode));

                            str_polarity = "[";
                            for ix_cell_anode = 1:length(cell_anode)
                                str_polarity = str_polarity + sprintf('%d', cell_anode{ix_cell_anode}.OutputNumber);
                                if ix_cell_anode ~= length(cell_anode)
                                    str_polarity = str_polarity + ", ";
                                end
                            end
                            str_polarity = str_polarity + "-";
                            for ix_cell_anode = 1:length(cell_cathode)
                                str_polarity = str_polarity + sprintf('%d', cell_cathode{ix_cell_anode}.OutputNumber);
                                if ix_cell_anode ~= length(cell_cathode)
                                    str_polarity = str_polarity + ", ";
                                end
                            end
                            str_polarity = str_polarity + "]";
                            ephys_info_mode.sc_polarity(ix_trial) = str_polarity;

                        else
                            error('?')
                        end
                        biphasic = string(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.Biphasic);
                        if biphasic == "true"
                            biphasic = true;
                            pw_disp_multiplier = 2;
                        elseif biphasic == "false"
                            biphasic = false;
                            pw_disp_multiplier = 1;
                        else
                            error('?');
                        end
                        if sc_count > 1
                            sc_displacement = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse + 1}.Displacement;
                            sc_ipi = sc_displacement - pw_disp_multiplier * ephys_info_mode.sc_pw(ix_trial);
                            sc_frequency = 1/sc_displacement;
                        else
                            if str_mode_out == "research_scs_train"
                                % one of these is probably wrong by a
                                % pulsewidth (but not a big deal)
                                sc_ipi = ephys_info_mode.iti(ix_trial);
                                sc_frequency = 1/ephys_info_mode.iti(ix_trial);
                                ephys_info_mode.iti(ix_trial) = 0;
                            else
                                sc_ipi = 0;
                                sc_frequency = 0;
                            end
                        end

                        if isfield(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}, 'Displacement')
                            sc_displacement = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Displacement;
                        else
                            sc_displacement = 0;
                        end
                        ephys_info_mode.sc_ipi(ix_trial) = sc_ipi;

                        ephys_info_mode.sc_biphasic(ix_trial) = biphasic;

                        if isfield(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}, 'SensedCurrent')
                            ephys_info_mode.sc_current(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.SensedCurrent;
                            ephys_info_mode.sc_voltage(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.SensedVoltage;
                        else
                            fprintf('For some reason, the current was not sensed. ');
                            fprintf('Mode: %s, trial: %d, stimuli: %d, ', ephys_mode.Name, ix_trial, ix_stimuli);
                            fprintf('Timestamp: %s ', datetime(ephys_mode.Trials{ix_trial}.Timestamp * 1e-6, 'ConvertFrom', 'posixtime'));
                            fprintf('Replacing with intended current. Setting sensed voltage to NaN.')
                            fprintf('\n')
                            ephys_info_mode.sc_current(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{1}.Intensity;
                            ephys_info_mode.sc_voltage(ix_trial) = nan;
                        end

                        ephys_info_mode.sc_frequency(ix_trial) = sc_frequency;
                        ephys_info_mode.sc_displacement(ix_trial) = sc_displacement;

                        wrote_spinal = true;

                    elseif per1||per2
                        pe_count = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Train1PulseCount;
                        ephys_info_mode.pe_count(ix_trial) = pe_count;

                        ephys_info_mode.pe_pw(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.PulseWidth;
                        ephys_info_mode.pe_polarity(ix_trial) = string(lower(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.Polarity));
                        biphasic = string(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.Biphasic);
                        if biphasic == "true"
                            biphasic = true;
                            pw_disp_multiplier = 2;
                        elseif biphasic == "false"
                            biphasic = false;
                            pw_disp_multiplier = 1;
                        else
                            error('?');
                        end
                        if pe_count > 1
                            pe_displacement = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse + 1}.Displacement;
                            pe_ipi = pe_displacement - pw_disp_multiplier * ephys_info_mode.pe_pw(ix_trial);
                            pe_frequency = 1/pe_displacement;
                        else
                            pe_ipi = 0;
                            pe_frequency = 0;
                        end

                        if isfield(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}, 'Displacement')
                            pe_displacement = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Displacement;
                        else
                            pe_displacement = 0;
                        end
                        ephys_info_mode.pe_ipi(ix_trial) = pe_ipi;

                        ephys_info_mode.pe_biphasic(ix_trial) = biphasic;
                        if isfield(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}, 'SensedCurrent')
                            ephys_info_mode.pe_voltage(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.SensedVoltage;
                            ephys_info_mode.pe_current(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.SensedCurrent;
                        else
                            fprintf('For some reason, the current was not sensed. ');
                            fprintf('Mode: %s, trial: %d, stimuli: %d, ', ephys_mode.Name, ix_trial, ix_stimuli);
                            fprintf('Timestamp: %s ', datetime(ephys_mode.Trials{ix_trial}.Timestamp * 1e-6, 'ConvertFrom', 'posixtime'));
                            fprintf('Replacing with intended current. Setting sensed voltage to NaN.')
                            fprintf('\n')
                            ephys_info_mode.pe_current(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{1}.Intensity;
                            ephys_info_mode.pe_voltage(ix_trial) = nan;
                        end
                        ephys_info_mode.pe_frequency(ix_trial) = pe_frequency;
                        ephys_info_mode.pe_displacement(ix_trial) = pe_displacement;

                        wrote_peripheral = true;

                        assert(length(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs) == 1, "Not sure why this happens.");
                        limb_moddule_number = sprintf('LM%s', ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name(end));
                        es_channel = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{1}.Label;
                        pe_target = ephys_properties.peripheral_config.(sprintf('%s%s', limb_moddule_number, es_channel));

                        ephys_info_mode.pe_laterality(ix_trial) = string(pe_target(1));
                        ephys_info_mode.pe_nerve(ix_trial) = string(pe_target(2:end));

                    elseif cxs
                        cx_count = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Train1PulseCount;
                        ephys_info_mode.cx_count(ix_trial) = cx_count;

                        ephys_info_mode.cx_pw(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.PulseWidth;

                        n_cxs = length(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs);
                        if n_cxs == 2
                            str_e1 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{1}.Usage;
                            str_e2 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{2}.Usage;
                            cx_stimulation_configuration = "bipolar";
                            cx_stimulation_side = string(lower(sprintf('%s%s', str_e1(1), str_e2(1))));  % eventually you will need to add this in...
                        elseif n_cxs == 4
                            str_e1 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{1}.Usage;
                            str_e2 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{2}.Usage;
                            str_e3 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{3}.Usage;
                            str_e4 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{4}.Usage;
                            assert(strcmpi(str_e2, str_e4) && strcmpi(str_e1, str_e3), '?');
                            cx_stimulation_configuration = "quad";
                            cx_stimulation_side = string(lower(sprintf('%s%s', str_e1(1), str_e2(1))));  % eventually you will need to add this in...
                        elseif n_cxs == 3
                            % not thoroughly tested
                            str_e1 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{1}.Usage;
                            str_e2 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{2}.Usage;
                            str_e3 = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{3}.Usage;
                            if strcmpi(str_e1, str_e3)
                                cx_stimulation_side = string(lower(sprintf('%s%s', str_e1(1), str_e2(1))));  % eventually you will need to add this in...
                            elseif strcmpi(str_e1, str_e2)
                                cx_stimulation_side = string(lower(sprintf('%s%s', str_e1(1), str_e3(1))));  % eventually you will need to add this in...
                            end
                            cx_stimulation_configuration = "tri";
                        else
                            error('Unusual cortical montage?');
                        end
                        if strcmpi(cx_stimulation_side, 'ac')
                            cx_stimulation_mep_side = "R";
                        elseif strcmpi(cx_stimulation_side, 'ca')
                            cx_stimulation_mep_side = "L";
                        end

                        ephys_info_mode.cx_polarity(ix_trial) = string(lower(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.Polarity));
                        cx_biphasic = string(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.Biphasic);
                        if cx_biphasic == "true"
                            cx_biphasic = true;
                            pw_disp_multiplier = 2;

                        elseif cx_biphasic == "false"
                            cx_biphasic = false;
                            pw_disp_multiplier = 1;
                        else
                            error('?');
                        end

                        if cx_count > 1
                            cx_displacement = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse + 1}.Displacement;
                            cx_ipi = cx_displacement - pw_disp_multiplier * ephys_info_mode.cx_pw(ix_trial);
                            cx_frequency = 1/cx_displacement;
                        else
                            cx_ipi = 0;
                            cx_frequency = 0;
                        end

                        if isfield(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}, 'Displacement')
                            cx_displacement = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Displacement;
                        else
                            cx_displacement = 0;
                        end

                        ephys_info_mode.cx_ipi(ix_trial) = cx_ipi;

                        ephys_info_mode.cx_biphasic(ix_trial) = cx_biphasic;
                        if isfield(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}, 'SensedVoltage')
                            ephys_info_mode.cx_voltage(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.SensedVoltage;
                        else
                            % not sure why this happens - maybe if IOM
                            % spams the stim button during clinical MEPs?
                            ephys_info_mode.cx_voltage(ix_trial) = nan;
                        end
                        if isfield(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}, 'SensedCurrent')
                            ephys_info_mode.cx_current(ix_trial) = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.SensedCurrent;
                        else
                            ephys_info_mode.cx_current(ix_trial) = nan;
                        end
                        ephys_info_mode.cx_frequency(ix_trial) = cx_frequency;
                        ephys_info_mode.cx_displacement(ix_trial) = cx_displacement;
                        ephys_info_mode.cx_stimulation_configuration(ix_trial) = cx_stimulation_configuration;
                        ephys_info_mode.cx_stimulation_mep_side(ix_trial) = cx_stimulation_mep_side;
                        wrote_cortical = true;

                    elseif cxs_trigger
                        cx_count = 0;
                        cx_pw = 0;
                        cx_stimulation_configuration = "quad";
                        cx_stimulation_side = "ac";
                        cx_displacement = nan;
                        cx_biphasic = "false";
                        cx_polarity = "normal";
                        cx_voltage = 0;
                        cx_current = 0;

                        % overwrite the device string
                        ephys_info_mode.device(ix_trial) = string(ephys_out.HardwareType) + '-digitimer';

                        dt_day = dateshift(ephys_info_mode.datetime(1), 'start', 'day');
                        vec_time_strings = string(fieldnames(ephys_properties.digitimer));
                        for ix_vec_time_strings = 1:length(vec_time_strings)
                            str_t = vec_time_strings(ix_vec_time_strings);
                            digitimer_cfg = ephys_properties.digitimer.(str_t);
                            time_bounds = dt_day + duration(string(digitimer_cfg.time));
                            time_now = ephys_info_mode.datetime(ix_trial);
                            if (time_now > time_bounds(1)) && (time_now <= time_bounds(2))
                                cx_count = double(digitimer_cfg.cx_count);
                                cx_pw = double(digitimer_cfg.cx_pw);
                                cx_stimulation_configuration = string(digitimer_cfg.cx_stimulation_configuration); % = "quad";
                                cx_stimulation_side = string(digitimer_cfg.cx_stimulation_side); %  = "ac";  % or ca
                                cx_displacement = double(digitimer_cfg.cx_displacement);  % = 3e-3;
                                cx_biphasic = string(digitimer_cfg.cx_biphasic);  %  = "false";
                                cx_polarity = string(digitimer_cfg.cx_polarity);  % = "normal";
                                cx_voltage = double(digitimer_cfg.cx_voltage);  % = nan;
                                cx_current = double(digitimer_cfg.cx_current);  % = nan;
                            end
                        end
                        if cx_biphasic == "true"
                            cx_biphasic = true;
                            pw_disp_multiplier = 2;

                        elseif cx_biphasic == "false"
                            cx_biphasic = false;
                            pw_disp_multiplier = 1;
                        else
                            error('?');
                        end
                        cx_ipi = cx_displacement - pw_disp_multiplier * cx_pw;
                        cx_frequency = 1/cx_displacement;

                        %                         ephys_properties.digitimer

                        ephys_info_mode.cx_count(ix_trial) = cx_count;
                        ephys_info_mode.cx_pw(ix_trial) = cx_pw;

                        if strcmpi(cx_stimulation_side, 'ac')
                            cx_stimulation_mep_side = "R";
                        elseif strcmpi(cx_stimulation_side, 'ca')
                            cx_stimulation_mep_side = "L";
                        end

                        ephys_info_mode.cx_polarity(ix_trial) = cx_polarity; %string(lower(ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.ElectricalPulses{ix_exemplar_pulse}.Polarity));
                        ephys_info_mode.cx_ipi(ix_trial) = cx_ipi;

                        ephys_info_mode.cx_biphasic(ix_trial) = cx_biphasic;

                        ephys_info_mode.cx_voltage(ix_trial) = cx_voltage;
                        ephys_info_mode.cx_current(ix_trial) = cx_current;

                        ephys_info_mode.cx_frequency(ix_trial) = cx_frequency;
                        ephys_info_mode.cx_displacement(ix_trial) = cx_displacement;
                        ephys_info_mode.cx_stimulation_configuration(ix_trial) = cx_stimulation_configuration;
                        ephys_info_mode.cx_stimulation_mep_side(ix_trial) = cx_stimulation_mep_side;
                        wrote_cortical = true;
                    else
                        error('not coded');
                    end
                end

                % correct the sc_frequency and the sc_count if we were in
                % research_multipulse. In the IOMAX this mode was treated
                % as multiple stimuli with individual pulses, but in previous systems it was
                % treated as a single stimuli was multiple pulses
                if (str_mode_out == "research_multipulse") || (str_mode_out == "research_multipulse_brain")
                    ephys_info_mode.sc_count(ix_trial) = n_stimuli;
                    sc_displacement = ephys_mode.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_exemplar_pulse + 1}.Displacement;
                    sc_frequency = 1/sc_displacement;
                    ephys_info_mode.sc_frequency(ix_trial) = sc_frequency;
                    %                     pw_disp_multiplier_sc = 2;
                    %                     sc_ipi = sc_displacement - pw_disp_multiplier_sc * ephys_info_mode.sc_pw(ix_trial);  % not sure about this line. Do not need for now.
                end

                ephys_info_mode.misc(ix_trial) = "";

                if wrote_spinal && wrote_cortical
                    if ephys_info_mode.sc_current(ix_trial) < 5e-5  % if negligible SCS
                        ephys_info_mode.sc_displacement(ix_trial) = 0;
                        ephys_info_mode.sc_current(ix_trial) = 0;
                    end
                elseif wrote_peripheral && wrote_cortical
                    if ephys_info_mode.pe_current(ix_trial) < 5e-5  % if negligible peripheral
                        ephys_info_mode.pe_displacement(ix_trial) = 0;
                        ephys_info_mode.pe_current(ix_trial) = 0;
                    end

                end
                if not(wrote_spinal)
                    ephys_info_mode = blank_spinal(ephys_info_mode, ix_trial);
                end
                if not(wrote_cortical)
                    ephys_info_mode = blank_cortical(ephys_info_mode, ix_trial);
                end
                if not(wrote_peripheral)
                    ephys_info_mode = blank_peripheral(ephys_info_mode, ix_trial);
                end

            end

            ephys_info_mode.institute(:) = string(ephys_properties.institute);
            ephys_info_mode.participant(:) = string(participant);
            if isfield(ephys_properties, 'main_targeted_side')
                ephys_info_mode.main_targeted_side(:) = string(ephys_properties.main_targeted_side);
            else
                warning('MISSING MAIN TARGETED SIDE FOR %s', str_redcapiid);
                ephys_info_mode.main_targeted_side(:) = "";
            end

            ephys_info.Modes{ix_vec_mode} = ephys_info_mode;
            ephys_out.Modes{ix_vec_mode} = ephys_mode;
        end


        if isfield(ephys_properties, 'replace_muscle')
            % turns out not to be needed for json exported surgical studio
            % data
            % ephys_properties.replace_muscle.research_scs.Delt
        end
        % add a single custom field
        %         X.etc = ephys_in.etc;

        % Unfortunately all code uses uV instead of V as base units so
        % tweak that here.
        for ix_vec_mode = 1:length(ephys_out.Modes)
            for ix_trial = 1:length(ephys_out.Modes{ix_vec_mode}.Trials)
                for ix_trace = 1:length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces)
                    tds = ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces{ix_trace}.TraceDataScalar;
                    tds = tds * 1e6;
                    ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces{ix_trace}.TraceDataScalar = tds;
                end
            end
        end
        %
        fn = fieldnames(ephys_properties);
        for ix_fn = 1:length(fn)
            v.(fn{ix_fn}) = ephys_properties.(fn{ix_fn});
        end
        ephys_info.etc = v;
        %         ephys_info.etc.vec_mode = arrayfun(@(ix) ephys_out.Modes{ix}.Name, 1:length(ephys_out.Modes));

        % Strip the true data datetime info -
        dt_day = datetime(ephys_out.StartDate * 1e-6, 'ConvertFrom', 'posixtime');
        dt_day = dateshift(dt_day, 'start', 'day');
        ephys_out.StartDate = anon_timestamp(ephys_out.StartDate, dt_day);
        if isfield(ephys_out, 'PatientBirthDate')
            ephys_out.PatientBirthDate = anon_timestamp(ephys_out.PatientBirthDate, dt_day);
        end
        for ix_vec_mode = 1:length(ephys_out.Modes)
            for ix_trial = 1:length(ephys_out.Modes{ix_vec_mode}.Trials)
                ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Timestamp = ...
                    anon_timestamp(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Timestamp, dt_day);
                for ix_trace = 1:length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces)
                    ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces{ix_trace}.Timestamp = ...
                        anon_timestamp(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces{ix_trace}.Timestamp, dt_day);
                end
            end
            ephys_info.Modes{ix_vec_mode}.datetime = anon_datetime(ephys_info.Modes{ix_vec_mode}.datetime, dt_day);
        end
        for ix_event = 1:length(ephys_out.Events)
            ephys_out.Events{ix_event}.Timestamp = anon_timestamp(ephys_out.Events{ix_event}.Timestamp, dt_day);
        end
        ephys_out.PulseOximetryTimestamps = [];  % if you ever need them you can fix this...

        %% deal with exceptions
        if isfield(exceptions, 'channel_reassign')
            for ix_vec_mode = 1:length(ephys_out.Modes)
                for ix_trial = 1:length(ephys_out.Modes{ix_vec_mode}.Trials)
                    if isfield(exceptions, 'channel_reassign_after')
                        trial_time_local = datetime(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Timestamp * 1e-6, 'ConvertFrom', 'posixtime');
                        trial_day_local = dateshift(trial_time_local, 'start', 'day');
                        channel_reassign_after = datetime(sprintf('%sT%s', datestr(trial_day_local, 'yyyy-mm-dd'), exceptions.channel_reassign_after));
                        if trial_time_local < channel_reassign_after
                            continue;
                        end
                    end

                    % first write out the channel data for this trial &
                    % mode into a vector
                    vec_channel = cell(1, length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces));
                    for ix_trace = 1:length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces)
                        ch = ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces{ix_trace}.Channel.Name;
                        vec_channel{1, ix_trace} = ch;
                    end

                    % now do the switch again into a vector
                    vec_channel_original = vec_channel;
                    fn_re = fieldnames(exceptions.channel_reassign);
                    for ix_reassign = 1:length(fn_re)
                        cleaned_fn_re = strrep(fn_re{ix_reassign}, '_0x20_', ' ');  % if there is a space in the name, then it ends up like this
                        ix_original_location = strcmpi(vec_channel_original, cleaned_fn_re);
                        if sum(ix_original_location)>0
                            vec_channel{ix_original_location} = exceptions.channel_reassign.(fn_re{ix_reassign});
                        end
                    end

                    % now re-assign back to the original structure
                    for ix_trace = 1:length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces)
                        ch = vec_channel{1, ix_trace};
                        ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Traces{ix_trace}.Channel.Name = ch;
                    end

                end
            end
        end
        if isfield(exceptions, 'invert_cortical_stimulation')
            if exceptions.invert_cortical_stimulation
                for ix_vec_mode = 1:length(ephys_out.Modes)
                    ephys_info.Modes{ix_vec_mode}.cx_stimulation_mep_side(ephys_info.Modes{ix_vec_mode}.cx_stimulation_mep_side == "L") = "RX";
                    ephys_info.Modes{ix_vec_mode}.cx_stimulation_mep_side(ephys_info.Modes{ix_vec_mode}.cx_stimulation_mep_side == "R") = "LX";
                    ephys_info.Modes{ix_vec_mode}.cx_stimulation_mep_side(ephys_info.Modes{ix_vec_mode}.cx_stimulation_mep_side == "LX") = "L";
                    ephys_info.Modes{ix_vec_mode}.cx_stimulation_mep_side(ephys_info.Modes{ix_vec_mode}.cx_stimulation_mep_side == "RX") = "R";
                end

                for ix_vec_mode = 1:length(ephys_out.Modes)
                    for ix_trial = 1:length(ephys_out.Modes{ix_vec_mode}.Trials)
                        if not(isfield(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli, 'DiscreteStimuli')), continue;end
                        for ix_stimuli = 1:length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli)
                            if contains(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, 'TCS-9')
                                n_cxs = length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs);
                                for ix_cxs = 1:n_cxs
                                    ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{ix_cxs}.Usage = ...
                                        switch_anode_cathode(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs{ix_cxs}.Usage);
                                end
                            end
                        end
                    end
                end
            end
        end
        if isfield(exceptions, 'tes_is_hardware_quad')
            % if we are using a hardware splitter to make quad stim instead
            % of using the IOMAX config directly
            if exceptions.tes_is_hardware_quad
                for ix_vec_mode = 1:length(ephys_out.Modes)
                    ephys_info.Modes{ix_vec_mode}.cx_stimulation_configuration = strrep(ephys_info.Modes{ix_vec_mode}.cx_stimulation_configuration, "bipolar", "quad");
                end

                for ix_vec_mode = 1:length(ephys_out.Modes)
                    for ix_trial = 1:length(ephys_out.Modes{ix_vec_mode}.Trials)
                        if not(isfield(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli, 'DiscreteStimuli')), continue;end
                        for ix_stimuli = 1:length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli)
                            if contains(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, 'TCS-9')
                                n_cxs = length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs);
                                for ix_cxs = 1:n_cxs
                                    cx_op_cfg = ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs;
                                    quad_in_table = (ephys_info.Modes{ix_vec_mode}.cx_stimulation_configuration(ix_trial) == "quad");
                                    if quad_in_table && (length(cx_op_cfg) == 2)
                                        cx_op_cfg_alt = cx_op_cfg;
                                        cx_op_cfg_alt{1}.Label = 'H3';cx_op_cfg_alt{1}.OutputNumber = 3;
                                        cx_op_cfg_alt{2}.Label = 'H4';cx_op_cfg_alt{2}.OutputNumber = 4;
                                        ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Outputs = [cx_op_cfg, cx_op_cfg_alt];
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        % deal with incorrect sweep setup in early digitimer usage
        if isfield(exceptions, 'sweep')
            if isfield(exceptions.sweep, 'research_paired_repeat_trigger')
                for ix_vec_mode = 1:length(ephys_out.Modes)
                    for ix_trial = 1:length(ephys_out.Modes{ix_vec_mode}.Trials)
                        if not(isfield(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli, 'DiscreteStimuli')), continue;end
                        if contains(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{1}.Name, 'Trigger Out')
                            sweep_t = (double(exceptions.sweep.('research_paired_repeat_trigger').sweep) * 10) * 1e-3;
                            sweep_mspdiv = (sweep_t/10) * 1e3;
                            sweep_delay_chunks = double(exceptions.sweep.('research_paired_repeat_trigger').sweep_delay);
                            %                             sweep_delay_t = ((10 * sweep_mspdiv) * 1e-3) * (sweep_delay_chunks/sweep_mspdiv);
                            sweep_delay_t = (sweep_delay_chunks * sweep_mspdiv * 1e-3);% * sweep_t;
                            ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DataSweepTriggerDelayCustom = sweep_delay_t;
                        end
                    end
                end
            else
                error('not coded')
            end
        end

        if any('research_scs_train' == arrayfun(@(ix) ephys_out.Modes{ix}.Name, 1:length(ephys_out.Modes)))
            ix_mode = find(arrayfun(@(ix) ephys_out.Modes{ix}.Name, 1:length(ephys_out.Modes)) == "research_scs_train");
            ephys_info_local = ephys_info.Modes{ix_mode};
            ephys_out_local = ephys_out.Modes{ix_mode};
            % view.plot_channel_traces_with_events(ephys_out_local, 14)
            [ephys_info_local, ephys_out_local] = ...
                exc.merge_events_in_researsch_scs_train(ephys_info_local, ephys_out_local);
            ephys_info.Modes{ix_mode} = ephys_info_local;
            ephys_out.Modes{ix_mode} = ephys_out_local;

        end
        if isfield(exceptions, 'DataSweepTriggerDelayCustom')
            % was needed for cdmrp003
            [ephys_info, ephys_out] = ...
                exc.adjust_DataSweepTriggerDelayCustom(ephys_info, ephys_out, exceptions);
        end
        if any('research_scs_train' == arrayfun(@(ix) ephys_out.Modes{ix}.Name, 1:length(ephys_out.Modes)))
            [ephys_info, ephys_out] = ...
                exc.t0_adjustments(ephys_info, ephys_out, exceptions);
        end

        % Convert the trigger mode into something that looks like TES
        for ix_vec_mode = 1:length(ephys_out.Modes)
            for ix_trial = 1:length(ephys_out.Modes{ix_vec_mode}.Trials)
                if not(isfield(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli, 'DiscreteStimuli')), continue;end
                for ix_stimuli = 1:length(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli)
                    if contains(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, 'Trigger Out')
                        tes_temp = struct;
                        tes_temp.Name = 'Digitimer';
                        tes_temp.Displacement = 0;
                        tes_temp.Train1PulseCount = ephys_info.Modes{ix_vec_mode}.cx_count(ix_trial);
                        tes_temp.Train2PulseCount = 0;
                        tes_temp.SensedHiZ = 0;
                        cx_current = ephys_info.Modes{ix_vec_mode}.cx_current(ix_trial);
                        cx_voltage = ephys_info.Modes{ix_vec_mode}.cx_voltage(ix_trial);
                        if isnan(cx_current), cx_current = -1;end  % not sure - but things are getting really slow. Maybe this is why.
                        if isnan(cx_voltage), cx_voltage = -1;end  % not sure - but things are getting really slow. Maybe this is why.
                        tes_temp.SensedCurrent = cx_current;
                        tes_temp.SensedVoltage = cx_voltage;
                        if ephys_info.Modes{ix_vec_mode}.cx_stimulation_configuration(ix_trial) == "quad"
                            for ixq = 1:4
                                tes_temp.Outputs{ixq}.Label = sprintf('H%d', ixq);
                                tes_temp.Outputs{ixq}.OutputNumber = ixq;
                                tes_temp.Outputs{ixq}.PowerSetting = 'High';
                                tes_temp.Outputs{ixq}.OperationMode = 'Constant Current';
                                tes_temp.Outputs{ixq}.Usage = 'Ignore';  % this is annoying to set + redundant so ignoring for now.
                            end
                        end
                        for ix_pulse = 1:tes_temp.Train1PulseCount
                            tes_temp.ElectricalPulses{ix_pulse}.Displacement = ephys_info.Modes{ix_vec_mode}.cx_displacement(ix_pulse);
                            tes_temp.ElectricalPulses{ix_pulse}.Intensity = ephys_info.Modes{ix_vec_mode}.cx_current(ix_pulse);
                            tes_temp.ElectricalPulses{ix_pulse}.IntensityUnits = 'A';
                            tes_temp.ElectricalPulses{ix_pulse}.PulseWidth = ephys_info.Modes{ix_vec_mode}.cx_pw(ix_trial);
                            tes_temp.ElectricalPulses{ix_pulse}.Polarity = ephys_info.Modes{ix_vec_mode}.cx_polarity(ix_trial);
                            tes_temp.ElectricalPulses{ix_pulse}.Biphasic = ephys_info.Modes{ix_vec_mode}.cx_biphasic(ix_trial);
                        end
                        ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli} = tes_temp;

                    elseif contains(ephys_out.Modes{ix_vec_mode}.Trials{ix_trial}.Stimuli.DiscreteStimuli{ix_stimuli}.Name, 'TCS-9')
                        %
                    end
                end
            end
        end

        %%
        ephys_info.etc.redcap_id = str_redcapiid;

        %%
        % now save as json
        disp(p_out_ephys_data);
        savejson('Cases', {ephys_out}, char(p_out_ephys_data));  %  surgical studio format
        save(p_out_ephys_info, 'ephys_info');  % helper table for eeglab format
    end
end
end

function ephys_info_mode = blank_cortical(ephys_info_mode, ix_trial)
ephys_info_mode.cx_count(ix_trial) = 0;
ephys_info_mode.cx_ipi(ix_trial) = 0;
ephys_info_mode.cx_pw(ix_trial) = 0;
ephys_info_mode.cx_polarity(ix_trial) = string(missing);
ephys_info_mode.cx_biphasic(ix_trial) = false;  % default to false because missing is not allowed
ephys_info_mode.cx_voltage(ix_trial) = 0;
ephys_info_mode.cx_current(ix_trial) = 0;
ephys_info_mode.cx_frequency(ix_trial) = 0;
ephys_info_mode.cx_displacement(ix_trial) = 0;
ephys_info_mode.cx_stimulation_configuration(ix_trial) = string(missing);
ephys_info_mode.cx_stimulation_mep_side(ix_trial) = string(missing);
end

function ephys_info_mode = blank_spinal(ephys_info_mode, ix_trial)
ephys_info_mode.sc_count(ix_trial) = 0;
ephys_info_mode.sc_ipi(ix_trial) = 0;
ephys_info_mode.sc_pw(ix_trial) = 0;
ephys_info_mode.sc_polarity(ix_trial) = string(missing);
ephys_info_mode.sc_biphasic(ix_trial) = true;  % default to true because missing is not allowed
ephys_info_mode.sc_voltage(ix_trial) = 0;
ephys_info_mode.sc_current(ix_trial) = 0;
ephys_info_mode.sc_frequency(ix_trial) = 0;
ephys_info_mode.sc_displacement(ix_trial) = 0;
end

function ephys_info_mode = blank_peripheral(ephys_info_mode, ix_trial)
ephys_info_mode.pe_count(ix_trial) = 0;
ephys_info_mode.pe_ipi(ix_trial) = 0;
ephys_info_mode.pe_pw(ix_trial) = 0;
ephys_info_mode.pe_polarity(ix_trial) = string(missing);
ephys_info_mode.pe_biphasic(ix_trial) = true;  % default to true because missing is not allowed
ephys_info_mode.pe_voltage(ix_trial) = 0;
ephys_info_mode.pe_current(ix_trial) = 0;
ephys_info_mode.pe_frequency(ix_trial) = 0;
ephys_info_mode.pe_displacement(ix_trial) = 0;

ephys_info_mode.pe_laterality(ix_trial) = string(missing);
ephys_info_mode.pe_nerve(ix_trial) = string(missing);
end

function out = switch_anode_cathode(in)
if in == "Anode"
    out = "Cathode";
elseif in == "Cathode"
    out = "Anode";
else
    keyboard
    error('?');
end
end
% function save_local(f_out, record, v_local)
% % this is just to insulate v from v_local...
% v = v_local;
% save(f_out, 'record', 'v');
% end