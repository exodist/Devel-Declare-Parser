#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
    package MyExporter;
    use strict;
    use warnings;
    use Test::More;
    use Exporter::Declare;
    use Test::Exception::LessClever;

    sub normal { 1 };
    export normala => sub { 1 };
    export normalb => \&normal;
    export normalc => 'normal';
    export normale => sub($$) { 1 };

    # export recipe name { ... }

    export typename typename ( inject => 'my $inject = 1;' ) {
        ok( $inject, "injected" );
        my $out = ok( $type, "Got a type" )
               && ok( $name, "Got a name" )
               && ok( $sub, "Got a sub" );
        $sub->( $type, $name, $sub );
        return $out;
    }

    export named named {
        my $out = ok( $name, "Got a name" )
               && ok( $sub, "Got a sub" );
        $sub->( $type, $name, $sub );
        return $out;
    }

    export name_proto name_proto
    {
        my $out = ok( $name, "Got a name" )
               && ok( $sub, "Got a sub" )
               && lives_ok { keys %proto };
        $sub->( $name, \%proto, $sub );
        return $out;
    }

    export type_name_proto type_name_proto
    {
        my $out = ok( $type, "Got a type" )
               && ok( $name, "Got a name" )
               && ok( $sub, "Got a sub" )
               && lives_ok { keys %proto };
        $sub->( $type, $name, \%proto $sub );
        return $out;
    }

    export semicolon named { ok( 1, "made it" ) };

    export newlines
      typename
      ( inject => 'my $inject = 1' )
    {
        ok( $inject, "injected" );
        my $out = ok( $type, "Got a type" )
               && ok( $name, "Got a name" )
               && ok( $sub, "Got a sub" );
        $sub->( $type, $name, $sub );
        return $out;
    }

    export wrap_begin wrap_begin {
        ok( !$main::BEGAN, "Done before run-time" );
        is( $_[0], "ARG-A" );
        is( $_[1], "ARG-B" );
    }
}

BEGIN { MyExporter->import() }

can_ok( __PACKAGE__, qw/normala normalb normalc normald normale typename named
name_proto semicolon newlines type_name_proto wrap_begin/ );

$main::BEGAN = 1;
wrap_begin qw/ARG-A ARG-B/;

typename type name {
    is( @_, 3, "3 params" );
    is( $_[0], "type", "type" );
    is( $_[1], "name", "name" );
    isa_ok( $_[2], 'CODE', "sub" );
}

newlines type name {
    is( @_, 3, "3 params" );
    is( $_[0], "type", "type" );
    is( $_[1], "name", "name" );
    isa_ok( $_[2], 'CODE', "sub" );
}

named name {
    is( @_, 2, "2 params" );
    is( $_[0], "name", "name" );
    isa_ok( $_[1], 'CODE', "sub" );
}

name_proto with_proto( a => 'a' ) {
    is( @_, 3, "3 params" );
    is( $_[0], "with_proto", "name" );
    isa_ok( $_[1], 'HASH', "proto" );
    is_deeply( $_[1], { a => 'a' }, "proto correct" );
    isa_ok( $_[2], 'CODE', "sub" );
}

name_proto empty_proto() {
    is( @_, 3, "3 params" );
    is( $_[0], "empty_proto", "name" );
    isa_ok( $_[1], 'HASH', "proto" );
    is_deeply( $_[1], {}, "proto correct" );
    isa_ok( $_[2], 'CODE', "sub" );
}

name_proto no_proto {
    is( @_, 3, "3 params" );
    is( $_[0], "no_proto", "name" );
    isa_ok( $_[1], 'HASH', "proto" );
    is_deeply( $_[1], {}, "proto correct" );
    isa_ok( $_[2], 'CODE', "sub" );
}

type_name_proto type twith_proto ( a => 'a', b => 'b' ) {
    is( @_, 4, "4 params" );
    is( $_[0], "type", "type" );
    is( $_[1], "twith_proto", "name" );
    isa_ok( $_[2], 'HASH', "proto" );
    is_deeply( $_[2], { a => 'a', b => 'b' }, "proto correct" );
    isa_ok( $_[3], 'CODE', "sub" );
}

type_name_proto type tempty_proto () {
    is( @_, 4, "4 params" );
    is( $_[0], "type", "type" );
    is( $_[1], "tempty_proto", "name" );
    isa_ok( $_[2], 'HASH', "proto" );
    is_deeply( $_[2], {}, "proto correct" );
    isa_ok( $_[3], 'CODE', "sub" );
}

type_name_proto type tno_proto {
    is( @_, 4, "4 params" );
    is( $_[0], "type", "type" );
    is( $_[1], "tno_proto", "name" );
    isa_ok( $_[2], 'HASH', "proto" );
    is_deeply( $_[2], {}, "proto correct" );
    isa_ok( $_[3], 'CODE', "sub" );
}

semicolon name { 1 }

newlines { 1 }

done_testing();
