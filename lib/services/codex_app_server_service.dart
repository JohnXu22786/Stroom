import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum CodexAppServerStatus { authenticated, signedOut, unavailable, unknown }

class CodexAppServerLaunch {
  final int port;
  final String tokenFilePath;

  const CodexAppServerLaunch({required this.port, required this.tokenFilePath});

  String get executable => 'codex';
  bool get runInShell => false;
  List<String> get arguments => [
        'app-server',
        '--listen',
        'ws://127.0.0.1:$port',
        '--ws-auth',
        'capability-token',
        '--ws-token-file',
        tokenFilePath,
      ];
}

class CodexAppServerRpcException implements Exception {
  final int code;
  final String message;

  const CodexAppServerRpcException(this.code, this.message);

  @override
  String toString() => 'Codex App Server request failed ($code).';
}

class CodexAppServerDisconnected implements Exception {
  const CodexAppServerDisconnected();

  @override
  String toString() => 'Codex App Server connection closed.';
}

class CodexAppServerUnsupportedRequest implements Exception {
  final String code;

  const CodexAppServerUnsupportedRequest(this.code);

  @override
  String toString() => 'Codex App Server does not support this request.';
}

CodexAppServerStatus codexAppServerStatusFromAccountRead(Object? result) =>
    result is! Map || !result.containsKey('account')
        ? CodexAppServerStatus.unknown
        : result['account'] is Map
            ? CodexAppServerStatus.authenticated
            : CodexAppServerStatus.signedOut;

CodexAppServerStatus codexAppServerStatusFromAccountReadError(Object error) =>
    error is CodexAppServerRpcException &&
            RegExp(
              r'auth|login|sign|unauthor|401',
              caseSensitive: false,
            ).hasMatch(error.message)
        ? CodexAppServerStatus.signedOut
        : CodexAppServerStatus.unknown;

class CodexAppServerStatusResult {
  final CodexAppServerStatus status;
  final String message;
  final String code;

  const CodexAppServerStatusResult(this.status, this.message, this.code);
}

class CodexAppServerRequest {
  final String prompt;
  final String model;
  final String? effort;
  final List<Map<String, dynamic>> dynamicTools;
  final Set<String> customToolNames;
  final Set<String> toolSearchNames;
  final Map<String, String> toolNamespaces;
  final Map<String, String> namespacedToolNames;

  const CodexAppServerRequest({
    required this.prompt,
    required this.model,
    this.effort,
    this.dynamicTools = const [],
    this.customToolNames = const {},
    this.toolSearchNames = const {},
    this.toolNamespaces = const {},
    this.namespacedToolNames = const {},
  });

