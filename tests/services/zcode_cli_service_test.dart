import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:stroom/ai_gateway/ai_gateway_contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/zcode_cli_service.dart';

void main() {
  group('ZCode CLI launch policy', () {
    test('uses the fixed app-server argv and never a shell', () {
      const launch = ZcodeCliLaunch(executable: 'zcode');

      expect(launch.arguments, ['app-server']);
      expect(launch.runInShell, isFalse);
      expect(ZcodeCliLaunch.needsWindowsResolution('zcode'), isTrue);
      expect(
        ZcodeCliLaunch.needsWindowsResolution(r'C:\Tools\zcode.cmd'),
        isTrue,
      );
      expect(ZcodeCliLaunch.needsWindowsResolution('zcode.exe'), isFalse);
    });

    test('resolves only a validated npm shim to its JavaScript entrypoint', () {
      const shim = r'''@ECHO off
SETLOCAL
SET "_prog=node"
"%_prog%" "%dp0%\node_modules\@zai\zcode\bin\zcode.js" %*
''';

      expect(
        ZcodeCliLaunch.windowsNpmShimCommand(
          shimPath: r'C:\Users\me\AppData\Roaming\npm\zcode.cmd',
          shimContents: shim,
          nodePath: r'C:\Program Files\nodejs\node.exe',
        ),
        [
          r'C:\Program Files\nodejs\node.exe',
          r'C:\Users\me\AppData\Roaming\npm\node_modules\@zai\zcode\bin\zcode.js',
        ],
      );
      expect(
        ZcodeCliLaunch.windowsNpmShimCommand(
          shimPath: r'C:\Tools\zcode.cmd',
          shimContents: '@echo off\n%COMSPEC% /c echo unsafe',
          nodePath: r'C:\Program Files\nodejs\node.exe',
        ),
        isNull,
      );
      expect(
        ZcodeCliLaunch.windowsNpmShimCommand(
          shimPath: r'C:\Tools\zcode.cmd',
          shimContents: r'''"%dp0%\node_modules\@zai\zcode\..\outside.js"''',
          nodePath: r'C:\Program Files\nodejs\node.exe',
        ),
        isNull,
      );
    });
  });

  group('ZCode SocketProtocol codec', () {
    test(
      'round-trips typed serialized values and a length-prefixed RPC call',
      () {
        final value = [100, 9, 'zcode-agent', 'initialize'];
        final encoded = ZcodeSocketProtocol.encodeValue(value);
        final decoded = ZcodeSocketProtocol.decodeValue(encoded);

        expect(decoded.value, value);
        expect(decoded.offset, encoded.length);

        final frame = ZcodeSocketProtocol.encodeCall(
          9,
          'zcode-agent',
          'initialize',
          [
            {'workspacePath': '/private/workspace'},
          ],
        );
        expect(frame.length, greaterThan(13));
        expect(frame[0], 1);
        expect(ByteData.sublistView(frame).getUint32(9), frame.length - 13);
        expect(ZcodeSocketProtocol.decodeFrame(frame).header, [
          100,
          9,
          'zcode-agent',
          'initialize',
        ]);
      },
    );

    test(
      'rejects malformed lengths, unknown type tags, invalid JSON and IDs',
      () {
        expect(
          () => ZcodeSocketProtocol.decodeValue(Uint8List.fromList([99])),
          throwsFormatException,
        );
        expect(
          () => ZcodeSocketProtocol.decodeValue(Uint8List.fromList([1, 4, 65])),
          throwsFormatException,
        );
        expect(
          () => ZcodeSocketProtocol.encodeCall(-1, 'channel', 'method', []),
          throwsArgumentError,
        );
        expect(
          () =>
              ZcodeSocketProtocol.decodeValue(Uint8List.fromList([5, 1, 123])),
          throwsFormatException,
        );
        final malformedFrame = Uint8List.fromList(
          ZcodeSocketProtocol.encodeCall(9, 'channel', 'method', []),
        )..[9] = 1;
        expect(
          () => ZcodeSocketProtocol.decodeFrame(malformedFrame),
          throwsFormatException,
        );
      },
    );
  });

  group('ZCode model selection', () {
    final view = {
      'providers': [
        {
          'providerId': 'builtin:zai-coding-plan',
          'models': [
            {
              'modelId': 'glm-5.3-flash',
              'config': {
                'enabled': true,
                'optionSpecs': {
                  'maxOutputTokens': {'max': 32768},
                  'reasoningLevel': {
                    'values': ['low', 'high'],
                  },
                },
              },
            },
            {
              'modelId': 'glm-5.3-high',
              'config': {'enabled': true},
            },
            {
              'modelId': 'glm-5.3',
              'config': {},
            },
          ],
        },
        {
          'providerId': 'account:zai-individual-coding-plan',
          'models': [
            {
              'modelId': 'glm-5.3-flash',
              'config': {
                'enabled': true,
                'optionSpecs': {
                  'reasoningLevel': {
                    'values': ['low', 'high'],
                  },
                },
              },
            },
            {
              'modelId': 'glm-5.2',
              'config': {'enabled': false},
            },
          ],
        },
      ],
    };

    test(
      'prefers an enabled account Coding Plan model and inherits native limits',
      () {
        final selection = resolveZcodeModelSelection(view, 'glm-5.3-flash');

        expect(selection.providerId, 'account:zai-individual-coding-plan');
        expect(selection.modelId, 'glm-5.3-flash');
        expect(selection.reasoningLevel, 'high');
        expect(resolveZcodeMaxOutputTokens(view, 'glm-5.3-flash'), 32768);
      },
    );

    test(
      'rejects disabled and non-Coding-Plan models without provider fallback',
      () {
        expect(
          () => resolveZcodeModelSelection(view, 'glm-5.2'),
          throwsA(
            isA<ZcodeCliException>().having(
              (error) => error.code,
              'signed out or model unavailable',
              'model_unavailable',
            ),
          ),
        );
        expect(
          () => resolveZcodeModelSelection(view, 'other-provider/model'),
          throwsA(isA<ZcodeCliException>()),
        );
      },
    );

    test('matches native model IDs case-insensitively and preserves native ID',
        () {
      final caseVariant = {
        'providers': [
          {
            'providerId': 'account:zai-individual-coding-plan',
            'models': [
              {
                'modelId': 'GLM-5.3-Flash',
                'config': {'enabled': true},
              },
            ],
          },
        ],
      };

      final selection = resolveZcodeModelSelection(
        caseVariant,
        'glm-5.3-flash',
      );

      expect(selection.modelId, 'GLM-5.3-Flash');
    });

    test(
        'selects a built-in Coding Plan model when the account catalog lacks it',
        () {
      final selection = resolveZcodeModelSelection(view, 'glm-5.3');

      expect(selection.providerId, 'builtin:zai-coding-plan');
      expect(selection.modelId, 'glm-5.3');
    });
  });

  group('ZCode Chat Completions mapping', () {
    test('preserves full history, tool call IDs, and tool result identity', () {
      final request = ZcodeChatRequest.fromChatCompletionsBody({
        'messages': [
          {'role': 'system', 'content': 'rules'},
          {'role': 'user', 'content': 'first'},
          {
            'role': 'assistant',
            'content': 'checking',
            'tool_calls': [
              {
                'id': 'call-7',
                'type': 'function',
                'function': {'name': 'lookup', 'arguments': '{"q":"x"}'},
              },
            ],
          },
          {
            'role': 'tool',
            'tool_call_id': 'call-7',
            'name': 'lookup',
            'content': 'found',
          },
          {'role': 'user', 'content': 'continue'},
        ],
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'lookup',
              'description': 'Look up a record',
              'parameters': {'type': 'object'},
            },
          },
        ],
      });

      expect(request.messages.map((message) => message.role), [
        'system',
        'user',
        'assistant',
        'tool',
        'user',
      ]);
      expect(request.messages[2].toolCalls.single.id, 'call-7');
      expect(request.messages[3].toolCallId, 'call-7');
      expect(request.messages[3].toolName, 'lookup');
      expect(request.tools.single.name, 'lookup');
    });

    test(
      'accepts data images only for vision models and rejects other media',
      () {
        final dataUrl = 'data:image/png;base64,${base64Encode([1, 2, 3])}';
        final body = {
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'describe'},
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUrl},
                },
              ],
            },
          ],
        };

        expect(
          ZcodeChatRequest.fromChatCompletionsBody(
            body,
            modelSupportsVision: true,
          ).messages.single.images.single.dataUrl,
          dataUrl,
        );
        expect(
          ZcodeChatRequest.fromChatCompletionsBody(
            {
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': dataUrl.replaceFirst('data:', 'DATA:')
                      },
                    },
                  ],
                },
              ],
            },
            modelSupportsVision: true,
          ).messages.single.images.single.mediaType,
          'image/png',
        );
        expect(
          () => ZcodeChatRequest.fromChatCompletionsBody(
            body,
            modelSupportsVision: false,
          ),
          throwsA(isA<ZcodeCliException>()),
        );
        expect(
          () => ZcodeChatRequest.fromChatCompletionsBody({
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'input_audio', 'data': '...'},
                ],
              },
            ],
          }),
          throwsA(isA<ZcodeCliException>()),
        );
        expect(
          () => ZcodeChatRequest.fromChatCompletionsBody({
            'messages': [
              {'role': 'user', 'content': 'text'},
            ],
            'video': 'unsupported',
          }),
          throwsA(isA<ZcodeCliException>()),
        );
      },
    );

    test('fetches public image URLs through the injected bounded resolver',
        () async {
      final process = _FakeZcodeProcess(modelView: _enabledView);
      final fetchedUris = <Uri>[];
      final service = ZcodeCliService(
        launcher: _FakeZcodeLauncher(process),
        supportsLocalProcess: () => true,
        imageFetcher: (uri, _) async {
          fetchedUris.add(uri);
          return ZcodeFetchedImage(
            Uint8List.fromList([1, 2, 3]),
            'image/jpg',
          );
        },
      );

      await service.request(
        modelId: 'glm-5.3-flash',
        body: {
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'describe'},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'https://images.example/photo'},
                },
              ],
            },
          ],
        },
      );

      expect(fetchedUris, [Uri.parse('https://images.example/photo')]);
      final sentMessages = process.generationRequest!['messages'] as List;
      final sentImage =
          ((sentMessages.single as Map)['content'] as List).last as Map;
      expect(sentImage['mediaType'], 'image/jpeg');
      expect(sentImage['dataUrl'], 'data:image/jpeg;base64,AQID');
    });

    test('DNS lookup for remote images is bounded and cancellable', () async {
      final lookupStarted = Completer<void>();
      final pendingLookup = Completer<List<InternetAddress>>();
      final launcher = _FakeZcodeLauncher(
        _FakeZcodeProcess(modelView: _enabledView),
      );
      final service = ZcodeCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
        imageAddressLookup: (_) {
          lookupStarted.complete();
          return pendingLookup.future;
        },
        imageDnsTimeout: const Duration(seconds: 2),
      );
      final token = CancelToken();
      final request = service.request(
        modelId: 'glm-5.3-flash',
        body: {
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'https://images.example/photo'},
                },
              ],
            },
          ],
        },
        cancelToken: token,
      );
      await lookupStarted.future;
      token.cancel('test cancellation during DNS');
      await expectLater(
        request,
        throwsA(isA<ZcodeCliException>()
            .having((e) => e.code, 'code', 'cancelled')),
      );
      expect(launcher.calls, isEmpty);
    });

    test('DNS lookup timeout rejects a remote image before launch', () async {
      final launcher = _FakeZcodeLauncher(
        _FakeZcodeProcess(modelView: _enabledView),
      );
      final service = ZcodeCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
        imageAddressLookup: (_) => Completer<List<InternetAddress>>().future,
        imageDnsTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.request(
          modelId: 'glm-5.3-flash',
          body: {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'https://images.example/photo'},
                  },
                ],
              },
            ],
          },
        ),
        throwsA(isA<ZcodeCliException>()
            .having((e) => e.code, 'code', 'image_dns_timeout')),
      );
      expect(launcher.calls, isEmpty);
    });

    test('blocks private image URLs before calling the image fetcher',
        () async {
      var fetchCalled = false;
      final launcher = _FakeZcodeLauncher(
        _FakeZcodeProcess(modelView: _enabledView),
      );
      final service = ZcodeCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
        imageFetcher: (uri, _) async {
          fetchCalled = true;
          return ZcodeFetchedImage(Uint8List.fromList([1]), 'image/png');
        },
      );

      await expectLater(
        service.request(
          modelId: 'glm-5.3-flash',
          body: {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'http://127.0.0.1/private.png'},
                  },
                ],
              },
            ],
          },
        ),
        throwsA(isA<ZcodeCliException>()),
      );
      expect(fetchCalled, isFalse);
      expect(launcher.calls, isEmpty);
    });

    test('rejects an aggregate image frame overflow before sending', () async {
      final process = _FakeZcodeProcess(modelView: _enabledView);
      final service = ZcodeCliService(
        launcher: _FakeZcodeLauncher(process),
        supportsLocalProcess: () => true,
        imageFetcher: (_, _) async => ZcodeFetchedImage(
          Uint8List(7 * 1024 * 1024),
          'image/png',
        ),
      );
      var requestSent = false;

      await expectLater(
        service.request(
          modelId: 'glm-5.3-flash',
          body: {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'https://images.example/one.png'},
                  },
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'https://images.example/two.png'},
                  },
                ],
              },
            ],
          },
          onRequestSent: () async => requestSent = true,
        ),
        throwsA(isA<ZcodeCliException>().having(
          (error) => error.code,
          'code',
          'invalid_request',
        )),
      );
      expect(requestSent, isFalse);
      expect(process.rpcMethods, isNot(contains('generateWorkspaceText')));
      expect(process.terminated, isTrue);
    });

    test('rejects an oversized fetched image before launching ZCode', () async {
      final launcher = _FakeZcodeLauncher(
        _FakeZcodeProcess(modelView: _enabledView),
      );
      final service = ZcodeCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
        imageFetcher: (_, _) async => ZcodeFetchedImage(
          Uint8List(10 * 1024 * 1024 + 1),
          'image/png',
        ),
      );

      await expectLater(
        service.request(
          modelId: 'glm-5.3-flash',
          body: {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'https://images.example/large.png'},
                  },
                ],
              },
            ],
          },
        ),
        throwsA(isA<ZcodeCliException>()),
      );
      expect(launcher.calls, isEmpty);
    });

    test(
      'validates output token bounds and rejects malformed tool payloads',
      () {
        expect(
          () => ZcodeChatRequest.fromChatCompletionsBody({
            'messages': [
              {'role': 'user', 'content': 'hi'},
            ],
            'max_tokens': 0,
          }),
          throwsA(isA<ZcodeCliException>()),
        );
        expect(
          () => ZcodeChatRequest.fromChatCompletionsBody({
            'messages': [
              {'role': 'tool', 'tool_call_id': 'missing', 'content': 'result'},
            ],
          }),
          throwsA(isA<ZcodeCliException>()),
        );
      },
    );
  });

  group('ZCode local app-server peer', () {
    test(
      'status distinguishes model readiness and removes its private workspace',
      () async {
        final process = _FakeZcodeProcess(
          modelView: {
            'providers': [
              {
                'providerId': 'account:zai-individual-coding-plan',
                'models': [
                  {
                    'modelId': 'glm-5.3-flash',
                    'config': {'enabled': true},
                  },
                ],
              },
            ],
          },
        );
        final service = ZcodeCliService(
          launcher: _FakeZcodeLauncher(process),
          supportsLocalProcess: () => true,
        );

        expect((await service.status()).status, ZcodeServerStatus.ready);
        expect(await Directory(process.workspacePath!).exists(), isFalse);
        expect(process.terminated, isTrue);
      },
    );

    test(
        'builtin Coding Plan remains ready when account provider is signed out',
        () async {
      final process = _FakeZcodeProcess(
        modelView: {
          'providers': [
            {
              'providerId': 'account:zai-individual-coding-plan',
              'authenticated': false,
              'models': [],
            },
            {
              'providerId': 'builtin:zai-coding-plan',
              'models': [
                {
                  'modelId': 'glm-5.3-flash',
                  'config': {'enabled': true},
                },
              ],
            },
          ],
        },
      );
      final service = ZcodeCliService(
        launcher: _FakeZcodeLauncher(process),
        supportsLocalProcess: () => true,
      );

      expect((await service.status()).status, ZcodeServerStatus.ready);
      expect(process.terminated, isTrue);
    });

    test('signed-out and no-enabled-model status are distinct', () async {
      final noModels = _FakeZcodeProcess(modelView: {'providers': []});
      final noModelsService = ZcodeCliService(
        launcher: _FakeZcodeLauncher(noModels),
        supportsLocalProcess: () => true,
      );
      expect(
        (await noModelsService.status()).status,
        ZcodeServerStatus.modelServiceNotReady,
      );

      final signedOut = _FakeZcodeProcess(
        modelView: {
          'providers': [
            {
              'providerId': 'account:zai-individual-coding-plan',
              'authenticated': false,
              'models': [],
            },
          ],
        },
      );
      final signedOutService = ZcodeCliService(
        launcher: _FakeZcodeLauncher(signedOut),
        supportsLocalProcess: () => true,
      );
      expect(
        (await signedOutService.status()).status,
        ZcodeServerStatus.signedOut,
      );
    });

    test('request waits for the selected Coding Plan model to hydrate',
        () async {
      final process = _FakeZcodeProcess(
        modelView: {'providers': []},
        modelViews: [
          {'providers': []},
          _enabledView,
        ],
      );
      final service = ZcodeCliService(
        launcher: _FakeZcodeLauncher(process),
        supportsLocalProcess: () => true,
      );

      final response = await service.request(
        modelId: 'glm-5.3-flash',
        body: {
          'messages': [
            {'role': 'user', 'content': 'ready when available'},
          ],
        },
      );

      expect((response.body as Map)['choices'], isNotEmpty);
      expect(
        process.rpcMethods.where((method) => method == 'getView'),
        hasLength(2),
      );
      expect(process.rpcMethods.last, 'generateWorkspaceText');
      expect(process.terminated, isTrue);
    });

    test('streaming returns byte chunks in Chat Completions SSE format',
        () async {
      final process = _FakeZcodeProcess(
        modelView: _enabledView,
        generationResult: {
          'text': 'buffered answer',
          'usage': {'inputTokens': 3, 'outputTokens': 2},
        },
      );
      final service = ZcodeCliService(
        launcher: _FakeZcodeLauncher(process),
        supportsLocalProcess: () => true,
      );

      final response = await service.request(
        modelId: 'glm-5.3-flash',
        body: {
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        },
        stream: true,
      );
      final byteStream = response.body as Stream<List<int>>;
      final sse =
          utf8.decode(await byteStream.expand((chunk) => chunk).toList());

      expect(sse, contains('data: {"id":"chatcmpl-zcode-'));
      expect(sse, contains('"object":"chat.completion.chunk"'));
      expect(sse, contains('data: [DONE]'));
      expect(process.terminated, isTrue);
    });

    test('request preserves mixed text and image content order', () async {
      final process = _FakeZcodeProcess(modelView: _enabledView);
      final service = ZcodeCliService(
        launcher: _FakeZcodeLauncher(process),
        supportsLocalProcess: () => true,
      );
      await service.request(
        modelId: 'glm-5.3-flash',
        body: {
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'before'},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/png;base64,${base64Encode([1, 2])}',
                  },
                },
                {'type': 'text', 'text': 'after'},
              ],
            },
          ],
        },
      );

      final content = ((process.generationRequest!['messages'] as List).single
          as Map)['content'] as List;
      expect(
        content.map((part) => (part as Map)['type']),
        ['text', 'image', 'text'],
      );
      expect((content[0] as Map)['text'], 'before');
      expect((content[1] as Map)['mediaType'], 'image/png');
      expect((content[2] as Map)['text'], 'after');
    });

    test(
      'request preserves returned tool calls and cleans the empty Chat workspace',
      () async {
        final process = _FakeZcodeProcess(
          modelView: _enabledView,
          generationResult: {
            'text': 'I will call the tool.',
            'toolCalls': [
              {
                'id': 'call-9',
                'name': 'lookup',
                'input': {'key': 'v'},
              },
            ],
            'usage': {'inputTokens': 12, 'outputTokens': 3},
          },
        );
        final service = ZcodeCliService(
          launcher: _FakeZcodeLauncher(process),
          supportsLocalProcess: () => true,
        );

        final response = await service.request(
          modelId: 'glm-5.3-flash',
          body: {
            'messages': [
              {'role': 'user', 'content': 'search'},
              {
                'role': 'assistant',
                'content': 'checking',
                'tool_calls': [
                  {
                    'id': 'call-9-request',
                    'type': 'function',
                    'function': {'name': 'lookup', 'arguments': '{"key":"v"}'},
                  },
                ],
              },
              {
                'role': 'tool',
                'tool_call_id': 'call-9-request',
                'name': 'lookup',
                'content': 'tool result',
              },
            ],
            'tools': [
              {
                'type': 'function',
                'function': {
                  'name': 'lookup',
                  'parameters': {'type': 'object'},
                },
              },
            ],
          },
        );
        final completion = response.body as Map;
        final choice = (completion['choices'] as List).single as Map;
        final message = choice['message'] as Map;

        expect(message['content'], 'I will call the tool.');
        expect((message['tool_calls'] as List).single['id'], 'call-9');
        expect(
          process.generationRequest!['workspacePath'],
          process.workspacePath,
        );
        expect(process.generationRequest!['tools'], hasLength(1));
        final sentMessages = process.generationRequest!['messages'] as List;
        expect(
          (sentMessages[1] as Map)['toolCalls'].single['id'],
          'call-9-request',
        );
        expect((sentMessages[2] as Map)['toolCallId'], 'call-9-request');
        expect((sentMessages[2] as Map)['toolName'], 'lookup');
        expect(await Directory(process.workspacePath!).exists(), isFalse);
        expect(process.terminated, isTrue);
      },
    );

    test(
      'unsupported media is rejected before starting a local process',
      () async {
        final launcher = _FakeZcodeLauncher(
          _FakeZcodeProcess(modelView: _enabledView),
        );
        final service = ZcodeCliService(
          launcher: launcher,
          supportsLocalProcess: () => true,
        );

        await expectLater(
          service.request(
            modelId: 'glm-5.3-flash',
            body: {
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'input_audio', 'data': 'not forwarded'},
                  ],
                },
              ],
            },
          ),
          throwsA(isA<ZcodeCliException>()),
        );
        expect(launcher.calls, isEmpty);
      },
    );

    test(
      'Chat request cannot override the isolated subprocess workspace',
      () async {
        final launcher = _FakeZcodeLauncher(
          _FakeZcodeProcess(modelView: _enabledView),
        );
        final service = ZcodeCliService(
          launcher: launcher,
          supportsLocalProcess: () => true,
        );

        await expectLater(
          service.request(
            modelId: 'glm-5.3-flash',
            body: {
              'messages': [
                {'role': 'user', 'content': 'read this'},
              ],
              'workspacePath': Directory.current.path,
            },
          ),
          throwsA(isA<ZcodeCliException>()),
        );
        expect(launcher.calls, isEmpty);
      },
    );

    test(
      'native max output token limit clamps caller requests',
      () async {
        final process = _FakeZcodeProcess(modelView: _enabledView);
        final service = ZcodeCliService(
          launcher: _FakeZcodeLauncher(process),
          supportsLocalProcess: () => true,
        );

        await service.request(
          modelId: 'glm-5.3-flash',
          body: {
            'messages': [
              {'role': 'user', 'content': 'long answer'},
            ],
            'max_tokens': 65537,
          },
        );

        expect(process.generationRequest!['maxOutputTokens'], 65536);
      },
    );

    test('pending RPCs fail after disconnect and bounded timeout', () async {
      final disconnectedProcess = _FakeZcodeProcess(
        modelView: _enabledView,
        disconnectOnMethod: 'initialize',
      );
      final disconnectedClient = ZcodeAppServerClient(
        launcher: _FakeZcodeLauncher(disconnectedProcess),
        launch: const ZcodeCliLaunch(executable: 'fake-zcode'),
        requestTimeout: const Duration(milliseconds: 100),
      );
      await disconnectedClient.start(Directory.systemTemp.path);
      await expectLater(
        disconnectedClient.call('zcode-agent', 'initialize', const []),
        throwsA(isA<ZcodeCliException>()),
      );
      await disconnectedClient.close();
      expect(disconnectedProcess.terminated, isTrue);

      final timeoutProcess = _FakeZcodeProcess(
        modelView: _enabledView,
        hangOnMethod: 'initialize',
      );
      final timeoutClient = ZcodeAppServerClient(
        launcher: _FakeZcodeLauncher(timeoutProcess),
        launch: const ZcodeCliLaunch(executable: 'fake-zcode'),
        requestTimeout: const Duration(milliseconds: 10),
      );
      await timeoutClient.start(Directory.systemTemp.path);
      await expectLater(
        timeoutClient.call('zcode-agent', 'initialize', const []),
        throwsA(
          isA<ZcodeCliException>().having(
            (error) => error.code,
            'timeout code',
            'request_timeout',
          ),
        ),
      );
      await timeoutClient.close();
      expect(timeoutProcess.terminated, isTrue);
    });

    test(
      'repeated close calls wait for the same process cleanup',
      () async {
        final terminateGate = Completer<void>();
        final process = _FakeZcodeProcess(
          modelView: _enabledView,
          terminateGate: terminateGate,
        );
        final client = ZcodeAppServerClient(
          launcher: _FakeZcodeLauncher(process),
          launch: const ZcodeCliLaunch(executable: 'fake-zcode'),
        );
        await client.start(Directory.systemTemp.path);

        final firstClose = client.close();
        final secondClose = client.close();
        var secondCloseCompleted = false;
        unawaited(secondClose.then((_) => secondCloseCompleted = true));
        await Future<void>.delayed(Duration.zero);
        expect(secondCloseCompleted, isFalse);

        terminateGate.complete();
        await Future.wait([firstClose, secondClose]);
        expect(secondCloseCompleted, isTrue);
        expect(process.terminated, isTrue);
      },
    );

    test(
      'cancellation closes the peer process and private workspace',
      () async {
        final process = _FakeZcodeProcess(
          modelView: _enabledView,
          hangOnGenerate: true,
        );
        final service = ZcodeCliService(
          launcher: _FakeZcodeLauncher(process),
          supportsLocalProcess: () => true,
        );
        final token = CancelToken();
        final request = service.request(
          modelId: 'glm-5.3-flash',
          body: {
            'messages': [
              {'role': 'user', 'content': 'wait'},
            ],
          },
          cancelToken: token,
        );
        await process.generateStarted.future;
        token.cancel('test cancellation');

        await expectLater(request, throwsA(isA<ZcodeCliException>()));
        expect(process.terminated, isTrue);
        expect(await Directory(process.workspacePath!).exists(), isFalse);
      },
    );

    test(
      'cancellation during process launch terminates the late process',
      () async {
        final process = _FakeZcodeProcess(modelView: _enabledView);
        final launchCompleter = Completer<ZcodeCliProcess>();
        final client = ZcodeAppServerClient(
          launcher: _DeferredZcodeLauncher(launchCompleter.future),
          launch: const ZcodeCliLaunch(executable: 'fake-zcode'),
        );
        final start = client.start(Directory.systemTemp.path);
        await Future<void>.delayed(Duration.zero);
        await client.close();
        launchCompleter.complete(process);

        await expectLater(
          start,
          throwsA(isA<ZcodeCliException>()),
        );
        expect(process.terminated, isTrue);
      },
    );

    test(
      'startup timeout terminates a peer that never sends its hello',
      () async {
        final process = _FakeZcodeProcess(
          modelView: _enabledView,
          sendHello: false,
        );
        final client = ZcodeAppServerClient(
          launcher: _FakeZcodeLauncher(process),
          launch: const ZcodeCliLaunch(executable: 'fake-zcode'),
          startupTimeout: const Duration(milliseconds: 10),
        );

        await expectLater(
          client.start(Directory.systemTemp.path),
          throwsA(isA<ZcodeCliException>()),
        );
        await client.close();
        expect(process.terminated, isTrue);
      },
    );

    test('waits for the server-ready frame before sending RPCs', () async {
      final process = _FakeZcodeProcess(
        modelView: _enabledView,
        sendInitialized: false,
      );
      final client = ZcodeAppServerClient(
        launcher: _FakeZcodeLauncher(process),
        launch: const ZcodeCliLaunch(executable: 'fake-zcode'),
      );
      final start = client.start(Directory.systemTemp.path);

      await process.helloAcknowledged.future;
      await Future<void>.delayed(Duration.zero);
      expect(process.rpcMethods, isEmpty);
      process.emitInitializeMessage();
      await start;
      expect(process.rpcMethods, isEmpty);

      await client.call('zcode-agent', 'initialize', const []);
      expect(process.rpcMethods, ['initialize']);
      await client.close();
      expect(process.terminated, isTrue);
    });

    test('rejects an oversized hello even when its newline is in the chunk',
        () async {
      final process = _FakeZcodeProcess(
        modelView: _enabledView,
        helloPayload: '{"type":"zcode-hello","padding":"${'x' * (64 * 1024)}"}',
      );
      final client = ZcodeAppServerClient(
        launcher: _FakeZcodeLauncher(process),
        launch: const ZcodeCliLaunch(executable: 'fake-zcode'),
      );

      await expectLater(
        client.start(Directory.systemTemp.path),
        throwsA(isA<ZcodeCliException>().having(
          (error) => error.code,
          'protocol error code',
          'protocol_error',
        )),
      );
      await client.close();
      expect(process.terminated, isTrue);
    });

    test('invalid hello is a safe protocol error and closes the peer',
        () async {
      final process = _FakeZcodeProcess(
        modelView: _enabledView,
        helloPayload: '{"type":"unexpected"}',
      );
      final client = ZcodeAppServerClient(
        launcher: _FakeZcodeLauncher(process),
        launch: const ZcodeCliLaunch(executable: 'fake-zcode'),
      );

      await expectLater(
        client.start(Directory.systemTemp.path),
        throwsA(isA<ZcodeCliException>().having(
          (error) => error.code,
          'protocol error code',
          'protocol_error',
        )),
      );
      await client.close();
      expect(process.terminated, isTrue);
    });

    test('Gateway error messages never include local CLI details', () {
      final error = AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
        code: 'zcode_server_unavailable',
      );
      expect(error.toString(), contains('ZCode app-server is unavailable'));
      expect(error.toString(), isNot(contains('/home/')));
      expect(error.toString(), isNot(contains('token')));
    });
  });
}

