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
  Completer<void>? writeStarted;
  Completer<void>? writeGate;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!allowWrites) return false;
    final gate = writeGate;
    if (gate != null) {
      writeGate = null;
      writeStarted?.complete();
      await gate.future;
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
  if (preferencesStore != null) configureStore!(preferencesStore);
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
          await firstSave.started.future;
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
          await editSave.started.future;
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
        final originalAttachment = readyImage(
          id: 'edit-att',
          hash: 'hash-edit',
        )..conversationId = 'conv-1';

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
          await save.started.future;
        });

        await tester.pumpWidget(editingComposer('conv-2'));
        await tester.pumpWidget(editingComposer('conv-1'));
        await tester.pump();

        save.release.complete();
        await tester.runAsync(() => pendingImport);
        await tester.pump();

        expect(
            find.byKey(const ValueKey('pending_att_edit-att')), findsOneWidget);
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
        await save.started.future;
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
        await File('${tmpRoot.path}/$path').delete();
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
      AttachmentStorage.deleteCompressedImageOverrideForTesting = ({
        required conversationId,
        required hash,
      }) async {
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
        await File('${tmpRoot.path}/$path').delete();
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
          providerEntriesProvider
              .overrideWith((ref) => ProviderEntriesNotifier()),
        ],
      );
      await container.read(conversationsProvider.notifier).ready;
      var deleteCalled = false;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleteCalled = true;
        await File('${tmpRoot.path}/$path').delete();
        return true;
      };

      final notifier = container.read(conversationsProvider.notifier);
      notifier.queueDraftAttachmentFileDelete(storagePath);
      final saved = await tester.runAsync(
        () => notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: const [],
        ),
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
        await File('${tmpRoot.path}/$path').delete();
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
      await tester.runAsync(() => store.writeStarted!.future);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending_att_overlap-second')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      firstWriteGate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );

      expect(firstFile.existsSync(), isFalse);
      expect(secondFile.existsSync(), isFalse);
      expect(draftPathsAtDelete[firstPath], [secondPath]);
      expect(draftPathsAtDelete[secondPath], isEmpty);
      expect(deletedPaths, [firstPath, secondPath]);
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
        await File('${tmpRoot.path}/$path').delete();
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
      AttachmentStorage.deleteCompressedImageOverrideForTesting = ({
        required conversationId,
        required hash,
      }) async {
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
        () => notifier.saveDraftAndWait(
          'conv-1',
          '',
          draftAttachments: [second],
        ),
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
      AttachmentStorage.deleteCompressedImageOverrideForTesting = ({
        required conversationId,
        required hash,
      }) async {
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
      await tester.runAsync(() => store.writeStarted!.future);

      await tester.runAsync(
        () => key.currentState!.addPendingAttachmentForTesting(
          'readded.png',
          imageBytes,
        ),
      );
      expect(deletedCaches, isEmpty);

      removalWriteGate.complete();
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
      AttachmentStorage.deleteCompressedImageOverrideForTesting = ({
        required conversationId,
        required hash,
      }) async {
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
        await File('${tmpRoot.path}/$path').delete();
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
  });
}
