import 'package:flutter/material.dart';
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';

/// A widget that shows the raw HTML code inside a chat message (no inline
/// rendering), with a button to open the full-screen preview dialog.
///
/// The HTML is **not** rendered inline — only the raw source code is
/// displayed as a styled code block. The user must tap "全屏预览" to
/// open a [WebView]-based dialog that actually renders the HTML.
class HtmlCodeBlockWidget extends StatelessWidget {
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

  void _openFullScreen(BuildContext context) {
    showHtmlPreviewDialog(
      context: context,
      htmlCode: htmlCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? 300.0;
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xff555555) : const Color(0xffeff1f3);
    final textColor =
        isDark ? const Color(0xfff8f8f2) : const Color(0xff000000);
    final borderColor = cs.outlineVariant;

    return SizedBox(
      height: effectiveHeight,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Raw HTML source code shown as a scrollable code block
            Positioned.fill(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: SelectableText(
                      htmlCode.isEmpty ? '(empty)' : htmlCode,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Full-screen button (top right) with minimum 48x48 touch target
            Positioned(
              top: 4,
              right: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _openFullScreen(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen,
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '全屏预览',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
