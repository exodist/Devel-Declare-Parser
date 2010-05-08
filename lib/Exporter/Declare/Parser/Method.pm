package Exporter::Declare::Parser::Method;
use strict;
use warnings;

use base 'Exporter::Declare::Parser::Sublike';
__PACKAGE__->register( 'method' );

sub inject {('my $self = shift')}

sub recipe_inject { 'my $self = shift; ' }

1;
