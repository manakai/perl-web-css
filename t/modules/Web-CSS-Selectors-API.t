package test::Message::DOM::SelectorsAPI;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('modules', 'testdataparser', 'lib')->stringify;
use base qw(Test::Class);
use Test::Differences;
use Test::HTCT::Parser;

require Message::DOM::DOMImplementation;
my $dom = Message::DOM::DOMImplementation->new;

my $data_d = file (__FILE__)->dir->subdir ('selectors');

sub _query_selector : Tests {
  my $documents = {};

  for_each_test $_, {
    html => {is_prefixed => 1},
    xml => {is_prefixed => 1},
    data => {is_prefixed => 1},
    result => {is_list => 1, multiple => 1},
    ns => {is_list => 1},
    supported => {is_list => 1},
  }, sub {
    my $test = shift;

    if ($test->{html}) {
      my $doc_name = $test->{html}->[1]->[0];
      if (exists $documents->{$doc_name}) {
        warn "# Document |$doc_name| is already defined\n";
      }
      
      my $doc = $dom->create_document;
      $doc->manakai_is_html (1);
      $doc->inner_html ($test->{html}->[0]);
      $documents->{$doc_name} = $doc;

      return;
    } elsif ($test->{xml}) {
      my $doc_name = $test->{xml}->[1]->[0];
      if (exists $documents->{$doc_name}) {
        warn "# Document |$doc_name| is already defined\n";
      }
      
      my $doc = $dom->create_document;
      $doc->inner_html ($test->{xml}->[0]);
      $documents->{$doc_name} = $doc;

      return;
    }
    
    my %ns;
    for (@{$test->{ns}->[0] or []}) {
      if (/^(\S+)\s+(\S+)$/) {
        $ns{$1} = $2 eq '<null>' ? '' : $2;
      } elsif (/^(\S+)$/) {
        $ns{''} = $1 eq '<null>' ? '' : $1;
      }
    }

    my $lookup_ns = sub {
      return $ns{$_[0] // ''};
    }; # lookup_namespace_uri
    
    for my $result (@{$test->{result} or []}) {
      my $label = $result->[1]->[0];
      my $root = $result->[1]->[1] // '/';
      
      my $doc = $documents->{$label} or die "Test |$label| not found\n";
      my $root_node = get_node_by_path ($doc, $root);
      
      ## query_selector_all
      my $expected = join "\n", @{$result->[0]};
      my $actual = join "\n", map {
        get_node_path ($_)
      } @{$root_node->query_selector_all ($test->{data}->[0], $lookup_ns)};
      eq_or_diff $actual, $expected, "$test->{data}->[0] $label $root all";
      
      ## query_selector
      $expected = $result->[0]->[0];
      undef $actual;
      my $node = $root_node->query_selector ($test->{data}->[0], $lookup_ns);
      $actual = get_node_path ($node) if defined $node;
      eq_or_diff $actual, $expected, "$test->{data}->[0] $label $root one";
    } # $result
  } for map { $data_d->file ($_)->stringify } qw(
    query-1.dat
  );
} # _query_selector

sub get_node_path ($) {
  my $node = shift;
  my $r = '';
  my $parent = $node->parent_node;
  while ($parent) {
    my $i = 0;
    for (@{$parent->child_nodes}) {
      $i++;
      if ($_ eq $node) {
        $r = '/' . $i . $r;
      }
    }
    ($parent, $node) = ($parent->parent_node, $parent);
  }
  return $r;
} # get_node_path

sub get_node_by_path ($$) {
  my ($doc, $path) = @_;
  if ($path eq '/') {
    return $doc;
  } else {
    for (map {$_ - 1} grep {$_} split m#/#, $path) {
      $doc = $doc->child_nodes->[$_];
    }
    return $doc;
  }
} # get_node_by_path

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2007-2011 Wakaba <w@suika.fam.cx>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
