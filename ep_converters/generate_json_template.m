% generate a json template (mainly for nautilus data) based on the IOMAX
% file structure.
d_data = fullfile(fileparts(getenv('D_DATA')), '2021-08-00_human_scs_mapping', 'preproc_records');
X = loadjson(fullfile(d_data, 'sub-21', 'sub-21.json'));
X = X.Cases{1};

vec_str_mode = string(arrayfun(@(ix) X.Modes{ix}.Name, 1:length(X.Modes), 'UniformOutput', false));
case_mode = vec_str_mode == "Research SCS";
%%
Y = replicate_structure_fields(X);

Y.Events{1} = replicate_structure_fields(X.Events{1});
Y.Modes{1} = replicate_structure_fields(X.Modes{case_mode});

Y.Modes{1}.Trials{1} = replicate_structure_fields(X.Modes{case_mode}.Trials{1});
Y.Modes{1}.Trials{1}.Traces{1} = replicate_structure_fields(X.Modes{case_mode}.Trials{1}.Traces{1});
Y.Modes{1}.Trials{1}.Traces{1}.Channel = replicate_structure_fields(X.Modes{case_mode}.Trials{1}.Traces{1}.Channel);
for ix = 1:1
    Y.Modes{1}.Trials{1}.Traces{ix}.TraceData = replicate_structure_fields(X.Modes{case_mode}.Trials{1}.Traces{ix}.TraceData);
end
Y.Modes{1}.Trials{1}.Stimuli = replicate_structure_fields(X.Modes{case_mode}.Trials{1}.Stimuli);
Y.Modes{1}.Trials{1}.Stimuli.DiscreteStimuli{1} = replicate_structure_fields(X.Modes{case_mode}.Trials{1}.Stimuli.DiscreteStimuli{1});
Y.etc = struct;
json_out = fullfile(d_data, 'template.json');
savejson('iomaxtemplate', Y, json_out);
%%