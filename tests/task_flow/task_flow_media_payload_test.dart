// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/services/chat_protocol.dart' show maxAttachmentBytes;
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/openai_protocol.dart';
import 'package:stroom/services/anthropic_protocol.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/chat_executor.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

class _Manager extends ChatStreamManager {
  _Manager({this.fail = false});
  final bool fail;
  List<ChatMessage>? sentHistory;
  String? sentText;
  ProviderEntriesState? sentEntries;
  int starts = 0;
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
    ProviderEntriesState? entriesStateOverride,
  }) async {
    starts++;
    sentHistory = history;
    sentText = text;
    sentEntries = entriesStateOverride;
    final reply = ChatMessage(
      role: 'assistant',
      content: fail ? 'Failed' : 'Summary',
      isError: fail,
    );
    return StreamResult(
      history: [...history, reply],
      assistantMessage: reply,
      fullReply: reply.content,
    );
  }
}

class _RejectConversationMessageStore extends InMemorySharedPreferencesStore {
  _RejectConversationMessageStore(this.rejectedMessageCount) : super.empty();

  final int rejectedMessageCount;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.conversations' && value is String) {
      final conversations = jsonDecode(value) as List;
      if (conversations.any((conversation) =>
          (conversation['messages'] as List).length == rejectedMessageCount)) {
        return Future<bool>.value(false);
      }
    }
    return super.setValue(valueType, key, value);
  }
}

