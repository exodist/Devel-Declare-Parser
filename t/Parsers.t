#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok( 'Devel::Declare::Parser::Sublike', 'sl' );
    use_ok( 'Devel::Declare::Parser::Codeblock', 'cb' );
    use_ok( 'Devel::Declare::Parser::Method', 'mth' );
    Devel::Declare::Interface::enhance( 'main', $_->[0], $_->[1] )
        for [ 'sl', 'sublike'   ],
            [ 'cb', 'codeblock' ],
            [ 'mth', 'method'   ],
            [ 'beg', 'begin'    ];
}

sub
sl {
    $_[-1]->();
}

sub cb {
    $_[-1]->();
}

sub mth {
    $_[-1]->( 'self' );
}

sub beg {
    $_[-1]->();
};


our %ran;

sl a {
    $ran{sl}++;
}

sl {
    $ran{sl}++;
}

use vars qw/$BEGIN $got/;
our $BEGIN;
BEGIN { $BEGIN = 1 };
$BEGIN = 0;
ok( !$BEGIN, "reset begin" );
beg(
    sub {
        $ran{beg}++;
        $got = !!$BEGIN;
    }
);
ok( $got, "In Begin" );

ok( $ran{beg}, "ran beg" );

cb {
    $ran{cd}++;
}

mth a {
    is( $self, 'self', "got self" );
    $ran{mth}++;
}

is( $ran{sl}, 2, "ran sl twice" );
ok( $ran{cd}, "ran cd" );
ok( $ran{mth}, "ran mth" );

done_testing();
