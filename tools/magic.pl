#!/usr/bin/env perl

use common::sense;
use Getopt::Long;

GetOptions('length=i' => \my $length, 'quit=i' => \my $quit,
           'verbose' => \my $verbose)
  or die "usage: $0 [--length=n] [--quit=n] [--verbose]\n";
$length ||= 3;

my %cc;
while (<>) {
  chop;
  last if $quit && $. >= $quit;
  next unless /^[a-z]{$length}/i;
  $_ = lc $_;
  my @c = /(.)/g;
  for my $i (0 .. $#c) {
    $cc{$i}{$c[$i]}++;
  }
}

my $magic;
for my $i (0 .. $length - 1) {
  my ($a, $b, $c) = sort { $cc{$i}{$a} <=> $cc{$i}{$b} } keys %{$cc{$i}};
  warn join(', ', map "$i: $_ ($cc{$i}{$_})", $a, $b, $c), "\n" if $verbose;
  $magic .= $a;
}

print $magic, "\n";
