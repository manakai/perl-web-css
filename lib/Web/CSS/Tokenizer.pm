package Web::CSS::Tokenizer;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '1.21';
use Carp;

# XXX Need to be updated based on the latest css3-syntax standard

## ------ Character classes ------

## The "EOF" pseudo-character in the parsing algorithm.
sub EOF_CHAR () { -1 }

## Pause tokenization (and parsing) because of the end of the
## currently available characters (that could be different from EOF).
sub ABORT_CHAR () { -3 }

sub IS_NEWLINE () {
  return {
    0x000A => 1, # \n

    ## Normalized to U+000A by input stream preprocessor such that not
    ## included in the spec.
    0x000D => 1, # \r
    0x000C => 1, # \f
  };
} # IS_NEWLINE

sub IS_WHITE_SPACE () {
  return {
    0x0020 => 1, # SP
    0x0009 => 1, # \t
    0x000A => 1, # \n

    ## Normalized to U+000A by input stream preprocessor such that not
    ## included in the spec.
    0x000D => 1, # \r
    0x000C => 1, # \f
  };
} # IS_WHITE_SPACE

sub IS_DIGIT () {
  return {
    0x0030 => 1, 0x0031 => 1, 0x0032 => 1, 0x0033 => 1, 0x0034 => 1,
    0x0035 => 1, 0x0036 => 1, 0x0037 => 1, 0x0038 => 1, 0x0039 => 1,
  };
} # IS_DIGIT

sub IS_HEX_DIGIT () {
  return {
    0x0030 => 1, 0x0031 => 1, 0x0032 => 1, 0x0033 => 1, 0x0034 => 1,
    0x0035 => 1, 0x0036 => 1, 0x0037 => 1, 0x0038 => 1, 0x0039 => 1,
    0x0041 => 1, 0x0042 => 1, 0x0043 => 1,
    0x0044 => 1, 0x0045 => 1, 0x0046 => 1,
    0x0061 => 1, 0x0062 => 1, 0x0063 => 1,
    0x0064 => 1, 0x0065 => 1, 0x0066 => 1,
  };
} # IS_HEX_DIGIT

my $is_name_char = {
  map { $_ => 1 } 0x0030..0x0039, 0x0041..0x005A, 0x0061..0x007A, 0x005F, 0x002D,
};
my $is_name_start_char = {
  map { $_ => 1 } 0x0041..0x005A, 0x0061..0x007A, 0x005F,
};

sub IS_NAME ($) {
  return $is_name_char->{$_[0]} || $_[0] > 0x007F;
} # IS_NAME

sub IS_NAME_START ($) {
  return $is_name_start_char->{$_[0]} || $_[0] > 0x007F;
} # IS_NAME_START

sub IS_VALID_ESCAPE ($$) {
  return 0 if not defined $_[0] or $_[0] != 0x005C;
  return 0 if not defined $_[1] or $_[1] != EOF_CHAR or IS_NEWLINE->{$_[1]};
  return 1;
} # IS_VALID_ESCAPE

## ------ Tokenizer states ------

sub BEFORE_TOKEN_STATE () { 0 }
sub BEFORE_NMSTART_STATE () { 1 }
sub NAME_STATE () { 2 }
sub ESCAPE_OPEN_STATE () { 3 }
sub STRING_STATE () { 4 }
sub HASH_OPEN_STATE () { 5 }
sub NUMBER_STATE () { 6 }
sub NUMBER_FRACTION_STATE () { 7 }
sub AFTER_NUMBER_STATE () { 8 }
sub URI_BEFORE_WSP_STATE () { 9 }
sub ESCAPE_STATE () { 10 }
sub ESCAPE_BEFORE_LF_STATE () { 11 }
sub ESCAPE_BEFORE_NL_STATE () { 12 }
sub NUMBER_DOT_STATE () { 13 }
sub NUMBER_DOT_NUMBER_STATE () { 14 }
sub DELIM_STATE () { 15 }
sub URI_UNQUOTED_STATE () { 16 }
sub URI_AFTER_WSP_STATE () { 17 }
sub AFTER_AT_STATE () { 18 }
sub AFTER_AT_HYPHEN_STATE () { 19 }
sub BEFORE_EQUAL_STATE () { 20 }
sub PLUS_STATE () { 21 }
sub PLUS_DOT_STATE () { 22 }
sub MINUS_STATE () { 23 }
sub MINUS_DOT_STATE () { 24 }
sub SLASH_STATE () { 25 }
sub COMMENT_STATE () { 26 }
sub COMMENT_STAR_STATE () { 27 }
sub MINUS_MINUS_STATE () { 28 }
sub LESS_THAN_STATE () { 29 }
sub MDO_STATE () { 30 }
sub MDO_HYPHEN_STATE () { 31 }
sub NUMBER_E_STATE () { 32 }
sub NUMBER_E_NUMBER_STATE () { 33 }

sub ESCAPE_MODE_IDENT () { 1 }
sub ESCAPE_MODE_URL () { 2 }
sub ESCAPE_MODE_STRING () { 3 }

sub EM2STATE () { {
  ESCAPE_MODE_IDENT, NAME_STATE,
  ESCAPE_MODE_URL, URI_UNQUOTED_STATE,
  ESCAPE_MODE_STRING, STRING_STATE,
} }

## ------ Token types ------

## This module exports these token type constants for the use within
## the parser.

sub IDENT_TOKEN              () {  1 } # <ident>
sub ATKEYWORD_TOKEN          () {  2 } # <at-keyword>
sub HASH_TOKEN               () {  3 } # <hash>
sub FUNCTION_TOKEN           () {  4 } # <function>
sub URI_TOKEN                () {  5 } # <url>
sub URI_INVALID_TOKEN        () {  6 } # <bad-url>
sub URI_PREFIX_TOKEN         () {  7 }
sub URI_PREFIX_INVALID_TOKEN () {  8 }
sub STRING_TOKEN             () {  9 } # <string>
sub INVALID_TOKEN            () { 10 } # <bad-string>
sub NUMBER_TOKEN             () { 11 } # <number>
sub DIMENSION_TOKEN          () { 12 } # <dimension>
sub PERCENTAGE_TOKEN         () { 13 } # <percentage>
sub UNICODE_RANGE_TOKEN      () { 14 } # <unicode-range>
sub DELIM_TOKEN              () { 16 } # <delim>
sub PLUS_TOKEN               () { 17 } # <delim>               +
sub GREATER_TOKEN            () { 18 } # <delim>           >
sub COMMA_TOKEN              () { 19 } # <comma>           ,
sub TILDE_TOKEN              () { 20 } # <delim>               ~
sub DASHMATCH_TOKEN          () { 21 } # <dash-match>      |=
sub PREFIXMATCH_TOKEN        () { 22 } # <prefix-match>    ^=
sub SUFFIXMATCH_TOKEN        () { 23 } # <suffix-match>    $=
sub SUBSTRINGMATCH_TOKEN     () { 24 } # <substring-match> *=
sub INCLUDES_TOKEN           () { 25 } # <include-match>   ~=
sub SEMICOLON_TOKEN          () { 26 } # <semicolon>       ;
sub LBRACE_TOKEN             () { 27 } # <{> {
sub RBRACE_TOKEN             () { 28 } # <}> }
sub LPAREN_TOKEN             () { 29 } # <(> (
sub RPAREN_TOKEN             () { 30 } # <)> )
sub LBRACKET_TOKEN           () { 31 } # <delim>               [
sub RBRACKET_TOKEN           () { 32 } # <delim>               ]
sub S_TOKEN                  () { 33 } # <whitespace>
sub CDO_TOKEN                () { 34 } # <CDO> <!--
sub CDC_TOKEN                () { 35 } # <CDC> -->
#sub COMMENT_TOKEN            () { 36 }
#sub COMMENT_INVALID_TOKEN    () { 37 }
sub EOF_TOKEN                () { 38 }
sub MINUS_TOKEN              () { 39 } # <delim>               -
sub STAR_TOKEN               () { 40 } # <delim>               *
sub VBAR_TOKEN               () { 41 } # <delim>               |
sub DOT_TOKEN                () { 42 } # <delim>               .
sub COLON_TOKEN              () { 43 } # <colon>           :
sub MATCH_TOKEN              () { 44 } # <delim>               =
sub EXCLAMATION_TOKEN        () { 45 } # <delim>               !
sub COLUMN_TOKEN             () { 46 } # <column>          ||
sub ABORT_TOKEN              () { 47 }

