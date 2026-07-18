import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/pages/chat/dialogs/mermaid_preview_dialog.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
import 'code_block_source_widget.dart';

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

  /// If true (default), shows a toolbar in the top-right corner with zoom,
  /// fullscreen, and source-code toggle buttons. Set to false to hide the
  /// toolbar, e.g. when the widget is embedded in [MermaidChartPage] which
  /// provides its own navigation and mode controls.
  final bool showToolbar;

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
  /// This is the single source of truth for the Mermaid HTML/JS template.
  /// Both [MermaidRenderWidget] and [MermaidChartPage] use this method.
  static String buildMermaidHtml(String mermaidCode,
      {bool withJsGestures = true}) {
    final escaped = _escapeMermaidCode(mermaidCode);
    final gestureScript = withJsGestures ? _mermaidGestureJs : '';
    return _mermaidHtmlTemplate
        .replaceFirst('GESTURE_SCRIPT_PLACEHOLDER', gestureScript)
        .replaceFirst('MERMAID_CODE_PLACEHOLDER', escaped);
  }

  /// Shared HTML-escaping logic for mermaid code.
  static String _escapeMermaidCode(String code) {
    return code
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Builds an HTML document for inline rendering, including touch-only JS
  /// gesture handlers for mobile support. Mouse/trackpad gestures are
  /// handled at the Flutter level to prevent parent scroll view interference.
  static String _buildInlineMermaidHtml(String mermaidCode) {
    final escaped = _escapeMermaidCode(mermaidCode);
    return _mermaidHtmlTemplate
        .replaceFirst('GESTURE_SCRIPT_PLACEHOLDER', _mermaidTouchGestureJs)
        .replaceFirst('MERMAID_CODE_PLACEHOLDER', escaped);
  }

  /// Core HTML/CSS/JS template. [GESTURE_SCRIPT_PLACEHOLDER] is replaced
  /// with [_mermaidGestureJs] or an empty string based on [withJsGestures].
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

GESTURE_SCRIPT_PLACEHOLDER

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

  /// JavaScript snippet for touch-only pan/zoom gesture handlers.
  /// Used for inline Mermaid rendering where Flutter handles mouse
  /// gestures (to prevent parent scroll view interference) and JS
  /// handles touch gestures for mobile support.
  static const _mermaidTouchGestureJs = '''
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

    // Inline rendering includes touch-only JS gesture handlers (mobile).
    // Mouse/trackpad gestures are handled at the Flutter level for better
    // integration with the parent scroll view gesture arena.
    final html = MermaidRenderWidget._buildInlineMermaidHtml(code);
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
      _zoomLevel = (_gestureStartZoom * details.scale).clamp(0.1, 10.0);
    }

    // Batch pan and zoom in a single evaluateJavascript call to avoid
    // multiple expensive platform channel round-trips per gesture frame
    // and prevent race conditions between separate setPan/setZoom calls.
    final jsBuf = StringBuffer();
    jsBuf.write('window.setPan($_panX, $_panY);');
    if (hasZoom) {
      jsBuf.write('window.setZoom($_zoomLevel);');
    }
    ctrl.evaluateJavascript(source: jsBuf.toString());
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
      _webViewController?.evaluateJavascript(
        source: 'window.setZoom($newZoom, $centerX, $centerY)',
      );
    }
  }

  /// Wraps the rendered diagram [child] in gesture detectors that provide
  /// pan and zoom for all input types (mouse, touch, trackpad).
  ///
  /// Uses [HitTestBehavior.opaque] to absorb all pointer events within the
  /// Mermaid diagram area, preventing the parent chat scroll view from
  /// capturing them. This ensures that interactions within the diagram area
  /// always pan/zoom the diagram instead of scrolling the chat page.
  ///
  /// The [GestureDetector] with [onScaleStart]/[onScaleUpdate] handles:
  /// - Single-finger drag → pan
  /// - Two-finger pinch → zoom (mobile and touchpad)
  /// - The [ScaleGestureRecognizer] natively supports both single and
  ///   multi-touch, so the JS touch gesture handlers in the WebView are
  ///   no longer needed for inline rendering — all gesture logic is
  ///   handled at the Flutter level.
  ///
  /// The [Listener] with [onPointerSignal] handles Ctrl/MouseWheel zoom
  /// on desktop. The opaque hit test also prevents the parent scroll view
  /// from receiving wheel events while the pointer is over the diagram.
  ///
  /// Note: The inline HTML template still includes touch gesture JS for
  /// mobile as a fallback when [HitTestBehavior.opaque] does not fully
  /// absorb all touch sequences on certain platforms.
  Widget _buildGestureWrapper(Widget child) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        // Use opaque hit testing to absorb all pointer events within the
        // diagram area, preventing the parent scroll view from receiving
        // them. This fixes the issue where scrolling the chat page could
        // sometimes be triggered when interacting with the Mermaid diagram.
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
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
    // Inline rendering uses touch-only JS gesture handlers for mobile.
    return MermaidRenderWidget._buildInlineMermaidHtml(code);
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
          // The WebView — wrapped in gesture handler for desktop
          // pan/zoom, kept alive once created.
          _buildGestureWrapper(
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
  /// The "查看图表" toggle button is passed as an action button.
  Widget _buildSourceCodeView(
      ColorScheme cs, bool isDark, double? effectiveHeight) {
    return CodeBlockSourceView(
      code: widget.mermaidCode,
      height: effectiveHeight,
      actionButtons: [
        _buildSrcCodeActionButton(),
        _buildSrcSaveButton(),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 16,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image, size: 18, semanticLabel: '查看图表'),
              const SizedBox(width: 4),
              const Text(
                '查看图表',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 16,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.save, size: 18, semanticLabel: '保存'),
              const SizedBox(width: 4),
              const Text(
                '保存',
                style: TextStyle(fontSize: 12),
              ),
            ],
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

            // ---- Save button ----
            _buildActionButton(
              icon: Icons.save,
              label: '保存',
              onTap: _saveAsMmd,
            ),

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
