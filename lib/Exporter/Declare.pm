package Exporter::Declare;
use strict;
use warnings;

use Carp;
use Scalar::Util qw/blessed/;
use Exporter::Declare::Recipe;
use Exporter::Declare::Recipe::Export;

our $VERSION = 0.004;
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

Declarative function exporting. You can export subs as usualy with @EXPORT, or
export anonymous subs under whatever name you want. You can also extend
Exporter::Declare very easily. You can also add an export from outside the
package using the export() class method on it.

=head1 SYNOPSYS

Basic usage:

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

Extending:

    package MyExporterDeclare;
    use strict;
    use warnings;
    use Exporter::Declare ':extend';

    export my_export => sub {
        my ( $name, $sub ) = @_;
        export( $name, $sub );
    };

Import with a prefix:

    package MyThing;
    use strict;
    use warnings;
    use MyThingThatExports ':prefix:myprefix';

Import a list of subs only:

    package MyThing;
    use strict;
    use warnings;
    use MyThingThatExports qw/ sub_a sub_b /;

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
