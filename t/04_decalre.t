use strict;
use warnings;
use Test::More;

use Data::XDR::Declare;

my $xdrd = Data::XDR::Declare->new;
$xdrd->typedef(fooint => 'int');
$xdrd->typedef(foovector => $xdrd->xdr_vector('char', 3));
$xdrd->xdr_struct(barstruct => [
    foo => 'fooint',
    bar => 'foovector',
]);

my $xdr = $xdrd->xdr_create(\my $buffer);
$xdr->put(barstruct => {
    foo => 128,
    bar => [1, 2, 3],
});

is $buffer, pack 'l>c3', 128, 1, 2, 3;

done_testing;
