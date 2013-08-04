package Web::CSS::MediaQueries::Features;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::CSS::Values;

our $Defs;

$Defs->{color} = {
  parse => $Web::CSS::Values::NNIntegerParser,
}; # color

$Defs->{'min-color'} = {
  parse => $Web::CSS::Values::NNIntegerParser,
  requires_value => 1,
}; # min-color

$Defs->{'max-color'} = {
  parse => $Web::CSS::Values::NNIntegerParser,
  requires_value => 1,
}; # max-color

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
