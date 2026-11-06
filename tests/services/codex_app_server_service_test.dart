import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/codex_app_server_service.dart';

void main() {
  group('Codex App Server account status', () {
    test('account/read distinguishes signed in, signed out, and unknown', () {
      expect(
        codexAppServerStatusFromAccountRead({
          'account': {'type': 'chatgpt'},
        }),
        CodexAppServerStatus.authenticated,
      );
      expect(
        codexAppServerStatusFromAccountRead({'account': null}),
        CodexAppServerStatus.signedOut,
      );
      expect(
        codexAppServerStatusFromAccountRead({}),
        CodexAppServerStatus.unknown,
      );
      expect(
        codexAppServerStatusFromAccountReadError(
          const CodexAppServerRpcException(-32001, 'Auth required'),
        ),
        CodexAppServerStatus.signedOut,
      );
      expect(
        codexAppServerStatusFromAccountReadError(
          const CodexAppServerRpcException(-32603, 'internal'),
        ),
        CodexAppServerStatus.unknown,
      );
    });
  });

  group('Codex App Server launch policy', () {
    test(
      'launch uses the fixed CLI command and loopback capability endpoint',
      () {
        const launch = CodexAppServerLaunch(
          port: 32123,
          tokenFilePath: '/private/codex-app-server/token',
        );

        expect(launch.executable, 'codex');
        expect(launch.runInShell, isFalse);
        expect(launch.arguments, [
          'app-server',
          '--listen',
          'ws://127.0.0.1:32123',
          '--ws-auth',
          'capability-token',
          '--ws-token-file',
          '/private/codex-app-server/token',
        ]);
        expect(launch.arguments.join(' '), isNot(contains('0.0.0.0')));
      },
    );

    test('Response inputs preserve complete history and function tools', () {
      final input = CodexAppServerRequest.fromResponsesBody({
        'model': 'gpt-6.1-sol',
        'instructions': 'Keep going',
        'input': [
          {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': 'first question'},
            ],
          },
          {
            'type': 'function_call',
            'call_id': 'call-1',
            'name': 'lookup',
            'arguments': '{"q":"x"}',
          },
          {
            'type': 'function_call_output',
            'call_id': 'call-1',
            'output': 'result',
          },
          {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': 'follow up'},
            ],
          },
        ],
        'tools': [
          {
            'type': 'function',
            'name': 'lookup',
            'description': 'Find a record',
            'parameters': {
              'type': 'object',
              'properties': {
                'q': {'type': 'string'},
              },
            },
          },
        ],
      });

      expect(input.prompt, contains('[user]\nfirst question'));
      expect(input.prompt, contains('[assistant tool call lookup] {"q":"x"}'));
      expect(input.prompt, contains('[tool result call-1]\nresult'));
      expect(input.prompt, contains('[user]\nfollow up'));
      expect(input.prompt, contains('Keep going'));
      expect(input.dynamicTools, [
        {
          'type': 'function',
          'name': 'lookup',
          'description': 'Find a record',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'q': {'type': 'string'},
            },
          },
        },
      ]);
    });

    test(
      'namespace, custom, and tool-search tools retain their wire mappings',
      () {
        final input = CodexAppServerRequest.fromResponsesBody({
          'model': 'gpt-6.1-sol',
          'input': 'use tools',
          'tools': [
            {
              'type': 'namespace',
              'name': 'files',
              'tools': [
                {
                  'type': 'function',
                  'name': 'read',
                  'description': 'Read a file',
                  'parameters': {'type': 'object'},
                },
              ],
            },
            {'type': 'custom', 'name': 'patch', 'description': 'Apply a patch'},
            {'type': 'tool_search', 'description': 'Find more tools'},
          ],
        });

        expect(input.dynamicTools.map((tool) => tool['name']), [
          'files__read',
          'patch',
          'tool_search',
        ]);
        expect(input.toolNamespaces['files__read'], 'files');
        expect(input.namespacedToolNames['files__read'], 'read');
        expect(input.customToolNames, {'patch'});
        expect(input.toolSearchNames, {'tool_search'});

        final events = <CodexAppServerEvent>[];
        final translator = CodexAppServerEventTranslator(events.add);
        translator.toolCall(
          {
            'callId': 'call-1',
            'namespace': 'files',
            'tool': 'read',
            'arguments': {'path': 'file.txt'},
          },
          namespaces: input.toolNamespaces,
          namespacedNames: input.namespacedToolNames,
        );
        translator.toolCall({
          'callId': 'call-2',
          'tool': 'patch',
          'arguments': {'input': 'diff'},
        }, customNames: input.customToolNames);
        translator.toolCall({
          'callId': 'call-3',
          'tool': 'tool_search',
          'arguments': {'query': 'x'},
        }, toolSearchNames: input.toolSearchNames);
        final calls = events.whereType<CodexAppServerToolCall>().toList();
        expect(calls.map((call) => call.type), [
          'function_call',
          'custom_tool_call',
          'tool_search_call',
        ]);
        expect(calls.first.name, 'read');
        expect(calls.first.namespace, 'files');
      },
    );

    test('rejects unsupported media and server-side tools explicitly', () {
      for (final body in [
        {
          'input': [
            {
              'type': 'message',
              'role': 'user',
              'content': [
                {
                  'type': 'input_image',
                  'image_url': 'data:image/png;base64,AA==',
                },
              ],
            },
          ],
        },
        {
          'input': 'hello',
          'tools': [
            {'type': 'web_search_preview'},
          ],
        },
      ]) {
        expect(
          () => CodexAppServerRequest.fromResponsesBody(body),
          throwsA(isA<CodexAppServerUnsupportedRequest>()),
        );
      }
    });
  });

  group('Codex App Server JSON-RPC', () {
    test('correlates out-of-order replies by id', () async {
      final peer = FakeCodexAppServerSocket();
      final client = CodexAppServerRpcClient(
        peer,
        defaultTimeout: const Duration(seconds: 1),
      );
      final first = client.request('first', const {});
      final second = client.request('second', const {});
      final firstRequest = jsonDecode(peer.sent[0]) as Map<String, dynamic>;
      final secondRequest = jsonDecode(peer.sent[1]) as Map<String, dynamic>;

      peer.receive({
        'jsonrpc': '2.0',
        'id': secondRequest['id'],
        'result': 'two',
      });
      peer.receive({
        'jsonrpc': '2.0',
        'id': firstRequest['id'],
        'result': 'one',
      });

      await expectLater(first, completion('one'));
      await expectLater(second, completion('two'));
      await client.close();
    });

    test('times out and fails all requests on disconnect', () async {
      final peer = FakeCodexAppServerSocket();
      final client = CodexAppServerRpcClient(
        peer,
        defaultTimeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        client.request('slow', const {}),
        throwsA(isA<TimeoutException>()),
      );

      final pending = client.request('disconnect', const {});
      peer.close();
      await expectLater(pending, throwsA(isA<CodexAppServerDisconnected>()));
      await client.close();
    });

    test(
      'preserves text and reasoning deltas and translates tool calls',
      () async {
        final events = <CodexAppServerEvent>[];
        final translator = CodexAppServerEventTranslator(events.add);
        translator.notification('item/agentMessage/delta', {
          'delta': 'visible',
        });
        translator.notification('item/reasoning/summaryTextDelta', {
          'delta': 'summary',
        });
        translator.toolCall({
          'callId': 'call-2',
          'namespace': 'files',
          'tool': 'read',
          'arguments': {'path': 'a.txt'},
        });
        expect(events[0], isA<CodexAppServerTextDelta>());
        expect((events[0] as CodexAppServerTextDelta).text, 'visible');
        expect(events[1], isA<CodexAppServerReasoningDelta>());
        expect((events[1] as CodexAppServerReasoningDelta).text, 'summary');
        expect(events[2], isA<CodexAppServerToolCall>());
        expect((events[2] as CodexAppServerToolCall).name, 'files__read');
      },
    );
  });

  group('Codex App Server local process service', () {
    test(
      'status starts a private loopback session and reads account status',
      () async {
        final peer = FakeCodexAppServerSocket();
        final launcher = FakeCodexAppServerLauncher();
        final service = CodexAppServerService(
          processLauncher: launcher,
          socketConnector: FakeCodexAppServerConnector(peer),
        );
        peer.onSend = (message) {
          final request = jsonDecode(message) as Map<String, dynamic>;
          final method = request['method'];
          if (method == null) return;
          peer.receive({
            'jsonrpc': '2.0',
            'id': request['id'],
            'result': method == 'account/read'
                ? {
                    'account': {'type': 'chatgpt'},
                  }
                : <String, dynamic>{},
          });
        };

        final result = await service.status();

        expect(result.status, CodexAppServerStatus.authenticated);
        expect(launcher.launches, hasLength(1));
        expect(launcher.launches.single.executable, 'codex');
        expect(launcher.launches.single.runInShell, isFalse);
        expect(
          launcher.launches.single.arguments[2],
          startsWith('ws://127.0.0.1:'),
        );
        expect(launcher.tokenFilesAtStart, [isA<String>()]);
        expect(launcher.tokenWasPrivate, [true]);
        expect(await File(launcher.tokenFilesAtStart.single).exists(), isFalse);
        expect(launcher.processes.single.terminated, isTrue);
      },
    );

    test('status distinguishes signed out and unknown accounts', () async {
      final cases = <(Object?, CodexAppServerStatus)>[
        ({'account': null}, CodexAppServerStatus.signedOut),
        ({'other': true}, CodexAppServerStatus.unknown),
      ];
      for (final (account, expected) in cases) {
        final peer = FakeCodexAppServerSocket();
        peer.onSend = (message) {
          final request = jsonDecode(message) as Map<String, dynamic>;
          final method = request['method'];
          if (method == null) return;
          peer.receive({
            'jsonrpc': '2.0',
            'id': request['id'],
            'result': method == 'account/read' ? account : {},
          });
        };
        final service = CodexAppServerService(
          processLauncher: FakeCodexAppServerLauncher(),
          socketConnector: FakeCodexAppServerConnector(peer),
        );

        expect((await service.status()).status, expected);
      }
    });

    test('status reports a missing Codex CLI', () async {
      final launcher = FakeCodexAppServerLauncher(
        startError: ProcessException('codex', const [], '', 2),
      );
      final service = CodexAppServerService(processLauncher: launcher);

      final result = await service.status();

      expect(result.status, CodexAppServerStatus.unavailable);
      expect(result.code, 'codex_cli_not_installed');
      expect(launcher.launches, hasLength(1));
    });

    test('requests preserve the signed-out error for Gateway mapping',
        () async {
      final peer = FakeCodexAppServerSocket();
      final launcher = FakeCodexAppServerLauncher();
      peer.onSend = (message) {
        final request = jsonDecode(message) as Map<String, dynamic>;
        final method = request['method'];
        if (method == null) return;
        peer.receive({
          'jsonrpc': '2.0',
          'id': request['id'],
          'result': method == 'account/read' ? {'account': null} : {},
        });
      };
      final service = CodexAppServerService(
        processLauncher: launcher,
        socketConnector: FakeCodexAppServerConnector(peer),
      );

      await expectLater(
        service.request(
          body: {'input': 'hello'},
          modelId: 'gpt-6.1-sol',
          stream: true,
          cancelToken: null,
        ),
        throwsA(
          isA<CodexAppServerRpcException>().having(
            (error) => error.code,
            'authentication-required code',
            -32001,
          ),
        ),
      );
      expect(launcher.processes.single.terminated, isTrue);
    });

    test(
      'request streams text and reasoning events from an isolated turn',
      () async {
        final peer = FakeCodexAppServerSocket();
        final launcher = FakeCodexAppServerLauncher();
        final service = CodexAppServerService(
          processLauncher: launcher,
          socketConnector: FakeCodexAppServerConnector(peer),
        );
        peer.onSend = (message) {
          final request = jsonDecode(message) as Map<String, dynamic>;
          final method = request['method'];
          if (method == null) return;
          final id = request['id'];
          switch (method) {
            case 'initialize':
              peer.receive({'jsonrpc': '2.0', 'id': id, 'result': {}});
            case 'account/read':
              peer.receive({
                'jsonrpc': '2.0',
                'id': id,
                'result': {
                  'account': {'type': 'chatgpt'},
                },
              });
            case 'thread/start':
              peer.receive({
                'jsonrpc': '2.0',
                'id': id,
                'result': {
                  'thread': {'id': 'thread-1'},
                },
              });
            case 'turn/start':
              peer.receive({'jsonrpc': '2.0', 'id': id, 'result': {}});
              peer.receive({
                'jsonrpc': '2.0',
                'method': 'item/agentMessage/delta',
                'params': {'delta': 'hello'},
              });
              peer.receive({
                'jsonrpc': '2.0',
                'method': 'turn/completed',
                'params': {
                  'turn': {
                    'usage': {'input_tokens': 2},
                  },
                },
              });
          }
        };

        final response = await service.request(
          body: {
            'input': [
              {
                'type': 'message',
                'role': 'user',
                'content': [
                  {'type': 'input_text', 'text': 'hi'},
                ],
              },
            ],
          },
          modelId: 'gpt-6.1-sol',
          stream: true,
          cancelToken: null,
        );
        final events = await (response.body as Stream<List<int>>)
            .map(utf8.decode)
            .toList();
        final decoded = events.map(
          (event) => jsonDecode(event.substring('data: '.length).trim())
              as Map<String, dynamic>,
        );
        expect(decoded.map((event) => event['type']), [
          'response.output_text.delta',
          'response.completed',
        ]);
        expect(decoded.first['delta'], 'hello');
        expect(launcher.processes.single.terminated, isTrue);
      },
    );

    test(
      'tool calls pass through and internal approval requests are denied',
      () async {
        final peer = FakeCodexAppServerSocket();
        final service = CodexAppServerService(
          processLauncher: FakeCodexAppServerLauncher(),
          socketConnector: FakeCodexAppServerConnector(peer),
        );
        peer.onSend = (message) {
          final request = jsonDecode(message) as Map<String, dynamic>;
          final method = request['method'];
          if (method == 'initialize') {
            peer.receive({'jsonrpc': '2.0', 'id': request['id'], 'result': {}});
          } else if (method == 'account/read') {
            peer.receive({
              'jsonrpc': '2.0',
              'id': request['id'],
              'result': {
                'account': {'type': 'chatgpt'},
              },
            });
          } else if (method == 'thread/start') {
            final params = request['params'] as Map<String, dynamic>;
            expect(params['dynamicTools'], hasLength(1));
            expect(params['approvalPolicy'], 'never');
            expect(params['sandbox'], 'read-only');
            peer.receive({
              'jsonrpc': '2.0',
              'id': request['id'],
              'result': {
                'thread': {'id': 'thread-1'},
              },
            });
          } else if (method == 'turn/start') {
            peer.receive({'jsonrpc': '2.0', 'id': request['id'], 'result': {}});
            peer.receive({
              'jsonrpc': '2.0',
              'id': 42,
              'method': 'item/commandExecution/requestApproval',
              'params': {'command': 'unsafe'},
            });
            peer.receive({
              'jsonrpc': '2.0',
              'id': 41,
              'method': 'item/tool/call',
              'params': {
                'callId': 'call-1',
                'tool': 'lookup',
                'arguments': {'query': 'record'},
              },
            });
          }
        };

        final response = await service.request(
          body: {
            'input': 'find a record',
            'tools': [
              {
                'type': 'function',
                'name': 'lookup',
                'parameters': {'type': 'object'},
              },
            ],
          },
          modelId: 'gpt-6.1-sol',
          stream: false,
          cancelToken: null,
        );
        final body = response.body as Map<String, dynamic>;
        final call = (body['output'] as List).single as Map<String, dynamic>;
        final toolReply = peer.sent
            .map((message) => jsonDecode(message) as Map<String, dynamic>)
            .firstWhere((message) => message['id'] == 41);
        final approvalReply = peer.sent
            .map((message) => jsonDecode(message) as Map<String, dynamic>)
            .firstWhere((message) => message['id'] == 42);

        expect(call['type'], 'function_call');
        expect(call['name'], 'lookup');
        expect(call['arguments'], '{"query":"record"}');
        expect(toolReply['result']['success'], isFalse);
        expect(approvalReply['result']['decision'], 'denied');
      },
    );

    test('cancel interrupts the app-server turn', () async {
      final peer = FakeCodexAppServerSocket();
      final service = CodexAppServerService(
        processLauncher: FakeCodexAppServerLauncher(),
        socketConnector: FakeCodexAppServerConnector(peer),
      );
      final turnStarted = Completer<void>();
      peer.onSend = (message) {
        final request = jsonDecode(message) as Map<String, dynamic>;
        final method = request['method'];
        if (method == 'initialize') {
          peer.receive({'jsonrpc': '2.0', 'id': request['id'], 'result': {}});
        } else if (method == 'account/read') {
          peer.receive({
            'jsonrpc': '2.0',
            'id': request['id'],
            'result': {
              'account': {'type': 'chatgpt'},
            },
          });
        } else if (method == 'thread/start') {
          peer.receive({
            'jsonrpc': '2.0',
            'id': request['id'],
            'result': {
              'thread': {'id': 'thread-1'},
            },
          });
        } else if (method == 'turn/start') {
          if (!turnStarted.isCompleted) turnStarted.complete();
          peer.receive({'jsonrpc': '2.0', 'id': request['id'], 'result': {}});
        }
      };
      final cancelToken = CancelToken();
      final response = await service.request(
        body: {'input': 'hi'},
        modelId: 'gpt-6.1-sol',
        stream: true,
        cancelToken: cancelToken,
      );
      final eventsFuture = (response.body as Stream<List<int>>).toList();
      await turnStarted.future;
      cancelToken.cancel('stop');
      await eventsFuture;

      expect(
        peer.sent
            .map((message) => jsonDecode(message) as Map<String, dynamic>)
            .any((message) => message['method'] == 'turn/interrupt'),
        isTrue,
      );
    });

    test('canceling the SSE consumer interrupts and closes the app-server',
        () async {
      final peer = FakeCodexAppServerSocket();
      final launcher = FakeCodexAppServerLauncher();
      final service = CodexAppServerService(
        processLauncher: launcher,
        socketConnector: FakeCodexAppServerConnector(peer),
      );
      final turnStarted = Completer<void>();
      peer.onSend = (message) {
        final request = jsonDecode(message) as Map<String, dynamic>;
        final method = request['method'];
        if (method == 'initialize') {
          peer.receive({'jsonrpc': '2.0', 'id': request['id'], 'result': {}});
        } else if (method == 'account/read') {
          peer.receive({
            'jsonrpc': '2.0',
            'id': request['id'],
            'result': {
              'account': {'type': 'chatgpt'},
            },
          });
        } else if (method == 'thread/start') {
          peer.receive({
            'jsonrpc': '2.0',
            'id': request['id'],
            'result': {
              'thread': {'id': 'thread-1'},
            },
          });
        } else if (method == 'turn/start') {
          if (!turnStarted.isCompleted) turnStarted.complete();
          peer.receive({'jsonrpc': '2.0', 'id': request['id'], 'result': {}});
        }
      };

      final response = await service.request(
        body: {'input': 'hi'},
        modelId: 'gpt-6.1-sol',
        stream: true,
        cancelToken: null,
      );
      final subscription = (response.body as Stream<List<int>>).listen((_) {});
      await turnStarted.future;
      await subscription.cancel();

      expect(
        peer.sent
            .map((message) => jsonDecode(message) as Map<String, dynamic>)
            .any((message) => message['method'] == 'turn/interrupt'),
        isTrue,
      );
      expect(launcher.processes.single.terminated, isTrue);
    });
  });
}

