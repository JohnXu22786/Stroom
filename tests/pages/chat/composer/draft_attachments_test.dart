// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/attachment_storage.dart';

/// 测试用 PathProvider：把"应用文档目录"指向临时目录，让
/// AttachmentStorage 的磁盘读写落到真实临时文件上。
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;

  @override
  Future<String> getTemporaryPath() async => root;
}

class _RetryableWritePreferencesStore extends InMemorySharedPreferencesStore {
  _RetryableWritePreferencesStore(super.data) : super.withData();

  bool allowWrites = true;
  int writeCount = 0;
  Completer<void>? writeStarted;
  Completer<void>? writeGate;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    // These tests exercise conversation snapshot ordering. Active-conversation
    // preference writes are independent and must not consume its write gate.
    if (key == 'flutter.conversations') {
      writeCount++;
      if (!allowWrites) return false;
      final gate = writeGate;
      if (gate != null) {
        writeGate = null;
        if (writeStarted?.isCompleted == false) writeStarted!.complete();
        await gate.future;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

class _AttachmentSaveGate {
  final started = Completer<void>();
  final release = Completer<void>();
}

class _ControlledAttachmentStorage {
  _ControlledAttachmentStorage(this.root);

  final String root;
  final List<_AttachmentSaveGate> _saveGates = [];
  int _nextFileId = 0;

  _AttachmentSaveGate blockNextSave() {
    final gate = _AttachmentSaveGate();
    _saveGates.add(gate);
    return gate;
  }

  Future<String> saveFile(String fileName, Uint8List bytes) async {
    final gate = _saveGates.removeAt(0);
    gate.started.complete();
    await gate.release.future;

    final storagePath = 'attachments/test_import_${_nextFileId++}.bin';
    final file = File('$root/$storagePath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return storagePath;
  }

  Future<bool> deleteFile(String storagePath) async {
    final file = File('$root/$storagePath');
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }
}

void _dummyOnStop() {}
void _dummyOnToolsChanged(Set<String> tools) {}
void _dummyOnModelSelected(int index) {}

ProviderContainer _buildContainer() {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = [
          Conversation(id: 'conv-1', title: '对话A', messages: []),
          Conversation(id: 'conv-2', title: '对话B', messages: []),
        ];
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => 'conv-1'),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
    ],
  );
}

Future<ProviderContainer> _buildPersistedContainer({
  List<Attachment> draftAttachments = const [],
  void Function(_RetryableWritePreferencesStore store)? configureStore,
}) async {
  final conversation = Conversation(
    id: 'conv-1',
    title: '对话A',
    messages: [],
    draftAttachments: draftAttachments,
  );
  final conversationJson = jsonEncode([conversation.toMap()]);
  SharedPreferences.setMockInitialValues({'conversations': conversationJson});
  _RetryableWritePreferencesStore? preferencesStore;
  if (configureStore != null) {
    preferencesStore = _RetryableWritePreferencesStore({
      'flutter.conversations': conversationJson,
    });
    SharedPreferencesStorePlatform.instance = preferencesStore;
  }
  final container = ProviderContainer(
    overrides: [
      activeConversationIdProvider.overrideWith((ref) => 'conv-1'),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
    ],
  );
  await container.read(conversationsProvider.notifier).ready;
  if (preferencesStore != null) {
    // Drain startup writes before installing the gate so it observes the
    // persistence operation under test, not a background initialization.
    await container
        .read(conversationsProvider.notifier)
        .persistSnapshotForAttachmentCleanup();
    configureStore!(preferencesStore);
  }
  return container;
}

Widget _composer({
  required ProviderContainer container,
  Key? key,
  String? conversationId = 'conv-1',
  String initialDraftText = '',
  List<Attachment> initialDraftAttachments = const [],
  String? editingMessageId,
  String? editingMessageText,
  List<Attachment>? editingMessageAttachments,
  required void Function(String, List<Attachment>) onSend,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: ChatComposerWidget(
          key: key,
          conversationId: conversationId,
          initialDraftText: initialDraftText,
          initialDraftAttachments: initialDraftAttachments,
          editingMessageId: editingMessageId,
          editingMessageText: editingMessageText,
          editingMessageAttachments: editingMessageAttachments,
          onSend: onSend,
          onStop: _dummyOnStop,
          onEnabledToolsChanged: _dummyOnToolsChanged,
          onModelSelected: _dummyOnModelSelected,
        ),
      ),
    ),
  );
}

/// 已压缩完成的图片附件（base64 ≤ 阈值 → 可直接发送）。
Attachment readyImage({String id = 'ready-1', String hash = 'hash-ready'}) {
  final payload = base64Encode(List<int>.generate(500, (i) => i % 251));
  return Attachment(
    id: id,
    fileName: 'photo.jpg',
    mimeType: 'image/jpeg',
    fileType: 'image',
    hash: hash,
    storagePath: 'attachments/${hash}_1.jpg',
    fileSize: 4096, // 原始文件大于阈值 → 内存载荷必为压缩产物
    conversationId: 'conv-1',
    base64Data: payload,
  );
}

/// 未压缩完成的大图附件（base64 为原始字节 → 不随草稿携带）。
Attachment rawImage({String id = 'raw-1', String hash = 'hash-raw'}) {
  final big = base64Encode(List<int>.generate(3 * 1024 * 1024, (i) => i % 251));
  return Attachment(
    id: id,
    fileName: 'big.png',
    mimeType: 'image/png',
    fileType: 'image',
    hash: hash,
    storagePath: 'attachments/${hash}_1.png',
    fileSize: 3 * 1024 * 1024,
    conversationId: 'conv-1',
    base64Data: big,
  );
}

