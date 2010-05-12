package Devel::Declare::Parser::Sublike;
use strict;
use warnings;

use base 'Devel::Declare::Parser';
use Devel::Declare::Interface;
Devel::Declare::Interface::register_parser( 'sublike' );

sub args {(qw/name sub/)}

sub rewrite {
    my $self = shift;

    if ( @{ $self->parts } > 1 ) {
        ( undef, my @bad ) = @{ $self->parts };
        $self->bail(
            "Syntax error near: " . join( ' and ',
                map { $self->format_part($_)} @bad
            )
        );
    }

    $self->new_parts([ $self->parts->[0] || 'undef' ]);
    1;
}

1;

__END__

=head1 NAME

Devel::Declare::Parser::Sublike - Parser that acts just like 'sub'

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Devel-Declare-Parser is free software; Standard perl licence.

Devel-Declare-Parser is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