  factory CodexAppServerRequest.fromResponsesBody(
    Map<String, dynamic> body, {
    String? modelId,
  }) {
    final input = body['input'];
    final items = input == null
        ? const []
        : input is List
            ? input
            : [input];
    final text = <String>[];
    final instructions = body['instructions'];
    if (instructions is String && instructions.trim().isNotEmpty) {
      text.add('[system]\n${instructions.trim()}');
    }
    for (final item in items) {
      if (item is String) {
        if (item.isNotEmpty) text.add('[user]\n$item');
        continue;
      }
      if (item is! Map) {
        throw const CodexAppServerUnsupportedRequest('unsupported_input');
      }
      final type = item['type'];
      if (type == 'function_call' ||
          type == 'custom_tool_call' ||
          type == 'tool_search_call') {
        final name = item['name'];
        final namespace = item['namespace'];
        final wireName = namespace is String && namespace.isNotEmpty
            ? '${namespace}__${name ?? ''}'
            : type == 'tool_search_call'
                ? 'tool_search'
                : name;
        if (wireName is! String || wireName.isEmpty) {
          throw const CodexAppServerUnsupportedRequest('unsupported_tool');
        }
        final arguments = type == 'custom_tool_call'
            ? {'input': item['input'] ?? ''}
            : item['arguments'] ?? '{}';
        text.add('[assistant tool call $wireName] $arguments');
        continue;
      }
      if (type == 'function_call_output' ||
          type == 'custom_tool_call_output' ||
          type == 'tool_search_call_output') {
        text.add(
          '[tool result ${item['call_id'] ?? ''}]\n${item['output'] ?? ''}',
        );
        continue;
      }
      if (type != 'message') {
        throw const CodexAppServerUnsupportedRequest('unsupported_input');
      }
      final role = item['role'];
      if (role is! String ||
          !const {'user', 'assistant', 'system', 'developer'}.contains(role)) {
        throw const CodexAppServerUnsupportedRequest('unsupported_message');
      }
      final content = item['content'];
      final parts = content is List ? content : [content];
      final messageText = <String>[];
      for (final part in parts) {
        if (part is String) {
          messageText.add(part);
          continue;
        }
        if (part is! Map ||
            !const {
              'input_text',
              'output_text',
              'text',
            }.contains(part['type']) ||
            part['text'] is! String) {
          throw const CodexAppServerUnsupportedRequest('unsupported_media');
        }
        messageText.add(part['text'] as String);
      }
      if (messageText.isNotEmpty) text.add('[$role]\n${messageText.join()}');
    }

    final dynamicTools = <Map<String, dynamic>>[];
    final customToolNames = <String>{};
    final toolSearchNames = <String>{};
    final toolNamespaces = <String, String>{};
    final namespacedToolNames = <String, String>{};
    final rawTools = body['tools'];
    if (rawTools is List) {
      void addTool(
        String name,
        Object? description,
        Object? schema, {
        bool custom = false,
        bool toolSearch = false,
        String? namespace,
      }) {
        dynamicTools.add({
          'type': 'function',
          'name': name,
          'description': description is String ? description : '',
          'inputSchema': custom
              ? {
                  'type': 'object',
                  'properties': {
                    'input': {'type': 'string'},
                  },
                  'required': ['input'],
                }
              : schema is Map
                  ? Map<String, dynamic>.from(schema)
                  : toolSearch
                      ? {
                          'type': 'object',
                          'properties': {
                            'query': {'type': 'string'},
                            'limit': {'type': 'number'},
                          },
                          'required': ['query'],
                        }
                      : {'type': 'object'},
        });
        if (custom) customToolNames.add(name);
        if (toolSearch) toolSearchNames.add(name);
        if (namespace != null) {
          toolNamespaces[name] = namespace;
          namespacedToolNames[name] = name.substring(namespace.length + 2);
        }
      }

      for (final tool in rawTools) {
        if (tool is! Map) {
          throw const CodexAppServerUnsupportedRequest('unsupported_tool');
        }
        if (tool['type'] == 'web_search' ||
            tool['type'] == 'web_search_preview' ||
            tool['type'] == 'image_generation') {
          throw const CodexAppServerUnsupportedRequest('unsupported_tool');
        }
        if (tool['type'] == 'namespace' &&
            tool['name'] is String &&
            tool['tools'] is List) {
          final namespace = tool['name'] as String;
          for (final nested in tool['tools'] as List) {
            if (nested is! Map ||
                nested['type'] != 'function' ||
                nested['name'] is! String) {
              throw const CodexAppServerUnsupportedRequest('unsupported_tool');
            }
            final name = nested['name'] as String;
            addTool(
              '${namespace}__$name',
              nested['description'],
              nested['parameters'],
              namespace: namespace,
            );
          }
          continue;
        }
        if (!const {
          'function',
          'custom',
          'tool_search',
        }.contains(tool['type'])) {
          throw const CodexAppServerUnsupportedRequest('unsupported_tool');
        }
        final toolSearch = tool['type'] == 'tool_search';
        final name = toolSearch ? 'tool_search' : tool['name'];
        if (name is! String || name.isEmpty) {
          throw const CodexAppServerUnsupportedRequest('unsupported_tool');
        }
        addTool(
          name,
          tool['description'],
          tool['parameters'],
          custom: tool['type'] == 'custom',
          toolSearch: toolSearch,
        );
      }
    }
    final reasoning = body['reasoning'];
    final rawEffort =
        reasoning is Map ? reasoning['effort'] : body['reasoning_effort'];
    final selectedModel = modelId ?? body['model'];
    if (selectedModel is! String || selectedModel.trim().isEmpty) {
      throw const CodexAppServerUnsupportedRequest('missing_model');
    }
    return CodexAppServerRequest(
      prompt: text.join('\n\n'),
      model: selectedModel,
      effort: rawEffort is String && rawEffort.isNotEmpty ? rawEffort : null,
      dynamicTools: List.unmodifiable(dynamicTools),
      customToolNames: Set.unmodifiable(customToolNames),
      toolSearchNames: Set.unmodifiable(toolSearchNames),
      toolNamespaces: Map.unmodifiable(toolNamespaces),
      namespacedToolNames: Map.unmodifiable(namespacedToolNames),
    );
  }
}

