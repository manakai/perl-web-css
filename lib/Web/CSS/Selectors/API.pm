package Web::CSS::Selectors::API;
use strict;
use warnings;
our $VERSION = '1.13';
use Web::CSS::Selectors::Parser;
use Web::CSS::Context;

sub new ($) {
  return bless {}, $_[0];
} # new

## XXX API of this module is not stable yet; You should not rely on
## it.  Use $root_node->query_selector and
## $root_node->query_selector_all instead.

# XXX Need to match Selectors 4...

## NOTE: This implementation does no optimization at all.  Future
## revisions are expected to do it, but the current focus is
## implementing the features rather than tuning some of them.

sub is_html ($;$) {
  if (@_ > 1) {
    $_[0]->{is_html} = !!$_[1];
  }
  return $_[0]->{is_html};
} # is_html

sub root_node ($;$) {
  if (@_ > 1) {
    $_[0]->{root_node} = $_[1];
  }
  return $_[0]->{root_node};
} # root_node

sub return_all ($;$) {
  if (@_ > 1) {
    $_[0]->{return_all} = $_[1];
  }
  return $_[0]->{return_all};
} # return_all

sub selectors ($) {
  return $_[0]->{selectors};
} # selectors

sub selectors_has_ns_error ($) {
  return $_[0]->{selectors_has_ns_error};
} # selectors_has_ns_error

sub set_selectors ($$$;%) {
  my ($self, $selectors, $resolver, %args) = @_;
  if (ref $selectors eq 'ARRAY') {
    $self->{selectors} = $selectors;
    delete $self->{selectors_has_ns_error};
  } else {
    my $p = Web::CSS::Selectors::Parser->new;
    my $ns_error;
    if (defined $resolver) { # resolver must be CODE or can(lookup_namespace_uri)
      if (UNIVERSAL::can ($_[2], 'lookup_namespace_uri')) {
        my $obj = $resolver;
        $resolver = sub { $obj->lookup_namespace_uri ($_[0]) }; # or throw
      }
      if ($args{nsresolver}) {
        $p->context (Web::CSS::Context->new_from_nscallback (sub {
          my $result = $resolver->(defined $_[0] ? $_[0] : ''); # or throw
          $result = defined $result ? ''.$result : ''; # WebIDL DOMString
          if (defined $_[0] and length $_[0]) {
            $ns_error = $_[0] if $result eq '';
            return length $result ? $result : undef;
          } else {
            return length $result ? $result : '';
          }
        }));
      } else {
        $p->context (Web::CSS::Context->new_from_nscallback (sub {
          my $result = $resolver->($_[0]); # or throw
          $ns_error = $_[0] if defined $_[0] and length $_[0] and not defined $result;
          return $result;
        }));
      }
    } else { # resolver is null
      $p->context (Web::CSS::Context->new_from_nscallback (sub {
        if (defined $_[0] and length $_[0]) { # Namespace prefix
          $ns_error = $_[0];
          return undef; # not declared
        } else { # Default namespace
          return undef; # not declared
        }
      }));
    }

    ## NOTE: SHOULD ensure to remain stable when facing a hostile $_[2].

    my $mr = $p->media_resolver;
    $mr->{pseudo_class}->{$_} = 1 for qw/
      root nth-child nth-last-child nth-of-type nth-last-of-type
      first-child first-of-type last-child last-of-type
      only-child only-of-type empty
      not
      -manakai-contains -manakai-current
    /;
#      active checked disabled enabled focus hover indeterminate link
#      target visited lang

    ## NOTE: MAY treat all links as :link rather than :visited

    $mr->{pseudo_element}->{$_} = 1 for qw/
      after before first-letter first-line
    /;

    $self->{selectors} = $p->parse_char_string_as_selectors ($selectors);
    $self->{selectors_has_ns_error} = $ns_error;
  }
} # set_selectors

