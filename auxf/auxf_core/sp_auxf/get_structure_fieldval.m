function var_out = get_structure_fieldval(var_structure, var_field, var_default)
    if not(isfield(var_structure, var_field))
        var_out = var_default;
    elseif isempty(var_structure.(var_field))
        var_out = var_default;
    else
        var_out = var_structure.(var_field);
    end
end