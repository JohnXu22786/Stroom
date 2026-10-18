import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/pages/chat/dialogs/mermaid_preview_web_controls.dart';
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
  bool showControlsBeforeWebViewReadyForTesting = false,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _MermaidPreviewDialogContent(
      mermaidCode: mermaidCode,
      showControlsBeforeWebViewReadyForTesting:
          showControlsBeforeWebViewReadyForTesting,
    ),
  );
}

class _MermaidPreviewDialogContent extends StatefulWidget {
  final String mermaidCode;
  final bool showControlsBeforeWebViewReadyForTesting;

  const _MermaidPreviewDialogContent({
    required this.mermaidCode,
    this.showControlsBeforeWebViewReadyForTesting = false,
  });

  @override
  State<_MermaidPreviewDialogContent> createState() =>
      _MermaidPreviewDialogContentState();
}

class _MermaidPreviewDialogContentState
    extends State<_MermaidPreviewDialogContent> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _webNavigationTimedOut = false;
  double _zoomLevel = 1.0;
  bool _canApplyZoomDeltasAfterFit = false;
  bool _checkingZoomReadiness = false;
  bool _zoomReadinessCheckRequested = false;
  bool _flushingPendingZoomDeltas = false;
  final List<double> _pendingZoomDeltas = [];

  /// Bundled mermaid.js source, inlined into the render template so the
  /// diagram renders fully offline on every platform (no CDN request).
  /// Null while the asset is loading, or when the asset is unavailable
  /// (template then falls back to its CDN loader).
  String? _inlineMermaidJs;
  bool _mermaidJsLoading = true;

  /// Fallback timer that settles the preview if [onLoadStop] never fires.
  /// Web shows an error because it does not use the Flutter loading overlay;
  /// native platforms end their loading overlay as before.
  Timer? _readyFallbackTimer;
  Timer? _zoomReadinessRetryTimer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // On web the iframe manages its own loading state: no Flutter
      // overlay, no asset pre-load (the asset template loads
      // mermaid.min.js itself) — the diagram appears when rendered.
      _isLoading = false;
      _mermaidJsLoading = false;
      _armReadyFallback();
    } else if (widget.showControlsBeforeWebViewReadyForTesting) {
      _mermaidJsLoading = false;
      _armReadyFallback();
    } else {
      _loadMermaidAsset();
    }
  }

  Future<void> _loadMermaidAsset() async {
    final js = await MermaidRenderWidget.loadBundledMermaidJs();
    if (!mounted) return;
    setState(() {
      _inlineMermaidJs = js;
      _mermaidJsLoading = false;
    });
    // The WebView is now eligible to mount. Starting the timeout before the
    // bundled asset is available can consume the entire creation deadline
    // while no WebView exists in the widget tree.
    _armReadyFallback();
  }

  @override
  void dispose() {
    _readyFallbackTimer?.cancel();
    _zoomReadinessRetryTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }

  /// Arms a timeout once the WebView is eligible to mount. It reports a
  /// visible error if no controller is created, or settles navigation if a
  /// created WebView never fires [onLoadStop].
  void _armReadyFallback() {
    _readyFallbackTimer?.cancel();
    _readyFallbackTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_webViewController == null) {
        debugPrint('[MermaidPreviewDialog] WebView was not created within 3s');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      } else if (kIsWeb && !_hasError) {
        debugPrint('[MermaidPreviewDialog] web navigation did not settle '
            'within 3s');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _webNavigationTimedOut = true;
        });
      } else if (_isLoading) {
        debugPrint('[MermaidPreviewDialog] onLoadStop did not fire within '
            '3s, force-ending the loading state');
        setState(() => _isLoading = false);
        unawaited(_checkZoomReadiness());
      }
    });
  }

  /// HTML for the initial page load, memoized: [InAppWebView] reads
  /// `initialData` only when the WebView is created, so rebuilding the
  /// multi-megabyte document on every dialog rebuild would be pure waste
  /// (it used to run inside [build] on every setState).
  String? _initialHtml;

  String _buildHtml() {
    final code = widget.mermaidCode.trim();
    if (code.isEmpty) {
      return _emptyPlaceholderHtml;
    }
    // Same shared template as the inline widget, with the bundled
    // mermaid.js inlined (offline rendering, no CDN request).
    return _initialHtml ??= MermaidRenderWidget.buildMermaidHtml(code,
        inlineMermaidJs: _inlineMermaidJs);
  }

  /// Web-only: loads the bundled asset template (same origin) with the
  /// diagram code as a query parameter. The template loads mermaid.min.js
  /// itself from the same asset directory, so no CDN request is made.
  Future<void> _loadCode() async {
    final ctrl = _webViewController;
    if (ctrl == null) return;
    await ctrl.loadUrl(
        urlRequest: URLRequest(
            url: WebUri(
                MermaidRenderWidget.buildWebAssetUrl(widget.mermaidCode))));
  }

  /// Changes the zoom by [delta] at the center of the preview, based on the
  /// JavaScript renderer's live zoom so web auto-fit is preserved.
  Future<void> _zoomIn() async {
    await _zoomAroundCenter(0.1);
  }

  Future<void> _zoomOut() async {
    await _zoomAroundCenter(-0.1);
  }

  Future<void> _zoomAroundCenter(double delta) async {
    final controller = _webViewController;
    final canApplyZoomDeltas =
        controller != null && _canApplyZoomDeltasAfterFit;

    // Keep native state current for other dialog behavior, but let JS apply
    // the button delta to its live zoom. On web the JS callback bridge is
    // unsupported, so the cached Flutter zoom can be stale after auto-fit.
    if (!kIsWeb) {
      final target = (_zoomLevel + delta).clamp(0.1, 10.0);
      // The page's fit can update after its helper exists, so the cached
      // level may still be stale at either boundary. Always let JavaScript
      // apply and clamp the relative delta against its live zoom.
      _zoomLevel = target;
    }

    if (!canApplyZoomDeltas || _flushingPendingZoomDeltas) {
      _pendingZoomDeltas.add(delta);
      if (controller != null && !canApplyZoomDeltas) {
        unawaited(_checkZoomReadiness());
      }
      return;
    }

    await controller.evaluateJavascript(
      source: 'window.applyZoomDeltasAfterFit([$delta])',
    );
  }

  Future<void> _flushPendingZoomDeltas(
    InAppWebViewController controller,
  ) async {
    if (_pendingZoomDeltas.isEmpty || _flushingPendingZoomDeltas) return;

    final deltas = List<double>.of(_pendingZoomDeltas);
    _flushingPendingZoomDeltas = true;
    try {
      await controller.evaluateJavascript(
        source: 'window.applyZoomDeltasAfterFit(${jsonEncode(deltas)})',
      );
      if (controller == _webViewController) {
        _pendingZoomDeltas.removeRange(0, deltas.length);
      }
    } catch (_) {
      if (controller == _webViewController) {
        _canApplyZoomDeltasAfterFit = false;
        _scheduleZoomReadinessRetry();
      }
    } finally {
      _flushingPendingZoomDeltas = false;
      final currentController = _webViewController;
      if (mounted &&
          currentController != null &&
          _canApplyZoomDeltasAfterFit &&
          _pendingZoomDeltas.isNotEmpty) {
        unawaited(_flushPendingZoomDeltas(currentController));
      }
    }
  }

  Future<void> _checkZoomReadiness() async {
    final controller = _webViewController;
    if (controller == null || _hasError) return;
    if (_canApplyZoomDeltasAfterFit) {
      _zoomReadinessRetryTimer?.cancel();
      _zoomReadinessRetryTimer = null;
      return;
    }
    _zoomReadinessRetryTimer?.cancel();
    _zoomReadinessRetryTimer = null;
    if (_checkingZoomReadiness) {
      _zoomReadinessCheckRequested = true;
      return;
    }

    _checkingZoomReadiness = true;
    try {
      final result = await controller.evaluateJavascript(
        source: "typeof window.applyZoomDeltasAfterFit === 'function'",
      );
      if (!mounted ||
          controller != _webViewController ||
          !(result == true || result == 'true')) {
        return;
      }

      _canApplyZoomDeltasAfterFit = true;
      await _flushPendingZoomDeltas(controller);
    } catch (_) {
      // The page may still be loading. Queued deltas schedule another
      // readiness check; later taps can also request an immediate check.
    } finally {
      final shouldRetry = _zoomReadinessCheckRequested;
      _zoomReadinessCheckRequested = false;
      _checkingZoomReadiness = false;
      if (shouldRetry &&
          mounted &&
          !_hasError &&
          !_canApplyZoomDeltasAfterFit &&
          _pendingZoomDeltas.isNotEmpty) {
        unawaited(_checkZoomReadiness());
      } else if (mounted &&
          !_hasError &&
          !_canApplyZoomDeltasAfterFit &&
          _pendingZoomDeltas.isNotEmpty) {
        _scheduleZoomReadinessRetry();
      }
    }
  }

  void _scheduleZoomReadinessRetry() {
    if (!mounted ||
        _hasError ||
        _webViewController == null ||
        _canApplyZoomDeltasAfterFit ||
        _pendingZoomDeltas.isEmpty ||
        (_zoomReadinessRetryTimer?.isActive ?? false)) {
      return;
    }

    _zoomReadinessRetryTimer = Timer(const Duration(milliseconds: 500), () {
      _zoomReadinessRetryTimer = null;
      unawaited(_checkZoomReadiness());
    });
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
    final showControls =
        (!_isLoading || widget.showControlsBeforeWebViewReadyForTesting) &&
            !_hasError;
    final showWebControls = kIsWeb && (showControls || _hasError);
    final showFlutterClose = !showControls && !showWebControls;

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
            // WebView — full screen rendering. On native platforms it is
            // created only after the bundled mermaid.js asset is loaded,
            // so the initial HTML can inline it (offline, no CDN). On web
            // the asset template loads mermaid.min.js itself (same origin),
            // so the WebView can be created immediately.
            if (!_mermaidJsLoading || kIsWeb)
              InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  transparentBackground: true,
                ),
                // On web the initial page is loaded via loadUrl (the
                // bundled asset template, same origin) — a data: URL
                // cannot carry the bundled mermaid.js (Chromium truncates
                // data: URLs at ~1MB) nor reach same-origin assets.
                initialData: kIsWeb
                    ? null
                    : InAppWebViewInitialData(
                        data: _buildHtml(),
                        mimeType: 'text/html',
                        encoding: 'utf8',
                      ),
                onWebViewCreated: (ctrl) {
                  _readyFallbackTimer?.cancel();
                  final hadError = _hasError;
                  _webViewController = ctrl;
                  _canApplyZoomDeltasAfterFit = false;
                  _zoomReadinessRetryTimer?.cancel();
                  _zoomReadinessRetryTimer = null;
                  if (hadError && mounted) {
                    setState(() {
                      _hasError = false;
                      _isLoading = !kIsWeb;
                      _webNavigationTimedOut = false;
                    });
                  }
                  if (_pendingZoomDeltas.isNotEmpty) {
                    unawaited(_checkZoomReadiness());
                  }
                  // Give a created WebView its own navigation deadline,
                  // separate from the deadline for platform creation.
                  _armReadyFallback();
                  // On web the iframe manages its loading state; the fallback
                  // reports an error only if navigation never settles.
                  if (kIsWeb) {
                    _isLoading = false;
                    _loadCode();
                  }
                  // Register the JS→Flutter message bridge. The web platform
                  // of flutter_inappwebview does not implement
                  // addJavaScriptHandler (UnimplementedError); the diagram
                  // still renders with the template's JS gesture fallbacks,
                  // so guard the registration to keep the WebView working.
                  try {
                    ctrl.addJavaScriptHandler(
                      handlerName: 'onMermaidError',
                      callback: (args) {
                        if (mounted) {
                          setState(() {
                            _hasError = true;
                            _webNavigationTimedOut = false;
                          });
                        }
                      },
                    );
                    ctrl.addJavaScriptHandler(
                      handlerName: 'onTransformChanged',
                      callback: (args) {
                        // Mirrors the JS-side zoom level (the dialog does
                        // not track pan; zoom buttons anchor in JS). No
                        // setState: _zoomLevel is not read in build() and
                        // the WebView reflects the transform visually.
                        if (mounted && args.isNotEmpty) {
                          _zoomLevel =
                              double.tryParse(args[0].toString()) ?? 1.0;
                        }
                      },
                    );
                  } catch (e) {
                    debugPrint(
                        '[MermaidPreviewDialog] JS handler bridge unavailable: $e');
                  }
                },
                onLoadStop: (ctrl, url) {
                  _readyFallbackTimer?.cancel();
                  _zoomReadinessRetryTimer?.cancel();
                  _zoomReadinessRetryTimer = null;
                  _canApplyZoomDeltasAfterFit = true;
                  unawaited(_flushPendingZoomDeltas(ctrl));
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      if (kIsWeb && _webNavigationTimedOut) {
                        _hasError = false;
                        _webNavigationTimedOut = false;
                      }
                    });
                  }
                },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame == false) return;
                  _readyFallbackTimer?.cancel();
                  _zoomReadinessRetryTimer?.cancel();
                  _zoomReadinessRetryTimer = null;
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _hasError = true;
                      _webNavigationTimedOut = false;
                    });
                  }
                },
              ),

            // Loading overlay
            if (_isLoading || _mermaidJsLoading)
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

            // Keep a visible exit during loading. After a web navigation
            // error, HTML controls provide the exit above the mounted iframe.
            if (showFlutterClose)
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                right: 8,
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

            // Top bar with title, zoom controls, and close button
            // Web controls render in the document above the iframe, including
            // after a main-frame navigation error.
            if (showWebControls)
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 0,
                right: 0,
                child: SizedBox(
                  key: const ValueKey('mermaid-preview-web-controls'),
                  height: 44,
                  child: buildMermaidPreviewWebControls(
                    onZoomOut: _zoomOut,
                    onZoomIn: _zoomIn,
                    onClose: () => Navigator.pop(context),
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurface,
                    topInset: MediaQuery.of(context).padding.top + 4,
                  ),
                ),
              )
            else if (showControls)
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
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.85),
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
          child:
              Icon(icon, size: 20, color: cs.onSurface, semanticLabel: label),
        ),
      ),
    );
  }
}
