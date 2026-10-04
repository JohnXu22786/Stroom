// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
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
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/chat_stream_manager.dart';
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
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/services/block_executors/chat_executor.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';
import 'package:stroom/task_flow/services/task_flow_scheduler.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  Completer<void>? gate;
  Completer<void>? entered;
  @override
  Future<String> getApplicationDocumentsPath() async {
    final pending = gate;
    if (pending != null) {
      gate = null;
      entered?.complete();
      await pending.future;
    }
    return path;
  }
}

class _Flows extends TaskFlowNotifier {
  void changeInputType(String id, IOType type) {
    state = state
        .map((flow) => flow.id == id ? flow.copyWith(inputType: type) : flow)
        .toList();
  }

  @override
  Future<bool> persist() async => true;
}

class _Entries extends ProviderEntriesNotifier {
  _Entries(ProviderEntriesState entries) {
    state = entries;
  }
}

class _Assistants extends AssistantsNotifier {
  _Assistants(List<Assistant> assistants) {
    state = assistants;
  }
}

class _Manager extends ChatStreamManager {
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
      content: 'Summary',
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

class _RejectExecutionRemovalNotifier extends TaskFlowExecutionNotifier {
  bool rejectWrites = false;

  @override
  Future<bool> persist() =>
      rejectWrites ? Future<bool>.value(false) : super.persist();
}

class _GatedRegistrationNotifier extends TaskFlowExecutionNotifier {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool holdNextWrite = true;
  bool rejectHeldWrite = false;

