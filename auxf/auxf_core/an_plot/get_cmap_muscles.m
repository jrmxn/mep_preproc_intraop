function [c_map_ch, c_arm, c_hand, c_lower, ch_groups] = get_cmap_muscles
% error('probably want to use get_cmap_muscles_alt?');
c_arm = [1, 0, 0];
c_hand = [0, 1, 0];
c_lower = [0, 0, 1];
c_wrist = [0, 1, 1];

c_map_ch.Arm = rgb2hsv(c_arm);
c_map_ch.LArm = rgb2hsv(c_arm);
c_map_ch.RArm = rgb2hsv(c_arm);
c_map_ch.LTrapezius = rgb2hsv(c_arm) .* [1, 1.0, 1];
c_map_ch.RTrapezius = c_map_ch.LTrapezius;
c_map_ch.LDeltoid = rgb2hsv(c_arm) .* [1, 0.6, 1];
c_map_ch.RDeltoid = c_map_ch.LDeltoid;
c_map_ch.LBiceps = rgb2hsv(c_arm) .* [1, 0.4, 1];
c_map_ch.RBiceps = c_map_ch.LBiceps;
c_map_ch.LTriceps = rgb2hsv(c_arm) .* [1, 0.1, 1];
c_map_ch.RTriceps = c_map_ch.LTriceps;

c_map_ch.Wrist = rgb2hsv(c_wrist);
c_map_ch.LWrist = rgb2hsv(c_wrist);
c_map_ch.RWrist = rgb2hsv(c_wrist);
c_map_ch.LECR = rgb2hsv(c_wrist) .* [1, 1.0, 1];
c_map_ch.RECR = c_map_ch.LECR;
c_map_ch.LFCR = rgb2hsv(c_wrist) .* [1, 0.3, 1];
c_map_ch.RFCR = c_map_ch.LFCR;

c_map_ch.Hand = rgb2hsv(c_hand);
c_map_ch.LHand = rgb2hsv(c_hand);
c_map_ch.RHand = rgb2hsv(c_hand);
c_map_ch.LAPB = rgb2hsv(c_hand) .* [1, 1.0, 1];
c_map_ch.RAPB = c_map_ch.LAPB;
c_map_ch.LADM = rgb2hsv(c_hand) .* [1, 0.3, 1];
c_map_ch.RADM = c_map_ch.LADM;

c_map_ch.Lower = rgb2hsv(c_lower);
c_map_ch.LLower = rgb2hsv(c_lower);
c_map_ch.RLower = rgb2hsv(c_lower);
c_map_ch.LTA = rgb2hsv(c_lower) .* [1, 1.0, 1];
c_map_ch.RTA = c_map_ch.LTA;
c_map_ch.LEDB = rgb2hsv(c_lower) .* [1, 0.5, 1];
c_map_ch.REDB = c_map_ch.LEDB;
c_map_ch.LAH = rgb2hsv(c_lower) .* [1, 0.2, 1];
c_map_ch.RAH = c_map_ch.LAH;
fn_c_map_ch = fieldnames(c_map_ch);
for ix_fn_c_map_ch = 1:length(fn_c_map_ch)
    c_map_ch.(fn_c_map_ch{ix_fn_c_map_ch}) = hsv2rgb(c_map_ch.(fn_c_map_ch{ix_fn_c_map_ch}));
end

ch_groups = struct;
ch_groups.LArm = {'LTrapezius', 'LDeltoid', 'LBiceps', 'LTriceps'};
ch_groups.LHand = {'LAPB', 'LADM'};
ch_groups.LLower = {'LTA', 'LEDB', 'LAH'};
ch_groups.RArm = {'RTrapezius', 'RDeltoid', 'RBiceps', 'RTriceps'};
ch_groups.RHand = {'RAPB', 'RADM'};
ch_groups.RLower = {'RTA', 'REDB', 'RAH'};
end