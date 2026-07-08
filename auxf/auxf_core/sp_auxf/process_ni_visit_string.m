function [select_visit, is_numeric_visit] = process_ni_visit_string(select_visit, select_visit_default)
if nargin < 2
    select_visit_default = "ie-visit-last";
end
str_visit_error = 'Something wrong with the way you formatted the visit string!';
approved_set = ["pst-visit-all", "custom-visit", "paired-rec-visit-last-most", "ie-visit-last-most", "tms-visit-last-most", "tscs-visit-last-most", "last", "ie-visit-last", "any-visit-last", ...
    "custom-visit-TMS", "custom-visit-TSS", "custom-visit-TMS-REC", "custom-visit-TSS-REC", "all-csv-only"];  % may need to add -RE2, -RE3 if you want
if isempty(select_visit)
    select_visit = select_visit_default;  %"ie-visit-last";
    is_numeric_visit = nan;
    fprintf('Visit not specified - choosing last one!!!\n\n');
elseif any(select_visit == approved_set)
    % OK as is
    is_numeric_visit = false;
else
    is_numeric_visit = true;
    pattern = '([a-zA-Z]+)\s*(\d+)';
    try
        [tokens, matches] = regexp(select_visit, pattern, 'tokens', 'match');
    catch
        error(str_visit_error);
    end
    assert(length(tokens{1}) == 2, str_visit_error);
    tokens{1} = string(tokens{1});  % cell or string -> string

    tokens{1}(2) = string((str2double(tokens{1}{2})));  % gets rid of leading zeros
    if tokens{1}(1) == "visit"
        % ok
    elseif strcmpi(tokens{1}(1), 'V')
        tokens{1}(1) = 'visit';
    else
        error(str_visit_error);
    end
    select_visit = sprintf('%s%s', tokens{1}(1), tokens{1}(2));
end
end