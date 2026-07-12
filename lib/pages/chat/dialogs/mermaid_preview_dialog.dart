import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

/// Full-screen dialog that renders Mermaid diagram code in a full-size
/// [InAppWebView] with pan and zoom support.
///
/// This dialog uses the same [MermaidRenderWidget.buildMermaidHtml] HTML
/// template to render the diagram, so the pan/zoom JavaScript behavior is
/// identical to the inline widget.
///
/// Configuration:
/// - JavaScript enabled
/// - Transparent background
///
/// The dialog fills the entire screen (inset padding set to zero) and
/// shows a loading indicator while the WebView initializes.
void showMermaidPreviewDialog({
  required BuildContext context,
  required String mermaidCode,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _MermaidPreviewDialogContent(mermaidCode: mermaidCode),
  );
}

class _MermaidPreviewDialogContent extends StatefulWidget {
  final String mermaidCode;

  const _MermaidPreviewDialogContent({required this.mermaidCode});

  @override
  State<_MermaidPreviewDialogContent> createState() =>
      _MermaidPreviewDialogContentState();
}

class _MermaidPreviewDialogContentState
    extends State<_MermaidPreviewDialogContent> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  double _zoomLevel = 1.0;

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  String _buildHtml() {
    final code = widget.mermaidCode.trim();
    if (code.isEmpty) {
      return _emptyPlaceholderHtml;
    }
    return MermaidRenderWidget.buildMermaidHtml(code);
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
<div>No Mermaid code to preview</div>
</body>
</html>''';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showControls = !_isLoading && !_hasError;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!context.mounted) return;
        Navigator.pop(context);
      },
      child: Dialog(
        backgroundColor: cs.surface,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // WebView — full screen rendering
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
              ),
              initialData: InAppWebViewInitialData(
                data: _buildHtml(),
                mimeType: 'text/html',
                encoding: 'utf8',
              ),
              onWebViewCreated: (ctrl) {
                _webViewController = ctrl;
                // Register error handler from JS
                ctrl.addJavaScriptHandler(
                  handlerName: 'onMermaidError',
                  callback: (args) {
                    if (mounted) {
                      setState(() => _hasError = true);
                    }
                  },
                );
                ctrl.addJavaScriptHandler(
                  handlerName: 'onZoomChanged',
                  callback: (args) {
                    if (mounted && args.isNotEmpty) {
                      final level =
                          double.tryParse(args[0].toString()) ?? 1.0;
                      setState(() => _zoomLevel = level);
                    }
                  },
                );
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
                          '加载图表预览...',
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

            // Top bar with title, zoom controls, and close button
            // Only show controls when WebView is ready and no error
            if (showControls)
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    // Zoom controls
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildActionButton(
                              icon: Icons.zoom_out,
                              label: '缩小',
                              onTap: _zoomOut,
                              cs: cs,
                            ),
                            _buildActionButton(
                              icon: Icons.zoom_in,
                              label: '放大',
                              onTap: _zoomIn,
                              cs: cs,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Title label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Mermaid 预览',
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
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.85),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          child: Icon(icon, size: 20, color: cs.onSurface, semanticLabel: label),
        ),
      ),
    );
  }
}
