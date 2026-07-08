function str_redcapiid = sp_check_redcapid(p)
str_redcapiid_scap = check_redcapid_scap(p, 'PTIO**');
str_redcapiid_cdmrp = check_redcapid_scap(p, 'PTSC**');
str_redcapiid_mapping = check_redcapid_mapping(p, 'P_**');

if length(str_redcapiid_scap) > 0
    str_redcapiid = str_redcapiid_scap;
elseif length(str_redcapiid_cdmrp) > 0
    str_redcapiid = str_redcapiid_cdmrp;
elseif length(str_redcapiid_mapping) > 0
    str_redcapiid = str_redcapiid_mapping;
else
    error('missing redcap id:\n%s', p);
end
    
end

function str_redcapiid = check_redcapid_scap(p, p_code)
p_redcapid = glob(fullfile(char(p), p_code));
if length(p_redcapid) == 1
    [~, str_redcapiid] = fileparts(p_redcapid{1});
    if length(str_redcapiid) > 1
        str_redcapiid = strsplit(str_redcapiid, '_');
        str_redcapiid = str_redcapiid{1};
    else
        % should already be ok
    end
else
    str_redcapiid = "";
end
end

function str_redcapiid = check_redcapid_mapping(p, p_code)
p_redcapid = glob(fullfile(char(p), p_code));
if length(p_redcapid) == 1
    [~, str_redcapiid] = fileparts(p_redcapid{1});
    if length(str_redcapiid) > 1
        str_redcapiid = strsplit(str_redcapiid, '_');
        str_redcapiid = char(str_redcapiid{1} + "_" + str_redcapiid{2});
    else
        % should already be ok
    end
else
    str_redcapiid = "";
end
end