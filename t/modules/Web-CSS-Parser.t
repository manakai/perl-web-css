use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Web::CSS::Parser;
use Test::More;
use Test::Differences;
use Web::CSS::Selectors::Parser;
use Web::CSS::MediaQueries::Parser;
use Web::DOM::Document;

sub SS ($) { {id => 0, rule_type => 'sheet', rule_ids => $_[0]} }
sub S ($$$$$$) { {parent_id => $_[0], id => $_[1], rule_type => 'style',
                  selectors => do {
                    if (ref $_[2]) {
                      my $s = shift @{$_[2]};
                      my $p = Web::CSS::Selectors::Parser->new;
                      for (0..$#{$_[2]}) {
                        $p->context->{prefix_to_url}->{'N' . $_} = $_[2]->[$_];
                      }
                      $p->parse_char_string_as_selectors($s);
                    } else {
                      Web::CSS::Selectors::Parser->new->parse_char_string_as_selectors($_[2]);
                    }
                  },
                  prop_keys => $_[3], prop_values => $_[4],
                  prop_importants => $_[5]} }
sub MEDIA ($$$$) { {parent_id => $_[0], id => $_[1], rule_type => 'media',
                    rule_ids => $_[2],
                    mqs => Web::CSS::MediaQueries::Parser->new->parse_char_string_as_mq_list ($_[3])} }
sub CHARSET ($$$) { {parent_id => $_[0], id => $_[1], rule_type => 'charset',
                     encoding => $_[2]} }
sub IMPORT ($$$$) { {parent_id => $_[0], id => $_[1], rule_type => 'import',
                     href => $_[2],
                     mqs => Web::CSS::MediaQueries::Parser->new->parse_char_string_as_mq_list ($_[3])} }
