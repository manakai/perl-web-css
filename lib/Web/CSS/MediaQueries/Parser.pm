package Web::CSS::MediaQueries::Parser;
use strict;
use warnings;
our $VERSION = '1.4';
use Web::CSS::Tokenizer;

sub new ($) {
  return bless {}, $_[0];
} # new

sub init ($) {
  my $self = $_[0];
  delete $self->{context};
  delete $self->{onerror};
} # init

sub context ($;$) {
  if (@_ > 1) {
    $_[0]->{context} = $_[1];
  }
  return $_[0]->{context} ||= do {
    require Web::CSS::Context;
    Web::CSS::Context->new_empty;
  };
} # context

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub { };
} # onerror

sub parse_char_string ($$) {
  my $self = $_[0];

  my $s = $_[1];
  pos ($s) = 0;

  my $tt = Web::CSS::Tokenizer->new;
  $tt->context ($self->context);
  $tt->onerror ($self->onerror);
  $tt->{line} = 1;
  $tt->{column} = 1;
  $tt->{get_char} = sub {
    if (pos $s < length $s) {
      $tt->{column} = 1 + pos $s;
      return ord substr $s, pos ($s)++, 1;
    } else {
      return -1;
    }
  }; # $tt->{get_char}
  $tt->init_tokenizer;

  my $t = $tt->get_next_token;
  $t = $tt->get_next_token while $t->{type} == S_TOKEN;

  my $r;
  ($t, $r) = $self->_parse_mq_with_tokenizer ($t, $tt);
  return undef unless defined $r;

  if ($t->{type} != EOF_TOKEN) {
    $self->onerror->(type => 'mq syntax error',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }

  return $r;
} # parse_char_string

sub _parse_mq_with_tokenizer ($$$) {
  my ($self, $t, $tt) = @_;

  my $r = [];

  A: {
    ## NOTE: Unknown media types are converted into 'unknown', since
    ## Opera and WinIE do so and our implementation of the CSS
    ## tokenizer currently normalizes numbers in NUMBER or DIMENSION tokens
    ## so that the original representation cannot be preserved (e.g. '03d'
    ## is covnerted to '3' with unit 'd').

    if ($t->{type} == IDENT_TOKEN) {
      my $type = $t->{value};
      $type =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ({
        all => 1, braille => 1, embossed => 1, handheld => 1, print => 1,
        projection => 1, screen => 1, tty => 1, tv => 1,
        speech => 1, aural => 1,
        'atsc-tv' => 1, 'dde-tv' => 1, 'dvb-tv' => 1,
        dark => 1, emacs => 1, light => 1, xemacs => 1,
      }->{$type}) {
        push @$r, [['#type', $type]];
      } else {
        push @$r, [['#type', 'unknown']];
        $self->onerror->(type => 'unknown media type',
                         level => 'u',
                         uri => $self->context->urlref,
                         token => $t);
      }
      $t = $tt->get_next_token;
    } elsif ($t->{type} == NUMBER_TOKEN or $t->{type} == DIMENSION_TOKEN) {
      push @$r, [['#type', 'unknown']];
      $self->onerror->(type => 'unknown media type',
                       level => 'u',
                       uri => $self->context->urlref,
                       token => $t);
      $t = $tt->get_next_token;
    } else {
      $self->onerror->(type => 'mq syntax error',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);    
      return ($t, undef);
    }

    $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    if ($t->{type} == COMMA_TOKEN) {
      $t = $tt->get_next_token;
      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      redo A;
    }
  } # A

  return ($t, $r);
} # _parse_mq_with_tokenizer

1;

=head1 LICENSE

Copyright 2008-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
