import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/auggie_cli_service.dart';

void main() {
  group('Windows Auggie launcher resolution', () {
    test('npm command shim is converted to a shell-free Node argv', () {
      const shim = r'''@ECHO off
SETLOCAL
SET "_prog=node"
"%_prog%" "%dp0%\node_modules\@augmentcode\auggie\bin\auggie.js" %*
''';

      expect(
        IoAuggieCliProcessLauncher.windowsNpmShimCommand(
          shimPath: r'C:\Users\me\AppData\Roaming\npm\auggie.cmd',
          shimContents: shim,
          nodePath: r'C:\Program Files\nodejs\node.exe',
        ),
        [
          r'C:\Program Files\nodejs\node.exe',
          r'C:\Users\me\AppData\Roaming\npm\node_modules\@augmentcode\auggie\bin\auggie.js',
        ],
      );
    });

    test('unsupported batch shims are not interpreted as shell commands', () {
      expect(
        IoAuggieCliProcessLauncher.windowsNpmShimCommand(
          shimPath: r'C:\Tools\auggie.cmd',
          shimContents: '@echo off\n%COMSPEC% /c echo unsafe',
          nodePath: r'C:\Program Files\nodejs\node.exe',
        ),
        isNull,
      );
    });
  });

  group('Auggie CLI model and prompt safety', () {
    test('static catalog preserves source context metadata', () {
      final catalog = AuggieCliService.pinnedModels;

      expect(catalog.first.id, 'sonnet4.6');
      expect(catalog.first.contextLength, 200000);
      expect(
        catalog
            .singleWhere((model) => model.id == 'sonnet4.6-500k')
            .contextLength,
        500000,
      );
      expect(
        catalog
            .singleWhere((model) => model.id == 'gemini-3.1-pro-preview')
            .contextLength,
        1000000,
      );
    });

    test('model resolution accepts only static or discovered ids', () async {
      final launcher = _FakeLauncher()
        ..enqueue(_FakeProcess(output: '[custom-model]\n'));
      final service = AuggieCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
      );
      await service.discoverModels(refresh: true);

      expect(service.resolveModel('custom-model'), 'custom-model');
      expect(
        () => service.resolveModel('--help'),
        throwsA(isA<AuggieCliException>()),
      );
      expect(
        () => service.resolveModel('not-a-model'),
        throwsA(isA<AuggieCliException>()),
      );
      expect(launcher.calls.single.arguments, ['model', 'list']);
    });

    test('live model catalog is capped and replaced on successful refresh',
        () async {
      final firstOutput = List.generate(
        300,
        (index) => '[custom-model-$index]',
      ).join('\n');
      final launcher = _FakeLauncher()
        ..enqueue(_FakeProcess(output: firstOutput))
        ..enqueue(_FakeProcess(output: '[second-refresh-only]'));
      final service = AuggieCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
      );

      final firstCatalog = await service.discoverModels(refresh: true);
      expect(
        firstCatalog.length,
        AuggieCliService.pinnedModels.length + 256,
      );
      expect(service.resolveModel('custom-model-0'), 'custom-model-0');

      final secondCatalog = await service.discoverModels(refresh: true);
      expect(
        secondCatalog.any((model) => model.id == 'custom-model-0'),
        isFalse,
      );
      expect(
        secondCatalog.any((model) => model.id == 'second-refresh-only'),
        isTrue,
      );
      expect(
        () => service.resolveModel('custom-model-0'),
        throwsA(isA<AuggieCliException>()),
      );
    });

    test('prompt keeps role-labelled history in order', () {
      expect(
        AuggieCliService.buildPrompt([
          {'role': 'system', 'content': 'rules'},
          {'role': 'assistant', 'content': 'first answer'},
          {'role': 'user', 'content': 'next question'},
        ]),
        '[System]\nrules\n\n[Assistant]\nfirst answer\n\n[User]\nnext question',
      );
    });

    test(
      'unsupported tools and media are rejected before process launch',
      () async {
        final launcher = _FakeLauncher();
        final service = AuggieCliService(
          launcher: launcher,
          supportsLocalProcess: () => true,
        );

        await expectLater(
          service.request(
            modelId: 'sonnet4.6',
            body: {
              'messages': [
                {
                  'role': 'assistant',
                  'content': 'call',
                  'tool_calls': [
                    {'id': 'call-1'},
                  ],
                },
              ],
            },
            stream: false,
          ),
          throwsA(
            isA<AuggieCliException>().having(
              (error) => error.code,
              'Auggie-specific unsupported capability code',
              'auggie_unsupported_capability',
            ),
          ),
        );
        await expectLater(
          service.request(
            modelId: 'sonnet4.6',
            body: {
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'https://example.test/x.png'},
                    },
                  ],
                },
              ],
            },
            stream: false,
          ),
          throwsA(isA<AuggieCliException>()),
        );

        for (final mediaKey in ['image_url', 'audio']) {
          await expectLater(
            service.request(
              modelId: 'sonnet4.6',
              body: {
                'messages': [
                  {
                    'role': 'user',
                    'content': 'text beside unsupported media',
                    mediaKey: {'data': 'omitted'},
                  },
                ],
              },
              stream: false,
            ),
            throwsA(isA<AuggieCliException>()),
          );
          await expectLater(
            service.request(
              modelId: 'sonnet4.6',
              body: {
                'messages': [
                  {'role': 'user', 'content': 'text beside unsupported media'},
                ],
                mediaKey: {'data': 'omitted'},
              },
              stream: false,
            ),
            throwsA(isA<AuggieCliException>()),
          );
          await expectLater(
            service.request(
              modelId: 'sonnet4.6',
              body: {
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {
                        'type': 'text',
                        'text': 'text beside unsupported media',
                        mediaKey: {'data': 'omitted'},
                      },
                    ],
                  },
                ],
              },
              stream: false,
            ),
            throwsA(isA<AuggieCliException>()),
          );
        }

        expect(launcher.calls, isEmpty);
      },
    );
  });

  group('Auggie CLI process behavior', () {
    test(
      'connection test runs only version and retains no CLI output',
      () async {
        final launcher = _FakeLauncher()
          ..enqueue(_FakeProcess(output: 'Auggie v0.32.0\n'));
        final service = AuggieCliService(
          launcher: launcher,
          supportsLocalProcess: () => true,
        );

        final status = await service.testConnection();

        expect(status.available, isTrue);
        expect(launcher.calls.single.arguments, ['--version']);
        expect(launcher.calls.single.runInShell, isFalse);
      },
    );

    test(
      'version and discovery terminate children when stdin close fails',
      () async {
        final versionProcess = _FakeProcess(
          neverExit: true,
          closeStdinError: StateError('cannot close'),
        );
        final versionService = AuggieCliService(
          launcher: _FakeLauncher()..enqueue(versionProcess),
          supportsLocalProcess: () => true,
        );
        await expectLater(
          versionService.testConnection(),
          throwsA(
            isA<AuggieCliException>().having(
              (error) => error.code,
              'code',
              'process_failure',
            ),
          ),
        );
        expect(versionProcess.terminated, isTrue);
        expect(versionProcess.disposed, isTrue);

        final discoveryProcess = _FakeProcess(
          neverExit: true,
          closeStdinError: StateError('cannot close'),
        );
        final discoveryService = AuggieCliService(
          launcher: _FakeLauncher()..enqueue(discoveryProcess),
          supportsLocalProcess: () => true,
        );
        final models = await discoveryService.discoverModels(refresh: true);
        expect(models, isNotEmpty);
        expect(discoveryProcess.terminated, isTrue);
        expect(discoveryProcess.disposed, isTrue);
      },
    );

    test('missing and signed-out CLI states are reported safely', () async {
      final missingLauncher = _FakeLauncher()
        ..startError = ProcessException('auggie', const []);
      final missingService = AuggieCliService(
        launcher: missingLauncher,
        supportsLocalProcess: () => true,
      );
      await expectLater(
        missingService.testConnection(),
        throwsA(
          isA<AuggieCliException>().having(
            (error) => error.code,
            'missing CLI code',
            'auggie_not_installed',
          ),
        ),
      );

      final signedOut = AuggieCliService(
        launcher: _FakeLauncher()
          ..enqueue(
            _FakeProcess(
              stderrChunks: ['Not log', 'ged in; private-token=secret'],
              exitCode: 1,
            ),
          ),
        supportsLocalProcess: () => true,
      );
      await expectLater(
        signedOut.request(
          modelId: 'sonnet4.6',
          body: {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
          stream: false,
        ),
        throwsA(
          isA<AuggieCliException>()
              .having(
                (error) => error.code,
                'sign-in code',
                'auggie_not_logged_in',
              )
              .having(
                (error) => error.toString(),
                'safe message',
                isNot(contains('secret')),
              ),
        ),
      );
    });

    test('streaming emits stdout as a normal chat completion stream', () async {
      final process = _FakeProcess(
        output: 'Hello ',
        outputChunks: ['Hello ', 'world'],
        exitBeforeOutputClose: true,
      );
      final launcher = _FakeLauncher()..enqueue(process);
      final service = AuggieCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
      );

      final response = await service.request(
        modelId: 'sonnet4.6',
        body: {
          'messages': [
            {'role': 'user', 'content': 'Say hi'},
          ],
        },
        stream: true,
      );
      final output = await utf8.decodeStream(
        response.body as Stream<List<int>>,
      );

      expect(launcher.calls.single.arguments, [
        '--print',
        '--quiet',
        '--model',
        'sonnet4.6',
        '--',
      ]);
      expect(process.inputText, '[User]\nSay hi');
      expect(output, contains('"object":"chat.completion.chunk"'));
      expect(output, contains('Hello '));
      expect(output, contains('world'));
      expect(output, contains('data: [DONE]'));
    });

    test('streaming classifies short quota output before a nonzero exit',
        () async {
      final service = AuggieCliService(
        launcher: _FakeLauncher()
          ..enqueue(
            _FakeProcess(
              output: 'You have run out of usage for today',
              exitCode: 1,
              exitBeforeOutputClose: true,
            ),
          ),
        supportsLocalProcess: () => true,
      );

      final response = await service.request(
        modelId: 'sonnet4.6',
        body: {
          'messages': [
            {'role': 'user', 'content': 'Say hi'},
          ],
        },
        stream: true,
      );
      final output = await utf8.decodeStream(
        response.body as Stream<List<int>>,
      );

      expect(output, contains('auggie_quota_exhausted'));
      expect(output, isNot(contains('process_failure')));
    });

    test('streaming detects quota output after the initial buffer', () async {
      final service = AuggieCliService(
        launcher: _FakeLauncher()
          ..enqueue(
            _FakeProcess(
              outputChunks: [
                List.filled(120, 'ordinary response text ').join(),
                'You have run out of ',
                'usage for today',
              ],
              exitCode: 1,
              exitBeforeOutputClose: true,
            ),
          ),
        supportsLocalProcess: () => true,
      );

      final response = await service.request(
        modelId: 'sonnet4.6',
        body: {
          'messages': [
            {'role': 'user', 'content': 'Say hi'},
          ],
        },
        stream: true,
      );
      final output = await utf8.decodeStream(
        response.body as Stream<List<int>>,
      );

      expect(output, contains('auggie_quota_exhausted'));
      expect(output, isNot(contains('process_failure')));
    });

    test('nonstreaming buffers output into a normal completion', () async {
      final launcher = _FakeLauncher()
        ..enqueue(
          _FakeProcess(
            outputByteChunks: [
              [0xe4],
              [0xbd, 0xa0, 0xe5],
              [0xa5, 0xbd],
            ],
            exitBeforeOutputClose: true,
          ),
        );
      final service = AuggieCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
      );

      final response = await service.request(
        modelId: 'sonnet4.6',
        body: {
          'messages': [
            {'role': 'user', 'content': 'prompt'},
          ],
        },
        stream: false,
      );
      final completion =
          jsonDecode(utf8.decode(response.body as List<int>)) as Map;

      expect(completion['object'], 'chat.completion');
      expect((completion['choices'] as List).first['message']['content'], '你好');
    });

    test(
      'failure and quota errors are classified without exposing stderr',
      () async {
        final failed = _FakeProcess(
          exitCode: 1,
          stderrText: 'private token=secret',
        );
        final service = AuggieCliService(
          launcher: _FakeLauncher()..enqueue(failed),
          supportsLocalProcess: () => true,
        );

        await expectLater(
          service.request(
            modelId: 'sonnet4.6',
            body: {
              'messages': [
                {'role': 'user', 'content': 'prompt'},
              ],
            },
            stream: false,
          ),
          throwsA(
            isA<AuggieCliException>().having(
              (error) => error.toString(),
              'safe message',
              isNot(contains('secret')),
            ),
          ),
        );

        final quotaService = AuggieCliService(
          launcher: _FakeLauncher()
            ..enqueue(
              _FakeProcess(output: 'You have run out of usage for today'),
            ),
          supportsLocalProcess: () => true,
        );
        await expectLater(
          quotaService.request(
            modelId: 'sonnet4.6',
            body: {
              'messages': [
                {'role': 'user', 'content': 'prompt'},
              ],
            },
            stream: false,
          ),
          throwsA(
            isA<AuggieCliException>().having(
              (error) => error.code,
              'quota code',
              'auggie_quota_exhausted',
            ),
          ),
        );
      },
    );

    test(
      'streaming detects login diagnostics split across stderr chunks',
      () async {
        final service = AuggieCliService(
          launcher: _FakeLauncher()
            ..enqueue(
              _FakeProcess(
                stderrChunks: ['Not log', 'ged in; private-token=secret'],
                exitCode: 1,
              ),
            ),
          supportsLocalProcess: () => true,
        );
        final response = await service.request(
          modelId: 'sonnet4.6',
          body: {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
          stream: true,
        );
        final output = await utf8.decodeStream(
          response.body as Stream<List<int>>,
        );

        expect(output, contains('auggie_not_logged_in'));
        expect(output, isNot(contains('private-token')));
      },
    );

    test(
      'web/mobile capability and process timeout fail before leaking a child',
      () async {
        final unsupportedLauncher = _FakeLauncher();
        final unsupported = AuggieCliService(
          launcher: unsupportedLauncher,
          supportsLocalProcess: () => false,
        );
        await expectLater(
          unsupported.testConnection(),
          throwsA(
            isA<AuggieCliException>().having(
              (error) => error.code,
              'code',
              'desktop_only',
            ),
          ),
        );
        expect(unsupportedLauncher.calls, isEmpty);

        final process = _FakeProcess(neverExit: true);
        final timeoutService = AuggieCliService(
          launcher: _FakeLauncher()..enqueue(process),
          supportsLocalProcess: () => true,
          timeout: const Duration(milliseconds: 10),
        );
        await expectLater(
          timeoutService.request(
            modelId: 'sonnet4.6',
            body: {
              'messages': [
                {'role': 'user', 'content': 'prompt'},
              ],
            },
            stream: false,
          ),
          throwsA(
            isA<AuggieCliException>().having(
              (error) => error.code,
              'code',
              'timeout',
            ),
          ),
        );
        expect(process.terminated, isTrue);
      },
    );

    test('cancel token terminates a running process', () async {
      final process = _FakeProcess(neverExit: true);
      final service = AuggieCliService(
        launcher: _FakeLauncher()..enqueue(process),
        supportsLocalProcess: () => true,
      );
      final cancelToken = CancelToken();
      final request = service.request(
        modelId: 'sonnet4.6',
        body: {
          'messages': [
            {'role': 'user', 'content': 'prompt'},
          ],
        },
        stream: false,
        cancelToken: cancelToken,
      );
      cancelToken.cancel('cancel');

      await expectLater(request, throwsA(isA<AuggieCliException>()));
      expect(process.terminated, isTrue);
    });

    test('cancel during process startup prevents prompt delivery', () async {
      final process = _FakeProcess(neverExit: true);
      final launcher = _FakeLauncher()..enqueue(process);
      launcher.startGate = Completer<void>();
      launcher.startEntered = Completer<void>();
      final service = AuggieCliService(
        launcher: launcher,
        supportsLocalProcess: () => true,
      );
      final cancelToken = CancelToken();
      var callbackCalled = false;
      final request = service.request(
        modelId: 'sonnet4.6',
        body: {
          'messages': [
            {'role': 'user', 'content': 'private prompt'},
          ],
        },
        stream: false,
        cancelToken: cancelToken,
        onRequestSent: () async {
          callbackCalled = true;
        },
      );

      await launcher.startEntered!.future;
      cancelToken.cancel('cancel while starting');
      launcher.startGate!.complete();

      await expectLater(
        request,
        throwsA(
          isA<AuggieCliException>().having(
            (error) => error.code,
            'cancel code',
            'cancelled',
          ),
        ),
      );
      expect(process.inputText, isEmpty);
      expect(callbackCalled, isFalse);
      expect(process.terminated, isTrue);
      expect(process.disposed, isTrue);
    });

    test(
      'input and request callback failures terminate and dispose process',
      () async {
        for (final failAt in ['writeStdin', 'closeStdin', 'onRequestSent']) {
          final process = _FakeProcess(
            neverExit: true,
            writeStdinError:
                failAt == 'writeStdin' ? StateError('write failed') : null,
            closeStdinError:
                failAt == 'closeStdin' ? StateError('closed') : null,
          );
          final service = AuggieCliService(
            launcher: _FakeLauncher()..enqueue(process),
            supportsLocalProcess: () => true,
          );

          await expectLater(
            service.request(
              modelId: 'sonnet4.6',
              body: {
                'messages': [
                  {'role': 'user', 'content': 'prompt'},
                ],
              },
              stream: false,
              onRequestSent: failAt == 'onRequestSent'
                  ? () => Future.error(StateError('callback'))
                  : null,
            ),
            throwsA(isA<AuggieCliException>()),
          );

          expect(process.terminated, isTrue);
          expect(process.disposed, isTrue);
        }
      },
    );
  });
}

