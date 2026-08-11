import 'package:flutter/material.dart';

/// A reusable widget that displays source code with line numbers and a
/// wrap-toggle button, providing a consistent "code display area" UI form
/// that matches what [HtmlCodeBlockWidget] uses.
///
/// ## Usage
///
/// Use this widget anywhere you need to show source code with line numbers:
/// - Plain code blocks in markdown rendering
/// - Mermaid's "show source code" toggle view
/// - HTML code block display
///
/// Additional action buttons (e.g. "full screen" for HTML, "view chart" for
/// Mermaid) can be passed via [actionButtons] and appear in the top-right
/// button row.
class CodeBlockSourceView extends StatefulWidget {
  /// The source code to display.
  final String code;

  /// Optional fixed height. If null, uses adaptive height capped at
  /// 15 visible lines.
  final double? height;

  /// The language of the code (the info string after the opening fence,
  /// e.g. `html`, `python`, `mermaid`). Shown as a small label in the
  /// top-left corner. Hidden when empty (plain fences without a language).
  final String language;

  /// Optional additional action buttons placed in the top-right button
  /// row, to the right of the built-in wrap toggle.
  final List<Widget> actionButtons;

  const CodeBlockSourceView({
    super.key,
    required this.code,
    this.height,
    this.language = '',
    this.actionButtons = const [],
  });

  @override
  State<CodeBlockSourceView> createState() => _CodeBlockSourceViewState();
}

class _CodeBlockSourceViewState extends State<CodeBlockSourceView> {
  bool _wrapEnabled = false;

