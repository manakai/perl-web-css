package Web::CSS::Props;
use strict;
use warnings;
our $VERSION = '6.0';
use Web::CSS::Tokenizer;
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
##     shorthand_prop      Reference to the shorthand property
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
        if ($value eq 'none') {
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
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
}; # margin-left

$Key->{$_}->{parse_longhand} = sub {
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
      if ($value eq 'auto') {
        return ['KEYWORD', $value];
      }
    }
  }

  $self->onerror->(type => 'CSS syntax error', text => q['margin-*'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $us->[0]);
  return undef;
} for qw(margin_top margin_right margin_bottom margin_left); # parse_longhand

# XXX---XXX

$Prop->{top} = {
  css => 'top',
  dom => 'top',
  key => 'top',
  parse => $Key->{margin_top}->{parse},
  allow_negative => 1,
  keyword => {auto => 1},
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
};
$Attr->{top} = $Prop->{top};
$Key->{top} = $Prop->{top};

$Prop->{bottom} = {
  css => 'bottom',
  dom => 'bottom',
  key => 'bottom',
  allow_negative => 1,
  keyword => {auto => 1},
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute_multiple => $Prop->{top}->{compute_multiple},
};
$Attr->{bottom} = $Prop->{bottom};
$Key->{bottom} = $Prop->{bottom};

$Prop->{left} = {
  css => 'left',
  dom => 'left',
  key => 'left',
  allow_negative => 1,
  keyword => {auto => 1},
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
};
$Attr->{left} = $Prop->{left};
$Key->{left} = $Prop->{left};

$Prop->{right} = {
  css => 'right',
  dom => 'right',
  key => 'right',
  allow_negative => 1,
  keyword => {auto => 1},
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute_multiple => $Prop->{left}->{compute_multiple},
};
$Attr->{right} = $Prop->{right};
$Key->{right} = $Prop->{right};

$Prop->{width} = {
  css => 'width',
  dom => 'width',
  key => 'width',
  #allow_negative => 0,
  keyword => {
    auto => 1,
    
    ## Firefox 3
    '-moz-max-content' => 2, '-moz-min-content' => 2, 
    '-moz-available' => 2, '-moz-fit-content' => 2,
        ## NOTE: By "2", it represents that the parser must be configured
        ## to allow these values.
  },
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => $compute_length,
      ## NOTE: See <http://suika.fam.cx/gate/2005/sw/width> for
      ## browser compatibility issues.
};
$Attr->{width} = $Prop->{width};
$Key->{width} = $Prop->{width};

$Prop->{'min-width'} = {
  css => 'min-width',
  dom => 'min_width',
  key => 'min_width',
  #allow_negative => 0,
  keyword => {
    ## Firefox 3
    '-moz-max-content' => 2, '-moz-min-content' => 2, 
    '-moz-available' => 2, '-moz-fit-content' => 2,
  },
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
};
$Attr->{min_width} = $Prop->{'min-width'};
$Key->{min_width} = $Prop->{'min-width'};

$Prop->{'max-width'} = {
  css => 'max-width',
  dom => 'max_width',
  key => 'max_width',
  #allow_negative => 0,
  keyword => {
    none => 1,
    
    ## Firefox 3
    '-moz-max-content' => 2, '-moz-min-content' => 2, 
    '-moz-available' => 2, '-moz-fit-content' => 2,
  },
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_length,
};
$Attr->{max_width} = $Prop->{'max-width'};
$Key->{max_width} = $Prop->{'max-width'};

$Prop->{height} = {
  css => 'height',
  dom => 'height',
  key => 'height',
  #allow_negative => 0,
  keyword => {auto => 1},
  initial => ['KEYWORD', 'auto'],
  #inherited => 0,
  compute => $compute_length,
      ## NOTE: See <http://suika.fam.cx/gate/2005/sw/height> for
      ## browser compatibility issues.
};
$Attr->{height} = $Prop->{height};
$Key->{height} = $Prop->{height};

$Prop->{'min-height'} = {
  css => 'min-height',
  dom => 'min_height',
  key => 'min_height',
  #allow_negative => 0,
  #keyword => {},
  initial => ['DIMENSION', 0, 'px'],
  #inherited => 0,
  compute => $compute_length,
};
$Attr->{min_height} = $Prop->{'min-height'};
$Key->{min_height} = $Prop->{'min-height'};

$Prop->{'max-height'} = {
  css => 'max-height',
  dom => 'max_height',
  key => 'max_height',
  #allow_negative => 0,
  keyword => {none => 1},
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_length,
};
$Attr->{max_height} = $Prop->{'max-height'};
$Key->{max_height} = $Prop->{'max-height'};

$Prop->{'line-height'} = {
  css => 'line-height',
  dom => 'line_height',
  key => 'line_height',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    ## NOTE: Similar to 'margin-top', but different handling
    ## for unitless numbers.

    my $has_sign;
    my $sign = 1;
    if ($t->{type} == MINUS_TOKEN) {
      $t = $tt->get_next_token;
      $sign = -1;
      $has_sign = 1;
    } elsif ($t->{type} == PLUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
    }

    if ($t->{type} == DIMENSION_TOKEN) {
      my $value = $t->{number} * $sign;
      my $unit = lc $t->{value}; ## TODO: case
      if ($length_unit->{$unit} and $value >= 0) {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['DIMENSION', $value, $unit]});
      }
    } elsif ($t->{type} == PERCENTAGE_TOKEN) {
      my $value = $t->{number} * $sign;
      if ($value >= 0) {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['PERCENTAGE', $value]});
      }
    } elsif ($t->{type} == NUMBER_TOKEN) {
      my $value = $t->{number} * $sign;
      if ($value >= 0) {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['NUMBER', $value]});
      }
    } elsif (not $has_sign and $t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ($value eq 'normal') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['KEYWORD', $value]});        
      } elsif ($value eq 'inherit') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['INHERIT']});
      }
    }
    
    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
  initial => ['KEYWORD', 'normal'],
  inherited => 1,
  compute => $compute_length,
};
$Attr->{line_height} = $Prop->{'line-height'};
$Key->{line_height} = $Prop->{'line-height'};

$Prop->{'vertical-align'} = {
  css => 'vertical-align',
  dom => 'vertical_align',
  key => 'vertical_align',
  allow_negative => 1,
  keyword => {
    baseline => 1, sub => 1, super => 1, top => 1, 'text-top' => 1,
    middle => 1, bottom => 1, 'text-bottom' => 1,
  },
  ## NOTE: Currently, we don't support option to select subset of keywords
  ## supported by application (i.e. 
  ## $parser->{prop_value}->{'line-height'->{$keyword}).  Should we support
  ## it?
  initial => ['KEYWORD', 'baseline'],
  #inherited => 0,
  compute => $compute_length,
      ## NOTE: See <http://suika.fam.cx/gate/2005/sw/vertical-align> for
      ## browser compatibility issues.
};
$Attr->{vertical_align} = $Prop->{'vertical-align'};
$Key->{vertical_align} = $Prop->{'vertical-align'};

$Prop->{'text-indent'} = {
  css => 'text-indent',
  dom => 'text_indent',
  key => 'text_indent',
  allow_negative => 1,
  keyword => {},
  initial => ['DIMENSION', 0, 'px'],
  inherited => 1,
  compute => $compute_length,
};
$Attr->{text_indent} = $Prop->{'text-indent'};
$Key->{text_indent} = $Prop->{'text-indent'};

$Prop->{'background-position-x'} = {
  css => 'background-position-x',
  dom => 'background_position_x',
  key => 'background_position_x',
  parse_longhand => sub {
    my ($self, $tokens) = @_;

    # XXX

    if (@$tokens == 2) {
      if ($tokens->[0]->{type} == DIMENSION_TOKEN) {
        my $unit = $tokens->[0]->{value};
        $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        if ($length_unit->{$unit}) {
          return ['LENGTH', $tokens->[0]->{number}, $unit];
        }
      } elsif ($tokens->[0]->{type} == PERCENTAGE_TOKEN) {
        return ['PERCENTAGE', $tokens->[0]->{number}];
      } elsif ($tokens->[0]->{type} == NUMBER_TOKEN and
               $tokens->[0]->{number} == 0) {
        return ['LENGTH', $tokens->[0]->{value}, 'px'];
      } elsif ($tokens->[0]->{type} == IDENT_TOKEN) {
        my $value = $tokens->[0]->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insenstiive.
        if ($Key->{background_position_x}->{keyword}->{$value} and
            $self->context->{prop_value}->{'background-position-x'}->{$value}) {
          return ['KEYWORD', $value];
        }
      }
    }

    $self->onerror->(type => "css:value:'background-position-x':syntax error", # XXX
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $tokens->[0]);
  },
  allow_negative => 1,
  keyword => {left => 1, center => 1, right => 1},
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
  serialize_multiple => $Key->{background_color}->{serialize_multiple},
};
$Attr->{background_position_x} = $Prop->{'background-position-x'};
$Key->{background_position_x} = $Prop->{'background-position-x'};

$Prop->{'background-position-y'} = {
  css => 'background-position-y',
  dom => 'background_position_y',
  key => 'background_position_y',
  allow_negative => 1,
  keyword => {top => 1, center => 1, bottom => 1},
  serialize_multiple => $Key->{background_color}->{serialize_multiple},
  initial => ['PERCENTAGE', 0],
  #inherited => 0,
  compute => $Prop->{'background-position-x'}->{compute},
};
$Attr->{background_position_y} = $Prop->{'background-position-y'};
$Key->{background_position_y} = $Prop->{'background-position-y'};

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

$Prop->{'border-top-width'} = {
  css => 'border-top-width',
  dom => 'border_top_width',
  key => 'border_top_width',
  #allow_negative => 0,
  keyword => {thin => 1, medium => 1, thick => 1},
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
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
  ## NOTE: CSS3 will allow <percentage> as an option in <border-width>.
  ## Opera 9 has already implemented it.
};
$Attr->{border_top_width} = $Prop->{'border-top-width'};
$Key->{border_top_width} = $Prop->{'border-top-width'};

$Prop->{'border-right-width'} = {
  css => 'border-right-width',
  dom => 'border_right_width',
  key => 'border_right_width',
  parse => $Prop->{'border-top-width'}->{parse},
  #allow_negative => 0,
  keyword => {thin => 1, medium => 1, thick => 1},
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => $Prop->{'border-top-width'}->{compute},
};
$Attr->{border_right_width} = $Prop->{'border-right-width'};
$Key->{border_right_width} = $Prop->{'border-right-width'};

$Prop->{'border-bottom-width'} = {
  css => 'border-bottom-width',
  dom => 'border_bottom_width',
  key => 'border_bottom_width',
  parse => $Prop->{'border-top-width'}->{parse},
  #allow_negative => 0,
  keyword => {thin => 1, medium => 1, thick => 1},
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => $Prop->{'border-top-width'}->{compute},
};
$Attr->{border_bottom_width} = $Prop->{'border-bottom-width'};
$Key->{border_bottom_width} = $Prop->{'border-bottom-width'};

$Prop->{'border-left-width'} = {
  css => 'border-left-width',
  dom => 'border_left_width',
  key => 'border_left_width',
  parse => $Prop->{'border-top-width'}->{parse},
  #allow_negative => 0,
  keyword => {thin => 1, medium => 1, thick => 1},
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => $Prop->{'border-top-width'}->{compute},
};
$Attr->{border_left_width} = $Prop->{'border-left-width'};
$Key->{border_left_width} = $Prop->{'border-left-width'};

