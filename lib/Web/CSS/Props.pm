package Web::CSS::Props;
use strict;
use warnings;
our $VERSION = '7.0';
use Web::CSS::Builder;
use Web::CSS::Colors;
use Web::CSS::Values;

## Property definition
##
##     css                 CSS property name (lowercase, canonical)
##     dom                 DOM Perl binding method name (canonical)
##     key                 Internal property key
##     is_shorthand        Whether it is a shorthand property
##     longhand_subprops   List of keys of longhand sub-properties,
##                         in canonical order
##     shorthand_keys      Reference to the shorthand properties,
##                         in preferred order [CSSOM]
##     parse_longhand      Longhand property value parser
##     parse_shorthand     Shorthand property parser
##     keyword             Available keywords (key = lowercased, value = 1)
##     serialize_shorthand Shorthand property value serializer

our $Prop; ## By CSS property name
our $Attr; ## By CSSOM attribute name
our $Key; ## By internal key

my $GetBoxShorthandParser = sub {
  my $Def = $_[0];
  my $Props = $Def->{longhand_subprops};
  return sub {
    my ($self, $def, $tokens) = @_;
    $tokens = [grep { not $_->{type} == S_TOKEN } @$tokens];
    if (@$tokens == 5) { # $tokens->[-1] is EOF_TOKEN
      my $v1 = $Key->{$Props->[0]}->{parse_longhand}->($self, [$tokens->[0], _to_eof_token $tokens->[1]]);
      my $v2 = defined $v1 ? $Key->{$Props->[1]}->{parse_longhand}->($self, [$tokens->[1], _to_eof_token $tokens->[2]]) : undef;
      my $v3 = defined $v2 ? $Key->{$Props->[2]}->{parse_longhand}->($self, [$tokens->[2], _to_eof_token $tokens->[3]]) : undef;
      my $v4 = defined $v3 ? $Key->{$Props->[3]}->{parse_longhand}->($self, [$tokens->[3], _to_eof_token $tokens->[4]]) : undef;
      return undef unless defined $v4;
      return {$Props->[0] => $v1,
              $Props->[1] => $v2,
              $Props->[2] => $v3,
              $Props->[3] => $v4};
    } elsif (@$tokens == 4) {
      my $v1 = $Key->{$Props->[0]}->{parse_longhand}->($self, [$tokens->[0], _to_eof_token $tokens->[1]]);
      my $v2 = defined $v1 ? $Key->{$Props->[1]}->{parse_longhand}->($self, [$tokens->[1], _to_eof_token $tokens->[2]]) : undef;
      my $v3 = defined $v2 ? $Key->{$Props->[2]}->{parse_longhand}->($self, [$tokens->[2], _to_eof_token $tokens->[3]]) : undef;
      return undef unless defined $v3;
      return {$Props->[0] => $v1,
              $Props->[1] => $v2,
              $Props->[2] => $v3,
              $Props->[3] => $v2};
    } elsif (@$tokens == 3) {
      my $v1 = $Key->{$Props->[0]}->{parse_longhand}->($self, [$tokens->[0], _to_eof_token $tokens->[1]]);
      my $v2 = defined $v1 ? $Key->{$Props->[1]}->{parse_longhand}->($self, [$tokens->[1], _to_eof_token $tokens->[2]]) : undef;
      return undef unless defined $v2;
      return {$Props->[0] => $v1,
              $Props->[1] => $v2,
              $Props->[2] => $v1,
              $Props->[3] => $v2};
    } elsif (@$tokens == 2) {
      my $v1 = $Key->{$Props->[0]}->{parse_longhand}->($self, [$tokens->[0], _to_eof_token $tokens->[1]]);
      return undef unless defined $v1;
      return {$Props->[0] => $v1,
              $Props->[1] => $v1,
              $Props->[2] => $v1,
              $Props->[3] => $v1};
    } else {
      $self->onerror->(type => 'CSS syntax error', text => "'$Def->{css}'",
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $tokens->[0]);
      return undef;
    }
  };
}; # $GetBoxShorthandParser

my $GetBoxShorthandSerializer = sub {
  my $Def = $_[0];
  my $Props = $Def->{longhand_subprops};
  return sub {
    my ($se, $strings) = @_;

    my $v1 = $strings->{$Props->[0]};
    my $v2 = $strings->{$Props->[1]};
    my $v3 = $strings->{$Props->[2]};
    my $v4 = $strings->{$Props->[3]};

    if ($v2 eq $v4) {
      if ($v1 eq $v3) {
        if ($v1 eq $v2) {
          return $v1;
        } else {
          return "$v1 $v2";
        }
      } else {
        return "$v1 $v2 $v3";
      }
    } else {
      return "$v1 $v2 $v3 $v4";
    }
  };
}; # $GetBoxShorthandSerializer

my $compute_as_specified = sub ($$$$) {
  #my ($self, $element, $prop_name, $specified_value) = @_;
  return $_[3];
}; # $compute_as_specified

## <http://dev.w3.org/csswg/css-color/#foreground> [CSSCOLOR],
## <http://quirks.spec.whatwg.org/#the-hashless-hex-color-quirk>
## [QUIRKS].
$Key->{color} = {
  css => 'color',
  dom => 'color',
  parse_longhand => $Web::CSS::Values::ColorOrQuirkyColorParser,
  keyword => { # for Web::CSS::MediaResolver
    transparent => 1,
    flavor => 1,
  },
  initial => ['KEYWORD', '-manakai-default'],
  inherited => 1,
  compute => sub ($$$$) {
    my ($self, $element, $prop_name, $specified_value) = @_;

    if (defined $specified_value) {
      if ($specified_value->[0] eq 'KEYWORD') {
        if ($Web::CSS::Colors::X11Colors->{$specified_value->[1]}) {
          return ['RGBA', @{$Web::CSS::Colors::X11Colors->{$specified_value->[1]}}, 1];
        } elsif ($specified_value->[1] eq 'transparent') {
          return ['RGBA', 0, 0, 0, 0];
        } elsif ($specified_value->[1] eq 'currentcolor' or
                 ($specified_value->[1] eq '-manakai-invert-or-currentcolor'and
                  not $self->{has_invert})) {
          unless ($prop_name eq 'color') {
            return $self->get_computed_value ($element, 'color');
          } else {
            ## NOTE: This is an error, since it should have been
            ## converted to 'inherit' at parse time.
            ## NOTE: 'color: -manakai-invert-or-currentcolor' is not allowed.
            return ['KEYWORD', '-manakai-default'];
          }
        } elsif ($specified_value->[1] eq '-manakai-invert-or-currentcolor') {
          return ['KEYWORD', 'invert'];
        }
      }
    }
    
    return $specified_value;
  },
}; # color

## <http://dev.w3.org/csswg/css-backgrounds/#the-background-color>
## [CSSBACKGROUNDS],
## <http://quirks.spec.whatwg.org/#the-hashless-hex-color-quirk>
## [QUIRKS].
$Key->{background_color} = {
  css => 'background-color',
  dom => 'background_color',
  parse_longhand => $Web::CSS::Values::ColorOrQuirkyColorParser,
  initial => ['KEYWORD', 'transparent'],
  #inherited => 0,
  compute => $Key->{color}->{compute},
}; # background-color

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-color>
## [CSSBACKGROUNDS],
## <http://quirks.spec.whatwg.org/#the-hashless-hex-color-quirk>
## [QUIRKS].
$Key->{border_top_color} = {
  css => 'border-top-color',
  dom => 'border_top_color',
  parse_longhand => $Web::CSS::Values::ColorOrQuirkyColorParser,
  shorthand_keys => [qw(border border_color border_top)],
  initial => ['KEYWORD', 'currentcolor'],
  #inherited => 0,
  compute => $Key->{color}->{compute},
}; # border-top-color

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-color>
## [CSSBACKGROUNDS],
## <http://quirks.spec.whatwg.org/#the-hashless-hex-color-quirk>
## [QUIRKS].
$Key->{border_right_color} = {
  css => 'border-right-color',
  dom => 'border_right_color',
  parse_longhand => $Web::CSS::Values::ColorOrQuirkyColorParser,
  shorthand_keys => [qw(border border_color border_right)],
  initial => ['KEYWORD', 'currentcolor'],
  #inherited => 0,
  compute => $Key->{color}->{compute},
}; # border-right-color

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-color>
## [CSSBACKGROUNDS],
## <http://quirks.spec.whatwg.org/#the-hashless-hex-color-quirk>
## [QUIRKS].
$Key->{border_bottom_color} = {
  css => 'border-bottom-color',
  dom => 'border_bottom_color',
  parse_longhand => $Web::CSS::Values::ColorOrQuirkyColorParser,
  shorthand_keys => [qw(border border_color border_bottom)],
  initial => ['KEYWORD', 'currentcolor'],
  #inherited => 0,
  compute => $Key->{color}->{compute},
}; # border-bottom-color

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-color>
## [CSSBACKGROUNDS],
## <http://quirks.spec.whatwg.org/#the-hashless-hex-color-quirk>
## [QUIRKS].
$Key->{border_left_color} = {
  css => 'border-left-color',
  dom => 'border_left_color',
  parse_longhand => $Web::CSS::Values::ColorOrQuirkyColorParser,
  shorthand_keys => [qw(border border_color border_left)],
  initial => ['KEYWORD', 'currentcolor'],
  #inherited => 0,
  compute => $Key->{color}->{compute},
}; # border-left-color

## <http://dev.w3.org/csswg/css-ui/#outline-color> [CSSUI], [MANAKAICSS].
$Key->{outline_color} = {
  css => 'outline-color',
  dom => 'outline_color',
  parse_longhand => $Web::CSS::Values::OutlineColorParser,
  keyword => { # for Web::CSS::MediaResolver
    invert => 1,
  },
  initial => ['KEYWORD', '-manakai-invert-or-currentcolor'],
  #inherited => 0,
  compute => $Key->{color}->{compute},
}; # outline-color

## <http://dev.w3.org/csswg/css-display/#display> [CSSDISPLAY],
## <http://www.w3.org/TR/1998/REC-CSS2-19980512/visuren.html#display-prop>
## [CSS20].
$Key->{display} = {
  css => 'display',
  dom => 'display',
  keyword => {
    inline => 1, block => 1, 'list-item' => 1, #'inline-list-item' => 1,
    'inline-block' => 1, table => 1, 'inline-table' => 1,
    'table-cell' => 1, 'table-caption' => 1, #flex => 1, 'inline-flex' => 1,
    #grid => 1, 'inline-grid' => 1,

    ## <display-inside>
    #auto => 1,

    ## <display-outside>
    #'block-level' => 1, 'inline-level' => 1,
    none => 1,
    'table-row-group' => 1, 'table-header-group' => 1,
    'table-footer-group' => 1, 'table-row' => 1, 'table-column-group' => 1,
    'table-column' => 1,

    ## <display-extras>
    #
    
    ## CSS 2.0
    'run-in' => 1, compact => 1, marker => 1,
  },
  initial => ["KEYWORD", "inline"],
  #inherited => 0,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;
    ## NOTE: CSS 2.1 Section 9.7.

    ## WARNING: |compute| for 'float' property invoke this CODE
    ## in some case.  Careless modification might cause a infinite loop.

    if (defined $specified_value and $specified_value->[0] eq 'KEYWORD') {
      if ($specified_value->[1] eq 'none') {
        ## Case 1 [CSS 2.1]
        return $specified_value;
      } else {
        my $position = $self->get_computed_value ($element, 'position');
        if ($position->[0] eq 'KEYWORD' and 
            ($position->[1] eq 'absolute' or 
             $position->[1] eq 'fixed')) {
          ## Case 2 [CSS 2.1]
          #
        } else {
          my $float = $self->get_computed_value ($element, 'float');
          if ($float->[0] eq 'KEYWORD' and $float->[1] ne 'none') {
            ## Caes 3 [CSS 2.1]
            #
          } elsif (not defined $element->manakai_parent_element) {
            ## Case 4 [CSS 2.1]
            #
          } elsif ($specified_value->[1] eq 'marker') {
            ## TODO: If ::after or ::before, then 'marker'.  Otherwise,
            return ['KEYWORD', 'inline'];
          } else {
            ## Case 5 [CSS 2.1]
            return $specified_value;
          }
        }
        
        return ["KEYWORD",
                {
                 'inline-table' => 'table',
                 inline => 'block',
                 'run-in' => 'block',
                 'table-row-group' => 'block',
                 'table-column' => 'block',
                 'table-column-group' => 'block',
                 'table-header-group' => 'block',
                 'table-footer-group' => 'block',
                 'table-row' => 'block',
                 'table-cell' => 'block',
                 'table-caption' => 'block',
                 'inline-block' => 'block',

                 ## NOTE: Not in CSS 2.1, but maybe...
                 compact => 'block',
                 marker => 'block',
                }->{$specified_value->[1]} || $specified_value->[1]];
      }
    } else {
      return $specified_value; ## Maybe an error of the implementation.
    }
  },
}; # display

