import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';

import 'chat_page_test.dart' show createChatTestApp;

/// Load-more indicator key — the widget must not exist in the tree at all
/// while no pagination load is running (an indeterminate
/// CircularProgressIndicator keeps animating as long as it is mounted).
const loadMoreIndicatorKey = ValueKey('chat-load-more-indicator');

const noMoreMessagesText = '没有更多内容了';

List<ChatMessage> _msgs(int count) {
  return [
    for (var i = 0; i < count; i++)
      ChatMessage(
        id: 'm$i',
        role: i.isEven ? 'user' : 'assistant',
        content: 'Message $i content',
        createdAt: DateTime(2025, 1, 1).add(Duration(hours: i)),
      ),
  ];
}

/// Pumps the chat page with a conversation of [messageCount] messages and
/// settles the initial positioning pass.
Future<ProviderContainer> pumpConversation(
  WidgetTester tester, {
  required int messageCount,
}) async {
  await tester.pumpWidget(createChatTestApp());
  await tester.pump();

  final ctx = tester.element(find.byType(ChatPage));
  final container = ProviderScope.containerOf(ctx);
  container.read(conversationsProvider.notifier).state = [
    Conversation.fromMap({
      'id': 'test-conv-id',
      'title': 'Test Conversation',
      'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
      'messages': _msgs(messageCount).map((m) => m.toMap()).toList(),
      'isPinned': false,
      'sortOrder': 0,
    }),
  ];
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return container;
}

/// Drags the chat list far down so it reaches the very top (which triggers
/// the library's onEndReached / load-more path). Two pumps are needed: the
/// library's scroll anchoring awaits a layout pass before it calls
/// onEndReached, so the load (and its indicator) only materialize one frame
/// after the drag.
Future<void> dragToTop(WidgetTester tester) async {
  await tester.drag(find.byType(ChatPage), const Offset(0, 6000));
  await tester.pump();
  await tester.pump();
}

/// Lets the library's post-pagination scroll anchoring converge: it jumps
/// to the anchor message, then corrects the offset over the next few frames
/// as the sliver's extent estimate settles. Without these frames the
/// correction can still be running when the next drag starts.
Future<void> settleAnchor(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
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

  group('ChatPage load-more indicator', () {
    testWidgets(
        'spinner exists only while actually loading and is removed from the '
        'tree when the load ends', (tester) async {
      await pumpConversation(tester, messageCount: 35);

      // Idle: the indicator must not be in the widget tree at all, so its
      // animation cannot run while it is not displayed.
      expect(find.byKey(loadMoreIndicatorKey), findsNothing,
          reason: 'no pagination load running -> no spinner in the tree');

      // Scroll to the top: the first page of older messages loads.
      await dragToTop(tester);
      expect(find.byKey(loadMoreIndicatorKey), findsOneWidget,
          reason: 'spinner must show while the older-messages load runs');

      // The load itself is instantaneous; only the minimum display window
      // keeps the spinner alive. It must still be up 250ms later...
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(loadMoreIndicatorKey), findsOneWidget,
          reason: 'spinner must stay visible at least 500ms after the '
              'load finished');

      // ...and must be gone once the minimum display window has passed.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(loadMoreIndicatorKey), findsNothing,
          reason: 'spinner is removed from the tree when the load ends');
      final chat = tester.widget<Chat>(find.byType(Chat));
      expect(chat.chatController.messages.length, 35,
          reason: 'the older-messages page was inserted after the '
              'minimum display window');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'no-more-content hint appears only after reaching the top with '
        'nothing left to load', (tester) async {
      await pumpConversation(tester, messageCount: 35);

      // First pass to the top: a page of older messages is still available,
      // so the hint must not appear.
      await dragToTop(tester);
      await tester.pump(const Duration(milliseconds: 600));
      // Let the library's anchor scroll corrections settle before the next
      // drag (the fake clock skips the 500ms minimum display in one frame,
      // so those frame-based corrections have not run yet).
      await settleAnchor(tester);
      expect(find.text(noMoreMessagesText), findsNothing,
          reason: 'no hint while older pages remain');

      // Second pass to the top: everything is loaded now, so the hint
      // appears above the first message.
      await dragToTop(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(noMoreMessagesText), findsOneWidget,
          reason: 'hint appears at the top when there is no more content');

      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
        'no hint while scrolling mid-list in a fully loaded conversation',
        (tester) async {
      // 15 messages < one page: everything is loaded, but the content is
      // tall enough to scroll.
      await pumpConversation(tester, messageCount: 15);

      // A short upward drag that stays mid-list must not arm the hint
      // (the UserScrollNotification path is gated on being near the top).
      await tester.drag(find.byType(ChatPage), const Offset(0, 100));
      await tester.pump();
      await tester.pump();
      expect(find.text(noMoreMessagesText), findsNothing,
          reason: 'mid-list upward drag must not show the hint');

      // Reaching the actual top does.
      await tester.drag(find.byType(ChatPage), const Offset(0, 6000));
      await tester.pump();
      await tester.pump();
      expect(find.text(noMoreMessagesText), findsOneWidget,
          reason: 'reaching the top of a fully loaded conversation shows '
              'the hint');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'short conversation: no hint on entry; hint appears only after '
        'the user pulls at the top', (tester) async {
      // Fewer messages than one page: everything is loaded from the start,
      // so reaching the top means "no more content" — but only after the
      // user actually reaches it, not on entry.
      await pumpConversation(tester, messageCount: 5);
      expect(find.text(noMoreMessagesText), findsNothing,
          reason: 'no hint on entry, before any user scroll');

      // The list cannot scroll (all content fits), so the user's pull at
      // the top produces no pixel change — the UserScrollNotification path
      // must surface the hint.
      await tester.drag(find.byType(ChatPage), const Offset(0, 200));
      await tester.pump();
      await tester.pump();
      expect(find.text(noMoreMessagesText), findsOneWidget,
          reason: 'pull at the top of a fully-loaded conversation shows '
              'the hint');

      await tester.pumpWidget(const SizedBox());
    });
  });
}
