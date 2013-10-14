package Data::XDR::Stream;
use strict;
use warnings;
use Scalar::Util ();
use IO::Handle;
use IO::Scalar;

sub new {
    my ($class, $seed) = @_;

    if (!Scalar::Util::openhandle $seed) {
        $seed = '' unless defined $seed;
        my $ref = ref $seed;
        my $sref = $ref && $ref eq 'SCALAR' ? $seed : \(my $b = "$seed");
        $seed = IO::Scalar->new($sref)
            or die "Can't open scalar as stream: $!";
    }

    bless \$seed, $class;
}

sub getpos {
    my ($self) = @_;
    ($$self)->tell;
}

sub setpos {
    my ($self, $offset) = @_;
    ($$self)->seek($offset, 0);
}

sub get_bytes {
    my ($self, $size) = @_;
    my $rlen = ($$self)->sysread((my $bytes), $size);
    defined $rlen && $rlen == $size ? $bytes : undef;
}

sub put_bytes {
    my ($self, $bytes, $size) = @_;
    my $wlen = ($$self)->syswrite($bytes, $size);
    defined $wlen && $wlen == $size ? $bytes : undef;
}

1;
