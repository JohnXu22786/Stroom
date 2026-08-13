import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/unified_task_list/task_utils.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';

TaskFlowExecution _execution({
  required String status,
  required List<FlowSubTask> subTasks,
}) {
  return TaskFlowExecution(
    id: 'exec-1',
    flowId: 'f1',
    flowName: '测试流',
    status: status == 'running'
        ? FlowExecutionStatus.running
        : status == 'completed'
            ? FlowExecutionStatus.completed
            : FlowExecutionStatus.failed,
    subTasks: subTasks,
  );
}

void main() {
  group('removeFlowSubTaskTasksCore', () {
    test('removes real sub-task tasks and skips pending placeholders', () {
      final removedCatCatch = <String>[];
      final removedSynthesis = <String>[];
      final removedBackground = <String>[];
      final cancelledChats = <String>[];

      removeFlowSubTaskTasksCore(
        _execution(
          status: 'completed',
          subTasks: [
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '下载',
              subTaskId: 'pending_catcatch_0',
              subTaskType: 'catcatch',
            ),
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '下载',
              subTaskId: 'catcatch-real-1',
              subTaskType: 'catcatch',
            ),
            FlowSubTask(
              blockTypeKey: 'tts',
              blockLabel: '合成',
              subTaskId: 'tts-real-2',
              subTaskType: 'synthesis',
            ),
            FlowSubTask(
              blockTypeKey: 'chat',
              blockLabel: '对话',
              id: '3',
              subTaskId: 'chat_real_3',
              subTaskType: 'background',
            ),
            FlowSubTask(
              blockTypeKey: 'asr',
              blockLabel: '识别',
              subTaskId: 'asr-real-4',
              subTaskType: 'background',
            ),
          ],
        ),
        removeCatCatch: (id) => removedCatCatch.add(id),
        removeSynthesis: (id) => removedSynthesis.add(id),
        removeBackground: (id) => removedBackground.add(id),
        cancelChat: (st) => cancelledChats.add('flow_${st.id}'),
      );

      expect(removedCatCatch, ['catcatch-real-1']);
      expect(removedSynthesis, ['tts-real-2']);
      expect(removedBackground, ['chat_real_3', 'asr-real-4']);
      expect(cancelledChats, ['flow_3'],
          reason: 'chat sub-task convId is derived from the FlowSubTask id '
              '(the execId prefix is added by the production wrapper)');
    });

    test(
        'deleting a RUNNING execution cancels the active request '
        '(flow run lock frees promptly)', () {
      var cancelCalls = 0;
      removeFlowSubTaskTasksCore(
        _execution(
          status: 'running',
          subTasks: [
            FlowSubTask(
              blockTypeKey: 'asr',
              blockLabel: '识别',
              subTaskId: 'asr-real-1',
              subTaskType: 'background',
            ),
          ],
        ),
        removeCatCatch: (_) {},
        removeSynthesis: (_) {},
        removeBackground: (_) {},
        cancelChat: (_) {},
        cancelActiveRequest: () => cancelCalls++,
      );
      expect(cancelCalls, 1);
    });

    test('only a RUNNING execution may cancel the service\'s active request',
        () {
      expect(
        shouldCancelActiveRequest(
          _execution(status: 'running', subTasks: const []),
        ),
        isTrue,
      );
      expect(
        shouldCancelActiveRequest(
          _execution(status: 'completed', subTasks: const []),
        ),
        isFalse,
        reason: 'the cancel token belongs to the currently executing flow — '
            'deleting a completed/failed flow must not kill another '
            'flow\'s request',
      );
      expect(
        shouldCancelActiveRequest(
          _execution(status: 'failed', subTasks: const []),
        ),
        isFalse,
      );
    });

    test(
        'Core is null-safe when no cancel callback is provided '
        '(completed/failed deletion path)', () {
      removeFlowSubTaskTasksCore(
        _execution(status: 'completed', subTasks: const []),
        removeCatCatch: (_) {},
        removeSynthesis: (_) {},
        removeBackground: (_) {},
        cancelChat: (_) {},
      );
    });
  });
}
