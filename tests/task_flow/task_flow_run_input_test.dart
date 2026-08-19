import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _MockCatCatchNotifier extends Mock implements CatCatchNotifier {}

catcatch.CatCatchTask _failedTask(String id) => catcatch.CatCatchTask(
      id: id,
      url: 'https://example.com/v',
      expectedDurationSec: 0,
      title: '示例视频',
      status: catcatch.TaskStatus.failed,
      createdAt: DateTime(2026, 1, 1),
      steps: const [],
      error: '测试失败',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskFlowExecution inputDurationSec serialization', () {
    test('omitted from JSON when 0, round-trips when > 0', () {
      final without = TaskFlowExecution(
        flowId: 'f1',
        flowName: '流',
        inputText: 'https://example.com',
      );
      final mapWithout = without.toMap();
      expect(mapWithout.containsKey('inputDurationSec'), isFalse);
      expect(
        TaskFlowExecution.fromMap(mapWithout).inputDurationSec,
        0,
      );

      final withDuration = TaskFlowExecution(
        flowId: 'f1',
        flowName: '流',
        inputText: 'https://example.com',
        inputDurationSec: 125,
      );
      final mapWith = withDuration.toMap();
      expect(mapWith['inputDurationSec'], 125);
      expect(
        TaskFlowExecution.fromMap(mapWith).inputDurationSec,
        125,
      );
    });
  });

  group('TaskFlowExecutionService run-input fan-out', () {
    late ProviderContainer container;
    late TaskFlowExecutionService service;
    late _MockCatCatchNotifier catcatchNotifier;

    /// Captured (url, durationSec) pairs from catcatchNotifier.addTask.
    late List<(String, int)> addTaskCalls;

    String flowId = '';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      final flowNotifier = TaskFlowNotifier();
      flowId = flowNotifier.addFlow(
        name: '下载流程',
        blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)],
      );

      addTaskCalls = [];
      catcatchNotifier = _MockCatCatchNotifier();
      String? capturedTaskId;
      when(
        () => catcatchNotifier.addTask(
          any(),
          any(),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((inv) {
        addTaskCalls.add((
          inv.positionalArguments[0] as String,
          inv.positionalArguments[1] as int,
        ));
        capturedTaskId = inv.namedArguments[#taskId] as String;
        return capturedTaskId!;
      });
      // The executor polls for the task with the id it created — always
      // answer with a failed task so the block terminates fast.
      when(() => catcatchNotifier.state).thenAnswer(
        (_) => [_failedTask(capturedTaskId ?? 'stub')],
      );

      container = ProviderContainer(
        overrides: [
          taskFlowListProvider.overrideWith((ref) => flowNotifier),
          taskFlowExecutionsProvider.overrideWith(
            (ref) => TaskFlowExecutionNotifier(),
          ),
          catcatchTasksProvider.overrideWith((ref) => catcatchNotifier),
        ],
      );
      service = container.read(taskFlowExecutionServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test(
        'startFlowMany creates one execution per input, each carrying its '
        'own input text and duration', () async {
      await service.startFlowMany(flowId, [
        const FlowRunInput(text: 'https://a.com/v', durationSec: 90),
        const FlowRunInput(text: 'https://b.com/v'),
      ]);

      final executions = container.read(taskFlowExecutionsProvider);
      expect(executions.length, 2);
      // The notifier prepends new executions — match by input text.
      final byText = {for (final e in executions) e.inputText: e};
      expect(byText['https://a.com/v']!.inputDurationSec, 90);
      expect(byText['https://b.com/v']!.inputDurationSec, 0);
    });

    test(
        'the per-run duration reaches the catcatch block and overrides the '
        'block default; zero falls back to the block config', () async {
      // Block configured with a 300s duration filter.
      flowId = container.read(taskFlowListProvider.notifier).addFlow(
        name: '带时长的下载流程',
        blocks: [
          TaskFlowBlock(
            typeKey: BlockType.catcatch,
            params: const {'durationSec': 300},
          ),
        ],
      );

      await service.startFlowMany(flowId, [
        const FlowRunInput(text: 'https://a.com/v', durationSec: 125),
        const FlowRunInput(text: 'https://b.com/v'),
      ]);

      expect(addTaskCalls.length, 2);
      // Per-run duration (125) beats the block-configured 300.
      expect(addTaskCalls[0], ('https://a.com/v', 125));
      // No per-run duration → the block-configured 300 is used.
      expect(addTaskCalls[1], ('https://b.com/v', 300));
    });

    test(
        'startFlow keeps the single-input API and preserves durationSec '
        '(task-list retry path)', () async {
      await service.startFlow(
        flowId,
        'https://a.com/v',
        durationSec: 300,
      );

      final executions = container.read(taskFlowExecutionsProvider);
      expect(executions.length, 1);
      expect(executions[0].inputText, 'https://a.com/v');
      expect(executions[0].inputDurationSec, 300);
    });
  });
}
