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

    # export name recipe { ... }

    export typename typename ( inject => 'my $inject = 1;' ) {
        ok( $inject, "injected" );
        my $out = ok( $type, "Got a type" )
               && ok( $name, "Got a name" )
               && ok( $sub, "Got a sub" );
        $sub->( $type, $name, $sub );
        return $out;
    }
}

done_testing();
