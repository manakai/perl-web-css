use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Web::CSS::Context;

test {
  my $c = shift;
  my $ctx = Web::CSS::Context->new_empty;
  ok not $ctx->has_namespace;
  is $ctx->get_url_by_prefix (undef), undef;
  is $ctx->get_url_by_prefix (''), undef;
  is $ctx->get_url_by_prefix ('xml'), undef;
  is $ctx->get_url_by_prefix ('xmlns'), undef;
  is $ctx->get_prefix_by_url (undef), undef;
  is $ctx->get_prefix_by_url (''), undef;
  is $ctx->get_prefix_by_url ('http://hoge/'), undef;
  done $c;
} n => 8, name => 'new_empty';

test {
  my $c = shift;
  my $ctx = Web::CSS::Context->new_from_nsmaps
      ({ab => 'http://hoge/'}, {'http://' => ['De', 'cc']});
  ok $ctx->has_namespace;
  is $ctx->get_url_by_prefix (undef), undef;
  is $ctx->get_url_by_prefix (''), undef;
  is $ctx->get_url_by_prefix ('xml'), undef;
  is $ctx->get_url_by_prefix ('ab'), 'http://hoge/';
  is $ctx->get_prefix_by_url (undef), undef;
  is $ctx->get_prefix_by_url (''), undef;
  is $ctx->get_prefix_by_url ('http://hoge/'), undef;
  is $ctx->get_prefix_by_url ('http://'), 'cc';
  done $c;
} n => 9, name => 'new_from_nsmaps';

test {
  my $c = shift;
  my $ctx = Web::CSS::Context->new_from_nscallback (sub {
    if (defined $_[0] and $_[0] eq 'ab') {
      return 'http://hoge/';
    }
    return undef;
  });
  ok $ctx->has_namespace;
  is $ctx->get_url_by_prefix (undef), undef;
  is $ctx->get_url_by_prefix (''), undef;
  is $ctx->get_url_by_prefix ('xml'), undef;
  is $ctx->get_url_by_prefix ('ab'), 'http://hoge/';
  is $ctx->get_prefix_by_url (undef), undef;
  is $ctx->get_prefix_by_url (''), undef;
  is $ctx->get_prefix_by_url ('http://hoge/'), undef;
  is $ctx->get_prefix_by_url ('http://'), undef;
  done $c;
} n => 9, name => 'new_from_callback';

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
