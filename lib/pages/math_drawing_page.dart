import 'package:flutter/material.dart';

import '../models/math_expression.dart' show MathExpression;
import '../models/math_drawing_state.dart';
import '../models/formula_entry.dart';
import '../widgets/math_canvas.dart';

/// 数学绘制页面 — 多公式、等价的公式行、颜色选择、显隐切换。
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
  late final TabController _tabController;
  final GlobalKey<MathCanvasState> _canvasKey = GlobalKey();

  ViewMode _currentView = ViewMode.mode2D;

  /// All formula rows (each is equal).
  final List<_FormulaState> _formulas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Start with one formula row
    _formulas.add(_FormulaState(
      controller: TextEditingController(text: widget.initialExpression ?? ''),
      color: formulaPalette[0],
      autoColor: true,
      visible: true,
    ));
  }

  @override
  void dispose() {
    for (final f in _formulas) {
      f.controller.dispose();
    }
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
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
  // Formula management
  // ==================================================================

  bool get _canPlot {
    return _formulas.any((f) {
      final text = f.controller.text.trim();
      return text.isNotEmpty && text != f.committedText;
    });
  }

  /// Plot all visible formulas that have changes.
  void _plotAll() {
    final entries = <FormulaEntry>[];
    for (final f in _formulas) {
      final text = f.controller.text.trim();
      if (text.isEmpty) continue;
      if (!f.visible) continue;

      final parsed = MathExpression.fromInput(text);
      if (!parsed.isValid) {
        _showError(parsed.parseError ?? '表达式错误: $text');
        return;
      }
      entries.add(FormulaEntry(
        rawExpression: text,
        parsed: parsed,
        color: f.color,
        autoColor: f.autoColor,
      ));
    }
    if (entries.isEmpty) {
      _canvasKey.currentState?.setFormulas([]);
      return;
    }

    // Mark all rows as committed
    setState(() {
      for (final f in _formulas) {
        f.committedText = f.controller.text.trim();
      }
    });

    _canvasKey.currentState?.setFormulas(entries);
  }

  void _addFormula() {
    final used = _formulas
        .where((f) => f.autoColor)
        .map((f) => f.color)
        .toSet();
    final color = nextFormulaColor(used);

    setState(() {
      _formulas.add(_FormulaState(
        controller: TextEditingController(),
        color: color,
        autoColor: true,
        visible: true,
      ));
    });
  }

  void _removeFormula(int index) {
    if (_formulas.length <= 1) return;
    setState(() {
      _formulas[index].controller.dispose();
      _formulas.removeAt(index);
    });
  }

  void _confirmRemove(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除公式'),
        content: Text('确定要删除"公式 ${index + 1}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeFormula(index);
            },
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _toggleVisibility(int index) {
    setState(() {
      _formulas[index].visible = !_formulas[index].visible;
    });
    // Re-plot to update canvas
    _plotAll();
  }

  void _showColorPicker(int index) {
    final currentColor = _formulas[index].color;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: formulaPalette.map((c) {
            final selected = currentColor == c;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _formulas[index].color = c;
                  _formulas[index].autoColor = false;
                });
                Navigator.pop(ctx);
                _plotAll();
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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _onResetView() => _canvasKey.currentState?.resetView();

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
          // Formula list (always shown)
          _buildFormulaList(cs),
          // Canvas + 3D placeholder kept alive via IndexedStack
          Expanded(
            child: IndexedStack(
              index: _currentView == ViewMode.mode2D ? 0 : 1,
              children: [
                _buildCanvas(cs),
                _build3DPlaceholder(cs),
              ],
            ),
          ),
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
  // Formula list
  // ==================================================================

  Widget _buildFormulaList(ColorScheme cs) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
        itemCount: _formulas.length,
        itemBuilder: (_, index) => _buildFormulaRow(cs, index),
      ),
    );
  }

  Widget _buildFormulaRow(ColorScheme cs, int index) {
    final f = _formulas[index];
    final hasChanged = f.controller.text.trim().isNotEmpty &&
        f.controller.text.trim() != f.committedText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // ---- Color indicator (tappable) ----
          GestureDetector(
            onTap: () => _showColorPicker(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: f.color,
                shape: BoxShape.circle,
                border: hasChanged
                    ? Border.all(color: cs.primary, width: 2)
                    : null,
              ),
            ),
          ),

          const SizedBox(width: 4),

          // ---- Eye / eye-off toggle ----
          GestureDetector(
            onTap: () => _toggleVisibility(index),
            child: Icon(
              f.visible ? Icons.visibility : Icons.visibility_off,
              size: 20,
              color: f.visible ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 4),

          // ---- Formula text field ----
          Expanded(
            child: TextField(
              controller: f.controller,
              decoration: InputDecoration(
                hintText: '公式 ${index + 1}',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                filled: true,
                fillColor: f.color.withValues(alpha: 0.06),
              ),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: cs.onSurface,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _plotAll(),
            ),
          ),

          const SizedBox(width: 2),

          // ---- Add formula (+) button (first row only) ----
          if (index == 0)
            IconButton(
              icon: Icon(Icons.add_circle, size: 20, color: cs.primary),
              tooltip: '添加公式',
              onPressed: _addFormula,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),

          // ---- Remove formula (X) button ----
          if (_formulas.length > 1)
            IconButton(
              icon: Icon(Icons.remove_circle_outline, size: 18, color: cs.error.withValues(alpha: 0.7)),
              tooltip: '删除公式',
              onPressed: () => _confirmRemove(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),

          // ---- Plot (✓) button ----
          IconButton(
            icon: Icon(
              Icons.check_circle_outline,
              size: 22,
              color: hasChanged
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.2),
            ),
            tooltip: '绘制',
            onPressed: _canPlot ? _plotAll : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // Canvas (2D)
  // ==================================================================

  Widget _buildCanvas(ColorScheme cs) {
    return Padding(
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
            initialExpression: null,
            onReady: () => debugPrint('[MathDrawing] Canvas ready'),
            onError: (msg) {
              debugPrint('[MathDrawing] Canvas error: $msg');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(msg),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ));
              }
            },
          ),
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
            Icon(Icons.view_in_ar,
                size: 64,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('3D 绘图功能即将推出',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('敬请期待后续更新',
                style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

/// State for a single formula row.
class _FormulaState {
  final TextEditingController controller;
  Color color;
  bool autoColor;
  String committedText;
  bool visible;

  _FormulaState({
    required this.controller,
    required this.color,
    this.autoColor = true,
    this.committedText = '',
    this.visible = true,
  });
}
