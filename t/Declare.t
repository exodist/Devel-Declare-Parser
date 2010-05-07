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
    export normale => sub($$) { 1 };

    # export name recipe { ... }

    export apple { 'apple' }

    export pear ( inject => 'my $pear = "pear";' ) { $pear }

    export eexport export ( inject => 'my $inject = 1;' ) {
        ok( $name, "got name" );
        ok( $recipe, "got recipe" );
        ok( $inject, "injected" );
    }

    export cres ( recipe => { names => 'input', has_code => 1 }) {
        ok( $input, "Got input" );
        100;
    }
}

BEGIN { MyExporter->import };

eexport name export { 1 };
is( apple(), "apple", "export name and block" );
is( pear(), "pear", "export name and block with specs" );

is( cres('a'), 100, "cres worked" );
my $out = cres a { 1 };
is( $out, 100, "stored output" );

done_testing();
