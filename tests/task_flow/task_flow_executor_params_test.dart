import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/chat_executor.dart';
import 'package:stroom/task_flow/services/block_executors/shared_helpers.dart';
import 'package:stroom/task_flow/services/block_executors/asr_executor.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';

class _FakeChatStreamManager extends ChatStreamManager {
  _FakeChatStreamManager(this.onStart, {this.onCancel, this.captureHistory});

  final Future<StreamResult> Function() onStart;
  void Function()? onCancel;
  List<ChatMessage>? captureHistory;

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
    captureHistory = history;
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

  group('asrOutputTitleFromRecords', () {
    final records = [
      AudioRecord(
        name: '我想听一段新闻',
        hash: 'd41d8cd98f00b204e9800998ecf8427e',
        format: 'mp3',
        createdAt: DateTime.now(),
        size: 10,
      ),
    ];

    test(
        'input matching an in-app audio record uses the record name '
        '(TTS product → source text), not the hash filename', () {
      expect(
        asrOutputTitleFromRecords(
          '/storage/audio/d41d8cd98f00b204e9800998ecf8427e.mp3',
          records,
        ),
        '语音识别_我想听一段新闻',
      );
    });

    test('unknown input falls back to its own basename', () {
      expect(
        asrOutputTitleFromRecords('/storage/audio/my_voice.mp3', records),
        '语音识别_my_voice',
      );
      expect(
        asrOutputTitleFromRecords(
          '/storage/audio/d41d8cd98f00b204e9800998ecf8427e.mp3',
          const [],
        ),
        '语音识别_d41d8cd98f00b204e9800998ecf8427e',
      );
    });

    test('record with an empty name falls back to the hash basename', () {
      expect(
        asrOutputTitleFromRecords(
          '/storage/audio/d41d8cd98f00b204e9800998ecf8427e.mp3',
          [
            AudioRecord(
              name: '   ',
              hash: 'd41d8cd98f00b204e9800998ecf8427e',
              format: 'mp3',
              createdAt: DateTime.now(),
              size: 10,
            ),
          ],
        ),
        '语音识别_d41d8cd98f00b204e9800998ecf8427e',
      );
    });
  });

  group('resolveChatAssistant', () {
    final userAssistants = [
      Assistant(id: 'u1', name: '翻译助手', prompt: '你是翻译'),
    ];

    test('empty id → null (use the currently selected assistant)', () {
      expect(resolveChatAssistant('', userAssistants), isNull);
    });

    test(
        'built-in prompt ids are NOT resolvable — blocks only allow '
        'user-defined assistants (legacy config fails loud)', () {
      expect(resolveChatAssistant('builtin:prompt_0', userAssistants), isNull);
      expect(
        resolveChatAssistant('builtin:prompt_999', userAssistants),
        isNull,
      );
      expect(
        resolveChatAssistant('builtin:prompt_abc', userAssistants),
        isNull,
      );
    });

    test('user-defined assistant id resolves; deleted id → null', () {
      final a = resolveChatAssistant('u1', userAssistants);
      expect(a, isNotNull);
      expect(a!.name, '翻译助手');
      expect(resolveChatAssistant('deleted-id', userAssistants), isNull);
    });
  });

  group('chatOutputTitle', () {
    test('plain text input → 助手回复_<first 20 chars>', () async {
      expect(
        await chatOutputTitle('请帮我总结这份会议记录'),
        '助手回复_请帮我总结这份会议记录',
      );
      expect(
        await chatOutputTitle('一二三四五六七八九十一二三四五六七八九十更多内容'),
        '助手回复_一二三四五六七八九十一二三四五六七八九十',
      );
    });

    test('empty input falls back to 对话', () async {
      expect(await chatOutputTitle('   '), '助手回复_对话');
    });

    test('non-existent path input is treated as plain text', () async {
      expect(
        await chatOutputTitle(r'C:\no\such\file_abc.mp3'),
        r'助手回复_C:\no\such\file_abc.',
      );
    });
  });

