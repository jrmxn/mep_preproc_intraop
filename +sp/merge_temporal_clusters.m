function [dt_cluster_new, most_common_cluster] = merge_temporal_clusters(dt, dt_cluster, diff_threshold, cluster_offset)
% dt = dt_l;
% dt_cluster = dt_cl_l;
% sp_merge_temporal_clusters(dt_l, dt_cluster)

n_clusters = max(dt_cluster);
mat_cluster = false(length(dt), n_clusters);
% new_groupings = {};
for ix_dt = 1:length(dt)
    dt_diff = abs(dt(ix_dt) - dt);
    
    neighbour_clusters = dt_cluster(dt_diff < diff_threshold * seconds);
    
    original_cluster = dt_cluster(ix_dt);
    mat_cluster(ix_dt, unique([original_cluster; neighbour_clusters])) = true;
end

new_groupings = unique(mat_cluster, 'rows');
new_groupings = new_groupings(sum(new_groupings, 2)>1, :);
% cluster_offset is a hacky (rubbish) way to avoid potential collisions
new_clusters = n_clusters+1:n_clusters+size(new_groupings, 1);

if not(isempty(new_clusters))
    new_clusters = cluster_offset + new_clusters;
    fprintf('Merged some clusters...\n');
end

dt_cluster_new = dt_cluster;
for ix_dt = 1:length(dt)
    case_new_grouping_match = any(mat_cluster(ix_dt, :) == new_groupings, 2);
    if sum(case_new_grouping_match)==0
        % keep old group
    elseif sum(case_new_grouping_match)==1
        try
        dt_cluster_new(ix_dt) = new_clusters(case_new_grouping_match);
        catch
            keyboard;
        end
    else
        error('should only match one group...');
    end
end

dt_cluster_new_u = unique(dt_cluster_new);
[~, ix_max] = max(arrayfun(@(x) sum(x==dt_cluster_new), unique(dt_cluster_new_u)));
most_common_cluster = dt_cluster_new_u(ix_max);
end