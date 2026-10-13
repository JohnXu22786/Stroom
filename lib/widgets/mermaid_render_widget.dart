import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/pages/chat/dialogs/mermaid_preview_dialog.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
import 'code_block_source_widget.dart';

/// A [OneSequenceGestureRecognizer] that accepts a drag after the pointer moves
/// beyond the pointer's gesture slop, before the parent [ScrollView]'s
/// [VerticalDragGestureRecognizer] can take the gesture.
///
/// This recognizer is used in a [GestureArenaTeam] alongside the
/// [ScaleGestureRecognizer] so that when the [ImmediateMermaidGestureRecognizer]
/// wins Flutter's gesture arena, the [ScaleGestureRecognizer] also accepts,
/// ensuring both horizontal AND vertical drags within the Mermaid diagram area
/// are captured for pan/zoom instead of scrolling the parent chat page.
///
/// When paired with a [ScaleGestureRecognizer] in a [GestureArenaTeam]:
/// - **Taps / clicks** remain eligible while movement stays within the
///   pointer's hit slop, allowing the separate tap recognizer to forward the
///   click.
/// - **Drags of any direction** resolve with [GestureDisposition.accepted]
///   after movement exceeds the pointer's gesture slop, winning the arena
///   before the parent [ScrollView] can take an actual drag.
/// - **Pinch zoom** is captured when either pointer moves beyond the same slop.
class ImmediateMermaidGestureRecognizer extends OneSequenceGestureRecognizer {
  final Map<int, Offset> _initialPositions = <int, Offset>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // OneSequenceGestureRecognizer.addAllowedPointer already calls
    // startTrackingPointer, which registers with the pointer router and
    // adds this recognizer to the gesture arena.
    super.addAllowedPointer(event);
    _initialPositions[event.pointer] = event.position;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      final initialPosition = _initialPositions[event.pointer];
      final gestureSlop = computeHitSlop(event.kind, gestureSettings);
      if (initialPosition != null &&
          (event.position - initialPosition).distance > gestureSlop) {
        resolve(GestureDisposition.accepted);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _initialPositions.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _initialPositions.clear();
  }

  @override
  void acceptGesture(int pointer) {
    // No action needed — just winning the arena is sufficient.
  }

