function [cmap_mus_dark, cmap_mus_light, vec_muscle] = get_cmap_muscles_alt
vec_muscle = ["Trapezius", "Deltoid", "Biceps", "Triceps", "ECR", "FCR", "APB", "ADM", "TA", "EDB", "AH", "FDI"];


c = get_cmap;

cmap_mus_dark = [...
    adjust_brightness([    0.6350    0.0780    0.1840], 0.5);  % trapz
    [1, 133, 113]/255; % delt
    [166, 97, 26]/255; % biceps
    [44, 123, 182]/255; % triceps
    adjust_brightness([    75    0.    146]/256, 0.4);     % ecr - % old blue?
    adjust_brightness([    0.5000    0.5000    0.5000], 0.3); % fcr - olf green?
    [208, 28, 139]/255;  % apb
    [77, 172, 38]/255;  % adm
    [215, 25, 28]/255; %  ta
    [123, 50, 148]/255; % edb
    adjust_brightness([153, 79, 0]/256, 0.4);  % ah
    [23, 54, 124]/255; % edb
    ];

cmap_mus_light = [...
    adjust_brightness([    0.6350    0.0780    0.1840], 0.8);  % trapz
    [128, 205, 193]/255; %  delt
    [223, 194, 125]/255;  % biceps
    [171, 217, 233]/255;  % triceps
    adjust_brightness([    75    0.    146]/256, 0.6); % ecr
    adjust_brightness([    0.5000    0.5000    0.5000], 0.6); % fcr
    [241, 182, 218]/255; % apb
    [184, 225, 134]/255; % adm
    [253, 174, 97]/255; %  ta
    [194, 165, 207]/255; %  edb
    adjust_brightness([153, 79, 0]/256, 0.6); % ah
    adjust_brightness([23, 54, 124]/256, 0.6); % ah
    ];


T_color = array2table(vec_muscle(:));
T_color.cmap_mus_light = cmap_mus_light;
T_color.cmap_mus_dark = cmap_mus_dark;
T_color.cmap_mus_light_hex = rgb2hex(cmap_mus_light);
T_color.cmap_mus_dark = rgb2hex(cmap_mus_dark);

% cmap_mus_dark = [...
%     adjust_brightness([    0.3010    0.7450    0.9330], 0.4);      %%       [0    0.4470    0.7410];
%     adjust_brightness([0.8147    0.9058    0.1270], 0.4);
%     [0.4940    0.1840    0.5560];
%     c.green4;%[         0    0.5000         0];
%     [         0         0         0    ];     % temp
%     [         1         0         0  ];       % temp
%     [    0.6000    0.2294    0.0692];%[    0.8500    0.3250    0.0980];
%     [0.6000    0.4482    0.0807];
%     c.blue4;  %[    0.3010    0.7450    0.9330];
%     [    0.6350    0.0780    0.1840];
%     adjust_brightness([    0.5000    0.5000    0.5000], 0.6);
%     ];
% 
% cmap_mus_light = [...
%     adjust_brightness([    0.3010    0.7450    0.9330], 0.95);      %%       [0    0.4470    0.7410];
%     adjust_brightness([0.8147    0.9058    0.1270], 0.95);
%     adjust_brightness([0.4940    0.1840    0.5560], 0.95);
%     c.green5;%[         0    0.5000         0];
%     adjust_brightness([         0         0         0    ], 0.95);     % temp
%     adjust_brightness([         1         0         0  ], 0.95);       % temp
%     adjust_brightness([    0.6000    0.2294    0.0692], 0.95);
%     adjust_brightness([0.6000    0.4482    0.0807], 0.95);
%     c.blue5;  %[    0.3010    0.7450    0.9330];
%     adjust_brightness([    0.6350    0.0780    0.1840], 0.95);
%     adjust_brightness([    0.5000    0.5000    0.5000], 0.95);
%     ];
end