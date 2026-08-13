import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 长按触发拖拽的延迟（约 280ms，比默认 500ms 跟手）。
const Duration kDragSortDelay = Duration(milliseconds: 280);

/// 可拖拽排序的胶囊（自动换行）或行（垂直）列表。
///
/// 交互：
/// - 胶囊模式（[wrap] = true）：长按胶囊本身约 280ms 后拖拽；点击胶囊
///   触发 [onTap]；[deletable] 返回 true 时右上角显示删除按钮。
/// - 行模式（[wrap] = false）：长按行内 [DragSortRowHandle]（把手）拖拽，
///   行内容由 [itemBuilder] 构建（避免与输入框的文本选择冲突）。
///
/// 拖拽反馈：
/// - 被拖项原位以半透明「幽灵」显示（跟随手指的浮层由 Draggable 渲染
///   在 Overlay 上，不会被页面裁剪）；
/// - 其余项自动让位，目标插入位置显示高亮槽位（「拖动到哪里的反馈」）；
/// - 松手提交 [onReorder]（from/to 为「移除后插入」的索引，与 Flutter
///   `onReorderItem` 语义一致），列表经 [AnimatedPositioned] 平滑滑入
///   目标位置（预览排序动画）。
class DragSortArea extends StatefulWidget {
  /// 有序值列表。胶囊模式要求值唯一（布局按值定位）；行模式允许重复
  /// （布局按索引定位，行值可自由编辑）。
  final List<String> values;

  /// true = 胶囊自动换行布局；false = 垂直行布局。
  final bool wrap;

  /// 行布局的行高（不含行间距）。
  final double rowExtent;

  /// 胶囊布局：当前是否选中（高亮底色）。
  final bool Function(String value)? selected;

  /// 胶囊布局：是否可删除（右上角 x）。
  final bool Function(String value)? deletable;

  /// 胶囊布局：点击回调（勾选/取消）。
  final void Function(String value)? onTap;

  /// 胶囊布局：删除回调。
  final void Function(String value)? onDelete;

  /// 行布局：行内容构建器（内含 [DragSortRowHandle] 作为拖拽把手）。
  final Widget Function(BuildContext context, int index, String value)?
      itemBuilder;

  /// 排序提交回调：from/to 为「移除 after 插入」索引（与
  /// `ReorderableListView.onReorderItem` 一致）。
  final void Function(int from, int to) onReorder;

  const DragSortArea({
    super.key,
    required this.values,
    required this.wrap,
    this.rowExtent = 56,
    this.selected,
    this.deletable,
    this.onTap,
    this.onDelete,
    this.itemBuilder,
    required this.onReorder,
  });

  @override
  State<DragSortArea> createState() => _DragSortAreaState();
}

/// 行模式下的拖拽把手：长按 [child]（把手图标）启动整行拖拽。
/// 必须放在 [DragSortArea] 的 [itemBuilder] 返回的行内。
class DragSortRowHandle extends StatelessWidget {
  final int index;
  final Widget child;

  /// 拖拽时跟随手指的整行反馈（由调用方构建，通常为整行内容）。
  final Widget feedback;
  final bool enabled;
  final Duration delay;

  const DragSortRowHandle({
    super.key,
    required this.index,
    required this.child,
    required this.feedback,
    this.enabled = true,
    this.delay = kDragSortDelay,
  });

