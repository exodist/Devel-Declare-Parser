package Devel::Declare::Parser;
use strict;
use warnings;

require Devel::Declare::Interface;
use Devel::Declare;
use B::Compiling;
use B::Hooks::EndOfScope;
use Scalar::Util qw/blessed/;
use Carp;

our $VERSION = '0.014';

sub new {
    my $class = shift;
    my ( $name, $dec, $offset ) = @_;
    return bless( [ $name, $dec, $offset, $offset ], $class );
}

sub process {
    my $self = shift;
    return unless $self->pre_parse();
    return unless $self->parse();
    return unless $self->post_parse();
    return unless $self->rewrite();
    return unless $self->write_line();
    return unless $self->edit_line();
    return 1;
}

###############
# Abstractable
#

sub quote_chars {( qw/ [ ( ' " / )};
sub end_chars {( qw/ { ; / )};

sub inject {()}
sub args {()}

sub pre_parse {
    my $self = shift;
    $self->skip_declarator;
    $self->skipspace;

    return if $self->is_defenition;
    return if $self->is_contained;
    return if $self->is_arrow_contained;
    return 1;
}

sub parse {
    my $self = shift;
    $self->parts( $self->strip_remaining_items );
    $self->end_char( $self->peek_num_chars(1));
    $self->strip_length(1) if $self->end_char eq '{';
    return 1;
}

sub post_parse { 1 }

sub rewrite {
    my $self = shift;
    $self->new_parts( $self->parts );
    1;
}

sub write_line {
    my $self = shift;
    my $newline = $self->open_line();

    $newline .= join( ', ',
        map { $self->format_part($_) }
            @{ $self->new_parts || [] }
    );

    $newline .= $self->close_line();

    my $line = $self->line;
    substr( $line, $self->offset, 0 ) = $newline;
    $self->line( $line );
    $self->diag( "New Line: " . $line . "\n" )
        if $self->DEBUG;

    1;
}

sub edit_line { 1 }

sub open_line { "(" }

sub close_line {
    my $self = shift;
    my $end = $self->end_char();
    return ")" if $end ne '{';
    return ( @{$self->new_parts || []} ? ', ' : '' )
         . 'sub'
         . ( $self->prototype ? $self->prototype : '' )
         .' { '
         . join( '; ',
            $self->inject,
            $self->_block_end_injection,
         )
         . '; ';
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
# Accessors
#

my @ACCESSORS = qw/parts new_parts end_char prototype contained/;

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

sub linenum  { PL_compiling->line }
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

sub strip_length {
    my $self = shift;
    my ($len) = @_;
    return unless $len;

    my $linestr = $self->line();
    substr($linestr, $self->offset, $len) = '';
    $self->line($linestr);
}

sub skip_declarator {
    my $self = shift;
    my $item = $self->peek_is_other;
    my $name = $self->name;
    if ( $item =~ m/^(.*)$name/ ) {
        $self->original_offset(
            $self->original_offset + length($1)
        );
    }
    $self->advance( length($item) );
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

sub is_defenition {
    my $self = shift;
    my $name = $self->declarator;
    return 1 if $self->line =~ m/sub[\s\n]+$name/sm;
    return 0;
}

sub is_contained {
    my $self = shift;
    return 0 unless $self->peek_num_chars(1);
    return 0 if $self->peek_num_chars(1) ne '(';
    $self->contained(1);
    return 1;
}

sub is_arrow_contained {
    my $self = shift;
    $self->skipspace;

    #Strip first item
    my $first = $self->strip_item;
    my $offset = $self->offset;

    # look at whats next
    $self->skipspace;
    my $stuff = $self->peek_remaining();

    # Put first back.
    my $line = $self->line;
    substr( $line, $offset, 0 ) = $self->format_part( $first, 1 ) || "";
    $self->offset( $offset );
    $self->line( $line );

    return 1 if $stuff =~ m/^=>[\s\n]*\(/sm;
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
    my $quote = join( '', $self->quote_chars );
    return unless $linestr =~ m/^([^\s;{$quote]+)/;
    return $1;
}

sub peek_num_chars {
    my $self = shift;
    my @out = map { substr($self->line, $self->offset, $_) } @_;
    return @out if wantarray;
    return $out[0];
}

sub strip_item {
    my $self = shift;
    return $self->_item_via_( 'strip_length' );
}

sub strip_remaining_items {
    my $self = shift;
    my @parts;
    while ( my $part = $self->strip_item ) {
        push @parts => $part;
    }
    return \@parts;
}

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

    $self->_move_via_( $move_method, $type, $item );
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
    my ( $part, $no_added_quotes ) = @_;
    return unless $part;
    return $part unless ref($part);
    return $part->[0] if $no_added_quotes && !$part->[1];
    return "'" . $part->[0] . "'"
        unless $part->[1];
    return $part->[1] . $part->[0] . $self->end_quote( $part->[1] );
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

    my $oldlinestr = $self->line;
    my $linestr = $oldlinestr;
    $self->offset( $self->_linestr_offset_from_dd() );
    if ( $linestr =~ m/}\s*$/ ) {
        substr($linestr, $self->offset, 0) = ' );';
    }
    else {
        substr($linestr, $self->offset, 0) = ' ) ';
    }
    $self->line($linestr);
    $self->diag(
        "Old Line: " . $oldlinestr . "\n",
        "New Line: " . $linestr . "\n",
    ) if $self->DEBUG;

}

1;

__END__

=head1 NAME

Devel::Declare::Parser - Devel-Declare parser's for Devel-Declare

=head1 DESCRIPTION

Parser is a higher-level API sitting on top of L<Devel::Declare>. It is used by
L<Devel::Declare> to simplify exporting of L<Devel::Declare> magic.
Devel-Declare allows you to modify a subroutine call as it is being compiled
(or right before it is compiled).

A parser should subclass this package and implement the rewrite() method. By
the time rewrite is called parse() will have already read the current
declaration line into an array of datastructures called 'parts'. Rewrite's job
is to move, copy, or create new 'parts' which will then be assembled into the
new line.

=head1 SYNOPSIS

    package MyParser;
    use strict;
    use warnings;

    use base 'Devel::Declare::Parser';

    # Register your parser with a simple name.
    # This is optional, but helpful to people using your parser.
    __PACKAGE__->register( 'my_method' );

    sub rewrite {
        my $self = shift;

        # If there is more than one argument before the opening { throw an
        # exception.
        if ( @{ $self->parts } > 1 ) {
            # Get the parts and remove the first (good) item.
            my @parts = @{ $self->parts };
            shift( @parts );

            # use bail() instead of die or croak for context.
            $self->bail(
                "Syntax error near: " . join( ' and ',
                    map { $self->format_part($_)} @parts
                )
            );
        }

        # Set the first argument, or make it undef.
        $self->new_parts([ $self->parts->[0] || 'undef' ]);
    }

    sub inject {
        my $self = shift;
        # Inject self-shifting into the codeblock
        return ('my $self = shift');
    }

    1;

To use it:

    package My::Package;
    use strict;
    use warnings;

    use MyParser qw/my_func/;

    sub my_func {
        my ( $name, $code ) = @_;
        croak( "You did not define a subroutine" )
            unless $code;
        return $code unless $name;
        no strict 'refs';
        *$name = $code;
    }

    my_func do_all_stuff {
        # Automatically have $self
        $self->do_stuff;
        $self->do_more_stuff;
    }

    my $anon = my_func { $self->... };

    1;

=head1 INTERNALS WARNING

B<Parser objects are blessed arrays, not hashrefs.>

If you want to create a new accessor use the add_accessor() class method. It
will take care of assigning an unused array element to the attribute, and will
create a read/write accessor sub for you.

    __PACKAGE__->add_accessor( 'my_accessor' );

There are many public and private methods on the parser base class. Only the
public methods are fully documented. Be sure to refer often to the list of
private methods at the end of this document, accidently overriding a private
method could have devestating consequences.

=head1 CLASS METHODS

These are methods not related to parsing. Some of these should be used by a
subclass, others by tools that provide your interface.

=head2 FOR INTERFACES

=over 4

=item register( $name, $class )

Register a parser class under a short name.

=item get_parser( $name )

Get the parser class registered under $name.

=item enhance( $class, $function )

Enhance $function in $class to use the magic provided by this parser.

=item add_accessor( $name )

Add an accessor to this parser, takes care of obtaining an array index for you.

=item DEBUG($bool)

Turn debugging on/off.

=back

=head2 UTILITY

=over 4

=item bail( @messages )

Like croak, dies providing you context information. Since the death occurs
inside the parser croak provides useless information.

=item diag( @message )

Like carp, warns providing you context information. Since the warn occurs
inside the parser carp provides useless information.

=item end_quote($start_char)

Find the end-character for the provide starting quote character. As in '{'
returns '}' and '(' returns ')'. If there is no counter-part the start
character is returned: "'" return "'".

=item filename()

Filename the rewrite is occuring against.

=item linenum()

Linenum the rewrite is occuring on.

=item format_part()

Returns the stringified form of a part datastructure.

=item prefix()

Returns everything on the line up to the declaration statement. This might be
something like '$x = '

=item suffix()

Returns everything on the line from the ending statement character to the end
of the actual line. This might be something like '|| die(...)'. B<NOTE> This
will only work after parsing is complete.

=back

=head1 EVENTUAL OUTPUT

Parser is designed such that it will transform any and all calls to the desired
method into proper method calls.

That is this:

    function x { ... }

Will become this:

    function( 'x', sub { ... });

B<Note> Parser does not read in the entire codeblock, rather it injects a
statement into the start of the block that uses a callback to attach the ');'
to the end of the statement. This is per the documentation of
L<Devel::Declare>. Reading in the entire sub is not a desirable scenario.

=head1 WORKFLOW OVERVIEW

When an enhanced function is found the proper parser will be instanciated,
thanks to Devel-Declare it just knows what line to manipulate. The offset and
declarator name are provided to the new object. Finally the parse() method is
called.

The parse() method will check if the call is contained,as in a call where all
the parameters are contained within a set of parens. If the call is not
contained the parser will parse the entire line into parts.

parts are placed in an arrayref in the parts() method. Once the parts are ready
the rewrite() method is called. The rewrite() method will take the parts, do
what it will with them, and then place the modified/replaces parts into the
new_parts() accessor.

Once rewrite() is finished the _apply_rewrite() method will join the prefix
data, the function call, the parts, and the postfix data into the new line
string. If there is a codeblock at the end of the line it will have some code
injected into it to append text to the end of the function call.

The new line is given to Devel-Declare, and compiling continues with the new
line.

=head1 PARSED PARTS

Each item between the declarator and the end of the statement (; or {) will be
turned into a part datastructure. Each type of element has a different form.

=over 4

=item operator, variable or other non-string/non-quote

These will be strings, nothing more

    "string"
    "=>"
    ","
    "+"
    "$var"

=item bareword or package name

These will be arrayrefs containing the stringified word/package name and undef.

    [ "string",      undef ]
    [ "My::Package", undef ]
    [ "sub_name",    undef ]

=item quoted item (includes things wrapped in [] or ())

These will be an arrayref containing a string of everything between the opening
and closing quote character, and the starting quote character.

    [ "string",    "'" ]
    [ "qw/a b c/", "[" ]
    [ "a => 'apple', b => 'bat'", "(" ]

=back

The parse() methid will populate the parts() accessor with an arrayref
containing all the parsed parts.

    print Dumper( $parser->parts() );
    $VAR1 = [
        [ 'bareword', undef ],
        '=>',
        [ 'quoted string', '\'' ],
        ...,
    ];

=head1 ACCESSORS

These are the read/write accessors used by Parser. B<Not all of these act on an
array element, some will directly alter the current line.>

=over 4

=item line()

This will retrieve the current line from Devel-Declare. If given a value that
value will be set as the current line using Devel-Declare.

=item name()

Name of the declarator as provided via the parser.

=item declarator()

Name of the declarator as provided via the Devel-Declare.

=item original_offset()

Offset on the line when the parsing was started.

=item offset()

Current line offset.

=item parts()

Arrayref of parts (may be undef)

=item new_parts()

Arrayref of new parts (may be undef)

=item end_char()

Will be set to the character just after the completely parsed line (usually {
or ;)

=item original()

Set to the original line at construction. B<NOTE> this will likely not be
complete, if the declaration spans multiple lines it will not be known when
this is set.

=item prototype()

Used internally for prototype tracking.

=item contained()

True if the parser determined this was a contained call.

=back

=head1 OVERRIDABLE METHODS

These are methods you can, should, or may override in your baseclass.

=over 4

=item rewrite()

You must override this.

=item type()

Returns 'const', see the L<Devel::Declare> docs for other options.

=item quote_chars()

Specify the starting characters for quoted strings. (returns a list)

=item end_chars()

Characters to recognise as end of statement characters (; and {) (returns a
list)

=item end_hook()

A chance for you to modify the new line just before it is set.

=item inject()

Code to inject into functions enhanced by this parser.

=item args()

Should return a list of names which will be injected as shifted scalars in
codeblocks created by function that have been enhanced by this parser.

=back

=head1 API METHODS

This is a general description of the inner working of the parser, most of these
are used internally before rewrite() is called. Many of these will do nothing,
or possibly do damage if used within rewrite(). This section is mainly useful
if you want to patch Parser, or override parse() with your own implementation
B<Not Recommended>.

=over 4

=item parse()

=back

=head2 POSITION TRACKING

=over 4

=item advance( $num_chars )

Advances the offset by $num_chars.

=item skip_declarator()

Skips the declarator at the start of the line. B<Only call this once, and
within parse()>

=item skipspace()

Advances the offset past any whitespace.

=back

=head2 PART RETRIEVAL (MODIFYING)

These get parts from the current position in the line. These B<WILL> modify the
line and/or the position in the line.

=over 4

=item get_item()

Returns a part datastructure.

=item get_remaining_items()

=item peek_quote()

=back

=head2 PART CHECKING

These check against parts that have already been parsed out of the line.

=over 4

=item has_comma()

=item has_fat_comma()

=item has_keyword()

=item has_non_string_or_quote_parts()

=item has_string_or_quote_parts()

=back

=head2 LOOKING AHEAD

These *should* not modify anything, but rather return parts of the line yet to
be parsed.

=over 4

=item peek_is_block()

=item peek_is_end()

=item peek_is_other()

=item peek_is_quote()

=item peek_is_word()

=item peek_item()

=item peek_item_type()

=item peek_num_chars($num)

=item peek_other()

=item peek_remaining()

=item peek_word()

=back

=head1 PRIVATE METHODS LIST

This is a list of private methods. This list is provided to help you avoid
overriding something you shouldn't. B<This list is not guarenteed to be
complete.>

=over 4

=item _apply_rewrite()

=item _block_end_injection()

=item _close()

=item _contained()

=item _debug()

=item _edit_block_end()

=item _is_defenition()

=item _item_via_()

=item _linestr_offset_from_dd()

=item _move_via_()

=item _new()

=item _open()

=item _peek_is_package()

=item _peek_is_word()

=item _quoted_from_dd()

=item _sanity()

=item _scope_end()

=item _stash()

=item _unstash()

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Devel-Declare-Parser is free software; Standard perl licence.

Devel-Declare-Parser is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
