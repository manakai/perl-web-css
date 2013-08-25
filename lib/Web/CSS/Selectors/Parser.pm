package Web::CSS::Selectors::Parser;
use strict;
use warnings;
our $VERSION = '16.0';
push our @ISA, qw(Web::CSS::Selectors::Parser::_ Web::CSS::Builder);

sub new ($) {
  my $self = bless {
    #pseudo_class => {supported_class_name => 1, ...},
    #pseudo_element => {supported_class_name => 1, ...},
  }, shift;
  return $self;
} # new

package Web::CSS::Selectors::Parser::_;
use Carp;
use Web::CSS::Builder;

sub BEFORE_TYPE_SELECTOR_STATE () { 1 }
sub AFTER_NAME_STATE () { 2 }
sub BEFORE_LOCAL_NAME_STATE () { 3 }
sub BEFORE_SIMPLE_SELECTOR_STATE () { 4 }
sub BEFORE_CLASS_NAME_STATE () { 5 }
sub AFTER_COLON_STATE () { 6 }
sub AFTER_DOUBLE_COLON_STATE () { 7 }
sub AFTER_LBRACKET_STATE () { 8 }
sub AFTER_ATTR_NAME_STATE () { 9 }
sub BEFORE_ATTR_LOCAL_NAME_STATE () { 10 }
sub BEFORE_MATCH_STATE () { 11 }
sub BEFORE_VALUE_STATE () { 12 }
sub AFTER_VALUE_STATE () { 13 }
sub BEFORE_COMBINATOR_STATE () { 14 }
sub COMBINATOR_STATE () { 15 }
sub BEFORE_LANG_TAG_STATE () { 16 }
sub AFTER_LANG_TAG_STATE () { 17 }
sub BEFORE_AN_STATE () { 18 }
sub AFTER_AN_STATE () { 19 }
sub BEFORE_B_STATE () { 20 }
sub AFTER_B_STATE () { 21 }
sub AFTER_NEGATION_SIMPLE_SELECTOR_STATE () { 22 }
sub BEFORE_CONTAINS_STRING_STATE () { 23 }
sub AFTER_A_PLUS_STATE () { 24 }

sub NAMESPACE_SELECTOR () { 1 }
sub LOCAL_NAME_SELECTOR () { 2 }
sub ID_SELECTOR () { 3 }
sub CLASS_SELECTOR () { 4 }
sub PSEUDO_CLASS_SELECTOR () { 5 }
sub PSEUDO_ELEMENT_SELECTOR () { 6 }
sub ATTRIBUTE_SELECTOR () { 7 }

sub DESCENDANT_COMBINATOR () { S_TOKEN }
sub CHILD_COMBINATOR () { GREATER_TOKEN }
sub ADJACENT_SIBLING_COMBINATOR () { PLUS_TOKEN }
sub GENERAL_SIBLING_COMBINATOR () { TILDE_TOKEN }

sub EXISTS_MATCH () { 0 }
sub EQUALS_MATCH () { MATCH_TOKEN }
sub INCLUDES_MATCH () { INCLUDES_TOKEN }
sub DASH_MATCH () { DASHMATCH_TOKEN }
sub PREFIX_MATCH () { PREFIXMATCH_TOKEN }
sub SUFFIX_MATCH () { SUFFIXMATCH_TOKEN }
sub SUBSTRING_MATCH () { SUBSTRINGMATCH_TOKEN }

our @EXPORT = qw(NAMESPACE_SELECTOR LOCAL_NAME_SELECTOR ID_SELECTOR
    CLASS_SELECTOR PSEUDO_CLASS_SELECTOR PSEUDO_ELEMENT_SELECTOR
    ATTRIBUTE_SELECTOR
    DESCENDANT_COMBINATOR CHILD_COMBINATOR
    ADJACENT_SIBLING_COMBINATOR GENERAL_SIBLING_COMBINATOR
    EXISTS_MATCH EQUALS_MATCH INCLUDES_MATCH DASH_MATCH PREFIX_MATCH
    SUFFIX_MATCH SUBSTRING_MATCH);

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

