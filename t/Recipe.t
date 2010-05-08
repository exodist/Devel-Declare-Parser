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
    $CLASS = 'Exporter::Declare::Recipe';
    $RCLASS = 'My::Recipe';
}

use_ok( $CLASS );

BEGIN {
    package My::Recipe;
    use strict;
    use warnings;
    use base 'Exporter::Declare::Recipe';
    use Data::Dumper;

    __PACKAGE__->DEBUG( 1 );
    __PACKAGE__->add_accessor( 'test_line' );
    __PACKAGE__->register( 'test' );

    sub line { shift->test_line( @_ )}

    sub _remaining {
        my $self = shift;
        return substr( $self->line, $self->offset );
    }

    sub skipspace {
        my $self = shift;
        return unless $self->_remaining =~ m/^(\s+)/;
        $self->advance(length($1));
    }

    #XXX !BEWARE! Will not work for nested quoting, even escaped
    #             This is a very dumb implementation.
    sub _quoted_from_dd {
        my $self = shift;
        my $start = $self->peek_num_chars(1);
        my $end = $self->end_quote( $start );
        my $regex = "^\\$start\([^$end]*)\\$end";
        $self->_remaining =~ m/$regex/;
        my $quoted = $1;

        croak( "qfdd regex: |$regex| did not get complete quote." )
            unless $quoted;

        return ( length( $quoted ) + 2, $quoted );
    }

    sub peek_is_word {
        my $self = shift;
        my $start = $self->peek_num_chars(1);
        return $start =~ m/^\w$/ ? 1 : 0;
    }

    sub _linestr_offset_from_dd {
        my $self = shift;
        die( 'Implement this' );
    }

    sub type { 'const' }
    sub end_hook { 1 };

    sub rewrite {
        my $self = shift;
        print Dumper( $self->parts );
        0;
    }
}

my $one = $RCLASS->_new( 'test', 'test', 0 );
$one->line( qq/test a b => "aaaaa" 'bbbb' , ( a => "b" ) [ 'a', 'b' ] . ;/ );
$one->parse;

is_deeply(
    $one->parts,
    [
        [ 'a', undef ],
        [ 'b', undef ],
        '=>',
        [ 'aaaaa', '"' ],
        [ 'bbbb', "'"  ],
        ',',
        [ 'a => "b"', '(' ],
        [ "'a', 'b'", '[' ],
        '.'
    ],
    "Parsed properly"
);

done_testing;

1;
