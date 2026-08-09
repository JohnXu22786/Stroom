import 'dart:math' as dart_math;

import 'package:flutter/material.dart';

import '../models/math_3d_object.dart';
import '../models/math_drawing_state.dart';
import '../models/math_expression.dart' show MathExpression;
import '../models/math_expression_3d.dart';
import '../models/formula_entry.dart';
import '../widgets/math_3d_object_panel.dart';
import '../widgets/math_3d_toolbar.dart';
import '../widgets/math_3d_view_toolbar.dart';
import '../widgets/math_canvas.dart';
import '../widgets/math_canvas_3d.dart';

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
  bool _showObjectPanel = true;

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
      // Pause auto-rotation while the 3D canvas is hidden (IndexedStack
      // keeps it alive).
      if (_currentView == ViewMode.mode2D) {
        _canvas3DKey.currentState?.setAutoRotate(false);
      }
      // When switching to 3D with formulas already committed in 2D, plot
      // them so the 3D canvas is not empty (the ✓ button is disabled
      // because nothing changed).
      if (_currentView == ViewMode.mode3D) {
        final canvas = _canvas3DKey.currentState;
        final hasFormulas =
            _formulas.any((f) => f.controller.text.trim().isNotEmpty);
        if (canvas != null &&
            hasFormulas &&
            canvas.expressionObjectCount == 0) {
          _plotAll3D();
        }
      }
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

  /// Parse a formula into 3D objects (surface / implicit / curve).
  List<Object3D>? _parse3DFormula(String text, int colorInt) {
    final trimmed = text.trim();

    // 1) Explicit surface: z = f(x,y) or f(x,y) = ...
    final isSurfacePrefix = trimmed.startsWith('z=') ||
        trimmed.startsWith('z =') ||
        RegExp(r'^f\s*\(\s*x\s*,\s*y\s*\)').hasMatch(trimmed);

    if (!isSurfacePrefix && _hasTopLevelEquals(trimmed)) {
      // 2) Implicit equation: F(x, y, z) = 0
      final implicit = Expression3D.implicit(trimmed);
      if (implicit.isValid) {
        final mesh = implicit.sampleImplicitGrid(box: 5, grid: 32);
        if (mesh.vertices.isNotEmpty) {
          return [
            Object3D.surface(
              mesh,
              name: 'f${_formulaIndex(trimmed)}',
              style: ObjectStyle(
                color: colorInt,
                opacity: 0.85,
                labelMode: LabelMode.name,
              ),
            ),
          ];
        }
        _showError('无法生成隐式曲面: $text');
        return null;
      }
      _showError('隐式方程解析失败: ${implicit.parseError}');
      return null;
    }

    if (trimmed.startsWith('(')) {
      // 3) Parametric curve (t) or parametric surface (u, v).
      final curve =
          Expression3D.parametricCurve(trimmed, tMax: 2 * dart_math.pi);
      if (curve.isValid) {
        final points = curve.sampleCurve(numSamples: 150);
        if (points.isNotEmpty) {
          return [
            Object3D.curve(
              points,
              // 'F' prefix avoids clashing with construction labels
              // (circles use 'c1', 'c2', …).
              name: 'F${_formulaIndex(trimmed)}',
              style: ObjectStyle(color: colorInt, labelMode: LabelMode.name),
            ),
          ];
        }
      }
      final surface = Expression3D.parametricSurface(
        trimmed,
        uMin: 0,
        uMax: 2 * dart_math.pi,
        vMin: -1,
        vMax: 1,
      );
      if (surface.isValid) {
        final mesh = surface.sampleParametricSurface();
        if (mesh.vertices.isNotEmpty) {
          return [
            Object3D.surface(
              mesh,
              name: 'f${_formulaIndex(trimmed)}',
              style: ObjectStyle(
                color: colorInt,
                opacity: 0.85,
                labelMode: LabelMode.name,
              ),
            ),
          ];
        }
      }
      _showError('无法解析为参数曲线或参数曲面: $text');
      return null;
    }

    // 4) Surface z = f(x, y)
    final surfaceExpr = Expression3D.surface(trimmed);
    if (surfaceExpr.isValid) {
      final mesh = surfaceExpr.sampleSurfaceGrid(
        xMin: -5,
        xMax: 5,
        yMin: -5,
        yMax: 5,
        gridX: 36,
        gridY: 36,
      );
      if (mesh.vertices.isNotEmpty) {
        return [
          Object3D.surface(
            mesh,
            name: 'f${_formulaIndex(trimmed)}',
            style: ObjectStyle(
              color: colorInt,
              opacity: 0.85,
              labelMode: LabelMode.name,
            ),
          ),
        ];
      }
    }
    _showError('无法解析为3D表达式: $text');
    return null;
  }

  int _formulaIndex(String text) {
    for (int i = 0; i < _formulas.length; i++) {
      if (_formulas[i].controller.text.trim() == text) return i + 1;
    }
    return 1;
  }

  static bool _hasTopLevelEquals(String expr) {
    var depth = 0;
    for (int i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if (ch == '(' || ch == '[') {
        depth++;
      } else if (ch == ')' || ch == ']') {
        depth--;
      } else if (ch == '=' && depth == 0) {
        return true;
      }
    }
    return false;
  }

  void _plotAll3D() {
    final objects = <Object3D>[];
    for (final f in _formulas) {
      final text = f.controller.text.trim();
      if (text.isEmpty) continue;
      if (!f.visible) continue;

      final colorInt = f.color.toARGB32();
      final parsed = _parse3DFormula(text, colorInt);
      if (parsed == null) return; // error already shown
      objects.addAll(parsed);
    }

    setState(() {
      for (final f in _formulas) {
        f.committedText = f.controller.text.trim();
      }
    });

    _canvas3DKey.currentState?.setExpressionObjects(objects);
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
      duration: const Duration(seconds: 3),
    ));
  }

  void _onResetView() {
    if (_currentView == ViewMode.mode2D) {
      _canvasKey.currentState?.resetView();
    } else {
      _canvas3DKey.currentState?.resetView();
    }
  }

  /// Numeric input dialog for construction tools that need a number.
  Future<double?> _askNumber(String prompt, double initial) async {
    final controller = TextEditingController(text: '$initial');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prompt),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          decoration: const InputDecoration(hintText: '输入数值'),
          onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
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
          if (_currentView == ViewMode.mode3D)
            IconButton(
              icon: Icon(
                  _showObjectPanel ? Icons.view_list : Icons.view_list_outlined,
                  size: 20),
              tooltip: '对象列表',
              onPressed: () =>
                  setState(() => _showObjectPanel = !_showObjectPanel),
            ),
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
          const SizedBox(width: 4),

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

          const SizedBox(width: 12),

          // ---- Formula text field ----
          Expanded(
            child: TextField(
              controller: f.controller,
              decoration: InputDecoration(
                hintText: _currentView == ViewMode.mode3D
                    ? '公式（z=f(x,y) / x²+y²+z²=1 / (cos t, sin t, t)）'
                    : '公式 ${index + 1}',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                filled: true,
                fillColor: f.color.withValues(alpha: 0.06),
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

          const SizedBox(width: 12),

          // ---- Eye / eye-off toggle ----
          IconButton(
            icon: Icon(
              f.visible ? Icons.visibility : Icons.visibility_off,
              size: 20,
              color: f.visible ? cs.onSurface : cs.onSurfaceVariant,
            ),
            tooltip: f.visible ? '隐藏公式' : '显示公式',
            onPressed: () => _toggleVisibility(index),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
                minWidth: 24, maxWidth: 24, minHeight: 24, maxHeight: 24),
          ),

          const SizedBox(width: 12),

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
        // Construction toolbar (toolboxes).
        Math3DToolbar(
          activeTool: _current3DTool,
          instruction: _current3DTool != ConstructionTool.move
              ? (_canvas3DKey.currentState?.construction?.currentInstruction ??
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
        // Canvas + object panel.
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant, width: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MathCanvas3D(
                        key: _canvas3DKey,
                        initialTool: _current3DTool,
                        onReady: () {},
                        onViewportChange: () {},
                        onSceneChanged: () {
                          if (mounted) setState(() {});
                        },
                        onToolInstruction: (instruction) {
                          setState(() {
                            _toolInstruction = instruction;
                          });
                        },
                        onNumericInput: _askNumber,
                      ),
                    ),
                  ),
                ),
              ),
              if (_showObjectPanel) _buildObjectPanel(cs),
            ],
          ),
        ),
        // View settings (style bar).
        Math3DViewToolbar(
          showAxes: _canvas3DKey.currentState?.showAxes ?? true,
          showGrid: _canvas3DKey.currentState?.showGrid ?? true,
          showPlane: _canvas3DKey.currentState?.showPlane ?? true,
          autoRotating: _canvas3DKey.currentState?.autoRotating ?? false,
          capturing: _canvas3DKey.currentState?.capturing ?? PointCapturing.off,
          projectionType: _canvas3DKey.currentState?.projectionType ??
              ProjectionType.parallel,
          onToggleAxes: () {
            _canvas3DKey.currentState?.toggleAxes();
            setState(() {});
          },
          onToggleGrid: () {
            _canvas3DKey.currentState?.toggleGrid();
            setState(() {});
          },
          onTogglePlane: () {
            _canvas3DKey.currentState?.togglePlane();
            setState(() {});
          },
          onToggleAutoRotate: () {
            final s = _canvas3DKey.currentState;
            if (s != null) s.setAutoRotate(!s.autoRotating);
            setState(() {});
          },
          onResetView: () => _canvas3DKey.currentState?.resetView(),
          onCapturingChanged: (mode) {
            _canvas3DKey.currentState?.setPointCapturing(mode);
            setState(() {});
          },
          onStandardView: (view) {
            _canvas3DKey.currentState?.setStandardView(view);
          },
          onProjectionChanged: (type) {
            _canvas3DKey.currentState?.setProjectionType(type);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildObjectPanel(ColorScheme cs) {
    final state = _canvas3DKey.currentState;
    return SizedBox(
      width: 190,
      child: Math3DObjectPanel(
        objects: state?.objects ?? const [],
        selected: state?.selected,
        onSelect: (obj) {
          state?.selectObject(obj);
          setState(() {}); // refresh the panel highlight
        },
        onToggleVisible: (obj) =>
            state?.setObjectVisible(obj.name, !obj.visible),
        onDelete: (obj) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('删除对象'),
              content: Text('确定要删除对象 "${obj.name}" 吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    state?.removeObject(obj);
                  },
                  child: Text('删除', style: TextStyle(color: cs.error)),
                ),
              ],
            ),
          );
        },
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
    this.visible = true,
  }) : committedText = '';
}
