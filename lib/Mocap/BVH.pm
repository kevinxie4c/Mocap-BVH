package Mocap::BVH;

use 5.024001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Mocap::BVH ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';


=head1 NAME

Mocap::BVH - Perl extension for editing BVH files

=head1 SYNOPSIS

    use Mocap::BVH;
    $bvh = Mocap::BVH->load('file.bvh');    # load a BVH file
    $root = $bvh->root;	# get root joint
    $neck = $bvh->joint('neck');	# get the joint name "neck"
    @joints = $bvh->joints; # get all joints
    for (@joints) {
	print $_->name;	# print joint name
    }
    $neck->name('Neck');    # change joint name
    $bvh->save('modified-file.bvh');	# save the file

=head1 DESCRIPTION

This package is for loading, editing, and saving BVH files.
You can modify the joint propertis such as "name" and "offset", change channel values in different frames, and modify the skeleton structure (see L<Mocap::BVH::Joint> for details).

=head2 EXPORT

None by default.

=cut


# Preloaded methods go here.
use File::Slurp;
use Scalar::Util qw(blessed);
use Carp;
use Mocap::BVH::Joint;

my $digits = qr/[+\-]?(?:\d*\.\d+|\d+(?:\.\d*)?)(?:[Ee][+\-]?\d+)?/;

=head1 METHODS

=over

=item load

    $bvh = Mocap::BVH->load('filename.bvh');

load a BVH file and return a Mocap::BVH object.

=back
=cut

sub load {
    my ($class, $filename) = @_;
    croak "usage: ${class}->load(\$filename)" unless defined $filename;
    my $this = {};
    bless $this, $class;
    $this->{text} = read_file($filename);
    &parse_hierarchy($this);
    &parse_motion($this);
    $this;
}

=over

=item root

    $bvh->root($joint);
    $root = $bvh->root;

Set/get the root joint.

=back
=cut

sub root {
    my $this = shift;
    if (@_) {
	my $joint = shift;
	if (blessed($joint) && $joint->isa('Mocap::BVH::Joint')) {
	    $joint->parent(undef);
	    $this->{root} = $joint;
	} else {
            croak 'the argument you pass is not a Mocap::BVH::Joint object';
	}
    }
    $this->{root};
}

=over

=item joint

    $joint = $bvh->joint('name');

Find a joint by name.

=back
=cut

sub joint {
    my ($this, $name) = @_;
    if (defined($name)) {
	return $this->root if ($this->root->name eq $name);
        return $this->root->descendant($name);
    } else {
        croak 'usage: $bvh->joint($name)';
    }
}

=over

=item joints

    @joints = $bvh->joints;

Get all joints in the BVH.

=back
=cut

sub joints {
    my $this = shift;
    ($this->root, $this->root->descendants);
}

=over

=item remove_joints

    $bvh->remove_joints('name');
    $bvh->remove_joints('name1', 'name2');

Remove joints by names

=back
=cut

sub remove_joints {
    my ($this) = @_;
    if (grep $this->root->name eq $_, @_) {
        $this->root = undef;
    } else {
        $this->root->remove_descendants(@_);
    }
}

=over

=item frames

    $bvh->frames(1000);
    $num_frames = $bvh->frames;

Set/get I<Frames> field (number of frames) of the BVH.

=back
=cut

sub frames {
    $_[0]->{frames} = $_[1] if @_ > 1;
    $_[0]->{frames};
}

=over

=item frames

    $bvh->frames(0.04);
    $sec_per_frame = $bvh->frame_time;

Set/get I<Frame Time> field of the BVH.

=back
=cut

sub frame_time {
    $_[0]->{frame_time} = $_[1] if @_ > 1;
    $_[0]->{frame_time};
}

sub at_frame {
    my $this = shift;
    if (@_ < 1) {
        croak 'usage: $bvh->at_frame($t, ...)';
    }
    my $t = shift;
    my @nums;
    for ($this->joints) {
        if (@_) {
            $_->at_frame($t, splice(@_, 0, scalar($_->channels)));
        }
        push @nums, $_->at_frame($t);
    }
    @nums;
}

