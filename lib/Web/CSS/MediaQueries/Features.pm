package Web::CSS::MediaQueries::Features;
use strict;
use warnings;
use Web::CSS::Builder;
our $VERSION = '1.0';

our $Defs;

my $NNIntegerParser = sub {
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
};

$Defs->{color} = {
  parse => $NNIntegerParser,
}; # color

$Defs->{'min-color'} = {
  parse => $NNIntegerParser,
  requires_value => 1,
}; # min-color

$Defs->{'max-color'} = {
  parse => $NNIntegerParser,
  requires_value => 1,
}; # max-color

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
