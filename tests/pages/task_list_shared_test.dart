import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/task_list_page.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/pages/task_flow_run_page.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

class _RecordingTasks extends TaskListNotifier {
  _RecordingTasks(super.ref, List<SynthesisTask> tasks) {
    state = tasks;
  }

  final calls = <String>[];

  @override
  void pauseTask(String taskId) => calls.add('pause:$taskId');

  @override
  void resumeTask(String taskId,
          {ProviderConfigItem? providerConfig, ModelConfig? modelConfig}) =>
      calls.add('resume:$taskId');

  @override
  void removeTask(String taskId) => calls.add('remove:$taskId');
}

class _SeededExecutions extends TaskFlowExecutionNotifier {
  _SeededExecutions(List<TaskFlowExecution> flows) {
    state = flows;
  }

  void replace(List<TaskFlowExecution> flows) => state = flows;
}

SynthesisTask _task(String id, TaskStatus status) => SynthesisTask(
      id: id,
      title: '任务 $id',
      status: status,
      text: '测试文本',
      providerConfig: ProviderConfigItem(
        providerName: '测试供应商',
        host: 'https://example.com',
        key: 'test',
      ),
      modelConfig: ModelConfig(name: '测试模型', modelId: 'test-model'),
    );

TaskFlowExecution _flow(String id, String name, SynthesisTask child) =>
    TaskFlowExecution(
      id: id,
      flowId: 'definition-$id',
      flowName: name,
      status: child.status == TaskStatus.paused
          ? FlowExecutionStatus.paused
          : FlowExecutionStatus.running,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'tts',
          blockLabel: '语音合成',
          subTaskId: child.id,
          subTaskType: 'tts',
          status: child.status,
        ),
      ],
    );

Future<_RecordingTasks> _pumpList(WidgetTester tester,
    List<SynthesisTask> tasks, List<TaskFlowExecution> flows,
    {FlowExecutionRestoreStatus restoreStatus =
        FlowExecutionRestoreStatus.ready}) async {
  late _RecordingTasks notifier;
  final executions = _SeededExecutions(flows);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskListProvider.overrideWith((ref) {
          notifier = _RecordingTasks(ref, tasks);
          return notifier;
        }),
        taskFlowExecutionsProvider.overrideWith((ref) => executions),
        taskFlowExecutionRestoreStatusProvider
            .overrideWith((ref) => restoreStatus),
      ],
      child: const MaterialApp(home: TaskListPage()),
    ),
  );
  await tester.pump();
  return notifier;
}

void main() {
  testWidgets('task controls stay locked until flow ownership is restored',
      (tester) async {
    final flowChild = _task('flow-child', TaskStatus.paused);
    final standalone = _task('standalone', TaskStatus.paused);
    final notifier = await _pumpList(tester, [flowChild, standalone], [],
        restoreStatus: FlowExecutionRestoreStatus.restoring);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(TaskListPage)));
    final executions = container.read(taskFlowExecutionsProvider.notifier)
        as _SeededExecutions;

    expect(find.byTooltip('正在确认任务归属'), findsNWidgets(2));
    expect(find.text('继续'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    executions.replace([_flow('restored-run', '恢复的任务流', flowChild)]);
    await tester.pump();
    expect(find.text('查看任务流'), findsNothing);
    expect(find.text('继续'), findsNothing);

    container.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
        FlowExecutionRestoreStatus.ready;
    await tester.pump();
    expect(find.text('查看任务流'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(notifier.calls, isEmpty);

    container.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
        FlowExecutionRestoreStatus.failed;
    await tester.pump();
    expect(find.byTooltip('任务流记录读取失败，操作暂不可用'), findsNWidgets(2));
    expect(find.text('继续'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('unified list waits for flow ownership before showing task cards',
      (tester) async {
    final flowChild = _task('flow-child', TaskStatus.paused);
    final executions = _SeededExecutions([]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        taskListProvider
            .overrideWith((ref) => _RecordingTasks(ref, [flowChild])),
        taskFlowExecutionsProvider.overrideWith((ref) => executions),
        taskFlowExecutionRestoreStatusProvider
            .overrideWith((ref) => FlowExecutionRestoreStatus.restoring),
      ],
      child: const MaterialApp(home: UnifiedTaskListPage()),
    ));
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(UnifiedTaskListPage)));

    expect(find.text('正在恢复任务流记录…'), findsOneWidget);
    expect(find.text('任务 flow-child'), findsNothing);
    expect(
        tester
            .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>))
            .enabled,
        isFalse);
    executions.replace([_flow('restored-run', '恢复的任务流', flowChild)]);
    await tester.pump();
    expect(find.text('正在恢复任务流记录…'), findsOneWidget);

    container.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
        FlowExecutionRestoreStatus.ready;
    await tester.pump();
    expect(find.text('恢复的任务流'), findsOneWidget);
    expect(find.text('任务 flow-child'), findsNothing);
    expect(
        tester
            .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>))
            .enabled,
        isTrue);
  });

  testWidgets('running flow child opens its own run without child controls',
      (tester) async {
    final child = _task('flow-child', TaskStatus.running);
    final notifier = await _pumpList(tester, [
      child
    ], [
      _flow('target-run', '目标流程', child),
      TaskFlowExecution(id: 'other-run', flowId: 'other', flowName: '其他流程'),
    ]);

    expect(find.text('查看任务流'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.text('查看任务流'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(TaskFlowRunPage), findsOneWidget);
    expect(find.text('目标流程'), findsOneWidget);
    expect(find.text('其他流程'), findsNothing);
    expect(notifier.calls, isEmpty);
  });

  testWidgets('paused flow child has no direct resume or removal',
      (tester) async {
    final child = _task('paused-child', TaskStatus.paused);
    final notifier =
        await _pumpList(tester, [child], [_flow('paused-run', '已暂停流程', child)]);

    expect(find.text('查看任务流'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(notifier.calls, isEmpty);
  });

  testWidgets('ordinary running and paused tasks keep their controls',
      (tester) async {
    final running = _task('standalone-running', TaskStatus.running);
    final paused = _task('standalone-paused', TaskStatus.paused);
    final notifier = await _pumpList(tester, [running, paused], []);

    expect(find.text('查看任务流'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text('任务 standalone-running'),
        matching: find.byType(Card),
      ),
      matching: find.byType(PopupMenuButton<String>),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(notifier.calls, ['pause:standalone-running']);

    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(notifier.calls, [
      'pause:standalone-running',
      'resume:standalone-paused',
    ]);

    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text('任务 standalone-paused'),
        matching: find.byType(Card),
      ),
      matching: find.byType(PopupMenuButton<String>),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('清除任务'));
    await tester.pump();
    expect(notifier.calls, [
      'pause:standalone-running',
      'resume:standalone-paused',
      'remove:standalone-paused',
    ]);
  });
}
