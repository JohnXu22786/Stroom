import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/chat_visualization_prompt.dart';

void main() {
  group('chat visualization prompt', () {
    test(
        'adds the default visualization guidance when no assistant prompt exists',
        () {
      final prompt = withChatVisualizationPrompt(null);

      expect(prompt, contains('do not force a visual into every reply'));
      expect(prompt, contains('```html-preview'));
      expect(prompt, contains('fence for HTML code examples'));
    });

    test('preserves the assistant prompt and appends visualization guidance',
        () {
      const assistantPrompt = 'Explain concepts step by step in Chinese.';
      final prompt = withChatVisualizationPrompt(assistantPrompt);

      expect(prompt, startsWith(assistantPrompt));
      expect(prompt, contains('\n\n'));
      expect(prompt, endsWith(chatVisualizationPrompt.trim()));
    });
  });
}
