use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::Differences;
use Test::HTCT::Parser;

use Web::CSS::MediaQueries::Parser;
use Web::CSS::MediaQueries::Serializer;

my $data_d = file (__FILE__)->dir->parent->parent->subdir
    ('t_deps', 'tests', 'css', 'mq', 'syntax');

my $p = Web::CSS::MediaQueries::Parser->new;
my $s = Web::CSS::MediaQueries::Serializer->new;

for my $file_name (qw(mq-1.dat)) {
  for_each_test $data_d->file ($file_name)->stringify, {
    data => {is_prefixed => 1},
    errors => {is_list => 1},
    mediatext => {is_prefixed => 1},
  }, sub {
    my $test = shift;
    test {
      my $c = shift;

      my @actual_error;
      $p->{onerror} = sub {
        my (%opt) = @_;
        push @actual_error, join ';',
            '', $opt{token}->{line}, $opt{token}->{column},
            $opt{level},
            $opt{type} . (defined $opt{value} ? ';'.$opt{value} : '');
      };

      my $mq = $p->parse_char_string ($test->{data}->[0]);

      eq_or_diff \@actual_error, $test->{errors}->[0] // [], "#result";

      my $mt = $s->serialize_media_query ($mq);
      eq_or_diff $mt, $test->{mediatext}->[0], "#mediatext";

      done $c;
    } n => 2, name => ['p/s', $test->{data}->[0]];
  };
}

run_tests;

=head1 LICENSE

Copyright 2008-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
