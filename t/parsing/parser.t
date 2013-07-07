use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Test::HTCT::Parser;
use Web::CSS::Parser;
use Web::DOM::Document;
use Web::CSS::Serializer;
use Web::CSS::Selectors::Serializer;
use Web::CSS::MediaQueries::Serializer;

my $DefaultComputed;
my $DefaultComputedText;

sub apply_diff ($$$);

my $data_d = file (__FILE__)->dir->parent->parent
    ->subdir ('t_deps', 'tests', 'css', 'parsing', 'manakai');

{
  my $all_test = {document => {}, test => []};
  for (map { $data_d->file ($_)->stringify } qw[
    css-1.dat
    css-media.dat
    css-namespace.dat
    css-import.dat
    css-visual.dat
    css-generated.dat
    css-paged.dat
    css-text.dat
    css-font.dat
    css-table.dat
    css-interactive.dat
  ]) {
    for_each_test $_, {
      data => {is_prefixed => 1},
      errors => {is_list => 1},
      cssom => {is_prefixed => 1},
      csstext => {is_prefixed => 1},
      computed => {is_prefixed => 1},
      computedtext => {is_prefixed => 1},
      html => {is_prefixed => 1},
      xml => {is_prefixed => 1},
    }, sub {
      my $data = shift;
      
      if ($data->{data}) {
        my $test = {
          data => $data->{data}->[0],
          csstext => $data->{csstext}->[0],
          cssom => $data->{cssom}->[0],
          errors => $data->{errors}->[0],
        };
        for (qw(cssom csstext)) {
          $test->{$_} .= "\n" if defined $test->{$_} and length $test->{$_};
        }
        for my $key (qw(computed computedtext)) {
          if ($data->{$key}) {
            my $id = $data->{$key}->[1]->[0];
            my $sel = join ' ', @{$data->{$key}->[1]}[1..$#{$data->{$key}->[1]}];
            $test->{$key}->{$id}->{$sel} = $data->{$key}->[0];
          }
        }
        if ($data->{option} and $data->{option}->[1]->[0] eq 'q') {
          $test->{option}->{parse_mode} = 'q';
        }
        push @{$all_test->{test}}, $test;
      } elsif ($data->{html}) {
        $all_test->{document}->{$data->{html}->[1]->[0]} = {
          data => $data->{html}->[0],
          format => 'html',
        };
      } elsif ($data->{xml}) {
        $all_test->{document}->{$data->{xml}->[1]->[0]} = {
          data => $data->{xml}->[0],
          format => 'xml',
        };
      }
    }; # for_each_test

    for my $data (values %{$all_test->{document}}) {
      if ($data->{format} eq 'html') {
        my $doc = new Web::DOM::Document;
        $doc->manakai_is_html (1);
        $doc->inner_html ($data->{data});
        $data->{document} = $doc;
      } elsif ($data->{format} eq 'xml') {
        my $doc = new Web::DOM::Document;
        $doc->inner_html ($data->{data});
        $data->{document} = $doc;
      } else {
        die "Test data format $data->{format} is not supported";
      }
    }

    for my $test (@{$all_test->{test}}) {
      test {
        my $c = shift;
        my ($p) = get_parser ($test->{option}->{parse_mode});

        my @actual_error;
        $p->onerror (sub {
          my (%opt) = @_;
          push @actual_error, join ';',
              '',
              $opt{token}->{line} || $opt{line} || 0,
              $opt{token}->{column} || $opt{column} || 0,
              $opt{level},
              $opt{type} .
              (defined $opt{text} ? ';'.$opt{text} : '');
        });

        $p->parse_char_string ($test->{data});
        my $set = $p->parsed_sheet_set;

        eq_or_diff
            ((join "\n", @actual_error), (join "\n", @{$test->{errors} or []}),
             "#result ($test->{data})");

        if (defined $test->{cssom}) {
          my $actual = serialize_cssom ({}, $set, 0);
          eq_or_diff $actual, $test->{cssom}, "#cssom ($test->{data})";
        }

        done $c;
        return; # XXX

        if (defined $test->{csstext}) {
          my $actual = XXXSHEET->css_text;
          eq_or_diff $actual, $test->{csstext}, "#csstext ($test->{data})";
        }

        for my $doc_id (keys %{$test->{computed} or {}}) {
          for my $selectors (keys %{$test->{computed}->{$doc_id}}) {
            my ($window, $style) = get_computed_style
                ($all_test, $doc_id, $selectors, 'XXX', 'XXXSHEET');
            ## NOTE: $window is the root object, so that we must keep
            ## it referenced in this block.
        
            my $actual = serialize_style ({}, $style, '');
            my $expected = $DefaultComputed;
            my $diff = $test->{computed}->{$doc_id}->{$selectors};
            ($actual, $expected) = apply_diff ($actual, $expected, $diff);
            eq_or_diff $actual, $expected,
                "#computed $doc_id $selectors ($test->{data})";
          }
        }

        for my $doc_id (keys %{$test->{computedtext} or {}}) {
          for my $selectors (keys %{$test->{computedtext}->{$doc_id}}) {
            my ($window, $style) = get_computed_style
                ($all_test, $doc_id, $selectors, 'XXX', 'XXXSHEET');
            ## NOTE: $window is the root object, so that we must keep
            ## it referenced in this block.
        
            my $actual = $style->css_text;
            my $expected = $DefaultComputedText;
            my $diff = $test->{computedtext}->{$doc_id}->{$selectors};
            ($actual, $expected) = apply_diff ($actual, $expected, $diff);
            eq_or_diff $actual, $expected,
                "#computedtext $doc_id $selectors ($test->{data})";
          }
        }

        done $c;
      } name => ['p&c'];
    } # $test
  }
}

my @longhand;
my @shorthand;
BEGIN {
  @longhand = qw/
    alignment-baseline
    background-attachment background-color background-image
    background-position-x background-position-y
    background-repeat border-bottom-color
    border-bottom-style border-bottom-width border-collapse
    border-left-color
    border-left-style border-left-width border-right-color
    border-right-style border-right-width
    -manakai-border-spacing-x -manakai-border-spacing-y
    border-top-color border-top-style border-top-width bottom
    caption-side clear clip color content counter-increment counter-reset
    cursor direction display dominant-baseline empty-cells float
    font-family font-size font-size-adjust font-stretch
    font-style font-variant font-weight height left
    letter-spacing line-height
    list-style-image list-style-position list-style-type
    margin-bottom margin-left margin-right margin-top marker-offset
    marks max-height max-width min-height min-width opacity -moz-opacity
    orphans outline-color outline-style outline-width overflow-x overflow-y
    padding-bottom padding-left padding-right padding-top
    page page-break-after page-break-before page-break-inside
    position quotes right size table-layout
    text-align text-anchor text-decoration text-indent text-transform
    top unicode-bidi vertical-align visibility white-space width widows
    word-spacing writing-mode z-index
  /;
  @shorthand = qw/
    background background-position
    border border-color border-style border-width border-spacing
    border-top border-right border-bottom border-left
    font list-style margin outline overflow padding
  /;
  $DefaultComputedText = q[  alignment-baseline: auto;
  border-spacing: 0px;
  background: transparent none repeat scroll 0% 0%;
  border: 0px none -manakai-default;
  border-collapse: separate;
  bottom: auto;
  caption-side: top;
  clear: none;
  clip: auto;
  color: -manakai-default;
  content: normal;
  counter-increment: none;
  counter-reset: none;
  cursor: auto;
  direction: ltr;
  display: inline;
  dominant-baseline: auto;
  empty-cells: show;
  float: none;
  font-family: -manakai-default;
  font-size: 16px;
  font-size-adjust: none;
  font-stretch: normal;
  font-style: normal;
  font-variant: normal;
  font-weight: 400;
  height: auto;
  left: auto;
  letter-spacing: normal;
  line-height: normal;
  list-style-image: none;
  list-style-position: outside;
  list-style-type: disc;
  margin: 0px;
  marker-offset: auto;
  marks: none;
  max-height: none;
  max-width: none;
  min-height: 0px;
  min-width: 0px;
  opacity: 1;
  orphans: 2;
  outline: 0px none invert;
  overflow: visible;
  padding: 0px;
  page: auto;
  page-break-after: auto;
  page-break-before: auto;
  page-break-inside: auto;
  position: static;
  quotes: -manakai-default;
  right: auto;
  size: auto;
  table-layout: auto;
  text-align: begin;
  text-anchor: start;
  text-decoration: none;
  text-indent: 0px;
  text-transform: none;
  top: auto;
  unicode-bidi: normal;
  vertical-align: baseline;
  visibility: visible;
  white-space: normal;
  widows: 2;
  width: auto;
  word-spacing: normal;
  writing-mode: lr-tb;
  z-index: auto;
];
  $DefaultComputed = $DefaultComputedText;
  $DefaultComputed =~ s/^  //gm;
  $DefaultComputed =~ s/;$//gm;
  $DefaultComputed .= q[-manakai-border-spacing-x: 0px
-manakai-border-spacing-y: 0px
-moz-opacity: 1
background-attachment: scroll
background-color: transparent
background-image: none
background-position: 0% 0%
background-position-x: 0%
background-position-y: 0%
background-repeat: repeat
border-top: 0px none -manakai-default
border-right: 0px none -manakai-default
border-bottom: 0px none -manakai-default
border-left: 0px none -manakai-default
border-bottom-color: -manakai-default
border-bottom-style: none
border-bottom-width: 0px
border-left-color: -manakai-default
border-left-style: none
border-left-width: 0px
border-right-color: -manakai-default
border-right-style: none
border-right-width: 0px
border-top-color: -manakai-default
border-top-style: none
border-top-width: 0px
border-color: -manakai-default
border-style: none
border-width: 0px
float: none
font: 400 16px -manakai-default
list-style: disc none outside
margin-top: 0px
margin-right: 0px
margin-bottom: 0px
margin-left: 0px
outline-color: invert
outline-style: none
outline-width: 0px
overflow-x: visible
overflow-y: visible
padding-bottom: 0px
padding-left: 0px
padding-right: 0px
padding-top: 0px];
}

sub get_parser ($) {
  my $parse_mode = shift;

  my $p = Web::CSS::Parser->new;
  $p->media_resolver->set_supported (all => 1);

  if ($parse_mode and $parse_mode eq 'q') {
    $p->context->manakai_compat_mode ('quirks');
  }

  return ($p);
} # get_parser

sub serialize_selectors ($$) {
  my ($self, $selectors) = @_;
  $self->{selectors_serializer} ||= Web::CSS::Selectors::Serializer->new;
  return $self->{selectors_serializer}->serialize_selector_text
      ($selectors, $self->{nsmap});
} # serialize_selectors

sub serialize_mq ($$) {
  return Web::CSS::MediaQueries::Serializer->new->serialize_media_query ($_[1]);
} # serialize_mq

sub serialize_rule ($$$$) {
  my ($self, $set, $rule_id, $indent) = @_;
  my $rule = $set->{rules}->[$rule_id];
  my $v = '';
  if ($rule->{type} eq 'style') {
    $v .= $indent . '<' . (serialize_selectors $self, $rule->{selectors}) . ">\n";
    $v .= serialize_style ($self, $rule->{style}, $indent . '  ');
  } elsif ($rule->{type} eq '@media') {
    $v .= $indent . '@media ' . (serialize_mq $self, $rule->{media}) . "\n";
    $v .= serialize_rule ($self, $set, $_, $indent . '  ') for @{$rule->{rules}};
  } elsif ($rule->{type} eq '@namespace') {
    $v .= $indent . '@namespace ';
    my $prefix = $rule->{prefix};
    $v .= $$prefix . ': ' if defined $prefix and length $$prefix;
    $v .= '<' . ${$rule->{namespace_uri}} . ">\n";
    $self->{nsmap}->{has_namespace} = 1;
    push @{$self->{nsmap}->{uri_to_prefixes}->{${$rule->{namespace_uri}}} ||= []},
        defined $$prefix && length $$prefix ? $$prefix . '|' : '';
  } elsif ($rule->{type} eq '@import') {
    $v .= $indent . '@import <' . $rule->{href} . '> ' . serialize_mq $self, $rule->{media};
    $v .= "\n";
  } elsif ($rule->{type} eq '@charset') {
    $v .= $indent . '@charset ' . $rule->{encoding} . "\n";
  } else {
    die "Rule type $rule->{type} is not supported";
  }
  return $v;
} # serialize_rule

sub serialize_cssom ($$$) {
  my ($self, $set, $ss_id) = @_;
  my $ss = $set->{sheets}->[$ss_id];

  if (defined $ss) {
    if (ref $ss eq 'HASH') {
      my $v = '';
      for my $rule_id (@{$ss->{rules}}) {
        my $indent = '';
        $v .= serialize_rule ($self, $set, $rule_id, $indent);
      }
      return $v;
    } else {
      return '(' . (ref $ss) . ')';
    }
  } else {
    return '(undef)';
  }
} # serialize_cssom

# XXX
sub get_computed_style ($$$$$) {
  my ($all_test, $doc_id, $selectors, $css_options, $ss) = @_;

  my $doc = $all_test->{document}->{$doc_id}->{document};
  unless ($doc) {
    die "Test document $doc_id is not defined";
  }

  my $element = $doc->query_selector ($selectors);
  unless ($element) {
    die "Element $selectors not found in document $doc_id";
  }
  
  my $window = Message::DOM::Window->___new;
  $window->___set_css_options ($css_options);
  $window->___set_user_style_sheets ([$ss]);
  $window->set_document ($doc);
  
  my $style = $element->manakai_computed_style;
  return ($window, $style);
} # get_computed_style

sub serialize_value ($$$) {
  my $self = $_[0];
  $self->{value_serializer} ||= Web::CSS::Serializer->new;
  $self->{value_serializer}->{nsmap} = $self->{nsmap};
  return $self->{value_serializer}->serialize_prop_value ($_[1], $_[2]);
} # serialize_value

sub serialize_priority ($$$) {
  return Web::CSS::Serializer->new->serialize_prop_priority ($_[1], $_[2]);
} # serialize_priority

sub serialize_style ($$$) {
  my ($self, $style, $indent) = @_;

  ## TODO: check @$style

  my @v;
  for (map {get_dom_names ($_)} @shorthand, @longhand) {
    my $css = $_->[0];
    my $dom = $_->[1];
    my $internal = $_->[2];
    push @v, [$_->[0], $dom,
              (serialize_value $self, $style, $css),
              (serialize_priority $self, $style, $css)];
    $v[-1]->[3] = ' !' . $v[-1]->[3]
        if defined $v[-1]->[3] and length $v[-1]->[3];
  }
  return join '',
      map {"$indent$_->[0]: @{[defined $_->[2] ? $_->[2] : '']}@{[defined $_->[3] ? $_->[3] : '']}\n"}
      sort {$a->[0] cmp $b->[0]}
      grep {defined $_->[2] and length $_->[2]} @v;
} # serialize_style

sub get_dom_names ($) {
  my $dom_name = $_[0];
  if ($_[0] eq 'float') {
    return ([$_[0] => 'css_float', $_[0]], [$_[0] => 'style_float', $_[0]]);
  }

  $dom_name =~ tr/-/_/;
  return ([$_[0] => $dom_name => $_[0]]);
} # get_dom_names

sub apply_diff ($$$) {
  my ($actual, $expected, $diff) = @_;
  my @actual = split /[\x0D\x0A]+/, $actual;
  my @expected = split /[\x0D\x0A]+/, $expected;
  my @diff = split /[\x0D\x0A]+/, $diff;
  for (@diff) {
    if (s/^-(?:\| )?//) {
      push @actual, $_;
    } elsif (s/^\+(?:\| )?//) {
      push @expected, $_;
    } else {
      die "Invalid diff line: $_";
    }
  }
  $actual = join "\n", sort {$a cmp $b} @actual;
  $expected = join "\n", sort {$a cmp $b} @expected;
  ($actual, $expected);
} # apply_diff

run_tests;

1;

=head1

# XXXtest

> The namespace prefix is declared only within the style sheet in
which its @namespace rule appears. It is not declared in any style
sheets importing or imported by that style sheet, nor in any other
style sheets applying to the document.

=cut

=head1 LICENSE

Copyright 2008-2013 Wakaba <wakaba@suikawiki.org>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

