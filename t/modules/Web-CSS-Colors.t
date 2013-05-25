use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Web::CSS::Colors;
use Test::More;
use Test::Differences;

test {
  my $c = shift;
  eq_or_diff $Web::CSS::Colors::X11Colors->{red}, [0xFF, 0, 0];
  eq_or_diff $Web::CSS::Colors::X11Colors->{gray}, [0x80, 0x80, 0x80];
  eq_or_diff $Web::CSS::Colors::X11Colors->{grey}, [0x80, 0x80, 0x80];
  is $Web::CSS::Colors::X11Colors->{RED}, undef;
  is $Web::CSS::Colors::X11Colors->{unknown}, undef;
  done $c;
} n => 5, name => 'x11 colors';

test {
  my $c = shift;
  ok $Web::CSS::Colors::SystemColors->{activeborder};
  ok !$Web::CSS::Colors::SystemColors->{ActiveBorder};
  ok !$Web::CSS::Colors::SystemColors->{unknown};
  done $c;
} n => 3, name => 'system colors';

run_tests;

=head1 LICENSE

Copyright 2010-2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
