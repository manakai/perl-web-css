use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::CSS::MediaResolver;

test {
  my $c = shift;
  my $ctx = Web::CSS::MediaResolver->new;

  my $value = ['RGBA', 1000, -24, 40.5, 10.2];
  my $value2 = $ctx->clip_color ($value);
  isnt $value2, $value;
  eq_or_diff $value2, ['RGBA', 255, 0, 40.5, 10.2];

  done $c;
} n => 2, name => 'clip_color';

test {
  my $c = shift;
  my $ctx = Web::CSS::MediaResolver->new;

  my $value = ['notRGBA', 1000, -24, 40.5, 10.2];
  my $value2 = $ctx->clip_color ($value);
  is $value2, $value;

  done $c;
} n => 1, name => 'clip_color not rgba';

test {
  my $c = shift;
  my $ctx = Web::CSS::MediaResolver->new;

  my $value = {hoge => 'abc'};
  my $value2 = $ctx->get_system_font ($value);
  is $value, $value;

  done $c;
} n => 1, name => 'get_system_font';

test {
  my $c = shift;
  my $mr = Web::CSS::MediaResolver->new;
  $mr->set_supported (all => 1);

  my @longhand = qw/
    alignment-baseline
    background-attachment background-color background-image
    background-position-x background-position-y
    background-repeat border-bottom-color
    border-bottom-style border-bottom-width border-collapse
    border-left-color
    border-left-style border-left-width border-right-color
    border-right-style border-right-width
    -manakai-border-spacing-x -manakai-border-spacing-y
    border-top-color border-top-style border-top-width bottom
    caption-side clear clip color content counter-increment counter-reset
    cursor direction display dominant-baseline empty-cells float
    font-family font-size font-size-adjust font-stretch
    font-style font-variant font-weight height left
    letter-spacing line-height
    list-style-image list-style-position list-style-type
    margin-bottom margin-left margin-right margin-top marker-offset
    marks max-height max-width min-height min-width opacity -moz-opacity
    orphans outline-color outline-style outline-width overflow-x overflow-y
    padding-bottom padding-left padding-right padding-top
    page page-break-after page-break-before page-break-inside
    position quotes right size table-layout
    text-align text-anchor text-decoration text-indent text-transform
    top unicode-bidi vertical-align visibility white-space width widows
    word-spacing writing-mode z-index
  /;
  my @shorthand = qw/
    background background-position
    border border-color border-style border-width border-spacing
    border-top border-right border-bottom border-left
    font list-style margin outline overflow padding
  /;

  for (@longhand, @shorthand) {
    ok $mr->{prop}->{$_};
  }
  
  done $c;
} name => 'set_supported prop names';

