package Exporter::Declare::QuickRecipe;
use strict;
use warnings;

our $ANON = 'AAAAAAAA';

sub new {
    my $class = shift;
    my %proto = @_;
    my $anon = $ANON++;
    my $package = __PACKAGE__ . '::' . $anon;
    no strict 'refs';
    push @{ $package . '::ISA' } => 'Exporter::Declare::Recipe';
    for my $property ( keys %proto ) {
        *{ $package . '::' . $property } = sub { $proto{ $property }};
    }
    Exporter::Declare::Recipe->register( $anon, $package );
    return $anon;
}

1;