final _enabledView = {
  'providers': [
    {
      'providerId': 'account:zai-individual-coding-plan',
      'models': [
        {
          'modelId': 'glm-5.3-flash',
          'config': {
            'enabled': true,
            'optionSpecs': {
              'maxOutputTokens': {'max': 65536},
            },
          },
        },
      ],
    },
  ],
};

class _DeferredZcodeLauncher implements ZcodeCliProcessLauncher {
  final Future<ZcodeCliProcess> processFuture;

  _DeferredZcodeLauncher(this.processFuture);

  @override
  Future<ZcodeCliProcess> start(
    ZcodeCliLaunch launch, {
    required String workingDirectory,
  }) =>
      processFuture;
}

class _FakeZcodeLauncher implements ZcodeCliProcessLauncher {
  final _FakeZcodeProcess process;
  final calls = <String>[];

  _FakeZcodeLauncher(this.process);

  @override
  Future<ZcodeCliProcess> start(
    ZcodeCliLaunch launch, {
    required String workingDirectory,
  }) async {
    calls.add(workingDirectory);
    process.workspacePath = workingDirectory;
    process.start();
    return process;
  }
}

class _FakeZcodeProcess implements ZcodeCliProcess {
  final Object? modelView;
  final List<Object?>? modelViews;
  final Object? generationResult;
  int _modelViewIndex = 0;
  final bool hangOnGenerate;
  final String? hangOnMethod;
  final String? disconnectOnMethod;
  final bool sendHello;
  final bool sendInitialized;
  final String helloPayload;
  final Completer<void>? terminateGate;
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exited = Completer<int>();
  final generateStarted = Completer<void>();
  final helloAcknowledged = Completer<void>();
  String? workspacePath;
  Map<String, dynamic>? generationRequest;
  final rpcMethods = <String>[];
  bool _gotHelloAck = false;
  bool terminated = false;

