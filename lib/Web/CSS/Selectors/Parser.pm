package Whatpm::CSS::SelectorsParser;
use strict;
use warnings;
our $VERSION = '1.13';

require Exporter;
push our @ISA, 'Exporter';

use Whatpm::CSS::Tokenizer qw(:token);

sub new ($) {
  my $self = bless {
    onerror => sub { },

    ## See |Whatpm::CSS::Parser| for usage.
    lookup_namespace_uri => sub {
      return undef;
    },

    level => {
      must => 'm',
      should => 's',
      warning => 'w',
      uncertain => 'u',
    },

    #href => \(URL in which the selectors appear),
    #pseudo_class => {supported_class_name => 1, ...},
    #pseudo_element => {supported_class_name => 1, ...},
  }, shift;
  return $self;
} # new

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

our @EXPORT_OK = qw(NAMESPACE_SELECTOR LOCAL_NAME_SELECTOR ID_SELECTOR
    CLASS_SELECTOR PSEUDO_CLASS_SELECTOR PSEUDO_ELEMENT_SELECTOR
    ATTRIBUTE_SELECTOR
    DESCENDANT_COMBINATOR CHILD_COMBINATOR
    ADJACENT_SIBLING_COMBINATOR GENERAL_SIBLING_COMBINATOR
    EXISTS_MATCH EQUALS_MATCH INCLUDES_MATCH DASH_MATCH PREFIX_MATCH
    SUFFIX_MATCH SUBSTRING_MATCH);

our %EXPORT_TAGS = (
  selector => [qw(NAMESPACE_SELECTOR LOCAL_NAME_SELECTOR ID_SELECTOR
      CLASS_SELECTOR PSEUDO_CLASS_SELECTOR PSEUDO_ELEMENT_SELECTOR
      ATTRIBUTE_SELECTOR)],
  combinator => [qw(DESCENDANT_COMBINATOR CHILD_COMBINATOR
      ADJACENT_SIBLING_COMBINATOR GENERAL_SIBLING_COMBINATOR)],
  match => [qw(EXISTS_MATCH EQUALS_MATCH INCLUDES_MATCH DASH_MATCH
      PREFIX_MATCH SUFFIX_MATCH SUBSTRING_MATCH)],
);

sub parse_string ($$) {
  my $self = $_[0];
  
  my $s = $_[1];
  pos ($s) = 0;
  my $line = 1;
  my $column = 0;

  my $tt = Whatpm::CSS::Tokenizer->new;
  $tt->{onerror} = $self->{onerror};
  $tt->{href} = $self->{href};
  $tt->{level} = $self->{level};
  $tt->{get_char} = sub ($) {
    if (pos $s < length $s) {
      my $c = ord substr $s, pos ($s)++, 1;
      if ($c == 0x000A) {
        $line++;
        $column = 0;
      } elsif ($c == 0x000D) {
        unless (substr ($s, pos ($s), 1) eq "\x0A") {
          $line++;
          $column = 0;
        } else {
          $column++;
        }
      } else {
        $column++;
      }
      $_[0]->{line_prev} = $_[0]->{line};
      $_[0]->{column_prev} = $_[0]->{column};
      $_[0]->{line} = $line;
      $_[0]->{column} = $column;
      return $c;
    } else {
      $_[0]->{line_prev} = $_[0]->{line};
      $_[0]->{column_prev} = $_[0]->{column};
      $_[0]->{line} = $line;
      $_[0]->{column} = $column + 1; ## Set the same number always.
      return -1;
    }
  }; # $tt->{get_char}
  $tt->{line} = $line;
  $tt->{column} = $column;
  $tt->init;

  my ($next_token, $selectors)
      = $self->_parse_selectors_with_tokenizer ($tt, EOF_TOKEN);
  return $selectors; # or undef
} # parse_string

