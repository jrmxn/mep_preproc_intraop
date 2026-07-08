function modified_injury_row = calculate_injury_stats(participant, target_side, ...
    cell_scloc_level, relevant_segments, redcap_id, count_ignore_nonstimulated, augment_with_old_wcm_data)

redcap_events = load_redcap_info('augment_with_old_wcm_data', augment_with_old_wcm_data);
case_participant = redcap_events.record_id_custom == redcap_id;
assert(sum(case_participant) == 1, sprintf('missing entry: %s ?!', redcap_id));
redcap_entry = table2struct(redcap_events(case_participant, :));
vec_mtst_uppers_muscle = redcap_events.Properties.UserData.vec_mtst_uppers_muscle;
vec_reflexes_muscle = redcap_events.Properties.UserData.vec_reflexes_muscle;

% if isempty(redcap_entry)
%     fprintf('Removing all of %s/%s - foraminal stenosis data not inserted!\n', participant, redcap_id);
% end
modified_injury_row = struct;
modified_injury_row.participant = string(participant);

modified_injury_row.hyperreflexia_ue = redcap_entry.table_hyperreflexia_ue;
modified_injury_row.hyperreflexia_le = redcap_entry.table_hyperreflexia_le;

for ix_segment = 1:length(cell_scloc_level)
    for str_side = ["L", "R"]
        str_segment = cell_scloc_level{ix_segment};
        str_segment_side = sprintf('im_%sfor_%s', lower(str_side), lower(str_segment));
        if str_side == target_side
            str_segment_side_out = sprintf('im_ufor_%s', lower(str_segment));
        else
            str_segment_side_out = sprintf('im_ifor_%s', lower(str_segment));
        end

        seg_side_missing = ismissing(redcap_entry.(str_segment_side));

        if seg_side_missing
            modified_injury_row.(str_segment_side_out) = string(missing);
        else
            str_local_grading = redcap_entry.(str_segment_side);
            modified_injury_row.(str_segment_side_out) = str_local_grading;

            if count_ignore_nonstimulated
                if not(any(relevant_segments == str_segment))
                    modified_injury_row.(str_segment_side_out) = "non-stimulated";
                end
            end
        end
    end
end

% n.b. this is for uppers only!
for ix_muscle = 1:length(vec_mtst_uppers_muscle)
    for str_side = ["L", "R"]
        str_muscle = vec_mtst_uppers_muscle(ix_muscle);
        str_muscle_side = sprintf('med_mtst_%sue_%s', lower(str_side), lower(str_muscle));
        if str_side == target_side
            str_muscle_side_out = sprintf('med_mtst_usue_%s', lower(str_muscle));
        else
            str_muscle_side_out = sprintf('med_mtst_isue_%s', lower(str_muscle));
        end
        if ismissing(redcap_entry.(str_muscle_side))
            modified_injury_row.(str_muscle_side_out) = missing;
        else
            local_grading = redcap_entry.(str_muscle_side);
%             if local_grading == 6, local_grading = nan; end  % should maybe handle this in the loader
            modified_injury_row.(str_muscle_side_out) = local_grading;

            if count_ignore_nonstimulated
                if not(any(relevant_segments == str_segment))
                    modified_injury_row.(str_muscle_side_out) = nan;
                end
            end
        end
    end
end

for ix_muscle = 1:length(vec_reflexes_muscle)
    for str_side = ["L", "R"]
        str_muscle = vec_reflexes_muscle(ix_muscle);

        str_muscle_side = sprintf('med_reflex_%s_%s', lower(str_side), lower(str_muscle));
        if str_side == target_side
            str_muscle_side_out = sprintf('med_reflex_u_%s', lower(str_muscle));
        else
            str_muscle_side_out = sprintf('med_reflex_i_%s', lower(str_muscle));
        end
        if ismissing(redcap_entry.(str_muscle_side))
            modified_injury_row.(str_muscle_side_out) = missing;
        else
            local_grading = redcap_entry.(str_muscle_side);
            modified_injury_row.(str_muscle_side_out) = local_grading;

            if count_ignore_nonstimulated
                if not(any(relevant_segments == str_segment))
                    modified_injury_row.(str_muscle_side_out) = nan;
                end
            end
        end
    end
end
end