package Web::CSS::MediaResolver;
use strict;
use warnings;
our $VERSION = '1.0';

sub new ($) {
  return bless {}, $_[0];
} # new

## Media-dependent RGB color range clipper
sub clip_color ($$) {
  my $value = $_[1];
  if (defined $value and $value->[0] eq 'RGBA') {
    my ($r, $g, $b) = @$value[1, 2, 3];
    $r = 0 if $r < 0;  $r = 255 if $r > 255;
    $g = 0 if $g < 0;  $g = 255 if $g > 255;
    $b = 0 if $b < 0;  $b = 255 if $b > 255;
    return ['RGBA', $r, $g, $b, $value->[4]];
  } else {
    return $value;
  }
} # clip_color

## System dependent font expander
sub get_system_font ($$$) {
  #my ($self, $normalized_system_font_name, $font_properties) = @_;
  
  ## Modify $font_properties hash (except for 'font-family' property).
  return $_[2];
} # get_system_font

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