our $IdentOnlyPseudoClasses = {
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

our $IdentOnlyPseudoElements = {
  'first-letter' => 1,
  'first-line' => 1,
  after => 1,
  before => 1,
  cue => 1,
}; # $IdentOnlyPseudoElements

sub _parse_selectors_with_tokenizer ($$$;$) {
  my $self = $_[0];
  my $tt = $_[1];
  # $_[2] : End token (other than EOF_TOKEN - may be EOF_TOKEN if no other).
  # $_[3] : The first token, or undef

  my $default_namespace = $self->{lookup_namespace_uri}->('');

  my $selectors = [];
  my $selector = [DESCENDANT_COMBINATOR];
  my $sss = [];
  my $simple_selector;
  my $has_pseudo_element;
  my $in_negation;

  my $state = BEFORE_TYPE_SELECTOR_STATE;
  my $t = $_[3] || $tt->get_next_token;
  my $name;
  my $name_t;
  S: {
    if ($state == BEFORE_TYPE_SELECTOR_STATE) {
      $in_negation = 2 if $in_negation;

      if ($t->{type} == IDENT_TOKEN) { ## element type or namespace prefix
        $name = $t->{value};
        $name_t = $t;
        $state = AFTER_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == STAR_TOKEN) { ## universal selector or prefix
        undef $name;
        $state = AFTER_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == VBAR_TOKEN) { ## null namespace
        undef $name;
        push @$sss, [NAMESPACE_SELECTOR, undef];

        $state = BEFORE_LOCAL_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } elsif ({
                DOT_TOKEN, 1,
                COLON_TOKEN, 1,
                HASH_TOKEN, 1,
                LBRACKET_TOKEN, 1,
                RPAREN_TOKEN, $in_negation, # :not(a ->> ) <<-
               }->{$t->{type}}) {
        $in_negation = 1 if $in_negation;
        if (defined $default_namespace and not $in_negation) {
          if (length $default_namespace) {
            push @$sss, [NAMESPACE_SELECTOR, $default_namespace];
          } else {
            push @$sss, [NAMESPACE_SELECTOR, undef];
          }
        }

        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        # Reprocess.
        redo S;
      } else {
        if ($t->{type} == DELIM_TOKEN and
            $t->{value} eq '#') {
          $self->{onerror}->(type => 'selectors:id:empty',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
        } else {
          $self->{onerror}->(type => 'no sss',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
        }
        return ($t, undef);
      }
    } elsif ($state == BEFORE_SIMPLE_SELECTOR_STATE) {
      if ($in_negation and $in_negation++ == 2) {
        $state = AFTER_NEGATION_SIMPLE_SELECTOR_STATE;
        ## Reprocess.
        redo S;
      }

      if ($t->{type} == DOT_TOKEN) { ## class selector
        if ($has_pseudo_element) {
          $self->{onerror}->(type => 'ss after pseudo-element',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
        $state = BEFORE_CLASS_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == HASH_TOKEN) { ## ID selector
        if ($has_pseudo_element) {
          $self->{onerror}->(type => 'ss after pseudo-element',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
        if ($t->{not_ident}) {
          $self->{onerror}->(type => 'selectors:id:not ident',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
        push @$sss, [ID_SELECTOR, $t->{value}];
        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == COLON_TOKEN) { ## pseudo-class or pseudo-element
        if ($has_pseudo_element) {
          $self->{onerror}->(type => 'ss after pseudo-element',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
        $state = AFTER_COLON_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == LBRACKET_TOKEN) { ## attribute selector
        if ($has_pseudo_element) {
          $self->{onerror}->(type => 'ss after pseudo-element',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
        $state = AFTER_LBRACKET_STATE;
        $t = $tt->get_next_token;
        redo S;
      } else {
        $state = BEFORE_COMBINATOR_STATE;
        ## Reprocess.
        redo S;
      }
    } elsif ($state == AFTER_NAME_STATE) {
      if ($t->{type} == VBAR_TOKEN) {
        $state = BEFORE_LOCAL_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } else { ## Type or universal selector w/o namespace prefix
        if (defined $default_namespace) {
          if (length $default_namespace) {
            push @$sss, [NAMESPACE_SELECTOR, $default_namespace];
          } else {
            push @$sss, [NAMESPACE_SELECTOR, undef];
          }
        }
        push @$sss, [LOCAL_NAME_SELECTOR, $name] if defined $name;

        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        ## reprocess.
        redo S;
      }
    } elsif ($state == BEFORE_LOCAL_NAME_STATE) {
      if ($t->{type} == IDENT_TOKEN) {
        if (defined $name) { ## Prefix is neither empty nor "*"
          my $uri = $self->{lookup_namespace_uri}->($name);
          unless (defined $uri) {
            $self->{onerror}->(type => 'namespace prefix:not declared',
                               level => $self->{level}->{must},
                               uri => \$self->{href},
                               token => $name_t || $t,
                               value => $name);
            return ($t, undef);
          }
          undef $uri unless length $uri;
          push @$sss, [NAMESPACE_SELECTOR, $uri];
        }
        push @$sss, [LOCAL_NAME_SELECTOR, $t->{value}];

        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == STAR_TOKEN) {
        if (defined $name) { ## Prefix is neither empty nor "*"
          my $uri = $self->{lookup_namespace_uri}->($name);
          unless (defined $uri) {
            $self->{onerror}->(type => 'namespace prefix:not declared',
                               level => $self->{level}->{must},
                               uri => \$self->{href},
                               token => $name_t || $t,
                               value => $name);
            return ($t, undef);
          }
          undef $uri unless length $uri;
          push @$sss, [NAMESPACE_SELECTOR, $uri];
        }
        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } else { ## "|" not followed by type or universal selector
        $self->{onerror}->(type => 'no local name selector',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == BEFORE_CLASS_NAME_STATE) {
      if ($t->{type} == IDENT_TOKEN) {
        push @$sss, [CLASS_SELECTOR, $t->{value}];

        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'no class name',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == BEFORE_COMBINATOR_STATE) {
      push @$selector, $sss;
      $sss = [];

      if ($t->{type} == S_TOKEN) {
        $state = COMBINATOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ({
                GREATER_TOKEN, 1,
                PLUS_TOKEN, 1,
                TILDE_TOKEN, 1,
                COMMA_TOKEN, 1,
                EOF_TOKEN, 1,
                $_[2], 1,
               }->{$t->{type}}) {
        $state = COMBINATOR_STATE;
        ## Reprocess.
        redo S;
      } else {
        $self->{onerror}->(type => 'no combinator',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == COMBINATOR_STATE) {
      if ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } elsif ({
                GREATER_TOKEN, 1,
                PLUS_TOKEN, 1,
                TILDE_TOKEN, 1,
               }->{$t->{type}}) {
        if ($has_pseudo_element) {
          $self->{onerror}->(type => 'combinator after pseudo-element',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }

        push @$selector, $t->{type};

        $state = BEFORE_TYPE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == EOF_TOKEN or $t->{type} == $_[2]) {
        push @$selectors, $selector;
        return ($t, $selectors);
      } elsif ($t->{type} == COMMA_TOKEN) {
        push @$selectors, $selector;
        $selector = [DESCENDANT_COMBINATOR];
        undef $has_pseudo_element;

        $state = BEFORE_TYPE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } else {
        if ($has_pseudo_element) {
          $self->{onerror}->(type => 'ss after pseudo-element',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }

        push @$selector, S_TOKEN;

        $state = BEFORE_TYPE_SELECTOR_STATE;
        ## Reprocess.
        redo S;
      }
    } elsif ($state == AFTER_COLON_STATE) {
      if ($t->{type} == IDENT_TOKEN) {
        my $class = $t->{value};
        $class =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($IdentOnlyPseudoClasses->{$class}) {
          if ($self->{pseudo_class}->{$class}) {
            push @$sss, [PSEUDO_CLASS_SELECTOR, $class];
          } else {
            $self->{onerror}->(type => 'selectors:pseudo-class:ident:not supported',
                               level => $self->{level}->{warning},
                               uri => \$self->{href},
                               token => $t, value => $class);
            return ($t, undef);
          }
        } elsif ({'first-letter' => 1, 'first-line' => 1,
                  before => 1, after => 1}->{$class} and
                 not $in_negation) {
          if ($self->{pseudo_element}->{$class}) {
            $self->{onerror}->(type => 'selectors:pseudo-element:one colon',
                               level => $self->{level}->{warning},
                               uri => \$self->{href},
                               token => $t, value => $class);
            push @$sss, [PSEUDO_ELEMENT_SELECTOR, $class];
            $has_pseudo_element = 1;
          } else {
            $self->{onerror}->(type => 'selectors:pseudo-element:ident:not supported',
                               level => $self->{level}->{warning},
                               uri => \$self->{href},
                               token => $t, value => $class);
            return ($t, undef);
          }
        } else {
          $self->{onerror}->(type => 'selectors:pseudo-class:ident:unknown',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t, value => $class);
          return ($t, undef);
        }

        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == FUNCTION_TOKEN) {
        my $class = $t->{value};
        $class =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        
        my $known;
        if ($class eq 'lang') {
          if ($self->{pseudo_class}->{$class}) {
            $state = BEFORE_LANG_TAG_STATE;
            $t = $tt->get_next_token;
            redo S;
          } else {
            $known = 1;
          }
        } elsif ($class eq 'not' and not $in_negation) {
          if ($self->{pseudo_class}->{$class}) {
            $in_negation = 1;
            
            push @$sss, '';
            $state = BEFORE_TYPE_SELECTOR_STATE;
            $t = $tt->get_next_token;
            redo S;
          } else {
            $known = 1;
          }
        } elsif ({
                  'nth-child' => 1,
                  'nth-last-child' => 1,
                  'nth-of-type' => 1,
                  'nth-last-of-type' => 1,
                 }->{$class}) {
          if ($self->{pseudo_class}->{$class}) {
            $name = $class;
            
            $state = BEFORE_AN_STATE;
            $t = $tt->get_next_token;
            redo S;
          } else {
            $known = 1;
          }
        } elsif ($class eq '-manakai-contains') {
          if ($self->{pseudo_class}->{$class}) {
            $state = BEFORE_CONTAINS_STRING_STATE;
            $t = $tt->get_next_token;
            redo S;
          } else {
            $known = 1;
          }
        }

        if ($known) {
          $self->{onerror}->(type => 'selectors:pseudo-class:function:not supported',
                             level => $self->{level}->{warning},
                             uri => \$self->{href},
                             token => $t, value => $class);
          return ($t, undef);
        } else {
          $self->{onerror}->(type => 'selectors:pseudo-class:function:unknown',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t, value => $class);
          return ($t, undef);
        }
      } elsif ($t->{type} == COLON_TOKEN and
               not $in_negation) { ## Pseudo-element
        $state = AFTER_DOUBLE_COLON_STATE;
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'no pseudo-class name',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == AFTER_LBRACKET_STATE) { ## Attribute selector
      $simple_selector = [ATTRIBUTE_SELECTOR];
      if ($t->{type} == IDENT_TOKEN) {
        $name = $t->{value};
        $name_t = $t;

        $state = AFTER_ATTR_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == VBAR_TOKEN) {
        $simple_selector->[1] = ''; # null namespace
        
        $state = BEFORE_ATTR_LOCAL_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == STAR_TOKEN) {
        $name = undef;
        $name_t = undef;

        $state = AFTER_ATTR_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'no attr name',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == AFTER_ATTR_NAME_STATE) {
      if ($t->{type} == VBAR_TOKEN) {
        if (defined $name) {
          my $uri = $self->{lookup_namespace_uri}->($name);
          unless (defined $uri) {
            $self->{onerror}->(type => 'namespace prefix:not declared',
                               level => $self->{level}->{must},
                               uri => \$self->{href},
                               token => $name_t || $t,
                               value => $name);
            return ($t, undef);
          }
          $simple_selector->[1] = $uri; # null namespace if $uri is empty
        }

        $state = BEFORE_ATTR_LOCAL_NAME_STATE;
        $t = $tt->get_next_token;
        redo S;
      } else {
        unless (defined $name) { ## [*]
          $self->{onerror}->(type => 'no attr namespace separator',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
        $simple_selector->[1] = ''; # null namespace
        $simple_selector->[2] = $name;

        $state = BEFORE_MATCH_STATE;
        ## Reprocess.
        redo S;
      }
    } elsif ($state == BEFORE_ATTR_LOCAL_NAME_STATE) {
      if ($t->{type} == IDENT_TOKEN) {
        $simple_selector->[2] = $t->{value};
        
        $state = BEFORE_MATCH_STATE;
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'no attr local name',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == BEFORE_MATCH_STATE) {
      if ({
           MATCH_TOKEN, 1,
           INCLUDES_TOKEN, 1,
           DASHMATCH_TOKEN, 1,
           PREFIXMATCH_TOKEN, 1,
           SUFFIXMATCH_TOKEN, 1,
           SUBSTRINGMATCH_TOKEN, 1,
          }->{$t->{type}}) {
        $simple_selector->[3] = $t->{type};

        $state = BEFORE_VALUE_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == RBRACKET_TOKEN) {
        push @$sss, $simple_selector;
        
        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'no attr match',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == BEFORE_VALUE_STATE) {
      if ($t->{type} == IDENT_TOKEN or
          $t->{type} == STRING_TOKEN or
          ($t->{type} == INVALID_TOKEN and $t->{eos})) {
        $simple_selector->[4] = $t->{value};
        push @$sss, $simple_selector;

        $state = AFTER_VALUE_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'no attr value',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == AFTER_VALUE_STATE) {
      if ($t->{type} == RBRACKET_TOKEN) {
        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'attr selector not closed',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == AFTER_DOUBLE_COLON_STATE) {
      if ($t->{type} == IDENT_TOKEN) {
        my $pe = $t->{value};
        $pe =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($self->{pseudo_element}->{$pe} and 
            $IdentOnlyPseudoElements->{$pe}) {
          push @$sss, [PSEUDO_ELEMENT_SELECTOR, $pe];
          $has_pseudo_element = 1;

          $state = BEFORE_SIMPLE_SELECTOR_STATE;
          $t = $tt->get_next_token;
          redo S;
        } else {
          if ($IdentOnlyPseudoElements->{$pe}) {
            $self->{onerror}
                ->(type => 'selectors:pseudo-element:ident:not supported',
                   level => $self->{level}->{warning},
                   uri => \$self->{href},
                   token => $t, value => $pe);
          } else {
            $self->{onerror}
                ->(type => 'selectors:pseudo-element:ident:unknown',
                   level => $self->{level}->{must},
                   uri => \$self->{href},
                   token => $t, value => $pe);
          }
          return ($t, undef);
        }
      } elsif ($t->{type} == FUNCTION_TOKEN) {
        my $pe = $t->{value};
        $pe =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($self->{pseudo_element}->{$pe} and
            $pe eq 'cue') {
          my $sub_selectors;
          ($t, $sub_selectors)
              = $self->_parse_selectors_with_tokenizer ($tt, RPAREN_TOKEN);
          if ($sub_selectors and @$sub_selectors) {
            unless ($t->{type} == RPAREN_TOKEN) {
              $self->{onerror}->(type => 'function not closed',
                                 level => $self->{level}->{must},
                                 uri => \$self->{href},
                                 token => $t);
              return ($t, undef);
            }

            push @$sss, [PSEUDO_ELEMENT_SELECTOR, $pe, $sub_selectors];
            $has_pseudo_element = 1;
            
            $state = BEFORE_SIMPLE_SELECTOR_STATE;
            $t = $tt->get_next_token;
            redo S;
          } else {
            return ($t, undef);
          }
        } else {
          if ($pe eq 'cue') {
            $self->{onerror}
                ->(type => 'selectors:pseudo-element:function:not supported',
                   level => $self->{level}->{warning},
                   uri => \$self->{href},
                   token => $t, value => $pe);
          } else {
            $self->{onerror}
                ->(type => 'selectors:pseudo-element:function:unknown',
                   level => $self->{level}->{must},
                   uri => \$self->{href},
                   token => $t, value => $pe);
          }
          return ($t, undef);
        }
      } else {
        $self->{onerror}->(type => 'no pseudo-element name',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == BEFORE_LANG_TAG_STATE) {
      if ($t->{type} == IDENT_TOKEN) {
        push @$sss, [PSEUDO_CLASS_SELECTOR, 'lang', $t->{value}];
        
        $state = AFTER_LANG_TAG_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'no lang tag',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == AFTER_LANG_TAG_STATE) {
      if ($t->{type} == RPAREN_TOKEN) {
        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'selectors:pseudo:argument not closed',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == BEFORE_AN_STATE) {
      if ($t->{type} == DIMENSION_TOKEN) {
        if ($t->{number} =~ /\A[0-9]+\z/) {
          my $n = $t->{value};
          $n =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          if ($n eq 'n') {
            $simple_selector = [PSEUDO_CLASS_SELECTOR, $name,
                                0+$t->{number}, 0];
            
            $state = AFTER_AN_STATE;
            $t = $tt->get_next_token;
            redo S;
          } elsif ($n =~ /\An-([0-9]+)\z/) {
            push @$sss, [PSEUDO_CLASS_SELECTOR, $name, 0+$t->{number}, 0-$1];

            $state = AFTER_B_STATE;
            $t = $tt->get_next_token;
            redo S;
          } elsif ($n =~ /\An-\z/) {
            push @$sss, [PSEUDO_CLASS_SELECTOR, $name, 0+$t->{number}, 0];

            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
            if ($t->{type} == NUMBER_TOKEN and
                $t->{number} =~ /\A[0-9]+\z/) {
              $sss->[-1]->[-1] -= $t->{number};
              $state = AFTER_B_STATE;
              $t = $tt->get_next_token;
              redo S;
            }
          }
          $self->{onerror}->(type => 'an+b syntax error',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        } else {
          $self->{onerror}->(type => 'an+b syntax error',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
      } elsif ($t->{type} == NUMBER_TOKEN) {
        if ($t->{number} =~ /\A[0-9]+\z/) {
          push @$sss, [PSEUDO_CLASS_SELECTOR, $name, 0, 0+$t->{number}];

          $state = AFTER_B_STATE;
          $t = $tt->get_next_token;
          redo S;
        } else {
          $self->{onerror}->(type => 'an+b not integer',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t, value => $t->{number});
          return ($t, undef);
        }
      } elsif ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
        if ($value eq 'odd') {
          push @$sss, [PSEUDO_CLASS_SELECTOR, $name, 2, 1];

          $state = AFTER_B_STATE;
          $t = $tt->get_next_token;
          redo S;
        } elsif ($value eq 'even') {
          push @$sss, [PSEUDO_CLASS_SELECTOR, $name, 2, 0];

          $state = AFTER_B_STATE;
          $t = $tt->get_next_token;
          redo S;
        } elsif ($value eq 'n' or $value eq '-n') {
          $simple_selector = [PSEUDO_CLASS_SELECTOR, $name,
                              $value eq 'n' ? 1 : -1, 0];

          $state = AFTER_AN_STATE;
          $t = $tt->get_next_token;
          redo S;
        } elsif ($value =~ /\A(-?)n-([0-9]+)\z/) {
          push @$sss, [PSEUDO_CLASS_SELECTOR, $name, 0+($1.'1'), -$2];

          $state = AFTER_B_STATE;
          $t = $tt->get_next_token;
          redo S;
        } else {
          $self->{onerror}->(type => 'an+b syntax error',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
      } elsif ($t->{type} == MINUS_TOKEN or
               $t->{type} == PLUS_TOKEN) {
        my $sign = $t->{type} == MINUS_TOKEN ? -1 : +1;
        $t = $tt->get_next_token;
        if ($t->{type} == DIMENSION_TOKEN || $t->{type} == IDENT_TOKEN) {
          my $num = $t->{type} == IDENT_TOKEN ? 1 : $t->{number};
          if ($num =~ /\A[0-9]+\z/) {
            my $n = $t->{value};
            $n =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($n eq 'n') {
              $simple_selector = [PSEUDO_CLASS_SELECTOR, $name,
                                  $sign * $num, 0];
              
              $state = AFTER_AN_STATE;
              $t = $tt->get_next_token;
              redo S;
            } elsif ($n =~ /\An-([0-9]+)\z/) {
              $simple_selector = [PSEUDO_CLASS_SELECTOR, $name,
                                  $sign * $num, -$1];

              $state = AFTER_AN_STATE;
              $t = $tt->get_next_token;
              redo S;
            } else {
              $self->{onerror}->(type => 'an+b syntax error',
                                 level => $self->{level}->{must},
                                 uri => \$self->{href},
                                 token => $t);
              return ($t, undef);
            }
          } else {
            $self->{onerror}->(type => 'an+b syntax error',
                               level => $self->{level}->{must},
                               uri => \$self->{href},
                               token => $t);
            return ($t, undef);
          }
        } elsif ($t->{type} == NUMBER_TOKEN) {
          if ($t->{number} =~ /\A[0-9]+\z/) {
            push @$sss, [PSEUDO_CLASS_SELECTOR, $name,
                         0, $sign * $t->{number}];

            $state = AFTER_B_STATE;
            $t = $tt->get_next_token;
            redo S;
          } else {
            $self->{onerror}->(type => 'an+b syntax error',
                               level => $self->{level}->{must},
                               uri => \$self->{href},
                               token => $t);
            return ($t, undef);
          }
        } else {
          $self->{onerror}->(type => 'an+b syntax error',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'an+b syntax error',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == AFTER_AN_STATE) {
      if ($t->{type} == PLUS_TOKEN) {
        $simple_selector->[3] = +1;

        $state = BEFORE_B_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == MINUS_TOKEN) {
        $simple_selector->[3] = -1;

        $state = BEFORE_B_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == RPAREN_TOKEN) {
        push @$sss, $simple_selector;

        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'an+b syntax error',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == BEFORE_B_STATE) {
      if ($t->{type} == NUMBER_TOKEN) {
        if ($t->{number} =~ /\A[0-9]+\z/) {
          $simple_selector->[3] *= $t->{number};
          push @$sss, $simple_selector;
          
          $state = AFTER_B_STATE;
          $t = $tt->get_next_token;
          redo S;
        } else {
          $self->{onerror}->(type => 'an+b syntax error',
                             level => $self->{level}->{must},
                             uri => \$self->{href},
                             token => $t);
          return ($t, undef);
        }
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'an+b syntax error',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == AFTER_B_STATE) {
      if ($t->{type} == RPAREN_TOKEN) {
        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'an+b not closed',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == AFTER_NEGATION_SIMPLE_SELECTOR_STATE) {
      if ($t->{type} == RPAREN_TOKEN) {
        undef $in_negation;
        my $simple_selector = [];
        unshift @$simple_selector, pop @$sss while ref $sss->[-1];
        pop @$sss; # dummy
        unshift @$simple_selector, 'not';
        unshift @$simple_selector, PSEUDO_CLASS_SELECTOR;
        push @$sss, $simple_selector;
        
        $state = BEFORE_SIMPLE_SELECTOR_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'not not closed',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } elsif ($state == BEFORE_CONTAINS_STRING_STATE) {
      if ($t->{type} == STRING_TOKEN or
          $t->{type} == IDENT_TOKEN or
          ($t->{type} == INVALID_TOKEN and $t->{eos})) {
        push @$sss, [PSEUDO_CLASS_SELECTOR, '-manakai-contains', $t->{value}];
        
        $state = AFTER_LANG_TAG_STATE;
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == S_TOKEN) {
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } else {
        $self->{onerror}->(type => 'no contains string',
                           level => $self->{level}->{must},
                           uri => \$self->{href},
                           token => $t);
        return ($t, undef);
      }
    } else {
      die "$0: Selectors Parser: $state: Unknown state";
    }
  } # S
} # _parse_selectors_with_tokenizer

sub get_selector_specificity ($$) {
  my (undef, $selector) = @_;

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
      if ($ss->[0] == LOCAL_NAME_SELECTOR or
          $ss->[0] == PSEUDO_ELEMENT_SELECTOR) {
        $r->[3]++;
      } elsif ($ss->[0] == ATTRIBUTE_SELECTOR or
               $ss->[0] == CLASS_SELECTOR) {
        $r->[2]++;
      } elsif ($ss->[0] == PSEUDO_CLASS_SELECTOR) {
        if ($ss->[1] eq 'not') {
          push @sss, @$ss[2..$#$ss];
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

=head1 LICENSE

Copyright 2007-2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
