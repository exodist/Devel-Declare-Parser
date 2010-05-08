package Exporter::Declare;
use strict;
use warnings;

use Carp;
use Scalar::Util qw/blessed/;
use Exporter::Declare::Parser;

our $VERSION = 0.005;
our @CARP_NOT = ( __PACKAGE__ );
export( 'export', 'export' );

sub import {
    my $class = shift;
    my $caller = caller;
    my ( $imports, $specs ) = $class->_import_args( @_ );
    $class->export_to( $caller, $specs->{prefix} || undef, @$imports );

    my $base = $specs->{extend} ? $class : 'Exporter::Declare::Base';

    no strict 'refs';
    push @{ $caller . '::ISA' } => $base
        unless grep { $_ eq $base } @{ $caller . '::ISA' };
}

sub _import_args {
    my $class = shift;
    my ( @imports, %specs );
    for my $item ( @_ ) {
        if ( $item =~ m/^:([^:]*)(?::(.*))?$/ ) {
            $specs{ $1 } = $2 || 1;
        }
        else {
            push @imports => $item;
        }
    }
    return( \@imports, \%specs );
}

sub exports {
    my $class = shift;
    no strict 'refs';
    return {
        ( map { $_ => $_ } @{ $class . '::EXPORT' }),
        %{ $class . '::EXPORT' },
    };
}

sub parsers {
    my $class = shift;
    no strict 'refs';
    return { %{ $class . '::RECIPES' } };
}

sub export_to {
    my $class = shift;
    my ( $dest, $prefix, @list ) = @_;
    my $exports = $class->exports;
    my $parsers = $class->parsers;
    for my $name ( @list || keys %$exports ) {
        my $sub = $exports->{ $name };
        $sub = $class->can( $sub ) unless ref $sub eq 'CODE';

        croak( "Could not find sub '$name' in $class for export" )
            unless ref($sub) eq 'CODE';

        my $writename = $prefix ? $prefix . $name : $name;
        {
            no strict 'refs';
            *{ $dest . '::' . $writename } = $sub;
        }
        my $parser = $parsers->{ $name };
        next unless $parser;
        $parser->rewrite( $dest, $name );
    }
}

sub export {
    my ( $exporter, $sub );

    $sub = pop( @_ ) if ref( $_[-1] ) && ref( $_[-1] ) eq 'CODE';
    $exporter = shift( @_ ) if $_[0]
                            && (
                                blessed( $_[0] )
                             || (!ref($_[0]) && $_[0]->isa('Exporter::Declare'))
                            );

    $exporter = blessed( $exporter ) || $exporter || caller;
    my ( $name, $parser ) = @_;

    croak( "You must provide a name to export()" )
        unless $name;
    $sub ||= $exporter->can( $name );
    croak( "No code found in '$exporter' for exported sub '$name'" )
        unless $sub;

    my $rclass;
    if ( $parser ) {
        $rclass = Exporter::Declare::Parser->get_parser($parser);
        croak( "'$parser' is not a valid parser, did you forget to load the class that provides it?" )
            unless $rclass;
    }

    my $export;
    my $parsers;
    {
        no strict 'refs';
        no warnings 'once';
        $export = \%{ $exporter . '::EXPORT' };
        $parsers = \%{ $exporter . '::RECIPES' };
    }
    $export->{ $name } = $sub;
    $parsers->{ $name } = $rclass if $rclass;
}

package Exporter::Declare::Base;
use strict;
use warnings;
use base 'Exporter::Declare';

sub import {
    my $class = shift;
    my $caller = caller;
    my ( $imports, $specs ) = $class->_import_args( @_ );
    $class->export_to( $caller, $specs->{prefix} || undef, @$imports );
}

1;

__END__

=head1 NAME

Exporter::Declare - Declarative exports and simple Devel-Declare interface.

=head1 DESCRIPTION

Declarative function exporting. You can export subs as usual with @EXPORT, or
export anonymous subs under whatever name you want. You can also extend
Exporter::Declare very easily.

Exporter-Declare also provides a friendly interface to L<Devel::Declare> magic.
Provides a simple way to export functions with Devel-Declare magic. With
Exporter-Declare and its parser library, you can write L<Devel::Declare>
enhanced functions without directly using Devel-Declare or writing a custom
parser.

=head1 MANY FACES OF EXPORT

The export() function is the magical interface. It can be used in many forms:

=over 4

=item our @EXPORT = @names;

Technically your not actually using the function here, but it is worth noting
that use of a package variable '@EXPORT' works just like L<Exporter>. However
there is not currently an @EXPORT_OK.

=item export( $name )

Export the sub specified by the string $name. This sub must be defined in the
current package.

