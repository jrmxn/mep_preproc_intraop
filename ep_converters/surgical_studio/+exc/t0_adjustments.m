function [ephys_info, ephys_out] = t0_adjustments(ephys_info, ephys_out, exc)
% in scs_train data, if you made a table (in the json) to manually shift to the first
% stim pulse, then this does the correction
ix_mode = find(arrayfun(@(ix) ephys_out.Modes{ix}.Name, 1:length(ephys_out.Modes)) == "research_scs_train");
ephys_info_local = ephys_info.Modes{ix_mode};
ephys_out_local = ephys_out.Modes{ix_mode};
[ephys_info_local, ephys_out_local] = ...
    t0_adjustments_core(ephys_info_local, ephys_out_local, exc);
ephys_info.Modes{ix_mode} = ephys_info_local;
ephys_out.Modes{ix_mode} = ephys_out_local;

end


function [ephys_info_local, ephys_out_local] = t0_adjustments_core(ephys_info_local, ephys_out_local, exc)

check_corrections = true;

if isfield(exc, 't0_adjustments')
    adj = exc.t0_adjustments;
    adj = cell2table([cellfun(@(x) x.timestamp, adj, 'UniformOutput', false).', cellfun(@(x) x.value, adj, 'UniformOutput', false).']);
    adj.Var1 = datetime(adj.Var1);
else
    adj.Var1 = NaT;
    adj.Var2 = nan;
end

for ix_trial = 1:length(ephys_out_local.Trials)
    trial = ephys_out_local.Trials{ix_trial};
    f = ephys_info_local.sc_frequency(ix_trial);
    ix_trace_main = 15; % DELT PROB - might need adjusting if this gets used again...
    t_stim_time = 0.5;  %  TODO: should read this from .Stimuli.Duration
    g = seconds(adj.Var1 - ephys_info_local.datetime(ix_trial));
    g(g>0) = Inf;
    [ix_val, ix] = min(abs(g));
    if ix_val < 1
        adj_val = adj.Var2(ix);
    else
        adj_val = 0;
    end

    % adj_val = (-trial.Stimuli.DataSweepTriggerDelayCustom) / (1/f);
    adj_val(not(isfinite(adj_val))) = 0;

    t = (linspace(trial.Timestamp, trial.Timestamp + trial.Traces{ix_trace_main}.Sweep*1e6, trial.Traces{ix_trace_main}.TraceDataLength)) * 1e-6;
    t0 = -trial.Stimuli.DataSweepTriggerDelayCustom;

    n = floor(t_stim_time*f) - 1;

    if check_corrections
        figure(1);clf;
    end
    if check_corrections
        subplot(1, 3, 1);hold on;

        y_mep = abs(trial.Traces{ix_trace_main}.TraceData);

        plot(t, y_mep, 'Color', 'm');

        plot(ones(1, 2) * t(1) + t0, get(gca, 'ylim'), 'r--');
        vs = [0:1/f:n/f];
        for s = vs
            plot(ones(1, 2) * t(1) + (t0+s-5/f) , get(gca, 'ylim'), 'g--');
            plot(ones(1, 2) * t(1) + (t0+s+5/f), get(gca, 'ylim'), 'g--');
        end
        for s = vs
            plot(ones(1, 2) * t(1) + (t0+s), get(gca, 'ylim'), 'b--');
        end
        plot(ones(1, 2) * t(1) + (t0), get(gca, 'ylim'), 'r--');

        plot(t, y_mep, 'Color', 'm');

        title(sprintf('Original: %d', ix_trial));
        xlim([t(1), t(end)]);
    end

    if check_corrections
        subplot(1, 3, 2);hold on;

        y_mep = abs(trial.Traces{ix_trace_main}.TraceData);

        plot(t, y_mep, 'Color', 'm');

        plot(ones(1, 2) * t(1) + t0, get(gca, 'ylim'), 'r--');

        vs = [0:1/f:n/f]+adj_val/f;
        for s = vs
            plot(ones(1, 2) * t(1) + (t0+s-5/f) , get(gca, 'ylim'), 'g--');
            plot(ones(1, 2) * t(1) + (t0+s+5/f), get(gca, 'ylim'), 'g--');
        end
        for s = vs
            plot(ones(1, 2) * t(1) + (t0+s), get(gca, 'ylim'), 'b--');
        end
        plot(ones(1, 2) * t(1) + (t0), get(gca, 'ylim'), 'r--');

        plot(t, y_mep, 'Color', 'm');

        title(sprintf('Proposed: %d', ix_trial));
        xlim([t(1), t(end)]);
    end

    % the actual correction is here:
    if not(adj_val == 0)
        t_adj = adj_val/f;
        trial.Stimuli.DataSweepTriggerDelayCustom = trial.Stimuli.DataSweepTriggerDelayCustom - t_adj;
    end

    t0 = -trial.Stimuli.DataSweepTriggerDelayCustom;
    if check_corrections
        subplot(1, 3, 3);hold on;

        y_mep = abs(trial.Traces{ix_trace_main}.TraceData);

        plot(t, y_mep, 'Color', 'm');

        plot(ones(1, 2) * t(1) + t0, get(gca, 'ylim'), 'r--');
        vs = [0:1/f:n/f];
        for s = vs
            plot(ones(1, 2) * t(1) + (t0+s-5/f) , get(gca, 'ylim'), 'g--');
            plot(ones(1, 2) * t(1) + (t0+s+5/f), get(gca, 'ylim'), 'g--');
        end
        for s = vs
            plot(ones(1, 2) * t(1) + (t0+s), get(gca, 'ylim'), 'b--');
        end
        plot(ones(1, 2) * t(1) + (t0), get(gca, 'ylim'), 'r--');

        plot(t, y_mep, 'Color', 'm');

        title(sprintf('Corrected: %d', ix_trial));
        xlim([t(1), t(end)]);
    end

    % for ix_trace = 1:length(trial.Traces)
    %     if not(adj_val == 0)
    %         t_adj = adj_val/f;
    %         n_adj = round(t_adj/median(diff(t)));
    %         trial.Traces{ix_trace}.TraceData = circshift(trial.Traces{ix_trace}.TraceData, -n_adj);
    %         if n_adj <= 0
    %             trial.Traces{ix_trace}.TraceData(1:abs(n_adj)) = nan;
    %         else
    %             trial.Traces{ix_trace}.TraceData(end-abs(n_adj)+1:end) = nan;
    %         end
    %     end
    % end
    ephys_out_local.Trials{ix_trial} = trial;



end
end