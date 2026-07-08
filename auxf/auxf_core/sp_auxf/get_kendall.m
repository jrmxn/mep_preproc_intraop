function innervation = get_kendall
VariableNames = {'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'T1'};
RowNames = {'trap', 'bicep', 'tric', 'apb', 'adm', 'ta', 'edb' 'ah'};

innervation = array2table(zeros(length(RowNames), length(VariableNames)));
innervation.Properties.VariableNames = VariableNames;
innervation.Properties.RowNames = RowNames;


innervation.('C2')('trap') = 1/3;
innervation.('C3')('trap') = 1.0;
innervation.('C4')('trap') = 1.0;

innervation.('C5')('bicep') = 1.0;
innervation.('C6')('bicep') = 1.0;

innervation.('C6')('tric') = 1/3;
innervation.('C7')('tric') = 1.0;
innervation.('C8')('tric') = 1.0;
innervation.('T1')('tric') = 1/3;

innervation.('C6')('apb') = 1/3;
innervation.('C7')('apb') = 1/3;
innervation.('C8')('apb') = 1/3;
innervation.('T1')('apb') = 1/3;

innervation.('C7')('adm') = 1/3;
innervation.('C8')('adm') = 1.0;
innervation.('T1')('adm') = 1.0;
end