sub NS ($$$$) { {parent_id => $_[0], id => $_[1], rule_type => 'namespace',
                 (defined $_[2] ? (prefix => $_[2]) : ()), nsurl => $_[3]} }
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
  {in => '@namespace aa "bb";',
   out => [SS [1], NS(0=>1, 'aa', 'bb')]},
  {in => '@namespace Aa "bBb";',
   out => [SS [1], NS(0=>1, 'Aa', 'bBb')]},
  {in => '@namespace aa url(bb) /**/ ;',
   out => [SS [1], NS(0=>1, 'aa', 'bb')]},
  {in => '@namespace /**/ aa /**/ "bb" /**/ ;',
   out => [SS [1], NS(0=>1, 'aa', 'bb')]},
  {in => '@namespace/**/aa"bb";',
   out => [SS [1], NS(0=>1, 'aa', 'bb')]},
  {in => '@namespace aa/**/url(bb);',
   out => [SS [1], NS(0=>1, 'aa', 'bb')]},
  {in => '@namespace "bb";',
   out => [SS [1], NS(0=>1, undef, 'bb')]},
  {in => '@namespace url(bb);',
   out => [SS [1], NS(0=>1, undef, 'bb')]},
  {in => '@namespacE/**/url(bb);',
   out => [SS [1], NS(0=>1, undef, 'bb')]},
  {in => '@namespace url(bb)',
   out => [SS [1], NS(0=>1, undef, 'bb')],
   errors => ['1;19;w;css:at-rule:eof;;']},
  {in => '@namespace"bb"',
   out => [SS [1], NS(0=>1, undef, 'bb')],
   errors => ['1;15;w;css:at-rule:eof;;']},
  {in => '@namespace',
   out => [SS []],
   errors => ['1;11;w;css:at-rule:eof;;',
              '1;11;m;css:namespace:url missing;;']},
  {in => '@namespace 12px',
   out => [SS []],
   errors => ['1;16;w;css:at-rule:eof;;',
              '1;12;m;css:namespace:url missing;;']},
  {in => '@namespace 12 "px";',
   out => [SS []],
   errors => ['1;12;m;css:namespace:url missing;;']},
  {in => '@namespace 12 "px";p{}',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;12;m;css:namespace:url missing;;']},
  {in => '@namespace url(bb); @namespace "cc";',
   out => [SS [1, 2], NS(0=>1, undef, 'bb'), NS(0=>2, undef, 'cc')],
   errors => ['1;32;m;duplicate @namespace;;']},
  {in => '@charset "a"; @import "ad";@namespace url(bb); @namespace "cc";',
   out => [SS [1, 2, 3, 4], CHARSET(0=>1, 'a'), IMPORT(0=>2, 'ad', ''), NS(0=>3, undef, 'bb'), NS(0=>4, undef, 'cc')],
   errors => ['1;59;m;duplicate @namespace;;']},
  {in => '@namespace url(bb); @charset "a"; @import "ad";@namespace "cc";',
   out => [SS [1, 2], NS(0=>1, undef, 'bb'), NS(0=>2, undef, 'cc')],
   errors => ['1;21;m;at-rule not allowed;charset;',
              '1;35;m;at-rule not allowed;import;',
              '1;59;m;duplicate @namespace;;']},
  {in => '@namespace url(bb); @charset "a"; @media{}@namespace "cc";',
   out => [SS [1, 2], NS(0=>1, undef, 'bb'), MEDIA(0=>2=>[], '')],
   errors => ['1;21;m;at-rule not allowed;charset;',
              '1;43;m;at-rule not allowed;namespace;']},
  {in => '@namespace url(bb); @charset "a"; @media{ @namespace "cc"; }',
   out => [SS [1, 2], NS(0=>1, undef, 'bb'), MEDIA(0=>2=>[], '')],
   errors => ['1;21;m;at-rule not allowed;charset;',
              '1;43;m;at-rule not allowed;namespace;']},
  {in => '@namespace aa "bb" a;',
   out => [SS []],
   errors => ['1;20;m;css:namespace:broken;;']},
  {in => '@namespace    "bb" a;',
   out => [SS []],
   errors => ['1;20;m;css:namespace:broken;;']},
  {in => '@namespace aa "bb" a;@charset"a";@import"b";@namespace"c";',
   out => [SS [1, 2], IMPORT(0=>1, 'b', ''), NS(0=>2, undef, 'c')],
   errors => ['1;20;m;css:namespace:broken;;',
              '1;22;m;at-rule not allowed;charset;']},
  {in => '@namespace aa "bb";@namespace AA "bb";',
   out => [SS [1, 2], NS(0=>1, 'aa', 'bb'), NS(0=>2, 'AA', 'bb')]},
  {in => '@namespace aa "bb";@namespace aa "bb";',
   out => [SS [1, 2], NS(0=>1, 'aa', 'bb'), NS(0=>2, 'aa', 'bb')],
   errors => ['1;31;m;duplicate @namespace;;aa']},
  {in => '@namespace \30 "bb";@namespace \30 "bb";',
   out => [SS [1, 2], NS(0=>1, '0', 'bb'), NS(0=>2, '0', 'bb')],
   errors => ['1;32;m;duplicate @namespace;;0']},
  {in => '@namespace aa "bb";@namespace aa "";',
   out => [SS [1, 2], NS(0=>1, 'aa', 'bb'), NS(0=>2, 'aa', '')],
   errors => ['1;31;m;duplicate @namespace;;aa']},
  {in => '@namespace aa "bb";@namespace AA "bc";aa|p{}',
   out => [SS [1, 2, 3], NS(0=>1, 'aa', 'bb'), NS(0=>2, 'AA', 'bc'), S(0=>3, ['N0|p', 'bb'], [], {}, {})]},
  {in => '@namespace aa "bb";@namespace AA "bc";AA|p{}',
   out => [SS [1, 2, 3], NS(0=>1, 'aa', 'bb'), NS(0=>2, 'AA', 'bc'), S(0=>3, ['N0|p', 'bc'], [], {}, {})]},
  {in => '@namespace aa "bb";@namespace aa "bc";aa|p{}',
   out => [SS [1, 2, 3], NS(0=>1, 'aa', 'bb'), NS(0=>2, 'aa', 'bc'), S(0=>3, ['N0|p', 'bc'], [], {}, {})],
   errors => ['1;31;m;duplicate @namespace;;aa']},
  {in => '@namespace "bb";@namespace "bc";p{}',
   out => [SS [1, 2, 3], NS(0=>1, undef, 'bb'), NS(0=>2, undef, 'bc'), S(0=>3, ['N0|p', 'bc'], [], {}, {})],
   errors => ['1;28;m;duplicate @namespace;;']},
  {in => '@namespace "bb";@namespace "";p{}',
   out => [SS [1, 2, 3], NS(0=>1, undef, 'bb'), NS(0=>2, undef, ''), S(0=>3, ['N0|p', ''], [], {}, {})],
   errors => ['1;28;m;duplicate @namespace;;']},
  {in => '@namespace a "bb";@namespace a"";a|p{}',
   out => [SS [1, 2, 3], NS(0=>1, 'a', 'bb'), NS(0=>2, 'a', ''), S(0=>3, ['N0|p', ''], [], {}, {})],
   errors => ['1;30;m;duplicate @namespace;;a']},
  {in => '@namespace a "bb";@namespace a"";a|p b{}',
   out => [SS [1, 2, 3], NS(0=>1, 'a', 'bb'), NS(0=>2, 'a', ''), S(0=>3, ['N0|p *|b', ''], [], {}, {})],
   errors => ['1;30;m;duplicate @namespace;;a']},
  {in => '@namespace "";@namespace a"";a|p b{}',
   out => [SS [1, 2, 3], NS(0=>1, undef, ''), NS(0=>2, 'a', ''), S(0=>3, ['|p |b'], [], {}, {})]},
  {in => '@namespace a "bb" {} p{};',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;19;m;css:at-rule:block not allowed;;namespace',
              '1;26;m;css:qrule:no block;;']},
  {in => 'p{displaY2:}',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;3;m;css:prop:unknown;;displaY2']},
  {in => 'p{displaY2:!important}',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;3;m;css:prop:unknown;;displaY2']},
  {in => 'p{displaY2: /**/ !hoge}',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;3;m;css:prop:unknown;;displaY2']},
  {in => 'p{displaY2: /**/ ! important /**/ }',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;3;m;css:prop:unknown;;displaY2']},
  {in => 'p{displaY2:!hoge}',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;3;m;css:prop:unknown;;displaY2']},
  {in => 'p{displaY2:bloCk}',
   out => [SS [1], S(0=>1, 'p', [], {}, {})],
   errors => ['1;3;m;css:prop:unknown;;displaY2']},
  {in => 'p{displaY:block;display:inline}',
   out => [SS [1], S(0=>1, 'p', ['display'], {display => K 'inline'}, {})]},
  {in => 'p{displaY:block;display:inline!important}',
   out => [SS [1], S(0=>1, 'p', ['display'], {display => K 'inline'},
                     {display => 1})]},
  {in => 'p{displaY:block !important;display:inline}',
   out => [SS [1], S(0=>1, 'p', ['display'], {display => K 'block'},
                     {display => 1})],
   errors => ['1;28;w;css:prop:ignored;;display']},
  {in => 'p{displaY:block !important;display:inline !important}',
   out => [SS [1], S(0=>1, 'p', ['display'], {display => K 'inline'},
                     {display => 1})]},
  {in => 'p{displaY:block !important;display:inherit !important}',
   out => [SS [1], S(0=>1, 'p', ['display'], {display => K 'inherit'},
                     {display => 1})]},
  {in => 'p{displaY:block !important;display:inherit}',
   out => [SS [1], S(0=>1, 'p', ['display'], {display => K 'block'},
                     {display => 1})],
   errors => ['1;28;w;css:prop:ignored;;display']},
  {in => 'p{background-position:top}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_x', 'background_position_y'],
                     {background_position_x => K 'center',
                      background_position_y => K 'top'}, {})]},
  {in => 'p{background-position:top !important}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_x', 'background_position_y'],
                     {background_position_x => K 'center',
                      background_position_y => K 'top'},
                     {background_position_x => 1,
                      background_position_y => 1})]},
  {in => 'p{background-position:top !important;background-position:1px 2px}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_x', 'background_position_y'],
                     {background_position_x => K 'center',
                      background_position_y => K 'top'},
                     {background_position_x => 1,
                      background_position_y => 1})],
   errors => ['1;38;w;css:prop:ignored;;background-position-x',
              '1;38;w;css:prop:ignored;;background-position-y']},
  {in => 'p{background-position:top;background-position:1px 2px}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_x', 'background_position_y'],
                     {background_position_x => ['DIMENSION', '1', 'px'],
                      background_position_y => ['DIMENSION', '2', 'px']},
                     {})]},
  {in => 'p{background-position:top!IMportant;background-position:1px 2px!important}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_x', 'background_position_y'],
                     {background_position_x => ['DIMENSION', '1', 'px'],
                      background_position_y => ['DIMENSION', '2', 'px']},
                     {background_position_x => 1,
                      background_position_y => 1})]},
  {in => 'p{background-position:top!IMportant;background-position:inherit!important}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_x', 'background_position_y'],
                     {background_position_x => ['KEYWORD', 'inherit'],
                      background_position_y => ['KEYWORD', 'inherit']},
                     {background_position_x => 1,
                      background_position_y => 1})]},
  {in => 'p{background-position:inherit!important;background-position-x:12px}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_x', 'background_position_y'],
                     {background_position_x => ['KEYWORD', 'inherit'],
                      background_position_y => ['KEYWORD', 'inherit']},
                     {background_position_x => 1,
                      background_position_y => 1})],
   errors => ['1;41;w;css:prop:ignored;;background-position-x']},
  {in => 'p{background-position:inherit;background-position-x:12px}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_y', 'background_position_x'],
                     {background_position_x => ['DIMENSION', '12', 'px'],
                      background_position_y => ['KEYWORD', 'inherit']},
                     {})]},
  {in => 'p{background-position-x:12px!important;background-position:inherit;}',
   out => [SS [1], S(0=>1, 'p',
                     ['background_position_x', 'background_position_y'],
                     {background_position_x => ['DIMENSION', '12', 'px'],
                      background_position_y => ['KEYWORD', 'inherit']},
                     {background_position_x => 1})],
   errors => ['1;40;w;css:prop:ignored;;background-position-x']},
) {
  test {
    my $c = shift;

    my @error;

    my $p = Web::CSS::Parser->new;
    $p->media_resolver->set_supported (all => 1);
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
  } n => 2, name => ['parse_char_string_as_ss', $test->{in}];
}

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  my $parsed = $parser->parse_char_string_as_ss ('p{display:block}');
  eq_or_diff $parsed, {rules => [SS [1], S(0=>1, 'p', [], {}, {})],
                       base_urlref => \'about:blank'};
  done $c;
} n => 1, name => 'parse_char_string_as_ss not supported';

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  $parser->media_resolver->{prop}->{display} = 1;
  my $parsed = $parser->parse_char_string_as_ss ('p{display:block}');
  eq_or_diff $parsed, {rules => [SS [1], S(0=>1, 'p', [], {}, {})],
                       base_urlref => \'about:blank'};
  done $c;
} n => 1, name => 'parse_char_string_as_ss value not supported';

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  $parser->media_resolver->{prop}->{display} = 1;
  $parser->media_resolver->{prop_value}->{display}->{block} = 1;
  my $parsed = $parser->parse_char_string_as_ss ('p{display:block}');
  eq_or_diff $parsed, {rules => [SS [1], S(0=>1, 'p', ['display'],
                                           {display => K 'block'}, {})],
                       base_urlref => \'about:blank'};
  done $c;
} n => 1, name => 'parse_char_string_as_ss value supported';