test {
  my $c = shift;
  my $mr = Web::CSS::MediaResolver->new;
  $mr->set_supported (all => 1);

  ok $mr->{prop_value}->{display}->{$_} for qw/
    block inline inline-block inline-table list-item none
    table table-caption table-cell table-column table-column-group
    table-header-group table-footer-group table-row table-row-group
    compact marker
  /;
  ok $mr->{prop_value}->{position}->{$_} for qw/
    absolute fixed relative static
  /;
  for (qw/-moz-max-content -moz-min-content -moz-fit-content -moz-available/) {
    ok $mr->{prop_value}->{width}->{$_};
    ok $mr->{prop_value}->{'min-width'}->{$_};
    ok $mr->{prop_value}->{'max-width'}->{$_};
  }
  ok $mr->{prop_value}->{float}->{$_} for qw/
    left right none
  /;
  ok $mr->{prop_value}->{clear}->{$_} for qw/
    left right none both
  /;
  ok $mr->{prop_value}->{direction}->{ltr}, 'direction: ltr';
  ok $mr->{prop_value}->{direction}->{rtl};
  ok $mr->{prop_value}->{marks}->{crop};
  ok $mr->{prop_value}->{marks}->{cross};
  ok $mr->{prop_value}->{'unicode-bidi'}->{$_} for qw/
    normal bidi-override embed
  /;
  for my $prop_name (qw/overflow overflow-x overflow-y/) {
    ok $mr->{prop_value}->{$prop_name}->{$_} for qw/
      visible hidden scroll auto -webkit-marquee -moz-hidden-unscrollable
    /;
  }
  ok $mr->{prop_value}->{visibility}->{$_} for qw/
    visible hidden collapse
  /;
  ok $mr->{prop_value}->{'list-style-type'}->{$_}, ['line-style-type', $_] for qw/
    disc circle square decimal decimal-leading-zero
    lower-roman upper-roman lower-greek lower-latin
    upper-latin armenian georgian lower-alpha upper-alpha none
    hebrew cjk-ideographic hiragana katakana hiragana-iroha
    katakana-iroha
  /;
  ok $mr->{prop_value}->{'list-style-position'}->{outside};
  ok $mr->{prop_value}->{'list-style-position'}->{inside};
  ok $mr->{prop_value}->{'page-break-before'}->{$_} for qw/
    auto always avoid left right
  /;
  ok $mr->{prop_value}->{'page-break-after'}->{$_} for qw/
    auto always avoid left right
  /;
  ok $mr->{prop_value}->{'page-break-inside'}->{auto};
  ok $mr->{prop_value}->{'page-break-inside'}->{avoid};
  ok $mr->{prop_value}->{'background-repeat'}->{$_} for qw/
    repeat repeat-x repeat-y no-repeat
  /;
  ok $mr->{prop_value}->{'background-attachment'}->{scroll};
  ok $mr->{prop_value}->{'background-attachment'}->{fixed};
  ok $mr->{prop_value}->{'font-size'}->{$_} for qw/
    xx-small x-small small medium large x-large xx-large
    -manakai-xxx-large -webkit-xxx-large
    larger smaller
  /;
  ok $mr->{prop_value}->{'font-style'}->{normal};
  ok $mr->{prop_value}->{'font-style'}->{italic};
  ok $mr->{prop_value}->{'font-style'}->{oblique};
  ok $mr->{prop_value}->{'font-variant'}->{normal};
  ok $mr->{prop_value}->{'font-variant'}->{'small-caps'};
  ok $mr->{prop_value}->{'font-stretch'}->{$_} for
      qw/normal wider narrower ultra-condensed extra-condensed
        condensed semi-condensed semi-expanded expanded
        extra-expanded ultra-expanded/;
  ok $mr->{prop_value}->{'text-align'}->{$_} for qw/
    left right center justify begin end
  /;
  ok $mr->{prop_value}->{'text-transform'}->{$_} for qw/
    capitalize uppercase lowercase none
  /;
  ok $mr->{prop_value}->{'white-space'}->{$_}, ['white-space', $_] for qw/
    normal pre nowrap pre-line pre-wrap -moz-pre-wrap
  /;
  ok $mr->{prop_value}->{'writing-mode'}->{$_} for qw/
    lr rl tb lr-tb rl-tb tb-rl
  /;
  ok $mr->{prop_value}->{'text-anchor'}->{$_} for qw/
    start middle end
  /;
  ok $mr->{prop_value}->{'dominant-baseline'}->{$_} for qw/
    auto use-script no-change reset-size ideographic alphabetic
    hanging mathematical central middle text-after-edge text-before-edge
  /;
  ok $mr->{prop_value}->{'alignment-baseline'}->{$_} for qw/
    auto baseline before-edge text-before-edge middle central
    after-edge text-after-edge ideographic alphabetic hanging
    mathematical
  /;
  ok $mr->{prop_value}->{'text-decoration'}->{$_} for qw/
    none blink underline overline line-through
  /;
  ok $mr->{prop_value}->{'caption-side'}->{$_} for qw/
    top bottom left right
  /;
  ok $mr->{prop_value}->{'table-layout'}->{auto}, 'table-layout: auto';
  ok $mr->{prop_value}->{'table-layout'}->{fixed};
  ok $mr->{prop_value}->{'border-collapse'}->{collapse};
  ok $mr->{prop_value}->{'border-collapse'}->{separate};
  ok $mr->{prop_value}->{'empty-cells'}->{show};
  ok $mr->{prop_value}->{'empty-cells'}->{hide};
  ok $mr->{prop_value}->{cursor}->{$_} for qw/
    auto crosshair default pointer move e-resize ne-resize nw-resize n-resize
    se-resize sw-resize s-resize w-resize text wait help progress
  /;
  for my $prop (qw/border-top-style border-left-style
                   border-bottom-style border-right-style/) {
    ok $mr->{prop_value}->{$prop}->{$_}, [$prop, $_] for qw/
      none hidden dotted dashed solid double groove ridge inset outset
    /;
  }
  for my $prop (qw/outline-style/) {
    ok $mr->{prop_value}->{$prop}->{$_}, [$prop, $_] for qw/
      none dotted dashed solid double groove ridge inset outset
    /;
  }
  for my $prop (qw/color background-color
                   border-bottom-color border-left-color border-right-color
                   border-top-color/) {
    ok $mr->{prop_value}->{$prop}->{transparent};
    ok $mr->{prop_value}->{$prop}->{flavor};
    ok $mr->{prop_value}->{$prop}->{'-manakai-default'};
  }
  ok $mr->{prop_value}->{'outline-color'}->{invert};
  ok $mr->{prop_value}->{'outline-color'}->{'-manakai-invert-or-currentcolor'};
  done $c;
} name => 'set_supported prop values';

test {
  my $c = shift;
  my $mr = Web::CSS::MediaResolver->new;
  $mr->set_supported (all_pseudo_classes => 1);
  ok $mr->{pseudo_class}->{$_} for qw/
    active checked disabled empty enabled first-child first-of-type
    focus hover indeterminate last-child last-of-type link only-child
    only-of-type root target visited
    lang nth-child nth-last-child nth-of-type nth-last-of-type not
    -manakai-contains -manakai-current
  /;
  done $c;
} name => 'set_supported pseudo-classes';

test {
  my $c = shift;
  my $mr = Web::CSS::MediaResolver->new;
  $mr->set_supported (all_pseudo_elements => 1);
  ok $mr->{pseudo_element}->{$_} for qw/
    after before first-letter first-line
  /;
  done $c;
} name => 'set_supported pseudo-elements';

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
