package Web::CSS::MediaQueries::Parser;
use strict;
use warnings;
our $VERSION = '5.0';
use Web::CSS::Tokenizer;
use Web::CSS::Builder;
push our @ISA, qw(Web::CSS::Builder);

## The "media query list" struct:  An array reference of "media query"s.
## The "media query" struct:  A hash reference of:
##   only     - boolean  - Appearence of the 'only' keyword
##   not      - boolean  - Appearence of the 'not' keyword
##   type     - string?  - The media type, normalized
##   type_line, type_column - Line and column numbers of the media type
##   features - arrayref - Media feature expressions:
##     XXX

my $ReservedMediaTypes = {
  and => 1, or => 1, not => 1, only => 1,
};

sub parse_char_string_as_mqs ($$) {
  my $self = $_[0];

  $self->{line_prev} = $self->{line} = 1;
  $self->{column_prev} = -1;
  $self->{column} = 0;

  $self->{chars} = [split //, $_[1]];
  $self->{chars_pos} = 0;
  delete $self->{chars_was_cr};
  $self->{chars_pull_next} = sub { 0 };

  $self->init_tokenizer;
  $self->init_builder;

  $self->start_building_values or do {
    1 while not $self->continue_building_values;
  };

  my $tt = (delete $self->{parsed_construct})->{value};
  push @$tt, $self->get_next_token; # EOF_TOKEN

  my $t = shift @$tt;

  my $mq_list = [];
  my $mq;
  A: {
    $t = shift @$tt while $t->{type} == S_TOKEN;
    $mq = {};
    my $require_features;
    if ($t->{type} == IDENT_TOKEN) {
      my $mt = $t->{value};
      $mt =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($mt eq 'not' or $mt eq 'only') {
        $mq->{start_token} = $t; # XXX
        $t = shift @$tt;
        if ($t->{type} != S_TOKEN) {
          $self->onerror->(type => 'css:no s', # XXX
                           level => 'm',
                           token => $t);
          ## Non-conforming, but don't stop parsing.
        }
        $t = shift @$tt while $t->{type} == S_TOKEN;
        $mq->{$mt} = 1;
      }
      
      if ($t->{type} == IDENT_TOKEN) {
        $mq->{start_token} ||= $t; # XXX
        $mq->{type} = $t->{value};
        $mq->{type} =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($ReservedMediaTypes->{$mq->{type}}) {
          $self->onerror->(type => 'mq:not media type', # XXX
                           level => 'm',
                           token => $t);
          next A;
        }
        $mq->{type_line} = $t->{line};
        $mq->{type_column} = $t->{column};
        $t = shift @$tt;

        if ($t->{type} == IDENT_TOKEN and
            $t->{value} =~ /\A[Aa][Nn][Dd]\z/) { ## ASCII case-insensitive.
          $self->onerror->(type => 'css:no s', # XXX
                           level => 'm',
                           token => $t);
          ## Non-conforming, but don't stop parsing.
        }
        $t = shift @$tt while $t->{type} == S_TOKEN;

        if ($t->{type} == IDENT_TOKEN and
            $t->{value} =~ /\A[Aa][Nn][Dd]\z/) { ## ASCII case-insensitive.
          $t = shift @$tt;
          if ($t->{type} != S_TOKEN) {
            $self->onerror->(type => 'css:no s', # XXX
                             level => 'm',
                             token => $t);
            ## Non-conforming, but don't stop parsing.
          }
          $t = shift @$tt while $t->{type} == S_TOKEN;
          $require_features = 1;
        }
      } elsif ($mq->{not} or $mq->{only}) {
        $self->onerror->(type => 'mq:no mt', # XXX
                         level => 'm',
                         token => $t);
        next A;
      } else {
        $require_features = 1;
      }
    }

    if ($t->{type} == BLOCK_CONSTRUCT and
        $t->{name}->{type} == LPAREN_TOKEN) {
      # XXX
    }

    if ($t->{type} == COMMA_TOKEN or $t->{type} == EOF_TOKEN) {
      if (not defined $mq->{type} and not @{$mq->{features} or []}) {
        if ($t->{type} == EOF_TOKEN and not @$mq_list) {
          last A;
        } else {
          $self->onerror->(type => 'mq:query:empty',
                           level => 'm',
                           token => $t);
          next A;
        }
      }

      push @$mq_list, $mq;
      if ($t->{type} == COMMA_TOKEN) {
        $t = shift @$tt;
        redo A;
      } else { # EOF_TOKEN
        last A;
      }
    }

    $self->onerror->(type => 'mq:broken', # XXX
                     level => 'm',
                     token => $t);
    next A;
  } continue {
    $mq->{not} = 1;
    $mq->{type} = 'all';
    delete $mq->{only};
    delete $mq->{features};
    # type_line, type_column
    push @$mq_list, $mq;

    $t = shift @$tt
        while not ($t->{type} == COMMA_TOKEN or $t->{type} == EOF_TOKEN);

    if ($t->{type} == COMMA_TOKEN) {
      $t = shift @$tt;
      redo A;
    }
  } # A

  return $mq_list;
} # parse_char_string_as_mqs

1;

=head1 LICENSE

Copyright 2008-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
