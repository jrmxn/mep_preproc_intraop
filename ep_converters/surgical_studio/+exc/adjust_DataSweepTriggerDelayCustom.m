function [ephys_info, ephys_out] = adjust_DataSweepTriggerDelayCustom(ephys_info, ephys_out, exceptions)

vec_modes_local = arrayfun(@(ix) ephys_out.Modes{ix}.Name, 1:length(ephys_out.Modes));
fn_mode = fieldnames(exceptions.('DataSweepTriggerDelayCustom'));
for ix_fn_mode = 1:length(fn_mode)
    str_mode_local = fn_mode{ix_fn_mode};
    value_adjust = exceptions.('DataSweepTriggerDelayCustom').(str_mode_local);
    ix_mode = find(str_mode_local == vec_modes_local);

    for ix_trial = 1:length(ephys_out.Modes{ix_mode}.Trials)
        ephys_out.Modes{ix_mode}.Trials{ix_trial}.Stimuli.DataSweepTriggerDelayCustom = value_adjust;
    end
end

end
