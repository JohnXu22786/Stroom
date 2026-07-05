import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A reusable widget that renders Mermaid diagram code using [InAppWebView]
/// with mermaid.js loaded from CDN.
///
/// This widget is extracted from [MermaidChartPage] to be used inline
/// in chat messages and other contexts where Mermaid rendering is needed.
class MermaidRenderWidget extends StatefulWidget {
  /// The Mermaid diagram code to render.
  final String mermaidCode;

  /// Optional height constraint. If null, a default of 300 is used.
  final double? height;

  const MermaidRenderWidget({
    super.key,
    required this.mermaidCode,
    this.height,
  });

  /// Builds a complete HTML document with mermaid.js that renders the
  /// given [mermaidCode] as a diagram.
  static String buildMermaidHtml(String mermaidCode) {
    final escaped = mermaidCode
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return _mermaidHtmlTemplate.replaceFirst(
      'MERMAID_CODE_PLACEHOLDER',
      escaped,
    );
  }

  static const _mermaidHtmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js">
  </script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: sans-serif;
      padding: 16px;
      background: transparent;
      display: flex;
      justify-content: center;
    }
    #container {
      max-width: 100%;
      overflow-x: auto;
    }
    .mermaid {
      text-align: center;
    }
    .error-message {
      color: #e74c3c;
      padding: 16px;
      border: 1px solid #e74c3c;
      border-radius: 8px;
      margin: 16px;
      background: #fdf0ef;
      font-family: monospace;
      white-space: pre-wrap;
    }
  </style>
</head>
<body>
  <div id="container">
    <pre class="mermaid" id="mermaid-code">
MERMAID_CODE_PLACEHOLDER
    </pre>
  </div>
  <script>
    try {
      mermaid.initialize({
        startOnLoad: true,
        theme: 'default',
        securityLevel: 'loose',
        fontFamily: 'sans-serif',
      });
    } catch(e) {
      document.getElementById('container').innerHTML =
        '<div class="error-message">Mermaid initialize error: ' + e.message + '</div>';
    }
  </script>
</body>
</html>
''';

  @override
  State<MermaidRenderWidget> createState() => _MermaidRenderWidgetState();
}

class _MermaidRenderWidgetState extends State<MermaidRenderWidget> {
  InAppWebViewController? _webViewController;
  bool _isReady = false;

  @override
  void didUpdateWidget(MermaidRenderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidCode != widget.mermaidCode) {
      // Reset ready state so the loading overlay reappears
      _isReady = false;
      _loadMermaidCode();
    }
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  void _loadMermaidCode() {
    final ctrl = _webViewController;
    // If the WebView hasn't been created yet, the initial data will
    // already contain the correct content via _getInitialHtml().
    if (ctrl == null) return;

    final code = widget.mermaidCode.trim();
    if (code.isEmpty) {
      ctrl.loadData(
        data: _emptyPlaceholderHtml,
        mimeType: 'text/html',
        encoding: 'utf8',
      );
      return;
    }

    final html = MermaidRenderWidget.buildMermaidHtml(code);
    ctrl.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf8',
    );
  }

  static const _emptyPlaceholderHtml = '''
<html>
<body style="background:transparent;display:flex;justify-content:center;align-items:center;height:100%;font-family:sans-serif;color:#999;font-size:14px;padding:16px;text-align:center;">
<div>No Mermaid code to render</div>
</body>
</html>''';

  String _getInitialHtml() {
    final code = widget.mermaidCode.trim();
    if (code.isEmpty) {
      return _emptyPlaceholderHtml;
    }
    return MermaidRenderWidget.buildMermaidHtml(code);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.height ?? 300.0;
    final cs = Theme.of(context).colorScheme;

    // Determine if we should show the loading overlay
    final showLoading = widget.mermaidCode.trim().isNotEmpty && !_isReady;

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
                  // Even if the CDN fails, mark as ready so the loading
                  // overlay disappears and the user can see the error
                  // message displayed inside the WebView HTML.
                  setState(() => _isReady = true);
                }
              },
            ),

            // Loading overlay — only shown while WebView is loading
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
                          '加载渲染引擎...',
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
          ],
        ),
      ),
    );
  }
}
