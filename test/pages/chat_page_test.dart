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
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/assistant_provider.dart';
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
      // The absolute identity is stored alongside the display name so a
      // later rename of the model/provider cannot break the reference.
      expect(conv.lastUsedModelId, 'claude-3.5-sonnet');
      expect(conv.lastUsedProviderName, 'OpenAI');

      // The global "last used" rule is REMOVED: switching a model in one
      // conversation must NOT write a global selected_model_index that
      // other record-less conversations would inherit.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('selected_model_index'), isNull,
          reason: 'no global last-used index may be written — the fallback '
              'for record-less conversations is assistant default / first '
              'model, not "whatever was used last"');
    });

    testWidgets(
        'switching model in a conversation with its own model record does '
        'NOT rewrite the global default', (tester) async {
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
                  // 已存在对话自身的模型记录（如助手默认模型播种而来）：
                  // 覆盖全局默认，切换后不得反向泄漏到全局。
                  lastUsedModelName: 'gpt-4o | OpenAI',
                  lastUsedModelId: 'gpt-4o',
                  lastUsedProviderName: 'OpenAI',
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
      expect(conv.lastUsedModelId, 'claude-3.5-sonnet');
      expect(conv.lastUsedProviderName, 'OpenAI');

      // …and no global index is ever written.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('selected_model_index'), isNull,
          reason: 'the global last-used index rule is removed entirely');
    });

    testWidgets(
        'a record-less conversation follows the ASSISTANT DEFAULT model '
        '(not the stale global index)', (tester) async {
      // Simulate an old installation: a stale global index points at the
      // second model. The conversation has no per-conversation record and
      // its assistant declares a default model — the assistant default
      // must win over the stale index.
      SharedPreferences.setMockInitialValues({
        'selected_model_index': 1,
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
                  assistantId: 'asst-1',
                  // 无对话自身记录：走助手默认 → 列表第一个
                ),
              ];
              return notifier;
            }),
            activeConversationIdProvider.overrideWith((ref) => 'conv-a'),
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              notifier.state = [
                Assistant(
                  id: 'asst-1',
                  name: '助手',
                  prompt: '你好',
                  defaultModelName: 'claude-3.5-sonnet | OpenAI',
                  defaultModelId: 'claude-3.5-sonnet',
                  defaultProviderName: 'OpenAI',
                ),
              ];
              return notifier;
            }),
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

      // Assistant default wins over the stale global index 1.
      expect(find.text('claude-3.5-sonnet | OpenAI'), findsOneWidget);
    });

    testWidgets(
        'assistant default is applied even when the assistant list loads '
        'AFTER the conversation (async load race)', (tester) async {
      // 模拟启动竞态：conversations 先加载完、assistants 后加载。
      // 恢复链第一次跑时助手列表为空（规则2落空→列表第一个），
      // assistantProvider 从空变非空时必须补跑恢复链。
      SharedPreferences.setMockInitialValues({});
      final lateNotifier = AssistantsNotifier();
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
                  assistantId: 'asst-1',
                ),
              ];
              return notifier;
            }),
            activeConversationIdProvider.overrideWith((ref) => 'conv-a'),
            assistantProvider.overrideWith((ref) => lateNotifier),
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

      // 助手尚未加载：暂时落到列表第一个
      expect(find.text('gpt-4o | OpenAI'), findsOneWidget);

      // 助手列表异步加载完成（空 → 非空）→ 恢复链补跑 → 助手默认生效
      lateNotifier.state = [
        Assistant(
          id: 'asst-1',
          name: '助手',
          prompt: '你好',
          defaultModelName: 'claude-3.5-sonnet | OpenAI',
          defaultModelId: 'claude-3.5-sonnet',
          defaultProviderName: 'OpenAI',
        ),
      ];
      await tester.pumpAndSettle();

      expect(find.text('claude-3.5-sonnet | OpenAI'), findsOneWidget,
          reason: 'assistant list arriving late must re-trigger the restore '
              'chain so the assistant default wins over the temporary first '
              'model');
    });

    testWidgets(
        'a record-less conversation with NO assistant default falls back to '
        'the FIRST model in the list (not a stale global index)',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_model_index': 1, // stale: would point at the 2nd model
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

      // First model in the list — the stale index 1 is ignored entirely.
      expect(find.text('gpt-4o | OpenAI'), findsOneWidget);
    });

    testWidgets(
        'per-conversation record resolves by ABSOLUTE modelId even when the '
        'stored display name is stale (model renamed)', (tester) async {
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
                  // 显示名已过期（模型被重命名），但绝对身份仍可解析。
                  lastUsedModelName: 'old-display-name | OpenAI',
                  lastUsedModelId: 'claude-3.5-sonnet',
                  lastUsedProviderName: 'OpenAI',
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

      // Resolved through the absolute id, not the stale display name.
      expect(find.text('claude-3.5-sonnet | OpenAI'), findsOneWidget);
    });
  });
}
