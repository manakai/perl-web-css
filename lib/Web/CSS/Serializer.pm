package Web::CSS::Serializer;
use strict;
use warnings;
our $VERSION = '1.17';
use Web::CSS::Props;

# XXX API is not stable

# XXX tests

sub new ($) {
  return bless {}, $_[0];
} # new

sub serialize_value ($$$) {
  my ($self, $prop_name, $value) = @_;
return '' if not defined $value; # XXX
  if ($value->[0] eq 'NUMBER' or $value->[0] eq 'WEIGHT') {
    ## TODO: What we currently do for 'font-weight' is different from
    ## any browser for lighter/bolder cases.  We need to fix this, but
    ## how?
    return $value->[1]; ## TODO: big or small number cases?
  } elsif ($value->[0] eq 'DIMENSION') {
    return $value->[1] . $value->[2]; ## NOTE: This is what browsers do.
  } elsif ($value->[0] eq 'PERCENTAGE') {
    return $value->[1] . '%';
  } elsif ($value->[0] eq 'KEYWORD' or $value->[0] eq 'PAGE') {
    return $value->[1];
  } elsif ($value->[0] eq 'URI') {
    ## NOTE: This is what browsers do.
    return 'url('.$value->[1].')';
  } elsif ($value->[0] eq 'RGBA') {
    if ($value->[4] == 1) {
      return 'rgb('.$value->[1].', '.$value->[2].', '.$value->[3].')';
    } elsif ($value->[4] == 0) {
      ## TODO: check what browsers do...
      return 'transparent';
    } else {
      return 'rgba('.$value->[1].', '.$value->[2].', '.$value->[3].', '
          .$value->[4].')';
    }
  } elsif ($value->[0] eq 'INHERIT') {
    return 'inherit';
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
          #    my $map = $$ss->{_nsmap};
          #    my $prefix = [grep { length } @{$map->{uri_to_prefixes}->{$_->[1]} or []}]->[0];
          #    if (defined $prefix) {
          #      'attr(' . $prefix . $_->[2] . ')';
          #    } else {
          #      ## Not serializable!
          #      'attr(' . $_->[2] . ')';
          #    }
          #  } else {
          #    ## Not serializable!
          #    'attr(' . $_->[2] . ')';
          #  }
          #} else {
            ## Not serializable!
            'attr(' . $_->[2] . ')';
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
    return '';
  }
} # $serialize_value

sub serialize_prop_value ($$$) {
  my ($self, $style, $css_name) = @_;

  my $prop_def = $Web::CSS::Props::Prop->{$css_name};
  if ($prop_def and defined $prop_def->{key}) {
    my $value = $style->{props}->{$prop_def->{key}};
    if (defined $value) {
      return $self->serialize_value ($prop_def->{css}, $value->[0]);
    } else {
      return '';
    }
  } elsif ($prop_def->{serialize_shorthand} or
           $prop_def->{serialize_multiple}) {
    # XXX
    my $v = eval {($prop_def->{serialize_shorthand} or
             $prop_def->{serialize_multiple})->($self, $style) };
    if (defined $v->{$prop_def->{css}}) {
      return $v->{$prop_def->{css}}->[0];
    } else {
      return '';
    }
    ## ISSUE: If one of shorthand component properties is !important?
  } else {
    die "Property |$css_name| is not supported";
  }
} # serialize_prop_value

sub serialize_prop_priority ($$$) {
  my ($self, $style, $css_name) = @_;
  my $prop_def = $Web::CSS::Props::Prop->{$css_name};
  if ($prop_def and defined $prop_def->{key}) {
    my $value = $style->{props}->{$css_name};
    return $value->[1] if defined $value;
  }
  # XXX for shorthand
  return '';
} # serialize_prop_priority

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
