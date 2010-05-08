package Exporter::Declare::Parser;
use strict;
use warnings;

use Devel::Declare;
use B::Compiling;
use B::Hooks::EndOfScope;
use Scalar::Util qw/blessed/;
use Carp;

###############
# Parser Registration and Retrieval
#
our %PARSER_AUTOLOAD = (
    begin     => 'Exporter::Declare::Parser::Begin',
    codeblock => 'Exporter::Declare::Parser::Codeblock',
    export    => 'Exporter::Declare::Parser::Export',
    method    => 'Exporter::Declare::Parser::Method',
    sublike   => 'Exporter::Declare::Parser::Sublike',
);

our %REGISTER;
sub register {
    my $class = shift;
    my ( $name  ) = @_;
    croak( "No name for registration" ) unless $name;
    croak( "Parser $name already registered" )
        if $REGISTER{ $name };
    $REGISTER{ $name } = $class;
}

sub get_parser {
    my $class = shift;
    my ( $name ) = @_;
    croak( "No name for parser" ) unless $name;
    if ( !$REGISTER{ $name } && $PARSER_AUTOLOAD{ $name }) {
        eval "require " . $PARSER_AUTOLOAD{$name} . "; 1" || die($@)
    }
    return $REGISTER{ $name };
}

##############
# Stash
#

our %STASH;

sub _stash {
    my ( $item ) = @_;
    my $id = "$item";
    $STASH{$id} = $item;
    return $id;
}

sub _unstash {
    my ( $id ) = @_;
    return delete $STASH{$id};
}

##############
# Class methods
#

