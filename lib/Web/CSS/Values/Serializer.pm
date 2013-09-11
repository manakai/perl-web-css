package Web::CSS::Values::Serializer;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '2.0';
use Carp;

## This module is not intended for standalone use.  See
## |Web::CSS::Serializer|.

our @EXPORT = qw(_number _string _ident);

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  for (@_ ? @_ : @EXPORT) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    no strict 'refs';
    *{$to_class . '::' . $_} = $code;
  }
} # import

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

my $KeywordSetOrder = {
  # 'text-decoration'
  blink => 1, underline => 2, overline => 3, 'line-through' => 4,

  # 'marks'
  crop => 1, cross => 2,
};

my $ValueSerializer = {
  KEYWORD => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>.
    return $_[0]->[1];
  },
  CUSTOMID => sub {
    return _ident $_[0]->[1];
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
  CURSORURL => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>.
    return 'url(' . _string ($_[0]->[1]) . ') ' .
        (_number $_[0]->[3]) . ' ' . (_number $_[0]->[4]);
  },
  RATIO => sub {
    ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>
    ## + [MQ] + Serializer.pod.
    return _number ($_[0]->[1]) . '/' . _number ($_[0]->[2]);
  },
  LIST => sub {
    return join ', ', map { __PACKAGE__->serialize_value ($_) } @{$_[0]}[1..$#{$_[0]}];
  },
  SEQ => sub {
    return join ' ', map { __PACKAGE__->serialize_value ($_) } @{$_[0]}[1..$#{$_[0]}];
  },
  KEYWORDSET => sub {
    return join ' ', map { $_->[0] } sort { $a->[1] <=> $b->[1] } map { [$_, $KeywordSetOrder->{$_}] } keys %{$_[0]->[1]};
  },
  QUOTES => sub {
    return join ' ', map { (_string $_->[0]), (_string $_->[1]) } @{$_[0]}[1..$#{$_[0]}];
  },
  ATTR => sub {
    my $r = '';
    if (defined $_->[2]) { # namespace prefix
      if (length $_->[2]) {
        $r .= (_ident $_->[2]) . '|';
      } # or default namespace
    } elsif (defined $_->[1] and $_->[1] eq '') { # nsurl
      $r .= '|';
    }
    $r .= _ident $_->[3]; # local name
    # XXX <type-or-unit>, <fallback>
    return "attr($r)";
  },
  COUNTER => sub {
    return 'counter(' . (_ident $_->[1]) . ', ' . __PACKAGE__->serialize_value ($_->[2]) . ')';
  },
  COUNTERS => sub {
    return 'counters(' . (_ident $_->[1]) . ', ' . (_string $_->[2]) . ', ' . __PACKAGE__->serialize_value ($_->[3]) . ')';
  },
  COUNTERDELTAS => sub {
    return join ' ', map { (_ident $_->[0]) . ' ' . (_number $_->[1]) } @{$_[0]}[1..$#{$_[0]}];
  },
  RECT => sub {
    return 'rect(' . (join ', ', map { __PACKAGE__->serialize_value ($_) } @{$_[0]}[1..4]) . ')';
  },
  DIMENSION => sub {
    my $v1 = __PACKAGE__->serialize_value ($_[0]->[1]);
    my $v2 = __PACKAGE__->serialize_value ($_[0]->[2]);
    if ($v1 eq $v2) {
      return $v1;
    } else {
      return "$v1 $v2";
    }
  },
}; # $ValueSerializer

$ValueSerializer->{$_} = sub {
  ## <http://dev.w3.org/csswg/cssom/#serialize-a-css-component-value>
  ## + Serializer.pod.
  return _number ($_[0]->[1]) . $_[0]->[2];
} for qw(ANGLE FREQUENCY LENGTH RESOLUTION TIME);

sub serialize_value ($$) {
  my ($self, $value) = @_;
  return ($ValueSerializer->{$value->[0]} || sub { die "Serializer for |$value->[0]| not implemented" })->($value);
} # serialize_value

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