sealed class CodexAppServerEvent {
  const CodexAppServerEvent();
}

class CodexAppServerTextDelta extends CodexAppServerEvent {
  final String text;
  const CodexAppServerTextDelta(this.text);
}

class CodexAppServerReasoningDelta extends CodexAppServerEvent {
  final String text;
  const CodexAppServerReasoningDelta(this.text);
}

class CodexAppServerToolCall extends CodexAppServerEvent {
  final String id;
  final String name;
  final String arguments;
  final String type;
  final String? namespace;
  const CodexAppServerToolCall(
    this.id,
    this.name,
    this.arguments, {
    this.type = 'function_call',
    this.namespace,
  });
}

class CodexAppServerCompleted extends CodexAppServerEvent {
  final Map<String, dynamic> usage;
  const CodexAppServerCompleted([this.usage = const {}]);
}

class CodexAppServerFailed extends CodexAppServerEvent {
  final String message;
  const CodexAppServerFailed(this.message);
}

class CodexAppServerEventTranslator {
  final void Function(CodexAppServerEvent) emit;
  const CodexAppServerEventTranslator(this.emit);

  bool notification(String method, Object? rawParams) {
    final params = rawParams is Map ? rawParams : const <Object?, Object?>{};
    final delta = params['delta'];
    switch (method) {
      case 'item/agentMessage/delta':
        if (delta is String && delta.isNotEmpty) {
          emit(CodexAppServerTextDelta(delta));
        }
        return false;
      case 'item/reasoning/textDelta':
      case 'item/reasoning/summaryTextDelta':
        if (delta is String && delta.isNotEmpty) {
          emit(CodexAppServerReasoningDelta(delta));
        }
        return false;
      case 'turn/completed':
        final turn = params['turn'];
        final rawUsage = turn is Map ? turn['usage'] : params['usage'];
        emit(
          CodexAppServerCompleted(
            rawUsage is Map ? Map<String, dynamic>.from(rawUsage) : const {},
          ),
        );
        return true;
      case 'error':
        if (params['willRetry'] == true) return false;
        final error = params['error'];
        final message = error is Map && error['message'] is String
            ? error['message'] as String
            : 'Codex App Server turn failed.';
        emit(CodexAppServerFailed(_safeError(message)));
        return true;
      default:
        return false;
    }
  }

  void toolCall(
    Object? rawParams, {
    Set<String> customNames = const {},
    Set<String> toolSearchNames = const {},
    Map<String, String> namespaces = const {},
    Map<String, String> namespacedNames = const {},
  }) {
    final params = rawParams is Map ? rawParams : const <Object?, Object?>{};
    final id = params['callId'];
    final tool = params['tool'];
    final namespace = params['namespace'];
    if (id is! String || id.isEmpty || tool is! String || tool.isEmpty) return;
    final wireName = namespace is String && namespace.isNotEmpty
        ? '${namespace}__$tool'
        : tool;
    final mappedNamespace = namespaces[wireName];
    final name = namespacedNames[wireName] ?? wireName;
    final outputType = toolSearchNames.contains(wireName)
        ? 'tool_search_call'
        : customNames.contains(wireName)
            ? 'custom_tool_call'
            : 'function_call';
    final rawArguments = params['arguments'];
    final arguments = rawArguments is String
        ? rawArguments
        : rawArguments == null
            ? '{}'
            : jsonEncode(rawArguments);
    emit(
      CodexAppServerToolCall(
        id,
        name,
        arguments,
        type: outputType,
        namespace: mappedNamespace,
      ),
    );
  }
}

