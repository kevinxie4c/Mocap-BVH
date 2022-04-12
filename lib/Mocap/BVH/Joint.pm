package Mocap::BVH::Joint;

use strict;
use warnings;
use Scalar::Util qw(blessed);
use Carp;

sub new {
    my ($class, $name) = @_;
    croak "usage: ${class}->new(\$name)" unless defined $name;
    my $this =  {
        name => $name,
        parent => undef,
        children => [],
        positions => [],
    };
    bless $this;
}

sub name {
    my $this = shift;
    if (@_) {
        $this->{name} = shift;
    }
    $this->{name};
}

sub offset {
    my $this = shift;
    if (@_) {
        $this->{offset} = [@_];
    }
    @{$this->{offset}};
}

sub channels {
    my $this = shift;
    if (@_) {
        $this->{channels} = [@_];
    }
    @{$this->{channels}};
}

sub end_site {
    my $this = shift;
    if (@_) {
        $this->{end_site} = [@_];
    }
    if (defined($this->{end_site})) {
        return @{$this->{end_site}};
    } else {
        return undef;
    }
}

sub parent {
    my $this = shift;
    if (@_) {
        my $parent = shift;
        if (blessed($parent) && $parent->isa('Mocap::BVH::Joint')) {
            $this->{parent} = $parent;
        } else {
            croak 'not a Mocap::BVH::Joint instance';
        }
    }
    $this->{parent};
}

sub children {
    my $this = shift;
    @{$this->{children}};
}

sub child {
    my ($this, $name) = @_;
    if (defined($name)) {
        for ($this->children) {
            return $_ if $_->name eq $name;
        }
        return undef;
    } else {
        croak 'usage: $joint->child($name)';
    }
}

sub descendant {
    my ($this, $name) = @_;
    if (defined($name)) {
        for ($this->children) {
            return $_ if $_->name eq $name;
            my $ret = $_->descendant($name);
            return $ret if defined $ret;
        }
        return undef;
    } else {
        croak 'usage: $joint->descendant($name)';
    }
}

sub descendants {
    my $this = shift;
    my @list;
    for ($this->children) {
        push @list, $_;
        push @list, $_->descendants;
    }
    @list;
}

sub add_children {
    my $this = shift;
    for (@_) {
        if (blessed($_) && $_->isa('Mocap::BVH::Joint')) {
            $_->parent($this);
            push @{$this->{children}}, $_;
        } else {
            croak 'not a Mocap::BVH::Joint instance';
        }
    }
}

sub remove_children {
    my $this = shift;
    my @list;
    for my $child(@{$this->{children}}) {
        push @list, $child unless grep $child->name eq $_, @_;
    }
    $this->{children} = \@list;
}

sub remove_descendants {
    my $this = shift;
    if (@_) {
        $this->remove_children(@_);
        for ($this->children) {
            $_->remove_descendants(@_);
        }
    } else {
        $this->{children} = [];
    }
}

sub at_frame {
    my $this = shift;
    my $t = shift;
    if (defined($t)) {
        if (@_) {
            if (@_ == $this->channels) {
                $this->{positions}[$t] = [@_];
            } else {
                croak 'the number of arguments does not match the number of channels';
            }
        }
        return @{$this->{positions}[$t]};
    } else {
        croak 'usage: $joint->at_frame($t, ...)';
    }
}

1;
