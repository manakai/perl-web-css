package Web::CSS::Parser;
use strict;
use warnings;
our $VERSION = '14.0';
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
          if (defined $self->{has_charset} and not $self->{has_charset}) {
            $self->onerror->(type => 'css:charset:token error', # XXX
                             level => 'w',
                             uri => $self->context->urlref,
                             line => $construct->{line},
                             column => $construct->{column});
          }
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

## XXX Encoding Standard support

## <http://dvcs.w3.org/hg/encoding/raw-file/tip/Overview.html#encodings>

# $ curl http://dvcs.w3.org/hg/encoding/raw-file/tip/encodings.json | perl -MJSON::XS -MData::Dumper -e 'local $/ = undef; $json = JSON::XS->new->decode(<>); $Data::Dumper::Sortkeys = 1; print Dumper {map { my $name = $_->{name}; map { $_ => $name } @{$_->{labels}} } map { @{$_->{encodings}} } @$json}'
my $CharsetMap = {
          '866' => 'ibm866',
          'ansi_x3.4-1968' => 'windows-1252',
          'arabic' => 'iso-8859-6',
          'ascii' => 'windows-1252',
          'asmo-708' => 'iso-8859-6',
          'big5' => 'big5',
          'big5-hkscs' => 'big5',
          'chinese' => 'gbk',
          'cn-big5' => 'big5',
          'cp1250' => 'windows-1250',
          'cp1251' => 'windows-1251',
          'cp1252' => 'windows-1252',
          'cp1253' => 'windows-1253',
          'cp1254' => 'windows-1254',
          'cp1255' => 'windows-1255',
          'cp1256' => 'windows-1256',
          'cp1257' => 'windows-1257',
          'cp1258' => 'windows-1258',
          'cp819' => 'windows-1252',
          'cp864' => 'ibm864',
          'cp866' => 'ibm866',
          'csbig5' => 'big5',
          'cseuckr' => 'euc-kr',
          'cseucpkdfmtjapanese' => 'euc-jp',
          'csgb2312' => 'gbk',
          'csibm864' => 'ibm864',
          'csibm866' => 'ibm866',
          'csiso2022jp' => 'iso-2022-jp',
          'csiso2022kr' => 'iso-2022-kr',
          'csiso58gb231280' => 'gbk',
          'csiso88596e' => 'iso-8859-6',
          'csiso88596i' => 'iso-8859-6',
          'csiso88598e' => 'iso-8859-8',
          'csiso88598i' => 'iso-8859-8',
          'csisolatin1' => 'windows-1252',
          'csisolatin2' => 'iso-8859-2',
          'csisolatin3' => 'iso-8859-3',
          'csisolatin4' => 'iso-8859-4',
          'csisolatin5' => 'windows-1254',
          'csisolatin6' => 'iso-8859-10',
          'csisolatin9' => 'iso-8859-15',
          'csisolatinarabic' => 'iso-8859-6',
          'csisolatincyrillic' => 'iso-8859-5',
          'csisolatingreek' => 'iso-8859-7',
          'csisolatinhebrew' => 'iso-8859-8',
          'cskoi8r' => 'koi8-r',
          'csksc56011987' => 'euc-kr',
          'csmacintosh' => 'macintosh',
          'csshiftjis' => 'shift_jis',
          'cyrillic' => 'iso-8859-5',
          'dos-874' => 'windows-874',
          'ecma-114' => 'iso-8859-6',
          'ecma-118' => 'iso-8859-7',
          'elot_928' => 'iso-8859-7',
          'euc-jp' => 'euc-jp',
          'euc-kr' => 'euc-kr',
          'gb18030' => 'gb18030',
          'gb2312' => 'gbk',
          'gb_2312' => 'gbk',
          'gb_2312-80' => 'gbk',
          'gbk' => 'gbk',
          'greek' => 'iso-8859-7',
          'greek8' => 'iso-8859-7',
          'hebrew' => 'iso-8859-8',
          'hz-gb-2312' => 'hz-gb-2312',
          'ibm-864' => 'ibm864',
          'ibm819' => 'windows-1252',
          'ibm864' => 'ibm864',
          'ibm866' => 'ibm866',
          'iso-2022-jp' => 'iso-2022-jp',
          'iso-2022-kr' => 'iso-2022-kr',
          'iso-8859-1' => 'windows-1252',
          'iso-8859-10' => 'iso-8859-10',
          'iso-8859-11' => 'windows-874',
          'iso-8859-13' => 'iso-8859-13',
          'iso-8859-14' => 'iso-8859-14',
          'iso-8859-15' => 'iso-8859-15',
          'iso-8859-16' => 'iso-8859-16',
          'iso-8859-2' => 'iso-8859-2',
          'iso-8859-3' => 'iso-8859-3',
          'iso-8859-4' => 'iso-8859-4',
          'iso-8859-5' => 'iso-8859-5',
          'iso-8859-6' => 'iso-8859-6',
          'iso-8859-6-e' => 'iso-8859-6',
          'iso-8859-6-i' => 'iso-8859-6',
          'iso-8859-7' => 'iso-8859-7',
          'iso-8859-8' => 'iso-8859-8',
          'iso-8859-8-e' => 'iso-8859-8',
          'iso-8859-8-i' => 'iso-8859-8',
          'iso-8859-9' => 'windows-1254',
          'iso-ir-100' => 'windows-1252',
          'iso-ir-101' => 'iso-8859-2',
          'iso-ir-109' => 'iso-8859-3',
          'iso-ir-110' => 'iso-8859-4',
          'iso-ir-126' => 'iso-8859-7',
          'iso-ir-127' => 'iso-8859-6',
          'iso-ir-138' => 'iso-8859-8',
          'iso-ir-144' => 'iso-8859-5',
          'iso-ir-148' => 'windows-1254',
          'iso-ir-149' => 'euc-kr',
          'iso-ir-157' => 'iso-8859-10',
          'iso-ir-58' => 'gbk',
          'iso8859-1' => 'windows-1252',
          'iso8859-10' => 'iso-8859-10',
          'iso8859-11' => 'windows-874',
          'iso8859-13' => 'iso-8859-13',
          'iso8859-14' => 'iso-8859-14',
          'iso8859-15' => 'iso-8859-15',
          'iso8859-2' => 'iso-8859-2',
          'iso8859-3' => 'iso-8859-3',
          'iso8859-4' => 'iso-8859-4',
          'iso8859-5' => 'iso-8859-5',
          'iso8859-6' => 'iso-8859-6',
          'iso8859-7' => 'iso-8859-7',
          'iso8859-8' => 'iso-8859-8',
          'iso8859-9' => 'windows-1254',
          'iso88591' => 'windows-1252',
          'iso885910' => 'iso-8859-10',
          'iso885911' => 'windows-874',
          'iso885913' => 'iso-8859-13',
          'iso885914' => 'iso-8859-14',
          'iso885915' => 'iso-8859-15',
          'iso88592' => 'iso-8859-2',
          'iso88593' => 'iso-8859-3',
          'iso88594' => 'iso-8859-4',
          'iso88595' => 'iso-8859-5',
          'iso88596' => 'iso-8859-6',
          'iso88597' => 'iso-8859-7',
          'iso88598' => 'iso-8859-8',
          'iso88599' => 'windows-1254',
          'iso_8859-1' => 'windows-1252',
          'iso_8859-15' => 'iso-8859-15',
          'iso_8859-1:1987' => 'windows-1252',
          'iso_8859-2' => 'iso-8859-2',
          'iso_8859-2:1987' => 'iso-8859-2',
          'iso_8859-3' => 'iso-8859-3',
          'iso_8859-3:1988' => 'iso-8859-3',
          'iso_8859-4' => 'iso-8859-4',
          'iso_8859-4:1988' => 'iso-8859-4',
          'iso_8859-5' => 'iso-8859-5',
          'iso_8859-5:1988' => 'iso-8859-5',
          'iso_8859-6' => 'iso-8859-6',
          'iso_8859-6:1987' => 'iso-8859-6',
          'iso_8859-7' => 'iso-8859-7',
          'iso_8859-7:1987' => 'iso-8859-7',
          'iso_8859-8' => 'iso-8859-8',
          'iso_8859-8:1988' => 'iso-8859-8',
          'iso_8859-9' => 'windows-1254',
          'iso_8859-9:1989' => 'windows-1254',
          'koi' => 'koi8-r',
          'koi8' => 'koi8-r',
          'koi8-r' => 'koi8-r',
          'koi8-u' => 'koi8-u',
          'koi8_r' => 'koi8-r',
          'korean' => 'euc-kr',
          'ks_c_5601-1987' => 'euc-kr',
          'ks_c_5601-1989' => 'euc-kr',
          'ksc5601' => 'euc-kr',
          'ksc_5601' => 'euc-kr',
          'l1' => 'windows-1252',
          'l2' => 'iso-8859-2',
          'l3' => 'iso-8859-3',
          'l4' => 'iso-8859-4',
          'l5' => 'windows-1254',
          'l6' => 'iso-8859-10',
          'l9' => 'iso-8859-15',
          'latin1' => 'windows-1252',
          'latin2' => 'iso-8859-2',
          'latin3' => 'iso-8859-3',
          'latin4' => 'iso-8859-4',
          'latin5' => 'windows-1254',
          'latin6' => 'iso-8859-10',
          'logical' => 'iso-8859-8',
          'mac' => 'macintosh',
          'macintosh' => 'macintosh',
          'ms_kanji' => 'shift_jis',
          'shift-jis' => 'shift_jis',
          'shift_jis' => 'shift_jis',
          'sjis' => 'shift_jis',
          'sun_eu_greek' => 'iso-8859-7',
          'tis-620' => 'windows-874',
          'unicode-1-1-utf-8' => 'utf-8',
          'us-ascii' => 'windows-1252',
          'utf-16' => 'utf-16',
          'utf-16be' => 'utf-16be',
          'utf-16le' => 'utf-16',
          'utf-8' => 'utf-8',
          'utf8' => 'utf-8',
          'visual' => 'iso-8859-8',
          'windows-1250' => 'windows-1250',
          'windows-1251' => 'windows-1251',
          'windows-1252' => 'windows-1252',
          'windows-1253' => 'windows-1253',
          'windows-1254' => 'windows-1254',
          'windows-1255' => 'windows-1255',
          'windows-1256' => 'windows-1256',
          'windows-1257' => 'windows-1257',
          'windows-1258' => 'windows-1258',
          'windows-31j' => 'shift_jis',
          'windows-874' => 'windows-874',
          'windows-949' => 'euc-kr',
          'x-cp1250' => 'windows-1250',
          'x-cp1251' => 'windows-1251',
          'x-cp1252' => 'windows-1252',
          'x-cp1253' => 'windows-1253',
          'x-cp1254' => 'windows-1254',
          'x-cp1255' => 'windows-1255',
          'x-cp1256' => 'windows-1256',
          'x-cp1257' => 'windows-1257',
          'x-cp1258' => 'windows-1258',
          'x-euc-jp' => 'euc-jp',
          'x-gbk' => 'gbk',
          'x-mac-cyrillic' => 'x-mac-cyrillic',
          'x-mac-roman' => 'macintosh',
          'x-mac-ukrainian' => 'x-mac-cyrillic',
          'x-sjis' => 'shift_jis',
          'x-x-big5' => 'big5'
}; # $CharsetMap

