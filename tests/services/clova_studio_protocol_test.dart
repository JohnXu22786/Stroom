import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/clova_studio_protocol.dart';

void main() {
  group('CLOVA Studio v3 protocol', () {
    test(
      'builds native message requests and preserves HCX-005 image data URIs',
      () {
        final request = ClovaStudioProtocol.buildRequest('HCX-005', {
          'system': 'Be concise.',
          'messages': [
            {'role': 'system', 'content': 'Be concise.'},
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'Describe this.'},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,AAEC'},
                },
              ],
            },
          ],
          'temperature': 0.2,
          'max_tokens': 500,
        });

        expect(request['messages'], [
          {
            'role': 'system',
            'content': [
              {'type': 'text', 'text': 'Be concise.'},
            ],
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Describe this.'},
              {
                'type': 'image_url',
                'dataUri': {'data': 'data:image/png;base64,AAEC'},
              },
            ],
          },
        ]);
        expect(request['temperature'], 0.2);
        expect(request['maxTokens'], 500);
        expect(request['stream'], isTrue);
      },
    );

    test('maps HCX-007 output cap and thinking effort to native camelCase', () {
      final request = ClovaStudioProtocol.buildRequest('HCX-007', {
        'messages': [
          {'role': 'user', 'content': 'Explain.'},
        ],
        'reasoning_effort': 'high',
        'max_completion_tokens': 12000,
      });

      expect(request['thinking'], {'effort': 'high'});
      expect(request['maxCompletionTokens'], 12000);
      expect(request, isNot(contains('maxTokens')));
    });

    test(
      'rejects images for text-only models and unsupported tool requests',
      () async {
        expect(
          () => ClovaStudioProtocol.buildRequest('HCX-DASH-002', {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'https://example.test/image.png'},
                  },
                ],
              },
            ],
          }),
          throwsUnsupportedError,
        );
        expect(
          () => ClovaStudioProtocol.buildRequest('HCX-005', {
            'messages': [
              {'role': 'user', 'content': 'Use lookup.'},
            ],
            'tools': [
              {
                'type': 'function',
                'function': {'name': 'lookup'},
              },
            ],
          }),
          throwsUnsupportedError,
        );
      },
    );

    test('rejects remote HCX-005 image URLs instead of forwarding them', () {
      for (final url in [
        'https://127.0.0.1/image.png',
        'https://user:secret@images.example.com/image.png',
        'https://attacker.example/image.png',
        'https://cdn.example.com/image.png',
      ]) {
        expect(
          () => ClovaStudioProtocol.buildRequest('HCX-005', {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': url},
                  },
                ],
              },
            ],
          }),
          throwsA(
            isA<UnsupportedError>().having(
              (error) => error.message,
              'message',
              contains('remote image URLs are not supported'),
            ),
          ),
          reason: url,
        );
      }
    });

    test(
      'parses token and terminal SSE events without duplicating final snapshot',
      () {
        final parser = ClovaStudioSseAccumulator();
        final first = parser.addFrame(
          'event: token\ndata: {"message":{"content":"hello "}}\n\n',
        );
        final second = parser.addFrame(
          'event: token\ndata: {"message":{"content":"world"}}\n\n',
        );
        final terminal = parser.addFrame(
          'event: result\ndata: {"status":{"code":"20000"},"result":{"message":{"content":"hello world"},"stopReason":"length","inputLength":3,"outputLength":2}}\n\n',
        );

        expect(first.textDelta, 'hello ');
        expect(second.textDelta, 'world');
        expect(terminal.textDelta, isNull);
        expect(terminal.done, isTrue);
        expect(terminal.finishReason, 'length');
        expect(terminal.usage, {
          'input_tokens': 3,
          'output_tokens': 2,
          'total_tokens': 5,
        });
        expect(parser.text, 'hello world');
      },
    );

    test(
      'emits only upstream-returned HCX-007 reasoning and errors on failed status',
      () {
        final parser = ClovaStudioSseAccumulator();
        final event = parser.addFrame(
          'event: token\ndata: {"message":{"thinkingContent":"working","content":"answer"}}\n\n',
        );
        expect(event.reasoningDelta, 'working');
        expect(event.textDelta, 'answer');

        final terminalReasoning = ClovaStudioSseAccumulator().addFrame(
          'event: result\ndata: {"result":{"message":{"content":"answer","thinkingContent":"returned trace"}}}\n\n',
        );
        expect(terminalReasoning.reasoningDelta, 'returned trace');

        final failed = ClovaStudioSseAccumulator();
        expect(
          () => failed.addFrame(
            'event: error\ndata: {"status":{"code":"40001","message":"invalid"}}\n\n',
          ),
          throwsA(isA<ClovaStudioUpstreamException>()),
        );
      },
    );
  });
}
