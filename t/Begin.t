#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception::LessClever;
use Devel::Declare::Parser;
use Devel::Declare::Parser::Begin;

BEGIN {
    eval { require Devel::BeginLift; 1 }
      || plan skip_all => 'Devel::BeginList is not installed';
    Devel::Declare::Parser::Begin->enhance( 'main', 'beg' );
}

our $ran;
is( $ran, 2, "ran beg twice already" );
sub beg { $_[0]->() }

our $BEGIN;
BEGIN { $BEGIN = 1 };
$BEGIN = 0;
ok( !$BEGIN, "reset begin" );
beg( sub { $ran++; ok( $BEGIN, "In Begin" )});
ok( !$BEGIN, "reset begin (still)" );

beg sub { $ran++; ok( $BEGIN, "In Begin still" )};

done_testing();
