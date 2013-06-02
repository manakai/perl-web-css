use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Web::CSS::Parser;
use Test::More;
use Test::Differences;

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  $parser->parse_char_string ('');
  my $result = $parser->parsed;
  is scalar @{$result->{sheets}}, 1;
  eq_or_diff $result->{sheets}->[0]->{rules}, [];
  is ${$result->{sheets}->[0]->{base_urlref}}, 'about:blank';
  is scalar @{$result->{rules}}, 0;
  done $c;
} n => 4, name => 'parse_char_string empty string';

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  $parser->parse_char_string ('@charset "utf-8";');
  my $result = $parser->parsed;
  is scalar @{$result->{sheets}}, 1;
  eq_or_diff $result->{sheets}->[0]->{rules}, [0];
  is ${$result->{sheets}->[0]->{base_urlref}}, 'about:blank';
  is scalar @{$result->{rules}}, 1;
  is $result->{rules}->[0]->{type}, '@charset';
  is $result->{rules}->[0]->{encoding}, 'utf-8';
  done $c;
} n => 6, name => 'parse_char_string @charset';

test {
  my $c = shift;
  my $parser = Web::CSS::Parser->new;
  $parser->{prop}->{color} = 1;
  $parser->{prop}->{'font-size'} = 1;
  $parser->parse_char_string ('p { color : blue; opacity: 0; font-size: small }');
  my $result = $parser->parsed;
  is scalar @{$result->{sheets}}, 1;
  eq_or_diff $result->{sheets}->[0]->{rules}, [0];
  is ${$result->{sheets}->[0]->{base_urlref}}, 'about:blank';
  is scalar @{$result->{rules}}, 1;
  is $result->{rules}->[0]->{type}, 'style';
  eq_or_diff $result->{rules}->[0]->{style},
      {props => {color => [[KEYWORD => 'blue'], ''],
                 font_size => [[KEYWORD => 'small'], '']},
       prop_names => ['color', 'font_size']};
  done $c;
} n => 6, name => 'parse_char_string style declarations';

test {
  my $c = shift;
  my $p = Web::CSS::Parser->new;
  $p->context->url ('hoge://fuga');
  my @url;
  $p->{onerror} = sub {
    my %args = @_;
    push @url, ${$args{uri}};
  };
  $p->parse_char_string ('& { } @hoge; @media abc { }');

  eq_or_diff \@url, ['hoge://fuga', 'hoge://fuga', 'hoge://fuga'];

  done $c;
} n => 1, name => 'context->url';

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
