// DragSortArea 胶囊/行拖拽排序测试：
// - 长按胶囊/把手启动拖拽，其余条目让位并显示目标槽位
// - 松手提交 onReorder（移除后插入索引语义）
// - 点击/删除回调照常工作
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/drag_sort_area.dart';

/// 长按 [from] 后移动 [offset] 再松手。
Future<void> _longPressDrag(
  WidgetTester tester,
  Finder from,
  Offset offset, {
  Duration hold = const Duration(milliseconds: 600),
}) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await tester.pump(hold);
  await gesture.moveBy(offset);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 有状态的测试宿主：onReorder 真正重排 values（与真实页面一致），
/// 并记录提交的 (from, to)。
class _Harness extends StatefulWidget {
  final List<String> initial;
  final bool wrap;
  final void Function(int from, int to) onReorder;
  const _Harness({
    required this.initial,
    required this.wrap,
    required this.onReorder,
  });
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late List<String> values = List.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: DragSortArea(
              wrap: widget.wrap,
              values: values,
              selected: (v) => v.startsWith('sel'),
              deletable: (v) => v.startsWith('del'),
              onTap: (v) => debugPrint('tap-$v'),
              onReorder: (from, to) {
                widget.onReorder(from, to);
                setState(() {
                  final v = values.removeAt(from);
                  values.insert(to, v);
                });
              },
              itemBuilder: (context, i, v) => Row(
                children: [
                  DragSortRowHandle(
                    index: i,
                    feedback: const SizedBox(width: 300, height: 56),
                    child: const Icon(Icons.drag_handle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(v)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _wrap(
    {required List<String> values,
    required void Function(int, int) onReorder,
    bool wrap = true}) {
  return _Harness(initial: values, wrap: wrap, onReorder: onReorder);
}

void main() {
  group('DragSortArea pills (wrap)', () {
    testWidgets('deletable pills show an inline close button that deletes',
        (tester) async {
      final deleted = <String>[];
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: DragSortArea(
                  wrap: true,
                  values: ['del-a', 'keep-b'],
                  selected: (_) => false,
                  deletable: (v) => v.startsWith('del'),
                  onTap: taps.add,
                  onDelete: deleted.add,
                  onReorder: (_, __) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget,
          reason: '仅可删除的胶囊显示关闭按钮');

      // 删除按钮与文字同一行、同一高度：图标中心 Y ≈ 文字中心 Y
      // （不再是右上角小叉）
      final textRect = tester.getRect(find.text('del-a'));
      final closeCenter = tester.getCenter(find.byIcon(Icons.close));
      expect(
        (closeCenter.dy - textRect.center.dy).abs() < 4,
        isTrue,
        reason: '删除按钮应垂直居中于文字（与文字标签同一高度）',
      );
      // 按钮位于文字右侧，不遮挡文字
      expect(closeCenter.dx > textRect.right, isTrue,
          reason: '删除按钮应在文字右侧而非压在文字上');

      // 文字完整显示（无省略号）：渲染宽度 == 文本自然宽度
      final painter = TextPainter(
        text: const TextSpan(text: 'del-a', style: TextStyle(fontSize: 13)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler:
            MediaQuery.textScalerOf(tester.element(find.text('del-a'))),
      )..layout();
      expect(textRect.width, closeTo(painter.width, 1.0),
          reason: '删除按钮不应挤占文字宽度（Flexible 均分会截断文字）');

      // 删除按钮保持固定 24×19 点击区
      final control = find
          .ancestor(
            of: find.byIcon(Icons.close),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(control), const Size(24, 19),
          reason: '删除按钮应保持固定尺寸（整行可点）');

      // 点击删除 → 仅触发 onDelete，不触发勾选（onTap）
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(deleted, ['del-a']);
      expect(taps, isEmpty,
          reason: '点删除按钮不应同时触发胶囊的勾选回调');
    });

    testWidgets('long-press starting on the delete button still drags',
        (tester) async {
      final reorders = <(int, int)>[];
      await tester.pumpWidget(
        _wrap(
            values: ['del-a', 'b', 'c'],
            onReorder: (f, t) => reorders.add((f, t))),
      );
      await tester.pumpAndSettle();

      // 长按 del-a 胶囊内的删除按钮区域（图标中心），拖动到末尾
      final closeIcon = find.byIcon(Icons.close);
      final gesture = await tester.startGesture(tester.getCenter(closeIcon));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(250, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reorders, [(0, 2)],
          reason: '从删除按钮区域长按也应启动整块拖拽排序');
    });

    testWidgets('long-press dragging a pill to the end reorders it',
        (tester) async {
      final reorders = <(int, int)>[];
      await tester.pumpWidget(
        _wrap(
            values: ['a', 'b', 'c'], onReorder: (f, t) => reorders.add((f, t))),
      );
      await tester.pumpAndSettle();

      // 把第一个胶囊拖到末尾
      await _longPressDrag(tester, find.text('a'), const Offset(250, 0));
      expect(reorders, [(0, 2)]);
    });

    testWidgets('dragging shows a drop slot and reorders to the middle',
        (tester) async {
      final reorders = <(int, int)>[];
      await tester.pumpWidget(
        _wrap(
            values: ['a', 'bb', 'c'],
            onReorder: (f, t) => reorders.add((f, t))),
      );
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('a')));
      await tester.pump(const Duration(milliseconds: 600));
      // 移到 bb 上（胶囊较窄：a≈39px + 间距，+55 落在 bb 内）→ 槽位出现
      await gesture.moveBy(const Offset(55, 0));
      await tester.pump(); // 预览帧（动画起点）
      await tester.pump(const Duration(milliseconds: 250)); // 让位动画完成
      expect(find.byKey(const ValueKey('drag-slot')), findsOneWidget,
          reason: '拖拽中应显示目标槽位');
      // 槽位 = 被拖项的落点：幽灵条目与槽位矩形一致（无错位）
      final slotRect = tester.getRect(find.byKey(const ValueKey('drag-slot')));
      final ghostRect = tester.getRect(find.byKey(const ValueKey('pill-a')));
      expect(slotRect, ghostRect, reason: '槽位必须与被拖项的落点重合，否则松手后会回跳');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reorders, isNotEmpty, reason: '松手应提交排序');
      // 松手后条目按预览位置就位：被拖项最终停在槽位处
      expect(
        tester.getRect(find.byKey(const ValueKey('pill-a'))),
        slotRect,
        reason: '松手后 a 应停在槽位指示的落点（预览即最终排布）',
      );
    });

    testWidgets('dropping back on the origin does not reorder', (tester) async {
      final reorders = <(int, int)>[];
      await tester.pumpWidget(
        _wrap(
            values: ['a', 'b', 'c'], onReorder: (f, t) => reorders.add((f, t))),
      );
      await tester.pumpAndSettle();

      await _longPressDrag(tester, find.text('b'), const Offset(2, 0));
      expect(reorders, isEmpty);
    });

    testWidgets('dragging the last pill to the front reorders to index 0',
        (tester) async {
      final reorders = <(int, int)>[];
      await tester.pumpWidget(
        _wrap(
            values: ['a', 'b', 'c'], onReorder: (f, t) => reorders.add((f, t))),
      );
      await tester.pumpAndSettle();

      // 长按 c（第三个），向左拖过 a 的中心
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('c')));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(-140, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      // 槽位与被拖项落点重合（拖向上方无错位）
      final slotRect = tester.getRect(find.byKey(const ValueKey('drag-slot')));
      final ghostRect = tester.getRect(find.byKey(const ValueKey('pill-c')));
      expect(slotRect, ghostRect);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reorders, [(2, 0)]);
      expect(
        tester.getRect(find.byKey(const ValueKey('pill-c'))),
        slotRect,
        reason: 'c 应停在槽位指示的落点',
      );
    });
  });

  group('DragSortArea rows (column)', () {
    testWidgets('long-press dragging the handle reorders rows', (tester) async {
      final reorders = <(int, int)>[];
      await tester.pumpWidget(
        _wrap(
          wrap: false,
          values: ['r0', 'r1', 'r2'],
          onReorder: (f, t) => reorders.add((f, t)),
        ),
      );
      await tester.pumpAndSettle();

      // 长按第一行的把手，向下拖过一行
      final handle = find.byIcon(Icons.drag_handle).first;
      await _longPressDrag(tester, handle, const Offset(0, 70));
      expect(reorders, [(0, 1)]);
    });

    testWidgets('rows stay editable (tap works, no drag from text)',
        (tester) async {
      final reorders = <(int, int)>[];
      await tester.pumpWidget(
        _wrap(
          wrap: false,
          values: ['r0', 'r1'],
          onReorder: (f, t) => reorders.add((f, t)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('r0'), findsOneWidget);
      expect(find.text('r1'), findsOneWidget);
      // 直接长按行文本不会触发排序（只有把手可拖）
      await _longPressDrag(tester, find.text('r0'), const Offset(0, 70));
      expect(reorders, isEmpty);
    });

    testWidgets('dragging a row upward reorders to the top', (tester) async {
      final reorders = <(int, int)>[];
      await tester.pumpWidget(
        _wrap(
          wrap: false,
          values: ['r0', 'r1', 'r2'],
          onReorder: (f, t) => reorders.add((f, t)),
        ),
      );
      await tester.pumpAndSettle();

      // 长按第三行的把手，向上拖过第一行
      final handle = find.byIcon(Icons.drag_handle).at(2);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, -140));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final slotRect = tester.getRect(find.byKey(const ValueKey('drag-slot')));
      final ghostRect = tester.getRect(find.byKey(const ValueKey('entry-2')));
      expect(slotRect, ghostRect, reason: '槽位与落点重合（向上拖无错位）');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reorders, [(2, 0)]);
    });
  });
}
