package Web::CSS::Serializer;
use strict;
use warnings;
our $VERSION = '22.0';
use Web::CSS::Selectors::Serializer;
use Web::CSS::MediaQueries::Serializer;
push our @ISA, qw(Web::CSS::Selectors::Serializer
                  Web::CSS::MediaQueries::Serializer);
use Web::CSS::Props;

sub new ($) {
  return bless {}, $_[0];
} # new

sub _number ($) {
  my $n = sprintf '%f', $_[0];
  $n =~ s/0+$//;
  $n =~ s/\.$//;
  $n =~ s/^-0$/0/;
  return $n;
} # _number

sub _string ($) {
  my $s = $_[0];
  ## XXX According to the CSSOM spec U+0000 must throw an exception.
  ## (Chrome does not throw.)
  $s =~ s{([\x00-\x1F\x7F-\x9F\"\\])}{
    $1 eq '\\' ? '\\\\' :
    $1 eq '"' ? '\\"' :
    sprintf '\\%x ', ord $1;
  }ge;
  return '"' . $s . '"';
} # _string

my $ValueSerializer = {
  KEYWORD => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>.
    return $_[0]->[1];
  },
  NUMBER => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>
    ## + Serializer.pod.
    return _number $_[0]->[1];
  },
  PERCENTAGE => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>
    ## + Serializer.pod.
    return _number ($_[0]->[1]) . '%';
  },
  RGBA => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>
    ## + Serializer.pod.
    my $alpha = _number $_[0]->[4];
    if ($alpha eq '1') {
      return 'rgb('.(_number $_[0]->[1]).', '.(_number $_[0]->[2]).', '.(_number $_[0]->[3]).')';
    } else {
      return 'rgba('.(_number $_[0]->[1]).', '.(_number $_[0]->[2]).', '.(_number $_[0]->[3]).', '.(_number $_[0]->[4]).')';
    }
  },
  STRING => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>.
    return _string $_[0]->[1];
  },
  URL => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>.
    return 'url(' . _string ($_[0]->[1]) . ')';
  },
  RATIO => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>
    ## + [MQ] + Serializer.pod.
    return _number ($_[0]->[1]) . '/' . _number ($_[0]->[2]);
  },

## COUNTER
##   XXX
## COUNTERS
##   XXX
## SETCOUNTER
##   XXX
## ADDCOUNTER
##   XXX
## RECT
##   XXX
## WEIGHT
##   XXX
## PAGE
##   XXX
## DECORATION
##   XXX
## QUOTES
##   XXX
## CONTENT
##   XXX
## FONT
##   XXX
## CURSOR
##   XXX
## MARKS
##   XXX
## SIZE
##   XXX
}; # $ValueSerializer

$ValueSerializer->{$_} = sub {
  ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>
  ## + Serializer.pod.
  return _number ($_[0]->[1]) . $_[0]->[2];
} for qw(ANGLE FREQUENCY LENGTH RESOLUTION TIME);

