import 'package:flutter/material.dart';
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';
import 'code_block_source_widget.dart';

/// A widget that shows the raw HTML code inside a chat message (no inline
/// rendering), with a button to open the full-screen preview dialog.
///
/// The HTML is **not** rendered inline — only the raw source code is
/// displayed as a styled code block. The user must tap "全屏预览" to
/// open a [WebView]-based dialog that actually renders the HTML.
///
/// The code display area uses the shared [CodeBlockSourceView] widget
/// that provides line numbers and a wrap toggle. This widget adds the
/// fullscreen preview button on top.
class HtmlCodeBlockWidget extends StatelessWidget {
  /// The raw HTML code to display.
  final String htmlCode;

  /// Optional height constraint for the code block.
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
    return CodeBlockSourceView(
      code: htmlCode,
      height: height,
      actionButtons: [
        _buildActionButton(
          icon: Icons.fullscreen,
          label: '全屏预览',
          onTap: () => _openFullScreen(context),
        ),
      ],
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
