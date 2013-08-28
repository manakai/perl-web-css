package Web::CSS::Serializer;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '26.0';
use Web::CSS::Selectors::Serializer;
use Web::CSS::MediaQueries::Serializer;
use Web::CSS::Values::Serializer;
push our @ISA, qw(Web::CSS::Selectors::Serializer::_
                  Web::CSS::MediaQueries::Serializer::_
                  Web::CSS::Values::Serializer);
use Web::CSS::Props;

sub serialize_prop_value ($$$) {
  my ($self, $style, $prop_key) = @_;
  ## $style - A property struct (see Web::CSS::Parser)
  ## $key - The key of the property

  ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-value>.
  ## <http://dev.w3.org/csswg/cssom/#dom-cssstyledeclaration-getpropertyvalue>.

  if (defined $style->{prop_values}->{$prop_key}) {
    return $self->serialize_value ($style->{prop_values}->{$prop_key});
  } else {
    my $prop_def = $Web::CSS::Props::Key->{$prop_key};
    if (defined $prop_def and $prop_def->{serialize_shorthand}) {
      my $long_strings = {};
      my $css_wide;
      for (0..$#{$prop_def->{longhand_subprops}}) {
        my $key = $prop_def->{longhand_subprops}->[$_];
        $long_strings->{$key} = $self->serialize_prop_value ($style, $key);
        return undef unless defined $long_strings->{$key};
        if (defined $css_wide) {
          if ($long_strings->{$key} =~ /$Web::CSS::Values::CSSWidePattern/o) {
            return undef unless $css_wide eq $long_strings->{$key};
          } else {
            return undef;
          }
        } elsif ($_ == 0) {
          if ($long_strings->{$key} =~ /$Web::CSS::Values::CSSWidePattern/o) {
            $css_wide = $long_strings->{$key};
          }
        } else {
          if ($long_strings->{$key} =~ /$Web::CSS::Values::CSSWidePattern/o) {
            return undef;
          }
        }
      }
      return $css_wide if defined $css_wide;
      return $prop_def->{serialize_shorthand}->($self, $long_strings); # or undef
    } else {
      return undef;
    }
  }
} # serialize_prop_value

sub serialize_prop_priority ($$$) {
  my ($self, $style, $prop_key) = @_;
  ## $style - A property struct (see Web::CSS::Parser)
  ## $key - The key of the property

  ## <http://dev.w3.org/csswg/cssom/#dom-cssstyledeclaration-getpropertypriority>.

  if ($style->{prop_importants}->{$prop_key}) {
    return 'important';
  } else {
    my $prop_def = $Web::CSS::Props::Key->{$prop_key};
    if (defined $prop_def and defined $prop_def->{longhand_subprops}) {
      for (@{$prop_def->{longhand_subprops}}) {
        return undef unless $style->{prop_importants}->{$_};
      }
      return 'important';
    } else {
      return undef;
    }
  }
} # serialize_prop_priority

sub serialize_prop_decls ($$) {
  my ($self, $style) = @_;
  my @decl;
  my %done;

  ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-declaration-block>.

  for my $key (@{$style->{prop_keys}}) {
    next if $done{$key};
    my $def = $Web::CSS::Props::Key->{$key};
    my $short_key = $def->{shorthand_prop};
    if (defined $short_key) {
      my $short_def = $Web::CSS::Props::Key->{$short_key};
      my $has_important;
      my $has_non_important;
      for (@{$short_def->{longhand_subprops}}) {
        if ($style->{prop_importants}->{$_}) {
          $has_important = 1;
        } else {
          $has_non_important = 1;
        }
      }
      unless ($has_important and $has_non_important) {
        my $short_value = $self->serialize_prop_value ($style, $short_key);
        if (defined $short_value) {
          push @decl, $short_def->{css} . ': ' . $short_value .
              ($has_important ? ' !important' : '') . ';';
          $done{$_} = 1 for @{$short_def->{longhand_subprops}};
          next;
        }
        # XXX 'background' > 'background-position' > 'background-position-*'
        # XXX 'border' > 'border-{top|...}' / 'border-{style|...}' > ...
      }
    }
    
    my $value = $self->serialize_value ($style->{prop_values}->{$key});
    push @decl, $def->{css} . ': ' . $value
        . ($style->{prop_importants}->{$key} ? ' !important' : '') . ';';
    $done{$key} = 1;
  }

  return join ' ', @decl;
} # serialize_prop_decls

sub serialize_rule ($$$) {
  my ($self, $rule_set, $rule_id) = @_;
  my $rule = $rule_set->{rules}->[$rule_id];

  ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-rule> +
  ## Serializer.pod.

  if ($rule->{rule_type} eq 'style') {
    return $self->serialize_selectors ($rule->{selectors}) . ' { '
        . $self->serialize_prop_decls ($rule)
        . (@{$rule->{prop_keys}} ? ' ' : '') . '}';
  } elsif ($rule->{rule_type} eq 'media') {
    return '@media ' . $self->serialize_mq_list ($rule->{mqs}) . " { \x0A"
        . (join '', map { '  ' . $self->serialize_rule ($rule_set, $_) . "\x0A" } @{$rule->{rule_ids}})
        . '}';
  } elsif ($rule->{rule_type} eq 'namespace') {
    return '@namespace '
        . (defined $rule->{prefix} ? (_ident $rule->{prefix}) . ' ' : '')
        . 'url(' . (_string $rule->{nsurl}) . ');';
  } elsif ($rule->{rule_type} eq 'import') {
    return '@import url(' . (_string $rule->{href}) . ')'
        . (@{$rule->{mqs}} ? ' ' : '')
        . $self->serialize_mq_list ($rule->{mqs}) . ';';
  } elsif ($rule->{rule_type} eq 'charset') {
    return '@charset ' . (_string $rule->{encoding}) . ';';
  } elsif ($rule->{rule_type} eq 'sheet') {
    return join "\x0A", map { $self->serialize_rule ($rule_set, $_) } @{$rule->{rule_ids}};
  } else {
    die "Can't serialzie rule of type |$rule->{rule_type}|";
  }
} # serialize_rule

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
