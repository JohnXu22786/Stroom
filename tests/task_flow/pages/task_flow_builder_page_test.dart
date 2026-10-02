import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/widgets/flow_block_card.dart';

class _Flows extends TaskFlowNotifier {
  int writes = 0;
  @override
  Future<bool> persist() async {
    writes++;
    return true;
  }
}

Future<void> _open(WidgetTester tester, _Flows flows, String flowId) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [taskFlowListProvider.overrideWith((_) => flows)],
      child: MaterialApp(home: TaskFlowBuilderPage(flowId: flowId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The repository keeps Flutter tests under tests/ rather than test/.
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'delete preserves configured suffix, blocks save, and undo repairs',
    (tester) async {
      final flows = _Flows();
      final flow = TaskFlowDefinition(
        name: 'Chain',
        blocks: [
          TaskFlowBlock(
            id: 'download',
            typeKey: BlockType.catcatch,
            params: {'durationSec': 19},
          ),
          TaskFlowBlock(
            id: 'audio',
            typeKey: BlockType.audioSeparation,
            params: {'saveFolder': 'kept-folder'},
          ),
          TaskFlowBlock(
            id: 'recognition',
            typeKey: BlockType.asr,
            params: {
              'modelRef': {'configId': 'provider', 'modelId': 'kept-model'},
            },
          ),
        ],
      );
      await flows.saveFlow(flow);
      final initialWrites = flows.writes;
      await _open(tester, flows, flow.id);
      await tester.ensureVisible(find.byTooltip('步骤 2 操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('步骤 2 操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除功能块'));
      await tester.pumpAndSettle();
      final cards = tester.widgetList<FlowBlockCard>(
        find.byType(FlowBlockCard),
      );
      expect(cards.map((card) => card.block.id), ['download', 'recognition']);
      expect(cards.last.block.params['modelRef'], {
        'configId': 'provider',
        'modelId': 'kept-model',
      });
      expect(find.textContaining('「语音识别」需要音频'), findsOneWidget);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(flows.writes, initialWrites);
      expect(flows.getFlow(flow.id)!.blocks, hasLength(3));
      await tester.tap(find.byTooltip('撤销'));
      await tester.pumpAndSettle();
      final restored = tester.widgetList<FlowBlockCard>(
        find.byType(FlowBlockCard),
      );
      expect(restored.map((card) => card.block.id), [
        'download',
        'audio',
        'recognition',
      ]);
      expect(restored.elementAt(1).block.params['saveFolder'], 'kept-folder');
      expect(find.textContaining('「语音识别」需要音频'), findsNothing);
    },
  );

  testWidgets('parameter edits and initial input changes can both be undone', (
    tester,
  ) async {
    final flows = _Flows();
    final flow = TaskFlowDefinition(
      name: 'Editable',
      blocks: [
        TaskFlowBlock(
          id: 'download',
          typeKey: BlockType.catcatch,
          params: {'durationSec': 19},
        ),
      ],
    );
    await flows.saveFlow(flow);
    await _open(tester, flows, flow.id);
    await tester.tap(find.byTooltip('设置参数'));
    await tester.pumpAndSettle();
    final duration = find.widgetWithText(TextField, '19');
    await tester.enterText(duration, '41');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FlowBlockCard>(find.byType(FlowBlockCard))
          .block
          .params['durationSec'],
      41,
    );
    await tester.tap(find.byType(DropdownButton<IOType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图片').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('初始输入为图片'), findsOneWidget);
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<IOType>>(find.byType(DropdownButton<IOType>))
          .value,
      IOType.text,
    );
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FlowBlockCard>(find.byType(FlowBlockCard))
          .block
          .params['durationSec'],
      19,
    );
    expect(flows.getFlow(flow.id)!.blocks.single.params['durationSec'], 19);
  });

  testWidgets('an initial template stays an independent unsaved draft', (
    tester,
  ) async {
    final flows = _Flows();
    final draft = TaskFlowDefinition(
      name: 'Template draft',
      description: 'Editable template',
      inputType: IOType.video,
      blocks: [
        TaskFlowBlock(
          id: 'template-step',
          typeKey: BlockType.audioSeparation,
          params: {'saveFolder': 'template-folder'},
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskFlowListProvider.overrideWith((_) => flows)],
        child: MaterialApp(home: TaskFlowBuilderPage(initialDraft: draft)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Template draft'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Editable template'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<IOType>>(find.byType(DropdownButton<IOType>))
          .value,
      IOType.video,
    );
    expect(
      tester
          .widget<FlowBlockCard>(find.byType(FlowBlockCard))
          .block
          .params['saveFolder'],
      'template-folder',
    );
    expect(flows.writes, 0);
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制功能块'));
    await tester.pumpAndSettle();
    final edited = tester.widgetList<FlowBlockCard>(find.byType(FlowBlockCard));
    expect(edited, hasLength(2));
    expect(edited.last.block.id, isNot(draft.blocks.single.id));
    expect(draft.blocks, hasLength(1));
    expect(flows.writes, 0);
  });
}
