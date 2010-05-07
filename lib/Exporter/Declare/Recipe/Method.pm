package Exporter::Declare::Recipe::Method;
use strict;
use warnings;

use base 'Exporter::Declare::Recipe';
__PACKAGE__->register( 'method' );

sub names {(qw//)}
sub has_proto { 0 }
sub has_specs { 0 }
sub has_code  { 1 }
sub type { 'const' }

sub recipe_inject { 'my $self = shift; ' }

1;
