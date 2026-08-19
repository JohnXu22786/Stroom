// Widget tests for ToolCallCard's collapsible display behavior:
//   - running / pending: always expanded (arguments + result visible)
//   - completed / error: collapsed to a single line (tool name only),
//     tap toggles expand / collapse
//   - error: tool name rendered in red
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart' show ToolCallData, ToolCallStatus;
import 'package:stroom/services/context_manager.dart'
    show kCompactedToolResultPlaceholder;
import 'package:stroom/widgets/llm/tool_call_card.dart';

ToolCallData _tc({
  String id = 'tc-1',
  required String name,
  required ToolCallStatus status,
  Map<String, dynamic> arguments = const {'query': '天气'},
  String? result = '搜索结果',
}) =>
    ToolCallData(
      id: id,
      name: name,
      arguments: arguments,
      status: status,
      result: result,
    );

Widget _wrap(ToolCallData data) => MaterialApp(
      home: Scaffold(
        body: ToolCallCard(data: data),
      ),
    );

void main() {
  group('ToolCallCard - collapsible display', () {
    testWidgets('running 状态保持展开：参数与结果可见，且无折叠箭头', (tester) async {
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.running)),
      );

      expect(find.text('web_search'), findsOneWidget);
      expect(find.text('query: 天气'), findsOneWidget, reason: '调用进行中应显示参数');
      expect(find.text('搜索结果'), findsOneWidget, reason: '调用进行中应显示结果');
      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: '调用进行中应显示加载 spinner');
      expect(find.byIcon(Icons.expand_more), findsNothing,
          reason: '调用进行中不应显示折叠箭头');
      expect(find.byIcon(Icons.expand_less), findsNothing,
          reason: '调用进行中不应显示展开箭头');
    });

    testWidgets('pending 状态保持展开：参数与结果可见，且无箭头', (tester) async {
      await tester.pumpWidget(
        _wrap(_tc(name: 'todo_add', status: ToolCallStatus.pending)),
      );

      expect(find.text('query: 天气'), findsOneWidget, reason: '待执行阶段应保持展开显示参数');
      expect(find.text('搜索结果'), findsOneWidget, reason: '待执行阶段应显示结果');
      expect(find.byIcon(Icons.expand_more), findsNothing,
          reason: '待执行阶段不应显示箭头');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'pending 阶段不显示 spinner（spinner 仅 running 显示）');
    });

    testWidgets('pending 状态点击为 no-op：点击后转为完成仍自动收起', (tester) async {
      await tester.pumpWidget(
        _wrap(_tc(name: 'todo_add', status: ToolCallStatus.pending)),
      );
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('query: 天气'), findsOneWidget, reason: '待执行卡片点击后仍应展开');

      await tester.pumpWidget(
        _wrap(_tc(name: 'todo_add', status: ToolCallStatus.completed)),
      );
      await tester.pump();
      expect(find.text('query: 天气'), findsNothing,
          reason: '待执行点击应为 no-op，转为完成后仍应自动收起');
    });

    testWidgets('completed 状态默认收起为一行：名称可见，参数与结果隐藏', (tester) async {
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.completed)),
      );

      expect(find.text('web_search'), findsOneWidget);
      expect(find.text('query: 天气'), findsNothing, reason: '调用完成后应自动收起参数');
      expect(find.text('搜索结果'), findsNothing, reason: '调用完成后应自动收起结果');
      expect(find.byIcon(Icons.expand_more), findsOneWidget,
          reason: '收起状态应显示可展开箭头');
    });

    testWidgets('点击已完成卡片可展开/收起切换', (tester) async {
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.completed)),
      );

      // Initially collapsed.
      expect(find.text('query: 天气'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget,
          reason: '收起状态应显示向下箭头');

      // Tap → expanded.
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('query: 天气'), findsOneWidget, reason: '点击收起卡片应展开并显示参数');
      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget,
          reason: '展开状态箭头应翻转为向上');

      // Tap again → collapsed.
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('query: 天气'), findsNothing, reason: '再次点击应重新收起');
      expect(find.byIcon(Icons.expand_more), findsOneWidget,
          reason: '收起后箭头应恢复为向下');
    });

    testWidgets('展开后点击参数行右侧的空白区域同样可收起', (tester) async {
      // Regression: GestureDetector 需 HitTestBehavior.opaque，否则点击
      // 参数（窄文本）与结果容器之间的空白处会命中测试穿透、无法切换。
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.completed)),
      );
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('query: 天气'), findsOneWidget, reason: '先展开');

      // 参数行（窄文本）右侧是空白区：取其水平中点、参数行垂直中点，
      // 该点不在任何子组件渲染盒内，仅靠 opaque 才能命中卡片。
      final cardRect = tester.getRect(find.byType(ToolCallCard));
      final argsRect = tester.getRect(find.text('query: 天气'));
      final blankPoint = Offset(
        (argsRect.right + cardRect.right) / 2,
        argsRect.center.dy,
      );
      await tester.tapAt(blankPoint);
      await tester.pump();

      expect(find.text('query: 天气'), findsNothing, reason: '点击参数行右侧空白处应触发收起');
    });

    testWidgets('点击卡片左缘内边距环带同样可切换', (tester) async {
      // Regression: GestureDetector 若包在内边距之内，卡片外圈 10px
      // 环带（视觉上属于卡片）点击无效。
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.completed)),
      );
      final cardRect = tester.getRect(find.byType(ToolCallCard));
      await tester.tapAt(Offset(cardRect.left + 3, cardRect.center.dy));
      await tester.pump();
      expect(find.text('query: 天气'), findsOneWidget, reason: '点击内边距环带应能展开');
    });

    testWidgets('error 状态名称红色（展开/收起一致），再点一次收回起', (tester) async {
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.error)),
      );

      // Collapsed: name visible in red, details hidden.
      final collapsedName = tester.widget<Text>(find.text('web_search'));
      expect(collapsedName.style?.color, Colors.red,
          reason: '失败的调用收起后工具名称应为红色');
      expect(find.text('query: 天气'), findsNothing);

      // Expand: name stays red.
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      final expandedName = tester.widget<Text>(find.text('web_search'));
      expect(expandedName.style?.color, Colors.red, reason: '失败调用展开后工具名称仍应为红色');

      // Tap again → collapsed (same as completed 卡片).
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('query: 天气'), findsNothing, reason: '失败调用再点一次应收起');
    });

    testWidgets('completed 名称非红色（对照组）', (tester) async {
      await tester.pumpWidget(
        _wrap(_tc(name: 'read_file', status: ToolCallStatus.completed)),
      );

      final okName = tester.widget<Text>(find.text('read_file'));
      expect(okName.style?.color, isNot(Colors.red), reason: '成功的调用名称不应为红色');
    });

    testWidgets('compactedAt 非空时收起态显示"已压缩"徽标，展开显示占位符', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolCallCard(
              data: ToolCallData(
                id: 'tc-1',
                name: 'web_search',
                arguments: const {},
                status: ToolCallStatus.completed,
                result: '很长的结果内容',
                compactedAt: DateTime(2025, 1, 1),
              ),
            ),
          ),
        ),
      );

      // 收起态：徽标可见，占位符隐藏。
      expect(find.text('已压缩'), findsOneWidget, reason: '收起态应显示"已压缩"徽标');
      expect(find.text(kCompactedToolResultPlaceholder), findsNothing);

      // 展开态：徽标保留，结果渲染为占位符。
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('已压缩'), findsOneWidget, reason: '展开后徽标仍应可见');
      expect(find.text(kCompactedToolResultPlaceholder), findsOneWidget,
          reason: '展开后结果应渲染压缩占位符');
      expect(find.text('很长的结果内容'), findsNothing,
          reason: 'compacted 后不应再渲染原始结果');
    });

    testWidgets('运行中→完成的状态转换自动收起', (tester) async {
      // Same element position, data switches running → completed: the card
      // must collapse automatically (regression: 完成前不可折叠，完成后应
      // 立即收起，而不是保持展开直到用户手动操作).
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.running)),
      );
      expect(find.text('query: 天气'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.completed)),
      );
      await tester.pump();

      expect(find.text('query: 天气'), findsNothing, reason: '状态转为完成后应自动收起为一行');
      expect(find.text('web_search'), findsOneWidget);
    });

    testWidgets('同 id 完成(已展开)→重新进行中→再次完成时自动收起', (tester) async {
      // Regression: didUpdateWidget 需在状态退回进行中时重置展开状态，
      // 否则同一 id 重跑时第二次完成后会残留旧的展开状态、无法自动收起。
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.completed)),
      );
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('query: 天气'), findsOneWidget, reason: '先展开已完成卡片');

      // 同一 id 重新进入进行中（同 id 重跑）：必须重置展开状态。
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.running)),
      );
      await tester.pump();
      expect(find.text('query: 天气'), findsOneWidget, reason: '进行中仍应展开显示');

      // 再次完成：应自动收起，而不是残留展开状态。
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.completed)),
      );
      await tester.pump();
      expect(find.text('query: 天气'), findsNothing, reason: '同 id 第二次完成后也应自动收起');
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('running 状态点击为 no-op：点击后转为完成仍自动收起', (tester) async {
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.running)),
      );

      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('query: 天气'), findsOneWidget, reason: '进行中卡片点击后仍应展开');

      // 判别性断言：若点击曾把 _expanded 置 true（守卫失效），
      // 转为完成后会残留展开状态，此断言即失败。
      await tester.pumpWidget(
        _wrap(_tc(name: 'web_search', status: ToolCallStatus.completed)),
      );
      await tester.pump();
      expect(find.text('query: 天气'), findsNothing,
          reason: '进行中点击应为 no-op，转为完成后仍应自动收起');
    });

    testWidgets('同一位置替换为新工具调用（不同 id）时重置展开状态', (tester) async {
      // didUpdateWidget 的 id 重置分支：列表原地替换时，新工具的
      // 展开状态不应沿用到新工具上。
      await tester.pumpWidget(
        _wrap(_tc(
            id: 'tc-1', name: 'web_search', status: ToolCallStatus.completed)),
      );
      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      expect(find.text('query: 天气'), findsOneWidget, reason: '先展开旧工具');

      await tester.pumpWidget(
        _wrap(_tc(
            id: 'tc-2', name: 'read_file', status: ToolCallStatus.completed)),
      );
      await tester.pump();

      expect(find.text('query: 天气'), findsNothing, reason: '换新工具调用后应重置为收起状态');
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('收起与展开状态卡片宽度一致（无水平跳动）', (tester) async {
      // Regression: 收起态若收缩为内容宽，切换时卡片宽度会跳动。
      // Align 提供松约束，width: double.infinity 才能让卡片撑满。
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ToolCallCard(
                data: _tc(name: 'web_search', status: ToolCallStatus.completed),
              ),
            ),
          ),
        ),
      );
      final collapsedWidth = tester.getRect(find.byType(ToolCallCard)).width;

      await tester.tap(find.byType(ToolCallCard));
      await tester.pump();
      final expandedWidth = tester.getRect(find.byType(ToolCallCard)).width;

      expect(collapsedWidth, expandedWidth, reason: '收起/展开切换时卡片宽度不应跳动');
    });

    testWidgets('长工具名收起时不换行、不溢出（省略号截断）', (tester) async {
      // Regression: 收起为一行后长名称（如 MCP 工具）在窄屏会撑破
      // 卡片（RenderFlex overflow）或换行成两行。
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const longName = 'mcp__notion__search_pages_tool';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: ToolCallCard(
                  data: _tc(name: longName, status: ToolCallStatus.completed),
                ),
              ),
            ),
          ),
        ),
      );
      // 布局若溢出会抛出 RenderFlex overflow，测试框架自动判失败。
      await tester.pump();
      final name = tester.widget<Text>(find.text(longName));
      expect(name.maxLines, 1, reason: '长名称应单行省略显示');
    });
  });
}
