import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// ============================================================================
// View Mode
// ============================================================================

/// View mode for the math graph canvas.
enum ViewMode {
  /// 2D graph only, using JSXGraph
  dim2,

  /// 3D graph only, using Three.js
  dim3,

  /// Split screen: 2D on top, 3D on bottom
  split;

  String get label {
    switch (this) {
      case ViewMode.dim2:
        return '2D';
      case ViewMode.dim3:
        return '3D';
      case ViewMode.split:
        return '2D+3D';
    }
  }
}

// ============================================================================
// Coordinate Point Model
// ============================================================================

/// A single coordinate point from the graph canvas.
class CoordinatePoint {
  final double x;
  final double y;
  final double? z;

  const CoordinatePoint({
    required this.x,
    required this.y,
    this.z,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        if (z != null) 'z': z,
      };

  factory CoordinatePoint.fromJson(Map<String, dynamic> json) {
    return CoordinatePoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: json['z'] != null ? (json['z'] as num).toDouble() : null,
    );
  }
}

// ============================================================================
// MathGraphDrawingPage
// ============================================================================

/// 数学绘图页面 — 采用 Flutter + WebView 混合架构
///
/// Flutter 原生层负责 UI 外壳、公式文本输入框、坐标数据列表及参数调节滑块。
/// WebView 画布层嵌入本地网页，利用 JavaScript 数学库作为核心绘图引擎：
/// - 2D 采用 JSXGraph
/// - 3D 采用 Three.js（可替换为 MathBox.js）
///
/// 通过双向通道实现数据高频同步：
/// - Flutter → WebView: 公式/参数变化实时发送
/// - WebView → Flutter: 坐标数据回传刷新原生界面
class MathGraphDrawingPage extends StatefulWidget {
  /// 初始是否显示 WebView 预览。测试环境中设为 false 以避免
  /// InAppWebView 平台未初始化导致的崩溃。
  final bool initialShowPreview;

  const MathGraphDrawingPage({
    super.key,
    this.initialShowPreview = true,
  });

  // ---------------------------------------------------------------------------
  // Static testable methods
  // ---------------------------------------------------------------------------

  /// 构建 2D 画布 HTML（JSXGraph）
  static String build2dHtml(
    String formula, {
    Map<String, double>? params,
  }) {
    final escapedFormula = _escapeHtml(formula);
    final paramScript = _buildParamScript(params);
    return _dim2HtmlTemplate
        .replaceFirst('FORMULA_PLACEHOLDER', escapedFormula)
        .replaceFirst('PARAM_SCRIPT_PLACEHOLDER', paramScript);
  }

  /// 构建 3D 画布 HTML（Three.js）
  static String build3dHtml(
    String formula, {
    Map<String, double>? params,
  }) {
    final escapedFormula = _escapeHtml(formula);
    final paramScript = _buildParamScript(params);
    return _dim3HtmlTemplate
        .replaceFirst('FORMULA_PLACEHOLDER', escapedFormula)
        .replaceFirst('PARAM_SCRIPT_PLACEHOLDER', paramScript);
  }

