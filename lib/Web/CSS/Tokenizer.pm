package Whatpm::CSS::Tokenizer;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '1.21';

require Exporter;
push our @ISA, 'Exporter';

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

sub IDENT_TOKEN () { 1 }
sub ATKEYWORD_TOKEN () { 2 }
sub HASH_TOKEN () { 3 }
sub FUNCTION_TOKEN () { 4 }
sub URI_TOKEN () { 5 }
sub URI_INVALID_TOKEN () { 6 }
sub URI_PREFIX_TOKEN () { 7 }
sub URI_PREFIX_INVALID_TOKEN () { 8 }
sub STRING_TOKEN () { 9 }
sub INVALID_TOKEN () { 10 }
sub NUMBER_TOKEN () { 11 }
sub DIMENSION_TOKEN () { 12 }
sub PERCENTAGE_TOKEN () { 13 }
sub UNICODE_RANGE_TOKEN () { 14 }
sub DELIM_TOKEN () { 16 }
sub PLUS_TOKEN () { 17 }
sub GREATER_TOKEN () { 18 }
sub COMMA_TOKEN () { 19 }
sub TILDE_TOKEN () { 20 }
sub DASHMATCH_TOKEN () { 21 }
sub PREFIXMATCH_TOKEN () { 22 }
sub SUFFIXMATCH_TOKEN () { 23 }
sub SUBSTRINGMATCH_TOKEN () { 24 }
sub INCLUDES_TOKEN () { 25 }
sub SEMICOLON_TOKEN () { 26 }
sub LBRACE_TOKEN () { 27 }
sub RBRACE_TOKEN () { 28 }
sub LPAREN_TOKEN () { 29 }
sub RPAREN_TOKEN () { 30 }
sub LBRACKET_TOKEN () { 31 }
sub RBRACKET_TOKEN () { 32 }
sub S_TOKEN () { 33 }
sub CDO_TOKEN () { 34 }
sub CDC_TOKEN () { 35 }
sub COMMENT_TOKEN () { 36 }
sub COMMENT_INVALID_TOKEN () { 37 }
sub EOF_TOKEN () { 38 }
sub MINUS_TOKEN () { 39 }
sub STAR_TOKEN () { 40 }
sub VBAR_TOKEN () { 41 }
sub DOT_TOKEN () { 42 }
sub COLON_TOKEN () { 43 }
sub MATCH_TOKEN () { 44 }
sub EXCLAMATION_TOKEN () { 45 }

our @TokenName = qw(
  0 IDENT ATKEYWORD HASH FUNCTION URI URI_INVALID URI_PREFIX URI_PREFIX_INVALID
  STRING INVALID NUMBER DIMENSION PERCENTAGE UNICODE_RANGE
  0 DELIM PLUS GREATER COMMA TILDE DASHMATCH
  PREFIXMATCH SUFFIXMATCH SUBSTRINGMATCH INCLUDES SEMICOLON
  LBRACE RBRACE LPAREN RPAREN LBRACKET RBRACKET S CDO CDC COMMENT
  COMMENT_INVALID EOF MINUS STAR VBAR DOT COLON MATCH EXCLAMATION
);

our @EXPORT_OK = qw(
  IDENT_TOKEN ATKEYWORD_TOKEN HASH_TOKEN FUNCTION_TOKEN URI_TOKEN
  URI_INVALID_TOKEN URI_PREFIX_TOKEN URI_PREFIX_INVALID_TOKEN
  STRING_TOKEN INVALID_TOKEN NUMBER_TOKEN DIMENSION_TOKEN PERCENTAGE_TOKEN
  UNICODE_RANGE_TOKEN DELIM_TOKEN PLUS_TOKEN GREATER_TOKEN COMMA_TOKEN
  TILDE_TOKEN DASHMATCH_TOKEN PREFIXMATCH_TOKEN SUFFIXMATCH_TOKEN
  SUBSTRINGMATCH_TOKEN INCLUDES_TOKEN SEMICOLON_TOKEN LBRACE_TOKEN
  RBRACE_TOKEN LPAREN_TOKEN RPAREN_TOKEN LBRACKET_TOKEN RBRACKET_TOKEN
  S_TOKEN CDO_TOKEN CDC_TOKEN COMMENT_TOKEN COMMENT_INVALID_TOKEN EOF_TOKEN
  MINUS_TOKEN STAR_TOKEN VBAR_TOKEN DOT_TOKEN COLON_TOKEN MATCH_TOKEN
  EXCLAMATION_TOKEN
);

