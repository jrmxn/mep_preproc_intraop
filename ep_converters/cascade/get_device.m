function [d_sub_device, str_device, skip] = get_device(d_sub_ephys)
str_device = '';
d_sub_device = '';
skip = false;
fstruct_device = dir(d_sub_ephys);
if isempty(fstruct_device)
    fprintf('Skipping, probably json exported from SS. Import with other software.\n');
    skip = true;
    return
end

cell_device = {fstruct_device.name};
cell_device = cell_device([fstruct_device.isdir]);

if any(strcmpi(cell_device, 'cadwell-elite-pro'))
    str_device = 'cadwell-elite-pro';
elseif  any(strcmpi(cell_device, 'cadwell-iomax'))
    str_device = 'cadwell-iomax';
else
    str_device = '';
    return
end

d_sub_device = char(fullfile(d_sub_ephys, str_device));

end