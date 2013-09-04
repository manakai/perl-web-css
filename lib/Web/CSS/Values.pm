package Web::CSS::Values;
use strict;
use warnings;
our $VERSION = '5.0';
use Web::CSS::Builder;
use Web::CSS::Colors;

## Values - CSS values are represented as an array reference whose
## zeroth item represents the data type (encoded as an uppercase
## word).
##
## KEYWORD - Keyword
##   1: Keyword in lowercase
## STRING - String
##   1: Value as Perl character string
## URL - URL
##   1: URL as Perl character string, resolved if possible
## NUMBER - Number (including integer)
##   1: Value as Perl number
## PERCENTAGE - Number in percentage
##   1: Value as Perl number
## LENGTH - Number with length unit
##   1: Value as Perl number
##   2: Unit in lowercase
## ANGLE - Number with angle unit
##   1: Value as Perl number
##   2: Unit in lowercase
## TIME - Number with time unit
##   1: Value as Perl number
##   2: Unit in lowercase
## FREQUENCY - Number with frequency unit
##   1: Value as Perl number
##   2: Unit in lowercase
## RESOLUTION - Number with resolution unit
##   1: Value as Perl number
##   2: Unit in lowercase
## RATIO - <ratio>
##   1: First value as Perl number
##   2: Second value as Perl number
## RGBA - RGBA color
##   1: Red as Perl number [0-255]
##   2: Green as Perl number [0-255]
##   3: Blue as Perl number [0-255]
##   4: Alpha as Perl number [0-1]
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

## CSS-wide keywords
## <http://dev.w3.org/csswg/css-values/#common-keywords>,
## <http://dev.w3.org/csswg/css-cascade/#defaulting-keywords>.  See
## also |Web::CSS::Parser|.
our $CSSWidePattern = qr/\A(?:inherit|initial|unset)\z/;
# XXX toggle

our $GetKeywordParser = sub ($;$) {
  my ($keywords, $prop_name) = @_;
  return sub ($$) {
    my ($self, $us) = @_;
    if (@$us == 2 and $us->[0]->{type} == IDENT_TOKEN) {
      my $kwd = $us->[0]->{value};
      $kwd =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($keywords->{$kwd} and
          (not defined $prop_name or
           $self->media_resolver->{prop_value}->{$prop_name}->{$kwd})) {
        return ['KEYWORD', $kwd];
      } else {
        $self->onerror->(type => 'css:keyword:not allowed', # XXX
                         value => $kwd,
                         level => 'm',
                         token => $us->[0]);
        return undef;
      }
    }
    $self->onerror->(type => 'css:value:not keyword', # XXX
                     level => 'm',
                     token => $us->[0]);
    return undef;
  };
}; # $GetKeywordParser

## <integer>, non-negative [CSSSYNTAX] [MQ]
our $NNIntegerParser = sub {
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
}; # $NNIntegerParser

