import 'package:flutter/material.dart';
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';
import 'code_block_source_widget.dart';

/// Widget shown for ```html fenced code blocks inside a chat message.
///
/// The default preview is a compact CARD (not the raw code): it shows an
/// "html" language badge, the document's extracted `<title>` as a single
/// centered line, a "正在生成中..." indicator while the block is still
/// being generated, and two action buttons — 全屏查看 (renders the HTML in a
/// full-screen [WebView]-based dialog; disabled while generating) and
/// 查看代码 (reveals the raw source).
///
/// Tapping 查看代码 switches to the shared [CodeBlockSourceView] code
/// display. In that code view the preview action uses an eye icon
/// ([Icons.visibility], meaning "preview") — HTML only; other code blocks
/// keep the plain fullscreen icon.
class HtmlCodeBlockWidget extends StatefulWidget {
  /// The raw HTML code to display.
  final String htmlCode;

  /// The language from the opening fence (e.g. `html`, `HTML`), shown
  /// as-is in the top-left badge. Defaults to 'html'.
  final String language;

  /// Optional height constraint for the code block (code view only).
  final double? height;

  /// True while the code block is still being generated (its fence is
  /// still open). While true the card shows "正在生成中..." and the
  /// full-screen preview button is disabled.
  final bool isStreaming;

  const HtmlCodeBlockWidget({
    super.key,
    required this.htmlCode,
    this.language = 'html',
    this.height,
    this.isStreaming = false,
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

  /// Extracts the text of the document's `<title>` tag, trimmed, or ''
  /// when the HTML has no (non-empty) title. Case-insensitive.
  static String extractHtmlTitle(String html) {
    final match = RegExp(
      r'<\s*title\b[^>]*>([\s\S]*?)<\s*/\s*title\s*>',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1)?.trim() ?? '';
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
  /// Whether the raw source code view is shown instead of the card.
  bool _showCode = false;

  void _openFullScreen(BuildContext context) {
    showHtmlPreviewDialog(
      context: context,
      htmlCode: widget.htmlCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showCode) {
      return CodeBlockSourceView(
        code: widget.htmlCode,
        height: widget.height,
        language: widget.language,
        actionButtons: [
          // HTML code view uses an EYE icon for "preview" (only HTML; all
          // other code blocks keep the plain fullscreen icon).
          _buildActionButton(
            icon: Icons.visibility,
            label: '预览',
            onTap: () => _openFullScreen(context),
          ),
          _buildActionButton(
            icon: Icons.arrow_back,
            label: '返回卡片',
            onTap: () => setState(() => _showCode = false),
          ),
        ],
      );
    }
    return _buildCard(context);
  }

  /// The default HTML card preview.
  Widget _buildCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff555555) : const Color(0xffeff1f3);
    final title = HtmlCodeBlockWidget.extractHtmlTitle(widget.htmlCode);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: cs.outlineVariant, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language badge (top-left): the fence info string, as-is.
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
                    color: isDark
                        ? const Color(0xffcccccc)
                        : const Color(0xff555555),
                  ),
                ),
              ),
            ),
            // The extracted document <title>, shown as a single centered
            // line (replaces the old 标题 button). Hidden when the HTML has
            // no (non-empty) title.
            if (title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xffe0e0e0)
                      : const Color(0xff333333),
                ),
              ),
            ],
            // "(empty)" hint for a finished block with no content.
            if (widget.htmlCode.trim().isEmpty && !widget.isStreaming) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '(empty)',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            // "正在生成中" indicator while the block is still streaming.
            if (widget.isStreaming) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '正在生成中...',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons: 全屏查看 / 查看代码. Wrapped so very narrow
            // bubbles wrap onto a second row instead of overflowing.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCardButton(
                  icon: Icons.fullscreen,
                  label: '全屏查看',
                  onPressed: widget.isStreaming
                      ? null
                      : () => _openFullScreen(context),
                ),
                _buildCardButton(
                  icon: Icons.code,
                  label: '查看代码',
                  onPressed: () => setState(() => _showCode = true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
