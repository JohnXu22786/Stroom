// Widget tests for the chat page's scroll-to-bottom button FOLLOW behavior:
// after tapping the button (or while already at the bottom), new streaming
// content must keep the list pinned to the bottom — the same follow the
// reasoning panel's button has. Streaming growth goes through
// `controller.updateMessage`, which the chat library does not auto-scroll
// for, so the page must react to scroll METRICS changes, not just scroll
// events.
//
// Behaviors protected:
//  1. While at the bottom, a growing streaming message keeps the list
//     pinned to the bottom (no silent drift) — repro test.
//  2. Tapping the scroll-to-bottom button re-engages following: the jump
//     converges on the true bottom even when the sliver's extent estimate
//     lands it short, and subsequent stream growth stays followed — repro
//     test.
//  3. Stream growth during the keyboard-dismiss restore never yanks the
//     list away from the restore target — guard test for the restore
//     interaction.
//  4. A small scroll-up within the at-bottom window is not undone by the
//     follow logic; growth within the window still re-pins — guard test
//     for the extent gate.
//  5. A viewport-only change (window resize) never moves the scroll
//     offset — guard test for the content-extent gate.
//  6. Growth after the content shrank re-pins the list (the gate re-arms
//     on shrink instead of suppressing the follow) — guard test for the
//     last-observed-extent record.
//  7. Growth while the user is scrolled up (button visible) never yanks
//     the list back to the bottom — guard test for the follow gate.
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';

import 'chat_page_test.dart' show createChatTestApp;

const _convId = 'test-conv-id';
const _streamMsgId = 's1';

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

/// Pumps a ChatPage with a conversation pre-populated with [messageCount]
/// messages and waits for the initial scroll pass to settle.
Future<ProviderContainer> pumpChat(
  WidgetTester tester, {
  int messageCount = 40,
}) async {
  final messages = _testMessages(messageCount);
  await tester.pumpWidget(createChatTestApp());
  await tester.pump();

  final ctx = tester.element(find.byType(ChatPage));
  final container = ProviderScope.containerOf(ctx);
  container.read(conversationsProvider.notifier).state = [
    Conversation.fromMap({
      'id': _convId,
      'title': 'Test Conversation',
      'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
      'messages': messages.map((m) => m.toMap()).toList(),
      'isPinned': false,
      'sortOrder': 0,
    }),
  ];
  // The conversations listener reloads the page in a post-frame; the initial
  // scroll pass then takes a few more frames (each step consumes one frame).
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  // Flush the chat library's one-shot timers (scroll-to-bottom show timer,
  // visibility re-checks) so the end-of-test pending-timer check passes.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return container;
}

/// The chat list's scroll position: the page's only Scrollable whose
/// viewport is taller than 100 logical pixels.
ScrollPosition _chatPosition(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(ChatPage),
    matching: find.byType(Scrollable),
    skipOffstage: false,
  );
  for (final e in finder.evaluate()) {
    final controller = (e.widget as Scrollable).controller;
    if (controller != null &&
        controller.hasClients &&
        controller.position.viewportDimension > 100) {
      return controller.position;
    }
  }
  throw StateError('chat list scroll position not found');
}

/// Scrolls the chat list to the bottom. Uses the scroll position directly
/// (a drag gesture is unreliable here because message bubbles intercept
/// the pointer), which notifies the same listeners a real scroll would.
Future<void> scrollToBottom(WidgetTester tester) async {
  final pos = _chatPosition(tester);
  pos.jumpTo(pos.maxScrollExtent);
  await tester.pump();
}

/// Scrolls up (toward older messages) by [amount] logical pixels.
Future<void> scrollUp(WidgetTester tester, {double amount = 400}) async {
  final pos = _chatPosition(tester);
  pos.jumpTo((pos.pixels - amount).clamp(0.0, pos.maxScrollExtent));
  await tester.pump();
}

