use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Web::CSS::MediaQueries::Serializer;

for my $test (
  {in => {type => 'hoge'}, out => 'hoge'},
  {in => {type => 'h"oge'."\x0f"}, out => 'h\\"oge\\f '},
  {in => {type => 'h"oge'."\x0f\x0A "}, out => 'h\\"oge\\f \\a \\ '},
  {in => {type => 'hoge', only => 1}, out => 'only hoge'},
  {in => {type => 'hoge', not => 1,
          features => [{name => 'width',
                        value => ['LENGTH', '12.1', 'px']}]},
   out => 'not hoge and (width: 12.1px)'},
  {in => {type => 'hoge', not => 1,
          features => [{name => 'max-width',
                        value => ['LENGTH', '12.1', 'px']},
                       {name => 'resolution'}]},
   out => 'not hoge and (max-width: 12.1px) and (resolution)'},
  {in => {features => [{name => 'max-width',
                        value => ['LENGTH', '12.1', 'px']},
                       {name => 'resolution'}]},
   out => '(max-width: 12.1px) and (resolution)'},
) {
  test {
    my $c = shift;
    my $s = Web::CSS::MediaQueries::Serializer->new;
    is $s->serialize_mq ($test->{in}), $test->{out};
    done $c;
  } n => 1, name => ['serialize_mq', $test->{out}];
}

for my $test (
  {in => [],
   out => ''},
  {in => [{only => 1, type => '"'}],
   out => 'only \\"'},
  {in => [{type => 'hoge'}, {not => 1, type => 'a'}],
   out => 'hoge, not a'},
  {in => [{type => 'hoge'}, {not => 1, type => 'a',
                             features => [{name => 'height'}]}],
   out => 'hoge, not a and (height)'},
) {
  test {
    my $c = shift;
    my $s = Web::CSS::MediaQueries::Serializer->new;
    is $s->serialize_mq_list ($test->{in}), $test->{out};
    done $c;
  } n => 1, name => ['serialize_mq_list', $test->{out}];
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
