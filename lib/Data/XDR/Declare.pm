package Data::XDR::Declare;
use 5.008005;
use strict;
use warnings;
use Data::XDR;
use Exporter 'import';
use Scalar::Util ();

our @EXPORT_OK;
push @EXPORT_OK, qw{
  xdr_declare
  xdr_typedef
  xdr_struct
  xdr_union
}; # And more at end of this module
our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
    DSL => \@EXPORT_OK,
);

our $Singleton;
sub singleton {
    my ($class, @args) = @_;
    $Singleton ||= $class->new(@args);
}

sub xdr_declare(&) {
    my ($block) = @_;
    local $Singleton;
    $block->();
    __PACKAGE__->singleton;
}

sub _args {
    unless (Scalar::Util::blessed($_[0]) && $_[0]->isa(__PACKAGE__)) {
        unshift @_, __PACKAGE__->singleton;
    }
    @_;
}

sub new {
    my ($class, %args) = @_;

    bless \%args, $class;
}

sub xdr_create {
    my ($self, @args) = @_;
    my %args = @args > 1 ? @args : (xdrs => $args[0]);
    $args{declare} = $self;
    Data::XDR->new(%args);
}

sub type {
    my ($self, $type) = @_;
    my $ref = ref $type;
    if ($ref && $ref eq 'CODE') {
        return $type;
    } elsif ($self->{$type}) {
        return $self->{$type};
    } elsif (my $tg = Data::XDR->can('XDR_'.uc($type))) {
        return $tg->();
    } else {
        return;
    }
}

sub typedef {
    my ($self, $ident, $type) = _args(@_);
    $self->{$ident} = $self->type($type);
}
BEGIN { *xdr_typedef = \&typedef }

sub xdr_struct {
    my ($self, @args) = _args(@_);
    my ($ident, $members) = @args > 1 ? @args : (undef, @args);
    my $struct = Data::XDR->XDR_STRUCT(@$members);
    $self->typedef($ident => $struct) if defined $ident;
    $struct;
}

sub xdr_union {
    my ($self, @args) = _args(@_);
    my ($ident, $dispatch_type, $dispatch) = @args > 2 ? @args : (undef, @args);
    my $union = Data::XDR->XDR_UNION($dispatch_type, $dispatch);
    $self->typedef($ident => $union) if defined $ident;
    $union;
}

# Port all XDR_* and some other functions from Data::XDR
BEGIN {
    my @port_methods = (
        grep { !__PACKAGE__->can(lc($_)) }
        grep { /^XDR_/ && defined &{"Data::XDR::$_"} } keys %Data::XDR::
    );

    for my $meth (@port_methods) {
        my $lcmeth = lc($meth);
        my $origmeth = Data::XDR->can($meth);
        my $code = sub {
            # Remove first argument if this was called as class method
            @_ = _args(@_); shift;
            Data::XDR->$meth(@_);
        };
        push @EXPORT_OK, $lcmeth;
        no strict 'refs';
        *$lcmeth = $code;
    }
}

1;
