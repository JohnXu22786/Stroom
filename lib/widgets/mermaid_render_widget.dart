import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/pages/chat/dialogs/mermaid_preview_dialog.dart';

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
///
/// ## Pan / Zoom / Controls
///
/// The rendered diagram supports:
/// - **Drag to pan** with the mouse (click and drag on the diagram area).
/// - **Zoom** via Ctrl+MouseWheel, pinch-to-zoom on touch devices, or
///   the zoom in/out buttons in the top-right toolbar.
/// - **Fullscreen** button opens [MermaidPreviewDialog].
/// - **Toggle source code** button switches between the rendered diagram
///   and the raw Mermaid source code view.
///
/// The pan and zoom logic is implemented in JavaScript inside the WebView
/// HTML template. The Flutter side communicates zoom level changes via
/// [InAppWebViewController.evaluateJavascript].
class MermaidRenderWidget extends StatefulWidget {
  /// The Mermaid diagram code to render.
  final String mermaidCode;

  /// Optional height constraint. If null and [expand] is false, a default
  /// of 300 is used.
  final double? height;

  /// If true, the widget fills the available space instead of having a
  /// fixed [height]. Used by [MermaidChartPage] to fill the preview pane.
  ///
  /// Defaults to false for backward compatibility (inline chat usage).
  final bool expand;

  /// {@template mermaid_render_widget_test_only_show_source_code}
  /// Test-only: if true, the widget starts in source-code view mode instead of
  /// render mode. This allows widget tests to verify the source code view and
  /// button behaviors without triggering [InAppWebView] creation (which
  /// requires a platform implementation).
  /// {@endtemplate}
  final bool? testOnlyShowSourceCode;

