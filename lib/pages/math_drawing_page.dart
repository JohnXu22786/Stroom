import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../models/math_expression.dart';
import '../models/math_drawing_state.dart';
import '../widgets/math_canvas_webview.dart';

/// The constant used to multiply parameter slider values for display.
const double _parameterDefaultValue = 1.0;
const double _parameterMinValue = -10.0;
const double _parameterMaxValue = 10.0;

/// 数学绘制页面 — 使用 JSXGraph 在 WebView 中绘制函数图像。
///
/// 支持 LaTeX 格式的数学表达式输入，实时渲染函数图像。
/// 提供 2D 绘图功能（3D 功能待推出）。
class MathDrawingPage extends StatefulWidget {
  /// 初始表达式（可选）
  final String? initialExpression;

  /// 初始是否显示 WebView（测试环境中设为 false 以避免 InAppWebView 平台问题）
  final bool initialShowWebView;

  const MathDrawingPage({
    super.key,
    this.initialExpression,
    this.initialShowWebView = true,
  });

  @override
  State<MathDrawingPage> createState() => _MathDrawingPageState();
}

class _MathDrawingPageState extends State<MathDrawingPage>
    with SingleTickerProviderStateMixin {
  // Controller
  late final TextEditingController _formulaController;
  late final TabController _tabController;
  final GlobalKey<MathCanvasWebViewState> _canvasKey = GlobalKey();

  // State
  ViewMode _currentView = ViewMode.mode2D;
  MathExpression? _currentExpression;
  Map<String, double> _parameterValues = {};
  List<Map<String, dynamic>> _coordinatePoints = [];
  bool _showCoordinatePanel = false;

  // Debounce
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    _formulaController = TextEditingController(
      text: widget.initialExpression ?? '',
    );

    // If there's an initial expression, parse it
    if (widget.initialExpression != null &&
        widget.initialExpression!.isNotEmpty) {
      _parseAndPlotExpression(widget.initialExpression!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _formulaController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentView = _tabController.index == 0
            ? ViewMode.mode2D
            : ViewMode.mode3D;
      });
    }
  }

  // ==================================================================
  // Expression handling
  // ==================================================================

  void _parseAndPlotExpression(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    final expression = MathExpression.fromInput(trimmed);
    if (!expression.isValid) return;

    setState(() {
      _currentExpression = expression;
      // Initialize parameters with default values
      _parameterValues = {};
      for (final param in expression.parameters) {
        _parameterValues[param] = _parameterDefaultValue;
      }
    });

    // Send to WebView
    _canvasKey.currentState?.setExpression(
      expression.rawExpression,
      _parameterValues.isNotEmpty ? _parameterValues : null,
    );
  }

  void _onPlotPressed() {
    _parseAndPlotExpression(_formulaController.text);
  }

  void _onParameterChanged(String param, double value) {
    setState(() {
      _parameterValues[param] = value;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _canvasKey.currentState?.updateParameters(_parameterValues);
    });
  }

  void _onResetView() {
    _canvasKey.currentState?.resetView();
  }

  // ==================================================================
  // WebView callbacks
  // ==================================================================

  void _onCoordinateUpdate(List<Map<String, dynamic>> points) {
    if (!mounted) return;
    setState(() {
      _coordinatePoints = points;
    });
  }

  void _onViewportChange(
      double xMin, double yMin, double xMax, double yMax) {
    debugPrint(
      '[MathDrawing] Viewport changed: [$xMin, $yMin, $xMax, $yMax]',
    );
  }

  // ==================================================================
  // Build
  // ==================================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('数学绘制'),
        actions: [
          // Reset view button
          IconButton(
            icon: const Icon(Icons.center_focus_strong, size: 20),
            tooltip: '重置视图',
            onPressed: _onResetView,
          ),
        ],
      ),
      body: Column(
        children: [
          // ----- Tab bar for 2D / 3D switching -----
          _buildTabBar(cs),

          // ----- Main content area -----
          Expanded(
            child: _currentView == ViewMode.mode2D
                ? _build2DContent(cs)
                : _build3DPlaceholder(cs),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // Tab bar
  // ==================================================================

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerLow,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.show_chart, size: 18),
                SizedBox(width: 6),
                Text('2D 绘图'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, size: 18),
                SizedBox(width: 6),
                Text('3D'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // 2D content
  // ==================================================================

  Widget _build2DContent(ColorScheme cs) {
    return Column(
      children: [
        // ----- Formula input row -----
        _buildFormulaInput(cs),

        // ----- LaTeX preview -----
        if (_currentExpression != null) _buildLatexPreview(cs),

        // ----- WebView canvas -----
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: cs.outlineVariant,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MathCanvasWebView(
                  key: _canvasKey,
                  initialExpression: widget.initialExpression ?? '',
                  initialShowWebView: widget.initialShowWebView,
                  onCoordinateUpdate: _onCoordinateUpdate,
                  onViewportChange: _onViewportChange,
                ),
              ),
            ),
          ),
        ),

        // ----- Parameter sliders -----
        if (_currentExpression != null &&
            _currentExpression!.parameters.isNotEmpty)
          _buildParameterSliders(cs),

        // ----- Coordinate panel toggle button -----
        _buildCoordinateToggle(cs),

        // ----- Coordinate data panel -----
        if (_showCoordinatePanel) _buildCoordinatePanel(cs),
      ],
    );
  }

  // ==================================================================
  // Formula input
  // ==================================================================

  Widget _buildFormulaInput(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _formulaController,
              decoration: InputDecoration(
                hintText: '输入数学表达式，如: x^2',
                labelText: '表达式',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
                suffixIcon: _formulaController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _formulaController.clear();
                          setState(() {
                            _currentExpression = null;
                            _parameterValues = {};
                            _coordinatePoints = [];
                          });
                        },
                      )
                    : null,
              ),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: cs.onSurface,
              ),
              onChanged: (value) {
                if (value.trim().isEmpty) {
                  setState(() {
                    _currentExpression = null;
                    _parameterValues = {};
                    _coordinatePoints = [];
                  });
                } else {
                  setState(() {});
                }
              },
              onSubmitted: (_) => _onPlotPressed(),
            ),
          ),
          const SizedBox(width: 8),
          // Plot button
          FilledButton(
            onPressed:
                _formulaController.text.trim().isNotEmpty ? _onPlotPressed : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(40, 40),
            ),
            child: const Icon(Icons.functions, size: 20),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // LaTeX preview
  // ==================================================================

  Widget _buildLatexPreview(ColorScheme cs) {
    if (_currentExpression == null) return const SizedBox.shrink();

    final latex = _currentExpression!.latexDisplay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.functions, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  latex,
                  textStyle: TextStyle(
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  // Parameter sliders
  // ==================================================================

  Widget _buildParameterSliders(ColorScheme cs) {
    final params = _currentExpression!.parameters.toList()..sort();

    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: params.map((param) {
            final value = _parameterValues[param] ?? _parameterDefaultValue;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      param,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: value.toDouble(),
                      min: _parameterMinValue,
                      max: _parameterMaxValue,
                      divisions: 200,
                      label: value.toStringAsFixed(2),
                      onChanged: (v) => _onParameterChanged(param, v),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      value.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==================================================================
  // Coordinate panel toggle
  // ==================================================================

  Widget _buildCoordinateToggle(ColorScheme cs) {
    return InkWell(
      onTap: () {
        setState(() => _showCoordinatePanel = !_showCoordinatePanel);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '坐标数据',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              _coordinatePoints.isNotEmpty
                  ? '${_coordinatePoints.length} 个点'
                  : '暂无数据',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _showCoordinatePanel
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  // Coordinate data panel
  // ==================================================================

  Widget _buildCoordinatePanel(ColorScheme cs) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: _coordinatePoints.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '绘制函数后将在此显示坐标数据',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            'x',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'y',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Coordinate rows (show first 20)
                  ..._coordinatePoints.take(20).map((point) {
                    final x = (point['x'] as num).toDouble();
                    final y = (point['y'] as num).toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              x.toStringAsFixed(3),
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              y.toStringAsFixed(3),
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_coordinatePoints.length > 20)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '... 还有 ${_coordinatePoints.length - 20} 个点',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ==================================================================
  // 3D placeholder
  // ==================================================================

  Widget _build3DPlaceholder(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '3D 绘图功能即将推出',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '敬请期待后续更新',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
