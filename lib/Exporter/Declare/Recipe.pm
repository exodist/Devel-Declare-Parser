package Exporter::Declare::Recipe;
use strict;
use warnings;

use Devel::Declare;
use B::Compiling;
use B::Hooks::EndOfScope;
use Scalar::Util qw/blessed/;
use Carp;
require Devel::BeginLift;

our %REGISTER;

sub register {
    my $class = shift;
    my ( $name, $package ) = @_;
    croak( "No name for registration" ) unless $name;
    $REGISTER{ $name } = $package || caller;
}

sub get_recipe {
    my $class = shift;
    my ( $name ) = @_;
    croak( "No name for recipe" ) unless $name;
    $REGISTER{ $name };
}

sub num_names {
    my $class = shift;
    my @names = $class->names;
    return scalar @names;
}
sub names {()}
sub has_proto { 0 }
sub has_specs { 0 }
sub has_code  { 1 }
sub run_at_compile { 0 }
sub recipe_inject {}
sub hook {};

sub type { 'const' }
sub skip { 0 };
sub _skip {
    my $self = shift;
    return 1 if $self->skip;

    my $line = Devel::Declare::get_linestr();
    substr( $line, 0, $self->offset ) = '';
    my $name = $self->name;
    return 1 if $line =~ m/^$name\s*\(/;
    return 0;
}

{
    my $count = 0;
    for my $accessor ( qw/name declarator offset at_end parsed_names parsed_specs proto_string/ ) {
        my $idx = $count++;
        no strict 'refs';
        *$accessor = sub {
            my $self = shift;
            ( $self->[$idx] ) = @_ if @_;
            return $self->[$idx];
        };
    }
}

sub _new {
    my $class = shift;
    $class->_sanity;
    return bless( [ @_ ], $class );
}

sub _sanity {
    my $class = shift;
    $class->type;
    die( "You cannot mix protos and specs" )
        if $class->has_proto && $class->has_specs;
    die( "You cannot mix run_at_compile with anything else" )
        if $class->run_at_compile && (
           $class->has_code ||
           $class->has_specs ||
           $class->has_proto
        );
}

sub rewrite {
    my $class = shift;
    my ( $for, $name ) = @_;

    if ( $class->run_at_compile ) {
        Devel::BeginLift->setup_for($for => [$name]);
    }
    else {
        Devel::Declare->setup_for(
            $for,
            { $name => { $class->type => sub { $class->_new( $name, @_ )->parse() }}}
        );
    }
}

sub verify_end {
    my $self = shift;
    $self->too_many_tokens unless $self->at_end;
    my $end = $self->at_end;
    my $line = PL_compiling->line;
    my $file = PL_compiling->file;
    die( "Code block is required near '$end' at $file line $line\n" )
        if $self->has_code && $end ne '{';
    die( "Code block is not allowed near '$end' at $file line $line\n" )
        if !$self->has_code && $end ne ';';
    1;
}

sub parse {
    my $self = shift;
    return if $self->_skip;

    $self->skip_declarator;
    my ( $proto, $specs, @names, @inject );
    push @names => $self->get_name() for $self->names;
    $specs = $self->get_specs if $self->has_specs;
    $proto = $self->get_proto if $self->has_proto;
    $proto =~ s/(^\s+|\s+$)// if $proto;

    $self->goto_end;
    $self->verify_end;

    $self->parsed_names( \@names );
    $self->parsed_specs( $specs );
    $self->proto_string( $proto );
    $self->hook();

    if ($self->has_code) {
        push @inject => $self->block_inject;
        push @inject => $self->recipe_inject if $self->recipe_inject;
        push @inject => $specs->{inject} if $specs->{inject};
    }

    my $linestr = Devel::Declare::get_linestr();

    my $insert = "("
             . join(
                ", ",
                map {
                    $names[$_]
                        ? "'" . $names[$_] . "'"
                        : 'undef'
                } 0 .. ($self->num_names - 1)
               )
             . ( $proto ? ", $proto " : '' )
             . ( $self->has_code ? ', sub {' : $self->end_no_code )
             . join( '', @inject );

    substr($linestr, $self->offset, 0) = $insert;
    Devel::Declare::set_linestr($linestr);
}

sub end_no_code {
    my $self = shift;
    my $out = ");";
    return $out;
}

sub skip_declarator {
    my $self = shift;
    $self->offset( $self->offset + length($self->name) );
}

sub get_name {
    my $self = shift;
    $self->skipspace;
    if (my $len = Devel::Declare::toke_scan_word($self->offset, 1)) {
        my $linestr = Devel::Declare::get_linestr();
        my $name = substr($linestr, $self->offset, $len);
        substr($linestr, $self->offset, $len) = '';
        Devel::Declare::set_linestr($linestr);
        return $name;
    }
    return;
}

sub strip_paren {
    my $self = shift;
    $self->skipspace;

    my $linestr = Devel::Declare::get_linestr();
    if (substr($linestr, $self->offset, 1) eq '(') {
        my $length = Devel::Declare::toke_scan_str($self->offset);
        my $paren = Devel::Declare::get_lex_stuff();
        Devel::Declare::clear_lex_stuff();
        $linestr = Devel::Declare::get_linestr();
        substr($linestr, $self->offset, $length) = '';
        Devel::Declare::set_linestr($linestr);
        return $paren;
    }
    return;
}

sub skipspace {
    my $self = shift;
    my $offset = $self->offset;
    $self->offset(
        $offset + Devel::Declare::toke_skipspace($offset)
    );
}

sub get_proto {
    my $self = shift;
    return $self->strip_paren;
}

sub get_specs {
    my $self = shift;
    my $paren = $self->strip_paren;
    return unless $paren;
    return eval "{$paren}";
}

sub goto_end {
    my $self = shift;
    $self->skipspace;
    my $linestr = Devel::Declare::get_linestr;
    my $at = substr($linestr, $self->offset, 1);
    $self->at_end( $at =~ m/^[;{]$/ ? $at : 0 );
    return unless $self->at_end;
    substr($linestr, $self->offset, 1) = '';
    Devel::Declare::set_linestr($linestr);
}

sub block_inject {
    my $self = shift;
    my $class = blessed( $self );

    my $vars = join(
        ", ",
        (map { "\$$_" } $self->names),
        '%proto'
    );
    return " BEGIN { $class\->do_block_inject() }; ";
}

sub do_block_inject {
    my $class = shift;
    my %specs = @_;
    on_scope_end {
        my $linestr = Devel::Declare::get_linestr;
        my $offset = Devel::Declare::get_linestr_offset;
        my $add = ');';
        substr($linestr, $offset, 0) = $add;
        Devel::Declare::set_linestr($linestr);
    };
}

sub too_many_tokens {
    my $self = shift;
    my $line = PL_compiling->line;
    my $file = PL_compiling->file;
    my $problem = Devel::Declare::get_linestr;
    chomp( $problem );
    $problem =~ s/^\s+//;

    die( "Invalid syntax near '$problem' at $file line $line\n" );
}


1;
