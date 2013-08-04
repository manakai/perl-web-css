package Web::CSS::MediaQueries::Features;
use strict;
use warnings;
our $VERSION = '2.0';
use Web::CSS::Values;

our $Defs;

$Defs->{width} = {
  parse => $Web::CSS::Values::NNLengthParser,
}; # width
$Defs->{'min-width'} = {
  parse => $Web::CSS::Values::NNLengthParser,
  requires_value => 1,
}; # min-width
$Defs->{'max-width'} = {
  parse => $Web::CSS::Values::NNLengthParser,
  requires_value => 1,
}; # max-width

$Defs->{height} = {
  parse => $Web::CSS::Values::NNLengthParser,
}; # height
$Defs->{'min-height'} = {
  parse => $Web::CSS::Values::NNLengthParser,
  requires_value => 1,
}; # min-height
$Defs->{'max-height'} = {
  parse => $Web::CSS::Values::NNLengthParser,
  requires_value => 1,
}; # max-height

$Defs->{'device-width'} = {
  parse => $Web::CSS::Values::NNLengthParser,
}; # device-width
$Defs->{'min-device-width'} = {
  parse => $Web::CSS::Values::NNLengthParser,
  requires_value => 1,
}; # min-device-width
$Defs->{'max-device-width'} = {
  parse => $Web::CSS::Values::NNLengthParser,
  requires_value => 1,
}; # max-device-width

$Defs->{'device-height'} = {
  parse => $Web::CSS::Values::NNLengthParser,
}; # device-height
$Defs->{'min-device-height'} = {
  parse => $Web::CSS::Values::NNLengthParser,
  requires_value => 1,
}; # min-device-height
$Defs->{'max-device-height'} = {
  parse => $Web::CSS::Values::NNLengthParser,
  requires_value => 1,
}; # max-device-height

$Defs->{orientation} = {
  parse => $Web::CSS::Values::GetKeywordParser->({
    portrait => 1, landscape => 1,
  }),
}; # orientation

$Defs->{'aspect-ratio'} = {
  parse => $Web::CSS::Values::RatioParser,
}; # aspect-ratio
$Defs->{'min-aspect-ratio'} = {
  parse => $Web::CSS::Values::RatioParser,
  requires_value => 1,
}; # min-aspect-ratio
$Defs->{'max-aspect-ratio'} = {
  parse => $Web::CSS::Values::RatioParser,
  requires_value => 1,
}; # max-aspect-ratio

$Defs->{'device-aspect-ratio'} = {
  parse => $Web::CSS::Values::RatioParser,
}; # device-aspect-ratio
$Defs->{'min-device-aspect-ratio'} = {
  parse => $Web::CSS::Values::RatioParser,
  requires_value => 1,
}; # min-device-aspect-ratio
$Defs->{'max-device-aspect-ratio'} = {
  parse => $Web::CSS::Values::RatioParser,
  requires_value => 1,
}; # max-device-aspect-ratio

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

$Defs->{'color-index'} = {
  parse => $Web::CSS::Values::NNIntegerParser,
}; # color-index
$Defs->{'min-color-index'} = {
  parse => $Web::CSS::Values::NNIntegerParser,
  requires_value => 1,
}; # min-color-index
$Defs->{'max-color-index'} = {
  parse => $Web::CSS::Values::NNIntegerParser,
  requires_value => 1,
}; # max-color-index

$Defs->{monochrome} = {
  parse => $Web::CSS::Values::NNIntegerParser,
}; # monochrome
$Defs->{'min-monochrome'} = {
  parse => $Web::CSS::Values::NNIntegerParser,
  requires_value => 1,
}; # min-monochrome
$Defs->{'max-monochrome'} = {
  parse => $Web::CSS::Values::NNIntegerParser,
  requires_value => 1,
}; # max-monochrome

$Defs->{resolution} = {
  parse => $Web::CSS::Values::ResolutionParser,
}; # resolution
$Defs->{'min-resolution'} = {
  parse => $Web::CSS::Values::ResolutionParser,
  requires_value => 1,
}; # min-resolution
$Defs->{'max-resolution'} = {
  parse => $Web::CSS::Values::ResolutionParser,
  requires_value => 1,
}; # max-resolution

$Defs->{scan} = {
  parse => $Web::CSS::Values::GetKeywordParser->({
    progressive => 1, interlace => 1,
  }),
}; # scan

$Defs->{grid} = {
  parse => $Web::CSS::Values::BooleanIntegerParser,
}; # grid

# XXX script pointer hover luminosity

$Defs->{'-webkit-device-pixel-ratio'} = {
  parse => $Web::CSS::Values::NNNumberParser,
}; # -webkit-device-pixel-ratio
$Defs->{'-moz-device-pixel-ratio'} = $Defs->{'-webkit-device-pixel-ratio'};
$Defs->{'-webkit-min-device-pixel-ratio'} = {
  parse => $Web::CSS::Values::NNNumberParser,
  requires_value => 1,
}; # -webkit-min-device-pixel-ratio
$Defs->{'-webkit-min-device-pixel-ratio'} = {
  parse => $Web::CSS::Values::NNNumberParser,
  requires_value => 1,
}; # -webkit-min-device-pixel-ratio
$Defs->{'-webkit-max-device-pixel-ratio'} = {
  parse => $Web::CSS::Values::NNNumberParser,
  requires_value => 1,
}; # -webkit-max-device-pixel-ratio

$Defs->{'view-mode'} = {
  parse => $Web::CSS::Values::GetKeywordParser->({
    windowed => 1, floating => 1, fullscreen => 1,
    maximized => 1, minimized => 1,
  }),
}; # view-mode

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
