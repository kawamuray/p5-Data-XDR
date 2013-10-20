use strict;
use warnings;
use Test::More;

use Data::XDR;
use Data::XDR::Declare ':DSL';

my $xdr = Data::XDR->new(
    xdrs => \my $buffer,
    declare => xdr_declare {
        xdr_typedef fooint => xdr_int;
        xdr_typedef foovector => xdr_vector(xdr_char, 3);
        xdr_struct barstruct => [
            foo => 'fooint',
            bar => 'foovector',
        ];
    }
);

$xdr->put(barstruct => {
    foo => 128,
    bar => [1, 2, 3],
});

is $buffer, pack 'l>c3', 128, 1, 2, 3;

done_testing;
