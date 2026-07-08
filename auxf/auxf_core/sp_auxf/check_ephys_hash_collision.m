function check_ephys_hash_collision(ephys)
vec_hash = [];
for ix = 1:length(ephys)
    hash = ephys{ix}.hash;
    hash(hash == 0) = [];
    hash(not(isfinite(hash))) = [];
    vec_hash = [vec_hash, hash];
end
assert(length(vec_hash) == unique(length(vec_hash)), 'There appears to be a hash collision!');
end