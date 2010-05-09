package Devel::Declare::Parser::Codeblock;
use strict;
use warnings;

use base 'Devel::Declare::Parser';
__PACKAGE__->register( 'codeblock' );

sub args {(qw/sub/)}

sub rewrite {
    my $self = shift;
    $self->bail(
        "Syntax error near: " . join( ' and ',
            map { $self->format_part($_)}
                @{ $self->parts }
        )
    ) if $self->parts && @{ $self->parts };
    1;
}

1;

__END__

=head1 NAME

Devel::Declare::Parser::Codeblock - Parser for functions that just take a
codeblock.

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
