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
  });
}
