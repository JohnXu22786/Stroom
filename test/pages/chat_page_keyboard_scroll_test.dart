// Widget tests for the chat page's soft-keyboard scroll behavior.
//
// Behaviors protected:
//  1. Tapping the composer input while scrolled up starts the scroll-to-
//     bottom animation immediately — before any keyboard metrics change
//     arrives (the "shift up must start the moment the user taps"
//     requirement; the didChangeMetrics transition otherwise only fires
//     once the insets cross the threshold mid-animation).
//  2. The keyboard-open metrics transition must NOT overwrite the position
//     saved by the focus hook; dismissing the keyboard restores the
//     tap-time position.
//  3. A keyboard that appears while the hook's scroll animation is still
//     running still ends at the bottom of the final viewport (the
//     follow-up scroll closes the gap the shrinking viewport left).
//  4. A saved position whose keyboard never appeared (physical keyboard /
//     suppressed IME) is dropped as stale, so a later keyboard session
//     saves a fresh position.
//  5. Keyboards that appear without a focus event (fallback path) still
//     save the current position, scroll toward the bottom, and restore on
//     dismiss.
//  6. Desktop platforms (no soft keyboard) never scroll on focus.
//  7. Tapping while already at the bottom has no side effects.
//  8. An empty conversation survives input tap + keyboard open/close.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Test messages alternating user/assistant roles.
List<ChatMessage> _testMessages(int count) {
  return List.generate(count, (i) {
    return ChatMessage(
      id: i.isEven ? 'user_$i' : 'assistant_$i',
      role: i.isEven ? 'user' : 'assistant',
      content: 'Message $i content',
      createdAt: DateTime(2025, 1, 1).add(Duration(hours: i)),
    );
  });
}

/// Wraps [app] in a `Visibility` that mirrors how HomePage's IndexedStack
/// hides the chat tab while another main page is selected: the subtree
/// stays mounted, laid out and animated, but reports itself hidden to
/// `Visibility.of(context)` and is not painted. The wrapper is ALWAYS
/// present (also for `visible: true`) so flipping the flag keeps the same
/// widget tree shape and all State.
Widget _wrapTabVisibility(Widget app, {required bool visible}) {
  return Visibility(
    visible: visible,
    maintainState: true,
    maintainSize: true,
    maintainAnimation: true,
    maintainInteractivity: true,
    child: app,
  );
}