  _FakeZcodeProcess({
    required this.modelView,
    this.modelViews,
    this.generationResult = const {'text': 'ok'},
    this.hangOnGenerate = false,
    this.hangOnMethod,
    this.disconnectOnMethod,
    this.sendHello = true,
    this.sendInitialized = true,
    this.helloPayload = '{"type":"zcode-hello"}',
    this.terminateGate,
  });

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exited.future;

  void start() {
    if (sendHello) {
      _stdout.add(utf8.encode('$helloPayload\n'));
    }
  }

  @override
  void writeStdin(List<int> bytes) {
    if (!_gotHelloAck) {
      _gotHelloAck = true;
      if (!helloAcknowledged.isCompleted) helloAcknowledged.complete();
      if (sendInitialized) emitInitializeMessage();
      return;
    }
    final frame = ZcodeSocketProtocol.decodeFrame(Uint8List.fromList(bytes));
    final header = frame.header as List;
    final type = header[0] as int;
    final id = header[1] as int;
    final channel = header[2] as String;
    final method = header[3] as String;
    rpcMethods.add(method);
    final arguments = frame.payload as List;
    if (method == disconnectOnMethod) {
      unawaited(disconnect());
      return;
    }
    if (method == hangOnMethod) return;
    if (channel == 'zcode-agent' && method == 'initialize') {
      _sendResponse(type, id, const {'available': true});
    } else if (channel == 'model-selection' && method == 'getView') {
      final views = modelViews;
      final view = views == null
          ? modelView
          : views[_modelViewIndex.clamp(0, views.length - 1)];
      _modelViewIndex++;
      _sendResponse(type, id, view);
    } else if (channel == 'zcode-agent' && method == 'generateWorkspaceText') {
      generationRequest = Map<String, dynamic>.from(arguments.single as Map);
      if (!generateStarted.isCompleted) generateStarted.complete();
      if (!hangOnGenerate) _sendResponse(type, id, generationResult);
    } else {
      _sendResponse(type, id, const {});
    }
  }

