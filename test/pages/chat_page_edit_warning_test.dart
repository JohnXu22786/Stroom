// Tests for the edit data-loss warning overlay on ChatPage:
// editing a user message deletes every message below it once sent,
// so entering edit mode shows a centered, auto-dismissing warning
// ("重新编辑发送后下面所有的消息将丢失") with a close button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// The exact warning text shown when editing a user message.
const _warningText = '重新编辑发送后下面所有的消息将丢失';

/// Key of the warning's close button (distinguishes it from the edit
/// capsule's own close button in the composer).
const _closeButtonKey = Key('editWarningCloseButton');

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

/// Alternating user/assistant messages: user_0, assistant_1, user_2, ...
List<ChatMessage> _alternatingMessages(int count) {
  return List.generate(count, (i) {
    return ChatMessage(
      id: i.isEven ? 'user_$i' : 'assistant_$i',
      role: i.isEven ? 'user' : 'assistant',
      content: 'Message $i content',
      createdAt: DateTime(2025, 1, 1).add(Duration(hours: i)),
    );
  });
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

/// The edit (pencil) button under a user message bubble.
Finder _editButton({required bool last}) {
  final matches = find.byIcon(Icons.edit_outlined);
  return last ? matches.last : matches.first;
}

/// The close (X) button of the composer's edit capsule.
Finder _editCapsuleCloseButton() {
  return find.descendant(
    of: find.byType(ChatComposerWidget),
    matching: find.byIcon(Icons.close),
  );
}

void main() {
  setUp(() {
    // Disable visibility_detector's 500ms debounce timer in tests,
    // otherwise it leaves a pending timer that fails test teardown
    // (same pattern as chat_reentry_test.dart).
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  group('ChatPage edit data-loss warning', () {
    testWidgets(
      'editing a user message with newer messages below shows the '
      'centered warning with a close button',
      (tester) async {
        // user_0 has assistant_1 and user_2 below it.
        await _pumpLoadedChatPage(tester, _alternatingMessages(3));

        await tester.tap(_editButton(last: false));
        await tester.pump();

        expect(find.text(_warningText), findsOneWidget);
        expect(find.byKey(_closeButtonKey), findsOneWidget);
        // The requirement: floating centered in the message display area.
        expect(
          find.ancestor(
            of: find.text(_warningText),
            matching: find.byType(Center),
          ),
          findsOneWidget,
        );

        // Dismiss via the close button so no timers stay pending.
        await tester.tap(find.byKey(_closeButtonKey));
        await tester.pump();
        expect(find.text(_warningText), findsNothing);
      },
    );

    testWidgets('warning auto-dismisses after 2 seconds', (tester) async {
      await _pumpLoadedChatPage(tester, _alternatingMessages(3));

      await tester.tap(_editButton(last: false));
      await tester.pump();
      expect(find.text(_warningText), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text(_warningText), findsNothing);
    });

    testWidgets('close button dismisses the warning immediately', (
      tester,
    ) async {
      await _pumpLoadedChatPage(tester, _alternatingMessages(3));

      await tester.tap(_editButton(last: false));
      await tester.pump();
      expect(find.text(_warningText), findsOneWidget);

      await tester.tap(find.byKey(_closeButtonKey));
      await tester.pump();
      expect(find.text(_warningText), findsNothing);

      // Nothing reappears when the would-be 2s window elapses.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(_warningText), findsNothing);
    });

    testWidgets(
      'editing the last user message (no newer messages) shows no warning',
      (tester) async {
        // user_4 is the last message — nothing below it can be lost.
        await _pumpLoadedChatPage(tester, _alternatingMessages(5));

        expect(find.text(_warningText), findsNothing);

        await tester.tap(_editButton(last: true));
        await tester.pump();

        expect(find.text(_warningText), findsNothing);
        expect(find.byKey(_closeButtonKey), findsNothing);
      },
    );

    testWidgets('canceling edit mode hides a still-visible warning', (
      tester,
    ) async {
      await _pumpLoadedChatPage(tester, _alternatingMessages(3));

      await tester.tap(_editButton(last: false));
      await tester.pump();
      expect(find.text(_warningText), findsOneWidget);

      // Tap the composer's edit-capsule X to cancel edit mode.
      await tester.tap(_editCapsuleCloseButton());
      await tester.pump();
      expect(find.text(_warningText), findsNothing);

      // Nothing reappears when the would-be 2s window elapses.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(_warningText), findsNothing);
    });

    testWidgets('no warning before any edit interaction', (tester) async {
      await _pumpLoadedChatPage(tester, _alternatingMessages(3));

      expect(find.text(_warningText), findsNothing);
      expect(find.byKey(_closeButtonKey), findsNothing);
    });
  });
}
