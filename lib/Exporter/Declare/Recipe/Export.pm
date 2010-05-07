package Exporter::Declare::Recipe::Export;
use strict;
use warnings;

use base 'Exporter::Declare::Recipe';
__PACKAGE__->register( 'export' );

sub names {(qw/name recipe/)}
sub has_proto { 0 }
sub has_specs { 1 }
sub has_code  { 1 }
sub type { 'const' }

sub skip {
    my $self = shift;
    my $line = Devel::Declare::get_linestr();
    my $name = $self->name;
    return 1 if $line =~ m/$name\s*\(/;
    return 1 if $line =~ m/$name\s+[^\s]+\s*;/;
    return 1 if $line =~ m/$name\s+[^\s]+\s+(=>|,)/;
    return 0;
}


1;
