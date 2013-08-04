package Web::CSS::Values;
use strict;
use warnings;
our $VERSION = '2.0';
use Web::CSS::Builder;

## Values - CSS values are represented as an array reference whose
## zeroth item represents the data type (encoded as an uppercase
## word).
##
## KEYWORD - Keyword
##   1: Keyword in lowercase
## NUMBER - Number (including integer)
##   1: Value as Perl number
## DIMENSION - Number with unit
##   1: Value as Perl number
##   2: Unit in lowercase
## RATIO - <ratio>
##   1: First value as Perl number
##   2: Second value as Perl number

our $GetKeywordParser = sub ($) {
  my $keywords = $_[0];
  return sub ($$) {
    my ($self, $us) = @_;
    if (@$us == 2 and $us->[0]->{type} == IDENT_TOKEN) {
      my $kwd = $us->[0]->{value};
      $kwd =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($keywords->{$kwd}) {
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

## <integer>, non-negative [SYNTAX] [MQ]
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

## <integer>, either 0 or 1 [SYNTAX] [MQ]
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

## <number>, non-negative [SYNTAX] [MQ]
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

my $LengthUnits = {
  em => 1, ex => 1, px => 1,
  in => 1, cm => 1, mm => 1, pt => 1, pc => 1,
}; # $LengthUnits

## <length>, non-negative [VALUES] [MQ]
our $NNLengthParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2 and $us->[0]->{type} == DIMENSION_TOKEN) {
    my $unit = $us->[0]->{value};
    $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($us->[0]->{number} >= 0 and $LengthUnits->{$unit}) {
      return ['DIMENSION', 0+$us->[0]->{number}, $unit];
    }
  }
  $self->onerror->(type => 'css:value:not nnlength', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $NNLengthParser

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
                   token => $us->[0]);
  return undef;
}; # $RatioParser

my $ResolutionUnits = {dpi => 1, dpcm => 1, dppx => 1};

## <resolution> [VALUES]
our $ResolutionParser = sub {
  my ($self, $us) = @_;
  if (@$us == 2 and $us->[0]->{type} == DIMENSION_TOKEN) {
    my $unit = $us->[0]->{value};
    $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($us->[0]->{number} > 0 and $ResolutionUnits->{$unit}) {
      return ['DIMENSION', 0+$us->[0]->{number}, $unit];
    }
  }
  $self->onerror->(type => 'css:value:not resolution', # XXX
                   level => 'm',
                   token => $us->[0]);
  return undef;
}; # $ResolutionParser

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
