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
sub Gt ($$) { {line => $_[0], column => $_[1], type => 18} }
sub RBrace ($$) { {line => $_[0], column => $_[1], type => 28} }
sub RParen ($$) { {line => $_[0], column => $_[1], type => 30} }
sub ID ($$$) { {line => $_[0], column => $_[1], type => 1, value => $_[2]} }
sub Str ($$$) { {line => $_[0], column => $_[1], type => 9, value => $_[2]} }
sub URL ($$$) { {line => $_[0], column => $_[1], type => 5, value => $_[2]} }
sub N ($$$) { {line => $_[0], column => $_[1], type => 11,
               number => ''.$_[2], value => ''} }
sub Pct ($$$) { {line => $_[0], column => $_[1], type => 13,
                 number => ''.$_[2], value => ''} }
sub Rules ($$$$;@) { my $t = {line => shift, column => shift,
                              end_line => shift, end_column => shift,
                              single => '',
                              type => 10000 + 1, value => [@_]};
                     for (@{$t->{value}}) {
                       delete $_->{delim_type} if $_->{type} == 10000 + 2;
                     }
                     $t }
sub Q ($$$$;@) { {line => shift, column => shift,
                  do { end_line => shift, end_column => shift; () },
                  type => 10000 + 3,
                  value => [@_],
                  parent_at => '',
                  delim_type => 27} }
sub Block ($$$$;@) { my $t = {line => shift, column => shift,
                              type => 10000 + 4,
                              end_line => shift, end_column => shift,
                              value => [@_],
                              end_type => 28};
                     for (@{$t->{value}}) {
                       $_->{end_type} = 28 if $_->{type} == 10000 + 3;
                     }
                     $t }
sub Box ($$$$;@) { {line => shift, column => shift,
                    type => 10000 + 5,
                    end_line => shift, end_column => shift,
                    value => [@_],
                    end_type => 32} }
sub Paren ($$$$;@) { {line => shift, column => shift,
                      type => 10000 + 6,
                      end_line => shift, end_column => shift,
                      value => [@_],
                      end_type => 30} }
sub F ($$$$$;@) { {line => $_[0], column => $_[1],
                   type => 10000 + 7,
                   name => {line => shift, column => shift, type => 4,
                            value => $_[2]},
                   end_line => shift, end_column => shift,
                   do { shift; () },
                   value => [@_],
                   end_type => 30} } # function
sub At ($$$$$;@) { my $t = {line => $_[0], column => $_[1], type => 10000 + 2,
                            name => {line => shift, column => shift, type => 2,
                                     value => $_[2]},
                            end_line => shift, end_column => shift,
                            do { shift; () },
                            delim_type => 28,
                            value => [@_]};
                   if (@{$t->{value}} and
                       $t->{value}->[-1]->{type} == 10000 + 4) { # block
                     $t->{value}->[-1]->{at} = lc $t->{name}->{value};
                     for (@{$t->{value}->[-1]->{value}}) {
                       next unless $_->{type} == 10000 + 3;
                       $_->{parent_at} = lc $t->{name}->{value};
                     }
                     delete $t->{end_line};
                     delete $t->{end_column};
                   }
                   $t }
sub AtToken ($$$) { {line => $_[0], column => $_[1], type => 2,
                     value => $_[2]} }
sub D ($$$$$;@) { {line => $_[0], column => $_[1], type => 10000 + 8,
                   name => {line => shift, column => shift, type => 1,
                            value => $_[2]},
                   end_line => shift, end_column => shift,
                   do { shift; () },
                   delim_type => 26, end_type => 28,
                   value => [@_]} }

