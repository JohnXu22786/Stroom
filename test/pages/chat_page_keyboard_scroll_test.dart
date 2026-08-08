// Widget tests for the chat page's soft-keyboard scroll behavior.
//
// Behaviors protected:
//  1. Tapping the composer input while scrolled up immediately jumps to the
//     bottom — before any keyboard metrics change arrives (the "shift up
//     must start the moment the user taps" requirement).
//  2. Opening the keyboard while scrolled up saves the position and jumps
//     to the bottom; dismissing it scrolls back to the saved position with
//     an animation (not an instant teleport after the keyboard is gone).
//  3. While the keyboard is open and the list is at the bottom, continuing
//     viewport shrink (the keyboard animation) keeps the list pinned to
//     the new bottom instead of drifting.
//  4. Dismissing the keyboard while at the bottom leaves the list at the
//     bottom of the restored viewport.
//  5. The bottom-pinning never yanks the list back when the user scrolls
//     up manually while the keyboard is open.
//  6. An empty conversation survives input tap + keyboard open/close.
//  7. With HomePage's IndexedStack keep-alive, the page stays mounted while
//     another main page is shown: a keyboard that opens on ANOTHER tab must
//     not hijack the hidden chat list (the open transition is gated by
//     Visibility.of), while a keyboard dismissed while hidden must still
//     restore the reading position.
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

