import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/assistant_prompt_safety_review.dart';
import 'package:stroom/services/chat_adapter.dart';

void main() {
  test('fails closed when prompt review has no configured LLM', () async {
    await expectLater(
      AssistantPromptSafetyReview.review(
        adapter: ChatAdapter(),
        entriesState: const ProviderEntriesState(),
        assistantId: 'stroom.test',
        prompt: 'Be helpful.',
        settings: const {},
      ),
      throwsA(isA<StateError>()),
    );
  });
}
