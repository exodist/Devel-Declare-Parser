#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception::LessClever;

sub test { $_[-1]->( @_ ) }

BEGIN {
    use_ok( 'Exporter::Declare::Parser::Sublike' );
    Exporter::Declare::Parser::Sublike->enhance( 'main', 'test' );
}

our $ran;

test( 'a', sub { $ran++, is( $_[0], 'a', "got name" ) });
is( $ran, 1, "ran enclosed" );

test a {
    $ran++;
    is( $_[0], 'a', "got name" );
}
is( $ran, 2, "ran multiline block no semicolon" );

test a {
    $ran++;
    is( $_[0], 'a', "got name" );
};
is( $ran, 3, "ran multiline block with semicolon" );

test a { $ran++; is( $_[0], 'a', "got name" ); };
is( $ran, 4, "ran singleline block with semicolon" );

test a { $ran++; is( $_[0], 'a', "got name" ); }
is( $ran, 5, "ran singleline block no semicolon" );

test 'quoted name' {
    $ran++;
    is( $_[0], 'quoted name', "got ' quoted name" );
}
is( $ran, 6, "ran singleline block no semicolon" );

test "quoted name" {
    $ran++;
    is( $_[0], 'quoted name', 'got " quoted name' );
}
is( $ran, 7, "ran singleline block no semicolon" );


ok( !eval 'test { die( "Should not get here" ) }; 1', "invalid syntax" );
like( $@, qr/You must provide a name to test\(\) at /, "Useful message" );

ok( !eval 'test a b c { "Should not get here" } 1', "invalid syntax" );
like( $@, qr/Syntax error near: 'b' and 'c' at /, "Useful message" );

done_testing();
