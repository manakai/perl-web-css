use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'test-x1', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::CSS::Context;
use Web::CSS::Selectors::Parser;

for my $test (
  [[ELEMENT_SELECTOR, undef, 'a'  , ''   , 0, 0],   'a'],
  [[ELEMENT_SELECTOR, undef, undef, ''   , 0, 1],   '*'],
  [[ELEMENT_SELECTOR, ''   , 'a'  , undef, 0, 0],  '|a'],
  [[ELEMENT_SELECTOR, ''   , undef, undef, 0, 1],  '|*'],
  [[ELEMENT_SELECTOR, undef, 'a'  , undef, 1, 0], '*|a'],
  [[ELEMENT_SELECTOR, undef, undef, undef, 1, 1], '*|*'],
  [[ELEMENT_SELECTOR, undef, undef, ''   , 0, 0], '.b'],
) {
  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    my @b;
    push @b, [CLASS_SELECTOR, 'b'] if $test->[1] eq '.b';
    eq_or_diff $s->parse_char_string_as_selectors ($test->[1]),
        [[DESCENDANT_COMBINATOR, [$test->[0], @b]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors', $test->[1]];
}

for my $test (
  #@namespace '';
  [[ELEMENT_SELECTOR, ''   , 'a'  , ''   , 0, 0],   'a'],
  [[ELEMENT_SELECTOR, ''   , undef, ''   , 0, 1],   '*'],
  [[ELEMENT_SELECTOR, ''   , 'a'  , undef, 0, 0],  '|a'],
  [[ELEMENT_SELECTOR, ''   , undef, undef, 0, 1],  '|*'],
  [[ELEMENT_SELECTOR, undef, 'a'  , undef, 1, 0], '*|a'],
  [[ELEMENT_SELECTOR, undef, undef, undef, 1, 1], '*|*'],
  [[ELEMENT_SELECTOR, ''   , undef, ''   , 0, 0], '.b'],
) {
  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->context->{prefix_to_url}->{''} = '';
    my @b;
    push @b, [CLASS_SELECTOR, 'b'] if $test->[1] eq '.b';
    eq_or_diff $s->parse_char_string_as_selectors ($test->[1]),
        [[DESCENDANT_COMBINATOR, [$test->[0], @b]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors', $test->[1]];
}

for my $test (
  #@namespace 'ns';
  [[ELEMENT_SELECTOR, 'ns' , 'a'  , ''   , 0, 0],   'a'],
  [[ELEMENT_SELECTOR, 'ns' , undef, ''   , 0, 1],   '*'],
  [[ELEMENT_SELECTOR, ''   , 'a'  , undef, 0, 0],  '|a'],
  [[ELEMENT_SELECTOR, ''   , undef, undef, 0, 1],  '|*'],
  [[ELEMENT_SELECTOR, undef, 'a'  , undef, 1, 0], '*|a'],
  [[ELEMENT_SELECTOR, undef, undef, undef, 1, 1], '*|*'],
  [[ELEMENT_SELECTOR, 'ns' , undef, ''   , 0, 0], '.b'],
) {
  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->context->{prefix_to_url}->{''} = 'ns';
    my @b;
    push @b, [CLASS_SELECTOR, 'b'] if $test->[1] eq '.b';
    eq_or_diff $s->parse_char_string_as_selectors ($test->[1]),
        [[DESCENDANT_COMBINATOR, [$test->[0], @b]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors', $test->[1]];
}

for my $test (
  #@namespace p '';
  [[ELEMENT_SELECTOR, ''   , 'a'  , 'p'  , 0, 0], 'p|a'],
  [[ELEMENT_SELECTOR, ''   , undef, 'p'  , 0, 1], 'p|*'],
) {
  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->context->{prefix_to_url}->{p} = '';
    eq_or_diff $s->parse_char_string_as_selectors ($test->[1]),
        [[DESCENDANT_COMBINATOR, [$test->[0]]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors', $test->[1]];
}

for my $test (
  #@namespace p 'ns';
  [[ELEMENT_SELECTOR, 'ns' , 'a'  , 'p'  , 0, 0], 'p|a'],
  [[ELEMENT_SELECTOR, 'ns' , undef, 'p'  , 0, 1], 'p|*'],
) {
  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->context->{prefix_to_url}->{p} = 'ns';
    eq_or_diff $s->parse_char_string_as_selectors ($test->[1]),
        [[DESCENDANT_COMBINATOR, [$test->[0]]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors', $test->[1]];
}

{
  #In :not() or :match()
  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->media_resolver->{pseudo_class}->{not} = 1;
    eq_or_diff $s->parse_char_string_as_selectors (':not(.b)')->[0]->[1]->[1]->[2],
        [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, undef, '', 0, 0],
                                  [CLASS_SELECTOR, 'b']]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors'];

  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->media_resolver->{pseudo_class}->{not} = 1;
    $s->context->{prefix_to_url}->{''} = '';
    eq_or_diff $s->parse_char_string_as_selectors (':not(.b)')->[0]->[1]->[1]->[2],
        [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, undef, '', 0, 0],
                                  [CLASS_SELECTOR, 'b']]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors'];

  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->context->{prefix_to_url}->{''} = 'ns';
    $s->media_resolver->{pseudo_class}->{not} = 1;
    eq_or_diff $s->parse_char_string_as_selectors (':not(.b)')->[0]->[1]->[1]->[2],
        [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, undef, '', 0, 0],
                                  [CLASS_SELECTOR, 'b']]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors'];

  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->context->{prefix_to_url}->{''} = 'ns';
    $s->media_resolver->{pseudo_class}->{not} = 1;
    eq_or_diff $s->parse_char_string_as_selectors (':not(*.b)')->[0]->[1]->[1]->[2],
        [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'ns', undef, '', 0, 1],
                                  [CLASS_SELECTOR, 'b']]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors'];

  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->context->{prefix_to_url}->{''} = 'ns';
    $s->media_resolver->{pseudo_class}->{not} = 1;
    eq_or_diff $s->parse_char_string_as_selectors (':not(a.b)')->[0]->[1]->[1]->[2],
        [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'ns', 'a', '', 0, 0],
                                  [CLASS_SELECTOR, 'b']]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors'];

  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Parser->new;
    $s->context->{prefix_to_url}->{''} = 'ns';
    $s->media_resolver->{pseudo_element}->{cue} = 1;
    eq_or_diff $s->parse_char_string_as_selectors ('::cue(.b)')->[0]->[1]->[1]->[2],
        [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'ns', undef, '', 0, 0],
                                  [CLASS_SELECTOR, 'b']]]];
    done $c;
  } n => 1, name => ['parse_char_string_as_selectors'];
}

for my $test (         # s  a  b  c
  ['*',                 [0, 0, 0, 0]],
  ['LI',                [0, 0, 0, 1]],
  ['UL LI',             [0, 0, 0, 2]],
  ['UL OL+LI',          [0, 0, 0, 3]],
  ['H1 + *[REL=up]',    [0, 0, 1, 1]],
  ['UL OL LI.red',      [0, 0, 1, 3]],
  ['LI.red.level',      [0, 0, 2, 1]],
  ['#x34y',             [0, 1, 0, 0]],
  ['#s12:not(FOO)',     [0, 1, 0, 1]],
  [':first-child',      [0, 0, 1, 0]],
  [':lang(en)::before', [0, 0, 1, 1]],
  [':NOT(.foo):NOT(*)', [0, 0, 1, 0]],
  ['ns1|*',             [0, 0, 0, 0]],
  ['ns1|hoge',          [0, 0, 0, 1]],
  ['[ns1|foo]',         [0, 0, 1, 0]],
  ['[ns1~=hoge]',       [0, 0, 1, 0]],
  [':not(em,strong)',   [0, 0, 0, 1]],
  [':not(.a,b.c .d)',   [0, 0, 2, 1]],
  [':not(b.c .d,.a)',   [0, 0, 2, 1]],
  ['::cue',             [0, 0, 0, 1]],
  ['::cue(a, b)',       [0, 0, 0, 3]],
  ['::cue(a, .b)',      [0, 0, 1, 2]],
) {
  test {
    my $c = shift;
    my $parser = Web::CSS::Selectors::Parser->new;
    $parser->media_resolver->{pseudo_class}->{not} = 1;
    $parser->media_resolver->{pseudo_class}->{lang} = 1;
    $parser->media_resolver->{pseudo_class}->{'first-child'} = 1;
    $parser->media_resolver->{pseudo_element}->{before} = 1;
    $parser->media_resolver->{pseudo_element}->{cue} = 1;
    $parser->context (Web::CSS::Context->new_from_nscallback (sub {
      my $prefix = shift;
      return 'http://foo/' if $prefix;
      return undef;
    }));
    my $selectors = $parser->parse_char_string_as_selectors ($test->[0]);
    eq_or_diff $parser->get_selector_specificity ($selectors->[0]), $test->[1];
    done $c;
  } n => 1, name => ['get_selector_specificity', $test->[0]];
}

run_tests;

=head1 LICENSE

Copyright 2011-2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