sub to_string {
    my $this = shift;
    my $output = "HIERARCHY\n";
    $output .= &joint_to_string($this->root, 0); 
    $output .= "MOTION\nFrames: " . $this->frames . "\nFrame Time: " . $this->frame_time . "\n";
    for my $t(0 .. $this->frames - 1) {
        my @nums;
        for ($this->joints) {
            push @nums, $_->at_frame($t);
        }
        $output .= join("\t", @nums) . "\n";
    }
    $output;
}

sub save {
    my ($this, $filename) = @_;
    if (defined($filename)) {
        write_file($filename, $this->to_string);
    } else {
        croak 'usage $bvh->save($filename)';
    }
}

sub joint_to_string {
    my ($joint, $indent) = @_;
    my $output = '';
    &indent($output, $indent);
    if (defined($joint->parent)) {
        $output .= 'JOINT ';
    } else {
        $output .= 'ROOT ';
    }
    $output .= $joint->name . "\n";
    &indent($output, $indent);
    $output .= "{\n";
    &indent($output, $indent);
    $output .= "\tOFFSET " . join("\t", $joint->offset) . "\n";
    &indent($output, $indent);
    $output .= "\tCHANNELS " . scalar($joint->channels) . ' ' .join(" ", $joint->channels) . "\n";
    for ($joint->children) {
        $output .= joint_to_string($_, $indent + 1);
    }
    if ($joint->end_site) {
        &indent($output, $indent);
        $output .= "\tEnd Site\n";
        &indent($output, $indent);
        $output .= "\t{\n";
        &indent($output, $indent);
        $output .= "\t\tOFFSET " . join("\t", $joint->end_site) . "\n";
        &indent($output, $indent);
        $output .= "\t}\n";
    }
    &indent($output, $indent);
    $output .= "}\n";
}

sub indent {
    $_[0] .= "\t" x $_[1];
}

sub peek_token {
    my $this = shift;
    my $pos = pos $this->{text};
    my $token = '';
    if ($this->{text} =~ /\G\s*(\S+)/gcms) {
        $token = $1;
    }
    pos($this->{text}) = $pos;
    return $token;
}

sub skip_space {
    $_[0] =~ /\G\s*/gcms;
}

sub expect {
    my ($expected, $received) = @_;
    if (defined($received)) {
        croak "expected $expected but received $received";
    } else {
        croak "expected $expected";
    }
}

sub parse_hierarchy {
    my $this = shift;
    my $hierarchy = 'HIERARCHY';
    skip_space($this->{text});
    if ($this->{text} =~ /\G(\w+)/gcms) {
        my $label = $1;
        if ($label eq $hierarchy) {
            &parse_root($this);
        } else {
            expect($hierarchy, $label);
        }
    } else {
        expect($hierarchy);
    }
}

sub parse_motion {
    my $this = shift;
    skip_space($this->{text});
    unless ($this->{text} =~ /\GMOTION/gcms) {
        expect('MOTION');
    }
    skip_space($this->{text});
    if ($this->{text} =~ /\GFrames:\s*(\d+)/gcms) {
        $this->{frames} = $1;
    } else {
        expect('Frames');
    }
    skip_space($this->{text});
    if ($this->{text} =~ /\GFrame\s+Time:\s*($digits)/gcms) {
        $this->{frame_time} = $1;
    } else {
        expect('Frame Time');
    }
    skip_space($this->{text});
    my $text = substr($this->{text}, pos($this->{text}));
    my @lines = split "\n", $text;
    if (@lines != $this->frames) {
        croak 'inconsistent frames number';
    }
    my @joints = $this->joints;
    my $t = 0;
    for my $line(@lines) {
        my @nums = split ' ', $line;
	$this->at_frame($t, @nums);
        ++$t;
    }
}

