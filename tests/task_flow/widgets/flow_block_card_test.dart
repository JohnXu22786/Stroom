import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/flow_block_card.dart';

void main() {
  testWidgets('menu exposes duplicate and movement with disabled boundary',
      (tester) async {
    var duplicates = 0;
    var moves = 0;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: FlowBlockCard(
            block: TaskFlowBlock(typeKey: BlockType.chat),
            index: 1,
            isFirst: true,
            onDuplicate: () => duplicates++,
            onMoveDown: () => moves++,
          ),
        ),
      ),
    ));
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PopupMenuItem<int>>(
                find.widgetWithText(PopupMenuItem<int>, '上移（已在最前）'))
            .enabled,
        isFalse);
    await tester.tap(find.text('复制功能块'));
    await tester.pumpAndSettle();
    expect(duplicates, 1);
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下移'));
    await tester.pumpAndSettle();
    expect(moves, 1);
  });

  testWidgets('unsupported blocks still offer replacement and deletion',
      (tester) async {
    var removed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: FlowBlockCard(
            block: TaskFlowBlock(typeKey: BlockType.custom),
            index: 1,
            isFirst: true,
            onDelete: () => removed = true,
            onReplace: () {},
          ),
        ),
      ),
    ));
    expect(find.textContaining('未知功能块'), findsOneWidget);
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PopupMenuItem<int>>(
                find.widgetWithText(PopupMenuItem<int>, '替换功能块'))
            .enabled,
        isTrue);
    await tester.tap(find.text('删除功能块'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
  });
}
