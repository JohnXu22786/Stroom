// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/pages/unified_task_list/task_flow_card.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/models/flow_launch_snapshot.dart';
import 'package:stroom/task_flow/pages/task_flow_run_page.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _FeedbackDocuments extends PathProviderPlatform {
  _FeedbackDocuments(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _Executions extends TaskFlowExecutionNotifier {
  bool persistenceFails = false;
  bool removalPersistenceFails = false;
  int persistAttempts = 0;
  int removalPersistAttempts = 0;
  List<TaskFlowExecution> durable = [];

  @override
  Future<bool> persist() async {
    persistAttempts++;
    if (persistenceFails) return false;
    durable = List.of(executions);
    return true;
  }

  @override
  Future<bool> persistSnapshot(List<TaskFlowExecution> snapshot) async {
    removalPersistAttempts++;
    if (removalPersistenceFails) return false;
    durable = List.of(snapshot);
    return true;
  }

  void load(List<TaskFlowExecution> executions) => state = executions;
}

class _Backgrounds extends BackgroundTaskNotifier {
  bool removalPersistenceFails = false;
  int removalPersistAttempts = 0;
  List<BackgroundTask> durable = [];

  List<BackgroundTask> get tasks => state;

  void load(List<BackgroundTask> tasks) {
    state = tasks;
    durable = List.of(tasks);
  }

  @override
  void removeTask(String id) => state = state.where((t) => t.id != id).toList();

  @override
  Future<bool> removeTasksPersisted(Iterable<String> ids) async {
    removalPersistAttempts++;
    if (removalPersistenceFails) return false;
    state = state.where((t) => !ids.contains(t.id)).toList();
    durable = List.of(state);
    return true;
  }
}

class _Control implements TaskFlowExecutionService {
  final _Executions executions;
  final batches = <String>[];
  final singles = <String>[];
  bool cancellationFails = false;
  Completer<void>? batchGate;

  _Control(this.executions);

  @override
  Future<void> cancelBatch(String batchId) async {
    batches.add(batchId);
    executions.load([
      for (final execution in executions.executions)
        execution.batchId == batchId && !execution.isTerminal
            ? execution.copyWith(status: FlowExecutionStatus.cancelled)
            : execution,
    ]);
    if (batchGate case final gate?) await gate.future;
    if (cancellationFails) {
      throw const TaskFlowPersistenceException('批次取消状态无法保存');
    }
  }

  @override
  Future<void> cancelExecution(String id) async {
    if (executions.execution(id)?.isTerminal ?? true) return;
    singles.add(id);
    executions.load([
      for (final execution in executions.executions)
        execution.id == id
            ? execution.copyWith(status: FlowExecutionStatus.cancelled)
            : execution,
    ]);
    if (cancellationFails) {
      throw const TaskFlowPersistenceException('取消状态无法保存');
    }
  }

  @override
  void cancelActiveRequest(String id) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final terminalStatus in [
    FlowExecutionStatus.completed,
    FlowExecutionStatus.failed
  ]) {
    testWidgets(
        'clear ${terminalStatus.name} durably cancels unfinished batch siblings',
        (tester) async {
      final directory = (await tester
          .runAsync(() => Directory.systemTemp.createTemp('terminal_clear_')))!;
      final previousDocuments = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FeedbackDocuments(directory.path);
      AppStorage.resetCache();
      final executions = TaskFlowExecutionNotifier();
      final terminal = TaskFlowExecution(
          id: 'terminal',
          flowId: 'f',
          flowName: 'First',
          batchId: 'batch',
          status: terminalStatus);
      final sibling = TaskFlowExecution(
          id: 'sibling',
          flowId: 'f',
          flowName: 'Second',
          batchId: 'batch',
          status: FlowExecutionStatus.waiting,
          queued: true);
      try {
        await tester.runAsync(() async {
          expect(await executions.addExecutions([terminal, sibling]), isTrue);
        });
        await tester.pumpWidget(ProviderScope(overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
        ], child: const MaterialApp(home: UnifiedTaskListPage())));
        if (terminalStatus == FlowExecutionStatus.completed) {
          await _clearCompleted(tester);
        } else {
          await _clearFailed(tester);
        }
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (executions.execution(terminal.id) != null &&
            DateTime.now().isBefore(deadline)) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump();
        }
        expect(executions.execution(terminal.id), isNull);
        expect(executions.execution(sibling.id)?.status,
            FlowExecutionStatus.cancelled);
        expect(executions.execution(sibling.id)?.queued, isFalse);
        await tester.runAsync(() async {
          final file = File('${directory.path}/task_flows/executions.json');
          final saved = (jsonDecode(await file.readAsString()) as List).single;
          expect(saved['id'], sibling.id);
          expect(saved['status'], FlowExecutionStatus.cancelled.name);
          final restored = TaskFlowExecutionNotifier();
          try {
            expect(await restored.restoreFromPersistence(), isTrue);
            expect(restored.executions.single.status,
                FlowExecutionStatus.cancelled);
          } finally {
            restored.dispose();
          }
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        if (executions.mounted) executions.dispose();
        PathProviderPlatform.instance = previousDocuments;
        AppStorage.resetCache();
        await tester.runAsync(() => directory.delete(recursive: true));
      }
    });
  }

  testWidgets('completed card can cancel its unfinished batch', (tester) async {
    final completed = TaskFlowExecution(
        id: 'completed',
        flowId: 'f',
        flowName: 'Completed',
        batchId: 'batch',
        status: FlowExecutionStatus.completed);
    final waiting = TaskFlowExecution(
        id: 'waiting',
        flowId: 'f',
        flowName: 'Waiting',
        batchId: 'batch',
        status: FlowExecutionStatus.waiting);
    final executions = _Executions()..load([completed, waiting]);
    final control = _Control(executions);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionServiceProvider.overrideWithValue(control),
        ],
        child: MaterialApp(
            home: Scaffold(body: TaskFlowCard(execution: completed)))));
    await tester.tap(find.text('Completed'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '取消整个批次'));
    await tester.pump();
    expect(control.batches, ['batch']);
    expect(executions.execution(completed.id)?.status,
        FlowExecutionStatus.completed);
    expect(executions.execution(waiting.id)?.status,
        FlowExecutionStatus.cancelled);
    expect(find.text('取消整个批次'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final restoreStatus in [
    FlowExecutionRestoreStatus.restoring,
    FlowExecutionRestoreStatus.failed,
  ]) {
    testWidgets('run page waits for ${restoreStatus.name} ownership',
        (tester) async {
      final executions = _Executions()
        ..load([
          TaskFlowExecution(
              id: 'run',
              flowId: 'f',
              flowName: 'Run',
              batchId: 'batch',
              status: FlowExecutionStatus.waiting),
        ]);
      final container = ProviderContainer(overrides: [
        taskFlowExecutionsProvider.overrideWith((ref) => executions),
        taskFlowExecutionRestoreStatusProvider
            .overrideWith((ref) => restoreStatus),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child:
              const MaterialApp(home: TaskFlowRunPage(executionIds: ['run']))));
      expect(find.byType(TaskFlowCard), findsNothing);
      expect(find.text('取消整个批次'), findsNothing);
      expect(
          find.textContaining(
              restoreStatus == FlowExecutionRestoreStatus.restoring
                  ? '正在恢复'
                  : '读取失败'),
          findsOneWidget);
      container.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
          FlowExecutionRestoreStatus.ready;
      await tester.pump();
      expect(find.byType(TaskFlowCard), findsOneWidget);
      expect(find.text('取消整个批次'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    for (final status in [
      FlowExecutionStatus.running,
      FlowExecutionStatus.paused,
      FlowExecutionStatus.failed,
      FlowExecutionStatus.interrupted
    ]) {
      testWidgets(
          '${status.name} card locks actions while ${restoreStatus.name}',
          (tester) async {
        final execution = TaskFlowExecution(
            id: 'run',
            flowId: 'f',
            flowName: 'Run',
            batchId: 'batch',
            status: status,
            snapshot: FlowLaunchSnapshot.fromMap({}));
        final executions = _Executions()..load([execution]);
        final container = ProviderContainer(overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionRestoreStatusProvider
              .overrideWith((ref) => restoreStatus),
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                home: Scaffold(body: TaskFlowCard(execution: execution)))));
        if (status == FlowExecutionStatus.running ||
            status == FlowExecutionStatus.paused) {
          await tester.tap(find.text('Run'));
          await tester.pump();
        }
        final delete = find.widgetWithText(TextButton, '删除');
        expect(tester.widget<TextButton>(delete).onPressed, isNull);
        for (final label in [
          '暂停流程',
          '继续流程',
          '从中断步骤继续',
          '取消流程',
          '取消整个批次',
          '重试'
        ]) {
          expect(find.text(label), findsNothing);
        }
        container.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
            FlowExecutionRestoreStatus.ready;
        await tester.pump();
        expect(tester.widget<TextButton>(delete).onPressed, isNotNull);
        if (status == FlowExecutionStatus.running) {
          expect(find.text('暂停流程'), findsOneWidget);
        }
        if (status == FlowExecutionStatus.paused) {
          expect(find.text('继续流程'), findsOneWidget);
        }
        if (status == FlowExecutionStatus.failed ||
            status == FlowExecutionStatus.interrupted) {
          expect(find.text('从中断步骤继续'), findsOneWidget);
          expect(find.text('重试'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

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
                body: TaskFlowCard(execution: executions.executions.single)))));
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
    executions.load([active, waiting]);
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
    expect(executions.executions.single.id, waiting.id);
    expect(executions.executions.single.status, FlowExecutionStatus.cancelled);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear all preserves flow records when cancellation cannot save',
      (tester) async {
    final executions = _Executions();
    executions.load([
      TaskFlowExecution(
          id: 'queued',
          flowId: 'f',
          flowName: 'Queued',
          batchId: 'batch',
          status: FlowExecutionStatus.waiting)
    ]);
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
    expect(executions.executions.single.id, 'queued');
    expect(find.textContaining('批次取消状态无法保存'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('clear all cancels active runs before removing records', (
    tester,
  ) async {
    final executions = _Executions();
    executions.load([
      TaskFlowExecution(
        id: 'batch-one',
        flowId: 'f',
        flowName: 'First',
        batchId: 'batch',
        status: FlowExecutionStatus.waiting,
      ),
      TaskFlowExecution(
        id: 'batch-two',
        flowId: 'f',
        flowName: 'Second',
        batchId: 'batch',
        status: FlowExecutionStatus.waiting,
      ),
      TaskFlowExecution(
        id: 'single',
        flowId: 'f',
        flowName: 'Single',
        status: FlowExecutionStatus.waiting,
      ),
    ]);
    final control = _Control(executions);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionServiceProvider.overrideWithValue(control),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _clearAll(tester);
    expect(control.batches, ['batch']);
    expect(control.singles, ['single']);
    expect(executions.executions, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear all retains records when cancellation cannot persist', (
    tester,
  ) async {
    final executions = _Executions();
    executions.load([
      TaskFlowExecution(
        id: 'queued',
        flowId: 'f',
        flowName: 'Queued',
        batchId: 'batch',
        status: FlowExecutionStatus.waiting,
      ),
    ]);
    executions.persistenceFails = true;
    final control = _Control(executions)..cancellationFails = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionServiceProvider.overrideWithValue(control),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _clearAll(tester);
    expect(control.batches, ['batch']);
    expect(executions.executions.single.id, 'queued');
    expect(find.textContaining('批次取消状态无法保存'), findsOneWidget);
    control.cancellationFails = false;
    await _clearAll(tester);
    expect(control.batches, ['batch']);
    expect(executions.executions.single.id, 'queued');
    expect(find.textContaining('取消状态无法保存'), findsOneWidget);
    expect(executions.persistAttempts, 1);
    executions.persistenceFails = false;
    await _clearAll(tester);
    expect(executions.executions, isEmpty);
    expect(executions.persistAttempts, greaterThanOrEqualTo(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear all removes a child created while another batch cancels', (
    tester,
  ) async {
    final executions = _Executions();
    executions.load([
      TaskFlowExecution(
        id: 'batch',
        flowId: 'f',
        flowName: 'Batch',
        batchId: 'batch-id',
        status: FlowExecutionStatus.waiting,
      ),
      TaskFlowExecution(
        id: 'solo',
        flowId: 'f',
        flowName: 'Solo',
        status: FlowExecutionStatus.running,
      ),
    ]);
    final backgrounds = _Backgrounds();
    final gate = Completer<void>();
    final control = _Control(executions)..batchGate = gate;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionServiceProvider.overrideWithValue(control),
          backgroundTasksProvider.overrideWith((ref) => backgrounds),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _clearAll(tester);
    expect(control.batches, ['batch-id']);

    // The second run finishes and creates a child after clear-all began.
    // Cleanup must use its latest execution and child-task state.
    backgrounds.load([
      BackgroundTask(
        id: 'late-child',
        type: BackgroundTaskType.chat,
        title: 'Late child',
        status: TaskStatus.completed,
      ),
    ]);
    executions.addSubTask(
      'solo',
      FlowSubTask(
        blockTypeKey: 'chat',
        blockLabel: 'Late child',
        subTaskId: 'late-child',
        subTaskType: 'background',
        status: TaskStatus.completed,
      ),
    );
    executions.completeExecution('solo');
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(control.singles, isEmpty);
    expect(executions.executions, isEmpty);
    expect(backgrounds.tasks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear all keeps records and children when removal write fails', (
    tester,
  ) async {
    final executions = _Executions()..removalPersistenceFails = true;
    executions.load([
      TaskFlowExecution(
        id: 'finished',
        flowId: 'f',
        flowName: 'Finished',
        status: FlowExecutionStatus.completed,
        subTasks: [
          FlowSubTask(
            blockTypeKey: 'chat',
            blockLabel: 'Child',
            subTaskId: 'child',
            subTaskType: 'background',
            status: TaskStatus.completed,
          ),
        ],
      ),
    ]);
    final backgrounds = _Backgrounds()
      ..load([
        BackgroundTask(
          id: 'child',
          type: BackgroundTaskType.chat,
          title: 'Child',
          status: TaskStatus.completed,
        ),
      ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          backgroundTasksProvider.overrideWith((ref) => backgrounds),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _clearAll(tester);
    expect(executions.removalPersistAttempts, 1);
    expect(executions.executions.single.id, 'finished');
    expect(executions.durable.single.id, 'finished');
    expect(backgrounds.tasks, isEmpty);
    expect(backgrounds.durable, isEmpty);
    expect(find.textContaining('记录删除状态无法保存'), findsOneWidget);

    executions.removalPersistenceFails = false;
    await _clearAll(tester);
    expect(executions.executions, isEmpty);
    expect(executions.durable, isEmpty);
    expect(backgrounds.tasks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear all keeps parent when a child removal write fails', (
    tester,
  ) async {
    final executions = _Executions();
    executions.load([
      TaskFlowExecution(
        id: 'finished',
        flowId: 'f',
        flowName: 'Finished',
        status: FlowExecutionStatus.completed,
        subTasks: [
          FlowSubTask(
            blockTypeKey: 'chat',
            blockLabel: 'Child',
            subTaskId: 'child',
            subTaskType: 'background',
            status: TaskStatus.completed,
          ),
        ],
      ),
    ]);
    final backgrounds = _Backgrounds()
      ..load([
        BackgroundTask(
          id: 'child',
          type: BackgroundTaskType.chat,
          title: 'Child',
          status: TaskStatus.completed,
        ),
      ])
      ..removalPersistenceFails = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          backgroundTasksProvider.overrideWith((ref) => backgrounds),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _clearAll(tester);
    expect(backgrounds.removalPersistAttempts, 1);
    expect(backgrounds.tasks.single.id, 'child');
    expect(backgrounds.durable.single.id, 'child');
    expect(executions.executions.single.id, 'finished');
    expect(executions.durable.single.id, 'finished');
    expect(executions.removalPersistAttempts, 0);
    expect(find.textContaining('后台子任务删除状态无法保存'), findsOneWidget);

    backgrounds.removalPersistenceFails = false;
    await _clearAll(tester);
    expect(backgrounds.tasks, isEmpty);
    expect(backgrounds.durable, isEmpty);
    expect(executions.executions, isEmpty);
    expect(executions.durable, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear completed retries child write after restart', (
    tester,
  ) async {
    final finished = TaskFlowExecution(
      id: 'finished',
      flowId: 'f',
      flowName: 'Finished',
      status: FlowExecutionStatus.completed,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: 'Finished child',
          subTaskId: 'finished-child',
          subTaskType: 'background',
          status: TaskStatus.completed,
        ),
      ],
    );
    final active = TaskFlowExecution(
      id: 'active',
      flowId: 'f',
      flowName: 'Active',
      status: FlowExecutionStatus.running,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: 'Active child',
          subTaskId: 'active-child',
          subTaskType: 'background',
          status: TaskStatus.completed,
        ),
      ],
    );
    final stopped = TaskFlowExecution(
      id: 'stopped',
      flowId: 'f',
      flowName: 'Stopped',
      status: FlowExecutionStatus.cancelled,
    );
    final executions = _Executions()
      ..load([finished, active, stopped])
      ..durable = [finished, active, stopped];
    final backgrounds = _Backgrounds()
      ..load([
        for (final id in ['finished-child', 'active-child', 'standalone'])
          BackgroundTask(
            id: id,
            type: BackgroundTaskType.chat,
            title: id,
            status: TaskStatus.completed,
          ),
      ])
      ..removalPersistenceFails = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          backgroundTasksProvider.overrideWith((ref) => backgrounds),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _clearCompleted(tester);
    expect(executions.removalPersistAttempts, 0);
    expect(executions.durable.map((e) => e.id),
        containsAll(['finished', 'active', 'stopped']));
    expect(backgrounds.durable.map((t) => t.id),
        containsAll(['finished-child', 'active-child', 'standalone']));
    expect(find.textContaining('后台子任务删除状态无法保存'), findsOneWidget);

    // Recreate providers from their saved snapshots, as an app restart does.
    final restoredExecutions = _Executions()
      ..load(List.of(executions.durable))
      ..durable = List.of(executions.durable);
    final restoredBackgrounds = _Backgrounds()
      ..load(List.of(backgrounds.durable));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => restoredExecutions),
          backgroundTasksProvider.overrideWith((ref) => restoredBackgrounds),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _clearCompleted(tester);
    expect(restoredExecutions.executions.map((e) => e.id),
        containsAll(['active', 'stopped']));
    expect(restoredExecutions.executions.length, 2);
    expect(restoredBackgrounds.tasks.map((t) => t.id), ['active-child']);
    expect(restoredBackgrounds.durable.map((t) => t.id), ['active-child']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear failed keeps saved parent after removal write fails', (
    tester,
  ) async {
    final failed = TaskFlowExecution(
      id: 'failed',
      flowId: 'f',
      flowName: 'Failed',
      status: FlowExecutionStatus.failed,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: 'Successful child',
          subTaskId: 'child',
          subTaskType: 'background',
          status: TaskStatus.completed,
        ),
      ],
    );
    final completed = TaskFlowExecution(
      id: 'completed',
      flowId: 'f',
      flowName: 'Completed',
      status: FlowExecutionStatus.completed,
    );
    final executions = _Executions()
      ..load([failed, completed])
      ..durable = [failed, completed]
      ..removalPersistenceFails = true;
    final backgrounds = _Backgrounds()
      ..load([
        BackgroundTask(
          id: 'child',
          type: BackgroundTaskType.chat,
          title: 'Child',
          status: TaskStatus.completed,
        ),
        BackgroundTask(
          id: 'standalone-failed',
          type: BackgroundTaskType.chat,
          title: 'Standalone failed',
          status: TaskStatus.failed,
        ),
      ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          backgroundTasksProvider.overrideWith((ref) => backgrounds),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _openClearFailed(tester);
    // The list is read on confirmation, not when the menu opens.
    final later = TaskFlowExecution(
      id: 'later',
      flowId: 'f',
      flowName: 'Later failure',
      status: FlowExecutionStatus.failed,
    );
    executions.load([failed, completed, later]);
    executions.durable = [failed, completed, later];
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(executions.removalPersistAttempts, 1);
    expect(executions.executions.map((e) => e.id),
        containsAll(['failed', 'completed', 'later']));
    expect(executions.durable.map((e) => e.id),
        containsAll(['failed', 'completed', 'later']));
    expect(backgrounds.durable, isEmpty);
    expect(find.textContaining('记录删除状态无法保存'), findsOneWidget);

    final restoredExecutions = _Executions()
      ..load(List.of(executions.durable))
      ..durable = List.of(executions.durable);
    final restoredBackgrounds = _Backgrounds()
      ..load(List.of(backgrounds.durable));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => restoredExecutions),
          backgroundTasksProvider.overrideWith((ref) => restoredBackgrounds),
        ],
        child: const MaterialApp(home: UnifiedTaskListPage()),
      ),
    );
    await _clearFailed(tester);
    expect(restoredExecutions.executions.map((e) => e.id), ['completed']);
    expect(restoredBackgrounds.tasks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deleting a completed batch card cancels unfinished siblings', (
    tester,
  ) async {
    final executions = _Executions();
    final active = TaskFlowExecution(
      id: 'active',
      flowId: 'f',
      flowName: 'Active',
      batchId: 'batch',
      status: FlowExecutionStatus.completed,
    );
    executions.load([
      active,
      TaskFlowExecution(
        id: 'waiting',
        flowId: 'f',
        flowName: 'Waiting',
        batchId: 'batch',
        status: FlowExecutionStatus.waiting,
      ),
    ]);
    final control = _Control(executions);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionServiceProvider.overrideWithValue(control),
        ],
        child: MaterialApp(
          home: Scaffold(body: TaskFlowCard(execution: active)),
        ),
      ),
    );
    await tester.tap(find.text('Active'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(control.batches, ['batch']);
    expect(executions.executions.single.id, 'waiting');
    expect(executions.executions.single.status, FlowExecutionStatus.cancelled);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('delete retry retains a cancelled record until it is saved', (
    tester,
  ) async {
    final executions = _Executions()..persistenceFails = true;
    final active = TaskFlowExecution(
      id: 'active',
      flowId: 'f',
      flowName: 'Active',
      status: FlowExecutionStatus.running,
    );
    executions.load([active]);
    final control = _Control(executions)..cancellationFails = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionServiceProvider.overrideWithValue(control),
        ],
        child: MaterialApp(
          home: Scaffold(body: TaskFlowCard(execution: active)),
        ),
      ),
    );
    await tester.tap(find.text('Active'));
    await tester.pump();
    await _deleteCard(tester);
    expect(control.singles, ['active']);
    expect(executions.executions.single.status, FlowExecutionStatus.cancelled);

    control.cancellationFails = false;
    await _deleteCard(tester);
    expect(control.singles, ['active']);
    expect(executions.executions.single.id, 'active');
    expect(find.textContaining('取消状态无法保存'), findsOneWidget);
    expect(executions.persistAttempts, 1);

    executions.persistenceFails = false;
    await _deleteCard(tester);
    expect(executions.executions, isEmpty);
    expect(executions.persistAttempts, greaterThanOrEqualTo(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('card delete keeps run and child when removal write fails', (
    tester,
  ) async {
    final executions = _Executions()..removalPersistenceFails = true;
    final active = TaskFlowExecution(
      id: 'active',
      flowId: 'f',
      flowName: 'Active',
      status: FlowExecutionStatus.waiting,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: 'Child',
          subTaskId: 'child',
          subTaskType: 'background',
          status: TaskStatus.completed,
        ),
      ],
    );
    executions.load([active]);
    final backgrounds = _Backgrounds()
      ..load([
        BackgroundTask(
          id: 'child',
          type: BackgroundTaskType.chat,
          title: 'Child',
          status: TaskStatus.completed,
        ),
      ]);
    final control = _Control(executions);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          taskFlowExecutionServiceProvider.overrideWithValue(control),
          backgroundTasksProvider.overrideWith((ref) => backgrounds),
        ],
        child: MaterialApp(
          home: Scaffold(body: TaskFlowCard(execution: active)),
        ),
      ),
    );
    await tester.tap(find.text('Active'));
    await tester.pump();
    await _deleteCard(tester);
    expect(control.singles, ['active']);
    expect(executions.removalPersistAttempts, 1);
    expect(executions.executions.single.status, FlowExecutionStatus.cancelled);
    expect(executions.durable.single.status, FlowExecutionStatus.cancelled);
    expect(backgrounds.tasks, isEmpty);
    expect(backgrounds.durable, isEmpty);
    expect(find.textContaining('记录删除状态无法保存'), findsOneWidget);

    executions.removalPersistenceFails = false;
    await _deleteCard(tester);
    expect(executions.executions, isEmpty);
    expect(executions.durable, isEmpty);
    expect(backgrounds.tasks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('card delete keeps parent when a child removal write fails', (
    tester,
  ) async {
    final executions = _Executions();
    final finished = TaskFlowExecution(
      id: 'finished',
      flowId: 'f',
      flowName: 'Finished',
      status: FlowExecutionStatus.completed,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: 'Child',
          subTaskId: 'child',
          subTaskType: 'background',
          status: TaskStatus.completed,
        ),
      ],
    );
    executions.load([finished]);
    final backgrounds = _Backgrounds()
      ..load([
        BackgroundTask(
          id: 'child',
          type: BackgroundTaskType.chat,
          title: 'Child',
          status: TaskStatus.completed,
        ),
      ])
      ..removalPersistenceFails = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
          backgroundTasksProvider.overrideWith((ref) => backgrounds),
        ],
        child: MaterialApp(
            home: Scaffold(body: TaskFlowCard(execution: finished))),
      ),
    );
    await tester.tap(find.text('Finished'));
    await tester.pump();
    await _deleteCard(tester);
    expect(backgrounds.removalPersistAttempts, 1);
    expect(backgrounds.tasks.single.id, 'child');
    expect(backgrounds.durable.single.id, 'child');
    expect(executions.executions.single.id, 'finished');
    expect(executions.durable.single.id, 'finished');
    expect(executions.removalPersistAttempts, 0);
    expect(find.textContaining('后台子任务删除状态无法保存'), findsOneWidget);

    backgrounds.removalPersistenceFails = false;
    await _deleteCard(tester);
    expect(backgrounds.tasks, isEmpty);
    expect(backgrounds.durable, isEmpty);
    expect(executions.executions, isEmpty);
    expect(executions.durable, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _clearAll(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.text('清除所有'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.widgetWithText(TextButton, '确定'));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _clearCompleted(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.text('清除已完成'));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openClearFailed(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.text('清除失败任务'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _clearFailed(WidgetTester tester) async {
  await _openClearFailed(tester);
  await tester.tap(find.widgetWithText(TextButton, '确定'));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _deleteCard(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, '删除').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.widgetWithText(TextButton, '确定'));
  await tester.pump(const Duration(milliseconds: 350));
}
