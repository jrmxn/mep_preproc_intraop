function veco = musclestruct2musclevec(si, vec_muscle)
fn = fieldnames(si);
veco = nan(size(vec_muscle(:).'));
for ix_muscle = 1:length(vec_muscle)
    str_muscle = vec_muscle(ix_muscle);
    if any(fn == str_muscle)
        case_fn = str_muscle == vec_muscle;
        veco(case_fn) = si.(str_muscle);
    end
end
end