class _RejectConversationRemovalStore extends InMemorySharedPreferencesStore {
  _RejectConversationRemovalStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.conversations' &&
        value is String &&
        (jsonDecode(value) as List).isEmpty) {
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _RejectExecutionRemovalNotifier extends TaskFlowExecutionNotifier {
  bool rejectWrites = false;

  @override
  Future<bool> persist() =>
      rejectWrites ? Future<bool>.value(false) : super.persist();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previous;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    directory = await Directory.systemTemp.createTemp('flow_media_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  test(
    'typed payload distinguishes path-shaped text from files and persists',
    () {
      final text = FlowPayload.fromValue('/tmp/meeting.wav', IOType.text);
      expect(text.text, '/tmp/meeting.wav');
      expect(text.fileReference, isNull);
      final audio = FlowPayload.file(
        fileReference: '/tmp/meeting.wav',
        type: IOType.audio,
        text: '总结',
        fileName: 'original recording.wav',
      );
      final restored = FlowPayload.fromMap(audio.toMap());
      expect(restored.type, IOType.audio);
      expect(restored.fileReference, '/tmp/meeting.wav');
      expect(restored.text, '总结');
      expect(restored.fileName, 'original recording.wav');
    },
  );

  test('an existing file path declared as text stays verbatim text', () async {
    final file =
        await File('${directory.path}/notes.txt').writeAsString('notes');
    final message = await prepareFlowChatMessage(
      FlowPayload.fromValue(file.path, IOType.text),
      'conversation',
    );
    expect(message.content, file.path);
    expect(message.attachments, isEmpty);
  });

  test('chat attachment keeps the selected name instead of the copy name',
      () async {
    final storagePath = await AttachmentStorage.saveFile(
      'notes.pdf',
      Uint8List.fromList(utf8.encode('%PDF-1.7\nreport')),
    );
    final copy = File('${directory.path}/$storagePath');
    final restored = FlowPayload.fromMap(FlowPayload.fromValue(
      copy.path,
      IOType.file,
      fileName: 'notes.pdf',
    ).toMap());
    final message = await prepareFlowChatMessage(restored, 'conversation');
    expect(message.attachments.single.fileName, 'notes.pdf');
    expect(
        message.attachments.single.fileName, isNot(copy.uri.pathSegments.last));
  });

  test('execution history keeps picker name and copy until its last removal',
      () async {
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nreport'));
    final storagePath = await AttachmentStorage.saveFile('notes.pdf', bytes);
    final copy = File('${directory.path}/$storagePath');
    final executions = TaskFlowExecutionNotifier();
    addTearDown(executions.dispose);
    final first = executions.addExecution(
      flowId: 'flow',
      flowName: 'Flow',
      inputText: copy.path,
      inputFileName: 'notes.pdf',
      inputStoragePath: storagePath,
    );
    final second = executions.addExecution(
      flowId: 'flow',
      flowName: 'Flow retry',
      inputText: copy.path,
      inputFileName: 'notes.pdf',
      inputStoragePath: storagePath,
    );
    expect(await executions.persist(), isTrue);
    final restored = TaskFlowExecution.fromMap(
      executions.execution(first)!.toMap(),
    );
    expect(restored.inputFileName, 'notes.pdf');
    expect(restored.inputStoragePath, storagePath);
    final retry = FlowRunInput(
      text: restored.inputText,
      fileName: restored.inputFileName,
      ownedStoragePath: restored.inputStoragePath,
    );
    final retryMessage = await prepareFlowChatMessage(
      FlowPayload.fromValue(retry.text, IOType.file, fileName: retry.fileName),
      'retry',
    );
    expect(retryMessage.attachments.single.fileName, 'notes.pdf');
    expect(await copy.readAsBytes(), bytes);

    await executions.removeExecution(first);
    expect(await copy.readAsBytes(), bytes,
        reason: 'another execution can still retry this copy');
    await executions.removeExecution(second);
    expect(await copy.exists(), isFalse);
    await AttachmentStorage.deleteFile(
      retryMessage.attachments.single.storagePath,
    );
  });

  test('bulk execution removal waits for every shared copy reference',
      () async {
    final storagePath = await AttachmentStorage.saveFile(
      'notes.pdf',
      Uint8List.fromList(utf8.encode('%PDF-1.7\nreport')),
    );
    final copy = File('${directory.path}/$storagePath');
    final executions = TaskFlowExecutionNotifier();
    addTearDown(executions.dispose);
    final ids = [
      for (var i = 0; i < 3; i++)
        executions.addExecution(
          flowId: 'flow',
          flowName: 'Flow $i',
          inputText: copy.path,
          inputStoragePath: storagePath,
        ),
    ];
    expect(await executions.persist(), isTrue);
    await Future.wait(ids.map(executions.removeExecution));
    expect(await copy.exists(), isFalse);
  });

  test('failed execution deletion keeps its retry input and stops its work',
      () async {
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nreport'));
    final storagePath = await AttachmentStorage.saveFile('notes.pdf', bytes);
    final copy = File('${directory.path}/$storagePath');
    final executions = _RejectExecutionRemovalNotifier();
    addTearDown(executions.dispose);
    final id = executions.addExecution(
      flowId: 'flow',
      flowName: 'Flow',
      inputText: copy.path,
      inputStoragePath: storagePath,
    );
    executions.addSubTask(
      id,
      FlowSubTask(
        blockTypeKey: 'chat',
        blockLabel: 'Assistant',
        subTaskId: 'chat',
        subTaskType: 'background',
        status: TaskStatus.running,
      ),
    );
    expect(await executions.persist(), isTrue);
    executions.rejectWrites = true;
    await executions.removeExecution(id);
    expect(executions.execution(id)!.status, FlowExecutionStatus.failed);
    expect(executions.execution(id)!.subTasks.single.status, TaskStatus.failed);
    expect(await copy.readAsBytes(), bytes);
    executions.rejectWrites = false;
    await executions.removeExecution(id);
    expect(await copy.exists(), isFalse);
  });

  for (final entry in {
    IOType.image: ('photo.png', 'image_url', 'image/png'),
    IOType.audio: ('speech.wav', 'input_audio', 'audio/x-wav'),
    IOType.video: ('clip.mp4', 'video_url', 'video/mp4'),
  }.entries) {
    test(
      '${entry.key.name} reaches the existing protocol as an attachment',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final file = await File('${directory.path}/${entry.value.$1}')
            .writeAsBytes(bytes);
        final message = await prepareFlowChatMessage(
          FlowPayload.file(
            fileReference: file.path,
            type: entry.key,
            text: '总结',
          ),
          'conversation',
        );
        expect(message.content, '总结');
        final attachment = message.attachments.single;
        expect(attachment.fileType, entry.key.name);
        expect(attachment.conversationId, 'conversation');
        expect(await AttachmentStorage.readFile(attachment.storagePath), bytes);
        final request = await const OpenAIProtocol().buildRequest(
          history: [message],
        );
        final content = request.messages.single['content'] as List;
        expect(content.first, {'type': 'text', 'text': '总结'});
        expect(content.last['type'], entry.value.$2);
        expect(jsonEncode(content), contains(base64Encode(bytes)));
        expect(jsonEncode(content), isNot(contains(file.path)));
      },
    );
  }

  test(
    'unsupported kinds, missing files and mismatched media fail explicitly',
    () async {
      expect(BlockTypeDefinition.chat.acceptsInput(IOType.any), isFalse);
      final audio =
          await File('${directory.path}/speech.mp3').writeAsBytes([1]);
      for (final payload in [
        FlowPayload.file(fileReference: audio.path, type: IOType.video),
        FlowPayload.file(
          fileReference: '${directory.path}/missing.png',
          type: IOType.image,
        ),
        FlowPayload.fromValue('unsupported', IOType.any),
      ]) {
        await expectLater(
          prepareFlowChatMessage(payload, 'conversation'),
          throwsA(isA<Exception>()),
        );
      }
    },
  );

  test(
    'preflight checks the actual kind of an initial chat media file',
    () async {
      final assistant = Assistant(
        id: 'assistant',
        name: 'Assistant',
        prompt: 'Help',
      );
      final audio =
          await File('${directory.path}/speech.mp3').writeAsBytes([1, 2]);
      final flow = TaskFlowDefinition(
        name: 'Video',
        inputType: IOType.video,
        blocks: [
          TaskFlowBlock(
            typeKey: BlockType.chat,
            params: {'assistantId': assistant.id},
          ),
        ],
      );
      await expectLater(
        validateTaskFlow(
          flow,
          [FlowRunInput(text: audio.path)],
          providers: const ProviderEntriesState(),
          assistants: [assistant],
        ),
        throwsA(
          isA<TaskFlowValidationException>().having(
            (e) => e.message,
            'actual audio kind',
            contains('音频'),
          ),
        ),
      );
    },
  );

  test('saved MP4 MIME does not override a different file signature', () async {
    final image = await File('${directory.path}/fake.mp4')
        .writeAsBytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    final assistant = Assistant(
      id: 'assistant',
      name: 'Assistant',
      prompt: 'Help',
    );
    final flow = TaskFlowDefinition(
      name: 'Audio',
      inputType: IOType.audio,
      blocks: [
        TaskFlowBlock(
          typeKey: BlockType.chat,
          params: {'assistantId': assistant.id},
        ),
      ],
    );
    await expectLater(
      validateTaskFlow(
        flow,
        [FlowRunInput(text: image.path, mimeType: 'audio/mp4')],
        providers: const ProviderEntriesState(),
        assistants: [assistant],
      ),
      throwsA(
        isA<TaskFlowValidationException>().having(
          (e) => e.message,
          'actual image kind',
          contains('图片'),
        ),
      ),
    );
  });

  test(
    'generic file input accepts an image over the document size limit',
    () async {
      final image = File('${directory.path}/large.png');
      final handle = image.openSync(mode: FileMode.write);
      handle.writeFromSync([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      handle.setPositionSync(maxAttachmentBytes);
      handle.writeByteSync(0);
      handle.closeSync();
      final assistant = Assistant(
        id: 'assistant',
        name: 'Assistant',
        prompt: 'Help',
      );
      final flow = TaskFlowDefinition(
        name: 'Image',
        inputType: IOType.file,
        blocks: [
          TaskFlowBlock(
            typeKey: BlockType.chat,
            params: {'assistantId': assistant.id},
          ),
        ],
      );
      await validateTaskFlow(
        flow,
        [FlowRunInput(text: image.path)],
        providers: const ProviderEntriesState(),
        assistants: [assistant],
      );
      final message = await prepareFlowChatMessage(
        FlowPayload.file(fileReference: image.path, type: IOType.file),
        'conversation',
      );
      expect(message.attachments.single.fileType, 'image');
      expect(message.attachments.single.fileSize, maxAttachmentBytes + 1);
    },
  );

  test(
    'oversized image is rejected before chat attachment allocation',
    () async {
      final image = File('${directory.path}/oversized.png');
      final handle = image.openSync(mode: FileMode.write);
      handle.writeFromSync([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      handle.setPositionSync(maxFlowImageInputBytes);
      handle.writeByteSync(0);
      handle.closeSync();
      final assistant = Assistant(
        id: 'assistant',
        name: 'Assistant',
        prompt: 'Help',
      );
      final flow = TaskFlowDefinition(
        name: 'Image',
        inputType: IOType.file,
        blocks: [
          TaskFlowBlock(
            typeKey: BlockType.chat,
            params: {'assistantId': assistant.id},
          ),
        ],
      );
      await expectLater(
        validateTaskFlow(
          flow,
          [FlowRunInput(text: image.path)],
          providers: const ProviderEntriesState(),
          assistants: [assistant],
        ),
        throwsA(
          isA<TaskFlowValidationException>().having(
            (e) => e.message,
            'image size',
            contains('20 MB'),
          ),
        ),
      );
      await expectLater(
        prepareFlowChatMessage(
          FlowPayload.file(fileReference: image.path, type: IOType.file),
          'conversation',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'image size',
            contains('20 MB'),
          ),
        ),
      );
    },
  );

  for (final fail in [false, true]) {
    test(
      'chat execution ${fail ? 'cleans failed' : 'persists successful'} media attachments',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final file =
            await File('${directory.path}/speech.wav').writeAsBytes(bytes);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final executions = TaskFlowExecutionNotifier();
        final execId = executions.addExecution(
          flowId: 'flow',
          flowName: 'Flow',
        );
        final subTask = FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: '助手',
          subTaskId: 'pending',
          subTaskType: 'background',
          status: TaskStatus.waiting,
        );
        executions.addSubTask(execId, subTask);
        final manager = _Manager(fail: fail);
        const originalProviders = ProviderEntriesState();
        final result = executeChatBlock(
          block: TaskFlowBlock(typeKey: BlockType.chat),
          def: BlockTypeDefinition.chat,
          input: file.path,
          payload: FlowPayload.file(
            fileReference: file.path,
            type: IOType.audio,
            text: 'Summarize',
          ),
          execId: execId,
          execNotifier: executions,
          flowSubTask: subTask,
          bgNotifier: BackgroundTaskNotifier(),
          chatManager: manager,
          providerEntries: originalProviders,
          conversationsNotifier: container.read(conversationsProvider.notifier),
        );
        if (fail) {
          await expectLater(result, throwsException);
          expect(container.read(conversationsProvider), isEmpty);
          final prefs = await SharedPreferences.getInstance();
          expect(
            jsonDecode(prefs.getString('conversations') ?? '[]'),
            isEmpty,
            reason: 'failed flow chat must be removed on disk before its '
                'attachment copy is deleted',
          );
          expect(
            await AttachmentStorage.readFile(
              manager.sentHistory!.single.attachments.single.storagePath,
            ),
            isNull,
          );
          expect(
            await file.readAsBytes(),
            bytes,
            reason: 'the source media remains untouched',
          );
        } else {
          expect(await result, 'Summary');
          final saved =
              container.read(conversationsProvider).single.messages.first;
          expect(saved.attachments.single.fileType, 'audio');
          expect(
            await AttachmentStorage.readFile(
              saved.attachments.single.storagePath,
            ),
            bytes,
          );
        }
        expect(manager.sentEntries, same(originalProviders));
        expect(manager.sentText, 'Summarize');
        expect(manager.sentHistory!.single.content, 'Summarize');
        expect(manager.sentHistory!.single.attachments, hasLength(1));
      },
    );
  }

  for (final rejectedCount in [1, 2]) {
    test(
      'chat does not ${rejectedCount == 1 ? 'send' : 'complete'} when its '
      '$rejectedCount-message save fails',
      () async {
        final previousStore = SharedPreferencesStorePlatform.instance;
        final store = _RejectConversationMessageStore(rejectedCount);
        SharedPreferencesStorePlatform.instance = store;
        addTearDown(
          () => SharedPreferencesStorePlatform.instance = previousStore,
        );
        final bytes = Uint8List.fromList([1, 2, 3]);
        final source =
            await File('${directory.path}/speech.wav').writeAsBytes(bytes);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final executions = TaskFlowExecutionNotifier();
        addTearDown(executions.dispose);
        final execId = executions.addExecution(
          flowId: 'flow',
          flowName: 'Flow',
        );
        final subTask = FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: '助手',
          subTaskId: 'pending',
          subTaskType: 'background',
          status: TaskStatus.waiting,
        );
        executions.addSubTask(execId, subTask);
        final manager = _Manager();
        await expectLater(
          executeChatBlock(
            block: TaskFlowBlock(typeKey: BlockType.chat),
            def: BlockTypeDefinition.chat,
            input: source.path,
            payload: FlowPayload.file(
              fileReference: source.path,
              type: IOType.audio,
            ),
            execId: execId,
            execNotifier: executions,
            flowSubTask: subTask,
            bgNotifier: BackgroundTaskNotifier(),
            chatManager: manager,
            conversationsNotifier:
                container.read(conversationsProvider.notifier),
          ),
          throwsA(isA<Exception>()),
        );
        expect(manager.starts, rejectedCount == 1 ? 0 : 1);
        expect(container.read(conversationsProvider), isEmpty);
        final disk = await store.getAll();
        expect(jsonDecode(disk['flutter.conversations'] as String), isEmpty);
        expect(await source.readAsBytes(), bytes);
        expect(
          (await Directory('${directory.path}/attachments').list().toList())
              .whereType<File>(),
          isEmpty,
          reason: 'a rejected exchange must not orphan an attachment',
        );
      },
    );
  }

  test(
    'failed deletion keeps stored chat attachments when disk write fails',
    () async {
      final previousStore = SharedPreferencesStorePlatform.instance;
      final store = _RejectConversationRemovalStore();
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = previousStore,
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      final source =
          await File('${directory.path}/speech.wav').writeAsBytes(bytes);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final executions = TaskFlowExecutionNotifier();
      addTearDown(executions.dispose);
      final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
      final subTask = FlowSubTask(
        blockTypeKey: 'chat',
        blockLabel: '助手',
        subTaskId: 'pending',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      executions.addSubTask(execId, subTask);
      final manager = _Manager(fail: true);
      await expectLater(
        executeChatBlock(
          block: TaskFlowBlock(typeKey: BlockType.chat),
          def: BlockTypeDefinition.chat,
          input: source.path,
          payload: FlowPayload.file(
            fileReference: source.path,
            type: IOType.audio,
          ),
          execId: execId,
          execNotifier: executions,
          flowSubTask: subTask,
          bgNotifier: BackgroundTaskNotifier(),
          chatManager: manager,
          conversationsNotifier: container.read(conversationsProvider.notifier),
        ),
        throwsA(isA<Exception>()),
      );

      final disk = await store.getAll();
      final persisted =
          jsonDecode(disk['flutter.conversations'] as String) as List;
      expect(persisted, hasLength(1));
      expect(container.read(conversationsProvider), hasLength(1));
      final copy = manager.sentHistory!.single.attachments.single.storagePath;
      expect(
        await AttachmentStorage.readFile(copy),
        bytes,
        reason: 'a saved conversation must not point at a deleted file',
      );
      expect(await source.readAsBytes(), bytes);
    },
  );

  test('a retry replaces a loaded conversation and its old attachment',
      () async {
    final source =
        await File('${directory.path}/speech.wav').writeAsBytes([1, 2, 3]);
    final executions = TaskFlowExecutionNotifier();
    addTearDown(executions.dispose);
    final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    final subTask = FlowSubTask(
        blockTypeKey: 'chat',
        blockLabel: '助手',
        subTaskId: 'pending',
        subTaskType: 'background',
        status: TaskStatus.waiting);
    executions.addSubTask(execId, subTask);
    final convId = 'flow_${execId}_${subTask.id}';
    final oldPath = await AttachmentStorage.saveFile(
        'old.wav', Uint8List.fromList([9, 8, 7]));
    final old = Conversation(id: convId, title: 'Previous attempt', messages: [
      ChatMessage(role: 'user', content: '', attachments: [
        Attachment(
            fileName: 'old.wav',
            mimeType: 'audio/x-wav',
            fileType: 'audio',
            hash: 'old',
            storagePath: oldPath,
            fileSize: 3,
            conversationId: convId)
      ])
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('conversations', jsonEncode([old.toMap()]));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
        await executeChatBlock(
            block: TaskFlowBlock(typeKey: BlockType.chat),
            def: BlockTypeDefinition.chat,
            input: source.path,
            payload: FlowPayload.file(
                fileReference: source.path, type: IOType.audio),
            execId: execId,
            execNotifier: executions,
            flowSubTask: subTask,
            bgNotifier: BackgroundTaskNotifier(),
            chatManager: _Manager(),
            conversationsNotifier:
                container.read(conversationsProvider.notifier)),
        'Summary');
    final current = container.read(conversationsProvider).single;
    expect(current.id, convId);
    expect(current.messages, hasLength(2));
    expect(
        current.messages.first.attachments.single.storagePath, isNot(oldPath));
    expect(await AttachmentStorage.readFile(oldPath), isNull);
    expect(await source.readAsBytes(), [1, 2, 3]);
  });

  test(
    'Anthropic rejects media kinds that its shared chat protocol skips',
    () async {
      for (final entry in {
        IOType.audio: 'speech.wav',
        IOType.video: 'clip.mp4',
        IOType.file: 'notes.txt',
      }.entries) {
        final file =
            await File('${directory.path}/${entry.value}').writeAsBytes([1, 2]);
        await expectLater(
          prepareFlowChatMessage(
            FlowPayload.file(fileReference: file.path, type: entry.key),
            'conversation',
            endpointType: 'anthropic',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Anthropic'),
            ),
          ),
        );
      }
      final pdf = await File('${directory.path}/notes.pdf')
          .writeAsBytes(utf8.encode('%PDF-1.7\nexample'));
      final message = await prepareFlowChatMessage(
        FlowPayload.file(fileReference: pdf.path, type: IOType.file),
        'conversation',
        endpointType: 'anthropic',
      );
      expect(message.attachments.single.fileType, 'document');
    },
  );

  test(
    'Anthropic uses PDF bytes rather than the filename for flow files',
    () async {
      final pdfBytes = utf8.encode('%PDF-1.7\nexample');
      for (final name in ['report', 'report.docx']) {
        final file =
            await File('${directory.path}/$name').writeAsBytes(pdfBytes);
        final message = await prepareFlowChatMessage(
          FlowPayload.file(fileReference: file.path, type: IOType.file),
          'conversation',
          endpointType: 'anthropic',
        );
        expect(message.attachments.single.mimeType, 'application/pdf');
        expect(message.attachments.single.fileType, 'document');
        final request = await const AnthropicProtocol().buildRequest(
          history: [message],
        );
        final parts = request.messages.single['content'] as List;
        expect(parts.single['type'], 'document');
        expect(parts.single['source']['media_type'], 'application/pdf');
      }
      final spoofed = await File('${directory.path}/fake.pdf')
          .writeAsBytes([0x50, 0x4b, 0x03, 0x04, 1, 2]);
      await expectLater(
        prepareFlowChatMessage(
          FlowPayload.file(fileReference: spoofed.path, type: IOType.file),
          'conversation',
          endpointType: 'anthropic',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'non-PDF content',
            contains('PDF'),
          ),
        ),
      );
    },
  );

  test(
      'chat input uses the assistant model protocol, then the current chat fallback',
      () {
    final model = ModelConfig(
      name: 'Claude',
      modelId: 'claude',
      endpointType: 'anthropic',
    );
    final config = ProviderConfigItem(
      providerName: 'Provider',
      host: 'https://example.com',
      key: 'key',
      models: [model],
    );
    final providers = ProviderEntriesState(
      entries: [
        ProviderEntry(name: 'LLM', type: 'llm', configs: [config]),
      ],
    );
    final assistant = Assistant(
      id: 'assistant',
      name: 'Claude',
      prompt: 'Help',
      defaultModelId: 'claude',
      defaultProviderName: 'Provider',
    );
    expect(flowChatEndpointType(assistant, providers), 'anthropic');
    expect(
      flowChatEndpointType(null, providers, fallback: 'anthropic'),
      'anthropic',
    );
  });

  test(
    'oversized audio fails before being reduced to a skipped-file text',
    () async {
      final file = File('${directory.path}/speech.wav');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(10 * 1024 * 1024 + 1);
      await handle.close();
      await expectLater(
        prepareFlowChatMessage(
          FlowPayload.file(fileReference: file.path, type: IOType.audio),
          'conversation',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('10 MB'),
          ),
        ),
      );
    },
  );
}
