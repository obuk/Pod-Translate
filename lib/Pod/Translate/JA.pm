package Pod::Translate::JA;

use warnings;
use strict;
use Carp;

use version;
our $VERSION = qv('0.0.3');

use parent qw(Pod::Translate);
use utf8;

sub init {
  my ($self) = @_;
  $self->SUPER::init;
  $self->{trans} = [ qw/ -brief -no-auto -t ja / ];
  $self;
}

sub preproc {
  s/[BI]<([[a-z\d\s:;,.]*)>/$1/g;
}

use Encode::CJKConstants;

sub postproc {
  my $han = qr/[!-~]/;
  my $zen = qr/[\p{InHiragana}\p{InKatakana}\p{CJKUnifiedIdeographs}]/;
  tr/［｛（＜＞）｝］：；＆/\[{(<>)}\]:;&/;
  s/($han)($zen)/$1 $2/g;
  s/($zen)($han)/$1 $2/g;
  s/\s+([\>\)\]\}:;]+|。、．，)/$1/g;
  s/([\[\{\(\<]+)\s+/$1/g;
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Pod::Translate::JA - to Japanese

=head1 SYNOPSIS

 use Pod::Translate::JA;

=head1 DESCRIPTION

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2017, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
