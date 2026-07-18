import 'package:flutter/material.dart';

import '../models/math_expression.dart';
import '../models/math_drawing_state.dart';
import '../models/formula_entry.dart';
import '../widgets/math_canvas.dart';

/// 数学绘制页面 — 支持多公式、悬浮公式面板。
class MathDrawingPage extends StatefulWidget {
  final String? initialExpression;
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
  final LayerLink _overlayLayerLink = LayerLink();

  ViewMode _currentView = ViewMode.mode2D;
  MathExpression? _currentExpression;
  Map<String, double> _parameterValues = {};
  String _renderedExpression = '';

  /// Extra formulas beyond the first one.
  final List<_ExtraFormula> _extraFormulas = [];
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    _formulaController = TextEditingController(
      text: widget.initialExpression ?? '',
    );

    if (widget.initialExpression != null &&
        widget.initialExpression!.isNotEmpty) {
      final expr = MathExpression.fromInput(widget.initialExpression!);
      if (expr.isValid) {
        _currentExpression = expr;
        _renderedExpression = widget.initialExpression!;
        _parameterValues = {};
        for (final param in expr.parameters) {
          _parameterValues[param] = 1.0;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final f in _extraFormulas) {
      f.controller.dispose();
    }
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _formulaController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentView =
            _tabController.index == 0 ? ViewMode.mode2D : ViewMode.mode3D;
      });
    }
  }

  // ==================================================================
  // Expression / formula handling
  // ==================================================================

  bool get _canPlot {
    final mainText = _formulaController.text.trim();
    if (mainText.isNotEmpty && mainText != _renderedExpression) return true;
    for (final f in _extraFormulas) {
      final text = f.controller.text.trim();
      if (text.isNotEmpty && text != f.committedText) return true;
    }
    return false;
  }

  void _onPlotPressed() {
    // Build all formula entries
    final entries = <FormulaEntry>[];

    // Main formula
    final mainText = _formulaController.text.trim();
    if (mainText.isNotEmpty) {
      final parsed = MathExpression.fromInput(mainText);
      if (!parsed.isValid) {
        _showError(parsed.parseError ?? '表达式错误');
        return;
      }
      entries.add(FormulaEntry(
        rawExpression: mainText,
        parsed: parsed,
        color: formulaPalette[0],
        autoColor: true,
      ));
    }

    // Extra formulas
    for (int i = 0; i < _extraFormulas.length; i++) {
      final text = _extraFormulas[i].controller.text.trim();
      if (text.isEmpty) continue;
      final parsed = MathExpression.fromInput(text);
      if (!parsed.isValid) {
        _showError(parsed.parseError ?? '表达式 ${i + 2} 错误');
        return;
      }
      entries.add(FormulaEntry(
        rawExpression: text,
        parsed: parsed,
        color: _extraFormulas[i].color,
        autoColor: _extraFormulas[i].autoColor,
      ));
    }

    if (entries.isEmpty) return;

    setState(() {
      _renderedExpression = _formulaController.text.trim();
      for (final f in _extraFormulas) {
        f.committedText = f.controller.text.trim();
      }
      _showOverlay = false;
    });

    _canvasKey.currentState?.setFormulas(entries);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _addFormula() {
    final used = _extraFormulas
        .where((f) => f.autoColor)
        .map((f) => f.color)
        .toSet()
      ..add(formulaPalette[0]); // main formula uses first color
    final color = nextFormulaColor(used);

    setState(() {
      _extraFormulas.add(_ExtraFormula(
        controller: TextEditingController(),
        color: color,
        autoColor: true,
      ));
      _showOverlay = true;
    });
  }

  void _removeExtraFormula(int index) {
    setState(() {
      _extraFormulas[index].controller.dispose();
      _extraFormulas.removeAt(index);
      if (_extraFormulas.isEmpty) _showOverlay = false;
    });
  }

  void _onColorChanged(int index, Color newColor) {
    setState(() {
      _extraFormulas[index].color = newColor;
      _extraFormulas[index].autoColor = false;
    });
  }

  void _showColorPicker(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: formulaPalette.map((c) {
            final selected = _extraFormulas[index].color == c;
            return GestureDetector(
              onTap: () {
                _onColorChanged(index, c);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: Colors.black87, width: 3)
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _onParameterChanged(String param, double value) {
    setState(() => _parameterValues[param] = value);
    // TODO: update parameter on canvas for the relevant formula
  }

  void _onResetView() => _canvasKey.currentState?.resetView();

  // ==================================================================
  // Canvas callbacks
  // ==================================================================

  void _onViewportChange(double xMin, double yMin, double xMax, double yMax) {
    debugPrint('[MathDrawing] Viewport: [$xMin, $yMin, $xMax, $yMax]');
  }

  void _onCanvasReady() => debugPrint('[MathDrawing] Canvas ready');

  void _onCanvasError(String msg) {
    debugPrint('[MathDrawing] Canvas error: $msg');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
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
          if (_currentView == ViewMode.mode2D) ...[
            _buildFormulaInput(cs),
            Expanded(child: _buildCanvasArea(cs)),
            if (_currentExpression != null &&
                _currentExpression!.parameters.isNotEmpty)
              _buildParameterSliders(cs),
          ] else
            Expanded(child: _build3DPlaceholder(cs)),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerLow,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.show_chart, size: 18),
            SizedBox(width: 6),
            Text('2D 绘图'),
          ])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.view_in_ar, size: 18),
            SizedBox(width: 6),
            Text('3D'),
          ])),
        ],
      ),
    );
  }

  // ==================================================================
  // Formula input row (original style, 1 line)
  // ==================================================================

  Widget _buildFormulaInput(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Color dot for main formula
          Container(
            width: 20, height: 20,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: formulaPalette[0],
              shape: BoxShape.circle,
            ),
          ),
          // Text field
          Expanded(
            child: TextField(
              controller: _formulaController,
              decoration: InputDecoration(
                hintText: '输入表达式，如: x^2',
                labelText: '公式 1',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: cs.onSurface,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _onPlotPressed(),
            ),
          ),
          const SizedBox(width: 6),
          // Add formula button
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            tooltip: '添加公式',
            onPressed: _addFormula,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          // Plot button (keyboard return)
          FilledButton(
            onPressed: _canPlot ? _onPlotPressed : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(40, 38),
            ),
            child: const Icon(Icons.keyboard_return, size: 20),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // Canvas area with floating overlay
  // ==================================================================

  Widget _buildCanvasArea(ColorScheme cs) {
    return Stack(
      children: [
        // Canvas (fills entire area)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MathCanvas(
                  key: _canvasKey,
                  onViewportChange: _onViewportChange,
                  onReady: _onCanvasReady,
                  onError: _onCanvasError,
                ),
              ),
            ),
          ),
        ),
        // Floating formula overlay (if extra formulas exist)
        if (_showOverlay && _extraFormulas.isNotEmpty)
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              color: cs.surface,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  children: [
                    // Header
                    Row(
                      children: [
                        Text('附加公式',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _showOverlay = false),
                          child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const Divider(height: 8),
                    // Extra formula rows
                    for (int i = 0; i < _extraFormulas.length; i++)
                      _buildExtraFormulaRow(cs, i),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExtraFormulaRow(ColorScheme cs, int index) {
    final f = _extraFormulas[index];
    final hasChanged = f.controller.text.trim().isNotEmpty &&
        f.controller.text.trim() != f.committedText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Color indicator
          GestureDetector(
            onTap: () => _showColorPicker(index),
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: f.color,
                shape: BoxShape.circle,
                border: hasChanged
                    ? Border.all(color: cs.primary, width: 2)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Formula text
          Expanded(
            child: TextField(
              controller: f.controller,
              decoration: InputDecoration(
                hintText: '公式 ${index + 2}',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                filled: true,
                fillColor: f.color.withValues(alpha: 0.06),
              ),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: cs.onSurface,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _onPlotPressed(),
            ),
          ),
          // Remove
          IconButton(
            icon: Icon(Icons.remove_circle_outline, size: 18, color: cs.error),
            onPressed: () => _removeExtraFormula(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
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
            final value = _parameterValues[param] ?? 1.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(
                  width: 24,
                  child: Text(param,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface)),
                ),
                Expanded(
                  child: Slider(
                    value: value.toDouble(),
                    min: -10,
                    max: 10,
                    divisions: 200,
                    label: value.toStringAsFixed(2),
                    onChanged: (v) => _onParameterChanged(param, v),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(value.toStringAsFixed(1),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      textAlign: TextAlign.right),
                ),
              ]),
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
            Icon(Icons.view_in_ar, size: 64,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('3D 绘图功能即将推出',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('敬请期待后续更新',
                style: TextStyle(
                    fontSize: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

/// State for an extra formula row.
class _ExtraFormula {
  final TextEditingController controller;
  Color color;
  bool autoColor;
  String committedText;

  _ExtraFormula({
    required this.controller,
    required this.color,
    this.autoColor = true,
    this.committedText = '',
  });
}
