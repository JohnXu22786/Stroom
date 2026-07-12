import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/widgets/html_code_block_widget.dart';

/// Full-screen dialog that renders HTML code in a completely open sandbox
/// WebView browser.
///
/// Configuration:
/// - JavaScript enabled
/// - Mixed content always allowed (MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW)
/// - File access from file URLs allowed
/// - Universal access from file URLs allowed
/// - Default navigation behavior (hyperlinks clickable, page navigation allowed)
///
/// This allows the user to freely browse the rendered HTML, interact with
/// JavaScript, load CDN libraries, images, and other external resources,
/// and navigate to linked pages by clicking hyperlinks.
void showHtmlPreviewDialog({
  required BuildContext context,
  required String htmlCode,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _HtmlPreviewDialogContent(htmlCode: htmlCode),
  );
}

class _HtmlPreviewDialogContent extends StatefulWidget {
  final String htmlCode;

  const _HtmlPreviewDialogContent({required this.htmlCode});

  @override
  State<_HtmlPreviewDialogContent> createState() =>
      _HtmlPreviewDialogContentState();
}

class _HtmlPreviewDialogContentState extends State<_HtmlPreviewDialogContent> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  String _buildHtml() {
    final code = widget.htmlCode.trim();
    if (code.isEmpty) {
      return _emptyPlaceholderHtml;
    }
    // Reuse the shared HTML builder from HtmlCodeBlockWidget, then add
    // extra body padding via a style override injected into the <head>.
    final base = HtmlCodeBlockWidget.buildHtmlDocument(code);
    // Add dialog-specific body padding override
    return base.replaceFirst(
      '</head>',
      '''  <style>
    body { padding: 16px; }
  </style>
</head>''',
    );
  }

  static const _emptyPlaceholderHtml = '''
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      color: #999;
      font-size: 14px;
      padding: 16px;
      text-align: center;
    }
  </style>
</head>
<body>
<div>No HTML content to preview</div>
</body>
</html>''';

  Future<bool> _onPopScope() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      if (canGoBack) {
        _webViewController!.goBack();
        return false; // Do NOT pop the dialog
      }
    }
    return true; // Allow dialog to close
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onPopScope();
        if (shouldPop) {
          if (!context.mounted) return;
          Navigator.pop(context);
        }
      },
      child: Dialog(
        backgroundColor: cs.surface,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // WebView — full screen preview with fully open permissions
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                domStorageEnabled: true,
                // Allow navigation — users can click links and browse
                useOnDownloadStart: true,
              ),
              initialData: InAppWebViewInitialData(
                data: _buildHtml(),
                mimeType: 'text/html',
                encoding: 'utf8',
              ),
              onWebViewCreated: (ctrl) {
                _webViewController = ctrl;
              },
              onLoadStop: (ctrl, url) {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              },
              onReceivedError: (controller, request, error) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                  });
                }
              },
            ),

            // Loading overlay
            if (_isLoading)
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
                        const SizedBox(height: 12),
                        Text(
                          '加载 HTML 预览...',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Error overlay
            if (_hasError)
              Positioned.fill(
                child: Container(
                  color: cs.surface,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: cs.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '加载失败',
                          style: TextStyle(
                            fontSize: 16,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top bar with title and close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 4,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  const Spacer(),
                  // Title label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'HTML 预览',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Close button
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 24),
                        tooltip: '关闭预览',
                        color: cs.onSurface,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
