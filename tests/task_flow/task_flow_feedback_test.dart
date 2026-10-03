import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/unified_task_list/task_flow_card.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/pages/task_flow_run_page.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _Executions extends TaskFlowExecutionNotifier {
  @override
  Future<bool> persist() async => true;

  void load(List<TaskFlowExecution> executions) => state = executions;
}

class _Control implements TaskFlowExecutionService {
  final _Executions executions;
  final batches = <String>[];
  bool cancellationFails = false;
  _Control(this.executions);

  @override
  Future<void> cancelBatch(String batchId) async {
    batches.add(batchId);
    if (cancellationFails) {
      throw const TaskFlowPersistenceException('批次取消状态无法保存');
    }
    executions.state = executions.state
        .map((execution) => execution.batchId == batchId
            ? execution.copyWith(status: FlowExecutionStatus.cancelled)
            : execution)
        .toList();
  }

  @override
  void cancelActiveRequest(String id) {}

  @override
  Future<void> cancelExecution(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final status in [
    FlowExecutionStatus.failed,
    FlowExecutionStatus.interrupted,
  ]) {
    testWidgets('initially ${status.name} flow displays its failure reason',
        (tester) async {
      final executions = _Executions();
      final execution = TaskFlowExecution(
        id: 'initial-${status.name}',
        flowId: 'f',
        flowName: 'Initial failure',
        status: status,
        error: '无法读取输入文件',
      );
      executions.load([execution]);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            taskFlowExecutionsProvider.overrideWith((ref) => executions),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: TaskFlowCard(
                      execution: status == FlowExecutionStatus.interrupted
                          ? execution.copyWith(
                              status: FlowExecutionStatus.running)
                          : execution)))));
      expect(find.text('无法读取输入文件'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'failed transition keeps expanded detail and counts skipped separately',
      (tester) async {
    final executions = _Executions();
    final failedStep = FlowSubTask(
        blockTypeKey: 'chat',
        blockLabel: 'Assistant',
        subTaskId: 'pending_chat_0',
        subTaskType: 'background');
    final unrunStep = FlowSubTask(
        blockTypeKey: 'tts',
        blockLabel: 'Speech',
        subTaskId: 'pending_tts_1',
        subTaskType: 'synthesis',
        status: TaskStatus.waiting);
    final id = executions.addExecution(
        flowId: 'f', flowName: 'Run', subTasks: [failedStep, unrunStep]);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: TaskFlowCard(execution: executions.state.single)))));
    await tester.tap(find.text('Run'));
    await tester.pump();
    executions.updateSubTaskStatus(id, failedStep.id, TaskStatus.failed);
    executions.failExecution(id, error: 'Network unavailable');
    await tester.pump();
    expect(find.text('Network unavailable'), findsOneWidget);
    expect(find.textContaining('1 个失败'), findsOneWidget);
    expect(find.textContaining('1 个跳过'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('this run shows only submitted IDs and handles removed records',
      (tester) async {
    final executions = _Executions();
    final id = executions.addExecution(flowId: 'f', flowName: 'Submitted');
    executions.completeExecution(id);
    final other = executions.addExecution(flowId: 'f', flowName: 'Other');
    executions.completeExecution(other);
    await tester.pumpWidget(ProviderScope(overrides: [
      taskFlowExecutionsProvider.overrideWith((ref) => executions),
    ], child: MaterialApp(home: TaskFlowRunPage(executionIds: [id]))));
    await tester.pump();
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    executions.removeExecution(id);
    await tester.pump();
    expect(find.text('本次运行记录已清除'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deleting an active batch record cancels its waiting siblings',
      (tester) async {
    final executions = _Executions();
    final active = TaskFlowExecution(
        id: 'active',
        flowId: 'f',
        flowName: 'Active',
        batchId: 'batch',
        status: FlowExecutionStatus.running);
    final waiting = TaskFlowExecution(
        id: 'waiting',
        flowId: 'f',
        flowName: 'Waiting',
        batchId: 'batch',
        status: FlowExecutionStatus.waiting);
    executions.state = [active, waiting];
    final control = _Control(executions);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionServiceProvider.overrideWithValue(control),
        ],
        child: MaterialApp(
            home: Scaffold(body: TaskFlowCard(execution: active)))));
    await tester.tap(find.text('Active'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();
    expect(control.batches, ['batch']);
    expect(executions.state.single.id, waiting.id);
    expect(executions.state.single.status, FlowExecutionStatus.cancelled);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear all preserves flow records when cancellation cannot save',
      (tester) async {
    final executions = _Executions();
    executions.state = [
      TaskFlowExecution(
          id: 'queued',
          flowId: 'f',
          flowName: 'Queued',
          batchId: 'batch',
          status: FlowExecutionStatus.waiting)
    ];
    final control = _Control(executions)..cancellationFails = true;
    await tester.pumpWidget(ProviderScope(overrides: [
      taskFlowExecutionsProvider.overrideWith((ref) => executions),
      taskFlowExecutionServiceProvider.overrideWithValue(control),
      taskListLastReadProvider.overrideWith((ref) => DateTime.now()),
    ], child: const MaterialApp(home: UnifiedTaskListPage())));
    await tester.pump();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除所有'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(control.batches, ['batch']);
    expect(executions.state.single.id, 'queued');
    expect(find.textContaining('批次取消状态无法保存'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });
}
