package Exporter::Declare::Parser::Export;
use strict;
use warnings;

use base 'Exporter::Declare::Parser';
BEGIN { Exporter::Declare::Parser->register( 'export' )};

__PACKAGE__->add_accessor( '_inject' );

sub inject {
    my $self = shift;
    my $items = $self->_inject();
    return unless $items;
    return ( $items ) unless ref( $items );
    return @$items if ref( $items ) eq 'ARRAY';
    $self->bail( "$items is not a valid injection" );
}

sub _check_parts {
    my $self = shift;
    $self->bail( "You must provide a name to " . $self->name . "()" )
        if ( !$self->parts || !@{ $self->parts });

    if ( @{ $self->parts } > 3 ) {
        ( undef, undef, undef, my @bad ) = @{ $self->parts };
        $self->bail(
            "Syntax error near: " . join( ' and ',
                map { $self->format_part($_)} @bad
            )
        );
    }
}

sub sort_parts {
    my $self = shift;
    $self->bail(
        "Parsing Error, unrecognized tokens: "
        . join( ', ', map {"'$_'"} $self->has_non_string_or_quote_parts )
    ) if $self->has_non_string_or_quote_parts;

    my ( @names, @specs );
    for my $part (@{ $self->parts }) {
        $self->bail( "Bad part: $part" ) unless ref($part);
        $part->[1] && $part->[1] eq '('
            ? ( push @specs => $part )
            : ( push @names => $part )
    }

    if ( @names > 2 ) {
        ( undef, undef, my @bad ) = @names;
        $self->bail(
            "Syntax error near: " . join( ' and ',
                map { $self->format_part($_)} @bad
            )
        );
    }

    push @names => 'undef' unless @names > 1;

    return ( \@names, \@specs );
}

sub rewrite {
    my $self = shift;

    $self->_check_parts;

    my $is_arrow = $self->parts->[1]
                && ($self->parts->[1] eq '=>' || $self->parts->[1] eq ',');
    if (( $is_arrow && $self->parts->[2]->[0] eq 'sub')
    || ( @{ $self->parts } == 1 )) {
        $self->new_parts([ $self->parts->[0] ]);
        return 1;
    }

    my ( $names, $specs ) = $self->sort_parts();
    $self->new_parts( $names );

    if ( @$specs ) {
        $self->bail( "Too many spec defenitions" )
            if @$specs > 1;
        my $specs = eval "{ " . $specs->[0]->[0] . " }"
              || $self->bail($@);
        $self->_inject( delete $specs->{ inject });
    }

    1;
}

1;

__END__

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
