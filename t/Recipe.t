#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;

our $CLASS;
our $ECLASS;

our ( $PROTO, $SPECS, $CODE );
our @NAMES;

BEGIN {
    $CLASS = 'Exporter::Declare::Recipe';
    $ECLASS = 'My::Exporter';
    ( $PROTO, $SPECS, $CODE ) = (0, 0, 1);
    @NAMES = qw/a b/;
}

use_ok( $CLASS );

{
    package My::Exporter;
    use strict;
    use warnings;
    use base 'Exporter::Declare::Recipe';

    sub names { @main::NAMES }
    sub has_proto { $main::PROTO }
    sub has_specs { $main::SPECS }
    sub has_code  { $main::CODE }
    sub type { 'const' }
}

sub test {
    my $code;
    $code = pop( @_ ) if ref( $_[-1]) eq 'CODE';
    $code->(@_, $code) if $code;
}

BEGIN {
    $ECLASS->rewrite( __PACKAGE__, 'test' );
}

test a b { is( $a, 'a' ); is( $b, 'b' ); isa_ok( $sub, 'CODE' ); 100 }

test a b {
    is( $a, 'a' );
    is( $b, 'b' );
    isa_ok( $sub, 'CODE' );
    100
}

test a b
{
    is( $a, 'a' );
    is( $b, 'b' );
    isa_ok( $sub, 'CODE' );
    100
}

test
 a
 b
 {
    is( $a, 'a' );
    is( $b, 'b' );
    isa_ok( $sub, 'CODE' );
    100
 }

BEGIN {
    $PROTO = 1;
};

test a b ( a => 'b' ) {
    is_deeply( \%proto, { a => 'b' });
    100;
}

test a b () {
    is_deeply( \%proto, {});
    100;
}

test a b {
    is_deeply( \%proto, {});
    100;
}

test  a  {
    is( $a, 'a' );
    is( $b, undef );
    100;
}

BEGIN {
    $PROTO = 0;
    $SPECS = 1;
    @NAMES = qw/a/
};

test a (inject => 'my $xxx = "xxx";') {
    is( $xxx, 'xxx' );
}

BEGIN {
    $PROTO = 0;
    $SPECS = 1;
    @NAMES = qw/a b c d e/
};

test a b c d e (inject => 'my $xxx = "xxx";') {
    is( $a, 'a' );
    is( $b, 'b' );
    is( $c, 'c' );
    is( $d, 'd' );
    is( $e, 'e' );
    is( $xxx, 'xxx' );
}

done_testing;