/// Inserts the streaming placeholder message into the chat controller the
/// same way `_startStreaming` does, and registers its streaming msg id so
/// the page's full-reply listener drives subsequent updates.
Future<void> startStreaming(WidgetTester tester) async {
  final ctx = tester.element(find.byType(ChatPage));
  final container = ProviderScope.containerOf(ctx);
  container.read(streamingMsgIdProvider(_convId).notifier).state = _streamMsgId;
  final chat = tester.widget<Chat>(find.byType(Chat));
  final controller = chat.chatController as InMemoryChatController;
  await controller.insertMessage(
    Message.textStream(
      id: _streamMsgId,
      authorId: 'ai1',
      createdAt: DateTime(2025, 1, 1),
      streamId: _streamMsgId,
    ),
  );
  await tester.pump();
  // Let the library's post-frame scroll-to-end run.
  await tester.pump(const Duration(milliseconds: 100));
}

/// Appends a streaming chunk the way ChatStreamManager does: the
/// full-reply provider listener updates the controller message and
/// rebuilds the page.
void streamChunk(ProviderContainer container, String text) {
  container.read(streamingFullReplyProvider(_convId).notifier).state = text;
}

/// True when the chat list sits at (or within [tolerance] of) the bottom.
/// Uses the absolute distance so an overshot position does not count.
bool _isAtBottom(WidgetTester tester, {double tolerance = 10}) {
  final pos = _chatPosition(tester);
  return (pos.maxScrollExtent - pos.pixels).abs() <= tolerance;
}

/// Pumps frames until [condition] holds or [maxFrames] is exhausted.
/// The follow logic converges over several frames (each step builds one
/// more viewport of the sliver's previously unbuilt tail), so assertions
/// must not assume a fixed frame budget — first-run warm-up (font and
/// markdown parsing) can stretch the per-frame work.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxFrames = 40,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (condition()) return;
  }
}