/// Builds the chat-page app (ProviderScope + MaterialApp + ChatPage).
Widget _buildChatApp() {
  return ProviderScope(
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
    child: const MaterialApp(home: ChatPage()),
  );
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

/// Post-pump common setup: consume flutter_chat_ui's pre-existing framework
/// exceptions and neutralize the visibility_detector polling interval so no
/// timers are left pending at the end of the test.
void _postPumpSetup(WidgetTester tester) {
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

/// Pumps a ChatPage with a conversation pre-populated with [messages].
/// When [visible] is false the page is kept alive but hidden, as it would
/// be while another main page is selected (IndexedStack keep-alive).
Future<void> pumpChat(
  WidgetTester tester, {
  int messageCount = 60,
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
  await tester
      .pumpWidget(_wrapTabVisibility(_buildChatApp(), visible: visible));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // Let the chat list fully initialize (delayed insert/scroll timers from
  // flutter_chat_ui) so scroll positions are stable for the assertions.
  await settle(tester);
  _postPumpSetup(tester);
}

/// The chat list's scrollable (inside the ChatAnimatedList).
Finder _chatScrollable({bool skipOffstage = true}) {
  return find
      .descendant(
        of: find.byType(ChatAnimatedList, skipOffstage: skipOffstage),
        matching: find.byType(Scrollable, skipOffstage: skipOffstage),
      )
      .first;
}

ScrollPosition _scrollPosition(
  WidgetTester tester, {
  bool skipOffstage = true,
}) {
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

/// Dispatches the view-metrics change to `didChangeMetrics` observers
/// synchronously (the test binding otherwise defers it), then lets the tree
/// rebuild so `MediaQuery` reflects the new insets, then dispatches once
/// more — `didChangeMetrics` reads the inherited `MediaQuery` which is one
/// frame behind the view, so the second dispatch is the one that carries
/// the fresh inset to the page logic.
Future<void> _dispatchMetrics(WidgetTester tester) async {
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  tester.binding.handleMetricsChanged();
  await tester.pump(const Duration(milliseconds: 16));
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  tester.binding.handleMetricsChanged();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

/// Simulates the soft keyboard occupying [inset] logical pixels at the
/// bottom of the window: both the window (and therefore the chat area)
/// shrinks — mirroring `adjustResize` — and the view insets update.
///
/// Pumps enough frames for the metrics events to be delivered and the
/// per-frame pinning to converge.
Future<void> setKeyboardInset(WidgetTester tester, double inset) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(800.0 * dpr, (600.0 - inset) * dpr);
  tester.view.viewInsets = FakeViewPadding(bottom: inset * dpr);
  await _dispatchMetrics(tester);
}

void main() {
  group('ChatPage keyboard scroll', () {
    testWidgets(
        'tapping the composer input while scrolled up jumps to the bottom '
        'immediately (before any keyboard metrics change)', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      expect(
        _scrollPosition(tester).pixels,
        lessThan(_scrollPosition(tester).maxScrollExtent - 200),
        reason: 'precondition: the list is scrolled up',
      );

      // Just tap the input; no keyboard metrics have changed yet.
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final pos = _scrollPosition(tester);
      expect(
        pos.pixels,
        closeTo(pos.maxScrollExtent, 10.0),
        reason: 'the list must shift up the moment the input is tapped '
            '(small tolerance for the scrollbar appearing after the jump)',
      );
      await settle(tester);
    });

    testWidgets(
        'keyboard open while scrolled up jumps to bottom; dismiss animates '
        'back to the saved position instead of teleporting', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final savedPos = _scrollPosition(tester).pixels;
      expect(savedPos, greaterThan(0));

      // Keyboard opens — the list jumps to the bottom.
      await setKeyboardInset(tester, 300);
      final openPos = _scrollPosition(tester);
      expect(
        openPos.pixels,
        closeTo(openPos.maxScrollExtent, 5.0),
        reason: 'opening the keyboard shows the latest messages '
            '(small tolerance for the scrollbar settling the viewport)',
      );

      // Keyboard dismisses — the list must scroll back smoothly.
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.viewInsets = FakeViewPadding.zero;
      await _dispatchMetrics(tester); // close transition + restore starts
      await tester.pump(const Duration(milliseconds: 100)); // mid-animation

      final midPos = _scrollPosition(tester).pixels;
      expect(
        midPos,
        greaterThan(savedPos),
        reason: 'the restore must be an animation, not an instant teleport',
      );
      expect(
        midPos,
        lessThan(_scrollPosition(tester).maxScrollExtent - 50),
        reason: 'mid-animation it must not already be at the bottom',
      );

      await tester.pump(const Duration(milliseconds: 300)); // finish
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _scrollPosition(tester).pixels,
        closeTo(savedPos, 1.0),
        reason: 'dismissing the keyboard returns to the saved position',
      );
      await settle(tester);
    });

    testWidgets(
        're-tapping the input while the dismiss restore is still animating '
        'must keep the original pre-keyboard position for the next session',
        (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final savedPos = _scrollPosition(tester).pixels;
      expect(savedPos, greaterThan(0));

      // Session 1: tap the input (saves [savedPos]) and open the keyboard.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await setKeyboardInset(tester, 300);
      expect(
        _scrollPosition(tester).pixels,
        closeTo(_scrollPosition(tester).maxScrollExtent, 5.0),
      );

      // Dismiss — the restore animation starts (150ms).
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.viewInsets = FakeViewPadding.zero;
      await _dispatchMetrics(tester);

      // Mid-restore, the user re-taps the input (unfocus first — the field
      // still holds focus from session 1).
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Session 2: keyboard reopens and closes again.
      await setKeyboardInset(tester, 300);
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.viewInsets = FakeViewPadding.zero;
      await _dispatchMetrics(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        _scrollPosition(tester).pixels,
        closeTo(savedPos, 5.0),
        reason: 'session 2 must restore to the ORIGINAL pre-keyboard '
            'position, not a mid-animation offset',
      );
      await settle(tester);
    });

    testWidgets(
        'reopening the keyboard on a still-focused field after a completed '
        'restore re-saves the current position (Android back-button flow)',
        (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final firstSavedPos = _scrollPosition(tester).pixels;
      expect(firstSavedPos, greaterThan(0));

      // Session 1: tap the input and open/close the keyboard; the restore
      // runs to completion (the field keeps focus the whole time).
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await setKeyboardInset(tester, 300);
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.viewInsets = FakeViewPadding.zero;
      await _dispatchMetrics(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // The user scrolls elsewhere; the field is STILL focused (Android
      // back button hides the IME without unfocusing), so re-opening the
      // keyboard never fires the focus hook.
      final pos = _scrollPosition(tester);
      final secondPos = (pos.pixels - 200).clamp(0.0, pos.maxScrollExtent);
      pos.jumpTo(secondPos);
      await tester.pump();
      expect(
        _scrollPosition(tester).pixels,
        closeTo(secondPos, 1.0),
        reason: 'precondition: the user scrolled to a new position',
      );

      // Session 2: the keyboard reopens (no tap, no focus change) and
      // closes again.
      await setKeyboardInset(tester, 300);
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.viewInsets = FakeViewPadding.zero;
      await _dispatchMetrics(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        _scrollPosition(tester).pixels,
        closeTo(secondPos, 5.0),
        reason: 'the second session must restore to the position the user '
            'is at now, not the stale position of the first session',
      );
      expect(
          _scrollPosition(tester).pixels, isNot(closeTo(firstSavedPos, 5.0)));
      await settle(tester);
    });

    testWidgets(
        'losing focus without a keyboard (phantom session) releases the '
        'pin but keeps the saved pre-tap position', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final savedPos = _scrollPosition(tester).pixels;
      expect(savedPos, greaterThan(0));

      // Phantom tap: focus is gained, but the keyboard never appears.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        _scrollPosition(tester).pixels,
        closeTo(_scrollPosition(tester).maxScrollExtent, 10.0),
      );

      // Focus is lost while the keyboard is still hidden — the phantom
      // session is abandoned (pin released), the saved position kept.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // A keyboard session now happens without any focus event (metrics
      // only) and closes again.
      await setKeyboardInset(tester, 300);
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.viewInsets = FakeViewPadding.zero;
      await _dispatchMetrics(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        _scrollPosition(tester).pixels,
        closeTo(savedPos, 5.0),
        reason: 'the dismiss restores to the position captured at the tap, '
            'not the bottom',
      );
      await settle(tester);
    });

    testWidgets(
        'while the keyboard is open and the list is at the bottom, further '
        'viewport shrink keeps the list pinned to the new bottom (no drift)',
        (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);

      await setKeyboardInset(tester, 300);
      var pos = _scrollPosition(tester);
      expect(pos.pixels, closeTo(pos.maxScrollExtent, 1.0));

      // The keyboard animation continues: the viewport shrinks further.
      // (Insets are capped so the window never gets too small for the
      // page's fixed header/composer — a pre-existing layout limitation.)
      await setKeyboardInset(tester, 350);
      pos = _scrollPosition(tester);
      expect(
        pos.pixels,
        closeTo(pos.maxScrollExtent, 1.0),
        reason: 'the list must follow the shrinking viewport, not drift',
      );

      // The keyboard starts closing: the viewport grows back — the list
      // must follow down. An idle scroll position is range-clamped by the
      // framework when the viewport grows, and the pinning re-establishes
      // the exact bottom; this assertion guards the combined behavior.
      await setKeyboardInset(tester, 300);
      pos = _scrollPosition(tester);
      expect(
        pos.pixels,
        closeTo(pos.maxScrollExtent, 1.0),
        reason: 'the list sits at the bottom once the keyboard closes',
      );
      await settle(tester);
    });

    testWidgets(
        'dismissing the keyboard while at the bottom leaves the '
        'list at the bottom of the restored viewport', (tester) async {
      // Guard test: the close direction must never strand the list mid-way
      // (an idle position is range-clamped as the viewport grows, and the
      // restore animation must not overshoot or skip).
      await pumpChat(tester);
      await scrollToBottom(tester);

      await setKeyboardInset(tester, 300);
      await setKeyboardInset(tester, 0);
      await tester.pump(const Duration(milliseconds: 300)); // finish restore

      final pos = _scrollPosition(tester);
      expect(
        pos.pixels,
        closeTo(pos.maxScrollExtent, 25.0),
        reason: 'after the keyboard closes the list sits at the bottom '
            '(small tolerance for the scrollbar toggling the viewport)',
      );
      await settle(tester);
    });

    testWidgets(
        'manual scroll-up while the keyboard is open is never '
        'overridden by the bottom pinning', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await setKeyboardInset(tester, 300);
      expect(
        _scrollPosition(tester).pixels,
        closeTo(_scrollPosition(tester).maxScrollExtent, 1.0),
      );

      // User scrolls up to read history while the keyboard is open. A real
      // drag gesture is used so the page sees a user-initiated scroll
      // (ScrollDragController), which is what stops the bottom pinning.
      // (x=2 avoids message bubbles; y must be inside the chat area, below
      // the 48px top bar.)
      final gesture = await tester.startGesture(const Offset(2, 100));
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      final userPos = _scrollPosition(tester).pixels;
      expect(
        userPos,
        lessThan(_scrollPosition(tester).maxScrollExtent - 50),
        reason: 'precondition: the user scrolled up',
      );

      // The keyboard animation continues — the list must not be yanked back.
      // (Note: the chat library's own keyboard handler fires ~100ms after
      // the metrics change and can yank a scrolled-up list to the bottom;
      // that pre-existing library behavior is out of scope here — the
      // assertion runs before its debounce fires.)
      await setKeyboardInset(tester, 350);
      expect(
        _scrollPosition(tester).pixels,
        closeTo(userPos, 1.0),
        reason: 'the pinning must not fight the user\'s scroll position',
      );
      await settle(tester);
    });

    testWidgets(
        'empty conversation survives input tap and keyboard '
        'open/close without errors', (tester) async {
      await pumpChat(tester, messageCount: 0);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await setKeyboardInset(tester, 300);
      await setKeyboardInset(tester, 0);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
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
      // hidden — otherwise the hidden list jumps to the bottom and a bogus
      // keyboard session corrupts the next real one. (The chat library's
      // own debounced keyboard handler is not under test here — the
      // assertion runs within the metrics-dispatch window, like the
      // visible-page tests.)
      await setKeyboardInset(tester, 300);
      expect(
        _scrollPosition(tester, skipOffstage: false).pixels,
        closeTo(savedPos, 1.0),
        reason: 'a keyboard opening on another tab must not move the '
            'hidden chat list',
      );

      await setKeyboardInset(tester, 0);
      await settle(tester);
    });

    testWidgets(
        'keyboard dismissed while the chat tab is hidden still restores '
        'the reading position', (tester) async {
      // Session starts while the chat tab is visible.
      await pumpChat(tester);
      await scrollToBottom(tester);
      await scrollUp(tester);
      final savedPos = _scrollPosition(tester).pixels;
      expect(savedPos, greaterThan(0));

      await setKeyboardInset(tester, 300);
      expect(
        _scrollPosition(tester).pixels,
        closeTo(_scrollPosition(tester).maxScrollExtent, 5.0),
        reason: 'precondition: keyboard open on the visible chat tab '
            'pins the list to the bottom',
      );

      // Switch to another tab while the keyboard is still open (the same
      // widget tree is re-pumped with the Visibility flag flipped, keeping
      // all State).
      await tester
          .pumpWidget(_wrapTabVisibility(_buildChatApp(), visible: false));
      await tester.pump();

      // The keyboard dismisses while the chat tab is hidden — only the
      // OPEN transition is gated; the close must still restore the saved
      // reading position.
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.viewInsets = FakeViewPadding.zero;
      await _dispatchMetrics(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // Return to the chat tab — the list is back at the reading position.
      await tester
          .pumpWidget(_wrapTabVisibility(_buildChatApp(), visible: true));
      await tester.pump();

      expect(
        _scrollPosition(tester).pixels,
        closeTo(savedPos, 5.0),
        reason: 'dismissing the keyboard while hidden must still restore '
            'the reading position captured before the session',
      );
      await settle(tester);
    });
  });
}
