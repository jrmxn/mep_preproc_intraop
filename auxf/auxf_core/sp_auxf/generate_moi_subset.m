function moi_out = generate_moi_subset(moi, vec_muscle_unsided)
moi = eval(moi);
% just re-order them into the usual order
moi_out = moi;
ix_count = 1;
for ix_vec_muscle_unsided = 1:length(vec_muscle_unsided)
    case_moi = moi == vec_muscle_unsided(ix_vec_muscle_unsided);
    if sum(case_moi)==1
        moi_out(ix_count) = moi(case_moi);
        ix_count = ix_count + 1;
    end
end
end