package Exporter::Declare;
use strict;
use warnings;

use Carp;
use Scalar::Util qw/blessed/;
use Exporter::Declare::Recipe;
use Exporter::Declare::Recipe::Export;
use Exporter::Declare::Recipe::Sublike;
use Exporter::Declare::Recipe::Codeblock;
use Exporter::Declare::Recipe::Method;
use Exporter::Declare::Recipe::Begin;

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

sub recipes {
    my $class = shift;
    no strict 'refs';
    return { %{ $class . '::RECIPES' } };
}

sub export_to {
    my $class = shift;
    my ( $dest, $prefix, @list ) = @_;
    my $exports = $class->exports;
    my $recipes = $class->recipes;
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
        my $recipe = $recipes->{ $name };
        next unless $recipe;
        $recipe->rewrite( $dest, $name );
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
    my ( $name, $recipe ) = @_;

    croak( "You must provide a name to export()" )
        unless $name;
    $sub ||= $exporter->can( $name );
    croak( "No code found in '$exporter' for exported sub '$name'" )
        unless $sub;

    my $rclass;
    if ( $recipe ) {
        $rclass = Exporter::Declare::Recipe->get_recipe($recipe);
        croak( "'$recipe' is not a valid recipe, did you forget to load the class that provides it?" )
            unless $rclass;
    }

    my $export;
    my $recipes;
    {
        no strict 'refs';
        no warnings 'once';
        $export = \%{ $exporter . '::EXPORT' };
        $recipes = \%{ $exporter . '::RECIPES' };
    }
    $export->{ $name } = $sub;
    $recipes->{ $name } = $rclass if $rclass;
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

Exporter::Declare - Declarative function exporting

=head1 DESCRIPTION

Declarative function exporting. You can export subs as usual with @EXPORT, or
export anonymous subs under whatever name you want. You can also extend
Exporter::Declare very easily. You can also add an export from outside the
package using the export() class method on it.

Exporter-Declare also provides a friendly interface to L<Devel::Declare> magic.
If you want to provide methods that work like L<MooseX::Declare> or other
L<Devel::Declare> enhanced function, this is the module for you. There are a
few common recipes available for formatting exports.

=head1 EXPORTER SYNOPSIS

=head2 Basic usage (No Devel-Declare)

    package MyPackage;
    use strict;
    use warnings;
    use Exporter::Declare;

    # works as expected
    our @EXPORT = qw/a/;

    # Declare an anonymous export
    export b => sub { 'b' };

    export 'c';
    sub c { 'c' }
    sub a { 'a' }

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

    export d
    {
        'd'
    }

    1;

=head2 Exporting Devel-Declare magic

    export sl sublike {
        ok( $name, "Got name" );
        $code = pop(@_);
    }

    export cb codeblock {
        $code = pop(@_);
    }

    export mth method {
        $code = pop(@_);
    }

    export beg begin {
        my @args = @_;
    };

    # Inject something into the start of the code block
    export injected method ( inject => 'my $arg2 = shift; ' ) { ... }

    # If you are brave and read up on Recipe's:
    export custom ( recipe => \%myrecipe ) { ... }

Then to use those in the importing class:

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

=head2 Writing custom recipes

See L<Exporter::Declare::Recipe>

=head2 Provided Recipes

=over 4

=item L<Exporter::Declare::Recipe::Export>

Used for export()

=item L<Exporter::Declare::Recipe::Sublike>

Things that act like sub name {}

=item L<Exporter::Declare::Recipe::Codeblock>

Things that take a single codeblock as an arg. Like defining sub mysub(&)
except that you do not need a semicolon at the end.

=item L<Exporter::Declare::Recipe::Method>

Define codeblocks that have $self automatically shifted off.

=item L<Exporter::Declare::Recipe::Begin>

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
