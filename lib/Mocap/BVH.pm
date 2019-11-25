package Mocap::BVH;

use 5.028001;
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


# Preloaded methods go here.
use File::Slurp;
use Carp;
use Mocap::BVH::Joint;

my $digits = qr/[+\-]?\d+(?:\.\d+)?/;
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

sub root {
    $_[0]->{root};
}

sub joint {
    my ($this, $name) = @_;
    if (defined($name)) {
        return $this->root->descendant($name);
    } else {
        croak 'usage: $bvh->joint($name)';
    }
}

sub joints {
    my $this = shift;
    ($this->root, $this->root->descendants);
}

sub remove_joints {
    my ($this) = @_;
    if (grep $this->root->name eq $_, @_) {
        $this->root = undef;
    } else {
        $this->root->remove_descendants(@_);
    }
}

sub frames {
    $_[0]->{frames};
}

sub frame_time {
    $_[0]->{frame_time};
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
    my @joints = $this->joints;
    my $t = 0;
    for my $line(@lines) {
        my @nums = split ' ', $line;
        for (@joints) {
            $_->at_time($t, splice(@nums, 0, scalar($_->channels)));
        }
        ++$t;
    }
}

sub parse_offset {
    my $this = shift;
    skip_space($this->{text});
    if ($this->{text} =~ /\GOFFSET\s+($digits)\s+($digits)\s+($digits)/gcms) {
        return ($1, $2, $3)
    } else {
        $this->{text} =~ /\G(\S+)/gcms;
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
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Mocap::BVH - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Mocap::BVH;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Mocap::BVH, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2019 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.28.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
