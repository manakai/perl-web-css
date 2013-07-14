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
sub Rules ($$;@) { {line => shift, column => shift,
                    type => 10000 + 1, value => [@_]} }
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

for my $test (
  [[''], Rules(1,0)],
  [['   '], Rules(1,0)],
  [['aa'], Rules(1,0), ['1;3;css:qrule:no block']],
  [['hoge   {}'], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  [['hoge   {} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  [['ho', 'ge   ', '{} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  [['ho', '', 'ge   {} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  [['hoge', '   {} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  [['ho', '', 'ge   ', '', '{} '], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8)))],
  [['hoge   {} a'], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Block(1,8))), ['1;12;css:qrule:no block']],
  [['<!--'], Rules(1,0)],
  [['<!--p{}'], Rules(1,0,Q(1,5,ID(1,5,'p'),Block(1,6)))],
  [[' -->p{}'], Rules(1,0,Q(1,5,ID(1,5,'p'),Block(1,6)))],
  [['q<!--p{}'], Rules(1,0,Q(1,1,ID(1,1,'q'),CDO(1,2),ID(1,6,'p'),Block(1,7)))],
  [['aa-->'], Rules(1,0), '1;6;css:qrule:no block'],
  [['{}-->'], Rules(1,0,Q(1,1,Block(1,1)))],
  [['{}-->{}'], Rules(1,0,Q(1,1,Block(1,1)),Q(1,6,Block(1,6)))],
  [['}ab{}'], Rules(1,0,Q(1,1,RBrace(1,1),ID(1,2,'ab'),Block(1,4)))],
  [['@hoge'], Rules(1,0,At(1,1,'hoge')), '1;6;css:at-rule:eof'],
  [['@hoge;'], Rules(1,0,At(1,1,'hoge'))],
  [['@hoge/**/foo 12;'], Rules(1,0,At(1,1,'hoge',ID(1,10,'foo'),S(1,13),N(1,14,12)))],
  [['@hoge[foo]12;'], Rules(1,0,At(1,1,'hoge',Box(1,6,ID(1,7,'foo')),N(1,11,12)))],
  [['@hoge[foo;1]12;'], Rules(1,0,At(1,1,'hoge',Box(1,6,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  [['@hoge[foo;1]12;<!--'], Rules(1,0,At(1,1,'hoge',Box(1,6,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  [['@hoge(foo;1)12;<!--'], Rules(1,0,At(1,1,'hoge',Paren(1,6,ID(1,7,'foo'),Semi(1,10),N(1,11,1)),N(1,13,12)))],
  [['@hoge aa(foo;1)12;<!--'], Rules(1,0,At(1,1,'hoge',S(1,6),F(1,7,'aa',ID(1,10,'foo'),Semi(1,13),N(1,14,1)),N(1,16,12)))],
  [['@hoge{foo}12;'], Rules(1,0,At(1,1,'hoge',Block(1,6,ID(1,7,'foo')))), '1;14;css:qrule:no block'],
  [['@hoge{foo{}}12;'], Rules(1,0,At(1,1,'hoge',Block(1,6,ID(1,7,'foo'),Block(1,10)))), '1;16;css:qrule:no block'],
  [['@', '', 'hoge{', '', 'foo{', '', '}}12', '', ';'], Rules(1,0,At(1,1,'hoge',Block(1,6,ID(1,7,'foo'),Block(1,10)))), '1;16;css:qrule:no block'],
  [['@aaa[12'], Rules(1,0,At(1,1,'aaa',Box(1,5,N(1,6,12)))), '1;8;css:block:eof'],
  [['@aaa(12'], Rules(1,0,At(1,1,'aaa',Paren(1,5,N(1,6,12)))), '1;8;css:block:eof'],
  [['@aaa{12'], Rules(1,0,At(1,1,'aaa',Block(1,5,N(1,6,12)))), '1;8;css:block:eof'],
  [['@aa h(12'], Rules(1,0,At(1,1,'aa',S(1,4),F(1,5,'h',N(1,7,12)))), '1;9;css:block:eof'],
  [['@aa{h(12'], Rules(1,0,At(1,1,'aa',Block(1,4,F(1,5,'h',N(1,7,12))))), '1;9;css:block:eof'],
  [['@aa{h("12'], Rules(1,0,At(1,1,'aa',Block(1,4,F(1,5,'h',Str(1,7,'12'))))), '1;10;css:string:eof'],
  [['@aa{url(12'], Rules(1,0,At(1,1,'aa',Block(1,4,URL(1,5,'12')))), '1;11;css:url:eof'],
  [['ab{'], Rules(1,0,Q(1,1,ID(1,1,'ab'),Block(1,3))), '1;4;css:block:eof'],
  [['hoge (ab { ) cd }) 2 {}'], Rules(1,0,Q(1,1,ID(1,1,'hoge'),S(1,5),Paren(1,6,ID(1,7,'ab'),S(1,9),Block(1,10,S(1,11),RParen(1,12),S(1,13),ID(1,14,'cd'),S(1,16))),S(1,19),N(1,20,2),S(1,21),Block(1,22)))],
  [[':hoge(ab { ) cd }) 2 {}'], Rules(1,0,Q(1,1,Colon(1,1),F(1,2,'hoge',ID(1,7,'ab'),S(1,9),Block(1,10,S(1,11),RParen(1,12),S(1,13),ID(1,14,'cd'),S(1,16))),S(1,19),N(1,20,2),S(1,21),Block(1,22)))],
  [['@ab{co{}}'], Rules(1,0,At(1,1,'ab',Block(1,4,ID(1,5,'co'),Block(1,7))))],
  [['@media{co{}}'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'co'),Block(1,10)))))],
  [['@media{co{}'], Rules(1,0,At(1,1,'media',Block(1,7,Q(1,8,ID(1,8,'co'),Block(1,10))))), '1;12;css:block:eof'],
  [['@MedIA{co{}}'], Rules(1,0,At(1,1,'MedIA',Block(1,7,Q(1,8,ID(1,8,'co'),Block(1,10)))))],
  [['@MedIA{@media{co{'], Rules(1,0,At(1,1,'MedIA',Block(1,7,At(1,8,'media',Block(1,14,Q(1,15,ID(1,15,'co'),Block(1,17))))))), '1;18;css:block:eof'],
  [['@MedIA{@media{co{}}'], Rules(1,0,At(1,1,'MedIA',Block(1,7,At(1,8,'media',Block(1,14,Q(1,15,ID(1,15,'co'),Block(1,17))))))), '1;20;css:block:eof'],
  [['@MedIA{@media{co{}}}'], Rules(1,0,At(1,1,'MedIA',Block(1,7,At(1,8,'media',Block(1,14,Q(1,15,ID(1,15,'co'),Block(1,17)))))))],
  [['@MedIA{@-moz-Document{co{}}}'], Rules(1,0,At(1,1,'MedIA',Block(1,7,At(1,8,'-moz-Document',Block(1,22,Q(1,23,ID(1,23,'co'),Block(1,25)))))))],
  [['@keyframes{@media{co{}}}'], Rules(1,0,At(1,1,'keyframes',Block(1,11,At(1,12,'media',Block(1,18,Q(1,19,ID(1,19,'co'),Block(1,21)))))))],
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
      my @s = @{$test->[0]};
      $b->{chars_pull_next} = sub {
        my $s = shift @s;
        push @{$b->{chars}}, split //, $s if defined $s;
        return defined $s;
      };
      $b->init_tokenizer;
      $b->init_builder;
    }

    $b->start_building_style_sheet or do {
      1 while not $b->continue_building;
    };

    eq_or_diff $b->{parsed_construct}, $test->[1], 'tree';
    eq_or_diff $errors, $test->[2] || [], 'errors';

    done $c;
  } name => ['tree building', @{$test->[0]}], n => 2;
} # $test

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