# XXX
sub _get_encoding_name ($) {
  my $input = shift || '';
  $input =~ s/\A[\x09\x0A\x0C\x0D\x20]+//;
  $input =~ s/[\x09\x0A\x0C\x0D\x20]+\z//;
  $input =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  return $CharsetMap->{$input}; # or undef
} # _get_encoding_name

# XXX
sub _decode ($$) {
  require Encode;
  return Encode::decode $_[0], $_[1];
} # _decode

sub parse_byte_string_as_ss ($$;%) {
  my ($self, undef, %args) = @_;

  ## Determine the fallback encoding
  ## <http://dev.w3.org/csswg/css-syntax/#input-byte-stream>.
  my $encoding;
  my $has_charset;
  {
    ## 1.
    if (defined $args{transport_encoding_name}) {
      $encoding = _get_encoding_name $args{transport_encoding_name};
      if (defined $encoding) {
        $has_charset = $_[1] =~ /\A\x40\x63\x68\x61\x72\x73\x65\x74\x20\x22([^\x22]*)\x22\x3B/;
        if ($has_charset and $1 =~ /\\/) {
          $self->onerror->(type => 'css:charset:token error', # XXX
                           level => 'w',
                           uri => $self->context->urlref,
                           line => 1,
                           column => 1);
        }
        last;
      }
    }

    ## 2.
    if ($_[1] =~ /\A\x40\x63\x68\x61\x72\x73\x65\x74\x20\x22([^\x22]*)\x22\x3B/) {
      $encoding = $1;
      if ($encoding =~ /\\/) {
        $self->onerror->(type => 'css:charset:token error', # XXX
                         level => 'w',
                         uri => $self->context->urlref,
                         line => 1,
                         column => 1);
      }
      $encoding = _get_encoding_name $encoding;
      $has_charset = 1;
      if (defined $encoding) {
        $encoding = 'utf-8' if $encoding eq 'utf-16' or $encoding eq 'utf-16be';
        last;
      }
    }

    ## 3.-4.
    if (defined $args{parent_encoding_name}) {
      $encoding = _get_encoding_name $args{parent_encoding_name};
      last if defined $encoding;
    }

    ## 5.
    $encoding = 'utf-8';
  } # Determine the encoding

  local $self->{has_charset} = $has_charset ? 1 : 0;
  my $parsed = $self->parse_char_string_as_ss (_decode $encoding, $_[1]);
  $parsed->{input_encoding} = $encoding;
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

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
