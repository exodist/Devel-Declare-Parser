package Exporter::Declare::Recipe::Sublike;
use strict;
use warnings;

use base 'Exporter::Declare::Recipe';
__PACKAGE__->register( 'sublike' );

sub names {(qw/name/)}
sub has_proto { 0 }
sub has_specs { 0 }
sub has_code  { 1 }
sub type { 'const' }

1;
