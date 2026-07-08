function get_percentage_rejected(rej_stack)
n_reject = sum(rej_stack(:) == 1, 'omitnan');
n_responses = sum((rej_stack(:) == 1)|(rej_stack(:) == 0), 'omitnan');
rej_pct = (n_reject/n_responses) * 100;
fprintf('Rejected percentage total: %0.1f%%\n', rej_pct);
fprintf('Total responses: %d\n', n_responses);
fprintf('Of which rejected: %d\n', n_reject);
end
