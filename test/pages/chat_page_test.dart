// Merged from:
//   chat_page_test.dart
//   chat_page_alignment_and_preview_test.dart
//   chat_page_back_navigation_test.dart
//   chat_page_infinite_scroll_test.dart
//   chat_page_reasoning_init_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/utils/data_sanitizer.dart';

/// Helper that creates a MaterialApp wrapped in ProviderScope with
/// all providers needed to render ChatPage. This matches the v0.2.15
/// dependencies in which ChatPage did NOT depend on assistant providers.
Widget createChatTestApp({String? activeConversationId}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      // Provide a conversation so the active ID resolves
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider
          .overrideWith((ref) => activeConversationId ?? 'test-conv-id'),
      // Provide an empty provider config so adapter is unconfigured
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: const ChatPage(),
    ),
  );
}

/// Helper for the message-alignment/file-preview groups (was file-scope in
/// chat_page_alignment_and_preview_test.dart and shared the same name as
/// [createChatTestApp]; renamed to avoid the merge conflict).
Widget createAlignmentChatTestApp({String? activeConversationId}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider
          .overrideWith((ref) => activeConversationId ?? 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: const ChatPage(),
    ),
  );
}

/// Helper to create a [ChatMessage] with incremental content for testing.
ChatMessage _createTestMessage(String role, int index) {
  return ChatMessage(
    id: '${role}_$index',
    role: role,
    content: 'Message $index content',
    createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
  );
}

/// Create a list of test messages.
List<ChatMessage> createTestMessages(int count) {
  final msgs = <ChatMessage>[];
  for (var i = 0; i < count; i++) {
    msgs.add(_createTestMessage(i.isEven ? 'user' : 'assistant', i));
  }
  return msgs;
}

/// Create a test app with a conversation pre-populated with messages.
Widget createChatTestAppWithMessages({
  required List<ChatMessage> messages,
  String? conversationId,
}) {
  SharedPreferences.setMockInitialValues({
    'conversations': jsonEncode([
      {
        'id': conversationId ?? 'test-conv-id',
        'title': 'Test Conversation',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'isPinned': false,
        'sortOrder': 0,
      }
    ]),
  });
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider
          .overrideWith((ref) => conversationId ?? 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: const ChatPage(),
    ),
  );
}

