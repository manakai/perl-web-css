use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Web::CSS::PARSER;# XXX
use Test::More;
use Test::Differences;
use Web::CSS::Selectors::Parser;
use Web::CSS::MediaQueries::Parser;

sub SS ($) { {id => 0, type => 'sheet', rule_ids => $_[0]} }
sub S ($$$$$$) { {parent_id => $_[0], id => $_[1], type => 'style',
                  selectors => Web::CSS::Selectors::Parser->new->parse_char_string_as_selectors($_[2]),
                  prop_keys => $_[3], prop_values => $_[4],
                  prop_importants => $_[5]} }
sub MEDIA ($$$$) { {parent_id => $_[0], id => $_[1], type => 'media',
                    rule_ids => $_[2],
                    mqs => Web::CSS::MediaQueries::Parser->new->parse_char_string_as_mqs($_[3])} }
sub CHARSET ($$$) { {parent_id => $_[0], id => $_[1], type => 'charset',
                     encoding => $_[2]} }
sub IMPORT ($$$$) { {parent_id => $_[0], id => $_[1], type => 'import',
                     href => $_[2],
                     mqs => Web::CSS::MediaQueries::Parser->new->parse_char_string_as_mqs($_[3])} }
sub K ($) { ['KEYWORD', $_[0]] }