sub parse_offset {
    my $this = shift;
    skip_space($this->{text});
    if ($this->{text} =~ /\GOFFSET\s+($digits)\s+($digits)\s+($digits)/gcms) {
        return ($1, $2, $3)
    } else {
        $this->{text} =~ /\G(.*?)$/gcms;
        expect('OFFSET', $1);
    }
}

sub parse_channels {
    my $this = shift;
    skip_space($this->{text});
    my @list;
    if ($this->{text} =~ /\GCHANNELS\s+(\d+)/gcms) {
        my $n = $1;
        for (1 .. $n) {
            skip_space($this->{text});
            if ($this->{text} =~ /(\G[XYZ](?:rotation|position))/gcms) {
                push @list, $1;
            } else {
                expect('[XYZ](?:rotation|position)');
            }
        }
    } else {
        expect('CHANNELS');
    }
    @list;
}

sub parse_root {
    my $this = shift;
    my $root = 'ROOT';
    skip_space($this->{text});
    if ($this->{text} =~ /\G(\w+)\s+(\w+)/gcms) {
        my ($root_label, $label) = ($1, $2);
        if ($root_label eq $root) {
            my $joint = Mocap::BVH::Joint->new($label);
            $this->{root} = $joint;
            skip_space($this->{text});
            if ($this->{text} =~ /\G\{/gcms) {
                $joint->offset(parse_offset($this));
                $joint->channels(parse_channels($this));
                while (1) {
                    my $token = peek_token($this);
                    if ($token eq 'JOINT') {
                        &parse_joint($this, $joint);
                    } elsif ($token eq 'End') {
                        &parse_end_site($this, $joint);
                    } elsif ($token eq '}') {
                        last;
                    } else {
                        expect('JOINT or End or }', $token);
                    }
                }
            } else {
                expect('{');
            }
            skip_space($this->{text});
            unless ($this->{text} =~ /\G\}/gcms) {
                expect('}');
            }
        } else {
            expect($root);
        }
    } else {
        expect("$root label");
    }
}

sub parse_joint {
    my $this = shift;
    my $parent = shift;
    skip_space($this->{text});
    if ($this->{text} =~ /\G(\w+)\s+(\w+)/gcms) {
        my ($joint_label, $label) = ($1, $2);
        if ($joint_label eq 'JOINT') {
            my $joint = Mocap::BVH::Joint->new($label);
            $parent->add_children($joint);
            skip_space($this->{text});
            if ($this->{text} =~ /\G\{/gcms) {
                $joint->offset(parse_offset($this));
                $joint->channels(parse_channels($this));
                while (1) {
                    my $token = peek_token($this);
                    if ($token eq 'JOINT') {
                        &parse_joint($this, $joint);
                    } elsif ($token eq 'End') {
                        &parse_end_site($this, $joint);
                    } elsif ($token eq '}') {
                        last;
                    } else {
                        expect('JOINT or End or }', $token);
                    }
                }
            } else {
                expect('{');
            }
            skip_space($this->{text});
            unless ($this->{text} =~ /\G\}/gcms) {
                expect('}');
            }
        } else {
            expect('JOINT');
        }
    } else {
        expect("JOINT label");
    }
}

sub parse_end_site {
    my $this = shift @_;
    my $joint = shift @_;
    skip_space($this->{text});
    if ($this->{text} =~ /\GEnd Site/gcms) {
        skip_space($this->{text});
        if ($this->{text} =~ /\G\{/gcms) {
            $joint->end_site(parse_offset($this));
        } else {
            expect('{');
        }
        skip_space($this->{text});
        unless ($this->{text} =~ /\G\}/gcms) {
            expect('}');
        }
    } else {
        expect('End Site')
    }
}

1;
__END__
# Other documentation.

=head1 SEE ALSO

A document about the BVH format: L<https://research.cs.wisc.edu/graphics/Courses/cs-838-1999/Jeff/BVH.html>.

=head1 AUTHOR

Kaixiang Xie, E<lt>kaixiangxie@outlook.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2019 by Kaixiang Xie

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.28.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
