import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A reusable widget that renders Mermaid diagram code using [InAppWebView]
/// with mermaid.js loaded from CDN.
///
/// This widget is extracted from [MermaidChartPage] to be used inline
/// in chat messages and other contexts where Mermaid rendering is needed.
///
/// ## UI Isolation
///
/// The [InAppWebView] creation is deferred to after the first frame via
/// [WidgetsBinding.instance.addPostFrameCallback] so that creating the
/// heavyweight platform view (WebView2 on Windows) does not freeze the
/// initial page transition. A [CircularProgressIndicator] loading state
/// is shown while the WebView is being created and initialized.
///
/// Mermaid rendering errors are reported from JavaScript back to Flutter
/// via `callHandler`, so the widget can display a user-friendly error
/// widget with a retry button.
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
  ///
  /// This is the single source of truth for the Mermaid HTML/JS template.
  /// Both [MermaidRenderWidget] and [MermaidChartPage] use this method.
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
      overflow-x: auto;
    }
    #container {
      max-width: 100%;
      overflow-x: auto;
    }
    .mermaid {
      text-align: center;
    }
    /* Prevent mermaid SVG from overflowing its container */
    .mermaid svg {
      max-width: 100%;
      height: auto;
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
    function reportError(msg) {
      document.getElementById('container').innerHTML =
        '<div class="error-message">' + msg + '</div>';
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('onMermaidError', msg);
        }
      } catch(_) {}
    }
    try {
      mermaid.initialize({
        theme: 'default',
        securityLevel: 'loose',
        fontFamily: 'sans-serif',
      });
      mermaid.run({
        nodes: [document.getElementById('mermaid-code')],
      }).catch(function(err) {
        reportError('Mermaid render error: ' + err.message);
      });
    } catch(e) {
      reportError('Mermaid initialize error: ' + e.message);
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
  bool _shouldCreateWebView = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Defer WebView creation to after the first frame so that the
    // page transition is not blocked by platform view creation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_shouldCreateWebView) {
        setState(() => _shouldCreateWebView = true);
      }
    });
  }

  @override
  void didUpdateWidget(MermaidRenderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidCode != widget.mermaidCode) {
      _isReady = false;
      _errorMessage = null;
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

  void _retry() {
    setState(() {
      _errorMessage = null;
      _isReady = false;
    });
    // The WebView stays alive (never removed from tree), so the controller
    // is still valid for reloading the mermaid code.
    _loadMermaidCode();
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
    final code = widget.mermaidCode.trim();

    // ---- Loading placeholder (deferred WebView creation) ----
    // Only shown before the WebView is first created.
    if (!_shouldCreateWebView) {
      return _buildBorderedContainer(
        height: effectiveHeight,
        cs: cs,
        child: code.isEmpty
            ? _buildEmptyPlaceholder(cs)
            : _buildLoadingIndicator(cs, '正在准备渲染引擎...'),
      );
    }

    // ---- WebView + overlays ----
    // The WebView is always kept alive once created. Loading, empty code,
    // and error states are overlaid on top so the platform view (WebView2)
    // is never destroyed by removing it from the widget tree.
    final showLoading = !_isReady && _errorMessage == null && code.isNotEmpty;
    final showEmptyOverlay = code.isEmpty && _isReady;
    final showErrorOverlay = _errorMessage != null;

    return _buildBorderedContainer(
      height: effectiveHeight,
      cs: cs,
      child: Stack(
        children: [
          // The WebView — kept alive once created via the key
          InAppWebView(
            key: const Key('mermaid_render_webview'),
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
              // Set up JavaScript handler to receive mermaid errors
              ctrl.addJavaScriptHandler(
                handlerName: 'onMermaidError',
                callback: (args) {
                  if (mounted) {
                    final msg =
                        args.isNotEmpty ? args[0].toString() : '未知错误';
                    setState(() => _errorMessage = msg);
                  }
                },
              );
            },
            onLoadStop: (ctrl, url) {
              if (mounted && !_isReady) {
                setState(() => _isReady = true);
              }
            },
            onLoadError: (ctrl, url, code, message) {
              if (mounted && !_isReady) {
                setState(() {
                  _isReady = true;
                  _errorMessage = '页面加载失败: $message';
                });
              }
            },
          ),

          // Loading overlay — shown while WebView is initializing
          if (showLoading)
            Positioned.fill(
              child: Container(
                color: cs.surface,
                child: _buildLoadingIndicator(cs, '加载渲染引擎...'),
              ),
            ),

          // Empty code overlay — shown when code is cleared but WebView stays alive
          if (showEmptyOverlay)
            Positioned.fill(
              child: Container(
                color: cs.surface,
                child: _buildEmptyPlaceholder(cs),
              ),
            ),

          // Error overlay — shown on top of the WebView when mermaid fails
          if (showErrorOverlay)
            Positioned.fill(
              child: Container(
                color: cs.surface,
                child: _buildErrorWidget(cs, _errorMessage!),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _buildBorderedContainer({
    required double height,
    required ColorScheme cs,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }

  Widget _buildLoadingIndicator(ColorScheme cs, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.primary,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(ColorScheme cs) {
    return Center(
      child: Text(
        'No Mermaid code to render',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(ColorScheme cs, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: cs.error),
            const SizedBox(height: 8),
            Text(
              '渲染图表时出错',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
