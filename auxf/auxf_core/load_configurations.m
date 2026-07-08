function [config_struct_in, p_config] = load_configurations(f_config, varargin)
d.open_config_file = false;
d.verbose = true;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);
v = inputParserStructureOverwrite(v);

%%
p_config = which(f_config, '-all');
if length(p_config) > 1
    disp(p_config);
    error('^ You should not have more than one config file on the path ^');
elseif isempty(p_config)
    error('Could not find:\n%s\n', f_config);
else
    p_config = p_config{1};
    if v.verbose
        fprintf('Loading config from:\n%s\n', p_config);
    end
end
[~, ~, ext] = fileparts(p_config);
if strcmpi(ext, '.json')
    config_struct_in = loadjson(p_config);
elseif strcmpi(ext, '.toml')
    config_struct_in = toml.map_to_struct(toml.read(p_config));
else
    error('?')
end
config_struct_cfg = config_struct_in.cfg;
config_struct_in = config_struct_in.main_conditions;
if not(iscell(config_struct_in))
    config_struct_in = {config_struct_in};
end
vec_keep = false(size(config_struct_in));
for ix = 1:length(config_struct_in)
    fn = fieldnames(config_struct_in{ix});
    if isfield(config_struct_in{ix}, 'enabled')
        vec_keep(ix) = config_struct_in{ix}.enabled;
    else
        vec_keep(ix) = true;
    end
    for ix_fn = 1:length(fn)
        val_name = fn{ix_fn};
        val = config_struct_in{ix}.(val_name);

        % convert cell of chars to vector of string
        if iscell(val)
            if not(isempty(val))
                if ischar(val{1})
                    val = string(val);
                    if (lower(val) == "all"), val = string([]);end
                end
            end
        end

        config_struct_in{ix}.(val_name) = val;
    end
end
config_struct_in = config_struct_in(vec_keep);
if not(config_struct_cfg.allow_multiple_enabled)
    assert(length(config_struct_in) == 1, "Only (and at least) one option can be enabled at the time!");
    config_struct_in = config_struct_in{1};
end

if v.open_config_file
    if isunix
        str_text_editor = 'gedit';
        system(sprintf('env -u LD_LIBRARY_PATH %s %s &', str_text_editor, p_config));
    else
        str_text_editor = 'notepad++';
        system(sprintf('%s %s', str_text_editor, p_config));
    end

    pause(0.5);
    [config_struct_in, ~] = load_configurations(f_config, 'open_config_file', false, 'verbose', false);
end
end