abstract interface class CodexAppServerSocket {
  Stream<Object?> get messages;
  void send(String message);
  Future<void> close();
}

abstract interface class CodexAppServerSocketConnector {
  Future<CodexAppServerSocket> connect(Uri uri, String capabilityToken);
}

class IoCodexAppServerSocketConnector implements CodexAppServerSocketConnector {
  @override
  Future<CodexAppServerSocket> connect(Uri uri, String capabilityToken) async {
    if (uri.scheme != 'ws' || uri.host != '127.0.0.1') {
      throw const CodexAppServerUnsupportedRequest('unsafe_endpoint');
    }
    final channel = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer $capabilityToken'},
      connectTimeout: const Duration(seconds: 5),
    );
    await channel.ready.timeout(const Duration(seconds: 6));
    return _IoCodexAppServerSocket(channel);
  }
}

class _IoCodexAppServerSocket implements CodexAppServerSocket {
  final WebSocketChannel channel;
  _IoCodexAppServerSocket(this.channel);
  @override
  Stream<Object?> get messages => channel.stream;
  @override
  void send(String message) => channel.sink.add(message);
  @override
  Future<void> close() async {
    await channel.sink.close();
  }
}

abstract interface class CodexAppServerProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  Future<void> terminate({bool force = false});
}

abstract interface class CodexAppServerProcessLauncher {
  Future<CodexAppServerProcess> start(CodexAppServerLaunch launch);
}

class IoCodexAppServerProcessLauncher implements CodexAppServerProcessLauncher {
  @override
  Future<CodexAppServerProcess> start(CodexAppServerLaunch launch) async {
    final process = await Process.start(
      launch.executable,
      launch.arguments,
      runInShell: launch.runInShell,
      mode: ProcessStartMode.normal,
    );
    return _IoCodexAppServerProcess(process);
  }
}

class _IoCodexAppServerProcess implements CodexAppServerProcess {
  final Process process;
  _IoCodexAppServerProcess(this.process);
  @override
  Stream<List<int>> get stdout => process.stdout;
  @override
  Stream<List<int>> get stderr => process.stderr;
  @override
  Future<int> get exitCode => process.exitCode;
  @override
  Future<void> terminate({bool force = false}) async {
    process.kill(force ? ProcessSignal.sigkill : ProcessSignal.sigterm);
  }
}

class CodexAppServerRpcClient {
  final CodexAppServerSocket socket;
  final Duration defaultTimeout;
  final Map<int, Completer<Object?>> _pending = {};
  final StreamSubscription<Object?> _subscription;
  var _nextId = 1;
  var _closed = false;

  CodexAppServerRpcClient(
    this.socket, {
    this.defaultTimeout = const Duration(seconds: 12),
  }) : _subscription = socket.messages.listen((_) {}) {
    _subscription
      ..onData(_onMessage)
      ..onError((Object _) => _failPending())
      ..onDone(_failPending);
  }

