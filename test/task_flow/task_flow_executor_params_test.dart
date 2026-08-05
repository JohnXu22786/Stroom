import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/chat_executor.dart';
import 'package:stroom/task_flow/services/block_executors/shared_helpers.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _FakeChatStreamManager extends ChatStreamManager {
  _FakeChatStreamManager(this.onStart, {this.onCancel});

  final Future<StreamResult> Function() onStart;
  void Function()? onCancel;

  @override
  Future<StreamResult> startStreaming({
    required String text,
    required String convId,
    required List<ChatMessage> history,
    List<ToolDefinition> tools = const [],
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    String? streamingMsgId,
    Assistant? assistant,
  }) {
    return onStart();
  }

  @override
  void cancel([String? convId]) {
    onCancel?.call();
  }
}

void main() {
  group('asIntParam', () {
    test('returns an int value as-is', () {
      expect(asIntParam({'k': 3}, 'k', 0), 3);
    });

    test('coerces a double value by truncation', () {
      expect(asIntParam({'k': 3.9}, 'k', 0), 3);
    });

    test('parses a numeric string value', () {
      expect(asIntParam({'k': '2'}, 'k', 0), 2);
    });

    test('falls back when the value is missing or unparseable', () {
      expect(asIntParam({}, 'k', 7), 7);
      expect(asIntParam({'k': 'abc'}, 'k', 7), 7);
    });
  });

  group('asStringParam', () {
    test('returns a string value as-is', () {
      expect(asStringParam({'k': 'v'}, 'k', 'd'), 'v');
    });

    test('stringifies numeric values (TTS speed regression)', () {
      expect(asStringParam({'k': 1.5}, 'k', '1.0'), '1.5');
      expect(asStringParam({'k': 2}, 'k', '1.0'), '2');
    });

    test('falls back when the value is missing', () {
      expect(asStringParam({}, 'k', 'd'), 'd');
    });
  });

  group('subTaskTypeFor', () {
    test('chat maps to background so the flow card links the real task', () {
      expect(subTaskTypeFor(BlockType.chat), 'background');
    });

    test('catcatch and tts map to their dedicated card types', () {
      expect(subTaskTypeFor(BlockType.catcatch), 'catcatch');
      expect(subTaskTypeFor(BlockType.tts), 'synthesis');
    });

    test('asr/ocr/audioSeparation/custom map to background', () {
      expect(subTaskTypeFor(BlockType.asr), 'background');
      expect(subTaskTypeFor(BlockType.ocr), 'background');
      expect(subTaskTypeFor(BlockType.audioSeparation), 'background');
      expect(subTaskTypeFor(BlockType.custom), 'background');
    });
  });

  group('executeChatBlock', () {
    late TaskFlowExecutionNotifier execNotifier;
    late BackgroundTaskNotifier bgNotifier;
    late FlowSubTask flowSubTask;
    late String execId;

    setUp(() {
      execNotifier = TaskFlowExecutionNotifier();
      bgNotifier = BackgroundTaskNotifier();
      execId = execNotifier.addExecution(flowId: 'f1', flowName: '测试流');
      flowSubTask = FlowSubTask(
        blockTypeKey: 'chat',
        blockLabel: '助手对话',
        subTaskId: 'pending_chat_0',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      execNotifier.addSubTask(execId, flowSubTask);
    });

    test(
        'fails the sub-task and bg task when the stream is cancelled '
        'instead of succeeding with a partial reply', () async {
      final fakeManager = _FakeChatStreamManager(
        () async => const StreamResult(
          history: [],
          fullReply: '部分回复',
          cancelled: true,
        ),
      );

      await expectLater(
        executeChatBlock(
          block: TaskFlowBlock(typeKey: BlockType.chat),
          def: BlockTypeDefinition.chat,
          input: '输入',
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          bgNotifier: bgNotifier,
          chatManager: fakeManager,
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(bgNotifier.state[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].status, FlowExecutionStatus.failed);
    });

    test('times out and cancels the stream instead of hanging forever',
        () async {
      final completer = Completer<StreamResult>();
      var cancelled = false;
      final fakeManager = _FakeChatStreamManager(
        () => completer.future,
        onCancel: () => cancelled = true,
      );

      await expectLater(
        executeChatBlock(
          block: TaskFlowBlock(typeKey: BlockType.chat),
          def: BlockTypeDefinition.chat,
          input: '输入',
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          bgNotifier: bgNotifier,
          chatManager: fakeManager,
          maxWait: const Duration(milliseconds: 50),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(cancelled, isTrue);
      expect(bgNotifier.state[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.failed);
    });

    test(
        'fails the sub-task when the stream ends with an error reply '
        '(error text must not become flow output)', () async {
      final fakeManager = _FakeChatStreamManager(
        () async => StreamResult(
          history: const [],
          assistantMessage: ChatMessage(
            role: 'assistant',
            content: '网络连接失败，请重试',
            isError: true,
          ),
          fullReply: '网络连接失败，请重试',
        ),
      );

      await expectLater(
        executeChatBlock(
          block: TaskFlowBlock(typeKey: BlockType.chat),
          def: BlockTypeDefinition.chat,
          input: '输入',
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          bgNotifier: bgNotifier,
          chatManager: fakeManager,
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(bgNotifier.state[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].status, FlowExecutionStatus.failed);
    });
  });
}