sub _sss_match ($$$) {
  my ($self, $sss, $node) = @_;
  my $is_html = $self->is_html;

  my $sss_matched = 1;
  for my $simple_selector (@{$sss}) {
    if ($simple_selector->[0] == LOCAL_NAME_SELECTOR) {
            if ($simple_selector->[1] eq
                $node->manakai_local_name) {
              #
            } elsif ($is_html) {
              my $nsuri = $node->namespace_uri;
              if (defined $nsuri and
                  $nsuri eq q<http://www.w3.org/1999/xhtml>) {
                if (lc $simple_selector->[1] eq
                    $node->manakai_local_name) {
                  ## TODO: What kind of case-insensitivility?
                  ## TODO: Is this checking method OK?
                  #
                } else {
                  $sss_matched = 0;
                }
              } else {
                $sss_matched = 0;
              }
            } else {
              $sss_matched = 0;
            }
          } elsif ($simple_selector->[0] == NAMESPACE_SELECTOR) {
            my $nsuri = $node->namespace_uri;
            if (defined $simple_selector->[1]) {
              if (defined $nsuri and $nsuri eq $simple_selector->[1]) {
                #
              } else {
                $sss_matched = 0;
              }
            } else {
              if (defined $nsuri) {
                $sss_matched = 0;
              }
            }
    } elsif ($simple_selector->[0] == CLASS_SELECTOR) {
      M: {
        my $class_name = $node->class_name;
        $class_name = '' unless defined $class_name;
        for (grep length, split /[\x09\x0A\x0C\x0D\x20]/, $class_name, -1) {
          if ($simple_selector->[1] eq $_) {
            last M;
          }
        }
        $sss_matched = 0;
      } # M
    } elsif ($simple_selector->[0] == ID_SELECTOR) {
      my $el = $node->owner_document->get_element_by_id ($simple_selector->[1]);
      $sss_matched = $el eq $node;
    } elsif ($simple_selector->[0] == ATTRIBUTE_SELECTOR) {
            my @attr_node;
            ## Namespace URI
            if (not defined $simple_selector->[1]) {
              my $ln = $simple_selector->[2];
              if ($is_html) {
                my $nsuri = $node->namespace_uri;
                if (defined $nsuri and
                    $nsuri eq q<http://www.w3.org/1999/xhtml>) {
                  $ln =~ tr/A-Z/a-z/; ## ISSUE: Case-insensitivity
                }
              }

              ## Any Namespace, Local Name
              M: {
                for my $attr_node (@{$node->attributes}) {
                  my $node_ln = $attr_node->manakai_local_name;
                  if ($node_ln eq $simple_selector->[2]) {
                    push @attr_node, $attr_node;
                    last M if $simple_selector->[3] == EXISTS_MATCH;
                  } elsif (not defined $attr_node->namespace_uri and
                           $node_ln eq $ln) {
                    push @attr_node, $attr_node;
                    last M if $simple_selector->[3] == EXISTS_MATCH;
                  }
                }
                last M if @attr_node;
                $sss_matched = 0;
              } # M
            } elsif ($simple_selector->[1] eq '') {
              my $ln = $simple_selector->[2];
              if ($is_html) {
                my $nsuri = $node->namespace_uri;
                if (defined $nsuri and
                    $nsuri eq q<http://www.w3.org/1999/xhtml>) {
                  $ln =~ tr/A-Z/a-z/; ## ISSUE: Case-insensitivity
                }
              }

              ## ISSUE: Does <p>.setAttributeNS (undef, 'Align')'ed <p>
              ## match with [align]?

              ## Null Namespace, Local Name
              my $attr_node = $node->get_attribute_node_ns
                  (undef, $ln);
              if ($attr_node) {
                push @attr_node, $attr_node;
              } else {
                $sss_matched = 0;
              }
            } else {
              ## Non-null Namespace, Local Name
              my $attr_node = $node->get_attribute_node_ns
                      ($simple_selector->[1], $simple_selector->[2]);
              if ($attr_node) {
                push @attr_node, $attr_node;
              } else {
                $sss_matched = 0;
              }
            }

      if ($sss_matched) {
        if ($simple_selector->[3] == EXISTS_MATCH) {
          #
        } else {
          for my $attr_node (@attr_node) {
            ## TODO: Attribute value case-insensitivility
            my $value = $attr_node->value;
            if ($simple_selector->[3] == EQUALS_MATCH) {
              if ($value eq $simple_selector->[4]) {
                #
              } else {
                $sss_matched = 0;
              }
            } elsif ($simple_selector->[3] == DASH_MATCH) {
              ## ISSUE: [a|=""] a="a--b" a="-" ?
              if ($value eq $simple_selector->[4]) {
                #
              } elsif (substr ($value, 0,
                               1 + length $simple_selector->[4]) eq
                       $simple_selector->[4] . '-') {
                #
              } else {
                $sss_matched = 0;
              }
            } elsif ($simple_selector->[3] == INCLUDES_MATCH) { # ~=
              M: {
                for (split /[\x09\x0A\x0C\x0D\x20]+/, $value, -1) {
                  next unless length;
                  if ($_ eq $simple_selector->[4]) {
                    last M;
                  }
                }
                $sss_matched = 0;
              } # M
            } elsif ($simple_selector->[3] == PREFIX_MATCH) {
              if (length $simple_selector->[4] and
                  $simple_selector->[4] eq
                      substr ($value, 0, length $simple_selector->[4])) {
                #
              } else {
                $sss_matched = 0;
              }
            } elsif ($simple_selector->[3] == SUFFIX_MATCH) {
              if (length $simple_selector->[4] and
                  $simple_selector->[4] eq
                      substr ($value, -length $simple_selector->[4])) {
                #
              } else {
                $sss_matched = 0;
              }
            } elsif ($simple_selector->[3] == SUBSTRING_MATCH) {
              if (length $simple_selector->[4] and
                  index ($value, $simple_selector->[4]) > -1) {
                #
              } else {
                $sss_matched = 0;
              }
            } else {
              ## New matching type, supported by the parser but not by
              ## this Selectors API implementation.
              $sss_matched = 0;
            }
          }
        }
      }
    } elsif ($simple_selector->[0] == PSEUDO_CLASS_SELECTOR) {
      my $class_name = $simple_selector->[1];
      if ($class_name eq 'not') {
        my $list = $simple_selector->[2];
        if (@$list == 1) {
          my $sel = $list->[0];
          if (@$sel == 2) {
            my $sss = $sel->[1];
            if ($self->_sss_match ([@$sss], $node)) {
              $sss_matched = 0;
            }
          } else {
            $sss_matched = 0;
          }
        } else {
          $sss_matched = 0;
        }

        ## XXX Only ':not({simple_selector}+)' (Selectors level 3) is
        ## supported.
      } elsif ({
        'nth-child' => 1, 'nth-last-child' => 1,
        'nth-of-type' => 1, 'nth-last-of-type' => 1,
        'first-child' => 1, 'last-child' => 1,
        'first-of-type' => 1, 'last-of-type' => 1,
      }->{$class_name}) {
        my $aa = $class_name =~ /^first/ ? 0
               : $class_name =~ /^last/ ? 0
               : $simple_selector->[2];
        my $ab = $class_name =~ /^first/ ? 1
               : $class_name =~ /^last/ ? 1
               : $simple_selector->[3];
        my $parent = $node->parent_node;
        if ($parent) {

          ## O(n^2) (or O(nm) where /m/ is the average number of
          ## children, more strictly speaking) as a whole, which seems
          ## bad...
          my $i = 0;
          my @child = @{$parent->child_nodes};
          @child = reverse @child if $class_name =~ /last/;
          for (@child) {
            next unless $_->node_type == 1; # ELEMENT_NODE
            next if $class_name =~ /of-type/ and
                not $_->manakai_element_type_match
                        ($node->namespace_uri, $node->manakai_local_name);
            $i++;
            last if $_ eq $node;
          }

          if ($aa == 0) {
            $sss_matched = 0 if $i != $ab;
          } else {
            my $j = $i - $ab;
            if ($aa > 0) {
              $sss_matched = 0 if $j % $aa or $j / $aa < 0;
            } else { # $aa < 0
              $sss_matched = 0 if -$j % -$aa or -$j / -$aa < 0;
            }
          }
        } else {
          $sss_matched = 0;
        }
      } elsif ($class_name eq 'only-child' or $class_name eq 'only-of-type') {
        my $parent = $node->parent_node;
        if ($parent) {
          my $i = 0;
          for (@{$parent->child_nodes}) {
            if ($_->node_type == 1) { # ELEMENT_NODE
              if ($class_name eq 'only-of-type') {
                $i++ if $_->manakai_element_type_match
                    ($node->namespace_uri, $node->manakai_local_name);
              } else {
                $i++;
              }
              if ($i == 2) {
                $sss_matched = 0;
                last;
              }
            }
          }
        } else {
          $sss_matched = 0;
        }
      } elsif ($class_name eq 'empty') {
        for (@{$node->child_nodes}) {
          my $nt = $_->node_type;
          if ($nt == 1) { # ELEMENT_NODE
            $sss_matched = 0;
            last;
          } elsif ($nt == 3 or $nt == 4) { # TEXT_NODE, CDATA_SECTION_NODE
            my $length = length $_->data;
            if ($length) {
              $sss_matched = 0;
              last;
            }
          }
        }
      } elsif ($class_name eq 'root') {
        my $parent = $node->parent_node;
        $sss_matched = 0
            unless $parent->node_type == 9; # DOCUMENT_NODE
      } elsif ($class_name eq '-manakai-current') {
        ## $self->root_node can be non-element, but $node is always an
        ## Element.
        $sss_matched = 0 if $self->root_node ne $node;
      } elsif ($class_name eq '-manakai-contains') {
        $sss_matched = 0
            if index ($node->text_content,
                      $simple_selector->[2]) == -1;
      } else {
        ## This statement should never be executed.
        die "$class_name: Bad pseudo-class";
      }
    } elsif ($simple_selector->[0] == PSEUDO_ELEMENT_SELECTOR) {
      $sss_matched = 0;
    } else {
      ## New simple selector type, supported by the parser but not
      ## supported by this Selectors API implementation.
      $sss_matched = 0;
    }
  }
  return $sss_matched;
} # _sss_match