$Prop->{'outline-width'} = {
  css => 'outline-width',
  dom => 'outline_width',
  key => 'outline_width',
  parse => $Prop->{'border-top-width'}->{parse},
  #allow_negative => 0,
  keyword => {thin => 1, medium => 1, thick => 1},
  serialize_multiple => $Key->{outline_color}->{serialize_multiple},
  initial => ['KEYWORD', 'medium'],
  #inherited => 0,
  compute => $Prop->{'border-top-width'}->{compute},
};
$Attr->{outline_width} = $Prop->{'outline-width'};
$Key->{outline_width} = $Prop->{'outline-width'};

$Prop->{'font-weight'} = {
  css => 'font-weight',
  dom => 'font_weight',
  key => 'font_weight',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    my $has_sign;
    if ($t->{type} == PLUS_TOKEN) {
      $has_sign = 1;
      $t = $tt->get_next_token;
    }

    if ($t->{type} == NUMBER_TOKEN) {
      ## ISSUE: See <http://suika.fam.cx/gate/2005/sw/font-weight> for
      ## browser compatibility issue.
      my $value = $t->{number} + 0;
      $t = $tt->get_next_token;
      if ($value % 100 == 0 and 100 <= $value and $value <= 900) {
        return ($t, {$prop_name => ['WEIGHT', $value, 0]});
      }
    } elsif (not $has_sign and $t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ({
           normal => 1, bold => 1, bolder => 1, lighter => 1,
          }->{$value}) {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['KEYWORD', $value]});
      } elsif ($value eq 'inherit') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['INHERIT']});
      }
    }
    
    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
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
};
$Attr->{font_weight} = $Prop->{'font-weight'};
$Key->{font_weight} = $Prop->{'font-weight'};

my $uri_or_none_parser = sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    if ($t->{type} == URI_TOKEN) {
      my $value = $t->{value};
      $t = $tt->get_next_token;
      return ($t, {$prop_name => ['URI', $value, $self->context->base_urlref]});
    } elsif ($t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      $t = $tt->get_next_token;
      if ($value eq 'none') {
        ## NOTE: |none| is the default value and therefore it must be
        ## supported anyway.
        return ($t, {$prop_name => ["KEYWORD", 'none']});
      } elsif ($value eq 'inherit') {
        return ($t, {$prop_name => ['INHERIT']});
      }
    ## NOTE: None of Firefox2, WinIE6, and Opera9 support this case.
    #} elsif ($t->{type} == URI_INVALID_TOKEN) {
    #  my $value = $t->{value};
    #  $t = $tt->get_next_token;
    #  if ($t->{type} == EOF_TOKEN) {
    #    $onerror->(type => 'uri not closed',
    #               level => 'm',
    #               uri => $self->context->urlref,
    #               token => $t);
    #    
    #    return ($t, {$prop_name => ['URI', $value, $self->context->base_urlref]});
    #  }
    }
    
    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
}; # $uri_or_none_parser

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

$Prop->{'list-style-image'} = {
  css => 'list-style-image',
  dom => 'list_style_image',
  key => 'list_style_image',
  parse => $uri_or_none_parser,
  initial => ['KEYWORD', 'none'],
  inherited => 1,
  compute => $compute_uri_or_none,
};
$Attr->{list_style_image} = $Prop->{'list-style-image'};
$Key->{list_style_image} = $Prop->{'list-style-image'};

$Prop->{'background-image'} = {
  css => 'background-image',
  dom => 'background_image',
  key => 'background_image',
  parse => $uri_or_none_parser,
  serialize_multiple => $Key->{background_color}->{serialize_multiple},
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_uri_or_none,
};
$Attr->{background_image} = $Prop->{'background-image'};
$Key->{background_image} = $Prop->{'background-image'};

$Attr->{font_stretch} =
$Key->{font_stretch} =
$Prop->{'font-stretch'} = {
  css => 'font-stretch',
  dom => 'font_stretch',
  key => 'font_stretch',
  keyword => {
    qw/normal 1 wider 1 narrower 1 ultra-condensed 1 extra-condensed 1
       condensed 1 semi-condensed 1 semi-expanded 1 expanded 1 
       extra-expanded 1 ultra-expanded 1/,
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
};

$Attr->{writing_mode} =
$Key->{writing_mode} =
$Prop->{'writing-mode'} = {
  css => 'writing-mode',
  dom => 'writing_mode',
  key => 'writing_mode',
  keyword => {
    'lr' => 1, 'lr-tb' => 1,
    'rl' => 1, 'rl-tb' => 1,
    'tb' => 1, 'tb-rl' => 1,
  },
  initial => ['KEYWORD', 'lr-tb'],
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
};

$Attr->{text_anchor} =
$Key->{text_anchor} =
$Prop->{'text-anchor'} = {
  css => 'text-anchor',
  dom => 'text_anchor', ## TODO: manakai extension.  Documentation.
  key => 'text_anchor',
  keyword => {
    start => 1, middle => 1, end => 1,
  },
  initial => ['KEYWORD', 'start'],
  inherited => 1,
  compute => $compute_as_specified,
};

$Attr->{dominant_baseline} =
$Key->{dominant_baseline} =
$Prop->{'dominant-baseline'} = {
  css => 'dominant-baseline',
  dom => 'dominant_baseline', ## TODO: manakai extension.  Documentation.
  key => 'dominant_baseline',
  keyword => {
    qw/auto 1 use-script 1 no-change 1 reset-size 1 ideographic 1 alphabetic 1
       hanging 1 mathematical 1 central 1 middle 1 text-after-edge 1
       text-before-edge 1/
  },
  initial => ['KEYWORD', 'auto'],
  inherited => 0,
  compute => $compute_as_specified,
};

$Attr->{alignment_baseline} =
$Key->{alignment_baseline} =
$Prop->{'alignment-baseline'} = {
  css => 'alignment-baseline',
  dom => 'alignment_baseline', ## TODO: manakai extension.  Documentation.
  key => 'alignment_baseline',
  keyword => {
    qw/auto 1 baseline 1 before-edge 1 text-before-edge 1 middle 1 central 1
       after-edge 1 text-after-edge 1 ideographic 1 alphabetic 1 hanging 1
       mathematical 1/
  },
  initial => ['KEYWORD', 'auto'],
  inherited => 0,
  compute => $compute_as_specified,
};

my $border_style_keyword = {
  none => 1, hidden => 1, dotted => 1, dashed => 1, solid => 1,
  double => 1, groove => 1, ridge => 1, inset => 1, outset => 1,
};

$Prop->{'border-top-style'} = {
  css => 'border-top-style',
  dom => 'border_top_style',
  key => 'border_top_style',
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
  keyword => $border_style_keyword,
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
};
$Attr->{border_top_style} = $Prop->{'border-top-style'};
$Key->{border_top_style} = $Prop->{'border-top-style'};

$Prop->{'border-right-style'} = {
  css => 'border-right-style',
  dom => 'border_right_style',
  key => 'border_right_style',
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
  keyword => $border_style_keyword,
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
};
$Attr->{border_right_style} = $Prop->{'border-right-style'};
$Key->{border_right_style} = $Prop->{'border-right-style'};

$Prop->{'border-bottom-style'} = {
  css => 'border-bottom-style',
  dom => 'border_bottom_style',
  key => 'border_bottom_style',
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
  keyword => $border_style_keyword,
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
};
$Attr->{border_bottom_style} = $Prop->{'border-bottom-style'};
$Key->{border_bottom_style} = $Prop->{'border-bottom-style'};

$Prop->{'border-left-style'} = {
  css => 'border-left-style',
  dom => 'border_left_style',
  key => 'border_left_style',
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
  keyword => $border_style_keyword,
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
};
$Attr->{border_left_style} = $Prop->{'border-left-style'};
$Key->{border_left_style} = $Prop->{'border-left-style'};

$Prop->{'outline-style'} = {
  css => 'outline-style',
  dom => 'outline_style',
  key => 'outline_style',
  serialize_multiple => $Key->{outline_color}->{serialize_multiple},
  keyword => {%$border_style_keyword},
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_as_specified,
};
$Attr->{outline_style} = $Prop->{'outline-style'};
$Key->{outline_style} = $Prop->{'outline-style'};
delete $Prop->{'outline-style'}->{keyword}->{hidden};

my $generic_font_keywords = {
  serif => 1, 'sans-serif' => 1, cursive => 1,
  fantasy => 1, monospace => 1, '-manakai-default' => 1,
  '-manakai-caption' => 1, '-manakai-icon' => 1,
  '-manakai-menu' => 1, '-manakai-message-box' => 1, 
  '-manakai-small-caption' => 1, '-manakai-status-bar' => 1,
};
## NOTE: "All five generic font families are defined to exist in all CSS
## implementations (they need not necessarily map to five distinct actual
## fonts)." [CSS 2.1].
## NOTE: "If no font with the indicated characteristics exists on a given
## platform, the user agent should either intelligently substitute (e.g., a
## smaller version of the 'caption' font might be used for the 'small-caption'
## font), or substitute a user agent default font." [CSS 2.1].

$Prop->{'font-family'} = {
  css => 'font-family',
  dom => 'font_family',
  key => 'font_family',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    ## NOTE: See <http://suika.fam.cx/gate/2005/sw/font-family> for
    ## how chaotic browsers are!

    ## NOTE: Opera 9 allows NUMBER and DIMENSION as part of 
    ## <font-family>, while Firefox 2 does not.

    my @prop_value;

    my $font_name = '';
    my $may_be_generic = 1;
    my $may_be_inherit = ($prop_name ne 'font');
    my $has_s = 0;
    F: {
      if ($t->{type} == IDENT_TOKEN) {
        undef $may_be_inherit if $has_s or length $font_name;
        undef $may_be_generic if $has_s or length $font_name;
        $font_name .= ' ' if $has_s;
        $font_name .= $t->{value};
        undef $has_s;
        $t = $tt->get_next_token;
      } elsif ($t->{type} == STRING_TOKEN) {
        $font_name .= ' ' if $has_s;
        $font_name .= $t->{value};
        undef $may_be_inherit;
        undef $may_be_generic;
        undef $has_s;
        $t = $tt->get_next_token;
      } elsif ($t->{type} == COMMA_TOKEN) { ## TODO: case
        if ($may_be_generic and $generic_font_keywords->{lc $font_name}) {
          push @prop_value, ['KEYWORD', $font_name];
        } elsif (not $may_be_generic or length $font_name) {
          push @prop_value, ["STRING", $font_name];
        }
        undef $may_be_inherit;
        $may_be_generic = 1;
        undef $has_s;
        $font_name = '';
        $t = $tt->get_next_token;
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      } elsif ($t->{type} == S_TOKEN) {
        $has_s = 1;
        $t = $tt->get_next_token;
      } else {
        if ($may_be_generic and $generic_font_keywords->{lc $font_name}) {
          push @prop_value, ['KEYWORD', $font_name]; ## TODO: case
        } elsif (not $may_be_generic or length $font_name) {
          push @prop_value, ['STRING', $font_name];
        } else {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          return ($t, undef);
        }
        last F;
      }
      redo F;
    } # F

    if ($may_be_inherit and
        @prop_value == 1 and
        $prop_value[0]->[0] eq 'STRING' and
        lc $prop_value[0]->[1] eq 'inherit') { ## TODO: case
      return ($t, {$prop_name => ['INHERIT']});
    } else {
      unshift @prop_value, 'FONT';
      return ($t, {$prop_name => \@prop_value});
    }
  },
  initial => ['FONT', ['KEYWORD', '-manakai-default']],
  inherited => 1,
  compute => $compute_as_specified,
};
$Attr->{font_family} = $Prop->{'font-family'};
$Key->{font_family} = $Prop->{'font-family'};

