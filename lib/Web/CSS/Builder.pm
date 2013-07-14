package Web::CSS::Builder;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::CSS::Tokenizer;
push our @ISA, qw(Web::CSS::Tokenizer);

sub init ($) {
  my $self = $_[0];
  $self->SUPER::init;

  delete $self->{constructs};
  delete $self->{parsed_construct};
} # init

## ------ Builder states ------

sub LIST_OF_RULES_STATE () { 1 }
sub QUALIFIED_RULE_STATE () { 2 }
sub ATKEYWORD_STATE () { 3 }
sub SIMPLE_BLOCK_STATE () { 4 }
sub COMPONENT_VALUE_STATE () { 5 }
sub LIST_OF_DECLARATIONS_STATE () { 6 }
sub DECLARATION_AFTER_NAME_STATE () { 7 }
sub BAD_DECLARATION_STATE () { 8 }
sub DECLARATION_COLON_STATE () { 9 }
sub FUNCTION_STATE () { 10 }

## <http://suika.suikawiki.org/~wakaba/wiki/sw/n/rule#anchor-3>
sub AtBlockState () {
  {
    # <stylesheet>
    media => LIST_OF_RULES_STATE,
    '-moz-document' => LIST_OF_RULES_STATE,

    # <rule-list>
    keyframes => LIST_OF_RULES_STATE,

    # <declaration-list>
    'font-face' => LIST_OF_DECLARATIONS_STATE,
    page => LIST_OF_DECLARATIONS_STATE,
    global => LIST_OF_DECLARATIONS_STATE,
  }
}
sub QualifiedBlockState () {
  {
    # <stylesheet> > <declaration-list>
    '' => LIST_OF_DECLARATIONS_STATE,
    media => LIST_OF_DECLARATIONS_STATE,
    '-moz-document' => LIST_OF_DECLARATIONS_STATE,

    # <declaration-list>
    keyframes => LIST_OF_DECLARATIONS_STATE,
  }
}

## ------ Construct types ------

sub RULE_LIST_CONSTRUCT () { 10000 + 1 }
sub AT_RULE_CONSTRUCT () { 10000 + 2 }
sub QUALIFIED_RULE_CONSTRUCT () { 10000 + 3 }
sub BLOCK_CONSTRUCT () { 10000 + 4 }
sub DECLARATION_CONSTRUCT () { 10000 + 5 }

## ------ Builder implementation ------

sub init_builder ($) {
  my $self = $_[0];
  $self->{constructs} = []; ## Stack of open constructs
  ## bs Builder's state
  ## bt Builder's current token
  delete $self->{parsed_construct};
} # init_builder

## Construct
##   type                        - Type of the construct, as one of constants.
##   line, column                - The position of the first character for
##                                 the construct.
##   name
##     AT_RULE_CONSTRUCT         - The first <at-keyword> token.
##     DECLARATION_CONSTRUCT     - The name token.
##     BLOCK_CONSTRUCT           - The opening token for the block or function.
##   at
##     BLOCK_CONSTRUCT & name.type == LBRACE_TOKEN - The lowercase-normalized
##                                 name of the at-rule.
##   parent_at
##     QUALIFIED_RULE_CONSTRUCT  - The lowercase-normalized name of the at-rule
##                                 in which the qualified rule is directly
##                                 contained.
##   value
##     RULE_LIST_CONSTRUCt       - Rules in the list of rules.
##     AT_RULE_CONSTRUCT         - Tokens and/or constructs after the
##                                 <at-keyword> token, i.e. prelude
##                                 components followed by an optional block.
##     QUALIFIED_RULE_CONSTRUCT  - Tokens and/or constructs in the rule,
##                                 i.e. prelude components followed by
##                                 a block.
##     BLOCK_CONSTRUCT           - Tokens and/or constructs in the block.
##                                 Open and end tokens are not contained.
##     DECLARATION_CONSTRUCT     - Tokens and/or constructs for the value
##                                 and the |important| flag.
##   end_type
##     BLOCK_CONSTRUCT           - The type of the end token for the block.
##     DECLARATION_CONSTRUCT     - The type of the end token for the block.
##   delim_type
##     DECLARATION_CONSTRUCT     - The type of the token closing the
##                                 declaration.
##   top_level
##     RULE_LIST_CONSTRUCT       - The top-level flag.

