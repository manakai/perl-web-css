use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Web::CSS::Serializer;
use Web::CSS::Selectors::Parser;
use Web::CSS::Parser;
use Test::More;
use Test::Differences;

for my $test (
  {in => ['KEYWORD', 'none'], out => 'none'},
  {in => ['KEYWORD', 'list-item'], out => 'list-item'},
  {in => ['NUMBER', '0'], out => '0'},
  {in => ['NUMBER', '0.0001'], out => '0.0001'},
  {in => ['NUMBER', '0.000001'], out => '0.000001'},
  {in => ['NUMBER', '.0001'], out => '0.0001'},
  {in => ['NUMBER', '.000001'], out => '0.000001'},
  {in => ['NUMBER', '0.0000001'], out => '0'},
  {in => ['NUMBER', '-0'], out => '0'},
  {in => ['NUMBER', '-0.0001'], out => '-0.0001'},
  {in => ['NUMBER', '-0.000001'], out => '-0.000001'},
  {in => ['NUMBER', '-.0001'], out => '-0.0001'},
  {in => ['NUMBER', '-.000001'], out => '-0.000001'},
  {in => ['NUMBER', '-0.0000001'], out => '0'},
  {in => ['NUMBER', '000120'], out => '120'},
  {in => ['NUMBER', '0000'], out => '0'},
  {in => ['NUMBER', '000e0'], out => '0'},
  {in => ['NUMBER', '001e10'], out => '10000000000'},
  {in => ['NUMBER', '21e10'], out => '210000000000'},
  {in => ['NUMBER', '21e-10'], out => '0'},
  {in => ['NUMBER', '21e-3'], out => '0.021'},
  {in => ['NUMBER', '-21e10'], out => '-210000000000'},
  {in => ['NUMBER', '-21e-10'], out => '0'},
  {in => ['NUMBER', '-21e-3'], out => '-0.021'},
  {in => ['NUMBER', '+21e-3'], out => '0.021'},
  {in => ['ANGLE', '12', 'deg'], out => '12deg'},
  {in => ['ANGLE', '12', 'grad'], out => '12grad'},
  {in => ['ANGLE', '12.20', 'turn'], out => '12.2turn'},
  {in => ['ANGLE', '-0012.20', 'turn'], out => '-12.2turn'},
  {in => ['FREQUENCY', '12', 'hz'], out => '12hz'},
  {in => ['FREQUENCY', '12', 'khz'], out => '12khz'},
  {in => ['FREQUENCY', '12.20', 'hz'], out => '12.2hz'},
  {in => ['FREQUENCY', '-0012.20', 'hz'], out => '-12.2hz'},
  {in => ['LENGTH', '12', 'px'], out => '12px'},
  {in => ['LENGTH', '12', 'cm'], out => '12cm'},
  {in => ['LENGTH', '12.20', 'vmin'], out => '12.2vmin'},
  {in => ['LENGTH', '-0012.20', 'em'], out => '-12.2em'},
  {in => ['RESOLUTION', '12', 'dppx'], out => '12dppx'},
  {in => ['RESOLUTION', '12', 'dpcm'], out => '12dpcm'},
  {in => ['RESOLUTION', '12.20', 'dpi'], out => '12.2dpi'},
  {in => ['RESOLUTION', '-0012.20', 'dppx'], out => '-12.2dppx'},
  {in => ['TIME', '12', 's'], out => '12s'},
  {in => ['TIME', '12', 'ms'], out => '12ms'},
  {in => ['TIME', '12.20', 's'], out => '12.2s'},
  {in => ['TIME', '-0012.20', 'ms'], out => '-12.2ms'},
  {in => ['PERCENTAGE', '12'], out => '12%'},
  {in => ['PERCENTAGE', '12'], out => '12%'},
  {in => ['PERCENTAGE', '12.20'], out => '12.2%'},
  {in => ['PERCENTAGE', '-0012.20'], out => '-12.2%'},
  {in => ['RGBA', '12', '21', '255', '1'], out => 'rgb(12, 21, 255)'},
  {in => ['RGBA', '+12', '-21', '255.0001', '+1.0'], out => 'rgb(12, -21, 255.0001)'},
  {in => ['RGBA', '12', '21', '255', '00.4'], out => 'rgba(12, 21, 255, 0.4)'},
  {in => ['RGBA', '0', '0', '0', '0'], out => 'rgba(0, 0, 0, 0)'},
  {in => ['STRING', ''], out => '""'},
  {in => ['STRING', 'a  bc'], out => '"a  bc"'},
  {in => ['STRING', "a\x0Ab"], out => '"a\a b"'},
  {in => ['STRING', "a\x{7F}\x9f\x01"], out => q{"a\7f \9f \1 "}},
  {in => ['STRING', "a\x{FFFF}b"], out => qq{"a\x{ffff}b"}},
  {in => ['STRING', "a\x{10FFFF}b"], out => qq{"a\x{10ffff}b"}},
  {in => ['STRING', "a\x{D800}b"], out => qq{"a\x{D800}b"}},
  {in => ['STRING', '"\\'], out => q{"\\"\\\\"}},
  {in => ['URL', ''], out => 'url("")'},
  {in => ['URL', 'a  bc'], out => 'url("a  bc")'},
  {in => ['URL', "a\x0Ab"], out => 'url("a\a b")'},
  {in => ['URL', "a\x{7F}\x9f\x01"], out => q{url("a\7f \9f \1 ")}},
  {in => ['URL', "a\x{FFFF}b"], out => qq{url("a\x{ffff}b")}},
  {in => ['URL', "a\x{10FFFF}b"], out => qq{url("a\x{10ffff}b")}},
  {in => ['URL', "a\x{D800}b"], out => qq{url("a\x{D800}b")}},
  {in => ['URL', '"\\'], out => q{url("\\"\\\\")}},
  {in => ['RATIO', '12', '0010'], out => '12/10'},
  {in => ['RATIO', '0000001', '0010'], out => '1/10'},
) {
  test {
    my $c = shift;
    my $serializer = Web::CSS::Serializer->new;
    my $actual = $serializer->serialize_value ($test->{in});
    is $actual, $test->{out};
    done $c;
  } n => 1, name => ['serialize_value', $test->{out}];
}

for my $test (
  {in => {prop_values => {}}, key => 'display', out => undef},
  {in => {prop_values => {display => ['KEYWORD', 'block']}},
   key => 'display', out => 'block'},
  {in => {prop_values => {}}, key => 'background_position', out => undef},
  {in => {prop_values => {background_position_x => ['PERCENTAGE', 40]}},
   key => 'background_position', out => undef},
  {in => {prop_values => {background_position_x => ['PERCENTAGE', 40],
                          background_position_y => ['KEYWORD', 'top']}},
   key => 'background_position', out => '40% top'},
) {
  test {
    my $c = shift;
    my $serializer = Web::CSS::Serializer->new;
    my $actual = $serializer->serialize_prop_value ($test->{in}, $test->{key});
    is $actual, $test->{out};
    done $c;
  } n => 1, name => ['serialize_prop_value', $test->{out}];
}

for my $test (
  {in => {prop_importants => {}}, key => 'display', out => undef},
  {in => {prop_importants => {display => 1}},
   key => 'display', out => 'important'},
  {in => {prop_importants => {}},
   key => 'background_position', out => undef},
  {in => {prop_importants => {background_position_x => 1}},
   key => 'background_position', out => undef},
  {in => {prop_importants => {background_position_x => 1,
                              background_position_y => 1}},
   key => 'background_position', out => 'important'},
) {
  test {
    my $c = shift;
    my $serializer = Web::CSS::Serializer->new;
    my $actual = $serializer->serialize_prop_priority
        ($test->{in}, $test->{key});
    is $actual, $test->{out};
    done $c;
  } n => 1, name => ['serialize_prop_priority', $test->{out}];
}

for my $test (
  {in => {}, out => ''},
  {in => {prop_keys => ['display'],
          prop_values => {display => ['KEYWORD', 'block']}},
   out => 'display: block;'},
  {in => {prop_keys => ['list_style_type', 'display'],
          prop_values => {display => ['KEYWORD', 'block'],
                          list_style_type => ['KEYWORD', 'none']}},
   out => 'list-style-type: none; display: block;'},
  {in => {prop_keys => ['list_style_type', 'display'],
          prop_values => {display => ['KEYWORD', 'block'],
                          list_style_type => ['KEYWORD', 'none']},
          prop_importants => {list_style_type => 1}},
   out => 'list-style-type: none !important; display: block;'},
  {in => {prop_keys => ['background_position_x'],
          prop_values => {background_position_x => ['KEYWORD', 'left']}},
   out => 'background-position-x: left;'},
  {in => {prop_keys => ['background_position_y', 'background_position_x'],
          prop_values => {background_position_x => ['KEYWORD', 'left'],
                          background_position_y => ['PERCENTAGE', 29]}},
   out => 'background-position: left 29%;'},
  {in => {prop_keys => ['background_position_y', 'background_position_x'],
          prop_values => {background_position_x => ['KEYWORD', 'left'],
                          background_position_y => ['PERCENTAGE', 29]},
          prop_importants => {background_position_x => 1,
                              background_position_y => 1}},
   out => 'background-position: left 29% !important;'},
  {in => {prop_keys => ['background_position_y', 'background_position_x'],
          prop_values => {background_position_x => ['KEYWORD', 'left'],
                          background_position_y => ['PERCENTAGE', 29]},
          prop_importants => {background_position_x => 0,
                              background_position_y => 1}},
   out => 'background-position-y: 29% !important; background-position-x: left;'},
  {in => {prop_keys => ['background_position_y', 'background_position_x'],
          prop_values => {background_position_x => ['KEYWORD', 'inherit'],
                          background_position_y => ['PERCENTAGE', 29]},
          prop_importants => {background_position_x => 1,
                              background_position_y => 1}},
   out => 'background-position-y: 29% !important; background-position-x: inherit !important;'},
  {in => {prop_keys => ['background_position_y', 'background_position_x'],
          prop_values => {background_position_x => ['KEYWORD', 'inherit'],
                          background_position_y => ['KEYWORD', 'inherit']},
          prop_importants => {background_position_x => 1,
                              background_position_y => 1}},
   out => 'background-position: inherit !important;'},
  {in => {prop_keys => ['background_position_y', 'display', 'background_position_x'],
          prop_values => {background_position_x => ['KEYWORD', 'left'],
                          background_position_y => ['PERCENTAGE', 29],
                          display => ['KEYWORD', 'inline']},
          prop_importants => {background_position_x => 0,
                              background_position_y => 1}},
   out => 'background-position-y: 29% !important; display: inline; background-position-x: left;'},
) {
  test {
    my $c = shift;
    my $serializer = Web::CSS::Serializer->new;
    my $actual = $serializer->serialize_prop_decls
        ($test->{in}, $test->{key});
    is $actual, $test->{out};
    done $c;
  } n => 1, name => ['serialize_prop_decls', $test->{out}];
}

for my $test (
  {in => {rules => [{rule_type => 'style',
                     selectors => [[0, [[2, 'hoge'], [3, 'fuga']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}}]},
   out => 'hoge#fuga { }'},
  {in => {rules => [{rule_type => 'style',
                     selectors => [[0, [[2, 'hoge'], [3, 'fuga']]]],
                     prop_keys => ['display'],
                     prop_values => {display => ['KEYWORD', 'block']},
                     prop_importants => {}}]},
   out => 'hoge#fuga { display: block; }'},
  {in => {rules => [{rule_type => 'charset', encoding => ''}]},
   out => '@charset "";'},
  {in => {rules => [{rule_type => 'charset', encoding => 'hoge\f"'}]},
   out => '@charset "hoge\\\\f\\"";'},
  {in => {rules => [{rule_type => 'import', href => '',
                     mqs => []}]},
   out => '@import url("");'},
  {in => {rules => [{rule_type => 'import', href => 'ab"c'."\x0F",
                     mqs => []}]},
   out => '@import url("ab\\"c\\f ");'},
  {in => {rules => [{rule_type => 'import', href => 'ab"c'."\x0F",
                     mqs => [{type => 'all'}, {type => 'screen'}]}]},
   out => '@import url("ab\\"c\\f ") all, screen;'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => undef, nsurl => ''}]},
   out => '@namespace url("");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => undef, nsurl => 'http hoge \\"'}]},
   out => '@namespace url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => 'a', nsurl => 'http hoge \\"'}]},
   out => '@namespace a url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => '12', nsurl => 'http hoge \\"'}]},
   out => '@namespace \31 2 url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => ' ', nsurl => 'http hoge \\"'}]},
   out => '@namespace \  url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => "\x01\x0A\x21\x22\x23\x24\x25\x26", nsurl => 'http hoge \\"'}]},
   out => '@namespace \\1 \\a \\!\\"\\#\\$\\%\\& url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => "\x27\x28\x29\x30", nsurl => 'http hoge \\"'}]},
   out => '@namespace \\\'\\(\\)0 url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => "-12", nsurl => 'http hoge \\"'}]},
   out => '@namespace -\\31 2 url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => "--12", nsurl => 'http hoge \\"'}]},
   out => '@namespace -\\-12 url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => "--12\x7E\x7F\x80", nsurl => 'http hoge \\"'}]},
   out => '@namespace -\\-12\\~\\7f \\80  url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => "\x2A\x2B\x2C\x2D\x2E\x2F\x{3000}\x{3001}", nsurl => 'http hoge \\"'}]},
   out => '@namespace \\*\\+\\,-\\.\\/'."\x{3000}\x{3001}".' url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'namespace',
                     prefix => "\x{DC00}\x{FFFF}\x{10FFFF}", nsurl => 'http hoge \\"'}]},
   out => '@namespace '."\x{DC00}\x{FFFF}\x{10FFFF}".' url("http hoge \\\\\\"");'},
  {in => {rules => [{rule_type => 'media',
                     mqs => [],
                     rule_ids => []}]},
   out => '@media  { '."\x0A".'}'},
  {in => {rules => [{rule_type => 'media',
                     mqs => [],
                     rule_ids => [1]},
                    {rule_type => 'style',
                     selectors => [[0, [[2, 'hoge'], [3, 'fuga']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}}]},
   out => '@media  { '."\x0A".'  hoge#fuga { }'."\x0A".'}'},
  {in => {rules => [{rule_type => 'media',
                     mqs => [],
                     rule_ids => [1, 2]},
                    {rule_type => 'style',
                     selectors => [[0, [[2, 'hoge'], [3, 'fuga']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}},
                    {rule_type => 'media',
                     mqs => [],
                     rule_ids => [3]},
                    {rule_type => 'style',
                     selectors => [[0, [[2, 'AAA']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}}]},
   out => '@media  { '."\x0A".'  hoge#fuga { }'."\x0A".'  @media  { '."\x0A".'  AAA { }'."\x0A"."}\x0A".'}'},
  {in => {rules => [{rule_type => 'media',
                     mqs => [{type => 'all', not => 1},
                             {type => 'print'}],
                     rule_ids => [1]},
                    {rule_type => 'style',
                     selectors => [[0, [[2, 'hoge'], [3, 'fuga']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}}]},
   out => '@media not all, print { '."\x0A".'  hoge#fuga { }'."\x0A".'}'},
  {in => {rules => [{rule_type => 'sheet',
                     rule_ids => [1]},
                    {rule_type => 'style',
                     selectors => [[0, [[2, 'hoge'], [3, 'fuga']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}}]},
   out => 'hoge#fuga { }'},
  {in => {rules => [{rule_type => 'sheet',
                     rule_ids => [1, 2]},
                    {rule_type => 'style',
                     selectors => [[0, [[2, 'hoge'], [3, 'fuga']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}},
                    {rule_type => 'style',
                     selectors => [[0, [[3, 'aaA']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}}]},
   out => 'hoge#fuga { }'."\x0A".'#aaA { }'},
  {in => {rules => [{rule_type => 'sheet',
                     rule_ids => [1, 2]},
                    {rule_type => 'style',
                     selectors => [[0, [[2, 'hoge'], [3, 'fuga']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}},
                    {rule_type => 'media',
                     mqs => [],
                     rule_ids => [3]},
                    {rule_type => 'style',
                     selectors => [[0, [[2, 'AAA']]]],
                     prop_keys => [], prop_values => {},
                     prop_importants => {}}]},
   out => 'hoge#fuga { }'."\x0A".'@media  { '."\x0A".'  AAA { }'."\x0A".'}'},
) {
  test {
    my $c = shift;
    my $serializer = Web::CSS::Serializer->new;
    my $actual = $serializer->serialize_rule ($test->{in}, 0);
    eq_or_diff $actual, $test->{out};
    done $c;
  } n => 1, name => ['serialize_rule', $test->{out}];
}

test {
  my $c = shift;
  my $serializer = Web::CSS::Serializer->new;
  is $serializer->serialize_mq ({type => 'a b', features => []}), 'a\\ b';
  done $c;
} n => 1, name => 'serialize_mq';

test {
  my $c = shift;
  my $serializer = Web::CSS::Serializer->new;
  is $serializer->serialize_mq_list
      ([{type => 'a b', features => []},
        {features => [{name => 'color'}]}]), 'a\\ b, (color)';
  done $c;
} n => 1, name => 'serialize_mq_list';

test {
  my $c = shift;
  my $serializer = Web::CSS::Serializer->new;
  is $serializer->serialize_selectors
      ([[DESCENDANT_COMBINATOR, [[LOCAL_NAME_SELECTOR, 'a'],
                                 [CLASS_SELECTOR, 'b']]]]),
          'a.b';
  done $c;
} n => 1, name => 'serialize_selectors';

for my $test (
  {in => q{hoge{} |fuga{} *|abc {}
           *{} |*{} *|*{}
           .a {} *.a {} |*.a {} *|*.a {}}, out => q{hoge { }
|fuga { }
*|abc { }
* { }
|* { }
*|* { }
.a { }
*.a { }
|*.a { }
*|*.a { }}},
  {in => q{@namespace "";hoge{} |fuga{}*|abc{}
           *{} |*{} *|*{}
           .a {} *.a {} |*.a {} *|*.a {}}, out => q{@namespace url("");
hoge { }
|fuga { }
*|abc { }
* { }
|* { }
*|* { }
.a { }
*.a { }
|*.a { }
*|*.a { }}},
  {in => q{@namespace "hoge";hoge{} |fuga{}*|abc{}
           *{} |*{} *|*{}
           .a {} *.a {} |*.a {} *|*.a {}}, out => q{@namespace url("hoge");
hoge { }
|fuga { }
*|abc { }
* { }
|* { }
*|* { }
.a { }
*.a { }
|*.a { }
*|*.a { }}},
  {in => q{@namespace abc "hoge";hoge{} |fuga{}*|abc{}
           *{} |*{} *|*{}
           .a {} *.a {} |*.a {} *|*.a {}}, out => q{@namespace abc url("hoge");
hoge { }
|fuga { }
*|abc { }
* { }
|* { }
*|* { }
.a { }
*.a { }
|*.a { }
*|*.a { }}},
) {
  test {
    my $c = shift;
    my $parser = Web::CSS::Parser->new;
    my $parsed = $parser->parse_char_string_as_ss ($test->{in});
    my $serializer = Web::CSS::Serializer->new;
    eq_or_diff $serializer->serialize_rule ($parsed, 0), $test->{out};
    done $c;
  } n => 1, name => ['parse then serialize', $test->{in}];
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