void main() {
  setUp(() {
    // Markdown rendering wraps blocks in VisibilityDetector; its default
    // 500ms debounce timer would remain pending at test teardown.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  group('ChatPage scroll-to-bottom follow', () {
    testWidgets(
        'while at the bottom, a growing streaming message keeps the list '
        'pinned to the bottom', (tester) async {
      final container = await pumpChat(tester);
      await scrollToBottom(tester);
      await startStreaming(tester);
      await scrollToBottom(tester);

      final before = _chatPosition(tester);
      expect(
        before.maxScrollExtent - before.pixels,
        lessThanOrEqualTo(10),
        reason: 'precondition: the list is at the bottom',
      );

      // The stream continues: the streaming message grows by thousands of
      // pixels (content growth, not a new message — no scroll event fires).
      streamChunk(container, 'A' * 3000);
      await tester.pump(); // listener -> updateMessage -> setState
      // The follow is a post-frame jump on the next metrics notification.
      await pumpUntil(tester, () => _isAtBottom(tester));

      final after = _chatPosition(tester);
      expect(
        after.maxScrollExtent - after.pixels,
        lessThanOrEqualTo(10),
        reason: 'the list must follow the growing message instead of '
            'drifting away from the bottom',
      );
      // Flush one-shot timers before teardown.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets(
        'tapping the scroll-to-bottom button re-engages following: the '
        'growing stream stays pinned to the bottom after the tap',
        (tester) async {
      final container = await pumpChat(tester);
      await scrollToBottom(tester);
      await startStreaming(tester);
      await scrollToBottom(tester);

      // The user scrolls up to read history — the button appears and
      // following stops.
      await scrollUp(tester);
      expect(
        find.byIcon(Icons.arrow_downward),
        findsOneWidget,
        reason: 'precondition: scrolling up shows the scroll-to-bottom '
            'button',
      );

      // The stream keeps growing while the user reads — no follow.
      streamChunk(container, 'B' * 2000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final drifted = _chatPosition(tester);
      expect(
        drifted.maxScrollExtent - drifted.pixels,
        greaterThan(100),
        reason: 'precondition: while scrolled up the list does not follow',
      );

      // Tap the button: the list jumps to the bottom and must then keep
      // following subsequent growth (the reasoning-panel behavior). When
      // the tail is not built yet, the sliver's extent estimate lands the
      // jump short; the follow logic must then converge to the true bottom
      // over the next few frames.
      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: 'the button hides after the tap');
      await pumpUntil(tester, () => _isAtBottom(tester));
      final tapped = _chatPosition(tester);
      expect(
        tapped.maxScrollExtent - tapped.pixels,
        lessThanOrEqualTo(10),
        reason: 'tapping the button scrolls to the bottom',
      );

      streamChunk(container, 'B' * 2000 + 'C' * 3000);
      await tester.pump();
      await pumpUntil(tester, () => _isAtBottom(tester));

      final followed = _chatPosition(tester);
      expect(
        followed.maxScrollExtent - followed.pixels,
        lessThanOrEqualTo(10),
        reason: 'after the tap the list must keep following the stream',
      );
      // Flush one-shot timers before teardown.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets(
        'stream growth during the keyboard-dismiss restore never yanks '
        'the list away from the restore target', (tester) async {
      final container = await pumpChat(tester);
      await scrollToBottom(tester);
      await startStreaming(tester);
      await scrollToBottom(tester);

      // Open the keyboard while scrolled up: the list scrolls to the
      // bottom and auto-scroll engages. The scroll is a 200ms animation
      // plus a 600ms follow-up (the per-frame keyboard pinning this
      // superseded was reverted), so let it land before the precondition.
      await scrollUp(tester);
      final savedPos = _chatPosition(tester).pixels;
      expect(savedPos, greaterThan(0));
      await setKeyboardInset(tester, 300);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      var pos = _chatPosition(tester);
      expect(
        pos.maxScrollExtent - pos.pixels,
        lessThanOrEqualTo(60),
        reason: 'precondition: keyboard open lands at/near the bottom',
      );

      // Dismiss the keyboard: the restore is a single jump (the animated
      // 150ms restore belonged to the reverted keyboard pinning), so it
      // completes within a frame.
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.viewInsets = FakeViewPadding.zero;
      await _dispatchMetrics(tester);
      await tester.pump(const Duration(milliseconds: 16));

      // The stream grows right after the restore — the list must stay at
      // the saved position, not snap back to the bottom.
      streamChunk(container, 'E' * 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final restored = _chatPosition(tester);
      expect(
        restored.pixels,
        closeTo(savedPos, 10.0),
        reason: 'the keyboard-dismiss restore wins over stream growth; '
            'the list must not be yanked to the bottom',
      );
      // Flush one-shot timers before teardown.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets(
        'a small scroll-up within the at-bottom window is not undone by '
        'the follow logic; growth within the window still re-pins',
        (tester) async {
      final container = await pumpChat(tester);
      await scrollToBottom(tester);
      await startStreaming(tester);
      await scrollToBottom(tester);

      // Small scroll up: 40px — still inside the 80px "at bottom" window
      // (_onChatScroll keeps auto-scroll engaged there).
      final pos = _chatPosition(tester);
      pos.jumpTo(pos.maxScrollExtent - 40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        _chatPosition(tester).maxScrollExtent - _chatPosition(tester).pixels,
        closeTo(40, 5),
        reason: 'a plain scroll (no content growth) must not be undone by '
            'the follow logic, even inside the at-bottom window',
      );

      // Growth while the user rests within the window re-pins to the
      // bottom — following is still engaged.
      streamChunk(container, 'F' * 3000);
      await tester.pump();
      await pumpUntil(tester, () => _isAtBottom(tester));

      expect(
        _chatPosition(tester).maxScrollExtent - _chatPosition(tester).pixels,
        lessThanOrEqualTo(10),
        reason: 'growth inside the at-bottom window snaps to the bottom',
      );
      // Flush one-shot timers before teardown.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets(
        'a viewport-only change (window resize) never yanks a reader '
        'resting within the at-bottom window', (tester) async {
      await pumpChat(tester);
      await scrollToBottom(tester);
      await startStreaming(tester);
      await scrollToBottom(tester);

      // Rest 40px above the bottom (within the 80px window — auto-scroll
      // stays engaged there).
      final pos = _chatPosition(tester);
      pos.jumpTo(pos.maxScrollExtent - 40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final restPixels = _chatPosition(tester).pixels;

      // The window shrinks: the chat viewport becomes shorter but the
      // message content itself does not grow (no stream chunk).
      const dpr = 3.0;
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = const Size(2400, 1350);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        _chatPosition(tester).pixels,
        closeTo(restPixels, 1.0),
        reason: 'a viewport-only change must not move the scroll offset',
      );
      // Flush one-shot timers before teardown.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets(
        'after the content shrank, growth re-pins the list (the extent '
        'record re-arms instead of suppressing the follow)', (tester) async {
      final container = await pumpChat(tester);
      await scrollToBottom(tester);
      await startStreaming(tester);
      await scrollToBottom(tester);

      // Stream grows to a large extent.
      streamChunk(container, 'A' * 5000);
      await tester.pump();
      await pumpUntil(tester, () => _isAtBottom(tester));
      expect(_isAtBottom(tester), isTrue,
          reason: 'precondition: following a large stream');

      // The content shrinks (e.g. an edit truncating the reply) while the
      // user is scrolled up — no out-of-range correction is triggered.
      await scrollUp(tester);
      streamChunk(container, 'A' * 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // Back at the bottom, auto-scroll re-engages.
      await scrollToBottom(tester);
      await pumpUntil(tester, () => _isAtBottom(tester));
      expect(_isAtBottom(tester), isTrue,
          reason: 'precondition: back at the bottom after the shrink');

      // Growth returns but stays BELOW the pre-shrink extent — the follow
      // must still re-pin (a high-water record would suppress it here).
      streamChunk(container, 'A' * 3000);
      await tester.pump();
      await pumpUntil(tester, () => _isAtBottom(tester));

      expect(
        _isAtBottom(tester),
        isTrue,
        reason: 'growth after a shrink must re-pin the list to the bottom',
      );
      // Flush one-shot timers before teardown.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets(
        'growth while the user is scrolled up never yanks the list back '
        'to the bottom', (tester) async {
      final container = await pumpChat(tester);
      await scrollToBottom(tester);
      await startStreaming(tester);
      await scrollToBottom(tester);

      await scrollUp(tester);
      final before = _chatPosition(tester);
      expect(
        before.maxScrollExtent - before.pixels,
        greaterThan(100),
        reason: 'precondition: the user is scrolled up',
      );
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      streamChunk(container, 'D' * 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final after = _chatPosition(tester);
      expect(
        after.pixels,
        closeTo(before.pixels, 1.0),
        reason: 'a scrolled-up reader must not be yanked by stream growth',
      );
      expect(
        find.byIcon(Icons.arrow_downward),
        findsOneWidget,
        reason: 'the button stays visible while scrolled up',
      );
      // Flush one-shot timers before teardown.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });
  });
}

/// Dispatches the view-metrics change to `didChangeMetrics` observers
/// synchronously (the test binding otherwise defers it), then lets the tree
/// rebuild so `MediaQuery` reflects the new insets, then dispatches once
/// more — `didChangeMetrics` reads the inherited `MediaQuery` which is one
/// frame behind the view, so the second dispatch is the one that carries
/// the fresh inset to the page logic. Same pattern as the keyboard scroll
/// tests.
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
/// bottom of the window: the window (and therefore the chat area) shrinks
/// and the view insets update. Pumps enough frames for the metrics events
/// to be delivered and the per-frame pinning to converge.
Future<void> setKeyboardInset(WidgetTester tester, double inset) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(800.0 * dpr, (600.0 - inset) * dpr);
  tester.view.viewInsets = FakeViewPadding(bottom: inset * dpr);
  await _dispatchMetrics(tester);
}
