function cfg_proc = toml_cfg_reader(f_cfg)
assert(exist(f_cfg, 'file') == 2, "Cannot find requested cfg: %s", f_cfg);
cfg_proc = toml.map_to_struct(toml.read(f_cfg));
if isfield(cfg_proc, 'parent')
    % if the config file specifies a parent, then load the parent and
    % update that with the config file specified.
    if not(isempty(cfg_proc.parent))
        assert(exist(cfg_proc.parent, 'file') == 2, "Canno find required parent cfg: %s", cfg_proc.parent);
        cfg_proc_parent = toml.map_to_struct(toml.read(cfg_proc.parent));
        cfg_proc = rmfield(cfg_proc, 'parent');
        cfg_proc = structure_update_simple(cfg_proc_parent, cfg_proc, false);
    end
end
end