use strict;
use warnings;
use Test::More;
use Test::Exception;

use Data::XDR;

sub xdr_encode {
    my ($type, $value) = @_;
    Data::XDR->new(\my $buffer)->put($type => $value);
    $buffer;
}

subtest "primitives" => sub {
    is xdr_encode(char => 127),     pack 'B*',   '01111111';
    is xdr_encode(u_char => 127),   pack 'B*',   '01111111';
    is xdr_encode(int => 127),      pack 'x3B*', '01111111';
    is xdr_encode(u_int => 127),    pack 'x3B*', '01111111';
    is xdr_encode(short => 127),    pack 'x1B*', '01111111';
    is xdr_encode(u_short => 127),  pack 'x1B*', '01111111';
    # is $xdr-(>hyper(127),    pack 'x7B*', '01111111';
    # is $xdr->u_hyper(127),  pack 'x7B*', '01111111';

    # IEEE 754
    is xdr_encode(float => 3.14),  pack 'B*', '01000000010010001111010111000011';
    is xdr_encode(double => 3.14), pack 'B*', '0100000000001001000111101011100001010001111010111000010100011111';
};

subtest "opaque" => sub {
    my $xdr = Data::XDR->new;

    is xdr_encode($xdr->XDR_OPAQUE(12) => 'a'x12), 'a'x12;
    is xdr_encode($xdr->XDR_OPAQUE(10) => 'a'x10), 'a'x10 . "\0"x2;
    dies_ok { xdr_encode($xdr->XDR_OPAQUE(12) => 'a'x10) };
    dies_ok { xdr_encode($xdr->XDR_OPAQUE(12) => 'a'x16) };

    is xdr_encode($xdr->XDR_BYTES => 'a'x12), pack 'Na*', 12, 'a'x12;
    is xdr_encode($xdr->XDR_BYTES => 'a'x10), pack 'Na*x2', 10, 'a'x10;
    dies_ok { xdr_encode($xdr->XDR_BYTES(10) => 'a'x12) };
};

subtest "array" => sub {
    my $xdr = Data::XDR->new;

    is xdr_encode($xdr->XDR_VECTOR('int', 3) => [3, 2, 1]), pack 'N3', 3, 2, 1;
    dies_ok { xdr_encode($xdr->XDR_VECTOR('int', 3) => [3]) };
    dies_ok { xdr_encode($xdr->XDR_VECTOR('int', 1) => [2, 1]) };

    is xdr_encode($xdr->XDR_ARRAY($xdr->XDR_INT) => [3, 4]), pack 'NN2', 2, 3, 4;
    is xdr_encode($xdr->XDR_ARRAY($xdr->XDR_STRUCT(
        sn  => $xdr->XDR_U_SHORT,
        in  => $xdr->XDR_INT,
        str => $xdr->XDR_STRING(30),
    )) => [
        {
            sn  => 1,
            in  => 2,
            str => 'aaa',
        },
        {
            sn  => 3,
            in  => 4,
            str => 'bbb',
        },
    ]), pack 'N(nNNa3x)2', 2, 1, 2, 3, 'aaa', 3, 4, 3, 'bbb';

    dies_ok { xdr_encode($xdr->XDR_ARRAY('int', 1) => [1, 2]) };
};

subtest "struct" => sub {
    my $xdr = Data::XDR->new;

    is xdr_encode($xdr->XDR_STRUCT(
        un  => $xdr->XDR_U_INT,
        vec => $xdr->XDR_VECTOR($xdr->XDR_CHAR, 3),
    ) => {
        un  => 10,
        vec => [3, 2, 1],
    }), pack 'Nc3', 10, 3, 2, 1;
};

subtest "union" => sub {
    my $xdr = Data::XDR->new;
    is xdr_encode($xdr->XDR_UNION('u_int', {
        1 => $xdr->XDR_U_INT,
        2 => $xdr->XDR_STRING,
    }) => { type => 1, value => 100 }), pack 'NN', 1, 100;

    is xdr_encode($xdr->XDR_UNION('u_int', {
        1 => $xdr->XDR_U_INT,
        2 => $xdr->XDR_STRING,
    }) => { type => 2, value => 'abc' }), pack 'NNa3x', 2, 3, 'abc'
};

done_testing;
