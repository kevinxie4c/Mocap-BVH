# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Mocap-BVH.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 12;
BEGIN { use_ok('Mocap::BVH') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $bvh = Mocap::BVH->load('sample.bvh');
my $root = $bvh->root;
ok($root->name eq 'Hips', 'Mocap::BVH::root');
my $left_up_leg = $root->child('LeftUpLeg');
ok($left_up_leg->name eq 'LeftUpLeg', 'Mocap::BVH::Joint::child');
my @offset = $left_up_leg->offset;
is_deeply(\@offset, [qw(3.91 0.00 0.00)], 'Mocap::BVH::Joint::offset');
my $left_foot = $bvh->joint('LeftFoot');
ok($left_foot->name eq 'LeftFoot', 'Mocap::BVH::joint');
my @channels = $left_foot->channels;
is_deeply(\@channels, [qw(Zrotation Xrotation Yrotation)], 'Mocap::BVH::Joint::channels');
my @joints = map $_->name, $bvh->joints;
my @joints_expected = qw(Hips Chest Neck Head LeftCollar LeftUpArm LeftLowArm LeftHand RightCollar RightUpArm RightLowArm RightHand LeftUpLeg LeftLowLeg LeftFoot RightUpLeg RightLowLeg RightFoot);
is_deeply(\@joints, \@joints_expected, 'Mocap::BVH::joints');
$bvh->remove_joints('LeftHand', 'RightHand');
@joints = map $_->name, $bvh->joints;
@joints_expected = qw(Hips Chest Neck Head LeftCollar LeftUpArm LeftLowArm RightCollar RightUpArm RightLowArm LeftUpLeg LeftLowLeg LeftFoot RightUpLeg RightLowLeg RightFoot);
is_deeply(\@joints, \@joints_expected, 'Mocap::BVH::remove_joints');
is_deeply([$root->at_frame(0)], [qw(8.03	 35.01	 88.36	-3.41	 14.78	-164.35)], 'Mocap::BVH::Joint::at_time');
my $right_root = $bvh->joint('RightFoot');
is_deeply([$right_root->at_frame(1)], [qw(0.00	-25.93	 0.00)], 'Mocap::BVH::Joint::at_time');

my $bvh_a = Mocap::BVH->load('sample.bvh');
$bvh_a->save('tmp.bvh');
my $bvh_b = Mocap::BVH->load('tmp.bvh');
is_deeply($bvh_a->root, $bvh_b->root, 'Mocap::BVH->load');
unlink 'tmp.bvh';

my @nums = map $_ + 1, $bvh->at_frame(0);
$bvh->at_frame(0, @nums);
is_deeply([$bvh->at_frame(0)], \@nums, 'Mocap::BVH::at_frame');
