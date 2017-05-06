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
sub ID ($$) { [$_[0], IDENT_TOKEN, $_[1]] }
sub N ($$) { [$_[0], NUMBER_TOKEN, $_[1]] }
sub Dim ($$$) { [$_[0], DIMENSION_TOKEN, $_[1], $_[2]] }
sub Minus ($) { [$_[0], MINUS_TOKEN] }
sub BS ($) { Delim($_[0],'\\') }
sub Abort () { [undef, ABORT_TOKEN] }

for my $test (
  [[''] => []],
  [['hoge'] => [[1, IDENT_TOKEN, 'hoge']]],
  [['-hoge'] => [[1, IDENT_TOKEN, '-hoge']]],
  [["\x80hoge"] => [[1, IDENT_TOKEN, "\x80hoge"]]],
  [['-\\'] => ['1;2;css:escape:broken', [1, IDENT_TOKEN, "-\x{FFFD}"]]],
  [[" \x0C"] => [[1, S_TOKEN]]],
  [["\x09+"] => [S(1), [2, PLUS_TOKEN]]],
  [[' ', ' '] => [S(1), S(2)]],
  [[' ', '', ' '] => [S(1), Abort, S(2)]],
  [['"aa'] => ['1;4;css:string:eof', [1, STRING_TOKEN, 'aa']]],
  [["'aa"] => ['1;4;css:string:eof', [1, STRING_TOKEN, 'aa']]],
  [['"aa"'] => [[1, STRING_TOKEN, 'aa']]],
  [["'aa'"] => [[1, STRING_TOKEN, 'aa']]],
  [["'aa\x0A"] => ['2;0;css:string:newline', [1, INVALID_TOKEN], S([2,0])]],
  [["\"aa\x0C"] => ['2;0;css:string:newline', [1, INVALID_TOKEN], S([2,0])]],
  [["\"aa\\\x0A"] => ['2;1;css:string:eof', [1, STRING_TOKEN, 'aa']]],
  [['"aa\\'] => ['1;4;css:escape:broken', '1;5;css:string:eof', [1, STRING_TOKEN, "aa\x{FFFD}"]]],
  [["'aa\x0C"] => ['2;0;css:string:newline', [1, INVALID_TOKEN], S([2,0])]],
  [["'aa\\\x0A"] => ['2;1;css:string:eof', [1, STRING_TOKEN, 'aa']]],
  [["'aa\\"] => ['1;4;css:escape:broken', '1;5;css:string:eof', [1, STRING_TOKEN, "aa\x{FFFD}"]]],
  [['#'] => [Delim(1,'#')]],
  [['#\\'] => ['1;2;css:escape:broken', [1, HASH_TOKEN, "\x{FFFD}", 'id']]],
  [['#\\x'] => [[1, HASH_TOKEN, 'x', 'id']]],
  [['#-\\'] => ['1;3;css:escape:broken', [1, HASH_TOKEN, "-\x{FFFD}", 'id']]],
  [['#--'] => [[1, HASH_TOKEN, '--', '']]],
  [['#-\\-'] => [[1, HASH_TOKEN, '--', 'id']]],
  [['#-a'] => [[1, HASH_TOKEN, '-a', 'id']]],
  [['#-\\z'] => [[1, HASH_TOKEN, '-z', 'id']]],
  [['#1235'] => [[1, HASH_TOKEN, '1235', '']]],
  [['#z1235'] => [[1, HASH_TOKEN, 'z1235', 'id']]],
  [['#_z1235'] => [[1, HASH_TOKEN, '_z1235', 'id']]],
  [['#\\1235'] => [[1, HASH_TOKEN, "\x{1235}", 'id']]],
  [["#\\\x0A1235"] => ['1;2;css:escape:broken', Delim(1, '#'), Delim(2, '\\'), S([2,0]), [[2,1], NUMBER_TOKEN, '1235']]],
  [['$'] => [Delim(1, '$')]],
  [['$ab'] => [Delim(1, '$'), [2, IDENT_TOKEN, 'ab']]],
  [['$='] => [[1, SUFFIXMATCH_TOKEN]]],
  [['$', '='] => [[1, SUFFIXMATCH_TOKEN]]],
  [['$=ab'] => [[1, SUFFIXMATCH_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['^'] => [Delim(1, '^')]],
  [['^ab'] => [Delim(1, '^'), [2, IDENT_TOKEN, 'ab']]],
  [['^='] => [[1, PREFIXMATCH_TOKEN]]],
  [['^', '='] => [[1, PREFIXMATCH_TOKEN]]],
  [['^=ab'] => [[1, PREFIXMATCH_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['*'] => [[1, STAR_TOKEN]]],
  [['*ab'] => [[1, STAR_TOKEN], [2, IDENT_TOKEN, 'ab']]],
  [['*='] => [[1, SUBSTRINGMATCH_TOKEN]]],
  [['*', '='] => [[1, SUBSTRINGMATCH_TOKEN]]],
  [['*=ab'] => [[1, SUBSTRINGMATCH_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['*|=ab'] => [[1, STAR_TOKEN], [2, DASHMATCH_TOKEN], [4, IDENT_TOKEN, 'ab']]],
  [['|'] => [[1, VBAR_TOKEN]]],
  [['|ab'] => [[1, VBAR_TOKEN], [2, IDENT_TOKEN, 'ab']]],
  [['|='] => [[1, DASHMATCH_TOKEN]]],
  [['|=ab'] => [[1, DASHMATCH_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['||=ab'] => [[1, COLUMN_TOKEN], [3, MATCH_TOKEN], [4, IDENT_TOKEN, 'ab']]],
  [['~'] => [[1, TILDE_TOKEN]]],
  [['~ab'] => [[1, TILDE_TOKEN], [2, IDENT_TOKEN, 'ab']]],
  [['~='] => [[1, INCLUDES_TOKEN]]],
  [['~', '='] => [[1, INCLUDES_TOKEN]]],
  [['~=ab'] => [[1, INCLUDES_TOKEN], [3, IDENT_TOKEN, 'ab']]],
  [['~|=ab'] => [[1, TILDE_TOKEN], [2, DASHMATCH_TOKEN], [4, IDENT_TOKEN, 'ab']]],
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
  [['+12.'] => [[1, NUMBER_TOKEN, '+12'], [4, DOT_TOKEN]]],
  [['+.20'] => [[1, NUMBER_TOKEN, '+.20']]],
  [['+.20.4'] => [[1, NUMBER_TOKEN, '+.20'], [5, NUMBER_TOKEN, '.4']]],
  [['+.'] => [[1, PLUS_TOKEN], [2, DOT_TOKEN]]],
  [['+.x'] => [[1, PLUS_TOKEN], [2, DOT_TOKEN], [3, IDENT_TOKEN, 'x']]],
  [[','] => [[1, COMMA_TOKEN]]],
  [[',,'] => [[1, COMMA_TOKEN], [2, COMMA_TOKEN]]],
  [['-'] => [[1, MINUS_TOKEN]]],
  [['-910'] => [[1, NUMBER_TOKEN, '-910']]],
  [['-.'] => [[1, MINUS_TOKEN], [2, DOT_TOKEN]]],
  [['-.12'] => [[1, NUMBER_TOKEN, '-.12']]],
  [['-.12.5'] => [[1, NUMBER_TOKEN, '-.12'], [5, NUMBER_TOKEN, '.5']]],
  [['-00.12'] => [[1, NUMBER_TOKEN, '-00.12']]],
  [['-910\\a'] => [[1, DIMENSION_TOKEN, '-910', "\x0A"]]],
  [['-a'] => [[1, IDENT_TOKEN, '-a']]],
  [['-\\'] => ['1;2;css:escape:broken', [1, IDENT_TOKEN, "-\x{FFFD}"]]],
  [["-\\\x0Ac"] => ['1;2;css:escape:broken', [1, MINUS_TOKEN], [2, DELIM_TOKEN, '\\'], S([2,0]), [[2,1], IDENT_TOKEN, 'c']]],
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
  [['@-_a'] => [[1, ATKEYWORD_TOKEN, '-_a']]],
  [["\@-\x{5000}"] => [[1, ATKEYWORD_TOKEN, "-\x{5000}"]]],
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
  [['\\'] => ['1;1;css:escape:broken', [1, IDENT_TOKEN, "\x{FFFD}"]]],
  [["\\\x0A"] => ['1;1;css:escape:broken', Delim(1,'\\'), S([2,0])]],
  [["\\120"] => [[1, IDENT_TOKEN, "\x{120}"]]],
  [["\\120 x"] => [[1, IDENT_TOKEN, "\x{120}x"]]],
  [['612'] => [[1, NUMBER_TOKEN, '612']]],
  [['00.612'] => [[1, NUMBER_TOKEN, '00.612']]],
  [['U'] => [[1, IDENT_TOKEN, 'U']]],
  [['u'] => [[1, IDENT_TOKEN, 'u']]],
  [['USb'] => [[1, IDENT_TOKEN, 'USb']]],
  [['usn'] => [[1, IDENT_TOKEN, 'usn']]],
  [['U+'] => [[1, IDENT_TOKEN, 'U'], [2, PLUS_TOKEN]]],
  [['u+'] => [[1, IDENT_TOKEN, 'u'], [2, PLUS_TOKEN]]],
  [['U '] => [[1, IDENT_TOKEN, 'U'], [2, S_TOKEN]]],
  [['u '] => [[1, IDENT_TOKEN, 'u'], [2, S_TOKEN]]],
  [['U-'] => [[1, IDENT_TOKEN, 'U-']]],
  [['u-'] => [[1, IDENT_TOKEN, 'u-']]],
  [['U*'] => [[1, IDENT_TOKEN, 'U'], [2, STAR_TOKEN]]],
  [['u*'] => [[1, IDENT_TOKEN, 'u'], [2, STAR_TOKEN]]],
  [['U+?'] => [[1, UNICODE_RANGE_TOKEN, 0x0000=>0x000F]]],
  [['u+?'] => [[1, UNICODE_RANGE_TOKEN, 0x0000=>0x000F]]],
  [['U+1'] => [[1, UNICODE_RANGE_TOKEN, 0x0001=>0x0001]]],
  [['u+2'] => [[1, UNICODE_RANGE_TOKEN, 0x0002=>0x0002]]],
  [['U+a'] => [[1, UNICODE_RANGE_TOKEN, 0x000A=>0x000A]]],
  [['u+f'] => [[1, UNICODE_RANGE_TOKEN, 0x000F=>0x000F]]],
  [['u+A9f'] => [[1, UNICODE_RANGE_TOKEN, 0x0A9F=>0x0A9F]]],
  [['u+00?A9f'] => [[1, UNICODE_RANGE_TOKEN, 0x0000=>0x000F], ID(6,'A9f')]],
  [['u+A9f+'] => [[1, UNICODE_RANGE_TOKEN, 0x0A9F=>0x0A9F], [6, PLUS_TOKEN]]],
  [['\\U+2'] => [[1, IDENT_TOKEN, 'U'], [3, NUMBER_TOKEN, '+2']]],
  [['\\u+2'] => [[1, IDENT_TOKEN, 'u'], [3, NUMBER_TOKEN, '+2']]],
  [['U+1034567'] => [[1, UNICODE_RANGE_TOKEN, 0x103456=>0x103456], N(9,'7')]],
  [['U+???????'] => ['1;1;css:unicode-range:end not unicode', [1, UNICODE_RANGE_TOKEN, 0x000000=>0x10FFFF], Delim(9,'?')]],
  [['U+1034567-ffffff'] => [[1, UNICODE_RANGE_TOKEN, 0x103456=>0x103456], Dim(9,'7','-ffffff')]],
  [['U+103?-1fff'] => [[1, UNICODE_RANGE_TOKEN, 0x1030=>0x103F], Dim(7,'-1','fff')]],
  [['U+1-5f1'] => [[1, UNICODE_RANGE_TOKEN, 0x0001=>0x05F1]]],
  [['U+1-0005f1'] => [[1, UNICODE_RANGE_TOKEN, 0x0001=>0x05F1]]],
  [['U+1-00005f1'] => [[1, UNICODE_RANGE_TOKEN, 0x0001=>0x005F], N(11,'1')]],
  [['U+1-00', '005f1'] => [[1, UNICODE_RANGE_TOKEN, 0x0001=>0x005F], N(11,'1')]],
  [['U+1-00005fx'] => [[1, UNICODE_RANGE_TOKEN, 0x0001=>0x005F], ID(11,'x')]],
  [['u+zad'] => [ID(1,'u'), [2, PLUS_TOKEN], ID(3,'zad')]],
  [['u+105-'] => [[1, UNICODE_RANGE_TOKEN, 0x0105=>0x0105], [6, MINUS_TOKEN]]],
  [['u+105000-'] => [[1, UNICODE_RANGE_TOKEN, 0x0105000=>0x0105000], [9, MINUS_TOKEN]]],
  [['u+105000', '-'] => [[1, UNICODE_RANGE_TOKEN, 0x0105000=>0x0105000], [9, MINUS_TOKEN]]],
  [['u+105-z'] => [[1, UNICODE_RANGE_TOKEN, 0x0105=>0x0105], ID(6,'-z')]],
  [['u+105000-z'] => [[1, UNICODE_RANGE_TOKEN, 0x0105000=>0x0105000], ID(9,'-z')]],
  [['u+105\\-12'] => [[1, UNICODE_RANGE_TOKEN, 0x0105=>0x0105], ID(6,'-12')]],
  [['u+105000\\-12'] => [[1, UNICODE_RANGE_TOKEN, 0x0105000=>0x0105000], ID(9,'-12')]],
  [['u+1', '0500', '0\\-12'] => [[1, UNICODE_RANGE_TOKEN, 0x0105000=>0x0105000], ID(9,'-12')]],
  [['u+105-\\12'] => [[1, UNICODE_RANGE_TOKEN, 0x0105=>0x0105], ID(6,"-\x12")]],
  [['u+105000-\\12'] => [[1, UNICODE_RANGE_TOKEN, 0x0105000=>0x0105000], ID(9,"-\x12")]],
  [['u+105--\\12'] => [[1, UNICODE_RANGE_TOKEN, 0x0105=>0x0105], [6, MINUS_TOKEN], ID(7,"-\x12")]],
  [['u+105000--\\12'] => [[1, UNICODE_RANGE_TOKEN, 0x0105000=>0x0105000], [9, MINUS_TOKEN], ID(10,"-\x12")]],
  [['u+105-->'] => [[1, UNICODE_RANGE_TOKEN, 0x0105=>0x0105], [6, CDC_TOKEN]]],
  [['u+105000-->'] => [[1, UNICODE_RANGE_TOKEN, 0x0105000=>0x0105000], [9, CDC_TOKEN]]],
  [['u+314-429??'] => [[1, UNICODE_RANGE_TOKEN, 0x0314=>0x0429], Delim(10,'?'), Delim(11,'?')]],
  [['u', '+', '314-', '429??'] => [[1, UNICODE_RANGE_TOKEN, 0x0314=>0x0429], Delim(10,'?'), Delim(11,'?')]],
  [['U+10FFFF'] => [[1, UNICODE_RANGE_TOKEN, 0x10FFFF=>0x10FFFF]]],
  [['U+010FFFF'] => [[1, UNICODE_RANGE_TOKEN, 0x10FFF=>0x10FFF], ID(9,'F')]],
  [['U+110000'] => ['1;1;css:unicode-range:start not unicode', [1, UNICODE_RANGE_TOKEN, -1=>-1]]],
  [['U+1000-110000'] => ['1;1;css:unicode-range:end not unicode', [1, UNICODE_RANGE_TOKEN, 0x1000=>0x10FFFF]]],
  [['U+1?????'] => ['1;1;css:unicode-range:end not unicode', [1, UNICODE_RANGE_TOKEN, 0x100000=>0x10FFFF]]],
  [['U+655-21'] => ['1;1;css:unicode-range:start gt end', [1, UNICODE_RANGE_TOKEN, -1=>-1]]],
  [['U+513-0513'] => [[1, UNICODE_RANGE_TOKEN, 0x0513=>0x0513]]],
  [['abc'] => [[1, IDENT_TOKEN, 'abc']]],
  [['Zbc'] => [[1, IDENT_TOKEN, 'Zbc']]],
  [['_Zbc'] => [[1, IDENT_TOKEN, '_Zbc']]],
  [['-_Zbc'] => [[1, IDENT_TOKEN, '-_Zbc']]],
  [["\x03"] => [Delim(1,"\x03")]],
  [["%"] => [Delim(1,"%")]],
  [["\x7F"] => [Delim(1,"\x7F")]],
  [['12E'] => [[1, DIMENSION_TOKEN, '12', 'E']]],
  [['12e'] => [[1, DIMENSION_TOKEN, '12', 'e']]],
  [['12\\45'] => [[1, DIMENSION_TOKEN, '12', 'E']]],
  [['12\\065'] => [[1, DIMENSION_TOKEN, '12', 'e']]],
  [['12E0'] => [[1, NUMBER_TOKEN, '12E0']]],
  [['12e05'] => [[1, NUMBER_TOKEN, '12e05']]],
  [['12E9f'] => [[1, DIMENSION_TOKEN, '12E9', 'f']]],
  [['1', '2', 'E9', 'f'] => [[1, DIMENSION_TOKEN, '12E9', 'f']]],
  [['12', 'E9f'] => [[1, DIMENSION_TOKEN, '12E9', 'f']]],
  [['12E', '9f'] => [[1, DIMENSION_TOKEN, '12E9', 'f']]],
  [['12e1000a'] => [[1, DIMENSION_TOKEN, '12e1000', 'a']]],
  [['12E9-f'] => [[1, DIMENSION_TOKEN, '12E9', '-f']]],
  [['12e1000-a'] => [[1, DIMENSION_TOKEN, '12e1000', '-a']]],
  [['12e05e5'] => [[1, DIMENSION_TOKEN, '12e05', 'e5']]],
  [['12ef5'] => [[1, DIMENSION_TOKEN, '12', 'ef5']]],
  [['12\\45 5'] => [[1, DIMENSION_TOKEN, '12', 'E5']]],
  [['12e-5'] => [[1, DIMENSION_TOKEN, '12', 'e-5']]],
  [['12e+5'] => [[1, DIMENSION_TOKEN, '12', 'e'], [4, NUMBER_TOKEN, '+5']]],
  [['12e5.0'] => [[1, NUMBER_TOKEN, '12e5'], [5, NUMBER_TOKEN, '.0']]],
  [['+12e5.0'] => [[1, NUMBER_TOKEN, '+12e5'], [6, NUMBER_TOKEN, '.0']]],
  [['+', '12e5.0'] => [[1, NUMBER_TOKEN, '+12e5'], [6, NUMBER_TOKEN, '.0']]],
  [['-12e5.0'] => [[1, NUMBER_TOKEN, '-12e5'], [6, NUMBER_TOKEN, '.0']]],
  [['12.4e5.0'] => [[1, NUMBER_TOKEN, '12.4e5'], [7, NUMBER_TOKEN, '.0']]],
  [['12.41e5.0'] => [[1, NUMBER_TOKEN, '12.41e5'], [8, NUMBER_TOKEN, '.0']]],
  [['12.e5'] => [[1, NUMBER_TOKEN, '12'], [3, DOT_TOKEN], [4, IDENT_TOKEN, 'e5']]],
  [['12EM'] => [[1, DIMENSION_TOKEN, '12', 'EM']]],
  [['12\\EM'] => [[1, DIMENSION_TOKEN, '12', "\x0EM"]]],
  [['12\\-M'] => [[1, DIMENSION_TOKEN, '12', "-M"]]],
  [['12-M'] => [[1, DIMENSION_TOKEN, '12', "-M"]]],
  [['12-e'] => [[1, DIMENSION_TOKEN, '12', "-e"]]],
  [['12--e'] => [[1, NUMBER_TOKEN, '12'], [3, MINUS_TOKEN], [4, IDENT_TOKEN, '-e']]],
  [['12-->'] => [[1, NUMBER_TOKEN, '12'], [3, CDC_TOKEN]]],
  [['12ab-->'] => [[1, DIMENSION_TOKEN, '12', 'ab--'], [7, GREATER_TOKEN]]],
  [['12', '-->'] => [[1, NUMBER_TOKEN, '12'], [3, CDC_TOKEN]]],
  [['12ab', '-->'] => [[1, DIMENSION_TOKEN, '12', 'ab--'], [7, GREATER_TOKEN]]],
  [['12-', '->'] => [[1, NUMBER_TOKEN, '12'], [3, CDC_TOKEN]]],
  [['12ab-', '->'] => [[1, DIMENSION_TOKEN, '12', 'ab--'], [7, GREATER_TOKEN]]],
  [['12--', '>'] => [[1, NUMBER_TOKEN, '12'], [3, CDC_TOKEN]]],
  [['12ab--', '>'] => [[1, DIMENSION_TOKEN, '12', 'ab--'], [7, GREATER_TOKEN]]],
  [['12a', 'b', '-->'] => [[1, DIMENSION_TOKEN, '12', 'ab--'], [7, GREATER_TOKEN]]],
  [['12-ab'] => [Dim(1,'12','-ab')]],
  [['12-\\ab'] => [Dim(1,'12',"-\xab")]],
  [['12-\\'] => ['1;4;css:escape:broken', Dim(1,'12',"-\x{FFFD}")]],
  [["12-\\\x0A"] => ['1;4;css:escape:broken', N(1,'12'), Minus(3), BS(4), S([2,0])]],
  [["12-`"] => [N(1,'12'), Minus(3), Delim(4,'`')]],
  [['12e4-ab'] => [Dim(1,'12e4','-ab')]],
  [['12e4-\\ab'] => [Dim(1,'12e4',"-\xab")]],
  [['12e4-\\'] => ['1;6;css:escape:broken', Dim(1,'12e4',"-\x{FFFD}")]],
  [["12e4-\\\x0A"] => ['1;6;css:escape:broken', N(1,'12e4'), Minus(5), BS(6), S([2,0])]],
  [["12e4-`"] => [N(1,'12e4'), Minus(5), Delim(6,'`')]],
  [["12\\"] => ['1;3;css:escape:broken', [1, DIMENSION_TOKEN, '12', "\x{FFFD}"]]],
  [["12\\\x0A"] => ['1;3;css:escape:broken', [1, NUMBER_TOKEN, '12'], Delim(3,'\\'), S([2,0])]],
  [['0903%'] => [[1, PERCENTAGE_TOKEN, '0903']]],
  [['0903\\%'] => [[1, DIMENSION_TOKEN, '0903', '%']]],
  [['0903.44%'] => [[1, PERCENTAGE_TOKEN, '0903.44']]],
  [['0903E60%'] => [[1, PERCENTAGE_TOKEN, '0903E60']]],
  [['0903e00%'] => [[1, PERCENTAGE_TOKEN, '0903e00']]],
  [['09.03e6%'] => [[1, PERCENTAGE_TOKEN, '09.03e6']]],
  [['\\ab'] => [[1, IDENT_TOKEN, "\x{ab}"]]],
  [['-\\ab'] => [[1, IDENT_TOKEN, "-\x{ab}"]]],
  [['--\\ab'] => [[1, MINUS_TOKEN], [2, IDENT_TOKEN, "-\x{ab}"]]],
  [['---\\ab'] => [[1, MINUS_TOKEN], [2, MINUS_TOKEN], [3, IDENT_TOKEN, "-\x{ab}"]]],
  [['\\xyz'] => [[1, IDENT_TOKEN, 'xyz']]],
  [['-\\xyz'] => [[1, IDENT_TOKEN, '-xyz']]],
  [['a\\xyz'] => [[1, IDENT_TOKEN, 'axyz']]],
  [['120\\xyz'] => [[1, DIMENSION_TOKEN, '120', 'xyz']]],
  [['120-\\xyz'] => [[1, DIMENSION_TOKEN, '120', '-xyz']]],
  [['120a\\xyz'] => [[1, DIMENSION_TOKEN, '120', 'axyz']]],
  [['@\\xyz'] => [[1, ATKEYWORD_TOKEN, 'xyz']]],
  [['@-\\xyz'] => [[1, ATKEYWORD_TOKEN, '-xyz']]],
  [['@a\\xyz'] => [[1, ATKEYWORD_TOKEN, 'axyz']]],
  [['#\\xyz'] => [[1, HASH_TOKEN, 'xyz', 'id']]],
  [['#-\\xyz'] => [[1, HASH_TOKEN, '-xyz', 'id']]],
  [['#a\\xyz'] => [[1, HASH_TOKEN, 'axyz', 'id']]],
  [['url(\\xyz)'] => [[1, URI_TOKEN, 'xyz']]],
  [['url( \\xyz)'] => [[1, URI_TOKEN, 'xyz']]],
  [['url(a\\xyz)'] => [[1, URI_TOKEN, 'axyz']]],
  [['url(a \\xyz)'] => ['1;7;css:url:bad', [1, URI_INVALID_TOKEN]]],
  [['"\\xyz"'] => [[1, STRING_TOKEN, 'xyz']]],
  [['"a\\xyz"'] => [[1, STRING_TOKEN, 'axyz']]],
  [["'\\xyz'"] => [[1, STRING_TOKEN, 'xyz']]],
  [["'a\\xyz'"] => [[1, STRING_TOKEN, 'axyz']]],
  [['url("\\xyz")'] => [[1, URI_TOKEN, 'xyz']]],
  [['url("a\\xyz")'] => [[1, URI_TOKEN, 'axyz']]],
  [["url('\\xyz')"] => [[1, URI_TOKEN, 'xyz']]],
  [["url('a\\xyz')"] => [[1, URI_TOKEN, 'axyz']]],
  [['\\1'] => [[1, IDENT_TOKEN, "\x01"]]],
  [['\\12'] => [[1, IDENT_TOKEN, "\x12"]]],
  [['\\123'] => [[1, IDENT_TOKEN, "\x{123}"]]],
  [['\\1234'] => [[1, IDENT_TOKEN, "\x{1234}"]]],
  [['\\12345'] => [[1, IDENT_TOKEN, "\x{12345}"]]],
  [['\\103456'] => [[1, IDENT_TOKEN, "\x{103456}"]]],
  [['\\123456'] => ['1;7;css:escape:not unicode', [1, IDENT_TOKEN, "\x{FFFD}"]]],
  [['\\1034567'] => [[1, IDENT_TOKEN, "\x{103456}7"]]],
  [["\\103 4567"] => [[1, IDENT_TOKEN, "\x{103}4567"]]],
  [["\\103\x0A4567"] => [[1, IDENT_TOKEN, "\x{103}4567"]]],
  [["\\103456 7"] => [[1, IDENT_TOKEN, "\x{103456}7"]]],
  [['\\Ba45f'] => [[1, IDENT_TOKEN, "\x{ba45f}"]]],
  [['\\Ba4z5f'] => [[1, IDENT_TOKEN, "\x{ba4}z5f"]]],
  [['\\0000001'] => ['1;7;css:escape:null', [1, IDENT_TOKEN, "\x{FFFD}1"]]],
  [['"\\0000001"'] => ['1;8;css:escape:null', [1, STRING_TOKEN, "\x{FFFD}1"]]],
  [['\\000000 '] => ['1;7;css:escape:null', [1, IDENT_TOKEN, "\x{FFFD}"]]],
  [['a\\000000 '] => ['1;8;css:escape:null', [1, IDENT_TOKEN, "a\x{FFFD}"]]],
  [['a\\', '000000 '] => ['1;8;css:escape:null', [1, IDENT_TOKEN, "a\x{FFFD}"]]],
  [['\\', '1034567'] => [[1, IDENT_TOKEN, "\x{103456}7"]]],
  [['\\1', '034567'] => [[1, IDENT_TOKEN, "\x{103456}7"]]],
  [['\\1034', '567'] => [[1, IDENT_TOKEN, "\x{103456}7"]]],
  [["\\124\x0Abc"] => [[1, IDENT_TOKEN, "\x{124}bc"]]],
  [["\\124\x0A", "bc"] => [[1, IDENT_TOKEN, "\x{124}bc"]]],
  [["\\\x0A", "bc"] => ['1;1;css:escape:broken', Delim(1,'\\'), S([2,0]), [[2,1], IDENT_TOKEN, "bc"]]],
  [["a\\\x0A", "bc"] => ['1;2;css:escape:broken', [1, IDENT_TOKEN, 'a'], Delim(2,'\\'), S([2,0]), [[2,1], IDENT_TOKEN, "bc"]]],
  [['hoge('] => [[1, FUNCTION_TOKEN, 'hoge']]],
  [['ho\\ge('] => [[1, FUNCTION_TOKEN, 'hoge']]],
  [['\\55ho\\ge('] => [[1, FUNCTION_TOKEN, "\x55hoge"]]],
  [['hoge\\('] => [ID(1,'hoge(')]],
  [['hoge/**/('] => [ID(1,'hoge'), [9, LPAREN_TOKEN]]],
  [['url/**/('] => [ID(1,'url'), [8, LPAREN_TOKEN]]],
  [['url\\('] => [ID(1,'url(')]],
  [['url()a'] => [[1, URI_TOKEN, ''], ID(6,'a')]],
  [['url(  )a'] => [[1, URI_TOKEN, ''], ID(8,'a')]],
  [['url(  xy)a'] => [[1, URI_TOKEN, 'xy'], ID(10,'a')]],
  [["url(  xy\x09)a"] => [[1, URI_TOKEN, 'xy'], ID(11,'a')]],
  [['u\\rl(  xy  )a'] => [[1, URI_TOKEN, 'xy'], ID(13,'a')]],
  [['url(  /**/xy)a'] => [[1, URI_TOKEN, '/**/xy'], ID(14,'a')]],
  [['url(a  b  \\) ad)a'] => ['1;8;css:url:bad', [1, URI_INVALID_TOKEN], ID(17,'a')]],
  [['url(\xab)'] => [[1, URI_TOKEN, 'xab']]],
  [['url(d\xab)'] => [[1, URI_TOKEN, 'dxab']]],
  [['url(\ab)'] => [[1, URI_TOKEN, "\xAB"]]],
  [['url(\ab f)'] => [[1, URI_TOKEN, "\xABf"]]],
  [['url(\ab\)aa)'] => [[1, URI_TOKEN, "\xAB)aa"]]],
  [['url(\ab )'] => [[1, URI_TOKEN, "\xAB"]]],
  [['url('] => ['1;5;css:url:eof', [1, URI_TOKEN, ""]]],
  [['url(  '] => ['1;7;css:url:eof', [1, URI_TOKEN, ""]]],
  [['url( a'] => ['1;7;css:url:eof', [1, URI_TOKEN, "a"]]],
  [['url( a  '] => ['1;9;css:url:eof', [1, URI_TOKEN, "a"]]],
  [['url( \a  '] => ['1;10;css:url:eof', [1, URI_TOKEN, "\x0A"]]],
  [['url(aa\\'] => ['1;7;css:escape:broken', '1;8;css:url:eof', [1, URI_TOKEN, "aa\x{FFFD}"]]],
  [["url(aa\\\x0A"] => ['1;7;css:escape:broken', [1, URI_INVALID_TOKEN]]],
  [["url(aa\\\x0A)a"] => ['1;7;css:escape:broken', [1, URI_INVALID_TOKEN], ID([2,2],'a')]],
  [["url(a a\\\x0A)a"] => ['1;7;css:url:bad', '1;8;css:escape:broken', [1, URI_INVALID_TOKEN], ID([2,2],'a')]],
  [["url(a a\\\x0A\\)c)a"] => ['1;7;css:url:bad', '1;8;css:escape:broken', [1, URI_INVALID_TOKEN], ID([2,5],'a')]],
  [['url(a(b)c'] => ['1;6;css:url:bad', [1, URI_INVALID_TOKEN], ID(9,'c')]],
  [['url(a"b)c'] => ['1;6;css:url:bad', [1, URI_INVALID_TOKEN], ID(9,'c')]],
  [["url(a'b)c"] => ['1;6;css:url:bad', [1, URI_INVALID_TOKEN], ID(9,'c')]],
  [["url(a\x0Ab)c"] => ['2;1;css:url:bad', [1, URI_INVALID_TOKEN], ID([2,3],'c')]],
  [['url(a a\)bb)c'] => ['1;7;css:url:bad', [1, URI_INVALID_TOKEN], ID(13,'c')]],
  [['url(a \)b b)c'] => ['1;7;css:url:bad', [1, URI_INVALID_TOKEN], ID(13,'c')]],
  [['url( aa c '] => ['1;9;css:url:bad', [1, URI_INVALID_TOKEN]]],
  [['url( aa c\\'] => ['1;9;css:url:bad', '1;10;css:escape:broken', [1, URI_INVALID_TOKEN]]],
  [['url("")'] => [[1, URI_TOKEN, '']]],
  [['url("abc")'] => [[1, URI_TOKEN, 'abc']]],
  [['url("abc\\z")'] => [[1, URI_TOKEN, 'abcz']]],
  [['url("abc\\z\\123")'] => [[1, URI_TOKEN, "abcz\x{123}"]]],
  [['url( "abc\\z\\123"  )'] => [[1, URI_TOKEN, "abcz\x{123}"]]],
  [['url( "abc\\z\\123"  '] => ['1;19;css:url:eof', [1, URI_TOKEN, "abcz\x{123}"]]],
  [['url( "abc\\z\\123  '] => ['1;18;css:string:eof', [1, URI_TOKEN, "abcz\x{123} "]]],
  [['url( "abc\\z\\123'] => ['1;16;css:string:eof', [1, URI_TOKEN, "abcz\x{123}"]]],
  [['url( "abc'] => ['1;10;css:string:eof', [1, URI_TOKEN, "abc"]]],
  [[qq{url( "abc\x0A}] => ['2;0;css:string:newline', [1, URI_INVALID_TOKEN], S([2,0])]],
  [[qq{url( "abc\\\x0A}] => ['2;1;css:string:eof', [1, URI_TOKEN, 'abc']]],
  [[qq{url( "abc\\}.qq{\x0A}] => ['2;1;css:string:eof', [1, URI_TOKEN, 'abc']]],
  [['url("abc" a)d'] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(13,'d')]],
  [['url("abcd"a)d'] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(13,'d')]],
  [['url("abcd""")d'] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(14,'d')]],
  [[q{url("abcd"'')d}] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(14,'d')]],
  [[q{url("abcd"\\)'')d}] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(16,'d')]],
  [["url('')"] => [[1, URI_TOKEN, '']]],
  [["url('abc')"] => [[1, URI_TOKEN, 'abc']]],
  [["url('abc\\z')"] => [[1, URI_TOKEN, 'abcz']]],
  [["url('abc\\z\\123')"] => [[1, URI_TOKEN, "abcz\x{123}"]]],
  [["url( 'abc\\z\\123'  )"] => [[1, URI_TOKEN, "abcz\x{123}"]]],
  [["url( 'abc\\z\\123'  "] => ['1;19;css:url:eof', [1, URI_TOKEN, "abcz\x{123}"]]],
  [["url( 'abc\\z\\123  "] => ['1;18;css:string:eof', [1, URI_TOKEN, "abcz\x{123} "]]],
  [["url( 'abc\\z\\123"] => ['1;16;css:string:eof', [1, URI_TOKEN, "abcz\x{123}"]]],
  [["url( 'abc"] => ['1;10;css:string:eof', [1, URI_TOKEN, "abc"]]],
  [[qq{url( 'abc\x0A}] => ['2;0;css:string:newline', [1, URI_INVALID_TOKEN], S([2,0])]],
  [[qq{url( 'abc\\\x0A}] => ['2;1;css:string:eof', [1, URI_TOKEN, 'abc']]],
  [[qq{url( 'abc\\}.qq{\x0A}] => ['2;1;css:string:eof', [1, URI_TOKEN, 'abc']]],
  [["url('abc' a)d"] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(13,'d')]],
  [["url('abcd'a)d"] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(13,'d')]],
  [[q{url('abcd'"")d}] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(14,'d')]],
  [[q{url('abcd''')d}] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(14,'d')]],
  [[q{url('abcd'\\)'')d}] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(16,'d')]],
  [[q{url('abcd'\\)"")d}] => ['1;11;css:url:bad', [1, URI_INVALID_TOKEN], ID(16,'d')]],
  [[q{url("a\\"b")c}] => [[1, URI_TOKEN, 'a"b'], ID(12,'c')]],
  [[q{url('a\\'b')c}] => [[1, URI_TOKEN, "a'b"], ID(12,'c')]],
  [[q{url(a"b\\"c")d}] => ['1;6;css:url:bad', [1, URI_INVALID_TOKEN], ID(13,'d')]],
  [[q{url(a"b)c")d}] => ['1;6;css:url:bad', [1, URI_INVALID_TOKEN], ID(9,'c'), '1;13;css:string:eof', [10, STRING_TOKEN, ')d']]],
  [[qq{url("a\\\x0Ab")}] => [[1, URI_TOKEN, 'ab']]],
  [[qq{url('a\\\x0Ab')}] => [[1, URI_TOKEN, 'ab']]],
  [[qq{url("a\\}.qq{\x0Ab")}] => [[1, URI_TOKEN, 'ab']]],
  [[qq{url('a\\}.qq{\x0A}.qq{b')}] => [[1, URI_TOKEN, 'ab']]],
  [[qq{url('a\\}.qq{\x0A}.qq{ b')}] => [[1, URI_TOKEN, 'a b']]],
  [[qq{"a\\\x0Cb"}] => [[1, STRING_TOKEN, "ab"]]],
  [[qq{"a\\\x0Db"}] => [[1, STRING_TOKEN, "ab"]]],
  [[qq{"a\\\x0Ab"}] => [[1, STRING_TOKEN, "ab"]]],
  [[qq{"a\\\x0D\x0Ab"}] => [[1, STRING_TOKEN, "ab"]]],
  [[qq{"a\\\x0A\x0Db"}] => ['3;0;css:string:newline', [1, INVALID_TOKEN], S([3,0]), ID([3,1],'b'), '3;3;css:string:eof', [[3,2], STRING_TOKEN, '']]],
  [[qq{"a\\\x09b"}] => [[1, STRING_TOKEN, "a\x09b"]]],
  [[qq{"a\\\x0Bb"}] => [[1, STRING_TOKEN, "a\x0Bb"]]],
  [[qq{a\\x\x0Ab}] => [ID(1,"ax"), S([2,0]), ID([2,1],'b')]],
  [[qq{a\\1\x0Ab}] => [ID(1,"a\x01b")]],
  [[qq{a\\1\x0D\x0Ab}] => [ID(1,"a\x01b")]],
  [[qq{a\\1\x0Bb}] => [ID(1,"a\x01"), Delim(4,"\x0B"), ID(5,'b')]],
  [[qq{a\\1\x0Cb}] => [ID(1,"a\x01b")]],
  [[qq{a\\1\x0Db}] => [ID(1,"a\x01b")]],
  [[qq{a\\1\x09b}] => [ID(1,"a\x01b")]],
  [[qq{url(\x09\x0A\x0D\x0D\x0A\x0Caaaa\x0A\x0C\x0D\x0D\x0A\x09)}] => [[1, URI_TOKEN, 'aaaa']]],
  [[qq{\x00}] => ['1;1;NULL', ID(1,"\x{FFFD}")]],
  [[qq{ab\x00c}] => ['1;3;NULL', ID(1,"ab\x{FFFD}c")]],
  [[qq{12\x00}] => ['1;3;NULL', Dim(1,'12',"\x{FFFD}")]],
  [[qq{'12\x00'}] => ['1;4;NULL', [1, STRING_TOKEN, "12\x{FFFD}"]]],
  [[qq{\\\x00}] => ['1;2;NULL', ID(1,"\x{FFFD}")]],
) {
  for (@{$test->[1]}) {
    next unless ref $_;
    my $f = $_->[3];
    $_ = {line => ref $_->[0] ? $_->[0]->[0] : 1,
          column => ref $_->[0] ? $_->[0]->[1] : $_->[0],
          type => $_->[1], value => $_->[2]};
    delete $_->{line}, delete $_->{column} if $_->{type} == ABORT_TOKEN;
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
    if ($_->{type} == PERCENTAGE_TOKEN) {
      $_->{number} = $_->{value};
      $_->{value} = '';
    }
    if ($_->{type} == UNICODE_RANGE_TOKEN) {
      $_->{start} = delete $_->{value};
      $_->{end} = $f;
    }
  }
  test {
    my $c = shift;

    my $tokens = [];
    my $tt = do {
      my $tt = Web::CSS::Tokenizer->new;
      $tt->onerror (sub {
        my %args = @_;
        push @$tokens, join ';', $args{line}, $args{column}, $args{type};
      });

      $tt->{line_prev} = $tt->{line} = 1;
      $tt->{column_prev} = -1;
      $tt->{column} = 0;

      $tt->{chars} = [];
      $tt->{chars_pos} = 0;
      delete $tt->{chars_was_cr};
      my @s = @{$test->[0]};
      $tt->{chars_pull_next} = sub {
        my $s = shift @s;
        push @{$tt->{chars}}, split //, $s if defined $s;
        return defined $s;
      };
      $tt->init_tokenizer;
      $tt;
    };

    {
      my $t = $tt->get_next_token;
      last if $t->{type} == EOF_TOKEN;
      delete $t->{hyphen};
      push @$tokens, $t;
      redo;
    }
    eq_or_diff $tokens, $test->[1];

    delete $tt->{chars_pull_next};
    done $c;
  } n => 1, name => [@{$test->[0]}];
}

run_tests;