## <http://dev.w3.org/csswg/css-position/#position-property>
## [CSSPOSITION].
$Key->{position} = {
  css => 'position',
  dom => 'position',
  keyword => {
    static => 1, relative => 1, absolute => 1, fixed => 1,
    #center => 1, page => 1,
  },
  initial => ["KEYWORD", "static"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # position

## <http://dev.w3.org/csswg/css-box/#the-float-property> [CSSBOX].
$Key->{float} = {
  css => 'float',
  dom => 'float',
  key => 'float',
  keyword => {
    left => 1, right => 1, none => 1,
    #top => 1, bottom => 1, start => 1, end => 1,
  },
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;
    ## NOTE: CSS 2.1 Section 9.7.

    ## WARNING: |compute| for 'display' property invoke this CODE
    ## in some case.  Careless modification might cause a infinite loop.
    
    if (defined $specified_value and $specified_value->[0] eq 'KEYWORD') {
      if ($specified_value->[1] eq 'none') {
        ## Case 1 [CSS 2.1]
        return $specified_value;
      } else {
        my $position = $self->get_computed_value ($element, 'position');
        if ($position->[0] eq 'KEYWORD' and 
            ($position->[1] eq 'absolute' or 
             $position->[1] eq 'fixed')) {
          ## Case 2 [CSS 2.1]
          return ["KEYWORD", "none"];
        }
      }
    }

    ## ISSUE: CSS 2.1 section 9.7 and 9.5.1 ('float' definition) disagree
    ## on computed value of 'float' property.
    
    ## Case 3, 4, and 5 [CSS 2.1]
    return $specified_value;
  },
}; # float
$Attr->{css_float} = $Key->{float};

## <http://dev.w3.org/csswg/css-box/#the-clear-property> [CSSBOX].
$Key->{clear} = {
  css => 'clear',
  dom => 'clear',
  keyword => {
    left => 1, right => 1, none => 1, both => 1,
  },
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # clear

## <http://dev.w3.org/csswg/css-writing-modes/#direction>
## [CSSWRITINGMODES].
$Key->{direction} = {
  css => 'direction',
  dom => 'direction',
  keyword => {
    ltr => 1, rtl => 1,
  },
  initial => ["KEYWORD", "ltr"],
  inherited => 1,
  compute => $compute_as_specified,
}; # direction

## <http://dev.w3.org/csswg/css-writing-modes/#unicode-bidi>
## [CSSWRITINGMODES].
$Key->{unicode_bidi} = {
  css => 'unicode-bidi',
  dom => 'unicode_bidi',
  keyword => {
    normal => 1, embed => 1, 'bidi-override' => 1,
    isolate => 1, 'isolate-override' => 1, plaintext => 1,
  },
  initial => ["KEYWORD", "normal"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # unicode-bidi

## <http://dev.w3.org/csswg/css-overflow/#overflow-properties>
## [CSSOVERFLOW].
$Key->{overflow_x} = {
  css => 'overflow-x',
  dom => 'overflow_x',
  keyword => {
    visible => 1, hidden => 1, scroll => 1, auto => 1,
    '-moz-hidden-unscrollable' => 1,
    # paged-x paged-y paged-x-controls paged-y-controls fragments
  },
  initial => ["KEYWORD", "visible"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # overflow-x

## <http://dev.w3.org/csswg/css-overflow/#overflow-properties>
## [CSSOVERFLOW].
$Key->{overflow_y} = {
  css => 'overflow-y',
  dom => 'overflow_y',
  keyword => $Key->{overflow_x}->{keyword},
  initial => ["KEYWORD", "visible"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # overflow-y

## <http://dev.w3.org/csswg/css-overflow/#overflow-properties>
## [CSSOVERFLOW].
$Key->{overflow} = {
  css => 'overflow',
  dom => 'overflow',
  is_shorthand => 1,
  longhand_subprops => [qw(overflow_x overflow_y)],
  parse_shorthand => sub {
    my ($self, $def, $tokens) = @_;
    my $value = $Key->{overflow_x}->{parse_longhand}->($self, $tokens);
    if (defined $value) {
      return {overflow_x => $value, overflow_y => $value};
    } else {
      return undef;
    }
  }, # parse_shorthand
  serialize_shorthand => sub {
    my ($se, $strings) = @_;
    if ($strings->{overflow_x} eq $strings->{overflow_y}) {
      return $strings->{overflow_x};
    } else {
      return undef;
    }
  }, # serialize_shorthand
}; # overflow

## <http://dev.w3.org/csswg/css-box/#the-visibility-property>
## [CSSBOX].
$Key->{visibility} = {
  css => 'visibility',
  dom => 'visibility',
  keyword => {
    visible => 1, hidden => 1, collapse => 1,
  },
  initial => ["KEYWORD", "visible"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # visibility

## <http://dev.w3.org/csswg/css-lists/#list-style-type> [CSSLISTS],
## <http://dev.w3.org/csswg/css-counter-styles/> [CSSCOUNTERSTYLES].
$Key->{list_style_type} = {
  css => 'list-style-type',
  dom => 'list_style_type',
  keyword => {
    map { $_ => 1 } qw(
      none

      decimal decimal-leading-zero cjk-decimal lower-roman upper-roman
      armenian georgian hebrew

      lower-alpha lower-latin upper-alpha upper-latin lower-greek
      hiragana hiragana-iroha katakana katakana-iroha

      disc circle square disclosure-open disclosure-closed

      japanese-informal japanese-formal korean-hangul-formal
      korean-hanja-informal korean-hanja-formal simp-chinese-informal
      simp-chinese-formal trad-chinese-informal trad-chinese-formal
      cjk-ideographic

      ethiopic-numeric
    )
  },
  initial => ["KEYWORD", 'disc'],
  inherited => 1,
  compute => $compute_as_specified,
}; # list-style-type

## <http://dev.w3.org/csswg/css-lists/#list-style-position-property>
## [CSSLISTS].
$Key->{list_style_position} = {
  css => 'list-style-position',
  dom => 'list_style_position',
  keyword => {
    inside => 1, outside => 1,
  },
  initial => ["KEYWORD", 'outside'],
  inherited => 1,
  compute => $compute_as_specified,
}; # list-style-position

## <http://dev.w3.org/csswg/css-break/#page-break-properties>
## [CSSBREAK].
$Key->{page_break_before} = {
  css => 'page-break-before',
  dom => 'page_break_before',
  keyword => {
    auto => 1, always => 1, avoid => 1, left => 1, right => 1,
  },
  initial => ["KEYWORD", 'auto'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # page-break-before

## <http://dev.w3.org/csswg/css-break/#page-break-properties>
## [CSSBREAK].
$Key->{page_break_after} = {
  css => 'page-break-after',
  dom => 'page_break_after',
  keyword => {
    auto => 1, always => 1, avoid => 1, left => 1, right => 1,
  },
  initial => ["KEYWORD", 'auto'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # page-break-after

## <http://dev.w3.org/csswg/css-break/#page-break-properties>
## [CSSBREAK].
$Key->{page_break_inside} = {
  css => 'page-break-inside',
  dom => 'page_break_inside',
  keyword => {
    auto => 1, avoid => 1,
  },
  initial => ["KEYWORD", 'auto'],
  inherited => 1,
  compute => $compute_as_specified,
}; # page-break-inside

## <http://dev.w3.org/csswg/css-backgrounds/#the-background-repeat>
## [CSSBACKGROUNDS].
$Key->{background_repeat} = {
  css => 'background-repeat',
  dom => 'background_repeat',
  keyword => {
    repeat => 1, 'repeat-x' => 1, 'repeat-y' => 1, 'no-repeat' => 1,
  },
  initial => ["KEYWORD", 'repeat'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # background-repeat

## <http://dev.w3.org/csswg/css-backgrounds/#the-background-attachment>
## [CSSBACKGROUNDS].
$Key->{background_attachment} = {
  css => 'background-attachment',
  dom => 'background_attachment',
  keyword => {
    scroll => 1, fixed => 1,
  },
  initial => ["KEYWORD", 'scroll'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # background-attachment

## <http://dev.w3.org/csswg/css-fonts/#font-style-prop> [CSSFONTS].
$Key->{font_style} = {
  css => 'font-style',
  dom => 'font_style',
  keyword => {
    normal => 1, italic => 1, oblique => 1,
    '-moz-use-system-font' => 1,
  },
  initial => ["KEYWORD", 'normal'],
  inherited => 1,
  compute => $compute_as_specified,
}; # font-style

## <http://dev.w3.org/csswg/css-fonts/#font-rend-desc> [CSSFONTS].
$Key->{font_variant} = {
  css => 'font-variant',
  dom => 'font_variant',
  keyword => {
    normal => 1, 'small-caps' => 1,
    '-moz-use-system-font' => 1,
  },
  initial => ["KEYWORD", 'normal'],
  inherited => 1,
  compute => $compute_as_specified,
}; # font-variant

## <http://dev.w3.org/csswg/css-text/#text-align> [CSSTEXT].
$Key->{text_align} = {
  css => 'text-align',
  dom => 'text_align',
  keyword => {
    left => 1, right => 1, center => 1, justify => 1,
    start => 1, end => 1,
  },
  initial => ["KEYWORD", 'start'],
  inherited => 1,
  compute => $compute_as_specified,
}; # text-align

## <http://dev.w3.org/csswg/css-text/#text-transform> [CSSTEXT].
$Key->{text_transform} = {
  css => 'text-transform',
  dom => 'text_transform',
  keyword => {
    capitalize => 1, uppercase => 1, lowercase => 1, none => 1,
  },
  initial => ["KEYWORD", 'none'],
  inherited => 1,
  compute => $compute_as_specified,
}; # text-transform

## <http://dev.w3.org/csswg/css-text/#white-space> [CSSTEXT].
$Key->{white_space} = {
  css => 'white-space',
  dom => 'white_space',
  keyword => {
    normal => 1, pre => 1, nowrap => 1, 'pre-wrap' => 1, 'pre-line' => 1,
  },
  initial => ["KEYWORD", 'normal'],
  inherited => 1,
  compute => $compute_as_specified,
}; # white-space

## <http://www.w3.org/TR/CSS21/tables.html#propdef-caption-side>
## [CSS21],
## <http://www.w3.org/TR/1998/REC-CSS2-19980512/tables.html#propdef-caption-side>
## [CSS20].
$Key->{caption_side} = {
  css => 'caption-side',
  dom => 'caption_side',
  keyword => {
    top => 1, bottom => 1,

    ## CSS 2
    left => 1, right => 1,
  },
  initial => ['KEYWORD', 'top'],
  inherited => 1,
  compute => $compute_as_specified,
}; # caption-side

## <http://www.w3.org/TR/CSS21/tables.html#width-layout> [CSS21].
$Key->{table_layout} = {
  css => 'table-layout',
  dom => 'table_layout',
  keyword => {
    auto => 1, fixed => 1,
  },
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # table-layout

## <http://www.w3.org/TR/CSS21/tables.html#propdef-border-collapse>
## [CSS21].
$Key->{border_collapse} = {
  css => 'border-collapse',
  dom => 'border_collapse',
  keyword => {
    collapse => 1, separate => 1,
  },
  initial => ['KEYWORD', 'separate'],
  inherited => 1,
  compute => $compute_as_specified,
}; # border-collapse

## <http://www.w3.org/TR/CSS21/tables.html#propdef-empty-cells>
## [CSS21].
$Key->{empty_cells} = {
  css => 'empty-cells',
  dom => 'empty_cells',
  keyword => {
    show => 1, hide => 1,
  },
  initial => ['KEYWORD', 'show'],
  inherited => 1,
  compute => $compute_as_specified,
}; # empty-cells

## <http://dev.w3.org/csswg/css-position/#z-index> [CSSPOSITION].
$Key->{z_index} = {
  css => 'z-index',
  dom => 'z_index',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == NUMBER_TOKEN) {
        if ($us->[0]->{number} =~ /\A[+-]?[0-9]+\z/) {
          return ['NUMBER', 0+$us->[0]->{number}];
        }
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'auto') {
          return ['KEYWORD', $value];
        }
      }
    }
    
    $self->onerror->(type => 'CSS syntax error', text => q['z-index'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # z-index

## <http://dev.w3.org/csswg/css-fonts/#font-size-adjust-prop>
## [CSSFONTS].
$Key->{font_size_adjust} = {
  css => 'font-size-adjust',
  dom => 'font_size_adjust',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == NUMBER_TOKEN) {
        return ['NUMBER', 0+$us->[0]->{number}];
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'none' or $value eq '-moz-use-system-font') {
          return ['KEYWORD', $value];
        }
      }
    }
    
    $self->onerror->(type => 'CSS syntax error', text => q['z-index'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'none'],
  inherited => 1,
  compute => $compute_as_specified,
}; # font-size-adjust

## <http://dev.w3.org/csswg/css-break/#widows-orphans> [CSSBREAK].
$Key->{orphans} = {
  css => 'orphans',
  dom => 'orphans',
  parse_longhand => $Web::CSS::Values::PositiveIntegerParser,
  initial => ['NUMBER', 2],
  inherited => 1,
  compute => $compute_as_specified,
}; # orphans

## <http://dev.w3.org/csswg/css-break/#widows-orphans> [CSSBREAK].
$Key->{widows} = {
  css => 'widows',
  dom => 'widows',
  parse_longhand => $Web::CSS::Values::PositiveIntegerParser,
  initial => ['NUMBER', 2],
  inherited => 1,
  compute => $compute_as_specified,
}; # widows

## <http://dev.w3.org/csswg/css-color/#opacity> [CSSCOLOR].
$Key->{opacity} = {
  css => 'opacity',
  dom => 'opacity',
  parse_longhand => $Web::CSS::Values::NumberParser,
  initial => ['NUMBER', 1],
  #inherited => 0,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    if (defined $specified_value) {
      if ($specified_value->[0] eq 'NUMBER') {
        if ($specified_value->[1] < 0) {
          return ['NUMBER', 0];
        } elsif ($specified_value->[1] > 1) {
          return ['NUMBER', 1];
        }
      }
    }

    return $specified_value;
  },
}; # opacity
$Prop->{'-webkit-opacity'} = $Key->{opacity};
$Attr->{_webkit_opacity} = $Key->{opacity};

my $length_unit = {
  em => 1, ex => 1, px => 1,
  in => 1, cm => 1, mm => 1, pt => 1, pc => 1,
};

my $length_percentage_keyword_parser = sub ($$$$$) {
  my ($self, $prop_name, $tt, $t, $onerror) = @_;

  ## NOTE: Allowed keyword must have true value for $self->{prop_value}->{$_}.

    my $sign = 1;
    my $has_sign;
    if ($t->{type} == MINUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
      $sign = -1;
    } elsif ($t->{type} == PLUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
    }
    my $allow_negative = $Prop->{$prop_name}->{allow_negative};

    if ($t->{type} == DIMENSION_TOKEN) {
      my $value = $t->{number} * $sign;
      my $unit = lc $t->{value}; ## TODO: case
      if ($length_unit->{$unit} and ($allow_negative or $value >= 0)) {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['DIMENSION', $value, $unit]});
      }
    } elsif ($t->{type} == PERCENTAGE_TOKEN) {
      my $value = $t->{number} * $sign;
      if ($allow_negative or $value >= 0) {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['PERCENTAGE', $value]});
      }
    } elsif ($t->{type} == NUMBER_TOKEN and
             ($self->context->quirks or $t->{number} == 0)) {
      my $value = $t->{number} * $sign;
      if ($allow_negative or $value >=0) {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['DIMENSION', $value, 'px']});
      }
    } elsif (not $has_sign and $t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ($Prop->{$prop_name}->{keyword}->{$value}) {
        if ($Prop->{$prop_name}->{keyword}->{$value} == 1 or
            $self->{prop_value}->{$prop_name}->{$value}) {
          $t = $tt->get_next_token;
          return ($t, {$prop_name => ['KEYWORD', $value]});        
        }
      } elsif ($value eq 'inherit') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['INHERIT']});
      }
      ## NOTE: In the "else" case, don't procede the |$t| pointer
      ## for the support of 'border-top' property (and similar ones).
    }
    
    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
}; # $length_percentage_keyword_parser

## <http://dev.w3.org/csswg/css-fonts/#font-size-prop> [CSSFONTS],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS], [MANAKAICSS].
$Key->{font_size} = {
  css => 'font-size',
  dom => 'font_size',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::NNLengthOrQuirkyLengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        if ($us->[0]->{number} >= 0) {
          return ['PERCENTAGE', 0+$us->[0]->{number}];
        }
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ({
          # <absolute-size>
          'xx-small' => 1, 'x-small' => 1, small => 1, medium => 1,
          large => 1, 'x-large' => 1, 'xx-large' => 1,
          '-webkit-xxx-large' => 1,

          # <relative-size>
          larger => 1, smaller => 1,

          '-moz-use-system-font' => 1,
        }->{$value}) {
          return ['KEYWORD', $value];
        } elsif ($value eq '-manakai-xxx-large') {
          return ['KEYWORD', '-webkit-xxx-large'];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['font-size'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  #allow_negative => 0,
  initial => ['KEYWORD', 'medium'],
  inherited => 1,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;
    
    if (defined $specified_value) {
      if ($specified_value->[0] eq 'DIMENSION') {
        my $unit = $specified_value->[2];
        my $value = $specified_value->[1];

        if ($unit eq 'em' or $unit eq 'ex') {
          $value *= 0.5 if $unit eq 'ex';
          ## TODO: Preferred way to determine the |ex| size is defined
          ## in CSS 2.1.

          my $parent_element = $element->manakai_parent_element;
          if (defined $parent_element) {
            $value *= $self->get_computed_value ($parent_element, $prop_name)
                ->[1];
          } else {
            $value *= $self->{font_size}->[3]; # medium
          }
          $unit = 'px';
        } elsif ({in => 1, cm => 1, mm => 1, pt => 1, pc => 1}->{$unit}) {
          ($value *= 12, $unit = 'pc') if $unit eq 'pc';
          ($value /= 72, $unit = 'in') if $unit eq 'pt';
          ($value *= 2.54, $unit = 'cm') if $unit eq 'in';
          ($value *= 10, $unit = 'mm') if $unit eq 'cm';
          ($value /= 0.26, $unit = 'px') if $unit eq 'mm';
        }
        ## else: consistency error

        return ['DIMENSION', $value, $unit];
      } elsif ($specified_value->[0] eq 'PERCENTAGE') {
        my $parent_element = $element->manakai_parent_element;
        my $parent_cv;
        if (defined $parent_element) {
          $parent_cv = $self->get_computed_value
              ($parent_element, $prop_name);
        } else {
          $parent_cv = [undef, $self->{font_size}->[3]];
        }
        return ['DIMENSION', $parent_cv->[1] * $specified_value->[1] / 100,
                'px'];
      } elsif ($specified_value->[0] eq 'KEYWORD') {
        if ($specified_value->[1] eq 'larger') {
          my $parent_element = $element->manakai_parent_element;
          if (defined $parent_element) {
            my $parent_cv = $self->get_computed_value
                ($parent_element, $prop_name);
            return ['DIMENSION',
                    $self->{get_larger_font_size}->($self, $parent_cv->[1]),
                    'px'];
          } else { ## 'larger' relative to 'medium', initial of 'font-size'
            return ['DIMENSION', $self->{font_size}->[4], 'px'];
          }
        } elsif ($specified_value->[1] eq 'smaller') {
          my $parent_element = $element->manakai_parent_element;
          if (defined $parent_element) {
            my $parent_cv = $self->get_computed_value
                ($parent_element, $prop_name);
            return ['DIMENSION',
                    $self->{get_smaller_font_size}->($self, $parent_cv->[1]),
                    'px'];
          } else { ## 'smaller' relative to 'medium', initial of 'font-size'
            return ['DIMENSION', $self->{font_size}->[2], 'px'];
          }
        } else {
          ## TODO: different computation in quirks mode?
          return ['DIMENSION', $self->{font_size}->[{
            'xx-small' => 0,
            'x-small' => 1,
            small => 2,
            medium => 3,
            large => 4,
            'x-large' => 5,
            'xx-large' => 6,
            '-manakai-xxx-large' => 7,
            '-webkit-xxx-large' => 7,
          }->{$specified_value->[1]}], 'px'];
        }
      }
    }

    ## TODO: Should we convert '-manakai-xxx-large' to '-webkit-xxx-large'
    ## at the parse time?
    
    return $specified_value;
  },
}; # font-size

my $compute_length = sub {
  my ($self, $element, $prop_name, $specified_value) = @_;
  
  if (defined $specified_value) {
    if ($specified_value->[0] eq 'DIMENSION') {
      my $unit = $specified_value->[2];
      my $value = $specified_value->[1];

      if ($unit eq 'em' or $unit eq 'ex') {
        $value *= 0.5 if $unit eq 'ex';
        ## TODO: Preferred way to determine the |ex| size is defined
        ## in CSS 2.1.

        $value *= $self->get_computed_value ($element, 'font-size')->[1];
        $unit = 'px';
      } elsif ({in => 1, cm => 1, mm => 1, pt => 1, pc => 1}->{$unit}) {
        ($value *= 12, $unit = 'pc') if $unit eq 'pc';
        ($value /= 72, $unit = 'in') if $unit eq 'pt';
        ($value *= 2.54, $unit = 'cm') if $unit eq 'in';
        ($value *= 10, $unit = 'mm') if $unit eq 'cm';
        ($value /= 0.26, $unit = 'px') if $unit eq 'mm';
      }

      return ['DIMENSION', $value, $unit];
    }
  }
  
  return $specified_value;
}; # $compute_length

## <http://dev.w3.org/csswg/css-text/#letter-spacing> [CSSTEXT],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{letter_spacing} = {
  css => 'letter-spacing',
  dom => 'letter_spacing',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::LengthOrQuirkyLengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'normal') {
          return ['KEYWORD', $value];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['letter-spacing'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'normal'],
  inherited => 1,
  compute => $compute_length,
}; # letter-spacing

## <http://dev.w3.org/csswg/css-text/#word-spacing> [CSSTEXT],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{word_spacing} = {
  css => 'word-spacing',
  dom => 'word_spacing',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::LengthOrQuirkyLengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        return ['PERCENTAGE', 0+$us->[0]->{number}];
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'normal') {
          return ['KEYWORD', $value];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['word-spacing'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'normal'],
  inherited => 1,
  compute => $compute_length,
}; # word-spacing

## [MANAKAICSS].
$Key->{_webkit_border_horizontal_spacing} = {
  css => '-webkit-border-horizontal-spacing',
  dom => '_webkit_border_horizontal_spacing',
  parse_longhand => $Web::CSS::Values::NNLengthParser,
  initial => ['DIMENSION', 0, 'px'],
  inherited => 1,
  compute => $compute_length,
}; # -webkit-border-horizontal-spacing
$Prop->{'-manakai-border-spacing-x'} = $Key->{_webkit_border_horizontal_spacing};
$Attr->{_manakai_border_spacing_x} = $Key->{_webkit_border_horizontal_spacing};

## [MANAKAICSS].
$Key->{_webkit_border_vertical_spacing} = {
  css => '-webkit-border-vertical-spacing',
  dom => '_webkit_border_vertical_spacing',
  parse_longhand => $Web::CSS::Values::NNLengthParser,
  initial => ['DIMENSION', 0, 'px'],
  inherited => 1,
  compute => $compute_length,
}; # -webkit-border-vertical-spacing
$Prop->{'-manakai-border-spacing-y'} = $Key->{_webkit_border_vertical_spacing};
$Attr->{_manakai_border_spacing_y} = $Key->{_webkit_border_vertical_spacing};

## <http://www.w3.org/TR/1998/REC-CSS2-19980512/generate.html#markers>
## [CSS20].
$Key->{marker_offset} = {
  css => 'marker-offset',
  dom => 'marker_offset',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::LengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'auto') {
          return ['KEYWORD', $value];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['marker-offset'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => $compute_length,
}; # marker-offset

## <http://dev.w3.org/csswg/css-box/#the-margin-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{margin_top} = {
  css => 'margin-top',
  dom => 'margin_top',
  parse_longhand => $Web::CSS::Values::LengthPergentageAutoQuirkyParser,
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # margin-top

## <http://dev.w3.org/csswg/css-box/#the-margin-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{margin_bottom} = {
  css => 'margin-bottom',
  dom => 'margin_bottom',
  parse_longhand => $Web::CSS::Values::LengthPergentageAutoQuirkyParser,
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # margin-bottom

## <http://dev.w3.org/csswg/css-box/#the-margin-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{margin_right} = {
  css => 'margin-right',
  dom => 'margin_right',
  parse_longhand => $Web::CSS::Values::LengthPergentageAutoQuirkyParser,
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # margin-right

## <http://dev.w3.org/csswg/css-box/#the-margin-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{margin_left} = {
  css => 'margin-left',
  dom => 'margin_left',
  parse_longhand => $Web::CSS::Values::LengthPergentageAutoQuirkyParser,
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # margin-left

## <http://dev.w3.org/csswg/css-position/#box-offsets-trbl>
## [CSSPOSITION],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{top} = {
  css => 'top',
  dom => 'top',
  parse_longhand => $Web::CSS::Values::LengthPergentageAutoQuirkyParser,
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute_multiple => sub {
    my ($self, $element, $eid, $prop_name) = @_;

    my $pos_value = $self->get_computed_value ($element, 'position');
    if (defined $pos_value and $pos_value->[0] eq 'KEYWORD') {
      if ($pos_value->[1] eq 'static') {
        $self->{computed_value}->{$eid}->{top} = ['KEYWORD', 'auto'];
        $self->{computed_value}->{$eid}->{bottom} = ['KEYWORD', 'auto'];
        return;
      } elsif ($pos_value->[1] eq 'relative') {
        my $top_specified = $self->get_specified_value_no_inherit
          ($element, 'top');
        if (defined $top_specified and
            ($top_specified->[0] eq 'DIMENSION' or
             $top_specified->[0] eq 'PERCENTAGE')) {
          my $tv = $self->{computed_value}->{$eid}->{top}
              = $compute_length->($self, $element, 'top', $top_specified);
          $self->{computed_value}->{$eid}->{bottom}
              = [$tv->[0], -$tv->[1], $tv->[2]];
        } else { # top: auto
          my $bottom_specified = $self->get_specified_value_no_inherit
              ($element, 'bottom');
          if (defined $bottom_specified and
              ($bottom_specified->[0] eq 'DIMENSION' or
               $bottom_specified->[0] eq 'PERCENTAGE')) {
            my $tv = $self->{computed_value}->{$eid}->{bottom}
                = $compute_length->($self, $element, 'bottom',
                                    $bottom_specified);
            $self->{computed_value}->{$eid}->{top}
                = [$tv->[0], -$tv->[1], $tv->[2]];
          } else { # bottom: auto
            $self->{computed_value}->{$eid}->{top} = ['DIMENSION', 0, 'px'];
            $self->{computed_value}->{$eid}->{bottom} = ['DIMENSION', 0, 'px'];
          }
        }
        return;
      }
    }

    my $top_specified = $self->get_specified_value_no_inherit
        ($element, 'top');
    $self->{computed_value}->{$eid}->{top}
        = $compute_length->($self, $element, 'top', $top_specified);
    my $bottom_specified = $self->get_specified_value_no_inherit
        ($element, 'bottom');
    $self->{computed_value}->{$eid}->{bottom}
        = $compute_length->($self, $element, 'bottom', $bottom_specified);
  },
}; # top

## <http://dev.w3.org/csswg/css-position/#box-offsets-trbl>
## [CSSPOSITION],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{bottom} = {
  css => 'bottom',
  dom => 'bottom',
  parse_longhand => $Web::CSS::Values::LengthPergentageAutoQuirkyParser,
  keyword => {auto => 1},
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute_multiple => $Key->{top}->{compute_multiple},
}; # bottom

## <http://dev.w3.org/csswg/css-position/#box-offsets-trbl>
## [CSSPOSITION],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{left} = {
  css => 'left',
  dom => 'left',
  parse_longhand => $Web::CSS::Values::LengthPergentageAutoQuirkyParser,
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute_multiple => sub {
    my ($self, $element, $eid, $prop_name) = @_;

    my $pos_value = $self->get_computed_value ($element, 'position');
    if (defined $pos_value and $pos_value->[0] eq 'KEYWORD') {
      if ($pos_value->[1] eq 'static') {
        $self->{computed_value}->{$eid}->{left} = ['KEYWORD', 'auto'];
        $self->{computed_value}->{$eid}->{right} = ['KEYWORD', 'auto'];
        return;
      } elsif ($pos_value->[1] eq 'relative') {
        my $left_specified = $self->get_specified_value_no_inherit
            ($element, 'left');
        if (defined $left_specified and
            ($left_specified->[0] eq 'DIMENSION' or
             $left_specified->[0] eq 'PERCENTAGE')) {
          my $right_specified = $self->get_specified_value_no_inherit
              ($element, 'right');
          if (defined $right_specified and
              ($right_specified->[0] eq 'DIMENSION' or
               $right_specified->[0] eq 'PERCENTAGE')) {
            my $direction = $self->get_computed_value ($element, 'direction');
            if (defined $direction and $direction->[0] eq 'KEYWORD' and
                $direction->[0] eq 'ltr') {
              my $tv = $self->{computed_value}->{$eid}->{left}
                  = $compute_length->($self, $element, 'left',
                                      $left_specified);
              $self->{computed_value}->{$eid}->{right}
                  = [$tv->[0], -$tv->[1], $tv->[2]];
            } else {
              my $tv = $self->{computed_value}->{$eid}->{right}
                  = $compute_length->($self, $element, 'right',
                                      $right_specified);
              $self->{computed_value}->{$eid}->{left}
                  = [$tv->[0], -$tv->[1], $tv->[2]];
            }
          } else {
            my $tv = $self->{computed_value}->{$eid}->{left}
                = $compute_length->($self, $element, 'left', $left_specified);
            $self->{computed_value}->{$eid}->{right}
                = [$tv->[0], -$tv->[1], $tv->[2]];
          }
        } else { # left: auto
          my $right_specified = $self->get_specified_value_no_inherit
              ($element, 'right');
          if (defined $right_specified and
              ($right_specified->[0] eq 'DIMENSION' or
               $right_specified->[0] eq 'PERCENTAGE')) {
            my $tv = $self->{computed_value}->{$eid}->{right}
                = $compute_length->($self, $element, 'right',
                                    $right_specified);
            $self->{computed_value}->{$eid}->{left}
                = [$tv->[0], -$tv->[1], $tv->[2]];
          } else { # right: auto
            $self->{computed_value}->{$eid}->{left} = ['DIMENSION', 0, 'px'];
            $self->{computed_value}->{$eid}->{right} = ['DIMENSION', 0, 'px'];
          }
        }
        return;
      }
    }

    my $left_specified = $self->get_specified_value_no_inherit
        ($element, 'left');
    $self->{computed_value}->{$eid}->{left}
        = $compute_length->($self, $element, 'left', $left_specified);
    my $right_specified = $self->get_specified_value_no_inherit
        ($element, 'right');
    $self->{computed_value}->{$eid}->{right}
        = $compute_length->($self, $element, 'right', $right_specified);
  },
}; # left

## <http://dev.w3.org/csswg/css-position/#box-offsets-trbl>
## [CSSPOSITION],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{right} = {
  css => 'right',
  dom => 'right',
  parse_longhand => $Web::CSS::Values::LengthPergentageAutoQuirkyParser,
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute_multiple => $Key->{left}->{compute_multiple},
}; # right

## <http://dev.w3.org/csswg/css-box/#the-width-and-height-properties>
## [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{width} = {
  css => 'width',
  dom => 'width',
  keyword => { # For Web::CSS::MediaResolver
    available => 1, 'fit-content' => 1, 'min-content' => 1, 'max-content' => 1,
  },
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => $compute_length,
}; # width

## <http://dev.w3.org/csswg/css-box/#the-width-and-height-properties>
## [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{height} = {
  css => 'height',
  dom => 'height',
  keyword => { # For Web::CSS::MediaResolver
    available => 1, 'fit-content' => 1, 'min-content' => 1, 'max-content' => 1,
  },
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => $compute_length,
}; # height