  @override
  Future<bool> persist() async {
    if (holdNextWrite) {
      holdNextWrite = false;
      entered.complete();
      await release.future;
      if (rejectHeldWrite) return false;
    }
    return super.persist();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previous;
  final trackedExecutions = <TaskFlowExecutionNotifier>[];
  final trackedBackgrounds = <BackgroundTaskNotifier>[];

  TaskFlowExecutionNotifier trackedExecution() {
    final notifier = TaskFlowExecutionNotifier();
    trackedExecutions.add(notifier);
    return notifier;
  }

  BackgroundTaskNotifier trackedBackground() {
    final notifier = BackgroundTaskNotifier();
    trackedBackgrounds.add(notifier);
    return notifier;
  }

  setUp(() async {
    trackedExecutions.clear();
    trackedBackgrounds.clear();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    directory = await Directory.systemTemp.createTemp('flow_media_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();
  });
  tearDown(() async {
    // Flow and background notifiers enqueue writes. Finish them while their
    // path provider still points at this test's temporary directory.
    for (final execution in trackedExecutions) {
      if (execution.mounted) expect(await execution.persist(), isTrue);
      await execution.persistenceResult;
    }
    for (final background in trackedBackgrounds) {
      await background.pendingPersistence;
    }
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  test('non-UTF-8 picked text is rejected before attachment storage', () async {
    final file =
        await File('${directory.path}/copy.bin').writeAsBytes([0xc3, 0x28]);
    await expectLater(
      prepareFlowChatMessage(
        FlowPayload.file(
          fileReference: file.path,
          type: IOType.file,
          fileName: 'report.txt',
        ),
        'invalid-text',
      ),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'text encoding', contains('UTF-8'))),
    );
    expect(await Directory('${directory.path}/attachments').exists(), isFalse);

    await file.writeAsBytes(utf8.encode('Valid UTF-8 text'));
    final message = await prepareFlowChatMessage(
      FlowPayload.file(
        fileReference: file.path,
        type: IOType.file,
        fileName: 'report.txt',
      ),
      'valid-text',
    );
    final request = await const OpenAIProtocol().buildRequest(
      history: [message],
    );
    expect(jsonEncode(request.messages.single), contains('Valid UTF-8 text'));

    await file.writeAsBytes([...utf8.encode('%PDF-1.7\n'), 0xff]);
    final pdf = await prepareFlowChatMessage(
      FlowPayload.file(
        fileReference: file.path,
        type: IOType.file,
        fileName: 'report.txt',
      ),
      'binary-pdf',
      endpointType: 'anthropic',
    );
    final anthropic = await const AnthropicProtocol().buildRequest(
      history: [pdf],
    );
    final part = (anthropic.messages.single['content'] as List).single;
    expect(part['type'], 'document');
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

  test('app media names retain formats for chat attachment previews', () async {
    for (final (name, format, type, bytes) in [
      ('recording', 'mp3', IOType.audio, [0x49, 0x44, 0x33, 4, 0, 0]),
      ('clip', 'mp4', IOType.video, [0, 0, 0, 24, 102, 116, 121, 112]),
    ]) {
      final source =
          await File('${directory.path}/$name.$format').writeAsBytes(bytes);
      final selectedName = flowMediaRecordFileName(name, format);
      final message = await prepareFlowChatMessage(
        FlowPayload.file(
          fileReference: source.path,
          type: type,
          fileName: selectedName,
        ),
        'preview-$name',
      );
      expect(message.attachments.single.fileName, '$name.$format');
      expect(message.attachments.single.fileType, type.name);
    }
    expect(flowMediaRecordFileName('photo.svg', '.SVG'), 'photo.svg');
  });

  test('SVG is rejected before either chat protocol receives an attachment',
      () async {
    final source = await File('${directory.path}/vector.svg')
        .writeAsString('<svg xmlns="http://www.w3.org/2000/svg"></svg>');
    for (final endpoint in ['openai', 'anthropic']) {
      await expectLater(
        prepareFlowChatMessage(
          FlowPayload.file(fileReference: source.path, type: IOType.image),
          'svg-$endpoint',
          endpointType: endpoint,
        ),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'unsupported SVG', contains('SVG'))),
      );
    }
  });

  test('unsupported image and audio subtypes never allocate an attachment',
      () async {
    final bmp = await File('${directory.path}/photo.bmp')
        .writeAsBytes([0x42, 0x4d, 0, 0, 0, 0]);
    final wma = await File('${directory.path}/recording.wma').writeAsBytes([
      0x30,
      0x26,
      0xb2,
      0x75,
      0x8e,
      0x66,
      0xcf,
      0x11,
    ]);
    for (final (source, endpoint) in [
      (bmp, 'openai'),
      (bmp, 'anthropic'),
      (wma, 'openai'),
    ]) {
      await expectLater(
        prepareFlowChatMessage(
          FlowPayload.file(fileReference: source.path, type: IOType.file),
          'unsupported-$endpoint',
          endpointType: endpoint,
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'unsupported media subtype',
          contains('不支持'),
        )),
      );
    }
    final attachments = Directory('${directory.path}/attachments');
    expect(await attachments.exists(), isFalse);

    // Closely related formats otherwise fall through the shared encoder's
    // JPEG or MP3 fallback just like BMP and WMA.
    for (final mime in ['image/tiff', 'image/avif', 'image/heic']) {
      expect(flowChatInputError(IOType.image, 'openai', mimeType: mime),
          contains('不支持'));
    }
    for (final mime in ['audio/x-aiff', 'audio/opus', 'audio/x-ms-wma']) {
      expect(flowChatInputError(IOType.audio, 'openai', mimeType: mime),
          contains('不支持'));
    }
  });

  test('supported image and audio subtypes keep their protocol formats',
      () async {
    for (final (name, bytes, mime) in [
      (
        'photo.png',
        [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
        'image/png'
      ),
      ('photo.jpg', [0xff, 0xd8, 0xff, 0xe0], 'image/jpeg'),
      ('photo.gif', utf8.encode('GIF89a'), 'image/gif'),
      ('photo.webp', utf8.encode('RIFF0000WEBP'), 'image/webp'),
    ]) {
      final source = await File('${directory.path}/$name').writeAsBytes(bytes);
      for (final endpoint in ['openai', 'anthropic']) {
        final message = await prepareFlowChatMessage(
          FlowPayload.file(fileReference: source.path, type: IOType.image),
          '$endpoint-$name',
          endpointType: endpoint,
        );
        expect(message.attachments.single.mimeType, mime);
        if (endpoint == 'openai') {
          final request =
              await const OpenAIProtocol().buildRequest(history: [message]);
          final part = (request.messages.single['content'] as List).single;
          expect(part['image_url']['url'], startsWith('data:$mime;base64,'));
        } else {
          final request =
              await const AnthropicProtocol().buildRequest(history: [message]);
          final part = (request.messages.single['content'] as List).single;
          expect(part['source']['media_type'], mime);
        }
      }
    }
    for (final (name, bytes, format) in [
      ('speech.mp3', [0x49, 0x44, 0x33, 4, 0, 0], 'mp3'),
      ('speech.wav', utf8.encode('RIFF0000WAVE'), 'wav'),
      ('speech.m4a', utf8.encode('0000ftypM4A '), 'm4a'),
    ]) {
      final source = await File('${directory.path}/$name').writeAsBytes(bytes);
      final message = await prepareFlowChatMessage(
        FlowPayload.file(fileReference: source.path, type: IOType.audio),
        'audio-$name',
      );
      final request =
          await const OpenAIProtocol().buildRequest(history: [message]);
      final part = (request.messages.single['content'] as List).single;
      expect(part['input_audio']['format'], format);
    }
  });

  test('chat title uses the selected filename, not the storage hash', () async {
    final storagePath = await AttachmentStorage.saveFile(
      'meeting.mp3',
      Uint8List.fromList([0x49, 0x44, 0x33, 4, 0, 0]),
    );
    final copy = File('${directory.path}/$storagePath');
    expect(await chatOutputTitle(copy.path, fileName: 'meeting.mp3'),
        '助手回复_meeting');
  });

  test('execution history keeps picker name and copy until its last removal',
      () async {
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nreport'));
    final storagePath = await AttachmentStorage.saveFile('notes.pdf', bytes);
    final copy = File('${directory.path}/$storagePath');
    final executions = trackedExecution();
    addTearDown(executions.dispose);
    final first = executions.addExecution(
      flowId: 'flow',
      flowName: 'Flow',
      inputText: copy.path,
      inputType: IOType.file,
      inputMimeType: 'application/pdf',
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
    expect(restored.inputMimeType, 'application/pdf');
    expect(restored.inputStoragePath, storagePath);
    expect(restored.inputType, IOType.file);
    expect(
      TaskFlowExecution.fromMap({...restored.toMap(), 'inputType': 'unknown'})
          .inputType,
      isNull,
    );
    final retry = FlowRunInput(
      text: restored.inputText,
      mimeType: restored.inputMimeType,
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

  test('audio MP4 MIME survives execution history and a cold retry', () async {
    final bytes = Uint8List.fromList(
        [0, 0, 0, 24, 102, 116, 121, 112, 105, 115, 111, 109]);
    final storagePath =
        await AttachmentStorage.saveFile('recording.mp4', bytes);
    final copy = File('${directory.path}/$storagePath');
    final executions = trackedExecution();
    addTearDown(executions.dispose);
    final id = executions.addExecution(
      flowId: 'flow',
      flowName: 'Flow',
      inputText: copy.path,
      inputMimeType: 'audio/mp4',
      inputType: IOType.audio,
      inputFileName: 'recording.mp4',
      inputStoragePath: storagePath,
    );
    expect(await executions.persist(), isTrue);
    final restored =
        TaskFlowExecution.fromMap(executions.execution(id)!.toMap());
    expect(restored.inputType, IOType.audio);
    final retry = FlowRunInput(
      text: restored.inputText,
      mimeType: restored.inputMimeType,
      fileName: restored.inputFileName,
      ownedStoragePath: restored.inputStoragePath,
    );
    final message = await prepareFlowChatMessage(
      FlowPayload.fromValue(retry.text, IOType.audio,
          mimeType: retry.mimeType, fileName: retry.fileName),
      'audio-retry',
    );
    expect(message.attachments.single.fileType, 'audio');
    expect(message.attachments.single.mimeType, 'audio/mp4');
    expect(message.attachments.single.fileName, 'recording.mp4');
  });

  test('queued registration protects its copy during cleanup without deadlock',
      () async {
    final path = await AttachmentStorage.saveFile(
        'queued.pdf', Uint8List.fromList(utf8.encode('%PDF-1.7\nqueued')));
    final copy = File('${directory.path}/$path');
    final notifier = _GatedRegistrationNotifier();
    trackedExecutions.add(notifier);
    addTearDown(notifier.dispose);
    final blocking = notifier.addExecutions([
      TaskFlowExecution(id: 'blocking', flowId: 'flow', flowName: 'Blocking')
    ]);
    await notifier.entered.future.timeout(const Duration(seconds: 5));
    final retry = TaskFlowExecution(
        id: 'queued-retry',
        flowId: 'flow',
        flowName: 'Retry',
        inputText: copy.path,
        inputStoragePath: path);
    final queued = Completer<void>();
    final registered = notifier.withInputStoragePathLock(path, () async {
      final pending = notifier.addExecutions([retry]);
      queued.complete();
      return pending;
    });
    await queued.future.timeout(const Duration(seconds: 5));
    expect(notifier.execution(retry.id), isNull,
        reason: 'the preceding registration still holds the queue');
    expect(notifier.referencesInputStoragePath(path), isTrue,
        reason: 'queued requests reserve their copies before publishing state');
    // A removed owner may ask for cleanup while the retry holds this path
    // lock and waits for the registration queue. Cleanup must finish promptly.
    await notifier
        .cleanupInputStoragePaths([path]).timeout(const Duration(seconds: 5));
    expect(await copy.exists(), isTrue);
    notifier.release.complete();
    expect(await blocking.timeout(const Duration(seconds: 5)), isTrue);
    expect(await registered.timeout(const Duration(seconds: 5)), isTrue);
    expect(notifier.execution(retry.id), isNotNull);
    await notifier.removeExecution(retry.id);
    expect(await copy.exists(), isFalse,
        reason: 'the settled request releases its reservation');
  });

  test('failed registration releases its reserved copy for later cleanup',
      () async {
    final path = await AttachmentStorage.saveFile(
        'rejected.pdf', Uint8List.fromList(utf8.encode('%PDF-1.7\nrejected')));
    final copy = File('${directory.path}/$path');
    final notifier = _GatedRegistrationNotifier()..rejectHeldWrite = true;
    trackedExecutions.add(notifier);
    addTearDown(notifier.dispose);
    final save = notifier.addExecutions([
      TaskFlowExecution(
          id: 'rejected',
          flowId: 'flow',
          flowName: 'Rejected',
          inputText: copy.path,
          inputStoragePath: path)
    ]);
    expect(notifier.referencesInputStoragePath(path), isTrue);
    await notifier.entered.future.timeout(const Duration(seconds: 5));
    notifier.release.complete();
    expect(await save, isFalse);
    expect(notifier.execution('rejected'), isNull);
    expect(notifier.referencesInputStoragePath(path), isFalse);
    await notifier.cleanupInputStoragePaths([path]);
    expect(await copy.exists(), isFalse);
  });

  for (final accepted in [false, true]) {
    test(
        'disposal retains owned input with ${accepted ? 'accepted' : 'rejected'} registration',
        () async {
      final path = await AttachmentStorage.saveFile('retained.pdf',
          Uint8List.fromList(utf8.encode('%PDF-1.7\nretained')));
      final copy = File('${directory.path}/$path');
      final notifier = _GatedRegistrationNotifier()
        ..holdNextWrite = false
        ..rejectHeldWrite = !accepted;
      trackedExecutions.add(notifier);
      final existing = TaskFlowExecution(
          id: 'existing-owned',
          flowId: 'flow',
          flowName: 'Existing',
          inputText: copy.path,
          inputType: IOType.file,
          inputFileName: 'retained.pdf',
          inputStoragePath: path);
      expect(await notifier.addExecutions([existing]), isTrue);
      notifier.holdNextWrite = true;
      final registration = notifier.addExecutions([
        TaskFlowExecution(
            id: 'pending-owned',
            flowId: 'flow',
            flowName: 'Pending',
            status: FlowExecutionStatus.waiting,
            inputText: copy.path,
            inputType: IOType.file,
            inputFileName: 'retained.pdf',
            inputStoragePath: path)
      ]);
      await notifier.entered.future.timeout(const Duration(seconds: 5));
      notifier.cancelExecution(existing.id);
      notifier.dispose();
      notifier.release.complete();
      expect(await registration, accepted);
      expect(await notifier.persist(), isTrue);
      await notifier.cleanupInputStoragePaths([path]);
      final records = (jsonDecode(
              await File('${directory.path}/task_flows/executions.json')
                  .readAsString()) as List)
          .cast<Map<String, dynamic>>();
      expect(
          records.map((entry) => entry['id']),
          unorderedEquals(accepted
              ? ['existing-owned', 'pending-owned']
              : ['existing-owned']));
      final restored = TaskFlowExecution.fromMap(
          records.firstWhere((entry) => entry['id'] == 'existing-owned'));
      expect(restored.status, FlowExecutionStatus.cancelled);
      expect(restored.inputStoragePath, path);
      expect(restored.inputFileName, 'retained.pdf');
      expect(await copy.exists(), isTrue);
    });
  }

  test('bulk execution removal waits for every shared copy reference',
      () async {
    final storagePath = await AttachmentStorage.saveFile(
      'notes.pdf',
      Uint8List.fromList(utf8.encode('%PDF-1.7\nreport')),
    );
    final copy = File('${directory.path}/$storagePath');
    final executions = trackedExecution();
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

  test('retry registration cannot race the final picker-copy deletion',
      () async {
    final path = await AttachmentStorage.saveFile(
      'input.pdf',
      Uint8List.fromList(utf8.encode('%PDF-1.7\nreport')),
    );
    final copy = File('${directory.path}/$path');
    final executions = trackedExecution();
    final assistant = Assistant(
      id: 'assistant',
      name: 'Assistant',
      prompt: 'Help',
      defaultModelId: 'gpt',
      defaultProviderName: 'OpenAI',
    );
    final flows = _Flows();
    final flowId = flows.addFlow(
      name: 'Retry flow',
      inputType: IOType.file,
      blocks: [
        TaskFlowBlock(
          typeKey: BlockType.chat,
          params: {'assistantId': assistant.id},
        ),
      ],
    );
    final manager = _Manager();
    final container = ProviderContainer(overrides: [
      taskFlowListProvider.overrideWith((ref) => flows),
      taskFlowExecutionsProvider.overrideWith((ref) => executions),
      providerEntriesProvider.overrideWith(
        (ref) => _Entries(ProviderEntriesState(entries: [
          ProviderEntry(name: 'LLM', type: 'llm', configs: [
            ProviderConfigItem(
              providerName: 'OpenAI',
              host: 'https://example.com',
              key: 'test',
              models: [ModelConfig(name: 'GPT', modelId: 'gpt')],
            ),
          ]),
        ])),
      ),
      assistantProvider.overrideWith((ref) => _Assistants([assistant])),
      chatStreamManagerProvider.overrideWithValue(manager),
    ]);
    addTearDown(container.dispose);
    addTearDown(manager.dispose);
    final old = executions.addExecution(
      flowId: 'flow',
      flowName: 'Flow',
      inputText: copy.path,
      inputStoragePath: path,
    );
    expect(await executions.persist(), isTrue);

    final documents = PathProviderPlatform.instance as _Documents;
    final deleteGate = documents.gate = Completer<void>();
    documents.entered = Completer<void>();
    final removal = executions.removeExecution(old);
    await documents.entered!.future.timeout(const Duration(seconds: 5));
    expect(
      () => executions.addExecution(
        flowId: 'flow',
        flowName: 'Unsafe retry',
        inputText: copy.path,
        inputStoragePath: path,
      ),
      throwsStateError,
    );
    final retry =
        container.read(taskFlowExecutionServiceProvider).launchFlowMany(
      flowId,
      [
        FlowRunInput(
          text: copy.path,
          fileName: 'input.pdf',
          ownedStoragePath: path,
        ),
      ],
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(taskFlowExecutionsProvider), isEmpty,
        reason: 'the retry waits until the copy deletion completes');
    deleteGate.complete();
    await removal;
    await expectLater(
      retry,
      throwsA(isA<TaskFlowValidationException>()),
    );
    expect(await copy.exists(), isFalse);
    expect(executions.execution(old), isNull);

    // If the retry owns the path first, removal waits and keeps its copy.
    final secondPath = await AttachmentStorage.saveFile(
      'second.pdf',
      Uint8List.fromList(utf8.encode('%PDF-1.7\nsecond')),
    );
    final secondCopy = File('${directory.path}/$secondPath');
    final secondOld = executions.addExecution(
      flowId: 'flow',
      flowName: 'Second flow',
      inputText: secondCopy.path,
      inputStoragePath: secondPath,
    );
    expect(await executions.persist(), isTrue);
    final registerGate = Completer<void>();
    final registerEntered = Completer<void>();
    final registered =
        executions.withInputStoragePathLock(secondPath, () async {
      registerEntered.complete();
      await registerGate.future;
      final id = executions.addExecution(
        flowId: 'flow',
        flowName: 'Second retry',
        inputText: secondCopy.path,
        inputStoragePath: secondPath,
      );
      expect(await executions.persist(), isTrue);
      return id;
    });
    await registerEntered.future.timeout(const Duration(seconds: 5));
    final secondRemoval = executions.removeExecution(secondOld);
    registerGate.complete();
    final retryId = await registered;
    await secondRemoval;
    expect(executions.execution(retryId), isNotNull);
    expect(await secondCopy.exists(), isTrue);
  });

  test('failed execution deletion keeps its retry input and stops its work',
      () async {
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nreport'));
    final storagePath = await AttachmentStorage.saveFile('notes.pdf', bytes);
    final copy = File('${directory.path}/$storagePath');
    final executions = _RejectExecutionRemovalNotifier();
    trackedExecutions.add(executions);
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
    expect(executions.execution(id)!.status, FlowExecutionStatus.interrupted);
    expect(executions.execution(id)!.subTasks.single.status, TaskStatus.paused);
    expect(executions.execution(id)!.isTerminal, isTrue);
    executions.updateSubTaskStatus(
      id,
      executions.execution(id)!.subTasks.single.id,
      TaskStatus.completed,
    );
    expect(executions.execution(id)!.status, FlowExecutionStatus.interrupted,
        reason: 'a late task callback cannot revive a cancelled execution');
    expect(await copy.readAsBytes(), bytes);
    executions.rejectWrites = false;
    await executions.removeExecution(id);
    expect(await copy.exists(), isFalse);
  });

  test('failed disk removal clears a queued flow and retains its owned input',
      () async {
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nreport'));
    final storagePath = await AttachmentStorage.saveFile('notes.pdf', bytes);
    final copy = File('${directory.path}/$storagePath');
    final assistant = Assistant(
        id: 'assistant',
        name: 'Assistant',
        prompt: 'Help',
        defaultModelId: 'gpt',
        defaultProviderName: 'OpenAI');
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(name: 'LLM', type: 'llm', configs: [
        ProviderConfigItem(
            providerName: 'OpenAI',
            host: 'https://example.com',
            key: 'test',
            models: [ModelConfig(name: 'GPT', modelId: 'gpt')])
      ])
    ]);
    final flows = _Flows();
    final flowId =
        flows.addFlow(name: 'Queued file', inputType: IOType.file, blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': assistant.id})
    ]);
    final executions = trackedExecution();
    final scheduler = TaskFlowScheduler(coreCount: 4, rssBytes: () => 0);
    await scheduler.acquire('other-work', scheduler.currentBudget);
    addTearDown(() => scheduler.release('other-work'));
    var starts = 0;
    final container = ProviderContainer(overrides: [
      taskFlowListProvider.overrideWith((ref) => flows),
      taskFlowExecutionsProvider.overrideWith((ref) => executions),
      providerEntriesProvider.overrideWith((ref) => _Entries(providers)),
      assistantProvider.overrideWith((ref) => _Assistants([assistant])),
      taskFlowSchedulerProvider.overrideWithValue(scheduler),
      taskFlowBlockRunnerProvider
          .overrideWithValue((block, input, id, step) async {
        starts++;
        return const FlowPayload.text('Summary');
      }),
    ]);
    addTearDown(container.dispose);
    final running =
        container.read(taskFlowExecutionServiceProvider).startFlowMany(flowId, [
      FlowRunInput(
          text: copy.path, fileName: 'notes.pdf', ownedStoragePath: storagePath)
    ]);
    for (var i = 0; i < 100 && scheduler.queuedCount == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(scheduler.queuedCount, 1);
    final id = executions.executions.single.id;
    expect(executions.execution(id)!.queued, isTrue);
    expect(await executions.persist(), isTrue);

    // A directory at the destination makes AtomicFile's asynchronous rename
    // fail after removal has already cancelled the real scheduler wait.
    final recordsFile = File('${directory.path}/task_flows/executions.json');
    await recordsFile.delete();
    final blockedDestination = await Directory(recordsFile.path).create();
    try {
      await executions.removeExecution(id).timeout(const Duration(seconds: 5));
      await running.timeout(const Duration(seconds: 5));
      expect(executions.persistenceError, isA<FileSystemException>());
      final retained = executions.execution(id)!;
      expect(retained.status, FlowExecutionStatus.interrupted);
      expect(retained.queued, isFalse);
      expect(retained.subTasks.single.outcome, FlowStepOutcome.interrupted);
      expect(scheduler.queuedCount, 0);
      expect(starts, 0);
      expect(await copy.readAsBytes(), bytes);
    } finally {
      await blockedDestination.delete(recursive: true);
    }
    expect(await executions.persist(), isTrue);
    final saved = TaskFlowExecution.fromMap(
        (jsonDecode(await recordsFile.readAsString()) as List).single);
    expect(saved.status, FlowExecutionStatus.interrupted);
    expect(saved.queued, isFalse);
    expect(saved.inputStoragePath, storagePath);
    await executions.removeExecution(id);
    expect(await copy.exists(), isFalse);
  });

  test(
      'owned file batches and retries retain names and reject changed input types',
      () async {
    final assistant = Assistant(
        id: 'assistant',
        name: 'Assistant',
        prompt: 'Help',
        defaultModelId: 'gpt',
        defaultProviderName: 'OpenAI');
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(name: 'LLM', type: 'llm', configs: [
        ProviderConfigItem(
            providerName: 'OpenAI',
            host: 'https://example.com',
            key: 'test',
            models: [ModelConfig(name: 'GPT', modelId: 'gpt')])
      ])
    ]);
    final flows = _Flows();
    final flowId =
        flows.addFlow(name: 'File batch', inputType: IOType.file, blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': assistant.id})
    ]);
    final inputs = <FlowRunInput>[];
    for (final name in ['first', 'second']) {
      final path = await AttachmentStorage.saveFile(
          '$name.pdf', Uint8List.fromList(utf8.encode('%PDF-1.7\n$name')));
      inputs.add(FlowRunInput(
          text: '${directory.path}/$path',
          fileName: '$name.pdf',
          ownedStoragePath: path));
    }
    final executions = trackedExecution();
    final received = <FlowPayload>[];
    final container = ProviderContainer(overrides: [
      taskFlowListProvider.overrideWith((ref) => flows),
      taskFlowExecutionsProvider.overrideWith((ref) => executions),
      providerEntriesProvider.overrideWith((ref) => _Entries(providers)),
      assistantProvider.overrideWith((ref) => _Assistants([assistant])),
      taskFlowBlockRunnerProvider
          .overrideWithValue((block, input, id, step) async {
        received.add(input);
        return const FlowPayload.text('Summary');
      }),
    ]);
    addTearDown(container.dispose);
    final service = container.read(taskFlowExecutionServiceProvider);
    await service.startFlowMany(flowId, inputs);
    expect(received.map((payload) => payload.fileName),
        ['first.pdf', 'second.pdf']);
    final original = executions.executions
        .where((entry) => entry.inputFileName == 'first.pdf')
        .single;
    expect(executions.executions.map((entry) => entry.inputStoragePath),
        unorderedEquals(inputs.map((input) => input.ownedStoragePath)));
    final retryIds = await service.retryExecution(original.id);
    for (var i = 0;
        i < 100 &&
            executions.execution(retryIds.single)?.status !=
                FlowExecutionStatus.completed;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(executions.execution(retryIds.single)!.status,
        FlowExecutionStatus.completed);
    expect(received.last.fileName, 'first.pdf');
    await executions.removeExecution(original.id);
    expect(await File(inputs.first.text).exists(), isTrue);
    flows.changeInputType(flowId, IOType.text);
    await expectLater(
        service.retryExecution(retryIds.single, useLatestConfiguration: true),
        throwsA(isA<TaskFlowValidationException>()
            .having((error) => error.isInputError, 'input mismatch', isTrue)));
    await executions.removeExecution(retryIds.single);
    expect(await File(inputs.first.text).exists(), isFalse);
    final remaining = executions.executions.single;
    await executions.removeExecution(remaining.id);
    expect(await File(inputs.last.text).exists(), isFalse);
  });

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
        final executions = trackedExecution();
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
            bgNotifier: trackedBackground(),
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
}
