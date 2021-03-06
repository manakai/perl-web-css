package Web::CSS::Parser;
use strict;
use warnings;
our $VERSION = '15.0';
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
  delete $self->{current};
  delete $self->{in_multiple_error};
} # init_parser

## Parsed style sheet data structure
##
##   input_encoding - The encoding name used to decode the input byte stream
##   rules
##     0            - The "style sheet" struct
##     n > 0        - Rules in the style sheet

## Style sheet struct
##
##   id          - Internal ID of the style sheet
##   rule_type   - "sheet"
##   rule_ids    - The arrayref of the IDs of the rules in the style sheet

## Style rule struct
##
##   id          - Internal ID of the rule
##   rule_type   - "style"
##   parent_id   - The internal ID of the parent rule
##   selectors   - Selectors struct
##   prop_keys, prop_values, prop_importants - Properties struct

## @charset struct
##
##   id          - Internal ID of the at-rule
##   rule_type   - "charset"
##   parent_id   - The internal ID of the parent rule
##   encoding    - The encoding of the at-rule

## @import struct
##
##   id          - Internal ID of the at-rule
##   rule_type   - "import"
##   parent_id   - The internal ID of the parent rule
##   href        - The URL of the imported style sheet
##   mqs         - List of media queries construct

## @namespace struct
##
##   id          - Internal ID of the at-rule
##   rule_type   - "namespace"
##   parent_id   - The internal ID of the parent rule
##   prefix      - The namespace prefix, if any, or |undef|
##   nsurl       - The namespace URL, possibly empty.

## @media struct
##
##   id          - Internal ID of the at-rule
##   rule_type   - "media"
##   parent_id   - The internal ID of the parent rule
##   mqs         - List of media queries construct
##   rule_ids    - The arrayref of the IDs of the rules in the @media at-rule

## Property struct
##
##   prop_keys   - The arrayref of the property keys
##   prop_values - The hashref of the property key / value struct pairs
##   prop_importants - The hashref of the property key / 'important' pairs

my $KnownAtRules = {charset => 1, import => 1, media => 1, namespace => 1};