## <length> | <quirky-length> | available | min-content | max-content
## | fit-content | auto [CSSBOX] [QUIRKS]
for my $prop_name (qw(width height)) {
  $Key->{$prop_name}->{parse_longhand} = sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::NNLengthOrQuirkyLengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        if ($us->[0]->{number} >= 0) {
          return ['PERCENTAGE', 0+$us->[0]->{number}];
        }
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'auto') {
          return ['KEYWORD', $value];
        } elsif ({available => 1, 'min-content' => 1,
                  'max-content' => 1, 'fit-content' => 1,
                  '-webkit-min-content' => 1, '-webkit-max-content' => 1,
                  '-webkit-fit-content' => 1,
                  '-moz-available' => ($prop_name eq 'width'),
                  '-moz-min-content' => ($prop_name eq 'width'),
                  '-moz-max-content' => ($prop_name eq 'width'),
                  '-moz-fit-content' => ($prop_name eq 'width')}->{$value}) {
          if ($value =~ s/^-moz-// or $value =~ s/^-webkit-//) {
            $self->onerror->(type => 'css:obsolete', # XXX
                             text => $us->[0]->{value},
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $us->[0]);
          }
          if ($self->media_resolver->{prop_value}->{$prop_name}->{$value}) {
            return ['KEYWORD', $value];
          }
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => "'$prop_name'",
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  };
} # width height

