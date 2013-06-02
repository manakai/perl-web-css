package Web::CSS::Context;
use strict;
use warnings;
our $VERSION = '1.0';

sub new_empty ($) {
  return bless {}, $_[0];
} # new_empty

sub new_from_nsmaps ($$$) {
  return bless {prefix_to_url => $_[1], url_to_prefix => $_[2]}, $_[0];
} # new_from_nsmaps

sub new_from_nscallback ($$) {
  return bless {
    callback => $_[1],
  }, $_[0];
} # new_from_nscallback

sub has_namespace ($) {
  return 1 if $_[0]->{callback};
  return 1 if keys %{$_[0]->{prefix_to_url} or {}};
  return 0;
} # has_namespace

## The argument is the namespace prefix, or |undef| for the default
## namespace.
##
## The method is expected to return either a non-empty string
## (namespace URL), the empty string (null namespace), or |undef| (no
## declaration).
sub get_url_by_prefix ($$) {
  return undef unless defined $_[1];
  my $prefix = $_[1];
  if (exists $_[0]->{prefix_to_url}->{$prefix}) {
    return $_[0]->{prefix_to_url}->{$prefix}; # or undef
  } elsif ($_[0]->{callback}) {
    my $result = $_[0]->{callback}->($_[1]); # or throw
    return $_[0]->{prefix_to_url}->{$prefix} = $result; # or undef
  } else {
    return undef;
  }
} # get_url_by_prefix

## The argument is the namespace URL, or |undef| for the null
## namespace.
##
## The method is expected to return a non-empty string (prefix), the
## empty string (the default namespace) or |undef| (no applicable
## prefix).
sub get_prefix_by_url ($$) {
  return undef unless defined $_[1];
  my $url = $_[1];
  if (exists $_[0]->{url_to_prefix}->{$url}) {
    return $_[0]->{url_to_prefix}->{$url};
  }
  return undef;
} # get_prefix_by_url

## A namespace prefix, or the default namespace, is in one of these
## three states:
##
##     (a) The namespace prefix is not declared.
##
##     (b) The namespace prefix, or the default namespace, is bound to
##         the null namespace.
##
##     (c) The namespace prefix, or the default namespace, is bound to a
##         (non-empty) namespace URL.
##
##     (d) The default namespace is not bound to any namespace,
##         i.e. equivalent to '*' (wildcard).
##
## Use case 1: Resolving CSS qualified name in CSS
##
##   If there is no '@namespace' at-rule in the CSS style sheet, the
##   namespace prefix is in the state (a) and is an error.  If there
##   is no '@namespace' at-rule for the default namespace, it is in
##   the state (d).  If there is a '@namespace' at-rule for the
##   namespace prefix or the default namespace and its value is the
##   empty string, it is in the state (b).  Otherwise, it is in the
##   state (c).
##
##   <http://dev.w3.org/csswg/css-namespaces/#css-qnames>
##
## Use case 2: Resolving namespaces in Selectors, using NSResolver
##
##   If the NSResolver returns the |undef| value for a namespace
##   prefix, it is in the state (a) and is an error.  If the
##   NSResolver returns the |undef| value for the default namespace,
##   it is in the state (d).  If the NSResolver returns a non-|undef|
##   value for a namespace prefix or the default namespace, it is in
##   the (c) state.
##
##   <http://dev.w3.org/cvsweb/~checkout~/2006/webapi/selectors-api/Overview.html?rev=1.28&content-type=text/html;%20charset=utf-8#nsresolver>
##
## Use case 3: Resolving namespaces in Selectors, using Node
##
##   If the namespace prefix is not in scope at the Node, it is in the
##   state (a) and is an error.  If the namespace prefix is in scope
##   at the Node (i.e. bound to a non-empty namespace URL), it is in
##   the state (c).  The default namespace is always in the state (d).
##
##   <http://www.w3.org/TR/2007/CR-xbl-20070316/#attributes>
##   <http://html5.org/tools/web-apps-tracker?from=2318&to=2319>
##
## Serialization:
##
##   In some browser, (d) is serialized with prefix '*|' if there is
##   at least a '@namespace' declaration, or without any prefix
##   otherwise.
##
##   In some browser, a name with namespace URL is serialized with the
##   last namespace prefix (or the default namespace) declared for the
##   namespace URL.
##
##   Note that no spec defines how to serialize namespaces of CSS
##   qualified names at the time of writing.  While some browser
##   preserves prefixes in the source, other browser does not.  No
##   browser performes namespace fixup when there are conflicting
##   usage of namespaces.

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
