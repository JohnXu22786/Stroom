import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';

void main() {
  group('ChatMessage.compactRawRequest', () {
    test(
      'compacts historical Responses input and current attachment bytes',
      () {
        final encodedImage =
            'data:image/png;base64,${List.filled(1000, 'A').join()}';
        final raw = <String, dynamic>{
          'body': {
            'input': [
              {
                'type': 'message',
                'role': 'user',
                'content': [
                  {'type': 'input_text', 'text': 'old user question'},
                  {'type': 'input_image', 'image_url': encodedImage},
                ],
              },
              {
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {'type': 'output_text', 'text': 'old assistant answer'},
                ],
              },
              {
                'type': 'message',
                'role': 'user',
                'content': [
                  {'type': 'input_text', 'text': 'current question'},
                  {'type': 'input_image', 'image_url': encodedImage},
                ],
              },
              {
                'type': 'function_call_output',
                'call_id': 'call-1',
                'output': 'large generated tool result',
              },
            ],
          },
        };

        final compacted = ChatMessage.compactRawRequest(raw);
        final input = (compacted['body'] as Map)['input'] as List;

        expect(
          (input[0] as Map)['content'],
          '[previous message content omitted]',
        );
        expect(
          (input[1] as Map)['content'],
          '[previous message content omitted]',
        );
        final currentContent = (input[2] as Map)['content'] as List;
        expect(currentContent.first['text'], 'current question');
        expect(currentContent.last['image_url'], contains('[base64 data:'));
        expect(
          currentContent.last['image_url'],
          isNot(contains(List.filled(1000, 'A').join())),
        );
        expect(
          (input[3] as Map)['output'],
          '[generated function output omitted]',
        );

        // Compaction runs again during serialization; markers stay bounded.
        final compactedAgain = ChatMessage.compactRawRequest(compacted);
        expect(compactedAgain, compacted);
      },
    );
  });
}
