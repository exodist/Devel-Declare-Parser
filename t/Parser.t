#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception::LessClever;
use Data::Dumper;
use Carp;

our $CLASS;
our $RCLASS;
BEGIN {
    $CLASS = 'Devel::Declare::Parser';
    $RCLASS = 'Devel::Declare::Parser::Emulate';
    use_ok( $CLASS );
    use_ok( $RCLASS );
}

my $one = $RCLASS->_new( 'test', 'test', 10 );
$one->line( qq/my \$xxx = test apple boy => "aaaaa" 'bbbb', (a => "b") ['a', 'b'] . \$xxx \%hash \@array \*glob Abc::DEF::HIJ { ... }/ );
$one->parse;

is_deeply(
    $one->parts,
    [
        [ 'apple', undef ],
        [ 'boy', undef ],
        '=>',
        [ 'aaaaa', '"' ],
        [ 'bbbb', "'"  ],
        ',',
        [ 'a => "b"', '(' ],
        [ "'a', 'b'", '[' ],
        '.',
        '$xxx',
        '%hash',
        '@array',
        '*glob',
        [ 'Abc::DEF::HIJ', undef ],
    ],
    "Parsed properly"
);

is(
    $one->line(),
    qq/my \$xxx = test('apple', 'boy', =>, "aaaaa", 'bbbb', ,, (a => "b"), ['a', 'b'], ., \$xxx, \%hash, \@array, \*glob, 'Abc::DEF::HIJ', sub { BEGIN { $RCLASS\->_edit_block_end('$one') };  ... } );/,
    "Got new line"
);

$one = $RCLASS->_new( 'test', 'test', 0 );
$one->line( qq/test apple boy;/ );
$one->parse;
is_deeply(
    $one->parts,
    [
        [ 'apple', undef ],
        [ 'boy', undef ],
    ],
    "Parts"
);
is( $one->line, "test('apple', 'boy'); ", "Non-codeblock" );


done_testing;

1;
