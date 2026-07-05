import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';

/// A widget that renders HTML code inline inside a chat message using
/// [InAppWebView], with a button to open the full-screen preview dialog.
///
/// Follows the same pattern as [MermaidRenderWidget] but for arbitrary HTML
/// content. The inline WebView has JavaScript enabled and mixed content
/// allowed so that CDN libraries and external resources can load.
/// Navigation is intercepted in the inline view to prevent accidental
/// navigation away from the chat context.
class HtmlCodeBlockWidget extends StatefulWidget {
  /// The raw HTML code to render.
  final String htmlCode;

  /// Optional height constraint for the inline preview. Defaults to 300.
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
  InAppWebViewController? _webViewController;
  bool _isReady = false;

  @override
  void didUpdateWidget(HtmlCodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlCode != widget.htmlCode) {
      _isReady = false;
      _loadHtmlCode();
    }
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  void _loadHtmlCode() {
    final ctrl = _webViewController;
    if (ctrl == null) return;
    ctrl.loadData(
      data: _getInitialHtml(),
      mimeType: 'text/html',
      encoding: 'utf8',
    );
  }

  void _openFullScreen() {
    showHtmlPreviewDialog(
      context: context,
      htmlCode: widget.htmlCode,
    );
  }

  static const _emptyPlaceholderHtml = '''
<html>
<body style="background:transparent;display:flex;justify-content:center;align-items:center;height:100%;font-family:sans-serif;color:#999;font-size:14px;padding:16px;text-align:center;">
<div>No HTML content to preview</div>
</body>
</html>''';

  String _getInitialHtml() {
    final code = widget.htmlCode.trim();
    if (code.isEmpty) {
      return _emptyPlaceholderHtml;
    }
    return HtmlCodeBlockWidget.buildHtmlDocument(code);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.height ?? 300.0;
    final cs = Theme.of(context).colorScheme;

    final showLoading = widget.htmlCode.trim().isNotEmpty && !_isReady;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: effectiveHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: cs.outlineVariant,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // The WebView — created once, stays alive
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                transparentBackground: true,
              ),
              initialData: InAppWebViewInitialData(
                data: _getInitialHtml(),
                mimeType: 'text/html',
                encoding: 'utf8',
              ),
              onWebViewCreated: (ctrl) {
                _webViewController = ctrl;
              },
              onLoadStop: (ctrl, url) {
                if (mounted && !_isReady) {
                  setState(() => _isReady = true);
                }
              },
              onLoadError: (ctrl, url, code, message) {
                if (mounted && !_isReady) {
                  setState(() => _isReady = true);
                }
              },
              // Intercept navigation in inline view so clicking links
              // doesn't navigate away from the chat context. Users can
              // still open links by using the full-screen preview.
              shouldOverrideUrlLoading: (ctrl, navigationAction) async {
                return NavigationActionPolicy.CANCEL;
              },
            ),

            // Loading overlay
            if (showLoading)
              Positioned.fill(
                child: Container(
                  color: cs.surface,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '加载 HTML 预览...',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
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
                      onTap: _openFullScreen,
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
