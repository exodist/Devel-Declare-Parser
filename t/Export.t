#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception::LessClever;
use Data::Dumper;

sub test { $_[-1]->( @_ ); $_[-1] }

BEGIN {
    use_ok( 'Devel::Declare::Parser::Export' );
    Devel::Declare::Interface::enhance( 'main', 'test', 'export' );
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

my $sub = test name => sub($$) { }
isa_ok( $sub, 'CODE' );
is( prototype( $sub ), '$$', "Carried prototype" );

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

test name export {
    $ran++;
    is( $name, 'name', "name" );
    is( $parser, 'export', 'parser' );
    ok( $sub, "got sub" );
}
is( $ran, 6, "name + parser + block" );

test name {
    $ran++;
    is( $_[0], 'name', "name" );
}
is( $ran, 7, "name + block" );

test name export ( inject => 'my ($x, $y) = (1,1)' ) {
    $ran++;
    is( $name, 'name', "name" );
    is( $parser, 'export', 'parser' );
    ok( $sub, "got sub" );
    is( $x, 1, "x" );
    is( $y, 1, "y" );
}
is( $ran, 8, "name + parser + specs + block" );

test name ( inject => 'my ($x, $y) = (1,1)' ) {
    $ran++;
    is( $_[0], 'name', "name" );
    is( $_[1], undef, 'no parser' );
    is( $x, 1, "x" );
    is( $y, 1, "y" );
}
is( $ran, 9, "name + specs + block" );

test
    name
        (
            inject => 'my ($x, $y) = (1,1)'
        ) {
    $ran++;
    is( $_[0], 'name', "name" );
    is( $_[1], undef, 'no parser' );
    is( $x, 1, "x" );
    is( $y, 1, "y" );
}

is( $ran, 10, "name + specs + block stepped" );

test name, sub {
    $ran++;
    is( $_[0], 'name', "name" );
};
is( $ran, 11, "comma form" );

    test b => sub { $ran++ };

is( $ran, 12, "indented" );

my $x = test b => sub { $ran++ };

is( $ran, 13, "assignment" );

test 'a long name' {
    $ran++;
    is( $_[0], 'a long name', "name" );
};
is( $ran, 14, "long name" );

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