sub start_building_style_sheet ($) {
  my $self = $_[0];

  ## Parse a stylesheet
  ## <http://dev.w3.org/csswg/css-syntax/#parse-a-stylesheet>.

  $self->{bs} = LIST_OF_RULES_STATE;
  $self->{prev_bs} = [];
  push @{$self->{constructs}},
      {type => RULE_LIST_CONSTRUCT,
       line => $self->{line},
       column => $self->{column},
       value => [],
       top_level => 1};
  $self->{bt} = $self->get_next_token;
  $self->start_construct;

  $self->_consume_tokens;

  if ($self->{bt}->{type} == EOF_TOKEN) {
    $self->end_construct;
    $self->{parsed_construct} = pop @{$self->{constructs}};
    die "Stack of constructs is not empty" if @{$self->{constructs}};
    return 1;
  }
  return 0;
} # start_building_style_sheet

sub continue_building ($) {
  my $self = $_[0];
  die "Stack of constructs is empty" unless @{$self->{constructs}};

  $self->_consume_tokens;

  if ($self->{bt}->{type} == EOF_TOKEN) {
    die "Stack of constructs is empty" unless @{$self->{constructs}};
    $self->end_construct;
    $self->{parsed_construct} = pop @{$self->{constructs}};
    die "Stack of constructs is not empty" if @{$self->{constructs}};
    return 1;
  }
  return 0;
} # continue_building