our %EXPORT_TAGS = ('token' => [@EXPORT_OK]);

sub new ($) {
  my $self = bless {token => [], get_char => sub { -1 }}, shift;
  return $self;
} # new

sub init ($) {
  my $self = shift;
  $self->{state} = BEFORE_TOKEN_STATE;
  $self->{c} = $self->{get_char}->($self);
  #$self->{t} = {type => token-type,
  #              value => value,
  #              number => number,
  #              line => ..., column => ...,
  #              hyphen => bool,
  #              not_ident => bool, # HASH_TOKEN does not contain an identifier
  #              eos => bool};
} # init

sub get_next_token ($) {
  my $self = shift;
  if (@{$self->{token}}) {
    return shift @{$self->{token}};
  }

  my $char;
  my $num; # |{num}|, if any.
  my $i; # |$i + 1|th character in |unicode| in |escape|.
  my $q;
      ## NOTE:
      ##   0: in |ident|.
      ##   1: in |URI| outside of |string|.
      ##   0x0022: in |string1| or |invalid1|.
      ##   0x0027: in |string2| or |invalid2|.

  A: {
    if ($self->{state} == BEFORE_TOKEN_STATE) {
      if ($self->{c} == 0x002D) { # -
        ## NOTE: |-| in |ident| in |IDENT|
        $self->{t} = {type => IDENT_TOKEN, value => '-', hyphen => 1,
                      line => $self->{line}, column => $self->{column}};
        $self->{state} = BEFORE_NMSTART_STATE;
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
      } elsif ((0x0041 <= $self->{c} and $self->{c} <= 0x005A) or # A..Z
               (0x0061 <= $self->{c} and $self->{c} <= 0x007A) or # a..z
               $self->{c} == 0x005F or # _
               $self->{c} > 0x007F) { # nonascii
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
        $self->{state} = ESCAPE_OPEN_STATE; $q = 0;
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
        $self->{state} = STRING_STATE; $q = $self->{c};
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
      } elsif ($self->{c} == 0x002E) { # .
        ## NOTE: |num|.
        $self->{t} = {type => NUMBER_TOKEN, value => '0',
                      line => $self->{line}, column => $self->{column}};
        ## NOTE: 'value' is renamed as 'number' later.
        $self->{state} = NUMBER_FRACTION_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002F) { # /
        my ($l, $c) = ($self->{line}, $self->{column});
        $self->{c} = $self->{get_char}->($self);
        if ($self->{c} == 0x002A) { # *
          C: {
            $self->{c} = $self->{get_char}->($self);
            if ($self->{c} == 0x002A) { # *
              D: {
                $self->{c} = $self->{get_char}->($self);
                if ($self->{c} == 0x002F) { # /
                  #
                } elsif ($self->{c} == 0x002A) { # *
                  redo D;
                } else {
                  redo C;
                }
              } # D
            } elsif ($self->{c} == -1) {
              # stay in the state
              # reprocess
              return {type => COMMENT_INVALID_TOKEN};
              #redo A;
            } else {
              redo C;
            }
          } # C

          # stay in the state.
          $self->{c} = $self->{get_char}->($self);
          redo A;
        } else {
          # stay in the state.
          # reprocess
          return {type => DELIM_TOKEN, value => '/', line => $l, column => $c};
          #redo A;
        }         
      } elsif ($self->{c} == 0x003C) { # <
        my ($l, $c) = ($self->{line}, $self->{column});
        ## NOTE: |CDO|
        $self->{c} = $self->{get_char}->($self);
        if ($self->{c} == 0x0021) { # !
          $self->{c} = $self->{get_char}->($self);
          if ($self->{c} == 0x002D) { # -
            $self->{c} = $self->{get_char}->($self);
            if ($self->{c} == 0x002D) { # -
              $self->{state} = BEFORE_TOKEN_STATE;
              $self->{c} = $self->{get_char}->($self);
              return {type => CDO_TOKEN, line => $l, column => $c};
              #redo A;
            } else {
              unshift @{$self->{token}},
                  {type => EXCLAMATION_TOKEN, line => $l, column => $c + 1};
              ## NOTE: |-| in |ident| in |IDENT|
              $self->{t} = {type => IDENT_TOKEN, value => '-',
                            line => $l, column => $c + 2};
              $self->{state} = BEFORE_NMSTART_STATE;
              #reprocess
              return {type => DELIM_TOKEN, value => '<',
                      line => $l, column => $c};
              #redo A;
            }
          } else {
            unshift @{$self->{token}}, {type => EXCLAMATION_TOKEN,
                                        line => $l, column => $c + 1};
            $self->{state} = BEFORE_TOKEN_STATE;
            #reprocess
            return {type => DELIM_TOKEN, value => '<',
                    line => $l, column => $c};
            #redo A;
          }
        } else {
          $self->{state} = BEFORE_TOKEN_STATE;
          #reprocess
          return {type => DELIM_TOKEN, value => '<',
                  line => $l, column => $c};
          #redo A;
        }
      } elsif (my $t = {
                        0x0021 => EXCLAMATION_TOKEN, # !
                        0x002D => MINUS_TOKEN, # -
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
               }->{$self->{c}}) {
        my ($l, $c) = ($self->{line}, $self->{column});
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        return {type => $t, line => $l, column => $c};
        # redo A;
      } elsif ({
                0x0020 => 1, # SP
                0x0009 => 1, # \t
                0x000D => 1, # \r
                0x000A => 1, # \n
                0x000C => 1, # \f
               }->{$self->{c}}) {
        my ($l, $c) = ($self->{line}, $self->{column});
        W: {
          $self->{c} = $self->{get_char}->($self);
          if ({
                0x0020 => 1, # SP
                0x0009 => 1, # \t
                0x000D => 1, # \r
                0x000A => 1, # \n
                0x000C => 1, # \f
              }->{$self->{c}}) {
            redo W;
          } elsif (my $v = {
                            0x002B => PLUS_TOKEN, # +
                            0x003E => GREATER_TOKEN, # >
                            0x002C => COMMA_TOKEN, # ,
                            0x007E => TILDE_TOKEN, # ~
                           }->{$self->{c}}) {
            my ($l, $c) = ($self->{line}, $self->{column});
            # stay in the state
            $self->{c} = $self->{get_char}->($self);
            return {type => $v, line => $l, column => $c};
            #redo A;
          } else {
            # stay in the state
            # reprocess
            return {type => S_TOKEN, line => $l, column => $c};
            #redo A;
          }
        } # W
      } elsif (my $v = {
                        0x007C => DASHMATCH_TOKEN, # |
                        0x005E => PREFIXMATCH_TOKEN, # ^
                        0x0024 => SUFFIXMATCH_TOKEN, # $
                        0x002A => SUBSTRINGMATCH_TOKEN, # *
                       }->{$self->{c}}) {
        my ($line, $column) = ($self->{line}, $self->{column});
        my $c = $self->{c};
        $self->{c} = $self->{get_char}->($self);
        if ($self->{c} == 0x003D) { # =
          # stay in the state
          $self->{c} = $self->{get_char}->($self);
          return {type => $v, line => $line, column => $column};
          #redo A;
        } elsif ($v = {
                       0x002A => STAR_TOKEN, # *
                       0x007C => VBAR_TOKEN, # |
                      }->{$c}) {
          # stay in the state.
          # reprocess
          return {type => $v, line => $line, column => $column};
          #redo A;
        } else {
          # stay in the state
          # reprocess
          return {type => DELIM_TOKEN, value => chr $c,
                  line => $line, column => $column};
          #redo A;
        }
      } elsif ($self->{c} == 0x002B) { # +
        my ($l, $c) = ($self->{line}, $self->{column});
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        return {type => PLUS_TOKEN, line => $l, column => $c};
        #redo A;
      } elsif ($self->{c} == 0x003E) { # >
        my ($l, $c) = ($self->{line}, $self->{column});
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        return {type => GREATER_TOKEN, line => $l, column => $c};
        #redo A;
      } elsif ($self->{c} == 0x002C) { # ,
        my ($l, $c) = ($self->{line}, $self->{column});
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        return {type => COMMA_TOKEN, line => $l, column => $c};
        #redo A;
      } elsif ($self->{c} == 0x007E) { # ~
        my ($l, $c) = ($self->{line}, $self->{column});
        $self->{c} = $self->{get_char}->($self);
        if ($self->{c} == 0x003D) { # =
          # stay in the state
          $self->{c} = $self->{get_char}->($self);
          return {type => INCLUDES_TOKEN, line => $l, column => $c};
          #redo A;
        } else {
          # stay in the state
          # reprocess
          return {type => TILDE_TOKEN, line => $l, column => $c};
          #redo A;
        }
      } elsif ($self->{c} == -1) {
        # stay in the state
        $self->{c} = $self->{get_char}->($self);
        return {type => EOF_TOKEN,
                line => $self->{line}, column => $self->{column}};
        #redo A;
      } else {
        # stay in the state
        $self->{t} = {type => DELIM_TOKEN, value => chr $self->{c},
                      line => $self->{line}, column => $self->{column}};
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      }
    } elsif ($self->{state} == BEFORE_NMSTART_STATE) {
      ## NOTE: |nmstart| in |ident| in (|IDENT|, |DIMENSION|, or
      ## |FUNCTION|)
      if ((0x0041 <= $self->{c} and $self->{c} <= 0x005A) or # A..Z
          (0x0061 <= $self->{c} and $self->{c} <= 0x007A) or # a..z
          $self->{c} == 0x005F or # _
          $self->{c} > 0x007F) { # nonascii
        $self->{t}->{value} .= chr $self->{c};
        $self->{t}->{type} = DIMENSION_TOKEN
            if $self->{t}->{type} == NUMBER_TOKEN;
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE; $q = 0;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002D) { # -
        if ($self->{t}->{type} == IDENT_TOKEN) {
          #$self->normalize_surrogate ($self->{t}->{value});
          $self->{c} = $self->{get_char}->($self);
          if ($self->{c} == 0x003E) { # >
            $self->{state} = BEFORE_TOKEN_STATE;
            $self->{c} = $self->{get_char}->($self);
            return {type => CDC_TOKEN,
                    line => $self->{t}->{line},
                    column => $self->{t}->{column}};
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
            unshift @{$self->{token}}, {type => CDC_TOKEN};
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
        $self->{state} = ESCAPE_OPEN_STATE; $q = 0;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return {type => DELIM_TOKEN, value => '@',
                line => $self->{t}->{line},
                column => $self->{t}->{column}};
      }
    } elsif ($self->{state} == AFTER_AT_HYPHEN_STATE) {
      if ((0x0041 <= $self->{c} and $self->{c} <= 0x005A) or # A..Z
          (0x0061 <= $self->{c} and $self->{c} <= 0x007A) or # a..z
          $self->{c} == 0x005F or # _
          $self->{c} > 0x007F) { # nonascii
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x002D) { # -
        $self->{c} = $self->{get_char}->($self);
        if ($self->{c} == 0x003E) { # >
          unshift @{$self->{token}}, {type => CDC_TOKEN};
          $self->{state} = BEFORE_TOKEN_STATE;
          $self->{c} = $self->{get_char}->($self);
          return {type => DELIM_TOKEN, value => '@'};
          #redo A;
        } else {
          unshift @{$self->{token}}, {type => MINUS_TOKEN};
          $self->{t} = {type => IDENT_TOKEN, value => '-'};
          $self->{state} = BEFORE_NMSTART_STATE;
          # reprocess
          return {type => DELIM_TOKEN, value => '@'};
          #redo A;
        }
      } elsif ($self->{c} == 0x005C) { # \
        ## TODO: @-\{nl}
        $self->{state} = ESCAPE_OPEN_STATE; $q = 0;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        unshift @{$self->{token}}, {type => MINUS_TOKEN};
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return {type => DELIM_TOKEN, value => '@'};
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
        $self->{state} = ESCAPE_OPEN_STATE; $q = 0;
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
      ## NOTE: The first |nmchar| in |name| in |HASH|.
      if ((0x0041 <= $self->{c} and $self->{c} <= 0x005A) or # A..Z
          (0x0061 <= $self->{c} and $self->{c} <= 0x007A) or # a..z
          (0x0030 <= $self->{c} and $self->{c} <= 0x0039) or # 0..9
          $self->{c} == 0x002D or # -
          $self->{c} == 0x005F or # _
          $self->{c} > 0x007F) { # nonascii
        $self->{t}->{not_ident} = 1 if
            (0x0030 <= $self->{c} and $self->{c} <= 0x0039); # 0..9
        $self->{t}->{hyphen} = 1 if $self->{c} == 0x002D; # -
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = NAME_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE; $q = 0;
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
        $self->{state} = ESCAPE_OPEN_STATE; $q = 0;
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
        $self->{state} = STRING_STATE; $q = $self->{c};
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0029) { # )
        $self->{state} = BEFORE_TOKEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        return $self->{t};
        #redo A;
      } elsif ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE; $q = 1;
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
        $self->{state} = ESCAPE_OPEN_STATE; $q = 1;
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
        $self->{state} = ESCAPE_OPEN_STATE; $q = 1;
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
      $self->{t}->{has_escape} = 1;
      if (0x0030 <= $self->{c} and $self->{c} <= 0x0039) { # 0..9
        ## NOTE: second character of |unicode| in |escape|.
        $char = $self->{c} - 0x0030;
        $self->{state} = ESCAPE_STATE; $i = 2;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif (0x0041 <= $self->{c} and $self->{c} <= 0x0046) { # A..F
        ## NOTE: second character of |unicode| in |escape|.
        $char = $self->{c} - 0x0041 + 0xA;
        $self->{state} = ESCAPE_STATE; $i = 2;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif (0x0061 <= $self->{c} and $self->{c} <= 0x0066) { # a..f
        ## NOTE: second character of |unicode| in |escape|.
        $char = $self->{c} - 0x0061 + 0xA;
        $self->{state} = ESCAPE_STATE; $i = 2;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x000A or # \n
               $self->{c} == 0x000C) { # \f
        if ($q == 0) {
          #
        } elsif ($q == 1) {
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
          ## Note: In |nl| in ... in |string| or |ident|.
          $self->{state} = STRING_STATE;
          $self->{c} = $self->{get_char}->($self);
          redo A;
        }
      } elsif ($self->{c} == 0x000D) { # \r
        if ($q == 0) {
          #
        } elsif ($q == 1) {
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
          ## Note: In |nl| in ... in |string| or |ident|.
          $self->{state} = ESCAPE_BEFORE_LF_STATE;
          $self->{c} = $self->{get_char}->($self);
          redo A;
        }
      } elsif ($self->{c} == -1) {
        #
      } else {
        ## NOTE: second character of |escape|.
        $self->{t}->{value} .= chr $self->{c};
        $self->{state} = $q == 0 ? NAME_STATE :
            $q == 1 ? URI_UNQUOTED_STATE : STRING_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      }

      if ($q == 0) {
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

          if ($self->{t}->{hyphen} and $self->{t}->{value} eq '-') {
            unshift @{$self->{token}},
                {type => MINUS_TOKEN,
                 line => $self->{line_prev},
                 column => $self->{column_prev} - 1};
            $self->{t}->{value} = '';
          }

          if (length $self->{t}->{value}) {
            $self->normalize_surrogate ($self->{t}->{value});
            $self->{state} = BEFORE_TOKEN_STATE;
            # reprocess
            return $self->{t};
            #redo A;
          }

          if ($self->{t}->{type} == HASH_TOKEN) {
            $self->{state} = BEFORE_TOKEN_STATE;
            # reprocess
            return {type => DELIM_TOKEN, value => '#',
                    line => $self->{t}->{line},
                    column => $self->{t}->{column}};
            #redo A;
          }

          $self->{state} = BEFORE_TOKEN_STATE;
          # reprocess
          return shift @{$self->{token}};
          #redo A;
        }
      } elsif ($q == 1) {
        $self->{state} = URI_UNQUOTED_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        unshift @{$self->{token}}, {type => DELIM_TOKEN, value => '\\',
                                    line => $self->{line_prev},
                                    column => $self->{column_prev}};
        $self->{t}->{type} = {
          STRING_TOKEN, INVALID_TOKEN,
          URI_TOKEN, URI_INVALID_TOKEN,
          URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}} || $self->{t}->{type};
        $self->{state} = BEFORE_TOKEN_STATE;
        # reprocess
        return $self->{t};
        #redo A;
      }
    } elsif ($self->{state} == ESCAPE_STATE) {
      ## NOTE: third..seventh character of |unicode| in |escape|.
      if (0x0030 <= $self->{c} and $self->{c} <= 0x0039) { # 0..9
        $char = $char * 0x10 + $self->{c} - 0x0030;
        $self->{state} = ++$i == 7 ? ESCAPE_BEFORE_NL_STATE : ESCAPE_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif (0x0041 <= $self->{c} and $self->{c} <= 0x0046) { # A..F
        $char = $char * 0x10 + $self->{c} - 0x0041 + 0xA;
        $self->{state} = ++$i == 7 ? ESCAPE_BEFORE_NL_STATE : ESCAPE_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif (0x0061 <= $self->{c} and $self->{c} <= 0x0066) { # a..f
        $char = $char * 0x10 + $self->{c} - 0x0061 + 0xA;
        $self->{state} = ++$i == 7 ? ESCAPE_BEFORE_NL_STATE : ESCAPE_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x0020 or # SP
               $self->{c} == 0x000A or # \n
               $self->{c} == 0x0009 or # \t
               $self->{c} == 0x000C) { # \f
        $self->{t}->{value} .= $self->_escaped_char ($char);
        $self->{state} = $q == 0 ? NAME_STATE :
            $q == 1 ? URI_UNQUOTED_STATE : STRING_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x000D) { # \r
        $self->{t}->{value} .= $self->_escaped_char ($char);
        $self->{state} = ESCAPE_BEFORE_LF_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{value} .= $self->_escaped_char ($char);
        $self->{state} = $q == 0 ? NAME_STATE :
            $q == 1 ? URI_UNQUOTED_STATE : STRING_STATE;
        # reconsume
        redo A;
      }
    } elsif ($self->{state} == ESCAPE_BEFORE_NL_STATE) {
      ## NOTE: eightth character of |unicode| in |escape|.
      if ($self->{c} == 0x0020 or # SP
          $self->{c} == 0x000A or # \n
          $self->{c} == 0x0009 or # \t
          $self->{c} == 0x000C) { # \f
        $self->{t}->{value} .= $self->_escaped_char ($char);
        $self->{state} = $q == 0 ? NAME_STATE :
            $q == 1 ? URI_UNQUOTED_STATE : STRING_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == 0x000D) { # \r
        $self->{t}->{value} .= $self->_escaped_char ($char);
        $self->{state} = ESCAPE_BEFORE_LF_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{t}->{value} .= $self->_escaped_char ($char);
        $self->{state} = $q == 0 ? NAME_STATE :
            $q == 1 ? URI_UNQUOTED_STATE : STRING_STATE;
        # reconsume
        redo A;
      }
    } elsif ($self->{state} == ESCAPE_BEFORE_LF_STATE) {
      ## NOTE: |\n| in |\r\n| in |nl| in |escape|.
      if ($self->{c} == 0x000A) { # \n
        $self->{state} = $q == 0 ? NAME_STATE :
            $q == 1 ? URI_UNQUOTED_STATE : STRING_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } else {
        $self->{state} = $q == 0 ? NAME_STATE :
            $q == 1 ? URI_UNQUOTED_STATE : STRING_STATE;
        # reprocess
        redo A;
      }
    } elsif ($self->{state} == STRING_STATE) {
      ## NOTE: A character in |string$Q| in |string| in |STRING|, or
      ## a character in |invalid$Q| in |invalid| in |INVALID|,
      ## where |$Q = $q == 0x0022 ? 1 : 2|.
      ## Or, in |URI|.
      if ($self->{c} == 0x005C) { # \
        $self->{state} = ESCAPE_OPEN_STATE;
        $self->{c} = $self->{get_char}->($self);
        redo A;
      } elsif ($self->{c} == $q) { # " | '
        if ($self->{t}->{type} == STRING_TOKEN) {
          $self->normalize_surrogate ($self->{t}->{value});
          $self->{state} = BEFORE_TOKEN_STATE;
          $self->{c} = $self->{get_char}->($self);
          return $self->{t};
          #redo A;
        } else {
          $self->{state} = URI_AFTER_WSP_STATE;
          $self->{c} = $self->{get_char}->($self);
          redo A;
        }
      } elsif ($self->{c} == 0x000A or # \n
               $self->{c} == 0x000D or # \r
               $self->{c} == 0x000C or # \f
               $self->{c} == -1) {
        $self->{t}->{type} = {
          STRING_TOKEN, INVALID_TOKEN,
          INVALID_TOKEN, INVALID_TOKEN,
          URI_TOKEN, URI_INVALID_TOKEN,
          URI_INVALID_TOKEN, URI_INVALID_TOKEN,
          URI_PREFIX_TOKEN, URI_PREFIX_INVALID_TOKEN,
          URI_PREFIX_INVALID_TOKEN, URI_PREFIX_INVALID_TOKEN,
        }->{$self->{t}->{type}};
        $self->{t}->{eos} = 1 if $self->{c} == -1;
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
        unshift @{$self->{token}}, {type => DOT_TOKEN};
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
      } else {
        $self->{t}->{number} = $self->{t}->{value};
        $self->{t}->{value} = '';
        $self->{state} = AFTER_NUMBER_STATE;
        # reprocess
        redo A;
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
  } elsif ($t->{type} == COMMENT_TOKEN) {
    return '/**/';
  } elsif ($t->{type} == COMMENT_INVALID_TOKEN) {
    return '/*';
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
  if ($_[1] == 0x0000) {
    $_[0]->{onerror}->(type => 'css:escape:null',
                       level => $_[0]->{level}->{must},
                       uri => \$_[0]->{href},
                       line => $_[0]->{line_prev},
                       column => $_[0]->{column_prev});
    return chr $_[1];
  } elsif ($_[1] > 0x10FFFF) {
    $_[0]->{onerror}->(type => 'css:escape:not unicode',
                       level => $_[0]->{level}->{should},
                       uri => \$_[0]->{href},
                       line => $_[0]->{line_prev},
                       column => $_[0]->{column_prev});
    return "\x{FFFD}";
  } else {
    return chr $_[1];
  }
} # _escaped_char

use Encode;
sub normalize_surrogate {
  ## XXX bad impl...
  $_[1] =~ s{((?:[\x{D800}-\x{DBFF}][\x{DC00}-\x{DF00}])+)}{
    decode 'utf-16be', join '', map { pack 'CC', int ((ord $_) / 0x100), ((ord $_) % 0x100) } split //, $1;
  }ge if defined $_[1];
} # _normalize_surrogate

=head1 LICENSE

Copyright 2007-2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
