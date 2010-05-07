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
    croak( "Recipe $name already registered" )
        if $class->get_recipe( $name );
    $REGISTER{ $name } = $package || caller;
}

sub get_recipe {
    my $class = shift;
    my ( $name ) = @_;
    croak( "No name for recipe" ) unless $name;
    $REGISTER{ $name };
}

sub names {()}
sub hook {};
sub type { 'const' }
sub skip { 0 }
sub has_proto { 0 }
sub has_specs { 0 }
sub has_code  { 0 }
sub run_at_compile { 0 }
sub recipe_inject {}

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

sub num_names {
    my $class = shift;
    my @names = $class->names;
    return scalar @names;
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
             . ( $self->num_names ? ',' : '' )
             . ( $proto ? "$proto, " : '' )
             . ( $self->has_code ? 'sub {' : $self->end_no_code )
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

__END__

=head1 NAME

Exporter::Declare::Recipe - Devel-Declare recipe's for Exporter-Declare

=head1 DESCRIPTION

Recipe is a module with a parser that provides hooks to alter behavior in
several predictably useful ways. Recipies should subclass this class.

=head1 INTERNALS

Recipe objects are blessed arrays, not hashrefs.

=head1 ACCESSORS

=over 4

=item name()

Name of the function that is magical

=item declarator()

Usually same as name

=item offset()

Current position on the line (for internal use)

=item at_end()

True if we have parsed to the end of the declaration (will be false, '{' or
';')

=item parsed_names()

Get the array of names that were parsed off the declaration.

    mydec a b { ... }

In the above 'a', and 'b' would be the parsed names.

=item parsed_specs()

if has_specs() returns true than this will be the hashref parsed from:

    mydec a ( THIS => 'STUFF' ) { ... }

=item proto_string()

if has_proto() returns true then this will be the raw string from:

    mydec a ( THIS STUFF ) { ... }

=back

=head1 BEHAVIOR MODIFIERS

=over 4

=item sub names {()}

Each name will be injected into the codeblock when your defining your exported
function.

    export my_func recipe_with_name_arga {
        is( $arga, 'my_func' );
    }

    export my_func arg_b recipe_with_name_arga_and_argb {
        is( $arga, 'my_func' );
        is( $argb, 'arg_b' );
    }

=item sub hook {};

Method called after parsing before outputing the expanded code. This is useful
if you want to munge anything in the accessors.

=item sub type { 'const' }

Type of export. See L<Devel::Declare> (sorry)

=item sub skip { 0 }

Will skip the current declaration and leave it unaltered if this returns true.

=item sub has_proto { 0 }

Override this to return true if you want to specify a proto (raw string in '()'
prior to the codeblock)

Not compatible with has_specs.

=item sub has_specs { 0 }

Override this to return true if you want to specify a specs hash which will be
read in and eval'd, then placed into parsed_proto().

Not compatible with has_proto.

=item sub has_code  { 0 }

Override this to return true if you want the functions defined with your recipe
to have codeblocks.

=item sub run_at_compile { 0 }

Override if you want the method to run in a begin block (not compatible with
any other option)

=item sub recipe_inject {}

Return a list of stringsw to inject into the codeblock (after other
injections).

=back

=head1 PARSING TOOLS

TODO

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
