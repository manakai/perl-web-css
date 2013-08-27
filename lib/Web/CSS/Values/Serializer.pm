package Web::CSS::Values::Serializer;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '1.0';
use Exporter::Lite;

## This module is not intended for standalone use.  See
## |Web::CSS::Serializer|.

our @EXPORT = qw(_number _string _ident);

sub new ($) {
  return bless {}, $_[0];
} # new

sub context ($;$) {
  if (@_ > 1) {
    $_[0]->{context} = $_[1];
  }
  return $_[0]->{context};
} # context

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

sub _ident ($) {
  my $s = $_[0];
  ## XXX According to the CSSOM spec U+0000 must throw an exception.
  ## (Chrome does not throw.)
  $s =~ s{([\x00-\x1F\x20\x7F-\x9F\"\\])}{
    $1 eq '\\' ? '\\\\' :
    $1 eq '"' ? '\\"' :
    $1 eq ' ' ? '\\ ' :
    sprintf '\\%x ', ord $1;
  }ge;
  $s =~ s{^(-|)([0-9])}{$1\\3$2 };
  $s =~ s{^--}{-\\-};
  $s =~ s{([\x21\x23-\x2C\x2E\x2F\x3A-\x40\x5B\x5D\x5E\x60\x7B-\x7E])}{\\$1}g;
  return $s;
} # _ident

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

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
