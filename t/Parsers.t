#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception::LessClever;

sub sl {
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

BEGIN {
    use_ok( 'Devel::Declare::Parser::Sublike' );
    Devel::Declare::Parser::Sublike->enhance( 'main', 'sl' );
    use_ok( 'Devel::Declare::Parser::Codeblock' );
    Devel::Declare::Parser::Codeblock->enhance( 'main', 'cb' );
    use_ok( 'Devel::Declare::Parser::Method' );
    Devel::Declare::Parser::Method->enhance( 'main', 'mth' );
    use_ok( 'Devel::Declare::Parser::Begin' );
    Devel::Declare::Parser::Begin->enhance( 'main', 'beg' )
        if ( eval { require Devel::BeginLift; 1 } );
}

our %ran;

sl a {
    $ran{sl}++;
}

sl {
    $ran{sl}++;
}

lives_and {
    if ( eval { require Devel::BeginLift; 1 } ) {
eval <<'EOT' || die( $@ );
        our $BEGIN;
        BEGIN { $BEGIN = 1 };
        $BEGIN = 0;
        ok( !$BEGIN, "reset begin" );
        beg( sub { $ran{beg}++; ok( $BEGIN, "In Begin" )});

        ok( $ran{beg}, "ran beg" );
EOT
    }
    else {
        diag "Skipping Devel::BeginLift tests";
    }
} "Devel::Begin";

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