for my $test (
  {in => '', out => [SS []]},
  {in => ' /**/ /**/ ', out => [SS []]},
  {in => 'hoge', out => [SS []],
   errors => ['1;5;m;css:qrule:no block;;']},
  {in => 'hoge{', out => [SS [1], S 0=>1, 'hoge', [], {}, {}],
   errors => ['1;6;w;css:block:eof;;']},
  {in => 'hoge{}', out => [SS [1], S(0=>1, 'hoge', [], {}, {})]},
  {in => 'hoge>{}', out => [SS []], errors => ['1;6;m;no sss;;']},
  {in => 'hoge>{}r{}', out => [SS [1], S(0=>1, 'r', [], {}, {})],
   errors => ['1;6;m;no sss;;']},
  {in => 'hoge>q{}', out => [SS [1], S(0=>1, 'hoge > q', [], {}, {})]},
  {in => '<!--hoge>q{}-->r{}',
   out => [SS [1, 2],
           S(0=>1, 'hoge > q', [], {}, {}),
           S(0=>2, 'r', [], {}, {})]},
  {in => 'hoge{displAy:Block}',
   out => [SS [1], S(0=>1, 'hoge', ['display'], {display => K 'block'}, {})]},
  {in => 'hoge{displAy:Block ! Important}',
   out => [SS [1], S(0=>1, 'hoge', ['display'], {display => K 'block'},
                     {display => 1})]},
  {in => ' /**/ hoge /**/ { /**/ displAy /**/ : /**/ Block /**/ ! /**/ /**/ Important /**/ /**/ } /**/ ',
   out => [SS [1], S(0=>1, 'hoge', ['display'], {display => K 'block'},
                     {display => 1})]},
  {in => 'hoge{displAy:Block ! Import}',
   out => [SS [1], S(0=>1, 'hoge', [], {}, {})],
   errors => ['1;14;m;css:value:not keyword;;']},
  {in => 'hoge{displAy: 12px}',
   out => [SS [1], S(0=>1, 'hoge', [], {}, {})],
   errors => ['1;15;m;css:value:not keyword;;']},
  {in => 'hoge{display:none ;displAy: 12px}',
   out => [SS [1], S(0=>1, 'hoge', ['display'], {display => K 'none'}, {})],
   errors => ['1;29;m;css:value:not keyword;;']},
  {in => 'hoge{displAy: inheRit }',
   out => [SS [1], S(0=>1, 'hoge', ['display'], {display => K 'inherit'}, {})]},
  {in => 'hoge{displAy: iniTial }',
   out => [SS [1], S(0=>1, 'hoge', ['display'], {display => K 'initial'}, {})]},
  {in => 'hoge{displAy: -moz-iniTial }',
   out => [SS [1], S(0=>1, 'hoge', ['display'], {display => K 'initial'}, {})]},
  {in => '@media{}',
   out => [SS [1], MEDIA(0=>1=>[], '')]},
  {in => '@media{',
   out => [SS [1], MEDIA(0=>1=>[], '')],
   errors => ['1;8;w;css:block:eof;;']},
  {in => '@media all, screen, (hoge) {}',
   out => [SS [1], MEDIA(0=>1=>[], '/*345*/all, screen, (error)')],
   errors => ['1;22;m;mq:feature:unknown;;']},
  {in => '@media{x y {}}',
   out => [SS [1], MEDIA(0=>1=>[2], ''), S(1=>2, 'x y', [], {}, {})]},
  {in => '@MEDIa{x y {}}',
   out => [SS [1], MEDIA(0=>1=>[2], ''), S(1=>2, 'x y', [], {}, {})]},
  {in => '@media{x y {displAy:none}}',
   out => [SS [1], MEDIA(0=>1=>[2], ''), S(1=>2, 'x y', ['display'], {display => K 'none'}, {})]},
  {in => '@media{x y {displAy:none;aa',
   out => [SS [1], MEDIA(0=>1=>[2], ''), S(1=>2, 'x y', ['display'], {display => K 'none'}, {})],
   errors => ['1;28;m;css:decl:no colon;;', '1;28;w;css:block:eof;;']},
  {in => '@media{x y {displAy:none;aa}}',
   out => [SS [1], MEDIA(0=>1=>[2], ''), S(1=>2, 'x y', ['display'], {display => K 'none'}, {})],
   errors => ['1;28;m;css:decl:no colon;;']},
  {in => '@media{x y {displAy:none;display',
   out => [SS [1], MEDIA(0=>1=>[2], ''), S(1=>2, 'x y', ['display'], {display => K 'none'}, {})],
   errors => ['1;33;m;css:decl:no colon;;', '1;33;w;css:block:eof;;']},
  {in => '@media{@media PRINT{x y {displAy:none}}}',
   out => [SS [1], MEDIA(0=>1=>[2], ''), MEDIA(1=>2=>[3], '/*3456789012*/print'), S(2=>3, 'x y', ['display'], {display => K 'none'}, {})]},
  {in => '@hoGe aa 12px; p {} q{}',
   out => [SS [1, 2], S(0=>1, 'p', [], {}, {}), S(0=>2, 'q', [], {}, {})],
   errors => ['1;1;m;unknown at-rule;;hoge']},
  {in => '@hoGe aa 12px; p >{} q{}',
   out => [SS [1], S(0=>1, 'q', [], {}, {})],
   errors => ['1;1;m;unknown at-rule;;hoge', '1;19;m;no sss;;']},
  {in => '@hoGe aa 12px {color:2px} q{}',
   out => [SS [1], S(0=>1, 'q', [], {}, {})],
   errors => ['1;1;m;unknown at-rule;;hoge']},
  {in => 'a { @media { } display:block}',
   out => [SS [1], S(0=>1, 'a', ['display'], {display => K 'block'}, {})],
   errors => ['1;5;m;css:style:at-rule;;media']},
  {in => 'a { @media { } ;display:block}',
   out => [SS [1], S(0=>1, 'a', ['display'], {display => K 'block'}, {})],
   errors => ['1;5;m;css:style:at-rule;;media']},
  {in => 'a { display: block; @media { }}',
   out => [SS [1], S(0=>1, 'a', ['display'], {display => K 'block'}, {})],
   errors => ['1;21;m;css:style:at-rule;;media']},
  {in => 'a { display: block @media { }}',
   out => [SS [1], S(0=>1, 'a', [], {}, {})],
   errors => ['1;14;m;css:value:not keyword;;']},
  {in => 'a { @media { display: block }} p {}',
   out => [SS [1, 2], S(0=>1, 'a', [], {}, {}), S(0=>2, 'p', [], {}, {})],
   errors => ['1;5;m;css:style:at-rule;;media',
              '1;29;m;css:qrule:no block;;']},
  {in => '@media{a { @media { display: block }} p {}}',
   out => [SS [1], MEDIA(0=>1=>[2, 3], ''), S(1=>2, 'a', [], {}, {}), S(1=>3, 'p', [], {}, {})],
   errors => ['1;12;m;css:style:at-rule;;media',
              '1;36;m;css:qrule:no block;;']},
  {in => '@media "utf-8";',
   out => [SS []],
   errors => ['1;15;m;css:at-rule:block missing;;media']},
  {in => '@mediA "utf-8";',
   out => [SS []],
   errors => ['1;15;m;css:at-rule:block missing;;media']},
  {in => '@media "utf-8"',
   out => [SS []],
   errors => ['1;15;w;css:at-rule:eof;;',
              '1;15;m;css:at-rule:block missing;;media']},
  {in => '@media "utf-8";p{}',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;15;m;css:at-rule:block missing;;media']},
  {in => '@charset "utf-8";',
   out => [SS [1], CHARSET(0=>1, 'utf-8')]},
  {in => '@cHARSET "utf-8";',
   out => [SS [1], CHARSET(0=>1, 'utf-8')]},
  {in => '@charset /**/ "utf-8" /**/ ;',
   out => [SS [1], CHARSET(0=>1, 'utf-8')]},
  {in => '@charset "utf-8"',
   out => [SS [1], CHARSET(0=>1, 'utf-8')],
   errors => ['1;17;w;css:at-rule:eof;;']},
  {in => '@charset"utf-8";',
   out => [SS [1], CHARSET(0=>1, 'utf-8')]},
  {in => q{@charset'Utf-8';},
   out => [SS [1], CHARSET(0=>1, 'Utf-8')]},
  {in => '@charset;',
   out => [SS []], errors => ['1;9;m;css:value:not string;;']},
  {in => '@charset',
   out => [SS []],
   errors => ['1;9;w;css:at-rule:eof;;', '1;9;m;css:value:not string;;']},
  {in => '@charset utf-8;',
   out => [SS []],
   errors => ['1;10;m;css:value:not string;;']},
  {in => '@charset "utf-8',
   out => [SS [1], CHARSET(0=>1, 'utf-8')],
   errors => ['1;16;w;css:string:eof;;']},
  {in => '@charset "utf-8' . "\n",
   out => [SS []],
   errors => ['2;0;m;css:string:newline;;', '2;1;w;css:at-rule:eof;;',
              '1;10;m;css:value:not string;;']},
  {in => '@charset "utf-8' . "\n" . 'p{}q{}',
   out => [SS [1], S(0=>1, 'q', [], {}, {})],
   errors => ['2;0;m;css:string:newline;;',
              '2;2;m;css:at-rule:block not allowed;;charset']},
  {in => '@charset "utf-8" {}',
   out => [SS []],
   errors => ['1;18;m;css:at-rule:block not allowed;;charset']},
  {in => '@charSET "utf-8" {}',
   out => [SS []],
   errors => ['1;18;m;css:at-rule:block not allowed;;charset']},
  {in => 'p{}@charset "u";',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;4;m;at-rule not allowed;charset;']},
  {in => '@media{@charset "u";}',
   out => [SS [1], MEDIA(0=>1=>[], '')],
   errors => ['1;8;m;at-rule not allowed;charset;']},
  {in => '>{}@charset "u";',
   out => [SS []],
   errors => ['1;1;m;no sss;;', '1;4;m;at-rule not allowed;charset;']},
  {in => '<!--@cHARSET "utf-8";',
   out => [SS [1], CHARSET(0=>1, 'utf-8')]},
  {in => '-->@cHARSET "utf-8";',
   out => [SS [1], CHARSET(0=>1, 'utf-8')]},
  {in => ' /**/ @cHARSET "utf-8";',
   out => [SS [1], CHARSET(0=>1, 'utf-8')]},
  {in => '@charset "x";@cHARSET "utf-8";',
   out => [SS [1], CHARSET(0=>1, 'x')],
   errors => ['1;14;m;at-rule not allowed;charset;']},
  {in => '@import "aa";',
   out => [SS [1], IMPORT(0=>1, 'aa', '')]},
  {in => '@import "aa" screEn;',
   out => [SS [1], IMPORT(0=>1, 'aa', '/*mport "aa*/screen')]},
  {in => '@import "aa" screEn ,print;',
   out => [SS [1], IMPORT(0=>1, 'aa', '/*mport "aa*/screen, print')]},
  {in => '@import "aa" "bb" screEn ,print;',
   out => [SS [1], IMPORT(0=>1, 'aa', '(error                 ), print')],
   errors => ['1;14;m;mq:broken;;']},
  {in => '@import url();',
   out => [SS [1], IMPORT(0=>1, '', '')]},
  {in => '@import url(a/b  );',
   out => [SS [1], IMPORT(0=>1, 'a/b', '')]},
  {in => '@impORt URL( h\) )   /**/ /**/ ;',
   out => [SS [1], IMPORT(0=>1, 'h)', '')]},
  {in => ' /**/ @import url();',
   out => [SS [1], IMPORT(0=>1, '', '')]},
  {in => 'p{}@import url();',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;4;m;at-rule not allowed;import;']},
  {in => '@media{@import url();}',
   out => [SS [1], MEDIA(0=>1=>[], '')],
   errors => ['1;8;m;at-rule not allowed;import;']},
  {in => q{@import 'a';@import url(b);},
   out => [SS [1, 2], IMPORT(0=>1, 'a', ''), IMPORT(0=>2, 'b', '')]},
  {in => q{@charset 'a';@import url(b);},
   out => [SS [1, 2], CHARSET(0=>1, 'a'), IMPORT(0=>2, 'b', '')]},
  {in => q{@import url(b);@charset 'a';},
   out => [SS [1], IMPORT(0=>1, 'b', '')],
   errors => ['1;16;m;at-rule not allowed;charset;']},
  {in => q{?{}@import url(b);},
   out => [SS [1], IMPORT(0=>1, 'b', '')],
   errors => ['1;1;m;no sss;;']},
  {in => q{@media;@import url(b);},
   out => [SS [1], IMPORT(0=>1, 'b', '')],
   errors => ['1;7;m;css:at-rule:block missing;;media']},
  {in => q{@import 'a';@media;@import url(b);},
   out => [SS [1, 2], IMPORT(0=>1, 'a', ''), IMPORT(0=>2, 'b', '')],
   errors => ['1;19;m;css:at-rule:block missing;;media']},
  {in => '@import "aa"',
   out => [SS [1], IMPORT(0=>1, 'aa', '')],
   errors => ['1;13;w;css:at-rule:eof;;']},
  {in => '@import ',
   out => [SS []],
   errors => ['1;9;w;css:at-rule:eof;;', '1;9;m;css:import:url missing;;']},
  {in => '@import {}',
   out => [SS []],
   errors => ['1;9;m;css:at-rule:block not allowed;;import']},
  {in => 'a{}@import {}',
   out => [SS [1], S(0=>1, 'a', [], {}, {})],
   errors => ['1;12;m;css:at-rule:block not allowed;;import']},
) {
  test {
    my $c = shift;

    my @error;

    my $p = Web::CSS::Parser->new;
    $p->onerror (sub {
      my %args = @_;
      push @error, join ';',
          $args{line} // $args{token}->{line},
          $args{column} // $args{token}->{column},
          $args{level},
          $args{type},
          $args{text} // '',
          $args{value} // '';
    });

    my $parsed = $p->parse_char_string_as_ss ($test->{in});
    eq_or_diff $parsed, {rules => $test->{out}, base_urlref => \'about:blank'};
    eq_or_diff \@error, $test->{errors} || [];
    
    done $c;
  } n => 2, name => ['parse', $test->{in}];
}

run_tests;

# XXX
__END__

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  $parser->parse_char_string ('');
  my $result = $parser->parsed_sheet_set;
  is scalar @{$result->{sheets}}, 1;
  eq_or_diff $result->{sheets}->[0]->{rules}, [];
  is ${$result->{sheets}->[0]->{base_urlref}}, 'about:blank';
  is scalar @{$result->{rules}}, 0;
  done $c;
} n => 4, name => 'parse_char_string empty string';

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  $parser->parse_char_string ('@charset "utf-8";');
  my $result = $parser->parsed_sheet_set;
  is scalar @{$result->{sheets}}, 1;
  eq_or_diff $result->{sheets}->[0]->{rules}, [0];
  is ${$result->{sheets}->[0]->{base_urlref}}, 'about:blank';
  is scalar @{$result->{rules}}, 1;
  is $result->{rules}->[0]->{type}, '@charset';
  is $result->{rules}->[0]->{encoding}, 'utf-8';
  done $c;
} n => 6, name => 'parse_char_string @charset';

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  $parser->media_resolver->{prop}->{color} = 1;
  $parser->media_resolver->{prop}->{'font-size'} = 1;
  $parser->parse_char_string ('p { color : blue; opacity: 0; font-size: small }');
  my $result = $parser->parsed_sheet_set;
  is scalar @{$result->{sheets}}, 1;
  eq_or_diff $result->{sheets}->[0]->{rules}, [0];
  is ${$result->{sheets}->[0]->{base_urlref}}, 'about:blank';
  is scalar @{$result->{rules}}, 1;
  is $result->{rules}->[0]->{type}, 'style';
  eq_or_diff $result->{rules}->[0]->{style},
      {props => {color => [[KEYWORD => 'blue'], ''],
                 font_size => [[KEYWORD => 'small'], '']},
       prop_names => ['color', 'font_size']};
  done $c;
} n => 6, name => 'parse_char_string style declarations';

