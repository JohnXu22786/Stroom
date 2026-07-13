import 'package:flutter/material.dart';
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';

/// A widget that shows the raw HTML code inside a chat message (no inline
/// rendering), with a button to open the full-screen preview dialog.
///
/// The HTML is **not** rendered inline — only the raw source code is
/// displayed as a styled code block. The user must tap "全屏预览" to
/// open a [WebView]-based dialog that actually renders the HTML.
///
/// Each line of code is prefixed with a line number. A wrap toggle button
/// lets the user switch between horizontal scrolling (no wrap) and
/// soft-wrapping the code within the available width.
///
/// When wrapping is off (default), the code uses a single [SelectableText]
/// so users can select and copy text across multiple lines. When wrapping
/// is on, each logical line is rendered independently to accommodate
/// wrapped visual lines.
class HtmlCodeBlockWidget extends StatefulWidget {
  /// The raw HTML code to display.
  final String htmlCode;

  /// Optional height constraint for the code block. Defaults to 300.
  final double? height;

  const HtmlCodeBlockWidget({
    super.key,
    required this.htmlCode,
    this.height,
  });

  /// Builds a complete HTML document wrapping the given [rawHtml] content.
  ///
  /// The raw HTML is placed inside the `<body>` tag of a standalone HTML5
  /// document. It is **not** escaped — the user's HTML code should be
  /// rendered as-is by the WebView browser engine.
  static String buildHtmlDocument(String rawHtml) {
    return _htmlTemplate.replaceFirst(
      'HTML_CONTENT_PLACEHOLDER',
      rawHtml,
    );
  }

  static const _htmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: sans-serif;
      padding: 8px;
      background: transparent;
    }
  </style>
