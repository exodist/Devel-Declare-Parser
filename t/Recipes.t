#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok( 'Exporter::Declare::Recipe::Export' );
    use_ok( 'Exporter::Declare::Recipe::Sublike' );
    use_ok( 'Exporter::Declare::Recipe::Codeblock' );
    use_ok( 'Exporter::Declare::Recipe::Method' );
    use_ok( 'Exporter::Declare::Recipe::Begin' );
}

BEGIN {
    package MyExporter;
    use strict;
    use warnings;
    use Test::More;
    use Exporter::Declare;

    export sl sublike {
        ok( $name, "Got name" );
        pop(@_)->();
    }

    export cb codeblock {
        pop(@_)->();
    }

    export mth method {
        pop(@_)->(1);
    }

    export beg begin {
        pop(@_)->();
    };
}

BEGIN { MyExporter->import };

my %ran;

sl a {
    $ran{sl}++;
}

our $BEGIN;
BEGIN { $BEGIN = 1 };
$BEGIN = 0;
ok( !$BEGIN, "reset begin" );
beg( sub { $ran{beg}++; ok( $BEGIN, "In Begin" )});

cb {
    $ran{cd}++;
}

mth {
    ok( $self, "got self" );
    $ran{mth}++;
}

ok( $ran{sl}, "ran sl" );
ok( $ran{cd}, "ran cd" );
ok( $ran{mth}, "ran mth" );
ok( $ran{beg}, "ran beg" );

done_testing();
