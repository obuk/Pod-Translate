package Pod::Translate::JA;

use warnings;
use strict;
use Carp;

use version;
our $VERSION = qv('0.0.1');

use parent qw(Pod::Translate);
use utf8;

sub init {
  my ($self) = @_;
  $self->SUPER::init;
  $self->{trans} = [ qw/ -brief -no-auto -t ja / ];
  $self;
}

=begin comment

use Text::LineFold;

sub wrap {
  my ($init, $subs, @text) = @_;
  my $text = join '', @text;
  $text =~ s/([^!-~\p{P}])\s+([^!-~])/$1$2/g;
  my ($wrap, $enc) = (Text::LineFold->new, 'utf8');
  decode($enc, $wrap->fold($init, $subs, encode($enc, $text)));
}

=end comment

=cut

sub unmask {
  my ($self, $c) = @_;
  #my $s = $c->{s};
  s/$c->{unmask}/do {
    my $k = sprintf $c->{mask}, $1;
    my $v = $c->{symtab}{$k};
    delete $c->{symtab}{$k};
    $v || $k;
  }/eg;
}

sub preproc {
  # B<h>elp onB<l>y B<D>escribes B<t>ext B<U>nformatted
  s/\b((?i:[a-z]*))[BI]<((?i:[a-z]))>((?i:[a-z]+))/$1$2$3/g;
  # I<not> I<do not> I<any>
  s/[BI]<((?:do(?:es)?\s)not|any)>/\U$1\E/g;
}

use Encode::CJKConstants;

sub postproc {
  my $han = qr/[!-~]/;
  my $zen = qr/[\p{InHiragana}\p{InKatakana}\p{CJKUnifiedIdeographs}]/;
  tr/［｛（＜＞）｝］：；/\[{(<>)}\];:/;
  s/($han)($zen)/$1 $2/g;
  s/($zen)($han)/$1 $2/g;
  s/\s+([\>\)\]\}:;]+)/$1/g;
  s/([\[\{\(\<]+)\s+/$1/g;
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Pod::Translate::JA - [One line description of module's purpose here]


=head1 VERSION

This document describes Pod::Translate::JA version 0.0.1

=head1 SYNOPSIS

 use Pod::Translate::JA;

=head1 DESCRIPTION

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2017, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