$Prop->{cursor} = {
  css => 'cursor',
  dom => 'cursor',
  key => 'cursor',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    ## NOTE: See <http://suika.fam.cx/gate/2005/sw/cursor> for browser
    ## compatibility issues.

    my @prop_value = ('CURSOR');

    F: {
      if ($t->{type} == IDENT_TOKEN) {
        my $v = lc $t->{value}; ## TODO: case
        if ($Prop->{$prop_name}->{keyword}->{$v}) {
          push @prop_value, ['KEYWORD', $v];
          $t = $tt->get_next_token;
          last F;
        } elsif ($v eq 'hand' and
                 $Prop->{$prop_name}->{keyword}->{pointer}) {
          ## TODO: add test
          $onerror->(type => 'CSS cursor hand',
                     level => 'm', # not valid <'cursor'>
                     uri => $self->context->urlref,
                     token => $t);
          push @prop_value, ['KEYWORD', 'pointer'];
          $t = $tt->get_next_token;
          last F;
        } elsif ($v eq 'inherit' and @prop_value == 1) {
          $t = $tt->get_next_token;
          return ($t, {$prop_name => ['INHERIT']});
        } else {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          return ($t, undef);
        }
      } elsif ($t->{type} == URI_TOKEN) {
        push @prop_value, ['URI', $t->{value}, $self->context->base_urlref];
        $t = $tt->get_next_token;
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    
      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      if ($t->{type} == COMMA_TOKEN) {
        $t = $tt->get_next_token;
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        redo F;
      }
    } # F

    return ($t, {$prop_name => \@prop_value});
  },
  keyword => {
    auto => 1, crosshair => 1, default => 1, pointer => 1, move => 1,
    'e-resize' => 1, 'ne-resize' => 1, 'nw-resize' => 1, 'n-resize' => 1,
    'n-resize' => 1, 'se-resize' => 1, 'sw-resize' => 1, 's-resize' => 1,
    'w-resize' => 1, text => 1, wait => 1, help => 1, progress => 1,
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
};
$Attr->{cursor} = $Prop->{cursor};
$Key->{cursor} = $Prop->{cursor};

$Prop->{'border-style'} = {
  css => 'border-style',
  dom => 'border_style',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    my %prop_value;
    if ($t->{type} == IDENT_TOKEN) {
      my $prop_value = lc $t->{value}; ## TODO: case folding
      $t = $tt->get_next_token;
      if ($border_style_keyword->{$prop_value} and
          $self->{prop_value}->{'border-top-style'}->{$prop_value}) {
        $prop_value{'border-top-style'} = ["KEYWORD", $prop_value];
      } elsif ($prop_value eq 'inherit') {
        $prop_value{'border-top-style'} = ["INHERIT"];
        $prop_value{'border-right-style'} = $prop_value{'border-top-style'};
        $prop_value{'border-bottom-style'} = $prop_value{'border-top-style'};
        $prop_value{'border-left-style'} = $prop_value{'border-right-style'};
        return ($t, \%prop_value);
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
      $prop_value{'border-right-style'} = $prop_value{'border-top-style'};
      $prop_value{'border-bottom-style'} = $prop_value{'border-top-style'};
      $prop_value{'border-left-style'} = $prop_value{'border-right-style'};
    } else {
      $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                 level => 'm',
                 uri => $self->context->urlref,
                 token => $t);
      return ($t, undef);
    }

    $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    if ($t->{type} == IDENT_TOKEN) {
      my $prop_value = lc $t->{value}; ## TODO: case folding
      $t = $tt->get_next_token;
      if ($border_style_keyword->{$prop_value} and
          $self->{prop_value}->{'border-right-style'}->{$prop_value}) {
        $prop_value{'border-right-style'} = ["KEYWORD", $prop_value];
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
      $prop_value{'border-left-style'} = $prop_value{'border-right-style'};

      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      if ($t->{type} == IDENT_TOKEN) {
        my $prop_value = lc $t->{value}; ## TODO: case folding
        $t = $tt->get_next_token;
        if ($border_style_keyword->{$prop_value} and
            $self->{prop_value}->{'border-bottom-style'}->{$prop_value}) {
          $prop_value{'border-bottom-style'} = ["KEYWORD", $prop_value];
        } else {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          return ($t, undef);
        }
        
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == IDENT_TOKEN) {
          my $prop_value = lc $t->{value}; ## TODO: case folding
          $t = $tt->get_next_token;
          if ($border_style_keyword->{$prop_value} and
              $self->{prop_value}->{'border-left-style'}->{$prop_value}) {
            $prop_value{'border-left-style'} = ["KEYWORD", $prop_value];
          } else {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          }
        }
      }
    }        

    return ($t, \%prop_value);
  },
  serialize_shorthand => sub {
    my ($se, $st) = @_;

    my @v;
    push @v, $se->serialize_prop_value ($st, 'border-top-style');
    my $i = $se->serialize_prop_priority ($st, 'border-top-style');
    return {} unless length $v[-1];
    push @v, $se->serialize_prop_value ($st, 'border-right-style');
    return {} unless length $v[-1];
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-right-style');
    push @v, $se->serialize_prop_value ($st, 'border-bottom-style');
    return {} unless length $v[-1];
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-bottom-style');
    push @v, $se->serialize_prop_value ($st, 'border-left-style');
    return {} unless length $v[-1];
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-left-style');

    my $v = 0;
    for (0..3) {
      $v++ if $v[$_] eq 'inherit';
    }
    if ($v == 4) {
      return {'border-style' => ['inherit', $i]};
    } elsif ($v) {
      return {};
    }

    pop @v if $v[1] eq $v[3];
    pop @v if $v[0] eq $v[2];
    pop @v if $v[0] eq $v[1];
    return {'border-style' => [(join ' ', @v), $i]};
  },
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
};
$Attr->{border_style} = $Prop->{'border-style'};

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

$Prop->{'border-top'} = {
  css => 'border-top',
  dom => 'border_top',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    ## TODO: Need to be rewritten.

    my %prop_value;
    my $pv;
    ## NOTE: Since $onerror is disabled for three invocations below,
    ## some informative warning messages (if they are added someday) will not
    ## be reported.
    ($t, $pv) = $Web::CSS::Values::GetColorParser->()->($self, $prop_name.'-color', $tt, $t, sub {});
    if (defined $pv) {
      if ($pv->{$prop_name.'-color'}->[0] eq 'INHERIT') {
        return ($t, {$prop_name.'-color' => ['INHERIT'],
                     $prop_name.'-style' => ['INHERIT'],
                     $prop_name.'-width' => ['INHERIT']});
      } else {
        $prop_value{$prop_name.'-color'} = $pv->{$prop_name.'-color'};
      }
    } else {
      ($t, $pv) = $Prop->{'border-top-width'}->{parse}
          ->($self, $prop_name.'-width', $tt, $t, sub {});
      if (defined $pv) {
        $prop_value{$prop_name.'-width'} = $pv->{$prop_name.'-width'};
      } else {
        ($t, $pv) = $Prop->{'border-top-style'}->{parse}
            ->($self, $prop_name.'-style', $tt, $t, sub {});
        if (defined $pv) {
          $prop_value{$prop_name.'-style'} = $pv->{$prop_name.'-style'};
        } else {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          return ($t, undef);
        }
      }
    }

    for (1..2) {
      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      if ($t->{type} == IDENT_TOKEN) {
        my $prop_value = lc $t->{value}; ## TODO: case
        if ($border_style_keyword->{$prop_value} and
            $self->{prop_value}->{'border-top-style'}->{$prop_value} and
            not defined $prop_value{$prop_name.'-style'}) {
          $prop_value{$prop_name.'-style'} = ['KEYWORD', $prop_value];
          $t = $tt->get_next_token;
          next;
        } elsif ({thin => 1, medium => 1, thick => 1}->{$prop_value} and
                 not defined $prop_value{$prop_name.'-width'}) {
          $prop_value{$prop_name.'-width'} = ['KEYWORD', $prop_value];
          $t = $tt->get_next_token;
          next;
        }
      }

      undef $pv;
      ($t, $pv) = $Web::CSS::Values::GetColorParser->()->($self, $prop_name.'-color', $tt, $t, $onerror)
          if not defined $prop_value{$prop_name.'-color'} and
              {
                IDENT_TOKEN, 1,
                HASH_TOKEN, 1, NUMBER_TOKEN, 1, DIMENSION_TOKEN, 1,
                FUNCTION_TOKEN, 1,
              }->{$t->{type}};
      if (defined $pv) {
        if ($pv->{$prop_name.'-color'}->[0] eq 'INHERIT') {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
        } else {
          $prop_value{$prop_name.'-color'} = $pv->{$prop_name.'-color'};
        }
      } else {
        undef $pv;
        ($t, $pv) = $Prop->{'border-top-width'}->{parse}
            ->($self, $prop_name.'-width',
               $tt, $t, $onerror)
            if not defined $prop_value{$prop_name.'-width'} and
                {
                  DIMENSION_TOKEN, 1,
                  NUMBER_TOKEN, 1,
                  IDENT_TOKEN, 1,
                  MINUS_TOKEN, 1,
                }->{$t->{type}};
        if (defined $pv) {
          if ($pv->{$prop_name.'-width'}->[0] eq 'INHERIT') {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
          } else {
            $prop_value{$prop_name.'-width'} = $pv->{$prop_name.'-width'};
          }
        } else {
          last;
        }
      }    
    }

    $prop_value{$prop_name.'-color'}
        ||= $Prop->{$prop_name.'-color'}->{initial};
    $prop_value{$prop_name.'-width'}
        ||= $Prop->{$prop_name.'-width'}->{initial};
    $prop_value{$prop_name.'-style'}
        ||= $Prop->{$prop_name.'-style'}->{initial};
    
    return ($t, \%prop_value);
  },
  serialize_shorthand => sub {
    my ($se, $st) = @_;

    my $w = $se->serialize_prop_value ($st, 'border-top-width');
    return {} unless length $w;
    my $i = $se->serialize_prop_priority ($st, 'border-top-width');
    my $s = $se->serialize_prop_value ($st, 'border-top-style');
    return {} unless length $s;
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-top-style');
    my $c = $se->serialize_prop_value ($st, 'border-top-color');
    return {} unless length $c;
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-top-color');

    my $v = 0;
    $v++ if $w eq 'inherit';
    $v++ if $s eq 'inherit';
    $v++ if $c eq 'inherit';
    if ($v == 3) {
      return {'border-top' => ['inherit', $i]};
    } elsif ($v) {
      return {};
    }

    return {'border-top' => [$w . ' ' . $s . ' ' . $c, $i]};
  },
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
};
$Attr->{border_top} = $Prop->{'border-top'};

