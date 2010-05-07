package Exporter::Declare::Recipe::Begin;
use strict;
use warnings;

use base 'Exporter::Declare::Recipe';
__PACKAGE__->register( 'begin' );

sub names {()}
sub type { 'const' }
sub run_at_compile { 1 }

sub recipe_inject { 'my $self = shift; ' }

1;
