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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/utils/data_sanitizer.dart';
part 'chat_page_test_p1.dart';
part 'chat_page_test_p2.dart';
part 'chat_page_test_p3.dart';
part 'chat_page_test_p4.dart';
part 'chat_page_test_p5.dart';

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
  chatPageGroup1();
  chatPageGroup2();
  chatPageGroup3();
  chatPageGroup4();
  chatPageGroup5();
}
