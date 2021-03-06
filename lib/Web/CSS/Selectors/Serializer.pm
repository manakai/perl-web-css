package Web::CSS::Selectors::Serializer;
use strict;
use warnings;
our $VERSION = '14.0';
push our @ISA, qw(Web::CSS::Selectors::Serializer::_
                  Web::CSS::Values::Serializer);

package Web::CSS::Selectors::Serializer::_;
use Web::CSS::Values::Serializer;
use Web::CSS::Selectors::Parser;

sub serialize_selectors ($$) {
  my ($self, $selectors) = @_;
  my $i = 0;

  ## <http://dev.w3.org/csswg/cssom/#serializing-selectors>.

  my $r = join ", ", map {
    join "", map {
      if (ref $_) {
        my $v = '';
        for (@$_) {
          if ($_->[0] == ELEMENT_SELECTOR) {
            if ($_->[4]) { # prefix wildcard
              $v .= '*|';
            } elsif (defined $_->[3]) { # prefix
              if (length $_->[3]) { # non-default
                $v .= _ident ($_->[3]) . '|';
              }
            } elsif (defined $_->[1] and $_->[1] eq '') { # nsurl
              $v .= '|';
            }
            if ($_->[5]) { # local name wildcard
              $v .= '*';
            } elsif (defined $_->[2]) { # local name
              $v .= _ident ($_->[2]);
            }
          } elsif ($_->[0] == ATTRIBUTE_SELECTOR) {
            $v .= '[';
            if (defined $_->[1]) {
              if ($_->[1] eq '') {
                #$v .= '|';
              } else {
                if (defined $_->[5] and length $_->[5]) {
                  $v .= _ident ($_->[5]) . '|';
                } else { # error
                  #$v .= '';
                }
              }
            } else {
              $v .= '*|';
            }
            $v .= _ident ($_->[2]) .
            ($_->[3] != EXISTS_MATCH ?
              {EQUALS_MATCH, '=',
               INCLUDES_MATCH, '~=',
               DASH_MATCH, '|=',
               PREFIX_MATCH, '^=',
               SUFFIX_MATCH, '$=',
               SUBSTRING_MATCH, '*='}->{$_->[3]} .
              _string ($_->[4])
            : '') .
            ']';
          } elsif ($_->[0] == CLASS_SELECTOR) {
            $v .= '.' . _ident ($_->[1]);
          } elsif ($_->[0] == ID_SELECTOR) {
            $v .= '#' . _ident ($_->[1]);
          } elsif ($_->[0] == PSEUDO_CLASS_SELECTOR) {
            my $vv = $_;
            if ($vv->[1] eq 'lang') {
              $v .= ':lang(' . _ident ($vv->[2]) . ')';
            } elsif ($vv->[1] eq 'not') {
              $v .= ":not(" . $self->serialize_selectors ($vv->[2]) . ")";
            } elsif ({'nth-child' => 1,
                      'nth-last-child' => 1,
                      'nth-of-type' => 1,
                      'nth-last-of-type' => 1}->{$vv->[1]}) {
              $v .= ':' . _ident ($vv->[1]) . '(';
              {
                ## <http://dev.w3.org/csswg/css-syntax/#serializing-anb>.
                my $a = _number $vv->[2];
                my $b = _number $vv->[3];
                if ($a eq '0') {
                  $v .= $b;
                } elsif ($b eq '0') {
                  $v .= $a . 'n';
                } else {
                  $v .= $a . 'n' . ($b > 0 ? '+' : '') . $b;
                }
              }
              $v .= ')';
            } elsif ($vv->[1] eq '-manakai-contains') {
              $v .= ':-manakai-contains(' . _string ($vv->[2]) . ')';
            } else {
              $v .= ':' . _ident ($vv->[1]);
            }
          } elsif ($_->[0] == PSEUDO_ELEMENT_SELECTOR) {
            if ($_->[1] eq 'cue' and defined $_->[2]) {
              $v .= '::' . _ident ($_->[1]) . '(' . $self->serialize_selectors ($_->[2]) . ')';
            } else {
              $v .= '::' . _ident ($_->[1]);
            }
          } else {
            die "Unknown simple selector type |$_->[0]|";
          }
        }
        $v;
      } else { # not ref $_
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