  @override
  void rejectGesture(int pointer) {
    _initialPositions.remove(pointer);
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

  /// Test-only: overrides the initial folder lookup used by Save as MMD.
  final Future<Set<String>> Function()? testOnlyGetAllFolders;

  const MermaidRenderWidget({
    super.key,
    required this.mermaidCode,
    this.height,
    this.expand = false,
    this.showToolbar = true,
    this.showZoomControls = false,
    this.testOnlyShowSourceCode,
    this.testOnlyGetAllFolders,
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
  /// Perf: the ~3.5MB library is JSON-encoded into the loader script
  /// exactly once per library instance ([_buildMermaidLoader] caches it),
  /// and the multi-megabyte skeleton (template + gestures + loader) is
  /// built once and reused ([_buildMermaidSkeleton] caches it). Each
  /// render only pays a single pass over the skeleton to splice in the
  /// (small) diagram code.
  ///
  /// This is the single source of truth for the Mermaid HTML/JS template.
  /// Both [MermaidRenderWidget] and [MermaidChartPage] use this method.
  static String buildMermaidHtml(String mermaidCode,
      {bool withJsGestures = true, String? inlineMermaidJs}) {
    final escaped = _escapeMermaidCode(mermaidCode);
    final loader = _buildMermaidLoader(inlineMermaidJs);
    final skeleton = _buildMermaidSkeleton(withJsGestures, loader);
    return skeleton.replaceFirst('MERMAID_CODE_PLACEHOLDER', escaped);
  }

  /// Test-only counter of full inline-loader builds (JSON-encoding of the
  /// inlined library). Pins the caching behavior: repeated renders with
  /// the same library must not re-encode the ~3.5MB source.
  @visibleForTesting
  static int inlineLoaderBuildCount = 0;

  /// The library most recently seen by [_buildMermaidLoader], paired with
  /// its fully built loader script. The bundled mermaid.js never changes
  /// at runtime, so the expensive JSON-encoding + '<'-escaping runs once
  /// instead of on every [buildMermaidHtml] call (which used to run on the
  /// UI thread for every render and every rebuild of every diagram).
  static String? _cachedLoaderLibraryJs;
  static String? _cachedLoaderScriptJs;

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
      if (identical(inlineMermaidJs, _cachedLoaderLibraryJs) &&
          _cachedLoaderScriptJs != null) {
        return _cachedLoaderScriptJs!;
      }
      // JSON-encode the library into a JS string literal, and additionally
      // escape every '<' as \u003C so the HTML parser cannot terminate the
      // script tag early (</script) or start an HTML comment (<!--) inside
      // the inlined code.
      final encoded = jsonEncode(inlineMermaidJs).replaceAll('<', r'\u003C');
      final loader = '''
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
      inlineLoaderBuildCount++;
      _cachedLoaderLibraryJs = inlineMermaidJs;
      _cachedLoaderScriptJs = loader;
      return loader;
    }
    return _cdnLoaderScript;
  }

  /// The last skeleton built by [_buildMermaidSkeleton], keyed by the
  /// loader script it embeds and the gesture flag. Building the skeleton
  /// means replacing the gesture and loader placeholders in the template —
  /// with the inline library the loader IS the ~3.5MB script, so this is
  /// the expensive part of [buildMermaidHtml] and must run once per
  /// combination, not once per render.
  static String? _cachedSkeletonLoaderJs;
  static bool? _cachedSkeletonWithGestures;
  static String? _cachedSkeletonHtml;

  /// Builds the HTML template with the gesture script and the mermaid
  /// loader already spliced in (cached), leaving only the small
  /// [MERMAID_CODE_PLACEHOLDER] to be replaced per render.
  static String _buildMermaidSkeleton(bool withJsGestures, String loader) {
    final cached = _cachedSkeletonHtml;
    if (cached != null &&
        identical(loader, _cachedSkeletonLoaderJs) &&
        withJsGestures == _cachedSkeletonWithGestures) {
      return cached;
    }
    final skeleton = _mermaidHtmlTemplate
        .replaceFirst('GESTURE_SCRIPT_PLACEHOLDER',
            withJsGestures ? _mermaidGestureJs : '')
        .replaceFirst('MERMAID_LOADER_PLACEHOLDER', loader);
    _cachedSkeletonLoaderJs = loader;
    _cachedSkeletonWithGestures = withJsGestures;
    _cachedSkeletonHtml = skeleton;
    return skeleton;
  }

  /// CDN loader script (constant): the same string instance every time, so
  /// [_buildMermaidSkeleton] can cache the CDN skeleton keyed by identity.
  static const _cdnLoaderScript = '''
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

  /// Web-only: builds the full template URL for [code]. The ?v= query
  /// forces a fresh template fetch (a stale browser/iframe cache of the
  /// old template would otherwise keep failing after an app update), and
  /// the code travels as its own &code= parameter — both must share one
  /// query string, or URLSearchParams cannot find the code and the
  /// template renders the empty-code placeholder.
  ///
  /// Bump ?v= whenever assets/vendor/mermaid_render.html changes (and keep
  /// the template's TEMPLATE_VERSION in sync: it keys the decompressed
  /// library's CacheStorage entry, so a stale version would serve the
  /// previous library forever).
  static String buildWebAssetUrl(String code) {
    final base = '$webAssetTemplateUrl?v=9';
    final trimmed = code.trim();
    return trimmed.isEmpty
        ? base
        : '$base&code=${Uri.encodeQueryComponent(trimmed)}';
  }

  /// Load-once cache of the bundled mermaid.js source, shared by every
  /// [MermaidRenderWidget] instance and the preview dialog.
  static Future<String?>? _bundledMermaidJsLoad;

  /// Loads the bundled mermaid.js source once, sharing an in-flight load.
  /// Returns null if the asset cannot be loaded — the caller then lets the
  /// template fall back to its CDN loader.
  static Future<String?> loadBundledMermaidJs() {
    return _bundledMermaidJsLoad ??= _loadBundledMermaidJs();
  }

  static Future<String?> _loadBundledMermaidJs() async {
    try {
      return await rootBundle.loadString(bundledMermaidJsAsset);
    } catch (e) {
      debugPrint(
        '[MermaidRenderWidget] Failed to load bundled mermaid.js '
        '($bundledMermaidJsAsset), falling back to CDN: $e',
      );
      return null;
    }
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
    var fitComplete = false;
    var pendingZoomOperations = [];
    var activeNativeGestureId = null;
    var nativeGestureZoomLevel = 1;

    function updateTransform() {
      var container = document.getElementById('diagram-container');
      container.style.transform =
        'translate(' + panX + 'px, ' + panY + 'px) scale(' + zoomLevel + ')';
    }

    function reportError(msg) {
      var viewport = document.getElementById('viewport');
      var errorMessage = document.createElement('div');
      errorMessage.className = 'error-message';
      errorMessage.textContent = msg;
      viewport.textContent = '';
      viewport.appendChild(errorMessage);
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
      activeNativeGestureId = null;
      nativeGestureZoomLevel = zoomLevel;
      updateTransform();
      notifyTransform();
    };

    // Sets absolute pan offset and zoom level in a single call for callers
    // that track the complete transform outside this page.
    window.setPanZoom = function(x, y, level) {
      panX = x;
      panY = y;
      zoomLevel = Math.max(0.1, Math.min(10, level));
      activeNativeGestureId = null;
      nativeGestureZoomLevel = zoomLevel;
      updateTransform();
    };

    // Applies a pan/pinch transform from the native Flutter gesture layer.
    // Before the first fit, retain it as a relative transform so the fit can
    // establish its base zoom and center before replaying the gesture.
    window.applyGestureTransformAfterFit = function(gestureId, scale, panDeltaX, panDeltaY, centerX, centerY) {
      if (!fitComplete) {
        pendingZoomOperations.push({
          kind: 'gesture',
          gestureId: gestureId,
          scale: scale,
          panDeltaX: panDeltaX,
          panDeltaY: panDeltaY,
          centerX: centerX,
          centerY: centerY
        });
        return;
      }
      if (activeNativeGestureId !== gestureId) {
        activeNativeGestureId = gestureId;
        nativeGestureZoomLevel = zoomLevel;
      }
      panX += panDeltaX;
      panY += panDeltaY;
      var oldZoom = zoomLevel;
      nativeGestureZoomLevel *= scale;
      zoomLevel = Math.max(0.1, Math.min(10, nativeGestureZoomLevel));
      var appliedScale = oldZoom > 0 ? zoomLevel / oldZoom : 1;
      if (centerX !== null && centerY !== null) {
        panX = centerX - (centerX - panX) * appliedScale;
        panY = centerY - (centerY - panY) * appliedScale;
      }
      updateTransform();
      notifyTransform();
    };

    window.applyZoomDeltasAfterFit = function(deltas) {
      if (!Array.isArray(deltas)) return;
      if (!fitComplete) {
        for (var i = 0; i < deltas.length; i++) {
          pendingZoomOperations.push({delta: deltas[i], anchored: false});
        }
        return;
      }
      var viewport = document.getElementById('viewport');
      for (var i = 0; i < deltas.length; i++) {
        window.setZoom(
          zoomLevel + deltas[i],
          viewport.clientWidth / 2,
          viewport.clientHeight / 2
        );
      }
    };

    window.applyWheelZoomAfterFit = function(delta, centerX, centerY) {
      if (!fitComplete) {
        pendingZoomOperations.push({
          delta: delta,
          anchored: true,
          centerX: centerX,
          centerY: centerY
        });
        return;
      }
      window.setZoom(zoomLevel + delta, centerX, centerY);
    };

    window.applyZoomOperationsAfterFit = function(operations) {
      if (!Array.isArray(operations)) return;
      for (var i = 0; i < operations.length; i++) {
        var operation = operations[i];
        if (!operation || typeof operation.delta !== 'number') continue;
        if (operation.kind === 'wheel') {
          window.applyWheelZoomAfterFit(
            operation.delta,
            operation.centerX,
            operation.centerY
          );
        } else if (operation.kind === 'toolbar') {
          window.applyZoomDeltasAfterFit([operation.delta]);
        }
      }
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
      if (vw <= 0 || vh <= 0) {
        // The WebView can finish rendering before it receives its initial
        // layout. Retry once its viewport has a non-zero size instead of
        // leaving the diagram at the default transform.
        window.addEventListener('resize', function onFitRetry() {
          if (viewport.clientWidth > 0 && viewport.clientHeight > 0) {
            window.removeEventListener('resize', onFitRetry);
            window.fitToViewport();
          }
        });
        return;
      }
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
      activeNativeGestureId = null;
      nativeGestureZoomLevel = zoomLevel;
      updateTransform();
      notifyTransform();
      fitComplete = true;
      var zoomOperations = pendingZoomOperations;
      pendingZoomOperations = [];
      for (var zoomIndex = 0; zoomIndex < zoomOperations.length; zoomIndex++) {
        var zoomOperation = zoomOperations[zoomIndex];
        if (zoomOperation.kind === 'gesture') {
          window.applyGestureTransformAfterFit(
            zoomOperation.gestureId,
            zoomOperation.scale,
            zoomOperation.panDeltaX,
            zoomOperation.panDeltaY,
            zoomOperation.centerX,
            zoomOperation.centerY
          );
        } else if (zoomOperation.anchored) {
          window.setZoom(
            zoomLevel + zoomOperation.delta,
            zoomOperation.centerX,
            zoomOperation.centerY
          );
        } else {
          window.setZoom(
            zoomLevel + zoomOperation.delta,
            vw / 2,
            vh / 2
          );
        }
      }
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
    var hasDragged = false;
    var suppressClickAfterPan = false;
    var suppressClickTimer = null;

    // Drag-to-pan with mouse
    document.addEventListener('mousedown', function(e) {
      if (suppressClickTimer !== null) {
        clearTimeout(suppressClickTimer);
        suppressClickTimer = null;
        suppressClickAfterPan = false;
      }
      if (e.target.closest('#diagram-container')) {
        isDragging = true;
        hasDragged = false;
        dragStartX = e.clientX;
        dragStartY = e.clientY;
        panStartX = panX;
        panStartY = panY;
        e.preventDefault();
      }
    });

    document.addEventListener('mousemove', function(e) {
      if (isDragging) {
        if (e.clientX !== dragStartX || e.clientY !== dragStartY) {
          hasDragged = true;
        }
        panX = panStartX + (e.clientX - dragStartX);
        panY = panStartY + (e.clientY - dragStartY);
        updateTransform();
        notifyTransform();
        e.preventDefault();
      }
    });

    document.addEventListener('mouseup', function() {
      if (isDragging && hasDragged) {
        suppressClickAfterPan = true;
        suppressClickTimer = setTimeout(function() {
          suppressClickAfterPan = false;
          suppressClickTimer = null;
        }, 0);
      }
      isDragging = false;
      hasDragged = false;
    });

    document.addEventListener('click', function(e) {
      if (!suppressClickAfterPan || e.detail === 0) return;
      suppressClickAfterPan = false;
      if (suppressClickTimer !== null) {
        clearTimeout(suppressClickTimer);
        suppressClickTimer = null;
      }
      e.preventDefault();
      e.stopPropagation();
    }, true);

    // Zoom with Ctrl/Meta + MouseWheel
    document.addEventListener('wheel', function(e) {
      if ((e.ctrlKey || e.metaKey) && e.deltaY !== 0) {
        e.preventDefault();
        var rect = document.getElementById('viewport').getBoundingClientRect();
        var centerX = e.clientX - rect.left;
        var centerY = e.clientY - rect.top;
        var delta = e.deltaY > 0 ? -0.1 : 0.1;
        window.applyWheelZoomAfterFit(delta, centerX, centerY);
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
  bool _hasLoadedPage = false;
  bool _canApplyZoomCommands = false;
  bool _shouldCreateWebView = false;
  Key _webViewKey = const Key('mermaid_render_webview');
  String? _errorMessage;
  bool _hasWebRetryTimeoutError = false;
  // Tracks ordinary navigations too, so their late main-frame errors are stale.
  String? _webLoadUrl;
  String? _webRetryUrl;
  int _webRetryGeneration = 0;
  int _webSourceUpdateGeneration = 0;
  int _nativeLoadGeneration = 0;
  WebUri? _nativeLoadBaseUrl;

  String _resolveWebUrl(String url) => Uri.base.resolve(url).toString();

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

  /// Total fallback: if the WebView is never created (onWebViewCreated
  /// does not fire, e.g. the platform view failed to mount), the loading
  /// state must still end with a visible error instead of spinning
  /// forever. "Loading forever" is structurally impossible with this.
  Timer? _webViewCreationFallbackTimer;

  /// Delays WebView creation until the page transition animation has
  /// settled (see [initState]). Cancelled on dispose so widget tests do
  /// not fail with a pending timer.
  Timer? _deferredCreationTimer;

  /// Guard flag to prevent concurrent save operations.
  bool _isSaving = false;

  /// Current zoom level tracked on the Flutter side.
  double _zoomLevel = 1.0;

  /// Zoom inputs made before the WebView is ready to accept commands.
  final List<({double delta, double? centerX, double? centerY})>
      _pendingZoomOperations = [];

  /// Pan offset tracked on the Flutter side for mouse/trackpad gesture
  /// handling (desktop). Updated by [_onScaleUpdate] and sent to JS via
  /// [InAppWebViewController.evaluateJavascript].
  double _panX = 0;
  double _panY = 0;

  /// Cumulative scale reported by Flutter at the previous update. Keeping
  /// this separate from zoom lets an active pinch continue across a JS fit
  /// notification that changes [_zoomLevel].
  double _lastGestureScale = 1.0;
  int _nativeGestureId = 0;

  @override
  void initState() {
    super.initState();
    // Test-only: start in source code mode if requested (avoids creating
    // InAppWebView which requires a platform implementation).
    if (widget.testOnlyShowSourceCode == true) {
      _showSourceCode = true;
      return;
    }
    // Defer WebView creation until the page transition animation has
    // settled: creating the platform view mid-transition can leave the
    // iframe with a zero size (the diagram is actually rendered, but the
    // iframe stays invisible until a window resize forces a re-layout).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferredCreationTimer?.cancel();
      _deferredCreationTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && !_shouldCreateWebView) {
          setState(() => _shouldCreateWebView = true);
          _armWebViewCreationFallback();
        }
      });
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
    _armWebViewCreationFallback();
  }

  @override
  void didUpdateWidget(MermaidRenderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidCode != widget.mermaidCode) {
      final isPendingWebRetry = kIsWeb &&
          !_isReady &&
          _webViewController != null &&
          (_readyFallbackTimer?.isActive ?? false);
      final isTimedOutWebRetry = kIsWeb &&
          _hasWebRetryTimeoutError &&
          _webRetryUrl != null &&
          _webViewController != null;
      final shouldRearmWebRetry = isPendingWebRetry || isTimedOutWebRetry;
      // Invalidate the memoized initial HTML: if the WebView is recreated
      // (e.g. the widget was unmounted and mounted again) it reads
      // initialData anew and must see the NEW code. While the WebView
      // stays alive the code change goes through loadData below. (The
      // source-code toggle keeps the WebView mounted — see [build].)
      _initialHtml = null;
      // Ordinary web source updates use the iframe's own loading hint. A
      // retained-view retry instead keeps Flutter's overlay until its
      // navigation completes or the retry fallback resolves it. On native
      // platforms the overlay tracks onLoadStop.
      if (!kIsWeb || shouldRearmWebRetry) {
        _isReady = false;
      }
      _hasLoadedPage = false;
      _errorMessage = null;
      _hasWebRetryTimeoutError = false;
      _showSourceCode = false;
      _zoomLevel = 1.0;
      _pendingZoomOperations.clear();
      _panX = 0;
      _panY = 0;
      if (oldWidget.mermaidCode.trim().isEmpty &&
          widget.mermaidCode.trim().isNotEmpty) {
        // The empty-code placeholder unmounts the WebView. Drop its stale
        // controller and give the remounted platform view a fresh creation
        // deadline, so a failed remount still reaches the error state.
        _webViewController = null;
        _webRetryUrl = null;
        _armWebViewCreationFallback();
      }
      if (shouldRearmWebRetry) {
        _armReadyFallback(showNavigationTimeoutError: true);
      }
      _loadMermaidCode();
    }
  }

  @override
  void dispose() {
    _readyFallbackTimer?.cancel();
    _webViewCreationFallbackTimer?.cancel();
    _deferredCreationTimer?.cancel();
    // Release the multi-megabyte initial HTML with the widget: a chat list
    // with several live diagram widgets must not pin one 3.6MB copy each.
    _initialHtml = null;
    _webViewController = null;
    super.dispose();
  }

  /// Arms the total fallback once the WebView can mount: if the controller
  /// still does not exist after 12s (the platform view failed to mount —
  /// onWebViewCreated never fired), show an error instead of loading forever.
  void _armWebViewCreationFallback() {
    if (!_shouldCreateWebView || (!kIsWeb && _mermaidJsLoading)) return;
    _webViewCreationFallbackTimer?.cancel();
    _webViewCreationFallbackTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _webViewController == null && _errorMessage == null) {
        debugPrint('[MermaidRenderWidget] WebView was not created within '
            '12s, showing an error');
        setState(() => _errorMessage = '图表渲染引擎初始化失败，请重试');
      }
    });
  }

  /// Arms a fallback timer that force-ends the loading state after 3s if
  /// [onLoadStop] has not fired yet. Web retries show an error because a
  /// failed navigation leaves no iframe loading UI to recover the preview.
  void _armReadyFallback({bool showNavigationTimeoutError = false}) {
    _readyFallbackTimer?.cancel();
    _readyFallbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isReady && _errorMessage == null) {
        debugPrint('[MermaidRenderWidget] onLoadStop did not fire within 3s, '
            'ending the loading state');
        setState(() {
          _isReady = true;
          if (showNavigationTimeoutError) {
            _errorMessage = '页面加载超时，请重试';
            _hasWebRetryTimeoutError = true;
          } else {
            _canApplyZoomCommands = true;
            _hasWebRetryTimeoutError = false;
          }
        });
        if (!showNavigationTimeoutError) {
          unawaited(_applyPendingZoomOperations());
        }
      }
    });
  }

  void _loadMermaidCode() {
    _hasLoadedPage = false;
    _canApplyZoomCommands = false;
    final code = widget.mermaidCode.trim();

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        code.isNotEmpty) {
      // Windows WebView2 ignores loadData's baseUrl, so replacing the view
      // gives each source update a distinct controller for callback checks.
      _readyFallbackTimer?.cancel();
      _webViewController = null;
      _webViewKey = UniqueKey();
      _armWebViewCreationFallback();
      return;
    }

    final ctrl = _webViewController;
    if (ctrl == null) return;

    if (kIsWeb) {
      // Web: load the bundled asset template (same origin, no CDN request)
      // with the code as a query parameter. A data: URL cannot be used
      // here — Chromium truncates data: URLs at ~1MB, and the bundled
      // mermaid.min.js cannot be reached from a data: page (opaque origin).
      // The iframe manages its own initial loading state; retained-view
      // retries arm a Flutter fallback separately in [_retry].
      final baseUrl = MermaidRenderWidget.buildWebAssetUrl(code);
      final isTrackedRetry =
          _readyFallbackTimer?.isActive == true || _webRetryUrl != null;
      final url = isTrackedRetry
          ? '$baseUrl&attempt=${++_webRetryGeneration}'
          : _webLoadUrl != null
              ? '$baseUrl&sourceUpdate=${++_webSourceUpdateGeneration}'
              : baseUrl;
      _webLoadUrl = _resolveWebUrl(url);
      if (isTrackedRetry) {
        _webRetryUrl = _webLoadUrl;
      }
      ctrl.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      return;
    }

    // Native loadData completions carry their document's base URL. Give each
    // HTML document a distinct URL so a late completion from an older load can
    // be ignored.
    final nativeLoadBaseUrl = WebUri(
      'https://mermaid.invalid/load/${++_nativeLoadGeneration}/',
    );
    _nativeLoadBaseUrl = nativeLoadBaseUrl;

    if (code.isEmpty) {
      ctrl.loadData(
        data: _emptyPlaceholderHtml,
        mimeType: 'text/html',
        encoding: 'utf8',
        baseUrl: nativeLoadBaseUrl,
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
      baseUrl: nativeLoadBaseUrl,
    );
  }

  void _retry() {
    final webViewWasNeverCreated = _webViewController == null;
    setState(() {
      _errorMessage = null;
      _hasWebRetryTimeoutError = false;
      _isReady = false;
      if (webViewWasNeverCreated) {
        _webViewKey = UniqueKey();
      }
    });
    if (webViewWasNeverCreated) {
      // The WebView was never created; re-arm the creation fallback for
      // the retry attempt and remount its platform view so creation is
      // attempted again. Re-arming also reports another failed mount.
      _armWebViewCreationFallback();
    } else if (kIsWeb) {
      // A web retry reuses the existing view, so it will not receive another
      // onWebViewCreated callback to restore readiness if navigation stalls.
      _armReadyFallback(showNavigationTimeoutError: true);
    }
    _loadMermaidCode();
  }

  // ---------------------------------------------------------------------------
  // Gesture handling (mouse/trackpad pan and zoom at the Flutter level)
  // ---------------------------------------------------------------------------

  /// Resets the cumulative scale baseline at the start of each gesture.
  void _onScaleStart(ScaleStartDetails details) {
    _nativeGestureId++;
    _lastGestureScale = 1.0;
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

    // Flutter reports scale cumulatively from the start of the gesture. Use
    // only the change since the prior update so a fit notification can safely
    // replace the current zoom while the gesture remains active.
    final gestureScale = details.scale / _lastGestureScale;
    _lastGestureScale = details.scale;
    final hasZoom = gestureScale != 1.0;
    double? centerX;
    double? centerY;
    if (hasZoom) {
      final newZoom = (_zoomLevel * gestureScale).clamp(0.1, 10.0);
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final localPos = renderBox.globalToLocal(details.focalPoint);
        centerX = localPos.dx.clamp(0.0, renderBox.size.width);
        centerY = localPos.dy.clamp(0.0, renderBox.size.height);
        _applyZoomAnchored(
          newZoom: newZoom,
          centerX: centerX,
          centerY: centerY,
        );
      } else {
        _zoomLevel = newZoom;
      }
    }

    // Batch pan and zoom in a single evaluateJavascript call to avoid
    // multiple expensive platform channel round-trips per gesture frame
    // and prevent race conditions between separate pan/zoom calls.
    _sendGestureTransformToWebView(
      gestureId: _nativeGestureId,
      scale: gestureScale,
      panDeltaX: details.focalPointDelta.dx,
      panDeltaY: details.focalPointDelta.dy,
      centerX: centerX,
      centerY: centerY,
    );
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

    // Resolve the wheel event here before ancestor Scrollables can claim it.
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      _handleCtrlWheelZoom,
    );
  }

  /// Forwards a tap from the Flutter overlay to the DOM element at
  /// the same WebView viewport position. Mermaid's own SVG click handlers
  /// then process callbacks and links as usual.
  void _onDiagramTap(TapUpDetails details) {
    final controller = _webViewController;
    if (controller == null) return;

    final position = details.localPosition;
    controller.evaluateJavascript(
      source: '''
        (() => {
          const target = document.elementFromPoint(
            ${position.dx},
            ${position.dy}
          );
          if (target) {
            target.dispatchEvent(new MouseEvent('click', {
              bubbles: true,
              cancelable: true,
              view: window,
              clientX: ${position.dx},
              clientY: ${position.dy}
            }));
          }
        })();
      ''',
    );
  }

  void _handleCtrlWheelZoom(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final verticalDelta = event.scrollDelta.dy;
    if (verticalDelta == 0) return;

    // Compute zoom center relative to this widget's render box
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final localPos = renderBox.globalToLocal(event.position);
    final centerX = localPos.dx.clamp(0.0, renderBox.size.width).toDouble();
    final centerY = localPos.dy.clamp(0.0, renderBox.size.height).toDouble();

    final delta = verticalDelta > 0 ? -0.1 : 0.1;
    final ctrl = _webViewController;
    // Keep every wheel step: before fit completes, Flutter cannot know the
    // final fitted zoom at which JavaScript will apply this delta.
    _zoomLevel = (_zoomLevel + delta).clamp(0.1, 10.0).toDouble();
    if (ctrl == null || !_canApplyZoomCommands) {
      _pendingZoomOperations.add((
        delta: delta,
        centerX: centerX,
        centerY: centerY,
      ));
      return;
    }
    // Anchor in JS at the cursor position: JavaScript owns the pan state and
    // queues the relative step if its initial fit has not completed yet.
    ctrl.evaluateJavascript(
      source: 'window.applyWheelZoomAfterFit($delta, $centerX, $centerY);',
    );
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

  /// Sends a relative native pan/pinch update to the WebView in one call.
  void _sendGestureTransformToWebView({
    required int gestureId,
    required double scale,
    required double panDeltaX,
    required double panDeltaY,
    required double? centerX,
    required double? centerY,
  }) {
    _webViewController?.evaluateJavascript(
      source: 'window.applyGestureTransformAfterFit($gestureId, $scale, '
          '$panDeltaX, $panDeltaY, $centerX, $centerY);',
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
  /// containing two recognizers, plus a separate [TapGestureRecognizer]:
  ///
  /// 1. [ImmediateMermaidGestureRecognizer] — wins the arena after movement
  ///    exceeds gesture slop in ANY direction, while allowing smaller
  ///    movements to remain taps.
  /// 2. [ScaleGestureRecognizer] — handles pan (single-finger drag) and
  ///    pinch zoom (two-finger pinch), communicating with the WebView via
  ///    [evaluateJavascript].
  ///
  /// The scale and immediate recognizers share a [GestureArenaTeam] so that when the
  /// [ImmediateMermaidGestureRecognizer] wins the arena, the
  /// [ScaleGestureRecognizer] also accepts, capturing the gesture for
  /// the diagram regardless of drag direction.
  ///
  /// This ensures both horizontal AND vertical drags are captured by the
  /// Mermaid diagram area, preventing the parent chat scroll view from
  /// scrolling while the user pans or zooms the diagram.
  ///
  /// Taps within gesture slop are recognized separately and forwarded to the
  /// WebView as a click on the DOM element at the tap position. The tap
  /// recognizer stays outside the pan/zoom team so a tap does not start a
  /// scale gesture. Moving beyond tap slop rejects it, leaving the immediate
  /// recognizer to claim the gesture for pan/zoom. Flutter toolbar controls
  /// are above this overlay and keep their normal tap behavior.
  ///
  /// The [Listener] on the overlay with [onPointerSignal] handles
  /// Ctrl/MouseWheel zoom on desktop.
  ///
  /// All gestures are communicated to the WebView via [evaluateJavascript]
  /// calls (see [_onDiagramTap], [_onScaleUpdate], [_onPointerSignal] and
  /// [_zoomAroundCenter]), so the inline widget owns pan/zoom state and
  /// sends native gesture transforms to the page after its first fit.
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

    // Shared gesture arena team: when the recognizer wins after pointer
    // movement exceeds gesture slop, the ScaleGestureRecognizer also accepts.
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
                  // Forward stationary taps to Mermaid's existing DOM click
                  // handlers. This recognizer is deliberately not on [team]:
                  // a tap must not accept the scale team's pan recognizer.
                  TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                      TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (instance) => instance.onTapUp = _onDiagramTap,
                  ),
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
                  // after movement exceeds gesture slop (any direction).
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
    await _zoomAroundCenter(0.1);
  }

  Future<void> _zoomOut() async {
    await _zoomAroundCenter(-0.1);
  }

  /// Changes the zoom by [delta] at the CENTER of the preview area, so the
  /// diagram zooms towards the middle instead of the top-left corner.
  ///
  /// The center is computed IN JS (`viewport.clientWidth/2`) so the anchor
  /// is exact in the page's own coordinate space at any display scaling.
  /// The anchor math runs in JS (`window.setZoom` with a center point),
  /// which keeps the JS-owned pan state untouched — Flutter never pushes
  /// its own (possibly stale) pan here.
  Future<void> _zoomAroundCenter(double delta) async {
    final ctrl = _webViewController;
    if (ctrl == null || !_canApplyZoomCommands) {
      _pendingZoomOperations.add((
        delta: delta,
        centerX: null,
        centerY: null,
      ));
      return;
    }

    // Keep native-side state current for Flutter gesture handling, but let
    // JavaScript apply the toolbar delta to its live zoom. The web platform
    // has no JS handler bridge, so Flutter's cached level may not reflect
    // auto-fit or JS gesture changes.
    if (!kIsWeb) {
      final target = (_zoomLevel + delta).clamp(0.1, 10.0);
      if (target == _zoomLevel) return;
      _zoomLevel = target;
    }

    await ctrl.evaluateJavascript(
      source: 'window.applyZoomDeltasAfterFit(${jsonEncode([delta])})',
    );
  }

  Future<void> _applyPendingZoomOperations() async {
    final ctrl = _webViewController;
    if (ctrl == null || _pendingZoomOperations.isEmpty) return;

    final pendingOperations = List.of(_pendingZoomOperations);
    _pendingZoomOperations.clear();
    final hasWheelZoom = pendingOperations.any(
      (operation) => operation.centerX != null && operation.centerY != null,
    );
    if (!hasWheelZoom) {
      final pendingDeltas =
          pendingOperations.map((operation) => operation.delta).toList();
      await ctrl.evaluateJavascript(
        source: 'window.applyZoomDeltasAfterFit(${jsonEncode(pendingDeltas)})',
      );
      return;
    }

    final operations = pendingOperations.map<Map<String, Object?>>((operation) {
      final centerX = operation.centerX;
      final centerY = operation.centerY;
      if (centerX == null || centerY == null) {
        return {'kind': 'toolbar', 'delta': operation.delta};
      }
      return {
        'kind': 'wheel',
        'delta': operation.delta,
        'centerX': centerX,
        'centerY': centerY,
      };
    }).toList();
    await ctrl.evaluateJavascript(
      source: 'window.applyZoomOperationsAfterFit(${jsonEncode(operations)})',
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

    late final Set<String> folders;
    try {
      folders = await (widget.testOnlyGetAllFolders?.call() ??
          TextManifest.getAllFolders());
    } catch (e) {
      _isSaving = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取文件夹失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
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

  /// HTML for the initial page load, memoized: [InAppWebView] reads
  /// `initialData` only when the WebView is created, and later code
  /// changes go through [loadData] ([_loadMermaidCode]), so rebuilding
  /// the multi-megabyte document on every widget rebuild would be pure
  /// waste (it used to run inside [build] on every setState).
  String? _initialHtml;

  String _getInitialHtml() {
    final code = widget.mermaidCode.trim();
    if (code.isEmpty) {
      return _emptyPlaceholderHtml;
    }
    // Same shared template as the fullscreen dialog, with the bundled
    // mermaid.js inlined (offline rendering, no CDN request).
    return _initialHtml ??= MermaidRenderWidget.buildMermaidHtml(code,
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

    // ---- Source code mode on web ----
    // On web the WebView is an iframe (HtmlElementView) that the engine
    // composites ABOVE the Flutter canvas, so a Flutter overlay cannot
    // reliably cover it. Unmount the iframe as before — re-creation is
    // cheap on web (no platform-view teardown), and the source view
    // renders unconditionally.
    if (_showSourceCode && kIsWeb) {
      return _buildSourceCodeView(cs, isDark, effectiveHeight);
    }

    // ---- Render layer + source-code overlay (stable root) ----
    // The render layer is ALWAYS the Stack's base child, so its element —
    // and with it the InAppWebView platform view on native — keeps the
    // same tree slot across source↔preview toggles. The source code view
    // is drawn ON TOP of the live render layer only while the source is
    // shown; toggling back just removes the overlay and the
    // already-rendered diagram is visible instantly — no blank flash, no
    // loading animation, no platform-view re-creation. This mirrors
    // MermaidChartPage's split mode, which keeps the preview mounted while
    // the code editor is visible.
    //
    // CodeBlockSourceView provides its own border, background, line
    // numbers, and wrap toggle, so the source view needs no extra border
    // container — it sits directly on top of the render layer.
    return Stack(
      children: [
        _buildRenderLayer(cs, effectiveHeight),
        if (_showSourceCode)
          Positioned.fill(
            child: _buildSourceCodeView(cs, isDark, effectiveHeight),
          ),
      ],
    );
  }

  /// Builds the render layer: the deferred-creation loading placeholder
  /// (before the WebView exists), or the WebView with its overlays and
  /// button row. Kept mounted underneath the source code view when
  /// [_showSourceCode] is true (see [build]).
  Widget _buildRenderLayer(ColorScheme cs, double? effectiveHeight) {
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
    final currentWebViewKey = _webViewKey;

    return _buildBorderedContainer(
      height: effectiveHeight,
      cs: cs,
      child: Stack(
        children: [
          // The WebView — wrapped in gesture handler for desktop
          // pan/zoom, kept alive once created.
          _buildGestureWrapper(
            InAppWebView(
              key: currentWebViewKey,
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
                if (currentWebViewKey != _webViewKey) return;
                _webViewController = ctrl;
                if (!kIsWeb) _nativeLoadBaseUrl = null;
                // On web the iframe manages its own loading state (the
                // asset template shows a hint until the diagram renders),
                // so the widget is immediately ready and no fallback timer
                // is armed — the diagram appears the moment it is rendered.
                if (kIsWeb) {
                  if (mounted && !_isReady) {
                    setState(() => _isReady = true);
                  }
                  _loadMermaidCode();
                } else {
                  // The initial page (initialData) loads outside
                  // [_loadMermaidCode], so arm the ready fallback here too.
                  _armReadyFallback();
                }
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
                        setState(() {
                          _errorMessage = msg;
                          _hasWebRetryTimeoutError = false;
                        });
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
                if (!kIsWeb &&
                    (ctrl != _webViewController ||
                        (_nativeLoadBaseUrl != null &&
                            url?.toString() !=
                                _nativeLoadBaseUrl.toString()))) {
                  return;
                }
                if (kIsWeb &&
                    _webRetryUrl != null &&
                    (url == null ||
                        _resolveWebUrl(url.toString()) != _webRetryUrl)) {
                  return;
                }
                _hasLoadedPage = true;
                _canApplyZoomCommands = true;
                if (mounted && (!_isReady || _hasWebRetryTimeoutError)) {
                  setState(() {
                    _isReady = true;
                    if (_hasWebRetryTimeoutError) {
                      _errorMessage = null;
                      _hasWebRetryTimeoutError = false;
                    }
                  });
                }
                _readyFallbackTimer?.cancel();
                unawaited(_applyPendingZoomOperations());
              },
              onReceivedError: (controller, request, error) {
                if (controller != _webViewController) return;
                if (request.isForMainFrame == true &&
                    !kIsWeb &&
                    _nativeLoadBaseUrl != null &&
                    request.url.toString() != _nativeLoadBaseUrl.toString()) {
                  return;
                }
                if (kIsWeb && request.isForMainFrame == true) {
                  final requestUrl = _resolveWebUrl(request.url.toString());
                  if ((_webLoadUrl != null && requestUrl != _webLoadUrl) ||
                      (_webRetryUrl != null && requestUrl != _webRetryUrl)) {
                    return;
                  }
                }
                // WebView creation ends the Flutter loading overlay before
                // the asset URL finishes navigating. Surface main-frame
                // failures even after that, but leave web subresource errors
                // to the iframe's own loading/error UI. Native behavior still
                // only reports load errors while its initial page is pending;
                // the readiness fallback only hides the loading overlay.
                final shouldShowError =
                    kIsWeb ? request.isForMainFrame == true : !_hasLoadedPage;
                if (mounted && shouldShowError) {
                  _readyFallbackTimer?.cancel();
                  setState(() {
                    _isReady = true;
                    _errorMessage = '页面加载失败: ${error.description}';
                    _hasWebRetryTimeoutError = false;
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
  /// area UI with line numbers, copy / save / wrap buttons.
  ///
  /// The [effectiveHeight] is passed through so the source code view
  /// uses the same height as the render mode, ensuring visual consistency.
  ///
  /// The shared code-block toolbar already provides copy and save, so
  /// only the block-specific "查看图表" toggle is passed as an action
  /// button (it sits right of the common buttons).
  Widget _buildSourceCodeView(
      ColorScheme cs, bool isDark, double? effectiveHeight) {
    return CodeBlockSourceView(
      code: widget.mermaidCode,
      language: 'mermaid',
      height: effectiveHeight,
      actionButtons: [
        _buildSrcCodeActionButton(),
      ],
    );
  }

  /// Builds the "查看图表" action button for the source code view.
  Widget _buildSrcCodeActionButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _toggleSourceCode,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.image, size: 20, semanticLabel: '查看图表'),
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
    // The pill just wraps its buttons (no forced minimum size), so a
    // single-button toolbar collapses into a circle with no trailing
    // blank space. Radius 18 = half of the 36px button circle.
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
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
    );
  }

  /// A compact circular icon button (36x36) with a circular ripple via
  /// [CircleBorder].
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, semanticLabel: label),
        ),
      ),
    );
  }

  /// Builds a compact row of zoom in/out buttons, shown when
  /// [showZoomControls] is true independently of the full toolbar.
  Widget _buildZoomControls(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
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