  @override
  Widget build(BuildContext context) {
    final controller = _DragSortScope.maybeOf(context);
    if (controller == null || !enabled) return child;
    return LongPressDraggable<String>(
      data: 'drag-row-$index',
      delay: delay,
      feedbackOffset: const Offset(-12, -24),
      // 反馈浮层不接收指针：拖拽中误点浮层不应触发行内控件
      ignoringFeedbackPointer: true,
      onDragStarted: () => controller.dragStarted(index),
      onDragUpdate: (d) => controller.dragUpdate(d.globalPosition),
      onDragEnd: (details) => controller.dragEnd(),
      onDraggableCanceled: (velocity, offset) => controller.dragCanceled(),
      // 反馈在 Overlay 上以松散约束布局，必须限定宽度（行内 Expanded
      // 需要有界宽度，否则整行会被撑满屏幕）。
      feedback: SizedBox(
        width: controller.maxWidth,
        child: feedback,
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}

class _DragSortScope extends InheritedWidget {
  final _DragSortAreaState controller;

  const _DragSortScope({required this.controller, required super.child});

  static _DragSortAreaState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DragSortScope>()?.controller;

  @override
  bool updateShouldNotify(_DragSortScope oldWidget) =>
      controller != oldWidget.controller;
}

/// 胶囊视觉高度：纵向 padding 6*2 + 一行文字 + 边框。
const double _kPillHeight = 34;

/// 胶囊内删除按钮的固定宽度（图标 16 + 左右点击留白 4*2）。
/// 按钮与文字同高（整行可点），位于胶囊右侧而非右上角小叉——
/// 更容易点击，也不遮挡文字。
const double _kPillDeleteWidth = 24;

class _DragSortAreaState extends State<DragSortArea> {
  /// 正在拖拽的条目索引（null = 未拖拽）。
  int? _dragIndex;

  /// 被拖项的最终落点索引（「移除后插入」语义，0..n-1；== _dragIndex
  /// 表示未移动）。build 里据此推导槽位在含拖项序列中的位置。
  int? _insertIndex;

  double _maxWidth = 0;

  /// 当前布局宽度（反馈副本用：Overlay 上布局需要限定宽度）。
  double get maxWidth => _maxWidth;

  void dragStarted(int index) {
    setState(() {
      _dragIndex = index;
      _insertIndex = index;
    });
  }

  void dragUpdate(Offset globalPosition) {
    final d = _dragIndex;
    if (d == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() {
      _insertIndex = _computeInsertIndex(box.globalToLocal(globalPosition), d);
    });
  }

  void dragEnd() {
    final d = _dragIndex;
    final t = _insertIndex;
    setState(() {
      _dragIndex = null;
      _insertIndex = null;
    });
    if (d == null || t == null || d == t) return;
    // _insertIndex 已是「移除后插入」索引
    widget.onReorder(d, t);
  }

  void dragCanceled() {
    setState(() {
      _dragIndex = null;
      _insertIndex = null;
    });
  }

  /// 判定插入点：找指针所在（或最近）的条目 k，返回「移除后插入」
  /// 索引 t = k —— 拖到条目 k 上即占据 k 的位置（与旧 DragTarget
  /// 语义一致），拖到列表外两端则贴到最近的条目。用原始布局（不含
  /// 槽）判定，位置稳定不受拖拽让位影响。
  int _computeInsertIndex(Offset local, int d) {
    final n = widget.values.length;
    if (n <= 1) return d;
    final rects = _layoutRects(
      [for (var k = 0; k < n; k++) _widthOf(k)],
      [for (var k = 0; k < n; k++) _minWidthOf(k)],
    );
    var best = d;
    var bestDist = double.infinity;
    for (var k = 0; k < n; k++) {
      final dist = _distanceToRect(local, rects[k]);
      if (dist < bestDist) {
        bestDist = dist;
        best = k;
      }
    }
    return best;
  }

  double _distanceToRect(Offset p, Rect r) {
    final dx =
        p.dx < r.left ? r.left - p.dx : (p.dx > r.right ? p.dx - r.right : 0);
    final dy =
        p.dy < r.top ? r.top - p.dy : (p.dy > r.bottom ? p.dy - r.bottom : 0);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 拖拽预览布局：条目按「最终顺序」（其余条目 + 被拖项落在 [t]）
  /// 排布，返回按位置排序的矩形列表——[t] 处即被拖项的落点（幽灵 +
  /// 槽位都渲染在这里），其余条目在最终位置，松手无需再移动。
  List<Rect> _layoutPreview(int t, int d) {
    final n = widget.values.length;
    final widths = <double>[];
    final minWidths = <double>[];
    for (var pos = 0; pos < n; pos++) {
      if (pos == t) {
        widths.add(_widthOf(d));
        minWidths.add(_minWidthOf(d));
        continue;
      }
      // 该位置在「除被拖项外」序列中的索引 → 原始索引
      final kPrime = pos < t ? pos : pos - 1;
      final k = kPrime < d ? kPrime : kPrime + 1;
      widths.add(_widthOf(k));
      minWidths.add(_minWidthOf(k));
    }
    return _layoutRects(widths, minWidths);
  }

  /// 原始索引 k（非被拖项）在预览布局中的位置。
  int _previewPosition(int k, int t, int d) {
    final kPrime = k > d ? k - 1 : k;
    return kPrime < t ? kPrime : kPrime + 1;
  }

  List<Rect> _layoutRects(List<double> widths, [List<double> minWidths = const []]) {
    final rects = <Rect>[];
    var x = 0.0, y = 0.0, rowBottom = 0.0;
    final itemHeight = widget.wrap ? _kPillHeight : widget.rowExtent;
    for (var i = 0; i < widths.length; i++) {
      var w = widths[i];
      if (w > _maxWidth) w = _maxWidth;
      // 可删除胶囊不能低于其最小宽度（padding + 边框 + 固定 24px 按钮），
      // 否则内部 Row 溢出抛异常。父级过窄时轻微超出布局宽度（Stack
      // clipBehavior 为 none，可正常绘制）。
      if (i < minWidths.length && w < minWidths[i]) w = minWidths[i];
      if (x + w > _maxWidth && x > 0) {
        x = 0;
        y = rowBottom + 8;
      }
      rects.add(Rect.fromLTWH(x, y, w, itemHeight));
      x += w + 8;
      rowBottom = math.max(rowBottom, y + itemHeight);
    }
    return rects;
  }

  /// 可删除胶囊的最小宽度（水平 padding 20 + 边框 + 删除按钮 24）。
  double _minWidthOf(int k) {
    if (!widget.wrap) return 0;
    final value = widget.values[k];
    if (!(widget.deletable?.call(value) ?? false)) return 0;
    final selected = widget.selected?.call(value) ?? false;
    return 20 + (selected ? 3.0 : 2.0) + _kPillDeleteWidth;
  }

  double _widthOf(int k) {
    if (!widget.wrap) return _maxWidth;
    final value = widget.values[k];
    final selected = widget.selected?.call(value) ?? false;
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      // 跟随系统字体缩放：否则放大字体下文字比预测宽度宽，
      // 胶囊提前省略号、拖拽幽灵与槽位宽度不符。
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    // 水平 padding（可删除时右侧 8）+ 边框（选中 1.5*2）+ 删除按钮宽度。
    // 边框必须与 _pillVisual 的 Border.all 一致，否则空值 + 删除按钮的
    // 胶囊会横向溢出 1px。
    final border = selected ? 3.0 : 2.0;
    final deletable = widget.deletable?.call(value) ?? false;
    return painter.width +
        (deletable ? 20 : 24) +
        border +
        (deletable ? _kPillDeleteWidth : 0);
  }

  bool get _uniqueValues =>
      widget.values.toSet().length == widget.values.length;

  Key _keyOf(int k) {
    if (widget.wrap && _uniqueValues) {
      return ValueKey('pill-${widget.values[k]}');
    }
    return ValueKey('entry-$k');
  }

  Widget _item(int k) {
    final value = widget.values[k];
    if (widget.wrap) return _buildPill(k, value);
    return widget.itemBuilder!(context, k, value);
  }

  Widget _buildPill(int k, String value) {
    final cs = Theme.of(context).colorScheme;
    final pill = _pillVisual(value, cs);
    return LongPressDraggable<String>(
      data: value,
      delay: kDragSortDelay,
      feedbackOffset: Offset(-_widthOf(k) / 2, -_kPillHeight / 2),
      // 反馈浮层不接收指针：拖拽中误点浮层不应触发勾选/删除
      ignoringFeedbackPointer: true,
      onDragStarted: () => dragStarted(k),
      onDragUpdate: (d) => dragUpdate(d.globalPosition),
      onDragEnd: (details) => dragEnd(),
      onDraggableCanceled: (velocity, offset) => dragCanceled(),
      feedback: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Opacity(opacity: 0.95, child: pill),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: pill),
      child: GestureDetector(
        onTap: widget.onTap == null ? null : () => widget.onTap!(value),
        child: pill,
      ),
    );
  }

  Widget _pillVisual(String value, ColorScheme cs) {
    final selected = widget.selected?.call(value) ?? false;
    final deletable = widget.deletable?.call(value) ?? false;
    final text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
    );
    final chip = Container(
      padding: EdgeInsets.fromLTRB(12, 6, deletable ? 8 : 12, 6),
      decoration: BoxDecoration(
        // 与聊天推理面板的 OptionChip 一致：选中 = 主色淡底 + 主色边框
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: text),
          if (deletable) _deleteControl(value, cs),
        ],
      ),
    );
    return chip;
  }

