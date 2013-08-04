package Web::CSS::MediaQueries::Serializer;
use strict;
use warnings;
our $VERSION = '2.0';

sub new ($) {
  return bless {}, $_[0];
} # new

sub serialize_mq_list ($$) {
  my ($self, $list) = @_;
  return join ', ', map { $self->serialize_mq ($_) } @$list;
} # serialize_mq_list

sub serialize_mq ($$) {
  my ($self, $mq) = @_;
  my @result;

  push @result, 'not' if $mq->{not};
  push @result, 'only' if $mq->{only};

  if (defined $mq->{type}) {
    push @result, $mq->{type}; # XXX identifier
  } elsif ($mq->{not}) {
    push @result, 'all';
  }

  for (@{$mq->{features}}) {
    push @result, 'and';
    push @result, '(' . $_->{name} . ')'; # XXX
  }

  return join ' ', @result;
} # serialize_mq

# XXX
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