$Prop->{'border-right'} = {
  css => 'border-right',
  dom => 'border_right',
  parse => $Prop->{'border-top'}->{parse},
  serialize_shorthand => sub {
    my ($se, $st) = @_;

    my $w = $se->serialize_prop_value ($st, 'border-right-width');
    return {} unless length $w;
    my $i = $se->serialize_prop_priority ($st, 'border-right-width');
    my $s = $se->serialize_prop_value ($st, 'border-right-style');
    return {} unless length $s;
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-right-style');
    my $c = $se->serialize_prop_value ($st, 'border-right-color');
    return {} unless length $c;
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-right-color');

    my $v = 0;
    $v++ if $w eq 'inherit';
    $v++ if $s eq 'inherit';
    $v++ if $c eq 'inherit';
    if ($v == 3) {
      return {'border-right' => ['inherit', $i]};
    } elsif ($v) {
      return {};
    }

    return {'border-right' => [$w . ' ' . $s . ' ' . $c, $i]};
  },
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
};
$Attr->{border_right} = $Prop->{'border-right'};

$Prop->{'border-bottom'} = {
  css => 'border-bottom',
  dom => 'border_bottom',
  parse => $Prop->{'border-top'}->{parse},
  serialize_shorthand => sub {
    my ($se, $st) = @_;

    my $w = $se->serialize_prop_value ($st, 'border-bottom-width');
    return {} unless length $w;
    my $i = $se->serialize_prop_priority ($st, 'border-bottom-width');
    my $s = $se->serialize_prop_value ($st, 'border-bottom-style');
    return {} unless length $s;
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-bottom-style');
    my $c = $se->serialize_prop_value ($st, 'border-bottom-color');
    return {} unless length $c;
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-bottom-color');

    my $v = 0;
    $v++ if $w eq 'inherit';
    $v++ if $s eq 'inherit';
    $v++ if $c eq 'inherit';
    if ($v == 3) {
      return {'border-bottom' => ['inherit', $i]};
    } elsif ($v) {
      return {};
    }

    return {'border-bottom' => [$w . ' ' . $s . ' ' . $c, $i]};
  },
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
};
$Attr->{border_bottom} = $Prop->{'border-bottom'};

$Prop->{'border-left'} = {
  css => 'border-left',
  dom => 'border_left',
  parse => $Prop->{'border-top'}->{parse},
  serialize_shorthand => sub {
    my ($se, $st) = @_;

    my $w = $se->serialize_prop_value ($st, 'border-left-width');
    return {} unless length $w;
    my $i = $se->serialize_prop_priority ($st, 'border-left-width');
    my $s = $se->serialize_prop_value ($st, 'border-left-style');
    return {} unless length $s;
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-left-style');
    my $c = $se->serialize_prop_value ($st, 'border-left-color');
    return {} unless length $c;
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-left-color');

    my $v = 0;
    $v++ if $w eq 'inherit';
    $v++ if $s eq 'inherit';
    $v++ if $c eq 'inherit';
    if ($v == 3) {
      return {'border-left' => ['inherit', $i]};
    } elsif ($v) {
      return {};
    }

    return {'border-left' => [$w . ' ' . $s . ' ' . $c, $i]};
  },
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
};
$Attr->{border_left} = $Prop->{'border-left'};

$Prop->{outline} = {
  css => 'outline',
  dom => 'outline',
  parse => $Prop->{'border-top'}->{parse}, # XXX 'outline-color'
  serialize_multiple => $Key->{outline_color}->{serialize_multiple},
};
$Attr->{outline} = $Prop->{outline};

$Prop->{border} = {
  css => 'border',
  dom => 'border',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;
    my $prop_value;
    ($t, $prop_value) = $Prop->{'border-top'}->{parse}
        ->($self, 'border-top', $tt, $t, $onerror);
    return ($t, undef) unless defined $prop_value;
    
    for (qw/border-right border-bottom border-left/) {
      $prop_value->{$_.'-color'} = $prop_value->{'border-top-color'}
          if defined $prop_value->{'border-top-color'};
      $prop_value->{$_.'-style'} = $prop_value->{'border-top-style'}
          if defined $prop_value->{'border-top-style'};
      $prop_value->{$_.'-width'} = $prop_value->{'border-top-width'}
          if defined $prop_value->{'border-top-width'};
    }
    return ($t, $prop_value);
  },
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
};
$Attr->{border} = $Prop->{border};

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

