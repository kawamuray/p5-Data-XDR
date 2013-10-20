use strict;
use warnings;
use Test::More;
use Data::XDR;
use Data::XDR::Declare;

subtest "Eager definition" => sub {
    my $xdrd = Data::XDR::Declare->new(
        footype => Data::XDR->XDR_INT,
    );
    my $xdr = Data::XDR->new(xdrs => \my $buffer, declare => $xdrd);
    $xdr->put(footype => 127);
    is $buffer, pack 'N', 127;
};

subtest "Lazy definition" => sub {
    my $xdr = Data::XDR->new(\my $buffer);
    $xdr->declare->typedef(footype => $xdr->XDR_INT);
    $xdr->put(footype => 127);
    is $buffer, pack 'N', 127;
};

done_testing;
