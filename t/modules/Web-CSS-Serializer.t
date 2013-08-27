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

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
