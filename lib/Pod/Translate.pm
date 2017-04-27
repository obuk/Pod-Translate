package Pod::Translate;

use warnings;
use strict;
use Carp;

use version;
our $VERSION = qv('0.0.3');

use parent qw(Pod::Simple);

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

use File::Temp;
use Perl6::Slurp;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  $class->SUPER::new(@_)->init;
}

sub init {
  my ($self) = @_;
  $self->strip_verbatim_indent(
    sub {
      my $lines = shift;
      (my $indent = $lines->[0]) =~ s/\S.*//;
      return $indent;
    }
  );
  $self;
}

sub trans_shell {
  my $self = shift;
  my @trans_opt = @{$self->{trans}};
  my @in = map { if (ref $_) { push @trans_opt, @$_; () } else { $_ } } @_;

  $self->{hint} = undef;

  local $_ = join ' ', @in;
  $self->preproc;
  my $c = { mask => "\x{200B}id%03d\x{200B}", unmask => qr/(?i:id)(\d{3})/ };
  my $mask = $self->mask($c, $_);
  my $tmp = File::Temp->new( UNLINK => 1 );
  binmode $tmp, ":utf8";
  print $tmp $mask;

  $self->hint(before => $mask);
  my @trans = ('trans', @trans_opt, -i => "$tmp");
  $_ = slurp '-|:utf8', @trans;
  s/[\x{2009}\x{200B}]//g; # thin space
  $self->hint(after => $_);

  $self->postproc;
  $self->unmask($c);

  if (my %symtab = %{$c->{symtab}}) {
    $self->hint(cant => [ map { "$_ = $symtab{$_}" } sort keys %symtab ]);
  }

  $_;
}

sub hint {
  my ($self, $key, @value) = @_;
  if (@value) {
    push @{$self->{hint}{$key}}, map { ref($_)? @$_ : $_ } @value;
  }
  my @hint;
  for (map { ref($_)? @$_ : $_ } $key) {
    if (my $h = $self->{hint}{$_}) {
      push @hint, (
        "=begin ${_}_trans\n\n",
        (map "$_\n", @$h, ''),
        "=end ${_}_trans\n\n",
      );
    }
  }
  wantarray ? @hint : @hint ? \@hint : undef;
}

sub mask {
  my ($self, $c) = @_;

  my @out;
  my @pos;

  my $id = 1;
  $c->{symtab} = {};

  my @stack;

  while (
    m/\G
      (?:
        # Match starting codes, including the whitespace following a
        # multiple-delimiter start code.  $1 gets the whole start code and
        # $2 gets all but one of the <s in the multiple-bracket case.
        ([A-Z]<(?:(<+)\s+)?)
        |
        # Match multiple-bracket end codes.  $3 gets the whitespace that
        # should be discarded before an end bracket but kept in other cases
        # and $4 gets the end brackets themselves.
        (\s+|(?<=\s\s))(>{2,})
        |
        (\s?>)          # $5: simple end-codes
        |
        (               # $6: stuff containing no start-codes or end-codes
          (?:
            [^A-Z\s>]
            |
            (?:
              [A-Z](?!<)
            )
            |
            # whitespace is ok, but we don't want to eat the whitespace before
            # a multiple-bracket end code.
            # NOTE: we may still have problems with e.g. S<<    >>
            (?:
              \s(?!\s*>{2,})
            )
          )+
        )
      )
    /xgo
  ) {

    if (defined $1) {
      push @pos, pos($_) - length($1);              # xxxxx
      if (defined $2) {
        push @stack, length($2) + 1;
      } else {
        push @stack, 0;  # signal that we're looking for simple
      }

    } elsif (defined $4) {

      if (! @stack) {
        next;
      } elsif (!$stack[-1]) {
        pos($_) = pos($_) - length($4) + 1;
      } elsif ($stack[-1] == length($4)) {
      } elsif ($stack[-1] < length($4)) {
        pos($_) = pos($_) - length($4) + $stack[-1];
      } else {
        next;
      }

    } elsif (defined $5) {

      if (! @stack) {
        push @out, $5;
        next;
      } elsif (!$stack[-1]) {
      } elsif ($stack[-1]) {
        next;
      } else {
        next;
      }

    } elsif (defined $6) {

      push @out, $6 unless @pos;

    } else {
      die "SPORK 512512!";
    }

    if (defined $4 || defined $5) {
      pop @stack;
      if (!@stack && @pos) {
        my $x = sprintf $c->{mask}, $id++;
        my $y = substr($_, $pos[-1], pos($_) - $pos[-1]);
        $c->{symtab}{$x} = $y;
        push @out, $x;
      }
      pop @pos;
    }

  }

  for (@out) {
    s/[*$@%&\\]?\w+(::\w+)+/do {
      my $sym = sprintf $c->{mask}, $id++;
      $c->{symtab}{$sym} = $&;
      $sym;
    }/eg;
  }

  join '', @out;
}

