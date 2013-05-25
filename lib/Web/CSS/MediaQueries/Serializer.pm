package Web::CSS::MediaQueries::Serializer;
use strict;
use warnings;
our $VERSION = '2.0';

sub new ($) {
  return bless {}, $_[0];
} # new

sub serialize_media_query ($$) {
  my (undef, $mq) = @_;
  return undef unless defined $mq;

  return join ', ', map {
    do {
      if (@$_ and $_->[0]->[0] eq '#type') {
        $_->[0]->[1];
      } else {
        'unknown';
      }
    }
  } @$mq;
} # serialize_media_query

1;

=head1 LICENSE

Copyright 2008-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
