import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/unified_task_list/task_flow_card.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/widgets/block_editor_dialog.dart';

class _Flows extends TaskFlowNotifier {
  @override
  Future<bool> persist() async => true;
}

class _Executions extends TaskFlowExecutionNotifier {
  @override
  Future<bool> persist() async => true;
}

class _Entries extends ProviderEntriesNotifier {
  _Entries(ProviderEntriesState entries) {
    state = entries;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('normal start opens the missing model step without starting work',
      (tester) async {
    final flows = _Flows();
    final flow = TaskFlowDefinition(
        name: 'Flow', blocks: [TaskFlowBlock(typeKey: BlockType.tts)]);
    await flows.saveFlow(flow);
    final executions = _Executions();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          taskFlowListProvider.overrideWith((ref) => flows),
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
        ],
        child: MaterialApp(
            home: TaskFlowBuilderPage(flowId: flow.id, startInRunMode: true))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Hello');
    await tester.pump();
    await tester.ensureVisible(find.text('开始任务流'));
    await tester.tap(find.text('开始任务流'));
    await tester.pumpAndSettle();
    expect(find.text('语音合成 设置'), findsOneWidget);
    expect(executions.state, isEmpty);
    expect(find.text('任务流已启动'), findsNothing);
  });

  testWidgets(
      'history retry opens the same invalid step and preserves its record',
      (tester) async {
    final flows = _Flows();
    final flow = TaskFlowDefinition(name: 'Flow', blocks: [
      TaskFlowBlock(typeKey: BlockType.chat, params: {'assistantId': 'deleted'})
    ]);
    await flows.saveFlow(flow);
    final executions = _Executions();
    final id = executions.addExecution(
        flowId: flow.id, flowName: flow.name, inputText: 'Hello');
    executions.failExecution(id, error: 'Previous failure');
    await tester.pumpWidget(ProviderScope(
        overrides: [
          taskFlowListProvider.overrideWith((ref) => flows),
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: TaskFlowCard(execution: executions.state.single)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();
    expect(find.text('助手对话 设置'), findsOneWidget);
    expect(executions.state, hasLength(1));
    expect(executions.state.single.id, id);
  });

  testWidgets(
      'editor never substitutes a missing model when confirming settings',
      (tester) async {
    final config = ProviderConfigItem(
        host: 'https://example.com',
        key: 'k',
        models: [ModelConfig(name: 'Replacement', modelId: 'm')]);
    final entries = ProviderEntriesState(entries: [
      ProviderEntry(name: 'TTS', type: 'tts', configs: [config])
    ]);
    final missing = {'configId': config.id, 'modelId': 'deleted-model'};
    TaskFlowBlock? result;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith((ref) => _Entries(entries)),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                          onPressed: () async {
                            result = await showBlockEditorDialog(context,
                                block: TaskFlowBlock(
                                    typeKey: BlockType.tts,
                                    params: {
                                      'modelRef': missing,
                                      'modelIndex': 0
                                    }));
                          },
                          child: const Text('Open'),
                        ))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('模型未选择或已失效，请重新选择'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result!.params['modelRef'], missing);
    expect(result!.params.containsKey('modelIndex'), isFalse);
  });
}
