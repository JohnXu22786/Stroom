// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/chat_executor.dart';

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
      fullReply: reply.content,
    );
  }
}

class _GatedConversations extends ConversationsNotifier {
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
    directory = await Directory.systemTemp.createTemp('flow_media_cancel_');
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
      status: TaskStatus.waiting,
    );
    executions.addSubTask(execId, subTask);
    expect(await executions.persist(), isTrue);
  });

  tearDown(() async {
    if (executions.mounted) executions.dispose();
    background.dispose();
    manager.dispose();
    container.dispose();
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  Future<String> runChat(File source) => executeChatBlock(
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
        bgNotifier: background,
        chatManager: manager,
        conversationsNotifier: container.read(conversationsProvider.notifier),
      );

  Future<void> expectCleaned(File source, List<int> bytes) async {
    expect(container.read(conversationsProvider), isEmpty);
    expect(await source.readAsBytes(), bytes);
    final attachments = Directory('${directory.path}/attachments');
    if (await attachments.exists()) {
      expect(await attachments.list().where((item) => item is File).toList(),
          isEmpty);
    }
    expect(
        background.state.where((task) => task.status == TaskStatus.completed),
        isEmpty);
  }

  test('deletion during conversation load preserves the earlier attempt',
      () async {
    container.dispose();
    late _GatedConversations conversations;
    container = ProviderContainer(overrides: [
      conversationsProvider
          .overrideWith((ref) => conversations = _GatedConversations(ref)),
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
          conversationId: convId,
        ),
      ]),
    ]);
    final bytes = [1, 2, 3];
    final source =
        await File('${directory.path}/speech.wav').writeAsBytes(bytes);
    final pending = runChat(source);
    await conversations.entered.future.timeout(const Duration(seconds: 5));
    expect(manager.starts, 0);
    final removal = executions.removeExecution(execId);
    conversations.release.complete();
    await expectLater(pending, throwsA(isA<BlockExecutionException>()));
    await removal;
    expect(container.read(conversationsProvider).single.id, convId);
    expect(await AttachmentStorage.readFile(oldCopy), [9, 8, 7]);
    expect(await source.readAsBytes(), bytes);
    expect(manager.starts, 0);
  });

  test('deletion during attachment storage cleans the new copy', () async {
    final bytes = [1, 2, 3];
    final source =
        await File('${directory.path}/speech.wav').writeAsBytes(bytes);
    final gate = documents.gate = Completer<void>();
    documents.entered = Completer<void>();
    final pending = runChat(source);
    await documents.entered!.future.timeout(const Duration(seconds: 5));
    final removal = executions.removeExecution(execId);
    gate.complete();
    await expectLater(pending, throwsA(isA<BlockExecutionException>()));
    await removal;
    expect(manager.starts, 0);
    await expectCleaned(source, bytes);
  });

  for (final finalReply in [false, true]) {
    test(
        'deletion during ${finalReply ? 'final reply' : 'user message'} save stops chat',
        () async {
      final bytes = [1, 2, 3];
      final source =
          await File('${directory.path}/speech.wav').writeAsBytes(bytes);
      Future<void>? removal;
      final subscription =
          container.listen(conversationsProvider, (previous, next) {
        if (removal != null) return;
        final role = finalReply ? 'assistant' : 'user';
        if (next.any((conversation) =>
            conversation.messages.any((message) => message.role == role))) {
          removal = executions.removeExecution(execId);
        }
      });
      addTearDown(subscription.close);
      await expectLater(
          runChat(source), throwsA(isA<BlockExecutionException>()));
      expect(removal, isNotNull);
      await removal;
      expect(manager.starts, finalReply ? 1 : 0);
      await expectCleaned(source, bytes);
    });
  }

  test('a late valid reply cannot complete a deleted execution', () async {
    final bytes = [1, 2, 3];
    final source =
        await File('${directory.path}/speech.wav').writeAsBytes(bytes);
    Future<void>? removal;
    manager.onStart = () => removal = executions.removeExecution(execId);
    await expectLater(runChat(source), throwsA(isA<BlockExecutionException>()));
    await removal;
    expect(manager.starts, 1);
    expect(executions.execution(execId), isNull);
    await expectCleaned(source, bytes);
  });
}
