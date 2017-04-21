
package Pod::Perldoc::ToJA;

use strict;
use warnings;

use parent qw(Pod::Translate::JA);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    output_encoding => 'UTF-8',
    @_,
  );
  return $self;
}

1;

=for test_synopsis
1;
__END__

=head1 SYNOPSIS

  perldoc -o JA Some::Module

=cut
