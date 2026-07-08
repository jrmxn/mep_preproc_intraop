function sp_cascade_ss2stimamp(d_data_coded, varargin)
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);
%%

cell_sub = dir(d_data_coded);
cell_sub = cell_sub([cell_sub.isdir]);
cell_sub(strcmpi({cell_sub.name}, '.')) = [];
cell_sub(strcmpi({cell_sub.name}, '..')) = [];
cell_sub = {cell_sub.name};
cell_sub = cell_sub(~strcmpi(cell_sub, 'auxf'));

% f_data_mat = dir(d_data_img);
% f_data_mat = f_data_mat(contains({f_data_mat.name}, '.zip'));
% f_data_mat = f_data_mat(not([f_data_mat.isdir]));
% cell_sub = {f_data_mat.name};
for ix_cell_sub = 1:length(cell_sub)
    str_sub = cell_sub{ix_cell_sub};
    
    d_data_img = fullfile(d_data_coded, str_sub, 'ephys', 'cadwell-elite-pro', 'data_cascade_event_ss');
    d_data_mat = fullfile(d_data_coded, str_sub, 'ephys', 'cadwell-elite-pro', 'data_deid_mat');
    
    f_out_mat = fullfile(d_data_img, str_sub); % this will be a mat
    f_out_xlsx = fullfile(d_data_img, [str_sub '_write.xlsx']); % this will be a mat
    d_imgsub = fullfile(d_data_img, [str_sub, '.zip']);
    
    %%
    % load each image and check if it has the potential to be important...
    % save the results into a mat file
    do_loadimages = generate_check_mat(f_out_mat, v.overwrite);
    if do_loadimages
        d_temp = tempname;
        mkdir(tempname);
        unzip(d_imgsub, d_temp);
        %
        cell_img = dir(d_temp);
        cell_img = cell_img(not([cell_img.isdir]));
        cell_img = {cell_img.name};
        %
        N_max = 1000;
        ix_count = 0;
        msg_prev = '';
        cell_msg = cell(1, length(cell_img));
        fprintf('Check to see if there is info - do not worry about decoding quality yet!!!\n');
        for ix_cell_img = 1:length(cell_img)
            f = fullfile(d_temp, cell_img{ix_cell_img});
            im = imread(f);
            % load all files with potential message into memory
            if ix_cell_img==1
                X = zeros([size(im), N_max], 'uint8');
            end
            o = ocr(im, 'TextLayout',  'Block');
            
            msg = strjoin(o.Words, ' ');
            if and((length(o.Words) > 1), not(strcmpi(msg_prev, msg)))
                ix_count = ix_count + 1;
                X(:, :, :, ix_count) = im;
                msg_prev = msg;
                fprintf('%04d %s\n', ix_count, msg);
            end
        end
        %
        rm_empty = squeeze(all(X==0, [1, 2, 3]));
        X(:, :, :, rm_empty) = [];
        save(f_out_mat, 'X');
        %
        [status, message, messageid] = rmdir(d_temp, 's');
        fprintf('Initial check done!\n');
    else
        X = load(f_out_mat);
        X = X.X;
    end
    
    %%
    
    if not(exist(f_out_xlsx, 'file') == 2)||v.overwrite
        T = table;
        dt_t1 = NaT;
        dt_t2 = NaT;
        
        record = load(fullfile(d_data_mat, str_sub));
        record = record.record;
        
        % btw lots of stuff will break if the clock strikes midnight...
        day_start = dateshift(record(1).datetime, 'start', 'day');
        
        for ix_img = 1:size(X, 4)
            im = X(:, :, :, ix_img);
            
            % crop image !!!
            im = im(1:96, :, :);
            % figure out background !!!
            im_background = smooth(mean(abs(im - 160), [1, 3]), 10) < 25;
            
            
            im = im(:, not(im_background), :);
            im = imresize(im, 3);
            o = ocr(im, 'TextLayout', 'Block');
            
            msg = strjoin(o.Words, ' ');
            
            fprintf('%04d %s\n', ix_img, msg);
            
            msg_s = msg;
            
            if ix_img == 1
                keyboard;
                % temporary - so that next time I run this I figure out the
                % necessary code to replace 'O.' into '0.' and 'OmA' into
                % '0mA'
            end
            
            [msg_s, dt_t1, str_t1] = msg_s_to_time(msg_s);
            
            [msg_s, dt_t2, str_t2] = msg_s_to_time(msg_s);
            
            % if they are both nan, assume that we actually know the time
            % (t2)
            if and(isnan(dt_t2), not(isnan(dt_t1)))
                dt_t2 = duration(strtrim(str_t1), 'InputFormat', 'hh:mm:ss');
                dt_t1 = nan * seconds;
            end
            
            dt_t2 = dt_t2 + day_start;
            
            msg_s = fliplr(deblank(fliplr(msg_s)));
            
            r = regexp(msg_s, '.+\s(\d\.*\d*mA)', 'tokens');
            
            if not(isempty(r))
                sc_stim_amp = r{1}{1};
                sc_stim_amp = str2double(erase(sc_stim_amp, 'mA'));
                fprintf('Stim amp: %0.1fmA\n', sc_stim_amp);
            else
                sc_stim_amp = nan;
            end
            
            try
                T.duration(ix_img) = dt_t1;
                
                T.datetime(ix_img) = dt_t2;
            catch
                keyboard
            end
            T.sc_stim_amp(ix_img) = sc_stim_amp;
            T.msg_split{ix_img} = msg_s;
            T.msg_full{ix_img} = msg;
            
        end
        
        [~, ix_datetime] = sort(T.datetime);
        T = T(ix_datetime, :);
        
        writetable(T, f_out_xlsx);
    end
end
end
function [msg_s, t, str_t] = msg_s_to_time(msg_s)
m = '\s*(\s*\d\s*\d\s*:\s*\d\s*\d\s*:\s*\d\s*\d).+';
r = regexp(msg_s, m, 'tokens');
if not(isempty(r))
    str_t = r{1}{1};
    msg_s = erase(msg_s, str_t);
    str_t(str_t==32) = [];
    t = duration(strtrim(str_t), 'InputFormat', 'hh:mm:ss');
else
    t = nan * seconds;
    str_t = '';
end
end