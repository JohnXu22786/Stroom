import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/clova_studio_protocol.dart';

void main() {
  group('CLOVA Studio v3 protocol', () {
    test(
      'builds native message requests and preserves HCX-005 image data URIs',
      () async {
        final request = await ClovaStudioProtocol.buildRequest('HCX-005', {
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

    test(
      'maps HCX-007 output cap and thinking effort to native camelCase',
      () async {
        final request = await ClovaStudioProtocol.buildRequest('HCX-007', {
          'messages': [
            {'role': 'user', 'content': 'Explain.'},
          ],
          'reasoning_effort': 'high',
          'max_completion_tokens': 12000,
        });

        expect(request['thinking'], {'effort': 'high'});
        expect(request['maxCompletionTokens'], 12000);
        expect(request, isNot(contains('maxTokens')));
      },
    );

    test(
      'rejects images for text-only models and unsupported tool requests',
      () async {
        await expectLater(
          ClovaStudioProtocol.buildRequest('HCX-DASH-002', {
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
        await expectLater(
          ClovaStudioProtocol.buildRequest('HCX-005', {
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

    test('rejects private and credentialed HCX-005 image URLs', () async {
      for (final url in [
        'https://127.0.0.1/image.png',
        'https://10.0.0.8/image.png',
        'https://172.16.0.1/image.png',
        'https://192.168.1.2/image.png',
        'https://192.88.99.1/image.png',
        'https://169.254.1.2/image.png',
        'https://[::1]/image.png',
        'https://[fc00::1]/image.png',
        'https://[fe80::1]/image.png',
        'https://[2001::1]/image.png',
        'https://[2002:0808:0808::1]/image.png',
        'https://[3fff::1]/image.png',
        'https://localhost/image.png',
        'https://127.1/image.png',
        'https://user:secret@images.example.com/image.png',
        'https://images.example.com:8443/image.png',
      ]) {
        await expectLater(
          ClovaStudioProtocol.buildRequest('HCX-005', {
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
          throwsUnsupportedError,
          reason: url,
        );
      }

      final request = await ClovaStudioProtocol.buildRequest('HCX-005', {
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'https://cdn.example.com/image.png'},
              },
            ],
          },
        ],
      }, lookupHost: (host) async => [InternetAddress('8.8.8.8')]);
      final content =
          ((request['messages'] as List).first as Map)['content'] as List;
      expect(content, hasLength(1));
      expect((content.single as Map)['imageUrl'], {
        'url': 'https://cdn.example.com/image.png',
      });
    });

    test('rejects a hostname that resolves to a private address', () async {
      await expectLater(
        ClovaStudioProtocol.buildRequest('HCX-005', {
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'https://attacker.example/image.png'},
                },
              ],
            },
          ],
        }, lookupHost: (host) async => [InternetAddress('10.0.0.1')]),
        throwsUnsupportedError,
      );
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
          'event: result\ndata: {"status":{"code":"20000"},"result":{"message":{"content":"hello world"},"finishReason":"stop","usage":{"promptTokens":3,"completionTokens":2,"totalTokens":5}}}\n\n',
        );

        expect(first.textDelta, 'hello ');
        expect(second.textDelta, 'world');
        expect(terminal.textDelta, isNull);
        expect(terminal.done, isTrue);
        expect(terminal.finishReason, 'stop');
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
