use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Web::CSS::Serializer;
use Test::More;

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

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
