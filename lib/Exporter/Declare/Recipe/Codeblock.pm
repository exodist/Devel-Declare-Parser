package Exporter::Declare::Recipe::Codeblock;
use strict;
use warnings;

use base 'Exporter::Declare::Recipe';
__PACKAGE__->register( 'codeblock' );

sub names {(qw//)}
sub has_proto { 0 }
sub has_specs { 0 }
sub has_code  { 1 }
sub type { 'const' }

1;
