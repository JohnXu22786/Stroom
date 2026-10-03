# 2D mathematical formula editor

In 2D plotting, click a formula to edit its rendered content. The trailing
keyboard button switches the same draft to a system-keyboard LaTeX source field.
The mathematical-input preference is remembered. Mathematical keys stay disabled
until the editor finishes loading; the source toggle remains available. 3D continues using source input.

The shared bottom keyboard follows the active formula. Its tabs separate common
arithmetic, exponents/logarithms, functions, constants, Greek letters/variants,
calculus, matrices, sets/logic, relations, arrows, fences/intervals,
typography and Latin letters. Scroll the tabs or open the category directory to
jump directly to a category; this resets its page and scroll position.
Numbers and backspace keep their positions in symbol categories. The Latin
letter tab uses the full width for all 26 letters in QWERTY rows, with Shift,
backspace and a numeric row. Shift toggles Latin and ordinary Greek case and
keeps the current Greek page; all 24 Greek letters are present in both cases.
The separate variants tab contains eight additional forms. Use page buttons
for more symbols.
The logarithm tab offers explicit base-ten, base-two and arbitrary-base templates
alongside natural ln and powers of e, 2 and 10. Legacy bare log remains natural.
Templates accept the selected expression; powers can capture the complete item
to the left of the caret. Empty slots stay visible until filled. Tap within the
formula to position the caret; drag or long press to select. The header identifies
the current numerator, denominator, exponent, subscript, radical or matrix cell.
The header also identifies upper/lower annotations and labelled arrows.
The arrow buttons stay visible while the key grid scrolls on short screens.
In very short landscape/window layouts, the header and category tabs scroll with
the keys to leave the navigation row visible and avoid clipping the key area.

| Control | Editing behavior |
| --- | --- |
| Left / Right | MathLive's atom traversal enters nested structures, crosses their branches, and exits them in document order. A selection collapses toward the requested side; reaching the document boundary keeps focus in the formula. |
| Up / Down | Switches between numerator and denominator, existing subscript and exponent, radical index and body, matrix rows in the same column, or an annotation and its body/other label. It uses the nearest enclosing structure with a valid destination and preserves horizontal position where geometry is available. It never creates a missing branch. Leaving a sole exponent/subscript lands after the complete scripted item. |
| Previous / Next | Visits filled as well as empty sibling slots. At the first/last slot it exits before/after that structure; from outside it enters the nearby structure. Empty placeholders are selected for replacement. |
| Exit structure | Leaves the nearest enclosing structure, retaining any outer structure. |

Arrow and slot movements do not edit the document. Undo restores the content and
caret before an insertion. Matrix keys add/remove rows and columns at the current cell.
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
Edited exports and clipboard selections use explicit digit-subscript groups so
`a_{1}x` remains a product instead of becoming the identifier `a_1x`. Legacy
underscore identifiers import with grouped subscripts and retain their names;
multi-letter bases use roman formatting. Literal text/operator names are preserved.
Separate ordinary Latin letter/number atoms export token boundaries, so entering
A then x produces A times x. Legacy multi-character identifiers import as exact
roman namespaces and retain their original parameter names after editing.
Deletion captures the formula identity before confirmation and rechecks that a
row remains after pending editor snapshots finish.

Unknown or malformed imported LaTeX remains in the source draft. Its rendered
view explains that it must be corrected in source mode instead of exporting a
lossy version. Editing/rendering coverage is MathLive's mathematical LaTeX subset,
not a full TeX document compiler: arbitrary packages and user-defined macros are
not promised. New symbols can be added to `math_keyboard.dart` without replacing
cursor handling or the graph engine.

`navigation.js` derives branch boundaries from MathLive's public offsets,
element depths and LaTeX metadata. Vertical movement uses rendered bounds when
available and falls back to the corresponding atom position. The pinned 0.111.0
integration uses one private compatibility hook, `stopCoalescingUndo()`, because
public position setters do not create an undo boundary. Integration tests guard
content and caret restoration when moving between slots before typing; check
that hook and structural metadata when upgrading MathLive.