</head>
<body>
HTML_CONTENT_PLACEHOLDER
</body>
</html>
''';

  @override
  State<HtmlCodeBlockWidget> createState() => _HtmlCodeBlockWidgetState();
}

class _HtmlCodeBlockWidgetState extends State<HtmlCodeBlockWidget> {
  bool _wrapEnabled = false;

  void _openFullScreen(BuildContext context) {
    showHtmlPreviewDialog(
      context: context,
      htmlCode: widget.htmlCode,
    );
  }

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
      // Explicit height provided — use fixed height
      return _buildSizedCodeBlock(
        height: widget.height!,
        bgColor: bgColor,
        textColor: textColor,
        borderColor: borderColor,
        isDark: isDark,
        context: context,
        cs: cs,
      );
    }

    // Adaptive height: cap at roughly 4:3 aspect ratio (height = width * 3/4)
    const verticalPadding = 40.0 + 12.0; // top button row + bottom padding
    final lineCount =
        widget.htmlCode.isEmpty ? 0 : widget.htmlCode.split('\n').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxAllowedHeight = maxWidth * 0.75; // 4:3 width-to-height ratio
        final contentHeight = lineCount > 0
            ? lineCount * lineHeight + verticalPadding
            : 40.0; // minimal height for empty state
        // Ensure lower bound (40) does not exceed upper bound (maxAllowedHeight)
        // when the available width is very narrow
        final effectiveMax = maxAllowedHeight < 40.0 ? 40.0 : maxAllowedHeight;
        final adaptiveHeight = contentHeight.clamp(40.0, effectiveMax);

        return _buildSizedCodeBlock(
          height: adaptiveHeight,
          bgColor: bgColor,
          textColor: textColor,
          borderColor: borderColor,
          isDark: isDark,
          context: context,
          cs: cs,
        );
      },
    );
  }

  /// Builds the code block container with the given [height], shared by both
  /// the explicit-height branch and the adaptive-height branch.
  Widget _buildSizedCodeBlock({
    required double height,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    required bool isDark,
    required BuildContext context,
    required ColorScheme cs,
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
              child: widget.htmlCode.isEmpty
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
            Positioned(
              top: 4,
              right: 4,
              child: _buildButtonRow(context, cs),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the scrollable code content with line numbers, adapting to
  /// the [_wrapEnabled] state.
  Widget _buildCodeContent(Color textColor, bool isDark) {
    final lines = widget.htmlCode.split('\n');

    const lineHeight = 13.0 * 1.5; // fontSize * height

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

    // Line number column width based on the digit count
    final digitCount = lines.length.toString().length;
    final lineNumWidth = (digitCount * 8.0 + 12.0).clamp(32.0, 80.0);

    if (_wrapEnabled) {
      // --- WRAP MODE ---
      // Each logical line is rendered independently; line numbers align
      // with the start of each logical line. Cross-line selection is
      // per-line in this mode.
      return _buildWrapModeContent(
        lines,
        textColor,
        lineNumWidth,
        lineNumStyle,
        codeStyle,
        lineHeight,
      );
    } else {
      // --- NO-WRAP MODE ---
      // A single SelectableText preserves cross-line selection. Line
      // numbers are in a fixed Column alongside, each at lineHeight.
      return _buildNoWrapModeContent(
        widget.htmlCode,
        lines,
        textColor,
        lineNumWidth,
        lineNumStyle,
        codeStyle,
        lineHeight,
      );
    }
  }

  /// Builds code content for wrap mode with per-line SelectableText.
  Widget _buildWrapModeContent(
    List<String> lines,
    Color textColor,
    double lineNumWidth,
    TextStyle lineNumStyle,
    TextStyle codeStyle,
    double lineHeight,
  ) {
    final lineWidgets = List<Widget>.generate(lines.length, (i) {
      final lineNum = i + 1;
      final line = lines[i];
      final codeText = line.isEmpty ? ' ' : line;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line number
          SizedBox(
            width: lineNumWidth,
            height: lineHeight,
            child: Text(
              '$lineNum',
              textAlign: TextAlign.right,
              style: lineNumStyle,
              overflow: TextOverflow.clip,
            ),
          ),
          const SizedBox(width: 8),
          // Code text: constrained to available width so it wraps
          Expanded(
            child: SelectableText(
              codeText,
              style: codeStyle,
            ),
          ),
        ],
      );
    });

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 40, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lineWidgets,
        ),
      ),
    );
  }

  /// Builds code content for no-wrap mode with a single SelectableText
  /// for cross-line selection support, and a sticky line-number column
  /// on the left that does NOT scroll away when the user drags
  /// horizontally to see overflow content.
  Widget _buildNoWrapModeContent(
    String fullCode,
    List<String> lines,
    Color textColor,
    double lineNumWidth,
    TextStyle lineNumStyle,
    TextStyle codeStyle,
    double lineHeight,
  ) {
    // Line numbers column — stays fixed because it sits OUTSIDE the
    // horizontal SingleChildScrollView below.
    final lineNumWidgets = List<Widget>.generate(lines.length, (i) {
      return SizedBox(
        width: lineNumWidth,
        height: lineHeight,
        child: Text(
          '${i + 1}',
          textAlign: TextAlign.right,
          style: lineNumStyle,
          overflow: TextOverflow.clip,
        ),
      );
    });

    final lineNumColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: lineNumWidgets,
    );

    final codeWidget = SelectableText(
      fullCode,
      style: codeStyle,
      // Ensure text does not wrap; horizontal scroll handles overflow.
      // No explicit softWrap — the unconstrained layout (inside horizontal
      // SingleChildScrollView) prevents wrapping regardless.
    );

    // Vertical scroll wraps a Row that, on the left, keeps the line-number
    // column fixed, and on the right nests the horizontal scroll for the
    // code content only.
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 40, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line numbers — outside the horizontal scroll, so they
            // remain visible when the user scrolls the code sideways.
            lineNumColumn,
            const SizedBox(width: 8),
            // Code scrolls horizontally while line numbers stay put.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: codeWidget,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the row of action buttons (wrap toggle + fullscreen preview)
  /// positioned at the top right of the code block.
  Widget _buildButtonRow(BuildContext context, ColorScheme cs) {
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
            // Wrap toggle button
            _buildActionButton(
              icon: Icons.wrap_text,
              label: _wrapEnabled ? '取消换行' : '换行显示',
              onTap: () {
                setState(() {
                  _wrapEnabled = !_wrapEnabled;
                });
              },
            ),
            // Fullscreen preview button
            _buildActionButton(
              icon: Icons.fullscreen,
              label: '全屏预览',
              onTap: () => _openFullScreen(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single action button inside the button row.
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, semanticLabel: label),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