  group('executeChatBlock', () {
    late TaskFlowExecutionNotifier execNotifier;
    late BackgroundTaskNotifier bgNotifier;
    late FlowSubTask flowSubTask;
    late String execId;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ManifestDatabase.enableTestMode();
      container = ProviderContainer();
      addTearDown(container.dispose);
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

    ConversationsNotifier conversationsNotifier() =>
        container.read(conversationsProvider.notifier);

    test(
        'sends the previous block output VERBATIM as a role:user message '
        'and persists the exchange as a real conversation (no text file)',
        () async {
      final fakeManager = _FakeChatStreamManager(
        () async => StreamResult(
          history: [
            ChatMessage(role: 'user', content: '上一步传递的内容'),
            ChatMessage(role: 'assistant', content: '好的，已处理'),
          ],
          assistantMessage: ChatMessage(
            role: 'assistant',
            content: '好的，已处理',
          ),
          fullReply: '好的，已处理',
        ),
      );

      final reply = await executeChatBlock(
        block: TaskFlowBlock(typeKey: BlockType.chat),
        def: BlockTypeDefinition.chat,
        input: '上一步传递的内容',
        execId: execId,
        execNotifier: execNotifier,
        flowSubTask: flowSubTask,
        bgNotifier: bgNotifier,
        chatManager: fakeManager,
        conversationsNotifier: conversationsNotifier(),
      );

      expect(reply, '好的，已处理');
      // The previous step's content goes out as a user message — the
      // model must receive it, not just the assistant's own system prompt.
      expect(fakeManager.captureHistory, isNotNull);
      expect(fakeManager.captureHistory!.length, 1);
      expect(fakeManager.captureHistory!.single.role, 'user');
      expect(fakeManager.captureHistory!.single.content, '上一步传递的内容');
      // The exchange lives in a REAL conversation keyed by the flow convId
      // — viewable and continuable from the topic-selection page.
      final convs = container.read(conversationsProvider);
      expect(convs, hasLength(1));
      final conv = convs.single;
      expect(conv.id, 'flow_${execId}_${flowSubTask.id}');
      expect(conv.messages, hasLength(2));
      expect(conv.messages[0].role, 'user');
      expect(conv.messages[0].content, '上一步传递的内容');
      expect(conv.messages[1].role, 'assistant');
      expect(conv.messages[1].content, '好的，已处理');
      // The flow conversation is created quietly: a background flow must
      // not hijack the chat tab's active conversation.
      expect(container.read(activeConversationIdProvider), isNull);
      // No text record is written to the gallery anymore.
      expect(await TextManifest.loadRecords(), isEmpty);
      // The background task keeps 助手回复_<short name> and completes
      // without an "open file" target.
      expect(bgNotifier.state[0].title, '助手回复_上一步传递的内容');
      expect(bgNotifier.state[0].status, TaskStatus.completed);
      expect(bgNotifier.state[0].downloadedFilePath, isNull);
    });

    test('a configured block assistant is bound to the saved conversation',
        () async {
      final fakeManager = _FakeChatStreamManager(
        () async => StreamResult(
          history: [
            ChatMessage(role: 'user', content: '输入'),
            ChatMessage(role: 'assistant', content: '好的'),
          ],
          assistantMessage: ChatMessage(role: 'assistant', content: '好的'),
          fullReply: '好的',
        ),
      );

      await executeChatBlock(
        block: TaskFlowBlock(typeKey: BlockType.chat),
        def: BlockTypeDefinition.chat,
        input: '输入',
        execId: execId,
        execNotifier: execNotifier,
        flowSubTask: flowSubTask,
        bgNotifier: bgNotifier,
        chatManager: fakeManager,
        conversationsNotifier: conversationsNotifier(),
        assistant: Assistant(id: 'u1', name: '翻译助手', prompt: '你是翻译'),
      );

      expect(container.read(conversationsProvider).single.assistantId, 'u1');
    });

    test(
        'fails the sub-task and bg task when the stream is cancelled '
        'instead of succeeding with a partial reply, and removes the '
        'stub conversation', () async {
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
          conversationsNotifier: conversationsNotifier(),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      // A failed block must not leave an orphan stub conversation.
      expect(container.read(conversationsProvider), isEmpty);
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
          conversationsNotifier: conversationsNotifier(),
          maxWait: const Duration(milliseconds: 50),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(cancelled, isTrue);
      expect(container.read(conversationsProvider), isEmpty);
      expect(bgNotifier.state[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.failed);
    });

    test(
        'fails the sub-task when the stream ends with an error reply '
        '(error text must not become flow output), and removes the '
        'stub conversation', () async {
      final fakeManager = _FakeChatStreamManager(
        () async => StreamResult(
          history: const [],
          assistantMessage: ChatMessage(
            role: 'assistant',
            content: '网络连接失败，请重试',
            isError: true,
            rawRequest: const {'url': 'https://api.example.com/v1/chat'},
            rawResponse: const {'statusCode': 500, 'error': 'server error'},
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
          conversationsNotifier: conversationsNotifier(),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(container.read(conversationsProvider), isEmpty);
      expect(bgNotifier.state[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].status, FlowExecutionStatus.failed);
      // The failed background task carries the message's raw
      // request/response so the task list shows the same
      // "查看错误详情" dialog as the chat page.
      expect(
        bgNotifier.state[0].rawRequest,
        const {'url': 'https://api.example.com/v1/chat'},
      );
      expect(
        bgNotifier.state[0].rawResponse,
        const {'statusCode': 500, 'error': 'server error'},
      );
    });

    test(
        'fails and removes the stub conversation when the assistant '
        'returns no content', () async {
      final fakeManager = _FakeChatStreamManager(
        () async => StreamResult(
          history: [
            ChatMessage(role: 'user', content: '输入'),
          ],
          fullReply: '',
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
          conversationsNotifier: conversationsNotifier(),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(container.read(conversationsProvider), isEmpty);
      expect(bgNotifier.state[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].status, FlowExecutionStatus.failed);
    });

    test(
        'a flow deleted mid-stream leaves no orphan conversation even '
        'when the stream finished successfully', () async {
      final fakeManager = _FakeChatStreamManager(
        () async => StreamResult(
          history: [
            ChatMessage(role: 'user', content: '输入'),
            ChatMessage(role: 'assistant', content: '好的'),
          ],
          assistantMessage: ChatMessage(role: 'assistant', content: '好的'),
          fullReply: '好的',
        ),
      );

      // The flow execution is removed while the stream is in flight (flow
      // card delete / 清除所有) — the reply must NOT be saved.
      execNotifier.removeExecution(execId);

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
          conversationsNotifier: conversationsNotifier(),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(container.read(conversationsProvider), isEmpty);
    });

    test(
        'a synchronously-throwing stream fails the block and removes '
        'the stub conversation', () async {
      final fakeManager = _FakeChatStreamManager(
        () => throw Exception('stream crashed'),
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
          conversationsNotifier: conversationsNotifier(),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(container.read(conversationsProvider), isEmpty);
      expect(bgNotifier.state[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].status, FlowExecutionStatus.failed);
    });
  });
}
