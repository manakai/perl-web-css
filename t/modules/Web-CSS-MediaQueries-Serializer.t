use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Web::CSS::MediaQueries::Serializer;

test {
  my $c = shift;
  my $s = Web::CSS::MediaQueries::Serializer->new;
  is $s->serialize_media_query (undef), undef;
  done $c;
} n => 1, name => 'serialize_media_query undef';

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