  void _sendResponse(int requestType, int id, Object? value) {
    final payload = _join([
      ZcodeSocketProtocol.encodeValue([201, id]),
      ZcodeSocketProtocol.encodeValue(value),
    ]);
    final frame = Uint8List(13 + payload.length);
    final header = ByteData.sublistView(frame);
    header.setUint8(0, 1);
    header.setUint32(1, 0);
    header.setUint32(5, 0);
    header.setUint32(9, payload.length);
    frame.setRange(13, frame.length, payload);
    _stdout.add(frame);
  }

  void emitInitializeMessage() {
    final payload = _join([
      ZcodeSocketProtocol.encodeValue([200]),
      ZcodeSocketProtocol.encodeValue(null),
    ]);
    final frame = Uint8List(13 + payload.length);
    final header = ByteData.sublistView(frame);
    header.setUint8(0, 1);
    header.setUint32(1, 0);
    header.setUint32(5, 0);
    header.setUint32(9, payload.length);
    frame.setRange(13, frame.length, payload);
    _stdout.add(frame);
  }

  Uint8List _join(List<List<int>> parts) {
    final builder = BytesBuilder(copy: false);
    for (final part in parts) {
      builder.add(part);
    }
    return builder.takeBytes();
  }

  @override
  Future<void> closeStdin() async {}

  Future<void> disconnect() async {
    if (!_exited.isCompleted) _exited.complete(1);
    await _stdout.close();
    await _stderr.close();
  }

  @override
  Future<void> terminate({bool force = false}) async {
    if (terminated) return;
    await terminateGate?.future;
    terminated = true;
    if (!_exited.isCompleted) _exited.complete(0);
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }
}
