function sp_scade_ss(d_data_coded, str_sub)
if nargin<2
    error('you need to specifiy subject as deid: P_...');
elseif isempty(str_sub)
    error('you need to specifiy subject as deid: P_...');
end
hWaitbar = waitbar(0, 'Hit cancel when all events are captured.', 'Name', 'Solving problem','CreateCancelBtn','delete(gcbf)');

disp('MAXIMIZE CASCADE ');
disp('uncheck view as recorded (in view)');
disp('in Edit->view setup, delete and uncheck all (for d-spinal)')
disp('lock windows');
disp('Hit cancel on the wait bar when ended');
disp('hit f5 to continue then alt-tab to cascade');
keyboard;
pause(3);

%%
d_data_img = fullfile(d_data_coded, str_sub, 'ephys', 'cadwell-elite-pro', 'data_cascade_event_ss');

%%
disp(str_sub);
d_temp = tempname;
mkdir(d_temp);
%Initialize the java engine
import java.awt.*;
import java.awt.event.*;
%Create a Robot-object to do the key-pressing
%Commands for pressing keys:
% If the text cursor isn't in the edit box allready, then it
% needs to be placed there for ctrl+a to select the text.
% Therefore, we make sure the cursor is in the edit box by
% forcing a mouse button press:
%             rob.mousePress(InputEvent.BUTTON1_MASK );
%             rob.mouseRelease(InputEvent.BUTTON1_MASK );
% CONTROL + A :
%             rob.keyPress(KeyEvent.VK_CONTROL)
%             rob.keyPress(KeyEvent.VK_A)
%             rob.keyRelease(KeyEvent.VK_A)
%             rob.keyRelease(KeyEvent.VK_CONTROL)
robot = java.awt.Robot();
sc = [0, 0, 3000, 2000];

% Take screen capture
h = 100;
bottom_margin = 150;
w = sc(3);
right_margin = 0;

pos = [sc(3) - right_margin - w, sc(4)-h-bottom_margin, w, h]; % [left top width height]
rect = java.awt.Rectangle(pos(1),pos(2),pos(3),pos(4));
% Convert to an RGB image

ix_step = 1;
while true
    robot.keyPress(KeyEvent.VK_RIGHT)
    robot.keyRelease(KeyEvent.VK_RIGHT)
    pause(1.5);
    for ix_sample = 1:20
        cap = robot.createScreenCapture(rect);
        rgb = typecast(cap.getRGB(0,0,cap.getWidth,cap.getHeight,[],0,cap.getWidth),'uint8');
        imgData = zeros(cap.getHeight,cap.getWidth,3,'uint8');
        
        
        imgData(:,:,1) = reshape(rgb(3:4:end),cap.getWidth,[])';
        imgData(:,:,2) = reshape(rgb(2:4:end),cap.getWidth,[])';
        imgData(:,:,3) = reshape(rgb(1:4:end),cap.getWidth,[])';
        % Show or save to file
        % close all;
        % imshow(imgData)
        imwrite(imgData, fullfile(d_temp, sprintf('f%04d_s%03d.png', ix_step, ix_sample)), 'Compression', 'none');
        if (ix_sample == 1)||(ix_sample == 2)
            pause(0.125);
        else
            pause(0.25);
        end
    end
    ix_step = ix_step + 1;
    
    drawnow;
    if ~ishandle(hWaitbar)
        % Stop the if cancel button was pressed
        disp('Stopped by user... saving');
        break;
    end
end

try
    zip(d_data_img, {'*.png'}, d_temp);
catch
    disp('Handle this manually! (probably drive not accessible?)');
    keyboard;
end

rmdir(d_temp, 's');
disp('Done');
%%
% clc
%             rob.keyPress(KeyEvent.VK_CONTROL)
% rob.keyPress(KeyEvent.VK_ALT)
% rob.keyPress(KeyEvent.VK_TAB)
%             rob.keyPress(KeyEvent.VK_ENTER)

% rob.keyRelease(KeyEvent.VK_ENTER)
% rob.keyRelease(KeyEvent.VK_TAB)
% rob.keyRelease(KeyEvent.VK_ALT)
%             rob.keyRelease(KeyEvent.VK_CONTROL)

end