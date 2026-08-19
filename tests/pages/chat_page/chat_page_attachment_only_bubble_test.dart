// Tests for user message bubble visibility based on text content:
// a user message that carries only attachments (files/images) and no
// text must NOT render an empty blue text bubble — the bubble is shown
// only when the message actually has text (trimmed), while the
// attachment previews stay visible regardless. Editing a message to
// add text re-shows the bubble (same render path, covered by the
// text+attachment case).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show SimpleTextMessage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/message_attachment_preview.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Creates a ChatPage app with a conversation pre-populated with [messages].
///
/// Seeds [conversationsProvider] state directly (the async `_load()` is
/// library-private and skipped by provider overrides) — this is the
/// established pattern used by other conversation-seeded tests.
Widget createChatTestAppWithMessages(List<ChatMessage> messages) {
  SharedPreferences.setMockInitialValues({});
  final conversation = Conversation(
    id: 'test-conv-id',
    title: 'Test Conversation',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    messages: messages,
  );
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = [conversation];
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: const MaterialApp(home: ChatPage()),
  );
}

ChatMessage _userMessage({
  required String id,
  required String content,
  List<Attachment> attachments = const [],
}) {
  return ChatMessage(
    id: id,
    role: 'user',
    content: content,
    attachments: attachments,
    createdAt: DateTime(2025, 1, 1),
  );
}

/// A document attachment (renders synchronously as an icon chip, no async
/// file IO in tests).
Attachment _documentAttachment() {
  return Attachment(
    fileName: 'doc.txt',
    mimeType: 'text/plain',
    fileType: 'document',
    hash: 'doc123',
    storagePath: '/tmp/doc.txt',
    fileSize: 2048,
  );
}

/// A document attachment with a distinct [fileName] (and hash) so tests can
/// assert which attachment rendered where.
Attachment _namedDocumentAttachment(String fileName) {
  return Attachment(
    fileName: fileName,
    mimeType: 'text/plain',
    fileType: 'document',
    hash: 'hash-$fileName',
    storagePath: '/tmp/$fileName',
    fileSize: 2048,
  );
}

/// Pumps until messages are loaded (same cadence as the existing tests).
Future<void> _pumpLoadedChatPage(
  WidgetTester tester,
  List<ChatMessage> messages,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  await tester.pumpWidget(createChatTestAppWithMessages(messages));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // Consume any pre-existing framework exceptions from flutter_chat_ui.
  tester.takeException();
}