our @TokenName = qw(
  0 IDENT ATKEYWORD HASH FUNCTION URI URI_INVALID URI_PREFIX URI_PREFIX_INVALID
  STRING INVALID NUMBER DIMENSION PERCENTAGE UNICODE_RANGE
  0 DELIM PLUS GREATER COMMA TILDE DASHMATCH
  PREFIXMATCH SUFFIXMATCH SUBSTRINGMATCH INCLUDES SEMICOLON
  LBRACE RBRACE LPAREN RPAREN LBRACKET RBRACKET S CDO CDC
  EOF MINUS STAR VBAR DOT COLON MATCH EXCLAMATION
  COLUMN ABORT
);

our @EXPORT = qw(
  IDENT_TOKEN ATKEYWORD_TOKEN HASH_TOKEN FUNCTION_TOKEN URI_TOKEN
  URI_INVALID_TOKEN URI_PREFIX_TOKEN URI_PREFIX_INVALID_TOKEN
  STRING_TOKEN INVALID_TOKEN NUMBER_TOKEN DIMENSION_TOKEN PERCENTAGE_TOKEN
  UNICODE_RANGE_TOKEN DELIM_TOKEN PLUS_TOKEN GREATER_TOKEN COMMA_TOKEN
  TILDE_TOKEN DASHMATCH_TOKEN PREFIXMATCH_TOKEN SUFFIXMATCH_TOKEN
  SUBSTRINGMATCH_TOKEN INCLUDES_TOKEN SEMICOLON_TOKEN LBRACE_TOKEN
  RBRACE_TOKEN LPAREN_TOKEN RPAREN_TOKEN LBRACKET_TOKEN RBRACKET_TOKEN
  S_TOKEN CDO_TOKEN CDC_TOKEN EOF_TOKEN
  MINUS_TOKEN STAR_TOKEN VBAR_TOKEN DOT_TOKEN COLON_TOKEN MATCH_TOKEN
  EXCLAMATION_TOKEN COLUMN_TOKEN ABORT_TOKEN
);

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  for (@_ ? @_ : @EXPORT) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    no strict 'refs';
    *{$to_class . '::' . $_} = $code;
  }
} # import

## ------ Initialization ------

sub new ($) {
  my $self = bless {token => [], get_char => sub { -1 }}, shift;
  return $self;
} # new

sub init ($) {
  my $self = $_[0];
  delete $self->{get_char};
  delete $self->{context};
  delete $self->{onerror};
} # init

## ------ Parameters ------

sub context ($;$) {
  if (@_ > 1) {
    $_[0]->{context} = $_[1];
  }
  return $_[0]->{context} ||= do {
    require Web::CSS::Context;
    Web::CSS::Context->new_empty;
  };
} # context

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub { };
} # onerror

## ------ Preprocessing of input stream ------

# XXX

## ------ Tokenization ------

## | BEFORE_TOKEN_STATE
## v
## consume a token
## |  |n |d
## |  |s v
## |  |\ consume a numeric token
## |  |@ |
## |  |  |>consume a number
## |  |  | |  :...................................................
## |  |  | |  :d    :+                           :-              :.
## |  |  | |  : PLUS_STATE                   MINUS_STATE         :
## |  |  | |  :     :..............          :d     .: :         :
## |  |  | |  :     :d            :.         :       : ......... : ......,
## |  |  | |  :     :             :          :       :           :       :
## |  |  | |  v     v             v          v       :           v
## |  |  | | NUMBER_STATE PLUS_DOT_STATE NUMBER_STATE v   NUMBER_FRACTION_STATE
## |  |  | | :  :e    :.            :d         MINUS_DOT_STATE     :d
## |  |  | | :  :     v             :                  :d          :     :
## |  |  | | :  :  NUMBER_DOT_STATE :                  :           :     :
## |  |  | | :  :     :d            :   ............................     :
## |  |  | | :  :     v             v   v                                :
## |  |  | | :  :  NUMBER_DOT_NUMBER_STATE                               :
## |  |  | | :  :     :e             :                                   :
## |  |  | | :  v     v              :                                   :
## |  |  | | : NUMBER_E_STATE        :                                   :
## |  |  | | :  :d         :         :                                   :
## |  |  | | :  :          ...........                                   :
## |  |  | | :  v                    :                                   :
## |  |  | | : NUMBER_E_NUMBER_STATE :                                   :
## |  |  | | :             :         :                                   :
## |  |  | | :             :.........:                                   :
## |  |  | v v             vv                                            :
## |  |  | AFTER_NUMBER_STATE                                            :
## |  |  v   :n                ..........................................:
## |  +,@    :s                :
## |  |:     :\                :
## |  v                        v
## |  Consume an ident-like token
## |  |
## |  |:...  :
## |  |   v  v
## |  |>Consume a name.............................
## |  | | :-        :ns                           :
## |  | | :..       :...............              :
## |  | | :::                      :              :
## |  | | :::         ,........... : ............ : .....
## |  | | ::v         v            :              :     :
## |  | | :vMINUS_STATE.........,  :              :     :
## |  | | :AFTER_AT_HYPHEN_STATE.. : ............ : ..> MINUS_MINUS_STATE
## |  | | v v                ,..'  :              :
## |  | | BEFORE_NMSTART_STATE.....:..............:
## |  | |                   :      :              :
## |  | |                   v      v              :
## |  | |                  NAME_STATE.............:\
## |  | |                           ^             v
## |  | |                           :        ESCAPE_*_STATE
## |  | |                           :.............:
## |  | v
## |  |
## |  |>Consume a url token
## |  | |
## |  | v
## |  v
## v

## BEFORE_TOKEN_STATE
## |\  |@     |#    |
## |   |      |     `-------------------+--+-------------------+---,
## |   |      `---------------,         |  |                   |"  |
## |   v                      |         |  |                   |'  |
## |  AFTER_AT_STATE          v         |  |                   |   :
## |   |\|-       |      HASH_OPEN_STATE|  :                   |   :
## |   | |        `-----------, |\ |- | |  :                   |   :
## |   | v                    | |  |  | |  :                   |   |
## |   | AFTER_AT_HYPHEN_STATE| |  |  | |  :                   :   v
## |   | |\|-        ,-----.|.|.|.-'  | |  |               URI_UNQUOTED_STATE
## |   | | v         v      | | |     | |  |                   :   |"    |\
## |   | | MINUS_STATE      | | |     | | AFTER_NUMBER_STATE   |   |'    |
## |   | | |\|-      |      | | :     | |  |  |\               |   |     |
## |   | | | |       `------+-+------,| |  |  |                v   v     |
## |   | | | v                  :    || |  |  |          STRING_STATE    |
## |   | | | MINUS_MINUS_STATE  |    || |  |  |           |\             |
## |   | | | |\              |  :    || |  |  |           |              |
## |   | | | |               `-----, || |  |  |           |              |
## |   | | | |                  :  v vv v  v  |           |              |
## |   | | | |                  |  NAME_STATE |           |              |
## |   | | | |                  |      |\     |           |              |
## |   | | | |               ,--+------+------+-----------+--------------'
## v   v v v v               v
## Consume an escape character
## :\
## v
## ESCAPE_OPEN_STATE
## :h
## v
## ESCAPE_STATE
## :6h
## v
## ESCAPE_BEFORE_NL_STATE
## :w
## v
## |
## v
## NAME_STATE (IDENT_TOKEN, DIMENSION_TOKEN, HASH_TOKEN, ATKEYWORD_TOKEN)
## STRING_STATE
## URI_UNQUOTED_STATE
## BEFORE_TOKEN_STATE