## <integer>, positive [CSSSYNTAX] [CSSBREAK]
our $PositiveIntegerParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2 and
      $us->[0]->{type} == NUMBER_TOKEN and
      $us->[0]->{number} =~ /\A[+-]?[0-9]+\z/) { # <integer>
    if ($us->[0]->{number} > 0) {
      return ['NUMBER', 0+$us->[0]->{number}];
    }
  }
  $self->onerror->(type => 'css:value:not positive integer', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $PositiveIntegerParser

## <integer>, either 0 or 1 [CSSSYNTAX] [MQ]
our $BooleanIntegerParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2 and
      $us->[0]->{type} == NUMBER_TOKEN and
      $us->[0]->{number} =~ /\A(?:[+-]?0+|\+?0*1)\z/) { # <integer>
    return ['NUMBER', 0+$us->[0]->{number}];
  }
  $self->onerror->(type => 'css:value:not boolean integer', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $BooleanIntegerParser

## <number>, non-negative [CSSSYNTAX] [MQ]
our $NNNumberParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2 and
      $us->[0]->{type} == NUMBER_TOKEN and
      $us->[0]->{number} >= 0) {
    return ['NUMBER', 0+$us->[0]->{number}];
  }
  $self->onerror->(type => 'css:value:not nnnumber', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $NNNumberParser

## <number> [CSSSYNTAX]
our $NumberParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2 and $us->[0]->{type} == NUMBER_TOKEN) {
    return ['NUMBER', 0+$us->[0]->{number}];
  }
  $self->onerror->(type => 'css:value:not number', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $NumberParser

my $LengthUnits = {
  em => 1, ex => 1, px => 1,
  in => 1, cm => 1, mm => 1, pt => 1, pc => 1,

  # XXX and more...
}; # $LengthUnits

## <length> [CSSVALUES].
our $LengthParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2) {
    if ($us->[0]->{type} == DIMENSION_TOKEN) {
      my $unit = $us->[0]->{value};
      $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($LengthUnits->{$unit}) {
        return ['LENGTH', 0+$us->[0]->{number}, $unit];
      }
    } elsif ($us->[0]->{type} == NUMBER_TOKEN) {
      if ($us->[0]->{number} == 0) {
        return ['LENGTH', 0, 'px'];
      }
    }
  }
  $self->onerror->(type => 'css:value:not length', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $LengthParser

## <length> | <quirky-length> [CSSVALUES] [QUIRKS].
our $LengthOrQuirkyLengthParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2) {
    if ($us->[0]->{type} == DIMENSION_TOKEN) {
      my $unit = $us->[0]->{value};
      $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($LengthUnits->{$unit}) {
        return ['LENGTH', 0+$us->[0]->{number}, $unit];
      }
    } elsif ($us->[0]->{type} == NUMBER_TOKEN) {
      if ($us->[0]->{number} == 0) {
        return ['LENGTH', 0, 'px'];
      } elsif ($self->context->quirks) {
        return ['LENGTH', 0+$us->[0]->{number}, 'px'];
      }
    }
  }
  $self->onerror->(type => 'css:value:not length', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $LengthOrQuirkyLengthParser

## <length>, non-negative [CSSVALUES] [MQ] [CSS21].
our $NNLengthParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2) {
    if ($us->[0]->{type} == DIMENSION_TOKEN) {
      my $unit = $us->[0]->{value};
      $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($us->[0]->{number} >= 0 and $LengthUnits->{$unit}) {
        return ['LENGTH', 0+$us->[0]->{number}, $unit];
      }
    } elsif ($us->[0]->{type} == NUMBER_TOKEN) {
      if ($us->[0]->{number} == 0) {
        return ['LENGTH', 0, 'px'];
      }
    }
  }
  $self->onerror->(type => 'css:value:not nnlength', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $NNLengthParser

## <length> | <quirky-length>, non-negative [CSSVALUES] [QUIRKS] [MQ]
## [CSSFONTS]
our $NNLengthOrQuirkyLengthParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2) {
    if ($us->[0]->{type} == DIMENSION_TOKEN) {
      my $unit = $us->[0]->{value};
      $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($us->[0]->{number} >= 0 and $LengthUnits->{$unit}) {
        return ['LENGTH', 0+$us->[0]->{number}, $unit];
      }
    } elsif ($us->[0]->{type} == NUMBER_TOKEN) {
      if ($us->[0]->{number} == 0) {
        return ['LENGTH', 0, 'px'];
      } elsif ($us->[0]->{number} > 0 and $self->context->quirks) {
        return ['LENGTH', 0+$us->[0]->{number}, 'px'];
      }
    }
  }
  $self->onerror->(type => 'css:value:not nnlength', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $NNLengthOrQuirkyLengthParser

## <length> | <quirky-length> | thin | medium | thick, non-negative -
## [CSSVALUES],
## <http://dev.w3.org/csswg/css-backgrounds/#the-border-width>
## [CSSBACKGROUND],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
our $LineWidthQuirkyParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2) {
    if ($us->[0]->{type} == DIMENSION_TOKEN) {
      my $unit = $us->[0]->{value};
      $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($us->[0]->{number} >= 0 and $LengthUnits->{$unit}) {
        return ['LENGTH', 0+$us->[0]->{number}, $unit];
      }
    } elsif ($us->[0]->{type} == NUMBER_TOKEN) {
      if ($us->[0]->{number} == 0) {
        return ['LENGTH', 0, 'px'];
      } elsif ($us->[0]->{number} > 0 and $self->context->quirks) {
        return ['LENGTH', 0+$us->[0]->{number}, 'px'];
      }
    } elsif ($us->[0]->{type} == IDENT_TOKEN) {
      my $value = $us->[0]->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value eq 'thin' or $value eq 'medium' or
          $value eq 'thick') {
        return ['KEYWORD', $value];
      }
    }
  }
  $self->onerror->(type => 'css:value:not nnlength', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $LineWidthQuirkyParser

## <length> | thin | medium | thick, non-negative - [CSSVALUES],
## <http://dev.w3.org/csswg/css-backgrounds/#the-border-width>
## [CSSBACKGROUND].
our $LineWidthParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2) {
    if ($us->[0]->{type} == DIMENSION_TOKEN) {
      my $unit = $us->[0]->{value};
      $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($us->[0]->{number} >= 0 and $LengthUnits->{$unit}) {
        return ['LENGTH', 0+$us->[0]->{number}, $unit];
      }
    } elsif ($us->[0]->{type} == NUMBER_TOKEN) {
      if ($us->[0]->{number} == 0) {
        return ['LENGTH', 0, 'px'];
      }
    } elsif ($us->[0]->{type} == IDENT_TOKEN) {
      my $value = $us->[0]->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value eq 'thin' or $value eq 'medium' or
          $value eq 'thick') {
        return ['KEYWORD', $value];
      }
    }
  }
  $self->onerror->(type => 'css:value:not nnlength', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $LineWidthParser

## <length> | <quirky-length> | <percentage> | auto [CSSVALUES]
## [QUIRKS] [CSSBOX] [CSSPOSITION].
our $LengthPergentageAutoQuirkyParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2) {
    if ($us->[0]->{type} == DIMENSION_TOKEN or
        $us->[0]->{type} == NUMBER_TOKEN) {
      return $LengthOrQuirkyLengthParser->($self, $us); # or undef
    } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
      return ['PERCENTAGE', 0+$us->[0]->{number}];
    } elsif ($us->[0]->{type} == IDENT_TOKEN) {
      my $value = $us->[0]->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value eq 'auto') {
        return ['KEYWORD', $value];
      }
    }
  }

  $self->onerror->(type => 'CSS syntax error', text => q[length],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $us->[0]);
  return undef;
}; # $LengthPercentageAutoQuirkyParser

