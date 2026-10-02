# 2D mathematical formula editor

In 2D plotting, click a formula to edit its rendered content. The trailing
keyboard button switches the same draft to a system-keyboard LaTeX source field.
The mathematical-input preference is remembered. Mathematical keys stay disabled
until the editor finishes loading; the source toggle remains available. 3D continues using source input.

The shared bottom keyboard follows the active formula. Its tabs cover arithmetic,
functions, structures, relations, Greek letters, Latin letters and typography.
Numbers and backspace keep their positions. Use page buttons for more symbols.
Templates accept the selected expression; powers can capture the complete item
to the left of the caret. Empty slots stay visible until filled. Tap within the
formula to position the caret; drag or long press to select. The left/right arrows
navigate atoms; Previous/Next moves between empty slots, then outside the parent
structure. Matrix keys add/remove rows and columns at the current cell.
Undo/redo operates on MathLive's document. The menu provides select all, copy,
cut and paste through Flutter's clipboard, with LaTeX as the transfer format.
Hide or Back dismisses the custom keyboard without discarding the draft.

## Implementation and synchronization

Each formula row owns a retained `MathFormulaField` and source controller.
MathLive 0.111.0 is bundled locally with its fonts and MIT license under
`assets/vendor/mathlive`, so rendering and editing do not require a CDN.
MathLive handles structured caret positioning, selections and undo; Flutter owns
the keyboard, mode buttons and graph actions. The native system IME is disabled
for mathematical input. Bridge arguments are JSON encoded.

The bridge preserves the source verbatim until an actual mathematical edit.
Its synchronous snapshot reads the current MathLive model because MathLive's
input event is deferred. Commands, plot, mode switches and tab switches consume
queued snapshots. Revisions reject messages from a prior source import, while
sequence numbers reject older updates within the same revision. A ResizeObserver
reports post-render formula height, including tall templates and error hints. Stable row keys
and keep-alive state preserve each editor when formulas are removed or scrolled.
Theme changes update the retained editor's ink, caret and error colors without
reimporting its content or resetting the selection.

Unknown or malformed imported LaTeX remains in the source draft. Its rendered
view explains that it must be corrected in source mode instead of exporting a
lossy version. Editing/rendering coverage is MathLive's mathematical LaTeX subset,
not a full TeX document compiler: arbitrary packages and user-defined macros are
not promised. New symbols can be added to `math_keyboard.dart` without replacing
cursor handling or the graph engine.

## Plotting and platform boundaries

Editing is broader than graph evaluation. Integrals, sums, matrices, annotations,
relations and other display-only structures can be edited, but are not numerically
evaluated by this change. Plot shows an error and retains the draft. Incomplete
slots are also rejected. Supported plotting conversions include nested fractions,
square/indexed roots, absolute values, base-specific logs and function prefixes
with MathLive delimiters; remaining unsupported commands are rejected rather than
silently interpreted as parameter names.

Native mathematical editing uses flutter_inappwebview on Android, iOS, macOS
and Windows. Web and Linux currently use the source editor with a disabled,
explanatory mode button because the installed WebView plugin has no suitable
bidirectional JavaScript handler there. No platform view is constructed on these
fallback platforms. Native touch selection and IME behavior still require device
acceptance testing; DOM tests validate the real editing model and bridge but do
not validate browser geometry or platform-view composition.

## Validation

```sh
flutter test tests/widgets/math_formula_field_test.dart tests/widgets/math_keyboard_test.dart tests/models/math_editor_plot_compatibility_test.dart tests/pages/content/math_drawing_page_test.dart
flutter test tests/models/math_expression_test.dart --name 'fromInput|withParameters|LaTeX conversion|isValid'
npm ci --prefix tools/math_editor_test
npm test --prefix tools/math_editor_test
```

The Node tests load the bundled MathLive code in jsdom, with browser layout,
audio and font APIs stubbed. They exercise nested templates, selection replacement,
undo, source import preservation and editable matrices; CI runs them separately.