sub _consume_tokens ($) {
  my $self = $_[0];

  A: {
    if ($self->{bt}->{type} == ABORT_TOKEN) {
      $self->{bt} = $self->get_next_token;
      return;
    }

    if ($self->{bs} == LIST_OF_RULES_STATE) {
      ## Consume a list of rules
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-list-of-rules>
      
      if ($self->{bt}->{type} == S_TOKEN) {
        ## Stay in this state.
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == ATKEYWORD_TOKEN) {
        my $construct = {type => AT_RULE_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         name => $self->{bt},
                         value => []};
        unless ($self->{constructs}->[-1]->{top_level}) {
          $construct->{delim_type} = RBRACE_TOKEN;
        }
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        push @{$self->{constructs}}, $construct;
        $self->start_construct;
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = ATKEYWORD_STATE;
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == EOF_TOKEN) {
        if (@{$self->{prev_bs}}) {
          $self->{onerror}->(type => 'css:block:eof', # XXX
                             level => 'w',
                             uri => $self->context->urlref,
                             token => $self->{bt})
              unless $self->{eof_error_reported};
          $self->{eof_error_reported} = 1;
          $self->end_construct;
          pop @{$self->{constructs}};
          $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
          ## Reconsume the current token.
          redo A;
        } else {
          return;
          #redo A;
        }
      } elsif (defined $self->{constructs}->[-1]->{end_type} and
               $self->{bt}->{type} == $self->{constructs}->[-1]->{end_type}) {
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{constructs}->[-1]->{top_level} and
               ($self->{bt}->{type} == CDO_TOKEN or
                $self->{bt}->{type} == CDC_TOKEN)) {
        ## Stay in this state.
        $self->{bt} = $self->get_next_token;
        redo A;
      } else {
        my $construct = {type => QUALIFIED_RULE_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         parent_at => '',
                         value => [],
                         delim_type => LBRACE_TOKEN};
        if ($self->{constructs}->[-1]->{type} == BLOCK_CONSTRUCT and
            defined $self->{constructs}->[-1]->{at}) {
          $construct->{parent_at} = $self->{constructs}->[-1]->{at};
        }
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        push @{$self->{constructs}}, $construct;
        $self->start_construct;
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = QUALIFIED_RULE_STATE;
        ## Reconsume the current token.
        redo A;
      }

    } elsif ($self->{bs} == QUALIFIED_RULE_STATE) {
      ## Consume a qualified rule
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-qualified-rule>
      if ($self->{bt}->{type} == LBRACE_TOKEN) {
        my $construct = {type => BLOCK_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         name => $self->{bt},
                         end_type => RBRACE_TOKEN,
                         value => []};
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        my $at = $self->{constructs}->[-1]->{parent_at} || '';
        $self->{constructs}->[-1] = $construct;
        $self->start_construct;
        $self->{bs} = QualifiedBlockState->{$at} || SIMPLE_BLOCK_STATE;
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == EOF_TOKEN) {
        ## Prelude not followed by a block
        $self->{onerror}->(type => 'css:qrule:no block', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $self->{bt});
        $self->end_construct (error => 1);
        pop @{$self->{constructs}};
        pop @{$self->{constructs}->[-1]->{value}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } else {
        ## At this point $self->{constructs}->[-1]->{delim_type} is
        ## set to LBRACE_TOKEN.
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = COMPONENT_VALUE_STATE;
        ## Reconsume the current token.
        redo A;
      }
    } elsif ($self->{bs} == ATKEYWORD_STATE) {
      ## Consume an at-rule
      ## <http://dev.w3.org/csswg/css-syntax/#consume-an-at-rule>
      if ($self->{bt}->{type} == SEMICOLON_TOKEN) {
        ## An at-rule without block.
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif (defined $self->{constructs}->[-1]->{delim_type} and
               $self->{bt}->{type} == $self->{constructs}->[-1]->{delim_type}) {
        ## An at-rule without trailing semicolon or block at the end
        ## of the <declaration-list> block.
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } elsif ($self->{bt}->{type} == EOF_TOKEN) {
        ## An at-rule without block or semicolon
        $self->{onerror}->(type => 'css:at-rule:eof', # XXX
                           level => 'w',
                           uri => $self->context->urlref,
                           token => $self->{bt})
            unless $self->{eof_error_reported};
        $self->{eof_error_reported} = 1;
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } elsif ($self->{bt}->{type} == LBRACE_TOKEN) {
        ## An at-rule followed by a block
        my $construct = {type => BLOCK_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         at => $self->{constructs}->[-1]->{name}->{value},
                         name => $self->{bt},
                         end_type => RBRACE_TOKEN,
                         value => []};
        $construct->{at} =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        $self->{bs} = AtBlockState->{$construct->{at}} || SIMPLE_BLOCK_STATE;
        $self->{constructs}->[-1] = $construct;
        $self->start_construct;
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == LBRACKET_TOKEN or
               $self->{bt}->{type} == LPAREN_TOKEN or
               $self->{bt}->{type} == FUNCTION_TOKEN) {
        my $construct = {type => BLOCK_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         name => $self->{bt},
                         end_type => {LBRACKET_TOKEN, RBRACKET_TOKEN,
                                      LPAREN_TOKEN, RPAREN_TOKEN,
                                      FUNCTION_TOKEN, RPAREN_TOKEN}->{$self->{bt}->{type}}};
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        push @{$self->{constructs}}, $construct;
        $self->start_construct;
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = SIMPLE_BLOCK_STATE;
        $self->{bt} = $self->get_next_token;
        redo A;
      } else {
        push @{$self->{constructs}->[-1]->{value}}, $self->{bt};
        ## Stay in this state.
        $self->{bt} = $self->get_next_token;
        redo A;
      }

    } elsif ($self->{bs} == LIST_OF_DECLARATIONS_STATE) {
      if ($self->{bt}->{type} == S_TOKEN or
          $self->{bt}->{type} == SEMICOLON_TOKEN) {
        ## Stay in this state.
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == IDENT_TOKEN) {
        my $construct = {type => DECLARATION_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         name => $self->{bt},
                         value => [],
                         end_type => $self->{constructs}->[-1]->{end_type},
                         delim_type => SEMICOLON_TOKEN};
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        push @{$self->{constructs}}, $construct;
        $self->start_construct;
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = DECLARATION_AFTER_NAME_STATE;
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == ATKEYWORD_TOKEN) {
        my $construct = {type => AT_RULE_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         name => $self->{bt},
                         value => [],
                         delim_type => RBRACE_TOKEN};
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        push @{$self->{constructs}}, $construct;
        $self->start_construct;
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = ATKEYWORD_STATE;
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif (defined $self->{constructs}->[-1]->{end_type} and
               $self->{constructs}->[-1]->{end_type} == $self->{bt}->{type}) {
        ## LBRACE_TOKEN closing the <declaration-list>'s block
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == EOF_TOKEN) {
        if (@{$self->{prev_bs}}) {
          $self->{onerror}->(type => 'css:block:eof', # XXX
                             level => 'w',
                             uri => $self->context->urlref,
                             token => $self->{bt})
              unless $self->{eof_error_reported};
          $self->{eof_error_reported} = 1;
          $self->end_construct;
          pop @{$self->{constructs}};
          $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
          ## Reconsume the current token.
          redo A;
        } else {
          return;
          #redo A;
        }
      } else {
        $self->{onerror}->(type => 'css:decls:bad name', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $self->{bt});
        my $construct = {type => DECLARATION_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         name => $self->{bt},
                         value => [],
                         end_type => $self->{constructs}->[-1]->{end_type},
                         delim_type => SEMICOLON_TOKEN};
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        push @{$self->{constructs}}, $construct;
        $self->start_construct;
        push @{$self->{prev_bs}}, $self->{bs};
        push @{$self->{prev_bs}}, BAD_DECLARATION_STATE;
        $self->{bs} = COMPONENT_VALUE_STATE;
        ## Reconsume the current token.
        redo A;
      }
    } elsif ($self->{bs} == DECLARATION_AFTER_NAME_STATE) {
      if ($self->{bt}->{type} == S_TOKEN) {
        ## Stay in this state.
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == COLON_TOKEN) {
        $self->{bs} = DECLARATION_COLON_STATE;
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ((defined $self->{constructs}->[-1]->{delim_type} and
                $self->{constructs}->[-1]->{delim_type} == $self->{bt}->{type}) or
               (defined $self->{constructs}->[-1]->{end_type} and
                $self->{constructs}->[-1]->{end_type} == $self->{bt}->{type}) or
               $self->{bt}->{type} == EOF_TOKEN) {
        ## SEMICOLON_TOKEN at the end of the declaration
        ## RBRACE_TOKEN closing the <declaration-list>'s block
        ## EOF_TOKEN at the end of the declaration
        $self->{onerror}->(type => 'css:decl:no colon', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $self->{bt});
        $self->end_construct (error => 1);
        pop @{$self->{constructs}};
        pop @{$self->{constructs}->[-1]->{value}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } else {
        $self->{onerror}->(type => 'css:decl:no colon', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $self->{bt});
        $self->{bs} = BAD_DECLARATION_STATE;
        ## Reconsume the current token.
        redo A;
      }
    } elsif ($self->{bs} == DECLARATION_COLON_STATE) {
      if (defined $self->{constructs}->[-1]->{delim_type} and
          $self->{constructs}->[-1]->{delim_type} == $self->{bt}->{type}) {
        ## SEMICOLON_TOKEN at the end of the declaration
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif (defined $self->{constructs}->[-1]->{end_type} and
               $self->{constructs}->[-1]->{end_type} == $self->{bt}->{type}) {
        ## RBRACE_TOKEN closing the <declaration-list>'s block
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } elsif ($self->{bt}->{type} == EOF_TOKEN) {
        ## EOF_TOKEN at the end of the declaration
        if (@{$self->{prev_bs}} > 1) {
          $self->{onerror}->(type => 'css:block:eof', # XXX
                             level => 'w',
                             uri => $self->context->urlref,
                             token => $self->{bt})
              unless $self->{eof_error_reported};
          $self->{eof_error_reported} = 1;
        }
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } else {
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = COMPONENT_VALUE_STATE;
        ## Reconsume the current token.
        redo A;
      }
    } elsif ($self->{bs} == BAD_DECLARATION_STATE) {
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-list-of-declarations>
      if ($self->{bt}->{type} == SEMICOLON_TOKEN or
          $self->{bt}->{type} == EOF_TOKEN) {
        $self->end_construct (error => 1);
        pop @{$self->{constructs}};
        pop @{$self->{constructs}->[-1]->{value}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif (defined $self->{constructs}->[-1]->{end_type} and
               $self->{constructs}->[-1]->{end_type} == $self->{bt}->{type}) {
        ## RBRACE_TOKEN at the end of the <declaration-list>'s block
        $self->end_construct (error => 1);
        pop @{$self->{constructs}};
        pop @{$self->{constructs}->[-1]->{value}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } else {
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = COMPONENT_VALUE_STATE;
        ## Reconsume the current token.
        redo A;
      }

    } elsif ($self->{bs} == SIMPLE_BLOCK_STATE) {
      ## Consume a simple block
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-simple-block>.
      ##
      ## Consume a function
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-function>.
      if ($self->{bt}->{type} == $self->{constructs}->[-1]->{end_type}) {
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == EOF_TOKEN) {
        $self->{onerror}->(type => 'css:block:eof', # XXX
                           level => 'w',
                           uri => $self->context->urlref,
                           token => $self->{bt})
            unless $self->{eof_error_reported};
        $self->{eof_error_reported} = 1;
        $self->end_construct;
        pop @{$self->{constructs}};
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        $self->{bt} = $self->get_next_token;
        redo A;
      } else {
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = COMPONENT_VALUE_STATE;
        ## Reconsume the current token.
        redo A;
      }
    } elsif ($self->{bs} == COMPONENT_VALUE_STATE) {
      ## Consume a component value
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-component-value>
      if ((defined $self->{constructs}->[-1]->{delim_type} and
           $self->{constructs}->[-1]->{delim_type} == $self->{bt}->{type}) or
          (defined $self->{constructs}->[-1]->{end_type} and
           $self->{constructs}->[-1]->{end_type} == $self->{bt}->{type})) {
        ## SEMICOLON_TOKEN in <declaration-list>
        ## RBRACE_TOKEN in simple block
        ## LBRACE_TOKEN in qualified rule's prelude
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } elsif ($self->{bt}->{type} == LBRACE_TOKEN or
               $self->{bt}->{type} == LBRACKET_TOKEN or
               $self->{bt}->{type} == LPAREN_TOKEN or
               $self->{bt}->{type} == FUNCTION_TOKEN) {
        my $construct = {type => BLOCK_CONSTRUCT,
                         line => $self->{bt}->{line},
                         column => $self->{bt}->{column},
                         name => $self->{bt},
                         end_type => {LBRACE_TOKEN, RBRACE_TOKEN,
                                      LBRACKET_TOKEN, RBRACKET_TOKEN,
                                      LPAREN_TOKEN, RPAREN_TOKEN,
                                      FUNCTION_TOKEN, RPAREN_TOKEN}->{$self->{bt}->{type}},
                         value => []};
        push @{$self->{constructs}->[-1]->{value}}, $construct;
        push @{$self->{constructs}}, $construct;
        $self->start_construct;
        push @{$self->{prev_bs}}, $self->{bs};
        $self->{bs} = SIMPLE_BLOCK_STATE;
        $self->{bt} = $self->get_next_token;
        redo A;
      } elsif ($self->{bt}->{type} == EOF_TOKEN) {
        ## "eof" error will be reported later.
        $self->{bs} = pop @{$self->{prev_bs}} or die "State stack is empty";
        ## Reconsume the current token.
        redo A;
      } else {
        push @{$self->{constructs}->[-1]->{value}}, $self->{bt};
        $self->{bt} = $self->get_next_token;
        ## Stay in this state.
        redo A;
      }

    } else {
      die "Unknown state |$self->{bs}|";
    }
  } # A

  ## Differences from the css-syntax's parsing algorithm:
  ##   - The parsing algorithm is implemented as a state machine
  ##     rather than the set of recursivly invoked steps.
  ##   - When a declaration is parsed, the "consume a component value"
  ##     steps are used to fill the temporary list.
  ##   - The "consume a component value" steps ignore the <{> token
  ##     when they are invoked directly from the "consume an at-rule" or
  ##     "consume a qualified rule" steps.
  ##   - The "consume an at-rule" steps act as if there is a <;> token before
  ##     the first <}> token which is not part of any block, if any, when
  ##     the steps are /not/ invoked directly from the "parse a
  ##     list of rules" steps.
  ##   - When the end of file is reached before any block or function
  ##     is closed, a warning is raised.
} # _consume_tokens

## ------ Hooks ------

## Invoked when a construct is pushed to the stack of the constructs.
sub start_construct ($;%) {
  #
} # start_construct

## Invoked when a construct is to be popped from the stack of the
## constructs.
##
##     error => boolean - The construct is in error and should be discarded.
sub end_construct ($;%) {
  #
} # end_construct

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