for my $test (
  {in => '', out => [SS []],
   errors => ['1;1;m;css:rule:not found;;']},
  {in => 'p{}', out => [SS [1], S(0=>1, 'p', [], {}, {})]},
  {in => 'p{display:block}',
   out => [SS [1], S(0=>1, 'p', ['display'], {display => K 'block'}, {})]},
  {in => 'p{}q', out => [SS []],
   errors => ['1;4;m;css:rule:multiple;;',
              '1;5;m;css:qrule:no block;;']},
  {in => 'q', out => [SS []],
   errors => ['1;2;m;css:qrule:no block;;',
              '1;2;m;css:rule:not found;;']},
  {in => 'p{}q{}', out => [SS []],
   errors => ['1;4;m;css:rule:multiple;;']},
  {in => '@media{p{display:block}q{}}',
   out => [SS [1], MEDIA(0=>1=>[2,3], ''),
           S(1=>2, 'p', ['display'], {display => K 'block'}, {}),
           S(1=>3, 'q', [], {}, {})]},
  {in => '@media{p{display:block}q{}}@media{}',
   out => [SS []], errors => ['1;28;m;css:rule:multiple;;']},
  {in => '@media2{p{display:block}q{}}',
   out => [SS []], errors => ['1;1;m;unknown at-rule;;media2']},
  {in => '<!--p{display:block}',
   out => [SS []], errors => ['1;1;m;no sss;;']},
  {in => 'p{display:block}-->',
   out => [SS []], errors => ['1;17;m;css:rule:multiple;;',
                              '1;20;m;css:qrule:no block;;']},
) {
  test {
    my $c = shift;

    my @error;

    my $p = Web::CSS::Parser->new;
    $p->media_resolver->set_supported (all => 1);
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

    my $parsed = $p->parse_char_string_as_rule ($test->{in});
    eq_or_diff $parsed, {rules => $test->{out}};
    eq_or_diff \@error, $test->{errors} || [];
    
    done $c;
  } n => 2, name => ['parse_char_string_as_rule', $test->{in}];
}

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  my $parsed = $parser->parse_char_string_as_rule ('p{display:block}');
  eq_or_diff $parsed, {rules => [SS [1], S(0=>1, 'p', [], {}, {})]};
  done $c;
} n => 1, name => 'parse_char_string_as_rule not supported';

