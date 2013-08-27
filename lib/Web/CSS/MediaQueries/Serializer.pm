package Web::CSS::MediaQueries::Serializer;
use strict;
use warnings;
our $VERSION = '4.0';
push our @ISA, qw(Web::CSS::MediaQueries::Serializer::_
                  Web::CSS::Values::Serializer);

package Web::CSS::MediaQueries::Serializer::_;
use Web::CSS::Values::Serializer; # exporting

sub serialize_mq_list ($$) {
  my ($self, $list) = @_;
  return join ', ', map { $self->serialize_mq ($_) } @$list;
} # serialize_mq_list

sub serialize_mq ($$) {
  my ($self, $mq) = @_;
  my @result;

  if (defined $mq->{type}) {
    push @result, join ' ',
        ($mq->{not} ? 'not' : ()),
        ($mq->{only} ? 'only' : ()),
        _ident ($mq->{type});
  }

  for (@{$mq->{features}}) {
    if (defined $_->{value}) {
      push @result, '(' . $_->{name} . ': ' . $self->serialize_value ($_->{value}) . ')';
    } else {
      push @result, '(' . $_->{name} . ')';
    }
  }

  return join ' and ', @result;
} # serialize_mq

1;

=head1 LICENSE

Copyright 2008-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