class FakeCodexAppServerSocket implements CodexAppServerSocket {
  final _incoming = StreamController<Object?>();
  final sent = <String>[];
  void Function(String message)? onSend;
  var isClosed = false;

  @override
  Stream<Object?> get messages => _incoming.stream;

  @override
  void send(String message) {
    sent.add(message);
    onSend?.call(message);
  }

  @override
  Future<void> close() async {
    if (isClosed) return;
    isClosed = true;
    await _incoming.close();
  }

  void receive(Map<String, dynamic> message) =>
      _incoming.add(jsonEncode(message));
}

class FakeCodexAppServerConnector implements CodexAppServerSocketConnector {
  final CodexAppServerSocket socket;
  FakeCodexAppServerConnector(this.socket);

  @override
  Future<CodexAppServerSocket> connect(Uri uri, String capabilityToken) async {
    expect(uri.scheme, 'ws');
    expect(uri.host, '127.0.0.1');
    expect(capabilityToken, hasLength(64));
    return socket;
  }
}

class FakeCodexAppServerLauncher implements CodexAppServerProcessLauncher {
  final launches = <CodexAppServerLaunch>[];
  final processes = <FakeCodexAppServerProcess>[];
  final tokenFilesAtStart = <String>[];
  final tokenWasPrivate = <bool>[];
  final Object? startError;

  FakeCodexAppServerLauncher({this.startError});

  @override
  Future<CodexAppServerProcess> start(CodexAppServerLaunch launch) async {
    launches.add(launch);
    tokenFilesAtStart.add(launch.tokenFilePath);
    final tokenFile = File(launch.tokenFilePath);
    final token = await tokenFile.readAsString();
    final directoryMode = await tokenFile.parent.stat();
    final fileMode = await tokenFile.stat();
    tokenWasPrivate.add(
      RegExp(r'^[a-f0-9]{64}$').hasMatch(token) &&
          (Platform.isWindows ||
              ((directoryMode.mode & 0x1ff) == 0x1c0 &&
                  (fileMode.mode & 0x1ff) == 0x180)),
    );
    if (startError != null) throw startError!;
    final process = FakeCodexAppServerProcess();
    processes.add(process);
    return process;
  }
}

class FakeCodexAppServerProcess implements CodexAppServerProcess {
  final _exitCode = Completer<int>();
  var terminated = false;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Future<void> terminate({bool force = false}) async {
    terminated = true;
    if (!_exitCode.isCompleted) _exitCode.complete(force ? 9 : 0);
  }
}
