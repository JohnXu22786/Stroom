// Tests for the edit data-loss warning on ChatPage:
// editing a user message deletes every message below it once sent, so
// entering edit mode shows a warning ("重新编辑发送后下面所有的消息将丢失")
// immediately — no keyboard/fallback wait — in the composer, centered in
// the edit capsule's row, replacing the capsule while visible. Fades in on
// entry, auto-dismisses after 2 seconds or via close; both fade the pill
// out before the edit capsule fades back in.
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

/// Key of the warning pill itself (for centering assertions).
const _pillKey = Key('editWarningPill');

/// Text of the composer's edit capsule.
const _capsuleText = '编辑消息';

/// How long dismissal takes before the edit capsule is back in the row:
/// the pill's 200ms fade-out plus its 50ms removal margin. Tests pump past
/// it to see the capsule return.
const _fadeDuration = Duration(milliseconds: 250);

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

/// The close (X) button of the composer's edit capsule (only present when
/// the capsule — not the warning pill — is shown).
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
      'editing a user message with newer messages below reveals the '
      'warning immediately, centered in the composer and replacing the '
      'capsule, with a close button',
      (tester) async {
        // user_0 has assistant_1 and user_2 below it.
        await _pumpLoadedChatPage(tester, _alternatingMessages(3));

        await tester.tap(_editButton(last: false));
        await tester.pump();

        // Revealed immediately — no keyboard/fallback wait.
        expect(find.text(_warningText), findsOneWidget);
        expect(find.byKey(_closeButtonKey), findsOneWidget);
        // The pill replaces the capsule in its row while visible.
        expect(find.text(_capsuleText), findsNothing);
        // It sits in the composer (not the message display area)…
        expect(
          find.ancestor(
            of: find.text(_warningText),
            matching: find.byType(ChatComposerWidget),
          ),
          findsOneWidget,
        );
        // …horizontally centered on the capsule's row.
        final composerCenter = tester.getCenter(
          find.byType(ChatComposerWidget),
        );
        final pillCenter = tester.getCenter(find.byKey(_pillKey));
        expect((pillCenter.dx - composerCenter.dx).abs(), lessThan(1.0));

        // Close: the pill fades out first, then the capsule returns.
        await tester.tap(find.byKey(_closeButtonKey));
        await tester.pump();
        expect(find.text(_warningText), findsOneWidget);
        expect(find.text(_capsuleText), findsNothing);
        await tester.pump(_fadeDuration);
        expect(find.text(_warningText), findsNothing);
        expect(find.text(_capsuleText), findsOneWidget);
      },
    );

    testWidgets('warning auto-dismisses after 2 seconds', (tester) async {
      await _pumpLoadedChatPage(tester, _alternatingMessages(3));

      await tester.tap(_editButton(last: false));
      await tester.pump();
      expect(find.text(_warningText), findsOneWidget);
      expect(find.text(_capsuleText), findsNothing);

      // The countdown fires: the pill fades out (still in the tree)…
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(_warningText), findsOneWidget);
      // …then is removed and the edit capsule is back in its row.
      await tester.pump(_fadeDuration);
      expect(find.text(_warningText), findsNothing);
      expect(find.text(_capsuleText), findsOneWidget);
    });

    testWidgets('close button dismisses the warning immediately', (
      tester,
    ) async {
      await _pumpLoadedChatPage(tester, _alternatingMessages(3));

      await tester.tap(_editButton(last: false));
      await tester.pump();
      expect(find.text(_warningText), findsOneWidget);

      await tester.tap(find.byKey(_closeButtonKey));
      await tester.pump(_fadeDuration);
      expect(find.text(_warningText), findsNothing);
      expect(find.text(_capsuleText), findsOneWidget);

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
        expect(find.text(_capsuleText), findsOneWidget);
      },
    );

    testWidgets(
      'canceling edit mode after the warning auto-hides shows no warning',
      (tester) async {
        await _pumpLoadedChatPage(tester, _alternatingMessages(3));

        await tester.tap(_editButton(last: false));
        await tester.pump();
        expect(find.text(_warningText), findsOneWidget);

        // Let the warning auto-hide (fade-out completes), then cancel via
        // the capsule's X.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(_fadeDuration);
        expect(find.text(_capsuleText), findsOneWidget);

        await tester.tap(_editCapsuleCloseButton());
        await tester.pump();
        expect(find.text(_capsuleText), findsNothing);
        expect(find.text(_warningText), findsNothing);

        // Nothing reappears when the would-be 2s window elapses.
        await tester.pump(const Duration(seconds: 2));
        expect(find.text(_warningText), findsNothing);
      },
    );

    testWidgets('no warning before any edit interaction', (tester) async {
      await _pumpLoadedChatPage(tester, _alternatingMessages(3));

      expect(find.text(_warningText), findsNothing);
      expect(find.byKey(_closeButtonKey), findsNothing);
    });
  });
}
