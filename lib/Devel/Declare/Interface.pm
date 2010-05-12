package Devel::Declare::Interface;
use strict;
use warnings;

use base 'Exporter';
use Carp;

our @EXPORT = qw/register_parser get_parser enhance/;

our %REGISTER = (
    codeblock => [ 'Devel::Declare::Parser::Codeblock', 0 ],
    export    => [ 'Devel::Declare::Parser::Export',    0 ],
    method    => [ 'Devel::Declare::Parser::Method',    0 ],
    sublike   => [ 'Devel::Declare::Parser::Sublike',   0 ],
);

sub register_parser {
    my ( $name, $rclass ) = @_;
    croak( "No name for registration" ) unless $name;
    $rclass ||= caller;
    croak( "Parser $name already registered" )
        if $REGISTER{ $name } && $REGISTER{ $name }->[0] ne $rclass;
    $REGISTER{ $name } = [ $rclass, 0 ];
}

sub get_parser {
    my ( $name ) = @_;
    croak( "No name for parser" ) unless $name;
    croak( "No parser found for $name" ) unless $REGISTER{$name};
    unless( $REGISTER{$name}->[1] ) {
        eval "require " . $REGISTER{$name}->[0] . "; 1" || die($@);
        $REGISTER{$name}->[1]++;
    }
    return $REGISTER{ $name }->[0];
}

sub enhance {
    my ( $for, $name, $parser, $type ) = @_;
    croak "You must specify a class, a function name, and a parser"
        unless $for && $name && $parser;
    $type ||= 'const';

    if ( $parser eq 'begin' ) {
        require Devel::BeginLift;
        return Devel::BeginLift->setup_for( $for => [$name] )
    }

    require Devel::Declare;
    Devel::Declare->setup_for(
        $for,
        {
            $name => {
                $type => sub {
                    my $pclass = get_parser( $parser );
                    my $parser = $pclass->new( $name, @_ );
                    $parser->process();
                }
            }
        }
    );
}

1;