sub enhance {
    my $class = shift;
    my ( $for, $name ) = @_;

    $class->_sanity;
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

sub _sanity {
    my $class = shift;
    if ( $class->run_at_compile && !eval { require Devel::BeginLift; 1 }) {
        bail( <<EOT );
Devel::BeginLift could not be found.
You must install Devel::BeginLift in order to use/export functions that run at
compile time.
Parser: @{[ $class ]}
This parser requires Devel::BeginLift.
$@
EOT
    }
}

sub _new {
    my $class = shift;
    my ( $name, $dec, $offset ) = @_;
    return bless( [ $name, $dec, $offset, $offset ], $class );
}

##############
# Accessors
#

my @ACCESSORS = qw/parts new_parts end_char original/;

{
    my $count = 0;
    for my $accessor ( qw/name declarator original_offset offset/, @ACCESSORS ) {
        my $idx = $count++;
        no strict 'refs';
        *$accessor = sub {
            my $self = shift;
            ( $self->[$idx] ) = @_ if @_;
            return $self->[$idx];
        };
    }
    no strict 'refs';
    *{ __PACKAGE__ . '::_last_index' } = sub { $count };
}

sub add_accessor {
    my $class = shift;
    my ( $accessor ) = @_;
    no strict 'refs';
    my $idx = $class->_last_index + ${ $class . '::_LAST_INDEX' }++;
    *{ $class . '::' . $accessor } = sub {
        my $self = shift;
        ( $self->[$idx] ) = @_ if @_;
        return $self->[$idx];
    };
}

###############
# Abstractable
#

sub type { 'const' }
sub quote_chars {( qw/ [ ( ' " / )};
sub end_chars {( qw/ { ; / )};
sub end_hook { 1 };
sub rewrite {
    my $self = shift;
    my $class = blessed( $self );
    bail( "You must override rewrite() in $class" );
}
sub inject {()}
sub run_at_compile { 0 }

###############
# Informational
#

our %QUOTEMAP = (
    '(' => ')',
    '{' => '}',
    '[' => ']',
    '<' => '>',
);

sub end_quote {
    my $self = shift;
    my ( $start ) = @_;
    return $QUOTEMAP{ $start } || $start;
}

sub linenum { PL_compiling->line }
sub filename { PL_compiling->file }

sub has_comma {
    my $self = shift;
    grep { $_ eq ',' } $self->has_non_string_or_quote_parts;
}

sub has_fat_comma {
    my $self = shift;
    grep { $_ eq '=>' } $self->has_non_string_or_quote_parts;
}

sub has_non_string_or_quote_parts {
    my $self = shift;
    grep { !ref($_) } @{ $self->parts };
}

sub has_string_or_quote_parts {
    my $self = shift;
    grep { ref($_) } @{ $self->parts };
}

sub has_keyword {
    my $self = shift;
    my ( $word ) = @_;
    return unless $word;
    grep {
        ref( $_ ) ? ($_->[1] eq $word) : ($_ eq $word)
    } @{ $self->parts };
}

################
# Debug
#

our $DEBUG = 0;
sub DEBUG {shift; ( $DEBUG ) = @_ if @_; $DEBUG }

sub diag { warn( _debug(@_)) }
sub bail { die( _debug(@_))  }

sub _debug {
    shift if blessed( $_[0] );

    my @caller = caller(1);
    my @msgs = (
        @_,
        DEBUG() ? (
            "\nCaller:      " . $caller[0] . "\n",
            "Caller file: " . $caller[1] . "\n",
            "Caller Line: " . $caller[2] . "\n",
        ) : (),
    );
    return ( @msgs, " at " . filename() . " line " . linenum() . "\n" );
}

################
# Line manipulation and advancement
#

sub line {
    my $self = shift;
    Devel::Declare::set_linestr($_[0]) if @_;
    return Devel::Declare::get_linestr();
}

sub advance {
    my $self = shift;
    my ( $len ) = @_;
    return unless $len;
    $self->offset( $self->offset + $len );
}

#sub strip_length {
#    my $self = shift;
#    my ($len) = @_;
#    return unless $len;
#
#    my $linestr = $self->line();
#    substr($linestr, $self->offset, $len) = '';
#    $self->line($linestr);
#}

sub skip_declarator {
    my $self = shift;
    $self->advance( length($self->name) );
}

sub skipspace {
    my $self = shift;
    $self->advance(
        Devel::Declare::toke_skipspace( $self->offset )
    );
}

################
# Public parsing interface
#

sub parse {
    my $self = shift;
    $self->original( $self->line );
    $self->skip_declarator;
    $self->skipspace;
    return if $self->peek_num_chars(1) eq '(';

    $self->parts( $self->get_remaining_items );
    $self->end_char( $self->peek_num_chars(1));

    $self->_apply_rewrite if $self->rewrite;
}

sub peek_item_type {
    my $self = shift;
    $self->skipspace;
    return 'quote' if $self->peek_is_quote;
    return 'word'  if $self->peek_is_word;
    return 'block' if $self->peek_is_block;
    return 'end'   if $self->peek_is_end;
    return 'other' if $self->peek_is_other;
    return undef;
}

sub peek_item {
    my $self = shift;
    $self->skipspace;

    my $type = $self->peek_item_type;
    return unless $type;

    my $method = "peek_$type";
    return unless $self->can( $method );

    my $item = $self->$method();
    return unless $item;

    return $item unless wantarray;
    return ( $item, $type );
}

sub peek_quote {
    my $self = shift;
    $self->skipspace;

    my $start = substr($self->line, $self->offset, 3);
    my $charstart = substr($start, 0, 1);
    return unless $self->peek_is_quote( $start, $charstart );

    my ( $length, $quoted ) = $self->_quoted_from_dd();

    return [ $quoted, $charstart ];
}

sub peek_word {
    my $self = shift;
    $self->skipspace;
    my $len = $self->peek_is_word;
    return unless $len;

    my $linestr = $self->line();
    my $name = substr($linestr, $self->offset, $len);
    return [ $name, undef ];
}

sub peek_other {
    my $self = shift;
    $self->skipspace;
    return if $self->peek_is_word;
    return if $self->peek_is_quote;
    return if $self->peek_is_end;
    return if $self->peek_is_block;
    return $self->peek_is_other;
}

sub peek_is_quote {
    my $self = shift;
    my ( $start ) = $self->peek_num_chars(1);
    return (grep { $_ eq $start } $self->quote_chars )
        || undef;
}

sub peek_is_word {
    my $self = shift;
    return $self->_peek_is_package
        || $self->_peek_is_word;
}

sub peek_is_block {
    my $self = shift;
    my ( $start ) = $self->peek_num_chars(1);
    return ($start eq '{')
        || undef;
}

sub peek_is_end {
    my $self = shift;
    my ( $start ) = $self->peek_num_chars(1);
    my ($end) = grep { $start eq $_ } $self->end_chars;
    return $end
        || $self->peek_is_block;
}

sub peek_is_other {
    my $self = shift;
    my $linestr = $self->line;
    substr( $linestr, 0, $self->offset ) = '';
    return unless $linestr =~ m/^(\S+)/;
    return $1;
}

sub peek_num_chars {
    my $self = shift;
    my @out = map { substr($self->line, $self->offset, $_) } @_;
    return @out if wantarray;
    return $out[0];
}

sub get_item {
    my $self = shift;
    return $self->_item_via_( 'advance' );
}

#sub strip_item {
#    my $self = shift;
#    return $self->_item_via_( 'strip_length' );
#}

sub get_remaining_items {
    my $self = shift;
    my @parts;
    while ( my $part = $self->get_item ) {
        push @parts => $part;
    }
    return \@parts;
}

#sub strip_remaining_items {
#    my $self = shift;
#    my @parts;
#    while ( my $part = $self->strip_item ) {
#        push @parts => $part;
#    }
#    return \@parts;
#}

sub peek_remaining {
    my $self = shift;
    return substr( $self->line, $self->offset );
}

###############
# Private parser interface
#

sub _peek_is_word {
    my $self = shift;
    return Devel::Declare::toke_scan_word($self->offset, 1)
        || undef;
}

sub _peek_is_package {
    my $self = shift;
    my $start = $self->peek_num_chars(1);
    return unless $start =~ m/^[A-Za-z_]$/;
    return unless $self->peek_remaining =~ m/^(\w+::[\w:]+)/;
    return length($1);
}

sub _linestr_offset_from_dd {
    my $self = shift;
    return Devel::Declare::get_linestr_offset()
}

sub _quoted_from_dd {
    my $self = shift;
    my $length = Devel::Declare::toke_scan_str($self->offset);
    my $quoted = Devel::Declare::get_lex_stuff();
    Devel::Declare::clear_lex_stuff();

    return ( $length, $quoted );
}

sub _item_via_ {
    my $self = shift;
    my ( $move_method ) = @_;

    my ( $item, $type ) = $self->peek_item;
    return unless $item;

    $self->_move_via_( 'advance', $type, $item );
    return $item;
}

sub _move_via_ {
    my $self = shift;
    my ( $method, $type, $item ) = @_;

    croak( "$method is not a valid move method" )
        unless $self->can( $method );

    if ( $type eq 'word' ) {
        $self->$method( $self->peek_is_word );
    }
    elsif ( $type eq 'quote' ) {
        my ( $len ) = $self->_quoted_from_dd();
        $self->$method( $len );
    }
    elsif ( $type eq 'other' ) {
        $self->$method( length( $item ));
    }
}

#############
# Rewriting interface
#

sub format_part {
    my $self = shift;
    my ( $part ) = @_;
    return unless $part;
    return $part unless ref($part);
    return "'" . $part->[0] . "'"
        unless $part->[1];
    return $part->[1] . $part->[0] . $self->end_quote( $part->[1] );
}

sub _apply_rewrite {
    my $self = shift;
    my $newline = $self->_open();
    $newline .= join( ', ',
        map { $self->format_part($_) }
            @{ $self->new_parts || [] }
    );
    $newline .= $self->_close();

    $self->end_hook( \$newline )
        if ( $self->end_char() ne '{' );

    diag(
        "Old Line: " . $self->line() . "\n",
        "New Line: " . $newline . "\n",
    ) if $self->DEBUG;
    $self->line( $newline );
}

sub prefix {
    my $self = shift;
    my $idx = $self->original_offset - 1;
    my $start = $idx < 0 ? '' : substr( $self->line, 0, $idx);
    return $start;
}

sub suffix {
    my $self = shift;
    return substr( $self->peek_remaining, 1 );
}

sub _open {
    my $self = shift;
    my $start = $self->prefix;
    return $start . $self->name . "( ";
}

sub _close {
    my $self = shift;
    my $end = $self->end_char();
    my $after_end = $self->suffix;
    return " )$end $after_end" unless $end eq '{';
    return ( @{$self->new_parts || []} ? ', ' : '' )
         . 'sub { '
         . join( '; ',
            $self->_block_end_injection,
            $self->inject
         )
         . '; '
         . $after_end;
}

#############
# Codeblock munging
#

sub _block_end_injection {
    my $self = shift;
    my $class = blessed( $self );

    my $id = _stash( $self );

    return "BEGIN { $class\->_edit_block_end('$id') }";
}

sub _edit_block_end {
    my $class = shift;
    my ( $id ) = @_;

    on_scope_end {
        $class->_scope_end($id);
    };
}

sub _scope_end {
    my $class = shift;
    my ( $id ) = @_;
    my $self = _unstash( $id );

    my $linestr = $self->line;
    $self->offset( $self->_linestr_offset_from_dd() );
    substr($linestr, $self->offset, 0) = ' );';
    $self->end_hook( \$linestr );
    $self->line($linestr);
}

1;

__END__

=head1 NAME

Exporter::Declare::Parser - Devel-Declare parser's for Exporter-Declare

=head1 DESCRIPTION

Parser is a module with a parser that provides hooks to alter behavior in
several predictably useful ways. Recipies should subclass this class.

=head1 INTERNALS

Parser objects are blessed arrays, not hashrefs.

=head1 ACCESSORS

=over 4

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the license for more details.