  Future<Object?> request(
    String method,
    Map<String, dynamic> params, {
    Duration? timeout,
  }) async {
    if (_closed) throw const CodexAppServerDisconnected();
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    socket.send(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    try {
      return await completer.future.timeout(timeout ?? defaultTimeout);
    } on TimeoutException {
      _pending.remove(id);
      throw TimeoutException('Codex App Server $method request timed out.');
    }
  }

  void notify(String method, Map<String, dynamic> params) {
    if (!_closed) {
      socket.send(
        jsonEncode({'jsonrpc': '2.0', 'method': method, 'params': params}),
      );
    }
  }

  void respond(int id, Object? result) {
    if (!_closed) {
      socket.send(jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}));
    }
  }

  void respondError(int id, int code, String message) {
    if (!_closed) {
      socket.send(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': code, 'message': message},
        }),
      );
    }
  }

  void _onMessage(Object? raw) {
    try {
      final decoded = jsonDecode(
        raw is String ? raw : utf8.decode(raw as List<int>),
      );
      if (decoded is! Map) return;
      final id = decoded['id'];
      if (id is int && decoded['method'] is! String) {
        final completer = _pending.remove(id);
        if (completer == null || completer.isCompleted) return;
        final error = decoded['error'];
        if (error is Map) {
          completer.completeError(
            CodexAppServerRpcException(
              error['code'] is int ? error['code'] as int : -32000,
              error['message'] is String
                  ? error['message'] as String
                  : 'Request failed',
            ),
          );
        } else {
          completer.complete(decoded['result']);
        }
      }
    } catch (_) {
      // Invalid frames are ignored; request deadlines remain bounded.
    }
  }

  void _failPending() {
    if (_closed) return;
    _closed = true;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const CodexAppServerDisconnected());
      }
    }
    _pending.clear();
  }

  Future<void> close() async {
    if (!_closed) _failPending();
    await _subscription.cancel();
    await socket.close();
  }
}

class CodexAppServerResponse {
  final int statusCode;
  final Object body;
  const CodexAppServerResponse(this.statusCode, this.body);
}

class CodexAppServerService {
  final CodexAppServerProcessLauncher processLauncher;
  final CodexAppServerSocketConnector socketConnector;
  final Directory? temporaryDirectory;

  CodexAppServerService({
    CodexAppServerProcessLauncher? processLauncher,
    CodexAppServerSocketConnector? socketConnector,
    this.temporaryDirectory,
  })  : processLauncher = processLauncher ?? IoCodexAppServerProcessLauncher(),
        socketConnector = socketConnector ?? IoCodexAppServerSocketConnector();

  Future<CodexAppServerStatusResult> status() async {
    try {
      final session = await _start();
      try {
        await session.rpc.request('initialize', {
          'clientInfo': {
            'name': 'stroom-codex-app-server-status',
            'title': 'Stroom',
            'version': '0.6',
          },
          'capabilities': null,
        });
        final status = await _readAccount(session.rpc);
        return CodexAppServerStatusResult(
          status,
          status == CodexAppServerStatus.authenticated
              ? 'Codex CLI is signed in.'
              : status == CodexAppServerStatus.signedOut
                  ? 'Codex App Server is running, but Codex CLI is signed out. Sign in with the official Codex CLI.'
                  : 'Codex App Server account status is unknown.',
          status == CodexAppServerStatus.authenticated
              ? 'codex_cli_ready'
              : status == CodexAppServerStatus.signedOut
                  ? 'codex_cli_not_signed_in'
                  : 'codex_app_server_unknown',
        );
      } finally {
        await session.close();
      }
    } on ProcessException catch (error) {
      return CodexAppServerStatusResult(
        error.errorCode == 2 || error.errorCode == -2
            ? CodexAppServerStatus.unavailable
            : CodexAppServerStatus.unknown,
        error.errorCode == 2 || error.errorCode == -2
            ? 'Codex CLI was not found. Install the official Codex CLI.'
            : 'Codex App Server could not be started.',
        error.errorCode == 2 || error.errorCode == -2
            ? 'codex_cli_not_installed'
            : 'codex_app_server_unavailable',
      );
    } catch (_) {
      return const CodexAppServerStatusResult(
        CodexAppServerStatus.unavailable,
        'Codex App Server is unavailable. Check that the official Codex CLI can start.',
        'codex_app_server_unavailable',
      );
    }
  }