sub get_elements ($) {
  my ($self) = @_;

  my $r;
  $r = [] if $self->return_all;
  my $selectors = $self->selectors or return $r;
  
  my @node_cond = map {$_->[1] = [@$selectors]; $_} @{$self->_get_node_cond};
  while (@node_cond) {
    my $node_cond = shift @node_cond;
    if ($node_cond->[0]->node_type == 1) { # ELEMENT_NODE
      my @new_cond;
      my $matched;
      for my $selector (@{$node_cond->[1]}) {
        if ($self->_sss_match ($selector->[1], $node_cond->[0])) {
          if (@$selector == 2) {
            unless ($node_cond->[3]) {
              return $node_cond->[0] unless defined $r;
              push @$r, $node_cond->[0] unless $matched;
              $matched = 1;
            }
          } else {
            my $new_selector = [@$selector[2..$#$selector]];
            if ($new_selector->[0] == DESCENDANT_COMBINATOR or
                $new_selector->[0] == CHILD_COMBINATOR) {
              push @new_cond, $new_selector;
            } else { # ADJACENT_SIBLING_COMBINATOR | GENERAL_SIBLING_COMBINATOR
              push @{$node_cond->[2]->[1] || []}, $new_selector;
            }
          }
        }
        if ($selector->[0] == DESCENDANT_COMBINATOR) {
          push @new_cond, $selector;
        } elsif ($selector->[0] == GENERAL_SIBLING_COMBINATOR) {
          push @{$node_cond->[2]->[1] || []}, $selector;
        } elsif ($selector->[0] == CHILD_COMBINATOR or
                 $selector->[0] == ADJACENT_SIBLING_COMBINATOR) {
          #
        } else {
          ## New combinator supported by the parser but not by this
          ## Selectors API implementation.
        }
      }

      if (@new_cond) {
        unless ($node_cond->[3]) {
          my @children = grep { $_->node_type == 1 } # ELEMENT_NODE
              @{$node_cond->[0]->child_nodes};
          my $next_sibling_cond;
          for (reverse @children) {
            my $new_node_cond = [$_, [@new_cond], $next_sibling_cond];
            unshift @node_cond, $new_node_cond;
            $next_sibling_cond = $new_node_cond;
          }
        } else {
          for (@{$node_cond->[4]}) {
            $_->[1] = [@new_cond];
          }
          $node_cond->[4]->[0]->[1] = \@new_cond if @{$node_cond->[4]};
        }
      }
    }
  }
  return $r;
} # get_elements

sub _get_node_cond ($) {
  my $node = $_[0]->root_node;
  my @node_cond;
  my $child_conds = [];

  ## Children of the Element.
  my @children = grep { $_->node_type == 1 } @{$node->child_nodes};
  my $next_sibling_cond;
  for (reverse @children) {
    my $new_node_cond = [$_, undef, $next_sibling_cond];
    unshift @node_cond, $new_node_cond;
    $next_sibling_cond = $new_node_cond;
  }
  @$child_conds = @node_cond;

  ## Ancestors and previous siblings of ancestors
  my $parent = $node->parent_node;
  while (defined $parent) {
    my $conds = [];
    for (grep { $_->node_type == 1 } @{$parent->child_nodes}) { # ELEMENT_NODE
      push @$conds, my $cond = [$_, undef, undef, 1, $child_conds];
      if ($_ eq $node) {
        $child_conds = $conds;
        ($node, $parent) = ($parent, $parent->parent_node);
        last;
      }
    }
    my $nsib_cond;
    for (reverse @$child_conds) {
      $_->[2] = $nsib_cond;
      $nsib_cond = $_;
    }
    unshift @node_cond, @$conds;
  }
  if ($node->node_type == 1) { # ELEMENT_NODE
    unshift @node_cond, [$node, undef, undef, 1, $child_conds];
  }

  return \@node_cond;
} # _get_node_cond

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
