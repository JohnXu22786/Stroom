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
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/message_attachment_preview.dart';
import 'package:stroom/pages/chat/widgets/reasoning_section.dart';
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

ChatMessage _assistantMessage({
  required String id,
  required String content,
  List<Attachment> attachments = const [],
  List<Map<String, dynamic>>? contentParts,
  List<ToolCallData>? toolCalls,
  String? reasoningContent,
  List<String>? reasoningSections,
  bool isError = false,
}) {
  return ChatMessage(
    id: id,
    role: 'assistant',
    content: content,
    isError: isError,
    attachments: attachments,
    contentParts: contentParts,
    toolCalls: toolCalls,
    reasoningContent: reasoningContent,
    reasoningSections: reasoningSections,
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
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
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
        'previews (no bubble to separate from)', (tester) async {
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
    });
  });

  testWidgets(
    'assistant generated media attachment renders through the message preview',
    (tester) async {
      await _pumpLoadedChatPage(tester, [
        _assistantMessage(
          id: 'a1',
          content: 'Here is the generated image.',
          attachments: [
            Attachment(
              fileName: 'generated.png',
              mimeType: 'image/png',
              fileType: 'image',
              hash: 'generated-image-hash',
              storagePath: '/tmp/generated.png',
              fileSize: 3,
            ),
          ],
        ),
      ]);

      expect(find.byType(MessageAttachmentPreview), findsOneWidget);
      expect(find.text('generated.png'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    },
  );

  testWidgets('assistant generated media stays between ordered text parts', (
    tester,
  ) async {
    final attachment = _namedDocumentAttachment('generated.pdf');
    await _pumpLoadedChatPage(tester, [
      _assistantMessage(
        id: 'a-ordered-media',
        content: 'before after',
        attachments: [attachment],
        contentParts: [
          {'type': 'text', 'text': 'before'},
          {'type': 'attachment', 'attachmentId': attachment.id},
          {'type': 'text', 'text': 'after'},
        ],
      ),
    ]);

    final beforeY = tester.getTopLeft(find.text('before')).dy;
    final attachmentY = tester.getTopLeft(find.text('generated.pdf')).dy;
    final afterY = tester.getTopLeft(find.text('after')).dy;
    expect(beforeY, lessThan(attachmentY));
    expect(attachmentY, lessThan(afterY));
  });

  testWidgets('assistant ordered media does not hide tool calls or reasoning', (
    tester,
  ) async {
    final attachment = _namedDocumentAttachment('generated.pdf');
    await _pumpLoadedChatPage(tester, [
      _assistantMessage(
        id: 'a-media-tools',
        content: 'Here is the file',
        attachments: [attachment],
        contentParts: [
          {'type': 'text', 'text': 'Here is the file'},
          {'type': 'attachment', 'attachmentId': attachment.id},
        ],
        toolCalls: const [
          ToolCallData(
            id: 'tool-1',
            name: 'search',
            arguments: {},
            status: ToolCallStatus.completed,
            result: 'Found a match',
          ),
        ],
        reasoningSections: ['I inspected the document.'],
      ),
    ]);

    expect(find.text('generated.pdf'), findsOneWidget);
    expect(find.text('search'), findsOneWidget);
    expect(find.byType(ReasoningSection), findsOneWidget);
  });

  testWidgets(
    'partial media remains available on an errored assistant message',
    (tester) async {
      await _pumpLoadedChatPage(tester, [
        _assistantMessage(
          id: 'a-error',
          content: 'Partial result',
          isError: true,
          attachments: [
            Attachment(
              fileName: 'partial.png',
              mimeType: 'image/png',
              fileType: 'image',
              hash: 'partial-image-hash',
              storagePath: '/tmp/partial.png',
              fileSize: 3,
            ),
          ],
        ),
      ]);

      expect(find.byType(MessageAttachmentPreview), findsOneWidget);
      expect(find.text('partial.png'), findsOneWidget);
    },
  );

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

  testWidgets('remote generated media preview shows its provider reference', (
    tester,
  ) async {
    const reference = 'gs://bucket/generated-clip.mp4';
    final attachment = Attachment(
      id: 'generated-remote-video',
      fileName: 'generated-clip.mp4',
      mimeType: 'video/mp4',
      fileType: 'video',
      hash: '',
      storagePath: reference,
      fileSize: 0,
      extraFields: const {'stroom.mediaReference': reference},
    );
    await _pumpLoadedChatPage(tester, [
      _assistantMessage(id: 'a1', content: '', attachments: [attachment]),
    ]);

    await tester.tap(find.byType(MessageAttachmentPreview));
    await tester.pumpAndSettle();

    expect(find.text(reference), findsOneWidget);
  });
}
