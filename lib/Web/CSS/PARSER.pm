package Web::CSS::Parser;
use strict;
use warnings;
our $VERSION = '6.0';
use Web::CSS::Builder;
use Web::CSS::Selectors::Parser;
use Web::CSS::MediaQueries::Parser;
push our @ISA, qw(Web::CSS::Selectors::Parser::_
                  Web::CSS::MediaQueries::Parser::_
                  Web::CSS::Builder);
use Web::CSS::Props;

sub init_parser ($) {
  my $self = $_[0];
  delete $self->{start_construct_count};
} # init_parser

sub parse_char_string_as_ss ($$) {
  my $self = $_[0];

  {
    $self->{line_prev} = $self->{line} = 1;
    $self->{column_prev} = -1;
    $self->{column} = 0;

    $self->{chars} = [split //, $_[1]];
    $self->{chars_pos} = 0;
    delete $self->{chars_was_cr};
    $self->{chars_pull_next} = sub { 0 };
    $self->init_tokenizer;
    $self->init_builder;
  }

  $self->{parsed} = {rules => [],
                     base_urlref => $self->context->base_urlref};
  ## rules
  ##   0         - The "style sheet" struct
  ##   n > 0     - Rules in the style sheet
  ## base_urlref - The scalarref to the base URL of the style sheet

  $self->start_building_rules or do {
    1 while not $self->continue_building_rules;
  };

  @{$self->{current}} == 0 or die "|current| stack is not empty";

  return delete $self->{parsed};
} # parse_char_string_as_ss

## Style sheet struct
##
##   id          - 0
##   type        - "sheet"
##   rule_ids    - The arrayref of the IDs of the rules in the style sheet

## Style rule struct
##
##   id          - Internal ID of the rule
##   type        - "style"
##   parent_id   - The internal ID of the parent rule
##   selectors   - Selectors struct
##   prop_keys   - The arrayref of the property keys
##   prop_values - The hashref of the property key / value struct pairs
##   prop_importants - The hashref of the property key / 'important' pairs

## @charset struct
##
##   id          - Internal ID of the at-rule
##   type        - "charset"
##   parent_id   - The internal ID of the parent rule
##   encoding    - The encoding of the at-rule

## @media struct
##
##   id          - Internal ID of the at-rule
##   type        - "media"
##   parent_id   - The internal ID of the parent rule
##   mqs         - List of media queries construct
##   rule_ids    - The arrayref of the IDs of the rules in the @media at-rule

my $KnownAtRules = {charset => 1, import => 1, media => 1};

sub start_construct ($;%) {
  my ($self, %args) = @_;
  $self->{start_construct_count}++;

  ## <http://dev.w3.org/csswg/css-syntax/#css-stylesheets>
  my $construct = $self->{constructs}->[-1];
  if ($construct->{type} == QUALIFIED_RULE_CONSTRUCT) {
    push @{$self->{current} ||= []},
        {type => 'style',
         prop_keys => [],
         prop_values => {},
         prop_importants => {}};
  } elsif ($construct->{type} == AT_RULE_CONSTRUCT) {
    push @{$self->{current} ||= []},
        {type => 'at',
         name => $construct->{name}->{value}};
  } elsif ($construct->{type} == BLOCK_CONSTRUCT) {
    if ($args{parent}) {
      $construct->{_has_entry} = 1;
      if ($self->{current}->[-1]->{type} eq 'style') {
        ## <http://dev.w3.org/csswg/css-syntax/#style-rules>
        my $tokens = $args{parent}->{value};
        $tokens->[-1] = {type => EOF_TOKEN,
                         line => $tokens->[-1]->{line},
                         column => $tokens->[-1]->{column}};

        my $sels = $self->parse_constructs_as_selectors ($tokens);
        if (defined $sels) {
          my $rule_id = @{$self->{parsed}->{rules}};
          $self->{parsed}->{rules}->[$rule_id] = $self->{current}->[-1];
          $self->{current}->[-1]->{id} = $rule_id;
          $self->{current}->[-1]->{parent_id} = $self->{current}->[-2]->{id};
          push @{$self->{current}->[-2]->{rule_ids}}, $rule_id;
          $self->{current}->[-1]->{selectors} = $sels;
        }
        ## Otherwise, an error has been reported within the Selectors
        ## parser and the style rule should be ignored.
      } else { # at
        my $at_name = $self->{current}->[-1]->{name};
        $at_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if (@{$self->{current}} > 1 and
            $self->{current}->[-2]->{type} eq 'style') {
          $self->onerror->(type => 'css:style:at-rule', # XXX
                           level => 'm',
                           value => $at_name,
                           uri => $self->context->urlref,
                           line => $args{parent}->{line},
                           column => $args{parent}->{column});
        } else {
          if ($at_name eq 'media') {
            ## <http://dev.w3.org/csswg/css-conditional/#at-media>.
            my $tokens = $args{parent}->{value};
            $tokens->[-1] = {type => EOF_TOKEN,
                             line => $tokens->[-1]->{line},
                             column => $tokens->[-1]->{column}};

            my $construct = $self->{current}->[-1];
            $construct->{mqs} = $self->parse_constructs_as_mqs ($tokens);
            $construct->{type} = 'media';
            $construct->{rule_ids} = [];
            delete $construct->{name};
            my $rule_id = @{$self->{parsed}->{rules}};
            $self->{parsed}->{rules}->[$rule_id] = $construct;
            $construct->{id} = $rule_id;
            $construct->{parent_id} = $self->{current}->[-2]->{id};
            push @{$self->{current}->[-2]->{rule_ids}}, $rule_id;
          } elsif ($KnownAtRules->{$at_name}) {
            $self->onerror->(type => 'css:at-rule:block not allowed', # XXX
                             level => 'm',
                             value => $at_name,
                             uri => $self->context->urlref,
                             line => $construct->{line},
                             column => $construct->{column});
          } else {
            $self->onerror->(type => 'unknown at-rule',
                             level => 'm',
                             value => $at_name,
                             uri => $self->context->urlref,
                             line => $args{parent}->{line},
                             column => $args{parent}->{column});
          }
        }
      }
    }
  } elsif ($construct->{type} == RULE_LIST_CONSTRUCT) {
    my $rule = {type => 'sheet', rule_ids => [], id => 0};
    $self->{parsed}->{rules}->[0] = $rule;
    push @{$self->{current} ||= []}, $rule;
  }
} # start_construct

sub end_construct ($;%) {
  my ($self, %args) = @_;

  my $construct = $self->{constructs}->[-1];
  if ($construct->{type} == DECLARATION_CONSTRUCT and not $args{error}) {
    my $prop_name = $construct->{name}->{value};
    $prop_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    # XXX custom properties
    my $def = $Web::CSS::Props::Prop->{$prop_name};
    if ($def) {
      my $tokens = $construct->{value};
      my $important;
      shift @$tokens while @$tokens and $tokens->[0]->{type} == S_TOKEN;
      pop @$tokens while @$tokens and $tokens->[-1]->{type} == S_TOKEN;
      if (@$tokens and $tokens->[-1]->{type} == IDENT_TOKEN and
          $tokens->[-1]->{value} =~ /\A[Ii][Mm][Pp][Oo][Rr][Tt][Aa][Nn][Tt]\z/) { ## 'important', ASCII case-insensitive.
        ## <http://dev.w3.org/csswg/css-syntax/#consume-a-declaration>
        ## <http://dev.w3.org/csswg/css-syntax/#declaration-rule-list>
        my @t = pop @$tokens; # 'important'
        unshift @t, pop @$tokens
            while @$tokens and $tokens->[-1]->{type} == S_TOKEN;
        if (@$tokens and $tokens->[-1]->{type} == EXCLAMATION_TOKEN) {
          pop @$tokens; # '!'
          pop @$tokens while @$tokens and $tokens->[-1]->{type} == S_TOKEN;
          $important = 1;
        } else {
          push @$tokens, @t;
        }
      }
      my $value;
      if (@$tokens == 1 and $tokens->[0]->{type} == IDENT_TOKEN and
          $tokens->[0]->{value} =~ /\A([Ii][Nn][Hh][Ee][Rr][Ii][Tt]|(?:-[Mm][Oo][Zz]-)?[Ii][Nn][Ii][Tt][Ii][Aa][Ll])\z/) {
        $value = ['KEYWORD', {inherit => 'inherit',
                              initial => 'initial',
                              '-moz-initial' => 'initial'}->{lc $1}];
      } else {
        push @$tokens, {type => EOF_TOKEN,
                        line => $tokens->[-1]->{line},
                        column => $tokens->[-1]->{column}};
        $value = $def->{parse}->($self, $tokens);
      }
      # XXX duplicate
      if (defined $value) {
        my $decl = $self->{current}->[-1];
        push @{$decl->{prop_keys}}, $def->{key};
        $decl->{prop_values}->{$def->{key}} = $value;
        if ($important) {
          $decl->{prop_importants}->{$def->{key}} = 1;
        } else {
          delete $decl->{prop_importants}->{$def->{key}};
        }
      }
    } else {
      $self->onerror->(type => 'css:prop:unknown', # XXX
                       level => 'm',
                       value => $prop_name,
                       uri => $self->context->urlref,
                       line => $construct->{name}->{line},
                       column => $construct->{name}->{column});
    }
  } elsif ($construct->{type} == BLOCK_CONSTRUCT) {
    if ($construct->{_has_entry}) {
      pop @{$self->{current}};
    }
  } elsif ($construct->{type} == AT_RULE_CONSTRUCT) {
    ## At-rule without block
    my $at_name = $construct->{name}->{value};
    $at_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($at_name eq 'import') {
      ## <http://dev.w3.org/csswg/css-cascade/#at-import>.
      if (not @{$self->{current}} == 2 or
          grep {
            my $t = $self->{parsed}->{rules}->[$_]->{type};
            $t ne 'import' and $t ne 'charset';
          } @{$self->{current}->[-2]->{rule_ids}}) {
        $self->onerror->(type => 'at-rule not allowed',
                         text => 'import',
                         level => 'm',
                         uri => $self->context->urlref,
                         line => $construct->{line},
                         column => $construct->{column});
      } else {
        my $tokens = $construct->{value};
        push @$tokens, {type => EOF_TOKEN,
                        line => $construct->{end_line},
                        column => $construct->{end_column}};
        my $t = shift @$tokens;
        $t = shift @$tokens while $t->{type} == S_TOKEN;
        if ($t->{type} == URI_TOKEN or $t->{type} == STRING_TOKEN) {
          my $rule = {type => 'import', href => $t->{value}};
          $t = shift @$tokens;
          $t = shift @$tokens while $t->{type} == S_TOKEN;
          unless ($t->{type} == EOF_TOKEN) {
            unshift @$tokens, $t;
            $rule->{mqs} = $self->parse_constructs_as_mqs ($tokens);
          } else {
            $rule->{mqs} = [];
          }
          
          my $rule_id = @{$self->{parsed}->{rules}};
          $self->{parsed}->{rules}->[$rule_id] = $rule;
          $rule->{id} = $rule_id;
          $rule->{parent_id} = $self->{current}->[-2]->{id};
          push @{$self->{current}->[-2]->{rule_ids}}, $rule_id;
        } else {
          $self->onerror->(type => 'css:import:url missing', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
        }
      }
    } elsif ($at_name eq 'charset') {
      ## <http://dev.w3.org/csswg/css-syntax/#the-charset-rule>.
      if ($self->{start_construct_count} != 2) {
        $self->onerror->(type => 'at-rule not allowed',
                         text => 'charset',
                         level => 'm',
                         uri => $self->context->urlref,
                         line => $construct->{line},
                         column => $construct->{column});
      } else {
        my $tokens = $construct->{value};
        shift @$tokens while @$tokens and $tokens->[0]->{type} == S_TOKEN;
        pop @$tokens while @$tokens and $tokens->[-1]->{type} == S_TOKEN;
        if (@$tokens == 1 and $tokens->[0]->{type} == STRING_TOKEN) {
          my $rule = {type => 'charset', encoding => $tokens->[0]->{value}};
          my $rule_id = @{$self->{parsed}->{rules}};
          $self->{parsed}->{rules}->[$rule_id] = $rule;
          $rule->{id} = $rule_id;
          $rule->{parent_id} = $self->{current}->[-2]->{id};
          push @{$self->{current}->[-2]->{rule_ids}}, $rule_id;
        } elsif (@$tokens) {
          $self->onerror->(type => 'css:value:not string', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           line => $tokens->[0]->{line},
                           column => $tokens->[0]->{column});
        } else {
          $self->onerror->(type => 'css:value:not string', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           line => $construct->{end_line},
                           column => $construct->{end_column});
        }
      }
    } elsif ($KnownAtRules->{$at_name}) {
      $self->onerror->(type => 'css:at-rule:block missing', # XXX
                       value => $at_name,
                       level => 'm',
                       uri => $self->context->urlref,
                       line => $construct->{end_line},
                       column => $construct->{end_column});
    } else {
      $self->onerror->(type => 'unknown at-rule',
                       value => $at_name,
                       level => 'm',
                       uri => $self->context->urlref,
                       line => $construct->{name}->{line},
                       column => $construct->{name}->{column});
    }
    pop @{$self->{current}};
  } elsif ($construct->{type} == QUALIFIED_RULE_CONSTRUCT) {
    ## Selectors without following block
    pop @{$self->{current}};
  } elsif ($construct->{type} == RULE_LIST_CONSTRUCT) {
    pop @{$self->{current}};
  }
} # end_construct


1;