  const MermaidRenderWidget({
    super.key,
    required this.mermaidCode,
    this.height,
    this.expand = false,
    this.testOnlyShowSourceCode,
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
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js">
  </script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: transparent;
    }
    #viewport {
      width: 100%;
      height: 100%;
      overflow: hidden;
      position: relative;
    }
    #diagram-container {
      transform-origin: 0 0;
      display: inline-block;
      cursor: grab;
    }
    #diagram-container:active {
      cursor: grabbing;
    }
    .mermaid {
      text-align: left;
    }
    .mermaid svg {
      max-width: none;
      max-height: none;
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
  <div id="viewport">
    <div id="diagram-container">
      <pre class="mermaid" id="mermaid-code">
MERMAID_CODE_PLACEHOLDER
      </pre>
    </div>
  </div>
  <script>
    var zoomLevel = 1;
    var panX = 0;
    var panY = 0;
    var isDragging = false;
    var dragStartX = 0;
    var dragStartY = 0;
    var panStartX = 0;
    var panStartY = 0;

    function updateTransform() {
      var container = document.getElementById('diagram-container');
      container.style.transform =
        'translate(' + panX + 'px, ' + panY + 'px) scale(' + zoomLevel + ')';
    }

    function reportError(msg) {
      document.getElementById('viewport').innerHTML =
        '<div class="error-message">' + msg + '</div>';
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('onMermaidError', msg);
        }
      } catch(_) {}
    }

    // Called from Flutter or local handlers to set zoom level.
    // When centerX / centerY are provided, the zoom is anchored at that
    // point (in viewport coordinates) instead of the top-left corner.
    window.setZoom = function(level, centerX, centerY) {
      var oldZoom = zoomLevel;
      zoomLevel = Math.max(0.1, Math.min(10, level));
      if (centerX !== undefined && centerY !== undefined) {
        // Adjust pan so that (centerX, centerY) stays fixed on screen.
        panX = centerX - (centerX - panX) * (zoomLevel / oldZoom);
        panY = centerY - (centerY - panY) * (zoomLevel / oldZoom);
      }
      updateTransform();
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('onZoomChanged', zoomLevel);
        }
      } catch(_) {}
    };

    // Called from Flutter to set pan offset
    window.setPan = function(x, y) {
      panX = x;
      panY = y;
      updateTransform();
    };

    // Drag-to-pan with mouse
    document.addEventListener('mousedown', function(e) {
      if (e.target.closest('#diagram-container')) {
        isDragging = true;
        dragStartX = e.clientX;
        dragStartY = e.clientY;
        panStartX = panX;
        panStartY = panY;
        e.preventDefault();
      }
    });

    document.addEventListener('mousemove', function(e) {
      if (isDragging) {
        panX = panStartX + (e.clientX - dragStartX);
        panY = panStartY + (e.clientY - dragStartY);
        updateTransform();
        e.preventDefault();
      }
    });

    document.addEventListener('mouseup', function() {
      isDragging = false;
    });

    // Zoom with Ctrl/Meta + MouseWheel — zooms towards the cursor position.
    document.addEventListener('wheel', function(e) {
      if (e.ctrlKey || e.metaKey) {
        e.preventDefault();
        var rect = document.getElementById('viewport').getBoundingClientRect();
        var centerX = e.clientX - rect.left;
        var centerY = e.clientY - rect.top;
        var delta = e.deltaY > 0 ? -0.1 : 0.1;
        window.setZoom(zoomLevel + delta, centerX, centerY);
      }
    }, { passive: false });

    // Touch events for mobile pan
    var touchStartX, touchStartY;
    var touchPanStartX, touchPanStartY;
    var lastTouchDist = 0;

    document.addEventListener('touchstart', function(e) {
      if (e.touches.length === 1) {
        touchStartX = e.touches[0].clientX;
        touchStartY = e.touches[0].clientY;
        touchPanStartX = panX;
        touchPanStartY = panY;
      } else if (e.touches.length === 2) {
        lastTouchDist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
      }
    });

    document.addEventListener('touchmove', function(e) {
      if (e.touches.length === 1) {
        panX = touchPanStartX + (e.touches[0].clientX - touchStartX);
        panY = touchPanStartY + (e.touches[0].clientY - touchStartY);
        updateTransform();
        e.preventDefault();
      } else if (e.touches.length === 2) {
        var dist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
        var scale = dist / lastTouchDist;
        lastTouchDist = dist;
        // Compute the midpoint of the two touches in viewport coordinates
        var midX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
        var midY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
        var rect = document.getElementById('viewport').getBoundingClientRect();
        var centerX = midX - rect.left;
        var centerY = midY - rect.top;
        window.setZoom(zoomLevel * scale, centerX, centerY);
        e.preventDefault();
      }
    }, { passive: false });

    document.addEventListener('touchend', function() {
      lastTouchDist = 0;
    });

    // Initialize mermaid
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

  /// Whether the source code view is shown instead of the rendered diagram.
  bool _showSourceCode = false;

  /// Current zoom level tracked on the Flutter side.
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    // Test-only: start in source code mode if requested (avoids creating
    // InAppWebView which requires a platform implementation).
    if (widget.testOnlyShowSourceCode == true) {
      _showSourceCode = true;
      return;
    }
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
      _showSourceCode = false;
      _zoomLevel = 1.0;
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
    _loadMermaidCode();
  }

  Future<void> _zoomIn() async {
    final newZoom = (_zoomLevel + 0.1).clamp(0.1, 10.0);
    setState(() => _zoomLevel = newZoom);
    await _webViewController?.evaluateJavascript(
      source: 'window.setZoom($newZoom)',
    );
  }

  Future<void> _zoomOut() async {
    final newZoom = (_zoomLevel - 0.1).clamp(0.1, 10.0);
    setState(() => _zoomLevel = newZoom);
    await _webViewController?.evaluateJavascript(
      source: 'window.setZoom($newZoom)',
    );
  }

  void _toggleSourceCode() {
    setState(() => _showSourceCode = !_showSourceCode);
  }

  void _openFullScreen() {
    showMermaidPreviewDialog(
      context: context,
      mermaidCode: widget.mermaidCode,
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
    final effectiveHeight = widget.expand ? null : (widget.height ?? 300.0);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final code = widget.mermaidCode.trim();

    // ---- Empty code placeholder ----
    if (code.isEmpty) {
      return _buildBorderedContainer(
        height: effectiveHeight,
        cs: cs,
        child: _buildEmptyPlaceholder(cs),
      );
    }

    // ---- Source code mode: show raw code without WebView ----
    if (_showSourceCode) {
      return _buildBorderedContainer(
        height: effectiveHeight,
        cs: cs,
        child: Stack(
          children: [
            _buildSourceCodeView(cs, isDark),
            // Button row at top right
            Positioned(
              top: 4,
              right: 4,
              child: _buildButtonRow(cs),
            ),
          ],
        ),
      );
    }

    // ---- Loading placeholder (deferred WebView creation) ----
    if (!_shouldCreateWebView) {
      return _buildBorderedContainer(
        height: effectiveHeight,
        cs: cs,
        child: _buildLoadingIndicator(cs, '正在准备渲染引擎...'),
      );
    }

    // ---- Render mode: WebView + overlays + button row ----
    final showLoading = !_isReady && _errorMessage == null;
    final showErrorOverlay = _errorMessage != null;

    return _buildBorderedContainer(
      height: effectiveHeight,
      cs: cs,
      child: Stack(
        children: [
          // The WebView — kept alive once created
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
              ctrl.addJavaScriptHandler(
                handlerName: 'onMermaidError',
                callback: (args) {
                  if (mounted) {
                    final msg = args.isNotEmpty ? args[0].toString() : '未知错误';
                    setState(() => _errorMessage = msg);
                  }
                },
              );
              ctrl.addJavaScriptHandler(
                handlerName: 'onZoomChanged',
                callback: (args) {
                  if (mounted && args.isNotEmpty) {
                    final level = double.tryParse(args[0].toString()) ?? 1.0;
                    setState(() => _zoomLevel = level);
                  }
                },
              );
            },
            onLoadStop: (ctrl, url) {
              if (mounted && !_isReady) {
                setState(() => _isReady = true);
              }
            },
            onReceivedError: (controller, request, error) {
              if (mounted && !_isReady) {
                setState(() {
                  _isReady = true;
                  _errorMessage = '页面加载失败: ${error.description}';
                });
              }
            },
          ),

          // Loading overlay
          if (showLoading)
            Positioned.fill(
              child: Container(
                color: cs.surface,
                child: _buildLoadingIndicator(cs, '加载渲染引擎...'),
              ),
            ),

          // Error overlay
          if (showErrorOverlay)
            Positioned.fill(
              child: Container(
                color: cs.surface,
                child: _buildErrorWidget(cs, _errorMessage!),
              ),
            ),

          // Button row (top right) — only show when ready and no error
          if (!showLoading && !showErrorOverlay)
            Positioned(
              top: 4,
              right: 4,
              child: _buildButtonRow(cs),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Source code view
  // ---------------------------------------------------------------------------

  /// Builds the raw Mermaid source code view (similar to HTML code block).
  Widget _buildSourceCodeView(ColorScheme cs, bool isDark) {
    final bgColor = isDark ? const Color(0xff555555) : const Color(0xffeff1f3);
    final textColor =
        isDark ? const Color(0xfff8f8f2) : const Color(0xff000000);

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
        child: SelectableText(
          widget.mermaidCode,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: textColor,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Button row (top right toolbar)
  // ---------------------------------------------------------------------------

  Widget _buildButtonRow(ColorScheme cs) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Zoom controls (only in render mode) ----
            if (!_showSourceCode) ...[
              _buildActionButton(
                icon: Icons.zoom_out,
                label: '缩小',
                onTap: _zoomOut,
              ),
              _buildActionButton(
                icon: Icons.zoom_in,
                label: '放大',
                onTap: _zoomIn,
              ),
              _buildActionButton(
                icon: Icons.fullscreen,
                label: '全屏',
                onTap: _openFullScreen,
              ),
            ],

            // ---- Source code toggle ----
            _buildActionButton(
              icon: _showSourceCode ? Icons.image : Icons.code,
              label: _showSourceCode ? '查看图表' : '查看源码',
              onTap: _toggleSourceCode,
            ),
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
              if (_showSourceCode) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _buildBorderedContainer({
    required double? height,
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