for my $test (
  ['stylesheet', [''], Rules(1,0=>1,1)],
  ['stylesheet', ['   '], Rules(1,0=>1,4)],
  ['stylesheet', ['aa'], Rules(1,0=>1,3), ['1;3;css:qrule:no block']],
  ['stylesheet', ['hoge   {}'], Rules(1,0=>1,10,Q(1,1=>1,9,ID(1,1,'hoge'),S(1,5),Block(1,8=>1,9)))],
  ['stylesheet', ['hoge   {} '], Rules(1,0=>1,11,Q(1,1=>1,9,ID(1,1,'hoge'),S(1,5),Block(1,8=>1,9)))],
  ['stylesheet', ['ho', 'ge   ', '{} '], Rules(1,0=>1,11,Q(1,1=>1,9,ID(1,1,'hoge'),S(1,5),Block(1,8=>1,9)))],
  ['stylesheet', ['ho', '', 'ge   {} '], Rules(1,0=>1,11,Q(1,1=>1,9,ID(1,1,'hoge'),S(1,5),Block(1,8=>1,9)))],
  ['stylesheet', ['hoge', '   {} '], Rules(1,0=>1,11,Q(1,1=>1,9,ID(1,1,'hoge'),S(1,5),Block(1,8=>1,9)))],
  ['stylesheet', ['ho', '', 'ge   ', '', '{} '], Rules(1,0=>1,11,Q(1,1=>1,10,ID(1,1,'hoge'),S(1,5),Block(1,8=>1,9)))],
  ['stylesheet', ['hoge   {} a'], Rules(1,0=>1,12,Q(1,1=>1,9,ID(1,1,'hoge'),S(1,5),Block(1,8=>1,9))), ['1;12;css:qrule:no block']],
  ['stylesheet', ['<!--'], Rules(1,0=>1,5)],
  ['stylesheet', ['<!--p{}'], Rules(1,0=>1,8,Q(1,5=>1,7,ID(1,5,'p'),Block(1,6=>1,7)))],
  ['stylesheet', [' -->p{}'], Rules(1,0=>1,8,Q(1,5=>1,7,ID(1,5,'p'),Block(1,6=>1,7)))],
  ['stylesheet', ['q<!--p{}'], Rules(1,0=>1,9,Q(1,1=>1,8,ID(1,1,'q'),CDO(1,2),ID(1,6,'p'),Block(1,7=>1,8)))],
  ['stylesheet', ['aa-->'], Rules(1,0=>1,6), ['1;6;css:qrule:no block']],
  ['stylesheet', ['{}-->'], Rules(1,0=>1,6,Q(1,1=>1,2,Block(1,1=>1,2)))],
  ['stylesheet', ['{}-->{}'], Rules(1,0=>1,8,Q(1,1=>1,2,Block(1,1=>1,2)),Q(1,6=>1,7,Block(1,6=>1,7)))],
  ['stylesheet', ['}ab{}'], Rules(1,0=>1,6,Q(1,1=>1,5,RBrace(1,1),ID(1,2,'ab'),Block(1,4=>1,5)))],
  ['stylesheet', ['@hoge'], Rules(1,0=>1,6,At(1,1=>1,6,'hoge')), ['1;6;css:at-rule:eof']],
  ['stylesheet', ['@hoge;'], Rules(1,0=>1,7,At(1,1=>1,6,'hoge'))],
  ['stylesheet', ['@hoge/**/foo 12;'], Rules(1,0=>1,17,At(1,1=>1,16,'hoge',ID(1,10,'foo'),S(1,13),N(1,14,12)))],
  ['stylesheet', ['@hoge[foo]12;'], Rules(1,0=>1,14,At(1,1=>1,13,'hoge',Box(1,6=>1,10,ID(1,7,'foo')),N(1,11,12)))],
  ['stylesheet', ['@hoge[foo;1]12;'], Rules(1,0=>1,16,At(1,1=>1,15,'hoge',Box(1,6=>1,12,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  ['stylesheet', ['@hoge[foo;1]12;<!--'], Rules(1,0=>1,20,At(1,1=>1,15,'hoge',Box(1,6=>1,12,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  ['stylesheet', ['@hoge(foo;1)12;<!--'], Rules(1,0=>1,20,At(1,1=>1,15,'hoge',Paren(1,6=>1,12,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  ['stylesheet', ['@hoge aa(foo;1)12;<!--'], Rules(1,0=>1,23,At(1,1=>1,18,'hoge',S(1,6),F(1,7=>1,15,'aa',ID(1,10,'foo'),Semi(1,13),N(1,14,1)),N(1,16,12)))],
  ['stylesheet', ['@hoge{foo}12;'], Rules(1,0=>1,14,At(1,1=>1,13,'hoge',Block(1,6=>1,10,ID(1,7,'foo')))), ['1;14;css:qrule:no block']],
  ['stylesheet', ['@hoge{foo{}}12;'], Rules(1,0=>1,16,At(1,1=>1,15,'hoge',Block(1,6=>1,12,ID(1,7,'foo'),Block(1,10=>1,11)))), ['1;16;css:qrule:no block']],
  ['stylesheet', ['@', '', 'hoge{', '', 'foo{', '', '}}12', '', ';'], Rules(1,0=>1,16,At(1,1=>1,15,'hoge',Block(1,6=>1,12,ID(1,7,'foo'),Block(1,10=>1,11)))), ['1;16;css:qrule:no block']],
  ['stylesheet', ['@aaa[12'], Rules(1,0=>1,8,At(1,1=>1,8,'aaa',Box(1,5=>1,8,N(1,6,12)))), ['1;8;css:block:eof']],
  ['stylesheet', ['@aaa(12'], Rules(1,0=>1,8,At(1,1=>1,8,'aaa',Paren(1,5=>1,8,N(1,6,12)))), ['1;8;css:block:eof']],
  ['stylesheet', ['@aaa{12'], Rules(1,0=>1,8,At(1,1=>1,8,'aaa',Block(1,5=>1,8,N(1,6,12)))), ['1;8;css:block:eof']],
  ['stylesheet', ['@aa h(12'], Rules(1,0=>1,9,At(1,1=>1,9,'aa',S(1,4),F(1,5=>1,9,'h',N(1,7,12)))), ['1;9;css:block:eof']],
  ['stylesheet', ['@aa{h(12'], Rules(1,0=>1,9,At(1,1=>1,9,'aa',Block(1,4=>1,9,F(1,5=>1,9,'h',N(1,7,12))))), ['1;9;css:block:eof']],
  ['stylesheet', ['@aa{h("12'], Rules(1,0=>1,10,At(1,1=>1,10,'aa',Block(1,4=>1,10,F(1,5=>1,10,'h',Str(1,7,'12'))))), ['1;10;css:string:eof']],
  ['stylesheet', ['@aa{url(12'], Rules(1,0=>1,11,At(1,1=>1,11,'aa',Block(1,4=>1,11,URL(1,5,'12')))), ['1;11;css:url:eof']],
  ['stylesheet', ['ab{'], Rules(1,0=>1,4,Q(1,1=>1,4,ID(1,1,'ab'),Block(1,3=>1,4))), ['1;4;css:block:eof']],
  ['stylesheet', ['hoge (ab { ) cd }) 2 {}'], Rules(1,0=>1,24,Q(1,1=>1,23,ID(1,1,'hoge'),S(1,5),Paren(1,6=>1,18,ID(1,7,'ab'),S(1,9),Block(1,10=>1,17,S(1,11),RParen(1,12),S(1,13),ID(1,14,'cd'),S(1,16))),S(1,19),N(1,20,2),S(1,21),Block(1,22=>1,23)))],
  ['stylesheet', [':hoge(ab { ) cd }) 2 {}'], Rules(1,0=>1,24,Q(1,1=>1,23,Colon(1,1),F(1,2=>1,18,'hoge',ID(1,7,'ab'),S(1,9),Block(1,10=>1,17,S(1,11),RParen(1,12),S(1,13),ID(1,14,'cd'),S(1,16))),S(1,19),N(1,20,2),S(1,21),Block(1,22=>1,23)))],
  ['stylesheet', ['@ab{co{}}'], Rules(1,0=>1,10,At(1,1=>1,9,'ab',Block(1,4=>1,9,ID(1,5,'co'),Block(1,7=>1,8))))],
  ['stylesheet', ['@media{co{}}'], Rules(1,0=>1,13,At(1,1=>1,12,'media',Block(1,7=>1,12,Q(1,8=>1,11,ID(1,8,'co'),Block(1,10=>1,11)))))],
  ['stylesheet', ['@media{co{}'], Rules(1,0=>1,12,At(1,1=>1,12,'media',Block(1,7=>1,12,Q(1,8=>1,11,ID(1,8,'co'),Block(1,10=>1,11))))), ['1;12;css:block:eof']],
  ['stylesheet', ['@MedIA{co{}}'], Rules(1,0=>1,13,At(1,1=>1,12,'MedIA',Block(1,7=>1,12,Q(1,8=>1,11,ID(1,8,'co'),Block(1,10=>1,11)))))],
  ['stylesheet', ['@MedIA{@media{co{'], Rules(1,0=>1,18,At(1,1=>1,18,'MedIA',Block(1,7=>1,18,At(1,8=>1,18,'media',Block(1,14=>1,18,Q(1,15=>1,18,ID(1,15,'co'),Block(1,17=>1,18))))))), ['1;18;css:block:eof']],
  ['stylesheet', ['@MedIA{@media{co{}}'], Rules(1,0=>1,20,At(1,1=>1,20,'MedIA',Block(1,7=>1,20,At(1,8=>1,19,'media',Block(1,14=>1,19,Q(1,15=>1,18,ID(1,15,'co'),Block(1,17=>1,18))))))), ['1;20;css:block:eof']],
  ['stylesheet', ['@MedIA{@media{co{}}}'], Rules(1,0=>1,21,At(1,1=>1,20,'MedIA',Block(1,7=>1,20,At(1,8=>1,18,'media',Block(1,14=>1,19,Q(1,15=>1,18,ID(1,15,'co'),Block(1,17=>1,18)))))))],
  ['stylesheet', ['@supports{@supports{co{a:b}}}'], Rules(1,0=>1,30,At(1,1=>1,29,'supports',Block(1,10=>1,29,At(1,11=>1,27,'supports',Block(1,20=>1,28,Q(1,21=>1,27,ID(1,21,'co'),Block(1,23=>1,27,D(1,24=>1,27,'a',ID(1,26,'b')))))))))],
  ['stylesheet', ['@MedIA{@-moz-Document{co{}}}'], Rules(1,0=>1,29,At(1,1=>1,28,'MedIA',Block(1,7=>1,28,At(1,8=>1,26,'-moz-Document',Block(1,22=>1,27,Q(1,23=>1,26,ID(1,23,'co'),Block(1,25=>1,26)))))))],
  ['stylesheet', ['@keyframes{@media{co{}}}'], Rules(1,0=>1,25,At(1,1=>1,24,'keyframes',Block(1,11=>1,24,At(1,12=>1,22,'media',Block(1,18=>1,23,Q(1,19=>1,22,ID(1,19,'co'),Block(1,21=>1,22)))))))],
  ['stylesheet', ['@media{hoge{'], Rules(1,0=>1,13,At(1,1=>1,13,'media',Block(1,7=>1,13,Q(1,8=>1,13,ID(1,8,'hoge'),Block(1,12=>1,13))))), ['1;13;css:block:eof']],
  ['stylesheet', ['@media{hoge{abc'], Rules(1,0=>1,16,At(1,1=>1,16,'media',Block(1,7=>1,16,Q(1,8=>1,16,ID(1,8,'hoge'),Block(1,12=>1,16))))), ['1;16;css:decl:no colon', '1;16;css:block:eof']],
  ['stylesheet', ['@-moz-Document{hoge{abc'], Rules(1,0=>1,24,At(1,1=>1,24,'-moz-Document',Block(1,15=>1,24,Q(1,16=>1,24,ID(1,16,'hoge'),Block(1,20=>1,24))))), ['1;24;css:decl:no colon', '1;24;css:block:eof']],
  ['stylesheet', ['@-moz-Document{@media{hoge{abc'], Rules(1,0=>1,31,At(1,1=>1,31,'-moz-Document',Block(1,15=>1,31,At(1,16=>1,31,'media',Block(1,22=>1,31,Q(1,23=>1,31,ID(1,23,'hoge'),Block(1,27=>1,31))))))), ['1;31;css:decl:no colon', '1;31;css:block:eof']],
  ['stylesheet', ['@KeyFrames{40%{color:red}}'], Rules(1,0=>1,27,At(1,1=>1,26,'KeyFrames',Block(1,11=>1,26,Q(1,12=>1,25,Pct(1,12,40),Block(1,15=>1,25,D(1,16=>1,25,'color',ID(1,22,'red')))))))],
  ['stylesheet', ['@KeyFrames{40%{color:red'], Rules(1,0=>1,25,At(1,1=>1,25,'KeyFrames',Block(1,11=>1,25,Q(1,12=>1,25,Pct(1,12,40),Block(1,15=>1,25,D(1,16=>1,25,'color',ID(1,22,'red'))))))), ['1;25;css:block:eof']],
  ['stylesheet', ['@page{hoge:12}'], Rules(1,0=>1,15,At(1,1=>1,14,'page',Block(1,6=>1,14,D(1,7=>1,14,'hoge',N(1,12,12)))))],
  ['stylesheet', ['@page{hoge:12'], Rules(1,0=>1,14,At(1,1=>1,14,'page',Block(1,6=>1,14,D(1,7=>1,14,'hoge',N(1,12,12))))), ['1;14;css:block:eof']],
  ['stylesheet', ['@font-FACe{hoge:12}'], Rules(1,0=>1,20,At(1,1=>1,19,'font-FACe',Block(1,11=>1,19,D(1,12=>1,19,'hoge',N(1,17,12)))))],
  ['stylesheet', ['@global{hoge:12}'], Rules(1,0=>1,17,At(1,1=>1,16,'global',Block(1,8=>1,16,D(1,9=>1,16,'hoge',N(1,14,12)))))],
  ['stylesheet', ['@media{@global{hoge:12}}'], Rules(1,0=>1,25,At(1,1=>1,24,'media',Block(1,7=>1,24,At(1,8=>1,23,'global',Block(1,15=>1,23,D(1,16=>1,23,'hoge',N(1,21,12)))))))],
  ['stylesheet', ['p{}q{}@media{}'], Rules(1,0=>1,15,Q(1,1=>1,3,ID(1,1,'p'),Block(1,2=>1,3)),Q(1,4=>1,6,ID(1,4,'q'),Block(1,5=>1,6)),At(1,7=>1,14,'media',Block(1,13=>1,14)))],
  ['stylesheet', ['@media{<!--q{}}'], Rules(1,0=>1,16,At(1,1=>1,15,'media',Block(1,7=>1,15,Q(1,8=>1,14,CDO(1,8),ID(1,12,'q'),Block(1,13=>1,14)))))],
  ['stylesheet', ['@media{--> q{}}'], Rules(1,0=>1,16,At(1,1=>1,15,'media',Block(1,7=>1,15,Q(1,8=>1,14,CDC(1,8),S(1,11),ID(1,12,'q'),Block(1,13=>1,14)))))],
  ['stylesheet', ['@media{--> q{}s{}}'], Rules(1,0=>1,19,At(1,1=>1,18,'media',Block(1,7=>1,18,Q(1,8=>1,14,CDC(1,8),S(1,11),ID(1,12,'q'),Block(1,13=>1,14)),Q(1,15=>1,17,ID(1,15,'s'),Block(1,16=>1,17)))))],
  ['stylesheet', ['a{color}'], Rules(1,0=>1,9,Q(1,1=>1,8,ID(1,1,'a'),Block(1,2=>1,8))), ['1;8;css:decl:no colon']],
  ['stylesheet', ['a{color;}'], Rules(1,0=>1,10,Q(1,1=>1,9,ID(1,1,'a'),Block(1,2=>1,9))), ['1;8;css:decl:no colon']],
  ['stylesheet', ['a{color; ;a-z:}'], Rules(1,0=>1,16,Q(1,1=>1,15,ID(1,1,'a'),Block(1,2=>1,15,D(1,11=>1,15,'a-z')))), ['1;8;css:decl:no colon']],
  ['stylesheet', ['a{color; ;a-z::}'], Rules(1,0=>1,17,Q(1,1=>1,16,ID(1,1,'a'),Block(1,2=>1,16,D(1,11=>1,16,'a-z',Colon(1,15))))), ['1;8;css:decl:no colon']],
  ['stylesheet', ['a{Color:0.1}'], Rules(1,0=>1,13,Q(1,1=>1,12,ID(1,1,'a'),Block(1,2=>1,12,D(1,3=>1,12,'Color',N(1,9,0.1)))))],
  ['stylesheet', ['a{Color:0.1'], Rules(1,0=>1,12,Q(1,1=>1,12,ID(1,1,'a'),Block(1,2=>1,12,D(1,3=>1,12,'Color',N(1,9,0.1))))), ['1;12;css:block:eof']],
  ['stylesheet', ['a{Color:"ab'], Rules(1,0=>1,12,Q(1,1=>1,12,ID(1,1,'a'),Block(1,2=>1,12,D(1,3=>1,12,'Color',Str(1,9,'ab'))))), ['1;12;css:string:eof']],
  ['stylesheet', ['a{Color:'], Rules(1,0=>1,9,Q(1,1=>1,9,ID(1,1,'a'),Block(1,2=>1,9,D(1,3=>1,9,'Color')))), ['1;9;css:block:eof']],
  ['stylesheet', ['a{Color'], Rules(1,0=>1,8,Q(1,1=>1,8,ID(1,1,'a'),Block(1,2=>1,8))), ['1;8;css:decl:no colon', '1;8;css:block:eof']],
  ['stylesheet', ['a{Color  '], Rules(1,0=>1,10,Q(1,1=>1,10,ID(1,1,'a'),Block(1,2=>1,10))), ['1;10;css:decl:no colon', '1;10;css:block:eof']],
  ['stylesheet', ['a{Color  :'], Rules(1,0=>1,11,Q(1,1=>1,11,ID(1,1,'a'),Block(1,2=>1,11,D(1,3=>1,11,'Color')))), ['1;11;css:block:eof']],
  ['stylesheet', ['a{Color:  '], Rules(1,0=>1,11,Q(1,1=>1,11,ID(1,1,'a'),Block(1,2=>1,11,D(1,3=>1,11,'Color',S(1,9))))), ['1;11;css:block:eof']],
  ['stylesheet', ['a{Color red:'], Rules(1,0=>1,13,Q(1,1=>1,13,ID(1,1,'a'),Block(1,2=>1,13))), ['1;9;css:decl:no colon', '1;13;css:block:eof']],
  ['stylesheet', ['a{Color red:;a:2'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'a',N(1,16,2))))), ['1;9;css:decl:no colon', '1;17;css:block:eof']],
  ['stylesheet', ['a{Color {}  ;a:2'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'a',N(1,16,2))))), ['1;9;css:decl:no colon', '1;17;css:block:eof']],
  ['stylesheet', ['a{Color {a:};a:2'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'a',N(1,16,2))))), ['1;9;css:decl:no colon', '1;17;css:block:eof']],
  ['stylesheet', ['a{Color {;;};a:2'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'a',N(1,16,2))))), ['1;9;css:decl:no colon', '1;17;css:block:eof']],
  ['stylesheet', ['a{Color:{;;};a:2'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,3=>1,13,'Color',Block(1,9=>1,12,Semi(1,10),Semi(1,11))),D(1,14=>1,17,'a',N(1,16,2))))), ['1;17;css:block:eof']],
  ['stylesheet', ['a{Color:[;;];a:2'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,3=>1,13,'Color',Box(1,9=>1,12,Semi(1,10),Semi(1,11))),D(1,14=>1,17,'a',N(1,16,2))))), ['1;17;css:block:eof']],
  ['stylesheet', ['a{Color:(;;);a:2'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,3=>1,13,'Color',Paren(1,9=>1,12,Semi(1,10),Semi(1,11))),D(1,14=>1,17,'a',N(1,16,2))))), ['1;17;css:block:eof']],
  ['stylesheet', ['a{Color:x(;);a:2'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,3=>1,13,'Color',F(1,9=>1,12,'x',Semi(1,11))),D(1,14=>1,17,'a',N(1,16,2))))), ['1;17;css:block:eof']],
  ['stylesheet', ['a{hoge!}'], Rules(1,0=>1,9,Q(1,1=>1,8,ID(1,1,'a'),Block(1,2=>1,8))), ['1;7;css:decl:no colon']],
  ['stylesheet', ['a{hoge[]}'], Rules(1,0=>1,10,Q(1,1=>1,9,ID(1,1,'a'),Block(1,2=>1,9))), ['1;7;css:decl:no colon']],
  ['stylesheet', ['a{hoge[}]'], Rules(1,0=>1,10,Q(1,1=>1,10,ID(1,1,'a'),Block(1,2=>1,10))), ['1;7;css:decl:no colon', '1;10;css:block:eof']],
  ['stylesheet', ['a{hoge[}];x:y'], Rules(1,0=>1,14,Q(1,1=>1,14,ID(1,1,'a'),Block(1,2=>1,14,D(1,11=>1,14,'x',ID(1,13,'y'))))), ['1;7;css:decl:no colon', '1;14;css:block:eof']],
  ['stylesheet', ['a{!foo:bar]a;b:c'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'b',ID(1,16,'c'))))), ['1;3;css:decl:bad name', '1;17;css:block:eof']],
  ['stylesheet', ['a{[foo:bar]a;b:c'], Rules(1,0=>1,17,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'b',ID(1,16,'c'))))), ['1;3;css:decl:bad name', '1;17;css:block:eof']],
  ['stylesheet', ['a{[foo:bar]a;b:c}'], Rules(1,0=>1,18,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'b',ID(1,16,'c'))))), ['1;3;css:decl:bad name']],
  ['stylesheet', ['a{h[oo:bar]a;b:c}'], Rules(1,0=>1,18,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'b',ID(1,16,'c'))))), ['1;4;css:decl:no colon']],
  ['stylesheet', ['a{:[fo:bar]a;b:c}'], Rules(1,0=>1,18,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,D(1,14=>1,17,'b',ID(1,16,'c'))))), ['1;3;css:decl:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c@x}'], Rules(1,0=>1,20,Q(1,1=>1,19,ID(1,1,'a'),Block(1,2=>1,19,D(1,14=>1,19,'b',ID(1,16,'c'),AtToken(1,17,'x'))))), ['1;3;css:decl:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x}'], Rules(1,0=>1,21,Q(1,1=>1,20,ID(1,1,'a'),Block(1,2=>1,20,D(1,14=>1,17,'b',ID(1,16,'c')),At(1,18=>1,20,'x')))), ['1;3;css:decl:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x;}'], Rules(1,0=>1,22,Q(1,1=>1,21,ID(1,1,'a'),Block(1,2=>1,21,D(1,14=>1,17,'b',ID(1,16,'c')),At(1,18=>1,20,'x')))), ['1;3;css:decl:bad name']],
  ['stylesheet', ['@media{@hoge}'], Rules(1,0=>1,14,At(1,1=>1,13,'media',Block(1,7=>1,13,At(1,8=>1,13,'hoge'))))],
  ['stylesheet', ['@media{@hoge;}'], Rules(1,0=>1,15,At(1,1=>1,14,'media',Block(1,7=>1,14,At(1,8=>1,13,'hoge'))))],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x{};x:y}'], Rules(1,0=>1,27,Q(1,1=>1,26,ID(1,1,'a'),Block(1,2=>1,26,D(1,14=>1,17,'b',ID(1,16,'c')),At(1,18=>1,21,'x',Block(1,20=>1,21)),D(1,23=>1,26,'x',ID(1,25,'y'))))), ['1;3;css:decl:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x{} x:y}'], Rules(1,0=>1,27,Q(1,1=>1,26,ID(1,1,'a'),Block(1,2=>1,26,D(1,14=>1,17,'b',ID(1,16,'c')),At(1,18=>1,21,'x',Block(1,20=>1,21)),D(1,23=>1,26,'x',ID(1,25,'y'))))), ['1;3;css:decl:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x{}!x:y}'], Rules(1,0=>1,27,Q(1,1=>1,26,ID(1,1,'a'),Block(1,2=>1,26,D(1,14=>1,17,'b',ID(1,16,'c')),At(1,18=>1,21,'x',Block(1,20=>1,21))))), ['1;3;css:decl:bad name', '1;22;css:decl:bad name']],
  ['stylesheet', ['a{:[fo:bar]a;b:c;@x  ;x:y}'], Rules(1,0=>1,27,Q(1,1=>1,26,ID(1,1,'a'),Block(1,2=>1,26,D(1,14=>1,17,'b',ID(1,16,'c')),At(1,18=>1,22,'x',S(1,20)),D(1,23=>1,26,'x',ID(1,25,'y'))))), ['1;3;css:decl:bad name']],
  ['stylesheet', ['a{@media{p{}}x:y}'], Rules(1,0=>1,18,Q(1,1=>1,17,ID(1,1,'a'),Block(1,2=>1,17,At(1,3=>1,13,'media',Block(1,9=>1,13,Q(1,10=>1,12,ID(1,10,'p'),Block(1,11=>1,12)))),D(1,14=>1,17,'x',ID(1,16,'y')))))],
  ['stylesheet', ['@color-profile{a:b}'], Rules(1,0=>1,20,At(1,1=>1,19,'color-profile',Block(1,15=>1,19,D(1,16=>1,19,'a',ID(1,18,'b')))))],
  ['stylesheet', ['a { @media { display: block }}'], Rules(1,0=>1,31,Q(1,1=>1,30,ID(1,1,'a'),S(1,2),Block(1,3=>1,30,At(1,5=>1,29,'media',S(1,11),Block(1,12=>1,29))))), ['1;29;css:qrule:no block']],
  ['stylesheet', ['a { @media { display: []ock }}'], Rules(1,0=>1,31,Q(1,1=>1,30,ID(1,1,'a'),S(1,2),Block(1,3=>1,30,At(1,5=>1,29,'media',S(1,11),Block(1,12=>1,29))))), ['1;29;css:qrule:no block']],
  ['stylesheet', ['a { @media { display: [{c}] }}'], Rules(1,0=>1,31,Q(1,1=>1,30,ID(1,1,'a'),S(1,2),Block(1,3=>1,30,At(1,5=>1,29,'media',S(1,11),Block(1,12=>1,29))))), ['1;29;css:qrule:no block']],
  ['stylesheet', ['a { @media { d{display:block} }}'], Rules(1,0=>1,33,Q(1,1=>1,32,ID(1,1,'a'),S(1,2),Block(1,3=>1,32,At(1,5=>1,31,'media',S(1,11),Block(1,12=>1,31,Q(1,14=>1,30,ID(1,14,'d'),Block(1,15=>1,29,D(1,16=>1,29,'display',ID(1,24,'block')))))))))],
  ['stylesheet', ['a { @media { @media{} }}'], Rules(1,0=>1,25,Q(1,1=>1,24,ID(1,1,'a'),S(1,2),Block(1,3=>1,24,At(1,5=>1,23,'media',S(1,11),Block(1,12=>1,23,At(1,14=>1,22,'media',Block(1,20=>1,21)))))))],
  ['stylesheet', ['a { @media { @media   }}'], Rules(1,0=>1,25,Q(1,1=>1,24,ID(1,1,'a'),S(1,2),Block(1,3=>1,24,At(1,5=>1,23,'media',S(1,11),Block(1,12=>1,23,At(1,14=>1,23,'media',S(1,20)))))))],

