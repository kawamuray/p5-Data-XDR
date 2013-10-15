package Data::XDR;
use 5.01000;
use strict;
use warnings;
use bytes ();
use Carp;
use Data::XDR::Stream;

our $VERSION = "0.01";

BEGIN {
    my %primitives = (
        char      => ['c', 1],
        u_char    => ['C', 1],
        short     => ['s>', 2],
        u_short   => ['S>', 2],
        int       => ['l>', 4],
        u_int     => ['L>', 4],
        hyper     => ['q>', 8],
        u_hyper   => ['Q>', 8],
        float     => ['f>', 4],
        double    => ['d>', 8],
        quadruple => ['D>', 16],
    );

    while (my ($type, $data) = each %primitives) {
        my $packer = sub {
            my ($self, $valuep) = @_;
            $self->x_op(@$data, $valuep);
        };
        my $meth = 'XDR_'.uc($type);
        my $op = sub {
            my ($self, @args) = @_;
            @args ? sub { $packer->(@args, @_) } : $packer;
        };
        no strict 'refs';
        *$meth = $op;
    }

    my $bool_packer = sub {
        my ($self, $valuep) = @_;
        $$valuep = $$valuep ? 1 : 0;
        $self->XDR_INT->($self, $valuep);
    };
    sub XDR_BOOL { $bool_packer }
}

sub new {
    my ($class, $seed) = @_;

    my $stream = Data::XDR::Stream->new($seed);
    bless {
        stream   => $stream,
        typedefs => {},
    }, $class;
}

sub type {
    my ($self, $type) = @_;
    if (ref $type) {
        return $type;
    } else {
        return $self->{typedefs}{$type} || $self->can('XDR_'.uc($type))->();
    }
}

sub typedef {
    my ($self, $ident, $typex) = @_;
    $self->{typedefs}{$ident} = $typex;
}

sub put {
    my ($self, $typex, @args) = @_;
    my $value = pop @args;
    local $self->{x_op} = $self->can('x_op_put');
    $self->type($typex)->($self, \$value, @args);
    # XXX: return value?
}

sub get {
    my ($self, $typex, @args) = @_;
    my $value = undef;
    local $self->{x_op} = $self->can('x_op_get');
    defined $self->type($typex)->($self, \$value, @args)
        ? $value : undef;
}

sub x_op {
    my ($self) = @_;
    $self->{x_op}->(@_);
}

sub x_op_put {
    my ($self, $tmpl, $size, $valuep) = @_;
    my $bytes = $tmpl ? pack($tmpl, $$valuep) : $$valuep;
    $self->{stream}->put_bytes($bytes, $size);
}

sub x_op_get {
    my ($self, $tmpl, $size, $valuep) = @_;
    my $bytes = $self->{stream}->get_bytes($size)
        or return;
    $$valuep = $tmpl ? unpack($tmpl, $bytes) : $bytes;
}

sub XDR_OPAQUE {
    my ($self, $size) = @_;
    defined $size or return;
    sub {
        my ($self, $opaquep) = @_;
        if ($self->{x_op} == $self->can('x_op_put') &&
            $size != (my $opqlen = length($$opaquep))) {
            croak "ERROR: length differ $size <-> $opqlen";
        }
        $self->x_op(undef, $size, $opaquep);
        my $rbytes = (4 - $size % 4) % 4;
        $self->x_op("x$rbytes", $rbytes, \my $unused);
        $$opaquep;
    };
}

sub XDR_BYTES {
    my ($self, $maxlen) = @_;
    $maxlen = ~0 unless defined $maxlen;
    sub {
        my ($self, $bytesp) = @_;
        my $length = bytes::length($$bytesp || '');
        croak "ERROR: length larger than maxlen $length > $maxlen"
            if $length > $maxlen;
        $self->XDR_U_INT->($self, \$length);
        return if $length > $maxlen;
        $self->XDR_OPAQUE($length)->($self, $bytesp);
    };
}

sub XDR_STRING { goto &XDR_BYTES }

sub XDR_VECTOR {
    my ($self, $rtype, $size) = @_;
    defined $size or return;
    sub {
        my ($self, $vecp) = @_;
        if ($self->{x_op} == $self->can('x_op_put') &&
            $size != @$$vecp) {
            croak "ERROR: length differ $size <-> ".@$$vecp;
        }
        for (my $i = 0; $i < $size; $i++) {
            $self->type($rtype)->($self, \($$vecp)->[$i])
                or return;
        }
        $$vecp;
    };
}

sub XDR_ARRAY {
    my ($self, $rtype, $maxlen) = @_;
    $maxlen = ~0 unless defined $maxlen;
    sub {
        my ($self, $arrp) = @_;
        $$arrp = [] unless defined $$arrp;
        my $length = @$$arrp;
        croak "ERROR: length larger than maxlen $length > $maxlen"
            if $length > $maxlen;
        $self->XDR_U_INT->($self, \$length);
        return if $length > $maxlen;
        $self->XDR_VECTOR($rtype, $length)->($self, $arrp);
    };
}

sub XDR_STRUCT {
    my ($self, @members) = @_;
    sub {
        my ($self, $structp) = @_;
        $$structp = {} unless defined $$structp;
        for (my $i = 0; $i < @members; $i += 2) {
            my ($ident, $type) = @members[$i,$i+1];
            $self->type($type)->($self, \($$structp)->{$ident})
                or return;
        }
        $$structp;
    };
}

sub XDR_UNION {
    my ($self, $dispatch_type, $dispatch) = @_;
    sub {
        my ($self, $objp) = @_;
        croak "ERROR: no such discriminent value: ".($$objp)->{type}
            if defined $$objp && !$dispatch->{($$objp)->{type}};
        $$objp = {} unless defined $$objp;
        $self->type($dispatch_type)->($self, \($$objp)->{type})
            or return;
        return unless $dispatch->{($$objp)->{type}};
        $self->type($dispatch->{($$objp)->{type}})->($self, \($$objp)->{value})
            or return;
        $$objp;
    };
}

1;
__END__

=encoding utf-8

=head1 NAME

Data::XDR - It's new $module

=head1 SYNOPSIS

    use Data::XDR;

=head1 DESCRIPTION

Data::XDR is ...

=head1 LICENSE

Copyright (C) Yuto KAWAMURA(kawamuray).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Yuto KAWAMURA(kawamuray) E<lt>kawamuray.dadada@gmail.comE<gt>

=cut

