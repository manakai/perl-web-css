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
  [['#1235'] => [[1, HASH_TOKEN, '1235', '']]],
  [['#z1235'] => [[1, HASH_TOKEN, 'z1235', 'id']]],
  [['#\\1235'] => [[1, HASH_TOKEN, "\x{1235}", 'id']]],
  [["#\\\x0A1235"] => [Delim(1, '#'), Delim(2, '\\'), S(3), [4, NUMBER_TOKEN, '1235']]],
  [['$'] => [Delim(1, '$')]],
  [['$ab'] => [Delim(1, '$'), [2, IDENT_TOKEN, 'ab']]],
  [['$='] => [[1, SUFFIXMATCH_TOKEN]]],
  [['$=ab'] => [[1, SUFFIXMATCH_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['^'] => [Delim(1, '^')]],
  [['^ab'] => [Delim(1, '^'), [2, IDENT_TOKEN, 'ab']]],
  [['^='] => [[1, PREFIXMATCH_TOKEN]]],
  [['^=ab'] => [[1, PREFIXMATCH_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['*'] => [[1, STAR_TOKEN]]],
  [['*ab'] => [[1, STAR_TOKEN], [2, IDENT_TOKEN, 'ab']]],
  [['*='] => [[1, SUBSTRINGMATCH_TOKEN]]],
  [['*=ab'] => [[1, SUBSTRINGMATCH_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['|'] => [[1, VBAR_TOKEN]]],
  [['|ab'] => [[1, VBAR_TOKEN], [2, IDENT_TOKEN, 'ab']]],
  [['|='] => [[1, DASHMATCH_TOKEN]]],
  [['|=ab'] => [[1, DASHMATCH_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['('] => [[1, LPAREN_TOKEN]]],
  [[')'] => [[1, RPAREN_TOKEN]]],
  [['(('] => [[1, LPAREN_TOKEN], [2, LPAREN_TOKEN]]],
  [[')a'] => [[1, RPAREN_TOKEN], [2, IDENT_TOKEN, 'a']]],
  [['+'] => [[1, PLUS_TOKEN]]],
  [['+.'] => [[1, PLUS_TOKEN], [2, DOT_TOKEN]]],
  [['+120'] => [[1, NUMBER_TOKEN, '+120']]],
  [['+1.20'] => [[1, NUMBER_TOKEN, '+1.20']]],
  [['+.20'] => [[1, NUMBER_TOKEN, '+.20']]],
  [['+.1234567'] => [[1, NUMBER_TOKEN, '+.1234567']]],
  [['+.+'] => [[1, PLUS_TOKEN], [2, DOT_TOKEN], [3, PLUS_TOKEN]]],
  [[','] => [[1, COMMA_TOKEN]]],
  [[',,'] => [[1, COMMA_TOKEN], [2, COMMA_TOKEN]]],
  [['-'] => [[1, MINUS_TOKEN]]],
  [['-910'] => [[1, NUMBER_TOKEN, '-910']]],
  [['-.'] => [[1, MINUS_TOKEN], [2, DOT_TOKEN]]],
  [['-.12'] => [[1, NUMBER_TOKEN, '-.12']]],
  [['-00.12'] => [[1, NUMBER_TOKEN, '-00.12']]],
  [['-910\\a'] => [[1, DIMENSION_TOKEN, '-910', "\x0A"]]],
  [['-a'] => [[1, IDENT_TOKEN, '-a']]],
  [['-\\'] => [[1, MINUS_TOKEN], [2, DELIM_TOKEN, '\\']]],
  [["-\\\x0Ac"] => [[1, MINUS_TOKEN], [2, DELIM_TOKEN, '\\'], S(3), [4, IDENT_TOKEN, 'c']]],
  [['-\\-'] => [[1, IDENT_TOKEN, '--']]],
  [['-abc'] => [[1, IDENT_TOKEN, '-abc']]],
  [['--120'] => [[1, MINUS_TOKEN], [2, NUMBER_TOKEN, '-120']]],
  [['--a'] => [[1, MINUS_TOKEN], [2, IDENT_TOKEN, '-a']]],
  [['----'] => [[1, MINUS_TOKEN], [2, MINUS_TOKEN], [3, MINUS_TOKEN], [4, MINUS_TOKEN]]],
  [['----a'] => [[1, MINUS_TOKEN], [2, MINUS_TOKEN], [3, MINUS_TOKEN], [4, IDENT_TOKEN, '-a']]],
  [['-->'] => [[1, CDC_TOKEN]]],
  [['-->-'] => [[1, CDC_TOKEN], [4, MINUS_TOKEN]]],
  [['-->-a'] => [[1, CDC_TOKEN], [4, IDENT_TOKEN, '-a']]],
  [['-', '->'] => [[1, CDC_TOKEN]]],
  [['-', '\\->'] => [[1, IDENT_TOKEN, '--'], [4, GREATER_TOKEN]]],
  [['-', '-', '>'] => [[1, CDC_TOKEN]]],
  [['abc-->'] => [[1, IDENT_TOKEN, 'abc--'], [6, GREATER_TOKEN]]],
  [['.'] => [[1, DOT_TOKEN]]],
  [['..'] => [[1, DOT_TOKEN], [2, DOT_TOKEN]]],
  [['.12'] => [[1, NUMBER_TOKEN, '.12']]],
  [['.12.4'] => [[1, NUMBER_TOKEN, '.12'], [4, NUMBER_TOKEN, '.4']]],
  [['.12.a'] => [[1, NUMBER_TOKEN, '.12'], [4, DOT_TOKEN], [5, IDENT_TOKEN, 'a']]],
  [['..4'] => [[1, DOT_TOKEN], [2, NUMBER_TOKEN, '.4']]],
  [['.+4'] => [[1, DOT_TOKEN], [2, NUMBER_TOKEN, '+4']]],
  [['/'] => [Delim(1,'/')]],
  [['/', '**/a'] => [[5, IDENT_TOKEN, 'a']]],
  [['/*/a'] => []],
  [['/*/a', '*/a'] => [[7, IDENT_TOKEN, 'a']]],
  [['/**/a'] => [[5, IDENT_TOKEN, 'a']]],
  [['/**/', 'a'] => [[5, IDENT_TOKEN, 'a']]],
  [['/****/', 'a'] => [[7, IDENT_TOKEN, 'a']]],
  [['/* a** b*/', 'a'] => [[11, IDENT_TOKEN, 'a']]],
  [['/* a**/ b'] => [S(8), [9, IDENT_TOKEN, 'b']]],
  [['/***'] => []],
  [['/* a**', '**/b'] => [[10, IDENT_TOKEN, 'b']]],
  [['/*', '*/a'] => [[5, IDENT_TOKEN, 'a']]],
  [['/**', '/a'] => [[5, IDENT_TOKEN, 'a']]],
  [[':'] => [[1, COLON_TOKEN]]],
  [['::'] => [[1, COLON_TOKEN], [2, COLON_TOKEN]]],
  [[';'] => [[1, SEMICOLON_TOKEN]]],
  [[';:'] => [[1, SEMICOLON_TOKEN], [2, COLON_TOKEN]]],
  [['<!--'] => [[1, CDO_TOKEN]]],
  [['<', '!--'] => [[1, CDO_TOKEN]]],
  [['<!', '--'] => [[1, CDO_TOKEN]]],
  [['<!-', '-'] => [[1, CDO_TOKEN]]],
  [['<!--a'] => [[1, CDO_TOKEN], [5, IDENT_TOKEN, 'a']]],
  [['<abc'] => [Delim(1,'<'), [2, IDENT_TOKEN, 'abc']]],
  [['<!abc'] => [Delim(1,'<'), [2, EXCLAMATION_TOKEN], [3, IDENT_TOKEN, 'abc']]],
  [['<!-'] => [Delim(1,'<'), [2, EXCLAMATION_TOKEN], [3, MINUS_TOKEN]]],
  [['<!-/**/-'] => [Delim(1,'<'), [2, EXCLAMATION_TOKEN], [3, MINUS_TOKEN], [8, MINUS_TOKEN]]],
  [['<!-a'] => [Delim(1,'<'), [2, EXCLAMATION_TOKEN], [3, IDENT_TOKEN, '-a']]],
  [['<!-12'] => [Delim(1,'<'), [2, EXCLAMATION_TOKEN], [3, NUMBER_TOKEN, '-12']]],
  [['<!---->'] => [[1, CDO_TOKEN], [5, CDC_TOKEN]]],
  [['<!----->'] => [[1, CDO_TOKEN], [5, MINUS_TOKEN], [6, CDC_TOKEN]]],
  [['@'] => [Delim(1,'@')]],
  [['@a'] => [[1, ATKEYWORD_TOKEN, 'a']]],
  [['@', 'a'] => [[1, ATKEYWORD_TOKEN, 'a']]],
  [['@a-->'] => [[1, ATKEYWORD_TOKEN, 'a--'], [5, GREATER_TOKEN]]],
  [['@-'] => [Delim(1,'@'), [2, MINUS_TOKEN]]],
  [['@--'] => [Delim(1,'@'), [2, MINUS_TOKEN], [3, MINUS_TOKEN]]],
  [['@-', '-'] => [Delim(1,'@'), [2, MINUS_TOKEN], [3, MINUS_TOKEN]]],
  [['@-a'] => [[1, ATKEYWORD_TOKEN, '-a']]],
  [['@-\\a'] => [[1, ATKEYWORD_TOKEN, "-\x0A"]]],
  [['@-\\', 'a'] => [[1, ATKEYWORD_TOKEN, "-\x0A"]]],
  [['@\\--'] => [[1, ATKEYWORD_TOKEN, "--"]]],
  [['@-->'] => [Delim(1,'@'), [2, CDC_TOKEN]]],
  [['@--120'] => [Delim(1,'@'), [2, MINUS_TOKEN], [3, NUMBER_TOKEN, '-120']]],
  [['@-120'] => [Delim(1,'@'), [2, NUMBER_TOKEN, '-120']]],
  [['@--abc'] => [Delim(1,'@'), [2, MINUS_TOKEN], [3, IDENT_TOKEN, '-abc']]],
  [['@--\\abc'] => [Delim(1,'@'), [2, MINUS_TOKEN], [3, IDENT_TOKEN, "-\x{abc}"]]],
  [['['] => [[1, LBRACKET_TOKEN]]],
  [[']'] => [[1, RBRACKET_TOKEN]]],
  [['{'] => [[1, LBRACE_TOKEN]]],
  [['}'] => [[1, RBRACE_TOKEN]]],

  # XXX 120--> 31ab-->
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
    if ($_->{type} == NUMBER_TOKEN) {
      $_->{number} = delete $_->{value};
      $_->{value} = '';
    }
    if ($_->{type} == DIMENSION_TOKEN) {
      $_->{number} = $_->{value};
      $_->{value} = $f;
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
      delete $t->{hyphen}; # XXX
      delete $t->{has_escape}; # XXX
      push @$tokens, $t;
      redo;
    }
    eq_or_diff $tokens, $test->[1];

    done $c;
  } n => 1, name => [@{$test->[0]}];
}

run_tests;
