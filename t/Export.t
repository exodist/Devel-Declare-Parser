#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception::LessClever;
use Data::Dumper;

sub test { $_[-1]->( @_ ) }

BEGIN {
    use_ok( 'Exporter::Declare::Parser::Export' );
    Exporter::Declare::Parser::Export->enhance( 'main', 'test' );
#    Exporter::Declare::Parser::Export->DEBUG(1);
}

our $ran;

test(
    'name',
    'parser',
    sub {
        $ran++;
        is( $_[0], 'name', "name" );
        is( $_[1], 'parser', 'parser' );
    },
);
is( $ran, 1, "ran 1 enclosed" );

test
(
    'name',
    'parser',
    sub {
        $ran++;
        is( $_[0], 'name', "name" );
        is( $_[1], 'parser', 'parser' );
    },
);
is( $ran, 2, "ran stepped enclosed" );

test name => sub {
    $ran++;
    is( $_[0], 'name', "name" );
}
is( $ran, 3, "Arrow form, no semicolon" );

test
    name
        =>
            sub
{
    $ran++;
    is( $_[0], 'name', "name" );
}
is( $ran, 4, "stepped Arrow form, no semicolon" );

test name => sub {
    $ran++;
    is( $_[0], 'name', "name" );
};
is( $ran, 5, "Arrow form + semicolon" );

test name parser {
    $ran++;
    is( $_[0], 'name', "name" );
    is( $_[1], 'parser', 'parser' );
}
is( $ran, 6, "name + parser + block" );

test name {
    $ran++;
    is( $_[0], 'name', "name" );
}
is( $ran, 7, "name + block" );

test name parser ( inject => 'my ($name, $parser) = @_' ) {
    $ran++;
    is( $name, 'name', "name" );
    is( $parser, 'parser', 'parser' );
}
is( $ran, 8, "name + parser + specs + block" );

test name ( inject => 'my ($name, $parser) = @_' ) {
    $ran++;
    is( $name, 'name', "name" );
    is( $parser, undef, 'no parser' );
}
is( $ran, 9, "name + specs + block" );

test
    name
        (
            inject => 'my ($name, $parser) = @_'
        )
{
    $ran++;
    is( $name, 'name', "name" );
    is( $parser, undef, 'no parser' );
}
is( $ran, 10, "name + specs + block stepped" );

test name, sub {
    $ran++;
    is( $_[0], 'name', "name" );
};
is( $ran, 11, "comma form" );

ok( !eval <<'EOT', "Invalid syntax" );
test name : sub {
    $ran++;
    is( $_[0], 'name', "name" );
};
EOT
like( $@, qr/Parsing Error, unrecognized tokens: ':' at /, "Useful message" );

ok( !eval 'test { die( "Should not get here" ) }; 1', "invalid syntax" );
like( $@, qr/You must provide a name to test\(\) at /, "Useful message" );

ok( !eval 'test a b c { "Should not get here" } 1', "invalid syntax" );
like( $@, qr/Syntax error near: 'c' at /, "Useful message" );

done_testing();