sub unmask {
  my ($self, $c) = @_;
  s/$c->{unmask}/do {
    my $k = sprintf $c->{mask}, $1;
    my $v = $c->{symtab}{$k};
    delete $c->{symtab}{$k};
    $v || $k;
  }/eg;
  $_;
}

sub preproc {
}

sub postproc {
}

sub _handle_encoding_line {
  my ($self, $line) = @_;
  print {$self->output_fh} $line, "\n\n";
  $self->SUPER::_handle_encoding_line($line);
}

sub _ponder_Plain {
  my ($self, $para) = @_;
  #print "_ponder_Plain: ", Dumper($para);
  my ($command, $opts, @text) = @$para;
  if ($command =~ /^=item-text/) {
    print {$self->output_fh} "=item ";
  } elsif ($command =~ /^=item-bullet/) {
    print {$self->output_fh} "=item *\n\n";
    @text = $self->translate(@text);
  } elsif ($command =~ /^=item-number/) {
    print {$self->output_fh} "=item $opts->{number}\n\n";
    @text = $self->translate(@text);
  } elsif ($command =~ /^=/) {
    print {$self->output_fh} "$command ";
  } elsif ($command =~ /^Para/) {
    @text = $self->translate(@text);
  } else {
    print "_ponder_Plain (unknown): ", Dumper($para);
  }
  if (@text) {
    chomp(@text);
    print {$self->output_fh} $_, "\n" for @text, '';
  }
  $self->SUPER::_ponder_Plain($para);
}

sub translate {
  my ($self, @in) = @_;

  unless ($self->encoding) {
    $self->encoding('utf8');
  }
  binmode $self->output_fh, ":utf8";

  print {$self->output_fh} "=begin original\n\n";
  print {$self->output_fh} $_, "\n" for @in, '';
  print {$self->output_fh} "=end original\n\n";

  my $hint = 2;
  print {$self->output_fh} "=for engine google\n\n"		if $hint >= 2;
  my @out = $self->trans_shell([ -e => 'google' ], @in);
  if ($self->hint('cant')) {
    print {$self->output_fh} $self->hint([qw/before after cant/]) if $hint >= 2;
    print {$self->output_fh} "=for engine bing\n\n"		if $hint >= 2;
    my @other = $self->trans_shell([ -e => 'bing' ], @in);
    @out = @other unless $self->hint('cant');
  }
  @out;
}

sub _ponder_Verbatim {
  my ($self, $para) = @_;
  #print "_ponder_Verbatim: ", Dumper($para);
  my ($command, undef, @text) = @$para;
  print {$self->output_fh} $command, ' ' if $command =~ /^=/;
  print {$self->output_fh} $_, "\n" for @text, '';
  $self->SUPER::_ponder_Verbatim($para);
}

sub _ponder_Data {
  my ($self, $para) = @_;
  print "_ponder_Data: ", Dumper($para);
  $self->SUPER::_ponder_Data($para);
}

sub _ponder_for {
  my ($self,$para,$curr_open,$paras) = @_;
  #print "_ponder_for: ", Dumper($para,$curr_open,$paras);
  my ($command, undef, @text) = @$para;
  print {$self->output_fh} $command, ' ' if $command =~ /^=/;
  print {$self->output_fh} $_, "\n" for @text, '';
  $self->SUPER::_ponder_for($para,$curr_open,$paras);
}

sub _ponder_over {
  my ($self,$para,$curr_open,$paras) = @_;
  #print {$self->output_fh} "_ponder_over: ", Dumper($para,$curr_open,$paras);
  print {$self->output_fh} "=over ", $para->[2], "\n\n";
  $self->SUPER::_ponder_over($para,$curr_open,$paras);
}

sub _ponder_back {
  my ($self,$para,$curr_open,$paras) = @_;
  #print "_ponder_back: ", Dumper($para,$curr_open,$paras);
  print {$self->output_fh} "=back\n\n";
  $self->SUPER::_ponder_back($para,$curr_open,$paras);
}

1;
__END__

=head1 NAME

Pod::Translate - Pod translator

=head1 SYNOPSIS

 perldoc -L EN -o JA perlpod

=head1 INSTALLATION

To install this module, run the following commands:

 perl Makefile.PL
 make
 make test
 make install

=head1 DEPENDENCIES

L<https://github.com/soimort/translate-shell>

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2017, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
