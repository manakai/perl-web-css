use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::CSS::MediaResolver;

test {
  my $c = shift;
  my $ctx = Web::CSS::MediaResolver->new;

  my $value = ['RGBA', 1000, -24, 40.5, 10.2];
  my $value2 = $ctx->clip_color ($value);
  isnt $value2, $value;
  eq_or_diff $value2, ['RGBA', 255, 0, 40.5, 10.2];

  done $c;
} n => 2, name => 'clip_color';

test {
  my $c = shift;
  my $ctx = Web::CSS::MediaResolver->new;

  my $value = ['notRGBA', 1000, -24, 40.5, 10.2];
  my $value2 = $ctx->clip_color ($value);
  is $value2, $value;

  done $c;
} n => 1, name => 'clip_color not rgba';

test {
  my $c = shift;
  my $ctx = Web::CSS::MediaResolver->new;

  my $value = {hoge => 'abc'};
  my $value2 = $ctx->get_system_font ($value);
  is $value, $value;

  done $c;
} n => 1, name => 'get_system_font';

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