  Future<CodexAppServerResponse> request({
    required Map<String, dynamic> body,
    required String modelId,
    required bool stream,
    required CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    final request = CodexAppServerRequest.fromResponsesBody(
      body,
      modelId: modelId,
    );
    final session = await _start();
    try {
      await session.rpc.request('initialize', {
        'clientInfo': {
          'name': 'stroom-codex-app-server',
          'title': 'Stroom',
          'version': '0.6',
        },
        'capabilities': request.dynamicTools.isNotEmpty
            ? {'experimentalApi': true, 'requestAttestation': false}
            : null,
      });
      final accountState = await _readAccount(session.rpc);
      if (accountState == CodexAppServerStatus.signedOut) {
        throw const CodexAppServerRpcException(
          -32001,
          'Codex CLI sign-in required',
        );
      }
      if (accountState != CodexAppServerStatus.authenticated) {
        throw const CodexAppServerDisconnected();
      }
    } catch (_) {
      try {
        await session.close();
      } catch (_) {}
      rethrow;
    }
    final output = _CodexResponseOutput(modelId);
    var terminal = false;
    final done = Completer<void>();
    late void Function() cancelStream;
    final events = StreamController<String>(
      onCancel: () async {
        cancelStream();
        await session.close();
      },
    );
    final translator = CodexAppServerEventTranslator((event) {
      if (terminal) return;
      output.add(event);
      if (stream) events.add(output.sse(event));
      if (event is CodexAppServerCompleted ||
          event is CodexAppServerFailed ||
          event is CodexAppServerToolCall) {
        if (event is CodexAppServerToolCall) output.finishToolTurn();
        if (!done.isCompleted) done.complete();
        terminal = true;
        if (stream) {
          if (event is CodexAppServerToolCall) {
            events.add(output.completedSse());
          }
        }
      }
    });
    session.rpc._subscription.onData((raw) {
      session.rpc._onMessage(raw);
      final decoded = _decodeRpc(raw);
      if (decoded == null || decoded['method'] is! String) return;
      final method = decoded['method'] as String;
      final id = decoded['id'];
      final params = decoded['params'];
      if (id is int) {
        if (method == 'item/tool/call') {
          translator.toolCall(
            params,
            customNames: request.customToolNames,
            toolSearchNames: request.toolSearchNames,
            namespaces: request.toolNamespaces,
            namespacedNames: request.namespacedToolNames,
          );
          session.rpc.respond(id, {
            'contentItems': [
              {'type': 'inputText', 'text': 'Stroom will execute this tool.'},
            ],
            'success': false,
          });
        } else if (_isApprovalRequest(method)) {
          session.rpc.respond(id, {
            'decision': 'denied',
            'note': 'Denied by Stroom policy.',
          });
        } else {
          session.rpc.respondError(
            id,
            -32601,
            'Unsupported Codex App Server request.',
          );
        }
        return;
      }
      if (translator.notification(method, params)) {
        if (!done.isCompleted) done.complete();
        terminal = true;
      }
    });

    void cancel() {
      if (!terminal) {
        session.rpc.notify('turn/interrupt', {
          'threadId': session.threadId,
          'turnId': '',
        });
        terminal = true;
        if (!done.isCompleted) done.complete();
      }
    }

    cancelStream = cancel;

    cancelToken?.whenCancel.then((_) => cancel());

    Future<void> run() async {
      try {
        if (terminal) return;
        final thread = await session.rpc.request('thread/start', {
          'cwd': workingDirectory ?? session.workspace.path,
          'approvalPolicy': 'never',
          'sandbox': 'read-only',
          if (request.dynamicTools.isNotEmpty)
            'dynamicTools': request.dynamicTools,
        });
        if (terminal) return;
        final threadMap = thread is Map ? thread : const <Object?, Object?>{};
        final threadData = threadMap['thread'];
        final threadId =
            threadData is Map ? threadData['id'] : threadMap['threadId'];
        if (threadId is! String || threadId.isEmpty) {
          throw const CodexAppServerDisconnected();
        }
        session.threadId = threadId;
        await session.rpc.request('turn/start', {
          'threadId': threadId,
          'input': [
            {'type': 'text', 'text': request.prompt, 'text_elements': []},
          ],
          'model': request.model,
          if (request.effort != null) 'effort': request.effort,
        });
        if (terminal) return;
        await done.future.timeout(const Duration(minutes: 2));
      } catch (error) {
        if (!terminal) {
          final failure = CodexAppServerFailed(_safeError(error.toString()));
          output.add(failure);
          if (stream) {
            events.add(output.sse(failure));
          }
          terminal = true;
        }
      } finally {
        await session.close();
        if (stream) await events.close();
      }
    }

    if (stream) {
      unawaited(run());
      return CodexAppServerResponse(
        200,
        events.stream.map<List<int>>(utf8.encode),
      );
    }
    await run();
    return CodexAppServerResponse(output.failed ? 502 : 200, output.toJson());
  }

  Future<_CodexAppServerSession> _start() async {
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      throw const CodexAppServerUnsupportedRequest('desktop_only');
    }
    final directory = await (temporaryDirectory ?? Directory.systemTemp)
        .createTemp('stroom-codex-app-server-');
    CodexAppServerProcess? process;
    try {
      if (!Platform.isWindows) {
        await Process.run('chmod', ['700', directory.path], runInShell: false);
      }
      final token = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final tokenString =
          token.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      final tokenFile = File(p.join(directory.path, 'capability-token'));
      await tokenFile.writeAsString(tokenString, flush: true);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['600', tokenFile.path], runInShell: false);
      }
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final launch = CodexAppServerLaunch(
        port: port,
        tokenFilePath: tokenFile.path,
      );
      process = await processLauncher.start(launch);
      process.stdout.listen((_) {});
      process.stderr.listen((_) {});
      final rpc = await _connectWithRetry(port, tokenString, process);
      return _CodexAppServerSession(directory, process, rpc);
    } catch (_) {
      try {
        await process?.terminate(force: true);
      } catch (_) {}
      try {
        await directory.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  Future<CodexAppServerRpcClient> _connectWithRetry(
    int port,
    String token,
    CodexAppServerProcess process,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        return CodexAppServerRpcClient(
          await socketConnector.connect(
            Uri.parse('ws://127.0.0.1:$port'),
            token,
          ),
        );
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
    // Keep details out of UI diagnostics; the status distinguishes unavailable.
    throw ProcessException('codex', const [], _safeError('$lastError'));
  }

  Future<CodexAppServerStatus> _readAccount(CodexAppServerRpcClient rpc) async {
    try {
      final account = await rpc.request('account/read', const {});
      return codexAppServerStatusFromAccountRead(account);
    } catch (error) {
      return codexAppServerStatusFromAccountReadError(error);
    }
  }
}

bool _isApprovalRequest(String method) => const {
      'item/commandExecution/requestApproval',
      'item/fileChange/requestApproval',
      'item/permissions/requestApproval',
      'applyPatchApproval',
      'execCommandApproval',
    }.contains(method);

class _CodexAppServerSession {
  final Directory workspace;
  final CodexAppServerProcess process;
  final CodexAppServerRpcClient rpc;
  String threadId = '';
  var _closed = false;
  _CodexAppServerSession(this.workspace, this.process, this.rpc);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await rpc.close();
    try {
      await process.terminate();
    } catch (_) {}
    try {
      await process.exitCode.timeout(const Duration(seconds: 1));
    } catch (_) {
      try {
        await process.terminate(force: true);
      } catch (_) {}
    }
    try {
      await workspace.delete(recursive: true);
    } catch (_) {}
  }
}