## <http://dev.w3.org/csswg/css-box/#min-max> [CSSBOX].
$Key->{min_width} = {
  css => 'min-width',
  dom => 'min_width',
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # min-width

## <http://dev.w3.org/csswg/css-box/#min-max> [CSSBOX].
$Key->{max_width} = {
  css => 'max-width',
  dom => 'max_width',
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_length,
}; # max-width

## <http://dev.w3.org/csswg/css-box/#min-max> [CSSBOX].
$Key->{min_height} = {
  css => 'min-height',
  dom => 'min_height',
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # min-height

## <http://dev.w3.org/csswg/css-box/#min-max> [CSSBOX].
$Key->{max_height} = {
  css => 'max-height',
  dom => 'max_height',
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_length,
}; # max-height

## <length> | available | min-content | max-content | fit-content |
## none (max-* only) [CSSBOX]
for my $prop_key (qw(min_width min_height max_width max_height)) {
  my $allow_none = $prop_key =~ /^max_/;
  my $pn = $prop_key;
  $pn =~ s/^(?:min|max)_//;
  $Key->{$prop_key}->{parse_longhand} = sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::NNLengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        if ($us->[0]->{number} >= 0) {
          return ['PERCENTAGE', 0+$us->[0]->{number}];
        }
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($allow_none and $value eq 'none') {
          return ['KEYWORD', $value];
        } elsif ({available => 1, 'min-content' => 1,
                  'max-content' => 1, 'fit-content' => 1,
                  '-webkit-min-content' => 1, '-webkit-max-content' => 1,
                  '-webkit-fit-content' => 1,
                  '-moz-available' => ($pn eq 'width'),
                  '-moz-min-content' => ($pn eq 'width'),
                  '-moz-max-content' => ($pn eq 'width'),
                  '-moz-fit-content' => ($pn eq 'width')}->{$value}) {
          if ($value =~ s/^-moz-// or $value =~ s/^-webkit-//) {
            $self->onerror->(type => 'css:obsolete', # XXX
                             text => $us->[0]->{value},
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $us->[0]);
          }
          if ($self->media_resolver->{prop_value}->{$pn}->{$value}) {
            return ['KEYWORD', $value];
          }
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => "'$pn'",
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  };
} # min-width min-height max-width max-height

## <http://dev.w3.org/csswg/css-inline/#InlineBoxHeight> [CSSINLINE].
$Key->{line_height} = {
  css => 'line-height',
  dom => 'line_height',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN) {
        return $Web::CSS::Values::NNLengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == NUMBER_TOKEN) {
        if ($us->[0]->{number} >= 0) {
          return ['NUMBER', 0+$us->[0]->{number}];
        }
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        if ($us->[0]->{number} >= 0) {
          return ['PERCENTAGE', 0+$us->[0]->{number}];
        }
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'normal' or $value eq 'none' or
            $value eq '-moz-use-system-font') {
          return ['KEYWORD', $value];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['line-height'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'normal'],
  inherited => 1,
  compute => $compute_length,
}; # line-height

## <http://dev.w3.org/csswg/css-inline/#vertical-align-prop>
## [CSSINLINE].
$Key->{vertical_align} = {
  css => 'vertical-align',
  dom => 'vertical_align',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::LengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        return ['PERCENTAGE', 0+$us->[0]->{number}];
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ({
          baseline => 1, sub => 1, super => 1, top => 1, 'text-top' => 1,
          middle => 1, bottom => 1, 'text-bottom' => 1,
          auto => 1, central => 1,
        }->{$value}) {
          return ['KEYWORD', $value];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['vertical-align'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'baseline'],
  #inherited => 0,
  compute => $compute_length,
}; # vertical-align

## <http://dev.w3.org/csswg/css-text/#text-indent> [CSSTEXT].
$Key->{text_indent} = {
  css => 'text-indent',
  dom => 'text_indent',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::LengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        return ['PERCENTAGE', 0+$us->[0]->{number}];
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['text-indent'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['DIMENSION', 0, 'px'],
  inherited => 1,
  compute => $compute_length,
}; # text-indent

## [CSSBACKGROUNDS].
$Key->{background_position_x} = {
  css => 'background-position-x',
  dom => 'background_position_x',
  shorthand_keys => [qw(background background_position)],
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::LengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        return ['PERCENTAGE', 0+$us->[0]->{number}];
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'left' or $value eq 'right' or
            $value eq 'center') {
          return ['KEYWORD', $value];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error',
                     text => q['background-position-x'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['PERCENTAGE', 0],
  #inherited => 0,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    if (defined $specified_value and $specified_value->[0] eq 'KEYWORD') {
      my $v = {
        left => 0, center => 50, right => 100, top => 0, bottom => 100,
      }->{$specified_value->[1]};
      if (defined $v) {
        return ['PERCENTAGE', $v];
      } else {
        return $specified_value;
      }
    } else {
      return $compute_length->(@_);
    }
  },
}; # background-position-x

## [CSSBACKGROUNDS].
$Key->{background_position_y} = {
  css => 'background-position-y',
  dom => 'background_position_y',
  shorthand_keys => [qw(background background_position)],
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == DIMENSION_TOKEN or
          $us->[0]->{type} == NUMBER_TOKEN) {
        return $Web::CSS::Values::LengthParser->($self, $us); # or undef
      } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
        return ['PERCENTAGE', 0+$us->[0]->{number}];
      } elsif ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'top' or $value eq 'bottom' or
            $value eq 'center') {
          return ['KEYWORD', $value];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error',
                     text => q['background-position-y'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['PERCENTAGE', 0],
  #inherited => 0,
  compute => $Key->{background_position_x}->{compute},
}; # background-position-y

## <http://dev.w3.org/csswg/css-box/#the-padding-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{padding_top} = {
  css => 'padding-top',
  dom => 'padding_top',
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # padding-top

## <http://dev.w3.org/csswg/css-box/#the-padding-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{padding_bottom} = {
  css => 'padding-bottom',
  dom => 'padding_bottom',
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # padding-bottom

## <http://dev.w3.org/csswg/css-box/#the-padding-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{padding_right} = {
  css => 'padding-right',
  dom => 'padding_right',
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # padding-right

## <http://dev.w3.org/csswg/css-box/#the-padding-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{padding_left} = {
  css => 'padding-left',
  dom => 'padding_left',
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # padding-left

$Key->{$_}->{parse_longhand} = sub {
  my ($self, $us) = @_;
  if (@$us == 2) {
    if ($us->[0]->{type} == DIMENSION_TOKEN or
        $us->[0]->{type} == NUMBER_TOKEN) {
      return $Web::CSS::Values::NNLengthOrQuirkyLengthParser->($self, $us); # or undef
    } elsif ($us->[0]->{type} == PERCENTAGE_TOKEN) {
      if ($us->[0]->{number} >= 0) {
        return ['PERCENTAGE', 0+$us->[0]->{number}];
      }
    }
  }

  $self->onerror->(type => 'CSS syntax error', text => q['padding-*'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $us->[0]);
  return undef;
} for qw(padding_top padding_right padding_bottom padding_left); # parse_longhand

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-width>
## [CSSBACKGROUND],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{border_top_width} = {
  css => 'border-top-width',
  dom => 'border_top_width',
  parse_longhand => $Web::CSS::Values::LineWidthQuirkyParser,
  shorthand_keys => [qw(border border_width border_top)],
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    ## NOTE: Used for 'border-top-width', 'border-right-width',
    ## 'border-bottom-width', 'border-right-width', and
    ## 'outline-width'.

    my $style_prop = $prop_name;
    $style_prop =~ s/width/style/;
    my $style = $self->get_computed_value ($element, $style_prop);
    if (defined $style and $style->[0] eq 'KEYWORD' and
        ($style->[1] eq 'none' or $style->[1] eq 'hidden')) {
      return ['DIMENSION', 0, 'px'];
    }

    my $value = $compute_length->(@_);
    if (defined $value and $value->[0] eq 'KEYWORD') {
      if ($value->[1] eq 'thin') {
        return ['DIMENSION', 1, 'px']; ## Firefox/Opera
      } elsif ($value->[1] eq 'medium') {
        return ['DIMENSION', 3, 'px']; ## Firefox/Opera
      } elsif ($value->[1] eq 'thick') {
        return ['DIMENSION', 5, 'px']; ## Firefox
      }
    }
    return $value;
  },
}; # border-top-width

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-width>
## [CSSBACKGROUND],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{border_right_width} = {
  css => 'border-right-width',
  dom => 'border_right_width',
  parse_longhand => $Web::CSS::Values::LineWidthQuirkyParser,
  shorthand_keys => [qw(border border_width border_right)],
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => $Key->{border_top_width}->{compute},
}; # border-right-width

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-width>
## [CSSBACKGROUND],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{border_bottom_width} = {
  css => 'border-bottom-width',
  dom => 'border_bottom_width',
  parse_longhand => $Web::CSS::Values::LineWidthQuirkyParser,
  shorthand_keys => [qw(border border_width border_bottom)],
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => $Key->{border_top_width}->{compute},
}; # border-bottom-width

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-width>
## [CSSBACKGROUND],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{border_left_width} = {
  css => 'border-left-width',
  dom => 'border_left_width',
  parse_longhand => $Web::CSS::Values::LineWidthQuirkyParser,
  shorthand_keys => [qw(border border_width border_left)],
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => $Key->{border_top_width}->{compute},
}; # border-left-width

## <http://dev.w3.org/csswg/css-ui/#outline-width> [CSSUI].
$Key->{outline_width} = {
  css => 'outline-width',
  dom => 'outline_width',
  parse_longhand => $Web::CSS::Values::LineWidthParser,
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => $Key->{border_top_width}->{compute},
}; # outline-width

## <http://dev.w3.org/csswg/css-fonts/#font-weight-prop> [CSSFONTS].
$Key->{font_weight} = {
  css => 'font-weight',
  dom => 'font_weight',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'normal' or
            $value eq 'bold' or
            $value eq 'bolder' or
            $value eq 'lighter' or
            $value eq '-moz-use-system-font') {
          return ['KEYWORD', $value];
        }
      } elsif ($us->[0]->{type} == NUMBER_TOKEN) {
        if ($us->[0]->{number} =~ /\A\+?0*[1-9]00\z/) {
          return ['NUMBER', 0+$us->[0]->{number}];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['font-weight'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'normal'],
  inherited => 1,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    if (defined $specified_value and $specified_value->[0] eq 'KEYWORD') {
      if ($specified_value->[1] eq 'normal') {
        return ['WEIGHT', 400, 0];
      } elsif ($specified_value->[1] eq 'bold') {
        return ['WEIGHT', 700, 0];
      } elsif ($specified_value->[1] eq 'bolder') {
        my $parent_element = $element->manakai_parent_element;
        if (defined $parent_element) {
          my $parent_value = $self->get_cascaded_value
              ($parent_element, $prop_name); ## NOTE: What Firefox does.
          return ['WEIGHT', $parent_value->[1], $parent_value->[2] + 1];
        } else {
          return ['WEIGHT', 400, 1];
        }
      } elsif ($specified_value->[1] eq 'lighter') {
        my $parent_element = $element->manakai_parent_element;
        if (defined $parent_element) {
          my $parent_value = $self->get_cascaded_value
              ($parent_element, $prop_name); ## NOTE: What Firefox does.
          return ['WEIGHT', $parent_value->[1], $parent_value->[2] - 1];
        } else {
          return ['WEIGHT', 400, 1];
        }
      }
    #} elsif (defined $specified_value and $specified_value->[0] eq 'WEIGHT') {
      #
    }

    return $specified_value;
  },
}; # font-weight

my $compute_uri_or_none = sub {
    my ($self, $element, $prop_name, $specified_value) = @_;
    
    if (defined $specified_value and
        $specified_value->[0] eq 'URI' and
        defined $specified_value->[2]) {
      require Web::URL::Canonical;
      my $url = Web::URL::Canonical::url_to_canon_url
          ($specified_value->[1], ${$specified_value->[2]});
      return ['URI', $url, $specified_value->[2]];
    }

    return $specified_value;
}; # $compute_uri_or_none

## <http://dev.w3.org/csswg/css-lists/#marker-content> [CSSLISTS].
$Key->{list_style_image} = {
  css => 'list-style-image',
  dom => 'list_style_image',
  parse_longhand => $Web::CSS::Values::URLOrNoneParser,
  initial => ['KEYWORD', 'none'],
  inherited => 1,
  compute => $compute_uri_or_none,
}; # list-style-image

## <http://dev.w3.org/csswg/css-backgrounds/#the-background-image>
## [CSSLISTS].
$Key->{background_image} = {
  css => 'background-image',
  dom => 'background_image',
  parse_longhand => $Web::CSS::Values::URLOrNoneParser,
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_uri_or_none,
}; # background-image