my $IdentOnlyPseudoClasses = {
  active => 1,
  checked => 1,
  '-manakai-current' => 1,
  disabled => 1,
  empty => 1,
  enabled => 1,
  'first-child' => 1,
  'first-of-type' => 1,
  focus => 1,
  future => 1,
  hover => 1,
  indeterminate => 1,
  'last-child' => 1,
  'last-of-type' => 1,
  link => 1,
  'only-child' => 1,
  'only-of-type' => 1,
  past => 1,
  root => 1,
  target => 1,
  visited => 1,
}; # $IdentOnlyPseudoClasses

my $IdentOnlyPseudoElements = {
  'first-letter' => 1,
  'first-line' => 1,
  after => 1,
  before => 1,
  cue => 1,
}; # $IdentOnlyPseudoElements

sub parse_char_string_as_selectors ($$) {
  my ($self, $selectors) = @_;
  $self->onerror; # setting $self->{onerror}

  $self->{line_prev} = $self->{line} = 1;
  $self->{column_prev} = -1;
  $self->{column} = 0;

  $self->{chars} = [split //, $selectors];
  $self->{chars_pos} = 0;
  delete $self->{chars_was_cr};
  $self->{chars_pull_next} = sub { 0 };

  $self->init_tokenizer;
  $self->init_builder;

  $self->start_building_values or do {
    1 while not $self->continue_building_values;
  };

  my $tt = (delete $self->{parsed_construct})->{value};
  push @$tt, $self->get_next_token; # EOF_TOKEN

  return $self->parse_constructs_as_selectors ($tt);
} # parse_char_string_as_selectors

sub parse_constructs_as_selectors ($$) {
  my ($self, $tt) = @_;
  $self->onerror; # setting $self->{onerror}

  my $default_ns = $self->context->get_url_by_prefix ('');

  my $process_tokens;
  $process_tokens = sub ($;%) {
    my ($tokens, %args) = @_;

    my $t = shift @$tokens;
    my $selector_group = [];
    my $selector = [DESCENDANT_COMBINATOR];
    my $sss = [];

    A: {
      $t = shift @$tokens while $t->{type} == S_TOKEN;

      my $found_tu = 0;
      if ($t->{type} == IDENT_TOKEN or $t->{type} == STAR_TOKEN) {
        my $t1 = $t;
        $t = shift @$tokens;
        if ($t->{type} == VBAR_TOKEN) {
          $t = shift @$tokens;
          if ($t->{type} == IDENT_TOKEN or $t->{type} == STAR_TOKEN) {
            if ($t1->{type} == IDENT_TOKEN) {
              my $url = $self->context->get_url_by_prefix ($t1->{value});
              unless (defined $url) {
                $self->{onerror}->(type => 'namespace prefix:not declared',
                                   level => 'm',
                                   uri => $self->context->urlref,
                                   token => $t1,
                                   value => $t1->{value});
                next A;
              }
              push @$sss, [NAMESPACE_SELECTOR, length $url ? $url : undef];
            }
            if ($t->{type} == IDENT_TOKEN) {
              push @$sss, [LOCAL_NAME_SELECTOR, $t->{value}];
            }
            $found_tu = 1;
            $t = shift @$tokens;
          } else {
            $self->{onerror}->(type => 'no local name selector',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
            next A;
          }
        } else {
          if (defined $default_ns) {
            push @$sss,
                [NAMESPACE_SELECTOR, length $default_ns ? $default_ns : undef];
          }
          if ($t1->{type} == IDENT_TOKEN) {
            push @$sss, [LOCAL_NAME_SELECTOR, $t1->{value}];
          }
          $found_tu = 1;
        }
      } elsif ($t->{type} == VBAR_TOKEN) {
        $t = shift @$tokens;
        if ($t->{type} == IDENT_TOKEN) {
          push @$sss, [NAMESPACE_SELECTOR, undef];
          push @$sss, [LOCAL_NAME_SELECTOR, $t->{value}];
          $t = shift @$tokens;
          $found_tu = 1;
        } elsif ($t->{type} == STAR_TOKEN) {
          push @$sss, [NAMESPACE_SELECTOR, undef];
          $t = shift @$tokens;
          $found_tu = 1;
        } else {
          $self->{onerror}->(type => 'no local name selector',
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
          next A;
        }
      }

      my $has_pseudo_element;
      B: {
        if ($t->{type} == BRACKET_CONSTRUCT) { ## Attribute selector
          if ($has_pseudo_element) {
            $self->{onerror}->(type => 'ss after pseudo-element',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
            next A;
          }

          my $us = $t->{value};
          push @$us, {type => EOF_TOKEN,
                      line => $t->{end_line},
                      column => $t->{end_column}};
          my $u = shift @$us;
          $u = shift @$us while $u->{type} == S_TOKEN;

          my $t1;
          my $nsurl = '';
          if ($u->{type} == IDENT_TOKEN) { # [hoge] or [hoge|fuga]
            $t1 = $u;
            $u = shift @$us;
            if ($u->{type} == VBAR_TOKEN) {
              $u = shift @$us;
              if ($u->{type} == IDENT_TOKEN) {
                my $p_t = $t1;
                $t1 = $u;
                $nsurl = $self->context->get_url_by_prefix ($p_t->{value});
                unless (defined $nsurl) {
                  $self->{onerror}->(type => 'namespace prefix:not declared',
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $p_t,
                                     value => $p_t->{value});
                  next A;
                }
                $u = shift @$us;
              } else {
                $self->{onerror}->(type => 'no attr local name',
                                   level => 'm',
                                   uri => $self->context->urlref,
                                   token => $u);
                next A;
              }
            }
          } elsif ($u->{type} == STAR_TOKEN) { # [*|hoge]
            $u = shift @$us;
            if ($u->{type} == VBAR_TOKEN) {
              $u = shift @$us;
              if ($u->{type} == IDENT_TOKEN) {
                $t1 = $u;
                $nsurl = undef; # any namespace
                $u = shift @$us;
              } else {
                $self->{onerror}->(type => 'no attr local name',
                                   level => 'm',
                                   uri => $self->context->urlref,
                                   token => $u);
                next A;
              }
            } else {
              $self->{onerror}->(type => 'no attr namespace separator',
                                 level => 'm',
                                 uri => $self->context->urlref,
                                 token => $u);
              next A;
            }
          } elsif ($u->{type} == VBAR_TOKEN) { # [|hoge]
            $u = shift @$us;
            if ($u->{type} == IDENT_TOKEN) {
              $t1 = $u;
              $u = shift @$us;
            } else {
              $self->{onerror}->(type => 'no attr local name',
                                 level => 'm',
                                 uri => $self->context->urlref,
                                 token => $u);
              next A;
            }
          } else {
            $self->{onerror}->(type => 'no attr name',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $u);
            next A;
          }
          
          $u = shift @$us while $u->{type} == S_TOKEN;
          if ({
            MATCH_TOKEN, 1,
            INCLUDES_TOKEN, 1,
            DASHMATCH_TOKEN, 1,
            PREFIXMATCH_TOKEN, 1,
            SUFFIXMATCH_TOKEN, 1,
            SUBSTRINGMATCH_TOKEN, 1,
          }->{$u->{type}}) {
            my $match = $u->{type};
            $u = shift @$us;
            $u = shift @$us while $u->{type} == S_TOKEN;
            if ($u->{type} == IDENT_TOKEN or
                $u->{type} == STRING_TOKEN) { # [name(match)value]
              push @$sss, [ATTRIBUTE_SELECTOR,
                           $nsurl, $t1->{value},
                           $match, $u->{value}];
              $u = shift @$us;
              $u = shift @$us while $u->{type} == S_TOKEN;
              if ($u->{type} != EOF_TOKEN) {
                $self->{onerror}->(type => 'selectors:attr:broken', # XXX
                                   level => 'm',
                                   uri => $self->context->urlref,
                                   token => $u);
                next A;
              }
              $t = shift @$tokens;
              redo B;
            } else {
              $self->{onerror}->(type => 'no attr value',
                                 level => 'm',
                                 uri => $self->context->urlref,
                                 token => $u);
              next A;
            }
          } elsif ($u->{type} == EOF_TOKEN) { # [name]
            push @$sss, [ATTRIBUTE_SELECTOR, $nsurl, $t1->{value}];
            $t = shift @$tokens;
            redo B;
          } else {
            $self->{onerror}->(type => 'no attr match',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $u);
            next A;
          }
        } elsif ($t->{type} == DOT_TOKEN) { ## Class selector
          if ($has_pseudo_element) {
            $self->{onerror}->(type => 'ss after pseudo-element',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
            next A;
          }
          $t = shift @$tokens;
          if ($t->{type} == IDENT_TOKEN) {
            push @$sss, [CLASS_SELECTOR, $t->{value}];
            $t = shift @$tokens;
          } else {
            $self->{onerror}->(type => 'no class name',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
            next A;
          }
        } elsif ($t->{type} == HASH_TOKEN) { ## ID selector
          if ($has_pseudo_element) {
            $self->{onerror}->(type => 'ss after pseudo-element',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
            next A;
          }
          if ($t->{not_ident}) {
            $self->{onerror}->(type => 'selectors:id:not ident',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
            next A;
          }
          push @$sss, [ID_SELECTOR, $t->{value}];
          $t = shift @$tokens;
        } elsif ($t->{type} == COLON_TOKEN) { ## Pseudo-class or pseudo-element
          if ($has_pseudo_element) {
            $self->{onerror}->(type => 'ss after pseudo-element',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
            next A;
          }
          $t = shift @$tokens;
          if ($t->{type} == COLON_TOKEN) { ## Pseudo-element (::)
            $t = shift @$tokens;
            if ($t->{type} == IDENT_TOKEN) {
              my $pe = $t->{value};
              $pe =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
              if ($self->media_resolver->{pseudo_element}->{$pe} and
                  $IdentOnlyPseudoElements->{$pe} and
                  not $args{in_not}) {
                push @$sss, [PSEUDO_ELEMENT_SELECTOR, $pe];
                $has_pseudo_element = 1;
                $t = shift @$tokens;
                redo B;
              } else {
                if ($args{in_not}) {
                  $self->{onerror}->(type => 'selectors:pseudo-element:in not', # XXX
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $t, value => $pe);
                } elsif ($IdentOnlyPseudoElements->{$pe}) {
                  $self->{onerror}->(type => 'selectors:pseudo-element:ident:not supported',
                                     level => 'w',
                                     uri => $self->context->urlref,
                                     token => $t, value => $pe);
                } else {
                  $self->{onerror}->(type => 'selectors:pseudo-element:ident:unknown',
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $t, value => $pe);
                }
                next A;
              }
            } elsif ($t->{type} == FUNCTION_CONSTRUCT) {
              my $pe = $t->{name}->{value};
              $pe =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
              if ($self->media_resolver->{pseudo_element}->{$pe} and
                  $pe eq 'cue' and
                  not $args{in_not}) { ## ::element(<selectors>)
                my $us = $t->{value};
                push @$us, {type => EOF_TOKEN,
                            line => $t->{end_line},
                            column => $t->{end_column}};
                my $result = $process_tokens->($us);
                if (defined $result) {
                  push @$sss, [PSEUDO_ELEMENT_SELECTOR, $pe, $result];
                  $t = shift @$tokens;
                  $has_pseudo_element = 1;
                  redo B;
                } else {
                  next A;
                }
              } else {
                if ($args{in_not}) {
                  $self->{onerror}->(type => 'selectors:pseudo-element:in not', # XXX
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $t, value => $pe);
                } elsif ($pe eq 'cue') {
                  $self->{onerror}->(type => 'selectors:pseudo-element:function:not supported',
                                     level => 'w',
                                     uri => $self->context->urlref,
                                     token => $t, value => $pe);
                } else {
                  $self->{onerror}->(type => 'selectors:pseudo-element:function:unknown',
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $t, value => $pe);
                }
                next A;
              }
            } else {
              $self->{onerror}->(type => 'no pseudo-element name',
                                 level => 'm',
                                 uri => $self->context->urlref,
                                 token => $t);
              next A;
            }
          } elsif ($t->{type} == IDENT_TOKEN) { ## Pseudo-class (no argument)
            my $class = $t->{value};
            $class =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($IdentOnlyPseudoClasses->{$class}) {
              if ($self->media_resolver->{pseudo_class}->{$class}) {
                push @$sss, [PSEUDO_CLASS_SELECTOR, $class];
              } else {
                $self->{onerror}->(type => 'selectors:pseudo-class:ident:not supported',
                                   level => 'w',
                                   uri => $self->context->urlref,
                                   token => $t, value => $class);
                next A;
              }
            } elsif ({'first-letter' => 1, 'first-line' => 1,
                      before => 1, after => 1}->{$class}) {
              if ($args{in_not}) {
                  $self->{onerror}->(type => 'selectors:pseudo-element:in not', # XXX
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $t, value => $class);
                  next A;
              } elsif ($self->media_resolver->{pseudo_element}->{$class}) {
                $self->{onerror}->(type => 'selectors:pseudo-element:one colon',
                                   level => 'w',
                                   uri => $self->context->urlref,
                                   token => $t, value => $class);
                push @$sss, [PSEUDO_ELEMENT_SELECTOR, $class];
                $has_pseudo_element = 1;
              } else {
                $self->{onerror}->(type => 'selectors:pseudo-element:ident:not supported',
                                   level => 'w',
                                   uri => $self->context->urlref,
                                   token => $t, value => $class);
                next A;
              }
            } else {
              $self->{onerror}->(type => 'selectors:pseudo-class:ident:unknown',
                                 level => 'm',
                                 uri => $self->context->urlref,
                                 token => $t, value => $class);
              next A;
            }
            
            $t = shift @$tokens;
          } elsif ($t->{type} == FUNCTION_CONSTRUCT) { ## Pseudo-class w/args
            my $class = $t->{name}->{value};
            $class =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            
            my $known;
            if ($class eq 'lang') { ## :class(<ident>)
              if ($self->media_resolver->{pseudo_class}->{$class}) {
                my $us = $t->{value};
                push @$us, {type => EOF_TOKEN,
                            line => $t->{end_line},
                            column => $t->{end_column}};
                my $u = shift @$us;
                $u = shift @$us while $u->{type} == S_TOKEN;
                if ($u->{type} == IDENT_TOKEN) {
                  push @$sss, [PSEUDO_CLASS_SELECTOR, $class, $u->{value}];
                  $u = shift @$us;
                  $u = shift @$us while $u->{type} == S_TOKEN;
                  unless ($u->{type} == EOF_TOKEN) {
                    $self->{onerror}->(type => 'selectors:pseudo:argument broken', # XXX
                                       level => 'm',
                                       uri => $self->context->urlref,
                                       token => $u);
                    next A;
                  }
                  $t = shift @$tokens;
                  redo B;
                } else {
                  $self->{onerror}->(type => 'no lang tag',
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $u);
                  next A;
                }
              } else {
                $known = 1;
              }
            } elsif ($class eq 'not' and not $args{in_not}) { ## :class(<selectors>)
              if ($self->media_resolver->{pseudo_class}->{$class}) {
                my $us = $t->{value};
                push @$us, {type => EOF_TOKEN,
                            line => $t->{end_line},
                            column => $t->{end_column}};
                my $result = $process_tokens->($us, in_not => 1);
                if (defined $result) {
                  push @$sss, [PSEUDO_CLASS_SELECTOR, $class, $result];
                  $t = shift @$tokens;
                  $known = 1;
                  redo B;
                } else {
                  next A;
                }
              } else {
                $known = 1;
              }
            } elsif ({
              'nth-child' => 1,
              'nth-last-child' => 1,
              'nth-of-type' => 1,
              'nth-last-of-type' => 1,
            }->{$class}) { ## :class(<an+b>)
              if ($self->media_resolver->{pseudo_class}->{$class}) {
                ## an+n <http://dev.w3.org/csswg/css-syntax/#anb>.
                my $us = $t->{value};
                my $in_error;
                push @$us, {type => EOF_TOKEN,
                            line => $t->{end_line},
                            column => $t->{end_column}};
                my $u = shift @$us;
                $u = shift @$us while $u->{type} == S_TOKEN;
                if ($u->{type} == IDENT_TOKEN) {
                  if ($u->{value} =~ /\A[Ee][Vv][Ee][Nn]\z/) { # even = 2n
                    push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 2, 0];
                    $u = shift @$us;
                  } elsif ($u->{value} =~ /\A[Oo][Dd][Dd]\z/) { # odd = 2n+1
                    push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 2, 1];
                    $u = shift @$us;
                  } elsif ($u->{value} =~ /\A(-?)[Nn]\z/) {
                    my $a = 0+($1.'1');
                    $u = shift @$us;
                    if ($u->{type} == NUMBER_TOKEN and
                        $u->{number} =~ /\A[+-][0-9]+\z/) { # n <signed-integer> = 1n+b | -n <signed-integer> = -1n+b
                      push @$sss, [PSEUDO_CLASS_SELECTOR, $class, $a, 0+$u->{number}];
                      $u = shift @$us;
                    } elsif ($u->{type} == PLUS_TOKEN or
                             $u->{type} == MINUS_TOKEN) {
                      my $bs = $u->{type} == PLUS_TOKEN ? +1 : -1;
                      $u = shift @$us;
                      $u = shift @$us while $u->{type} == S_TOKEN;
                      if ($u->{type} == NUMBER_TOKEN and
                          $u->{number} =~ /\A[0-9]+\z/) { # n ['+' | '-'] <signless-integer> = 1n+b | -n ['+' | '-'] <signless-integer>
                        push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 1, $bs*$u->{number}];
                        $u = shift @$us;
                      } else {
                        $in_error = 1;
                      }
                    } else { # n = 1n | -n = -1n
                      push @$sss, [PSEUDO_CLASS_SELECTOR, $class, $a, 0];
                    }
                  } elsif ($u->{value} =~ /\A(-?)[Nn](-[0-9]+)\z/) { # <ndashdigit-ident> = 1n-b | <dashndashdigit-ident> = -1n-b
                    push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 0+($1.'1'), 0+$2];
                    $u = shift @$us;
                  } else {
                    $in_error = 1;
                  }
                } elsif ($u->{type} == NUMBER_TOKEN and
                         $u->{number} =~ /\A[+-]?[0-9]+\z/) { # <integer> = b
                  push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 0, 0+$u->{number}];
                  $u = shift @$us;
                } elsif ($u->{type} == DIMENSION_TOKEN) {
                  if ($u->{number} =~ /\A[+-]?[0-9]+\z/ and
                      $u->{value} =~ /\A[Nn]\z/) {
                    my $a = 0+$u->{number};
                    $u = shift @$us;
                    $u = shift @$us while $u->{type} == S_TOKEN;
                    if ($u->{type} == NUMBER_TOKEN and
                        $u->{number} =~ /\A[+-][0-9]+\z/) { # <n-dimension> <signed-integer> = an+b
                      push @$sss, [PSEUDO_CLASS_SELECTOR, $class, $a, 0+$u->{number}];
                      $u = shift @$us;
                    } elsif ($u->{type} == PLUS_TOKEN or
                             $u->{type} == MINUS_TOKEN) {
                      my $bs = $u->{type} == PLUS_TOKEN ? +1 : -1;
                      $u = shift @$us;
                      $u = shift @$us while $u->{type} == S_TOKEN;
                      if ($u->{type} == NUMBER_TOKEN and
                          $u->{number} =~ /\A[0-9]+\z/) { # <n-dimension> ['+' | '-'] <signless-integer> = an+b
                        push @$sss, [PSEUDO_CLASS_SELECTOR, $class, $a, $bs*$u->{number}];
                        $u = shift @$us;
                      } else {
                        $in_error = 1;
                      }
                    } else { # <n-dimension> = an
                      push @$sss, [PSEUDO_CLASS_SELECTOR, $class, $a, 0];
                    }
                  } elsif ($u->{number} =~ /\A[+-]?[0-9]+\z/ and
                           $u->{value} =~ /\A[Nn](-[0-9]+)\z/) { # <ndashdigit-dimension> = an-b
                    push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 0+$u->{number}, 0+$1];
                    $u = shift @$us;
                  } else {
                    $in_error = 1;
                  }
                } elsif ($u->{type} == PLUS_TOKEN) {
                  $u = shift @$us;
                  if ($u->{type} == IDENT_TOKEN) {
                    if ($u->{value} =~ /\A[Nn]\z/) {
                      $u = shift @$us;
                      $u = shift @$us while $u->{type} == S_TOKEN;
                      if ($u->{type} == NUMBER_TOKEN and
                          $u->{number} =~ /\A[+-][0-9]+\z/) { # '+' n <signed-integer> = 1n+b
                        push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 1, 0+$u->{number}];
                        $u = shift @$us;
                      } elsif ($u->{type} == PLUS_TOKEN or
                               $u->{type} == MINUS_TOKEN) {
                        my $bs = $u->{type} == PLUS_TOKEN ? +1 : -1;
                        $u = shift @$us;
                        $u = shift @$us while $u->{type} == S_TOKEN;
                        if ($u->{type} == NUMBER_TOKEN and
                            $u->{number} =~ /\A[0-9]+\z/) { # '+' n ['+' | '-'] <signless-integer> = 1n+b
                          push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 1, $bs*$u->{number}];
                          $u = shift @$us;
                        } else {
                          $in_error = 1;
                        }
                      } else { # '+' n = 1n
                        push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 1, 0];
                      }
                    } elsif ($u->{value} =~ /\A[Nn](-[0-9]+)\z/) { # '+' <ndashdigit-ident> = 1n-b
                      push @$sss, [PSEUDO_CLASS_SELECTOR, $class, 1, 0+$1];
                      $u = shift @$us;
                    } else {
                      $in_error = 1;
                    }
                  } else {
                    $in_error = 1;
                  }
                } else {
                  $in_error = 1;
                }
                if ($in_error) {
                  $self->{onerror}->(type => 'an+b syntax error',
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $u);
                  next A;
                }
                $u = shift @$us while $u->{type} == S_TOKEN;
                unless ($u->{type} == EOF_TOKEN) {
                  $self->{onerror}->(type => 'selectors:pseudo:argument broken', # XXX
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $u);
                  next A;
                }
                $t = shift @$tokens;
                redo B;
              } else {
                $known = 1;
              }
            } elsif ($class eq '-manakai-contains') { ## :class(<ident>|<string>)
              if ($self->media_resolver->{pseudo_class}->{$class}) {
                my $us = $t->{value};
                push @$us, {type => EOF_TOKEN,
                            line => $t->{end_line},
                            column => $t->{end_column}};
                my $u = shift @$us;
                $u = shift @$us while $u->{type} == S_TOKEN;
                if ($u->{type} == IDENT_TOKEN or
                    $u->{type} == STRING_TOKEN) {
                  push @$sss, [PSEUDO_CLASS_SELECTOR, $class, $u->{value}];
                  $u = shift @$us;
                  $u = shift @$us while $u->{type} == S_TOKEN;
                  unless ($u->{type} == EOF_TOKEN) {
                    $self->{onerror}->(type => 'selectors:pseudo:argument broken', # XXX
                                       level => 'm',
                                       uri => $self->context->urlref,
                                       token => $u);
                    next A;
                  }
                  $t = shift @$tokens;
                  redo B;
                } else {
                  $self->{onerror}->(type => 'no contains string',
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $u);
                  next A;
                }
              } else {
                $known = 1;
              }
            }

            if ($known) {
              $self->{onerror}->(type => 'selectors:pseudo-class:function:not supported',
                                 level => 'w',
                                 uri => $self->context->urlref,
                                 token => $t, value => $class);
            } else {
              $self->{onerror}->(type => 'selectors:pseudo-class:function:unknown',
                                 level => 'm',
                                 uri => $self->context->urlref,
                                 token => $t, value => $class);
            }
            next A;
          } else {
            $self->{onerror}->(type => 'no combinatorXXX',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
            next A;
          }
        } else {
          last B;
        }
        redo B;
      } # B

      ## Default namespace for implicit '*' selector
      if (defined $default_ns and
          @$sss and
          not $found_tu and
          not $args{in_not}) {
        unshift @$sss,
            [NAMESPACE_SELECTOR, length $default_ns ? $default_ns : undef];
      }

      unless ($found_tu or @$sss) {
        $self->{onerror}->(type => 'no sss',
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
        next A;
      }

      my $has_s;
      if ($t->{type} == S_TOKEN) {
        $t = shift @$tokens while $t->{type} == S_TOKEN;
        $has_s = 1;
      }

      if ($t->{type} == COMMA_TOKEN) {
        push @$selector, $sss;
        push @$selector_group, $selector;
        $selector = [DESCENDANT_COMBINATOR];
        $sss = [];
        $t = shift @$tokens;
        redo A;
      } elsif ({GREATER_TOKEN, 1,
                PLUS_TOKEN, 1,
                TILDE_TOKEN, 1}->{$t->{type}}) {
        if ($has_pseudo_element) {
          $self->{onerror}->(type => 'combinator after pseudo-element',
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
          next A;
        }
        push @$selector,
            $sss,
            {GREATER_TOKEN, CHILD_COMBINATOR,
             PLUS_TOKEN, ADJACENT_SIBLING_COMBINATOR,
             TILDE_TOKEN, GENERAL_SIBLING_COMBINATOR}->{$t->{type}};
        $sss = [];
        $t = shift @$tokens;
        redo A;
      } elsif ($t->{type} == EOF_TOKEN) {
        push @$selector, $sss;
        push @$selector_group, $selector;
        last A;
      } elsif ($has_s) {
        if ($has_pseudo_element) {
          $self->{onerror}->(type => 'ss after pseudo-element',
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
          next A;
        }
        push @$selector, $sss, DESCENDANT_COMBINATOR;
        $sss = [];
        redo A;
      } else {
        $self->{onerror}->(type => 'no combinator',
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
        next A;
      }
    } continue { # error
      return undef;
    } # A

    if ($t->{type} == EOF_TOKEN) {
      return $selector_group;
    } else {
      return undef;
    }
  }; # $process_tokens
  return $process_tokens->($tt);
} # parse_constructs_as_selectors

# XXX move to some other module?
sub get_selector_specificity ($$) {
  my ($self, $selector) = @_;
  ## $selector is a selector (not a group of selectors)

  my $r = [0, 0, 0, 0]; # s, a, b, c

  ## s  = 1 iff style="" attribute
  ## a += 1 for ID attribute selectors
  ## b += 1 for attribute, class, and pseudo-class selectors
  ## c += 1 for type selectors and pseudo-elements

  for my $sss (@$selector) {
    next unless ref $sss; # combinator
    my @sss = @$sss;
    while (@sss) {
      my $ss = shift @sss;
      if ($ss->[0] == LOCAL_NAME_SELECTOR) {
        $r->[3]++;
      } elsif ($ss->[0] == PSEUDO_ELEMENT_SELECTOR) {
        $r->[3]++;
        if ($ss->[1] eq 'cue' and defined $ss->[2]) {
          my @rr;
          for my $rr (map { $self->get_selector_specificity ($_) } @{$ss->[2]}) {
            $r->[$_] += $rr->[$_] for 0..3;
          }
        }
      } elsif ($ss->[0] == ATTRIBUTE_SELECTOR or
               $ss->[0] == CLASS_SELECTOR) {
        $r->[2]++;
      } elsif ($ss->[0] == PSEUDO_CLASS_SELECTOR) {
        if ($ss->[1] eq 'not') {
          my @rr;
          push @rr, $self->get_selector_specificity ($_) for @{$ss->[2]};
          @rr = sort { $b->[0] <=> $a->[0] or
                       $b->[1] <=> $a->[1] or
                       $b->[2] <=> $a->[2] or
                       $b->[3] <=> $a->[3] } @rr;
          $r->[$_] += $rr[0]->[$_] for 0..3;
        } else {
          $r->[2]++;
        }
      } elsif ($ss->[0] == ID_SELECTOR) {
        $r->[1]++;
      }
    }
  }

  return $r;
} # get_selector_specificity

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
