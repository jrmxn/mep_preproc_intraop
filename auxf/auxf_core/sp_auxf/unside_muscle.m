function s = unside_muscle(s)
if ismissing(s)
    return
end
if isstring(s)
    input_is_string = true;
end

if input_is_string
    assert(length(size(s)) == 2, '?');
    assert(any(size(s) == 1), '?');
    s = s(:);
end

s = char(s);
s = s(:, 2:end);

if input_is_string
    s = string(s);
    s = strtrim(string(s));
end
end