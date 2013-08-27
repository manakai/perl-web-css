package Web::CSS::Selectors::Serializer;
use strict;
use warnings;
our $VERSION = '12.0';
use Web::CSS::Values::Serializer;
push our @ISA, qw(Web::CSS::Selectors::Serializer::_
                  Web::CSS::Values::Serializer);

package Web::CSS::Selectors::Serializer::_;
use Web::CSS::Selectors::Parser;

sub serialize_selectors ($$) {
  my ($self, $selectors) = @_;
  my $i = 0;
  my $ident = sub { $_[0] };
  my $str = sub { '"' . $_[0] . '"' };
  my $nsmap = $self->context; # XXX

  ## NOTE: See <http://suika.fam.cx/gate/2005/sw/namespace> for browser
  ## implementation issues.

  my $r = join ", ", map {
    join "", map {
      if (ref $_) {
        my $ns_selector;
        my $ln_selector;
        my $ss = [];
        for my $s (@$_) {
          if ($s->[0] == NAMESPACE_SELECTOR) {
            $ns_selector = $s;
          } elsif ($s->[0] == LOCAL_NAME_SELECTOR) {
            $ln_selector = $s;
          } else {
            push @$ss, $s;
          }
        }
        
        my $v = '';
        if (not defined $ns_selector) {
          $v .= '*|' if $nsmap->{has_namespace} and
              (not @$ss or defined $ln_selector);
        } elsif (defined $ns_selector->[1]) {
          if (defined $ns_selector->[2] and length $ns_selector->[2]) {
            $v .= $ident->($ns_selector->[2]) . '|';
          } elsif (defined $ns_selector->[2]) { # default namespace
            #$v .= '';
          } else { # error
            #$v .= '';
          }
        } else {
          $v .= '|';
        }

        if (defined $ln_selector) {
          $v .= $ident->($ln_selector->[1]);
        } else {
          $v .= '*' if not @$ss or length $v;
        }

        for (@$ss) {
          if ($_->[0] == ATTRIBUTE_SELECTOR) {
            $v .= '[';
            if (defined $_->[1]) {
              if ($_->[1] eq '') {
                #$v .= '|';
              } else {
                if (defined $_->[5] and length $_->[5]) {
                  $v .= $ident->($_->[5]) . '|';
                } else { # error
                  #$v .= '';
                }
              }
            } else {
              $v .= '*|';
            }
            $v .= $ident->($_->[2]) .
            ($_->[3] != EXISTS_MATCH ?
              {EQUALS_MATCH, '=',
               INCLUDES_MATCH, '~=',
               DASH_MATCH, '|=',
               PREFIX_MATCH, '^=',
               SUFFIX_MATCH, '$=',
               SUBSTRING_MATCH, '*='}->{$_->[3]} .
              $str->($_->[4])
            : '') .
            ']';
          } elsif ($_->[0] == CLASS_SELECTOR) {
            $v .= '.' . $ident->($_->[1]);
          } elsif ($_->[0] == ID_SELECTOR) {
            $v .= '#' . $ident->($_->[1]);
          } elsif ($_->[0] == PSEUDO_CLASS_SELECTOR) {
            my $vv = $_;
            if ($vv->[1] eq 'lang') {
              ':lang(' . $ident->($vv->[2]) . ')';
            } elsif ($vv->[1] eq 'not') {
              my $vvv = $self->serialize_selectors ($vv->[2]);
              $vvv =~ s/^\*\|\*(?!$)//;
              $v .= ":not(" . $vvv . ")";
            } elsif ({'nth-child' => 1,
                      'nth-last-child' => 1,
                      'nth-of-type' => 1,
                      'nth-last-of-type' => 1}->{$vv->[1]}) {
              ## TODO: We should copy what new versions of browsers do.
              $v .= ':' . $ident->($vv->[1]) . '(' .
                  ($vv->[2] . 'n' .
                  ($vv->[3] < 0 ? $vv->[3] : '+' . $vv->[3])) . ')';
            } elsif ($vv->[1] eq '-manakai-contains') {
              $v .= ':-manakai-contains(' . $str->($vv->[2]) . ')';
            } else {
              $v .= ':' . $ident->($vv->[1]);
            }
          } elsif ($_->[0] == PSEUDO_ELEMENT_SELECTOR) {
            if ({
              after => 1, before => 1, 'first-letter' => 1, 'first-line' => 1,
            }->{$_->[1]}) {
              $v .= ':' . $ident->($_->[1]);
            } else {
              $v .= '::' . $ident->($_->[1]);
            }
          }
          ## NOTE: else ... impl error

        }
        $v;
      } else {
        {
          DESCENDANT_COMBINATOR, ' ',
          CHILD_COMBINATOR, ' > ',
          ADJACENT_SIBLING_COMBINATOR, ' + ',
          GENERAL_SIBLING_COMBINATOR, ' ~ ',
        }->{$_};
      }
    } @$_[1..$#$_];
  } @$selectors;  

  return $r;
} # serialize_selectors

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
