package Exporter::Declare::Recipe;
use strict;
use warnings;

use Devel::Declare;
use B::Compiling;
use B::Hooks::EndOfScope;
use Scalar::Util qw/blessed/;

sub abstract { die "$_[0] must be overriden" }
sub num_names {
    my $class = shift;
    my @names = $class->names;
    return scalar @names;
}
sub names {()}
sub has_proto { 0 }
sub has_specs { 0 }
sub has_code  { 1 }
sub type { abstract 'type' }
sub skip { 0 }

{
    my $count = 0;
    for my $accessor ( qw/name declarator offset at_end/ ) {
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
    return bless( [ @_ ], $class );
}

sub rewrite {
    my $class = shift;
    my ( $for, $name ) = @_;

    Devel::Declare->setup_for(
        $for,
        { $name => { $class->type => sub { $class->_new( $name, @_ )->parse() }}}
    );
}

sub parse {
    my $self = shift;
    return if $self->skip;

    my $stripped = $self->get_name;
    die( "first token not " . $self->name )
        unless $stripped eq $self->name;

    my ( $proto, $specs, @names, @inject );
    push @names => $self->get_name() for 1 .. $self->num_names;
    $specs = $self->get_specs if $self->has_specs;
    $proto = $self->get_proto if $self->has_proto;

    $self->goto_end;

    $self->too_many_tokens unless $self->at_end;

    push @inject => $self->block_inject if $self->has_code;
    push @inject => $specs->{inject} if $specs->{inject};

    my $end = Devel::Declare::get_linestr();

    my $line = $self->name . "("
             . join(
                ", ",
                map {
                    $names[$_]
                        ? "'" . $names[$_] . "'"
                        : 'undef'
                } 0 .. ($self->num_names - 1)
               )
             . ( $proto ? ", $proto, " : '' )
             . ( $self->has_code ? ', sub {' : '' )
             . join( '', @inject )
             . ($end ? $end : '' );
    Devel::Declare::set_linestr($line);
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
    return " BEGIN { $class\->do_block_inject() }; "
         . ($self->has_code ? 'my $sub = pop( @_ ); ' : '')
         . 'my ( ' . $vars . ') = @_; '
}

sub do_block_inject {
    my $class = shift;
    my %specs = @_;
    on_scope_end {
        my $linestr = Devel::Declare::get_linestr;
        my $offset = Devel::Declare::get_linestr_offset;
        substr($linestr, $offset, 0) = ');';
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
