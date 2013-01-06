use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::Differences;
use Test::HTCT::Parser;
use Test::X1;
use Web::DOM::Document;
use Web::HTML::Parser;
use Web::XML::Parser;
use Web::CSS::Selectors::API;

my $data_d = file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'tests', 'css', 'selectors', 'parsing', 'manakai');

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

my $documents = {};
for my $file_name (map { $data_d->file ($_)->stringify } qw(
  query-1.dat
)) {
  for_each_test $file_name, {
    html => {is_prefixed => 1},
    xml => {is_prefixed => 1},
    data => {is_prefixed => 1},
    result => {is_list => 1, multiple => 1},
    ns => {is_list => 1},
    supported => {is_list => 1},
  }, sub {
    my $test = shift;

    my $doc = new Web::DOM::Document;
    if ($test->{html}) {
      my $doc_name = $test->{html}->[1]->[0];
      if (exists $documents->{$doc_name}) {
        warn "# Document |$doc_name| is already defined\n";
      }
      
      $doc->manakai_is_html (1);
      my $parser = Web::HTML::Parser->new;
      $parser->parse_char_string ($test->{html}->[0] => $doc);
      $documents->{$doc_name} = $doc;
      return;
    } elsif ($test->{xml}) {
      my $doc_name = $test->{xml}->[1]->[0];
      if (exists $documents->{$doc_name}) {
        warn "# Document |$doc_name| is already defined\n";
      }
      
      my $parser = Web::XML::Parser->new;
      $parser->parse_char_string ($test->{xml}->[0] => $doc);
      $documents->{$doc_name} = $doc;
      return;
    }

    test {
      my $c = shift;
      
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
        my $api = Web::CSS::Selectors::API->new;
        $api->is_html ($doc->manakai_is_html);
        $api->root_node ($root_node);
        $api->set_selectors ($test->{data}->[0], $lookup_ns);
        
        test {
          $api->return_all (1);
          my $expected = join "\n", @{$result->[0]};
          my $actual = join "\n",
              map { get_node_path ($_) } @{$api->get_elements};
          eq_or_diff $actual, $expected, "$test->{data}->[0] $label $root all";
        } $c, n => 1, name => 'query_selector_all';
        
        test {
          $api->return_all (0);
          my $expected = $result->[0]->[0];
          my $node = $api->get_elements;
          my $actual = defined $node ? get_node_path ($node) : undef;
          eq_or_diff $actual, $expected, "$test->{data}->[0] $label $root one";
        } $c, n => 1, name => 'query_selector';
      } # $result

      done $c;
    } name => ['query', $file_name], n => 2 * @{$test->{result} or []};
  }
}

run_tests;

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