class _CodexResponseOutput {
  final String model;
  final StringBuffer text = StringBuffer();
  final StringBuffer reasoning = StringBuffer();
  final List<Map<String, dynamic>> calls = [];
  Map<String, dynamic> usage = const {};
  var failed = false;
  String? error;
  _CodexResponseOutput(this.model);

  void add(CodexAppServerEvent event) {
    switch (event) {
      case CodexAppServerTextDelta(:final text):
        this.text.write(text);
      case CodexAppServerReasoningDelta(:final text):
        reasoning.write(text);
      case CodexAppServerToolCall():
        calls.add(_toolOutputItem(event));
      case CodexAppServerCompleted(:final usage):
        this.usage = usage;
      case CodexAppServerFailed(:final message):
        failed = true;
        error = message;
    }
  }

  void finishToolTurn() {}
  List<Map<String, dynamic>> get output => [
        if (reasoning.isNotEmpty)
          {
            'id': 'reasoning-1',
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': reasoning.toString()},
            ],
          },
        if (text.isNotEmpty)
          {
            'id': 'message-1',
            'type': 'message',
            'role': 'assistant',
            'content': [
              {
                'type': 'output_text',
                'text': text.toString(),
                'annotations': []
              },
            ],
          },
        ...calls,
      ];

  Map<String, dynamic> toJson() => {
        'id': 'resp_stroom_codex',
        'object': 'response',
        'status': failed ? 'failed' : 'completed',
        'model': model,
        'output': output,
        'output_text': text.toString(),
        if (error != null) 'error': {'message': error},
        if (usage.isNotEmpty) 'usage': usage,
      };

  String sse(CodexAppServerEvent event) {
    final data = switch (event) {
      CodexAppServerTextDelta(:final text) => {
          'type': 'response.output_text.delta',
          'delta': text,
        },
      CodexAppServerReasoningDelta(:final text) => {
          'type': 'response.reasoning_summary_text.delta',
          'delta': text,
        },
      CodexAppServerToolCall() => {
          'type': 'response.output_item.done',
          'item': _toolOutputItem(event),
        },
      CodexAppServerFailed(:final message) => {
          'type': 'response.failed',
          'response': {
            'error': {'message': message},
          },
        },
      CodexAppServerCompleted() => {
          'type': 'response.completed',
          'response': toJson(),
        },
    };
    return 'data: ${jsonEncode(data)}\n\n';
  }

  String completedSse() => 'data: ${jsonEncode({
            'type': 'response.completed',
            'response': toJson()
          })}\n\n';
}

