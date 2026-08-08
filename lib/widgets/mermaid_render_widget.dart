import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/pages/chat/dialogs/mermaid_preview_dialog.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
import 'code_block_source_widget.dart';

/// A [OneSequenceGestureRecognizer] that immediately accepts any drag gesture
/// on the very first [PointerMoveEvent], before the parent [ScrollView]'s
/// [VerticalDragGestureRecognizer] can accept (which typically requires ~1px
/// of vertical movement for mouse devices).
///
/// This recognizer is used in a [GestureArenaTeam] alongside the
/// [ScaleGestureRecognizer] so that when the [ImmediateMermaidGestureRecognizer]
/// wins Flutter's gesture arena, the [ScaleGestureRecognizer] also accepts,
/// ensuring both horizontal AND vertical drags within the Mermaid diagram area
/// are captured for pan/zoom instead of scrolling the parent chat page.
///
/// When paired with a [ScaleGestureRecognizer] in a [GestureArenaTeam]:
/// - **Taps / clicks** produce no [PointerMoveEvent], so this recognizer never
///   resolves, allowing toolbar buttons and other tap handlers to work normally.
/// - **Drags of any direction** produce a [PointerMoveEvent] immediately on
///   the first movement, at which point this recognizer resolves with
///   [GestureDisposition.accepted], winning the arena before the parent
///   [ScrollView] can detect the drag direction.
/// - **Pinch zoom** also triggers a [PointerMoveEvent] from one of the two
///   pointers, causing the same early acceptance and team win.
class ImmediateMermaidGestureRecognizer extends OneSequenceGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    // OneSequenceGestureRecognizer.addAllowedPointer already calls
    // startTrackingPointer, which registers with the pointer router and
    // adds this recognizer to the gesture arena.
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      // Accept on the very first movement (any direction, any distance),
      // winning the gesture arena before the parent ScrollView's
      // VerticalDragGestureRecognizer can accept (which needs ~1px for mouse).
      resolve(GestureDisposition.accepted);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    // No cleanup needed.
  }

  @override
  void acceptGesture(int pointer) {
    // No action needed — just winning the arena is sufficient.
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
  }

  @override
  String get debugDescription => 'immediate_mermaid_gesture';
}

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
/// HTML template, which is SHARED with the full-screen dialog
/// ([MermaidPreviewDialog]) so zoom anchoring and auto-fit behavior stay
/// identical everywhere. The Flutter side communicates zoom level changes
/// via [InAppWebViewController.evaluateJavascript].
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

  /// If true (default), shows a toolbar in the top-right corner with zoom,
  /// fullscreen, and source-code toggle buttons. Set to false to hide the
  /// toolbar, e.g. when the widget is embedded in [MermaidChartPage] which
  /// provides its own navigation and mode controls.
  final bool showToolbar;

  /// If true, shows zoom in/out buttons at the top-right of the preview
  /// area, independently of [showToolbar]. This allows the chart page to
  /// provide zoom controls without showing the full toolbar (fullscreen,
  /// save, code toggle) which is handled elsewhere in the chart page UI.
  ///
  /// Unlike [showToolbar], zoom controls are visible even during the
  /// loading state (before the WebView is ready), so users can zoom
  /// in/out as soon as the preview area appears.
  ///
  /// Defaults to false for backward compatibility.
  final bool showZoomControls;

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
    this.showToolbar = true,
    this.showZoomControls = false,
    this.testOnlyShowSourceCode,
  });

  /// Builds a complete HTML document with mermaid.js that renders the
  /// given [mermaidCode] as a diagram.
  ///
  /// If [withJsGestures] is true (default), the generated HTML includes
  /// JavaScript handlers for mouse and touch pan/zoom gestures. Set to
  /// false to omit these handlers (e.g., when the parent Flutter widget
  /// handles gestures and communicates via [InAppWebViewController]).
  ///
  /// If [inlineMermaidJs] is provided (the bundled mermaid.min.js asset),
  /// the library is inlined directly into the page so the diagram renders
  /// fully offline, with no CDN request. Otherwise mermaid.js is loaded
  /// dynamically from the CDN (non-blocking, with a visible error on
  /// failure or timeout).
  ///
  /// This is the single source of truth for the Mermaid HTML/JS template.
  /// Both [MermaidRenderWidget] and [MermaidChartPage] use this method.
  static String buildMermaidHtml(String mermaidCode,
      {bool withJsGestures = true, String? inlineMermaidJs}) {
    final escaped = _escapeMermaidCode(mermaidCode);
    final gestureScript = withJsGestures ? _mermaidGestureJs : '';
    return _mermaidHtmlTemplate
        .replaceFirst('GESTURE_SCRIPT_PLACEHOLDER', gestureScript)
        .replaceFirst('MERMAID_CODE_PLACEHOLDER', escaped)
        .replaceFirst(
            'MERMAID_LOADER_PLACEHOLDER', _buildMermaidLoader(inlineMermaidJs));
  }

  /// Builds the JavaScript that loads mermaid.js and initializes the
  /// diagram.
  ///
  /// With [inlineMermaidJs] (the bundled asset) the library is inlined as
  /// a script element, so rendering works fully offline. Without it,
  /// mermaid.js is loaded dynamically from the CDN — dynamic injection
  /// (not a static `<script>` in `<head>`) keeps the document load event
  /// from being blocked by a slow/unreachable CDN, and a failure or
  /// timeout shows a visible error instead of an endless spinner.
  static String _buildMermaidLoader(String? inlineMermaidJs) {
    if (inlineMermaidJs != null && inlineMermaidJs.isNotEmpty) {
      // JSON-encode the library into a JS string literal, and additionally
      // escape every '<' as \u003C so the HTML parser cannot terminate the
      // script tag early (</script) or start an HTML comment (<!--) inside
      // the inlined code.
      final encoded = jsonEncode(inlineMermaidJs).replaceAll('<', r'\u003C');
      return '''
    (function loadMermaid() {
      var hint = document.getElementById('loading-hint');
      var script = document.createElement('script');
      script.textContent = $encoded;
      document.head.appendChild(script);
      try {
        mermaid.initialize({
          theme: 'default',
          securityLevel: 'loose',
          fontFamily: 'sans-serif',
        });
        mermaid.run({
          nodes: [document.getElementById('mermaid-code')],
        }).then(function() {
          if (hint) hint.style.display = 'none';
          window.fitToViewport();
        }).catch(function(err) {
          if (hint) hint.style.display = 'none';
          reportError('Mermaid render error: ' + err.message);
        });
      } catch(e) {
        if (hint) hint.style.display = 'none';
        reportError('Mermaid initialize error: ' + e.message);
      }
    })();
''';
    }
    return '''
    (function loadMermaid() {
      var hint = document.getElementById('loading-hint');
      var mermaidTimer = setTimeout(function() {
        if (hint) hint.style.display = 'none';
        reportError('Mermaid 加载超时：请检查网络连接后重试');
      }, 20000);
      var script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js';
      script.onload = function() {
        clearTimeout(mermaidTimer);
        try {
          mermaid.initialize({
            theme: 'default',
            securityLevel: 'loose',
            fontFamily: 'sans-serif',
          });
          mermaid.run({
            nodes: [document.getElementById('mermaid-code')],
          }).then(function() {
            if (hint) hint.style.display = 'none';
            window.fitToViewport();
          }).catch(function(err) {
            if (hint) hint.style.display = 'none';
            reportError('Mermaid render error: ' + err.message);
          });
        } catch(e) {
          if (hint) hint.style.display = 'none';
          reportError('Mermaid initialize error: ' + e.message);
        }
      };
      script.onerror = function() {
        clearTimeout(mermaidTimer);
        if (hint) hint.style.display = 'none';
        reportError('Mermaid 加载失败：无法访问 cdn.jsdelivr.net');
      };
      document.head.appendChild(script);
    })();
''';
  }

  /// Shared HTML-escaping logic for mermaid code.
  static String _escapeMermaidCode(String code) {
    return code
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Path of the bundled mermaid.js library. Inlined into the render
  /// template so diagrams render fully offline on every platform — no CDN
  /// request is ever made (CDN fallback exists only for asset-loading
  /// failures, which do not happen in normal builds).
  static const bundledMermaidJsAsset = 'assets/vendor/mermaid.min.js';

  /// Web-only: absolute URL of the bundled asset template loaded via
  /// [InAppWebViewController.loadUrl]. Flutter web serves assets under
  /// `/assets/<pubspec path>`, and the template loads mermaid.min.js from
  /// the same directory (same origin, no CDN request).
  static const webAssetTemplateUrl =
      '/assets/assets/vendor/mermaid_render.html';

  /// Load-once cache of the bundled mermaid.js source, shared by every
  /// [MermaidRenderWidget] instance and the preview dialog.
  static String? _cachedInlineMermaidJs;
  static bool _bundledJsResolved = false;

  /// Loads the bundled mermaid.js source (cached after the first load).
  /// Returns null if the asset cannot be loaded — the caller then lets the
  /// template fall back to its CDN loader.
  static Future<String?> loadBundledMermaidJs() async {
    if (_bundledJsResolved) return _cachedInlineMermaidJs;
    _bundledJsResolved = true;
    try {
      _cachedInlineMermaidJs =
          await rootBundle.loadString(bundledMermaidJsAsset);
    } catch (e) {
      debugPrint('[MermaidRenderWidget] Failed to load bundled mermaid.js '
          '($bundledMermaidJsAsset), falling back to CDN: $e');
      _cachedInlineMermaidJs = null;
    }
    return _cachedInlineMermaidJs;
  }

  /// Core HTML/CSS/JS template. [GESTURE_SCRIPT_PLACEHOLDER] is replaced
  /// with [_mermaidGestureJs] or an empty string based on [withJsGestures].
  static const _mermaidHtmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
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
    #loading-hint {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #888;
      font-size: 13px;
      font-family: sans-serif;
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
    <div id="loading-hint">图表加载中...</div>
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

    // Reports the current zoom + pan to Flutter so the Flutter side always
    // mirrors the JS state (used for button anchors and gesture bases).
    function notifyTransform() {
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('onTransformChanged', zoomLevel, panX, panY);
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
        panX = centerX - (centerX - panX) * (zoomLevel / oldZoom);
        panY = centerY - (centerY - panY) * (zoomLevel / oldZoom);
      }
      updateTransform();
      notifyTransform();
    };

    // Sets absolute pan offset and zoom level in a single call. Used by the
    // inline widget, which tracks pan/zoom on the Flutter side and computes
    // the zoom anchor (finger position / preview center) itself.
    window.setPanZoom = function(x, y, level) {
      panX = x;
      panY = y;
      zoomLevel = Math.max(0.1, Math.min(10, level));
      updateTransform();
    };

    // Fits the rendered diagram into the viewport: zooms so that the WHOLE
    // diagram is visible (contain, NOT cover) at the maximum zoom, then
    // centers it. Called automatically once rendering completes.
    window.fitToViewport = function() {
      var viewport = document.getElementById('viewport');
      var container = document.getElementById('diagram-container');
      if (!viewport || !container) return;
      var svg = container.querySelector('svg');
      if (!svg) return;
      var vw = viewport.clientWidth;
      var vh = viewport.clientHeight;
      if (vw <= 0 || vh <= 0) return;
      var sw = 0, sh = 0;
      try {
        var bbox = svg.getBBox();
        sw = bbox.width;
        sh = bbox.height;
      } catch(_) {}
      if (sw <= 0 || sh <= 0) {
        var wAttr = parseFloat(svg.getAttribute('width'));
        var hAttr = parseFloat(svg.getAttribute('height'));
        if (!isNaN(wAttr) && !isNaN(hAttr)) {
          sw = wAttr;
          sh = hAttr;
        }
      }
      if (sw <= 0 || sh <= 0) return;
      // Pin the SVG to its natural content size: mermaid v11 renders the
      // root <svg> as `width="100%"` with only an inline `max-width` style
      // (no width/height attributes), so without explicit pixel dimensions
      // the SVG stretches to the container width while getBBox() still
      // reports the natural size — the fit math below would then
      // double-scale the diagram (shrunk and misplaced).
      svg.setAttribute('width', sw);
      svg.setAttribute('height', sh);
      zoomLevel = Math.max(0.1, Math.min(10, Math.min(vw / sw, vh / sh)));
      panX = (vw - sw * zoomLevel) / 2;
      panY = (vh - sh * zoomLevel) / 2;
      updateTransform();
      notifyTransform();
    };

