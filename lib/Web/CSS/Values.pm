package Web::CSS::Values;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::CSS::Builder;

## Values - CSS values are represented as an array reference whose
## zeroth item represents the data type (encoded as an uppercase
## word).
##
## NUMBER - Number (including integer)
##   1: Value as Perl number

our $NNIntegerParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2 and
      $us->[0]->{type} == NUMBER_TOKEN and
      $us->[0]->{number} =~ /\A[+-]?[0-9]+\z/) { # <integer>
    if ($us->[0]->{number} >= 0) {
      return ['NUMBER', 0+$us->[0]->{number}];
    }
  }
  $self->onerror->(type => 'css:value:not nninteger', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $NNIntegerParser

1;
