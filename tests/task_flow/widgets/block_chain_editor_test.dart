import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/block_chain_editor.dart';

void main() {
  testWidgets('middle block has an accessible menu and deletion action', (
    tester,
  ) async {
    int? removed;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BlockChainEditor(
              blocks: [
                TaskFlowBlock(typeKey: BlockType.chat),
                TaskFlowBlock(typeKey: BlockType.chat),
                TaskFlowBlock(typeKey: BlockType.chat),
              ],
              inputType: IOType.text,
              onInputTypeChanged: (_) {},
              onAddBlock: (_) {},
              onEditBlock: (_) {},
              onDeleteBlock: (index) => removed = index,
              onReplaceBlock: (_, __) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('步骤 2 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除功能块'));
    await tester.pumpAndSettle();
    expect(removed, 1);
  });

  testWidgets('insertion choices check both neighboring steps', (tester) async {
    int? position;
    BlockType? inserted;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BlockChainEditor(
              blocks: [
                TaskFlowBlock(typeKey: BlockType.asr),
                TaskFlowBlock(typeKey: BlockType.tts),
              ],
              inputType: IOType.audio,
              onInputTypeChanged: (_) {},
              onAddBlock: (_) {},
              onEditBlock: (_) {},
              onDeleteBlock: (_) {},
              onReplaceBlock: (_, __) {},
              onInsertBlock: (index, type) {
                position = index;
                inserted = type;
              },
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('insert-block-1')));
    await tester.tap(find.byKey(const ValueKey('insert-block-1')));
    await tester.pumpAndSettle();
    expect(find.text('助手对话'), findsOneWidget);
    expect(find.text('语音合成'), findsNothing);
    expect(find.text('下载网页资源'), findsNothing);
    expect(find.textContaining('下一步需要: 文本'), findsOneWidget);
    await tester.tap(find.text('助手对话'));
    await tester.pumpAndSettle();
    expect(position, 1);
    expect(inserted, BlockType.chat);
  });

  testWidgets('insertion explains when no type can connect both neighbors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BlockChainEditor(
              blocks: [
                TaskFlowBlock(typeKey: BlockType.tts),
                TaskFlowBlock(typeKey: BlockType.asr),
              ],
              inputType: IOType.text,
              onInputTypeChanged: (_) {},
              onAddBlock: (_) {},
              onEditBlock: (_) {},
              onDeleteBlock: (_) {},
              onReplaceBlock: (_, __) {},
              onInsertBlock: (_, __) {},
            ),
          ),
        ),
      ),
    );
    final insertion = tester.widget<TextButton>(
      find.byKey(const ValueKey('insert-block-1')),
    );
    expect(insertion.onPressed, isNull);
    expect(find.byTooltip('没有同时兼容相邻步骤的功能块，请先调整相邻步骤'), findsOneWidget);
  });
}