  /// 从 WebView JavaScript 回调中提取坐标数据
  static List<CoordinatePoint> extractCoordinatesFromJs(String? jsonData) {
    if (jsonData == null || jsonData.isEmpty) return [];
    try {
      final list = jsonDecode(jsonData) as List<dynamic>;
      return list
          .map((e) => CoordinatePoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll("'", '&#39;')
        .replaceAll('"', '&quot;');
  }

  static String _buildParamScript(Map<String, double>? params) {
    if (params == null || params.isEmpty) return '';
    final entries = params.entries.map((e) => '"${e.key}": ${e.value}');
    return 'var params = { ${entries.join(', ')} };';
  }

  // ---------------------------------------------------------------------------
  // 2D HTML Template (JSXGraph)
  // ---------------------------------------------------------------------------

  static const String _dim2HtmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<script src="https://cdn.jsdelivr.net/npm/jsxgraph/distrib/jsxgraphcore.js">
</script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
  #jxgbox { width: 100%; height: 100%; }
  .error-message {
    color: #e74c3c; padding: 16px; border: 1px solid #e74c3c;
    border-radius: 8px; margin: 16px; background: #fdf0ef;
    font-family: monospace; white-space: pre-wrap;
  }
</style>
</head>
<body>
<div id="jxgbox"></div>
<script>
  PARAM_SCRIPT_PLACEHOLDER

  function getParams() {
    if (typeof params !== 'undefined') return params;
    return { a: 1, b: 0, c: 0, d: 0 };
  }

  function getFormula() {
    var formulaStr = 'FORMULA_PLACEHOLDER';
    if (!formulaStr || formulaStr.trim() === '') return null;
    try {
      var p = getParams();
      var compiled = formulaStr
        .replace(/a/g, '(' + p.a + ')')
        .replace(/b/g, '(' + p.b + ')')
        .replace(/c/g, '(' + p.c + ')')
        .replace(/d/g, '(' + p.d + ')');
      return function(x) { return eval(compiled); };
    } catch(e) { return null; }
  }

  function initBoard() {
    var formula = getFormula();
    var board = JXG.JSXGraph.initBoard('jxgbox', {
      boundingbox: [-10, 10, 10, -10],
      axis: true,
      showCopyright: false,
      showNavigation: false,
      showZoom: false,
      pan: {enabled: true, needTwoFingers: false},
      zoom: {enabled: true, wheelOnly: true}
    });

    if (formula) {
      var graph = board.create('functiongraph', [formula, -10, 10], {
        strokeColor: '#4A90D9',
        strokeWidth: 2
      });
      board.on('update', function() {
        var points = [];
        try {
          for (var x = -10; x <= 10; x += 0.5) {
            var y = formula(x);
            if (isFinite(y)) points.push({x: x, y: y});
          }
        } catch(e) {}
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('mathGraphCoordinates', JSON.stringify(points));
        }
      });
    }
    board.update();
  }

  try { initBoard(); } catch(e) {
    var el = document.getElementById('jxgbox');
    el.innerHTML = '<div class="error-message"></div>';
    el.firstChild.textContent = 'Error: ' + e.message;
  }
</script>
</body>
</html>
''';

  // ---------------------------------------------------------------------------
  // 3D HTML Template (Three.js)
  // ---------------------------------------------------------------------------

  static const String _dim3HtmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js">
</script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
  #container { width: 100%; height: 100%; }
  .error-message {
    color: #e74c3c; padding: 16px; border: 1px solid #e74c3c;
    border-radius: 8px; margin: 16px; background: #fdf0ef;
    font-family: monospace; white-space: pre-wrap;
  }
</style>
</head>
<body>
<div id="container"></div>
<script>
  PARAM_SCRIPT_PLACEHOLDER

  var scene, camera, renderer, controls;
  var mesh;

  function getParams() {
    if (typeof params !== 'undefined') return params;
    return { a: 1, b: 0, c: 0, d: 0 };
  }

  function getSurfaceFunction() {
    var formulaStr = 'FORMULA_PLACEHOLDER';
    if (!formulaStr || formulaStr.trim() === '') return null;
    try {
      var p = getParams();
      var compiled = formulaStr
        .replace(/a/g, '(' + p.a + ')')
        .replace(/b/g, '(' + p.b + ')')
        .replace(/c/g, '(' + p.c + ')')
        .replace(/d/g, '(' + p.d + ')');
      return function(x, y) { return eval(compiled); };
    } catch(e) { return null; }
  }

  function buildSurface() {
    var surfFunc = getSurfaceFunction();
    if (!surfFunc) return;

    var size = 5;
    var segments = 40;
    var geometry = new THREE.BufferGeometry();
    var vertices = [];
    var indices = [];
    var colors = [];

    for (var i = 0; i <= segments; i++) {
      for (var j = 0; j <= segments; j++) {
        var x = -size + (2 * size * i / segments);
        var y = -size + (2 * size * j / segments);
        var z;
        try { z = surfFunc(x, y); } catch(e) { z = 0; }
        if (!isFinite(z)) z = 0;
        vertices.push(x, z, y);
        var t = (z + size) / (2 * size);
        t = Math.max(0, Math.min(1, t));
        colors.push(0.2 + t * 0.6, 0.2 + t * 0.4, 0.8 - t * 0.3);
      }
    }

    for (var i = 0; i < segments; i++) {
      for (var j = 0; j < segments; j++) {
        var a = i * (segments + 1) + j;
        var b = i * (segments + 1) + j + 1;
        var c = (i + 1) * (segments + 1) + j;
        var d = (i + 1) * (segments + 1) + j + 1;
        indices.push(a, b, c);
        indices.push(b, d, c);
      }
    }

    geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geometry.setIndex(indices);
    geometry.computeVertexNormals();

    var material = new THREE.MeshPhongMaterial({
      vertexColors: true,
      side: THREE.DoubleSide,
      shininess: 30,
      transparent: true,
      opacity: 0.9
    });

    if (mesh) scene.remove(mesh);
    mesh = new THREE.Mesh(geometry, material);
    scene.add(mesh);

    // Send sample coordinates
    if (window.flutter_inappwebview) {
      var samplePoints = [];
      for (var i = -4; i <= 4; i += 1) {
        for (var j = -4; j <= 4; j += 1) {
          try {
            var zv = surfFunc(i, j);
            if (isFinite(zv)) samplePoints.push({x: i, y: j, z: zv});
          } catch(e) {}
        }
      }
      window.flutter_inappwebview.callHandler('mathGraphCoordinates', JSON.stringify(samplePoints));
    }
  }

  function initScene() {
    scene = new THREE.Scene();
    scene.background = null;

    camera = new THREE.PerspectiveCamera(45, 1, 0.1, 100);
    camera.position.set(8, 6, 8);
    camera.lookAt(0, 0, 0);

    renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(window.innerWidth, window.innerHeight);
    document.getElementById('container').appendChild(renderer.domElement);

    // Lights
    var ambientLight = new THREE.AmbientLight(0x404040);
    scene.add(ambientLight);
    var dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
    dirLight.position.set(5, 10, 7);
    scene.add(dirLight);
    var dirLight2 = new THREE.DirectionalLight(0xffffff, 0.4);
    dirLight2.position.set(-5, -5, -5);
    scene.add(dirLight2);

    // Axes
    var axesHelper = new THREE.AxesHelper(6);
    scene.add(axesHelper);

    // Grid
    var gridHelper = new THREE.GridHelper(10, 10, 0x888888, 0x444444);
    scene.add(gridHelper);

    // Controls (orbit via mouse drag)
    var isDragging = false;
    var previousMousePosition = { x: 0, y: 0 };

    renderer.domElement.addEventListener('mousedown', function(e) {
      isDragging = true;
      previousMousePosition.x = e.clientX;
      previousMousePosition.y = e.clientY;
    });

    window.addEventListener('mousemove', function(e) {
      if (!isDragging) return;
      var deltaX = e.clientX - previousMousePosition.x;
      var deltaY = e.clientY - previousMousePosition.y;
      spherical.theta -= deltaX * 0.01;
      spherical.phi -= deltaY * 0.01;
      spherical.phi = Math.max(0.1, Math.min(Math.PI - 0.1, spherical.phi));
      previousMousePosition.x = e.clientX;
      previousMousePosition.y = e.clientY;
    });

    window.addEventListener('mouseup', function() { isDragging = false; });
    window.addEventListener('mouseleave', function() { isDragging = false; });

    // Wheel zoom
    renderer.domElement.addEventListener('wheel', function(e) {
      e.preventDefault();
      spherical.radius += e.deltaY * 0.01;
      spherical.radius = Math.max(3, Math.min(30, spherical.radius));
    }, { passive: false });

    // Touch support
    var touchStart = null;
    var touchDist = 0;
    renderer.domElement.addEventListener('touchstart', function(e) {
      if (e.touches.length === 1) {
        touchStart = { x: e.touches[0].clientX, y: e.touches[0].clientY };
      } else if (e.touches.length === 2) {
        var dx = e.touches[0].clientX - e.touches[1].clientX;
        var dy = e.touches[0].clientY - e.touches[1].clientY;
        touchDist = Math.sqrt(dx*dx + dy*dy);
      }
    }, { passive: true });

    renderer.domElement.addEventListener('touchmove', function(e) {
      e.preventDefault();
      if (e.touches.length === 1 && touchStart) {
        var dx = e.touches[0].clientX - touchStart.x;
        var dy = e.touches[0].clientY - touchStart.y;
        spherical.theta -= dx * 0.01;
        spherical.phi -= dy * 0.01;
        spherical.phi = Math.max(0.1, Math.min(Math.PI - 0.1, spherical.phi));
        touchStart = { x: e.touches[0].clientX, y: e.touches[0].clientY };
      } else if (e.touches.length === 2) {
        var dx = e.touches[0].clientX - e.touches[1].clientX;
        var dy = e.touches[0].clientY - e.touches[1].clientY;
        var dist = Math.sqrt(dx*dx + dy*dy);
        spherical.radius += (touchDist - dist) * 0.05;
        spherical.radius = Math.max(3, Math.min(30, spherical.radius));
        touchDist = dist;
      }
    }, { passive: false });

    renderer.domElement.addEventListener('touchend', function() {
      touchStart = null;
    }, { passive: true });

    buildSurface();

    animate();
  }

  function animate() {
    requestAnimationFrame(animate);
    if (camera) {
      camera.position.x = spherical.radius * Math.sin(spherical.phi) * Math.cos(spherical.theta);
      camera.position.y = spherical.radius * Math.cos(spherical.phi);
      camera.position.z = spherical.radius * Math.sin(spherical.phi) * Math.sin(spherical.theta);
      camera.lookAt(0, 0, 0);
    }
    if (renderer && scene) renderer.render(scene, camera);
  }

  var spherical = { theta: Math.PI / 4, phi: Math.PI / 4, radius: 12 };

  try { initScene(); } catch(e) {
    document.getElementById('container').innerHTML =
      '<div class="error-message">Error: ' + e.message + '</div>';
  }
</script>
</body>
</html>
''';

  @override
  State<MathGraphDrawingPage> createState() => _MathGraphDrawingPageState();
}

class _MathGraphDrawingPageState extends State<MathGraphDrawingPage> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final _formulaController = TextEditingController(text: 'x^2');
  ViewMode _viewMode = ViewMode.dim2;