=item export( $name, \&code )

=item export name { ... }

Export the coderef under the specified name.

=item export( $name, $parser )

Export the sub specified by the string $name, applying the magic from the
specified parser whenever the function is called by a class that imports it.

=item export( $name, $parser, \&code )

=item export name parser { ... }

Export the coderef under the specified name, applying the magic from the
specified parser whenever the function is called by a class that imports it.

=item export name ( ... ) { ... }

same as 'export name { ... }' except that parameters can be passed into the
parser. Currently you cannot put any variables in the ( ... ) as it will be
evaluated as a string outside of any closures - This may be fixed in the
future.

=item export name parser ( ... ) { ... }

same as 'export name parser { ... }' except that parameters can be passed into
the parser. Currently you cannot put any variables in the ( ... ) as it will be
evaluated as a string outside of any closures - This may be fixed in the
future.

=item $class->export( $name )

Method form of 'export( $name )'. $name must be the name of a subroutine in the
package $class. The export will be added as an export of $class.

=item $class->export( $name, \&code )

Method form of 'export( $name, \&code )'. The export will be added as an export
of $class.

=item $class->export( $name, $parser )

Method form of 'export( $name, $parser )'. $name must be the name of a
subroutine in the package $class. The export will be added as an export of
$class.

=item $class->export( $name, $parser, \&code )

Method form of 'export( $name, $parser, \&code )'. The export will be added as
an export of $class.

=back

=head1 EXPORTING SYNOPSIS

=head2 Basic usage (No Devel-Declare)

    package MyPackage;
    use strict;
    use warnings;
    use Exporter::Declare;

    # works as expected
    our @EXPORT = qw/a/;

    sub a { 'a' }

    # Declare an anonymous export
    export b => sub { 'b' };
    export( 'c', sub { 'c' });

    export 'd';
    sub d { 'd' }

    1;

=head2 Enhanced Exporting

Notice, no need for '=> sub', and trailing semicolon is optional.

    package MyPackage;
    use strict;
    use warnings;
    use Exporter::Declare;

    # Declare an anonymous export
    export b { 'b' }

    export c {
        'c'
    }

    1;

=head2 Exporting Devel-Declare magic

To export Devel-Declare magic you specify a parser as a second parameter to
export(). Please see the RECIPIES section for more information about each
parser.

    package MyPackage;
    use strict;
    use warnings;
    use Exporter::Declare;

    ################################
    # export( 'name', 'parser_name' );
    #   or
    # export( 'name', 'parser name', sub { ... })
    #   or
    # export name parser_name { ... }

    export sl sublike {
        ok( $name, "Got name" );
        $code = pop(@_);
    }

    export cb codeblock {
        $code = pop(@_);
    }

    export mth method {
        ok( $name, "Got name" );
        $code = pop(@_);
    }

    export beg begin {
        my @args = @_;
    };

    # Inject something into the start of the code block
    export injected method ( inject => 'my $arg2 = shift; ' ) { ... }

Then to use those in the importing class:

    use strict;
    use warnings;
    use MyPackage;

    sl a { ... }

    cb { ... }

    mth {
        ok( $self, "got self" );
        ...
    }

    # Same as BEGIN { beg(@args) };
    beg( @args );

=head2 Extending (Writing your own Exporter-Declare)

    package MyExporterDeclare;
    use strict;
    use warnings;
    use Exporter::Declare ':extend';

    export my_export => sub {
        my ( $name, $sub ) = @_;
        export( $name, $sub );
    };

=head1 IMPORTER SYNOPSIS

=head2 Normal

    package MyThing;
    use strict;
    use warnings;
    use MyThingThatExports;

=head2 Import with a prefix

    package MyThing;
    use strict;
    use warnings;
    use MyThingThatExports ':prefix:myprefix';

=head2 Import only some subs

    package MyThing;
    use strict;
    use warnings;
    use MyThingThatExports qw/ sub_a sub_b /;

=head1 RECIPES

=head2 Writing custom parsers

See L<Exporter::Declare::Parser>

=head2 Provided Parsers

=over 4

=item L<Exporter::Declare::Parser::Export>

Used for export()

=item L<Exporter::Declare::Parser::Sublike>

Things that act like sub name {}

=item L<Exporter::Declare::Parser::Codeblock>

Things that take a single codeblock as an arg. Like defining sub mysub(&)
except that you do not need a semicolon at the end.

=item L<Exporter::Declare::Parser::Method>

Define codeblocks that have $self automatically shifted off.

=item L<Exporter::Declare::Parser::Begin>

Define a sub that works like 'use' in that it runs at compile time (like
wrapping it in BEGIN{})

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
