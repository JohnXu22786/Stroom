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
  /// roughly 4:3 aspect ratio (height = width * 3/4).
  final double? height;

  /// Optional additional action buttons placed in the top-right button
  /// row, to the right of the built-in wrap toggle.
  final List<Widget> actionButtons;

  const CodeBlockSourceView({
    super.key,
    required this.code,
    this.height,
    this.actionButtons = const [],
  });

  @override
  State<CodeBlockSourceView> createState() => _CodeBlockSourceViewState();
}

class _CodeBlockSourceViewState extends State<CodeBlockSourceView> {
  bool _wrapEnabled = false;

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

    // Adaptive height: cap at roughly 4:3 aspect ratio
    const verticalPadding = 40.0 + 12.0;
    final lineCount =
        widget.code.isEmpty ? 0 : widget.code.split('\n').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxAllowedHeight = maxWidth * 0.75;
        final contentHeight = lineCount > 0
            ? lineCount * lineHeight + verticalPadding
            : 40.0;
        final effectiveMax =
            maxAllowedHeight < 40.0 ? 40.0 : maxAllowedHeight;
        final adaptiveHeight = contentHeight.clamp(40.0, effectiveMax);

        return _buildSizedCodeBlock(
          height: adaptiveHeight,
          bgColor: bgColor,
          textColor: textColor,
          borderColor: borderColor,
          isDark: isDark,
        );
      },
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

  Widget _buildCodeContent(Color textColor, bool isDark) {
    final lines = widget.code.split('\n');

    const lineHeight = 13.0 * 1.5;

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

    if (_wrapEnabled) {
      return _buildWrapModeContent(
        lines,
        textColor,
        lineNumWidth,
        lineNumStyle,
        codeStyle,
        lineHeight,
      );
    } else {
      return _buildNoWrapModeContent(
        widget.code,
        lines,
        textColor,
        lineNumWidth,
        lineNumStyle,
        codeStyle,
        lineHeight,
      );
    }
  }

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

  Widget _buildNoWrapModeContent(
    String fullCode,
    List<String> lines,
    Color textColor,
    double lineNumWidth,
    TextStyle lineNumStyle,
    TextStyle codeStyle,
    double lineHeight,
  ) {
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
    );

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 40, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lineNumColumn,
            const SizedBox(width: 8),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, semanticLabel: label),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
