#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception::LessClever;

our $CLASS;
our $ECLASS;

our ( $PROTO, $SPECS, $CODE, $ATCOMPILE, $INJECT );
our @NAMES;

BEGIN {
    $CLASS = 'Exporter::Declare::Recipe';
    $ECLASS = 'My::Recipe';
    ( $PROTO, $SPECS, $CODE ) = (0, 0, 1);
    $ATCOMPILE = 0;
    @NAMES = qw/a b/;
}

use_ok( $CLASS );

{
    package My::Recipe;
    use strict;
    use warnings;
    use base 'Exporter::Declare::Recipe';

    sub names { @main::NAMES }
    sub has_proto { $main::PROTO }
    sub has_specs { $main::SPECS }
    sub has_code  { $main::CODE }
    sub run_at_compile { $main::ATCOMPILE }
    sub type { 'const' }
    sub recipe_inject { $main::INJECT }
}

sub test {
    my ($code);
    $code = pop( @_ ) if ref( $_[-1]) eq 'CODE';
    is( $code->(), 100, "Code return" ) if $code;
    unless ( $code ) {
        is( $_[0], 'name', "got name" );
    }
}

BEGIN {
    $ECLASS->rewrite( __PACKAGE__, 'test' );
}

test a b { 100 }

test a b {
    100
}

test a b
{
    100
}

test
 a
 b
 {
    100
 }

BEGIN {
    $PROTO = 1;
};

{
    test a b ( a => 'b' ) {
        100;
    }
}

test a b () {
    100;
}

test a b {
    100;
}

test  a  {
    100;
}

BEGIN {
    $PROTO = 0;
    $SPECS = 1;
    $INJECT = 'my $yyy = "yyy";';
    @NAMES = qw/a/;
};

test a (inject => 'my $xxx = "xxx";') {
    is( $xxx, 'xxx', "Injected" );
    is( $yyy, 'yyy', "Injected2" );
    100
}

BEGIN {
    $PROTO = 0;
    $SPECS = 1;
    $INJECT = undef;
    @NAMES = qw/a b c d e/;
};

test a b c d e (inject => 'my $xxx = "xxx";') {
    is( $xxx, 'xxx', "injected" );
    100
}

BEGIN {
    $PROTO = 0;
    $SPECS = 0;
    $CODE = 0;
    @NAMES = qw/a/;
};

test name;

BEGIN {
    $PROTO = 1;
    $SPECS = 0;
    $CODE = 0;
    @NAMES = qw/a/;
};

test name;

test name ( a => 'b' );

sub test2 {
    is( $_[0], 'name', "got name" );
    is( $main::INBEGIN, 1, "In beginning" );
}

lives_and {
    BEGIN {
        $main::PROTO = 0;
        $main::SPECS = 0;
        $main::ATCOMPILE = 1;
        $main::INBEGIN = 1;
        $main::CODE = 0;
        @NAMES = qw/a/;
        $ECLASS->rewrite( __PACKAGE__, 'test2' );
    };

    $main::INBEGIN = 0;
    is( $main::INBEGIN, 0, "replaced INBEGIN" );

    test2 name;
} "Just a wrapper";

done_testing;

1;
