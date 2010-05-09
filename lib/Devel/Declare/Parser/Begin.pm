package Devel::Declare::Parser::Begin;
use strict;
use warnings;

use base 'Devel::Declare::Parser';
__PACKAGE__->register( 'begin' );

sub run_at_compile { 1 }

1;

__END__

=head1 NAME

Devel::Declare::Parser::Begin - Parser for functions that happen at compile
time.

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Devel-Declare-Parser is free software; Standard perl licence.

Devel-Declare-Parser is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