## NOTE: See <http://suika.fam.cx/gate/2005/sw/background-position> for
## browser compatibility problems.
$Key->{background_position} = {
  css => 'background-position',
  dom => 'background_position',
  is_shorthand => 1,
  longhand_subprops => [qw(background_position_x background_position_y)],
  parse_shorthand => sub {
    my ($self, $def, $tokens) = @_;
    
    my $prop_name = $def->{css};
    my %prop_value;

    my $t = shift @$tokens;
    if ($t->{type} == DIMENSION_TOKEN) {
      my $unit = $t->{value};
      $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($length_unit->{$unit}) {
        $prop_value{background_position_x} = ['LENGTH', $t->{number}, $unit];
        $prop_value{background_position_y} = ['PERCENTAGE', 50];
        $t = shift @$tokens;
      } else {
        $self->onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
        return undef;
      }
    } elsif ($t->{type} == PERCENTAGE_TOKEN) {
      $prop_value{background_position_x} = ['PERCENTAGE', $t->{number}];
      $prop_value{background_position_y} = ['PERCENTAGE', 50];
      $t = shift @$tokens;
    } elsif ($t->{type} == NUMBER_TOKEN and
             ($self->context->quirks or $t->{number} == 0)) {
      $prop_value{background_position_x} = ['LENGTH', $t->{number}, 'px'];
      $prop_value{background_position_y} = ['PERCENTAGE', 50];
      $t = shift @$tokens;
    } elsif ($t->{type} == IDENT_TOKEN) {
      my $prop_value = $t->{value};
      $prop_value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($prop_value eq 'left' or $prop_value eq 'right') {
        $prop_value{background_position_x} = ['KEYWORD', $prop_value];
        $prop_value{background_position_y} = ['KEYWORD', 'center'];
        $t = shift @$tokens;
      } elsif ($prop_value eq 'center') {
        $prop_value{background_position_x} = ['KEYWORD', $prop_value];
        $t = shift @$tokens;
        $t = shift @$tokens while $t->{type} == S_TOKEN;

        if ($t->{type} == IDENT_TOKEN) {
          my $prop_value = $t->{value};
          $prop_value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          if ($prop_value eq 'left' or $prop_value eq 'right') {
            $prop_value{background_position_y}
                = $prop_value{background_position_x};
            $prop_value{background_position_x} = ['KEYWORD', $prop_value];
            $t = shift @$tokens;
            unless ($t->{type} == EOF_TOKEN) {
              $self->onerror->(type => 'CSS syntax error',
                               text => qq['$prop_name'],
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
              return undef;
            }
            return \%prop_value;
          }
        } else {
          $prop_value{background_position_y} = ['KEYWORD', 'center'];
        }
      } elsif ($prop_value eq 'top' or $prop_value eq 'bottom') {
        $prop_value{background_position_y} = ['KEYWORD', $prop_value];
        $t = shift @$tokens;
        $t = shift @$tokens while $t->{type} == S_TOKEN;

        if ($t->{type} == IDENT_TOKEN) {
          my $prop_value = $t->{value};
          $prop_value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          if ({left => 1, center => 1, right => 1}->{$prop_value}) {
            $prop_value{background_position_x} = ['KEYWORD', $prop_value];
            $t = shift @$tokens;
            unless ($t->{type} == EOF_TOKEN) {
              $self->onerror->(type => 'CSS syntax error',
                               text => qq['$prop_name'],
                               level => 'm',
                               uri => $self->context->urlref,
                               token => $t);
              return undef;
            }
            return \%prop_value;
          }
        }
        $prop_value{background_position_x} = ['KEYWORD', 'center'];
        unless ($t->{type} == EOF_TOKEN) {
          $self->onerror->(type => 'CSS syntax error',
                           text => qq['$prop_name'],
                           level => 'm',
                           uri => $self->context->urlref,
                           token => $t);
          return undef;
        }
        return \%prop_value;
      } else {
        $self->onerror->(type => 'CSS syntax error',
                         text => qq['$prop_name'],
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
        return undef;
      }
    } else {
      $self->onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
      return undef;
    }

    $t = shift @$tokens while $t->{type} == S_TOKEN;

    if ($t->{type} == DIMENSION_TOKEN) {
      my $unit = $t->{value};
      $unit =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($length_unit->{$unit}) {
        $prop_value{background_position_y} = ['LENGTH', $t->{number}, $unit];
        $t = shift @$tokens;
      } else {
        $self->onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
        return undef;
      }
    } elsif ($t->{type} == PERCENTAGE_TOKEN) {
      $prop_value{background_position_y} = ['PERCENTAGE', $t->{number}];
      $t = shift @$tokens;
    } elsif ($t->{type} == NUMBER_TOKEN and
             ($self->context->quirks or $t->{number} == 0)) {
      $prop_value{background_position_y} = ['LENGTH', $t->{number}, 'px'];
      $t = shift @$tokens;
    } elsif ($t->{type} == IDENT_TOKEN) {
      my $value = $t->{value};
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ({top => 1, center => 1, bottom => 1}->{$value}) {
        $prop_value{'background-position-y'} = ['KEYWORD', $value];
        $t = shift @$tokens;
      }
    }

    unless ($t->{type} == EOF_TOKEN) {
      $self->onerror->(type => 'CSS syntax error',
                       text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
      return undef;
    }
    return \%prop_value;
  }, # parse_shorthand
  serialize_shorthand => sub {
    my ($se, $strings) = @_;
    return $strings->{background_position_x} . ' ' .$strings->{background_position_y};
  }, # serialize_shorthand
}; # background-position

$Prop->{background} = {
  css => 'background',
  dom => 'background',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;
    my %prop_value;
    B: for (1..5) {
      my $has_sign;
      my $sign = 1;
      if ($t->{type} == MINUS_TOKEN) {
        $sign = -1;
        $has_sign = 1;
        $t = $tt->get_next_token;
      } elsif ($t->{type} == PLUS_TOKEN) {
        $has_sign = 1;
        $t = $tt->get_next_token;
      }

      if (not $has_sign and $t->{type} == IDENT_TOKEN) {
        my $value = lc $t->{value}; ## TODO: case
        if ($Prop->{'background-repeat'}->{keyword}->{$value} and
            $self->{prop_value}->{'background-repeat'}->{$value} and
            not defined $prop_value{'background-repeat'}) {
          $prop_value{'background-repeat'} = ['KEYWORD', $value];
          $t = $tt->get_next_token;
        } elsif ($Prop->{'background-attachment'}->{keyword}->{$value} and
                 $self->{prop_value}->{'background-attachment'}->{$value} and
                 not defined $prop_value{'background-attachment'}) {
          $prop_value{'background-attachment'} = ['KEYWORD', $value];
          $t = $tt->get_next_token;
        } elsif ($value eq 'none' and
                 not defined $prop_value{'background-image'}) {
          $prop_value{'background-image'} = ['KEYWORD', $value];
          $t = $tt->get_next_token;
        } elsif ({left => 1, center => 1, right => 1}->{$value} and
                 not defined $prop_value{'background-position-x'}) {
          $prop_value{'background-position-x'} = ['KEYWORD', $value];
          $t = $tt->get_next_token;
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          my $sign = 1;
          my $has_sign;
          if ($t->{type} == MINUS_TOKEN) {
            $sign = -1;
            $has_sign = 1;
            $t = $tt->get_next_token;
          } elsif ($t->{type} == PLUS_TOKEN) {
            $has_sign = 1;
            $t = $tt->get_next_token;
          }
          if (not $has_sign and $t->{type} == IDENT_TOKEN) {
            my $value = lc $t->{value}; ## TODO: case
            if ({top => 1, bottom => 1, center => 1}->{$value}) {
              $prop_value{'background-position-y'} = ['KEYWORD', $value];
              $t = $tt->get_next_token;
            } elsif ($prop_value{'background-position-x'}->[1] eq 'center' and
                     $value eq 'left' or $value eq 'right') {
              $prop_value{'background-position-y'} = ['KEYWORD', 'center'];
              $prop_value{'background-position-x'} = ['KEYWORD', $value];
              $t = $tt->get_next_token;
            } else {
              $prop_value{'background-position-y'} = ['KEYWORD', 'center'];
            }
          } elsif ($t->{type} == DIMENSION_TOKEN) {
            my $value = $t->{number} * $sign;
            my $unit = lc $t->{value}; ## TODO: case
            $t = $tt->get_next_token;
            if ($length_unit->{$unit}) {
              $prop_value{'background-position-y'}
                  = ['DIMENSION', $value, $unit];
            } else {
              $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
              return ($t, undef);
            }
          } elsif ($t->{type} == PERCENTAGE_TOKEN) {
            my $value = $t->{number} * $sign;
            $t = $tt->get_next_token;
            $prop_value{'background-position-y'} = ['PERCENTAGE', $value];
          } elsif ($t->{type} == NUMBER_TOKEN and
                   ($self->context->quirks or $t->{number} == 0)) {
            my $value = $t->{number} * $sign;
            $t = $tt->get_next_token;
            $prop_value{'background-position-y'} = ['DIMENSION', $value, 'px'];
          } elsif ($has_sign) {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          } else {
            $prop_value{'background-position-y'} = ['KEYWORD', 'center'];
          }
        } elsif (($value eq 'top' or $value eq 'bottom') and
                 not defined $prop_value{'background-position-y'}) {
          $prop_value{'background-position-y'} = ['KEYWORD', $value];
          $t = $tt->get_next_token;
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          if ($t->{type} == IDENT_TOKEN and ## TODO: case
              {
                left => 1, center => 1, right => 1,
              }->{my $value = lc $t->{value}}) {
            $prop_value{'background-position-x'} = ['KEYWORD', $value];
            $t = $tt->get_next_token;
          } else {
            $prop_value{'background-position-x'} = ['KEYWORD', 'center'];
          }
        } elsif ($value eq 'inherit' and not keys %prop_value) {
          $prop_value{'background-color'} =
          $prop_value{'background-image'} =
          $prop_value{'background-repeat'} =
          $prop_value{'background-attachment'} = 
          $prop_value{'background-position-x'} =
          $prop_value{'background-position-y'} = ['INHERIT'];
          $t = $tt->get_next_token;
          return ($t, \%prop_value);
        } elsif (not defined $prop_value{'background-color'} or
                 not keys %prop_value) {
          ($t, my $pv) = $Web::CSS::Values::GetColorParser->()->($self, 'background', $tt, $t,
                                        $onerror);
          if (defined $pv) {
            $prop_value{'background-color'} = $pv->{background};
          } else {
            ## NOTE: An error should already be raiased.
            return ($t, undef);
          }
        }
      } elsif (($t->{type} == DIMENSION_TOKEN or
                $t->{type} == PERCENTAGE_TOKEN or
                ($t->{type} == NUMBER_TOKEN and
                 ($self->context->quirks or $t->{number} == 0))) and
               not defined $prop_value{'background-position-x'}) {
        if ($t->{type} == DIMENSION_TOKEN) {
          my $value = $t->{number} * $sign;
          my $unit = lc $t->{value}; ## TODO: case
          $t = $tt->get_next_token;
          if ($length_unit->{$unit}) {
            $prop_value{'background-position-x'}
                = ['DIMENSION', $value, $unit];
          } else {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          }
        } elsif ($t->{type} == PERCENTAGE_TOKEN) {
          my $value = $t->{number} * $sign;
          $t = $tt->get_next_token;
          $prop_value{'background-position-x'} = ['PERCENTAGE', $value];
        } elsif ($t->{type} == NUMBER_TOKEN and
                 ($self->context->quirks or $t->{number} == 0)) {
          my $value = $t->{number} * $sign;
          $t = $tt->get_next_token;
          $prop_value{'background-position-x'} = ['DIMENSION', $value, 'px'];
        } else {
          ## NOTE: Should not be happened.
          last B;
        }
        
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == MINUS_TOKEN) {
          $sign = -1;
          $has_sign = 1;
          $t = $tt->get_next_token;
        } elsif ($t->{type} == PLUS_TOKEN) {
          $has_sign = 1;
          $t = $tt->get_next_token;
        } else {
          undef $has_sign;
          $sign = 1;
        }

        if ($t->{type} == DIMENSION_TOKEN) {
          my $value = $t->{number} * $sign;
          my $unit = lc $t->{value}; ## TODO: case
          $t = $tt->get_next_token;
          if ($length_unit->{$unit}) {
            $prop_value{'background-position-y'}
                = ['DIMENSION', $value, $unit];
          } else {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          }
        } elsif ($t->{type} == PERCENTAGE_TOKEN) {
          my $value = $t->{number} * $sign;
          $t = $tt->get_next_token;
          $prop_value{'background-position-y'} = ['PERCENTAGE', $value];
        } elsif ($t->{type} == NUMBER_TOKEN and
                 ($self->context->quirks or $t->{number} == 0)) {
          my $value = $t->{number} * $sign;
          $t = $tt->get_next_token;
          $prop_value{'background-position-y'} = ['DIMENSION', $value, 'px'];
        } elsif ($t->{type} == IDENT_TOKEN) {
          my $value = lc $t->{value}; ## TODO: case
          if ({top => 1, center => 1, bottom => 1}->{$value}) {
            $prop_value{'background-position-y'} = ['KEYWORD', $value];
            $t = $tt->get_next_token;
          } else {
            $prop_value{'background-position-y'} = ['PERCENTAGE', 50];
          }
        } else {
          $prop_value{'background-position-y'} = ['PERCENTAGE', 50];
          if ($has_sign) {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          }
        }
      } elsif (not $has_sign and
               $t->{type} == URI_TOKEN and
               not defined $prop_value{'background-image'}) {
        $prop_value{'background-image'}
            = ['URI', $t->{value}, $self->context->base_urlref];
        $t = $tt->get_next_token;
      } else {
        if (keys %prop_value and not $has_sign) {
          last B;
        } else {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          return ($t, undef);
        }
      }

      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    } # B

    $prop_value{$_} ||= $Prop->{$_}->{initial}
        for qw/background-image background-attachment background-repeat
               background-color background-position-x background-position-y/;

    return ($t, \%prop_value);
  },
## TODO: background: #fff does not work.
  serialize_multiple => $Key->{background_color}->{serialize_multiple},
};
$Attr->{background} = $Prop->{background};

$Prop->{font} = {
  css => 'font',
  dom => 'font',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    my %prop_value;

    A: for (1..3) {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = lc $t->{value}; ## TODO: case
        if ($value eq 'normal') {
          $t = $tt->get_next_token;
        } elsif ($Prop->{'font-style'}->{keyword}->{$value} and
                 $self->{prop_value}->{'font-style'}->{$value} and
                 not defined $prop_value{'font-style'}) {
          $prop_value{'font-style'} = ['KEYWORD', $value];
          $t = $tt->get_next_token;
        } elsif ($Prop->{'font-variant'}->{keyword}->{$value} and
                 $self->{prop_value}->{'font-variant'}->{$value} and
                 not defined $prop_value{'font-variant'}) {
          $prop_value{'font-variant'} = ['KEYWORD', $value];
          $t = $tt->get_next_token;
        } elsif ({normal => 1, bold => 1,
                  bolder => 1, lighter => 1}->{$value} and
                 not defined $prop_value{'font-weight'}) {
          $prop_value{'font-weight'} = ['KEYWORD', $value];
          $t = $tt->get_next_token;
        } elsif ($value eq 'inherit' and 0 == keys %prop_value) {
          $t = $tt->get_next_token;
          return ($t, {'font-style' => ['INHERIT'],
                       'font-variant' => ['INHERIT'],
                       'font-weight' => ['INHERIT'],
                       'font-size' => ['INHERIT'],
                       'font-size-adjust' => ['INHERIT'],
                       'font-stretch' => ['INHERIT'],
                       'line-height' => ['INHERIT'],
                       'font-family' => ['INHERIT']});
        } elsif ({
                  caption => 1, icon => 1, menu => 1, 
                  'message-box' => 1, 'small-caption' => 1, 'status-bar' => 1,
                 }->{$value} and 0 == keys %prop_value) {
          $t = $tt->get_next_token;
          return ($t, $self->media_resolver->get_system_font ($value, {
            'font-style' => $Prop->{'font-style'}->{initial},
            'font-variant' => $Prop->{'font-variant'}->{initial},
            'font-weight' => $Prop->{'font-weight'}->{initial},
            'font-size' => $Prop->{'font-size'}->{initial},
            'font-size-adjust' => $Prop->{'font-size-adjust'}->{initial},
            'font-stretch' => $Prop->{'font-stretch'}->{initial},
            'line-height' => $Prop->{'line-height'}->{initial},
            'font-family' => ['FONT', ['KEYWORD', '-manakai-'.$value]],
          }));
        } else {
          if (keys %prop_value) {
            last A;
          } else {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          }
        }
      } elsif ($t->{type} == NUMBER_TOKEN) {
        if ({100 => 1, 200 => 1, 300 => 1, 400 => 1, 500 => 1,
             600 => 1, 700 => 1, 800 => 1, 900 => 1}->{$t->{number}}) {
          $prop_value{'font-weight'} = ['WEIGHT', $t->{number}, 0];
          $t = $tt->get_next_token;
        } else {
          last A;
        }
      } elsif ($t->{type} == PLUS_TOKEN) {
        $t = $tt->get_next_token;
        if ($t->{type} == NUMBER_TOKEN) {
          if ({100 => 1, 200 => 1, 300 => 1, 400 => 1, 500 => 1,
               600 => 1, 700 => 1, 800 => 1, 900 => 1}->{$t->{number}}) {
            $prop_value{'font-weight'} = ['WEIGHT', $t->{number}, 0];
            $t = $tt->get_next_token;
          } else {
            ## NOTE: <'font-size'> or invalid
            last A;
          }
        } elsif ($t->{type} == DIMENSION_TOKEN or
                 $t->{type} == PERCENTAGE_TOKEN) {
          ## NOTE: <'font-size'> or invalid
          last A;
        } else {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          return ($t, undef);
        }
      } else {
        last A;
      }

      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    } # A
    
    for (qw/font-style font-variant font-weight/) {
      $prop_value{$_} = $Prop->{$_}->{initial} unless defined $prop_value{$_};
    }
      
    ($t, my $pv) = $Prop->{'font-size'}->{parse}
        ->($self, 'font', $tt, $t, $onerror);
    return ($t, undef) unless defined $pv;
    if ($pv->{font}->[0] eq 'INHERIT') {
      $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                 level => 'm',
                 uri => $self->context->urlref,
                 token => $t);
      return ($t, undef);
    }
    $prop_value{'font-size'} = $pv->{font};

    $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    if ($t->{type} == DELIM_TOKEN and $t->{value} eq '/') {
      $t = $tt->get_next_token;
      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      ($t, my $pv) = $Prop->{'line-height'}->{parse}
          ->($self, 'font', $tt, $t, $onerror);
      return ($t, undef) unless defined $pv;
      if ($pv->{font}->[0] eq 'INHERIT') {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
      $prop_value{'line-height'} = $pv->{font};
      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    } else {
      $prop_value{'line-height'} = $Prop->{'line-height'}->{initial};
    }

    undef $pv;
    ($t, $pv) = $Prop->{'font-family'}->{parse}
        ->($self, 'font', $tt, $t, $onerror);
    return ($t, undef) unless defined $pv;
    $prop_value{'font-family'} = $pv->{font};

    $prop_value{'font-size-adjust'} = $Prop->{'font-size-adjust'}->{initial};
    $prop_value{'font-stretch'} = $Prop->{'font-stretch'}->{initial};

    return ($t, \%prop_value);
  },
  serialize_shorthand => sub {
    my ($se, $st) = @_;
    
    my $style = $se->serialize_prop_value ($st, 'font-style');
    my $i = $se->serialize_prop_priority ($st, 'font-style');
    return {} unless length $style;
    my $variant = $se->serialize_prop_value ($st, 'font-variant');
    return {} unless length $variant;
    return {} if $i ne $se->serialize_prop_priority ($st, 'font-variant');
    my $weight = $se->serialize_prop_value ($st, 'font-weight');
    return {} unless length $weight;
    return {} if $i ne $se->serialize_prop_priority ($st, 'font-weight');
    my $size = $se->serialize_prop_value ($st, 'font-size');
    return {} unless length $size;
    return {} if $i ne $se->serialize_prop_priority ($st, 'font-size');
    my $height = $se->serialize_prop_value ($st, 'line-height');
    return {} unless length $height;
    return {} if $i ne $se->serialize_prop_priority ($st, 'line-height');
    my $family = $se->serialize_prop_value ($st, 'font-family');
    return {} unless length $family;
    return {} if $i ne $se->serialize_prop_priority ($st, 'font-family');

    my $v = 0;
    for ($style, $variant, $weight, $size, $height, $family) {
      $v++ if $_ eq 'inherit';
    }
    if ($v == 6) {
      return {font => ['inherit', $i]};
    } elsif ($v) {
      return {};
    }
    
    my @v;
    push @v, $style unless $style eq 'normal';
    push @v, $variant unless $variant eq 'normal';
    push @v, $weight unless $weight eq 'normal';
    push @v, $size.($height eq 'normal' ? '' : '/'.$height);
    push @v, $family;
    return {font => [(join ' ', @v), $i]};
  },
};
$Attr->{font} = $Prop->{font};