void main() {
  late Directory tmpRoot;

  setUp(() {
    AttachmentStorage.resetOverridesForTesting();
    AppLogService.reset();
    AppLogService.disableFileLogging();
    tmpRoot = Directory.systemTemp.createTempSync('stroom_draft_att_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tmpRoot.path);
    AttachmentStorage.readFileOverrideForTesting = (path) async {
      final file = File('${tmpRoot.path}/attachments/${path.split('/').last}');
      return file.existsSync() ? file.readAsBytesSync() : null;
    };
    AttachmentStorage.restoreFileOverrideForTesting = (path, bytes) async {
      final file = File('${tmpRoot.path}/attachments/${path.split('/').last}')
        ..createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    };
    AttachmentStorage.deleteCompressedImageOverrideForTesting =
        ({required conversationId, required hash}) async => true;
  });

  tearDown(() {
    try {
      tmpRoot.deleteSync(recursive: true);
    } catch (_) {
      // 非关键清理
    }
    AppLogService.reset();
    AttachmentStorage.resetOverridesForTesting();
  });

  group('对话附件草稿', () {
    testWidgets(
      'conversation and edit draft switches discard in-flight imports',
      (tester) async {
        final container = _buildContainer();
        final key = GlobalKey<ChatComposerWidgetState>();
        final storage = _ControlledAttachmentStorage(tmpRoot.path);
        AttachmentStorage.saveFileOverrideForTesting = storage.saveFile;
        AttachmentStorage.deleteFileOverrideForTesting = storage.deleteFile;
        final firstSave = storage.blockNextSave();
        final attB = readyImage(id: 'att-b', hash: 'hash-b')
          ..conversationId = 'conv-2';

        await tester.pumpWidget(
          _composer(
            container: container,
            key: key,
            conversationId: 'conv-1',
            onSend: (text, atts) {},
          ),
        );

        late Future<void> pendingImport;
        await tester.runAsync(() async {
          pendingImport = key.currentState!.addPendingAttachmentForTesting(
            'old-chat.txt',
            Uint8List.fromList([1, 2, 3]),
          );
          await firstSave.started.future.timeout(const Duration(seconds: 15));
        });

        await tester.pumpWidget(
          _composer(
            container: container,
            key: key,
            conversationId: 'conv-2',
            initialDraftAttachments: [attB],
            onSend: (text, atts) {},
          ),
        );
        await tester.pump();

        firstSave.release.complete();
        await tester.runAsync(() => pendingImport);
        await tester.pump();

        expect(find.byKey(const ValueKey('pending_att_att-b')), findsOneWidget);
        expect(
          find.text('old-chat.txt'),
          findsNothing,
          reason:
              'late completion from conv-1 must not enter conv-2 pending draft',
        );
        final conv2 = container
            .read(conversationsProvider)
            .firstWhere((conversation) => conversation.id == 'conv-2');
        expect(
          conv2.draftAttachments,
          isEmpty,
          reason: 'a stale attachment import must not be saved into conv-2',
        );

        final attachmentFiles = Directory('${tmpRoot.path}/attachments');
        expect(
          attachmentFiles.existsSync()
              ? attachmentFiles.listSync()
              : <FileSystemEntity>[],
          isEmpty,
          reason:
              'the stale import file should be deleted after it is rejected',
        );

        final editSave = storage.blockNextSave();
        late Future<void> pendingEditImport;
        await tester.runAsync(() async {
          pendingEditImport = key.currentState!.addPendingAttachmentForTesting(
            'late-edit.txt',
            Uint8List.fromList([4, 5, 6]),
          );
          await editSave.started.future.timeout(const Duration(seconds: 15));
        });

        final originalEditAttachment = readyImage(
          id: 'edit-att',
          hash: 'hash-edit',
        )..conversationId = 'conv-2';
        await tester.pumpWidget(
          _composer(
            container: container,
            key: key,
            conversationId: 'conv-2',
            editingMessageId: 'edit-message',
            editingMessageText: 'edited text',
            editingMessageAttachments: [originalEditAttachment],
            onSend: (text, atts) {},
          ),
        );
        await tester.pump();

        editSave.release.complete();
        await tester.runAsync(() => pendingEditImport);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('pending_att_edit-att')),
          findsOneWidget,
        );
        expect(
          find.text('late-edit.txt'),
          findsNothing,
          reason: 'late completion must not enter a replacement edit session',
        );
        expect(
          attachmentFiles.existsSync()
              ? attachmentFiles.listSync()
              : <FileSystemEntity>[],
          isEmpty,
          reason: 'the stale edit-session import file should be deleted',
        );

        // didUpdateWidget saves the prior conversation after the frame; let
        // its debounced provider persistence timer finish before test teardown.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
      },
    );

    testWidgets(
      'edit import stays stale after switching away and back to its conversation',
      (tester) async {
        final container = _buildContainer();
        final key = GlobalKey<ChatComposerWidgetState>();
        final storage = _ControlledAttachmentStorage(tmpRoot.path);
        AttachmentStorage.saveFileOverrideForTesting = storage.saveFile;
        AttachmentStorage.deleteFileOverrideForTesting = storage.deleteFile;
        final save = storage.blockNextSave();
        final originalAttachment = readyImage(id: 'edit-att', hash: 'hash-edit')
          ..conversationId = 'conv-1';

        Widget editingComposer(String conversationId) => _composer(
              container: container,
              key: key,
              conversationId: conversationId,
              editingMessageId: 'edit-message',
              editingMessageText: 'edited text',
              editingMessageAttachments: [originalAttachment],
              onSend: (text, atts) {},
            );

        await tester.pumpWidget(editingComposer('conv-1'));

        late Future<void> pendingImport;
        await tester.runAsync(() async {
          pendingImport = key.currentState!.addPendingAttachmentForTesting(
            'late-edit.txt',
            Uint8List.fromList([4, 5, 6]),
          );
          await save.started.future.timeout(const Duration(seconds: 15));
        });

        await tester.pumpWidget(editingComposer('conv-2'));
        await tester.pumpWidget(editingComposer('conv-1'));
        await tester.pump();

        save.release.complete();
        await tester.runAsync(() => pendingImport);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('pending_att_edit-att')),
          findsOneWidget,
        );
        expect(find.text('late-edit.txt'), findsNothing);
        final attachmentFiles = Directory('${tmpRoot.path}/attachments');
        expect(
          attachmentFiles.existsSync()
              ? attachmentFiles.listSync()
              : <FileSystemEntity>[],
          isEmpty,
          reason:
              'the stale edit import file should be deleted after rejection',
        );
      },
    );

    testWidgets('picker results stay with the draft where picking began', (
      tester,
    ) async {
      final container = _buildContainer();
      final key = GlobalKey<ChatComposerWidgetState>();
      final storage = _ControlledAttachmentStorage(tmpRoot.path);
      AttachmentStorage.saveFileOverrideForTesting = storage.saveFile;
      AttachmentStorage.deleteFileOverrideForTesting = storage.deleteFile;
      final save = storage.blockNextSave();
      final attB = readyImage(id: 'att-b', hash: 'hash-b')
        ..conversationId = 'conv-2';

      await tester.pumpWidget(
        _composer(
          container: container,
          key: key,
          conversationId: 'conv-1',
          onSend: (text, atts) {},
        ),
      );

      final selectedBytes = Completer<Uint8List>();
      late Future<void> pendingImport;
      await tester.runAsync(() async {
        pendingImport =
            key.currentState!.addPendingAttachmentAfterPickerForTesting(
          'picked-in-conv-1.txt',
          selectedBytes.future,
        );
      });

      await tester.pumpWidget(
        _composer(
          container: container,
          key: key,
          conversationId: 'conv-2',
          initialDraftAttachments: [attB],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();

      await tester.runAsync(() async {
        selectedBytes.complete(Uint8List.fromList([7, 8, 9]));
        await save.started.future.timeout(const Duration(seconds: 15));
      });

      save.release.complete();
      await tester.runAsync(() => pendingImport);
      await tester.pump();

      expect(find.byKey(const ValueKey('pending_att_att-b')), findsOneWidget);
      expect(
        find.text('picked-in-conv-1.txt'),
        findsNothing,
        reason:
            'a picker result must not enter the conversation selected later',
      );
      final conv2 = container
          .read(conversationsProvider)
          .firstWhere((conversation) => conversation.id == 'conv-2');
      expect(
        conv2.draftAttachments,
        isEmpty,
        reason: 'a stale picker result must not be persisted to conv-2',
      );

      final attachmentFiles = Directory('${tmpRoot.path}/attachments');
      expect(
        attachmentFiles.existsSync()
            ? attachmentFiles.listSync()
            : <FileSystemEntity>[],
        isEmpty,
        reason: 'the stale picker result file should be deleted',
      );

      // Switching conversations schedules a debounced draft persistence write.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
    });

    testWidgets('恢复：initialDraftAttachments 进入 pending，发送时载荷直接可用', (
      tester,
    ) async {
      final container = _buildContainer();
      final att = readyImage();
      List<Attachment>? sent;

      await tester.pumpWidget(
        _composer(
          container: container,
          initialDraftAttachments: [att],
          onSend: (text, atts) => sent = atts,
        ),
      );
      await tester.pump();

      // 恢复的附件芯片可见
      expect(
        find.byKey(const ValueKey('pending_att_ready-1')),
        findsOneWidget,
        reason: '恢复的附件草稿必须显示为待发芯片',
      );

      // 发送：载荷（压缩 base64）原样带出，无需重新读取/压缩
      await tester.enterText(find.byType(TextField), '带着图发');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      // 让 notifier 的防抖持久化计时器（500ms）跑完，避免挂起
      await tester.pump(const Duration(milliseconds: 600));

      expect(sent, hasLength(1));
      expect(sent![0].id, 'ready-1');
      expect(
        sent![0].base64Data,
        att.base64Data,
        reason: '恢复的压缩 base64 必须直接可用（发送零等待）',
      );
    });

    testWidgets('保存：打字触发防抖保存，草稿快照写入 provider（压缩图带 base64，大图不带）', (
      tester,
    ) async {
      final container = _buildContainer();
      final ready = readyImage();
      final raw = rawImage();

      await tester.pumpWidget(
        _composer(
          container: container,
          initialDraftAttachments: [ready, raw],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();

      // 输入文字 → 防抖 800ms 后保存（文字 + 附件快照）
      await tester.enterText(find.byType(TextField), '草稿文字');
      await tester.pump(const Duration(milliseconds: 900));
      // 让 notifier 的防抖持久化计时器（500ms）跑完
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      final conv = container
          .read(conversationsProvider)
          .firstWhere((c) => c.id == 'conv-1');
      expect(conv.draftText, '草稿文字');
      expect(conv.draftAttachments, hasLength(2));

      final byId = {for (final a in conv.draftAttachments) a.id: a};
      expect(
        byId['ready-1']!.base64Data,
        ready.base64Data,
        reason: '压缩完成的图片必须携带 base64 随草稿持久化',
      );
      expect(
        byId['raw-1']!.base64Data,
        isNull,
        reason: '未压缩完的原始大 base64 不得塞进草稿 JSON（体积）',
      );
      expect(
        byId['raw-1']!.storagePath,
        raw.storagePath,
        reason: '文件引用必须保留，恢复时重新读取',
      );
      // 快照是深拷贝：后续修改 pending 不污染已保存的草稿
      expect(identical(byId['ready-1'], ready), isFalse);
    });

    testWidgets('切换对话：旧对话草稿（文字+附件）保存，新对话附件恢复', (tester) async {
      final container = _buildContainer();
      final attA = readyImage(id: 'att-a', hash: 'hash-a');
      final attB = readyImage(id: 'att-b', hash: 'hash-b');
      attB.conversationId = 'conv-2';

      // 对话1：输入文字 + 附件草稿
      await tester.pumpWidget(
        _composer(
          container: container,
          conversationId: 'conv-1',
          initialDraftAttachments: [attA],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '对话1的草稿');
      await tester.pump(const Duration(milliseconds: 900));
      // 让 notifier 的防抖持久化计时器（500ms）跑完
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // 切换到对话2（带自己的附件草稿）
      await tester.pumpWidget(
        _composer(
          container: container,
          conversationId: 'conv-2',
          initialDraftAttachments: [attB],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();

      // 对话1：文字 + 附件快照已保存
      final conv1 = container
          .read(conversationsProvider)
          .firstWhere((c) => c.id == 'conv-1');
      expect(conv1.draftText, '对话1的草稿');
      expect(conv1.draftAttachments.map((a) => a.id), ['att-a']);

      // 对话2：附件草稿恢复为 B（A 的芯片不残留）
      expect(find.byKey(const ValueKey('pending_att_att-b')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pending_att_att-a')),
        findsNothing,
        reason: '切换对话后不得残留上一对话的附件草稿',
      );

      // 帧后保存旧对话草稿 + notifier 防抖持久化计时器排空
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
    });

    testWidgets('旧对话附件保存完成不会跳过新对话相同文本', (tester) async {
      final storagePath = 'attachments/switching-conversation.txt';
      final attachment = Attachment(
        id: 'switching-conversation',
        fileName: 'switch.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'switching-conversation-hash',
        storagePath: storagePath,
        fileSize: 1,
        conversationId: 'conv-1',
      );
      final conversationJson = jsonEncode([
        Conversation(
          id: 'conv-1',
          title: '对话A',
          messages: [],
          draftAttachments: [attachment],
        ).toMap(),
        Conversation(id: 'conv-2', title: '对话B', messages: []).toMap(),
      ]);
      SharedPreferences.setMockInitialValues({
        'conversations': conversationJson,
      });
      final store = _RetryableWritePreferencesStore({
        'flutter.conversations': conversationJson,
      });
      SharedPreferencesStorePlatform.instance = store;
      final container = ProviderContainer(
        overrides: [
          activeConversationIdProvider.overrideWith((ref) => 'conv-1'),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      await notifier.persistSnapshotForAttachmentCleanup();
      final writeGate = Completer<void>();
      final writeStarted = Completer<void>();
      store
        ..allowWrites = true
        ..writeStarted = writeStarted
        ..writeGate = writeGate;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async => true;
      final key = GlobalKey<ChatComposerWidgetState>();

      await tester.pumpWidget(
        _composer(
          container: container,
          key: key,
          conversationId: 'conv-1',
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'hello');
      late Future<void> removal;
      await tester.runAsync(() async {
        removal = key.currentState!.removePendingAttachmentForTesting(0);
        await writeStarted.future.timeout(const Duration(seconds: 15));
      });

      await tester.pumpWidget(
        _composer(
          container: container,
          key: key,
          conversationId: 'conv-2',
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'hello');
      writeGate.complete();
      await tester.pump();
      await tester.runAsync(() => removal);
      await tester.pump(const Duration(milliseconds: 801));

      expect(
        container
            .read(conversationsProvider)
            .singleWhere((conversation) => conversation.id == 'conv-2')
            .draftText,
        'hello',
      );
      container.dispose();
    });

    testWidgets('恢复草稿不污染对话持有的附件对象（文件 base64 不得写回 provider）', (tester) async {
      final container = _buildContainer();
      // 真实文件落盘（恢复时 readFile 能读到，才会触发 base64 编码）
      final bytes = Uint8List.fromList(List.generate(256, (i) => i % 251));
      final storagePath = await tester.runAsync(
        () => AttachmentStorage.saveFile('doc.pdf', bytes),
      );

      final fileAtt = Attachment(
        id: 'file-1',
        fileName: 'doc.pdf',
        mimeType: 'application/pdf',
        fileType: 'document',
        hash: 'hash-doc',
        storagePath: storagePath!,
        fileSize: bytes.length,
        conversationId: 'conv-1',
      );
      // 对话持有该附件草稿（无 base64——文件 base64 只应存在于内存）
      final conv = container
          .read(conversationsProvider)
          .firstWhere((c) => c.id == 'conv-1');
      conv.draftAttachments = [fileAtt];

      // chat_page 直接传 conv.draftAttachments（不拷贝）
      await tester.pumpWidget(
        _composer(
          container: container,
          initialDraftAttachments: conv.draftAttachments,
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      // 让恢复路径的 readFile + base64 编码异步完成
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }

      final stored = container
          .read(conversationsProvider)
          .firstWhere((c) => c.id == 'conv-1');
      expect(
        stored.draftAttachments[0].base64Data,
        isNull,
        reason: '恢复路径必须深拷贝——文件 base64 不得写回对话持有的对象，'
            '否则对话 JSON 会被撑爆（持久化静默失败）',
      );
    });

    testWidgets('移除非图片草稿附件时先保存引用移除再删除文件', (tester) async {
      final storagePath = 'attachments/persist-before-delete.txt';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final attachment = Attachment(
        id: 'draft-document',
        fileName: 'draft.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'draft-document-hash',
        storagePath: storagePath,
        fileSize: 3,
        conversationId: 'conv-1',
      );
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
      );
      var draftWasClearAtDelete = false;
      var fileExistedAtDelete = false;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        final prefs = await SharedPreferences.getInstance();
        final saved = (jsonDecode(prefs.getString('conversations')!) as List)
            .cast<Map<String, dynamic>>()
            .map(Conversation.fromMap)
            .single;
        draftWasClearAtDelete = saved.draftAttachments.isEmpty;
        fileExistedAtDelete = file.existsSync();
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };

      await tester.pumpWidget(
        _composer(
          container: container,
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_draft-document')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(draftWasClearAtDelete, isTrue);
      expect(fileExistedAtDelete, isTrue);
      expect(file.existsSync(), isFalse);
      container.dispose();
    });

    testWidgets('替换草稿图片时先保存新路径再删除旧文件', (tester) async {
      final storagePath = 'attachments/persist-before-replace.png';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
          ),
        );
      final attachment = Attachment(
        id: 'draft-image',
        fileName: 'draft.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'draft-image-hash',
        storagePath: storagePath,
        fileSize: file.lengthSync(),
        conversationId: 'conv-1',
      );
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
      );
      final key = GlobalKey<ChatComposerWidgetState>();
      final preCompressGate = Completer<void>();
      var savedPathAtDelete = '';
      var oldFileExistedAtDelete = false;
      var cacheDeletedBeforePreCompressFinished = false;
      var cacheDeletedAfterPreCompressFinished = false;
      AttachmentStorage.deleteCompressedImageOverrideForTesting =
          ({required conversationId, required hash}) async {
        if (hash == attachment.hash && !preCompressGate.isCompleted) {
          cacheDeletedBeforePreCompressFinished = true;
        } else if (hash == attachment.hash) {
          cacheDeletedAfterPreCompressFinished = true;
        }
        return true;
      };
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        final prefs = await SharedPreferences.getInstance();
        final saved = (jsonDecode(prefs.getString('conversations')!) as List)
            .cast<Map<String, dynamic>>()
            .map(Conversation.fromMap)
            .single;
        savedPathAtDelete = saved.draftAttachments.single.storagePath;
        oldFileExistedAtDelete = file.existsSync();
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };

      await tester.pumpWidget(
        _composer(
          container: container,
          key: key,
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      key.currentState!.setPreCompressFutureForTesting(
        attachment.hash,
        preCompressGate.future,
      );
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      late Future<void> replaceFuture;
      await tester.runAsync(() async {
        replaceFuture = key.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(savedPathAtDelete, isEmpty);
      expect(file.existsSync(), isTrue);
      preCompressGate.complete();
      await tester.runAsync(() => replaceFuture);
      await tester.pump();

      expect(savedPathAtDelete, isNot(storagePath));
      expect(oldFileExistedAtDelete, isTrue);
      expect(cacheDeletedBeforePreCompressFinished, isFalse);
      expect(cacheDeletedAfterPreCompressFinished, isTrue);
      expect(file.existsSync(), isFalse);
      container.dispose();
    });

    testWidgets('保留的未解析记录引用附件时不清理其文件', (tester) async {
      final storagePath = 'attachments/preserved-record.txt';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final conversation = Conversation(
        id: 'conv-1',
        title: '对话A',
        messages: [],
      );
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          conversation.toMap(),
          [
            {'storagePath': storagePath},
          ],
        ]),
      });
      final container = ProviderContainer(
        overrides: [
          activeConversationIdProvider.overrideWith((ref) => 'conv-1'),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(conversationsProvider.notifier).ready;
      var deleteCalled = false;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleteCalled = true;
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };

      final notifier = container.read(conversationsProvider.notifier);
      notifier.queueDraftAttachmentFileDelete(storagePath);
      final saved = await tester.runAsync(
        () =>
            notifier.saveDraftAndWait('conv-1', '', draftAttachments: const []),
      );

      expect(saved, isTrue);
      expect(deleteCalled, isFalse);
      expect(file.existsSync(), isTrue);
      container.dispose();
    });

    testWidgets('重叠移除只在保存对应快照后清理各自文件', (tester) async {
      final firstPath = 'attachments/overlap-first.txt';
      final secondPath = 'attachments/overlap-second.txt';
      final firstFile = File('${tmpRoot.path}/$firstPath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      final secondFile = File('${tmpRoot.path}/$secondPath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([2]);
      final first = Attachment(
        id: 'overlap-first',
        fileName: 'first.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'overlap-first-hash',
        storagePath: firstPath,
        fileSize: 1,
        conversationId: 'conv-1',
      );
      final second = Attachment(
        id: 'overlap-second',
        fileName: 'second.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'overlap-second-hash',
        storagePath: secondPath,
        fileSize: 1,
        conversationId: 'conv-1',
      );
      late _RetryableWritePreferencesStore store;
      final firstWriteGate = Completer<void>();
      final secondWriteGate = Completer<void>();
      final secondWriteStarted = Completer<void>();
      final secondDeleteFinished = Completer<void>();
      final container = await _buildPersistedContainer(
        draftAttachments: [first, second],
        configureStore: (preferencesStore) {
          store = preferencesStore
            ..allowWrites = true
            ..writeStarted = Completer<void>()
            ..writeGate = firstWriteGate;
        },
      );
      final deletedPaths = <String>[];
      final draftPathsAtDelete = <String, List<String>>{};
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        final storedConversations =
            (await store.getAll())['flutter.conversations']! as String;
        final saved = (jsonDecode(storedConversations) as List)
            .cast<Map<String, dynamic>>()
            .map(Conversation.fromMap)
            .single;
        draftPathsAtDelete[path] =
            saved.draftAttachments.map((att) => att.storagePath).toList();
        deletedPaths.add(path);
        File('${tmpRoot.path}/$path').deleteSync();
        if (path == secondPath) secondDeleteFinished.complete();
        return true;
      };

      await tester.pumpWidget(
        _composer(
          container: container,
          initialDraftAttachments: [first, second],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_overlap-first')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => store.writeStarted!.future.timeout(const Duration(seconds: 15)),
      );
      // Install the second write gate before the second removal can enqueue
      // and begin its save; otherwise its setValue may pass before the test
      // observes the signal.
      store
        ..writeStarted = secondWriteStarted
        ..writeGate = secondWriteGate;
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_overlap-second')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      firstWriteGate.complete();
      await tester.pump();
      await tester.runAsync(
        () => secondWriteStarted.future.timeout(const Duration(seconds: 15)),
      );

      // The first write must persist the snapshot that still includes the
      // second attachment before deleting only the first file.
      expect(firstFile.existsSync(), isFalse);
      expect(secondFile.existsSync(), isTrue);
      expect(draftPathsAtDelete[firstPath], [secondPath]);

      secondWriteGate.complete();
      await tester.pump();
      await tester.runAsync(
        () => secondDeleteFinished.future.timeout(const Duration(seconds: 15)),
      );

      expect(firstFile.existsSync(), isFalse);
      expect(secondFile.existsSync(), isFalse);
      expect(draftPathsAtDelete[firstPath], [secondPath]);
      expect(draftPathsAtDelete[secondPath], isEmpty);
      expect(deletedPaths, [firstPath, secondPath]);
      container.dispose();
    });

    testWidgets('较早保存不会在更新的排队快照前删除附件', (tester) async {
      final storagePath = 'attachments/queued-snapshot.txt';
      late _RetryableWritePreferencesStore store;
      final firstWriteGate = Completer<void>();
      final firstWriteStarted = Completer<void>();
      final fileDeleteStarted = Completer<void>();
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([7]);
      final attachment = Attachment(
        id: 'queued-snapshot',
        fileName: 'queued.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'queued-snapshot-hash',
        storagePath: storagePath,
        fileSize: 1,
        conversationId: 'conv-1',
      );
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
        configureStore: (preferencesStore) {
          store = preferencesStore
            ..allowWrites = true
            ..writeCount = 0
            ..writeStarted = firstWriteStarted
            ..writeGate = firstWriteGate;
        },
      );
      var writesAtDelete = 0;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        writesAtDelete = store.writeCount;
        fileDeleteStarted.complete();
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };
      final notifier = container.read(conversationsProvider.notifier);
      notifier.queueDraftAttachmentFileDelete(storagePath);

      late Future<bool> firstSave;
      late Future<bool> readdSave;
      late Future<bool> finalRemovalSave;
      await tester.runAsync(() async {
        firstSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: const [],
        );
        await firstWriteStarted.future.timeout(const Duration(seconds: 15));
        readdSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: [attachment],
        );
        finalRemovalSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: const [],
        );
      });
      firstWriteGate.complete();
      final saved = await tester.runAsync(() async {
        return await firstSave && await readdSave && await finalRemovalSave;
      });

      expect(saved, isTrue);
      await tester.runAsync(
        () => fileDeleteStarted.future.timeout(const Duration(seconds: 15)),
      );
      expect(writesAtDelete, 3);
      expect(file.existsSync(), isFalse);
      container.dispose();
    });

    testWidgets('同一路径在删除进行中重新引用时恢复文件', (tester) async {
      final storagePath = 'attachments/reintroduced-during-delete.txt';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([4, 2]);
      final attachment = Attachment(
        id: 'reintroduced-during-delete',
        fileName: 'reintroduced.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'reintroduced-during-delete-hash',
        storagePath: storagePath,
        fileSize: 2,
        conversationId: 'conv-1',
      );
      final deleteStarted = Completer<void>();
      final releaseDelete = Completer<void>();
      final container = await _buildPersistedContainer();
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleteStarted.complete();
        await releaseDelete.future;
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };
      final notifier = container.read(conversationsProvider.notifier);
      notifier.queueDraftAttachmentFileDelete(storagePath);

      late Future<bool> firstSave;
      late Future<bool> readdSave;
      await tester.runAsync(() async {
        firstSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: const [],
        );
        await deleteStarted.future.timeout(const Duration(seconds: 15));
        readdSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: [attachment],
        );
      });
      releaseDelete.complete();
      final saved = await tester.runAsync(
        () async => await firstSave && await readdSave,
      );

      expect(saved, isTrue);
      expect(file.readAsBytesSync(), [4, 2]);
      expect(
        container
            .read(conversationsProvider)
            .single
            .draftAttachments
            .single
            .storagePath,
        storagePath,
      );
      container.dispose();
    });

    testWidgets('删除首个文件期间新增的后续引用受到保护', (tester) async {
      final firstPath = 'attachments/delete-first.txt';
      final secondPath = 'attachments/protect-second.txt';
      final firstFile = File('${tmpRoot.path}/$firstPath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      final secondFile = File('${tmpRoot.path}/$secondPath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([2]);
      final deleteGate = Completer<void>();
      final firstDeleteStarted = Completer<void>();
      final container = await _buildPersistedContainer();
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        if (path == firstPath) {
          firstDeleteStarted.complete();
          await deleteGate.future;
        }
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };
      final notifier = container.read(conversationsProvider.notifier);
      notifier
        ..queueDraftAttachmentFileDelete(firstPath)
        ..queueDraftAttachmentFileDelete(secondPath);
      late Future<bool> firstSave;
      late Future<bool> secondSave;
      await tester.runAsync(() async {
        firstSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: const [],
        );
        await firstDeleteStarted.future.timeout(const Duration(seconds: 15));
      });
      final secondAttachment = Attachment(
        id: 'protect-second-file',
        fileName: 'second.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'protect-second-file-hash',
        storagePath: secondPath,
        fileSize: 1,
        conversationId: 'conv-1',
      );
      await tester.runAsync(() async {
        secondSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: [secondAttachment],
        );
      });
      deleteGate.complete();
      expect(
        await tester.runAsync(() async => await firstSave && await secondSave),
        isTrue,
      );

      expect(deletedPaths, [firstPath]);
      expect(firstFile.existsSync(), isFalse);
      expect(secondFile.existsSync(), isTrue);
      container.dispose();
    });

    testWidgets('移除保存期间重新加入的附件仍保留其文件', (tester) async {
      final storagePath = 'attachments/readded-during-save.txt';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([3, 4, 5]);
      final attachment = Attachment(
        id: 'readded-during-save',
        fileName: 'readded.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'readded-during-save-hash',
        storagePath: storagePath,
        fileSize: 3,
        conversationId: 'conv-1',
      );
      late _RetryableWritePreferencesStore store;
      final firstWriteGate = Completer<void>();
      final composerKey = GlobalKey<ChatComposerWidgetState>();
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
        configureStore: (preferencesStore) {
          store = preferencesStore
            ..allowWrites = true
            ..writeCount = 0
            ..writeStarted = Completer<void>()
            ..writeGate = firstWriteGate;
        },
      );
      var deleteCalled = false;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleteCalled = true;
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };
      AttachmentStorage.saveFileOverrideForTesting = (fileName, bytes) async {
        await file.writeAsBytes(bytes);
        return storagePath;
      };

      await tester.pumpWidget(
        _composer(
          container: container,
          key: composerKey,
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();

      // Block the composer's real remove/save path, then re-import the same
      // bytes/path without allowing its 800ms draft debounce to persist.
      late Future<void> removal;
      await tester.runAsync(() async {
        removal = composerKey.currentState!.removePendingAttachmentForTesting(
          0,
        );
        await store.writeStarted!.future.timeout(const Duration(seconds: 15));
      });
      await tester.runAsync(
        () => composerKey.currentState!.addPendingAttachmentForTesting(
          'readded.txt',
          Uint8List.fromList([3, 4, 5]),
        ),
      );
      expect(
        container
            .read(conversationsProvider)
            .single
            .draftAttachments
            .single
            .storagePath,
        storagePath,
      );
      expect(store.writeCount, 1, reason: 'the re-add is still debounced');
      firstWriteGate.complete();
      await tester.pump();
      await tester.runAsync(() => removal);

      expect(file.existsSync(), isTrue);
      expect(deleteCalled, isFalse);
      final saved = await tester.runAsync(
        () => container
            .read(conversationsProvider.notifier)
            .persistSnapshotForAttachmentCleanup(),
      );
      expect(saved, isTrue);
      final storedConversations = await tester.runAsync(
        () async => (await store.getAll())['flutter.conversations']! as String,
      );
      final persisted = (jsonDecode(storedConversations!) as List)
          .cast<Map<String, dynamic>>()
          .map(Conversation.fromMap)
          .single;
      expect(persisted.draftAttachments.single.storagePath, storagePath);
      expect(file.existsSync(), isTrue);
      container.dispose();
    });

    testWidgets('导航离开期间移除附件仍完成持久化且不访问已销毁 widget', (
      tester,
    ) async {
      final storagePath = 'attachments/remove-during-navigation.txt';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final attachment = Attachment(
        id: 'remove-during-navigation',
        fileName: 'navigation.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'remove-during-navigation-hash',
        storagePath: storagePath,
        fileSize: 3,
        conversationId: 'conv-1',
      );
      late _RetryableWritePreferencesStore store;
      final writeGate = Completer<void>();
      final key = GlobalKey<ChatComposerWidgetState>();
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
        configureStore: (preferencesStore) {
          store = preferencesStore
            ..allowWrites = true
            ..writeCount = 0
            ..writeStarted = Completer<void>()
            ..writeGate = writeGate;
        },
      );
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };
      await tester.pumpWidget(
        _composer(
          container: container,
          key: key,
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();

      late Future<void> removal;
      await tester.runAsync(() async {
        removal = key.currentState!.removePendingAttachmentForTesting(0);
        await store.writeStarted!.future.timeout(const Duration(seconds: 15));
      });
      await tester.pumpWidget(const SizedBox.shrink());
      writeGate.complete();
      await tester.pump();
      await tester.runAsync(() => removal);

      expect(file.existsSync(), isFalse);
      expect(store.writeCount, greaterThanOrEqualTo(1));
      container.dispose();
    });

    testWidgets('清理编辑路径时保留其附件存储路径别名', (tester) async {
      const attachmentPath = 'attachments/reused.png';
      const editedPath = 'temp_edited/reused.png';
      final file = File('${tmpRoot.path}/$attachmentPath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final attachment = Attachment(
        id: 'reused-image',
        fileName: 'reused.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'reused-image-hash',
        storagePath: attachmentPath,
        fileSize: 3,
        conversationId: 'conv-1',
      );
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
      );
      var deleteCalled = false;
      AttachmentStorage.deletionIdentitiesOverrideForTesting =
          (path) => path == editedPath ? {editedPath, attachmentPath} : {path};
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleteCalled = true;
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };

      final notifier = container.read(conversationsProvider.notifier);
      notifier.queueDraftAttachmentFileDelete(editedPath);
      final saved = await tester.runAsync(
        () => notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: [attachment],
        ),
      );

      expect(saved, isTrue);
      expect(deleteCalled, isFalse);
      expect(file.existsSync(), isTrue);
      container.dispose();
    });

    testWidgets('保存失败后下一次成功保存再清理已移除附件文件', (tester) async {
      final storagePath = 'attachments/retry-delete.txt';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final attachment = Attachment(
        id: 'retry-document',
        fileName: 'retry.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'retry-document-hash',
        storagePath: storagePath,
        fileSize: 3,
        conversationId: 'conv-1',
      );
      late _RetryableWritePreferencesStore store;
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
        configureStore: (preferencesStore) {
          store = preferencesStore..allowWrites = false;
        },
      );
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };

      await tester.pumpWidget(
        _composer(
          container: container,
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_retry-document')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(file.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      store.allowWrites = true;
      final saved = await container
          .read(conversationsProvider.notifier)
          .saveDraftAndWait('conv-1', '', draftAttachments: const []);

      expect(saved, isTrue);
      expect(file.existsSync(), isFalse);
      container.dispose();
    });

    testWidgets('移除图片时保存失败会保留压缩缓存并重试引用检查', (tester) async {
      final first = Attachment(
        id: 'retry-image-first',
        fileName: 'first.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'retry-shared-hash',
        storagePath: 'attachments/retry-image-first.png',
        fileSize: 3,
        conversationId: 'conv-1',
      );
      final second = Attachment(
        id: 'retry-image-second',
        fileName: 'second.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: first.hash,
        storagePath: 'attachments/retry-image-second.png',
        fileSize: 3,
        conversationId: 'conv-1',
      );
      late _RetryableWritePreferencesStore store;
      final container = await _buildPersistedContainer(
        draftAttachments: [first, second],
        configureStore: (preferencesStore) {
          store = preferencesStore..allowWrites = false;
        },
      );
      final deletedCaches = <String>[];
      AttachmentStorage.deleteCompressedImageOverrideForTesting =
          ({required conversationId, required hash}) async {
        deletedCaches.add('$conversationId:$hash');
        return true;
      };
      AttachmentStorage.deleteFileOverrideForTesting = (path) async => true;

      await tester.pumpWidget(
        _composer(
          container: container,
          initialDraftAttachments: [first, second],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_retry-image-first')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(deletedCaches, isEmpty);

      store.allowWrites = true;
      final notifier = container.read(conversationsProvider.notifier);
      final retainedSave = await tester.runAsync(
        () =>
            notifier.saveDraftAndWait('conv-1', '', draftAttachments: [second]),
      );
      expect(retainedSave, isTrue);
      expect(deletedCaches, isEmpty);

      final removedSave = await tester.runAsync(
        () => notifier.saveDraftAndWait('conv-1', '', draftAttachments: []),
      );
      expect(removedSave, isTrue);
      expect(deletedCaches, ['conv-1:${first.hash}']);
      container.dispose();
    });

    testWidgets('移除保存期间重新添加同 hash 图片会取消旧缓存清理', (tester) async {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final hash = AttachmentStorage.computeHash(imageBytes);
      final attachment = Attachment(
        id: 'readded-image',
        fileName: 'readded.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: hash,
        storagePath: 'attachments/readded.png',
        fileSize: imageBytes.length,
        conversationId: 'conv-1',
      );
      late _RetryableWritePreferencesStore store;
      final removalWriteGate = Completer<void>();
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
        configureStore: (preferencesStore) {
          store = preferencesStore
            ..allowWrites = true
            ..writeStarted = Completer<void>()
            ..writeGate = removalWriteGate;
        },
      );
      final key = GlobalKey<ChatComposerWidgetState>();
      final deletedCaches = <String>[];
      AttachmentStorage.deleteCompressedImageOverrideForTesting =
          ({required conversationId, required hash}) async {
        deletedCaches.add('$conversationId:$hash');
        return true;
      };
      AttachmentStorage.deleteFileOverrideForTesting = (path) async => true;

      await tester.pumpWidget(
        _composer(
          container: container,
          key: key,
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_readded-image')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => store.writeStarted!.future.timeout(const Duration(seconds: 15)),
      );

      await tester.runAsync(
        () => key.currentState!.addPendingAttachmentForTesting(
          'readded.png',
          imageBytes,
        ),
      );
      expect(deletedCaches, isEmpty);

      removalWriteGate.complete();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      expect(deletedCaches, isEmpty);
      expect(
        container
            .read(conversationsProvider)
            .single
            .draftAttachments
            .single
            .hash,
        hash,
      );
      container.dispose();
    });

    testWidgets('保存失败后下一次成功保存再清理旧压缩缓存', (tester) async {
      final attachment = Attachment(
        id: 'retry-image',
        fileName: 'retry.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'retry-image-hash',
        storagePath: 'attachments/retry.png',
        fileSize: 3,
        conversationId: 'conv-1',
      );
      late _RetryableWritePreferencesStore store;
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
        configureStore: (preferencesStore) {
          store = preferencesStore..allowWrites = false;
        },
      );
      final deletedCaches = <String>[];
      AttachmentStorage.deleteCompressedImageOverrideForTesting =
          ({required conversationId, required hash}) async {
        deletedCaches.add('$conversationId:$hash');
        return true;
      };

      final notifier = container.read(conversationsProvider.notifier);
      notifier.queueDraftAttachmentCacheDelete(
        conversationId: 'conv-1',
        hash: attachment.hash,
      );
      final failedSave = await tester.runAsync(
        () => notifier.saveDraftAndWait('conv-1', '', draftAttachments: []),
      );
      expect(failedSave, isFalse);
      expect(deletedCaches, isEmpty);

      store.allowWrites = true;
      final retainedSave = await tester.runAsync(
        () => notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: [attachment],
        ),
      );
      expect(retainedSave, isTrue);
      expect(deletedCaches, isEmpty);

      notifier.createConversation(id: 'conv-2', activate: false);
      final otherConversationAttachment = Attachment(
        id: 'other-conversation-image',
        fileName: 'other.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: attachment.hash,
        storagePath: 'attachments/other.png',
        fileSize: 3,
        conversationId: 'conv-2',
      );
      final otherConversationSave = await tester.runAsync(
        () => notifier.saveDraftAndWait(
          'conv-2',
          '',
          draftAttachments: [otherConversationAttachment],
        ),
      );
      expect(otherConversationSave, isTrue);

      final successfulSave = await tester.runAsync(
        () => notifier.saveDraftAndWait('conv-1', '', draftAttachments: []),
      );
      expect(successfulSave, isTrue);
      expect(deletedCaches, ['conv-1:${attachment.hash}']);
      container.dispose();
    });

    testWidgets('缓存删除期间新排队的清理请求不会被旧删除吞掉', (tester) async {
      final cacheDeleteGate = Completer<void>();
      final cacheDeleteStarted = Completer<void>();
      final container = await _buildPersistedContainer();
      var deleteCount = 0;
      AttachmentStorage.deleteCompressedImageOverrideForTesting =
          ({required conversationId, required hash}) async {
        deleteCount++;
        if (deleteCount == 1) {
          cacheDeleteStarted.complete();
          await cacheDeleteGate.future;
        }
        return true;
      };
      final notifier = container.read(conversationsProvider.notifier);
      notifier.queueDraftAttachmentCacheDelete(
        conversationId: 'conv-1',
        hash: 'same-hash',
      );
      late Future<bool> firstSave;
      await tester.runAsync(() async {
        firstSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: const [],
        );
        await cacheDeleteStarted.future.timeout(const Duration(seconds: 15));
      });

      final replacementCacheWrite = Completer<void>();
      notifier
        ..cancelDraftAttachmentCacheDelete(
          conversationId: 'conv-1',
          hash: 'same-hash',
        )
        ..queueDraftAttachmentCacheDelete(
          conversationId: 'conv-1',
          hash: 'same-hash',
          waitFor: replacementCacheWrite.future,
        );
      cacheDeleteGate.complete();
      expect(await tester.runAsync(() => firstSave), isTrue);
      replacementCacheWrite.complete();
      final retriedSave = await tester.runAsync(
        () =>
            notifier.saveDraftAndWait('conv-1', '', draftAttachments: const []),
      );

      expect(retriedSave, isTrue);
      expect(deleteCount, 2);
      container.dispose();
    });

    testWidgets('删除首个缓存期间新增的后续引用受到保护', (tester) async {
      final deleteGate = Completer<void>();
      final firstDeleteStarted = Completer<void>();
      final container = await _buildPersistedContainer();
      final deletedHashes = <String>[];
      AttachmentStorage.deleteCompressedImageOverrideForTesting =
          ({required conversationId, required hash}) async {
        deletedHashes.add(hash);
        if (hash == 'first-cache') {
          firstDeleteStarted.complete();
          await deleteGate.future;
        }
        return true;
      };
      final notifier = container.read(conversationsProvider.notifier);
      notifier
        ..queueDraftAttachmentCacheDelete(
          conversationId: 'conv-1',
          hash: 'first-cache',
        )
        ..queueDraftAttachmentCacheDelete(
          conversationId: 'conv-1',
          hash: 'second-cache',
        );
      late Future<bool> firstSave;
      late Future<bool> secondSave;
      await tester.runAsync(() async {
        firstSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: const [],
        );
        await firstDeleteStarted.future.timeout(const Duration(seconds: 15));
      });
      final secondAttachment = Attachment(
        id: 'second-cache-reference',
        fileName: 'second.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'second-cache',
        storagePath: 'attachments/second.png',
        fileSize: 1,
        conversationId: 'conv-1',
      );
      await tester.runAsync(() async {
        secondSave = notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: [secondAttachment],
        );
      });
      deleteGate.complete();
      expect(
        await tester.runAsync(() async => await firstSave && await secondSave),
        isTrue,
      );

      expect(deletedHashes, ['first-cache']);
      container.dispose();
    });

    testWidgets('dispose 后附件清理不会回退已成功的完整历史保存', (tester) async {
      final message = ChatMessage(
        id: 'preserve-raw-data',
        role: 'assistant',
        content: 'answer',
        rawRequest: {'prompt': 'keep me'},
        rawResponse: {'response': 'keep me'},
      );
      final conversation = Conversation(
        id: 'conv-1',
        title: '对话A',
        messages: [message],
      );
      final conversationJson = jsonEncode([conversation.toMap()]);
      SharedPreferences.setMockInitialValues({
        'conversations': conversationJson,
      });
      final store = _RetryableWritePreferencesStore({
        'flutter.conversations': conversationJson,
      });
      SharedPreferencesStorePlatform.instance = store;
      final container = ProviderContainer(
        overrides: [
          activeConversationIdProvider.overrideWith((ref) => 'conv-1'),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      await notifier.persistSnapshotForAttachmentCleanup();
      final writeStarted = Completer<void>();
      final writeGate = Completer<void>();
      store
        ..allowWrites = true
        ..writeStarted = writeStarted
        ..writeGate = writeGate;
      var deleteCalled = false;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleteCalled = true;
        return true;
      };
      notifier.queueDraftAttachmentFileDelete('attachments/disposed.txt');

      container.dispose();
      await tester.runAsync(
        () => writeStarted.future.timeout(const Duration(seconds: 15)),
      );
      writeGate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      final stored = (await store.getAll())['flutter.conversations']! as String;
      final storedMessage = ((jsonDecode(stored) as List).single
          as Map<String, dynamic>)['messages'] as List;
      expect((storedMessage.single as Map<String, dynamic>)['rawRequest'], {
        'prompt': 'keep me',
      });
      expect((storedMessage.single as Map<String, dynamic>)['rawResponse'], {
        'response': 'keep me',
      });
      expect(deleteCalled, isTrue);
    });

    testWidgets('无 conversation ID 的移除附件仍清理无主文件', (tester) async {
      final storagePath = 'attachments/no-conversation.txt';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final attachment = Attachment(
        id: 'unowned-document',
        fileName: 'orphan.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'unowned-hash',
        storagePath: storagePath,
        fileSize: 3,
      );
      final container = _buildContainer();
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };

      await tester.pumpWidget(
        _composer(
          container: container,
          conversationId: null,
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_unowned-document')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      expect(file.existsSync(), isFalse);
      container.dispose();
    });

    testWidgets('composer 没有 conversation ID 时保留其他已保存对话引用的文件', (tester) async {
      final storagePath = 'attachments/owned-by-conversation.txt';
      final file = File('${tmpRoot.path}/$storagePath')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final attachment = Attachment(
        id: 'owned-document',
        fileName: 'owned.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'owned-hash',
        storagePath: storagePath,
        fileSize: 3,
        conversationId: 'conv-1',
      );
      late _RetryableWritePreferencesStore store;
      final writeGate = Completer<void>();
      final container = await _buildPersistedContainer(
        draftAttachments: [attachment],
        configureStore: (preferencesStore) {
          store = preferencesStore
            ..allowWrites = true
            ..writeStarted = Completer<void>()
            ..writeGate = writeGate;
        },
      );
      var deleteCalled = false;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleteCalled = true;
        File('${tmpRoot.path}/$path').deleteSync();
        return true;
      };

      await tester.pumpWidget(
        _composer(
          container: container,
          conversationId: null,
          initialDraftAttachments: [attachment],
          onSend: (text, atts) {},
        ),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_owned-document')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => store.writeStarted!.future.timeout(const Duration(seconds: 15)),
      );
      writeGate.complete();
      await tester.pump();
      final persisted = await tester.runAsync(
        () => container
            .read(conversationsProvider.notifier)
            .persistSnapshotForAttachmentCleanup(),
      );

      expect(persisted, isTrue);
      expect(file.existsSync(), isTrue);
      expect(deleteCalled, isFalse);
      final saved = container
          .read(conversationsProvider)
          .singleWhere((conversation) => conversation.id == 'conv-1');
      expect(saved.draftAttachments.single.storagePath, storagePath);
      container.dispose();
    });
  });
}
