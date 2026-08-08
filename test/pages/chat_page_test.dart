// Merged from:
//   chat_page_test.dart
//   chat_page_alignment_and_preview_test.dart
//   chat_page_back_navigation_test.dart
//   chat_page_infinite_scroll_test.dart
//   chat_page_reasoning_init_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/utils/data_sanitizer.dart';
part 'chat_page_test_p1.dart';
part 'chat_page_test_p3.dart';

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

void main() {
  chatPageGroup1();
  chatPageGroup3();

  // ====================================================================
  // Per-conversation model persistence
  // ====================================================================
  group('Per-conversation model persistence', () {
    testWidgets(
        'switching model in the composer persists to the active conversation',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              final notifier = ConversationsNotifier(ref);
              notifier.state = [
                Conversation(
                  id: 'conv-a',
                  title: '话题A',
                  createdAt: DateTime(2026, 1, 1),
                  updatedAt: DateTime(2026, 1, 1),
                  messages: [],
                  assistantId: null,
                ),
              ];
              return notifier;
            }),
            activeConversationIdProvider.overrideWith((ref) => 'conv-a'),
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = ProviderEntriesState(
                entries: [
                  ProviderEntry(
                    id: 'test_llm',
                    type: 'llm',
                    name: 'LLM供应商',
                    configs: [
                      ProviderConfigItem(
                        providerName: 'OpenAI',
                        host: 'https://api.openai.com/v1',
                        key: 'test-key',
                        models: [
                          ModelConfig(name: 'gpt-4o', modelId: 'gpt-4o'),
                          ModelConfig(
                            name: 'claude-3.5-sonnet',
                            modelId: 'claude-3.5-sonnet',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Composer chip shows the first available model
      expect(find.text('gpt-4o | OpenAI'), findsOneWidget);

      // Open the model panel and switch to the second model
      await tester.tap(find.text('gpt-4o | OpenAI'));
      await tester.pumpAndSettle();
      expect(find.text('选择模型'), findsOneWidget);
      await tester.tap(find.text('claude-3.5-sonnet | OpenAI'));
      await tester.pumpAndSettle();

      // The switch is recorded per-conversation so re-entry restores it
      // without affecting other conversations.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      final conv = container.read(conversationsProvider).single;
      expect(conv.lastUsedModelName, 'claude-3.5-sonnet | OpenAI');

      // The conversation had no per-conversation record before the switch,
      // so it was following the global default — the switch also updates
      // the global fallback (legacy behavior preserved).
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('selected_model_index'), 1);
    });

    testWidgets(
        'switching model in a conversation with its own model record does '
        'NOT rewrite the global default', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_model_index': 0,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              final notifier = ConversationsNotifier(ref);
              notifier.state = [
                Conversation(
                  id: 'conv-a',
                  title: '话题A',
                  createdAt: DateTime(2026, 1, 1),
                  updatedAt: DateTime(2026, 1, 1),
                  messages: [],
                  assistantId: null,
                  // 已存在对话自身的模型记录（如助手默认模型播种而来）：
                  // 覆盖全局默认，切换后不得反向泄漏到全局。
                  lastUsedModelName: 'gpt-4o | OpenAI',
                ),
              ];
              return notifier;
            }),
            activeConversationIdProvider.overrideWith((ref) => 'conv-a'),
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = ProviderEntriesState(
                entries: [
                  ProviderEntry(
                    id: 'test_llm',
                    type: 'llm',
                    name: 'LLM供应商',
                    configs: [
                      ProviderConfigItem(
                        providerName: 'OpenAI',
                        host: 'https://api.openai.com/v1',
                        key: 'test-key',
                        models: [
                          ModelConfig(name: 'gpt-4o', modelId: 'gpt-4o'),
                          ModelConfig(
                            name: 'claude-3.5-sonnet',
                            modelId: 'claude-3.5-sonnet',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Composer restores the conversation's own model
      expect(find.text('gpt-4o | OpenAI'), findsOneWidget);

      // Switch to the second model
      await tester.tap(find.text('gpt-4o | OpenAI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('claude-3.5-sonnet | OpenAI'));
      await tester.pumpAndSettle();

      // Per-conversation record updated…
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      final conv = container.read(conversationsProvider).single;
      expect(conv.lastUsedModelName, 'claude-3.5-sonnet | OpenAI');

      // …but the global default is untouched — the override must not leak
      // into other conversations that follow the global default.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('selected_model_index'), 0);
    });
  });
}