$Prop->{'border-width'} = {
  css => 'border-width',
  dom => 'border_width',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    my %prop_value;

    my $has_sign;
    my $sign = 1;
    if ($t->{type} == MINUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
      $sign = -1;
    } elsif ($t->{type} == PLUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
    }

    if ($t->{type} == DIMENSION_TOKEN) {
      my $value = $t->{number} * $sign;
      my $unit = lc $t->{value}; ## TODO: case
      if ($length_unit->{$unit} and $value >= 0) {
        $prop_value{'border-top-width'} = ['DIMENSION', $value, $unit];
        $t = $tt->get_next_token;
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } elsif ($t->{type} == NUMBER_TOKEN and
             ($self->context->quirks or $t->{number} == 0)) {
      my $value = $t->{number} * $sign;
      if ($value >= 0) {
        $prop_value{'border-top-width'} = ['DIMENSION', $value, 'px'];
        $t = $tt->get_next_token;
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } elsif (not $has_sign and $t->{type} == IDENT_TOKEN) {
      my $prop_value = lc $t->{value}; ## TODO: case folding
      if ({thin => 1, medium => 1, thick => 1}->{$prop_value}) {
        $t = $tt->get_next_token;
        $prop_value{'border-top-width'} = ['KEYWORD', $prop_value];
      } elsif ($prop_value eq 'inherit') {
        $t = $tt->get_next_token;
        $prop_value{'border-top-width'} = ['INHERIT'];
        $prop_value{'border-right-width'} = $prop_value{'border-top-width'};
        $prop_value{'border-bottom-width'} = $prop_value{'border-top-width'};
        $prop_value{'border-left-width'} = $prop_value{'border-right-width'};
        return ($t, \%prop_value);
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } else {
      $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                 level => 'm',
                 uri => $self->context->urlref,
                 token => $t);
      return ($t, undef);
    }
    $prop_value{'border-right-width'} = $prop_value{'border-top-width'};
    $prop_value{'border-bottom-width'} = $prop_value{'border-top-width'};
    $prop_value{'border-left-width'} = $prop_value{'border-right-width'};

    $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    if ($t->{type} == MINUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
      $sign = -1;
    } elsif ($t->{type} == PLUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
      $sign = 1;
    } else {
      undef $has_sign;
      $sign = 1;
    }

    if ($t->{type} == DIMENSION_TOKEN) {
      my $value = $t->{number} * $sign;
      my $unit = lc $t->{value}; ## TODO: case
      if ($length_unit->{$unit} and $value >= 0) {
        $t = $tt->get_next_token;
        $prop_value{'border-right-width'} = ['DIMENSION', $value, $unit];
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } elsif ($t->{type} == NUMBER_TOKEN and
             ($self->context->quirks or $t->{number} == 0)) {
      my $value = $t->{number} * $sign;
      if ($value >= 0) {
        $t = $tt->get_next_token;
        $prop_value{'border-right-width'} = ['DIMENSION', $value, 'px'];
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } elsif (not $has_sign and $t->{type} == IDENT_TOKEN) {
      my $prop_value = lc $t->{value}; ## TODO: case
      if ({thin => 1, medium => 1, thick => 1}->{$prop_value}) {
        $prop_value{'border-right-width'} = ['KEYWORD', $prop_value];
        $t = $tt->get_next_token;
      }
    } else {
      if ($has_sign) {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
      return ($t, \%prop_value);
    }
    $prop_value{'border-left-width'} = $prop_value{'border-right-width'};

    $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    if ($t->{type} == MINUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
      $sign = -1;
    } elsif ($t->{type} == PLUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
      $sign = 1;
    } else {
      undef $has_sign;
      $sign = 1;
    }

    if ($t->{type} == DIMENSION_TOKEN) {
      my $value = $t->{number} * $sign;
      my $unit = lc $t->{value}; ## TODO: case
      if ($length_unit->{$unit} and $value >= 0) {
        $t = $tt->get_next_token;
        $prop_value{'border-bottom-width'} = ['DIMENSION', $value, $unit];
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } elsif ($t->{type} == NUMBER_TOKEN and
             ($self->context->quirks or $t->{number} == 0)) {
      my $value = $t->{number} * $sign;
      if ($value >= 0) {
        $t = $tt->get_next_token;
        $prop_value{'border-bottom-width'} = ['DIMENSION', $value, 'px'];
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } elsif (not $has_sign and $t->{type} == IDENT_TOKEN) {
      my $prop_value = lc $t->{value}; ## TODO: case
      if ({thin => 1, medium => 1, thick => 1}->{$prop_value}) {
        $prop_value{'border-bottom-width'} = ['KEYWORD', $prop_value];
        $t = $tt->get_next_token;
      }
    } else {
      if ($has_sign) {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
      return ($t, \%prop_value);
    }

    $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    if ($t->{type} == MINUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
      $sign = -1;
    } elsif ($t->{type} == PLUS_TOKEN) {
      $t = $tt->get_next_token;
      $has_sign = 1;
      $sign = 1;
    } else {
      undef $has_sign;
      $sign = 1;
    }

    if ($t->{type} == DIMENSION_TOKEN) {
      my $value = $t->{number} * $sign;
      my $unit = lc $t->{value}; ## TODO: case
      if ($length_unit->{$unit} and $value >= 0) {
        $t = $tt->get_next_token;
        $prop_value{'border-left-width'} = ['DIMENSION', $value, $unit];
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } elsif ($t->{type} == NUMBER_TOKEN and
             ($self->context->quirks or $t->{number} == 0)) {
      my $value = $t->{number} * $sign;
      if ($value >= 0) {
        $t = $tt->get_next_token;
        $prop_value{'border-left-width'} = ['DIMENSION', $value, 'px'];
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } elsif (not $has_sign and $t->{type} == IDENT_TOKEN) {
      my $prop_value = lc $t->{value}; ## TODO: case
      if ({thin => 1, medium => 1, thick => 1}->{$prop_value}) {
        $prop_value{'border-left-width'} = ['KEYWORD', $prop_value];
        $t = $tt->get_next_token;
      }
    } else {
      if ($has_sign) {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
      return ($t, \%prop_value);
    }

    return ($t, \%prop_value);
  },
  serialize_shorthand => sub {
    my ($se, $st) = @_;

    my @v;
    push @v, $se->serialize_prop_value ($st, 'border-top-width');
    my $i = $se->serialize_prop_priority ($st, 'border-top-width');
    return {} unless length $v[-1];
    push @v, $se->serialize_prop_value ($st, 'border-right-width');
    return {} unless length $v[-1];
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-right-width');
    push @v, $se->serialize_prop_value ($st, 'border-bottom-width');
    return {} unless length $v[-1];
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-bottom-width');
    push @v, $se->serialize_prop_value ($st, 'border-left-width');
    return {} unless length $v[-1];
    return {} unless $i eq $se->serialize_prop_priority ($st, 'border-left-width');

    my $v = 0;
    for (0..3) {
      $v++ if $v[$_] eq 'inherit';
    }
    if ($v == 4) {
      return {'border-width' => ['inherit', $i]};
    } elsif ($v) {
      return {};
    }

    pop @v if $v[1] eq $v[3];
    pop @v if $v[0] eq $v[2];
    pop @v if $v[0] eq $v[1];
    return {'border-width' => [(join ' ', @v), $i]};
  },
  serialize_multiple => $Key->{border_top_color}->{serialize_multiple},
};
$Attr->{border_width} = $Prop->{'border-width'};

$Prop->{'list-style'} = {
  css => 'list-style',
  dom => 'list_style',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    my %prop_value;
    my $none = 0;

    F: for my $f (1..3) {
      if ($t->{type} == IDENT_TOKEN) {
        my $prop_value = lc $t->{value}; ## TODO: case folding
        $t = $tt->get_next_token;

        if ($prop_value eq 'none') {
          $none++;
        } elsif ($Prop->{'list-style-type'}->{keyword}->{$prop_value}) {
          if (exists $prop_value{'list-style-type'}) {
            $onerror->(type => 'CSS duplication', text => "'list-style-type'",
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          } else {
            $prop_value{'list-style-type'} = ['KEYWORD', $prop_value];
          }
        } elsif ($Prop->{'list-style-position'}->{keyword}->{$prop_value}) {
          if (exists $prop_value{'list-style-position'}) {
            $onerror->(type => 'CSS duplication',
                       text => "'list-style-position'",
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          }

          $prop_value{'list-style-position'} = ['KEYWORD', $prop_value];
        } elsif ($f == 1 and $prop_value eq 'inherit') {
          $prop_value{'list-style-type'} = ["INHERIT"];
          $prop_value{'list-style-position'} = ["INHERIT"];
          $prop_value{'list-style-image'} = ["INHERIT"];
          last F;
        } else {
          if ($f == 1) {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          } else {
            last F;
          }
        }
      } elsif ($t->{type} == URI_TOKEN) {
        if (exists $prop_value{'list-style-image'}) {
          $onerror->(type => 'CSS duplication', text => "'list-style-image'",
                     uri => $self->context->urlref,
                     level => 'm',
                     token => $t);
          return ($t, undef);
        }
        
        $prop_value{'list-style-image'}
            = ['URI', $t->{value}, $self->context->base_urlref];
        $t = $tt->get_next_token;
      } else {
        if ($f == 1) {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          return ($t, undef);
        } else {
          last F;
        }
      }

      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
    } # F
    ## NOTE: No browser support |list-style: url(xxx|{EOF}.

    if ($none == 1) {
      if (exists $prop_value{'list-style-type'}) {
        if (exists $prop_value{'list-style-image'}) {
          $onerror->(type => 'CSS duplication', text => "'list-style-image'",
                     uri => $self->context->urlref,
                     level => 'm',
                     token => $t);
          return ($t, undef);
        } else {
          $prop_value{'list-style-image'} = ['KEYWORD', 'none'];
        }
      } else {
        $prop_value{'list-style-type'} = ['KEYWORD', 'none'];
        $prop_value{'list-style-image'} = ['KEYWORD', 'none']
            unless exists $prop_value{'list-style-image'};
      }
    } elsif ($none == 2) {
      if (exists $prop_value{'list-style-type'}) {
        $onerror->(type => 'CSS duplication', text => "'list-style-type'",
                   uri => $self->context->urlref,
                   level => 'm',
                   token => $t);
        return ($t, undef);
      }
      if (exists $prop_value{'list-style-image'}) {
        $onerror->(type => 'CSS duplication', text => "'list-style-image'",
                   uri => $self->context->urlref,
                   level => 'm',
                   token => $t);
        return ($t, undef);
      }
      
      $prop_value{'list-style-type'} = ['KEYWORD', 'none'];
      $prop_value{'list-style-image'} = ['KEYWORD', 'none'];
    } elsif ($none == 3) {
      $onerror->(type => 'CSS duplication', text => "'list-style-type'",
                 uri => $self->context->urlref,
                 level => 'm',
                 token => $t);
      return ($t, undef);
    }

    for (qw/list-style-type list-style-position list-style-image/) {
      $prop_value{$_} = $Prop->{$_}->{initial} unless exists $prop_value{$_};
    }

    return ($t, \%prop_value);
  },
  ## NOTE: We don't merge longhands in |css_text| serialization,
  ## since no browser does.
  serialize_shorthand => sub {
    my ($se, $st) = @_;

    ## NOTE: Don't omit any value even if it is the initial value,
    ## since WinIE is buggy.
    
    my $type = $se->serialize_prop_value ($st, 'list-style-type');
    return {} unless length $type;
    my $type_i = $se->serialize_prop_priority ($st, 'list-style-type');
    my $image = $se->serialize_prop_value ($st, 'list-style-image');
    return {} unless length $image;
    my $image_i = $se->serialize_prop_priority ($st, 'list-style-image');
    return {} unless $type_i eq $image_i;
    my $position = $se->serialize_prop_value ($st, 'list-style-position');
    return {} unless length $position;
    my $position_i = $se->serialize_prop_priority ($st, 'list-style-position');
    return {} unless $type_i eq $position_i;

    return {'list-style' => [$type . ' ' . $image . ' ' . $position, $type_i]};
  },
};
$Attr->{list_style} = $Prop->{'list-style'};

## NOTE: Future version of the implementation will change the way to
## store the parsed value to support CSS 3 properties.
$Prop->{'text-decoration'} = {
  css => 'text-decoration',
  dom => 'text_decoration',
  key => 'text_decoration',
  keyword => {none => 1, underline => 1, overline => 1,
              'line-through' => 1, blink => 1},
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    my $value = ['DECORATION']; # , underline, overline, line-through, blink

    if ($t->{type} == IDENT_TOKEN) {
      my $v = lc $t->{value}; ## TODO: case
      $t = $tt->get_next_token;
      if ($v eq 'inherit') {
        return ($t, {$prop_name => ['INHERIT']});
      } elsif ($v eq 'none') {
        return ($t, {$prop_name => $value});
      } elsif ($v eq 'underline' and
               $self->{prop_value}->{$prop_name}->{$v}) {
        $value->[1] = 1;
      } elsif ($v eq 'overline' and
               $self->{prop_value}->{$prop_name}->{$v}) {
        $value->[2] = 1;
      } elsif ($v eq 'line-through' and
               $self->{prop_value}->{$prop_name}->{$v}) {
        $value->[3] = 1;
      } elsif ($v eq 'blink' and
               $self->{prop_value}->{$prop_name}->{$v}) {
        $value->[4] = 1;
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    }

    F: {
      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      last F unless $t->{type} == IDENT_TOKEN;

      my $v = lc $t->{value}; ## TODO: case
      $t = $tt->get_next_token;
      if ($v eq 'underline' and
          $self->{prop_value}->{$prop_name}->{$v}) {
        $value->[1] = 1;
      } elsif ($v eq 'overline' and
               $self->{prop_value}->{$prop_name}->{$v}) {
        $value->[1] = 2;
      } elsif ($v eq 'line-through' and
               $self->{prop_value}->{$prop_name}->{$v}) {
        $value->[1] = 3;
      } elsif ($v eq 'blink' and
               $self->{prop_value}->{$prop_name}->{$v}) {
        $value->[1] = 4;
      } else {
        last F;
      }

      redo F;
    } # F

    return ($t, {$prop_name => $value});
  },
  initial => ["KEYWORD", "none"],
  #inherited => 0,
  compute => $compute_as_specified,
};
$Attr->{text_decoration} = $Prop->{'text-decoration'};
$Key->{text_decoration} = $Prop->{'text-decoration'};

$Attr->{quotes} =
$Key->{quotes} =
$Prop->{quotes} = {
  css => 'quotes',
  dom => 'quotes',
  key => 'quotes',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    my @v;
    A: {
      if ($t->{type} == STRING_TOKEN) {
        my $open = $t->{value};
        $t = $tt->get_next_token;

        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == STRING_TOKEN) {
          push @v, [$open, $t->{value}];
          $t = $tt->get_next_token;
        } else {
          last A;
        }
      } elsif (not @v and $t->{type} == IDENT_TOKEN) {
        my $value = lc $t->{value}; ## TODO: case
        if ($value eq 'none' or $value eq '-manakai-default') {
          $t = $tt->get_next_token;
          return ($t, {$prop_name => ['KEYWORD', $value]});
        } elsif ($value eq 'inherit') {
          $t = $tt->get_next_token;
          return ($t, {$prop_name => ['INHERIT']});
        } else {
          last A;
        }
      } else {
        if (@v) {
          return ($t, {$prop_name => ['QUOTES', \@v]});
        } else {
          last A;
        }
      }

      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      redo A;
    }
    
    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
  initial => ['KEYWORD', '-manakai-default'],
  inherited => 1,
  compute => $compute_as_specified,
};

$Attr->{content} =
$Key->{content} =
$Prop->{content} = {
  css => 'content',
  dom => 'content',
  key => 'content',
  ## NOTE: See <http://suika.fam.cx/gate/2005/sw/content>.
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    if ($t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ($value eq 'normal' or $value eq 'none') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['KEYWORD', $value]});
      } elsif ($value eq 'inherit') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['INHERIT']});
      }
    }
    
    my @v;
    A: {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = lc $t->{value}; ## TODO: case
        if ({qw/open-quote 1 close-quote 1
                no-open-quote 1 no-close-quote 1/}->{$value} and
            $self->{prop}->{quotes}) {
          push @v, ['KEYWORD', $value];
          $t = $tt->get_next_token;
        } else {
          last A;
        }
      } elsif ($t->{type} == STRING_TOKEN) {
        push @v, ['STRING', $t->{value}];
        $t = $tt->get_next_token;
      } elsif ($t->{type} == URI_TOKEN) {
        push @v, ['URI', $t->{value}, $self->context->base_urlref];
        $t = $tt->get_next_token;
      } elsif ($t->{type} == FUNCTION_TOKEN) {
        my $name = lc $t->{value}; ## TODO: case
        if ($name eq 'attr') {
          $t = $tt->get_next_token;
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          if ($t->{type} == IDENT_TOKEN) {
            my $t_pfx;
            my $t_ln = $t;
            $t = $tt->get_next_token;
            if ($t->{type} == VBAR_TOKEN) {
              $t = $tt->get_next_token;
              if ($t->{type} == IDENT_TOKEN) {
                $t_pfx = $t_ln;
                $t_ln = $t;
                $t = $tt->get_next_token;
              } else {
                last A;
              }
            }
            
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
            if ($t->{type} == RPAREN_TOKEN) {
              if (defined $t_pfx) {
                my $pfx = $t_pfx->{value};
                my $uri = $self->context->get_url_by_prefix ($pfx);
                unless (defined $uri) {
                  $self->{onerror}->(type => 'namespace prefix:not declared',
                                     level => 'm',
                                     uri => $self->context->urlref,
                                     token => $t_pfx,
                                     value => $pfx);
                  return ($t, undef);
                }
                undef $uri unless length $uri;
                push @v, ['ATTR', $uri, $t_ln->{value}];
              } else {
                push @v, ['ATTR', undef, $t_ln->{value}];
              }
              $t = $tt->get_next_token;
            } else {
              last A;
            }
          } elsif ($t->{type} == VBAR_TOKEN) {
            $t = $tt->get_next_token;
            my $t_ln;
            if ($t->{type} == IDENT_TOKEN) {
              $t_ln = $t;
              $t = $tt->get_next_token;
            } else {
              last A;
            }
            
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
            if ($t->{type} == RPAREN_TOKEN) {
              push @v, ['ATTR', undef, $t_ln->{value}];
              $t = $tt->get_next_token;
            } else {
              last A;
            }
          } else {
            last A;
          }
        } elsif (($name eq 'counter' or $name eq 'counters') and
                 $self->{prop}->{'counter-reset'}) {
          $t = $tt->get_next_token;
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          if ($t->{type} == IDENT_TOKEN) {
            my $t_id = $t;
            my $t_str;
            my $type;
            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
            if ($t->{type} == COMMA_TOKEN) {
              $t = $tt->get_next_token;
              $t = $tt->get_next_token while $t->{type} == S_TOKEN;
              if ($name eq 'counters' and $t->{type} == STRING_TOKEN) {
                $t_str = $t;
                $t = $tt->get_next_token;
                $t = $tt->get_next_token while $t->{type} == S_TOKEN;
                if ($t->{type} == COMMA_TOKEN) {
                  $t = $tt->get_next_token;
                  $t = $tt->get_next_token while $t->{type} == S_TOKEN;
                  if ($t->{type} == IDENT_TOKEN) {
                    $type = lc $t->{value}; ## TODO: value
                    if ($Prop->{'list-style-type'}->{keyword}->{$type}) {
                      $t = $tt->get_next_token;
                    } else {
                      last A;
                    }
                  } else {
                    last A;
                  }
                }
              } elsif ($name eq 'counter' and $t->{type} == IDENT_TOKEN) {
                $type = lc $t->{value}; ## TODO: value
                if ($Prop->{'list-style-type'}->{keyword}->{$type}) {
                  $t = $tt->get_next_token;
                } else {
                  last A;
                }
              } else {
                last A;
              }
            } elsif ($name eq 'counters') {
              last A;
            }
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
            if ($t->{type} == RPAREN_TOKEN) {
              push @v, [uc $name, ## |COUNTER| or |COUNTERS|
                        $t_id->{value},
                        defined $t_str ? $t_str->{value} : undef,
                        defined $type ? $type : 'decimal'];
              $t = $tt->get_next_token;
            } else {
              last A;
            }
          } else {
            last A;
          }
        } else {
          last A;
        }
      } else {
        unshift @v, 'CONTENT';
        return ($t, {$prop_name => \@v});
      }

      $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      redo A;
    } # A

    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
  initial => ['KEYWORD', 'normal'],
  #inherited => 0,
  compute => $compute_as_specified,
      ## NOTE: This is what Opera 9 does, except for 'normal' -> 'none'.
      ## TODO: 'normal' -> 'none' for ::before and ::after [CSS 2.1]
};

$Attr->{counter_reset} =
$Key->{counter_reset} =
$Prop->{'counter-reset'} = {
  css => 'counter-reset',
  dom => 'counter_reset',
  key => 'counter_reset',
  ## NOTE: See <http://suika.fam.cx/gate/2005/sw/counter-reset>.
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    ## NOTE: For 'counter-increment' and 'counter-reset'.

    my @v = ($prop_name eq 'counter-increment' ? 'ADDCOUNTER' : 'SETCOUNTER');
    B: {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        my $lcvalue = lc $value; ## TODO: case
        last B if $lcvalue ne 'inherit' and $lcvalue ne 'none';
        
        $t = $tt->get_next_token;
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == IDENT_TOKEN) {
          push @v, [$value, $prop_name eq 'counter-increment' ? 1 : 0];
        } elsif ($t->{type} == NUMBER_TOKEN) {
          push @v, [$value, int $t->{number}];
          $t = $tt->get_next_token;
        } elsif ($t->{type} == PLUS_TOKEN) {
          $t = $tt->get_next_token;
          if ($t->{type} == NUMBER_TOKEN) {
            push @v, [$value, int $t->{number}];
            $t = $tt->get_next_token;
          } else {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          }
        } elsif ($t->{type} == MINUS_TOKEN) {
          $t = $tt->get_next_token;
          if ($t->{type} == NUMBER_TOKEN) {
            push @v, [$value, -int $t->{number}];
            $t = $tt->get_next_token;
          } else {
            $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                       level => 'm',
                       uri => $self->context->urlref,
                       token => $t);
            return ($t, undef);
          }
        } else {
          if ($lcvalue eq 'none') {
            return ($t, {$prop_name => ['KEYWORD', $lcvalue]});
          } elsif ($lcvalue eq 'inherit') {
            return ($t, {$prop_name => ['INHERIT']});
          } else {
            last B;
          }
        }
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
      } else {
        $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                   level => 'm',
                   uri => $self->context->urlref,
                   token => $t);
        return ($t, undef);
      }
    } # B

    A: {
      if ($t->{type} == IDENT_TOKEN) {
        my $value = $t->{value};
        $t = $tt->get_next_token;
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == NUMBER_TOKEN) {
          push @v, [$value, int $t->{number}];
          $t = $tt->get_next_token;
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        } elsif ($t->{type} == MINUS_TOKEN) {
          $t = $tt->get_next_token;
          if ($t->{type} == NUMBER_TOKEN) {
            push @v, [$value, -int $t->{number}];
            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          } else {
            last A;
          }
        } elsif ($t->{type} == PLUS_TOKEN) {
          $t = $tt->get_next_token;
          if ($t->{type} == NUMBER_TOKEN) {
            push @v, [$value, int $t->{number}];
            $t = $tt->get_next_token;
            $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          } else {
            last A;
          }
        } else {
          push @v, [$value, $prop_name eq 'counter-increment' ? 1 : 0];
        }
        redo A;
      } else {
        return ($t, {$prop_name => \@v});
      }
    } # A
    
    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_as_specified,
};

