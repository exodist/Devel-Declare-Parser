package Exporter::Declare;
use strict;
use warnings;

use Carp;
use Scalar::Util qw/blessed/;
use Exporter::Declare::Parser;

our $VERSION = 0.006;
our @CARP_NOT = ( __PACKAGE__ );
export( 'export', 'export' );

sub import {
    my $class = shift;
    my $caller = caller;
    my ( $imports, $specs ) = $class->_import_args( @_ );
    $class->export_to( $caller, $specs->{prefix} || undef, @$imports );

    my $base = $specs->{extend} ? $class : 'Exporter::Declare::Base';

    no strict 'refs';
    no warnings 'once';
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
    no warnings 'once';
    return {
        ( map { $_ => $_ } @{ $class . '::EXPORT' }),
        %{ $class . '::EXPORT' },
    };
}

sub parsers {
    my $class = shift;
    no strict 'refs';
    no warnings 'once';
    return { %{ $class . '::PARSERS' } };
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
            no warnings 'once';
            *{ $dest . '::' . $writename } = $sub;
        }
        my $parser = $parsers->{ $name };
        next unless $parser;
        $parser->enhance( $dest, $name );
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
        $parsers = \%{ $exporter . '::PARSERS' };
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
With Exporter-Declare and its parser library, you can write L<Devel::Declare>
enhanced functions without directly using Devel-Declare. If no available parser
meets your needs you can subclass L<Exporter::Declare::Parser> which provides a
higher-level interface to L<Devel::Declare>

=head1 BASIC SYNOPSIS

If you want to avoid magic you can still easily declare exports:

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

=head1 ENHANCED INTERFACE SYNOPSIS

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

=head1 EXPORTING DEVEL-DECLARE INTERFACES SYNOPSIS

To export Devel-Declare magic you specify a parser as a second parameter to
export(). Please see the PARSERS section for more information about each
parser.

    package MyPackage;
    use strict;
    use warnings;
    use Exporter::Declare;

    export sl sublike {
        # $name and $sub are automatically shifted for you.
        ...
    }

    export mth method {
        # $name and $sub are automatically shifted for you.
        ...
    }

    export cb codeblock {
        # $sub is automatically shifted for you.
        ...
    }

    export beg begin {
        my @args = @_;
        ...
    };

    # Inject something into the start of the code block
    export injected method ( inject => 'my $arg2 = shift; ' ) { ... }

Then to use those in the importing class:

    use strict;
    use warnings;
    use MyPackage;

    sl name { ... }

    mth name {
        # $self is automatically shifted for you.
        ...
    }

    cb { ... }

    # Same as BEGIN { beg(@args) };
    beg( @args );

=head1 MANY FACES OF EXPORT

The export() function is the magical interface. It can be used in many forms:

=over 4

=item our @EXPORT = @names;

Technically your not actually using the function here, but it is worth noting
that use of a package variable '@EXPORT' works just like L<Exporter>. However
there is not currently an @EXPORT_OK.

=item export($name)

Export the sub specified by the string $name. This sub must be defined in the
current package.

=item export($name, sub { ... })

=item export name => sub { ... }

=item export name { ... }

Export the coderef under the specified name. In the second 2 forms an ending
semicolon is optional, as well name can be quoted in single or double quotes,
or left as a bareword.

=item export( $name, $parser )

Export the sub specified by the string $name, applying the magic from the
specified parser whenever the function is called by a class that imports it.

=item export( $name, $parser, sub { ... })

=item export name parser { ... }

Export the coderef under the specified name, applying the magic from the
specified parser whenever the function is called by a class that imports it. In
the second form name and parser can be quoted in single or double quotes, or
left as a bareword.

=item export name ( ... ) { ... }

same as 'export name { ... }' except that parameters can be passed into the
parser. Currently you cannot put any variables in the ( ... ) as it will be
evaluated as a string outside of any closures - This may be fixed in the
future.

Name can be a quoted string or a bareword.

=item export name parser ( ... ) { ... }

same as 'export name parser { ... }' except that parameters can be passed into
the parser. Currently you cannot put any variables in the ( ... ) as it will be
evaluated as a string outside of any closures - This may be fixed in the
future.

Name and parser can be a quoted string or a bareword.

=item $class->export( $name )

Method form of 'export( $name )'. $name must be the name of a subroutine in the
package $class. The export will be added as an export of $class.

=item $class->export( $name, sub { ... })

Method form of 'export( $name, \&code )'. The export will be added as an export
of $class.

=item $class->export( $name, $parser )

Method form of 'export( $name, $parser )'. $name must be the name of a
subroutine in the package $class. The export will be added as an export of
$class.

=item $class->export( $name, $parser, sub { ... })

Method form of 'export( $name, $parser, \&code )'. The export will be added as
an export of $class.

=back

=head1 IMPORTER SYNOPSIS

=head2 Normal

    package MyThing;
    use MyThingThatExports;

=head2 Import with a prefix

    package MyThing;
    use MyThingThatExports ':prefix:myprefix';

=head2 Import only some subs

    package MyThing;
    use MyThingThatExports qw/ sub_a sub_b /;

=head1 Extending (Writing your own Exporter-Declare)

Doing this will make it so that importing your package will not only import
your exports, but it will also make the importing package capable of exporting
subs.

    package MyExporterDeclare;
    use strict;
    use warnings;
    use Exporter::Declare ':extend';

    export my_export export {
        my ( $name, $sub ) = @_;
        export( $name, $sub );
    }

=head1 PARSERS

=head2 Writing custom parsers

See L<Exporter::Declare::Parser>

=head2 Provided Parsers

=over 4

=item L<Exporter::Declare::Parser::Export>

Used for functions that export, accepting a name, a parser, and options.

=item L<Exporter::Declare::Parser::Sublike>

Things that act like 'sub name {}'

=item L<Exporter::Declare::Parser::Method>

Same ad Sublike except codeblocks have $self automatically shifted off.

=item L<Exporter::Declare::Parser::Codeblock>

Things that take a single codeblock as an arg. Like defining sub mysub(&)
except that you do not need a semicolon at the end.

=item L<Exporter::Declare::Parser::Begin>

Define a sub that works like 'use' in that it runs at compile time (like
wrapping it in BEGIN{})

This requires L<Devel::BeginLift>.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
