function cell_electrode = group_electrodes(cell_electrode)

cell_electrode = strrep(cell_electrode, 'CEDL-2PDINX-101', 'catheter');
cell_electrode = strrep(cell_electrode, 'double-ball-tip-302431-000', 'handheld');
cell_electrode = strrep(cell_electrode, 'PN-3600-00', 'concentric');


end

