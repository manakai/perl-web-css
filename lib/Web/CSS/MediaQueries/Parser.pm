package Web::CSS::MediaQueries::Parser;
use strict;
use warnings;
our $VERSION = '7.0';
push our @ISA, qw(Web::CSS::MediaQueries::Parser::_ Web::CSS::Builder);

package Web::CSS::MediaQueries::Parser::_;
use Web::CSS::Builder;
use Web::CSS::MediaQueries::Features;

## The "media query list" struct:  An array reference of "media query"s.
## The "media query" struct:  A hash reference of:
##   only     - boolean  - Appearence of the 'only' keyword
##   not      - boolean  - Appearence of the 'not' keyword
##   type     - string?  - The media type, normalized
##   type_line, type_column - Line and column numbers of the media type
##   features - arrayref - Media feature expressions:
##     name   - string   - Media feature name, normalized
##     value  - value    - Value of the expression
##     prefix - 'min'/'max'/undef

my $ReservedMediaTypes = {
  and => 1, or => 1, not => 1, only => 1,
};

sub parse_char_string_as_mq_list ($$) {
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

  return $self->parse_constructs_as_mq_list ($tt);
} # parse_char_string_as_mq_list

sub parse_constructs_as_mq_list ($$) {
  my ($self, $tt) = @_;
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
        $t = shift @$tt;
        if ($t->{type} != S_TOKEN) {
          $self->onerror->(type => 'css:no s', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
          ## Non-conforming, but don't stop parsing.
        }
        $t = shift @$tt while $t->{type} == S_TOKEN;
        $mq->{$mt} = 1;
      }
      
      if ($t->{type} == IDENT_TOKEN) {
        $mq->{type} = $t->{value};
        $mq->{type} =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($ReservedMediaTypes->{$mq->{type}}) {
          $self->onerror->(type => 'mq:not media type', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
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
                           uri => $self->context->urlref,
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
                             uri => $self->context->urlref,
                             token => $t);
            ## Non-conforming, but don't stop parsing.
          }
          $t = shift @$tt while $t->{type} == S_TOKEN;
          $require_features = 1;
        }
      } elsif ($mq->{not} or $mq->{only}) {
        $self->onerror->(type => 'mq:no mt', # XXX
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
        next A;
      } else {
        $require_features = 1;
      }
    }

    B: {
      if ($t->{type} == PAREN_CONSTRUCT) {
        my $us = $t->{value};
        push @$us, {type => EOF_TOKEN,
                    line => $t->{end_line}, column => $t->{end_column}};
        my $u = shift @$us;
        $u = shift @$us while $u->{type} == S_TOKEN;
        if ($u->{type} == IDENT_TOKEN) {
          my $u_name = $u;
          my $fn = $u->{value};
          $fn =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          $u = shift @$us;
          $u = shift @$us while $u->{type} == S_TOKEN;
          if ($u->{type} == COLON_TOKEN) { # with value
            $u = shift @$us;
            $u = shift @$us while $u->{type} == S_TOKEN;
            unshift @$us, $u;
            $u = pop @$us;
            pop @$us while @$us and $us->[-1]->{type} == S_TOKEN;
            push @$us, $u;
          } elsif ($u->{type} == EOF_TOKEN) { # without value
            $us = [];
          } else {
            $self->onerror->(type => 'mq:feature:no colon', # XXX
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $u);
            next A;
          }
          my $def = $Web::CSS::MediaQueries::Features::Defs->{$fn};
          if ($def and $self->media_resolver->{feature}->{$fn}) {
            if (@$us) { # with value
              my $parsed = $def->{parse}->($self, $us) or next A;
              push @{$mq->{features} ||= []}, {name => $fn, value => $parsed};
            } else { # valueless
              if ($def->{requires_value}) {
                $self->onerror->(type => 'mq:feature:no value', # XXX
                                 level => 'm',
                                 value => $fn,
                                 uri => $self->context->urlref,
                                 token => $u);
                next A;
              } else {
                push @{$mq->{features} ||= []}, {name => $fn};
              }
            }
            $t = shift @$tt;
            if ($t->{type} == IDENT_TOKEN) {
              $self->onerror->(type => 'css:no s', # XXX
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
              ## Non-conforming, but don't stop parsing.
            }
            $t = shift @$tt while $t->{type} == S_TOKEN;
          } else {
            $self->onerror->(type => 'mq:feature:unknown', # XXX
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $u_name);
            next A;
          }
        } else {
          $self->onerror->(type => 'mq:feature:broken', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $u);
          next A;
        }
      } elsif ($require_features) {
        $self->onerror->(type => 'mq:no feature', # XXX
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
        next A;
      }

      if ($t->{type} == IDENT_TOKEN and $t->{value} =~ /\A[Aa][Nn][Dd]\z/) {
        $t = shift @$tt;
        if ($t->{type} != S_TOKEN) {
          $self->onerror->(type => 'css:no s', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
          ## Non-conforming, but don't stop parsing.
        }
        $t = shift @$tt while $t->{type} == S_TOKEN;
        $require_features = 1;
        redo B;
      }
    } # B

    if ($t->{type} == COMMA_TOKEN or $t->{type} == EOF_TOKEN) {
      if (not defined $mq->{type} and not @{$mq->{features} or []}) {
        if ($t->{type} == EOF_TOKEN and not @$mq_list) {
          last A;
        } else {
          $self->onerror->(type => 'mq:query:empty',
                           level => 'm',
                           uri => $self->context->urlref,
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
                     uri => $self->context->urlref,
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
} # parse_constructs_as_mq_list

sub parse_char_string_as_mq ($$) {
  my $mq_list = $_[0]->parse_char_string_as_mq_list ($_[1]);
  if (@$mq_list == 1) {
    return $mq_list->[0];
  } elsif (@$mq_list == 0) {
    $_[0]->onerror->(type => 'mq:empty', # XXX
                     level => 'm',
                     uri => $_[0]->context->urlref,
                     line => 1, column => 1);
    return {not => 1, type => 'all'};
  } else {
    $_[0]->onerror->(type => 'mq:multiple', # XXX
                     level => 'm',
                     uri => $_[0]->context->urlref,
                     line => 1, column => 1);
    return undef;
  }
} # parse_char_string_as_mq

1;

=head1 LICENSE

Copyright 2008-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
