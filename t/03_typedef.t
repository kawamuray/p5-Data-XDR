use strict;
use warnings;
use Test::More;
use Data::XDR;

my $xdr = Data::XDR->new;
$xdr->typedef(footype => $xdr->XDR_INT);
is $xdr->put(footype => 127), pack 'N', 127;

done_testing;
