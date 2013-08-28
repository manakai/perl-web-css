package Web::CSS::MediaResolver;
use strict;
use warnings;
our $VERSION = '5.0';

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
    }
  }

  if ($args{all} or $args{all_functions}) {
    $self->{function}->{$_} = 1 for qw(rgba);
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

  if ($args{all} or $args{all_features}) {
    require Web::CSS::MediaQueries::Features;
    $self->{feature}->{$_} = 1
        for keys %$Web::CSS::MediaQueries::Features::Defs;
  }
} # set_supported

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
