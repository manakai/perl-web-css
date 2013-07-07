package Web::CSS::Parser;
use strict;
use warnings;
our $VERSION = '4.0';
use Web::CSS::Tokenizer;
use Web::CSS::Props;
use Web::CSS::Selectors::Parser;
use Web::CSS::MediaQueries::Parser;

sub new ($) {
  my $self = bless {}, $_[0];
} # new

sub BEFORE_STATEMENT_STATE () { 0 }
sub BEFORE_DECLARATION_STATE () { 1 }
sub IGNORED_STATEMENT_STATE () { 2 }
sub IGNORED_DECLARATION_STATE () { 3 }

sub init ($) {
  my $self = shift;
  for (qw(onerror media_resolver context parsed
          current_sheet_id open_rules_list current_rules
          current_decls closing_tokens state
          sheet_set style_decls
          sp mp tt t)) {
    delete $self->{$_};
  }
} # init

sub context ($;$) {
  if (@_ > 1) {
    $_[0]->{context} = $_[1];
  }
  return $_[0]->{context} ||= do {
    require Web::CSS::Context;
    Web::CSS::Context->new_from_nsmaps ({}, {});
  };
} # context

sub media_resolver ($;$) {
  if (@_ > 1) {
    $_[0]->{media_resolver} = $_[1];
  }
  return $_[0]->{media_resolver} ||= do {
    require Web::CSS::MediaResolver;
    Web::CSS::MediaResolver->new;
  };
} # media_resolver

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }

  return $_[0]->{onerror} ||= sub {
    my %opt = @_;
    require Carp;
    Carp::carp
        (sprintf 'Document <%s>: Line %d column %d (token %s): %s%s',
             ${$opt{uri}},
             $opt{token}->{line},
             $opt{token}->{column},
             Web::CSS::Tokenizer->serialize_token ($opt{token}),
             $opt{type},
             defined $opt{value} ? " (value $opt{value})" : '');
  }; # onerror
} # onerror

