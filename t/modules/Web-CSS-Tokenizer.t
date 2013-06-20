use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Web::CSS::Tokenizer;
use Test::More;
use Test::Differences;

sub S ($) { [$_[0], S_TOKEN] }
sub Delim ($$) { [$_[0], DELIM_TOKEN, $_[1]] }
sub Abort () { [undef, ABORT_TOKEN] }

for my $test (
  [[''] => []],
  [['hoge'] => [[1, IDENT_TOKEN, 'hoge']]],
  [['\\'] => [Delim(1,'\\')]],
  [['-\\'] => [[1, MINUS_TOKEN], Delim(2,'\\')]],
  [[" \x0C"] => [[1, S_TOKEN]]],
  [["\x09+"] => [S(1), [2, PLUS_TOKEN]]],
  [[' ', ' '] => [S(1), S(2)]],
  [[' ', '', ' '] => [[1, S_TOKEN], Abort, S(2)]],
  [['"aa'] => ['4;css:string:eof', [1, STRING_TOKEN, 'aa']]],
  [["'aa"] => ['4;css:string:eof', [1, STRING_TOKEN, 'aa']]],
  [['"aa"'] => [[1, STRING_TOKEN, 'aa']]],
  [["'aa'"] => [[1, STRING_TOKEN, 'aa']]],
  [["'aa\x0A"] => ['4;css:string:newline', [1, INVALID_TOKEN, 'aa'], S(4)]],
  [["\"aa\x0C"] => ['4;css:string:newline', [1, INVALID_TOKEN, 'aa'], S(4)]],
  [['"aa\\'] => ['4;css:escape:broken', [1, INVALID_TOKEN, 'aa']]],
  [['#'] => [Delim(1,'#')]],
  [['#\\'] => [Delim(1,'#'), Delim(2,'\\')]],
  [['#\\x'] => [[1, HASH_TOKEN, 'x', 'id']]],
  [['#-\\'] => [[1, HASH_TOKEN, '-', ''], Delim(3,'\\')]],
  [['#--'] => [[1, HASH_TOKEN, '--', '']]],
  [['#-\\-'] => [[1, HASH_TOKEN, '--', 'id']]],
  [['#-a'] => [[1, HASH_TOKEN, '-a', 'id']]],
  [['#-\\z'] => [[1, HASH_TOKEN, '-z', 'id']]],
) {
  for (@{$test->[1]}) {
    next unless ref $_;
    my $f = $_->[3];
    $_ = {line => 1, column => $_->[0], type => $_->[1], value => $_->[2]};
    delete $_->{line} if $_->{type} == ABORT_TOKEN;
    delete $_->{value} unless defined $_->{value};
    if ($_->{type} == HASH_TOKEN) {
      $_->{not_ident} = 1 if not $f;
    }
  }
  test {
    my $c = shift;

    my $tokens = [];
    my $tt = do {
      my @s = @{$test->[0]};
      my $s = shift @s;
      pos $s = 0;
      my $column = 1;
      my $tt = Web::CSS::Tokenizer->new;
      $tt->onerror (sub {
        my %args = @_;
        push @$tokens, $args{column} . ';' . $args{type};
      });
      $tt->{get_char} = sub ($) {
        if (defined $s and (pos $s < length $s)) {
          my $c = ord substr $s, pos ($s)++, 1;
          $_[0]->{line_prev} = 1;
          $_[0]->{column_prev} = $_[0]->{column};
          $_[0]->{line} = 1;
          $_[0]->{column} = $column++;
          return $c;
        } elsif (defined $s) {
          $s = shift @s;
          pos $s = 0 if defined $s;
          return -3; # ABORT_CHAR
        } else {
          $_[0]->{line_prev} = 1;
          $_[0]->{column_prev} = $_[0]->{column};
          $_[0]->{line} = 1;
          $_[0]->{column} = $column++;
          return -1;
        }
      }; # $tt->{get_char}
      $tt->{line} = 1;
      $tt->{column} = $column;
      $tt->init_tokenizer;
      $tt;
    };

    {
      my $t = $tt->get_next_token;
      last if $t->{type} == EOF_TOKEN;
      delete $t->{hyphen};
      delete $t->{has_escape};
      push @$tokens, $t;
      redo;
    }
    eq_or_diff $tokens, $test->[1];

    done $c;
  } n => 1, name => [@{$test->[0]}];
}

run_tests;
