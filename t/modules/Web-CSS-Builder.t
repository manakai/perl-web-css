use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;

{
  package CSSBuilder;
  use Web::CSS::Builder;
  push our @ISA, qw(Web::CSS::Builder);
}

sub S ($$) { {line => $_[0], column => $_[1], type => 33} }
sub CDO ($$) { {line => $_[0], column => $_[1], type => 34} }
sub CDC ($$) { {line => $_[0], column => $_[1], type => 35} }
sub Colon ($$) { {line => $_[0], column => $_[1], type => 43} }
sub Semi ($$) { {line => $_[0], column => $_[1], type => 26} }
sub RBrace ($$) { {line => $_[0], column => $_[1], type => 28} }
sub RParen ($$) { {line => $_[0], column => $_[1], type => 30} }
sub ID ($$$) { {line => $_[0], column => $_[1], type => 1, value => $_[2]} }
sub Str ($$$) { {line => $_[0], column => $_[1], type => 9, value => $_[2]} }
sub URL ($$$) { {line => $_[0], column => $_[1], type => 5, value => $_[2]} }
sub N ($$$) { {line => $_[0], column => $_[1], type => 11,
               number => ''.$_[2], value => ''} }
sub Pct ($$$) { {line => $_[0], column => $_[1], type => 13,
                 number => ''.$_[2], value => ''} }
sub Rules ($$;@) { my $t = {line => shift, column => shift,
                            single => '',
                            type => 10000 + 1, value => [@_]};
                   for (@{$t->{value}}) {
                     delete $_->{delim_type} if $_->{type} == 10000 + 2;
                   }
                   $t }
sub Q ($$;@) { {line => shift, column => shift,
                type => 10000 + 3,
                value => [@_],
                parent_at => '',
                delim_type => 27} }
sub Block ($$;@) { {line => $_[0], column => $_[1],
                    type => 10000 + 4,
                    name => {line => shift, column => shift, type => 27},
                    value => [@_],
                    end_type => 28} }
sub Box ($$;@) { {line => $_[0], column => $_[1],
                  type => 10000 + 4,
                  name => {line => shift, column => shift, type => 31},
                  value => [@_],
                  end_type => 32} }
sub Paren ($$;@) { {line => $_[0], column => $_[1],
                    type => 10000 + 4,
                    name => {line => shift, column => shift, type => 29},
                    value => [@_],
                    end_type => 30} }
sub F ($$$;@) { {line => $_[0], column => $_[1],
                 type => 10000 + 4,
                 name => {line => shift, column => shift, type => 4,
                          value => shift},
                 value => [@_],
                 end_type => 30} }
sub At ($$$;@) { my $t = {line => $_[0], column => $_[1], type => 10000 + 2,
                          name => {line => shift, column => shift, type => 2,
                                   value => shift},
                          delim_type => 28,
                          value => [@_]};
                 if (@{$t->{value}} and
                     $t->{value}->[-1]->{type} == 10000 + 4 and
                     $t->{value}->[-1]->{name}->{type} == 27) {
                   $t->{value}->[-1]->{at} = lc $t->{name}->{value};
                   for (@{$t->{value}->[-1]->{value}}) {
                     next unless $_->{type} == 10000 + 3;
                     $_->{parent_at} = lc $t->{name}->{value};
                   }
                 }
                 $t }
sub AtToken ($$$) { {line => $_[0], column => $_[1], type => 2,
                     value => $_[2]} }
sub D ($$$;@) { {line => $_[0], column => $_[1], type => 10000 + 5,
                 name => {line => shift, column => shift, type => 1,
                          value => shift},
                 delim_type => 26, end_type => 28,
                 value => [@_]} }

