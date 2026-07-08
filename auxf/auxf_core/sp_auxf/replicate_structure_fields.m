function Y = replicate_structure_fields(X)
Y = struct;
if isnumeric(X)
    Y = nan(size(X));
else
vec_fn1 = fieldnames(X);
for ix_vec_fn1 = 1:length(vec_fn1)
    x_class = class(X.(vec_fn1{ix_vec_fn1}));
    if ischar(x_class)
        v = '';
    elseif iscell(x_class)
        v = {};
    else
        v = [];
    end
    Y.(vec_fn1{ix_vec_fn1}) = v;
end
end
end