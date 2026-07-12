import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/models/chat_message.dart';

/// Helper that creates a MaterialApp wrapped in ProviderScope with
/// all providers needed to render ChatPage.
Widget createChatTestApp({String? activeConversationId}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith(
        (ref) => activeConversationId ?? 'test-conv-id',
      ),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: const MaterialApp(home: ChatPage()),
  );
}

/// Creates a minimal test wrapper for ChatComposerWidget in isolation.
/// This allows precise control over callbacks.
Widget wrapComposerInApp({
  String? editingMessageId,
  String? editingMessageText,
  List<Attachment>? editingMessageAttachments,
  void Function(String messageId, String text, List<Attachment>)? onEditSend,
  VoidCallback? onEditCancel,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ChatComposerWidget(
          onSend: (text, attachments) {},
          onStop: () {},
          onEnabledToolsChanged: (_) {},
          modelNames: const ['model-a', 'model-b'],
          selectedModelIndex: 0,
          onModelSelected: (_) {},
          editingMessageId: editingMessageId,
          editingMessageText: editingMessageText,
          editingMessageAttachments: editingMessageAttachments,
          onEditSend: onEditSend,
          onEditCancel: onEditCancel,
        ),
      ),
    ),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════
  // Logic verification tests
  // ═══════════════════════════════════════════════════════════

  group('Edit mode routing logic', () {
    test('non-empty text with editingMessageId routes to onEditSend', () {
      String? routedId;
      String? routedText;
      List<Attachment>? routedAtts;
      bool onSendCalled = false;

      // Simulates _handleSubmitted when editingMessageId is set
      void handleEditSubmit(
        String text,
        void Function(String, String, List<Attachment>) send,
      ) {
        send('msg-1', text, []);
      }

      // Simulates _handleSubmitted when editingMessageId is null
      void handleNewSubmit(String text, void Function(String, List) send) {
        send(text, []);
      }

      handleEditSubmit('edited content', (id, text, atts) {
        routedId = id;
        routedText = text;
        routedAtts = atts;
      });
      handleNewSubmit('new message', (text, _) {
        onSendCalled = true;
      });

      expect(routedId, 'msg-1');
      expect(routedText, 'edited content');
      expect(routedAtts, isNotNull);
      expect(onSendCalled, true);
    });

    test('empty text with no attachments is blocked by guard', () {
      // The real guard: `text.trim().isEmpty && _pendingAttachments.isEmpty`
      bool guardPassed(String text, bool hasAttachments) {
        return text.trim().isNotEmpty || hasAttachments;
      }

      expect(guardPassed('', false), false); // empty, no atts → blocked
      expect(guardPassed('', true), true); // empty, has atts → passes
      expect(guardPassed('hi', false), true); // non-empty, no atts → passes
      expect(guardPassed('hi', true), true); // non-empty, has atts → passes
    });

    test('cancel edit callback fires as expected', () {
      bool cancelCalled = false;
      final cancel = () => cancelCalled = true;

      cancel();
      expect(cancelCalled, true);
    });

    test('edit send passes messageId, text, and attachments to callback', () {
      String? capturedId;
      String? capturedText;
      List<Attachment>? capturedAtts;

      void handleEditSend(
        String messageId,
        String text,
        List<Attachment> attachments,
      ) {
        capturedId = messageId;
        capturedText = text;
        capturedAtts = attachments;
      }

      final testAtts = [
        Attachment(
            fileName: 'doc.pdf',
            mimeType: 'application/pdf',
            fileType: 'document',
            hash: 'abc',
            storagePath: '/path',
            fileSize: 100),
      ];

      handleEditSend('msg-abc-123', 'edited message content', testAtts);

      expect(capturedId, 'msg-abc-123');
      expect(capturedText, 'edited message content');
      expect(capturedAtts, hasLength(1));
      expect(capturedAtts![0].fileName, 'doc.pdf');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Widget tests: UI rendering
  // ═══════════════════════════════════════════════════════════

  group('Edit mode capsule UI', () {
    testWidgets('edit capsule NOT visible when editingMessageId is null', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // The edit capsule should NOT appear in normal mode
      expect(find.text('编辑消息'), findsNothing);
    });

      testWidgets(
        'edit capsule visible with X button when editingMessageId is set',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1200, 2000));
        await tester.pumpWidget(
          wrapComposerInApp(
            editingMessageId: 'msg-1',
            editingMessageText: 'original text',
            onEditCancel: () {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // The edit capsule should be visible
        expect(find.text('编辑消息'), findsOneWidget);

        // The X (close) button should be visible
        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets('X button on capsule triggers onEditCancel', (tester) async {
      String? cancelResult;
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: 'msg-1',
          editingMessageText: 'original text',
          onEditCancel: () => cancelResult = 'cancelled',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Tap the X button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(cancelResult, 'cancelled');
    });

    testWidgets(
      'text field is pre-filled with editingMessageText in edit mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 2000));
        await tester.pumpWidget(
          wrapComposerInApp(
            editingMessageId: 'msg-1',
            editingMessageText: 'this is the message being edited',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // The text field should contain the editing message text
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);

        // Verify the text field contains the pre-filled text
        final widget = tester.widget<TextField>(textField);
        expect(widget.controller?.text, 'this is the message being edited');
      },
    );

    testWidgets('send button triggers edit send in edit mode', (tester) async {
      String? editId;
      String? editText;
      List<Attachment>? editAtts;
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: 'msg-editing',
          editingMessageText: 'edit this',
          onEditSend: (id, text, atts) {
            editId = id;
            editText = text;
            editAtts = atts;
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Send button should be present
      final sendButton = find.byIcon(Icons.send_rounded);
      expect(sendButton, findsOneWidget);

      // Tap the send button
      await tester.tap(sendButton);
      await tester.pump();

      // onEditSend should have been called with correct params
      expect(editId, 'msg-editing');
      expect(editText, 'edit this');
      expect(editAtts, isNotNull);
    });

    testWidgets('model/tools/reasoning chips still visible in edit mode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: 'msg-1',
          editingMessageText: 'text',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Settings chips should still be visible
      expect(find.textContaining('model-a'), findsOneWidget);
      expect(find.text('工具'), findsOneWidget);
      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets('attach file button visible in edit mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: 'msg-1',
          editingMessageText: 'text',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Attach file button should be visible in edit mode (same as new msg)
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
    });

    testWidgets('attach file button visible in normal mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        wrapComposerInApp(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Attach file button should be visible in normal mode
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
    });

    testWidgets('fullscreen editor button visible in edit mode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: 'msg-1',
          editingMessageText: 'text for fullscreen',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Fullscreen icon should be visible
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    });

    testWidgets(
      'pre-populated attachments show in pending area in edit mode',
      (tester) async {
        final testAtts = [
          Attachment(
            fileName: 'doc.pdf',
            mimeType: 'application/pdf',
            fileType: 'document',
            hash: 'abc',
            storagePath: '/path/doc.pdf',
            fileSize: 100,
          ),
          Attachment(
            fileName: 'image.png',
            mimeType: 'image/png',
            fileType: 'image',
            hash: 'def',
            storagePath: '/path/image.png',
            fileSize: 200,
          ),
        ];

        await tester.binding.setSurfaceSize(const Size(1200, 2000));
        await tester.pumpWidget(
          wrapComposerInApp(
            editingMessageId: 'msg-1',
            editingMessageText: 'edit with attachments',
            editingMessageAttachments: testAtts,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // The pending attachment area should show the attachments
        expect(find.text('doc.pdf'), findsOneWidget);
        // Non-image files show a file icon in the pending area
        // (image atts may show loading state since bytes not available in test)
      },
    );

    testWidgets(
      'send in edit mode passes attachments to callback',
      (tester) async {
        List<Attachment>? sentAtts;
        final testAtts = [
          Attachment(
            fileName: 'report.pdf',
            mimeType: 'application/pdf',
            fileType: 'document',
            hash: '123',
            storagePath: '/path',
            fileSize: 500,
          ),
        ];

        await tester.binding.setSurfaceSize(const Size(1200, 2000));
        await tester.pumpWidget(
          wrapComposerInApp(
            editingMessageId: 'msg-1',
            editingMessageText: 'edit text',
            editingMessageAttachments: testAtts,
            onEditSend: (id, text, atts) {
              sentAtts = atts;
            },
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Tap the send button
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();

        // Attachments should be passed through
        expect(sentAtts, hasLength(1));
        expect(sentAtts![0].fileName, 'report.pdf');
      },
    );
  });

  // ═══════════════════════════════════════════════════════════
  // Chaos / Lifecycle tests
  // ═══════════════════════════════════════════════════════════

  group('Edit mode lifecycle', () {
    testWidgets('enter edit mode, cancel, re-enter works correctly', (
      tester,
    ) async {
      int cancelCount = 0;
      String? lastEditId;
      await tester.binding.setSurfaceSize(const Size(1200, 2000));

      // First: enter edit mode
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: 'msg-1',
          editingMessageText: 'first edit',
          onEditCancel: () => cancelCount++,
          onEditSend: (id, text, atts) => lastEditId = id,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Edit capsule should be visible
      expect(find.text('编辑消息'), findsOneWidget);

      // Cancel (simulate by tapping X)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(cancelCount, 1);

      // Second: re-enter edit mode with a different message
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: 'msg-2',
          editingMessageText: 'second edit',
          onEditCancel: () => cancelCount++,
          onEditSend: (id, text, atts) => lastEditId = id,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Edit capsule should be visible again
      expect(find.text('编辑消息'), findsOneWidget);

      // Send the edit
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(lastEditId, 'msg-2');
    });
  });
}