# <ratio> [MQ]
our $RatioParser = sub {
  my ($self, $us) = @_;
  @$us = grep { not ($_->{type} == S_TOKEN or $_->{type} == EOF_TOKEN) } @$us;
  if (@$us == 3 and
      $us->[0]->{type} == NUMBER_TOKEN and
      $us->[0]->{number} =~ /\A\+?[0-9]+\z/ and
      $us->[0]->{number} > 0 and # positive <integer>
      $us->[1]->{type} == DELIM_TOKEN and
      $us->[1]->{value} eq '/' and
      $us->[2]->{type} == NUMBER_TOKEN and
      $us->[2]->{number} =~ /\A\+?[0-9]+\z/ and
      $us->[2]->{number} > 0) { # positive <integer>
    return ['RATIO', 0+$us->[0]->{number}, 0+$us->[2]->{number}];
  }
  $self->onerror->(type => 'css:value:not ratio', # XXX
                   level => 'm',
                   token => $us->[0]); # XXX if empty
  return undef;
}; # $RatioParser

my $ResolutionUnits = {dpi => 1, dpcm => 1, dppx => 1};

## <resolution> [CSSVALUES]
our $ResolutionParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2 and $us->[0]->{type} == DIMENSION_TOKEN) {
    my $unit = $us->[0]->{value};
    $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($us->[0]->{number} > 0 and $ResolutionUnits->{$unit}) {
      return ['RESOLUTION', 0+$us->[0]->{number}, $unit];
    }
  }
  $self->onerror->(type => 'css:value:not resolution', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $ResolutionParser

sub hue2rgb ($$$) {
  my ($m1, $m2, $h) = @_;
  $h++ if $h < 0;
  $h-- if $h > 1;
  return $m1 + ($m2 - $m1) * $h * 6 if $h * 6 < 1;
  return $m2 if $h * 2 < 1;
  return $m1 + ($m2 - $m1) * (2/3 - $h) * 6 if $h * 3 < 2;
  return $m1;
} # hue2rgb

## <color> [CSSCOLOR] / <quirky-color> [QUIRKS] / <'outline-color'>
## [CSSUI] / [MANAKAICSS].
my $GetColorParser = sub {
  my (%args) = @_;
  # $args{is_outline_color}
  # $args{allow_quirky_color}
  return sub {
    my ($self, $us) = @_;
    my $t = shift @$us;

    my $r;
    T: {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($Web::CSS::Colors::X11Colors->{$value} or
            $Web::CSS::Colors::SystemColors->{$value} or
            $value eq '-manakai-default' or
            $value eq 'currentcolor' or
            (($value eq 'flavor' or $value eq 'transparent') and
             $self->media_resolver->{prop_value}->{color}->{$value}) or
            ($args{is_outline_color} and
             ($value eq 'invert' or
              $value eq '-manakai-invert-or-currentcolor') and
             $self->media_resolver->{prop_value}->{'outline-color'}->{invert})) {
          ## NOTE: "For systems that do not have a corresponding
          ## value, the specified value should be mapped to the
          ## nearest system value, or to a default color." [CSS 2.1].
          ## (Therefore, all system color values are not ignored
          ## irrelevant to supportedness.)
          $r = ['KEYWORD', $value];
          $t = shift @$us;
          last T;
        }
      } # keyword

      if ($t->{type} == HASH_TOKEN or
          ($args{allow_quirky_color} and
           $self->context->quirks and {
             IDENT_TOKEN, 1,
             NUMBER_TOKEN, 1,
             DIMENSION_TOKEN, 1,
           }->{$t->{type}})) {
        my $v = (defined $t->{number} ? $t->{number} : '') . $t->{value};
        if ($v =~ /\A([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})\z/) {
          $r = ['RGBA', hex $1, hex $2, hex $3, 1];
          if ($t->{type} != HASH_TOKEN) {
            $self->onerror->(type => 'css:color:quirky', # XXX
                             level => 'w',
                             uri => $self->context->urlref,
                             token => $t);
          }
          $t = shift @$us;
          last T;
        } elsif ($v =~ /\A([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])\z/) {
          $r = ['RGBA', hex $1.$1, hex $2.$2, hex $3.$3, 1];
          if ($t->{type} != HASH_TOKEN) {
            $self->onerror->(type => 'css:color:quirky', # XXX
                             level => 'w',
                             uri => $self->context->urlref,
                             token => $t);
          }
          $t = shift @$us;
          last T;
        }
      } # hash

      if ($t->{type} == FUNCTION_CONSTRUCT) {
        my $func = $t->{name}->{value};
        $func =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        my $vs = $t->{value};
        $vs = [grep { $_->{type} != S_TOKEN } @$vs];

        if ($func eq '-moz-rgba' or $func eq '-moz-hsla') {
          $self->onerror->(type => 'css:obsolete', text => $func.'()', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t->{name});
          $func =~ s/^-moz-//;
        }

        if ($func eq 'rgb') {
          if (@$vs == 5 and
              $vs->[0]->{type} == NUMBER_TOKEN and
              $vs->[1]->{type} == COMMA_TOKEN and
              $vs->[2]->{type} == NUMBER_TOKEN and
              $vs->[3]->{type} == COMMA_TOKEN and
              $vs->[4]->{type} == NUMBER_TOKEN) {
            $r = ['RGBA',
                  0+$vs->[0]->{number},
                  0+$vs->[2]->{number},
                  0+$vs->[4]->{number},
                  1];
            $t = shift @$us;
            last T;
          } elsif (@$vs == 5 and
                   $vs->[0]->{type} == PERCENTAGE_TOKEN and
                   $vs->[1]->{type} == COMMA_TOKEN and
                   $vs->[2]->{type} == PERCENTAGE_TOKEN and
                   $vs->[3]->{type} == COMMA_TOKEN and
                   $vs->[4]->{type} == PERCENTAGE_TOKEN) {
            $r = ['RGBA',
                  $vs->[0]->{number} * 255 / 100,
                  0+$vs->[2]->{number} * 255 / 100,
                  0+$vs->[4]->{number} * 255 / 100,
                  1];
            $t = shift @$us;
            last T;
          }
        } elsif ($func eq 'rgba') {
          if (@$vs == 7 and
              $vs->[0]->{type} == NUMBER_TOKEN and
              $vs->[1]->{type} == COMMA_TOKEN and
              $vs->[2]->{type} == NUMBER_TOKEN and
              $vs->[3]->{type} == COMMA_TOKEN and
              $vs->[4]->{type} == NUMBER_TOKEN and
              $vs->[5]->{type} == COMMA_TOKEN and
              $vs->[6]->{type} == NUMBER_TOKEN) {
            $r = ['RGBA',
                  0+$vs->[0]->{number},
                  0+$vs->[2]->{number},
                  0+$vs->[4]->{number},
                  0+$vs->[6]->{number}];
            $t = shift @$us;
            last T;
          } elsif (@$vs == 7 and
                   $vs->[0]->{type} == PERCENTAGE_TOKEN and
                   $vs->[1]->{type} == COMMA_TOKEN and
                   $vs->[2]->{type} == PERCENTAGE_TOKEN and
                   $vs->[3]->{type} == COMMA_TOKEN and
                   $vs->[4]->{type} == PERCENTAGE_TOKEN and
                   $vs->[5]->{type} == COMMA_TOKEN and
                   $vs->[6]->{type} == NUMBER_TOKEN) {
            $r = ['RGBA',
                  $vs->[0]->{number} * 255 / 100,
                  0+$vs->[2]->{number} * 255 / 100,
                  0+$vs->[4]->{number} * 255 / 100,
                  0+$vs->[6]->{number}];
            $t = shift @$us;
            last T;
          }
        } elsif ($func eq 'hsl') {
          if (@$vs == 5 and
              $vs->[0]->{type} == NUMBER_TOKEN and
              $vs->[1]->{type} == COMMA_TOKEN and
              $vs->[2]->{type} == PERCENTAGE_TOKEN and
              $vs->[3]->{type} == COMMA_TOKEN and
              $vs->[4]->{type} == PERCENTAGE_TOKEN) {
            my $h = ((($vs->[0]->{number} % 360) + 360) % 360) / 360;
            my $s = $vs->[2]->{number} / 100;
            $s = 0 if $s < 0;
            $s = 1 if $s > 1;
            my $l = $vs->[4]->{number} / 100;
            $l = 0 if $l < 0;
            $l = 1 if $l > 1;

            my $m2 = $l <= 0.5 ? $l * ($s + 1) : $l + $s - $l * $s;
            my $m1 = $l * 2 - $m2;

            $r = ['RGBA',
                  hue2rgb ($m1, $m2, $h + 1/3) * 255,
                  hue2rgb ($m1, $m2, $h) * 255,
                  hue2rgb ($m1, $m2, $h - 1/3) * 255,
                  1];
            $t = shift @$us;
            last T;
          }
        } elsif ($func eq 'hsla') {
          if (@$vs == 7 and
              $vs->[0]->{type} == NUMBER_TOKEN and
              $vs->[1]->{type} == COMMA_TOKEN and
              $vs->[2]->{type} == PERCENTAGE_TOKEN and
              $vs->[3]->{type} == COMMA_TOKEN and
              $vs->[4]->{type} == PERCENTAGE_TOKEN and
              $vs->[5]->{type} == COMMA_TOKEN and
              $vs->[6]->{type} == NUMBER_TOKEN) {
            my $h = ((($vs->[0]->{number} % 360) + 360) % 360) / 360;
            my $s = $vs->[2]->{number} / 100;
            $s = 0 if $s < 0;
            $s = 1 if $s > 1;
            my $l = $vs->[4]->{number} / 100;
            $l = 0 if $l < 0;
            $l = 1 if $l > 1;

            my $m2 = $l <= 0.5 ? $l * ($s + 1) : $l + $s - $l * $s;
            my $m1 = $l * 2 - $m2;

            $r = ['RGBA',
                  hue2rgb ($m1, $m2, $h + 1/3) * 255,
                  hue2rgb ($m1, $m2, $h) * 255,
                  hue2rgb ($m1, $m2, $h - 1/3) * 255,
                  0+$vs->[6]->{number}];
            $t = shift @$us;
            last T;
          }
        } # $func
      } # function

      $self->onerror->(type => 'css:color:syntax error', # XXX
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
      return undef;
    } # T

    if ($r->[0] eq 'RGBA') {
      for my $i (1, 2, 3) { # sRGB
        $r->[$i] = 0 if $r->[$i] < 0;
        $r->[$i] = 255 if $r->[$i] > 255;
      }
      $r->[4] = 0 if $r->[4] < 0;
      $r->[4] = 1 if $r->[4] > 1;

      if ($r->[4] == 1) { # = rgb()
        #
      } elsif ($r->[4] == 0) { # = transparent
        unless ($self->media_resolver->{prop_value}->{color}->{transparent}) {
          $self->onerror->(type => 'css:color:alpha:not supported', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
          return undef;
        }
      } else {
        unless ($self->media_resolver->{function}->{rgba}) {
          $self->onerror->(type => 'css:color:alpha:not supported', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
          return undef;
        }
      }
    }

    if ($t->{type} == EOF_TOKEN) {
      return $r;
    } else {
      $self->onerror->(type => 'css:color:syntax error', # XXX
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
      return undef;
    }
  };
}; # $GetColorParser
our $ColorOrQuirkyColorParser = $GetColorParser->(allow_quirky_color => 1);
our $OutlineColorParser = $GetColorParser->(is_outline_color => 1);

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
