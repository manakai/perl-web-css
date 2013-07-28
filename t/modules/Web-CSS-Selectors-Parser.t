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

test {
  my $c = shift;
  is ref $Web::CSS::Selectors::Parser::IdentOnlyPseudoClasses, 'HASH';
  is ref $Web::CSS::Selectors::Parser::IdentOnlyPseudoElements, 'HASH';
  done $c;
} n => 2, name => 'lists';

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
