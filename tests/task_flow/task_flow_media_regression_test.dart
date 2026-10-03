import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/openai_protocol.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/web_file_store.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/chat_executor.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_executor.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  Completer<void>? gate;
  final entered = Completer<void>();

  @override
  Future<String> getApplicationDocumentsPath() async {
    final pending = gate;
    if (pending != null) {
      gate = null;
      entered.complete();
      await pending.future;
    }
    return path;
  }
}

class _CatCatch extends Mock implements CatCatchNotifier {}

class _Manager extends ChatStreamManager {
  int starts = 0;
  void Function()? onStart;

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
    onStart?.call();
    final reply = ChatMessage(role: 'assistant', content: 'Summary');
    return StreamResult(
        history: [...history, reply],
        assistantMessage: reply,
        fullReply: reply.content);
  }

  // Cancelling before setup has no pending stream to cancel; a late valid
  // result must still be rejected by the flow executor's own liveness guard.
  @override
  void cancel([String? convId]) {}
}

class _GatedConversations extends ConversationsNotifier {
  // The superclass parameter is private to another library.
  // ignore: use_super_parameters
  _GatedConversations(Ref ref) : super(ref);

  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> get ready {
    if (!entered.isCompleted) entered.complete();
    return release.future;
  }
}

final _mp4Header = Uint8List.fromList([
  0,
  0,
  0,
  24,
  ...ascii.encode('ftypisom'),
  0,
  0,
  0,
  1,
  ...ascii.encode('isommp41'),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previous;
  late _Documents documents;
  late ProviderContainer container;
  late TaskFlowExecutionNotifier executions;
  late BackgroundTaskNotifier background;
  late _Manager manager;
  late String execId;
  late FlowSubTask subTask;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    directory = await Directory.systemTemp.createTemp('flow_media_regression_');
    previous = PathProviderPlatform.instance;
    documents = _Documents(directory.path);
    PathProviderPlatform.instance = documents;
    AppStorage.resetCache();
    container = ProviderContainer();
    executions = TaskFlowExecutionNotifier();
    background = BackgroundTaskNotifier();
    manager = _Manager();
    execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    subTask = FlowSubTask(
        blockTypeKey: 'chat',
        blockLabel: 'Chat',
        subTaskId: 'pending',
        subTaskType: 'background',
        status: TaskStatus.waiting);
    executions.addSubTask(execId, subTask);
    await executions.persist();
  });

  tearDown(() async {
    if (executions.mounted) executions.dispose();
    background.dispose();
    container.dispose();
    manager.dispose();
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  Future<String> runChat(File source) => executeChatBlock(
        block: TaskFlowBlock(typeKey: BlockType.chat),
        def: BlockTypeDefinition.chat,
        input: source.path,
        payload:
            FlowPayload.file(fileReference: source.path, type: IOType.audio),
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        chatManager: manager,
        conversationsNotifier: container.read(conversationsProvider.notifier),
      );

  Future<void> expectCleaned(File source, List<int> bytes) async {
    expect(container.read(conversationsProvider), isEmpty);
    expect(await source.readAsBytes(), bytes);
    final attachments = Directory('${directory.path}/attachments');
    if (await attachments.exists()) {
      expect(
          await attachments
              .list(recursive: true)
              .where((entry) => entry is File)
              .toList(),
          isEmpty);
    }
    expect(
        background.state.where((task) => task.status == TaskStatus.completed),
        isEmpty);
  }

  Future<String> seedPersistedConversation() async {
    final oldCopy = await AttachmentStorage.saveFile(
        'old.wav', Uint8List.fromList([9, 8, 7]));
    final convId = 'flow_${execId}_${subTask.id}';
    final old = Conversation(
        id: convId,
        title: 'Previous attempt',
        assistantId: 'assistant',
        messages: [
          ChatMessage(role: 'user', content: '', attachments: [
            Attachment(
                fileName: 'old.wav',
                mimeType: 'audio/x-wav',
                fileType: 'audio',
                hash: 'old',
                storagePath: oldCopy,
                fileSize: 3,
                conversationId: convId)
          ])
        ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('conversations', jsonEncode([old.toMap()]));
    return oldCopy;
  }

  test('cold retry replaces a loaded conversation and its old attachment',
      () async {
    final bytes = [1, 2, 3];
    final source =
        await File('${directory.path}/speech.wav').writeAsBytes(bytes);
    final oldCopy = await seedPersistedConversation();
    // The provider has not been read yet: runChat starts its async disk load.
    expect(await runChat(source), 'Summary');
    final convId = 'flow_${execId}_${subTask.id}';
    final current = container.read(conversationsProvider);
    expect(current.where((c) => c.id == convId), hasLength(1));
    expect(current.single.messages.map((m) => m.role), ['user', 'assistant']);
    expect(current.single.messages.first.attachments.single.storagePath,
        isNot(oldCopy));
    expect(await AttachmentStorage.readFile(oldCopy), isNull);
    expect(await source.readAsBytes(), bytes);
    final prefs = await SharedPreferences.getInstance();
    final persisted = jsonDecode(prefs.getString('conversations')!) as List;
    expect(persisted.where((raw) => raw['id'] == convId), hasLength(1));
    expect((persisted.single['messages'] as List), hasLength(2));
  });

  test('cold retry cancellation removes old and new copies without streaming',
      () async {
    final bytes = [1, 2, 3];
    final source =
        await File('${directory.path}/speech.wav').writeAsBytes(bytes);
    final oldCopy = await seedPersistedConversation();
    manager.onStart = () => executions.cancelExecution(execId);
    await expectLater(runChat(source), throwsA(isA<BlockExecutionException>()));
    expect(manager.starts, 1);
    expect(await AttachmentStorage.readFile(oldCopy), isNull);
    await expectCleaned(source, bytes);
  });

  test('cancellation while conversation load is pending keeps the old attempt',
      () async {
    container.dispose();
    late _GatedConversations conversations;
    container = ProviderContainer(overrides: [
      conversationsProvider
          .overrideWith((ref) => conversations = _GatedConversations(ref))
    ]);
    final notifier = container.read(conversationsProvider.notifier);
    final convId = 'flow_${execId}_${subTask.id}';
    final oldCopy = await AttachmentStorage.saveFile(
        'old.wav', Uint8List.fromList([9, 8, 7]));
    notifier.createConversation(id: convId, activate: false);
    await notifier.updateMessages(convId, [
      ChatMessage(role: 'user', content: '', attachments: [
        Attachment(
            fileName: 'old.wav',
            mimeType: 'audio/x-wav',
            fileType: 'audio',
            hash: 'old',
            storagePath: oldCopy,
            fileSize: 3,
            conversationId: convId)
      ])
    ]);
    final bytes = [1, 2, 3];
    final source =
        await File('${directory.path}/speech.wav').writeAsBytes(bytes);
    final pending = runChat(source);
    await conversations.entered.future.timeout(const Duration(seconds: 5));
    expect(manager.starts, 0);
    executions.cancelExecution(execId);
    conversations.release.complete();
    await expectLater(pending, throwsA(isA<BlockExecutionException>()));
    expect(container.read(conversationsProvider).single.id, convId);
    expect(await AttachmentStorage.readFile(oldCopy), [9, 8, 7]);
    expect(await source.readAsBytes(), bytes);
  });

  test(
      'checkpoint audio MIME survives MP4 container classification and reaches input_audio',
      () async {
    final file =
        await File('${directory.path}/recording.mp4').writeAsBytes(_mp4Header);
    final payload = FlowPayload.fromMap({
      'type': 'audio',
      'text': 'Summarize',
      'fileReference': file.path,
      'mimeType': 'audio/mp4',
    });
    expect(
        FlowPayload.fromMap(payload.toMap()).toMap()['mimeType'], 'audio/mp4');
    final message = await prepareFlowChatMessage(payload, 'conversation');
    expect(message.attachments.single.fileType, 'audio');
    expect(message.attachments.single.mimeType, 'audio/mp4');
    final request =
        await const OpenAIProtocol().buildRequest(history: [message]);
    final parts = request.messages.single['content'] as List;
    expect(parts.last['type'], 'input_audio');
    expect(parts.last['input_audio']['format'], 'm4a');
    expect(parts.last['input_audio']['data'], base64Encode(_mp4Header));
  });

  test(
      'CatCatch converted audio emits an audio MP4 payload for the chat pipeline',
      () async {
    await ManifestDatabase.getAllAudioRecords();
    WebFileStore.disableTestMode();
    final file = await File('tests/fixtures/catcatch/audio_only.mp4')
        .copy('${directory.path}/recording.mp4');
    final notifier = _CatCatch();
    late String taskId;
    when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
        .thenAnswer((invocation) {
      taskId = invocation.namedArguments[#taskId] as String;
      return taskId;
    });
    when(() => notifier.state).thenAnswer((_) => [
          catcatch.CatCatchTask(
            id: taskId,
            url: 'https://example.com/audio',
            expectedDurationSec: 0,
            createdAt: DateTime(2026),
            status: catcatch.TaskStatus.completed,
            downloadedFilePath: file.path,
            selectedMedia: const MediaResource(
                url: 'https://example.com/source.mp3',
                name: 'Source',
                ext: 'mp3',
                mimeType: 'audio/mpeg'),
          )
        ]);
    final block = TaskFlowBlock(
        typeKey: BlockType.catcatch, params: {'audioOutput': true});
    FlowPayload? output;
    final path = await executeCatCatchBlock(
      def: block.getDefinition()!,
      block: block,
      input: 'https://example.com/audio',
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      catcatchNotifier: notifier,
      pollInterval: const Duration(milliseconds: 1),
      onOutputPayload: (payload) => output = payload,
    );
    expect(path, file.path);
    expect(output!.type, IOType.audio);
    expect(output!.mimeType, 'audio/mp4',
        reason: 'the final container differs from the source MP3');
    final restored = FlowPayload.fromMap(output!.toMap());
    final message = await prepareFlowChatMessage(restored, 'conversation');
    expect(message.attachments.single.fileType, 'audio');
    final request =
        await const OpenAIProtocol().buildRequest(history: [message]);
    final parts = request.messages.single['content'] as List;
    expect(parts.single['type'], 'input_audio');
    expect(parts.single['input_audio']['format'], 'm4a');
  });

  test(
      'valid M4A with generic isom header passes preflight and chat attachment preparation',
      () async {
    final file =
        await File('${directory.path}/recording.m4a').writeAsBytes(_mp4Header);
    final assistant =
        Assistant(id: 'assistant', name: 'Assistant', prompt: 'Help');
    final flow =
        TaskFlowDefinition(name: 'Audio', inputType: IOType.audio, blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': assistant.id}),
    ]);
    await validateTaskFlow(flow, [FlowRunInput(text: file.path)],
        providers: const ProviderEntriesState(), assistants: [assistant]);
    final message = await prepareFlowChatMessage(
        FlowPayload.file(fileReference: file.path, type: IOType.audio),
        'conversation');
    expect(message.attachments.single.fileType, 'audio');
    expect(message.attachments.single.mimeType, 'audio/mp4');
  });

  test(
      'authoritative container metadata does not accept clearly different file kinds',
      () async {
    final mp3 = await File('${directory.path}/speech.mp3')
        .writeAsBytes([0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 0]);
    final png = await File('${directory.path}/renamed.m4a')
        .writeAsBytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    for (final entry in [
      (mp3, 'video', 'video/mp4'),
      (png, 'audio', 'audio/mp4')
    ]) {
      final payload = FlowPayload.fromMap({
        'type': entry.$2,
        'fileReference': entry.$1.path,
        'mimeType': entry.$3
      });
      await expectLater(prepareFlowChatMessage(payload, 'conversation'),
          throwsA(isA<FormatException>()));
    }
  });

  for (final action in ['cancel', 'delete', 'dispose']) {
    test(
        '$action during attachment storage prevents any stream and cleans owned copies',
        () async {
      final bytes = [1, 2, 3];
      final source =
          await File('${directory.path}/speech.wav').writeAsBytes(bytes);
      final gate = documents.gate = Completer<void>();
      final pending = runChat(source);
      await documents.entered.future.timeout(const Duration(seconds: 5));
      if (action == 'cancel') executions.cancelExecution(execId);
      if (action == 'delete') executions.removeExecution(execId);
      if (action == 'dispose') executions.dispose();
      manager.cancel('flow_${execId}_${subTask.id}');
      final assertion =
          expectLater(pending, throwsA(isA<BlockExecutionException>()));
      gate.complete();
      await assertion;
      expect(manager.starts, 0);
      if (action == 'cancel') {
        expect(executions.execution(execId)!.status,
            FlowExecutionStatus.cancelled);
        expect(executions.execution(execId)!.subTasks.single.outcome,
            FlowStepOutcome.cancelled);
      }
      await expectCleaned(source, bytes);
    });
  }

  for (final finalReply in [false, true]) {
    test(
        'cancellation during ${finalReply ? 'final reply' : 'initial user message'} persistence cleans without completion',
        () async {
      final bytes = [1, 2, 3];
      final source =
          await File('${directory.path}/speech.wav').writeAsBytes(bytes);
      var cancelled = false;
      final subscription =
          container.listen(conversationsProvider, (previous, next) {
        if (cancelled) return;
        final hasTarget = next.any((conversation) => conversation.messages.any(
            (message) => message.role == (finalReply ? 'assistant' : 'user')));
        if (hasTarget) {
          cancelled = true;
          executions.cancelExecution(execId);
          manager.cancel('flow_${execId}_${subTask.id}');
        }
      });
      addTearDown(subscription.close);
      await expectLater(
          runChat(source), throwsA(isA<BlockExecutionException>()));
      expect(cancelled, true);
      expect(manager.starts, finalReply ? 1 : 0);
      expect(
          executions.execution(execId)!.status, FlowExecutionStatus.cancelled);
      expect(executions.execution(execId)!.subTasks.single.outcome,
          FlowStepOutcome.cancelled);
      await expectCleaned(source, bytes);
    });
  }

  test(
      'late valid reply after retained-history cancellation is never completed',
      () async {
    final bytes = [1, 2, 3];
    final source =
        await File('${directory.path}/speech.wav').writeAsBytes(bytes);
    manager.onStart = () => executions.cancelExecution(execId);
    await expectLater(runChat(source), throwsA(isA<BlockExecutionException>()));
    expect(manager.starts, 1);
    expect(executions.execution(execId)!.status, FlowExecutionStatus.cancelled);
    await expectCleaned(source, bytes);
  });
}