#  ['rule-list', ['hoge{}'], Rules(1,0=>1,7,Q(1,1=>1,6,ID(1,1,'hoge'),Block(1,5=>1,6)))],
#  ['rule-list', ['-->hoge{}'], Rules(1,0=>1,10,Q(1,1=>1,9,CDC(1,1),ID(1,4,'hoge'),Block(1,8=>1,9)))],
#  ['rule-list', ['-->hoge{}<!--'], Rules(1,0=>1,14,Q(1,1=>1,9,CDC(1,1),ID(1,4,'hoge'),Block(1,8=>1,9))), ['1;14;css:qrule:no block']],

  ['rule', [''], undef, ['1;1;css:rule:not found']],
  ['rule', ['   '], undef, ['1;4;css:rule:not found']],
  ['rule', ['   <!--'], undef, ['1;8;css:qrule:no block', '1;8;css:rule:not found']],
  ['rule', ['hoge{}'], Q(1,1=>1,6,ID(1,1,'hoge'),Block(1,5=>1,6))],
  ['rule', ['hoge{}   '], Q(1,1=>1,6,ID(1,1,'hoge'),Block(1,5=>1,6))],
  ['rule', ['hoge{}-->'], Q(1,1=>1,6,ID(1,1,'hoge'),Block(1,5=>1,6)), ['1;7;css:rule:multiple', '1;10;css:qrule:no block']],
  ['rule', ['<!--hoge{}'], Q(1,1=>1,10,CDO(1,1),ID(1,5,'hoge'),Block(1,9=>1,10))],
  ['rule', ['hoge{}@a'], Q(1,1=>1,6,ID(1,1,'hoge'),Block(1,5=>1,6)), ['1;7;css:rule:multiple', '1;9;css:at-rule:eof']],
  ['rule', ['hoge{}fuga{}'], Q(1,1=>1,6,ID(1,1,'hoge'),Block(1,5=>1,6)), ['1;7;css:rule:multiple']],
  ['rule', ['@foo'], At(1,1=>1,5,'foo'), ['1;5;css:at-rule:eof']],
  ['rule', ['@foo;@bar;'], At(1,1=>1,5,'foo'), ['1;6;css:rule:multiple']],
  ['rule', ['abc;@foo;'], undef, ['1;10;css:qrule:no block', '1;10;css:rule:not found']],
  ['rule', ['abc{}@foo;'], Q(1,1=>1,5,ID(1,1,'abc'),Block(1,4=>1,5)), ['1;6;css:rule:multiple']],
  ['rule', ['@media{p{}q{}}'], At(1,1=>1,14,'media',Block(1,7=>1,14,Q(1,8=>1,10,ID(1,8,'p'),Block(1,9=>1,10)),Q(1,11=>1,13,ID(1,11,'q'),Block(1,12=>1,13))))],
  ['rule', ['@media{p{}@q{}}'], At(1,1=>1,15,'media',Block(1,7=>1,15,Q(1,8=>1,10,ID(1,8,'p'),Block(1,9=>1,10)),At(1,11=>1,14,'q',Block(1,13=>1,14))))],
  ['rule', ['@media{p{}@q{}}   '], At(1,1=>1,15,'media',Block(1,7=>1,15,Q(1,8=>1,10,ID(1,8,'p'),Block(1,9=>1,10)),At(1,11=>1,14,'q',Block(1,13=>1,14))))],
  ['rule', ['@media{p{}q{}'], At(1,1=>1,14,'media',Block(1,7=>1,14,Q(1,8=>1,10,ID(1,8,'p'),Block(1,9=>1,10)),Q(1,11=>1,13,ID(1,11,'q'),Block(1,12=>1,13)))), ['1;14;css:block:eof']],

  ['decl-list', [''], Block(1,0=>1,1)],
  ['decl-list', [';;  ;  '], Block(1,0=>1,8)],
  ['decl-list', [';;  ;  }'], Block(1,0=>1,9), ['1;8;css:decl:bad name']],
  ['decl-list', ['foo:bar'], Block(1,0=>1,8,D(1,1=>1,8,'foo',ID(1,5,'bar')))],
  ['decl-list', ['foo  :  bar'], Block(1,0=>1,12,D(1,1=>1,12,'foo',S(1,7),ID(1,9,'bar')))],
  ['decl-list', ['foo:'], Block(1,0=>1,5,D(1,1=>1,5,'foo'))],
  ['decl-list', ['foo'], Block(1,0=>1,4), ['1;4;css:decl:no colon']],
  ['decl-list', ['foo!'], Block(1,0=>1,5), ['1;4;css:decl:no colon']],
  ['decl-list', ['foo/**/bar'], Block(1,0=>1,11), ['1;8;css:decl:no colon']],
  ['decl-list', [' !'], Block(1,0=>1,3), ['1;2;css:decl:bad name']],
  ['decl-list', [' !;a:'], Block(1,0=>1,6,D(1,4=>1,6,'a')), ['1;2;css:decl:bad name']],
  ['decl-list', [' };a:'], Block(1,0=>1,6,D(1,4=>1,6,'a')), ['1;2;css:decl:bad name']],
  ['decl-list', ['{;b:c;};a:'], Block(1,0=>1,11,D(1,9=>1,11,'a')), ['1;1;css:decl:bad name']],
  ['decl-list', ['x{;b:c};a:'], Block(1,0=>1,11,D(1,9=>1,11,'a')), ['1;2;css:decl:no colon']],
  ['decl-list', ['@a{}b:c'], Block(1,0=>1,8,At(1,1=>1,4,'a',Block(1,3=>1,4)),D(1,5=>1,8,'b',ID(1,7,'c')))],
  ['decl-list', ['@a{};b:c'], Block(1,0=>1,9,At(1,1=>1,4,'a',Block(1,3=>1,4)),D(1,6=>1,9,'b',ID(1,8,'c')))],
  ['decl-list', ['b:c@a{}'], Block(1,0=>1,8,D(1,1=>1,8,'b',ID(1,3,'c'),AtToken(1,4,'a'),Block(1,6=>1,7)))],
  ['decl-list', ['b:c;@a{}'], Block(1,0=>1,9,D(1,1=>1,4,'b',ID(1,3,'c')),At(1,5=>1,8,'a',Block(1,7=>1,8)))],

  ['values', [''], Block(1,0=>1,1)],
  ['values', ['ab'], Block(1,0=>1,3,ID(1,1,'ab'))],
  ['values', ['ab}c'], Block(1,0=>1,5,ID(1,1,'ab'),RBrace(1,3),ID(1,4,'c'))],
  ['values', ['ab -->'], Block(1,0=>1,7,ID(1,1,'ab'),S(1,3),CDC(1,4))],
  ['values', ['ab-->'], Block(1,0=>1,6,ID(1,1,'ab--'),Gt(1,5))],
  ['values', ['ab{}c@aa{}'], Block(1,0=>1,11,ID(1,1,'ab'),Block(1,3=>1,4),ID(1,5,'c'),AtToken(1,6,'aa'),Block(1,9=>1,10))],
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

    if ($test->[0] eq 'decl-list') {
      $b->start_building_decls or do {
        1 while not $b->continue_building_decls;
      };
    } elsif ($test->[0] eq 'values') {
      $b->start_building_values or do {
        1 while not $b->continue_building_values;
      };
    } else {
      $b->start_building_rules ($test->[0] eq 'rule') or do {
        1 while not $b->continue_building_rules;
      };
    }

    if ($test->[2] and $test->[2]->{type} == 10000 + 1) {
      $test->[2]->{top_level} = $test->[0] eq 'stylesheet';
    } elsif ($test->[2] and $test->[2]->{type} == 10000 + 4) {
      delete $test->[2]->{end_type};
      delete $test->[2]->{name};
      for (@{$test->[2]->{value}}) {
        $_->{end_type} = undef
            if defined $_->{end_type} and
                $_->{type} != 10000 + 4;
      }
    }
    eq_or_diff $b->{parsed_construct}, $test->[2], 'tree';
    eq_or_diff $errors, $test->[3] || [], 'errors';

    delete $b->{chars_pull_next};
    done $c;
  } name => ['tree building', $test->[0], @{$test->[1]}], n => 2;
} # $test

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