$Attr->{counter_increment} =
$Key->{counter_increment} =
$Prop->{'counter-increment'} = {
  css => 'counter-increment',
  dom => 'counter_increment',
  key => 'counter_increment',
  parse => $Prop->{'counter-reset'}->{parse},
  initial => ['KEYWORD', 'none'],
  #inherited => 0,
  compute => $compute_as_specified,
};

$Attr->{clip} =
$Key->{clip} =
$Prop->{clip} = {
  css => 'clip',
  dom => 'clip',
  key => 'clip',
  ## NOTE: See <http://suika.fam.cx/gate/2005/sw/clip>.
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    if ($t->{type} == FUNCTION_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ($value eq 'rect') {
        $t = $tt->get_next_token;
        my $prop_value = ['RECT'];

        A: {
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          
          my $has_sign;
          my $sign = 1;
          if ($t->{type} == MINUS_TOKEN) {
            $sign = -1;
            $has_sign = 1;
            $t = $tt->get_next_token;
          } elsif ($t->{type} == PLUS_TOKEN) {
            $has_sign = 1;
            $t = $tt->get_next_token;
          }
          if ($t->{type} == DIMENSION_TOKEN) {
            my $value = $t->{number} * $sign;
            my $unit = lc $t->{value}; ## TODO: case
            if ($length_unit->{$unit}) {
              $t = $tt->get_next_token;
              push @$prop_value, ['DIMENSION', $value, $unit];
            } else {
              $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
              return ($t, undef);
            }
          } elsif ($t->{type} == NUMBER_TOKEN and
                   ($self->context->quirks or $t->{number} == 0)) {
            my $value = $t->{number} * $sign;
            $t = $tt->get_next_token;
            push @$prop_value, ['DIMENSION', $value, 'px'];
          } elsif (not $has_sign and $t->{type} == IDENT_TOKEN) {
            my $value = lc $t->{value}; ## TODO: case
            if ($value eq 'auto') {
              push @$prop_value, ['KEYWORD', 'auto'];
              $t = $tt->get_next_token;
            } else {
              last A;
            }
          } else {
            if ($has_sign) {
              $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                         level => 'm',
                         uri => $self->context->urlref,
                         token => $t);
              return ($t, undef);
            } else {
              last A;
            }
          }
        
          $t = $tt->get_next_token while $t->{type} == S_TOKEN;
          if ($#$prop_value == 4) {
            if ($t->{type} == RPAREN_TOKEN) {
              $t = $tt->get_next_token;
              return ($t, {$prop_name => $prop_value});
            } else {
              last A;
            }
          } else {
            $t = $tt->get_next_token if $t->{type} == COMMA_TOKEN;
            redo A;
          }
        } # A
      }
    } elsif ($t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ($value eq 'auto') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['KEYWORD', 'auto']});
      } elsif ($value eq 'inherit') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['INHERIT']});
      }
    }

    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
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
};