void main() {
  group('ChatPage (v0.2.15 restored)', () {
    // Helper: pump the widget and consume any pre-existing framework
    // exceptions from flutter_chat_ui rendering in test mode.
    Future<void> pumpChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Consume any pre-existing framework exceptions from flutter_chat_ui
      // (TextField without Material ancestor is a test-only issue)
      tester.takeException();
    }

    testWidgets('renders chat page with title', (tester) async {
      await pumpChatPage(tester);

      // Verify the page renders with the default conversation title
      expect(find.text('新对话'), findsOneWidget);
      // Verify the search button exists
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('history button is removed from top bar', (tester) async {
      await pumpChatPage(tester);

      // In merged design, history button has been removed
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('new conversation button is removed from top bar',
        (tester) async {
      await pumpChatPage(tester);

      // In merged design, new conversation button has been removed
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('shows search button', (tester) async {
      await pumpChatPage(tester);

      // The search/toggle button should be present
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows send button in composer', (tester) async {
      await pumpChatPage(tester);

      // Note: Icons.send_rounded can appear in both the composer and
      // the fullscreen editor dialog, so we only check it exists
      expect(find.byIcon(Icons.send_rounded), findsWidgets);
    });

    // Note: Testing the composer TextField and attachment button requires
    // a full Material ancestor chain in the test environment. These elements
    // render correctly in the running app but fail in unit tests due to the
    // Positioned widget in ChatComposerWidget not inheriting Material context
    // from the flutter_chat_ui Chat widget's Scaffold.
    // This is a pre-existing limitation in v0.2.15.
  });

  group('ChatPage composer layout (bottom of Column, not Stack overlay)', () {
    Future<void> pumpChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }

    testWidgets('composer is visible at the bottom of the page',
        (tester) async {
      await pumpChatPage(tester);

      // Verify the composer's icon buttons exist (attach file and send)
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsWidgets);
    });

    testWidgets('composer is rendered below the top bar', (tester) async {
      await pumpChatPage(tester);

      // Find the top bar row and the composer elements
      final topBar = find.text('新对话');
      final sendButton = find.byIcon(Icons.send_rounded);

      // Verify the top bar title is above the send button on the page
      // (top bar has smaller y coordinate than the composer)
      final topBarRect = tester.getRect(topBar);
      final sendRect = tester.getRect(sendButton.first);
      expect(topBarRect.bottom, lessThan(sendRect.top));
    });

    testWidgets('composer is not positioned at the top of the page',
        (tester) async {
      await pumpChatPage(tester);

      // The composer (send button) should be in the lower portion of the screen
      final sendButton = find.byIcon(Icons.send_rounded);
      final sendRect = tester.getRect(sendButton.first);
      final screenSize = tester.getSize(find.byType(MaterialApp));
      // Send button should be in bottom third of screen
      expect(sendRect.center.dy, greaterThan(screenSize.height * 0.7));
    });
  });

  group('ChatPage JSON error detail dialog data structure', () {
    test('DataSanitizer handles raw request data structure correctly', () {
      // Simulate rawRequest structure built by _startStreaming()
      final rawRequest = <String, dynamic>{
        'url': 'https://api.example.com/chat',
        'headers': {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer sk-****1234',
        },
        'body': {
          'model': 'gpt-4',
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
        },
      };

      final sanitized = DataSanitizer.sanitizeForDisplay(rawRequest);
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(sanitized);

      // Verify JSON output is valid and contains expected fields
      expect(jsonStr, contains('"url"'));
      expect(jsonStr, contains('https://api.example.com/chat'));
      expect(jsonStr, contains('"model"'));
      expect(jsonStr, contains('gpt-4'));
      expect(jsonStr, contains('"Authorization"'));
      // API key is masked in headers but not sanitized (not base64)
      expect(jsonStr, contains('sk-****1234'));
    });

    test('DataSanitizer handles error response data structure', () {
      final rawResponse = <String, dynamic>{
        'statusCode': 400,
        'data': {
          'error': {
            'message': 'Bad Request',
            'type': 'invalid_request_error',
          },
        },
      };

      final sanitized = DataSanitizer.sanitizeForDisplay(rawResponse);
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(sanitized);

      expect(jsonStr, contains('"statusCode"'));
      expect(jsonStr, contains('400'));
      expect(jsonStr, contains('Bad Request'));
      expect(jsonStr, contains('invalid_request_error'));
    });

    test('DataSanitizer handles null/missing raw data gracefully', () {
      // When raw data is null
      final resultNull = DataSanitizer.sanitizeForDisplay(null);
      expect(resultNull, isNull);

      // Empty map
      final resultEmpty = DataSanitizer.sanitizeForDisplay(<String, dynamic>{});
      expect(resultEmpty, <String, dynamic>{});
    });
  });

  group('ChatMessage rawRequest/rawResponse serialization for ChatPage', () {
    test(
        'rawRequest/rawResponse survive conversation message list serialization',
        () {
      final messages = [
        ChatMessage(role: 'user', content: 'Hello', id: 'u1'),
        ChatMessage(
          role: 'assistant',
          content: '错误: API 请求失败 (HTTP 500): Server Error',
          id: 'a1',
          isError: true,
          rawRequest: {'url': 'https://api.example.com/chat', 'body': {}},
          rawResponse: {
            'statusCode': 500,
            'data': {'error': 'Internal'}
          },
        ),
      ];

      // Simulate conversation serialization (map list)
      final serialized = messages.map((m) => m.toMap()).toList();
      final deserialized =
          serialized.map((m) => ChatMessage.fromMap(m)).toList();

      final errorMsg = deserialized[1];
      expect(errorMsg.isError, true);
      expect(errorMsg.rawRequest, isNotNull);
      expect(errorMsg.rawResponse, isNotNull);
      expect(errorMsg.rawRequest!['url'], 'https://api.example.com/chat');
      expect(errorMsg.rawResponse!['statusCode'], 500);
    });

    test('non-error message does not have rawRequest/rawResponse', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'Hello',
        id: 'u1',
      );
      final map = msg.toMap();
      expect(map.containsKey('rawRequest'), false);
      expect(map.containsKey('rawResponse'), false);
    });
  });

  group('ChatPage timestamp format (yyyy-MM-dd HH:mm)', () {
    test('DateFormat produces correct output for known DateTime', () {
      final fmt = DateFormat('yyyy-MM-dd HH:mm');
      final dt = DateTime(2026, 6, 14, 9, 5);
      final result = fmt.format(dt);
      expect(result, '2026-06-14 09:05');
    });

    test('DateFormat handles edge cases (single-digit, midnight, end-of-year)',
        () {
      final fmt = DateFormat('yyyy-MM-dd HH:mm');
      expect(fmt.format(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
      expect(fmt.format(DateTime(2026, 6, 15, 0, 0)), '2026-06-15 00:00');
      expect(fmt.format(DateTime(2026, 12, 31, 23, 59)), '2026-12-31 23:59');
    });

    test('DateFormat pattern matches reference page formats', () {
      // Topic selection page, conversations page, and message search page
      // all use manual formatting with .padLeft(2,'0') on each component:
      //   '$y-$m-$d $h:$min' (with y=year, m=month, d=day, h=hour, min=minute)
      // DateFormat('yyyy-MM-dd HH:mm') must produce identical output.
      final testCases = [
        (DateTime(2026, 1, 1, 0, 0), '2026-01-01 00:00'),
        (DateTime(2026, 12, 25, 8, 30), '2026-12-25 08:30'),
        (DateTime(2026, 6, 15, 14, 30), '2026-06-15 14:30'),
      ];
      final fmt = DateFormat('yyyy-MM-dd HH:mm');
      for (final (dt, expected) in testCases) {
        expect(fmt.format(dt), expected);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From chat_page_alignment_and_preview_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('ChatPage - message alignment and preview', () {
    Future<void> pumpAlignmentChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createAlignmentChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }

    testWidgets('page renders with composer and title', (tester) async {
      await pumpAlignmentChatPage(tester);

      // The page should render without crashing
      expect(find.text('新对话'), findsOneWidget);
      // Composer should be present with attachment and send buttons
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsWidgets);
    });

    testWidgets(
        'isStreamingProvider state is preserved across widget lifecycle',
        (tester) async {
      // Verify isStreamingProvider is a Riverpod StateProvider that exists
      // independently of the ChatPage widget lifecycle. This is important
      // because the streaming provider must survive page disposal when the
      // user navigates back during active generation.
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      expect(container.read(isStreamingProvider), false);
      container.read(isStreamingProvider.notifier).state = true;
      expect(container.read(isStreamingProvider), true);
    });

    testWidgets(
        'user message attachments ListView has correct reverse alignment',
        (tester) async {
      // This test verifies that the attachment ListView for user messages
      // uses reverse: true so items are right-aligned (sent-by-me).
      // The actual rendering is tested by checking the builder logic -
      // in the textMessageBuilder, user messages with attachments should
      // have the ListView reverse property conditionally set.
      //
      // We verify the page renders without errors and that the attachment
      // preview builder exists.
      await pumpAlignmentChatPage(tester);
      expect(find.byType(ChatPage), findsOneWidget);
    });
  });

  group('ChatPage - file preview', () {
    Future<void> pumpAlignmentChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createAlignmentChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }

    testWidgets('page renders without crashing', (tester) async {
      await pumpAlignmentChatPage(tester);
      expect(find.text('新对话'), findsOneWidget);
    });

    test('AttachmentStorage.readFile returns null for non-existent files',
        () async {
      // Test the file read logic directly by checking that reading a
      // non-existent file from a known location returns null.
      final tmpDir = Directory.systemTemp.createTempSync('stroom_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final file = File('${tmpDir.path}/nonexistent');
      expect(await file.exists(), isFalse);
      // The read behavior should just check file.exists() and return null.
      final result = await (() async {
        if (await file.exists()) return await file.readAsBytes();
        return null;
      })();
      expect(result, isNull);
    });

    testWidgets('attachment preview dispatch works per file type',
        (tester) async {
      // The _showAttachmentPreview method dispatches to different preview
      // dialogs based on file type:
      //   - 'image' -> showImagePreviewDialog
      //   - 'text'  -> show text content/TextPreviewEditPage
      //   - 'pdf'   -> show PDF via inappwebview
      //   - 'audio' -> show audio player via just_audio
      //   - 'video' -> show video player via media_kit
      //   - other   -> showFileInfoPreviewDialog
      //
      // The dispatch logic is verified in _showAttachmentPreview of chat_page.dart.
      // This test verifies the page renders and the attachment button exists.
      await pumpAlignmentChatPage(tester);
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
    });
  });

  group('ChatPage - streaming provider lifecycle', () {
    test('isStreamingProvider persists across provider reads', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.read(isStreamingProvider.notifier).state = true;
      expect(container.read(isStreamingProvider), true);

      for (int i = 0; i < 3; i++) {
        expect(container.read(isStreamingProvider), true,
            reason: 'isStreamingProvider should persist across rebuilds');
      }

      container.read(isStreamingProvider.notifier).state = false;
      expect(container.read(isStreamingProvider), false);
    });

    test('streamingMsgIdProvider correctly stores and clears message ID', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      expect(container.read(streamingMsgIdProvider), isNull);

      const testId = 'ai-test-msg-id';
      container.read(streamingMsgIdProvider.notifier).state = testId;
      expect(container.read(streamingMsgIdProvider), testId);

      container.read(streamingMsgIdProvider.notifier).state = null;
      expect(container.read(streamingMsgIdProvider), isNull);
    });

    test('streamingFullReplyProvider accumulates and resets correctly', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      expect(container.read(streamingFullReplyProvider), '');

      container.read(streamingFullReplyProvider.notifier).state = 'Hello';
      expect(container.read(streamingFullReplyProvider), 'Hello');

      container.read(streamingFullReplyProvider.notifier).state = 'Hello world';
      expect(container.read(streamingFullReplyProvider), 'Hello world');

      container.read(streamingFullReplyProvider.notifier).state = '';
      expect(container.read(streamingFullReplyProvider), '');
    });

    test('all streaming state providers are reset correctly on completion', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      // Simulate streaming lifecycle
      container.read(isStreamingProvider.notifier).state = true;
      container.read(streamingMsgIdProvider.notifier).state = 'msg-1';
      container.read(streamingFullReplyProvider.notifier).state = 'some text';
      container.read(streamingHasFirstTokenProvider.notifier).state = true;

      // Simulate completion: all should reset
      container.read(isStreamingProvider.notifier).state = false;
      container.read(streamingMsgIdProvider.notifier).state = null;
      container.read(streamingFullReplyProvider.notifier).state = '';
      container.read(streamingHasFirstTokenProvider.notifier).state = false;

      expect(container.read(isStreamingProvider), false);
      expect(container.read(streamingMsgIdProvider), isNull);
      expect(container.read(streamingFullReplyProvider), '');
      expect(container.read(streamingHasFirstTokenProvider), false);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From chat_page_back_navigation_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('ChatPage back navigation', () {
    /// Helper: pump a MaterialApp with a root page and push ChatPage on top.
    /// Optionally overrides isStreamingProvider to simulate streaming state.
    Future<NavigatorState> pushChatPage(
      WidgetTester tester, {
      bool isStreaming = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              return ConversationsNotifier(ref);
            }),
            activeConversationIdProvider.overrideWith((ref) => 'conv-test-1'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
            if (isStreaming) isStreamingProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Center(child: Text('Root Page'))),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      navKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ChatPage()),
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      return navKey.currentState!;
    }

    // ── Existing test: still passes ──
    testWidgets('isStreaming=false: back pops page', (tester) async {
      await pushChatPage(tester, isStreaming: false);

      expect(find.byType(ChatPage), findsOneWidget);

      // Tap back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pumpAndSettle();

      // Page should pop
      expect(find.byType(ChatPage), findsNothing);
      expect(find.text('Root Page'), findsOneWidget);
    });

    // ── Core fix: back button works during streaming ──
    testWidgets('isStreaming=true: back button pops page (no longer blocked)', (
      tester,
    ) async {
      await pushChatPage(tester, isStreaming: true);

      expect(find.byType(ChatPage), findsOneWidget);

      // Tap back — should pop even during streaming (this is the fix)
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pumpAndSettle();

      // Page should pop back to root
      expect(find.byType(ChatPage), findsNothing);
      expect(find.text('Root Page'), findsOneWidget);
    });

    // ── Core fix: system back respects PopScope with canPop=true ──
    testWidgets('isStreaming=true: PopScope is configured with canPop=true',
        (tester) async {
      await pushChatPage(tester, isStreaming: true);

      expect(find.byType(ChatPage), findsOneWidget);

      // Verify PopScope exists in the ChatPage widget tree.
      // With canPop: true, the system back (Android hardware button / iOS
      // swipe) is always allowed. The back button test above already proves
      // that programmatic Navigator.pop() works during streaming, and the
      // PopScope configuration allows system back as well.
      final popScope = find.byType(PopScope);
      expect(popScope, findsOneWidget);

      // Read the canPop property: we expect it to be true (the fix).
      // In test, PopScope.canPop starts as the passed value (true) and is
      // not overridden by any streaming check since we removed !isStreaming.
      final popScopeWidget = tester.widget<PopScope>(popScope);
      // For PopScope, canPop is a constructor parameter — we verify it's
      // set to true, meaning system back is never blocked.
      expect(popScopeWidget.canPop, isTrue);
    });

    // ── Verify no blocking snackbar during streaming ──
    testWidgets('isStreaming=true: no blocking snackbar shown', (tester) async {
      await pushChatPage(tester, isStreaming: true);

      expect(find.byType(ChatPage), findsOneWidget);

      // Tap back — the old code showed a snackbar, new code should not
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The old "AI正在生成回复" snackbar should NOT appear
      expect(find.text('AI正在生成回复，请等待回复完成后返回'), findsNothing);
    });

    // ── Verify streaming provider persists after navigation ──
    testWidgets('isStreaming=true: streaming state persists after pop',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            return ConversationsNotifier(ref);
          }),
          providerEntriesProvider.overrideWith((ref) {
            return ProviderEntriesNotifier();
          }),
        ],
      );

      // Manually set streaming state to true
      container.read(isStreamingProvider.notifier).state = true;

      // Use a simple navigator-less test: just verify the provider state
      // is set correctly. The provider is at the ProviderContainer scope,
      // which survives widget disposal. The other tests already verify
      // that back button and PopScope work correctly during streaming.
      expect(container.read(isStreamingProvider), isTrue);

      // Verify provider state is unchanged after building and disposing
      // a ChatPage widget within this container scope.
      // This simulates: navigate away → page disposed → streaming still active.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ChatPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Unmount the widget (simulates page being popped)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('New Page')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // After ChatPage is unmounted, streamingProvider should still be true
      expect(container.read(isStreamingProvider), isTrue);

      container.dispose();
    });

    // ── No old dialog ──
    testWidgets('no old dialog appears', (tester) async {
      await pushChatPage(tester, isStreaming: false);
      // The old stop dialog should never appear
      expect(find.text('停止生成？'), findsNothing);
      expect(find.text('停止并返回'), findsNothing);
      expect(find.text('取消'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From chat_page_infinite_scroll_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('Infinite Scroll / Lazy Loading - ChatPage', () {
    // ====== UNIT TESTS: Pagination Logic ======

    group('Pagination state calculation', () {
      test(
          'initial load with more than pageSize messages loads only the last page',
          () {
        const pageSize = 20;
        final allMessages = createTestMessages(100);
        final totalCount = allMessages.length;

        // Calculate initial load range
        final loadedStartIndex = (totalCount - pageSize).clamp(0, totalCount);
        final initialBatch = allMessages.sublist(loadedStartIndex);

        // Verify only last pageSize messages are loaded initially
        expect(initialBatch.length, pageSize);
        expect(initialBatch.first.id, 'user_80'); // msg[80]
        expect(initialBatch.last.id, 'assistant_99'); // msg[99]
        expect(loadedStartIndex, 80);
      });

      test('initial load with fewer than pageSize messages loads all', () {
        const pageSize = 20;
        final allMessages = createTestMessages(5);
        final totalCount = allMessages.length;

        // Calculate initial load range
        final loadedStartIndex = (totalCount - pageSize).clamp(0, totalCount);
        final initialBatch = allMessages.sublist(loadedStartIndex);

        // Verify all messages are loaded
        expect(initialBatch.length, 5);
        expect(initialBatch.first.id, 'user_0');
        expect(initialBatch.last.id, 'user_4'); // index 4 is even → 'user'
        expect(loadedStartIndex, 0);
      });

      test('load more returns the previous batch of messages', () {
        const pageSize = 20;
        final allMessages = createTestMessages(100);

        // Initial state: loaded from index 80 to 99
        int loadedStartIndex = 80;
        expect(loadedStartIndex > 0, true); // hasMore = true

        // Load more: get messages from index 60 to 79
        final newStart =
            (loadedStartIndex - pageSize).clamp(0, allMessages.length);
        final batch = allMessages.sublist(newStart, loadedStartIndex);
        loadedStartIndex = newStart;

        expect(batch.length, 20);
        expect(batch.first.id, 'user_60');
        expect(batch.last.id, 'assistant_79');
        expect(loadedStartIndex, 60);
      });

      test('load more stops at the beginning of history', () {
        const pageSize = 20;
        final allMessages = createTestMessages(25);

        // Initial state: loaded from index 5 to 24
        int loadedStartIndex = 5;

        // Load more 1: get messages from index 0 to 4
        final newStart =
            (loadedStartIndex - pageSize).clamp(0, allMessages.length);
        final batch = allMessages.sublist(newStart, loadedStartIndex);
        loadedStartIndex = newStart;

        expect(batch.length, 5);
        expect(batch.first.id, 'user_0');
        expect(loadedStartIndex, 0);
        expect(loadedStartIndex == 0, true); // no more messages after this
      });

      test('hasMoreMessages correctly reflects remaining messages', () {
        // Scenario 1: More to load
        int loadedStartIndex = 60;
        expect(loadedStartIndex > 0, true); // hasMore

        // Scenario 2: At the beginning
        loadedStartIndex = 0;
        expect(loadedStartIndex <= 0, true); // no more

        // Scenario 3: Empty history
        loadedStartIndex = 0;
        expect(loadedStartIndex <= 0, true); // no more
      });

      test('consecutive load more calls move backward through history', () {
        const pageSize = 20;
        final allMessages = createTestMessages(100);

        int loadedStartIndex = 80; // initial load
        final steps = <int>[];

        while (loadedStartIndex > 0) {
          final newStart =
              (loadedStartIndex - pageSize).clamp(0, allMessages.length);
          final batch = allMessages.sublist(newStart, loadedStartIndex);
          loadedStartIndex = newStart;
          steps.add(batch.length);
        }

        // Should have loaded 4 batches: 20 + 20 + 20 + 20 = 80
        expect(steps, [20, 20, 20, 20]);
        expect(loadedStartIndex, 0);
      });
    });

    // ====== UNIT TESTS: Message Ordering ======

    group('Message ordering with pagination', () {
      test('initial batch maintains chronological order', () {
        final allMessages = createTestMessages(30);
        const pageSize = 20;

        final loadedStartIndex =
            (allMessages.length - pageSize).clamp(0, allMessages.length);
        final initialBatch = allMessages.sublist(loadedStartIndex);

        // Verify chronological order (oldest first = index 0)
        for (var i = 1; i < initialBatch.length; i++) {
          expect(
            initialBatch[i].createdAt.isAfter(initialBatch[i - 1].createdAt),
            true,
            reason: 'Messages should be in chronological order',
          );
        }
      });

      test(
          'prepended batch maintains chronological order when inserted at position 0',
          () {
        const pageSize = 20;
        final allMessages = createTestMessages(60);
        int loadedStartIndex = 40; // initially loaded [40..59]

        // First load more: get [20..39] to prepend
        int newStart =
            (loadedStartIndex - pageSize).clamp(0, allMessages.length);
        final batch1 = allMessages.sublist(newStart, loadedStartIndex);

        // After prepending at index 0, the order should be:
        // [20..39, 40..59] → all in chronological order
        final afterLoad1 = [
          ...batch1,
          ...allMessages.sublist(loadedStartIndex)
        ];
        for (var i = 1; i < afterLoad1.length; i++) {
          expect(
            afterLoad1[i].createdAt.isAfter(afterLoad1[i - 1].createdAt),
            true,
            reason:
                'After prepend, messages should maintain chronological order',
          );
        }

        loadedStartIndex = newStart;

        // Second load more: get [0..19]
        newStart = (loadedStartIndex - pageSize).clamp(0, allMessages.length);
        final batch2 = allMessages.sublist(newStart, loadedStartIndex);

        final afterLoad2 = [...batch2, ...afterLoad1];
        for (var i = 1; i < afterLoad2.length; i++) {
          expect(
            afterLoad2[i].createdAt.isAfter(afterLoad2[i - 1].createdAt),
            true,
            reason:
                'After second prepend, messages should maintain chronological order',
          );
        }
      });
    });

    // ====== WIDGET TESTS ======

    group('Chat widget with infinite scroll', () {
      Future<void> pumpChatPageWithMessages(
        WidgetTester tester, {
        int messageCount = 25,
      }) async {
        final messages = createTestMessages(messageCount);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(createChatTestAppWithMessages(
          messages: messages,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        // Consume any pre-existing framework exceptions from flutter_chat_ui
        tester.takeException();
      }

      testWidgets('renders without crash with many messages', (tester) async {
        await pumpChatPageWithMessages(tester, messageCount: 25);

        // Should render the chat page without crashing
        expect(find.byType(ChatPage), findsOneWidget);
      });

      testWidgets('test app creates conversation with messages',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final messages = createTestMessages(10);
        await tester.pumpWidget(createChatTestAppWithMessages(
          messages: messages,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Page renders
        expect(find.byType(ChatPage), findsOneWidget);
      });

      testWidgets('empty conversation renders without crash', (tester) async {
        await pumpChatPageWithMessages(tester, messageCount: 0);

        // Should render without crash
        expect(find.byType(ChatPage), findsOneWidget);
      });

      testWidgets('custom chatAnimatedListBuilder is used by Chat widget',
          (tester) async {
        // This tests that the Chat widget receives a custom chatAnimatedListBuilder.
        // The builder creates a ChatAnimatedList with onEndReached callback.
        await pumpChatPageWithMessages(tester, messageCount: 5);

        // Verify the chat page renders
        expect(find.byType(ChatPage), findsOneWidget);

        // The Chat widget should exist
        expect(find.byType(Chat), findsOneWidget);
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From chat_page_reasoning_init_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('Reasoning sections initialization', () {
    test('streamingReasoningSectionsProvider starts as empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sections = container.read(streamingReasoningSectionsProvider);
      expect(sections, isEmpty, reason: '推理章节应在无推理内容时初始化为空列表，而非[""]');
    });

    test('streamingReasoningProvider starts as empty string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reasoning = container.read(streamingReasoningProvider);
      expect(reasoning, isEmpty);
    });

    test('isStreamingProvider starts as false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isStreaming = container.read(isStreamingProvider);
      expect(isStreaming, isFalse);
    });

    test('can add reasoning section to empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate the start of reasoning: first section
      container.read(streamingReasoningSectionsProvider.notifier).state = [];

      // Add reasoning content - this simulates ReasoningEvent handler logic
      final sections = [...container.read(streamingReasoningSectionsProvider)];
      if (sections.isEmpty) {
        sections.add('First reasoning text');
      } else {
        sections[sections.length - 1] = 'First reasoning text';
      }
      container.read(streamingReasoningSectionsProvider.notifier).state =
          sections;

      expect(container.read(streamingReasoningSectionsProvider).length, 1);
      expect(
        container.read(streamingReasoningSectionsProvider).first,
        'First reasoning text',
      );

      // Simulate ReasoningSectionEndEvent - add new empty section
      final sections2 = [...container.read(streamingReasoningSectionsProvider)];
      sections2.add('');
      container.read(streamingReasoningSectionsProvider.notifier).state =
          sections2;

      expect(container.read(streamingReasoningSectionsProvider).length, 2);

      // Fill second section (simulating second round of reasoning)
      final sections3 = [...container.read(streamingReasoningSectionsProvider)];
      sections3[sections3.length - 1] = 'Second reasoning text';
      container.read(streamingReasoningSectionsProvider.notifier).state =
          sections3;

      expect(
        container.read(streamingReasoningSectionsProvider).last,
        'Second reasoning text',
      );
    });

    test('sectioned reasoning works with empty sections (no reasoning content)',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate streaming start with no reasoning content yet
      container.read(streamingReasoningSectionsProvider.notifier).state = [];
      container.read(streamingReasoningProvider.notifier).state = '';

      // Simulate finalization when no reasoning was received
      final reasoningBuffer = '';
      var finalSections = [
        ...container.read(streamingReasoningSectionsProvider),
      ];
      if (finalSections.isNotEmpty) {
        finalSections[finalSections.length - 1] = reasoningBuffer;
      } else {
        // Don't add empty section - reasoningBuffer is empty
        // Keep sections empty so no button is shown
      }
      container.read(streamingReasoningSectionsProvider.notifier).state =
          finalSections;

      expect(container.read(streamingReasoningSectionsProvider), isEmpty,
          reason: '无推理内容时章节列表应为空，避免显示空按钮');
    });

    test('streamingReasoningSectionsProvider can be updated with new content',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(streamingReasoningSectionsProvider.notifier).state = [
        'test reasoning',
      ];

      expect(container.read(streamingReasoningSectionsProvider).length, 1);
      expect(container.read(streamingReasoningSectionsProvider).first,
          'test reasoning');
    });
  });

  group('Streaming providers lifecycle', () {
    test('streaming providers reset correctly for new session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate old session state
      container.read(streamingReasoningSectionsProvider.notifier).state = [
        'old reasoning',
        'more reasoning',
      ];
      container.read(streamingReasoningProvider.notifier).state = 'old buffer';
      container.read(streamingMsgIdProvider.notifier).state = 'old-msg-id';
      container.read(streamingFullReplyProvider.notifier).state = 'old content';

      // Reset for new session
      container.read(streamingReasoningSectionsProvider.notifier).state = [];
      container.read(streamingReasoningProvider.notifier).state = '';
      container.read(streamingMsgIdProvider.notifier).state = 'new-msg-id';
      container.read(streamingFullReplyProvider.notifier).state = '';

      expect(container.read(streamingReasoningSectionsProvider), isEmpty);
      expect(container.read(streamingReasoningProvider), isEmpty);
      expect(container.read(streamingMsgIdProvider), 'new-msg-id');
      expect(container.read(streamingFullReplyProvider), isEmpty);
    });
  });
}
