package Exporter::Declare::Recipe::Export;
use strict;
use warnings;

use B::Compiling;
use Exporter::Declare::QuickRecipe;

use base 'Exporter::Declare::Recipe';
__PACKAGE__->register( 'export' );

sub names {(qw/name recipe/)}
sub has_proto { 0 }
sub has_specs { 1 }
sub has_code  { 1 }
sub type { 'const' }

sub hook {
    my $self = shift;
    return unless my $spec = $self->parsed_specs;
    return unless my $rspec = $spec->{ recipe };
    if ( $self->parsed_names->[1] ) {
        my $line = PL_compiling->line;
        my $file = PL_compiling->file;
        die( "Custom recipe and actual recipe both specified at $file line $line\n" );
    }
    $self->parsed_names->[1] = Exporter::Declare::QuickRecipe->new(%$rspec);
}

sub recipe_inject {
    my $self = shift;
    my $recipename = $self->parsed_names->[1];
    return unless $recipename;
    my $recipe = Exporter::Declare::Recipe->get_recipe( $recipename );
    unless ( $recipe ) {
        my $line = PL_compiling->line;
        my $file = PL_compiling->file;
        die( "'$recipename' is not a valid recipe, did you forget to load the class that provides it? at $file line $line\n" )
    }
    my @names = $recipe->names;
    return map { "my \$$_ = shift;" } @names;
}

sub skip {
    my $self = shift;
    my $line = Devel::Declare::get_linestr();
    my $name = $self->name;
    return 1 if $line =~ m/$name\s+[^\s]+\s*;/;
    return 1 if $line =~ m/$name\s+[^\s]+\s+(=>|,)/;
    return 0;
}


1;