class _FakeLaunchCall {
  final List<String> arguments;
  final bool runInShell;
  final String? workingDirectory;

  const _FakeLaunchCall(this.arguments, this.runInShell, this.workingDirectory);
}

class _FakeLauncher implements AuggieCliProcessLauncher {
  final List<_FakeLaunchCall> calls = [];
  final List<AuggieCliProcess> _queued = [];
  Object? startError;
  Completer<void>? startGate;
  Completer<void>? startEntered;

  void enqueue(AuggieCliProcess process) => _queued.add(process);

  @override
  Future<AuggieCliProcess> start(
    List<String> arguments, {
    required bool runInShell,
    String? workingDirectory,
  }) async {
    calls.add(_FakeLaunchCall(arguments, runInShell, workingDirectory));
    if (startEntered case final entered?) entered.complete();
    await startGate?.future;
    if (startError case final error?) throw error;
    return _queued.removeAt(0);
  }
}

class _FakeProcess implements AuggieCliProcess {
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();
  final bool neverExit;
  final bool exitBeforeOutputClose;
  bool terminated = false;
  bool disposed = false;
  final Object? writeStdinError;
  final Object? closeStdinError;
  final StringBuffer _input = StringBuffer();
  String get inputText => _input.toString();

  _FakeProcess({
    String output = '',
    List<String>? outputChunks,
    List<List<int>>? outputByteChunks,
    String stderrText = '',
    List<String>? stderrChunks,
    int exitCode = 0,
    this.neverExit = false,
    this.exitBeforeOutputClose = false,
    this.writeStdinError,
    this.closeStdinError,
  }) {
    scheduleMicrotask(() async {
      if (!neverExit && exitBeforeOutputClose) _exit.complete(exitCode);
      if (outputByteChunks != null) {
        for (final chunk in outputByteChunks) {
          _stdout.add(chunk);
        }
      } else {
        for (final chunk in outputChunks ?? [output]) {
          if (chunk.isNotEmpty) _stdout.add(utf8.encode(chunk));
        }
      }
      for (final chunk in stderrChunks ?? [stderrText]) {
        if (chunk.isNotEmpty) _stderr.add(utf8.encode(chunk));
      }
      await _stdout.close();
      await _stderr.close();
      if (!neverExit && !exitBeforeOutputClose) _exit.complete(exitCode);
    });
  }

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void writeStdin(List<int> bytes) {
    if (writeStdinError case final error?) throw error;
    _input.write(utf8.decode(bytes));
  }

  @override
  Future<void> closeStdin() async {
    if (closeStdinError case final error?) throw error;
  }

  @override
  Future<void> terminate({bool force = false}) async {
    terminated = true;
    if (!_exit.isCompleted) _exit.complete(143);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
