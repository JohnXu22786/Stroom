import 'dart:math' as dart_math;

import 'package:flutter/material.dart';

import '../models/math_3d_object.dart';
import '../models/math_3d_tool.dart';
import '../models/math_drawing_state.dart';
import '../models/math_expression.dart' show MathExpression;
import '../models/math_expression_3d.dart';
import '../models/formula_entry.dart';
import '../widgets/math_canvas.dart';
import '../widgets/math_canvas_3d.dart';
import '../widgets/math_3d_toolbar.dart';

/// 数学绘图页面 — 多公式、等价的公式行、颜色选择、显隐切换。
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
  final GlobalKey<MathCanvas3DState> _canvas3DKey = GlobalKey();

  ViewMode _currentView = ViewMode.mode2D;

  // 3D construction state
  ConstructionTool _current3DTool = ConstructionTool.move;
  String _toolInstruction = '';

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
        _currentView =
            _tabController.index == 0 ? ViewMode.mode2D : ViewMode.mode3D;
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
    if (_currentView == ViewMode.mode2D) {
      _plotAll2D();
    } else {
      _plotAll3D();
    }
  }

  void _plotAll2D() {
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

  void _plotAll3D() {
    final objects = <Object3D>[];
    for (final f in _formulas) {
      final text = f.controller.text.trim();
      if (text.isEmpty) continue;
      if (!f.visible) continue;

      final colorInt = f.color.value;

      // Try parsing as 3D surface z = f(x, y)
      final surfaceExpr = Expression3D.surface(text);
      if (surfaceExpr.isValid) {
        final mesh = surfaceExpr.sampleSurfaceGrid(
          xMin: -5,
          xMax: 5,
          yMin: -5,
          yMax: 5,
          gridX: 30,
          gridY: 30,
        );
        if (mesh.vertices.isNotEmpty) {
          objects.add(Object3D.surface(
            vertices: mesh.vertices,
            indices: mesh.indices,
            normals: mesh.normals,
            color: colorInt,
            opacity: 0.85,
            label: text,
          ));
          continue;
        }
      }

      // Try parsing as parametric curve
      final curveExpr =
          Expression3D.parametricCurve(text, tMax: 2 * dart_math.pi);
      if (curveExpr.isValid) {
        final points = curveExpr.sampleCurve(numSamples: 100);
        if (points.isNotEmpty) {
          objects.add(Object3D.curve(
            points: points,
            color: colorInt,
            label: text,
          ));
          continue;
        }
      }

      // If none matched, show error
      _showError('无法解析为3D表达式: $text');
      return;
    }

    setState(() {
      for (final f in _formulas) {
        f.committedText = f.controller.text.trim();
      }
    });

    if (objects.isEmpty) {
      _canvas3DKey.currentState?.clearObjects();
    } else {
      _canvas3DKey.currentState?.setObjects(objects);
    }
  }

  void _addFormula() {
    final used =
        _formulas.where((f) => f.autoColor).map((f) => f.color).toSet();
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
    // Re-plot after deletion so the canvas reflects the remaining formulas
    _plotAll();
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
            child: Text('删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

  void _onResetView() {
    if (_currentView == ViewMode.mode2D) {
      _canvasKey.currentState?.resetView();
    } else {
      _canvas3DKey.currentState?.resetView();
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
        title: const Text('数学绘图'),
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
          // Canvas + 3D canvas kept alive via IndexedStack
          Expanded(
            child: IndexedStack(
              index: _currentView == ViewMode.mode2D ? 0 : 1,
              children: [
                _buildCanvas(cs),
                _build3DCanvas(cs),
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
          Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.show_chart, size: 18),
            SizedBox(width: 6),
            Text('2D 绘图'),
          ])),
          Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
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
    // Dynamic expand: no max height, the list grows as formulas are added,
    // pushing the canvas down naturally.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _formulas.length,
      itemBuilder: (_, index) => _buildFormulaRow(cs, index),
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
                border:
                    hasChanged ? Border.all(color: cs.primary, width: 2) : null,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ---- Eye / eye-off toggle ----
          GestureDetector(
            onTap: () => _toggleVisibility(index),
            child: Icon(
              f.visible ? Icons.visibility : Icons.visibility_off,
              size: 20,
              color: f.visible ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 12),

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
                // Undo button: appears only when text has been modified
                suffixIcon: hasChanged
                    ? IconButton(
                        icon: Icon(Icons.undo,
                            size: 16, color: cs.onSurfaceVariant),
                        tooltip: '撤销修改',
                        onPressed: () {
                          f.controller.text = f.committedText;
                          f.controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: f.committedText.length),
                          );
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 24, minHeight: 24),
                      )
                    : null,
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

          // ---- Add formula (+) button (first row only) ----
          if (index == 0)
            IconButton(
              icon: Icon(Icons.add_circle, size: 18, color: cs.primary),
              tooltip: '添加公式',
              onPressed: _addFormula,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                  minWidth: 24, maxWidth: 24, minHeight: 24, maxHeight: 24),
            ),

          // ---- Remove formula (X) button ----
          if (_formulas.length > 1)
            IconButton(
              icon: Icon(Icons.remove_circle_outline,
                  size: 16, color: cs.error.withValues(alpha: 0.7)),
              tooltip: '删除公式',
              onPressed: () => _confirmRemove(index),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                  minWidth: 24, maxWidth: 24, minHeight: 24, maxHeight: 24),
            ),

          // ---- Plot (✓) button ----
          IconButton(
            icon: Icon(
              Icons.check_circle_outline,
              size: 20,
              color:
                  hasChanged ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
            ),
            tooltip: '绘制',
            onPressed: _canPlot ? _plotAll : null,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
                minWidth: 24, maxWidth: 24, minHeight: 24, maxHeight: 24),
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
  // 3D canvas
  // ==================================================================

  Widget _build3DCanvas(ColorScheme cs) {
    return Column(
      children: [
        // Construction toolbar
        Math3DToolbar(
          activeTool: _current3DTool,
          instruction: _current3DTool != ConstructionTool.move
              ? (_canvas3DKey.currentState?.constructionInstruction ??
                  _toolInstruction)
              : null,
          onToolSelected: (tool) {
            setState(() {
              _current3DTool = tool;
              _toolInstruction = '';
            });
            _canvas3DKey.currentState?.setTool(tool);
          },
        ),
        // View settings row (projection, axes, grid)
        if (_current3DTool == ConstructionTool.move) _buildViewSettingsRow(cs),
        // 3D canvas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MathCanvas3D(
                  key: _canvas3DKey,
                  currentTool: _current3DTool,
                  onReady: () {},
                  onViewportChange: () {},
                  onObjectCreated: (obj) {
                    _canvas3DKey.currentState?.setObjects(
                      [...?_canvas3DKey.currentState?.objects, obj],
                    );
                  },
                  onToolInstruction: (instruction) {
                    setState(() {
                      _toolInstruction = instruction;
                    });
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewSettingsRow(ColorScheme cs) {
    final state3D = _canvas3DKey.currentState;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Projection toggle
            _buildToolButton(
              icon: state3D?.projectionType == ProjectionType.perspective
                  ? Icons.view_in_ar
                  : Icons.grid_3x3,
              tooltip: '切换投影类型',
              onPressed: () {
                final current =
                    state3D?.projectionType ?? ProjectionType.parallel;
                state3D?.setProjectionType(
                  current == ProjectionType.parallel
                      ? ProjectionType.perspective
                      : ProjectionType.parallel,
                );
                setState(() {});
              },
            ),
            const SizedBox(width: 4),
            // Reset view
            _buildToolButton(
              icon: Icons.center_focus_strong,
              tooltip: '重置视图',
              onPressed: () => state3D?.resetView(),
            ),
            const SizedBox(width: 4),
            // Toggle axes
            _buildToolButton(
              icon: Icons.crop_square,
              tooltip: '显示/隐藏坐标轴',
              isActive: state3D?.showAxes ?? true,
              onPressed: () {
                state3D?.toggleAxes();
                setState(() {});
              },
            ),
            const SizedBox(width: 4),
            // Toggle grid
            _buildToolButton(
              icon: Icons.grid_on,
              tooltip: '显示/隐藏网格',
              isActive: state3D?.showGrid ?? true,
              onPressed: () {
                state3D?.toggleGrid();
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = true,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) return null;
          return isActive ? null : Colors.grey.withValues(alpha: 0.1);
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return isActive ? null : Colors.grey;
        }),
      ),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
          minWidth: 36, minHeight: 36, maxWidth: 36, maxHeight: 36),
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
    this.visible = true,
  }) : committedText = '';
}
