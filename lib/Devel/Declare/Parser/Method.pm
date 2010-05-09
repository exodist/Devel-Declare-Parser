package Devel::Declare::Parser::Method;
use strict;
use warnings;

use base 'Devel::Declare::Parser::Sublike';
__PACKAGE__->register( 'method' );

sub inject {('my $self = shift')}

1;

=head1 NAME

Devel::Declare::Parser::Method - Parser that shifts $self automatically in
codeblocks.

=head1 TESTING ONLY

For testing purposes only.

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Devel-Declare is free software; Standard perl licence.

Devel-Declare is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
