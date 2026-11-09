import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
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

class _Entries extends ProviderEntriesNotifier {
  _Entries() {
    state = const ProviderEntriesState();
  }
}

class _Assistants extends AssistantsNotifier {
  _Assistants() {
    state = const [];
  }
}

Future<void> _open(WidgetTester tester, _Flows flows, String flowId) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [taskFlowListProvider.overrideWith((_) => flows)],
    child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TaskFlowBuilderPage(flowId: flowId)),
  ));
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
    final flow = TaskFlowDefinition(name: 'Chain', blocks: [
      TaskFlowBlock(
          id: 'download',
          typeKey: BlockType.catcatch,
          params: {'durationSec': 19}),
      TaskFlowBlock(
          id: 'audio',
          typeKey: BlockType.audioSeparation,
          params: {'saveFolder': 'kept-folder'}),
      TaskFlowBlock(id: 'recognition', typeKey: BlockType.asr, params: {
        'modelRef': {'configId': 'provider', 'modelId': 'kept-model'}
      }),
    ]);
    await flows.saveFlow(flow);
    final initialWrites = flows.writes;
    await _open(tester, flows, flow.id);
    await tester.ensureVisible(find.byTooltip('步骤 2 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('步骤 2 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除功能块'));
    await tester.pumpAndSettle();
    final cards = tester.widgetList<FlowBlockCard>(find.byType(FlowBlockCard));
    expect(cards.map((card) => card.block.id), ['download', 'recognition']);
    expect(cards.last.block.params['modelRef'],
        {'configId': 'provider', 'modelId': 'kept-model'});
    expect(find.textContaining('需要音频'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(flows.writes, initialWrites);
    expect(flows.getFlow(flow.id)!.blocks, hasLength(3));
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    final restored =
        tester.widgetList<FlowBlockCard>(find.byType(FlowBlockCard));
    expect(restored.map((card) => card.block.id),
        ['download', 'audio', 'recognition']);
    expect(restored.elementAt(1).block.params['saveFolder'], 'kept-folder');
    expect(find.textContaining('需要音频'), findsNothing);
  });

  testWidgets('parameter edits and initial input changes can both be undone',
      (tester) async {
    final flows = _Flows();
    final flow = TaskFlowDefinition(name: 'Editable', blocks: [
      TaskFlowBlock(
          id: 'download',
          typeKey: BlockType.catcatch,
          params: {'durationSec': 19}),
    ]);
    await flows.saveFlow(flow);
    await _open(tester, flows, flow.id);
    await tester.tap(find.byTooltip('设置参数'));
    await tester.pumpAndSettle();
    final duration = find.widgetWithText(TextField, '19');
    await tester.scrollUntilVisible(duration, 150,
        scrollable: find.byType(Scrollable).last);
    await tester.enterText(duration, '41');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FlowBlockCard>(find.byType(FlowBlockCard))
            .block
            .params['durationSec'],
        41);
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
        IOType.text);
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FlowBlockCard>(find.byType(FlowBlockCard))
            .block
            .params['durationSec'],
        19);
    expect(flows.getFlow(flow.id)!.blocks.single.params['durationSec'], 19);
  });

  testWidgets('generic file input is selectable and saved for assistant flows',
      (tester) async {
    final flows = _Flows();
    final flow = TaskFlowDefinition(
      name: 'Document summary',
      blocks: [
        TaskFlowBlock(
          typeKey: BlockType.chat,
          params: {'assistantId': 'selected-assistant'},
        ),
      ],
    );
    await flows.saveFlow(flow);
    await _open(tester, flows, flow.id);
    await tester.tap(find.byType(DropdownButton<IOType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文件').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButton<IOType>>(find.byType(DropdownButton<IOType>))
            .value,
        IOType.file);
    expect(find.textContaining('需要明确'), findsNothing);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(flows.getFlow(flow.id)!.inputType, IOType.file);
  });

  testWidgets('run-mode parameter labels follow the selected locale',
      (tester) async {
    final flows = _Flows();
    final flow = TaskFlowDefinition(
      name: 'Localized parameters',
      blocks: [
        TaskFlowBlock(
          typeKey: BlockType.chat,
          params: {'assistantId': ''},
        ),
        TaskFlowBlock(
          typeKey: BlockType.tts,
          params: {
            'modelRef': 'deleted-model',
            'voice': 'deleted-voice',
            'saveFolder': '',
          },
        ),
      ],
    );
    await flows.saveFlow(flow);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        taskFlowListProvider.overrideWith((_) => flows),
        providerEntriesProvider.overrideWith((_) => _Entries()),
        assistantProvider.overrideWith((_) => _Assistants()),
      ],
      child: MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TaskFlowBuilderPage(flowId: flow.id, startInRunMode: true),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FlowBlockCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Assistant: '), findsOneWidget);
    expect(find.text('(Not set)'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FlowBlockCard).last);
    await tester.pumpAndSettle();
    final dialogScrollView = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(dialogScrollView, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Synthesis model: '), findsOneWidget);
    expect(
      find.text(
        'No model is selected or the model is unavailable. Select another model.',
      ),
      findsOneWidget,
    );
    expect(find.text('Voice: '), findsOneWidget);
    expect(
      find.text('Voice is unavailable. Select another voice.'),
      findsOneWidget,
    );
    expect(find.text('Save folder: '), findsOneWidget);
    expect(find.text('Root folder'), findsOneWidget);
  });

  testWidgets('an initial template stays an independent unsaved draft',
      (tester) async {
    final flows = _Flows();
    final draft = TaskFlowDefinition(
        name: 'Template draft',
        description: 'Editable template',
        inputType: IOType.video,
        blocks: [
          TaskFlowBlock(
              id: 'template-step',
              typeKey: BlockType.audioSeparation,
              params: {'saveFolder': 'template-folder'}),
        ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [taskFlowListProvider.overrideWith((_) => flows)],
      child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TaskFlowBuilderPage(initialDraft: draft)),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Template draft'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Editable template'), findsOneWidget);
    expect(
        tester
            .widget<DropdownButton<IOType>>(find.byType(DropdownButton<IOType>))
            .value,
        IOType.video);
    expect(
        tester
            .widget<FlowBlockCard>(find.byType(FlowBlockCard))
            .block
            .params['saveFolder'],
        'template-folder');
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
