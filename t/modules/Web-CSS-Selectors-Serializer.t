use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Web::CSS::Selectors::Serializer;
use Web::CSS::Parser;

for my $test (
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, 'hoge', '']]]],
   out => 'hoge'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, 'ho ge"'."\x0A", '']]]],
   out => 'ho\\ ge\\"\\a '},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'http://hoge/', undef, 'ho ge"'."\x0A", 0, 1]]]],
   out => 'ho\\ ge\\"\\a |*'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', undef, undef, 0, 1]]]],
   out => '|*'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', undef, '', 0, 1]]]],
   out => '*'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'http://hoge/', undef, '', 0, 1]]]],
   out => '*'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', undef, undef, 0, 1]]]],
   out => '|*'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', 'hoge', undef, 0, 0]]]],
   out => '|hoge'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', 'ho ge', undef, 0, 0]]]],
   out => '|ho\\ ge'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, 'ho ge', '', 0, 0]]]],
   out => 'ho\\ ge'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', 'ho ge', undef, 0, 0]]]],
   out => '|ho\\ ge'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'http://hoge/', 'ho ge', '', 0, 0]]]],
   out => 'ho\\ ge'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'http://hoge/', 'ho ge', 'ab cd']]]],
   out => 'ab\\ cd|ho\\ ge'},
  {in => [[DESCENDANT_COMBINATOR, [[ID_SELECTOR, 'ab!cd']]]],
   out => '#ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[ID_SELECTOR, '1ab!cd']]]],
   out => '#\\31 ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[CLASS_SELECTOR, 'ab!cd']]]],
   out => '.ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', undef, undef, 0, 1],
                                   [ID_SELECTOR, 'ab!cd']]]],
   out => '|*#ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', undef, '', 0, 0],
                                   [ID_SELECTOR, 'ab!cd']]]],
   out => '#ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', undef, undef, 0, 1],
                                   [ID_SELECTOR, 'ab!cd']]]],
   out => '|*#ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'http://hoge/', undef, '12a', 0, 1],
                                   [ID_SELECTOR, 'ab!cd']]]],
   out => '\\31 2a|*#ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'http://hoge/', undef, '', 0, 0],
                                   [ID_SELECTOR, 'ab!cd']]]],
   out => '#ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, 'http://hoge/', undef, '', 0, 0],
                                   [CLASS_SELECTOR, 'ab!cd']]]],
   out => '.ab\\!cd'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, undef, 'ab!cd',
                                    EXISTS_MATCH]]]],
   out => '[*|ab\\!cd]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, '', 'ab!cd',
                                    EXISTS_MATCH]]]],
   out => '[ab\\!cd]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, 'http://ho/', 'ab!cd',
                                    EXISTS_MATCH, undef, 'fu ga']]]],
   out => '[fu\\ ga|ab\\!cd]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, 'http://ho/', 'ab!cd',
                                    EQUALS_MATCH, '"\\'."\x0A", 'fu ga']]]],
   out => '[fu\\ ga|ab\\!cd="\\"\\\\\\a "]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, 'http://ho/', 'ab!cd',
                                    INCLUDES_MATCH, '"\\'."\x0A", 'fu ga']]]],
   out => '[fu\\ ga|ab\\!cd~="\\"\\\\\\a "]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, 'http://ho/', 'ab!cd',
                                    DASH_MATCH, '"\\'."\x0A", 'fu ga']]]],
   out => '[fu\\ ga|ab\\!cd|="\\"\\\\\\a "]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, 'http://ho/', 'ab!cd',
                                    PREFIX_MATCH, '"\\'."\x0A", 'fu ga']]]],
   out => '[fu\\ ga|ab\\!cd^="\\"\\\\\\a "]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, 'http://ho/', 'ab!cd',
                                    SUFFIX_MATCH, '"\\'."\x0A", 'fu ga']]]],
   out => '[fu\\ ga|ab\\!cd$="\\"\\\\\\a "]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, 'http://ho/', 'ab!cd',
                                    SUBSTRING_MATCH, '"\\'."\x0A", 'fu ga']]]],
   out => '[fu\\ ga|ab\\!cd*="\\"\\\\\\a "]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, '', 'ab!cd',
                                    EQUALS_MATCH, '"\\'."\x0A", 'fu ga']]]],
   out => '[ab\\!cd="\\"\\\\\\a "]'},
  {in => [[DESCENDANT_COMBINATOR, [[ATTRIBUTE_SELECTOR, 'http://ho/', 'ab!cd',
                                    EQUALS_MATCH, '', 'fu ga']]]],
   out => '[fu\\ ga|ab\\!cd=""]'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'active']]]],
   out => ':active'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'only-child']]]],
   out => ':only-child'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'lang', 'a"']]]],
   out => ':lang(a\\")'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'lang', 'ja-JP']]]],
   out => ':lang(ja-JP)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, '-manakai-contains',
                                    '']]]],
   out => ':-manakai-contains("")'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, '-manakai-contains',
                                    'ja \\'."\x0F"]]]],
   out => ':-manakai-contains("ja \\\\\\f ")'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'not',
     [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, 'a', '', 0, 0]]],
      [DESCENDANT_COMBINATOR, [[CLASS_SELECTOR, 'b c']],
       ADJACENT_SIBLING_COMBINATOR, [[ID_SELECTOR, '1']]]],
   ]]]],
   out => ':not(a, .b\\ c + #\\31 )'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'not',
     [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', 'a', undef, 0, 0]]],
      [DESCENDANT_COMBINATOR, [[CLASS_SELECTOR, 'b c']],
       ADJACENT_SIBLING_COMBINATOR, [[ID_SELECTOR, '1']]]],
   ]]]],
   out => ':not(|a, .b\\ c + #\\31 )'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'not',
     [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, 'a', '', 0, 0]]],
      [DESCENDANT_COMBINATOR, [[CLASS_SELECTOR, 'b c']],
       ADJACENT_SIBLING_COMBINATOR, [[ID_SELECTOR, '1']]]],
   ]]]],
   out => ':not(a, .b\\ c + #\\31 )'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-child',
                                    '010', '0002']]]],
   out => ':nth-child(10n+2)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-child',
                                    '010', '000']]]],
   out => ':nth-child(10n)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-child',
                                    '-0', '0002']]]],
   out => ':nth-child(2)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-child',
                                    '00', '-000']]]],
   out => ':nth-child(0)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-child',
                                    '+0', '+0002']]]],
   out => ':nth-child(2)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-child',
                                    '-0', '-0002']]]],
   out => ':nth-child(-2)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-of-type',
                                    '-013', '000']]]],
   out => ':nth-of-type(-13n)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-last-child',
                                    '-013', '0002']]]],
   out => ':nth-last-child(-13n+2)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-last-of-type',
                                    '-013', '-0002']]]],
   out => ':nth-last-of-type(-13n-2)'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_ELEMENT_SELECTOR, 'before']]]],
   out => '::before'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_ELEMENT_SELECTOR, 'first-line']]]],
   out => '::first-line'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_ELEMENT_SELECTOR, 'cue']]]],
   out => '::cue'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_ELEMENT_SELECTOR, 'cue',
     [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, '', 'a', undef, 0, 0]]],
      [DESCENDANT_COMBINATOR, [[CLASS_SELECTOR, 'b c']],
       ADJACENT_SIBLING_COMBINATOR, [[ID_SELECTOR, '1']]]],
   ]]]],
   out => '::cue(|a, .b\\ c + #\\31 )'},
  {in => [[DESCENDANT_COMBINATOR, [[PSEUDO_CLASS_SELECTOR, 'nth-child',
                                    '010', '0002']],
           CHILD_COMBINATOR, [[PSEUDO_ELEMENT_SELECTOR, 'first-line']]]],
   out => ':nth-child(10n+2) > ::first-line'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, 'cd', '', 0, 0]],
           CHILD_COMBINATOR, [[CLASS_SELECTOR, 'line']],
           GENERAL_SIBLING_COMBINATOR, [[ID_SELECTOR, '_']]]],
   out => 'cd > .line ~ #_'},
  {in => [[DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, 'cd', '', 0, 0]],
           CHILD_COMBINATOR, [[CLASS_SELECTOR, 'line']],
           GENERAL_SIBLING_COMBINATOR, [[ID_SELECTOR, '_']]],
          [DESCENDANT_COMBINATOR, [[ELEMENT_SELECTOR, undef, 'f', '', 0, 0],
                                   [PSEUDO_CLASS_SELECTOR, 'enabled']],
           ADJACENT_SIBLING_COMBINATOR, [[ID_SELECTOR, '12']]]],
   out => 'cd > .line ~ #_, f:enabled + #\31 2'},
) {
  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Serializer->new;
    is $s->serialize_selectors ($test->{in}), $test->{out};
    done $c;
  } n => 1, name => ['serialize_selectors', $test->{out}];
}

