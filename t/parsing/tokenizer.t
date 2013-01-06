package test::Whatpm::CSS::Tokenizer;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use base qw(Test::Class);
use Test::Differences;

my $test_dir_name = 't/';

use JSON;
{
  no warnings 'once';
  $JSON::UnMapping = 1;
  $JSON::UTF8 = 1;
}

use Data::Dumper;
$Data::Dumper::Useqq = 1;
sub Data::Dumper::qquote {
  my $s = shift;
  $s =~ s/([^\x20\x21-\x26\x28-\x5B\x5D-\x7E])/sprintf '\x{%02X}', ord $1/ge;
  return q<qq'> . $s . q<'>;
} # Data::Dumper::qquote

use Whatpm::CSS::Tokenizer;

sub _test : Tests {
for my $file_name (grep {$_} split /\s+/, qq[
                      ${test_dir_name}css-token-1.test
                     ]) {
  open my $file, '<', $file_name
    or die "$0: $file_name: $!";
  local $/ = undef;
  my $js = <$file>;
  close $file;

  print "# $file_name\n";
  $js =~ s{\\u[Dd]([89A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
      \\u[Dd]([89A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])}{
    ## NOTE: JSON::Parser does not decode surrogate pair escapes
    ## NOTE: In older version of JSON::Parser, utf8 string will be broken
    ## by parsing.  Use latest version!
    ## NOTE: Encode.pm is broken; it converts e.g. U+10FFFF to U+FFFD.
    my $c = 0x10000;
    $c += ((((hex $1) & 0b1111111111) << 10) | ((hex $2) & 0b1111111111));
    chr $c;
  }gex;
  my $tests = from_json ($js)->{tests};
  TEST: for my $test (@$tests) {
    my $s = $test->{input};

    my $p = Whatpm::CSS::Tokenizer->new;
    $p->{onerror} = sub { };
    
    my $pos = 0;
    my $length = length $s;
    $p->{get_char} = sub {
      if ($pos < $length) {
        return ord substr $s, $pos++, 1;
      } else {
        return -1;
      }
    };
    $p->init;

    my @token;
    while (1) {
      my $token = $p->get_next_token;
      last if $token->{type} == Whatpm::CSS::Tokenizer::EOF_TOKEN ();

      my $test_token;
      $test_token->[0] = $Whatpm::CSS::Tokenizer::TokenName[$token->{type}] ||
          $token->{type};
      if ({
           NUMBER => 1,
           DIMENSION => 1,
           PERCENTAGE => 1,
          }->{$test_token->[0]}) {
        push @$test_token, $token->{number};
        delete $token->{value}
            if defined $token->{value} and $token->{value} eq '';
      }
      unless ({
               DOT => 1,
               LBRACE => 1, RBRACE => 1,
               LBRACKET => 1, RBRACKET => 1,
               CDO => 1, CDC => 1,
               COLON => 1,
               COMMA => 1,
               COMMENT_INVALID => 1,
               DASHMATCH => 1,
               DIMENSION => (not defined $token->{value}),
               EXCLAMATION => 1,
               GREATER => 1,
               INCLUDES => 1,
               MATCH => 1,
               MINUS => 1,
               NUMBER => (not defined $token->{value}),
               LPAREN => 1, RPAREN => 1,
               PERCENTAGE => (not defined $token->{value}),
               PLUS => 1,
               PREFIXMATCH => 1,
               S => 1,
               SEMICOLON => 1,
               STAR => 1,
               SUBSTRINGMATCH => 1,
               SUFFIXMATCH => 1,
               TILDE => 1,
               URI_INVALID => 1,
               URI_PREFIX_INVALID => 1,
               VBAR => 1,
              }->{$test_token->[0]}) {
        push @$test_token, $token->{value};
      }
      push @token, $test_token;
    }
     
    my $expected_dump = Dumper ($test->{output});
    my $parser_dump = Dumper (\@token);
    eq_or_diff $parser_dump, $expected_dump,
        $test->{description} . ': ' . Data::Dumper::qquote ($test->{input});
  }
}
}

__PACKAGE__->runtests;

1;

## License: Public Domain.
