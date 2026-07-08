function case_muscle_legs = isa_leg(vec_muscle)
vec_muscle_legs = ["TA", "EDB", "AH"];
vec_muscle_legs = ["L" + vec_muscle_legs, "R" + vec_muscle_legs];
case_muscle_legs = false(size(vec_muscle));
for ix_cell_legs = 1:length(vec_muscle_legs)
    case_muscle_legs = or(case_muscle_legs, strcmpi(vec_muscle, vec_muscle_legs(ix_cell_legs)));
end
end