GESTURE_SCRIPT_PLACEHOLDER

MERMAID_LOADER_PLACEHOLDER
  </script>
</body>
</html>
''';

  /// JavaScript snippet for mouse + touch pan/zoom gesture handlers.
  /// Injected into [_mermaidHtmlTemplate] when [withJsGestures] is true
  /// (used for full-screen dialogs where there is no parent scroll view).
  static const _mermaidGestureJs = '''
    var isDragging = false;
    var dragStartX = 0;
    var dragStartY = 0;
    var panStartX = 0;
    var panStartY = 0;

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
        notifyTransform();
        e.preventDefault();
      }
    });

    document.addEventListener('mouseup', function() {
      isDragging = false;
    });

    // Zoom with Ctrl/Meta + MouseWheel
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
        notifyTransform();
        e.preventDefault();
      } else if (e.touches.length === 2) {
        var dist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
        var scale = dist / lastTouchDist;
        lastTouchDist = dist;
        var midX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
        var midY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
        var rect = document.getElementById('viewport').getBoundingClientRect();
        var centerX = midX - rect.left;
        var centerY = midY - rect.top;
        window.setZoom(zoomLevel * scale, centerX, centerY);
        e.preventDefault();
      }
    }, { passive: false });

    document.addEventListener('touchend', function(e) {
      lastTouchDist = 0;
      if (e.touches.length === 1) {
        touchStartX = e.touches[0].clientX;
        touchStartY = e.touches[0].clientY;
        touchPanStartX = panX;
        touchPanStartY = panY;
      }
    });
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

  /// Bundled mermaid.js source, inlined into the render template so the
  /// diagram renders fully offline (no CDN request). Null while the asset
  /// is loading, or when the asset is unavailable (template then falls
  /// back to its CDN loader).
  String? _inlineMermaidJs;
  bool _mermaidJsLoading = true;

  /// Fallback timer that force-ends the loading state if [onLoadStop] never
  /// fires (e.g. the web platform's iframe load event or its JS bridge is
  /// unavailable). Without it the loading overlay could spin forever while
  /// the WebView actually rendered (or failed to render) underneath.
  Timer? _readyFallbackTimer;

  /// Guard flag to prevent concurrent save operations.
  bool _isSaving = false;

  /// Current zoom level tracked on the Flutter side.
  double _zoomLevel = 1.0;

  /// Pan offset tracked on the Flutter side for mouse/trackpad gesture
  /// handling (desktop). Updated by [_onScaleUpdate] and sent to JS via
  /// [InAppWebViewController.evaluateJavascript].
  double _panX = 0;
  double _panY = 0;

  /// Values captured at the start of a scale gesture, used to compute
  /// cumulative zoom and relative pan deltas.
  double _gestureStartZoom = 1.0;

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
    // Load the bundled mermaid.js (inlined into the page so rendering
    // works offline). The WebView is created only after it is ready.
    // On web the asset template loads mermaid.min.js itself (same
    // origin), so no pre-loading is needed.
    if (!kIsWeb) {
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
  }

  @override
  void didUpdateWidget(MermaidRenderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidCode != widget.mermaidCode) {
      _isReady = false;
      _errorMessage = null;
      _showSourceCode = false;
      _zoomLevel = 1.0;
      _panX = 0;
      _panY = 0;
      _loadMermaidCode();
    }
  }

  @override
  void dispose() {
    _readyFallbackTimer?.cancel();
    _webViewController = null;
    super.dispose();
  }

  /// Arms a fallback timer that force-ends the loading state after 3s if
  /// [onLoadStop] has not fired yet. The loading overlay must never spin
  /// forever: whatever the WebView does (rendered, blank, or errored), the
  /// overlay is removed so the user sees the actual iframe content (which
  /// shows its own loading hint or error message from the HTML template).
  /// On the web platform onLoadStop reliably does NOT fire (the plugin's
  /// web bridge does not deliver it), so this timer is the actual path
  /// that reveals the rendered diagram there.
  void _armReadyFallback() {
    _readyFallbackTimer?.cancel();
    _readyFallbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isReady && _errorMessage == null) {
        debugPrint('[MermaidRenderWidget] onLoadStop did not fire within 3s, '
            'force-ending the loading state');
        setState(() => _isReady = true);
      }
    });
  }

  void _loadMermaidCode() {
    final ctrl = _webViewController;
    if (ctrl == null) return;

    final code = widget.mermaidCode.trim();

    if (kIsWeb) {
      // Web: load the bundled asset template (same origin, no CDN request)
      // with the code as a query parameter. A data: URL cannot be used
      // here — Chromium truncates data: URLs at ~1MB, and the bundled
      // mermaid.min.js cannot be reached from a data: page (opaque origin).
      _armReadyFallback();
      final url = code.isEmpty
          ? MermaidRenderWidget.webAssetTemplateUrl
          : '${MermaidRenderWidget.webAssetTemplateUrl}'
              '?code=${Uri.encodeQueryComponent(code)}';
      ctrl.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      return;
    }

    if (code.isEmpty) {
      ctrl.loadData(
        data: _emptyPlaceholderHtml,
        mimeType: 'text/html',
        encoding: 'utf8',
      );
      return;
    }

    // Inline rendering uses the SAME HTML template as the fullscreen
    // dialog ([buildMermaidHtml], with full mouse + touch gesture JS).
    // On desktop the Flutter gesture wrapper intercepts pointer events, so
    // the JS mouse handlers act as a fallback (e.g. mobile platforms where
    // the platform view receives events directly). Sharing one template
    // keeps zoom anchoring and auto-fit behavior identical everywhere.
    final html = MermaidRenderWidget.buildMermaidHtml(code,
        inlineMermaidJs: _inlineMermaidJs);
    _armReadyFallback();
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

  // ---------------------------------------------------------------------------
  // Gesture handling (mouse/trackpad pan and zoom at the Flutter level)
  // ---------------------------------------------------------------------------

  /// Captures the current zoom level at the start of a scale gesture.
  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartZoom = _zoomLevel;
  }

  /// Handles mouse drag (pan) and touchpad pinch (zoom). The scale gesture
  /// recognizer claims the pointer event in Flutter's gesture arena,
  /// naturally preventing the parent scroll view from responding while
  /// the user interacts with the Mermaid diagram.
  ///
  /// Zoom is anchored at the gesture focal point (finger / cursor) instead
  /// of the top-left corner: the diagram point under the finger stays fixed
  /// while zooming.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    final ctrl = _webViewController;
    if (ctrl == null) return;

    // Pan: accumulate focal point delta for continuous drag
    _panX += details.focalPointDelta.dx;
    _panY += details.focalPointDelta.dy;

    // Zoom: compute new zoom level from cumulative scale factor
    // (details.scale is 1.0 for single-pointer drag, changes for pinch)
    final hasZoom = details.scale != 1.0;
    if (hasZoom) {
      final newZoom = (_gestureStartZoom * details.scale).clamp(0.1, 10.0);
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final localPos = renderBox.globalToLocal(details.focalPoint);
        _applyZoomAnchored(
          newZoom: newZoom,
          centerX: localPos.dx.clamp(0.0, renderBox.size.width),
          centerY: localPos.dy.clamp(0.0, renderBox.size.height),
        );
      } else {
        _zoomLevel = newZoom;
      }
    }

    // Batch pan and zoom in a single evaluateJavascript call to avoid
    // multiple expensive platform channel round-trips per gesture frame
    // and prevent race conditions between separate pan/zoom calls.
    _syncPanZoomToWebView();
  }

  /// Handles mouse wheel zoom with Ctrl/Meta modifier.
  /// Absorbs the scroll event at the Flutter level to prevent the parent
  /// chat scroll view from scrolling while the user zooms the diagram.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    // Check for Ctrl/Meta modifier key
    final ctrlOrMeta = HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.controlLeft ||
          k == LogicalKeyboardKey.controlRight ||
          k == LogicalKeyboardKey.metaLeft ||
          k == LogicalKeyboardKey.metaRight,
    );
    if (!ctrlOrMeta) return;

    // Compute zoom center relative to this widget's render box
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final localPos = renderBox.globalToLocal(event.position);
    final centerX = localPos.dx.clamp(0.0, renderBox.size.width);
    final centerY = localPos.dy.clamp(0.0, renderBox.size.height);

    final delta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
    final newZoom = (_zoomLevel + delta).clamp(0.1, 10.0);
    if (newZoom != _zoomLevel) {
      _zoomLevel = newZoom;
      // Anchor in JS at the cursor position: the JS side owns the pan
      // state here, so no absolute pan is pushed (avoids snap-back).
      _webViewController?.evaluateJavascript(
        source: 'window.setZoom($newZoom, $centerX, $centerY)',
      );
    }
  }

  /// Applies a new zoom level while keeping the viewport point
  /// ([centerX], [centerY]) fixed on screen. Mirrors the anchor math of
  /// the JS `setZoom`: newPan = center - (center - oldPan) * (new / old).
  void _applyZoomAnchored({
    required double newZoom,
    required double centerX,
    required double centerY,
  }) {
    final oldZoom = _zoomLevel;
    _zoomLevel = newZoom;
    if (oldZoom <= 0) return;
    _panX = centerX - (centerX - _panX) * (newZoom / oldZoom);
    _panY = centerY - (centerY - _panY) * (newZoom / oldZoom);
  }

  /// Pushes the Flutter-tracked pan/zoom state to the WebView in a single
  /// evaluateJavascript call.
  void _syncPanZoomToWebView() {
    _webViewController?.evaluateJavascript(
      source: 'window.setPanZoom($_panX, $_panY, $_zoomLevel);',
    );
  }

  /// Wraps the rendered diagram [child] in gesture detectors that provide
  /// pan and zoom for all input types (mouse, touch, trackpad).
  ///
  /// Uses a [Stack] with a transparent overlay [Container] on top of the
  /// WebView to absorb ALL pointer events within the Mermaid diagram area,
  /// even on transparent parts of the SVG where the WebView would otherwise
  /// pass events through to the parent scroll view. This ensures that
  /// interactions anywhere within the diagram area always pan/zoom the
  /// diagram instead of scrolling the chat page.
  ///
  /// This approach is similar to how Markdown table horizontal scrolling
  /// uses [SingleChildScrollView] to create a gesture boundary that
  /// absorbs events without affecting the parent. The overlay approach is
  /// necessary because platform views (InAppWebView / WebView2 on Windows)
  /// can receive touch/pointer events directly from the OS, bypassing
  /// Flutter's hit testing. A transparent overlay on top of the Stack
  /// captures every event at the Flutter level before it reaches the
  /// platform view.
  ///
  /// The overlay uses [RawGestureDetector] with a [GestureArenaTeam]
  /// containing two recognizers:
  ///
  /// 1. [ImmediateMermaidGestureRecognizer] — wins the arena on the very
  ///    first [PointerMoveEvent] in ANY direction, before the parent
  ///    [ScrollView]'s [VerticalDragGestureRecognizer] can determine the
  ///    drag direction (which typically needs ~1px of vertical movement
  ///    for mouse devices, or ~18px for touch devices).
  /// 2. [ScaleGestureRecognizer] — handles pan (single-finger drag) and
  ///    pinch zoom (two-finger pinch), communicating with the WebView via
  ///    [evaluateJavascript].
  ///
  /// Both recognizers are in the same [GestureArenaTeam] so that when the
  /// [ImmediateMermaidGestureRecognizer] wins the arena, the
  /// [ScaleGestureRecognizer] also accepts, capturing the gesture for
  /// the diagram regardless of drag direction.
  ///
  /// This ensures both horizontal AND vertical drags are captured by the
  /// Mermaid diagram area, preventing the parent chat scroll view from
  /// scrolling while the user pans or zooms the diagram.
  ///
  /// Taps (clicks without movement) produce no [PointerMoveEvent], so the
  /// [ImmediateMermaidGestureRecognizer] never resolves, and toolbar button
  /// taps and other click handlers work normally above the overlay.
  ///
  /// The [Listener] on the overlay with [onPointerSignal] handles
  /// Ctrl/MouseWheel zoom on desktop.
  ///
  /// All gestures are communicated to the WebView via [evaluateJavascript]
  /// calls (see [_onScaleUpdate], [_onPointerSignal] and
  /// [_zoomAroundCenter]), so the inline widget owns pan/zoom state and
  /// sends it to the page via `window.setPanZoom`.
  ///
  /// Note: the inline HTML template is the SAME template used by the
  /// full-screen dialog ([MermaidRenderWidget.buildMermaidHtml], with full
  /// mouse + touch gesture JS). On desktop the overlay intercepts pointer
  /// events so the JS mouse handlers stay idle; on mobile platforms where
  /// the platform view receives events directly, the JS handlers act as a
  /// fallback. Zoom anchoring and auto-fit behave identically in both.
  Widget _buildGestureWrapper(Widget child) {
    // On web the WebView is a real iframe that receives pointer events
    // directly; a Flutter gesture overlay would swallow every event and
    // break the template's built-in mouse/touch pan/zoom handlers. The
    // asset template carries those handlers itself, so render the iframe
    // without any Flutter-level gesture interception.
    if (kIsWeb) return child;

    // Shared gesture arena team: when the immediate recognizer wins the arena
    // on first pointer move, the ScaleGestureRecognizer also accepts.
    final team = GestureArenaTeam();

    return ClipRect(
      child: Stack(
        children: [
          // The WebView — positioned below the gesture overlay.
          Positioned.fill(child: child),
          // Gesture overlay: a transparent Container on top that captures
          // ALL pointer events within the Mermaid widget bounds. This
          // prevents transparent SVG areas from passing events through.
          Positioned.fill(
            child: Listener(
              onPointerSignal: _onPointerSignal,
              child: RawGestureDetector(
                gestures: <Type, GestureRecognizerFactory>{
                  // ScaleGestureRecognizer handles pan + pinch zoom.
                  // It enters the gesture arena via the team, so it
                  // automatically accepts when the immediate recognizer wins.
                  ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                      ScaleGestureRecognizer>(
                    () {
                      final recognizer = ScaleGestureRecognizer()..team = team;
                      // Set ScaleGestureRecognizer as the team captain so
                      // that when ImmediateMermaidGestureRecognizer wins the
                      // parent arena via the team, the
                      // ScaleGestureRecognizer's acceptGesture is called
                      // (instead of being rejected). Without a captain, the
                      // team would accept the immediately-resolved recognizer
                      // and reject the ScaleGestureRecognizer, breaking
                      // pan/zoom entirely.
                      team.captain = recognizer;
                      return recognizer;
                    },
                    (instance) {
                      instance.onStart = _onScaleStart;
                      instance.onUpdate = _onScaleUpdate;
                      instance.onEnd = (_) {};
                    },
                  ),
                  // ImmediateMermaidGestureRecognizer: wins the gesture arena
                  // on the very first PointerMoveEvent (any direction).
                  // Defined after ScaleGestureRecognizer so it enters the
                  // arena second, ensuring ScaleGestureRecognizer is in
                  // 'possible' state before the team resolves.
                  ImmediateMermaidGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          ImmediateMermaidGestureRecognizer>(
                    () => ImmediateMermaidGestureRecognizer()..team = team,
                    (instance) {},
                  ),
                },
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _zoomIn() async {
    await _zoomAroundCenter(_zoomLevel + 0.1);
  }

  Future<void> _zoomOut() async {
    await _zoomAroundCenter(_zoomLevel - 0.1);
  }

  /// Zooms to [newZoom] anchored at the CENTER of the preview area, so the
  /// diagram zooms towards the middle instead of the top-left corner.
  ///
  /// The center is computed IN JS (`viewport.clientWidth/2`) so the anchor
  /// is exact in the page's own coordinate space at any display scaling.
  /// The anchor math runs in JS (`window.setZoom` with a center point),
  /// which keeps the JS-owned pan state untouched — Flutter never pushes
  /// its own (possibly stale) pan here.
  Future<void> _zoomAroundCenter(double newZoom) async {
    final ctrl = _webViewController;
    if (ctrl == null) return;
    final target = newZoom.clamp(0.1, 10.0);
    if (target == _zoomLevel) return;
    // Optimistic local update so rapid clicks accumulate; the JS handler
    // round-trip (onTransformChanged) confirms the same value.
    _zoomLevel = target;
    await ctrl.evaluateJavascript(
      source: 'window.setZoom($target, '
          "document.getElementById('viewport').clientWidth / 2, "
          "document.getElementById('viewport').clientHeight / 2)",
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

  // ---------------------------------------------------------------------------
  // Save to text storage
  // ---------------------------------------------------------------------------

  /// Saves the Mermaid source code as a .mmd file using [FolderPickerDialog]
  /// for folder selection and [TextManifest] for persistent storage.
  Future<void> _saveAsMmd() async {
    if (_isSaving) return;
    _isSaving = true;

    final content = widget.mermaidCode.trim();
    if (content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mermaid 代码为空，无法保存')),
        );
      }
      _isSaving = false;
      return;
    }

    final folders = await TextManifest.getAllFolders();
    if (!mounted) {
      _isSaving = false;
      return;
    }

    // Use first line of code as default filename suggestion
    final firstLine = content.split('\n').first.trim();
    final defaultName = firstLine.isNotEmpty ? firstLine : 'mermaid-diagram';

    // Local controller - will be garbage collected after _saveAsMmd completes.
    // Not explicitly disposed because the dialog's dismiss animation still
    // references it after showDialog returns.
    final fileNameController = TextEditingController(text: defaultName);

    final selectedFolder = await FolderPickerDialog.show(
      context,
      availableFolders: folders,
      title: '保存 Mermaid 图表',
      hintText: '选择或创建文件夹保存 .mmd 文件',
      fileNameController: fileNameController,
      fileNameHintText: '输入文件名（自动添加 .mmd 后缀）',
      onCreateFolder: (name) async {
        await TextManifest.addFolder(name);
        return null;
      },
      onRefreshFolders: () async => TextManifest.getAllFolders(),
    );

    final userFileName = fileNameController.text.trim();

    if (selectedFolder == null || !mounted) {
      _isSaving = false;
      return;
    }

    if (userFileName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件名不能为空')),
        );
      }
      _isSaving = false;
      return;
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final hash = computeTextHash(bytes);
      final storageFileName = '$hash.txt';

      // Ensure unique filename in the selected folder
      final records = await TextManifest.loadRecords();
      String finalName = userFileName;
      int counter = 2;
      while (records
          .any((r) => r.name == finalName && r.folder == selectedFolder)) {
        finalName = '$userFileName ($counter)';
        counter++;
      }

      await TextManifest.writeText(storageFileName, content);
      await TextManifest.addRecord(TextRecord(
        name: finalName,
        hash: hash,
        format: 'mmd',
        createdAt: DateTime.now(),
        size: bytes.length,
        folder: selectedFolder,
        textLength: content.length,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已保存到文本储存区: ${selectedFolder.isEmpty ? "根目录" : selectedFolder}/$finalName.mmd',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _isSaving = false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _isSaving = false;
    }
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
    // Same shared template as the fullscreen dialog, with the bundled
    // mermaid.js inlined (offline rendering, no CDN request).
    return MermaidRenderWidget.buildMermaidHtml(code,
        inlineMermaidJs: _inlineMermaidJs);
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
    // Uses CodeBlockSourceView directly (which provides its own border,
    // background, line numbers, and wrap toggle) so we do NOT wrap it
    // in _buildBorderedContainer to avoid double borders.
    if (_showSourceCode) {
      return _buildSourceCodeView(cs, isDark, effectiveHeight);
    }

    // ---- Loading placeholder (deferred WebView creation) ----
    // On native platforms the WebView is created only after the bundled
    // mermaid.js asset is loaded (so the initial HTML can inline it) AND
    // after the first frame. On web the asset template loads the library
    // itself, so only the first-frame deferral applies.
    if (!_shouldCreateWebView || (!kIsWeb && _mermaidJsLoading)) {
      return _buildBorderedContainer(
        height: effectiveHeight,
        cs: cs,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildLoadingIndicator(cs, '正在准备渲染引擎...'),
            ),
            // Zoom controls overlay — visible even during loading when
            // showZoomControls is true.
            if (widget.showZoomControls)
              Positioned(
                top: 4,
                right: 4,
                child: _buildZoomControls(cs),
              ),
          ],
        ),
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
          // The WebView — wrapped in gesture handler for desktop
          // pan/zoom, kept alive once created.
          _buildGestureWrapper(
            InAppWebView(
              key: const Key('mermaid_render_webview'),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
              ),
              // On web the initial page is loaded via loadUrl (the bundled
              // asset template, same origin): a data: URL cannot carry the
              // bundled mermaid.js (Chromium truncates data: URLs at ~1MB)
              // and cannot reach same-origin assets from an opaque origin.
              initialData: kIsWeb
                  ? null
                  : InAppWebViewInitialData(
                      data: _getInitialHtml(),
                      mimeType: 'text/html',
                      encoding: 'utf8',
                    ),
              onWebViewCreated: (ctrl) {
                _webViewController = ctrl;
                // On web there is no initialData; load the asset template
                // right after the controller is created.
                if (kIsWeb) {
                  _loadMermaidCode();
                }
                // The initial page (initialData) loads outside
                // [_loadMermaidCode], so arm the ready fallback here too.
                _armReadyFallback();
                // Register the JS→Flutter message bridge (error reporting
                // and transform sync). flutter_inappwebview's WEB platform
                // does not implement addJavaScriptHandler and throws
                // UnimplementedError, so on web the diagram still renders
                // in the iframe with the template's built-in JS gesture
                // fallbacks — only the two bridges are unavailable. Guard
                // the registration so the WebView keeps working everywhere.
                try {
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
                  ctrl.addJavaScriptHandler(
                    handlerName: 'onTransformChanged',
                    callback: (args) {
                      // Mirrors the JS-side zoom + pan (set by setZoom,
                      // fitToViewport, or the JS gesture fallback handlers)
                      // into Flutter state, so button/wheel anchors and
                      // gesture bases always continue from the current view
                      // instead of jumping back to a stale position.
                      //
                      // No setState: these values are not read in build();
                      // the WebView itself reflects the transform visually.
                      if (!mounted || args.length < 3) return;
                      final zoom = double.tryParse(args[0].toString());
                      final px = double.tryParse(args[1].toString());
                      final py = double.tryParse(args[2].toString());
                      if (zoom == null || px == null || py == null) return;
                      _zoomLevel = zoom;
                      _panX = px;
                      _panY = py;
                    },
                  );
                } catch (e) {
                  debugPrint(
                      '[MermaidRenderWidget] JS handler bridge unavailable: $e');
                }
              },
              onLoadStop: (ctrl, url) {
                if (mounted && !_isReady) {
                  setState(() => _isReady = true);
                }
                _readyFallbackTimer?.cancel();
              },
              onReceivedError: (controller, request, error) {
                _readyFallbackTimer?.cancel();
                if (mounted && !_isReady) {
                  setState(() {
                    _isReady = true;
                    _errorMessage = '页面加载失败: ${error.description}';
                  });
                }
              },
            ),
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

          // Button row (top right) — only show when widget.showToolbar is true
          // and the WebView is ready with no error.
          if (widget.showToolbar && !showLoading && !showErrorOverlay)
            Positioned(
              top: 4,
              right: 4,
              child: _buildButtonRow(cs),
            ),

          // Zoom controls overlay — shown independently of showToolbar.
          // When showToolbar is also true and the widget is ready, the
          // toolbar already includes zoom controls (in render mode), so
          // we skip to avoid duplication.
          if (widget.showZoomControls &&
              (!widget.showToolbar || showLoading || showErrorOverlay))
            Positioned(
              top: 4,
              right: 4,
              child: _buildZoomControls(cs),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Source code view
  // ---------------------------------------------------------------------------

  /// Builds the raw Mermaid source code view using the shared
  /// [CodeBlockSourceView] widget, providing a unified code display
  /// area UI with line numbers and a wrap toggle.
  ///
  /// The [effectiveHeight] is passed through so the source code view
  /// uses the same height as the render mode, ensuring visual consistency.
  ///
  /// Button order follows the shared toolbar convention: block-specific
  /// buttons (wrap) on the left, common buttons on the right in the same
  /// order as the mermaid render toolbar — save before the code/view-chart
  /// toggle — so muscle memory carries over between views.
  Widget _buildSourceCodeView(
      ColorScheme cs, bool isDark, double? effectiveHeight) {
    return CodeBlockSourceView(
      code: widget.mermaidCode,
      height: effectiveHeight,
      actionButtons: [
        _buildSrcSaveButton(),
        _buildSrcCodeActionButton(),
      ],
    );
  }

  /// Builds the "查看图表" action button for the source code view.
  Widget _buildSrcCodeActionButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _toggleSourceCode,
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 16,
          ),
          child: Icon(Icons.image, size: 18, semanticLabel: '查看图表'),
        ),
      ),
    );
  }

  /// Builds the "保存" action button for the source code view.
  Widget _buildSrcSaveButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _saveAsMmd,
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 16,
          ),
          child: Icon(Icons.save, size: 18, semanticLabel: '保存'),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Button row (top right toolbar)
  // ---------------------------------------------------------------------------

  /// Builds the render-mode toolbar.
  ///
  /// Only reachable in render mode ([build] returns the source-code view
  /// before this when [_showSourceCode] is true).
  ///
  /// Button order follows the shared toolbar convention across mermaid
  /// and code-block toolbars: block-specific buttons (zoom) on the left,
  /// common buttons (fullscreen, save, code toggle) on the right in the
  /// same order everywhere — fullscreen → save → code. All buttons are
  /// pure icons (text-free) so the toolbars stay compact and consistent.
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
            // ---- Zoom controls (block-specific, left side) ----
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

            // ---- Common buttons (right-aligned, fixed order) ----
            _buildActionButton(
              icon: Icons.fullscreen,
              label: '全屏',
              onTap: _openFullScreen,
            ),
            _buildActionButton(
              icon: Icons.save,
              label: '保存',
              onTap: _saveAsMmd,
            ),
            _buildActionButton(
              icon: Icons.code,
              label: '查看源码',
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
          child: Icon(icon, size: 18, semanticLabel: label),
        ),
      ),
    );
  }

  /// Builds a compact row of zoom in/out buttons, shown when
  /// [showZoomControls] is true independently of the full toolbar.
  Widget _buildZoomControls(ColorScheme cs) {
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
          ],
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
