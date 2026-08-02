import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/home_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('homeStatusCountsProvider', () {
    test('excludes flow sub-tasks and counts each flow execution once', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final bg = container.read(backgroundTasksProvider.notifier);
      final exec = container.read(taskFlowExecutionsProvider.notifier);

      // A running flow execution whose chat sub-task exists as a real
      // background task (id chat_sub1) — the sub-task must NOT be counted
      // as a standalone item, the execution must count once.
      final execId = exec.addExecution(flowId: 'f1', flowName: '测试流');
      exec.addSubTask(
        execId,
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: '助手对话',
          subTaskId: 'chat_sub1',
          subTaskType: 'background',
          status: TaskStatus.running,
        ),
      );
      bg.addTask(
        type: BackgroundTaskType.chat,
        title: '助手对话',
        taskId: 'chat_sub1',
      );

      // A genuine standalone task must still count.
      bg.addTask(type: BackgroundTaskType.asr, title: '独立ASR');

      final counts = container.read(homeStatusCountsProvider);
      expect(counts.inProgress, 2); // 1 execution + 1 standalone ASR
      expect(counts.completed, 0);
      expect(counts.failed, 0);
    });
    test('completed flow sub-tasks are excluded, failed executions count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final bg = container.read(backgroundTasksProvider.notifier);
      final exec = container.read(taskFlowExecutionsProvider.notifier);

      final execId = exec.addExecution(flowId: 'f1', flowName: '测试流');
      exec.addSubTask(
        execId,
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: '助手对话',
          subTaskId: 'chat_sub1',
          subTaskType: 'background',
          status: TaskStatus.completed,
        ),
      );
      bg.addTask(
        type: BackgroundTaskType.chat,
        title: '助手对话',
        taskId: 'chat_sub1',
      );
      bg.completeTask('chat_sub1', downloadedFilePath: 'C:\\out.txt');

      exec.failExecution(execId, error: '步骤 1 失败');

      final counts = container.read(homeStatusCountsProvider);
      expect(counts.inProgress, 0);
      expect(counts.completed, 0); // completed sub-task excluded
      expect(counts.failed, 1); // the failed execution counts once
    });
  });
}
