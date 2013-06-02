package Web::CSS::Parser;
use strict;
use warnings;
our $VERSION = '3.0';
use Web::CSS::Tokenizer;
use Web::CSS::Props;
use Web::CSS::Selectors::Parser;
use Web::CSS::MediaQueries::Parser;

sub new ($) {
  my $self = bless {
    level => {
      must => 'm',
      should => 's',
      warning => 'w',
      uncertain => 'u',
    },
  }, shift;

  #$self->{parsed}
  #$self->{current_sheet_id}

  return $self;
} # new

sub BEFORE_STATEMENT_STATE () { 0 }
sub BEFORE_DECLARATION_STATE () { 1 }
sub IGNORED_STATEMENT_STATE () { 2 }
sub IGNORED_DECLARATION_STATE () { 3 }

sub init ($) {
  my $self = shift;
  delete $self->{onerror};
  delete $self->{parsed};
  delete $self->{media_resolver};
  delete $self->{context};
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

# XXX sync with new css-syntax definition

# XXX stream mode

# XXX parse_byte_string

sub parse_char_string ($$;%) {
  my ($self, undef, %args) = @_;

  my $s = $_[1];
  pos ($s) = 0;
  my $line = 1;
  my $column = 0;

  my $tt = Web::CSS::Tokenizer->new;
  my $onerror = $self->onerror;
  $tt->init;
  $tt->context ($self->context);
  $tt->onerror ($onerror);
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
  $tt->init_tokenizer;

  my $sp = Web::CSS::Selectors::Parser->new;
  $sp->{pseudo_element} = $self->{pseudo_element};
  $sp->{pseudo_class} = $self->{pseudo_class};
  $sp->context ($self->context);
  $sp->onerror ($onerror);

  my $mp = Web::CSS::MediaQueries::Parser->new;
  $mp->context ($self->context);
  $mp->onerror ($onerror);

  my $state = BEFORE_STATEMENT_STATE;
  my $t = $tt->get_next_token;

  my $open_rules = [[]];
  my $current_rules = $open_rules->[-1];
  my $current_decls;
  my $closing_tokens = [];
  my $charset_allowed = 1;
  my $namespace_allowed = 1;
  my $import_allowed = 1;
  my $media_allowed = 1;

  ## Parsed style sheet set structure
  ##
  ##   next_sheet_id - The index for the next style sheet structure
  ##   sheets        - The arrayref of style sheet structures
  ##   next_rule_id  - The index for the next rule structure
  ##   rules         - The arrayref of rule structures
  $self->{parsed} ||= {next_sheet_id => 0,
                       sheets => [],
                       next_rule_id => 0,
                       rules => []};

  $self->{current_sheet_id} = $self->{parsed}->{next_sheet_id}++;
  ## Style sheet structures
  ##
  ##   rules       - The arrayref of indexes of rules contained by the sheet
  ##   base_urlref - The scalarref of the base URL for the style sheet
  $self->{parsed}->{sheets}->[$self->{current_sheet_id}] = {
    rules => $open_rules->[0],
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

  S: {
    if ($state == BEFORE_STATEMENT_STATE) {
      $t = $tt->get_next_token
          while $t->{type} == S_TOKEN or
              $t->{type} == CDO_TOKEN or
              $t->{type} == CDC_TOKEN;

      if ($t->{type} == ATKEYWORD_TOKEN) {
        my $t_at = $t;
        my $at_rule_name = lc $t->{value}; ## TODO: case
        if ($at_rule_name eq 'namespace') { # @namespace
          $t = $tt->get_next_token;
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;

          my $prefix;
          if ($t->{type} == IDENT_TOKEN) {
            $prefix = $t->{value};
            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          }

          if ($t->{type} == STRING_TOKEN or $t->{type} == URI_TOKEN) {
            my $uri = $t->{value};
            
            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;

            if ($t->{type} == SEMICOLON_TOKEN) {
              if ($namespace_allowed) {
                my $p = $prefix;
                if (defined $prefix) {
                  if (defined $self->context->get_url_by_prefix ($prefix)) {
                    $onerror->(type => 'duplicate @namespace',
                               value => $prefix,
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t_at);
                  }
                  $self->context->{prefix_to_url}->{$prefix} = $uri;
                  $p .= '|';
                } else {
                  if (defined $self->context->get_url_by_prefix ('')) {
                    $onerror->(type => 'duplicate @namespace',
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
                my $rule_id = $self->{parsed}->{next_rule_id}++;
                $self->{parsed}->{rules}->[$rule_id]
                    = {type => '@namespace',
                       parent_style_sheet => $self->{current_sheet_id},
                       prefix => \$prefix, # XXX ref reuse
                       namespace_uri => \$uri}; # XXX ref reuse
                push @$current_rules, $rule_id;
                undef $charset_allowed;
                undef $import_allowed;
              } else {
                $onerror->(type => 'at-rule not allowed',
                           text => 'namespace',
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
              }
              
              $t = $tt->get_next_token;
              ## Stay in the state.
              redo S;
            } else {
              #
            }
          } else {
            #
          }

          $onerror->(type => 'at-rule syntax error',
                     text => 'namespace',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          #
        } elsif ($at_rule_name eq 'import') {
          if ($import_allowed) {
            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
            my $mq = [];
            if ($t->{type} == STRING_TOKEN or $t->{type} == URI_TOKEN) {
              my $uri = $t->{value};
              $t = $tt->get_next_token;
              $t = $tt->get_next_token while $t->{type} == S_TOKEN;
              if ($t->{type} == IDENT_TOKEN or 
                  $t->{type} == DIMENSION_TOKEN or
                  $t->{type} == NUMBER_TOKEN or
                  $t->{type} == LPAREN_TOKEN) {
                ($t, $mq) = $mp->_parse_mq_with_tokenizer ($t, $tt);
                $t = $tt->get_next_token while $t->{type} == S_TOKEN;
              }
              if ($mq and $t->{type} == SEMICOLON_TOKEN) {
                ## TODO: error or warning
                ## TODO: White space definition
                $uri =~ s/^[\x09\x0A\x0D\x20]+//;
                $uri =~ s/[\x09\x0A\x0D\x20]+\z//;

                my $sheet_id = $self->{parsed}->{next_sheet_id}++;
                $self->{parsed}->{sheets}->[$sheet_id] = {
                  rules => [],
                  parent_style_sheet => $self->{current_sheet_id},
                };

                my $rule_id = $self->{parsed}->{next_rule_id}++;
                $self->{parsed}->{rules}->[$rule_id]
                    = {type => '@import',
                       parent_style_sheet => $self->{current_sheet_id},
                       style_sheet => $sheet_id,
                       href => $uri,
                       media => $mq};
                push @$current_rules, $rule_id;
                undef $charset_allowed;

                $t = $tt->get_next_token;
                ## Stay in the state.
                redo S;
              }
            }

            $onerror->(type => 'at-rule syntax error',
                       text => 'import',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t)
                if defined $mq; ## NOTE: Otherwise, already raised in MQ parser
            
            #
          } else {
            $onerror->(type => 'at-rule not allowed',
                       text => 'import',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            
            #
          }
        } elsif ($at_rule_name eq 'media') {
          if ($media_allowed) {
            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
            
            my $q;
            ($t, $q) = $mp->_parse_mq_with_tokenizer ($t, $tt);
            if ($q) {
              if ($t->{type} == LBRACE_TOKEN) {
                undef $charset_allowed;
                undef $namespace_allowed;
                undef $import_allowed;
                undef $media_allowed;
                my $rule_id = $self->{parsed}->{next_rule_id}++;
                my $v = $self->{parsed}->{rules}->[$rule_id]
                    = {type => '@media',
                       parent_style_sheet => $self->{current_sheet_id},
                       media => $q,
                       rules => []};
                push @$current_rules, $rule_id;
                push @$open_rules, $current_rules = $v->{rules};
                $t = $tt->get_next_token;
                ## Stay in the state.
                redo S;
              } else {
                $onerror->(type => 'at-rule syntax error',
                           text => 'media',
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
              }

              #
            }
            
            #
          } else { ## Nested @media rule
            $onerror->(type => 'at-rule not allowed',
                       text => 'media',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            
            #
          }
        } elsif ($at_rule_name eq 'charset') {
          if ($charset_allowed) {
            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;

            if ($t->{type} == STRING_TOKEN) {
              my $encoding = $t->{value};
              
              $t = $tt->get_next_token;
              $t = $tt->get_next_token while $t->{type} == S_TOKEN;
            
              if ($t->{type} == SEMICOLON_TOKEN) {
                my $rule_id = $self->{parsed}->{next_rule_id}++;
                $self->{parsed}->{rules}->[$rule_id]
                    = {type => '@charset',
                       parent_style_sheet => $self->{current_sheet_id},
                       encoding => $encoding};
                push @$current_rules, $rule_id;
                undef $charset_allowed;

                ## TODO: Detect the conformance errors for @charset...
              
                $t = $tt->get_next_token;
                ## Stay in the state.
                redo S;
              } else {
                #
              }
            } else {
              #
            }
            
            $onerror->(type => 'at-rule syntax error',
                       text => 'charset',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            #
          } else {
            $onerror->(type => 'at-rule not allowed',
                       text => 'charset',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            #
          }
        } else {
          $onerror->(type => 'unknown at-rule',
                     level => 'u',
                     uri => $self->context->urlref,
                     token => $t,
                     value => $t->{value});
        }

        ## Reprocess.
        #$t = $tt->get_next_token;
        $state = IGNORED_STATEMENT_STATE;
        redo S;
      } elsif (@$open_rules > 1 and $t->{type} == RBRACE_TOKEN) {
        pop @$open_rules;
        $media_allowed = 1;
        $current_rules = $open_rules->[-1];
        ## Stay in the state.
        $t = $tt->get_next_token;
        redo S;
      } elsif ($t->{type} == EOF_TOKEN) {
        if (@$open_rules > 1) {
          $onerror->(type => 'block not closed',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
        }

        last S;
      } else {
        undef $charset_allowed;
        undef $namespace_allowed;
        undef $import_allowed;

        ($t, my $selectors) = $sp->_parse_selectors_with_tokenizer
            ($tt, LBRACE_TOKEN, $t);

        $t = $tt->get_next_token
            while $t->{type} != LBRACE_TOKEN and $t->{type} != EOF_TOKEN;

        if ($t->{type} == LBRACE_TOKEN) {
          $current_decls = {props => {}, prop_names => []};
          if (defined $selectors) {
            my $rule_id = $self->{parsed}->{next_rule_id}++;
            $self->{parsed}->{rules}->[$rule_id]
                = {type => 'style',
                   parent_style_sheet => $self->{current_sheet_id},
                   # XXX parent_owner
                   selectors => $selectors,
                   style => $current_decls};
            push @{$current_rules}, $rule_id;
          }
          $state = BEFORE_DECLARATION_STATE;
          $t = $tt->get_next_token;
          redo S;
        } else {
          $onerror->(type => 'no declaration block',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);

          ## Stay in the state.
          $t = $tt->get_next_token;
          redo S;
        }
      }
    } elsif ($state == BEFORE_DECLARATION_STATE) {
      ## NOTE: DELIM? in declaration will be removed:
      ## <http://csswg.inkedblade.net/spec/css2.1?s=declaration%20delim#issue-2>.

      my $prop_def;
      my $prop_value;
      my $prop_flag = '';
      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      if ($t->{type} == IDENT_TOKEN) { # property
        my $prop_name = lc $t->{value}; ## TODO: case folding
        my $prop_name_t = $t;
        $t = $tt->get_next_token;
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == COLON_TOKEN) {
          $t = $tt->get_next_token;
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;

          $prop_def = $Web::CSS::Props::Prop->{$prop_name};
          if ($prop_def and $self->{prop}->{$prop_name}) {
            ($t, $prop_value)
                = $prop_def->{parse}->($self, $prop_name, $tt, $t, $onerror);
            if ($prop_value) {
              ## NOTE: {parse} don't have to consume trailing spaces.
              $t = $tt->get_next_token while $t->{type} == S_TOKEN;

              if ($t->{type} == EXCLAMATION_TOKEN) {
                $t = $tt->get_next_token;
                $t = $tt->get_next_token while $t->{type} == S_TOKEN;
                if ($t->{type} == IDENT_TOKEN and
                    lc $t->{value} eq 'important') { ## TODO: case folding
                  $prop_flag = 'important';
                  
                  $t = $tt->get_next_token;
                  $t = $tt->get_next_token while $t->{type} == S_TOKEN;

                  #
                } else {
                  $onerror->(type => 'priority syntax error',
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
                  
                  ## Reprocess.
                  $state = IGNORED_DECLARATION_STATE;
                  redo S;
                }
              }

              #
            } else {
              ## Syntax error.
        
              ## Reprocess.
              $state = IGNORED_DECLARATION_STATE;
              redo S;
            }
          } else {
            $onerror->(type => 'unknown property',
                       level => 'u',
                       uri => $self->context->urlref,
                       token => $prop_name_t, value => $prop_name);

            #
            $state = IGNORED_DECLARATION_STATE;
            redo S;
          }
        } else {
          $onerror->(type => 'no property colon',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);

          #
          $state = IGNORED_DECLARATION_STATE;
          redo S;
        }
      }

      if ($t->{type} == RBRACE_TOKEN) {
        $t = $tt->get_next_token;
        $state = BEFORE_STATEMENT_STATE;
        #redo S;
      } elsif ($t->{type} == SEMICOLON_TOKEN) {
        $t = $tt->get_next_token;
        ## Stay in the state.
        #redo S;
      } elsif ($t->{type} == EOF_TOKEN) {
        $onerror->(type => 'block not closed',
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        ## Reprocess.
        $state = BEFORE_STATEMENT_STATE;
        #redo S;
      } else {
        if ($prop_value) {
          $onerror->(type => 'no property semicolon',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
        } else {
          $onerror->(type => 'no property name',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
        }

        #
        $state = IGNORED_DECLARATION_STATE;
        redo S;
      }

      my $important = ($prop_flag eq 'important');
      for my $set_prop_name (keys %{$prop_value or {}}) {
        my $set_prop_def = $Web::CSS::Props::Prop->{$set_prop_name};
        if ($important or
            not $current_decls->{props}->{$set_prop_def->{key}} or
            $current_decls->{props}->{$set_prop_def->{key}}->[1] ne 'important') {
          $current_decls->{props}->{$set_prop_def->{key}}
              = [$prop_value->{$set_prop_name}, $prop_flag];
          push @{$current_decls->{prop_names}}, $set_prop_def->{key};
        }
      }
      redo S;
    } elsif ($state == IGNORED_STATEMENT_STATE or
             $state == IGNORED_DECLARATION_STATE) {
      if (@$closing_tokens) { ## Something is yet in opening state.
        if ($t->{type} == EOF_TOKEN) {
          @$closing_tokens = ();
          ## Reprocess.
          $state = $state == IGNORED_STATEMENT_STATE
              ? BEFORE_STATEMENT_STATE : BEFORE_DECLARATION_STATE;
          redo S;
        } elsif ($t->{type} == $closing_tokens->[-1]) {
          pop @$closing_tokens;
          if (@$closing_tokens == 0 and
              $t->{type} == RBRACE_TOKEN and
              $state == IGNORED_STATEMENT_STATE) {
            $t = $tt->get_next_token;
            $state = BEFORE_STATEMENT_STATE;
            redo S;
          } else {
            $t = $tt->get_next_token;
            ## Stay in the state.
            redo S;
          }
        } elsif ({
          RBRACE_TOKEN, 1,
          #RBRACKET_TOKEN, 1,
          #RPAREN_TOKEN, 1,
          SEMICOLON_TOKEN, 1,
        }->{$t->{type}}) {
          $t = $tt->get_next_token;
          ## Stay in the state.
          #
        } else {
          #
        }
      } else {
        if ($t->{type} == SEMICOLON_TOKEN) {
          $t = $tt->get_next_token;
          $state = $state == IGNORED_STATEMENT_STATE
              ? BEFORE_STATEMENT_STATE : BEFORE_DECLARATION_STATE;
          redo S;
        } elsif ($t->{type} == RBRACE_TOKEN) {
          if ($state == IGNORED_DECLARATION_STATE) {
            $t = $tt->get_next_token;
            $state = BEFORE_STATEMENT_STATE;
            redo S;
          } else {
            ## NOTE: Maybe this state cannot be reached.
            $t = $tt->get_next_token;
            ## Stay in the state.
            redo S;
          }
        } elsif ($t->{type} == EOF_TOKEN) {
          ## Reprocess.
          $state = $state == IGNORED_STATEMENT_STATE
              ? BEFORE_STATEMENT_STATE : BEFORE_DECLARATION_STATE;
          redo S;
        #} elsif ($t->{type} == RBRACKET_TOKEN or $t->{type} == RPAREN_TOKEN) {
        #  $t = $tt->get_next_token;
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
      }->{$t->{type}}) {
        if ($t->{type} == LBRACE_TOKEN) {
          push @$closing_tokens, RBRACE_TOKEN;
        #} elsif ($t->{type} == LBRACKET_TOKEN) {
        #  push @$closing_tokens, RBRACKET_TOKEN;
        #} elsif ($t->{type} == LPAREN_TOKEN or $t->{type} == FUNCTION_TOKEN) {
        #  push @$closing_tokens, RPAREN_TOKEN;
        }

        $t = $tt->get_next_token;
      }

      #
      ## Stay in the state.
      redo S;
    } else {
      die "$0: parse_char_string: Unknown state: $state";
    }
  } # S
} # parse_char_string

sub parsed ($) {
  return $_[0]->{parsed};
} # parsed

## TODO: Test <style>'s base URI change and url()

# XXX integrate with parse_char_string
sub parse_char_string_as_inline ($$) {
  my $self = $_[0];

  my $s = $_[1];
  pos ($s) = 0;
  my $line = 1;
  my $column = 0;
  
  my $tt = Web::CSS::Tokenizer->new;
  my $onerror = $tt->{onerror} = $self->{onerror};
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
      $_[0]->{line} = $line;
      $_[0]->{column} = $column;
      return $c;
    } else {
      $_[0]->{column} = $column + 1; ## Set the same number always.
      return -1;
    }
  }; # $tt->{get_char}
  $tt->init;

  $self->{lookup_namespace_uri} = sub { ## TODO: case
    return undef; ## TODO: get from an external source
  }; # $sp->{lookup_namespace_uri}

  $self->{base_uri} = $self->{href} unless defined $self->{base_uri};

  my $state = BEFORE_DECLARATION_STATE;
  my $t = $tt->get_next_token;

  my $current_decls = {};
  my $closing_tokens = [];

  # XXX base_url

  S: {
    if ($state == BEFORE_DECLARATION_STATE) {
      ## NOTE: DELIM? in declaration will be removed:
      ## <http://csswg.inkedblade.net/spec/css2.1?s=declaration%20delim#issue-2>.

      my $prop_def;
      my $prop_value;
      my $prop_flag = '';
      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      if ($t->{type} == IDENT_TOKEN) { # property
        my $prop_name = lc $t->{value}; ## TODO: case folding
        my $prop_name_t = $t;
        $t = $tt->get_next_token;
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == COLON_TOKEN) {
          $t = $tt->get_next_token;
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;

          $prop_def = $Web::CSS::Props::Prop->{$prop_name};
          if ($prop_def and $self->{prop}->{$prop_name}) {
            ($t, $prop_value)
                = $prop_def->{parse}->($self, $prop_name, $tt, $t, $onerror);
            if ($prop_value) {
              ## NOTE: {parse} don't have to consume trailing spaces.
              $t = $tt->get_next_token while $t->{type} == S_TOKEN;

              if ($t->{type} == EXCLAMATION_TOKEN) {
                $t = $tt->get_next_token;
                $t = $tt->get_next_token while $t->{type} == S_TOKEN;
                if ($t->{type} == IDENT_TOKEN and
                    lc $t->{value} eq 'important') { ## TODO: case folding
                  $prop_flag = 'important';
                  
                  $t = $tt->get_next_token;
                  $t = $tt->get_next_token while $t->{type} == S_TOKEN;

                  #
                } else {
                  $onerror->(type => 'priority syntax error',
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
                  
                  ## Reprocess.
                  $state = IGNORED_DECLARATION_STATE;
                  redo S;
                }
              }

              #
            } else {
              ## Syntax error.
        
              ## Reprocess.
              $state = IGNORED_DECLARATION_STATE;
              redo S;
            }
          } else {
            $onerror->(type => 'unknown property',
                       level => 'u',
                       uri => $self->context->urlref,
                       token => $prop_name_t, value => $prop_name);

            #
            $state = IGNORED_DECLARATION_STATE;
            redo S;
          }
        } else {
          $onerror->(type => 'no property colon',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);

          #
          $state = IGNORED_DECLARATION_STATE;
          redo S;
        }
      }

      ## NOTE: Unlike the main parser, |RBRACE_TOKEN| does not close
      ## the block here.
      if ($t->{type} == SEMICOLON_TOKEN) {
        $t = $tt->get_next_token;
        ## Stay in the state.
        #redo S;
      } elsif ($t->{type} == EOF_TOKEN) {
        ## NOTE: Unlike the main parser, no error is raised here and
        ## exits the parser.
        #last S;
      } else {
        if ($prop_value) {
          $onerror->(type => 'no property semicolon',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
        } else {
          $onerror->(type => 'no property name',
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
        }

        ## Reprocess.
        $state = IGNORED_DECLARATION_STATE;
        redo S;
      }

      my $important = ($prop_flag eq 'important');
      for my $set_prop_name (keys %{$prop_value or {}}) {
        my $set_prop_def = $Web::CSS::Props::Prop->{$set_prop_name};
        $$current_decls->{$set_prop_def->{key}}
            = [$prop_value->{$set_prop_name}, $prop_flag]
            if $important or
                not $$current_decls->{$set_prop_def->{key}} or
                $$current_decls->{$set_prop_def->{key}}->[1] ne 'important';
      }
      last S if $t->{type} == EOF_TOKEN; # "color: red{EOF}" (w/ or w/o ";")
      redo S;
    } elsif ($state == IGNORED_DECLARATION_STATE) {
      ## NOTE: Difference from the main parser is that support for the
      ## |IGNORED_STATEMENT_STATE| cases is removed.
      if (@$closing_tokens) { ## Something is yet in opening state.
        if ($t->{type} == EOF_TOKEN) {
          @$closing_tokens = ();
          ## Reprocess.
          $state = BEFORE_DECLARATION_STATE;
          redo S;
        } elsif ($t->{type} == $closing_tokens->[-1]) {
          pop @$closing_tokens;
          $t = $tt->get_next_token;
          ## Stay in the state.
          redo S;
        } elsif ({
          RBRACE_TOKEN, 1,
          #RBRACKET_TOKEN, 1,
          #RPAREN_TOKEN, 1,
          SEMICOLON_TOKEN, 1,
        }->{$t->{type}}) {
          $t = $tt->get_next_token;
          ## Stay in the state.
          #
        } else {
          #
        }
      } else {
        ## NOTE: Unlike the main parser, |RBRACE_TOKEN| does not close
        ## the block here.
        if ($t->{type} == SEMICOLON_TOKEN) {
          $t = $tt->get_next_token;
          $state = BEFORE_DECLARATION_STATE;
          redo S;
        } elsif ($t->{type} == EOF_TOKEN) {
          ## Reprocess.
          $state = $state == IGNORED_STATEMENT_STATE
              ? BEFORE_STATEMENT_STATE : BEFORE_DECLARATION_STATE;
          redo S;
        #} elsif ($t->{type} == RBRACKET_TOKEN or $t->{type} == RPAREN_TOKEN) {
        #  $t = $tt->get_next_token;
        #  ## Stay in the state.
        #  #
        } else {
          #
        }
      }

      while (not {
        EOF_TOKEN, 1,
        #RBRACE_TOKEN, 1, ## NOTE: Difference from the main parser.
        ## NOTE: ']' and ')' are disabled for browser compatibility.
        #RBRACKET_TOKEN, 1,
        #RPAREN_TOKEN, 1,
        SEMICOLON_TOKEN, 1,
      }->{$t->{type}}) {
        if ($t->{type} == LBRACE_TOKEN) {
          push @$closing_tokens, RBRACE_TOKEN;
        #} elsif ($t->{type} == LBRACKET_TOKEN) {
        #  push @$closing_tokens, RBRACKET_TOKEN;
        #} elsif ($t->{type} == LPAREN_TOKEN or $t->{type} == FUNCTION_TOKEN) {
        #  push @$closing_tokens, RPAREN_TOKEN;
        }

        $t = $tt->get_next_token;
      }

      ## Reprocess.
      ## Stay in the state.
      redo S;
    } else {
      die "$0: parse_char_string: Unknown state: $state";
    }
  } # S

  ## TODO: CSSStyleDeclaration attributes ...

  return $current_decls;
} # parse_char_string_as_inline

## TODO: We need test script for the method above.

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