## <http://dev.w3.org/csswg/css-fonts/#font-stretch-prop> [CSSFONTS],
## <http://www.w3.org/TR/1998/REC-CSS2/fonts.html#propdef-font-stretch>
## [CSS20].
$Key->{font_stretch} = {
  css => 'font-stretch',
  dom => 'font_stretch',
  keyword => {
    qw/normal 1 wider 1 narrower 1 ultra-condensed 1 extra-condensed 1
       condensed 1 semi-condensed 1 semi-expanded 1 expanded 1 
       extra-expanded 1 ultra-expanded 1/,
    '-moz-use-system-font' => 1,
  },
  initial => ["KEYWORD", 'normal'],
  inherited => 1,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    if (defined $specified_value and $specified_value->[0] eq 'KEYWORD') {
      if ($specified_value->[1] eq 'wider') {
        my $parent = $element->manakai_parent_element;
        if ($parent) {
          my $computed = $self->get_computed_value ($parent, $prop_name);
          if (defined $computed and $computed->[0] eq 'KEYWORD') {
            return ['KEYWORD', {
                                'ultra-condensed' => 'extra-condensed',
                                'extra-condensed' => 'condensed',
                                'condensed' => 'semi-condensed',
                                'semi-condensed' => 'normal',
                                'normal' => 'semi-expanded',
                                'semi-expanded' => 'expanded',
                                'expanded' => 'extra-expanded',
                                'extra-expanded' => 'ultra-expanded',
                                'ultra-expanded' => 'ultra-expanded',
                               }->{$computed->[1]} || $computed->[1]];
          } else { ## This is an implementation error.
            #
          }
        } else {
          return ['KEYWORD', 'semi-expanded'];
        }
      } elsif ($specified_value->[1] eq 'narrower') {
        my $parent = $element->manakai_parent_element;
        if ($parent) {
          my $computed = $self->get_computed_value ($parent, $prop_name);
          if (defined $computed and $computed->[0] eq 'KEYWORD') {
            return ['KEYWORD', {
                                'ultra-condensed' => 'ultra-condensed',
                                'extra-condensed' => 'ultra-condensed',
                                'condensed' => 'extra-condensed',
                                'semi-condensed' => 'condensed',
                                'normal' => 'semi-condensed',
                                'semi-expanded' => 'normal',
                                'expanded' => 'semi-expanded',
                                'extra-expanded' => 'expanded',
                                'ultra-expanded' => 'extra-expanded',
                               }->{$computed->[1]} || $computed->[1]];
          } else { ## This is an implementation error.
            #
          }
        } else {
          return ['KEYWORD', 'semi-condensed'];
        }
      }
    }

    return $specified_value;
  },
}; # font-stretch

## <http://dev.w3.org/csswg/css-writing-modes/#writing-mode>
## [CSSWRITINGMODES].
$Key->{writing_mode} = {
  css => 'writing-mode',
  dom => 'writing_mode',
  keyword => {
    'horizontal-tb' => 1, 'vertical-rl' => 1, 'vertical-lr' => 1,
    'lr' => 1, 'lr-tb' => 1,
    'rl' => 1, 'rl-tb' => 1,
    'tb' => 1, 'tb-rl' => 1,
  },
  initial => ['KEYWORD', 'horizontal-tb'],
  inherited => 1,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    ## ISSUE: Not defined by any standard.

    if (defined $specified_value and $specified_value->[0] eq 'KEYWORD') {
      if ($specified_value->[1] eq 'lr') {
        return ['KEYWORD', 'lr-tb'];
      } elsif ($specified_value->[1] eq 'rl') {
        return ['KEYWORD', 'rl-tb'];
      } elsif ($specified_value->[1] eq 'tb') {
        return ['KEYWORD', 'tb-rl'];
      }
    }

    return $specified_value;
  },
}; # writing-mode
$Prop->{'-ms-writing-mode'} = $Key->{writing_mode};

## <https://svgwg.org/svg2-draft/text.html#TextAnchorProperty> [SVG].
$Key->{text_anchor} = {
  css => 'text-anchor',
  dom => 'text_anchor',
  keyword => {
    start => 1, middle => 1, end => 1,
  },
  initial => ['KEYWORD', 'start'],
  inherited => 1,
  compute => $compute_as_specified,
}; # text-anchor

## <https://svgwg.org/svg2-draft/text.html#DominantBaselineProperty>
## [SVG].
$Key->{dominant_baseline} = {
  css => 'dominant-baseline',
  dom => 'dominant_baseline',
  keyword => {
    qw/auto 1 use-script 1 no-change 1 reset-size 1 ideographic 1 alphabetic 1
       hanging 1 mathematical 1 central 1 middle 1 text-after-edge 1
       text-before-edge 1/
  },
  initial => ['KEYWORD', 'auto'],
  inherited => 0,
  compute => $compute_as_specified,
}; # dominant-baseline

## <https://svgwg.org/svg2-draft/text.html#AlignmentBaselineProperty>
## [SVG].
$Key->{alignment_baseline} = {
  css => 'alignment-baseline',
  dom => 'alignment_baseline',
  keyword => {
    qw/auto 1 baseline 1 before-edge 1 text-before-edge 1 middle 1 central 1
       after-edge 1 text-after-edge 1 ideographic 1 alphabetic 1 hanging 1
       mathematical 1/
  },
  initial => ['KEYWORD', 'auto'],
  inherited => 0,
  compute => $compute_as_specified,
}; # alignment-baseline