  /// Cursor width passed to the code [SelectableText]. [RenderEditable]
  /// wraps its text at `available width - (_kCaretGap + cursorWidth)`, so the
  /// wrap-mode measurement below subtracts `1.0 + _selectableCursorWidth` to
  /// stay in lock-step with the actual render. Keep both in sync if this
  /// ever changes.
  static const double _selectableCursorWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xff555555) : const Color(0xffeff1f3);
    final textColor =
        isDark ? const Color(0xfff8f8f2) : const Color(0xff000000);
    final borderColor = cs.outlineVariant;

    const lineHeight = 13.0 * 1.5; // fontSize * height

    if (widget.height != null) {
      return _buildSizedCodeBlock(
        height: widget.height!,
        bgColor: bgColor,
        textColor: textColor,
        borderColor: borderColor,
        isDark: isDark,
      );
    }

    // Adaptive height: cap at 15 visible lines so long code blocks do not
    // grow unbounded; shorter blocks stay compact (fit to their content).
    const verticalPadding = 40.0 + 12.0;
    const maxVisibleLines = 15;
    final lineCount = widget.code.isEmpty ? 0 : widget.code.split('\n').length;
    final contentHeight =
        lineCount > 0 ? lineCount * lineHeight + verticalPadding : 40.0;
    final maxAllowedHeight = maxVisibleLines * lineHeight + verticalPadding;
    final effectiveMax = maxAllowedHeight < 40.0 ? 40.0 : maxAllowedHeight;
    final adaptiveHeight = contentHeight.clamp(40.0, effectiveMax).toDouble();

    return _buildSizedCodeBlock(
      height: adaptiveHeight,
      bgColor: bgColor,
      textColor: textColor,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildSizedCodeBlock({
    required double height,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.code.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: SelectableText(
                        '(empty)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: textColor,
                          height: 1.5,
                        ),
                      ),
                    )
                  : _buildCodeContent(textColor, isDark),
            ),
            // Language label (top-left): the info string from the
            // opening fence (e.g. `html`, `python`), shown as-is.
            // Hidden while the code is empty so it cannot cover the
            // "(empty)" placeholder.
            if (widget.language.isNotEmpty && widget.code.isNotEmpty)
              Positioned(
                top: 8,
                left: 12,
                child: _buildLanguageLabel(),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: _buildButtonRow(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the small language badge shown in the top-left corner.
  Widget _buildLanguageLabel() {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        widget.language,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: isDark ? const Color(0xffcccccc) : const Color(0xff555555),
        ),
      ),
    );
  }

  Widget _buildCodeContent(Color textColor, bool isDark) {
    final lines = widget.code.split('\n');

    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: textColor,
      height: 1.5,
    );

    final lineNumStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: isDark ? const Color(0xff999999) : const Color(0xff888888),
      height: 1.5,
    );

    final digitCount = lines.length.toString().length;
    final lineNumWidth = (digitCount * 8.0 + 12.0).clamp(32.0, 80.0);

    return _buildCodeBlock(
      lines: lines,
      wrap: _wrapEnabled,
      lineNumWidth: lineNumWidth,
      lineNumStyle: lineNumStyle,
      codeStyle: codeStyle,
    );
  }

  /// Measures the actual rendered height of every logical code line when laid
  /// out at [maxWidth] with [codeStyle]. The code is shown in a single
  /// [SelectableText] (so a drag selection can span multiple lines), which
  /// means the line-number gutter can no longer align per-line inside the
  /// layout; instead each gutter entry is sized to the measured height of its
  /// logical line. Using the same style, text scaler and width constraint as
  /// the [SelectableText] keeps the gutter pixel-aligned with the rendered
  /// code lines in both wrap and no-wrap modes.
  List<double> _measureLineHeights(
    List<String> lines,
    TextStyle codeStyle,
    double maxWidth,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    return lines.map((line) {
      // An empty line still occupies one full line box in the rendered code;
      // measuring an empty string would report zero height instead.
      final painter = TextPainter(
        text: TextSpan(text: line.isEmpty ? ' ' : line, style: codeStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      return painter.height;
    }).toList();
  }

  /// Builds the line-number gutter. Each entry is [height] tall with the
  /// number pinned to its top-right, so the numbers line up with the first
  /// visual line of the corresponding (possibly wrapped) code line.
  Widget _buildLineNumberGutter(
    List<double> heights,
    double lineNumWidth,
    TextStyle lineNumStyle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < heights.length; i++)
          SizedBox(
            width: lineNumWidth,
            height: heights[i],
            child: Align(
              alignment: Alignment.topRight,
              child: Text(
                '${i + 1}',
                textAlign: TextAlign.right,
                style: lineNumStyle,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the code area: a line-number gutter next to a single
  /// [SelectableText] holding the whole code.
  ///
  /// In wrap mode the code wraps at the available width (the measurement
  /// width comes from a [LayoutBuilder]); in no-wrap mode the code sits in a
  /// horizontal scroll view, so every logical line is one visual line and the
  /// measurement width is unbounded.
  Widget _buildCodeBlock({
    required List<String> lines,
    required bool wrap,
    required double lineNumWidth,
    required TextStyle lineNumStyle,
    required TextStyle codeStyle,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 40, 12, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The SelectableText (RenderEditable) reserves a caret margin of
            // _kCaretGap (1.0) + cursorWidth and wraps text at
            // `available width - caretMargin`, so the measurement must use
            // the same width or lines falling in that narrow band wrap in
            // the render but not in the measurement, drifting the numbers
            // below them.
            final codeAreaWidth = wrap
                ? (constraints.maxWidth -
                        lineNumWidth -
                        8.0 -
                        1.0 -
                        _selectableCursorWidth)
                    .clamp(1.0, double.infinity)
                    .toDouble()
                : double.infinity;
            final visualHeights =
                _measureLineHeights(lines, codeStyle, codeAreaWidth);

            final codeSelectable = SelectableText(
              widget.code,
              style: codeStyle,
              cursorWidth: _selectableCursorWidth,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLineNumberGutter(
                  visualHeights,
                  lineNumWidth,
                  lineNumStyle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: wrap
                      ? codeSelectable
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: codeSelectable,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the top-right toolbar row.
  ///
  /// Toolbar buttons are PURE ICONS (no text labels) — accessibility is
  /// preserved through the icon [Icon.semanticLabel]. The built-in wrap
  /// toggle sits on the left; additional action buttons (common buttons
  /// like fullscreen / save / code toggle) are placed on the right in the
  /// order given by the consumer, matching the mermaid render toolbar
  /// convention (fullscreen → save → code).
  Widget _buildButtonRow() {
    final cs = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Wrap toggle button (always present)
            _buildActionButton(
              icon: Icons.wrap_text,
              label: _wrapEnabled ? '取消换行' : '换行显示',
              onTap: () {
                setState(() {
                  _wrapEnabled = !_wrapEnabled;
                });
              },
            ),
            // Additional action buttons from consumer
            ...widget.actionButtons,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 16,
          ),
          child: Icon(icon, size: 18, semanticLabel: label),
        ),
      ),
    );
  }
}
