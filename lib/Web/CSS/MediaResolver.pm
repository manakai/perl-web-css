package Web::CSS::MediaResolver;
use strict;
use warnings;
our $VERSION = '3.0';

sub new ($) {
  return bless {}, $_[0];
} # new

sub set_supported ($%) {
  my ($self, %args) = @_;

  if ($args{all} or $args{all_props}) {
    require Web::CSS::Props;
    $self->{prop}->{$_} = 1 for keys %$Web::CSS::Props::Prop;
  }

  if ($args{all} or $args{all_prop_values}) {
    require Web::CSS::Props;
    for my $pn (keys %$Web::CSS::Props::Prop) {
      for (keys %{$Web::CSS::Props::Prop->{$pn}->{keyword} or {}}) {
        $self->{prop_value}->{$pn}->{$_} = 1
            if $Web::CSS::Props::Prop->{$pn}->{keyword}->{$_};
      }
      for (keys %{$Web::CSS::Props::Prop->{$pn}->{keyword_replace} or {}}) {
        $self->{prop_value}->{$pn}->{$_} = 1
            if $Web::CSS::Props::Prop->{$pn}->{keyword_replace}->{$_};
      }
    }
  }

  if ($args{all} or $args{all_pseudo_classes}) {
    $self->{pseudo_class}->{$_} = 1 for qw/
      active checked disabled empty enabled first-child first-of-type
      focus hover indeterminate last-child last-of-type link only-child
      only-of-type root target visited
      lang nth-child nth-last-child nth-of-type nth-last-of-type not
      -manakai-contains -manakai-current
    /;
  }

  if ($args{all} or $args{all_pseudo_elements}) {
    $self->{pseudo_element}->{$_} = 1 for qw/
      after before first-letter first-line
    /;
  }
} # set_supported

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