void main() {
  setUp(() {
    // Disable visibility_detector's 500ms debounce timer in tests,
    // otherwise it leaves a pending timer that fails test teardown
    // (same pattern as chat_reentry_test.dart / edit warning test).
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  group('ChatPage user message bubble visibility', () {
    testWidgets(
      'attachment-only user message (empty text) renders no text bubble '
      'but keeps the attachment preview',
      (tester) async {
        await _pumpLoadedChatPage(tester, [
          _userMessage(
            id: 'u1',
            content: '',
            attachments: [_documentAttachment()],
          ),
        ]);

        expect(find.byType(SimpleTextMessage), findsNothing);
        expect(find.text('doc.txt'), findsOneWidget);
      },
    );

    testWidgets(
      'user message with whitespace-only text renders no text bubble',
      (tester) async {
        await _pumpLoadedChatPage(tester, [
          _userMessage(id: 'u1', content: '   '),
        ]);

        expect(find.byType(SimpleTextMessage), findsNothing);
      },
    );

    testWidgets(
      'user message with text and attachment still renders the text bubble',
      (tester) async {
        await _pumpLoadedChatPage(tester, [
          _userMessage(
            id: 'u1',
            content: '看一下这个文件',
            attachments: [_documentAttachment()],
          ),
        ]);

        expect(find.byType(SimpleTextMessage), findsOneWidget);
        expect(find.text('doc.txt'), findsOneWidget);
      },
    );

    testWidgets(
      'attachments keep a visible gap below the text bubble instead of '
      'sticking to it',
      (tester) async {
        await _pumpLoadedChatPage(tester, [
          _userMessage(
            id: 'u1',
            content: '看一下这个文件',
            attachments: [_documentAttachment()],
          ),
        ]);

        final bubbleRect = tester.getRect(find.byType(SimpleTextMessage));
        final previewRect = tester.getRect(
          find.byType(MessageAttachmentPreview),
        );
        // The attachment preview must not hug the bubble bottom edge:
        // SimpleTextMessage has no margin, so the rendered gap equals the
        // attachment area's top padding exactly. Pin both to the design
        // value so a partial regression (e.g. 8px -> 4px) fails too.
        expect(previewRect.top - bubbleRect.bottom, closeTo(8, 0.5));
        final padding = tester.widget<Padding>(
          find.byKey(const ValueKey('user-message-attachment-area')),
        );
        expect(
          padding.padding.resolve(TextDirection.ltr).top,
          closeTo(8, 0.001),
        );
      },
    );

    testWidgets(
      'attachment-only message does not add extra spacing above the '
      'previews (no bubble to separate from)',
      (tester) async {
        await _pumpLoadedChatPage(tester, [
          _userMessage(
            id: 'u1',
            content: '',
            attachments: [_documentAttachment()],
          ),
        ]);

        // No bubble above → the attachment area must not carry the
        // bubble-separation top padding.
        final padding = tester.widget<Padding>(
          find.byKey(const ValueKey('user-message-attachment-area')),
        );
        expect(padding.padding.resolve(TextDirection.ltr).top, 0);
      },
    );
  });

  group('ChatPage user message attachment preview order', () {
    testWidgets(
      'attachment previews render left-to-right in the same order as the '
      'pending/send order (first file leftmost)',
      (tester) async {
        await _pumpLoadedChatPage(tester, [
          _userMessage(
            id: 'u1',
            content: '三个文件',
            attachments: [
              _namedDocumentAttachment('alpha.txt'),
              _namedDocumentAttachment('bravo.txt'),
              _namedDocumentAttachment('charlie.txt'),
            ],
          ),
        ]);

        // 记录里的可见顺序必须与待发/发送顺序一致：alpha 最左、
        // charlie 最右（气泡右对齐，但顺序不能被镜像反转）。
        final xs = <double>[];
        for (final name in ['alpha.txt', 'bravo.txt', 'charlie.txt']) {
          final finder = find.text(name);
          expect(finder, findsOneWidget, reason: '附件名 $name 应显示在气泡中');
          xs.add(tester.getTopLeft(finder).dx);
        }
        expect(xs[0], lessThan(xs[1]), reason: '第一个待发文件必须显示在最左侧');
        expect(xs[1], lessThan(xs[2]), reason: '第二个待发文件必须显示在第三个之前');
      },
    );

    testWidgets(
      'overflowing attachment strips rest at the head: the first file is '
      'visible at the left (like the pending row)',
      (tester) async {
        // 窄屏让横条溢出：8 个文件 × 108px 间距 >> 400px 视口
        await tester.binding.setSurfaceSize(const Size(400, 800));
        await tester.pumpWidget(
          createChatTestAppWithMessages([
            _userMessage(
              id: 'u1',
              content: '一批文件',
              attachments: [
                for (var i = 0; i < 8; i++) _namedDocumentAttachment('f$i.txt'),
              ],
            ),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // 第一个文件必须构建且落在视口内（若横条按 reverse 右锚定，
        // f0 会在最左屏外不被构建；shrinkWrap + 左锚定则默认显示首项）
        final f0 = find.text('f0.txt');
        expect(f0, findsOneWidget, reason: '横条默认必须显示第一个文件');
        final f0dx = tester.getTopLeft(f0).dx;
        expect(f0dx, greaterThanOrEqualTo(0));
        expect(f0dx, lessThan(400));

        // 可见部分按发送顺序从左到右排布
        final dxs = [
          f0dx,
          tester.getTopLeft(find.text('f1.txt')).dx,
          tester.getTopLeft(find.text('f2.txt')).dx,
          tester.getTopLeft(find.text('f3.txt')).dx,
        ];
        expect(dxs[0], lessThan(dxs[1]));
        expect(dxs[1], lessThan(dxs[2]));
        expect(dxs[2], lessThan(dxs[3]));
      },
    );
  });
}
