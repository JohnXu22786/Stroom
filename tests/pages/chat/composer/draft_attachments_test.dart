import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
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

Widget _composer({
  required ProviderContainer container,
  String? conversationId = 'conv-1',
  String initialDraftText = '',
  List<Attachment> initialDraftAttachments = const [],
  required void Function(String, List<Attachment>) onSend,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: ChatComposerWidget(
          conversationId: conversationId,
          initialDraftText: initialDraftText,
          initialDraftAttachments: initialDraftAttachments,
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
    tmpRoot = Directory.systemTemp.createTempSync('stroom_draft_att_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tmpRoot.path);
  });

  tearDown(() {
    try {
      tmpRoot.deleteSync(recursive: true);
    } catch (_) {
      // 非关键清理
    }
  });

  group('对话附件草稿', () {
    testWidgets('恢复：initialDraftAttachments 进入 pending，发送时载荷直接可用',
        (tester) async {
      final container = _buildContainer();
      final att = readyImage();
      List<Attachment>? sent;

      await tester.pumpWidget(_composer(
        container: container,
        initialDraftAttachments: [att],
        onSend: (text, atts) => sent = atts,
      ));
      await tester.pump();

      // 恢复的附件芯片可见
      expect(find.byKey(const ValueKey('pending_att_ready-1')), findsOneWidget,
          reason: '恢复的附件草稿必须显示为待发芯片');

      // 发送：载荷（压缩 base64）原样带出，无需重新读取/压缩
      await tester.enterText(find.byType(TextField), '带着图发');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      // 让 notifier 的防抖持久化计时器（500ms）跑完，避免挂起
      await tester.pump(const Duration(milliseconds: 600));

      expect(sent, hasLength(1));
      expect(sent![0].id, 'ready-1');
      expect(sent![0].base64Data, att.base64Data,
          reason: '恢复的压缩 base64 必须直接可用（发送零等待）');
    });

    testWidgets('保存：打字触发防抖保存，草稿快照写入 provider（压缩图带 base64，大图不带）',
        (tester) async {
      final container = _buildContainer();
      final ready = readyImage();
      final raw = rawImage();

      await tester.pumpWidget(_composer(
        container: container,
        initialDraftAttachments: [ready, raw],
        onSend: (text, atts) {},
      ));
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

      final byId = {
        for (final a in conv.draftAttachments) a.id: a,
      };
      expect(byId['ready-1']!.base64Data, ready.base64Data,
          reason: '压缩完成的图片必须携带 base64 随草稿持久化');
      expect(byId['raw-1']!.base64Data, isNull,
          reason: '未压缩完的原始大 base64 不得塞进草稿 JSON（体积）');
      expect(byId['raw-1']!.storagePath, raw.storagePath,
          reason: '文件引用必须保留，恢复时重新读取');
      // 快照是深拷贝：后续修改 pending 不污染已保存的草稿
      expect(identical(byId['ready-1'], ready), isFalse);
    });

    testWidgets('切换对话：旧对话草稿（文字+附件）保存，新对话附件恢复', (tester) async {
      final container = _buildContainer();
      final attA = readyImage(id: 'att-a', hash: 'hash-a');
      final attB = readyImage(id: 'att-b', hash: 'hash-b');
      attB.conversationId = 'conv-2';

      // 对话1：输入文字 + 附件草稿
      await tester.pumpWidget(_composer(
        container: container,
        conversationId: 'conv-1',
        initialDraftAttachments: [attA],
        onSend: (text, atts) {},
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '对话1的草稿');
      await tester.pump(const Duration(milliseconds: 900));
      // 让 notifier 的防抖持久化计时器（500ms）跑完
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // 切换到对话2（带自己的附件草稿）
      await tester.pumpWidget(_composer(
        container: container,
        conversationId: 'conv-2',
        initialDraftAttachments: [attB],
        onSend: (text, atts) {},
      ));
      await tester.pump();

      // 对话1：文字 + 附件快照已保存
      final conv1 = container
          .read(conversationsProvider)
          .firstWhere((c) => c.id == 'conv-1');
      expect(conv1.draftText, '对话1的草稿');
      expect(conv1.draftAttachments.map((a) => a.id), ['att-a']);

      // 对话2：附件草稿恢复为 B（A 的芯片不残留）
      expect(find.byKey(const ValueKey('pending_att_att-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('pending_att_att-a')), findsNothing,
          reason: '切换对话后不得残留上一对话的附件草稿');

      // 帧后保存旧对话草稿 + notifier 防抖持久化计时器排空
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
    });

    testWidgets('恢复草稿不污染对话持有的附件对象（文件 base64 不得写回 provider）', (tester) async {
      final container = _buildContainer();
      // 真实文件落盘（恢复时 readFile 能读到，才会触发 base64 编码）
      final bytes = Uint8List.fromList(List.generate(256, (i) => i % 251));
      final storagePath = await tester
          .runAsync(() => AttachmentStorage.saveFile('doc.pdf', bytes));

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
      await tester.pumpWidget(_composer(
        container: container,
        initialDraftAttachments: conv.draftAttachments,
        onSend: (text, atts) {},
      ));
      await tester.pump();
      // 让恢复路径的 readFile + base64 编码异步完成
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
      }

      final stored = container
          .read(conversationsProvider)
          .firstWhere((c) => c.id == 'conv-1');
      expect(stored.draftAttachments[0].base64Data, isNull,
          reason: '恢复路径必须深拷贝——文件 base64 不得写回对话持有的对象，'
              '否则对话 JSON 会被撑爆（持久化静默失败）');
    });
  });
}