Map<String, dynamic> _toolOutputItem(CodexAppServerToolCall call) {
  if (call.type == 'tool_search_call') {
    Object? arguments;
    try {
      arguments = jsonDecode(call.arguments);
    } catch (_) {
      arguments = const <String, dynamic>{};
    }
    return {
      'id': call.id,
      'call_id': call.id,
      'type': 'tool_search_call',
      'execution': 'client',
      'arguments': arguments is Map ? arguments : const <String, dynamic>{},
      'status': 'completed',
    };
  }
  if (call.type == 'custom_tool_call') {
    var input = call.arguments;
    try {
      final decoded = jsonDecode(call.arguments);
      if (decoded is Map && decoded['input'] is String) {
        input = decoded['input'] as String;
      }
    } catch (_) {}
    return {
      'id': call.id,
      'call_id': call.id,
      'type': 'custom_tool_call',
      'name': call.name,
      'input': input,
      'status': 'completed',
    };
  }
  return {
    'id': call.id,
    'call_id': call.id,
    'type': 'function_call',
    'name': call.name,
    'arguments': call.arguments,
    if (call.namespace != null) 'namespace': call.namespace,
    'status': 'completed',
  };
}

Map<String, dynamic>? _decodeRpc(Object? raw) {
  try {
    final value = jsonDecode(
      raw is String ? raw : utf8.decode(raw as List<int>),
    );
    return value is Map ? Map<String, dynamic>.from(value) : null;
  } catch (_) {
    return null;
  }
}

String _safeError(String message) {
  final sanitized = message
      .replaceAll(
        RegExp(
          r'(authorization|bearer|token|secret)[=: ]+[^\s,;]+',
          caseSensitive: false,
        ),
        r'$1=[redacted]',
      )
      .replaceAll(RegExp(r'[/\\][^\s:]+\.codex[^\s:]*'), '[local Codex data]');
  return sanitized.length > 240 ? '${sanitized.substring(0, 240)}…' : sanitized;
}
