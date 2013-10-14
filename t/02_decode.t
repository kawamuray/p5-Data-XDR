use strict;
use warnings;
use Test::More;
use Test::Exception;
use POSIX;

use Data::XDR;
my $xdr = Data::XDR->new;

sub xdr_decode {
    my ($type, $buffer) = @_;
    Data::XDR->new($buffer)->get($type);
}

subtest "primitives" => sub {
    my $xdr = Data::XDR->new(\my $buffer);
    $xdr->put($_ => 127)
        for qw{ char u_char int u_int short u_short };
    $xdr->put(float => 3.14);
    $xdr->put(double => 3.14);

    $xdr = Data::XDR->new($buffer);
    is $xdr->get('char'), 127;
    is $xdr->get('u_char'), 127;
    is $xdr->get('int'), 127;
    is $xdr->get('u_int'), 127;
    is $xdr->get('short'), 127;
    is $xdr->get('u_short'), 127;

    # IEEE 754
    ok abs( $xdr->get('float') - 3.14 ) < POSIX::FLT_EPSILON;
    ok abs( $xdr->get('double') - 3.14 ) < POSIX::DBL_EPSILON;
};

subtest "opaque" => sub {
    is xdr_decode($xdr->XDR_OPAQUE(12), 'a'x12), 'a'x12;
    is xdr_decode($xdr->XDR_OPAQUE(10), 'a'x10 . "\0"x2), 'a'x10;
    # ok ! $xdr->XDR_opaque(12)->unpack('a'x16);

    is xdr_decode($xdr->XDR_BYTES => pack 'Na*', 12, 'a'x12), 'a'x12;
    is xdr_decode($xdr->XDR_BYTES => pack 'Na*x2', 10, 'a'x10), 'a'x10;
    ok ! xdr_decode($xdr->XDR_BYTES(10) => pack 'Na*', 12, 'a'x12);
};

subtest "array" => sub {
    is_deeply xdr_decode($xdr->XDR_VECTOR($xdr->XDR_INT, 3) => pack 'N3', 3, 2, 1), [3, 2, 1];
    ok ! xdr_decode($xdr->XDR_VECTOR($xdr->XDR_INT, 2) => pack 'N1', 2);

    is_deeply xdr_decode($xdr->XDR_ARRAY($xdr->XDR_INT) => pack 'NN2', 2, 3, 4), [3, 4];

    is_deeply xdr_decode($xdr->XDR_ARRAY($xdr->XDR_STRUCT(
        us  => $xdr->XDR_U_SHORT,
        ui  => $xdr->XDR_U_INT,
        str => $xdr->XDR_STRING(30),
    )) => pack 'N(nNNa3x)2', 2, 1, 2, 3, 'aaa', 3, 4, 3, 'bbb'), [
        { us => 1, ui => 2, str => 'aaa' },
        { us => 3, ui => 4, str => 'bbb' },
    ];

    ok ! xdr_decode($xdr->XDR_ARRAY($xdr->XDR_INT, 1) => pack 'NN2', 2, 1, 2);
};

subtest "struct" => sub {
    is_deeply xdr_decode($xdr->XDR_STRUCT(
        ui  => $xdr->XDR_U_INT,
        vec => $xdr->XDR_VECTOR($xdr->XDR_CHAR, 3),
    ) => pack 'Nc3', 10, 3, 2, 1), {
        ui  => 10,
        vec => [3, 2, 1],
    };
};

subtest "union" => sub {
    is xdr_decode($xdr->XDR_UNION('u_int', {
        1 => $xdr->XDR_U_INT,
        2 => $xdr->XDR_STRING,
    }) => pack 'NN', 1, 100)->{value}, 100;

    is xdr_decode($xdr->XDR_UNION('u_int', {
        1 => $xdr->XDR_U_INT,
        2 => $xdr->XDR_STRING,
    }) => pack 'NNa3x', 2, 3, 'abc')->{value}, 'abc';
};

done_testing;