  /// 胶囊右侧的删除按钮：与文字标签同一行、等高（整行高度都可点），
  /// 取代旧版右上角小叉（遮挡文字且难点）。
  Widget _deleteControl(String value, ColorScheme cs) {
    return GestureDetector(
      onTap: widget.onDelete == null ? null : () => widget.onDelete!(value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _kPillDeleteWidth,
        // 内容区高度 = 胶囊高 - 纵向 padding 12 - 选中边框 3（最紧情形）
        height: _kPillHeight - 12 - 3,
        alignment: Alignment.center,
        child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
      ),
    );
  }

  /// 拖拽目标槽位：主色高亮边框 + 淡底（垫在幽灵下方指示落点；
  /// 值文本由幽灵本身显示）。
  Widget _slotVisual(Size size, ColorScheme cs) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(widget.wrap ? 20 : 8),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DragSortScope(
      controller: this,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _maxWidth = constraints.maxWidth;
          final cs = Theme.of(context).colorScheme;
          final values = widget.values;
          final n = values.length;
          final d = _dragIndex;
          final t = _insertIndex;
          final dragging = d != null && t != null;
          // 拖拽中：条目按最终顺序排布，被拖项（幽灵）与其下方的槽位
          // 都渲染在落点 [t]（= 最终索引），其余条目让位——松手后条目
          // 已各就各位，槽位原地变成实体，无错位。
          final entries = <(Key, Rect, Widget)>[];
          if (dragging) {
            final rects = _layoutPreview(t, d);
            for (var k = 0; k < n; k++) {
              if (k == d) continue;
              final child = _item(k);
              entries.add((
                _keyOf(k),
                rects[_previewPosition(k, t, d)],
                // 行条目必须始终包在同一个 Opacity 里（拖拽中仅改
                // 透明度）——若拖拽中才插入 Opacity 包装，会改变子树
                // 根类型导致行内 LongPressDraggable 被卸载、拖拽取消。
                !widget.wrap ? Opacity(opacity: 1.0, child: child) : child,
              ));
            }
            // 槽位（虚线边框 + 淡底）垫在被拖项幽灵下方，指示落点
            if (t != d) {
              entries.add((
                const ValueKey('drag-slot'),
                rects[t],
                _slotVisual(rects[t].size, cs),
              ));
            }
            // 被拖项：渲染在落点（幽灵内容），保持原子树类型不变
            entries.add((
              _keyOf(d),
              rects[t],
              !widget.wrap ? Opacity(opacity: 0.45, child: _item(d)) : _item(d),
            ));
          } else {
            final rects = _layoutRects(
              [for (var k = 0; k < n; k++) _widthOf(k)],
              [for (var k = 0; k < n; k++) _minWidthOf(k)],
            );
            for (var k = 0; k < n; k++) {
              final child = _item(k);
              entries.add((
                _keyOf(k),
                rects[k],
                !widget.wrap ? Opacity(opacity: 1.0, child: child) : child,
              ));
            }
          }

          final totalHeight = entries.isEmpty
              ? 0.0
              : entries.map((e) => e.$2.bottom).reduce(math.max);
          return SizedBox(
            width: _maxWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (key, rect, child) in entries)
                  AnimatedPositioned(
                    key: key,
                    // 拖拽中：条目让位/收拢动画（预览排序动画）。
                    // 提交帧（拖拽已结束）：预览即最终排布，条目已各就
                    // 各位——动画反而会造成「内容回跳」的错位感。
                    duration: dragging
                        ? const Duration(milliseconds: 160)
                        : Duration.zero,
                    curve: Curves.easeInOut,
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: child,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
