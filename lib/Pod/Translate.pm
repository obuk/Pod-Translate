package Pod::Translate;

use warnings;
use strict;
use Carp;

use version;
our $VERSION = qv('0.0.4');
BEGIN { *DEBUG = sub () {0} unless defined &DEBUG }
use parent qw(Pod::Simple);

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

use File::Temp;
use Perl6::Slurp;

__PACKAGE__->_accessorize(qw/trans_opt/);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  $class->SUPER::new(@_)->init;
}

sub init {
  my ($self) = @_;
  $self->code_handler(\&code_process);
  $self->cut_handler(\&cut_process);
  $self;
}

sub code_process {
  my ($line, $line_count, $self) = @_;
  print {$self->output_fh} $line, "\n";
}

sub cut_process {
  my ($line, $line_count, $self) = @_;
  print {$self->output_fh} "\n", "=cut", "\n";
}

sub trans_shell {
  my $self = shift;
  my @trans_opt = @{$self->trans_opt};
  my @in = map { if (ref $_) { push @trans_opt, @$_; () } else { $_ } } @_;

  $self->{hint} = undef;

  local $_ = join ' ', @in;
  $self->preproc;

=begin comment

make $magic word that hardly appears in the dictionaries.

  $ ./script/magic.pl --length 4 --verbose /usr/share/dict/*
  0: x (773), 0: y (1580), 0: z (2002)
  1: j (126), 1: z (522), 1: k (1189)
  2: q (852), 2: j (1072), 2: z (1402)
  3: j (824), 3: q (1007), 3: x (1548)
  xjqj

=end comment

=cut

  my ($magic, $digits) = ('xjqj', 3);
  my $c = {
    format => "${magic}%0${digits}d",
    search => qr/(?i:${magic})(\d{${digits}})/,
    symtab => { },
    id => 1,
  };

  my $tmp = File::Temp->new(UNLINK => 1);
  binmode $tmp, ":utf8";
  print $tmp $self->mask($c);

  $self->hint(in => $_);
  my @trans = ('trans', @trans_opt);
  $self->hint(proc => "@trans");
  $_ = slurp '-|:utf8', @trans, -i => "$tmp";
  $self->hint(out => $_);

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
      my $name = "trans_$_";
      push @hint,
        "=begin $name\n\n",
        (map "$_\n", @$h, ''),
        "=end $name\n\n";
    }
  }
  wantarray ? @hint : @hint ? \@hint : undef;
}

sub mask {
  my ($self, $c) = @_;

  my @out;
  my @pos;

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
        my $v = substr($_, $pos[-1], pos($_) - $pos[-1]);
        $v = $&.$v if @out && $out[-1] =~ s/\S+$//; # xxxxx
        push @out, $self->symtab($c, $v);
      }
      pop @pos;
    }

  }

  for (@out) {
    s/[*$@%&\\]?\w+(::\w+)+/$self->symtab($c, $&)/eg;
  }

  $_ = join '', @out;
}

sub symtab {
  my ($self, $c, $v) = @_;
  my $k = sprintf $c->{format}, $c->{id}++;
  $c->{symtab}{$k} = $v;
  $k;
}

sub unmask {
  my ($self, $c) = @_;
  s/$c->{search}/do {
    my $k = sprintf $c->{format}, $1;
    my $v = $c->{symtab}{$k};
    delete $c->{symtab}{$k};
    $v || $k;
  }/eg;
  $_;
}

sub preproc {
  s/[BI]<([[a-z\d\s:;,.]*)>/$1/g;
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
    die "_ponder_Plain (? $command): ", Dumper($para);
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

  my @out;
  for my $option ([ -e => 'google' ], [ -e => 'bing' ]) {
    @out = $self->trans_shell($option, @in);
    print {$self->output_fh} $self->hint([qw/in out proc/])     if DEBUG;
    last unless my @cant = $self->hint('cant');
    print {$self->output_fh} @cant                              if DEBUG;
    @out = @in;
  }
  @out;
}

sub _ponder_Verbatim {
  my ($self, $para) = @_;
  my ($command, undef, @text) = @$para;
  print {$self->output_fh} $_, "\n" for @text;
  $self->SUPER::_ponder_Verbatim($para);
}

sub _ponder_for {
  my ($self,$para,$curr_open,$paras) = @_;
  my ($command, undef, @text) = @$para;
  print {$self->output_fh} $command, ' ';
  print {$self->output_fh} $_, "\n" for @text, '';
  $self->SUPER::_ponder_for($para,$curr_open,$paras);
}

sub _ponder_over {
  my ($self,$para,$curr_open,$paras) = @_;
  print {$self->output_fh} "=over ", $para->[2], "\n\n";
  $self->SUPER::_ponder_over($para,$curr_open,$paras);
}

sub _ponder_back {
  my ($self,$para,$curr_open,$paras) = @_;
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
