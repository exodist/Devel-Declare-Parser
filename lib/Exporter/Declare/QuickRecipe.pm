package Exporter::Declare::QuickRecipe;
use strict;
use warnings;

our $ANON = 'AAAAAAAA';

sub new {
    my $class = shift;
    my %proto = @_;
    my $anon = $ANON++;
    my $package = __PACKAGE__ . '::' . $anon;
    no strict 'refs';
    push @{ $package . '::ISA' } => 'Exporter::Declare::Recipe';
    for my $property ( keys %proto ) {
        *{ $package . '::' . $property } = sub { $proto{ $property }};
    }
    Exporter::Declare::Recipe->register( $anon, $package );
    return $anon;
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