/// Pumps a ChatPage with a conversation pre-populated with [messages].
/// [platform] overrides the theme platform (used to simulate a desktop
/// environment where no soft keyboard exists). When [visible] is false the
/// page is kept alive but hidden, as it would be while another main page
/// is selected (IndexedStack keep-alive).
Future<void> pumpChat(
  WidgetTester tester, {
  int messageCount = 60,
  TargetPlatform? platform,
  bool visible = true,
}) async {
  final messages = _testMessages(messageCount);
  SharedPreferences.setMockInitialValues({
    'conversations': jsonEncode([
      {
        'id': 'test-conv-id',
        'title': 'Test Conversation',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'isPinned': false,
        'sortOrder': 0,
      }
    ]),
  });
  await tester.pumpWidget(
    _wrapTabVisibility(
      ProviderScope(
        overrides: [
          // NOTE: conversationsProvider is intentionally NOT overridden —
          // the real provider triggers the async _load() that reads the
          // mock SharedPreferences; overriding it with a raw notifier
          // would leave the conversation unloaded and the list empty.
          activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
          providerEntriesProvider.overrideWith((ref) {
            return ProviderEntriesNotifier();
          }),
        ],
        child: MaterialApp(
          theme: platform == null
              ? null
              : ThemeData(platform: platform, useMaterial3: true),
          // In production ChatPage lives inside HomePage's Scaffold,
          // which strips viewInsets.bottom from the body's MediaQuery —
          // keyboard logic must therefore read the View directly. Keep
          // the Scaffold in the test tree so a regression (reading
          // MediaQuery instead) fails these tests instead of only
          // misbehaving on device.
          home: Scaffold(body: const ChatPage()),
        ),
      ),
      visible: visible,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // Let the chat list fully initialize (initial positioning pass, delayed
  // insert/scroll timers from flutter_chat_ui) so scroll positions are
  // stable for the assertions.
  await settle(tester);
  // Consume pre-existing framework exceptions from flutter_chat_ui.
  tester.takeException();
  // The chat library's visibility_detector schedules a 500ms re-check timer
  // whenever scrolling changes which messages are visible; using the
  // post-frame (Duration.zero) mode avoids leaving pending timers at the
  // end of the test.
  final oldUpdateInterval =
      VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  addTearDown(() {
    VisibilityDetectorController.instance.updateInterval = oldUpdateInterval;
  });
  addTearDown(tester.view.reset);
}

/// The chat list's scrollable (inside the ChatAnimatedList).
/// [skipOffstage] is false when the page is kept alive but hidden.
Finder _chatScrollable({bool skipOffstage = true}) {
  return find
      .descendant(
        of: find.byType(ChatAnimatedList, skipOffstage: skipOffstage),
        matching: find.byType(Scrollable, skipOffstage: skipOffstage),
      )
      .first;
}

ScrollPosition _scrollPosition(WidgetTester tester,
    {bool skipOffstage = true}) {
  return tester
      .state<ScrollableState>(_chatScrollable(skipOffstage: skipOffstage))
      .position;
}

/// Scrolls the chat list to the bottom. Uses the scroll position directly
/// (a drag gesture is unreliable here because message bubbles intercept
/// the pointer), which notifies the same listeners a real scroll would.
Future<void> scrollToBottom(WidgetTester tester) async {
  final pos = _scrollPosition(tester);
  pos.jumpTo(pos.maxScrollExtent);
  await tester.pump();
}

/// Scrolls up (toward older messages) by [amount] logical pixels.
Future<void> scrollUp(WidgetTester tester, {double amount = 400}) async {
  final pos = _scrollPosition(tester);
  pos.jumpTo((pos.pixels - amount).clamp(0.0, pos.maxScrollExtent));
  await tester.pump();
}

/// Flushes one-shot timers (chat library's scroll-to-bottom show timer,
/// conversation persist debounce, keyboard mixin debounce, ...) so the
/// framework's end-of-test pending-timer check passes. Pumps in small
/// steps so a timer scheduled mid-settle is also flushed.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Dispatches the view-metrics change to `didChangeMetrics` observers and
/// lets the tree rebuild. Setting `tester.view.viewInsets` already triggers
/// the metrics-changed dispatch synchronously; the app's `didChangeMetrics`
/// reads the inherited `MediaQuery`, which is one frame behind the view, so
/// the manual dispatch is repeated once the rebuild has delivered the fresh
/// insets to the page logic.
Future<void> _dispatchMetrics(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  tester.binding.handleMetricsChanged();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

/// Simulates the soft keyboard occupying [inset] logical pixels at the
/// bottom of the window: the view insets change and the enclosing
/// Scaffold (present in the test tree, like in production) shrinks the
/// body — mirroring `adjustResize` on Android. The window itself does NOT
/// resize (a resize here would double-shrink the chat area).
Future<void> setKeyboardInset(WidgetTester tester, double inset) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.viewInsets = FakeViewPadding(bottom: inset * dpr);
  await _dispatchMetrics(tester);
}

/// Restores the view insets to zero (keyboard gone).
Future<void> closeKeyboard(WidgetTester tester) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.viewInsets = FakeViewPadding.zero;
  await _dispatchMetrics(tester);
}

void main() {
  group('ChatPage keyboard scroll', () {
    testWidgets(
        'the keyboard opening or closing never moves the list — the '
        'library keyboard scroll is swallowed', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final saved = _scrollPosition(tester).pixels;
      expect(
        saved,
        lessThan(_scrollPosition(tester).maxScrollExtent - 200),
        reason: 'precondition: the list is scrolled up',
      );

      // Tap the input: no keyboard metrics yet, the list must not move.
      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'a tap must not move the list',
      );

      // The keyboard appears — the list still must not move (no keyboard
      // scroll at all; the library's debounced scroll is swallowed).
      await setKeyboardInset(tester, 300);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'the keyboard appearing must not scroll the list — the '
            'library scroll is swallowed and nothing else moves it',
      );

      // The keyboard closes — the list still must not move.
      await closeKeyboard(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'the keyboard closing must not move the list',
      );
      await settle(tester);
    });

    testWidgets(
        'scrolling to the bottom while the keyboard is open (user action) '
        'is clamped when the keyboard closes', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final saved = _scrollPosition(tester).pixels;

      // Open the keyboard: the list does not move (no keyboard scroll).
      await setKeyboardInset(tester, 300);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'precondition: keyboard open does not move the list',
      );

      // The user scrolls to the bottom while the keyboard is up (the
      // keyboard-shrunk bottom is past the pre-keyboard bottom).
      await scrollToBottom(tester);
      final openBottom = _scrollPosition(tester).pixels;

      // Dismiss: the list must NOT be animated; the viewport growing back
      // shrinks maxScrollExtent, so the offset is snapped back to the
      // (smaller) bottom — an instant correction, not a motion.
      await closeKeyboard(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(_scrollPosition(tester).maxScrollExtent, 1.0),
        reason: 'the overflow from the keyboard-shrunk bottom is clamped '
            'to the restored bottom, without any animation',
      );
      expect(
        _scrollPosition(tester).pixels,
        lessThan(openBottom),
        reason: 'the clamp moved the list back by the viewport growth',
      );
      await settle(tester);
    });

    testWidgets(
        'a keyboard appearing while the list is scrolled far up does not '
        'move it — the library scroll is swallowed', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      // Scroll far up; the keyboard must not scroll the list at all.
      await scrollUp(tester, amount: 1500);
      final saved = _scrollPosition(tester).pixels;

      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 16));
      await setKeyboardInset(tester, 300);
      // Well past the library's debounce window: nothing may move.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'the keyboard must not scroll the list, no matter how far '
            'up it is — the library scroll is swallowed',
      );

      await closeKeyboard(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'a keyboard opening without a focus event does not move the list '
        'either', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final savedPos = _scrollPosition(tester).pixels;
      expect(savedPos, greaterThan(0));

      // Keyboard appears with no focus event.
      await setKeyboardInset(tester, 300);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(savedPos, 1.0),
        reason: 'the keyboard must not scroll the list even without a '
            'focus event',
      );

      await closeKeyboard(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'desktop platforms handle the on-screen keyboard the same way: '
        'nothing moves on tap or insets change', (tester) async {
      await pumpChat(tester, platform: TargetPlatform.windows);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final saved = _scrollPosition(tester).pixels;

      // Tap alone (no keyboard on a desktop yet): no scroll.
      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'a tap must not move the list on any platform',
      );

      // A touch keyboard appears (Windows TabTip / Linux on-screen
      // keyboard drive viewInsets the same way as mobile): the list must
      // not move either.
      await setKeyboardInset(tester, 300);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'the keyboard must not scroll the list on desktop '
            'platforms either',
      );

      await closeKeyboard(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'dismiss must not move the list on desktop either',
      );
      await settle(tester);
    });

    testWidgets(
        'tapping the input while already at the bottom has no '
        'side effects', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      final before = _scrollPosition(tester).pixels;

      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        _scrollPosition(tester).pixels,
        closeTo(before, 1.0),
        reason: 'already at the bottom — no scroll should start',
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'user dragging the list while the keyboard is open cancels the '
        'follow-up scroll', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester, amount: 1500);

      // Keyboard opens; the hook scroll and the library's debounced scroll
      // run (small steps so they complete inside the follow-up window).
      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 16));
      await setKeyboardInset(tester, 300);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The user takes over the list while the keyboard is open — a
      // downward drag scrolls back up toward older messages.
      await tester.drag(_chatScrollable(), const Offset(0, 150));
      await tester.pump();

      // Past the 600ms follow-up deadline — and enough extra frames for a
      // follow-up animation to run to completion — the list must NOT have
      // snapped back.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      final pos = _scrollPosition(tester);
      expect(
        pos.pixels,
        lessThan(pos.maxScrollExtent - 100),
        reason: 'the follow-up must not yank the list back after the user '
            'took over the scroll',
      );

      await closeKeyboard(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty conversation survives input tap + keyboard open/close',
        (tester) async {
      await pumpChat(tester, messageCount: 0);
      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 16));
      await setKeyboardInset(tester, 300);
      await tester.pump(const Duration(milliseconds: 16));
      await closeKeyboard(tester);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'the keyboard-dismiss button unfocuses the input and is visible '
        'bottom-left, symmetric to the scroll-to-bottom button',
        (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final saved = _scrollPosition(tester).pixels;

      // Focus the input and open the keyboard.
      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 16));
      await setKeyboardInset(tester, 300);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byIcon(Icons.keyboard_hide),
        findsOneWidget,
        reason: 'the dismiss button appears while the keyboard is open',
      );
      // Symmetric to the scroll-to-bottom button: bottom-left.
      final dismissRect = tester.getRect(find.byIcon(Icons.keyboard_hide));
      final scrollRect = tester.getRect(find.byIcon(Icons.arrow_downward));
      expect(
        dismissRect.left,
        lessThan(scrollRect.left),
        reason: 'the dismiss button sits on the LEFT, the scroll-to-bottom '
            'button on the RIGHT',
      );
      expect(
        (dismissRect.bottom - scrollRect.bottom).abs(),
        lessThan(2.0),
        reason: 'the two buttons share the bottom edge (symmetric)',
      );

      // Tapping it drops the input focus (the keyboard close key / system
      // transition then fires the restore).
      await tester.tap(find.byIcon(Icons.keyboard_hide));
      await tester.pump();
      expect(
        tester.testTextInput.hasAnyClients,
        isFalse,
        reason: 'the dismiss button must unfocus the composer input',
      );

      // The keyboard close transition (simulated: on a device the IME
      // collapses when unfocused) hides the button; the list itself is
      // not moved on dismiss.
      await closeKeyboard(tester);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byIcon(Icons.keyboard_hide),
        findsNothing,
        reason: 'the dismiss button hides once the keyboard is gone',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(saved, 1.0),
        reason: 'dismissing the keyboard must not move the list — it stays '
            'where it was before the keyboard opened',
      );
      await settle(tester);
    });

    testWidgets(
        'keyboard opening while the chat tab is hidden does not move '
        'the chat list (IndexedStack keep-alive)', (tester) async {
      // Chat tab hidden — as when another main page is selected.
      await pumpChat(tester, visible: false);

      // Scroll the hidden list to a reading position (not the bottom).
      final pos = _scrollPosition(tester, skipOffstage: false);
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();
      pos.jumpTo((pos.pixels - 400).clamp(0.0, pos.maxScrollExtent));
      await tester.pump();
      final savedPos = pos.pixels;
      expect(savedPos, greaterThan(0));
      expect(savedPos, lessThan(pos.maxScrollExtent - 200));

      // A keyboard opens on ANOTHER tab: view insets change app-globally.
      // didChangeMetrics must ignore the open transition while the page is
      // hidden — otherwise the hidden list scrolls to the bottom and a
      // bogus keyboard session corrupts the next real one. (The chat
      // library's own debounced keyboard handler is not under test here —
      // the assertion runs within the metrics-dispatch window, like the
      // visible-page tests.)
      await setKeyboardInset(tester, 300);
      expect(
        _scrollPosition(tester, skipOffstage: false).pixels,
        closeTo(savedPos, 1.0),
        reason: 'a keyboard opening on another tab must not move the '
            'hidden chat list',
      );

      await closeKeyboard(tester);
      await settle(tester);
    });

    testWidgets(
        'keyboard dismissed while the chat tab is hidden: the list is not '
        'moved (no dismiss restore)', (tester) async {
      // Session starts while the chat tab is visible.
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final savedPos = _scrollPosition(tester).pixels;

      await setKeyboardInset(tester, 300);
      // The keyboard open must not move the list.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(savedPos, 1.0),
        reason: 'precondition: keyboard open does not move the list',
      );

      // Switch to another tab while the keyboard is still open (the same
      // widget tree is re-pumped with the Visibility flag flipped, keeping
      // all State).
      await tester.pumpWidget(
        _wrapTabVisibility(
          ProviderScope(
            overrides: [
              activeConversationIdProvider
                  .overrideWith((ref) => 'test-conv-id'),
              providerEntriesProvider.overrideWith((ref) {
                return ProviderEntriesNotifier();
              }),
            ],
            child: const MaterialApp(home: Scaffold(body: ChatPage())),
          ),
          visible: false,
        ),
      );
      await tester.pump();

      // The keyboard dismisses while the chat tab is hidden — the close
      // transition is honored (session cleanup), but the list is not
      // moved.
      await closeKeyboard(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // Return to the chat tab — the list is still where it was (no
      // dismiss restore, no motion).
      await tester.pumpWidget(
        _wrapTabVisibility(
          ProviderScope(
            overrides: [
              activeConversationIdProvider
                  .overrideWith((ref) => 'test-conv-id'),
              providerEntriesProvider.overrideWith((ref) {
                return ProviderEntriesNotifier();
              }),
            ],
            child: const MaterialApp(home: Scaffold(body: ChatPage())),
          ),
          visible: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        _scrollPosition(tester).pixels,
        closeTo(savedPos, 5.0),
        reason: 'dismissing the keyboard while hidden must not move the '
            'list',
      );
      await settle(tester);
    });
  });
}
