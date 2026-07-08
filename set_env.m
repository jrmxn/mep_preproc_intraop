function set_env
if ispc
    userDir = winqueryreg('HKEY_CURRENT_USER',...
        ['Software\Microsoft\Windows\CurrentVersion\' ...
        'Explorer\Shell Folders'],'Personal');
    userDir = fileparts(userDir);
else
    userDir = char(java.lang.System.getProperty('user.home'));
end
setenv('D_USER', userDir);

% Load settings from env.json
local_dir = fileparts(mfilename('fullpath'));
parent_dir = fileparts(local_dir);
env_file_parent = fullfile(parent_dir, 'env.json');
env_file_local = fullfile(local_dir, 'env.json');

if isfile(env_file_parent)
    env_file = env_file_parent;
elseif isfile(env_file_local)
    env_file = env_file_local;
else
    env_file = '';
end

if isfile(env_file)
    fid = fopen(env_file, 'r');
    raw = fread(fid, inf);
    str = char(raw');
    fclose(fid);
    env_data = jsondecode(str);
    
    fields = fieldnames(env_data);
    for i = 1:numel(fields)
        setenv(fields{i}, env_data.(fields{i}));
    end
else
    warning('env.json not found! Please create one based on the README.');
end

%%
if ~isempty(getenv('D_GIT'))
    addpath(genpath(fullfile(getenv('D_GIT'), 'auxf')));
end

%%
if isempty(getenv('DATETIME_SESSION'))
    % get a datetime, but only once per session
    setenv('DATETIME_SESSION', datestr(datetime, 'YYYY-mm-DD'));
end

%%
str_v_headless = 'V_HEADLESSS';
str_v_figvisible = 'V_FIGVISIBLE';
if string(java.lang.System.getProperty( 'java.awt.headless' )) == "true"
    setenv(str_v_headless, 'true');
    setenv(str_v_figvisible, 'off');
else
    setenv(str_v_headless, 'false');
    setenv(str_v_figvisible, 'on');
end

end