sub serialize_value ($$) {
  my ($self, $value) = @_;
  return ($ValueSerializer->{$value->[0]} || sub { die "Serializer for |$value->[0]| not implemented" })->($value);

  if ($value->[0] eq 'WEIGHT') {
    ## TODO: What we currently do for 'font-weight' is different from
    ## any browser for lighter/bolder cases.  We need to fix this, but
    ## how?
    return $value->[1]; ## TODO: big or small number cases?
  } elsif ($value->[0] eq 'PAGE') {
    return $value->[1];
  } elsif ($value->[0] eq 'URI') {
    ## NOTE: This is what browsers do.
    return 'url('.$value->[1].')';
  } elsif ($value->[0] eq 'DECORATION') {
    my @v = ();
    push @v, 'underline' if $value->[1];
    push @v, 'overline' if $value->[2];
    push @v, 'line-through' if $value->[3];
    push @v, 'blink' if $value->[4];
    return 'none' unless @v;
    return join ' ', @v;
  } elsif ($value->[0] eq 'QUOTES') {
    return join ' ', map {'"'.$_.'"'} map {$_->[0], $_->[1]} @{$value->[1]};
    ## NOTE: The result string might not be a <'quotes'> if it contains
    ## e.g. '"'.  In addition, it might not be a <'quotes'> if 
    ## @{$value->[1]} is empty (which is unlikely as long as the implementation
    ## is not broken).
  } elsif ($value->[0] eq 'CONTENT') {
    return join ' ', map {
      $_->[0] eq 'KEYWORD' ? $_->[1] :
      $_->[0] eq 'STRING' ? '"' . $_->[1] . '"' :
      $_->[0] eq 'URI' ? 'url(' . $_->[1] . ')' :
      $_->[0] eq 'ATTR' ? do {
        if (defined $_->[1]) {
          # XXX
          #my $rule = $self->parent_rule;
          #if ($rule) {
          #  my $ss = $rule->parent_style_sheet;
          #  if ($ss) {
              my $map = $self->{nsmap};
              my $prefix = [grep { length } @{$map->{uri_to_prefixes}->{$_->[1]} or []}]->[0];
              if (defined $prefix) {
                'attr(' . $prefix . $_->[2] . ')';
              } else {
                ## Not serializable!
                'attr(' . $_->[2] . ')';
              }
          #  } else {
          #    ## Not serializable!
          #    'attr(' . $_->[2] . ')';
          #  }
          #} else {
          #  ## Not serializable!
          #  'attr(' . $_->[2] . ')';
          #}
        } else {
          'attr(' . $_->[2] . ')';
        }
      } :
      $_->[0] eq 'COUNTER' ? 'counter(' . $_->[1] . ', ' . $_->[3] . ')' :
      $_->[0] eq 'COUNTERS' ? 'counters(' . $_->[1] . ', "' . $_->[2] . '", ' . $_->[3] . ')' :
      ''
    } @{$value}[1..$#$value];
  } elsif ($value->[0] eq 'RECT') {
    ## NOTE: Four components are DIMENSIONs.
    return 'rect(' . $value->[1]->[1].$value->[1]->[2] . ', '
          . $value->[2]->[1].$value->[2]->[2] . ', '
          . $value->[3]->[1].$value->[3]->[2] . ', '
          . $value->[4]->[1].$value->[4]->[2] . ')';
  } elsif ($value->[0] eq 'SETCOUNTER' or $value->[0] eq 'ADDCOUNTER') {
    return join ' ', map {$_->[0], $_->[1]} @$value[1..$#$value];
  } elsif ($value->[0] eq 'FONT') {
    return join ', ', map {
      if ($_->[0] eq 'STRING') {
        '"'.$_->[1].'"'; ## NOTE: This is what Firefox does.
      } elsif ($_->[0] eq 'KEYWORD') {
        $_->[1]; ## NOTE: This is what Firefox does.
      } else {
        ## NOTE: This should be an error.
        '""';
      }
    } @$value[1..$#$value];
  } elsif ($value->[0] eq 'CURSOR') {
    return join ', ', map {
      if ($_->[0] eq 'URI') {
        'url('.$_->[1].')'; ## NOTE: This is what Firefox does.
      } elsif ($_->[0] eq 'KEYWORD') {
        $_->[1];
      } else {
        ## NOTE: This should be an error.
        '""';
      }
    } @$value[1..$#$value];
  } elsif ($value->[0] eq 'MARKS') {
    if ($value->[1]) {
      if ($value->[2]) {
        return 'crop cross';
      } else {
        return 'crop';
      }
    } elsif ($value->[2]) {
      return 'cross';
    } else {
      return 'none';
    }
  } elsif ($value->[0] eq 'SIZE') {
    my $s1 = $value->[1]->[1] . $value->[1]->[2]; ## NOTE: They should be 
    my $s2 = $value->[2]->[1] . $value->[2]->[2]; ## 'DIMENSION's.
    if ($s1 eq $s2) {
      return $s1;
    } else {
      return $s1 . ' ' . $s2;
    }
  } else {
    return undef;
  }
} # serialize_value

# XXX API is not stable

# XXX tests

sub serialize_prop_value ($$$) {
  my ($self, $style, $css_name) = @_;
  # $style - A property struct (see Web::CSS::Parser)

  my $prop_def = $Web::CSS::Props::Prop->{$css_name};
  if (not defined $prop_def) {
    return undef;
  } elsif ($prop_def->{serialize_shorthand}) {
    my $v = $prop_def->{serialize_shorthand}->($self, $style);
    return $v->{$prop_def->{key}}; # or undef
  } else {
    my $value = $style->{prop_values}->{$prop_def->{key}};
    if (defined $value) {
      return $self->serialize_value ($prop_def->{css}, $value);
    } else {
      return undef;
    }
  }
} # serialize_prop_value

sub serialize_prop_priority ($$$) {
  my ($self, $style, $css_name) = @_;
  # $style - A property struct (see Web::CSS::Parser)

  my $prop_def = $Web::CSS::Props::Prop->{$css_name};
  if (not defined $prop_def) {
    return undef;
  } elsif ($prop_def->{longhand_subprops}) {
    for (@{$prop_def->{longhand_subprops}}) {
      return undef unless $style->{prop_importants}->{$_};
    }
    return 'important';
  } else {
    if ($style->{prop_importants}->{$prop_def->{key}}) {
      return 'important';
    }
    return undef;
  }
} # serialize_prop_priority

sub serialize_prop_decls ($$) {
  my ($self, $style) = @_;

  # XXX

  my @decl;
  for my $key (@{$style->{prop_keys}}) {
    my $css_name = $Web::CSS::Props::Key->{$key}->{css};
    my $value = $self->serialize_prop_value ($style, $css_name);
    my $priority = $self->serialize_prop_priority ($style, $css_name);
    push @decl, "$css_name: $value" . ($priority ? " !$priority" : '') . ';';
  }

  return join ' ', @decl;
} # serialize_prop_decls

sub serialize_rule ($$$) {
  my ($self, $rule_set, $rule_id) = @_;
  my $rule = $rule_set->{rules}->[$rule_id];

  if ($rule->{rule_type} eq 'style') {
    return $self->serialize_selectors ($rule->{selectors}) . ' { '
        . $self->serialize_prop_decls ($rule)
        . (@{$rule->{prop_keys}} ? ' ' : '') . '}';
  } elsif ($rule->{rule_type} eq 'media') {
    return '@media ' . $self->serialize_mq_list ($rule->{mqs}) . ' { ' # XXX
        . (join ' ', map { $self->serialize_rule ($rule_set, $_) } @{$rule->{rule_ids}})
        . ' }';
  } elsif ($rule->{rule_type} eq 'namespace') {
    return '@namespace '
        . (defined $rule->{prefix} ? $rule->{prefix} . ' ' : '')
        . 'url("' . $rule->{nsurl} . '");'; # XXX
  } elsif ($rule->{rule_type} eq 'import') {
    return '@import url("' . $rule->{href} . '")'
        . (@{$rule->{mqs}} ? ' ' : '')
        . $self->serialize_mq_list ($rule->{mqs}) . ';'; # XXX
  } elsif ($rule->{rule_type} eq 'charset') {
    return '@charset "' . $rule->{encoding} . '";'; # XXX
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