sub init_tokenizer ($) {
  my $self = shift;
  $self->{state} = BEFORE_TOKEN_STATE;
  $self->{c} = $self->{get_char}->($self);
  #$self->{t} = {type => token-type,
  #              value => value,
  #              number => number,
  #              line => ..., column => ...,
  #              hyphen => bool,
  #              not_ident => bool}; # HASH_TOKEN does not contain an identifier

  ## <number>/<dimension>'s type flag is represented by |$t->{number}
  ## =~ /[.Ee]/ ? 'number' : 'integer'|.

} # init_tokenizer

sub get_next_token ($) {
  my $self = shift;
  if (@{$self->{token}}) {
    return shift @{$self->{token}};
  }

  A: {
    if ($self->{c} == ABORT_CHAR) {
      $self->{c} = $self->{get_char}->($self);
      return {type => ABORT_TOKEN} if $self->{c} == ABORT_CHAR;
    }

    if ($self->{state} == BEFORE_TOKEN_STATE) {
      ## Consume a token
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-token>.

      if ($self->{c} == 0x002D) { # -
        ## NOTE: |-| in |ident| in |IDENT|
        $self->{t} = {type => IDENT_TOKEN, value => '-', hyphen => 1,
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = MINUS_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0055 or $self->{c} == 0x0075) { # U or u
        $self->{t} = {type => IDENT_TOKEN, value => chr $self->{c},
                      line => $self->{line}, column => $self->{column}};
        $self->{c} = $self->{get_char}->($self);
        if ($self->{c} == 0x002B) { # +
          my ($l, $c) = ($self->{line}, $self->{column});
          $self->{c} = $self->{get_char}->($self);
          if ((0x0030 <= $self->{c} and $self->{c} <= 0x0039) or # 0..9
              (0x0041 <= $self->{c} and $self->{c} <= 0x0046) or # A..F
              (0x0061 <= $self->{c} and $self->{c} <= 0x0066) or # a..f
              $self->{c} == 0x003F) { # ?
            $self->{t}->{value} = chr $self->{c};
            $self->{t}->{type} = UNICODE_RANGE_TOKEN;
            $self->{c} = $self->{get_char}->($self);
            C: for (2..6) {
              if ((0x0030 <= $self->{c} and $self->{c} <= 0x0039) or # 0..9
                  (0x0041 <= $self->{c} and $self->{c} <= 0x0046) or # A..F
                  (0x0061 <= $self->{c} and $self->{c} <= 0x0066) or # a..f
                  $self->{c} == 0x003F) { # ?
                $self->{t}->{value} .= chr $self->{c};
                $self->{c} = $self->{get_char}->($self);
              } else {
                last C;
              }
            } # C

            if ($self->{c} == 0x002D) { # -
              $self->{c} = $self->{get_char}->($self);
              if ((0x0030 <= $self->{c} and $self->{c} <= 0x0039) or # 0..9
                  (0x0041 <= $self->{c} and $self->{c} <= 0x0046) or # A..F
                  (0x0061 <= $self->{c} and $self->{c} <= 0x0066)) { # a..f
                $self->{t}->{value} .= '-' . chr $self->{c};
                $self->{c} = $self->{get_char}->($self);
                C: for (2..6) {
                  if ((0x0030 <= $self->{c} and $self->{c} <= 0x0039) or # 0..9
                      (0x0041 <= $self->{c} and $self->{c} <= 0x0046) or # A..F
                      (0x0061 <= $self->{c} and $self->{c} <= 0x0066)) { # a..f
                    $self->{t}->{value} .= chr $self->{c};
                    $self->{c} = $self->{get_char}->($self);
                  } else {
                    last C;
                  }
                } # C
                
                #
              } else {
                my $token = $self->{t};
                $self->{t} = {type => IDENT_TOKEN, value => '-',
                              line => $self->{line},
                              column => $self->{column}};
                $self->{state} = BEFORE_NMSTART_STATE;
                # reprocess
                return $token;
                #redo A;
              }
            }

            $self->{state} = BEFORE_TOKEN_STATE;
            # reprocess
            return $self->{t};
            #redo A;
          } else {
            unshift @{$self->{token}},
                {type => PLUS_TOKEN, line => $l, column => $c};
            $self->{state} = BEFORE_TOKEN_STATE;
            # reprocess
            return $self->{t};
            #redo A;
          }
        } else {
          $self->{state} = NAME_STATE;
          # reprocess
          redo A;
        }
      } elsif (IS_NAME_START ($self->{c})) {
        ## NOTE: |nmstart| in |ident| in |IDENT|
        $self->{t} = {type => IDENT_TOKEN, value => chr $self->{c},
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x005C) { # \
        ## NOTE: |nmstart| in |ident| in |IDENT|
        $self->{t} = {type => IDENT_TOKEN, value => '',
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_IDENT;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0040) { # @
        ## NOTE: |@| in |ATKEYWORD|
        $self->{t} = {type => ATKEYWORD_TOKEN, value => '',
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = AFTER_AT_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0022 or $self->{c} == 0x0027) { # " or '
        $self->{t} = {type => STRING_TOKEN, value => '',
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = STRING_STATE;
        $self->{end_char} = $self->{c};
            ## $self->{end_char} - ending character
            ##   0x0022: in |string1| or |invalid1|.
            ##   0x0027: in |string2| or |invalid2|.
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0023) { # #
        ## NOTE: |#| in |HASH|.
        $self->{t} = {type => HASH_TOKEN, value => '',
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = HASH_OPEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif (0x0030 <= $self->{c} and $self->{c} <= 0x0039) { # 0..9
        ## NOTE: |num|.
        $self->{t} = {type => NUMBER_TOKEN, value => chr $self->{c},
                      line => $self->{line}, column => $self->{column}};
        ## NOTE: 'value' is renamed as 'number' later.
        $self->{state} = NUMBER_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002B) { # +
        $self->{t} = {type => NUMBER_TOKEN, value => chr $self->{c},
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = PLUS_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002E) { # .
        ## NOTE: |num|.
        $self->{t} = {type => NUMBER_TOKEN, value => '',
                      line => $self->{line}, column => $self->{column}};
        ## NOTE: 'value' is renamed as 'number' later.
        $self->{state} = NUMBER_FRACTION_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002F) { # /
        $self->{t} = {type => DELIM_TOKEN, value => '/',
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = SLASH_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x003C) { # <
        $self->{t} = {type => DELIM_TOKEN, value => '<',
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = LESS_THAN_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif (my $t = {
                        0x0021 => EXCLAMATION_TOKEN, # !
                        0x002E => DOT_TOKEN, # .
                        0x003A => COLON_TOKEN, # :
                        0x003B => SEMICOLON_TOKEN, # ;
                        0x003D => MATCH_TOKEN, # =
                        0x007B => LBRACE_TOKEN, # {
                        0x007D => RBRACE_TOKEN, # }
                        0x0028 => LPAREN_TOKEN, # (
                        0x0029 => RPAREN_TOKEN, # )
                        0x005B => LBRACKET_TOKEN, # [
                        0x005D => RBRACKET_TOKEN, # ]
                        0x003E => GREATER_TOKEN, # >
                        0x002C => COMMA_TOKEN, # ,
               }->{$self->{c}}) {
        my ($l, $c) = ($self->{line}, $self->{column});
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        return {type => $t, line => $l, column => $c};
        # redo A;
      } elsif (IS_WHITE_SPACE->{$self->{c}}) {
        my ($l, $c) = ($self->{line}, $self->{column});
        W: {
          $self->{c} = $self->{get_char}->($self);
          if (IS_WHITE_SPACE->{$self->{c}}) {
            redo W;
          } else {
            # stay in the state
            # reprocess
            return {type => S_TOKEN, line => $l, column => $c};
            #redo A;
          }
        } # W
      } elsif (my $v = {
        0x007C => [VBAR_TOKEN, DASHMATCH_TOKEN], # |
        0x005E => [DELIM_TOKEN, PREFIXMATCH_TOKEN], # ^
        0x0024 => [DELIM_TOKEN, SUFFIXMATCH_TOKEN], # $
        0x002A => [STAR_TOKEN, SUBSTRINGMATCH_TOKEN], # *
        0x007E => [TILDE_TOKEN, INCLUDES_TOKEN], # ~
      }->{$self->{c}}) {
        $self->{t} = {type => $v->[0], value => chr $self->{c},
                      line => $self->{line}, column => $self->{column},
                      _equal_state => $v->[1]};
        $self->{c} = $self->{get_char}->($self);
        $self->{state} = BEFORE_EQUAL_STATE;
        redo A;
      } elsif ($self->{c} == EOF_CHAR) {
        ## Stay in this state.
        #$self->{c} = $self->{get_char}->($self);
        return {type => EOF_TOKEN,
                line => $self->{line}, column => $self->{column}};
        #redo A;
      } else {
        ## Stay in this state.
        $self->{t} = {type => DELIM_TOKEN, value => chr $self->{c},
                      line => $self->{line}, column => $self->{column}};
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      }

    } elsif ($self->{state} == BEFORE_NMSTART_STATE) {
      ## NOTE: |nmstart| in |ident| in (|IDENT|, |DIMENSION|, or
      ## |FUNCTION|)
      if (IS_NAME_START ($self->{c})) {
        $self->{t}->{value} .= chr $self->{c};
        $self->{t}->{type} = DIMENSION_TOKEN
            if $self->{t}->{type} == NUMBER_TOKEN;
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_IDENT;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002D) { # -
        #XXX
        if ($self->{t}->{type} == IDENT_TOKEN) {
          #$self->normalize_surrogate ($self->{t}->{value});
          $self->{c} = $self->{get_char}->($self);
          if ($self->{c} == 0x003E) { # >
            $self->{state} = BEFORE_TOKEN_STATE;
            $self->{c} = $self->{get_char}->($self);
            return {type => CDC_TOKEN,
                    line => $self->{t}->{line},
                    column => $self->{t}->{column}}; # XXX
            #redo A;
          } else {
            ## NOTE: |-|, |-|, $self->{c}
            #$self->{t} = {type => IDENT_TOKEN, value => '-'};
            $self->{t}->{column}++;
            # stay in the state
            # reconsume
            return {type => MINUS_TOKEN,
                    line => $self->{t}->{line},
                    column => $self->{t}->{column} - 1};
            #redo A;
          }
        } elsif ($self->{t}->{type} == DIMENSION_TOKEN) {
          my ($l, $c) = ($self->{line}, $self->{column}); # second '-'
          $self->{c} = $self->{get_char}->($self);
          if ($self->{c} == 0x003E) { # >
            unshift @{$self->{token}}, {type => CDC_TOKEN,
                                        line => $self->{line_prev},
                                        column => $self->{column_prev}-1}; # XXX
            $self->{t}->{type} = NUMBER_TOKEN;
            $self->{t}->{value} = '';
            $self->{state} = BEFORE_TOKEN_STATE;
            $self->{c} = $self->{get_char}->($self);
            return $self->{t};
            #redo A;
          } else {
            ## NOTE: NUMBER, |-|, |-|, $self->{c}
            my $t = $self->{t};
            $t->{type} = NUMBER_TOKEN;
            $t->{value} = '';
            $self->{t} = {type => IDENT_TOKEN, value => '-', hyphen => 1,
                          line => $l, column => $c};
            unshift @{$self->{token}}, {type => MINUS_TOKEN,
                                        line => $l, column => $c - 1};
            # stay in the state
            # reconsume
            return $t;
            #redo A;
          }
        } else {
          #
        }
      } else {
        #
      }
      
      if ($self->{t}->{type} == DIMENSION_TOKEN) {
        ## NOTE: |-| after |NUMBER|.
        unshift @{$self->{token}}, {type => MINUS_TOKEN,
                                    line => $self->{line},
                                    column => $self->{column} - 1};
        ## BUG: column might be wrong if on the line boundary.
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        $self->{t}->{type} = NUMBER_TOKEN;
        $self->{t}->{value} = '';
        return $self->{t};
      } else {
        ## NOTE: |-| not followed by |nmstart|.
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return {type => MINUS_TOKEN,
                line => $self->{line}, column => $self->{column} - 1};
        ## BUG: column might be wrong if on the line boundary.
      }
    } elsif ($self->{state} == AFTER_AT_STATE) {
      if ((0x0041 <= $self->{c} and $self->{c} <= 0x005A) or # A..Z
          (0x0061 <= $self->{c} and $self->{c} <= 0x007A) or # a..z
          $self->{c} == 0x005F or # _
          $self->{c} > 0x007F) { # nonascii
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002D) { # -
        $self->{t}->{value} .= '-';
        $self->{state} = AFTER_AT_HYPHEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_IDENT;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return {type => DELIM_TOKEN, value => '@',
                line => $self->{line_prev},
                column => $self->{column_prev}};
      }
    } elsif ($self->{state} == AFTER_AT_HYPHEN_STATE) {
      if (IS_NAME_START ($self->{c})) {
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002D) { # -  @--
        my $t = $self->{t};
        $t->{type} = DELIM_TOKEN;
        $t->{value} = '@';
        delete $t->{hyphen};
        $self->{t} = {type => IDENT_TOKEN, hyphen => 1, value => '-',
                      line => $self->{line_prev},
                      column => $self->{column_prev}};
        $self->{state} = MINUS_MINUS_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $t;
        #redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_IDENT;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        my $t = $self->{t};
        $t->{type} = DELIM_TOKEN;
        $t->{value} = '@';
        delete $t->{hyphen};
        $self->{t} = {type => IDENT_TOKEN, hyphen => 1, value => '-',
                      line => $self->{line_prev},
                      column => $self->{column_prev}};
        $self->{state} = MINUS_STATE;
        ## Reprocess the current input character.
        return $t;
        #redo A;
      }
    } elsif ($self->{state} == AFTER_NUMBER_STATE) {
      if ($self->{c} == 0x002D) { # -
        ## NOTE: |-| in |ident|.
        $self->{t}->{hyphen} = 1;
        $self->{t}->{value} = '-';
        $self->{t}->{type} = DIMENSION_TOKEN;
        $self->{state} = BEFORE_NMSTART_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ((0x0041 <= $self->{c} and $self->{c} <= 0x005A) or # A..Z
               (0x0061 <= $self->{c} and $self->{c} <= 0x007A) or # a..z
               $self->{c} == 0x005F or # _
               $self->{c} > 0x007F) { # nonascii
        ## NOTE: |nmstart| in |ident|.
        $self->{t}->{value} = chr $self->{c};
        $self->{t}->{type} = DIMENSION_TOKEN;
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x005C) { # \
        ## NOTE: |nmstart| in |ident| in |IDENT|
        $self->{t}->{value} = '';
        $self->{t}->{type} = DIMENSION_TOKEN;
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_IDENT;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0025) { # %
        $self->{t}->{type} = PERCENTAGE_TOKEN;
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } else {
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return $self->{t};
        #redo A;
      }

    } elsif ($self->{state} == HASH_OPEN_STATE) {
      ## Consume a token
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-token> -
      ## U+0023 NUMBER SIGN (#)

      ## NOTE: The first |nmchar| in |name| in |HASH|.
      if ((0x0041 <= $self->{c} and $self->{c} <= 0x005A) or # A..Z
          (0x0061 <= $self->{c} and $self->{c} <= 0x007A) or # a..z
          (0x0030 <= $self->{c} and $self->{c} <= 0x0039) or # 0..9
          $self->{c} == 0x002D or # -
          $self->{c} == 0x005F or # _
          $self->{c} > 0x007F) { # nonascii
        ## A name character
        $self->{t}->{not_ident} = 1 # <hash>'s type != "id"
            if (0x0030 <= $self->{c} and $self->{c} <= 0x0039); # 0..9
        $self->{t}->{hyphen} = 1 if $self->{c} == 0x002D; # -
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_IDENT;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return {type => DELIM_TOKEN, value => '#',
                line => $self->{t}->{line},
                column => $self->{t}->{column}};
        #redo A;
      }

    } elsif ($self->{state} == NAME_STATE) {
      ## NOTE: |nmchar| in (|ident| or |name|).
      if ((0x0041 <= $self->{c} and $self->{c} <= 0x005A) or # A..Z
          (0x0061 <= $self->{c} and $self->{c} <= 0x007A) or # a..z
          (0x0030 <= $self->{c} and $self->{c} <= 0x0039) or # 0..9
          $self->{c} == 0x005F or # _
          $self->{c} == 0x002D or # -
          $self->{c} > 0x007F) { # nonascii
        $self->{t}->{not_ident} = 1 if
            $self->{t}->{hyphen} and
            $self->{t}->{value} eq '-' and
            ((0x0030 <= $self->{c} and $self->{c} <= 0x0039) or # 0..9
             $self->{c} == 0x002D); # -
        $self->{t}->{value} .= chr $self->{c};
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_IDENT;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0028 and # (
               $self->{t}->{type} == IDENT_TOKEN) { # (
        my $func_name = $self->{t}->{value};
        $func_name =~ tr/A-Z/a-z/; ## TODO: Unicode or ASCII case-insensitive?
        if ($func_name eq 'url' or $func_name eq 'url-prefix') {
          if ($self->{t}->{has_escape}) {
            ## TODO: warn
          }
          $self->{t}->{type}
              = $func_name eq 'url' ? URI_TOKEN : URI_PREFIX_TOKEN;
          $self->{t}->{value} = '';
          $self->{state} = URI_BEFORE_WSP_STATE;
          $self->{c} = $self->{get_char}->($self);
          redo A;
        } else {
          $self->{t}->{type} = FUNCTION_TOKEN;
          $self->{state} = BEFORE_TOKEN_STATE;
          $self->{c} = $self->{get_char}->($self);
          return $self->{t};
          #redo A;
        }
      } else {
        $self->{t}->{not_ident} = 1
            if $self->{t}->{value} eq '-' and $self->{t}->{hyphen};
        $self->normalize_surrogate ($self->{t}->{value});
        $self->{state} = BEFORE_TOKEN_STATE;
        # reconsume
        return $self->{t};
        #redo A;
      }
    } elsif ($self->{state} == URI_BEFORE_WSP_STATE) {
      while ({
                0x0020 => 1, # SP
                0x0009 => 1, # \t
                0x000D => 1, # \r
                0x000A => 1, # \n
                0x000C => 1, # \f
             }->{$self->{c}}) {
        $self->{c} = $self->{get_char}->($self);
      }
      if ($self->{c} == -1) {
        $self->{t}->{type} = {
            URI_TOKEN, URI_INVALID_TOKEN,
            URI_INVALID_TOKEN, URI_INVALID_TOKEN,
            URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
            URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}};        
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } elsif ($self->{c} < 0x0020 or $self->{c} == 0x0028) { # C0 or (
        ## TODO: Should we consider matches of "(" and ")"?
        $self->{t}->{type} = {
            URI_TOKEN, URI_INVALID_TOKEN,
            URI_INVALID_TOKEN, URI_INVALID_TOKEN,
            URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
            URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}};
        $self->{state} = URI_UNQUOTED_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0022 or $self->{c} == 0x0027) { # " or '
        $self->{state} = STRING_STATE;
        $self->{end_char} = $self->{c};
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0029) { # )
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_URL;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = URI_UNQUOTED_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      }
    } elsif ($self->{state} == URI_UNQUOTED_STATE) {
      if ({
           0x0020 => 1, # SP
           0x0009 => 1, # \t
           0x000D => 1, # \r
           0x000A => 1, # \n
           0x000C => 1, # \f
          }->{$self->{c}}) {
        $self->{state} = URI_AFTER_WSP_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == -1) {
        $self->{t}->{type} = {
            URI_TOKEN, URI_INVALID_TOKEN,
            URI_INVALID_TOKEN, URI_INVALID_TOKEN,
            URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
            URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}};        
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } elsif ($self->{c} < 0x0020 or {
          0x0022 => 1, # "
          0x0027 => 1, # '
          0x0028 => 1, # (
      }->{$self->{c}}) { # C0 or (
        ## TODO: Should we consider matches of "(" and ")", '"', or "'"?
        $self->{t}->{type} = {
            URI_TOKEN, URI_INVALID_TOKEN,
            URI_INVALID_TOKEN, URI_INVALID_TOKEN,
            URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
            URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}};
        # stay in the state.
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0029) { # )
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_URL;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{value} .= chr $self->{c};
        # stay in the state.
        $self->{c} = $self->{get_char}->($self);
        redo A;
      }
    } elsif ($self->{state} == URI_AFTER_WSP_STATE) {
      if ({
           0x0020 => 1, # SP
           0x0009 => 1, # \t
           0x000D => 1, # \r
           0x000A => 1, # \n
           0x000C => 1, # \f
          }->{$self->{c}}) {
        # stay in the state.
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == -1) {
        $self->{t}->{type} = {
            URI_TOKEN, URI_INVALID_TOKEN,
            URI_INVALID_TOKEN, URI_INVALID_TOKEN,
            URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
            URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}};        
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } elsif ($self->{c} == 0x0029) { # )
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_URL;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        ## TODO: Should we consider matches of "(" and ")", '"', or "'"?
        $self->{t}->{type} = {
            URI_TOKEN, URI_INVALID_TOKEN,
            URI_INVALID_TOKEN, URI_INVALID_TOKEN,
            URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
            URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}};
        # stay in the state.
        $self->{c} = $self->{get_char}->($self);
        redo A;
      }

    } elsif ($self->{state} == ESCAPE_OPEN_STATE) {
      if (IS_HEX_DIGIT->{$self->{c}}) {
        ## NOTE: second character of |unicode| in |escape|.
        $self->{t}->{has_escape} = 1;
        $self->{escape_value} = chr $self->{c};
        $self->{state} = ESCAPE_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x000A or # \n
               $self->{c} == 0x000C) { # \f # XXX
        $self->onerror->(type => 'css:escape:broken', # XXX
                         level => 'm',
                         uri => $self->context->urlref,
                         line => $self->{line_prev},
                         column => $self->{column_prev});
        $self->{t}->{has_escape} = 1;
        if (defined $self->{end_char}) {
          ## Note: In |nl| in ... in |string| or |ident|.
          $self->{state} = STRING_STATE;
          $self->{c} = $self->{get_char}->($self);
          redo A;
        } elsif ($self->{escape_mode} == ESCAPE_MODE_URL) {
          ## NOTE: In |escape| in |URI|.
          $self->{t}->{type} = {
              URI_TOKEN, URI_INVALID_TOKEN,
              URI_INVALID_TOKEN, URI_INVALID_TOKEN,
              URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
              URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
          }->{$self->{t}->{type}};
          $self->{t}->{value} .= chr $self->{c};
          $self->{state} = URI_UNQUOTED_STATE;
          $self->{c} = $self->{get_char}->($self);
          redo A;
        } else {
          #
        }
      } elsif ($self->{c} == 0x000D) { # \r # XXX
        $self->{t}->{has_escape} = 1;
        if (defined $self->{end_char}) {
          ## Note: In |nl| in ... in |string| or |ident|.
          $self->{state} = ESCAPE_BEFORE_LF_STATE;
          $self->{c} = $self->{get_char}->($self);
          redo A;
        } elsif ($self->{escape_mode} == ESCAPE_MODE_URL) {
          ## NOTE: In |escape| in |URI|.
          $self->{t}->{type} = {
              URI_TOKEN, URI_INVALID_TOKEN,
              URI_INVALID_TOKEN, URI_INVALID_TOKEN,
              URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
              URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
          }->{$self->{t}->{type}};
          $self->{state} = ESCAPE_BEFORE_LF_STATE;
          $self->{c} = $self->{get_char}->($self);
          redo A;
        } else {
          #
        }
      } elsif ($self->{c} == EOF_CHAR) {
        $self->onerror->(type => 'css:escape:broken', # XXX
                         level => 'm',
                         uri => $self->context->urlref,
                         line => $self->{line_prev},
                         column => $self->{column_prev});
        $self->{t}->{has_escape} = 1;
        $self->{t}->{value} .= "\x{FFFD}";
        $self->{state} = EM2STATE->{$self->{escape_mode}};
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        ## NOTE: second character of |escape|.
        $self->{t}->{has_escape} = 1;
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = EM2STATE->{$self->{escape_mode}};
        $self->{c} = $self->{get_char}->($self);
        redo A;
      }

      if (defined $self->{end_char}) {
        $self->{t}->{type} = {
          STRING_TOKEN, INVALID_TOKEN,
          URI_TOKEN, URI_INVALID_TOKEN,
          URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}} || $self->{t}->{type};
        $self->{state} = BEFORE_TOKEN_STATE;
        delete $self->{end_char};
        # reprocess
        return $self->{t};
        #redo A;
      } elsif ($self->{escape_mode} == ESCAPE_MODE_IDENT) {
        if ($self->{t}->{type} == DIMENSION_TOKEN) {
          if ($self->{t}->{hyphen} and $self->{t}->{value} eq '-') {
            $self->{state} = BEFORE_TOKEN_STATE;
            # reprocess
            unshift @{$self->{token}}, {type => DELIM_TOKEN, value => '\\',
                                        line => $self->{line_prev},
                                        column => $self->{column_prev} - 1};
            unshift @{$self->{token}}, {type => MINUS_TOKEN,
                                        line => $self->{line_prev},
                                        column => $self->{column_prev}};
            $self->{t}->{type} = NUMBER_TOKEN;
            $self->{t}->{value} = '';
            return $self->{t};
            #redo A;
          } elsif (length $self->{t}->{value}) {
            $self->{state} = BEFORE_TOKEN_STATE;
            # reprocess
            unshift @{$self->{token}}, {type => DELIM_TOKEN, value => '\\',
                                        line => $self->{line_prev},
                                        column => $self->{column_prev}};
            return $self->{t};
            #redo A;
          } else {
            $self->{state} = BEFORE_TOKEN_STATE;
            # reprocess
            unshift @{$self->{token}}, {type => DELIM_TOKEN, value => '\\',
                                        line => $self->{line_prev},
                                        column => $self->{column_prev}};
            $self->{t}->{type} = NUMBER_TOKEN;
            $self->{t}->{value} = '';
            return $self->{t};
            #redo A;
          }
        } else {
          ## \ -> [DELIM \]
          ## #\ -> [DELIM #][DELIM \]
          ## -\ -> [MINUS][DELIM \]
          ## #-\ -> [HASH -][DELIM \]
          ## a\ -> [IDENT a][DELIM \]
          ## #a\ -> [HASH a][DELIM \]

          unshift @{$self->{token}},
              {type => DELIM_TOKEN, value => '\\',
               line => $self->{line_prev}, column => $self->{column_prev}};

          if ($self->{t}->{hyphen} and $self->{t}->{value} eq '-' and
              not $self->{t}->{type} == HASH_TOKEN) {
            unshift @{$self->{token}},
                {type => MINUS_TOKEN,
                 line => $self->{line_prev},
                 column => $self->{column_prev} - 1};
            $self->{t}->{value} = '';
          }

          if (length $self->{t}->{value}) {
            $self->normalize_surrogate ($self->{t}->{value});
            $self->{t}->{not_ident} = 1
                if $self->{t}->{type} == HASH_TOKEN and
                   $self->{t}->{value} eq '-' and $self->{t}->{hyphen};
            $self->{state} = BEFORE_TOKEN_STATE;
            # reprocess
            return $self->{t};
            #redo A;
          } elsif ($self->{t}->{type} == HASH_TOKEN) {
            unshift @{$self->{token}},
                {type => DELIM_TOKEN, value => '#',
                 line => $self->{line_prev}, column => $self->{column_prev}-1};
          }

          $self->{state} = BEFORE_TOKEN_STATE;
          # reprocess
          return shift @{$self->{token}};
          #redo A;
        }
      } elsif ($self->{escape_mode} == ESCAPE_MODE_URL) {
        $self->{state} = URI_UNQUOTED_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      }
    } elsif ($self->{state} == ESCAPE_STATE) {
      ## NOTE: third..seventh character of |unicode| in |escape|.
      if (IS_HEX_DIGIT->{$self->{c}}) {
        $self->{escape_value} .= chr $self->{c};
        if (6 == length $self->{escape_value}) {
          $self->{state} = ESCAPE_BEFORE_NL_STATE;
        } ## else, stay in this state.
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0020 or # SP
               $self->{c} == 0x000A or # \n
               $self->{c} == 0x0009 or # \t
               $self->{c} == 0x000C) { # \f
        $self->{t}->{value} .= $self->_escaped_char;
        $self->{state} = EM2STATE->{$self->{escape_mode}};
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x000D) { # \r
        $self->{t}->{value} .= $self->_escaped_char;
        $self->{state} = ESCAPE_BEFORE_LF_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{value} .= $self->_escaped_char;
        $self->{state} = EM2STATE->{$self->{escape_mode}};
        # reconsume
        redo A;
      }
    } elsif ($self->{state} == ESCAPE_BEFORE_NL_STATE) {
      ## NOTE: eightth character of |unicode| in |escape|.
      if ($self->{c} == 0x0020 or # SP
          $self->{c} == 0x000A or # \n
          $self->{c} == 0x0009 or # \t
          $self->{c} == 0x000C) { # \f
        $self->{t}->{value} .= $self->_escaped_char;
        $self->{state} = EM2STATE->{$self->{escape_mode}};
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x000D) { # \r
        $self->{t}->{value} .= $self->_escaped_char;
        $self->{state} = ESCAPE_BEFORE_LF_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{value} .= $self->_escaped_char;
        $self->{state} = EM2STATE->{$self->{escape_mode}};
        # reconsume
        redo A;
      }
    } elsif ($self->{state} == ESCAPE_BEFORE_LF_STATE) {
      ## NOTE: |\n| in |\r\n| in |nl| in |escape|.
      if ($self->{c} == 0x000A) { # \n
        $self->{state} = EM2STATE->{$self->{escape_mode}};
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = EM2STATE->{$self->{escape_mode}};
        # reprocess
        redo A;
      }

    } elsif ($self->{state} == STRING_STATE) {
      ## Consume a string token
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-string-token>.

      ## NOTE: A character in |string$Q| in |string| in |STRING|, or
      ## a character in |invalid$Q| in |invalid| in |INVALID|,
      ## where |$Q = $self->{end_char} == 0x0022 ? 1 : 2|.
      ## Or, in |URI|.
      if ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{escape_mode} = ESCAPE_MODE_STRING;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == $self->{end_char}) { # ending character (" | ')
        if ($self->{t}->{type} == STRING_TOKEN) {
          $self->normalize_surrogate ($self->{t}->{value});
          $self->{state} = BEFORE_TOKEN_STATE;
          delete $self->{end_char};
          $self->{c} = $self->{get_char}->($self);
          return $self->{t};
          #redo A;
        } else {
          $self->{state} = URI_AFTER_WSP_STATE;
          delete $self->{end_char};
          $self->{c} = $self->{get_char}->($self);
          redo A;
        }
      } elsif ($self->{c} == EOF_CHAR) {
        $self->onerror->(type => 'css:string:eof', # XXX
                         level => 'w',
                         uri => $self->context->urlref,
                         line => $self->{line},
                         column => $self->{column});
        $self->normalize_surrogate ($self->{t}->{value});
        $self->{state} = BEFORE_TOKEN_STATE;
        delete $self->{end_char};
        # reconsume
        return $self->{t};
        #redo A;
      } elsif (IS_NEWLINE->{$self->{c}}) {
        $self->onerror->(type => 'css:string:newline', # XXX
                         level => 'm',
                         uri => $self->context->urlref,
                         line => $self->{line},
                         column => $self->{column});
        $self->{t}->{type} = {
          STRING_TOKEN, INVALID_TOKEN,
          INVALID_TOKEN, INVALID_TOKEN,
          URI_TOKEN, URI_INVALID_TOKEN,
          URI_INVALID_TOKEN, URI_INVALID_TOKEN,
          URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
          URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}};
        $self->{state} = BEFORE_TOKEN_STATE;
        # reconsume
        return $self->{t};
        #redo A;
      } else {
        $self->{t}->{value} .= chr $self->{c};
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        redo A;
      }

    } elsif ($self->{state} == PLUS_STATE) {
      ## Consume a number
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-number>.

      if (IS_DIGIT->{$self->{c}}) {
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NUMBER_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002E) { # .
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = PLUS_DOT_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{type} = PLUS_TOKEN;
        delete $self->{t}->{value};
        $self->{state} = BEFORE_TOKEN_STATE;
        ## Reconsume the current input character.
        return $self->{t};
      }

    } elsif ($self->{state} == PLUS_DOT_STATE) {
      ## Consume a number
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-number>.

      if (IS_DIGIT->{$self->{c}}) {
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NUMBER_DOT_NUMBER_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{type} = PLUS_TOKEN;
        delete $self->{t}->{value};
        unshift @{$self->{token}},
            {type => DOT_TOKEN,
             line => $self->{line_prev}, column => $self->{column_prev}};
        $self->{state} = BEFORE_TOKEN_STATE;
        ## Reconsume the current input character.
        return $self->{t};
      }

    } elsif ($self->{state} == MINUS_STATE) {
      if (IS_DIGIT->{$self->{c}}) {
        $self->{t}->{type} = NUMBER_TOKEN;
        $self->{t}->{value} .= chr $self->{c};
        delete $self->{t}->{hyphen};
        $self->{state} = NUMBER_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002E) { # .
        $self->{t}->{type} = NUMBER_TOKEN;
        $self->{t}->{value} .= chr $self->{c};
        delete $self->{t}->{hyphen};
        $self->{state} = MINUS_DOT_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002D) { # -
        $self->{state} = MINUS_MINUS_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = BEFORE_NMSTART_STATE;
        ## Reconsume the current input character.
        redo A;
      }
    } elsif ($self->{state} == MINUS_DOT_STATE) {
      ## Consume a number
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-number>.

      if (IS_DIGIT->{$self->{c}}) {
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NUMBER_DOT_NUMBER_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{type} = MINUS_TOKEN;
        delete $self->{t}->{value};
        unshift @{$self->{token}},
            {type => DOT_TOKEN,
             line => $self->{line_prev}, column => $self->{column_prev}};
        $self->{state} = BEFORE_TOKEN_STATE;
        ## Reconsume the current input character.
        return $self->{t};
      }
    } elsif ($self->{state} == MINUS_MINUS_STATE) {
      if ($self->{c} == 0x003E) { # >
        $self->{t}->{type} = CDC_TOKEN;
        delete $self->{t}->{value};
        delete $self->{t}->{hyphen};
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } elsif ($self->{c} == 0x002D) { # -
        $self->{t}->{type} = MINUS_TOKEN;
        delete $self->{t}->{value};
        delete $self->{t}->{hyphen};
        my $t = $self->{t};
        $self->{t} = {type => IDENT_TOKEN, hyphen => 1, value => '-',
                      line => $self->{line_prev},
                      column => $self->{column_prev}};
        ## Stay in this state.
        $self->{c} = $self->{get_char}->($self);
        return $t;
        #redo A;
      } else {
        $self->{t}->{type} = MINUS_TOKEN;
        delete $self->{t}->{value};
        delete $self->{t}->{hyphen};
        my $t = $self->{t};
        $self->{t} = {type => IDENT_TOKEN, hyphen => 1, value => '-',
                      line => $self->{line_prev},
                      column => $self->{column_prev}};
        $self->{state} = MINUS_STATE;
        ## Reconsume the current input character.
        return $t;
        #redo A;
      }

    } elsif ($self->{state} == NUMBER_STATE) {
      ## NOTE: 2nd, 3rd, or ... character in |num| before |.|.
      if (0x0030 <= $self->{c} and $self->{c} <= 0x0039) {
        $self->{t}->{value} .= chr $self->{c};
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002E) { # .
        $self->{state} = NUMBER_DOT_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0045 or $self->{c} == 0x0065) { # E e
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NUMBER_E_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{number} = $self->{t}->{value};
        $self->{t}->{value} = '';
        $self->{state} = AFTER_NUMBER_STATE;
        # reprocess
        redo A;
      }
    } elsif ($self->{state} == NUMBER_DOT_STATE) {
      ## NOTE: The character immediately following |.| in |num|.
      if (0x0030 <= $self->{c} and $self->{c} <= 0x0039) {
        $self->{t}->{value} .= '.' . chr $self->{c};
        $self->{state} = NUMBER_DOT_NUMBER_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        unshift @{$self->{token}},
            {type => DOT_TOKEN,
             line => $self->{line_prev}, column => $self->{column_prev}};
        $self->{t}->{number} = $self->{t}->{value};
        $self->{t}->{value} = '';
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return $self->{t};
        #redo A;
      }
    } elsif ($self->{state} == NUMBER_FRACTION_STATE) {
      ## NOTE: The character immediately following |.| at the beginning of |num|.
      if (0x0030 <= $self->{c} and $self->{c} <= 0x0039) {
        $self->{t}->{value} .= '.' . chr $self->{c};
        $self->{state} = NUMBER_DOT_NUMBER_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return {type => DOT_TOKEN,
                line => $self->{line}, column => $self->{column} - 1};
        ## BUG: line and column might be wrong if they are on the
        ## line boundary.
        #redo A;
      }
    } elsif ($self->{state} == NUMBER_DOT_NUMBER_STATE) {
      ## NOTE: |[0-9]| in |num| after |.|.
      if (0x0030 <= $self->{c} and $self->{c} <= 0x0039) {
        $self->{t}->{value} .= chr $self->{c};
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0045 or $self->{c} == 0x0065) { # E e
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NUMBER_E_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{number} = $self->{t}->{value};
        $self->{t}->{value} = '';
        $self->{state} = AFTER_NUMBER_STATE;
        ## Reprocess the current input character.
        redo A;
      }
    } elsif ($self->{state} == NUMBER_E_STATE) {
      if (IS_DIGIT->{$self->{c}}) {
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NUMBER_E_NUMBER_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{type} = DIMENSION_TOKEN;
        $self->{t}->{number} = substr $self->{t}->{value}, 0, -1;
        $self->{t}->{value} = substr $self->{t}->{value}, -1;
        $self->{state} = NAME_STATE;
        ## Reprocess the current input character.
        redo A;
      }
    } elsif ($self->{state} == NUMBER_E_NUMBER_STATE) {
      if (IS_DIGIT->{$self->{c}}) {
        $self->{t}->{value} .= chr $self->{c};
        ## Stay in this state.
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{number} = $self->{t}->{value};
        $self->{t}->{value} = '';
        $self->{state} = AFTER_NUMBER_STATE;
        ## Reprocess the current input character.
        redo A;
      }

    } elsif ($self->{state} == BEFORE_EQUAL_STATE) {
      if ($self->{c} == 0x003D) { # = (|=, *=, ^=, $=)
        $self->{t}->{type} = delete $self->{t}->{_equal_state};
        delete $self->{t}->{value};
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
      } elsif ($self->{t}->{type} == VBAR_TOKEN and
               $self->{c} == 0x007C) { # |
        $self->{t}->{type} = COLUMN_TOKEN;
        delete $self->{t}->{value};
        delete $self->{t}->{_equal_state};
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
      } else {
        delete $self->{t}->{_equal_state};
        delete $self->{t}->{value} if $self->{t}->{type} != DELIM_TOKEN;
        $self->{state} = BEFORE_TOKEN_STATE;
        # Reprocess the current input character.
        return $self->{t};
      }

    } elsif ($self->{state} == SLASH_STATE) {
      if ($self->{c} == 0x002A) { # *
        $self->{state} = COMMENT_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = BEFORE_TOKEN_STATE;
        ## Reprocess the current input character.
        return $self->{t};
        #redo A;
      }
    } elsif ($self->{state} == COMMENT_STATE) {
      if ($self->{c} == 0x002A) { # *
        $self->{state} = COMMENT_STAR_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == EOF_CHAR) {
        $self->{state} = BEFORE_TOKEN_STATE;
        #$self->{c} = $self->{get_char}->($self);
        return {type => EOF_TOKEN,
                line => $self->{line}, column => $self->{column}};
        #redo A;
      } else {
        ## Stay in this state.
        $self->{c} = $self->{get_char}->($self)
            while $self->{c} >= 0x0000 and $self->{c} != 0x002A; # *
        redo A;
      }
    } elsif ($self->{state} == COMMENT_STAR_STATE) {
      if ($self->{c} == 0x002F) { # /
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002A) { # *
        ## Stay in this state.
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == EOF_CHAR) {
        $self->{state} = BEFORE_TOKEN_STATE;
        #$self->{c} = $self->{get_char}->($self);
        return {type => EOF_TOKEN,
                line => $self->{line}, column => $self->{column}};
        #redo A;
      } else {
        $self->{state} = COMMENT_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      }

    } elsif ($self->{state} == LESS_THAN_STATE) {
      if ($self->{c} == 0x0021) { # !
        $self->{state} = MDO_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = BEFORE_TOKEN_STATE;
        ## Reconsume the current input character.
        return $self->{t}; # DELIM_TOKEN(<)
        #redo A;
      }
    } elsif ($self->{state} == MDO_STATE) {
      if ($self->{c} == 0x002D) { # -
        $self->{state} = MDO_HYPHEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        unshift @{$self->{token}},
            {type => EXCLAMATION_TOKEN,
             line => $self->{line_prev}, column => $self->{column_prev}};
        $self->{state} = BEFORE_TOKEN_STATE;
        ## Reconsume the current input character.
        return $self->{t};
        #redo A;
      }
    } elsif ($self->{state} == MDO_HYPHEN_STATE) {
      if ($self->{c} == 0x002D) { # -
        $self->{t}->{type} = CDO_TOKEN;
        delete $self->{t}->{value};
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } else {
        my $t = $self->{t};
        unshift @{$self->{token}},
            {type => EXCLAMATION_TOKEN,
             line => $self->{line_prev}, column => $self->{column_prev}-1};
        $self->{t} = {type => IDENT_TOKEN, hyphen => 1, value => '-',
                      line => $self->{line_prev},
                      column => $self->{column_prev}};
        $self->{state} = MINUS_STATE;
        ## Reconsume the current input character.
        return $t;
        #redo A;
      }

    } else {
      die "$0: Unknown state |$self->{state}|";
    }
  } # A
} # get_next_token

sub serialize_token ($$) {
  shift;
  my $t = shift;

  ## NOTE: This function is not intended for roundtrip-able serialization.

  if ($t->{type} == IDENT_TOKEN) {
    return $t->{value};
  } elsif ($t->{type} == ATKEYWORD_TOKEN) {
    return '@' . $t->{value};
  } elsif ($t->{type} == HASH_TOKEN) {
    return '#' . $t->{value};
  } elsif ($t->{type} == FUNCTION_TOKEN) {
    return $t->{value} . '(';
  } elsif ($t->{type} == URI_TOKEN) {
    return 'url(' . $t->{value} . ')';
  } elsif ($t->{type} == URI_INVALID_TOKEN) {
    return 'url(' . $t->{value};
  } elsif ($t->{type} == URI_PREFIX_TOKEN) {
    return 'url-prefix(' . $t->{value} . ')';
  } elsif ($t->{type} == URI_PREFIX_INVALID_TOKEN) {
    return 'url-prefix(' . $t->{value};
  } elsif ($t->{type} == STRING_TOKEN) {
    return '"' . $t->{value} . '"';
  } elsif ($t->{type} == INVALID_TOKEN) {
    return '"' . $t->{value};
  } elsif ($t->{type} == NUMBER_TOKEN) {
    return $t->{number};
  } elsif ($t->{type} == DIMENSION_TOKEN) {
    return $t->{number} . $t->{value};
  } elsif ($t->{type} == PERCENTAGE_TOKEN) {
    return $t->{number} . '%';
  } elsif ($t->{type} == UNICODE_RANGE_TOKEN) {
    return 'U+' . $t->{value};
  } elsif ($t->{type} == DELIM_TOKEN) {
    return $t->{value};
  } elsif ($t->{type} == PLUS_TOKEN) {
    return '+';
  } elsif ($t->{type} == GREATER_TOKEN) {
    return '>';
  } elsif ($t->{type} == COMMA_TOKEN) {
    return ',';
  } elsif ($t->{type} == TILDE_TOKEN) {
    return '~';
  } elsif ($t->{type} == DASHMATCH_TOKEN) {
    return '|=';
  } elsif ($t->{type} == PREFIXMATCH_TOKEN) {
    return '^=';
  } elsif ($t->{type} == SUFFIXMATCH_TOKEN) {
    return '$=';
  } elsif ($t->{type} == SUBSTRINGMATCH_TOKEN) {
    return '*=';
  } elsif ($t->{type} == INCLUDES_TOKEN) {
    return '~=';
  } elsif ($t->{type} == SEMICOLON_TOKEN) {
    return ';';
  } elsif ($t->{type} == LBRACE_TOKEN) {
    return '{';
  } elsif ($t->{type} == RBRACE_TOKEN) {
    return '}';
  } elsif ($t->{type} == LPAREN_TOKEN) {
    return '(';
  } elsif ($t->{type} == RPAREN_TOKEN) {
    return ')';
  } elsif ($t->{type} == LBRACKET_TOKEN) {
    return '[';
  } elsif ($t->{type} == RBRACKET_TOKEN) {
    return ']';
  } elsif ($t->{type} == S_TOKEN) {
    return ' ';
  } elsif ($t->{type} == CDO_TOKEN) {
    return '<!--';
  } elsif ($t->{type} == CDC_TOKEN) {
    return '-->';
  } elsif ($t->{type} == EOF_TOKEN) {
    return '{EOF}';
  } elsif ($t->{type} == MINUS_TOKEN) {
    return '-';
  } elsif ($t->{type} == STAR_TOKEN) {
    return '*';
  } elsif ($t->{type} == VBAR_TOKEN) {
    return '|';
  } elsif ($t->{type} == COLON_TOKEN) {
    return ':';
  } elsif ($t->{type} == MATCH_TOKEN) {
    return '=';
  } elsif ($t->{type} == EXCLAMATION_TOKEN) {
    return '!';
  } else {
    return '{'.$t->{type}.'}';
  }
} # serialize_token

sub _escaped_char {
  my $v = hex $_[0]->{escape_value};
  if ($v == 0x0000) {
    $_[0]->onerror->(type => 'css:escape:null',
                     level => 'm',
                     uri => $_[0]->context->urlref,
                     line => $_[0]->{line_prev},
                     column => $_[0]->{column_prev});
    return "\x{FFFD}";
  } elsif ($v > 0x10FFFF) {
    $_[0]->onerror->(type => 'css:escape:not unicode',
                     level => 's',
                     uri => $_[0]->context->urlref,
                     line => $_[0]->{line_prev},
                     column => $_[0]->{column_prev});
    return "\x{FFFD}";
  } else {
    return chr $v;
  }
} # _escaped_char

use Encode;
sub normalize_surrogate {
  ## XXX bad impl...
  $_[1] =~ s{((?:[\x{D800}-\x{DBFF}][\x{DC00}-\x{DF00}])+)}{
    decode 'utf-16be', join '', map { pack 'CC', int ((ord $_) / 0x100), ((ord $_) % 0x100) } split //, $1;
  }ge if defined $_[1];
} # _normalize_surrogate

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
