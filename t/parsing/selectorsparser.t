package test::Whatpm::CSS::SelectorsParser;
use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('modules', 'testdataparser', 'lib')->stringify;
use base qw(Test::Class);
use Test::Differences;
use Test::HTCT::Parser;
use Whatpm::CSS::SelectorsParser qw(:selector :combinator :match);

my $data_d = file (__FILE__)->dir;

sub _lists : Test(2) {
  eq_or_diff ref $Whatpm::CSS::SelectorsParser::IdentOnlyPseudoClasses, 'HASH';
  eq_or_diff ref $Whatpm::CSS::SelectorsParser::IdentOnlyPseudoElements,
      'HASH';
} # _lists

sub serialize_selector_object ($);

sub serialize_simple_selector ($);
sub serialize_simple_selector ($) {
  local $_ = $_[0];
  my $result = '';

  ## A simple selector
  if ($_->[0] == LOCAL_NAME_SELECTOR) {
    $result .= "<" . $_->[1] . ">\n";
  } elsif ($_->[0] == ATTRIBUTE_SELECTOR) {
    $result .= "[" . (defined $_->[1] ? "{" . ($_->[1]) . "}" : "");
    $result .= $_->[2] . "]\n";
    if (defined $_->[3]) {
      $result .= {
        EQUALS_MATCH, '=',
        INCLUDES_MATCH, '~=',
        DASH_MATCH, '|=',
        PREFIX_MATCH, '^=',
        SUFFIX_MATCH, '$=',
        SUBSTRING_MATCH, '*=',
      }->{$_->[3]} || $_->[3];
      $result .= $_->[4] . "\n";
    }
  } elsif ($_->[0] == NAMESPACE_SELECTOR) {
    $result .= "{" . (defined $_->[1] ? length $_->[1] ? $_->[1] : '}empty{' : '') . "}" . "\n";
  } else {
    $result .= {
      ID_SELECTOR, '#',
      CLASS_SELECTOR, '.',
      PSEUDO_CLASS_SELECTOR, ':',
      PSEUDO_ELEMENT_SELECTOR, '::',
    }->{$_->[0]} || $_->[0];
    if (exists $_->[1]) {
      $result .= $_->[1];
    }
    $result .= "\n";
    if (exists $_->[2]) {
      my $value = $_->[1];
      for (@{$_}[2..$#{$_}]) {
        if (ref $_ eq 'ARRAY') {
          if ($value eq 'cue') {
            my $v = serialize_selector_object $_;
            $v =~ s/\x0A/\x0A  /g;
            $result .= "  " . $v . "\n";
          } else {
            my $r = "  " . serialize_simple_selector $_;
            $r =~ s/\n/\n  /g;
            $r =~ s/\n  $/\n/;
            $result .= $r;
          }
        } else {
          $result .= q<  "> . $_ . qq<"\n>;
        }
      }
    } elsif ($_->[1] eq 'not') {
      $result .= qq<  *\n>;
    }
  }
  return $result;
} # serialize_simple_selector

sub serialize_selector_object ($) {
  my $selectors = shift;
  my $result = '';
  my $i = 0;
  ## A group of selectors
  for (@$selectors) {
    $result .= "------\n" if $i++;
    ## A selector
    my $j = 0;
    my @sel = @$_;
    while (@sel) {
      my ($combinator, $sss) = (shift @sel, shift @sel);

      ## A combinator
      if ($combinator != DESCENDANT_COMBINATOR) {
        $result .= {
          CHILD_COMBINATOR, '>',
          ADJACENT_SIBLING_COMBINATOR, '+',
          GENERAL_SIBLING_COMBINATOR, '~',
        }->{$combinator} || $combinator;
        $result .= "\n";
      } else {
        $result .= "***\n" if $j;
      }

      ## A simple selector sequence
      if (@$sss) {
        for (@$sss) {
          $result .= serialize_simple_selector $_;
        }
      } else {
        $result .= "*\n";
      }

      $j++;
    }
  }
  $result =~ s/\n$//g;
  return $result;
} # serialize_selector_object

sub _parse_string : Tests {
  for_each_test ($_, {
    data => {is_prefixed => 1},
    ns => {is_list => 1},
    errors => {is_list => 1},
    parsed => {is_prefixed => 1},
    supported => {is_list => 1},
  }, sub {
    my $test = shift;

    my @error;

    my $parser = Whatpm::CSS::SelectorsParser->new;
    $parser->{onerror} = sub {
      my %args = @_;
      push @error, join ';', map { defined $_ ? $_ : '' }
          $args{token}->{line} // $args{line},
          $args{token}->{column} // $args{column},
          $args{type},
          $args{text},
          $args{value},
          $args{level};
    }; # onerror

    for (@{$test->{supported}->[0] or []}) {
      if (/^::(\S+)$/) {
        $parser->{pseudo_element}->{$1} = 1;
      } elsif (/^:(\S+)$/) {
        $parser->{pseudo_class}->{$1} = 1;
      }
    }

    my %ns;
    for (@{$test->{ns}->[0] or []}) {
      if (/^(\S+)\s+(\S+)$/) {
        $ns{$1} = $2 eq '<null>' ? '' : $2;
      } elsif (/^(\S+)$/) {
        $ns{''} = $1 eq '<null>' ? '' : $1;
      }
    }
    $parser->{lookup_namespace_uri} = sub {
      return $ns{$_[0] // ''};
    }; # lookup_namespace_uri

    my $selectors = $parser->parse_string ($test->{data}->[0]);

    my $serialized_selectors = serialize_selector_object $selectors;
    eq_or_diff $serialized_selectors, $test->{parsed}->[0];

    my $aerrors = join "\n", sort { $a cmp $b } @error;
    my $xerrors = join "\n", sort { $a cmp $b } @{$test->{errors}->[0] or []};
    eq_or_diff $aerrors, $xerrors;
  }) for map { $data_d->subdir ('selectors')->file ($_)->stringify } qw(
    parse-1.dat
    parse-spaces-1.dat
    parse-escapes-1.dat
    parse-invalid-1.dat
    parse-namespaces-1.dat
    parse-simple-1.dat
    parse-pseudo-1.dat
    parse-combinators-1.dat
  );
} # _parse_string

sub _get_selector_specificity : Test(16) {
  for (
    ['*',                 [0, 0, 0, 0]],
    ['LI',                [0, 0, 0, 1]],
    ['UL LI',             [0, 0, 0, 2]],
    ['UL OL+LI',          [0, 0, 0, 3]],
    ['H1 + *[REL=up]',    [0, 0, 1, 1]],
    ['UL OL LI.red',      [0, 0, 1, 3]],
    ['LI.red.level',      [0, 0, 2, 1]],
    ['#x34y',             [0, 1, 0, 0]],
    ['#s12:not(FOO)',     [0, 1, 0, 1]],
    [':first-child',      [0, 0, 1, 0]],
    [':lang(en)::before', [0, 0, 1, 1]],
    [':NOT(.foo):NOT(*)', [0, 0, 1, 0]],
    ['ns1|*',             [0, 0, 0, 0]],
    ['ns1|hoge',          [0, 0, 0, 1]],
    ['[ns1|foo]',         [0, 0, 1, 0]],
    ['[ns1~=hoge]',       [0, 0, 1, 0]],
  ) {
    my $parser = Whatpm::CSS::SelectorsParser->new;
    $parser->{pseudo_class}->{not} = 1;
    $parser->{pseudo_class}->{lang} = 1;
    $parser->{pseudo_class}->{'first-child'} = 1;
    $parser->{pseudo_element}->{before} = 1;
    $parser->{lookup_namespace_uri} = sub {
      my $prefix = shift;
      return 'http://foo/' if $prefix;
      return undef;
    };
    my $selectors = $parser->parse_string ($_->[0]);
    eq_or_diff $parser->get_selector_specificity ($selectors->[0]), $_->[1];
  }
}

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2011-2012 Wakaba <w@suika.fam.cx>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