for my $test (
  {in => '', out => {prop_keys => [], prop_values => {},
                     prop_importants => {}}},
  {in => ';', out => {prop_keys => [], prop_values => {},
                      prop_importants => {}}},
  {in => 'display:block',
   out => {prop_keys => ['display'],
           prop_values => {display => K 'block'},
           prop_importants => {}}},
  {in => 'display:block ! important',
   out => {prop_keys => ['display'],
           prop_values => {display => K 'block'},
           prop_importants => {display => 1}}},
  {in => 'background-POSITIon:inherit',
   out => {prop_keys => ['background_position_x', 'background_position_y'],
           prop_values => {background_position_x => K 'inherit',
                           background_position_y => K 'inherit'},
           prop_importants => {}}},
  {in => 'background-POSITIon:left;background-position-x:12px',
   out => {prop_keys => ['background_position_y', 'background_position_x'],
           prop_values => {background_position_x => ['DIMENSION', '12', 'px'],
                           background_position_y => K 'center'},
           prop_importants => {}}},
  {in => 'display:block}',
   out => {prop_keys => [], prop_values => {},
           prop_importants => {}},
   errors => ['1;9;m;css:value:not keyword;;']},
  {in => 'display{}:block',
   out => {prop_keys => [], prop_values => {},
           prop_importants => {}}, errors => ['1;8;m;css:decl:no colon;;']},
  {in => '@phpge {} display:block',
   out => {prop_keys => ['display'],
           prop_values => {display => K 'block'},
           prop_importants => {}}, errors => ['1;1;m;unknown at-rule;;phpge']},
) {
  test {
    my $c = shift;
    my $parser = Web::CSS::Parser->new;
    $parser->media_resolver->set_supported (all => 1);
    my @error;
    $parser->onerror (sub {
      my %args = @_;
      push @error, join ';',
          $args{line} // $args{token}->{line},
          $args{column} // $args{token}->{column},
          $args{level},
          $args{type},
          $args{text} // '',
          $args{value} // '';
    });
    
    my $parsed = $parser->parse_char_string_as_prop_decls ($test->{in});
    eq_or_diff $parsed, $test->{out};
    eq_or_diff \@error, $test->{errors} || [];

    done $c;
  } n => 2, name => ['parse_char_string_as_prop_decls', $test->{in}];
}

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  my $parsed = $parser->parse_char_string_as_prop_decls ('display:block');
  eq_or_diff $parsed, {prop_keys => [], prop_values => {},
                       prop_importants => {}};
  done $c;
} n => 1, name => 'parse_char_string_as_prop_decls not supported';