for my $test (
  [[ELEMENT_SELECTOR, undef, 'a'  , ''   , 0, 0],   'a'],
  [[ELEMENT_SELECTOR, undef, undef, ''   , 0, 1],   '*'],
  [[ELEMENT_SELECTOR, ''   , 'a'  , undef, 0, 0],  '|a'],
  [[ELEMENT_SELECTOR, ''   , undef, undef, 0, 1],  '|*'],
  [[ELEMENT_SELECTOR, undef, 'a'  , undef, 1, 0], '*|a'],
  [[ELEMENT_SELECTOR, undef, undef, undef, 1, 1], '*|*'],
  [[ELEMENT_SELECTOR, undef, undef, ''   , 0, 0], ''],

  #@namespace '';
  [[ELEMENT_SELECTOR, ''   , 'a'  , ''   , 0, 0],   'a'],
  [[ELEMENT_SELECTOR, ''   , undef, ''   , 0, 1],   '*'],
  [[ELEMENT_SELECTOR, ''   , 'a'  , undef, 0, 0],  '|a'],
  [[ELEMENT_SELECTOR, ''   , undef, undef, 0, 1],  '|*'],
  [[ELEMENT_SELECTOR, undef, 'a'  , undef, 1, 0], '*|a'],
  [[ELEMENT_SELECTOR, undef, undef, undef, 1, 1], '*|*'],
  [[ELEMENT_SELECTOR, ''   , undef, ''   , 0, 0], ''],

  #@namespace 'ns';
  [[ELEMENT_SELECTOR, 'ns' , 'a'  , ''   , 0, 0],   'a'],
  [[ELEMENT_SELECTOR, 'ns' , undef, ''   , 0, 1],   '*'],
  [[ELEMENT_SELECTOR, ''   , 'a'  , undef, 0, 0],  '|a'],
  [[ELEMENT_SELECTOR, ''   , undef, undef, 0, 1],  '|*'],
  [[ELEMENT_SELECTOR, undef, 'a'  , undef, 1, 0], '*|a'],
  [[ELEMENT_SELECTOR, undef, undef, undef, 1, 1], '*|*'],
  [[ELEMENT_SELECTOR, 'ns' , undef, ''   , 0, 0], ''],

  #@namespace p '';
  [[ELEMENT_SELECTOR, ''   , 'a'  , 'p'  , 0, 0], 'p|a'],
  [[ELEMENT_SELECTOR, ''   , undef, 'p'  , 0, 1], 'p|*'],

  #@namespace p 'ns';
  [[ELEMENT_SELECTOR, 'ns' , 'a'  , 'p'  , 0, 0], 'p|a'],
  [[ELEMENT_SELECTOR, 'ns' , undef, 'p'  , 0, 1], 'p|*'],

  #In :not() or :match()
  [[ELEMENT_SELECTOR, undef, undef, ''   , 0, 0], ''],
) {
  test {
    my $c = shift;
    my $s = Web::CSS::Selectors::Serializer->new;
    is $s->serialize_selectors ([[DESCENDANT_COMBINATOR, [$test->[0]]]]),
        $test->[1];
    done $c;
  } n => 1, name => ['serialize_selectors', $test->[1]];
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