for my $test (
  ['stylesheet', [''], Rules(1,0)],
  ['stylesheet', ['   '], Rules(1,0)],
  ['stylesheet', ['aa'], Rules(1,0), ['1;3;css:qrule:no block']],
  ['stylesheet', ['hoge   {}'], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  ['stylesheet', ['hoge   {} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  ['stylesheet', ['ho', 'ge   ', '{} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  ['stylesheet', ['ho', '', 'ge   {} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  ['stylesheet', ['hoge', '   {} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  ['stylesheet', ['ho', '', 'ge   ', '', '{} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  ['stylesheet', ['hoge   {} a'], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8))), ['1;12;css:qrule:no block']],
  ['stylesheet', ['<!--'], Rules(1,0)],
  ['stylesheet', ['<!--p{}'], Rules(1,0,Q(1,5,ID(1,5,'p'),Block(1,6)))],
  ['stylesheet', [' -->p{}'], Rules(1,0,Q(1,5,ID(1,5,'p'),Block(1,6)))],
  ['stylesheet', ['q<!--p{}'], Rules(1,0,Q(1,1,ID(1,1,'q'),CDO(1,2),ID(1,6,'p'),Block(1,7)))],
  ['stylesheet', ['aa-->'], Rules(1,0), ['1;6;css:qrule:no block']],
  ['stylesheet', ['{}-->'], Rules(1,0,Q(1,1,Block(1,1)))],
  ['stylesheet', ['{}-->{}'], Rules(1,0,Q(1,1,Block(1,1)),Q(1,6,Block(1,6)))],
  ['stylesheet', ['}ab{}'], Rules(1,0,Q(1,1,RBrace(1,1),ID(1,2,'ab'),Block(1,4)))],
  ['stylesheet', ['@hoge'], Rules(1,0,At(1,1,'hoge')), ['1;6;css:at-rule:eof']],
  ['stylesheet', ['@hoge;'], Rules(1,0,At(1,1,'hoge'))],
  ['stylesheet', ['@hoge/**/foo 12;'], Rules(1,0,At(1,1,'hoge',ID(1,10,'foo'),S(1,13),N(1,14,12)))],
  ['stylesheet', ['@hoge[foo]12;'], Rules(1,0,At(1,1,'hoge',Box(1,6,ID(1,7,'foo')),N(1,11,12)))],
  ['stylesheet', ['@hoge[foo;1]12;'], Rules(1,0,At(1,1,'hoge',Box(1,6,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  ['stylesheet', ['@hoge[foo;1]12;<!--'], Rules(1,0,At(1,1,'hoge',Box(1,6,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  ['stylesheet', ['@hoge(foo;1)12;<!--'], Rules(1,0,At(1,1,'hoge',Paren(1,6,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  ['stylesheet', ['@hoge aa(foo;1)12;<!--'], Rules(1,0,At(1,1,'hoge',S(1,6),F(1,7,'aa',ID(1,10,'foo'),Semi(1,13),N(1,14,1)),N(1,16,12)))],
  ['stylesheet', ['@hoge{foo}12;'], Rules(1,0,At(1,1,'hoge',Block(1,6,ID(1,7,'foo')))), ['1;14;css:qrule:no block']],
  ['stylesheet', ['@hoge{foo{}}12;'], Rules(1,0,At(1,1,'hoge',Block(1,6,ID(1,7,'foo'),Block(1,10)))), ['1;16;css:qrule:no block']],
  ['stylesheet', ['@', '', 'hoge{', '', 'foo{', '', '}}12', '', ';'], Rules(1,0,At(1,1,'hoge',Block(1,6,ID(1,7,'foo'),Block(1,10)))), ['1;16;css:qrule:no block']],
  ['stylesheet', ['@aaa[12'], Rules(1,0,At(1,1,'aaa',Box(1,5,N(1,6,12)))), ['1;8;css:block:eof']],
  ['stylesheet', ['@aaa(12'], Rules(1,0,At(1,1,'aaa',Paren(1,5,N(1,6,12)))), ['1;8;css:block:eof']],
  ['stylesheet', ['@aaa{12'], Rules(1,0,At(1,1,'aaa',Block(1,5,N(1,6,12)))), ['1;8;css:block:eof']],
  ['stylesheet', ['@aa h(12'], Rules(1,0,At(1,1,'aa',S(1,4),F(1,5,'h',N(1,7,12)))), ['1;9;css:block:eof']],
  ['stylesheet', ['@aa{h(12'], Rules(1,0,At(1,1,'aa',Block(1,4,F(1,5,'h',N(1,7,12))))), ['1;9;css:block:eof']],
  ['stylesheet', ['@aa{h("12'], Rules(1,0,At(1,1,'aa',Block(1,4,F(1,5,'h',Str(1,7,'12'))))), ['1;10;css:string:eof']],
  ['stylesheet', ['@aa{url(12'], Rules(1,0,At(1,1,'aa',Block(1,4,URL(1,5,'12')))), ['1;11;css:url:eof']],
  ['stylesheet', ['ab{'], Rules(1,0,Q(1,1,ID(1,1,'ab'),Block(1,3))), ['1;4;css:block:eof']],
  ['stylesheet', ['hoge (ab { ) cd }) 2 {}'], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Paren(1,6,ID(1,7,'ab'),S(1,9),Block(1,10,S(1,11),RParen(1,12),S(1,13),ID(1,14,'cd'),S(1,16))),S(1,19),N(1,20,2),S(1,21),Block(1,22)))],
  ['stylesheet', [':hoge(ab { ) cd }) 2 {}'], Rules(1,0,Q(1,1,Colon(1,1),F(1,2,'hoge',ID(1,7,'ab'),S(1,9),Block(1,10,S(1,11),RParen(1,12),S(1,13),ID(1,14,'cd'),S(1,16))),S(1,19),N(1,20,2),S(1,21),Block(1,22)))],
  ['stylesheet', ['@ab{co{}}'], Rules(1,0,At(1,1,'ab',Block(1,4,ID(1,5,'co'),Block(1,7))))],
  ['stylesheet', ['@media{co{}}'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'co'),Block(1,10)))))],
  ['stylesheet', ['@media{co{}'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'co'),Block(1,10))))), '1;12;css:block:eof'],
  ['stylesheet', ['@MedIA{co{}}'], Rules(1,0,At(1,1,'MedIA',Block(1,7,Q(1,8,ID(1,8,'co'),Block(1,10)))))],
  ['stylesheet', ['@MedIA{@media{co{'], Rules(1,0,At(1,1,'MedIA',Block(1,7,At(1,8,'media',Block(1,14,Q(1,15,ID(1,15,'co'),Block(1,17))))))), ['1;18;css:block:eof']],
  ['stylesheet', ['@MedIA{@media{co{}}'], Rules(1,0,At(1,1,'MedIA',Block(1,7,At(1,8,'media',Block(1,14,Q(1,15,ID(1,15,'co'),Block(1,17))))))), ['1;20;css:block:eof']],
  ['stylesheet', ['@MedIA{@media{co{}}}'], Rules(1,0,At(1,1,'MedIA',Block(1,7,At(1,8,'media',Block(1,14,Q(1,15,ID(1,15,'co'),Block(1,17)))))))],
  ['stylesheet', ['@MedIA{@-moz-Document{co{}}}'], Rules(1,0,At(1,1,'MedIA',Block(1,7,At(1,8,'-moz-Document',Block(1,22,Q(1,23,ID(1,23,'co'),Block(1,25)))))))],
  ['stylesheet', ['@keyframes{@media{co{}}}'], Rules(1,0,At(1,1,'keyframes',Block(1,11,At(1,12,'media',Block(1,18,Q(1,19,ID(1,19,'co'),Block(1,21)))))))],
  ['stylesheet', ['@media{hoge{'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'hoge'),Block(1,12))))), ['1;13;css:block:eof']],
  ['stylesheet', ['@media{hoge{abc'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'hoge'),Block(1,12))))), ['1;16;css:decl:no colon', '1;16;css:block:eof']],
  ['stylesheet', ['@-moz-Document{hoge{abc'], Rules(1,0,At(1,1,'-moz-Document',Block(1,15,Q(1,16,ID(1,16,'hoge'),Block(1,20))))), ['1;24;css:decl:no colon', '1;24;css:block:eof']],
  ['stylesheet', ['@-moz-Document{@media{hoge{abc'], Rules(1,0,At(1,1,'-moz-Document',Block(1,15,At(1,16,'media',Block(1,22,Q(1,23,ID(1,23,'hoge'),Block(1,27))))))), ['1;31;css:decl:no colon', '1;31;css:block:eof']],
  ['stylesheet', ['@KeyFrames{40%{color:red}}'], Rules(1,0,At(1,1,'KeyFrames',Block(1,11,Q(1,12,Pct(1,12,40),Block(1,15,D(1,16,'color',ID(1,22,'red')))))))],
  ['stylesheet', ['@KeyFrames{40%{color:red'], Rules(1,0,At(1,1,'KeyFrames',Block(1,11,Q(1,12,Pct(1,12,40),Block(1,15,D(1,16,'color',ID(1,22,'red'))))))), ['1;25;css:block:eof']],
  ['stylesheet', ['@page{hoge:12}'], Rules(1,0,At(1,1,'page',Block(1,6,D(1,7,'hoge',N(1,12,12)))))],
  ['stylesheet', ['@page{hoge:12'], Rules(1,0,At(1,1,'page',Block(1,6,D(1,7,'hoge',N(1,12,12))))), ['1;14;css:block:eof']],
  ['stylesheet', ['@font-FACe{hoge:12}'], Rules(1,0,At(1,1,'font-FACe',Block(1,11,D(1,12,'hoge',N(1,17,12)))))],
  ['stylesheet', ['@global{hoge:12}'], Rules(1,0,At(1,1,'global',Block(1,8,D(1,9,'hoge',N(1,14,12)))))],
  ['stylesheet', ['@media{@global{hoge:12}}'], Rules(1,0,At(1,1,'media',Block(1,7,At(1,8,'global',Block(1,15,D(1,16,'hoge',N(1,21,12)))))))],
  ['stylesheet', ['p{}q{}@media{}'], Rules(1,0,Q(1,1,ID(1,1,'p'),Block(1,2)),Q(1,4,ID(1,4,'q'),Block(1,5)),At(1,7,'media',Block(1,13)))],
  ['stylesheet', ['@media{<!--q{}}'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,CDO(1,8),ID(1,12,'q'),Block(1,13)))))],
  ['stylesheet', ['@media{--> q{}}'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,CDC(1,8),S(1,11),ID(1,12,'q'),Block(1,13)))))],
  ['stylesheet', ['@media{--> q{}s{}}'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,CDC(1,8),S(1,11),ID(1,12,'q'),Block(1,13)),Q(1,15,ID(1,15,'s'),Block(1,16)))))],
  ['stylesheet', ['a{color}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2))), ['1;8;css:decl:no colon']],
  ['stylesheet', ['a{color;}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2))), ['1;8;css:decl:no colon']],
  ['stylesheet', ['a{color; ;a-z:}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,11,'a-z')))), ['1;8;css:decl:no colon']],
  ['stylesheet', ['a{color; ;a-z::}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,11,'a-z',Colon(1,15))))), ['1;8;css:decl:no colon']],
  ['stylesheet', ['a{Color:0.1}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color',N(1,9,0.1)))))],
  ['stylesheet', ['a{Color:0.1'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color',N(1,9,0.1))))), ['1;12;css:block:eof']],
  ['stylesheet', ['a{Color:"ab'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color',Str(1,9,'ab'))))), ['1;12;css:string:eof']],
  ['stylesheet', ['a{Color:'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color')))), ['1;9;css:block:eof']],
  ['stylesheet', ['a{Color'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2))), ['1;8;css:decl:no colon', '1;8;css:block:eof']],
  ['stylesheet', ['a{Color  '], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2))), ['1;10;css:decl:no colon', '1;10;css:block:eof']],
  ['stylesheet', ['a{Color  :'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color')))), ['1;11;css:block:eof']],
  ['stylesheet', ['a{Color:  '], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color',S(1,9))))), ['1;11;css:block:eof']],
  ['stylesheet', ['a{Color red:'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2))), ['1;9;css:decl:no colon', '1;13;css:block:eof']],
  ['stylesheet', ['a{Color red:;a:2'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'a',N(1,16,2))))), ['1;9;css:decl:no colon', '1;17;css:block:eof']],
  ['stylesheet', ['a{Color {}  ;a:2'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'a',N(1,16,2))))), ['1;9;css:decl:no colon', '1;17;css:block:eof']],
  ['stylesheet', ['a{Color {a:};a:2'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'a',N(1,16,2))))), ['1;9;css:decl:no colon', '1;17;css:block:eof']],
  ['stylesheet', ['a{Color {;;};a:2'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'a',N(1,16,2))))), ['1;9;css:decl:no colon', '1;17;css:block:eof']],
  ['stylesheet', ['a{Color:{;;};a:2'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color',Block(1,9,Semi(1,10),Semi(1,11))),D(1,14,'a',N(1,16,2))))), ['1;17;css:block:eof']],
  ['stylesheet', ['a{Color:[;;];a:2'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color',Box(1,9,Semi(1,10),Semi(1,11))),D(1,14,'a',N(1,16,2))))), ['1;17;css:block:eof']],
  ['stylesheet', ['a{Color:(;;);a:2'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color',Paren(1,9,Semi(1,10),Semi(1,11))),D(1,14,'a',N(1,16,2))))), ['1;17;css:block:eof']],
  ['stylesheet', ['a{Color:x(;);a:2'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,3,'Color',F(1,9,'x',Semi(1,11))),D(1,14,'a',N(1,16,2))))), ['1;17;css:block:eof']],
  ['stylesheet', ['a{hoge!}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2))), ['1;7;css:decl:no colon']],
  ['stylesheet', ['a{hoge[]}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2))), ['1;7;css:decl:no colon']],
  ['stylesheet', ['a{hoge[}]'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2))), ['1;7;css:decl:no colon', '1;10;css:block:eof']],
  ['stylesheet', ['a{hoge[}];x:y'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,11,'x',ID(1,13,'y'))))), ['1;7;css:decl:no colon', '1;14;css:block:eof']],
  ['stylesheet', ['a{!foo:bar]a;b:c'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c'))))), ['1;3;css:decls:bad name', '1;17;css:block:eof']],
  ['stylesheet', ['a{[foo:bar]a;b:c'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c'))))), ['1;3;css:decls:bad name', '1;17;css:block:eof']],
  ['stylesheet', ['a{[foo:bar]a;b:c}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c'))))), ['1;3;css:decls:bad name']],
  ['stylesheet', ['a{h[oo:bar]a;b:c}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c'))))), ['1;4;css:decl:no colon']],
  ['stylesheet', ['a{:[fo:bar]a;b:c}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c'))))), ['1;3;css:decls:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c@x}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c'),AtToken(1,17,'x'))))), ['1;3;css:decls:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c')),At(1,18,'x')))), ['1;3;css:decls:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x;}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c')),At(1,18,'x')))), ['1;3;css:decls:bad name']],
  ['stylesheet', ['@media{@hoge}'], Rules(1,0,At(1,1,'media',Block(1,7,At(1,8,'hoge'))))],
  ['stylesheet', ['@media{@hoge;}'], Rules(1,0,At(1,1,'media',Block(1,7,At(1,8,'hoge'))))],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x{};x:y}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c')),At(1,18,'x',Block(1,20)),D(1,23,'x',ID(1,25,'y'))))), ['1;3;css:decls:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x{} x:y}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c')),At(1,18,'x',Block(1,20)),D(1,23,'x',ID(1,25,'y'))))), ['1;3;css:decls:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x{}!x:y}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c')),At(1,18,'x',Block(1,20))))), ['1;3;css:decls:bad name', '1;22;css:decls:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x  ;x:y}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,D(1,14,'b',ID(1,16,'c')),At(1,18,'x',S(1,20)),D(1,23,'x',ID(1,25,'y'))))), ['1;3;css:decls:bad name']],
  ['stylesheet', ['a{@media{p{}}x:y}'], Rules(1,0,Q(1,1,ID(1,1,'a'),Block(1,2,At(1,3,'media',Block(1,9,Q(1,10,ID(1,10,'p'),Block(1,11)))),D(1,14,'x',ID(1,16,'y')))))],

