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
    export 'normal';

    # export name parser { ... }

    export apple { 'apple' }

    export pear ( inject => 'my $pear = "pear";' ) { $pear }

    export eexport export ( inject => 'my $inject = 1;' ) {
        is( $name, "name", "got name" );
        is( $parser, "export", "got parser" );
        is( $inject, 1, "injected" );
    }
}

BEGIN { MyExporter->import };

eexport name export { 1 };
is( apple(), "apple", "export name and block" );
is( pear(), "pear", "export name and block with specs" );

done_testing();
