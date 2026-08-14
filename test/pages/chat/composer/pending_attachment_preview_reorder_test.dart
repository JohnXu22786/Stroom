import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void _dummyOnSend(String text, List<Attachment> attachments) {}
void _dummyOnStop() {}
void _dummyOnToolsChanged(Set<String> tools) {}
void _dummyOnModelSelected(int index) {}

/// 测试用 PathProvider：把"应用文档目录"指向临时目录，让
/// AttachmentStorage 的磁盘读写落到真实临时文件上（与
/// draft_attachments_test.dart 同一模式）。
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;

  @override
  Future<String> getTemporaryPath() async => root;
}

ProviderContainer _buildContainer() {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = [
          Conversation(id: 'test-conv-id', title: 'Test', messages: []),
        ];
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith(
        (ref) => ProviderEntriesNotifier(),
      ),
    ],
  );
}

Widget _composer({
  required ProviderContainer container,
  required List<Attachment> initialDraftAttachments,
  required void Function(String text, List<Attachment> attachments) onSend,
  void Function(Attachment attachment)? onPreviewAttachment,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: ChatComposerWidget(
          conversationId: 'test-conv-id',
          initialDraftAttachments: initialDraftAttachments,
          onSend: onSend,
          onStop: _dummyOnStop,
          onEnabledToolsChanged: _dummyOnToolsChanged,
          onModelSelected: _dummyOnModelSelected,
          onPreviewAttachment: onPreviewAttachment,
        ),
      ),
    ),
  );
}

/// 文档附件：待发芯片无需文件 IO 即可渲染（图标 + 文件名），
/// 恢复草稿时 readFile 读不到文件也只是静默返回 null。
Attachment _docAttachment(String id, String fileName) {
  return Attachment(
    id: id,
    fileName: fileName,
    mimeType: 'text/plain',
    fileType: 'document',
    hash: 'hash-$id',
    storagePath: 'attachments/$id.txt',
    fileSize: 1024,
    conversationId: 'test-conv-id',
  );
}

void main() {
  group('ChatComposerWidget pending attachments rendering', () {
    testWidgets('composer shows attachment panel when attach button is tapped',
        (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith(
              (ref) => ConversationsNotifier(ref),
            ),
            activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);

      // Tap the attach button to confirm the panel opens
      await tester.tap(find.byIcon(Icons.attach_file_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the file attachment panel
      expect(find.text('传文件'), findsOneWidget);
    });
  });

  group('ChatComposerWidget pending attachment drag reorder', () {
    late Directory tmpRoot;
    late PathProviderPlatform previousPlatform;

    setUp(() {
      tmpRoot = Directory.systemTemp.createTempSync('stroom_pending_reorder_');
      previousPlatform = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(tmpRoot.path);
    });

    tearDown(() {
      PathProviderPlatform.instance = previousPlatform;
      try {
        tmpRoot.deleteSync(recursive: true);
      } catch (_) {
        // 非关键清理
      }
    });

    testWidgets(
      'long-press ~350ms then drag reorders pending chips; send preserves '
      'the reordered order (short drag trigger, not the 500ms default)',
      (tester) async {
        final container = _buildContainer();
        List<Attachment>? sent;
        await tester.pumpWidget(_composer(
          container: container,
          initialDraftAttachments: [
            _docAttachment('a', 'a.txt'),
            _docAttachment('b', 'b.txt'),
          ],
          onSend: (text, atts) => sent = atts,
        ));
        await tester.pump();

        final aFinder = find.byKey(const ValueKey('pending_att_a'));
        final bFinder = find.byKey(const ValueKey('pending_att_b'));
        expect(aFinder, findsOneWidget);
        expect(bFinder, findsOneWidget);

        // 按住 350ms（> 全应用拖拽排序短延迟 kDragSortDelay 280ms、
        // < ReorderableDelayedDragStartListener 默认 500ms）：只有短
        // 延迟生效时拖拽才会开始，移动才会触发重排。
        final gesture = await tester.startGesture(tester.getCenter(aFinder));
        await tester.pump(const Duration(milliseconds: 350));
        // 拖动第一个芯片越过第二个（芯片宽 72 + 右边距 8 = 80 间距）
        await gesture.moveBy(const Offset(170, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        // 发送：顺序必须与重排后的待发状态一致（b 在前）
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
        // 排空 notifier 的防抖持久化计时器（500ms），避免挂起
        await tester.pump(const Duration(milliseconds: 600));

        expect(sent, isNotNull);
        expect(sent!.map((a) => a.id).toList(), ['b', 'a'],
            reason: '发送顺序必须与拖拽重排后的待发状态一致');
      },
    );

    testWidgets(
      'quick tap on a pending chip still opens the preview and does not '
      'start a drag reorder',
      (tester) async {
        final container = _buildContainer();
        List<Attachment>? sent;
        final previewed = <String>[];
        await tester.pumpWidget(_composer(
          container: container,
          initialDraftAttachments: [
            _docAttachment('a', 'a.txt'),
            _docAttachment('b', 'b.txt'),
          ],
          onSend: (text, atts) => sent = atts,
          onPreviewAttachment: (att) => previewed.add(att.id),
        ));
        await tester.pump();

        // 快速点击（远短于短延迟）→ 打开预览，不得触发拖拽
        await tester.tap(find.byKey(const ValueKey('pending_att_a')));
        await tester.pump();
        expect(previewed, ['a'],
            reason: '快速点击必须走预览回调而非拖拽');

        // 顺序未被意外改变
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(sent, isNotNull);
        expect(sent!.map((a) => a.id).toList(), ['a', 'b'],
            reason: '未拖拽时发送顺序保持原待发顺序');
      },
    );
  });
}