for my $test (
  {prop => 'Display', in => 'BlocK',
   out => {prop_keys => ['display'], prop_values => {display => K 'block'}}},
  {prop => 'Display', in => ' /**/ BlocK /**/ ',
   out => {prop_keys => ['display'], prop_values => {display => K 'block'}}},
  {prop => 'Display', in => 'BlocK?',
   out => {prop_keys => [], prop_values => {}},
   errors => ['1;1;m;css:value:not keyword;;']},
  {prop => 'Display', in => 'BlocK !important',
   out => {prop_keys => [], prop_values => {}},
   errors => ['1;1;m;css:value:not keyword;;']},
  {prop => 'xDisplay', in => 'Block',
   out => undef, errors => []},
  {prop => 'background-position', in => 'left',
   out => {prop_keys => ['background_position_x', 'background_position_y'],
           prop_values => {background_position_x => K 'left',
                           background_position_y => K 'center'}}},
  {prop => 'background-position', in => 'inherit ',
   out => {prop_keys => ['background_position_x', 'background_position_y'],
           prop_values => {background_position_x => K 'inherit',
                           background_position_y => K 'inherit'}}},
  {prop => 'display', in => ' unSet ',
   out => {prop_keys => ['display'],
           prop_values => {display => K 'unset'}}},
) {
  test {
    my $c = shift;
    my $parser = Web::CSS::Parser->new;
    $parser->media_resolver->set_supported (all => 1);
    my @error;
    $parser->onerror (sub {
      my %args = @_;
      push @error, join ';',
          $args{line} // $args{token}->{line},
          $args{column} // $args{token}->{column},
          $args{level},
          $args{type},
          $args{text} // '',
          $args{value} // '';
    });
    
    my $parsed = $parser->parse_char_string_as_prop_value
        ($test->{prop}, $test->{in});
    eq_or_diff $parsed, $test->{out};
    eq_or_diff \@error, $test->{errors} || [];

    done $c;
  } n => 2, name => ['parse_char_string_as_prop_value', $test->{prop}, $test->{in}];
}

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  my $parsed = $parser->parse_char_string_as_prop_value ('display', 'block');
  is $parsed, undef;
  done $c;
} n => 1, name => 'parse_char_string_as_prop_value not supported';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('style');

  my $parser = Web::CSS::Parser->new;
  $parser->parse_style_element ($el);

  my $sheet = $el->sheet;
  isa_ok $sheet, 'Web::DOM::CSSStyleSheet';
  
  my $owner = $sheet->owner_node;
  is $owner, $el;

  is $el->sheet, $sheet;

  isa_ok $sheet->owner_node, 'Web::DOM::Element';
  is $sheet->owner_node->sheet, $sheet;

  done $c;
} n => 5, name => 'parse_style_element - empty';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;

  is +Web::CSS::Parser->get_parser_of_document ($doc), $$doc->[0]->css_parser;
  isa_ok +Web::CSS::Parser->get_parser_of_document ($doc), 'Web::CSS::Parser';
  
  done $c;
} n => 2, name => 'get_parser_of_document doc';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->append_child ($doc->create_element ('a'));

  is +Web::CSS::Parser->get_parser_of_document ($doc->first_child), $$doc->[0]->css_parser;
  isa_ok +Web::CSS::Parser->get_parser_of_document ($doc->first_child), 'Web::CSS::Parser';
  
  done $c;
} n => 2, name => 'get_parser_of_document non-doc node';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('style');

  my $parser = Web::CSS::Parser->new;
  $parser->parse_style_element ($el);

  my $sheet = $el->sheet;

  is +Web::CSS::Parser->get_parser_of_document ($sheet), $$doc->[0]->css_parser;
  isa_ok +Web::CSS::Parser->get_parser_of_document ($sheet), 'Web::CSS::Parser';
  
  done $c;
} n => 2, name => 'get_parser_of_document sheet';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('style');
  $el->inner_html ('p{}');

  my $parser = Web::CSS::Parser->new;
  $parser->parse_style_element ($el);

  my $sheet = $el->sheet;
  my $rule = $sheet->css_rules->[0];

  is +Web::CSS::Parser->get_parser_of_document ($rule), $$doc->[0]->css_parser;
  isa_ok +Web::CSS::Parser->get_parser_of_document ($rule), 'Web::CSS::Parser';
  
  done $c;
} n => 2, name => 'get_parser_of_document rule';

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

## TODO: Test <style>'s base URI change and url()

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