## Plotting and platform boundaries

After plotting, named parameters appear beneath the formula rows as shared
sliders, with an initial value of 1 and range -5 to 5. The same case-sensitive
name uses the same value across visible formulas. Dragging a slider redraws the
committed curves without submitting formula drafts. Click a value or its settings
button to edit the value, minimum, maximum and step (initially 0.1).
The dialog rejects nonfinite values, reversed ranges and invalid steps; changing
the range clamps the value to its bounds. Slider steps start at the minimum;
if the range does not divide evenly, its final tick stays below the maximum.
Typing a numeric value preserves it exactly rather than rounding to a slider tick.
Keyboard arrows and screen-reader adjustments visit the same configured ticks;
from a typed value between ticks, they move to the next tick in that direction.
Values and range settings survive replotting and hiding/showing formulas for the
current page session. Coordinates x/y and existing built-in constants e, pi,
E, PI and their aliases are not adjustable parameters. The parameter display
shows A = value; this does not introduce assignment rows or dependent definitions.

Editing is broader than graph evaluation. Integrals, sums, matrices, annotations,
relations and other display-only structures can be edited, but are not numerically
evaluated by this change. Plot shows an error and retains the draft. Incomplete
slots are also rejected. The keyboard covers the evaluator's complete finite
vocabulary: 24 unary functions, 3 binary functions and 8 constants, plus arithmetic,
powers, fractions, indexed roots, implicit multiplication and parameterized
explicit/implicit equations. Function templates and the parser share a catalog;
numeric tests compare every template with function_tree's actual function tables.
All 24 Greek lowercase letters, 24 uppercase letters and eight variant/archaic
forms have keys. Greek letters and simple letter/digit subscripts work as parameters, initially 1,
and remain adjustable through parameter controls. Lowercase pi and e retain their
constant meaning. Complex indexed expressions such as `a_{x+1}` remain editable
but cannot be plotted; supported logarithm bases continue to evaluate normally.

Floor/ceiling fences, grouped factorials, percentages, remainder and scientific
notation keep their numeric meaning. The percent key divides its preceding item
by 100; the mod key inserts binary remainder. Legacy ASCII function calls import
as editable structures while retaining their source until the first edit.
Identifiers in simple braced subscripts remain literal during import, including
names that match constants, functions or scientific notation.
Unsupported commands, unknown functions and multivalued signs such as ± are
rejected rather than silently becoming a different curve. This change does not
add symbolic calculus, complex plotting or inequality shading.

Native mathematical editing uses flutter_inappwebview on Android, iOS, macOS
and Windows. Web and Linux currently use the source editor with a disabled,
explanatory mode button because the installed WebView plugin has no suitable
bidirectional JavaScript handler there. No platform view is constructed on these
fallback platforms. Native touch selection and IME behavior still require device
acceptance testing; DOM tests validate the real editing model and bridge but do
not validate browser geometry or platform-view composition.

## Validation

```sh
flutter test tests/widgets/math_formula_field_test.dart tests/widgets/math_keyboard_test.dart tests/models/math_editor_plot_compatibility_test.dart tests/models/math_input_catalog_test.dart tests/pages/content/math_drawing_page_test.dart
flutter test tests/models/math_parameter_test.dart tests/widgets/math_parameter_controls_test.dart
flutter test tests/models/math_expression_test.dart --name 'fromInput|withParameters|LaTeX conversion|isValid|parameters'
npm ci --prefix tools/math_editor_test
npm test --prefix tools/math_editor_test
```

The Node tests load the bundled MathLive code in jsdom, with browser layout,
audio and font APIs stubbed. They exercise nested templates, selection replacement,
undo including caret restoration, source import preservation, horizontal and
vertical navigation, filled-slot navigation and editable matrices; CI runs them separately.