  // Parameters
  double _paramA = 1.0;
  double _paramB = 0.0;
  double _paramC = 0.0;
  double _paramD = 0.0;

  // Coordinate data from canvas
  List<CoordinatePoint> _coordinates = [];

  // WebView state
  InAppWebViewController? _dim2Controller;
  InAppWebViewController? _dim3Controller;
  bool _dim2Loaded = false;
  bool _dim3Loaded = false;

  bool get _showWebView => widget.initialShowPreview;

  // Debounce
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _formulaController.addListener(_onFormulaChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _formulaController.removeListener(_onFormulaChanged);
    _formulaController.dispose();
    _dim2Controller = null;
    _dim3Controller = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Formula / Parameter change handling
  // ---------------------------------------------------------------------------

  void _onFormulaChanged() {
    _scheduleUpdate();
  }

  void _onParamChanged() {
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _sendToWebView();
    });
  }

  void _sendToWebView() {
    final formula = _formulaController.text.trim();
    final params = {'a': _paramA, 'b': _paramB, 'c': _paramC, 'd': _paramD};

    if (_viewMode == ViewMode.dim2 || _viewMode == ViewMode.split) {
      _loadContent(_dim2Controller, () => MathGraphDrawingPage.build2dHtml(
        formula,
        params: params,
      ));
    }
    if (_viewMode == ViewMode.dim3 || _viewMode == ViewMode.split) {
      _loadContent(_dim3Controller, () => MathGraphDrawingPage.build3dHtml(
        formula,
        params: params,
      ));
    }
  }

  void _loadContent(
    InAppWebViewController? controller,
    String Function() buildHtml,
  ) {
    if (controller == null) return;
    final html = buildHtml();
    controller.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf8',
    );
  }

  // ---------------------------------------------------------------------------
  // View mode switching
  // ---------------------------------------------------------------------------

  void _setViewMode(ViewMode mode) {
    setState(() {
      _viewMode = mode;
      // Reset loading flags so indicators show during transition
      _dim2Loaded = false;
      _dim3Loaded = false;
    });
    // Reload content for the new mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendToWebView();
    });
  }

  // ---------------------------------------------------------------------------
  // JavaScript handler for coordinate data from WebView
  // ---------------------------------------------------------------------------

  Future<void> _onCoordinatesReceived(String jsonData) async {
    final coords = MathGraphDrawingPage.extractCoordinatesFromJs(jsonData);
    if (!mounted) return;
    setState(() {
      _coordinates = coords;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('数学绘图'),
        actions: [
          _buildViewModeToggle(cs),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Formula input
          _buildFormulaInput(cs),
          // View mode indicator + canvas
          Expanded(
            child: _buildCanvasArea(cs),
          ),
          // Parameter sliders
          _buildParameterSliders(cs),
          // Coordinate data list
          _buildCoordinateList(cs),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View mode toggle buttons
  // ---------------------------------------------------------------------------

  Widget _buildViewModeToggle(ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToggleButton('2D', ViewMode.dim2, cs),
        const SizedBox(width: 4),
        _buildToggleButton('3D', ViewMode.dim3, cs),
        const SizedBox(width: 4),
        _buildToggleButton('2D+3D', ViewMode.split, cs),
      ],
    );
  }

  Widget _buildToggleButton(String label, ViewMode mode, ColorScheme cs) {
    final isSelected = _viewMode == mode;
    return Material(
      color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _setViewMode(mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formula input
  // ---------------------------------------------------------------------------

  Widget _buildFormulaInput(ColorScheme cs) {
    final is3d = _viewMode == ViewMode.dim3 || _viewMode == ViewMode.split;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _formulaController,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          labelText: is3d ? 'z = f(x, y)' : 'y = f(x)',
          hintText: is3d ? '输入 z = f(x, y)' : '输入函数表达式...',
          prefixIcon: Icon(
            Icons.functions,
            size: 20,
            color: cs.primary,
          ),
          suffixIcon: _formulaController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _formulaController.clear();
                  },
                )
              : null,
          isDense: true,
        ),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        maxLines: 1,
        textInputAction: TextInputAction.done,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Canvas area
  // ---------------------------------------------------------------------------

  Widget _buildCanvasArea(ColorScheme cs) {
    if (!_showWebView) {
      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 48, color: cs.outlineVariant),
              const SizedBox(height: 8),
              Text(
                '画布预览区域',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    switch (_viewMode) {
      case ViewMode.dim2:
        return _buildSingleWebView(dim: 2, cs: cs);
      case ViewMode.dim3:
        return _buildSingleWebView(dim: 3, cs: cs);
      case ViewMode.split:
        return _buildSplitWebView(cs);
    }
  }

  Widget _buildSingleWebView({required int dim, required ColorScheme cs}) {
    final isDim2 = dim == 2;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant, width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  transparentBackground: true,
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                ),
                onWebViewCreated: (ctrl) {
                  if (isDim2) {
                    _dim2Controller = ctrl;
                  } else {
                    _dim3Controller = ctrl;
                  }
                  _setupWebViewHandler(ctrl);
                  _loadInitialContent(ctrl, isDim2);
                },
                onLoadStop: (ctrl, url) {
                  if (mounted) {
                    setState(() {
                      if (isDim2) {
                        _dim2Loaded = true;
                      } else {
                        _dim3Loaded = true;
                      }
                    });
                  }
                },
              ),
              // Loading indicator
              if (!(isDim2 ? _dim2Loaded : _dim3Loaded))
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
      ),
    );
  }

  Widget _buildSplitWebView(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 2D canvas (top half)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant, width: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    InAppWebView(
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        transparentBackground: true,
                        verticalScrollBarEnabled: false,
                        horizontalScrollBarEnabled: false,
                      ),
                      onWebViewCreated: (ctrl) {
                        _dim2Controller = ctrl;
                        _setupWebViewHandler(ctrl);
                        _loadInitialContent(ctrl, true);
                      },
                      onLoadStop: (ctrl, url) {
                        if (mounted) {
                          setState(() => _dim2Loaded = true);
                        }
                      },
                    ),
                    if (!_dim2Loaded)
                      _buildLoadingOverlay(cs),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Divider label
          Row(
            children: [
              Expanded(
                child: Divider(thickness: 0.5, color: cs.outlineVariant),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '3D',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Divider(thickness: 0.5, color: cs.outlineVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 3D canvas (bottom half)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant, width: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    InAppWebView(
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        transparentBackground: true,
                        verticalScrollBarEnabled: false,
                        horizontalScrollBarEnabled: false,
                      ),
                      onWebViewCreated: (ctrl) {
                        _dim3Controller = ctrl;
                        _setupWebViewHandler(ctrl);
                        _loadInitialContent(ctrl, false);
                      },
                      onLoadStop: (ctrl, url) {
                        if (mounted) {
                          setState(() => _dim3Loaded = true);
                        }
                      },
                    ),
                    if (!_dim3Loaded)
                      _buildLoadingOverlay(cs),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(ColorScheme cs) {
    return Positioned.fill(
      child: Container(
        color: cs.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                '加载渲染引擎...',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setupWebViewHandler(InAppWebViewController ctrl) {
    ctrl.addJavaScriptHandler(
      handlerName: 'mathGraphCoordinates',
      callback: (args) {
        if (args.isNotEmpty && args[0] is String) {
          _onCoordinatesReceived(args[0] as String);
        }
      },
    );
  }

  void _loadInitialContent(InAppWebViewController ctrl, bool isDim2) {
    final formula = _formulaController.text.trim();
    final params = {'a': _paramA, 'b': _paramB, 'c': _paramC, 'd': _paramD};

    final html = isDim2
        ? MathGraphDrawingPage.build2dHtml(formula, params: params)
        : MathGraphDrawingPage.build3dHtml(formula, params: params);

    ctrl.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf8',
    );
  }

  // ---------------------------------------------------------------------------
  // Parameter sliders
  // ---------------------------------------------------------------------------

  Widget _buildParameterSliders(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '参数',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          // Compact sliders in a row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSlider('a', _paramA, -5, 5, (v) {
                  setState(() => _paramA = v);
                  _onParamChanged();
                }),
                const SizedBox(width: 8),
                _buildSlider('b', _paramB, -5, 5, (v) {
                  setState(() => _paramB = v);
                  _onParamChanged();
                }),
                const SizedBox(width: 8),
                _buildSlider('c', _paramC, -5, 5, (v) {
                  setState(() => _paramC = v);
                  _onParamChanged();
                }),
                const SizedBox(width: 8),
                _buildSlider('d', _paramD, -5, 5, (v) {
                  setState(() => _paramD = v);
                  _onParamChanged();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
        SizedBox(
          width: 80,
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Coordinate data list
  // ---------------------------------------------------------------------------

  Widget _buildCoordinateList(ColorScheme cs) {
    final displayCoords = _coordinates.length > 20
        ? _coordinates.sublist(0, 20)
        : _coordinates;

    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
            child: Row(
              children: [
                Icon(Icons.table_chart, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '坐标数据 (${_coordinates.length} 点)',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: displayCoords.isEmpty
                ? Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: displayCoords.length,
                    itemBuilder: (context, index) {
                      final coord = displayCoords[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(
                            coord.z != null
                                ? '(${coord.x.toStringAsFixed(1)}, ${coord.y.toStringAsFixed(1)}, ${coord.z!.toStringAsFixed(1)})'
                                : '(${coord.x.toStringAsFixed(1)}, ${coord.y.toStringAsFixed(1)})',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