sub start_construct ($;%) {
  my ($self, %args) = @_;
  $self->{start_construct_count}++;

  ## <http://dev.w3.org/csswg/css-syntax/#css-stylesheets>
  my $construct = $self->{constructs}->[-1];
  if ($construct->{type} == QUALIFIED_RULE_CONSTRUCT) {
    push @{$self->{current} ||= []},
        {rule_type => 'style',
         prop_keys => [],
         prop_values => {},
         prop_importants => {}};
  } elsif ($construct->{type} == AT_RULE_CONSTRUCT) {
    push @{$self->{current} ||= []},
        {rule_type => 'at',
         name => $construct->{name}->{value}};
  } elsif ($construct->{type} == BLOCK_CONSTRUCT) {
    if ($args{parent}) {
      $construct->{_has_entry} = 1;
      if ($self->{current}->[-1]->{rule_type} eq 'style') {
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
            $self->{current}->[-2]->{rule_type} eq 'style') {
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
            $construct->{mqs} = $self->parse_constructs_as_mq_list ($tokens);
            $construct->{rule_type} = 'media';
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
    my $rule = {rule_type => 'sheet', rule_ids => [], id => 0};
    $self->{parsed}->{rules}->[0] = $rule;
    push @{$self->{current} ||= []}, $rule;
  }
} # start_construct

sub end_construct ($;%) {
  my ($self, %args) = @_;

  my $construct = $self->{constructs}->[-1];
  if ($construct->{type} == DECLARATION_CONSTRUCT and not $args{error}) {
    my $tokens = $construct->{value};
    my $important;
    my $l_t;
    $l_t = pop @$tokens while @$tokens and $tokens->[-1]->{type} == S_TOKEN;
    if (@$tokens and $tokens->[-1]->{type} == IDENT_TOKEN and
        $tokens->[-1]->{value} =~ /\A[Ii][Mm][Pp][Oo][Rr][Tt][Aa][Nn][Tt]\z/) { ## 'important', ASCII case-insensitive.
      ## <http://dev.w3.org/csswg/css-syntax/#consume-a-declaration>
      ## <http://dev.w3.org/csswg/css-syntax/#declaration-rule-list>
      ## <http://dev.w3.org/csswg/css-cascade/#importance>
      my @t = pop @$tokens; # 'important'
      unshift @t, pop @$tokens
          while @$tokens and $tokens->[-1]->{type} == S_TOKEN;
      if (@$tokens and $tokens->[-1]->{type} == EXCLAMATION_TOKEN) {
        $l_t = pop @$tokens; # '!'
        $l_t = pop @$tokens while @$tokens and $tokens->[-1]->{type} == S_TOKEN;
        $important = 1;
      } else {
        push @$tokens, @t;
      }
    }
    push @$tokens,
        {type => EOF_TOKEN,
         line => defined $l_t ? $l_t->{line} : $construct->{end_line},
         column => defined $l_t ? $l_t->{column} : $construct->{end_column}};
    my $parsed = $self->parse_constructs_as_prop_value
        ($construct->{name}->{value}, $tokens);
    if (defined $parsed) {
      my $decl = $self->{current}->[-1];
      for my $key (@{$parsed->{prop_keys}}) {
        if ($important or not $decl->{prop_importants}->{$key}) {
          if ($decl->{prop_values}->{$key}) {
            # XXX duplicate warning
            @{$decl->{prop_keys}} = grep { $_ ne $key } @{$decl->{prop_keys}};
          }
          push @{$decl->{prop_keys}}, $key;
          $decl->{prop_values}->{$key} = $parsed->{prop_values}->{$key};
          if ($important) {
            $decl->{prop_importants}->{$key} = 1;
          } else {
            delete $decl->{prop_importants}->{$key};
          }
        } else {
          $self->onerror->(type => 'css:prop:ignored', # XXX
                           level => 'w',
                           value => $Web::CSS::Props::Key->{$key}->{css},
                           uri => $self->context->urlref,
                           token => $construct);
        }
      }
    } else {
      $self->onerror->(type => 'css:prop:unknown', # XXX
                       level => 'm',
                       value => $construct->{name}->{value},
                       uri => $self->context->urlref,
                       line => $construct->{line},
                       column => $construct->{column});
    }
  } elsif ($construct->{type} == BLOCK_CONSTRUCT) {
    if ($construct->{_has_entry}) {
      pop @{$self->{current}};
    }
  } elsif ($construct->{type} == AT_RULE_CONSTRUCT) {
    ## At-rule without block
    my $at_name = $construct->{name}->{value};
    $at_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($at_name eq 'namespace') {
      ## <http://dev.w3.org/csswg/css-namespaces/#declaration>.
      if (not @{$self->{current}} == 2 or
          grep {
            my $t = $self->{parsed}->{rules}->[$_]->{rule_type};
            $t ne 'namespace' and $t ne 'import' and $t ne 'charset';
          } @{$self->{current}->[-2]->{rule_ids}}) {
        $self->onerror->(type => 'at-rule not allowed',
                         text => 'namespace',
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
        my $rule = {rule_type => 'namespace'};
        my $context = $self->context;
        if ($t->{type} == IDENT_TOKEN) {
          $rule->{prefix} = $t->{value};
          if (defined $context->{prefix_to_url}->{$rule->{prefix}}) {
            $self->onerror->(type => 'duplicate @namespace',
                             value => $rule->{prefix},
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
            @{$context->{url_to_prefixes}->{$context->{prefix_to_url}->{$rule->{prefix}}}}
                = grep { $_ ne $rule->{prefix} } @{$context->{url_to_prefixes}->{$context->{prefix_to_url}->{$rule->{prefix}}}};
          }
          $t = shift @$tokens;
          $t = shift @$tokens while $t->{type} == S_TOKEN;
        } else {
          if (defined $context->{prefix_to_url}->{''}) {
            $self->onerror->(type => 'duplicate @namespace',
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
          }
        }
        if ($t->{type} == STRING_TOKEN or $t->{type} == URI_TOKEN) {
          $rule->{nsurl} = $t->{value};
          $t = shift @$tokens;
          $t = shift @$tokens while $t->{type} == S_TOKEN;
          if ($t->{type} == EOF_TOKEN) {
            $context->{prefix_to_url}->{defined $rule->{prefix} ? $rule->{prefix} : ''} = $rule->{nsurl};
            push @{$context->{url_to_prefixes}->{$rule->{nsurl}} ||= []},
                $rule->{prefix} if defined $rule->{prefix};
            my $rule_id = @{$self->{parsed}->{rules}};
            $self->{parsed}->{rules}->[$rule_id] = $rule;
            $rule->{id} = $rule_id;
            $rule->{parent_id} = $self->{current}->[-2]->{id};
            push @{$self->{current}->[-2]->{rule_ids}}, $rule_id;
          } else {
            $self->onerror->(type => 'css:namespace:broken', # XXX
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
          }
        } else {
          $self->onerror->(type => 'css:namespace:url missing', # XXX
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
        }
      }
    } elsif ($at_name eq 'import') {
      ## <http://dev.w3.org/csswg/css-cascade/#at-import>.
      if (not @{$self->{current}} == 2 or
          grep {
            my $t = $self->{parsed}->{rules}->[$_]->{rule_type};
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
          my $rule = {rule_type => 'import', href => $t->{value}};
          $t = shift @$tokens;
          $t = shift @$tokens while $t->{type} == S_TOKEN;
          unless ($t->{type} == EOF_TOKEN) {
            unshift @$tokens, $t;
            $rule->{mqs} = $self->parse_constructs_as_mq_list ($tokens);
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
          my $rule = {rule_type => 'charset',
                      encoding => $tokens->[0]->{value}};
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
    $self->{in_multiple_error} = $construct->{in_multiple_error};
    pop @{$self->{current}};
  }
} # end_construct

sub parse_byte_string_as_ss ($$;%) {
  my ($self, undef, %args) = @_;

  require Web::Encoding::Sniffer;
  my $sniffer = Web::Encoding::Sniffer->new_from_context ('css');
  $sniffer->detect (
    substr ($_[1], 0, 1024),
    transport => $args{transport_encoding_name},
    reference => $args{parent_encoding_name},
    embed => $args{embed_encoding_key},
  );

  # XXX report encoding errors and warnings for validator

  require Web::Encoding;
  my $parsed = $self->parse_char_string_as_ss
      (Web::Encoding::decode_web_charset ($sniffer->encoding, $_[1]));
  $parsed->{input_encoding} = $sniffer->encoding;
  return $parsed;
} # parse_byte_string_as_ss

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

  $self->{parsed} = {rules => []};

  $self->start_building_rules or do {
    1 while not $self->continue_building_rules;
  };

  @{$self->{current}} == 0 or die "|current| stack is not empty";

  return delete $self->{parsed};
} # parse_char_string_as_ss

sub parse_char_string_as_rule ($$) {
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

  $self->{parsed} = {rules => []};

  $self->start_building_rules (1) or do {
    1 while not $self->continue_building_rules;
  };

  @{$self->{current}} == 0 or die "|current| stack is not empty";

  if (delete $self->{in_multiple_error}) {
    $#{$self->{parsed}->{rules}} = 0;
    $self->{parsed}->{rules}->[0]->{rule_ids} = [];
  }

  ## $returned->{rules}->[1] is the parsed rule.
  return delete $self->{parsed};
} # parse_char_string_as_rule

sub parse_char_string_as_prop_decls ($$) {
  my $self = $_[0];

  ## <http://dev.w3.org/csswg/css-syntax/#parse-a-list-of-declarations0>.

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

  $self->{current} = [{prop_keys => [], prop_values => {},
                       prop_importants => {}}];

  $self->start_building_decls or do {
    1 while not $self->continue_building_decls;
  };

  @{$self->{current}} == 1 or die "|current| stack is broken";

  return pop @{$self->{current}};
} # parse_constructs_as_prop_decls

sub parse_char_string_as_prop_value ($$$) {
  my $self = $_[0];

  {
    $self->{line_prev} = $self->{line} = 1;
    $self->{column_prev} = -1;
    $self->{column} = 0;

    $self->{chars} = [split //, $_[2]];
    $self->{chars_pos} = 0;
    delete $self->{chars_was_cr};
    $self->{chars_pull_next} = sub { 0 };
    $self->init_tokenizer;
    $self->init_builder;
  }

  $self->start_building_values or do {
    1 while not $self->continue_building_values;
  };

  my $tokens = $self->{parsed_construct}->{value};
  push @$tokens, $self->get_next_token; # EOF_TOKEN

  return $self->parse_constructs_as_prop_value ($_[1], $tokens); # or undef
} # parse_char_string_as_prop_value

sub parse_constructs_as_prop_value ($$$) {
  my ($self, $prop_name, $tokens) = @_;
  $prop_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.

  # XXX custom properties

  my $def = $Web::CSS::Props::Prop->{$prop_name} or return undef;
  $self->media_resolver->{prop}->{$def->{css}} or return undef;

  if ($def->{css} ne $prop_name) {
    $self->onerror->(type => 'css:obsolete', text => $prop_name, # XXX
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $tokens->[0]);
  }

  my $value;
  shift @$tokens while $tokens->[0]->{type} == S_TOKEN;
  splice @$tokens, -2, 1, ()
      while @$tokens > 1 and $tokens->[-2]->{type} == S_TOKEN;
  if (@$tokens == 2 and
      $tokens->[0]->{type} == IDENT_TOKEN and
      $tokens->[0]->{value} =~ /\A([Ii][Nn][Hh][Ee][Rr][Ii][Tt]|(?:-[Mm][Oo][Zz]-)?[Ii][Nn][Ii][Tt][Ii][Aa][Ll]|[Uu][Nn][Ss][Ee][Tt])\z/ and
      $tokens->[1]->{type} == EOF_TOKEN) {
    ## CSS-wide keywords
    ## <http://dev.w3.org/csswg/css-values/#common-keywords>,
    ## <http://dev.w3.org/csswg/css-cascade/#defaulting-keywords>.
    ## See also |Web::CSS::Values|.
    $value = $1;
    $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($value eq '-moz-initial') {
      $self->onerror->(type => 'css:obsolete', text => $value, # XXX
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $tokens->[0]);
      $value = 'initial';
    }
    $value = ['KEYWORD', $value];
    if ($def->{is_shorthand}) {
      my $result = {prop_keys => $def->{longhand_subprops}};
      for (@{$def->{longhand_subprops}}) {
        $result->{prop_values}->{$_} = $value;
      }
      return $result;

      # XXX toggle()
    } else {
      return {prop_keys => [$def->{key}],
              prop_values => {$def->{key} => $value}};
    }
  } else {
    if ($def->{is_shorthand}) {
      my $values = $def->{parse_shorthand}->($self, $def, $tokens);
      if (defined $values) {
        return {prop_keys => $def->{longhand_subprops},
                prop_values => $values};
      } else {
        return {prop_keys => [], prop_values => {}};
      }
    } else {
      $value = $def->{parse_longhand}->($self, $tokens);
      if (defined $value) {
        return {prop_keys => [$def->{key}],
                prop_values => {$def->{key} => $value}};
      } else {
        return {prop_keys => [], prop_values => {}};
      }
    }
  }
} # parse_constructs_as_prop_value

# XXX at risk
sub parse_style_element ($$) {
  my ($self, $style) = @_;

  ## $style MUST be the |Web::DOM::Element| object representing an
  ## HTML |style| element.

  # XXX SVG |style| element

  ## This method does not check for the |type| attribute, nor does
  ## examine the current |sheet| attrbute value.  Additionally, the
  ## |media| attribute and the |title| attribute do not affect this
  ## method's processing.

  $self->context (undef);
  my $context = $self->context;
  $context->url ($style->owner_document->url);
  $context->base_url ($style->base_uri);
  $context->manakai_compat_mode ($style->owner_document->manakai_compat_mode);

  my $parsed = $self->parse_char_string_as_ss
      (join '', map { $_->data } grep { $_->node_type == $_->TEXT_NODE } @{$style->child_nodes});
  
  my $old_id = $$style->[2]->{sheet};
  if (defined $old_id) {
    $$style->[0]->disconnect ($old_id);
    delete $$style->[0]->{data}->[$old_id]->{owner};
  }

  my $new_id = $$style->[0]->import_parsed_ss ($parsed);
  $$style->[2]->{sheet} = $new_id;
  $$style->[0]->connect ($new_id => $$style->[1]);
  my $ss_data = $$style->[0]->{data}->[$new_id];
  #$ss_data->{href};
  $ss_data->{context} = $context;
  $context->url (undef);
  $ss_data->{owner} = $$style->[1];
  #$ss_data->{parent_style_sheet};
  $ss_data->{title} = $style->get_attribute ('title');
  #$ss_data->{disabled};
  #XXX origin

  my $mq = $style->get_attribute ('media');
  $style->sheet->media ($mq) if defined $mq;

  $self->context (undef);
} # process_style_element

sub get_parser_of_document ($$) {
  my $node = $_[1];
  return $$node->[0]->css_parser;
} # get_parser_of_document

1;

=head1 LICENSE

Copyright 2007-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