#  ['rule-list', ['hoge{}'], Rules(1,0,Q(1,1,ID(1,1,'hoge'),Block(1,5)))],
#  ['rule-list', ['-->hoge{}'], Rules(1,0,Q(1,1,CDC(1,1),ID(1,4,'hoge'),Block(1,8)))],
#  ['rule-list', ['-->hoge{}<!--'], Rules(1,0,Q(1,1,CDC(1,1),ID(1,4,'hoge'),Block(1,8))), ['1;14;css:qrule:no block']],

  ['rule', [''], undef, ['1;1;css:rule:not found']],
  ['rule', ['   '], undef, ['1;4;css:rule:not found']],
  ['rule', ['   <!--'], undef, ['1;8;css:qrule:no block', '1;8;css:rule:not found']],
  ['rule', ['hoge{}'], Q(1,1,ID(1,1,'hoge'),Block(1,5))],
  ['rule', ['hoge{}   '], Q(1,1,ID(1,1,'hoge'),Block(1,5))],
  ['rule', ['hoge{}-->'], Q(1,1,ID(1,1,'hoge'),Block(1,5)), ['1;7;css:rule:multiple', '1;10;css:qrule:no block']],
  ['rule', ['<!--hoge{}'], Q(1,1,CDO(1,1),ID(1,5,'hoge'),Block(1,9))],
  ['rule', ['hoge{}@a'], Q(1,1,ID(1,1,'hoge'),Block(1,5)), ['1;7;css:rule:multiple', '1;9;css:at-rule:eof']],
  ['rule', ['hoge{}fuga{}'], Q(1,1,ID(1,1,'hoge'),Block(1,5)), ['1;7;css:rule:multiple']],
  ['rule', ['@foo'], At(1,1,'foo'), ['1;5;css:at-rule:eof']],
  ['rule', ['@foo;@bar;'], At(1,1,'foo'), ['1;6;css:rule:multiple']],
  ['rule', ['abc;@foo;'], undef, ['1;10;css:qrule:no block', '1;10;css:rule:not found']],
  ['rule', ['abc{}@foo;'], Q(1,1,ID(1,1,'abc'),Block(1,4)), ['1;6;css:rule:multiple']],
  ['rule', ['@media{p{}q{}}'], At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'p'),Block(1,9)),Q(1,11,ID(1,11,'q'),Block(1,12))))],
  ['rule', ['@media{p{}@q{}}'], At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'p'),Block(1,9)),At(1,11,'q',Block(1,13))))],
  ['rule', ['@media{p{}@q{}}   '], At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'p'),Block(1,9)),At(1,11,'q',Block(1,13))))],
  ['rule', ['@media{p{}q{}'], At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'p'),Block(1,9)),Q(1,11,ID(1,11,'q'),Block(1,12)))), ['1;14;css:block:eof']],
) {
  test {
    my $c = shift;
    my $b = CSSBuilder->new;

    my $errors = [];
    {
      $b->onerror (sub {
        my %args = @_;
        push @$errors, join ';',
            $args{token}->{line} || $args{line},
            $args{token}->{column} || $args{column},
            $args{type};
      });

      $b->{line_prev} = $b->{line} = 1;
      $b->{column_prev} = -1;
      $b->{column} = 0;

      $b->{chars} = [];
      $b->{chars_pos} = 0;
      delete $b->{chars_was_cr};
      my @s = @{$test->[1]};
      $b->{chars_pull_next} = sub {
        my $s = shift @s;
        push @{$b->{chars}}, split //, $s if defined $s;
        return defined $s;
      };
      $b->init_tokenizer;
      $b->init_builder;
    }

    $b->start_building_rules ($test->[0] eq 'rule') or do {
      1 while not $b->continue_building_rules;
    };

    if ($test->[2] and $test->[2]->{type} == 10000 + 1) {
      $test->[2]->{top_level} = $test->[0] eq 'stylesheet';
    }
    eq_or_diff $b->{parsed_construct}, $test->[2], 'tree';
    eq_or_diff $errors, $test->[3] || [], 'errors';

    done $c;
  } name => ['tree building', $test->[0], @{$test->[1]}], n => 2;
} # $test

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
