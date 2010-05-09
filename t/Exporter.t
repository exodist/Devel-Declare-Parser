#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception::LessClever;

use_ok( "Exporter::Declare" );
BEGIN {
    use Exporter::Declare::Parser;
}

BEGIN {
    package Extended;
    use strict;
    use warnings;
    use Exporter::Declare ':extend';

    our @EXPORT = qw/a export/;

    export b => sub { 'b' };
    export 'c';

    sub a { 'a' }
    sub c { 'c' }

    package UseExtended;
    use strict;
    use warnings;
    Extended->import;

    export( 'c' => sub { 'c' } );

    package UseExtendedExtended;
    use strict;
    use warnings;
    UseExtended->import();

    package UsePrefix;
    use strict;
    use warnings;
    UseExtended->import( ':prefix:blah_' );

    package NormalUse;
    use strict;
    use warnings;
    use Exporter::Declare;
    use Test::Exception::LessClever;

    our @EXPORT = qw/f/;

    export e => sub { 'e' }

    export('y', undef, sub { 100 });

    export x export { 100 }

    export l { 100 }

    throws_ok { eval ' export z z { 1 } 1' || die $@ }
    qr/'z' is not a valid parser, did you forget to load the class that provides it?/,
    "Invalid parser";

    sub f { 'f' }
};

use Exporter::Declare;

export x { 100 }

can_ok( 'Extended', 'export' );
isa_ok( 'Extended', 'Exporter::Declare' );
is_deeply(
    [ sort keys %{ Extended->exports }],
    [qw/ a b c export /],
    "exports"
);

can_ok( 'UseExtended', 'export', 'a', 'b', 'c' );
ok( !UseExtended->isa( 'Extended' ), "Not an extended" );
isa_ok( 'UseExtended', 'Exporter::Declare' );
isa_ok( 'UseExtended', 'Exporter::Declare::Base' );
is_deeply(
    [ keys %{ UseExtended->exports }],
    [ 'c' ],
    "export",
);
UseExtended->export( 'd' => sub { 'd' });
is_deeply(
    [ keys %{ UseExtended->exports }],
    [ 'c', 'd' ],
    "export as class method",
);

can_ok( 'NormalUse', 'export' );
ok( !NormalUse->isa( 'Extended' ), "Not an extended" );
isa_ok( 'UseExtended', 'Exporter::Declare' );
isa_ok( 'UseExtended', 'Exporter::Declare::Base' );
is_deeply(
    [ sort keys %{ NormalUse->exports }],
    [ 'e', 'f', 'l', 'x', 'y', ],
    "Exports in normal use",
);

throws_ok { NormalUse::export() }
    qr/You must provide a name to export\(\)/,
    "Must provide a name";

throws_ok { NormalUse::export('bubba') }
    qr/No code found in 'main' for exported sub 'bubba'/,
    "Must have sub when adding export";

push @NormalUse::EXPORT => 'apple';
throws_ok { NormalUse->export_to( 'xxx' )}
    qr/Could not find sub 'apple' in NormalUse for export/,
    "Must have sub to export";
pop @NormalUse::EXPORT;

can_ok( 'UseExtendedExtended', 'c' );
ok( !UseExtendedExtended->isa( 'Extended' ), "Not an extended" );
ok( !UseExtendedExtended->isa( 'Extended::Declare' ), "Not a declare" );
ok( !UseExtendedExtended->isa( 'Extended::DeclareBase' ), "Not a declarebase" );
ok( !UseExtendedExtended->can( 'export' ), "Can't export" );

ok( !UsePrefix->can( 'c' ), "No c" );
can_ok( 'UsePrefix', 'blah_c' );

{
    package XXX::XXX;
    use strict;
    use warnings;
    use Test::More;
    use Test::Exception::LessClever;
    BEGIN { NormalUse->import() };
    is( l(), 100, "l works" );
    is( x(), 100, "x works" );
    my $x = x a { 100 }

    lives_and {
        is( $x, 100, "Value set" );
    };
}

done_testing;
