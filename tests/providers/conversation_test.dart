// Merged from:
//   - conversation_draft_test.dart
//   - conversation_history_ordering_test.dart
//   - conversation_mcp_tools_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
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
  conversationGroup1();
  conversationGroup2();
  conversationGroup3();
  conversationGroup4();
  conversationGroup5();
  conversationGroup6();
}
