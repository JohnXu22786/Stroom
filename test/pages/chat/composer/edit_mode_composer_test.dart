import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
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
  void Function(String text, List<Attachment> attachments)? onSend,
  String? conversationId,
  Set<String> streamingConversations = const {},
  bool showEditWarningOnEntry = false,
  int editWarningArmCount = 0,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      streamingConversationsProvider.overrideWith(
        (ref) => streamingConversations,
      ),
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
          onSend: onSend ?? (text, attachments) {},
          onStop: () {},
          onEnabledToolsChanged: (_) {},
          modelNames: const ['model-a', 'model-b'],
          selectedModelIndex: 0,
          onModelSelected: (_) {},
          conversationId: conversationId,
          editingMessageId: editingMessageId,
          editingMessageText: editingMessageText,
          editingMessageAttachments: editingMessageAttachments,
          onEditSend: onEditSend,
          onEditCancel: onEditCancel,
          showEditWarningOnEntry: showEditWarningOnEntry,
          editWarningArmCount: editWarningArmCount,
        ),
      ),
    ),
  );
}

void main() {
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

  // ═══════════════════════════════════════════════════════════
  // Fullscreen editor dialog exit behavior
  // ═══════════════════════════════════════════════════════════
  // Regression: exiting the fullscreen editor with the system back key
  // (navigation key) must behave like clicking the top-right X button —
  // the edited text is written back to the main input instead of being
  // discarded. Before the fix, back/pop discarded the content.

  group('Fullscreen editor dialog exit behavior', () {
    /// Pumps the composer, opens the fullscreen editor, and settles the
    /// dialog entrance animation.
    Future<void> openFullscreenEditor(
      WidgetTester tester, {
      String? editingMessageId,
      String? editingMessageText,
      String? conversationId,
      Set<String> streamingConversations = const {},
      void Function(String text, List<Attachment> attachments)? onSend,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: editingMessageId,
          editingMessageText: editingMessageText,
          conversationId: conversationId,
          streamingConversations: streamingConversations,
          onSend: onSend,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Consume the pre-existing benign framework exceptions the other
      // tests in this file tolerate; fail loudly if anything else is thrown.
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// The TextField inside the fullscreen editor dialog.
    Finder dialogTextField() => find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        );

    /// The main composer input TextField (outside the dialog).
    Finder mainInputField() => find.descendant(
          of: find.byType(ChatComposerWidget),
          matching: find.byType(TextField),
        );

    String mainInputText(WidgetTester tester) =>
        tester.widget<TextField>(mainInputField()).controller?.text ?? '';

    testWidgets('X button preserves edited text back to main input', (
      tester,
    ) async {
      await openFullscreenEditor(tester);
      await tester.enterText(dialogTextField(), 'edited in dialog');

      // Tap the top-right X button
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog closed and content preserved in the main input
      expect(find.byType(Dialog), findsNothing);
      expect(mainInputText(tester), 'edited in dialog');
    });

    testWidgets('system back key preserves edited text like the X button', (
      tester,
    ) async {
      await openFullscreenEditor(tester);
      await tester.enterText(dialogTextField(), 'typed in fullscreen');

      // Simulate the system back navigation key
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog closed and content preserved — same as the X button,
      // NOT discarded.
      expect(find.byType(Dialog), findsNothing);
      expect(mainInputText(tester), 'typed in fullscreen');
    });

    testWidgets('barrier tap preserves edited text like the X button', (
      tester,
    ) async {
      await openFullscreenEditor(tester);
      await tester.enterText(dialogTextField(), 'typed before barrier tap');

      // Tap the 8px barrier ring outside the dialog (insetPadding: 8).
      // Barrier dismiss flows through Navigator.maybePop, so it must end
      // up in the same preserve-on-close path as the X button.
      await tester.tapAt(const Offset(4, 1000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Dialog), findsNothing);
      expect(mainInputText(tester), 'typed before barrier tap');
    });

    testWidgets('back key with unchanged text keeps the original text', (
      tester,
    ) async {
      await openFullscreenEditor(
        tester,
        editingMessageId: 'msg-1',
        editingMessageText: 'original text',
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Dialog), findsNothing);
      expect(mainInputText(tester), 'original text');
    });

    testWidgets('send button still works with back-key guard in place', (
      tester,
    ) async {
      String? sentText;
      await openFullscreenEditor(tester, onSend: (text, atts) {
        sentText = text;
      });
      await tester.enterText(dialogTextField(), 'hello from fullscreen');

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.send_rounded),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog closed, message sent, composer input cleared (send behavior
      // must not be broken by the PopScope guard).
      expect(find.byType(Dialog), findsNothing);
      expect(sentText, 'hello from fullscreen');
      expect(mainInputText(tester), isEmpty);
    });

    testWidgets('send during streaming is blocked but typed text is kept', (
      tester,
    ) async {
      bool sendCalled = false;
      await openFullscreenEditor(
        tester,
        conversationId: 'test-conv-id',
        streamingConversations: {'test-conv-id'},
        onSend: (text, atts) {
          sendCalled = true;
        },
      );
      await tester.enterText(dialogTextField(), 'typed during stream');

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.send_rounded),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The streaming guard inside _handleSubmitted blocks the send, but
      // the dialog's write-back must not lose the typed text — it stays
      // in the main input instead of being discarded.
      expect(find.byType(Dialog), findsNothing);
      expect(sendCalled, false);
      expect(mainInputText(tester), 'typed during stream');
    });

    testWidgets('double back during exit animation does not pop the page', (
      tester,
    ) async {
      await openFullscreenEditor(tester);
      await tester.enterText(dialogTextField(), 'typed text');

      // First back press starts the exit animation...
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 50));
      expect(mainInputText(tester), 'typed text');

      // ...second back press mid-animation: the _closed guard (plus the
      // framework) must keep this from closing anything else. The dialog
      // closes exactly once and the composer page beneath survives.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Dialog), findsNothing);
      // The composer page must still be present (not popped twice).
      expect(find.byType(ChatComposerWidget), findsOneWidget);
      expect(mainInputText(tester), 'typed text');
    });

    testWidgets('re-opening the editor starts fresh and keeps the text', (
      tester,
    ) async {
      await openFullscreenEditor(tester);
      await tester.enterText(dialogTextField(), 'round trip text');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(mainInputText(tester), 'round trip text');

      // Re-open: a fresh dialog State seeded from the written-back text.
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<TextField>(dialogTextField()).controller?.text,
        'round trip text',
      );

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Dialog), findsNothing);
      expect(mainInputText(tester), 'round trip text');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Edit data-loss warning (composer-owned state machine)
  // ═══════════════════════════════════════════════════════════

  group('Edit data-loss warning', () {
    const warningText = '重新编辑发送后下面所有的消息将丢失';
    const closeKey = Key('editWarningCloseButton');

    /// Pumps a direct-mount composer in edit mode with the warning armed.
    Future<void> pumpArmedComposer(
      WidgetTester tester, {
      String? editingMessageId = 'msg-1',
      String conversationId = 'conv-a',
      int editWarningArmCount = 1,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: editingMessageId,
          editingMessageText: 'original text',
          conversationId: conversationId,
          showEditWarningOnEntry: true,
          editWarningArmCount: editWarningArmCount,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Consume any pre-existing framework exceptions from flutter_chat_ui
      // (same pattern as the other composer tests).
      tester.takeException();
    }

    testWidgets(
      'armed warning appears after the no-keyboard fallback and replaces '
      'the capsule',
      (tester) async {
        await pumpArmedComposer(tester);

        // Not visible immediately — waits for the soft keyboard (or the
        // no-keyboard fallback, which is what fires in tests).
        expect(find.text(warningText), findsNothing);
        expect(find.text('编辑消息'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(warningText), findsOneWidget);
        expect(find.text('编辑消息'), findsNothing);

        // Dismiss so no timers stay pending.
        await tester.tap(find.byKey(closeKey));
        await tester.pump();
        expect(find.text(warningText), findsNothing);
        expect(find.text('编辑消息'), findsOneWidget);
      },
    );

    testWidgets('leaving edit mode disarms the warning', (tester) async {
      await pumpArmedComposer(tester);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text(warningText), findsOneWidget);

      // Cancel edit mode (editingMessageId → null): the warning and the
      // capsule both disappear and nothing reappears afterwards.
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: null,
          showEditWarningOnEntry: true,
        ),
      );
      await tester.pump();
      expect(find.text(warningText), findsNothing);
      expect(find.text('编辑消息'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text(warningText), findsNothing);
    });

    testWidgets('switching conversations disarms the warning', (tester) async {
      await pumpArmedComposer(tester);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text(warningText), findsOneWidget);

      // Conversation switch while still in edit mode: the pill refers to
      // the previous conversation's messages and must disappear.
      await tester.pumpWidget(
        wrapComposerInApp(
          editingMessageId: 'msg-1',
          editingMessageText: 'original text',
          conversationId: 'conv-b',
          showEditWarningOnEntry: true,
          editWarningArmCount: 1,
        ),
      );
      await tester.pump();
      expect(find.text(warningText), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text(warningText), findsNothing);
    });

    testWidgets(
      're-entering edit on the same message (arm count bump) re-shows the '
      'warning after a dismissal',
      (tester) async {
        await pumpArmedComposer(tester);
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(warningText), findsOneWidget);

        // Dismiss via the close button.
        await tester.tap(find.byKey(closeKey));
        await tester.pump();
        expect(find.text(warningText), findsNothing);

        // Same message id, but the page bumped the arm count (user tapped
        // the edit button again): the warning re-arms and re-appears.
        await tester.pumpWidget(
          wrapComposerInApp(
            editingMessageId: 'msg-1',
            editingMessageText: 'original text',
            conversationId: 'conv-a',
            showEditWarningOnEntry: true,
            editWarningArmCount: 2,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(warningText), findsOneWidget);

        await tester.tap(find.byKey(closeKey));
        await tester.pump();
        expect(find.text(warningText), findsNothing);
      },
    );

    testWidgets(
      'a composer created directly in edit mode with the keyboard already '
      'up reveals the warning immediately (post-frame arm)',
      (tester) async {
        addTearDown(tester.view.reset);
        await tester.binding.setSurfaceSize(const Size(1200, 2000));
        // Keyboard up before the composer is even mounted.
        tester.view.viewInsets = const FakeViewPadding(bottom: 600);
        await tester.pumpWidget(
          wrapComposerInApp(
            editingMessageId: 'msg-1',
            editingMessageText: 'original text',
            showEditWarningOnEntry: true,
            editWarningArmCount: 1,
          ),
        );
        await tester.pump();
        await tester.pump();
        tester.takeException();

        // Revealed via the post-frame arm (no fallback wait needed).
        expect(find.text(warningText), findsOneWidget);
        expect(find.text('编辑消息'), findsNothing);

        await tester.tap(find.byKey(closeKey));
        await tester.pump();
        expect(find.text(warningText), findsNothing);
      },
    );

    testWidgets(
      'a rebuild without any entry bump does not re-show the warning',
      (tester) async {
        await pumpArmedComposer(tester);
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(warningText), findsOneWidget);

        // Dismiss; the capsule returns.
        await tester.tap(find.byKey(closeKey));
        await tester.pump();
        expect(find.text(warningText), findsNothing);

        // Ordinary rebuild (e.g. a keystroke) with the same arm count:
        // the warning stays dismissed.
        await tester.pumpWidget(
          wrapComposerInApp(
            editingMessageId: 'msg-1',
            editingMessageText: 'original text',
            conversationId: 'conv-a',
            showEditWarningOnEntry: true,
            editWarningArmCount: 1,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(warningText), findsNothing);
      },
    );
  });
}
