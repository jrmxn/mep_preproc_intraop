function [info_auxf] = modify_auxf(participant, varargin)
d.mode = 'load';
d.info_auxf = [];
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);
v = inputParserStructureOverwrite(v);

%%
p_info_auxf = fullfile(getenv('D_PROC'), 'preproc_standard', char(participant), 'ephys', sprintf('%s_auxf.mat', participant));
if strcmpi(v.mode, 'load')
    generate_aux = generate_check(p_info_auxf, v.overwrite);
    if generate_aux
        p_info = fullfile(getenv('D_PROC'), 'preproc_standard', char(participant), 'ephys', sprintf('%s_info.mat', participant));
        info = load(p_info);info = info.info_flat;
        info_auxf = info(:, {'ix', 'participant'});
    else
        info_auxf = load(p_info_auxf);
        info_auxf = info_auxf.info_auxf;
    end
    
elseif strcmpi(v.mode, 'save')
    if isempty(v.info_auxf)
        error('what am I saving???');
    else
        if exist(p_info_auxf, 'file') == 2
            info_auxf = load(p_info_auxf);
            info_auxf = info_auxf.info_auxf;
            info_auxf_new = v.info_auxf;
            
            if not(height(info_auxf_new) == height(info_auxf))
                error(['Rejection table size has changed - run:\ndelete("%s");\n' ...
                    'OR\n' ...
                    'system("rm %s")\n' ...
                    'and try again.'], p_info_auxf, p_info_auxf);
            end
            assert(all(info_auxf_new.ix == info_auxf.ix), "?");
            assert(all(info_auxf_new.participant == info_auxf.participant), "?");
            
            new_column = info_auxf_new.Properties.VariableNames{contains(info_auxf_new.Properties.VariableNames, 'reject')};
            
            info_auxf.(new_column) = info_auxf_new.(new_column);  % overwrites if the same
            save(p_info_auxf, 'info_auxf');
        else
            info_auxf = v.info_auxf;
            save(p_info_auxf, 'info_auxf');
        end
    end
end
end