test {
  my $c = shift;
  my $p = Web::CSS::Parser->new;
  $p->context->url ('hoge://fuga');
  my @url;
  $p->{onerror} = sub {
    my %args = @_;
    push @url, ${$args{uri}};
  };
  $p->parse_char_string ('& { } @hoge; @media abc { }');

  eq_or_diff \@url, ['hoge://fuga', 'hoge://fuga', 'hoge://fuga'];

  done $c;
} n => 1, name => 'context->url';

# XXX broken
for my $test (
  {input => '', result => {props => {}, prop_names => []}},
  {input => 'color:red',
   result => {props => {color => [['KEYWORD', 'red'], '']},
              prop_names => ['color']}},
  {input => 'color:red; font-size: 10px ! imporTant',
   result => {props => {color => [['KEYWORD', 'red'], ''],
                        font_size => [['DIMENSION', 10, 'px'], 'important']},
              prop_names => ['color', 'font_size']}},
) {
  test {
    my $c = shift;
    my $parser = Web::CSS::Parser->new;
    my @error;
    $parser->onerror (sub {
      my %args = @_;
      push @error, join ';',
          $args{token}->{line}, $args{token}->{column},
          $args{level},
          $args{type};
    });
    $parser->media_resolver->set_supported (all => 1);
    $parser->parse_char_string_as_style_decls ($test->{input});
    my $result = $parser->parsed_style_decls;
    eq_or_diff $result, $test->{result};
    eq_or_diff \@error, $test->{errors} || [];
    done $c;
  } n => 2, name => 'parse_char_string_as_style_decls';
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
