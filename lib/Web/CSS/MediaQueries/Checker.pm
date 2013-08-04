package Web::CSS::MediaQueries::Checker;
use strict;
use warnings;
our $VERSION = '1.0';

sub new ($) {
  return bless {}, $_[0];
} # new

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub { warn join "\t", @_, "\n" };
} # onerror

sub check_mq_list ($$) {
  my ($self, $list) = @_;

  for (@$list) {
    $self->check_mq ($_);
  }
} # check_mq_list

my $ValidMediaTypes = {
  all => 1,

  braille => 1,
  handheld => 1,
  print => 1,
  projection => 1,
  screen => 1,
  tty => 1,
  tv => 1,

  aural => 0.5,

  embossed => 1,
  speech => 1,

  'atsc-tv' => 0,
  'dde-tv' => 0,
  'dvb-tv' => 0,
  emboss => 0,
  dark => 0,
  light => 0,
  emacs => 0,
  xemacs => 0,
  oxygen => 0,
  csshttprequest => 0,
  unknown => 0,
}; # $ValidMediaTypes

sub check_mq ($$) {
  my ($self, $mq) = @_;
  
  if (defined $mq->{type}) {
    my $valid = $ValidMediaTypes->{$mq->{type}};
    if ($valid and $valid >= 1) {
      #
    } elsif ($valid) {
      $self->onerror->(type => 'mq:type:deprecated', # XXX
                       level => 'w',
                       line => $mq->{type_line}, column => $mq->{type_column});
    } else {
      $self->onerror->(type => 'unknown media type',
                       level => 'w',
                       line => $mq->{type_line}, column => $mq->{type_column});
    }
  }

  # XXX
} # check_mq

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