$Attr->{marks} =
$Key->{marks} =
$Prop->{marks} = {
  css => 'marks',
  dom => 'marks',
  key => 'marks',
  keyword => {crop => 1, cross => 1},
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    if ($t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ($value eq 'crop' and $self->{prop_value}->{$prop_name}->{$value}) {
        $t = $tt->get_next_token;
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == IDENT_TOKEN) {
          my $value = lc $t->{value}; ## TODO: case
          if ($value eq 'cross' and
              $self->{prop_value}->{$prop_name}->{$value}) {
            $t = $tt->get_next_token;
            return ($t, {$prop_name => ['MARKS', 1, 1]});
          }
        }
        return ($t, {$prop_name => ['MARKS', 1, 0]});
      } elsif ($value eq 'cross' and
               $self->{prop_value}->{$prop_name}->{$value}) {
        $t = $tt->get_next_token;
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        if ($t->{type} == IDENT_TOKEN) {
          my $value = lc $t->{value}; ## TODO: case
          if ($value eq 'crop' and
              $self->{prop_value}->{$prop_name}->{$value}) {
            $t = $tt->get_next_token;
            return ($t, {$prop_name => ['MARKS', 1, 1]});
          }
        }
        return ($t, {$prop_name => ['MARKS', 0, 1]});
      } elsif ($value eq 'none') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['MARKS']});
      } elsif ($value eq 'inherit') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['INHERIT']});
      }
    }

    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
  initial => ['MARKS', 0, 0],
  #inherited => 0,
  compute => $compute_as_specified,
};

$Attr->{size} =
$Key->{size} =
$Prop->{size} = {
  css => 'size',
  dom => 'size',
  key => 'size',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    if ($t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ({
           auto => 1, portrait => 1, landscape => 1,
          }->{$value}) {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['KEYWORD', $value]});
      } elsif ($value eq 'inherit') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['INHERIT']});
      }
    }

    my $prop_value = ['SIZE'];
    A: {
      my $has_sign;
      my $sign = 1;
      if ($t->{type} == MINUS_TOKEN) {
        $has_sign = 1;
        $sign = -1;
        $t = $tt->get_next_token;
      } elsif ($t->{type} == PLUS_TOKEN) {
        $has_sign = 1;
        $t = $tt->get_next_token;
      }
      
      if ($t->{type} == DIMENSION_TOKEN) {
        my $value = $t->{number} * $sign;
        my $unit = lc $t->{value}; ## TODO: case
        if ($length_unit->{$unit}) {
          $t = $tt->get_next_token;
          push @$prop_value, ['DIMENSION', $value, $unit];
        } else {
          $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
                     level => 'm',
                     uri => $self->context->urlref,
                     token => $t);
          return ($t, undef);
        }
      } elsif ($t->{type} == NUMBER_TOKEN and
               ($self->context->quirks or $t->{number} == 0)) {
        my $value = $t->{number} * $sign;
        $t = $tt->get_next_token;
        push @$prop_value, ['DIMENSION', $value, 'px'];
      } else {
        if (@$prop_value == 2) {
          $prop_value->[2] = $prop_value->[1];
          return ($t, {$prop_name => $prop_value});
        } else {
          last A;
        }
      }

      if (@$prop_value == 3) {
        return ($t, {$prop_name => $prop_value});
      } else {
        $t = $tt->get_next_token while $t->{type} == S_TOKEN;
        redo A;
      }
    } # A

    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
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
};

$Attr->{page} =
$Key->{page} =
$Prop->{page} = {
  css => 'page',
  dom => 'page',
  key => 'page',
  parse => sub {
    my ($self, $prop_name, $tt, $t, $onerror) = @_;

    if ($t->{type} == IDENT_TOKEN) {
      my $value = lc $t->{value}; ## TODO: case
      if ($value eq 'auto') {
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['KEYWORD', 'auto']});
      } else {
        $value = $t->{value};
        $t = $tt->get_next_token;
        return ($t, {$prop_name => ['PAGE', $value]});
      }
    }

    $onerror->(type => 'CSS syntax error', text => qq['$prop_name'],
               level => 'm',
               uri => $self->context->urlref,
               token => $t);
    return ($t, undef);
  },
  initial => ['KEYWORD', 'auto'],
  inherited => 1,
  compute => $compute_as_specified,
};

for my $key (keys %$Key) {
  my $def = $Key->{$key};
  $def->{key} ||= $key;
  $Attr->{$def->{dom}} ||= $def;
  $Prop->{$def->{css}} ||= $def;
  if ($def->{keyword} and not $def->{parse_longhand}) {
    $def->{parse_longhand} = $Web::CSS::Values::GetKeywordParser->($def->{keyword}, $def->{css});
  }
  for (@{$def->{longhand_subprops} or []}) {
    $Key->{$_}->{shorthand_prop} ||= $key;
  }
} # $key

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
