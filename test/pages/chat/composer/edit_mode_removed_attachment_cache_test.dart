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
/// AttachmentStorage 的磁盘读写（含压缩缓存）落到真实临时文件上。
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;

  @override
  Future<String> getTemporaryPath() async => root;
}

void _dummyOnSend(String text, List<Attachment> attachments) {}
void _dummyOnStop() {}
void _dummyOnToolsChanged(Set<String> tools) {}
void _dummyOnModelSelected(int index) {}

/// 构造进入编辑模式的 composer（editingMessageId 非空），
/// 原消息带一组图片附件（conversationId 已持久化）。
Widget _buildEditModeComposer({
  required List<Attachment> attachments,
  required void Function(String, String, List<Attachment>) onEditSend,
  String messageId = 'msg-1',
  String messageText = '原文本',
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) => ConversationsNotifier(ref)),
      activeConversationIdProvider.overrideWith((ref) => 'conv-1'),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ChatComposerWidget(
          onSend: _dummyOnSend,
          onStop: _dummyOnStop,
          onEnabledToolsChanged: _dummyOnToolsChanged,
          onModelSelected: _dummyOnModelSelected,
          editingMessageId: messageId,
          editingMessageText: messageText,
          editingMessageAttachments: attachments,
          onEditSend: onEditSend,
        ),
      ),
    ),
  );
}

/// 普通模式 composer（无编辑参数）——用于模拟 chat page 取消编辑后
/// 重建 composer（editingMessageId 由非空变 null）。
Widget _buildNormalComposer() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) => ConversationsNotifier(ref)),
      activeConversationIdProvider.overrideWith((ref) => 'conv-1'),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: ChatComposerWidget(
          onSend: _dummyOnSend,
          onStop: _dummyOnStop,
          onEnabledToolsChanged: _dummyOnToolsChanged,
          onModelSelected: _dummyOnModelSelected,
        ),
      ),
    ),
  );
}

/// 让真实异步 IO（unawaited 的缓存删除等）在 widget 测试中完成。
///
/// unawaited 的清理链在 fake 区里走 microtask（pump 排空），真实文件
/// IO 靠真实事件循环（runAsync 驱动）——两者交替出现，需要轮流泵。
Future<void> _flushRealAsync(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }
}

void main() {
  late Directory tmpRoot;

  setUp(() {
    tmpRoot = Directory.systemTemp.createTempSync('stroom_composer_cache_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tmpRoot.path);
  });

  tearDown(() {
    try {
      tmpRoot.deleteSync(recursive: true);
    } catch (_) {
      // 非关键清理
    }
  });

  /// 原消息的图片附件（模拟从历史加载：conversationId 已持久化）。
  Attachment originalImage({String id = 'orig-1', String hash = 'hash-orig'}) {
    return Attachment(
      id: id,
      fileName: 'photo.png',
      mimeType: 'image/png',
      fileType: 'image',
      hash: hash,
      storagePath: 'attachments/${hash}_1.png',
      fileSize: 1024,
      conversationId: 'conv-1',
    );
  }

  Future<void> seedCache(WidgetTester tester, Attachment att) async {
    await tester.runAsync(() => AttachmentStorage.saveCompressedImage(
          conversationId: att.conversationId,
          hash: att.hash,
          bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]),
          mimeType: 'image/jpeg',
        ));
  }

  Future<bool> cacheExists(WidgetTester tester, Attachment att) async {
    final cached = await tester.runAsync(() => AttachmentStorage
        .readCompressedImage(
            conversationId: att.conversationId, hash: att.hash));
    return cached != null;
  }

  group('编辑模式移除图片的压缩缓存清理时机', () {
    testWidgets('移除原图后缓存仍在（可能取消编辑），确定重发后才清理',
        (tester) async {
      final att = originalImage();
      await seedCache(tester, att);

      String? sentId;
      String? sentText;
      List<Attachment>? sentAttachments;
      await tester.pumpWidget(_buildEditModeComposer(
        attachments: [att],
        onEditSend: (id, text, atts) {
          sentId = id;
          sentText = text;
          sentAttachments = atts;
        },
      ));
      await tester.pump();

      // 编辑模式下移除原图：缓存必须保留（用户可能取消编辑）
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('pending_att_orig-1')),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pump();
      await _flushRealAsync(tester);
      expect(await cacheExists(tester, att), isTrue,
          reason: '编辑期间移除原图不得立即删缓存——取消编辑后原消息仍引用它');

      // 确定重发：编辑模式下点发送
      await tester.enterText(find.byType(TextField), '新文本');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sentId, 'msg-1');
      expect(sentText, '新文本');
      expect(sentAttachments, isEmpty, reason: '被移除的附件不应出现在重发列表');

      // 提交后缓存被清理（等待异步删除完成）
      await _flushRealAsync(tester);
      expect(await cacheExists(tester, att), isFalse,
          reason: '确定重发后必须清理被移除图片的压缩缓存');
    });

    testWidgets('移除原图后取消编辑（不发送）：缓存保持不变', (tester) async {
      final att = originalImage();
      await seedCache(tester, att);

      await tester.pumpWidget(_buildEditModeComposer(
        attachments: [att],
        onEditSend: (id, text, atts) {},
      ));
      await tester.pump();

      // 移除原图（缓存不得删）
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('pending_att_orig-1')),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pump();
      await _flushRealAsync(tester);
      expect(await cacheExists(tester, att), isTrue);

      // 取消编辑：chat page 把 editingMessageId 置空 → composer
      // didUpdateWidget 走编辑取消分支（_clearPendingAttachments）
      await tester.pumpWidget(_buildNormalComposer());
      await tester.pump();
      // 取消后编辑模式退出（无胶囊、无 pending 附件）
      expect(find.text('编辑消息'), findsNothing);
      await _flushRealAsync(tester);

      expect(await cacheExists(tester, att), isTrue,
          reason: '取消编辑后原消息仍引用该附件，缓存必须保留');
    });

    testWidgets('移除原图后切换到无附件消息编辑：陈旧芯片清空，提交不误删上一会话缓存',
        (tester) async {
      final att = originalImage();
      await seedCache(tester, att);

      // 编辑 msg-1（带图），移除原图（缓存推迟）
      await tester.pumpWidget(_buildEditModeComposer(
        attachments: [att],
        onEditSend: (id, text, atts) {},
      ));
      await tester.pump();
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('pending_att_orig-1')),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pump();
      await _flushRealAsync(tester);

      // 直接切换编辑目标：msg-2（无附件）→ 会话状态必须重置
      await tester.pumpWidget(_buildEditModeComposer(
        attachments: const [],
        onEditSend: (id, text, atts) {},
        messageId: 'msg-2',
        messageText: '文本2',
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('pending_att_orig-1')), findsNothing,
          reason: '切换到无附件消息后，上一会话的陈旧附件芯片必须清空');

      // 在 msg-2 上确定重发：不得误删 msg-1 仍引用图片的缓存
      await tester.enterText(find.byType(TextField), '文本2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await _flushRealAsync(tester);
      expect(await cacheExists(tester, att), isTrue,
          reason: 'msg-1 仍引用该附件，msg-2 的提交不得删除它的缓存');
    });
  });
}