my $border_style_keyword = {
  none => 1, hidden => 1, dotted => 1, dashed => 1, solid => 1,
  double => 1, groove => 1, ridge => 1, inset => 1, outset => 1,
};

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-style>
## [CSSBACKGROUNDS].
$Key->{border_top_style} = {
  css => 'border-top-style',
  dom => 'border_top_style',
  keyword => $border_style_keyword,
  shorthand_keys => [qw(border border_style border_top)],
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # border-top-style

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-style>
## [CSSBACKGROUNDS].
$Key->{border_right_style} = {
  css => 'border-right-style',
  dom => 'border_right_style',
  keyword => $border_style_keyword,
  shorthand_keys => [qw(border border_style border_right)],
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # border-right-style

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-style>
## [CSSBACKGROUNDS].
$Key->{border_bottom_style} = {
  css => 'border-bottom-style',
  dom => 'border_bottom_style',
  keyword => $border_style_keyword,
  shorthand_keys => [qw(border border_style border_bottom)],
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # border-bottom-style

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-style>
## [CSSBACKGROUNDS].
$Key->{border_left_style} = {
  css => 'border-left-style',
  dom => 'border_left_style',
  keyword => $border_style_keyword,
  shorthand_keys => [qw(border border_style border_left)],
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # border-left-style

## <http://dev.w3.org/csswg/css-ui/#outline-style> [CSSUI].
$Key->{outline_style} = {
  css => 'outline-style',
  dom => 'outline_style',
  keyword => {%$border_style_keyword, auto => 1, hidden => 0},
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # outline-style

## <http://dev.w3.org/csswg/css-fonts/#font-family-prop> [CSSFONTS].
$Key->{font_family} = {
  css => 'font-family',
  dom => 'font_family',
  parse_longhand => sub {
    my ($self, $us) = @_;

    my $result = ['LIST'];
    my $t = shift @$us;
    {
      $t = shift @$us while $t->{type} == S_TOKEN;
      
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ({serif => 1, 'sans-serif' => 1, cursive => 1,
             fantasy => 1, monospace => 1,
             '-manakai-default' => 1,
             '-moz-use-system-font' => 1}->{$value}) {
          my $values = [$t->{value}];
          $t = shift @$us;
          $t = shift @$us while $t->{type} == S_TOKEN;
          while ($t->{type} == IDENT_TOKEN) {
            push @$values, $t->{value};
            $t = shift @$us;
            $t = shift @$us while $t->{type} == S_TOKEN;
          }
          if (@$values == 1) {
            push @$result, ['KEYWORD', $value];
          } else {
            push @$result, ['STRING', join ' ', @$values];
          }
        } elsif ($Web::CSS::Values::CSSWideKeywords->{$value} or
                 $value eq 'default') {
          last;
        } else {
          my $values = [$t->{value}];
          $t = shift @$us;
          $t = shift @$us while $t->{type} == S_TOKEN;
          while ($t->{type} == IDENT_TOKEN) {
            push @$values, $t->{value};
            $t = shift @$us;
            $t = shift @$us while $t->{type} == S_TOKEN;
          }
          push @$result, ['STRING', join ' ', @$values];
        }
        if ($t->{type} == COMMA_TOKEN) {
          $t = shift @$us;
          $t = shift @$us while $t->{type} == S_TOKEN;
          redo;
        } elsif ($t->{type} == EOF_TOKEN) {
          return $result;
        } else {
          last;
        }
      } elsif ($t->{type} == STRING_TOKEN) {
        push @$result, ['STRING', $t->{value}];

        $t = shift @$us;
        $t = shift @$us while $t->{type} == S_TOKEN;
        if ($t->{type} == COMMA_TOKEN) {
          $t = shift @$us;
          $t = shift @$us while $t->{type} == S_TOKEN;
          redo;
        } elsif ($t->{type} == EOF_TOKEN) {
          return $result;
        } else {
          last;
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['font-family'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['FONT', ['KEYWORD', '-manakai-default']],
  inherited => 1,
  compute => $compute_as_specified,
}; # font-family

## <http://dev.w3.org/csswg/css-ui/#cursor> [CSSUI].
$Key->{cursor} = {
  css => 'cursor',
  dom => 'cursor',
  keyword => {
    auto => 1, crosshair => 1, default => 1, pointer => 1, move => 1,
    'e-resize' => 1, 'ne-resize' => 1, 'nw-resize' => 1,
    'n-resize' => 1, 'se-resize' => 1, 'sw-resize' => 1, 's-resize' => 1,
    'w-resize' => 1, text => 1, wait => 1, help => 1, progress => 1,
    none => 1, 'context-menu' => 1, cell => 1, 'vertical-text' => 1,
    alias => 1, copy => 1, 'no-drop' => 1, 'not-allowed' => 1,
    'ew-resize' => 1, 'ns-resize' => 1, 'nesw-resize' => 1,
    'nwse-resize' => 1, 'col-resize' => 1, 'row-resize' => 1,
    'all-scroll' => 1, 'zoom-in' => 1, 'zoom-out' => 1,
    grab => 1, grabbing => 1,
    # hand -moz-grab -webkit-grab -moz-grabbing -webkit-grabbing
    # -moz-zoom-in -webkit-zoom-in -moz-zoom-out -webkit-zoom-out
  },
  initial => ['CURSOR', ['KEYWORD', 'auto']],
  inherited => 1,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    if (defined $specified_value and $specified_value->[0] eq 'CURSOR') {
      my @new_value = ('CURSOR');
      for my $value (@$specified_value[1..$#$specified_value]) {
        if ($value->[0] eq 'URI') {
          if (defined $value->[2]) {
            require Web::URL::Canonical;
            my $url = Web::URL::Canonical::url_to_canon_url
                ($value->[1], ${$value->[2]});
            push @new_value, ['URI', $url, $value->[2]];
          } else {
            push @new_value, $value;
          }
        } else {
          push @new_value, $value;
        }
      }
      return \@new_value;
    }

    return $specified_value;
  },
}; # cursor
$Key->{cursor}->{parse_longhand} = sub {
  my $def = $_[0];
  return sub {
    my ($self, $us) = @_;

    my $result = ['LIST'];
    my $t = shift @$us;
    {
      if ($t->{type} == URI_TOKEN) {
        my $value = ['URL', $t->{value}, $self->context->base_urlref];
        $t = shift @$us;
        $t = shift @$us while $t->{type} == S_TOKEN;
        if ($t->{type} == NUMBER_TOKEN) {
          $value->[0] = 'CURSORURL';
          $value->[3] = 0+$t->{number};
          $t = shift @$us;
          $t = shift @$us while $t->{type} == S_TOKEN;
          if ($t->{type} == NUMBER_TOKEN) {
            $value->[4] = 0+$t->{number};
            $t = shift @$us;
            $t = shift @$us while $t->{type} == S_TOKEN;
            if ($t->{type} == COMMA_TOKEN) {
              $t = shift @$us;
              $t = shift @$us while $t->{type} == S_TOKEN;
              push @$result, $value;
              redo;
            }
          }
        } elsif ($t->{type} == COMMA_TOKEN) {
          $t = shift @$us;
          $t = shift @$us while $t->{type} == S_TOKEN;
          push @$result, $value;
          redo;
        }
      } elsif ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        my $replaced = {
          hand => 'pointer',
          '-moz-grab' => 'grab',
          '-webkit-grab' => 'grab',
          '-moz-grabbing' => 'grabbing',
          '-webkit-grabbing' => 'grabbing',
          '-moz-zoom-in' => 'zoom-in',
          '-webkit-zoom-in' => 'zoom-in',
          '-moz-zoom-out' => 'zoom-out',
          '-webkit-zoom-out' => 'zoom-out',
        }->{$value} || $value;
        if ($def->{keyword}->{$replaced} and
            $self->media_resolver->{prop_value}->{cursor}->{$replaced}) {
          if ($value ne $replaced) {
            $self->onerror->(type => 'css:obsolete', # XXX
                             text => $t->{value},
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
          }
          push @$result, ['KEYWORD', $replaced];
          $t = shift @$us;
          $t = shift @$us while $t->{type} == S_TOKEN;
          if ($t->{type} == EOF_TOKEN) {
            return $result;
          }
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['cursor'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  };
}->($Key->{cursor}); # parse_longhand

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-style>
## [CSSBACKGROUNDS].
$Key->{border_style} = {
  css => 'border-style',
  dom => 'border_style',
  is_shorthand => 1,
  longhand_subprops => [qw(border_top_style border_right_style
                           border_bottom_style border_left_style)],
}; # border-style
$Key->{border_style}->{parse_shorthand} = $GetBoxShorthandParser->($Key->{border_style});
$Key->{border_style}->{serialize_shorthand} = $GetBoxShorthandSerializer->($Key->{border_style});

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-color>
## [CSSBACKGROUNDS],
## <http://quirks.spec.whatwg.org/#the-hashless-hex-color-quirk>
## [QUIRKS].
$Key->{border_color} = {
  css => 'border-color',
  dom => 'border_color',
  is_shorthand => 1,
  longhand_subprops => [qw(border_top_color border_right_color
                           border_bottom_color border_left_color)],
}; # border-color
$Key->{border_color}->{parse_shorthand} = $GetBoxShorthandParser->($Key->{border_color});
$Key->{border_color}->{serialize_shorthand} = $GetBoxShorthandSerializer->($Key->{border_color});

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-shorthands>
## [CSSBACKGROUNDS].
$Key->{border_top} = {
  css => 'border-top',
  dom => 'border_top',
  is_shorthand => 1,
  longhand_subprops => [qw(border_top_width border_top_style
                           border_top_color)],
}; # border-top

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-shorthands>
## [CSSBACKGROUNDS].
$Key->{border_right} = {
  css => 'border-right',
  dom => 'border_right',
  is_shorthand => 1,
  longhand_subprops => [qw(border_right_width border_right_style
                           border_right_color)],
}; # border-right

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-shorthands>
## [CSSBACKGROUNDS].
$Key->{border_bottom} = {
  css => 'border-bottom',
  dom => 'border_bottom',
  is_shorthand => 1,
  longhand_subprops => [qw(border_bottom_width border_bottom_style
                           border_bottom_color)],
}; # border-bottom

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-shorthands>
## [CSSBACKGROUNDS].
$Key->{border_left} = {
  css => 'border-left',
  dom => 'border_left',
  is_shorthand => 1,
  longhand_subprops => [qw(border_left_width border_left_style
                           border_left_color)],
}; # border-left

## <http://dev.w3.org/csswg/css-ui/#outline> [CSSUI].
$Key->{outline} = {
  css => 'outline',
  dom => 'outline',
  is_shorthand => 1,
  longhand_subprops => [qw(outline_width outline_style outline_color)],
}; # outline

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-shorthands>
## [CSSBACKGROUNDS].
$Key->{border} = {
  css => 'border',
  dom => 'border',
  is_shorthand => 1,
  longhand_subprops => [qw(border_top_color border_right_color
                           border_bottom_color border_left_color
                           border_top_width border_right_width
                           border_bottom_width border_left_width
                           border_top_style border_right_style
                           border_bottom_style border_left_style
                           )], # XXX border-image-*
}; # border

for (
  ['border_top', ['border_top_width'], ['border_top_style'],
   ['border_top_color']],
  ['border_right', ['border_right_width'], ['border_right_style'],
   ['border_right_color']],
  ['border_bottom', ['border_bottom_width'], ['border_bottom_style'],
   ['border_bottom_color']],
  ['border_left', ['border_left_width'], ['border_left_style'],
   ['border_left_color']],
  ['border',
   ['border_top_width', 'border_right_width',
    'border_bottom_width', 'border_left_width'],
   ['border_top_style', 'border_right_style',
    'border_bottom_style', 'border_left_style'],
   ['border_top_color', 'border_right_color',
    'border_bottom_color', 'border_left_color']],
  ['outline', ['outline_width'], ['outline_style'], ['outline_color']],
) {
  my ($prop_key, $width_keys, $style_keys, $color_keys) = @$_;
  my $prop_name = $Key->{$prop_key}->{css};
  $Key->{$prop_key}->{parse_shorthand} = sub {
    my ($self, $def, $tokens) = @_;
    my $t = shift @$tokens;

    my $width;
    my $style;
    my $color;

    {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/;
        if ($value eq 'hidden' and $prop_name eq 'outline') {
          last;
        } elsif ($value eq 'auto' and $prop_name eq 'outline') {
          last if defined $style;
          $style = ['KEYWORD', $value];
        } elsif ($border_style_keyword->{$value}) {
          last if defined $style;
          $style = ['KEYWORD', $value];
        } elsif ($value eq 'thin' or $value eq 'thick' or $value eq 'medium') {
          last if defined $width;
          $width = ['KEYWORD', $value];
        } else {
          last if defined $color;
          $color = $Web::CSS::Values::ColorParser->($self, [$t, _to_eof_token $tokens->[0]]);
          return undef unless defined $color;
        }
      } elsif ($t->{type} == DIMENSION_TOKEN or
               $t->{type} == NUMBER_TOKEN) {
        last if defined $width;
        $width = $Web::CSS::Values::LineWidthParser->($self, [$t, _to_eof_token $tokens->[0]]);
        return undef unless defined $width;
      } elsif ($t->{type} == HASH_TOKEN or
               $t->{type} == FUNCTION_CONSTRUCT) {
        last if defined $color;
        $color = $Web::CSS::Values::ColorParser->($self, [$t, _to_eof_token $tokens->[0]]);
        return undef unless defined $color;
      }

      $t = shift @$tokens;
      $t = shift @$tokens while $t->{type} == S_TOKEN;
      if ($t->{type} == EOF_TOKEN) {
        return {(map { $_ => $width || $Key->{$_}->{initial} } @$width_keys),
                (map { $_ => $style || $Key->{$_}->{initial} } @$style_keys),
                (map { $_ => $color || $Key->{$_}->{initial} } @$color_keys)};
        # XXX 'border-image'
      }
      redo;
    }

    $self->onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }; # parse_shorthand

  $Key->{$prop_key}->{serialize_shorthand} = sub {
    my ($se, $strings) = @_;

    if (@$style_keys == 4) {
      return undef
          if $strings->{$width_keys->[0]} ne $strings->{$width_keys->[1]} or
             $strings->{$width_keys->[0]} ne $strings->{$width_keys->[2]} or
             $strings->{$width_keys->[0]} ne $strings->{$width_keys->[3]};
      return undef
          if $strings->{$style_keys->[0]} ne $strings->{$style_keys->[1]} or
             $strings->{$style_keys->[0]} ne $strings->{$style_keys->[2]} or
             $strings->{$style_keys->[0]} ne $strings->{$style_keys->[3]};
      return undef
          if $strings->{$color_keys->[0]} ne $strings->{$color_keys->[1]} or
             $strings->{$color_keys->[0]} ne $strings->{$color_keys->[2]} or
             $strings->{$color_keys->[0]} ne $strings->{$color_keys->[3]};
    }

    my $color = $strings->{$color_keys->[0]};
    if (($color eq 'currentcolor' and $prop_name ne 'outline') or
        ($color eq '-manakai-invert-or-currentcolor' and $prop_name eq 'outline')) {
      return $strings->{$width_keys->[0]} . ' ' .
             $strings->{$style_keys->[0]};
    } else {
      return $strings->{$width_keys->[0]} . ' ' .
             $strings->{$style_keys->[0]} . ' ' .
             $color;
    }
  }; # serialize_shorthand
}

## <http://dev.w3.org/csswg/css-box/#the-margin-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{margin} = {
  css => 'margin',
  dom => 'margin',
  is_shorthand => 1,
  longhand_subprops => [qw(margin_top margin_right margin_bottom margin_left)],
}; # margin
$Key->{margin}->{parse_shorthand} = $GetBoxShorthandParser->($Key->{margin});
$Key->{margin}->{serialize_shorthand} = $GetBoxShorthandSerializer->($Key->{margin});

## <http://dev.w3.org/csswg/css-box/#the-padding-properties> [CSSBOX],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{padding} = {
  css => 'padding',
  dom => 'padding',
  is_shorthand => 1,
  longhand_subprops => [qw(padding_top padding_right
                           padding_bottom padding_left)],
}; # padding
$Key->{padding}->{parse_shorthand} = $GetBoxShorthandParser->($Key->{padding});
$Key->{padding}->{serialize_shorthand} = $GetBoxShorthandSerializer->($Key->{padding});

## <http://www.w3.org/TR/CSS21/tables.html#separated-borders> [CSS21],
## [MANAKAICSS].
$Key->{border_spacing} = {
  css => 'border-spacing',
  dom => 'border_spacing',
  is_shorthand => 1,
  longhand_subprops => [qw(_webkit_border_horizontal_spacing
                           _webkit_border_vertical_spacing)],
  parse_shorthand => sub {
    my ($self, $def, $tokens) = @_;
    $tokens = [grep { not $_->{type} == S_TOKEN } @$tokens];
    ## If <length> becomes to be able to include multiple component in
    ## future, this need to be rewritten.
    if (@$tokens == 3) {
      my $v1 = $Web::CSS::Values::NNLengthParser->($self, [$tokens->[0], _to_eof_token $tokens->[1]]);
      my $v2 = defined $v1 ? $Web::CSS::Values::NNLengthParser->($self, [$tokens->[1], _to_eof_token $tokens->[2]]) : undef;
      return undef unless defined $v2;
      return {_webkit_border_horizontal_spacing => $v1,
              _webkit_border_vertical_spacing => $v2};
    } elsif (@$tokens == 2) {
      my $v1 = $Web::CSS::Values::NNLengthParser->($self, [$tokens->[0], _to_eof_token $tokens->[1]]);
      return undef unless defined $v1;
      return {_webkit_border_horizontal_spacing => $v1,
              _webkit_border_vertical_spacing => $v1};
    } else {
      $self->onerror->(type => 'CSS syntax error', text => q['border-spacing'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $tokens->[0]);
      return undef;
    }
  }, # parse_shorthand
  serialize_shorthand => sub {
    my ($se, $strings) = @_;
    my $v1 = $strings->{_webkit_border_horizontal_spacing};
    my $v2 = $strings->{_webkit_border_vertical_spacing};
    if ($v1 eq $v2) {
      return $v1;
    } else {
      return "$v1 $v2";
    }
  }, # serialize_shorthand
}; # border-spacing

## <http://dev.w3.org/csswg/css-backgrounds/#the-background-position>
## [CSSBACKGROUNDS].
$Key->{background_position} = {
  css => 'background-position',
  dom => 'background_position',
  is_shorthand => 1,
  longhand_subprops => [qw(background_position_x background_position_y)],
  parse_shorthand => sub {
    my ($self, $def, $tokens) = @_;
    $tokens = [grep { not $_->{type} == S_TOKEN } @$tokens];
    if (@$tokens == 2) {
      if ($tokens->[0]->{type} == IDENT_TOKEN and
          $tokens->[0]->{value} =~ /\A(?:[Tt][Oo][Pp]|[Bb][Oo][Tt][Tt][Oo][Mm])\z/) {
        return {background_position_x => ['PERCENTAGE', 50],
                background_position_y => ['KEYWORD', lc $tokens->[0]->{value}]};
      } else {
        my $v1 = $Key->{background_position_x}->{parse_longhand}->($self, $tokens); # or undef
        if (defined $v1) {
          return {background_position_x => $v1,
                  background_position_y => ['PERCENTAGE', 50]};
        } else {
          return undef;
        }
      }
    } elsif (@$tokens == 3) {
      my $v1 = do {
        if ($tokens->[0]->{type} == DIMENSION_TOKEN or
            $tokens->[0]->{type} == NUMBER_TOKEN) {
          $Web::CSS::Values::LengthParser->($self, [$tokens->[0], _to_eof_token $tokens->[1]]); # or undef
        } elsif ($tokens->[0]->{type} == PERCENTAGE_TOKEN) {
          ['PERCENTAGE', 0+$tokens->[0]->{number}];
        } elsif ($tokens->[0]->{type} == IDENT_TOKEN) {
          my $value = $tokens->[0]->{value};
          $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          ['KEYWORD', $value];
        } else {
          $self->onerror->(type => 'CSS syntax error',
                           text => q[position],
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $tokens->[0]);
          undef;
        }
      };
      my $v2 = defined $v1 ? do {
        if ($tokens->[1]->{type} == DIMENSION_TOKEN or
            $tokens->[1]->{type} == NUMBER_TOKEN) {
          $Web::CSS::Values::LengthParser->($self, [$tokens->[1], $tokens->[2]]); # or undef
        } elsif ($tokens->[1]->{type} == PERCENTAGE_TOKEN) {
          ['PERCENTAGE', 0+$tokens->[1]->{number}];
        } elsif ($tokens->[1]->{type} == IDENT_TOKEN) {
          my $value = $tokens->[1]->{value};
          $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          ['KEYWORD', $value];
        } else {
          $self->onerror->(type => 'CSS syntax error',
                           text => q[position],
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $tokens->[1]);
          undef;
        }
      } : undef;
      return undef unless defined $v2;
      
      if ($v1->[0] eq 'KEYWORD') {
        if ($v1->[1] eq 'left' or $v1->[1] eq 'right') {
          if ($v2->[0] eq 'KEYWORD') {
            if ($v2->[1] eq 'top' or $v2->[1] eq 'bottom' or
                $v2->[1] eq 'center') {
              #
            } else {
              $self->onerror->(type => 'CSS syntax error',
                               text => q[position],
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $tokens->[1]);
              return undef;
            }
          }
          return {background_position_x => $v1,
                  background_position_y => $v2};
        } elsif ($v1->[1] eq 'top' or $v1->[1] eq 'bottom') {
          if ($v2->[0] eq 'KEYWORD') {
            if ($v2->[1] eq 'left' or $v2->[1] eq 'right' or
                $v2->[1] eq 'center') {
              return {background_position_x => $v2,
                      background_position_y => $v1};
            } else {
              $self->onerror->(type => 'CSS syntax error',
                               text => q[position],
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $tokens->[1]);
              return undef;
            }
          }
        } elsif ($v1->[1] eq 'center') {
          if ($v2->[0] eq 'KEYWORD') {
            if ($v2->[1] eq 'left' or $v2->[1] eq 'right' or
                $v2->[1] eq 'center') {
              return {background_position_x => $v2,
                      background_position_y => $v1};
            } elsif ($v2->[1] eq 'top' or $v2->[1] eq 'bottom') {
              return {background_position_x => $v2,
                      background_position_y => $v1};
            } else {
              $self->onerror->(type => 'CSS syntax error',
                               text => q[position],
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $tokens->[1]);
              return undef;
            }
          }
          return {background_position_x => $v1,
                  background_position_y => $v2};
        } else { # $v1 KEYWORD
          $self->onerror->(type => 'CSS syntax error',
                           text => q[position],
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $tokens->[0]);
          return undef;
        } # $v1 KEYWORD
      } else { # $v1
        if ($v2->[0] eq 'KEYWORD') {
          if ($v2->[1] eq 'top' or $v2->[1] eq 'bottom' or
              $v2->[1] eq 'center') {
            return {background_position_x => $v1,
                    background_position_y => $v2};
          } else {
            $self->onerror->(type => 'CSS syntax error',
                             text => q[position],
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $tokens->[1]);
            return undef;
          }
        } else { # $v2
          return {background_position_x => $v1,
                  background_position_y => $v2};
        } # $v2
      } # $v1
    }
    
    $self->onerror->(type => 'CSS syntax error',
                     text => q[position],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $tokens->[0]);
    return undef;
  }, # parse_shorthand
  serialize_shorthand => sub {
    my ($se, $strings) = @_;
    return $strings->{background_position_x} . ' ' .$strings->{background_position_y};
  }, # serialize_shorthand
}; # background-position

## <http://dev.w3.org/csswg/css-backgrounds/#the-background>
## [CSSBACKGROUNDS].
$Key->{background} = {
  css => 'background',
  dom => 'background',
  is_shorthand => 1,
  longhand_subprops => [qw(background_image background_repeat
                           background_attachment background_position_x
                           background_position_y background_color)],
                      # XXX background_size background_origin background_clip
  parse_shorthand => sub {
    my ($self, $def, $tokens) = @_;

    my $image;
    my $pos_x;
    my $pos_y;
    my $repeat;
    my $attachment;
    my $color;

    my $t = shift @$tokens;
    {
      my $next_is_pos;
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'none') {
          last if defined $image;
          $image = ['KEYWORD', $value];
        } elsif ({left => 1, center => 1, right => 1,
                  top => 1, bottom => 1}->{$value}) {
          last if defined $pos_x;
          $next_is_pos = 1;
        } elsif ({'repeat-x' => 1, 'repeat-y' => 1,
                  repeat => 1, 'no-repeat' => 1}->{$value} and
                 $self->media_resolver->{prop_value}->{'background-repeat'}->{$value}) {
          last if defined $repeat;
          $repeat = ['KEYWORD', $value];
        } elsif ({scroll => 1, fixed => 1}->{$value} and
                 $self->media_resolver->{prop_value}->{'background-attachment'}->{$value}) {
          last if defined $attachment;
          $attachment = ['KEYWORD', $value];
        } else {
          last if defined $color;
          $color = $Web::CSS::Values::ColorParser->($self, [$t, _to_eof_token $tokens->[0]]);
          return undef unless defined $color;
        }
      } elsif ($t->{type} == PERCENTAGE_TOKEN or
               $t->{type} == DIMENSION_TOKEN or
               $t->{type} == NUMBER_TOKEN) {
        $next_is_pos = 1;
      } elsif ($t->{type} == HASH_TOKEN or
               $t->{type} == FUNCTION_CONSTRUCT) {
        last if defined $color;
        $color = $Web::CSS::Values::ColorParser->($self, [$t, _to_eof_token $tokens->[0]]);
        return undef unless defined $color;
      } elsif ($t->{type} == URI_TOKEN) {
        last if defined $image;
        $image = ['URL', $t->{value}, $self->context->base_urlref];
      } else {
        last;
      }

      if ($next_is_pos) {
        last if defined $pos_x;
        my $us = [$t];
        $t = shift @$tokens;
        while ($t->{type} == PERCENTAGE_TOKEN or
               $t->{type} == DIMENSION_TOKEN or
               $t->{type} == NUMBER_TOKEN or
               $t->{type} == S_TOKEN or
               ($t->{type} == IDENT_TOKEN and
                do {
                  my $v = $t->{value};
                  $v =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
                  {left => 1, center => 1, right => 1,
                   top => 1, bottom => 1}->{$v};
                })) {
          push @$us, $t unless $t->{type} == S_TOKEN;
          $t = shift @$tokens;
        }
        push @$us, _to_eof_token $t;
        my $pos = $Key->{background_position}->{parse_shorthand}->($self, $Key->{background_position}, $us);
        return undef unless defined $pos;
        $pos_x = $pos->{background_position_x};
        $pos_y = $pos->{background_position_y};
      } else {
        $t = shift @$tokens;
      }
      $t = shift @$tokens while $t->{type} == S_TOKEN;
      if ($t->{type} == EOF_TOKEN) {
        return {background_image => $image || $Key->{background_image}->{initial},
                background_position_x => $pos_x || $Key->{background_position_x}->{initial},
                background_position_y => $pos_y || $Key->{background_position_y}->{initial},
                background_repeat => $repeat || $Key->{background_repeat}->{initial},
                background_attachment => $attachment || $Key->{background_attachment}->{initial},
                background_color => $color || $Key->{background_color}->{initial}};
      }
      redo;
    }

    $self->onerror->(type => 'CSS syntax error', text => q['background'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }, # parse_shorthand
  serialize_shorthand => sub {
    my ($se, $strings) = @_;
    return join ' ',
        $strings->{background_image},
        $strings->{background_repeat},
        $strings->{background_attachment},
        $strings->{background_position_x}, $strings->{background_position_y},
        $strings->{background_color};
  }, # serialize_shorthand
}; # background

## [CSSFONTS].
$Key->{_x_system_font} = {
  css => '-x-system-font',
  dom => '_x_system_font',
  keyword => {caption => 1, icon => 1, menu => 1,
              'message-box' => 1, 'small-caption' => 1,
              'status-bar' => 1,
              none => 1},
  initial => ['KEYWORD', 'none'],
  inherited => 1,
  compute => sub {  },
}; # -x-system-font

## <http://dev.w3.org/csswg/css-fonts/#font-prop> [CSSFONTS].
$Key->{font} = {
  css => 'font',
  dom => 'font',
  is_shorthand => 1,
  longhand_subprops => [qw(font_style font_variant font_weight
                           font_stretch font_size line_height font_family
                           _x_system_font font_size_adjust)],
                # XXX font_kerning font_language_override
  parse_shorthand => sub {
    my ($self, $def, $tokens) = @_;
    my $t = shift @$tokens;
    $t = shift @$tokens while $t->{type} == S_TOKEN;

    if ($t->{type} == IDENT_TOKEN) {
      my $value = $t->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($Key->{_x_system_font}->{keyword}->{$value} and $value ne 'none') {
        $t = shift @$tokens;
        $t = shift @$tokens while $t->{type} == S_TOKEN;
        if ($t->{type} == EOF_TOKEN) {
          my $use_system_font = ['KEYWORD', '-moz-use-system-font'];
          return {font_style => $use_system_font,
                  font_variant => $use_system_font,
                  font_weight => $use_system_font,
                  font_stretch => $use_system_font,
                  font_size => $use_system_font,
                  line_height => $use_system_font,
                  font_family => $use_system_font,
                  font_size_adjust => $use_system_font,
                  _x_system_font => ['KEYWORD', $value]};
        } else {
          $self->onerror->(type => 'CSS syntax error', text => q['font'],
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
          return undef;
        }
      }
    }

    my $style;
    my $variant;
    my $weight;
    my $stretch;
    my $max_normal = 4;
    {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'normal') {
          if ($max_normal <= 0) { # 'font-style'/'font-variant'/'font-weight'/'font-stretch'
            $self->onerror->(type => 'CSS syntax error', text => q['font'],
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
            return undef;
          }
          $max_normal--;
        } elsif ($value eq '-moz-use-system-font') {
          $self->onerror->(type => 'CSS syntax error', text => q['font'],
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
          return undef;
        } elsif ($Key->{font_style}->{keyword}->{$value} and
                 $self->media_resolver->{prop_value}->{'font-style'}->{$value}) {
          if (defined $style) {
            $self->onerror->(type => 'CSS syntax error', text => q['font'],
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
            return undef;
          }
          $style = ['KEYWORD', $value];
          $max_normal--;
        } elsif ($value eq 'small-caps' and
                 $self->media_resolver->{prop_value}->{'font-variant'}->{$value}) {
          if (defined $variant) {
            $self->onerror->(type => 'CSS syntax error', text => q['font'],
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
            return undef;
          }
          $variant = ['KEYWORD', $value];
          $max_normal--;
        } elsif ($value eq 'bold' or $value eq 'bolder' or $value eq 'lighter') {
          if (defined $weight) {
            $self->onerror->(type => 'CSS syntax error', text => q['font'],
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
            return undef;
          }
          $weight = ['KEYWORD', $value];
          $max_normal--;
        } elsif ($Key->{font_stretch}->{keyword}->{$value} and
                 $self->media_resolver->{prop_value}->{'font-stretch'}->{$value}) {
          if (defined $stretch) {
            $self->onerror->(type => 'CSS syntax error', text => q['font'],
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
            return undef;
          }
          $stretch = ['KEYWORD', $value];
          $max_normal--;
        } else {
          last;
        }
      } elsif ($t->{type} == NUMBER_TOKEN) {
        if ($t->{number} =~ /\A\+?0*[1-9]00\z/) {
          if (defined $weight) {
            $self->onerror->(type => 'CSS syntax error', text => q['font'],
                             level => 'm',
                             uri => $self->context->urlref,
                             token => $t);
            return undef;
          }
          $weight = ['NUMBER', 0+$t->{number}];
          $max_normal--;
        } else {
          last;
        }
      } else {
        last;
      }
      $t = shift @$tokens;
      $t = shift @$tokens while $t->{type} == S_TOKEN;
      redo;
    }
    
    if ($t->{type} == NUMBER_TOKEN and $t->{number} != 0) { # <quriky-length> not allowed
      $self->onerror->(type => 'css:value:not nnlength',
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
      return undef;
    }
    my $size = $Key->{font_size}->{parse_longhand}->($self, [$t, _to_eof_token $tokens->[0]]);
    return undef unless defined $size;
    $t = shift @$tokens;
    $t = shift @$tokens while $t->{type} == S_TOKEN;

    my $height;
    if ($t->{type} == DELIM_TOKEN and $t->{value} eq '/') {
      $t = shift @$tokens;
      $t = shift @$tokens while $t->{type} == S_TOKEN;
      if ($t->{type} == IDENT_TOKEN and
          $t->{value} =~ /\A-[Mm][Oo][Zz]-[Uu][Ss][Ee]-[Ss][Yy][Ss][Tt][Ee][Mm]-[Ff][Oo][Nn][Tt]\z/) {
        $self->onerror->(type => 'CSS syntax error', text => q['font'],
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
        return undef;
      }
      $height = $Key->{line_height}->{parse_longhand}->($self, [$t, _to_eof_token $tokens->[0]]);
      return undef unless defined $height;
      $t = shift @$tokens;
      $t = shift @$tokens while $t->{type} == S_TOKEN;
    }

    unshift @$tokens, $t;
    my $family = $Key->{font_family}->{parse_longhand}->($self, $tokens);
    return undef unless defined $family;
    
    return {font_style => $style || $Key->{font_style}->{initial},
            font_variant => $variant || $Key->{font_variant}->{initial},
            font_weight => $weight || $Key->{font_weight}->{initial},
            font_stretch => $stretch || $Key->{font_stretch}->{initial},
            font_size => $size || $Key->{font_size}->{initial},
            line_height => $height || $Key->{line_height}->{initial},
            font_family => $family || $Key->{font_family}->{initial},
            font_size_adjust => $Key->{font_size_adjust}->{initial},
            _x_system_font => $Key->{_x_system_font}->{initial}};
  }, # parse_shorthand
  serialize_shorthand => sub {
    my ($se, $strings) = @_;

    unless ($strings->{_x_system_font} eq 'none') {
      for (qw(font_style font_variant font_weight font_stretch
              font_size line_height font_family font_size_adjust)) {
        return undef unless $strings->{$_} eq '-moz-use-system-font';
      }
      return $strings->{_x_system_font};
    }

    return undef unless $strings->{font_size_adjust} eq 'none';
    return undef unless $strings->{font_variant} eq 'normal' or
                        $strings->{font_variant} eq 'small-caps';
    for (qw(font_style font_variant font_weight font_stretch
            font_size line_height font_family font_size_adjust
            _x_system_font)) {
      return undef if $strings->{$_} eq '-moz-use-system-font';
    }

    my @result;

    push @result, $strings->{font_style}
        unless $strings->{font_style} eq 'normal';
    push @result, $strings->{font_variant}
        unless $strings->{font_variant} eq 'normal';
    push @result, $strings->{font_weight}
        unless $strings->{font_weight} eq 'normal';
    push @result, $strings->{font_stretch}
        unless $strings->{font_stretch} eq 'normal';
    push @result, $strings->{font_size};
    if ($strings->{line_height} ne 'normal') {
      $result[-1] .= '/' . $strings->{line_height};
    }
    push @result, $strings->{font_family};
    
    return join ' ', @result;
  }, # serialize_shorthand
}; # font

## <http://dev.w3.org/csswg/css-backgrounds/#the-border-width>
## [CSSBACKGROUND],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{border_width} = {
  css => 'border-width',
  dom => 'border_width',
  is_shorthand => 1,
  longhand_subprops => [qw(border_top_width border_right_width
                           border_bottom_width border_left_width)],
}; # border-width
$Key->{border_width}->{parse_shorthand} = $GetBoxShorthandParser->($Key->{border_width});
$Key->{border_width}->{serialize_shorthand} = $GetBoxShorthandSerializer->($Key->{border_width});

## <http://dev.w3.org/csswg/css-lists/#list-style-property>
## [CSSLISTS].
$Key->{list_style} = {
  css => 'list-style',
  dom => 'list_style',
  is_shorthand => 1,
  longhand_subprops => [qw(list_style_type list_style_position
                           list_style_image)],
  parse_shorthand => sub {
    my ($self, $def, $tokens) = @_;
    my $t = shift @$tokens;

    my $type;
    my $pos;
    my $image;
    my $max_none = 2;
    my $none_count = 0;
    {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'inside' or $value eq 'outside') {
          last if defined $pos;
          $pos = ['KEYWORD', $value];
        } elsif ($value eq 'none') {
          last if $max_none <= 0;
          $max_none--;
          $none_count++;
        } else {
          last if defined $type;
          $type = $Key->{list_style_type}->{parse_longhand}->($self, [$t, _to_eof_token $tokens->[0]]);
          return undef unless defined $type;
          $max_none--;
        }
      } elsif ($t->{type} == URI_TOKEN) {
        last if defined $image;
        $image = ['URL', $t->{value}, $self->context->base_urlref];
        $max_none--;
      } else {
        last if defined $type;
        $type = $Key->{list_style_type}->{parse_longhand}->($self, [$t, _to_eof_token $tokens->[0]]);
        return undef unless defined $type;
        $max_none--;
      }
      $t = shift @$tokens;
      $t = shift @$tokens while $t->{type} == S_TOKEN;

      if ($t->{type} == EOF_TOKEN) {
        $type = ['KEYWORD', 'none'] if not defined $type and $none_count;
        return {list_style_type => $type || $Key->{list_style_type}->{initial},
                list_style_position => $pos || $Key->{list_style_position}->{initial},
                list_style_image => $image || $Key->{list_style_image}->{initial}};
      }
      redo;
    }

    $self->onerror->(type => 'CSS syntax error', text => q['list-style'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }, # parse_shorthand
  serialize_shorthand => sub {
    my ($se, $strings) = @_;
    return join ' ',
        $strings->{list_style_type},
        $strings->{list_style_position},
        $strings->{list_style_image};
  }, # serialize_shorthand
}; # list-style

## <http://dev.w3.org/csswg/css-text-decor/#text-decoration-property>
## [CSSTEXTDECOR].
$Key->{text_decoration} = {
  css => 'text-decoration',
  dom => 'text_decoration',
  keyword => { # For MediaResolver
    underline => 1, overline => 1, 'line-through' => 1, blink => 1,
  },
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
}; # text-decoration
$Key->{text_decoration}->{parse_longhand} = sub {
  my $def = $_[0];
  return sub {
    my ($self, $us) = @_;
    my $t = shift @$us;
    if ($t->{type} == IDENT_TOKEN) {
      my $value = $t->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value eq 'none') {
        $t = shift @$us;
        if ($t->{type} == EOF_TOKEN) {
          return ['KEYWORD', $value];
        }
      } elsif ($def->{keyword}->{$value} and
               $self->media_resolver->{prop_value}->{'text-decoration'}->{$value}) {
        my $set = {};
        $set->{$value} = 1;
        $t = shift @$us;
        $t = shift @$us while $t->{type} == S_TOKEN;
        while ($t->{type} == IDENT_TOKEN) {
          my $value = $t->{value};
          $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          if ($def->{keyword}->{$value} and
              $self->media_resolver->{prop_value}->{'text-decoration'}->{$value}) {
            last if $set->{$value};
            $set->{$value} = 1;
            $t = shift @$us;
            $t = shift @$us while $t->{type} == S_TOKEN;
          } else {
            last;
          }
        }
        if ($t->{type} == EOF_TOKEN) {
          return ['KEYWORDSET', $set];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['text-decoration'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }; # parse_longhand
}->($Key->{text_decoration});

## <http://www.w3.org/TR/CSS21/generate.html#quotes-specify> [CSS21].
$Key->{quotes} = {
  css => 'quotes',
  dom => 'quotes',
  parse_longhand => sub {
    my ($self, $us) = @_;
    my $t = shift @$us;
    if ($t->{type} == IDENT_TOKEN) {
      my $value = $t->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value eq 'none' or $value eq '-manakai-default') {
        $t = shift @$us;
        if ($t->{type} == EOF_TOKEN) {
          return ['KEYWORD', $value];
        }
      }
    } else {
      my @pair;
      while ($t->{type} == STRING_TOKEN) {
        my $s1 = $t->{value};
        $t = shift @$us;
        $t = shift @$us while $t->{type} == S_TOKEN;
        if ($t->{type} == STRING_TOKEN) {
          push @pair, [$s1, $t->{value}];
          $t = shift @$us;
          $t = shift @$us while $t->{type} == S_TOKEN;
          if ($t->{type} == EOF_TOKEN) {
            return ['QUOTES', @pair];
          }
        } else {
          last;
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['quotes'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', '-manakai-default'],
  inherited => 1,
  compute => $compute_as_specified,
}; # quotes

## <http://www.w3.org/TR/CSS21/generate.html#content> [CSS21],
## <http://dev.w3.org/csswg/css-values/#custom-idents>,
## <http://dev.w3.org/csswg/css-values/#attr-notation> [CSSVALUES],
## <http://dev.w3.org/csswg/css-lists/#counter-functions> [CSSLISTS].
$Key->{content} = {
  css => 'content',
  dom => 'content',
  parse_longhand => sub {
    my ($self, $us) = @_;
    my $t = shift @$us;
    if ($t->{type} == IDENT_TOKEN) {
      my $value = $t->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value eq 'normal' or $value eq 'none') {
        $t = shift @$us;
        if ($t->{type} == EOF_TOKEN) {
          return ['KEYWORD', $value];
        }
        $self->onerror->(type => 'CSS syntax error', text => q['content'],
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
        return undef;
      }
    }

    my @result;
    {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ({'open-quote' => 1, 'close-quote' => 1,
             'no-open-quote' => 1, 'no-close-quote' => 1}->{$value}) {
          push @result, ['KEYWORD', $value];
        } else {
          last;
        }
      } elsif ($t->{type} == STRING_TOKEN) {
        push @result, ['STRING', $t->{value}];
      } elsif ($t->{type} == URI_TOKEN) {
        push @result, ['URL', $t->{value}, $self->context->base_urlref];
      } elsif ($t->{type} == FUNCTION_CONSTRUCT) {
        my $name = $t->{name}->{value};
        $name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($name eq 'attr') {
          my $tokens = [grep { $_->{type} != S_TOKEN } @{$t->{value}}];
          if (@$tokens == 1 and $tokens->[0]->{type} == IDENT_TOKEN) {
            push @result, ['ATTR', undef, undef, $tokens->[0]->{value}, 'string', undef];
          } elsif (@$tokens == 2 and
                   $tokens->[0]->{type} == VBAR_TOKEN and
                   $tokens->[1]->{type} == IDENT_TOKEN) {
            push @result, ['ATTR', '', undef, $tokens->[1]->{value}, 'string', undef];
          } elsif (@$tokens == 3 and
                   $tokens->[0]->{type} == IDENT_TOKEN and
                   $tokens->[1]->{type} == VBAR_TOKEN and
                   $tokens->[2]->{type} == IDENT_TOKEN) {
            my $url = $self->context->get_url_by_prefix ($tokens->[0]->{value});
            unless (defined $url) {
              $self->onerror->(type => 'namespace prefix:not declared',
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $tokens->[0],
                               value => $tokens->[0]->{value});
              return undef;
            }
            push @result, ['ATTR', $url, $tokens->[0]->{value}, $tokens->[2]->{value}, 'string', undef];
          } else {
            last;
          }
        } elsif ($name eq 'counter') {
          my $tokens = [grep { $_->{type} != S_TOKEN } @{$t->{value}},
                        {type => EOF_TOKEN,
                         line => $t->{end_line},
                         column => $t->{end_column}}];
          my $u = shift @$tokens;
          if ($u->{type} == IDENT_TOKEN) {
            my $name = $u->{value};
            $u = shift @$tokens;
            if ($u->{type} == COMMA_TOKEN) {
              my $type = $Key->{list_style_type}->{parse_longhand}->($self, $tokens);
              return undef unless defined $type;
              push @result, ['COUNTER', $name, $type];
            } elsif ($u->{type} == EOF_TOKEN) {
              push @result, ['COUNTER', $name, ['KEYWORD', 'decimal']];
            } else {
              $t = $u;
              last;
            }
          } else {
            $t = $u;
            last;
          }
        } elsif ($name eq 'counters') {
          my $tokens = [grep { $_->{type} != S_TOKEN } @{$t->{value}},
                        {type => EOF_TOKEN,
                         line => $t->{end_line},
                         column => $t->{end_column}}];
          my $u = shift @$tokens;
          if ($u->{type} == IDENT_TOKEN) {
            my $name = $u->{value};
            $u = shift @$tokens;
            if ($u->{type} == COMMA_TOKEN) {
              $u = shift @$tokens;
              if ($u->{type} == STRING_TOKEN) {
                my $sep = $u->{value};
                $u = shift @$tokens;
                if ($u->{type} == COMMA_TOKEN) {
                  my $type = $Key->{list_style_type}->{parse_longhand}->($self, $tokens);
                  return undef unless defined $type;
                  push @result, ['COUNTERS', $name, $sep, $type];
                } elsif ($u->{type} == EOF_TOKEN) {
                  push @result, ['COUNTERS', $name, $sep, ['KEYWORD', 'decimal']];
                } else {
                  $t = $u;
                  last;
                }
              } else {
                $t = $u;
                last;
              }
            } else {
              $t = $u;
              last;
            }
          } else {
            $t = $u;
            last;
          }
        } else {
          last;
        }
      } else {
        last;
      }
      $t = shift @$us;
      $t = shift @$us while $t->{type} == S_TOKEN;

      if ($t->{type} == EOF_TOKEN) {
        return ['SEQ', @result];
      }
      redo;
    }

    $self->onerror->(type => 'CSS syntax error', text => q['content'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'normal'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # content

## <http://dev.w3.org/csswg/css-lists/#counter-properties> [CSSLISTS].
$Key->{counter_reset} = {
  css => 'counter-reset',
  dom => 'counter_reset',
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # counter-reset

## <http://dev.w3.org/csswg/css-lists/#counter-properties> [CSSLISTS].
$Key->{counter_increment} = {
  css => 'counter-increment',
  dom => 'counter_increment',
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # counter-increment

for my $key (qw(counter_reset counter_increment)) {
  my $default = $key eq 'counter_reset' ? 0 : 1;
  $Key->{$key}->{parse_longhand} = sub {
    my ($self, $us) = @_;
    my $t = shift @$us;
    if ($t->{type} == IDENT_TOKEN) {
      my $value = $t->{value};
      my $value_l = $value;
      $value_l =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value_l eq 'none') {
        $t = shift @$us;
        if ($t->{type} == EOF_TOKEN) {
          return ['KEYWORD', $value_l];
        }
      } elsif ($Web::CSS::Values::CSSWideKeywords->{$value_l}) {
        #
      } else {
        my $data = ['COUNTERDELTAS'];
        $t = shift @$us;
        $t = shift @$us while $t->{type} == S_TOKEN;
        {
          if ($t->{type} == NUMBER_TOKEN) {
            if ($t->{number} =~ /\A[+-]?[0-9]+\z/) {
              push @$data, [$value, 0+$t->{number}];
              $t = shift @$us;
              $t = shift @$us while $t->{type} == S_TOKEN;
            } else {
              last;
            }
          } else {
            push @$data, [$value, $default];
          }
          if ($t->{type} == IDENT_TOKEN) {
            $value = $t->{value};
            $t = shift @$us;
            $t = shift @$us while $t->{type} == S_TOKEN;
            redo;
          } elsif ($t->{type} == EOF_TOKEN) {
            return $data;
          } else {
            last;
          }
        }
      }
    }

    $self->onerror->(type => 'css:counter set:syntax error', # XXX
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }; # parse_longhand
}

## <http://dev.w3.org/csswg/css-position/#clip-property>
## [CSSPOSITION],
## <http://quirks.spec.whatwg.org/#the-unitless-length-quirk>
## [QUIRKS].
$Key->{clip} = {
  css => 'clip',
  dom => 'clip',
  parse_longhand => sub {
    my ($self, $us) = @_;
    my $t = shift @$us;
    if ($t->{type} == IDENT_TOKEN) {
      my $value = $t->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value eq 'auto') {
        $t = shift @$us;
        if ($t->{type} == EOF_TOKEN) {
          return ['KEYWORD', $value];
        }
      }
    } elsif ($t->{type} == FUNCTION_CONSTRUCT) {
      my $name = $t->{name}->{value};
      $name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($name eq 'rect') {
        my $tokens = [grep { $_->{type} != S_TOKEN } @{$t->{value}},
                      {type => EOF_TOKEN,
                       line => $t->{end_line},
                       column => $t->{end_column}}];
        if ((@$tokens == 8 and
             $tokens->[1]->{type} == COMMA_TOKEN and
             $tokens->[3]->{type} == COMMA_TOKEN and
             $tokens->[5]->{type} == COMMA_TOKEN) or
            @$tokens == 5) {
          $tokens = [grep { $_->{type} != COMMA_TOKEN } @$tokens];
          my $result = ['RECT'];
          for (0, 1, 2, 3) {
            my $value = $tokens->[$_]->{value};
            $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($value eq 'auto') {
              push @$result, ['KEYWORD', $value];
            } else {
              my $r = $Web::CSS::Values::LengthOrQuirkyLengthParser->($self, [$tokens->[$_], $tokens->[$_ + 1]]); # or undef
              return undef unless defined $r;
              push @$result, $r;
            }
          }
          $t = shift @$us;
          if ($t->{type} == EOF_TOKEN) {
            return $result;
          }
        }
      } # rect()
    }

    $self->onerror->(type => 'CSS syntax error', text => q['clip'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    if (defined $specified_value and $specified_value->[0] eq 'RECT') {
      my $v = ['RECT'];
      for (@$specified_value[1..4]) {
        push @$v, $compute_length->($self, $element, $prop_name, $_);
      }
      return $v;
    }

    return $specified_value;
  },
}; # clip

## <http://dev.w3.org/csswg/css-gcpm/#page-marks-and-bleed-area>
## [CSSGCPM].
$Key->{marks} = {
  css => 'marks',
  dom => 'marks',
  keyword => { # For MediaResolver
    crop => 1, cross => 1,
  },
  parse_longhand => sub {
    my ($self, $us) = @_;
    my $t = shift @$us;
    my $values = {};
    {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'crop' or $value eq 'cross') {
          if ($self->media_resolver->{prop_value}->{marks}->{$value}) {
            last if defined $values->{$value};
            $values->{$value} = 1;
          } else {
            last;
          }
        } elsif ($value eq 'none') {
          last if keys %$values;
        } else {
          last;
        }
      } else {
        last;
      }
      $t = shift @$us;
      $t = shift @$us while $t->{type} == S_TOKEN;
      if ($t->{type} == EOF_TOKEN) {
        if (keys %$values) {
          return ['KEYWORDSET', $values];
        } else {
          return ['KEYWORD', 'none'];
        }
      }
      last unless keys %$values;
      redo;
    }

    $self->onerror->(type => 'CSS syntax error', text => q['marks'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_as_specified,
}; # marks

## <http://dev.w3.org/csswg/css-page/#page-size-prop> [CSSPAGE].
$Key->{size} = {
  css => 'size',
  dom => 'size',
  parse_longhand => sub {
    my ($self, $us) = @_;
    $us = [grep { $_->{type} != S_TOKEN } @$us];
    if (@$us == 2) {
      if ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($value eq 'auto' or
            $value eq 'portrait' or
            $value eq 'landscape') {
          return ['KEYWORD', $value];
        }
      } else {
        my $v1 = $Web::CSS::Values::NNLengthParser->($self, $us); # or undef
        return undef unless defined $v1;
        return ['DIMENSION', $v1, $v1];
      }
    } elsif (@$us == 3) {
      my $v1 = $Web::CSS::Values::NNLengthParser->($self, [$us->[0], _to_eof_token $us->[1]]);
      my $v2 = defined $v1 ? $Web::CSS::Values::NNLengthParser->($self, [$us->[1], $us->[2]]) : undef;
      return undef unless defined $v2;
      return ['DIMENSION', $v1, $v2];
    }

    $self->onerror->(type => 'CSS syntax error', text => q['size'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => sub {
    my ($self, $element, $prop_name, $specified_value) = @_;

    if (defined $specified_value and $specified_value->[0] eq 'SIZE') {
      my $v = ['SIZE'];
      for (@$specified_value[1..2]) {
        push @$v, $compute_length->($self, $element, $prop_name, $_);
      }
      return $v;
    }

    return $specified_value;
  },
}; # size

## <http://dev.w3.org/csswg/css-page/#using-named-pages> [CSSPAGE].
$Key->{page} = {
  css => 'page',
  dom => 'page',
  parse_longhand => sub {
    my ($self, $us) = @_;
    if (@$us == 2) {
      if ($us->[0]->{type} == IDENT_TOKEN) {
        my $value = $us->[0]->{value};
        if ($value =~ /\A[Aa][Uu][Tt][Oo]\z/) {
          return ['KEYWORD', 'auto'];
        } else {
          return ['CUSTOMID', $value];
        }
      }
    }

    $self->onerror->(type => 'CSS syntax error', text => q['page'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $us->[0]);
    return undef;
  }, # parse_longhand
  initial => ['KEYWORD', 'auto'],
  inherited => 0,
  compute => $compute_as_specified,
}; # page

for my $key (keys %$Key) {
  my $def = $Key->{$key};
  $def->{key} ||= $key;
  $Attr->{$def->{dom}} ||= $def;
  $Prop->{$def->{css}} ||= $def;
  if ($def->{keyword} and not $def->{parse_longhand}) {
    $def->{parse_longhand} = $Web::CSS::Values::GetKeywordParser->($def->{keyword}, $def->{css});
  }
  for (@{$def->{longhand_subprops} or []}) {
    $Key->{$_}->{shorthand_keys} ||= [$key];
  }
} # $key

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
