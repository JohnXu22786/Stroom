import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../models/math_expression.dart';
import '../models/math_drawing_state.dart';
import '../widgets/math_canvas.dart';

/// The constant used to multiply parameter slider values for display.
const double _parameterDefaultValue = 1.0;
const double _parameterMinValue = -10.0;
const double _parameterMaxValue = 10.0;

/// 数学绘制页面 — 使用纯 Flutter Canvas 绘制函数图像。
///
/// 使用 [function_tree] 解析数学表达式，[CustomPainter] 负责渲染，
/// 不再依赖 WebView/JSXGraph，支持全平台一致体验。
///
/// 点击回车按钮（而非自动渲染）才执行绘制，避免过度渲染。
class MathDrawingPage extends StatefulWidget {
  /// 初始表达式（可选）
  final String? initialExpression;

  /// 初始是否显示 WebView（保留参数保持兼容，新 Canvas 始终有效）
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
  late final TextEditingController _formulaController;
  late final TabController _tabController;
  final GlobalKey<MathCanvasState> _canvasKey = GlobalKey();

  // State
  ViewMode _currentView = ViewMode.mode2D;
  MathExpression? _currentExpression;

  /// The last expression text that was successfully rendered (plotted).
  /// Used to determine whether the plot button should be enabled.
  String _renderedExpression = '';

  Map<String, double> _parameterValues = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    _formulaController = TextEditingController(
      text: widget.initialExpression ?? '',
    );

    // Initial expression is handled by the MathCanvas widget itself.
    // Sync page state for LaTeX preview and parameter sliders.
    if (widget.initialExpression != null &&
        widget.initialExpression!.isNotEmpty) {
      final expr = MathExpression.fromInput(widget.initialExpression!);
      if (expr.isValid) {
        _currentExpression = expr;
        _renderedExpression = widget.initialExpression!;
        _parameterValues = {};
        for (final param in expr.parameters) {
          _parameterValues[param] = _parameterDefaultValue;
        }
      }
    }
  }

  @override
  void dispose() {
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
    if (!expression.isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(expression.parseError ?? '表达式解析失败'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _currentExpression = expression;
      _renderedExpression = trimmed;
      _parameterValues = {};
      for (final param in expression.parameters) {
        _parameterValues[param] = _parameterDefaultValue;
      }
    });

    _canvasKey.currentState?.setExpression(
      expression.rawExpression,
      _parameterValues.isNotEmpty ? _parameterValues : null,
    );
  }

  void _onPlotPressed() {
    _parseAndPlotExpression(_formulaController.text);
  }

  /// Whether the plot button should be enabled.
  /// Only enabled when the text field content differs from the last rendered
  /// expression, i.e., there are uncommitted changes.
  bool get _canPlot {
    final currentText = _formulaController.text.trim();
    if (currentText.isEmpty) return false;
    return currentText != _renderedExpression;
  }

  void _onParameterChanged(String param, double value) {
    setState(() {
      _parameterValues[param] = value;
    });
    _canvasKey.currentState?.updateParameters(_parameterValues);
  }

  void _onResetView() {
    _canvasKey.currentState?.resetView();
  }

  // ==================================================================
  // Canvas callbacks
  // ==================================================================

  void _onViewportChange(
      double xMin, double yMin, double xMax, double yMax) {
    debugPrint(
      '[MathDrawing] Viewport changed: [$xMin, $yMin, $xMax, $yMax]',
    );
  }

  void _onCanvasReady() {
    debugPrint('[MathDrawing] Canvas is ready');
  }

  void _onCanvasError(String message) {
    debugPrint('[MathDrawing] Canvas error: $message');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
          IconButton(
            icon: const Icon(Icons.center_focus_strong, size: 20),
            tooltip: '重置视图',
            onPressed: _onResetView,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(cs),
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
        _buildFormulaInput(cs),
        if (_currentExpression != null) _buildLatexPreview(cs),
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
                child: MathCanvas(
                  key: _canvasKey,
                  initialExpression: widget.initialExpression,
                  onViewportChange: _onViewportChange,
                  onReady: _onCanvasReady,
                  onError: _onCanvasError,
                ),
              ),
            ),
          ),
        ),
        if (_currentExpression != null &&
            _currentExpression!.parameters.isNotEmpty)
          _buildParameterSliders(cs),
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
                            _renderedExpression = '';
                            _parameterValues = {};
                          });
                          _canvasKey.currentState?.setExpression('', null);
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
                    _renderedExpression = '';
                    _parameterValues = {};
                  });
                  _canvasKey.currentState?.setExpression('', null);
                } else {
                  setState(() {});
                }
              },
              onSubmitted: (_) => _onPlotPressed(),
            ),
          ),
          const SizedBox(width: 8),
          // Plot button: only enabled when text differs from rendered expression
          FilledButton(
            onPressed: _canPlot ? _onPlotPressed : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(40, 40),
            ),
            child: const Icon(Icons.keyboard_return, size: 20),
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
