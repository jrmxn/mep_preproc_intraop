function T_amp = sp_stimamp_extract(p_zip, p_out, varargin)
newadjs = [0, 10, 0, 0];
d.x0y0wh_amp = [200, 326, 400, 30] + newadjs; %  old version: [600, 980, 400, 30]
d.x0y0wh_set = [40, 473, 100, 30] + newadjs; %  old version: [400, 1123, 100, 30]
d.x0y0wh_timebase = [200, 250, 400, 30] + newadjs; %  old version: [600, 980, 400, 30]
d.overwrite = false;
d.d_overwrite = struct;

%% Parse input
[v, d] = inputParserCustom(d, varargin);clear d;
v = inputParserStructureOverwrite(v);

%%
x0y0wh_amp = v.x0y0wh_amp;
x0y0wh_set = v.x0y0wh_set;
x0y0wh_timebase = v.x0y0wh_timebase;

%%
do_stimamp_generate = generate_check(p_out, v.overwrite);
if do_stimamp_generate
    d_temp = tempname;
    mkdir(tempname);
    try
        unzip(p_zip, d_temp);
        cell_img = glob(fullfile(d_temp, '*.tif'));
        cell_msg = cell(1, length(cell_img));
        T_amp = array2table(nan(length(cell_img), 1));
        T_amp.Properties.VariableNames{1} = 'stimamp';
        T_amp.set(:) = nan;
        T_amp.file(:) = nan;
        T_amp.duplicate(:) = false;
        T_amp.timebase(:) = nan;
        
        for ix_cell_img = 1:length(cell_img)
            f = fullfile(cell_img{ix_cell_img});
            [~, f_name, ~] = fileparts(f);
            
            im = imread(f);
            
            str_expression = 'x(?<str_fnumber>\d*)';
            tokens = regexp(f_name, str_expression, 'names');
            str_fnumber = tokens.str_fnumber;
            
            im_stimamp = im(x0y0wh_amp(2):x0y0wh_amp(2) + x0y0wh_amp(4), x0y0wh_amp(1):x0y0wh_amp(1) + x0y0wh_amp(3), :);
            % I have no idea how these three lines work or how I came up with them,
            % but they work great...
            im_background = smooth(mean(abs(im_stimamp - 160), [1, 3]), 10) < 25;
            im_stimamp = im_stimamp(:, not(im_background), :);
            if isempty(im_stimamp)
                keyboard;
                continue;
            end
            o = ocr(im_stimamp, 'TextLayout',  'Block');
            msg = strjoin(o.Words, ' ');
            str_expression = '.*[\(\[](?<str_amp>.*)\s*mA[\]\)]';
            tokens = regexp(msg, str_expression,'names');
            try
                str_amp = strrep(lower(tokens.str_amp), 'o', '0');
            catch
                %                 if it's a one off, handle it manually
                %                 (remember it should be a string at this
                %                 stage)
                fprintf('%04d, setting timebase of %s to ', ix_cell_img, msg);
                str_amp_new = input('');
                str_amp_new = char(string(str_amp_new));
                str_amp = str_amp_new;
            end
            str_amp = strtrim(str_amp);
            
            if str_amp(1) == '0' && not(any(str_amp == '.')) && length(str_amp)>1
                % probably the . is missing...
                str_amp_new = [str_amp(1), '.', str_amp(2:end)];
                fprintf('%04d, replacing %s with %s\n', ix_cell_img, str_amp, str_amp_new);
                str_amp = str_amp_new;
            end
            
            if strcmpi(str_amp, '4.e')
                fprintf('Swapping 4.e with 4.6\n');
                str_amp = strrep(str_amp, '4.e', '4.6');
            end
            
            
            im_set = im(x0y0wh_set(2):x0y0wh_set(2) + x0y0wh_set(4), x0y0wh_set(1):x0y0wh_set(1) + x0y0wh_set(3), :);
            im_background = smooth(mean(abs(im_set - 160), [1, 3]), 10) < 25;
            im_set = im_set(:, not(im_background), :);
            im_set = imresize(im_set, 3);
            o = ocr(im_set, 'TextLayout',  'Block');
            msg = strjoin(o.Words, ' ');
            str_expression = '.*Set\s?(?<str_set>\d*o*O*)';  % the o* is if a trailing 0 is read as an o
            tokens = regexp(msg, str_expression,'names');
            try
                str_set = strrep(lower(tokens.str_set), 'o', '0');
            catch
                keyboard;
            end
            
            im_timebase = im(x0y0wh_timebase(2):x0y0wh_timebase(2) + x0y0wh_timebase(4), x0y0wh_timebase(1):x0y0wh_timebase(1) + x0y0wh_timebase(3), :);
            im_background = smooth(mean(abs(im_timebase - 160), [1, 3]), 10) < 25;
            im_timebase = im_timebase(:, not(im_background), :);
            im_timebase = imresize(im_timebase, 3);
            o = ocr(im_timebase, 'TextLayout',  'Block');
            msg = strjoin(o.Words, ' ');
            str_expression = '(?<str_timebase>\d+)\sms\/div.*';
            tokens = regexp(msg, str_expression,'names');
            try
                str_timebase = strrep(lower(tokens.str_timebase), 'o', '0');
            catch
                % if it's a one off, handle it manually
                fprintf('%04d, setting timebase of %s to ', ix_cell_img, msg);
                str_timebase_new = input('');
                str_timebase_new = char(string(str_timebase_new));
                str_timebase = str_timebase_new;
            end
            
            int_f_number = str2double(str_fnumber);
            int_amp = str2double(str_amp);
            if isnan(int_amp)
                fprintf('Failed to convert amp: %s\n Look at generated figure, please enter:', str_amp);
                clf;imagesc(im_stimamp);title(ix_cell_img);drawnow;
                int_amp_alt = input('');
                if isempty(int_amp_alt)
                    int_amp_alt = int_amp_alt_prev;
                    fprintf('\b %0.1f\n', int_amp_alt);
                end
                int_amp = int_amp_alt;
                int_amp_alt_prev = int_amp;
            end
            int_set = str2double(str_set);
            int_timebase = str2double(str_timebase);
            
            if int_amp > 10
                % probably another x.x getting read as xx
                % just fix it manually since rare.
                % set int_amp_new
                fprintf('%04d, replacing %d with ', ix_cell_img, int_amp);
                int_amp_new = input('');
                if isempty(int_amp_new)
                    int_amp_new = int_amp / 10;
                    fprintf('%0.2f\n', int_amp_new);
                end
                int_amp = int_amp_new;
            end
            
            
            T_amp.file(ix_cell_img) = int_f_number;
            T_amp.stimamp(ix_cell_img) = int_amp;
            T_amp.set(ix_cell_img) = int_set;
            T_amp.timebase(ix_cell_img) = int_timebase;
            
            if any(T_amp.set(1:ix_cell_img-1) == int_set)
                T_amp.duplicate(ix_cell_img) = true;
            end
            
        end
        [status, message, messageid] = rmdir(d_temp, 's');
    catch errt
        [status, message, messageid] = rmdir(d_temp, 's');
        rethrow(errt);
    end
    [~, ix_sort] = sort(T_amp.file);
    T_amp = T_amp(ix_sort, :);
    T_amp(T_amp.duplicate, :) = [];
    writetable(T_amp, p_out);
else
    opts = detectImportOptions(p_out, "ReadRowNames", false);
    T_amp = readtable(p_out, opts);
end
end