sub _init_subcomponents {
  my $self = $_[0];
  my $onerror = $self->onerror; # touch

  {
    my $s = $_[1];
    pos ($s) = 0;
    my $line = 1;
    my $column = 0;
    $self->{tt} = Web::CSS::Tokenizer->new;
    $self->{tt}->context ($self->context);
    $self->{tt}->onerror ($onerror);

    $self->{tt}->{line_prev} = $self->{tt}->{line} = 1;
    $self->{tt}->{column_prev} = -1;
    $self->{tt}->{column} = 0;

    $self->{tt}->{chars} = [split //, $s];
    $self->{tt}->{chars_pos} = 0;
    delete $self->{tt}->{chars_was_cr};
    $self->{tt}->{chars_pull_next} = sub { 0 };
    $self->{tt}->init_tokenizer;
  }

  $self->{sp} = Web::CSS::Selectors::Parser->new;
  $self->{sp}->{pseudo_element} = $self->{pseudo_element};
  $self->{sp}->{pseudo_class} = $self->{pseudo_class};
  $self->{sp}->context ($self->context);
  $self->{sp}->media_resolver ($self->media_resolver);
  $self->{sp}->onerror ($onerror);

  $self->{mp} = Web::CSS::MediaQueries::Parser->new;
  $self->{mp}->context ($self->context);
  $self->{mp}->onerror ($onerror);

  ## List of supported properties and their keywords
  {
    my $mr = $self->media_resolver;
    $self->{prop} = $mr->{prop} || {};
    $self->{prop_value} = $mr->{prop_value} || {};
  }
} # _init_subcomponents

# XXX sync with new css-syntax definition

# XXX stream mode

# XXX parse_byte_string

sub parse_char_string ($$;%) {
  my ($self, undef, %args) = @_;
  $self->_init_subcomponents ($_[1]);

  ## Parser states
  $self->{state} = BEFORE_STATEMENT_STATE;
  $self->{t} = $self->{tt}->get_next_token;

  ## Arrayref of the "rules" arrayrefs of the currenly open rules.
  $self->{open_rules_list} = [[]];

  ## The "rules" arrayref of the most recently opened rule, i.e. the
  ## arrayref of the rules contained by the innermost rule.
  $self->{current_rules} = $self->{open_rules_list}->[-1];

  ## The hashref of the declarations for the current rule.
  #$self->{current_decls}

  ## The LILO stack of token types, representing the expected token to
  ## close the current structure.
  $self->{closing_tokens} = [];

  # XXX
  $self->{charset_allowed} = 1;
  $self->{namespace_allowed} = 1;
  $self->{import_allowed} = 1;
  $self->{media_allowed} = 1;

  ## Parsed style sheet set structure
  ##
  ##   next_sheet_id - The index for the next style sheet structure
  ##   sheets        - The arrayref of style sheet structures
  ##   next_rule_id  - The index for the next rule structure
  ##   rules         - The arrayref of rule structures
  $self->{sheet_set} ||= {next_sheet_id => 0,
                       sheets => [],
                       next_rule_id => 0,
                       rules => []};

  $self->{current_sheet_id} = $self->{sheet_set}->{next_sheet_id}++;
  ## Style sheet structures
  ##
  ##   rules       - The arrayref of indexes of rules contained by the sheet
  ##   base_urlref - The scalarref of the base URL for the style sheet
  $self->{sheet_set}->{sheets}->[$self->{current_sheet_id}] = {
    rules => $self->{open_rules_list}->[0],
    base_urlref => $self->context->base_urlref,
    # XXX parent_style_sheet => ...,
  };
  # XXX import

  ## Rule structures
  ##
  ##   type               - The type of rule, |@/rule/| or |style|
  ##   parent_style_sheet - The ID of the owner style sheet
  ##   parent_rule        - The ID of the parent rule
  ##   href               - The imported URL (not normalized)
  ##   media              - Parsed media queries
  ##   namespace_uri      - Scalarref of namespace URL
  ##   prefix             - Scalarref of namespace prefix
  ##   style_sheet        - The ID of the referenced style sheet
  ##   rules              - The arrayref of rule structures
  ##   selectors          - Parsed selectors
  ##   style              - Parsed declarations
  
  $self->_parse;
} # parse_char_string

sub parse_char_string_as_style_decls ($$;%) {
  my ($self, undef, %args) = @_;
  $self->_init_subcomponents ($_[1]);

  ## Parser states
  $self->{state} = BEFORE_DECLARATION_STATE;
  $self->{t} = $self->{tt}->get_next_token;

  $self->{style_decls} = 
  ## The hashref of the declarations for the current rule.
  $self->{current_decls} = {props => {}, prop_names => []};

  ## The LILO stack of token types, representing the expected token to
  ## close the current structure.
  $self->{closing_tokens} = [];
  
  $self->_parse;
} # parse_char_string_as_style_decls

sub _parse ($) {
  my ($self) = @_;

  S: {
    if ($self->{state} == BEFORE_STATEMENT_STATE) {
      $self->{t} = $self->{tt}->get_next_token
          while $self->{t}->{type} == S_TOKEN or
              $self->{t}->{type} == CDO_TOKEN or
              $self->{t}->{type} == CDC_TOKEN;

      if ($self->{t}->{type} == ATKEYWORD_TOKEN) {
        my $t_at = $self->{t};
        my $at_rule_name = lc $self->{t}->{value}; ## TODO: case
        if ($at_rule_name eq 'namespace') { # @namespace
          $self->{t} = $self->{tt}->get_next_token;
          $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;

          my $prefix;
          if ($self->{t}->{type} == IDENT_TOKEN) {
            $prefix = $self->{t}->{value};
            $self->{t} = $self->{tt}->get_next_token;
            $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
          }

          if ($self->{t}->{type} == STRING_TOKEN or $self->{t}->{type} == URI_TOKEN) {
            my $uri = $self->{t}->{value};
            
            $self->{t} = $self->{tt}->get_next_token;
            $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;

            if ($self->{t}->{type} == SEMICOLON_TOKEN) {
              if ($self->{namespace_allowed}) {
                my $p = $prefix;
                if (defined $prefix) {
                  if (defined $self->context->get_url_by_prefix ($prefix)) {
                    $self->{onerror}->(type => 'duplicate @namespace',
                               value => $prefix,
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t_at);
                  }
                  $self->context->{prefix_to_url}->{$prefix} = $uri;
                  $p .= '|';
                } else {
                  if (defined $self->context->get_url_by_prefix ('')) {
                    $self->{onerror}->(type => 'duplicate @namespace',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t_at);
                  }
                  $self->context->{prefix_to_url}->{''} = $uri;
                  $p = '';
                }
                my $map = $self->context->{url_to_prefixes};
                for my $u (keys %$map) {
                  next if $u eq $uri;
                  my $list = $map->{$u};
                  next unless $list;
                  for (reverse 0..$#$list) {
                    splice @$list, $_, 1, () if $list->[$_] eq $p;
                  }
                }
                push @{$map->{$uri} ||= []}, $p;
                my $rule_id = $self->{sheet_set}->{next_rule_id}++;
                $self->{sheet_set}->{rules}->[$rule_id]
                    = {type => '@namespace',
                       parent_style_sheet => $self->{current_sheet_id},
                       prefix => \$prefix, # XXX ref reuse
                       namespace_uri => \$uri}; # XXX ref reuse
                push @{$self->{current_rules}}, $rule_id;
                undef $self->{charset_allowed};
                undef $self->{import_allowed};
              } else {
                $self->{onerror}->(type => 'at-rule not allowed',
                           text => 'namespace',
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $self->{t});
              }
              
              $self->{t} = $self->{tt}->get_next_token;
              ## Stay in the state.
              redo S;
            } else {
              #
            }
          } else {
            #
          }

          $self->{onerror}->(type => 'at-rule syntax error',
                     text => 'namespace',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $self->{t});
          #
        } elsif ($at_rule_name eq 'import') {
          if ($self->{import_allowed}) {
            $self->{t} = $self->{tt}->get_next_token;
            $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
            my $mq = [];
            if ($self->{t}->{type} == STRING_TOKEN or $self->{t}->{type} == URI_TOKEN) {
              my $uri = $self->{t}->{value};
              $self->{t} = $self->{tt}->get_next_token;
              $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
              if ($self->{t}->{type} == IDENT_TOKEN or 
                  $self->{t}->{type} == DIMENSION_TOKEN or
                  $self->{t}->{type} == NUMBER_TOKEN or
                  $self->{t}->{type} == LPAREN_TOKEN) {
                ($self->{t}, $mq) = $self->{mp}->_parse_mq_with_tokenizer ($self->{t}, $self->{tt});
                $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
              }
              if ($mq and $self->{t}->{type} == SEMICOLON_TOKEN) {
                ## TODO: error or warning
                ## TODO: White space definition
                $uri =~ s/^[\x09\x0A\x0D\x20]+//;
                $uri =~ s/[\x09\x0A\x0D\x20]+\z//;

                my $sheet_id = $self->{sheet_set}->{next_sheet_id}++;
                $self->{sheet_set}->{sheets}->[$sheet_id] = {
                  rules => [],
                  parent_style_sheet => $self->{current_sheet_id},
                };

                my $rule_id = $self->{sheet_set}->{next_rule_id}++;
                $self->{sheet_set}->{rules}->[$rule_id]
                    = {type => '@import',
                       parent_style_sheet => $self->{current_sheet_id},
                       style_sheet => $sheet_id,
                       href => $uri,
                       media => $mq};
                push @{$self->{current_rules}}, $rule_id;
                undef $self->{charset_allowed};

                $self->{t} = $self->{tt}->get_next_token;
                ## Stay in the state.
                redo S;
              }
            }

            $self->{onerror}->(type => 'at-rule syntax error',
                       text => 'import',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $self->{t})
                if defined $mq; ## NOTE: Otherwise, already raised in MQ parser
            
            #
          } else {
            $self->{onerror}->(type => 'at-rule not allowed',
                       text => 'import',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $self->{t});
            
            #
          }
        } elsif ($at_rule_name eq 'media') {
          if ($self->{media_allowed}) {
            $self->{t} = $self->{tt}->get_next_token;
            $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
            
            my $q;
            ($self->{t}, $q) = $self->{mp}->_parse_mq_with_tokenizer ($self->{t}, $self->{tt});
            if ($q) {
              if ($self->{t}->{type} == LBRACE_TOKEN) {
                undef $self->{charset_allowed};
                undef $self->{namespace_allowed};
                undef $self->{import_allowed};
                undef $self->{media_allowed};
                my $rule_id = $self->{sheet_set}->{next_rule_id}++;
                my $v = $self->{sheet_set}->{rules}->[$rule_id]
                    = {type => '@media',
                       parent_style_sheet => $self->{current_sheet_id},
                       media => $q,
                       rules => []};
                push @{$self->{current_rules}}, $rule_id;
                push @{$self->{open_rules_list}},
                    $self->{current_rules} = $v->{rules};
                $self->{t} = $self->{tt}->get_next_token;
                ## Stay in the state.
                redo S;
              } else {
                $self->{onerror}->(type => 'at-rule syntax error',
                           text => 'media',
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $self->{t});
              }

              #
            }
            
            #
          } else { ## Nested @media rule
            $self->{onerror}->(type => 'at-rule not allowed',
                       text => 'media',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $self->{t});
            
            #
          }
        } elsif ($at_rule_name eq 'charset') {
          if ($self->{charset_allowed}) {
            $self->{t} = $self->{tt}->get_next_token;
            $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;

            if ($self->{t}->{type} == STRING_TOKEN) {
              my $encoding = $self->{t}->{value};
              
              $self->{t} = $self->{tt}->get_next_token;
              $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
            
              if ($self->{t}->{type} == SEMICOLON_TOKEN) {
                my $rule_id = $self->{sheet_set}->{next_rule_id}++;
                $self->{sheet_set}->{rules}->[$rule_id]
                    = {type => '@charset',
                       parent_style_sheet => $self->{current_sheet_id},
                       encoding => $encoding};
                push @{$self->{current_rules}}, $rule_id;
                undef $self->{charset_allowed};

                ## TODO: Detect the conformance errors for @charset...
              
                $self->{t} = $self->{tt}->get_next_token;
                ## Stay in the state.
                redo S;
              } else {
                #
              }
            } else {
              #
            }
            
            $self->{onerror}->(type => 'at-rule syntax error',
                       text => 'charset',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $self->{t});
            #
          } else {
            $self->{onerror}->(type => 'at-rule not allowed',
                       text => 'charset',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $self->{t});
            #
          }
        } else {
          $self->{onerror}->(type => 'unknown at-rule',
                     level => 'u',
                     uri => $self->context->urlref,
                     token => $self->{t},
                     value => $self->{t}->{value});
        }

        ## Reprocess.
        #$self->{t} = $self->{tt}->get_next_token;
        $self->{state} = IGNORED_STATEMENT_STATE;
        redo S;
      } elsif (@{$self->{open_rules_list} or []} > 1 and
               $self->{t}->{type} == RBRACE_TOKEN) {
        pop @{$self->{open_rules_list}};
        $self->{media_allowed} = 1;
        $self->{current_rules} = $self->{open_rules_list}->[-1];
        ## Stay in the state.
        $self->{t} = $self->{tt}->get_next_token;
        redo S;
      } elsif ($self->{t}->{type} == EOF_TOKEN) {
        if (@{$self->{open_rules_list} or []} > 1) {
          $self->{onerror}->(type => 'block not closed',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $self->{t});
        }

        last S;
      } else {
        undef $self->{charset_allowed};
        undef $self->{namespace_allowed};
        undef $self->{import_allowed};

        ($self->{t}, my $selectors) = $self->{sp}->_parse_selectors_with_tokenizer
            ($self->{tt}, LBRACE_TOKEN, $self->{t});

        $self->{t} = $self->{tt}->get_next_token
            while $self->{t}->{type} != LBRACE_TOKEN and $self->{t}->{type} != EOF_TOKEN;

        if ($self->{t}->{type} == LBRACE_TOKEN) {
          $self->{current_decls} = {props => {}, prop_names => []};
          if (defined $selectors) {
            my $rule_id = $self->{sheet_set}->{next_rule_id}++;
            $self->{sheet_set}->{rules}->[$rule_id]
                = {type => 'style',
                   parent_style_sheet => $self->{current_sheet_id},
                   # XXX parent_owner
                   selectors => $selectors,
                   style => $self->{current_decls}};
            push @{$self->{current_rules}}, $rule_id;
          }
          $self->{state} = BEFORE_DECLARATION_STATE;
          $self->{t} = $self->{tt}->get_next_token;
          redo S;
        } else {
          $self->{onerror}->(type => 'no declaration block',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $self->{t});

          ## Stay in the state.
          $self->{t} = $self->{tt}->get_next_token;
          redo S;
        }
      }
    } elsif ($self->{state} == BEFORE_DECLARATION_STATE) {
      ## NOTE: DELIM? in declaration will be removed:
      ## <http://csswg.inkedblade.net/spec/css2.1?s=declaration%20delim#issue-2>.

      my $prop_def;
      my $prop_value;
      my $prop_flag = '';
      $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
      if ($self->{t}->{type} == IDENT_TOKEN) { # property
        my $prop_name = lc $self->{t}->{value}; ## TODO: case folding
        my $prop_name_t = $self->{t};
        $self->{t} = $self->{tt}->get_next_token;
        $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
        if ($self->{t}->{type} == COLON_TOKEN) {
          $self->{t} = $self->{tt}->get_next_token;
          $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;

          $prop_def = $Web::CSS::Props::Prop->{$prop_name};
          if ($prop_def and $self->{prop}->{$prop_name}) {
            ($self->{t}, $prop_value)
                = $prop_def->{parse}->($self, $prop_name, $self->{tt}, $self->{t}, $self->{onerror});
            if ($prop_value) {
              ## NOTE: {parse} don't have to consume trailing spaces.
              $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;

              if ($self->{t}->{type} == EXCLAMATION_TOKEN) {
                $self->{t} = $self->{tt}->get_next_token;
                $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;
                if ($self->{t}->{type} == IDENT_TOKEN and
                    lc $self->{t}->{value} eq 'important') { ## TODO: case folding
                  $prop_flag = 'important';
                  
                  $self->{t} = $self->{tt}->get_next_token;
                  $self->{t} = $self->{tt}->get_next_token while $self->{t}->{type} == S_TOKEN;

                  #
                } else {
                  $self->{onerror}->(type => 'priority syntax error',
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $self->{t});
                  
                  ## Reprocess.
                  $self->{state} = IGNORED_DECLARATION_STATE;
                  redo S;
                }
              }

              #
            } else {
              ## Syntax error.
        
              ## Reprocess.
              $self->{state} = IGNORED_DECLARATION_STATE;
              redo S;
            }
          } else {
            $self->{onerror}->(type => 'unknown property',
                       level => 'u',
                       uri => $self->context->urlref,
                       token => $prop_name_t, value => $prop_name);

            #
            $self->{state} = IGNORED_DECLARATION_STATE;
            redo S;
          }
        } else {
          $self->{onerror}->(type => 'no property colon',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $self->{t});

          #
          $self->{state} = IGNORED_DECLARATION_STATE;
          redo S;
        }
      }

      if ($self->{t}->{type} == RBRACE_TOKEN) {
        $self->{t} = $self->{tt}->get_next_token;
        $self->{state} = BEFORE_STATEMENT_STATE;
        #redo S;
      } elsif ($self->{t}->{type} == SEMICOLON_TOKEN) {
        $self->{t} = $self->{tt}->get_next_token;
        ## Stay in the state.
        #redo S;
      } elsif ($self->{t}->{type} == EOF_TOKEN) {
        $self->{onerror}->(type => 'block not closed',
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $self->{t});
        ## Reprocess.
        $self->{state} = BEFORE_STATEMENT_STATE;
        #redo S;
      } else {
        if ($prop_value) {
          $self->{onerror}->(type => 'no property semicolon',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $self->{t});
        } else {
          $self->{onerror}->(type => 'no property name',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $self->{t});
        }

        #
        $self->{state} = IGNORED_DECLARATION_STATE;
        redo S;
      }

      my $important = ($prop_flag eq 'important');
      for my $set_prop_name (keys %{$prop_value or {}}) {
        my $set_prop_def = $Web::CSS::Props::Prop->{$set_prop_name};
        if ($important or
            not $self->{current_decls}->{props}->{$set_prop_def->{key}} or
            $self->{current_decls}->{props}->{$set_prop_def->{key}}->[1] ne 'important') {
          $self->{current_decls}->{props}->{$set_prop_def->{key}}
              = [$prop_value->{$set_prop_name}, $prop_flag];
          push @{$self->{current_decls}->{prop_names}}, $set_prop_def->{key};
        }
      }
      redo S;
    } elsif ($self->{state} == IGNORED_STATEMENT_STATE or
             $self->{state} == IGNORED_DECLARATION_STATE) {
      if (@{$self->{closing_tokens}}) { ## Something is yet in opening state.
        if ($self->{t}->{type} == EOF_TOKEN) {
          @{$self->{closing_tokens}} = ();
          ## Reprocess.
          $self->{state} = $self->{state} == IGNORED_STATEMENT_STATE
              ? BEFORE_STATEMENT_STATE : BEFORE_DECLARATION_STATE;
          redo S;
        } elsif ($self->{t}->{type} == $self->{closing_tokens}->[-1]) {
          pop @{$self->{closing_tokens}};
          if (@{$self->{closing_tokens}} == 0 and
              $self->{t}->{type} == RBRACE_TOKEN and
              $self->{state} == IGNORED_STATEMENT_STATE) {
            $self->{t} = $self->{tt}->get_next_token;
            $self->{state} = BEFORE_STATEMENT_STATE;
            redo S;
          } else {
            $self->{t} = $self->{tt}->get_next_token;
            ## Stay in the state.
            redo S;
          }
        } elsif ({
          RBRACE_TOKEN, 1,
          #RBRACKET_TOKEN, 1,
          #RPAREN_TOKEN, 1,
          SEMICOLON_TOKEN, 1,
        }->{$self->{t}->{type}}) {
          $self->{t} = $self->{tt}->get_next_token;
          ## Stay in the state.
          #
        } else {
          #
        }
      } else {
        if ($self->{t}->{type} == SEMICOLON_TOKEN) {
          $self->{t} = $self->{tt}->get_next_token;
          $self->{state} = $self->{state} == IGNORED_STATEMENT_STATE
              ? BEFORE_STATEMENT_STATE : BEFORE_DECLARATION_STATE;
          redo S;
        } elsif ($self->{t}->{type} == RBRACE_TOKEN) {
          if ($self->{state} == IGNORED_DECLARATION_STATE) {
            $self->{t} = $self->{tt}->get_next_token;
            $self->{state} = BEFORE_STATEMENT_STATE;
            redo S;
          } else {
            ## NOTE: Maybe this state cannot be reached.
            $self->{t} = $self->{tt}->get_next_token;
            ## Stay in the state.
            redo S;
          }
        } elsif ($self->{t}->{type} == EOF_TOKEN) {
          ## Reprocess.
          $self->{state} = $self->{state} == IGNORED_STATEMENT_STATE
              ? BEFORE_STATEMENT_STATE : BEFORE_DECLARATION_STATE;
          redo S;
        #} elsif ($self->{t}->{type} == RBRACKET_TOKEN or $self->{t}->{type} == RPAREN_TOKEN) {
        #  $self->{t} = $self->{tt}->get_next_token;
        #  ## Stay in the state.
        #  #
        } else {
          #
        }
      }

      while (not {
        EOF_TOKEN, 1,
        RBRACE_TOKEN, 1,
        ## NOTE: ']' and ')' are disabled for browser compatibility.
        #RBRACKET_TOKEN, 1,
        #RPAREN_TOKEN, 1,
        SEMICOLON_TOKEN, 1,
      }->{$self->{t}->{type}}) {
        if ($self->{t}->{type} == LBRACE_TOKEN) {
          push @{$self->{closing_tokens}}, RBRACE_TOKEN;
        #} elsif ($self->{t}->{type} == LBRACKET_TOKEN) {
        #  push @{$self->{closing_tokens}}, RBRACKET_TOKEN;
        #} elsif ($self->{t}->{type} == LPAREN_TOKEN or $self->{t}->{type} == FUNCTION_TOKEN) {
        #  push @{$self->{closing_tokens}}, RPAREN_TOKEN;
        }

        $self->{t} = $self->{tt}->get_next_token;
      }

      #
      ## Stay in the state.
      redo S;
    } else {
      die "$0: parse_char_string: Unknown state: $self->{state}";
    }
  } # S
} # _parse

sub parsed_sheet_set ($) {
  return $_[0]->{sheet_set};
} # parsed_sheet_set

sub parsed_style_decls ($) {
  return $_[0]->{style_decls};
} # parsed_style_decls

## TODO: Test <style>'s base URI change and url()

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
