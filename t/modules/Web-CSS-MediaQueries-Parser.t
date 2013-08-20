use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::CSS::MediaQueries::Parser;

for my $test (
  {in => '', out => []},
  {in => 'screen,Hoge',
   out => [{type => 'screen', type_line => 1, type_column => 1},
           {type => 'hoge', type_line => 1, type_column => 8}]},
  {in => 'screen(),Hoge',
   out => [{not => 1, type => 'all'},
           {type => 'hoge', type_line => 1, type_column => 10}],
   errors => ['1;1;m;mq:broken;;']},
) {
  test {
    my $c = shift;
    my $p = Web::CSS::MediaQueries::Parser->new;
    my @error;
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
    my $parsed = $p->parse_char_string_as_mq_list ($test->{in});
    eq_or_diff $parsed, $test->{out};
    eq_or_diff \@error, $test->{errors} || [];
    done $c;
  } n => 2, name => ['parse_char_string_as_mq_list', $test->{in}];
}

for my $test (
  {in => '', out => {not => 1, type => 'all'},
   errors => ['1;1;m;mq:empty;;']},
  {in => 'screen',
   out => {type => 'screen', type_line => 1, type_column => 1}},
  {in => 'screen,Hoge',
   out => undef,
   errors => ['1;1;m;mq:multiple;;']},
  {in => 'screen(),Hoge',
   out => undef,
   errors => ['1;1;m;mq:broken;;', '1;1;m;mq:multiple;;']},
) {
  test {
    my $c = shift;
    my $p = Web::CSS::MediaQueries::Parser->new;
    my @error;
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
    my $parsed = $p->parse_char_string_as_mq ($test->{in});
    eq_or_diff $parsed, $test->{out};
    eq_or_diff \@error, $test->{errors} || [];
    done $c;
  } n => 2, name => ['parse_char_string_as_mq', $test->{in}];
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
