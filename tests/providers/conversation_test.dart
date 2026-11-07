// Merged from:
//   - conversation_draft_test.dart
//   - conversation_history_ordering_test.dart
//   - conversation_mcp_tools_test.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/locale_provider.dart';
part 'conversation_test_p1.dart';
part 'conversation_test_p2.dart';
part 'conversation_test_p3.dart';
part 'conversation_test_p4.dart';
part 'conversation_test_p5.dart';
part 'conversation_test_p6.dart';

/// Helper: create a ProviderContainer with a ConversationsNotifier that has
/// state pre-set (bypassing async _load from SharedPreferences).
ProviderContainer _createContainer({List<Conversation>? initialState}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = initialState ?? [];
        return notifier;
      }),
    ],
  );
}

void main() {
  group('Default assistant localization', () {
    for (final locale in [
      (
        'en_US',
        'General Assistant',
        "You are a helpful AI assistant. Answer the user's questions clearly and helpfully.",
      ),
      (
        'zh_CN',
        '通用助手',
        '你是一个有帮助的AI助手。请用中文回答用户的问题。',
      ),
    ]) {
      test('migration-created default uses ${locale.$1}', () async {
        SharedPreferences.setMockInitialValues({
          localePreferenceKey: locale.$1,
        });
        final prefs = await SharedPreferences.getInstance();
        final conversations = [Conversation(title: 'Legacy conversation')];

        final changed = await assignNullAssistantConversations(
          prefs,
          conversations,
        );

        expect(changed, isTrue);
        expect(conversations.single.assistantId, isNotNull);
        final assistants = (jsonDecode(prefs.getString('assistants')!) as List)
            .cast<Map<String, dynamic>>();
        expect(assistants, hasLength(1));
        expect(assistants.single['name'], locale.$2);
        expect(assistants.single['prompt'], locale.$3);
      });
    }

    test(
      'keeps a stored assistant and prompt while binding legacy chat',
      () async {
        final stored = Assistant(
          id: 'stored-assistant',
          name: 'Saved assistant',
          prompt: 'Edited prompt',
        );
        SharedPreferences.setMockInitialValues({
          localePreferenceKey: 'en_US',
          'assistants': jsonEncode([stored.toMap()]),
        });
        final prefs = await SharedPreferences.getInstance();
        final originalJson = prefs.getString('assistants');
        final conversation = Conversation(title: 'Legacy conversation');

        await assignNullAssistantConversations(prefs, [conversation]);

        expect(conversation.assistantId, stored.id);
        expect(prefs.getString('assistants'), originalJson);
      },
    );
  });

  conversationGroup1();
  conversationGroup2();
  conversationGroup3();
  conversationGroup4();
  conversationGroup5();
  conversationGroup6();
}
