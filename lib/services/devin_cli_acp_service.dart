import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../ai_gateway/ai_gateway_contracts.dart';
import 'devin_cli_acp.dart';

abstract interface class DevinCliAcpProcess {
  Stream<List<int>> get stdoutBytes;
  Stream<String> get stdoutLines;
  Future<void> writeLine(String line);
  Future<int> get exitCode;
  Future<void> terminate();
}

abstract interface class DevinCliAcpProcessLauncher {
  Future<DevinCliAcpProcess> start(
    DevinCliAcpLaunch launch, {
    required String workingDirectory,
  });
}

abstract final class DevinCliAcpProcessShutdown {
  static Future<void> terminateAndWait({
    required Future<int> exitCode,
    required void Function() terminate,
    required void Function() forceTerminate,
    Duration gracefulTimeout = const Duration(seconds: 2),
  }) async {
    terminate();
    try {
      await exitCode.timeout(gracefulTimeout);
    } on TimeoutException {
      forceTerminate();
      await exitCode;
    }
  }
}

typedef _StartedDevinCliAcpSession = ({
  Directory workspace,
  DevinCliAcpProcess process,
  _DevinCliAcpRpc rpc,
  String sessionId,
});

const _notificationWriteTimeout = Duration(seconds: 1);

class IoDevinCliAcpProcessLauncher implements DevinCliAcpProcessLauncher {
  @override
  Future<DevinCliAcpProcess> start(
    DevinCliAcpLaunch launch, {
    required String workingDirectory,
  }) async {
    if (kIsWeb ||
        !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      throw UnsupportedError('Devin CLI ACP is available on desktop only.');
    }
    const allowedCommands = <String>{
      'acp',
      'auth login',
      'auth status',
      'auth logout',
    };
    if (!allowedCommands.contains(launch.arguments.join(' '))) {
      throw ArgumentError('Unsupported Devin CLI command.');
    }
    final executableCopy = await launch.prepareApprovedExecutableCopy();
    late final Process process;
    try {
      process = await Process.start(
        executableCopy.executablePath,
        launch.arguments,
        workingDirectory: workingDirectory,
        environment: launch.environment,
        includeParentEnvironment: launch.includeParentEnvironment,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
    } catch (_) {
      try {
        await executableCopy.directory.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
    // Drain stderr without retaining it: CLI diagnostics can contain secrets.
    process.stderr.listen((_) {}, onError: (Object _, StackTrace _) {});
    return _IoDevinCliAcpProcess(process, executableCopy.directory);
  }
}

class _IoDevinCliAcpProcess implements DevinCliAcpProcess {
  final Process _process;
  final Directory _executableDirectory;
  late final Future<int> _exitCode;
  late final Stream<String> _stdoutLines = DevinCliAcpJsonRpc.decodeLines(
    stdoutBytes,
  );

  _IoDevinCliAcpProcess(this._process, this._executableDirectory) {
    _exitCode = _process.exitCode.whenComplete(_deleteExecutableCopy);
  }

  Future<void> _deleteExecutableCopy() async {
    try {
      await _executableDirectory.delete(recursive: true);
    } catch (_) {}
  }

  @override
  Stream<List<int>> get stdoutBytes => _process.stdout;

  @override
  Stream<String> get stdoutLines => _stdoutLines;

  @override
  Future<void> writeLine(String line) async {
    _process.stdin.write(line);
    await _process.stdin.flush();
  }

  @override
  Future<int> get exitCode => _exitCode;

  @override
  Future<void> terminate() async {
    await DevinCliAcpProcessShutdown.terminateAndWait(
      exitCode: _exitCode,
      terminate: () => _process.kill(),
      forceTerminate: () {
        if (Platform.isWindows) {
          _process.kill();
        } else {
          _process.kill(ProcessSignal.sigkill);
        }
      },
    );
  }
}

/// Executes the documented official Devin CLI ACP command for one request.
/// No client filesystem or terminal capabilities are advertised, so the CLI
/// cannot ask Stroom to run an arbitrary command or read arbitrary paths.
class DevinCliAcpService implements AiGatewayLocalCliAuthentication {
  final DevinCliAcpProcessLauncher _launcher;
  final Future<String> Function() _supportDirectory;
  final Map<String, String> Function() _parentEnvironment;
  final Map<String, Set<DevinCliAcpProcess>> _activeProcesses = {};
  final Map<String, Future<void>> _logoutInFlight = {};
  final Map<String, Future<void>> _accountLifecycle = {};
  final Set<String> _loggedOutAccounts = {};

  DevinCliAcpService({
    DevinCliAcpProcessLauncher? launcher,
    Future<String> Function()? supportDirectory,
    Map<String, String> Function()? parentEnvironment,
  })  : _launcher = launcher ?? IoDevinCliAcpProcessLauncher(),
        _supportDirectory = supportDirectory ?? _defaultSupportDirectory,
        _parentEnvironment = parentEnvironment ?? (() => Platform.environment);

  static Future<String> _defaultSupportDirectory() async =>
      (await getApplicationSupportDirectory()).path;

  @override
  Future<void> login(AiGatewayAccount account) async {
    if (account.connectorType != 'devin-cli-agentic' ||
        account.authType != 'cli_session') {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
    }
    if (!_hasExecutableApproval(account)) {
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.authenticationRequired,
      );
    }
    await _withAccountLifecycle(account.id, () async {
      final home = await _home(account.id);
      final launch = DevinCliAcpLaunch.forLogin(
        homePath: home.path,
        executablePath: _approvedExecutablePath(account),
        executableSha256: _approvedExecutableSha256(account),
        parentEnvironment: _parentEnvironment(),
      );
      late final DevinCliAcpProcess process;
      try {
        process = await _launcher.start(launch, workingDirectory: home.path);
      } on DevinCliAcpExecutableApprovalException {
        throw AiGatewayExecutionException(
          kind: AiGatewayFailureKind.authenticationRequired,
        );
      } catch (_) {
        throw AiGatewayExecutionException(
          kind: AiGatewayFailureKind.transportUnavailable,
        );
      }
      _track(account.id, process);
      try {
        _discardStdout(process);
        final result = await process.exitCode.timeout(
          const Duration(minutes: 5),
        );
        if (result != 0) {
          throw AiGatewayExecutionException(
            kind: AiGatewayFailureKind.authenticationRequired,
          );
        }
        _loggedOutAccounts.remove(account.id);
      } on TimeoutException {
        await process.terminate();
        throw AiGatewayExecutionException(
          kind: AiGatewayFailureKind.authenticationRequired,
        );
      } finally {
        await process.terminate();
        _activeProcesses[account.id]?.remove(process);
      }
    });
  }

  @override
  Future<void> logout(AiGatewayAccount account) async {
    if (account.connectorType != 'devin-cli-agentic' ||
        account.authType != 'cli_session') {
      return;
    }
    final existing = _logoutInFlight[account.id];
    if (existing != null) return existing;
    final logout = _withAccountLifecycle(account.id, () async {
      _loggedOutAccounts.add(account.id);
      final active =
          _activeProcesses.remove(account.id) ?? <DevinCliAcpProcess>{};
      await Future.wait([
        for (final process in active) process.terminate(),
      ]);
      final home = await _home(account.id);
      await _logoutAndDelete(home, account);
    }).whenComplete(() {
      _logoutInFlight.remove(account.id);
    });
    _logoutInFlight[account.id] = logout;
    return logout;
  }

  Future<T> _withAccountLifecycle<T>(
    String accountId,
    Future<T> Function() action, {
    CancelToken? cancelToken,
  }) async {
    final previous = _accountLifecycle[accountId] ?? Future<void>.value();
    final gate = Completer<void>();
    final current = gate.future;
    _accountLifecycle[accountId] = current;
    var previousCompleted = false;
    try {
      await _awaitWithCancellation(previous, cancelToken);
      previousCompleted = true;
      _throwIfCancelled(cancelToken);
      return await action();
    } finally {
      void releaseGate() {
        if (!gate.isCompleted) gate.complete();
        if (identical(_accountLifecycle[accountId], current)) {
          _accountLifecycle.remove(accountId);
        }
      }

      if (previousCompleted) {
        releaseGate();
      } else {
        unawaited(previous.whenComplete(releaseGate));
      }
    }
  }

  Future<void> _logoutAndDelete(
    Directory home,
    AiGatewayAccount account,
  ) async {
    DevinCliAcpProcess? process;
    var processStopped = true;
    try {
      process = await _launcher.start(
        DevinCliAcpLaunch.forLogout(
          homePath: home.path,
          executablePath: _approvedExecutablePath(account),
          executableSha256: _approvedExecutableSha256(account),
          parentEnvironment: _parentEnvironment(),
        ),
        workingDirectory: home.path,
      );
      processStopped = false;
      _discardStdout(process);
      await process.exitCode.timeout(const Duration(seconds: 30));
    } catch (_) {
      // CLI output is not retained; process termination below is mandatory.
    } finally {
      if (process != null) {
        try {
          await process.terminate();
          processStopped = true;
        } catch (_) {}
      }
    }
    if (!processStopped) {
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
      );
    }
    try {
      if (await home.exists()) await home.delete(recursive: true);
    } catch (_) {
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
      );
    }
  }

  @override
  Future<bool> isAuthenticated(
    AiGatewayAccount account, {
    CancelToken? cancelToken,
  }) async {
    if (account.connectorType != 'devin-cli-agentic' ||
        account.authType != 'cli_session') {
      return false;
    }
    if (!_hasExecutableApproval(account)) return false;
    return _withAccountLifecycle(account.id, () async {
      _throwIfCancelled(cancelToken);
      if (_loggedOutAccounts.contains(account.id)) return false;
      final home = await _home(account.id);
      late final DevinCliAcpProcess process;
      try {
        process = await _launcher.start(
          DevinCliAcpLaunch.forStatus(
            homePath: home.path,
            executablePath: _approvedExecutablePath(account),
            executableSha256: _approvedExecutableSha256(account),
            parentEnvironment: _parentEnvironment(),
          ),
          workingDirectory: home.path,
        );
      } on DevinCliAcpExecutableApprovalException {
        throw AiGatewayExecutionException(
          kind: AiGatewayFailureKind.authenticationRequired,
        );
      } catch (_) {
        throw AiGatewayExecutionException(
          kind: AiGatewayFailureKind.transportUnavailable,
        );
      }
      _track(account.id, process);
      _discardStdout(process);
      try {
        return await _awaitWithCancellation(
              process.exitCode.timeout(const Duration(seconds: 15)),
              cancelToken,
            ) ==
            0;
      } on TimeoutException {
        return false;
      } finally {
        await process.terminate();
        _activeProcesses[account.id]?.remove(process);
      }
    }, cancelToken: cancelToken);
  }

  Future<AiGatewayResponse> request({
    required AiGatewayAccount account,
    required String modelId,
    required Object? body,
    bool stream = false,
    CancelToken? cancelToken,
    Future<void> Function()? onRequestSent,
  }) async {
    if (account.connectorType != 'devin-cli-agentic' ||
        account.authType != 'cli_session' ||
        modelId != 'devin-cli-default') {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
    }
    if (body is! Map) {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
    }
    final configuredTools = body['tools'];
    if (configuredTools is List && configuredTools.isNotEmpty ||
        body['tool_choice'] != null ||
        body['functions'] != null ||
        body['function_call'] != null ||
        body['response_format'] != null) {
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
        code: 'unsupported_capability',
      );
    }
    if (cancelToken?.isCancelled == true) {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.cancelled);
    }
    final authenticated = await isAuthenticated(
      account,
      cancelToken: cancelToken,
    );
    _throwIfCancelled(cancelToken);
    if (!authenticated) {
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.authenticationRequired,
      );
    }

    final prompt = _promptText(Map<String, dynamic>.from(body));
    if (stream) {
      return AiGatewayResponse(
        statusCode: 200,
        body: _streamRequest(
          account: account,
          prompt: prompt,
          cancelToken: cancelToken,
          onRequestSent: onRequestSent,
        ),
      );
    }

    final started = await _startSession(account, cancelToken: cancelToken);
    final responseStream = _streamPrompt(
      rpc: started.rpc,
      process: started.process,
      accountId: account.id,
      workspace: started.workspace,
      sessionId: started.sessionId,
      prompt: prompt,
      cancelToken: cancelToken,
      onRequestSent: onRequestSent,
    );
    final text = await _collectText(responseStream);
    return AiGatewayResponse(
      statusCode: 200,
      body: {
        'id': 'devin-cli-acp',
        'model': modelId,
        'choices': [
          {
            'index': 0,
            'message': {'role': 'assistant', 'content': text},
            'finish_reason': 'stop',
          },
        ],
      },
    );
  }

  Future<_StartedDevinCliAcpSession> _startSession(
    AiGatewayAccount account, {
    required CancelToken? cancelToken,
  }) async {
    Directory? workspace;
    DevinCliAcpProcess? process;
    _DevinCliAcpRpc? rpc;
    try {
      final started = await _withAccountLifecycle(account.id, () async {
        if (_loggedOutAccounts.contains(account.id)) {
          throw AiGatewayExecutionException(
            kind: AiGatewayFailureKind.authenticationRequired,
          );
        }
        final home = await _home(account.id);
        final requestWorkspace = await Directory.systemTemp.createTemp(
          'stroom-devin-cli-',
        );
        DevinCliAcpProcess? requestProcess;
        try {
          await permissionsForDirectory(requestWorkspace.path);
          _throwIfCancelled(cancelToken);
          requestProcess = await _launcher.start(
            DevinCliAcpLaunch.forAccount(
              homePath: home.path,
              executablePath: _approvedExecutablePath(account),
              executableSha256: _approvedExecutableSha256(account),
              parentEnvironment: _parentEnvironment(),
              temporaryDirectory: requestWorkspace.path,
            ),
            workingDirectory: requestWorkspace.path,
          );
          _track(account.id, requestProcess);
          _throwIfCancelled(cancelToken);
          return (requestWorkspace, requestProcess);
        } on DevinCliAcpExecutableApprovalException {
          if (requestProcess != null) {
            await requestProcess.terminate();
            _activeProcesses[account.id]?.remove(requestProcess);
          }
          await _deleteWorkspace(requestWorkspace);
          throw AiGatewayExecutionException(
            kind: AiGatewayFailureKind.authenticationRequired,
          );
        } catch (_) {
          if (requestProcess != null) {
            await requestProcess.terminate();
            _activeProcesses[account.id]?.remove(requestProcess);
          }
          await _deleteWorkspace(requestWorkspace);
          rethrow;
        }
      }, cancelToken: cancelToken);
      workspace = started.$1;
      process = started.$2;
      rpc = _DevinCliAcpRpc(process);
      final initialized = await _awaitWithCancellation(
        rpc.request('initialize', const {
          'protocolVersion': DevinCliAcpJsonRpc.protocolVersion,
          'clientInfo': {'name': 'Stroom', 'version': '0.6'},
          'clientCapabilities': <String, Object?>{},
        }),
        cancelToken,
      );
      _throwIfCancelled(cancelToken);
      DevinCliAcpJsonRpc.validateNegotiatedVersion(
        initialized['protocolVersion'],
      );
      final session = await _awaitWithCancellation(
        rpc.request('session/new', {
          'cwd': workspace.path,
          'mcpServers': const <Object?>[],
        }),
        cancelToken,
      );
      _throwIfCancelled(cancelToken);
      final sessionId = session['sessionId'];
      if (sessionId is! String || sessionId.isEmpty) {
        throw const FormatException('Invalid ACP session response.');
      }
      return (
        workspace: workspace,
        process: process,
        rpc: rpc,
        sessionId: sessionId,
      );
    } on AiGatewayExecutionException {
      await _disposeRequestResources(account.id, rpc, process, workspace);
      rethrow;
    } on DevinCliAcpExecutableApprovalException {
      await _disposeRequestResources(account.id, rpc, process, workspace);
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.authenticationRequired,
      );
    } on DevinCliAcpUnsupportedProtocolVersion {
      await _disposeRequestResources(account.id, rpc, process, workspace);
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
        code: 'unsupported_acp_protocol',
      );
    } on UnsupportedError {
      await _disposeRequestResources(account.id, rpc, process, workspace);
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
        code: 'unsupported_capability',
      );
    } catch (_) {
      await _disposeRequestResources(account.id, rpc, process, workspace);
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
      );
    }
  }

  Stream<List<int>> _streamRequest({
    required AiGatewayAccount account,
    required String prompt,
    required CancelToken? cancelToken,
    required Future<void> Function()? onRequestSent,
  }) {
    final streamCancelToken = CancelToken();
    if (cancelToken != null) {
      cancelToken.whenCancel.then((cancel) {
        if (!streamCancelToken.isCancelled) streamCancelToken.cancel(cancel);
      });
    }
    var started = false;
    StreamSubscription<List<int>>? responseSubscription;
    final setupComplete = Completer<void>();
    late final StreamController<List<int>> output;
    output = StreamController<List<int>>(
      onListen: () {
        if (started) return;
        started = true;
        unawaited(() async {
          try {
            final session = await _startSession(
              account,
              cancelToken: streamCancelToken,
            );
            if (!output.hasListener) {
              await _disposeStartedSession(account.id, session);
              return;
            }
            responseSubscription = _streamPrompt(
              rpc: session.rpc,
              process: session.process,
              accountId: account.id,
              workspace: session.workspace,
              sessionId: session.sessionId,
              prompt: prompt,
              cancelToken: streamCancelToken,
              onRequestSent: onRequestSent,
            ).listen(
              output.add,
              onError: output.addError,
              onDone: output.close,
            );
          } catch (error, stackTrace) {
            if (!setupComplete.isCompleted) setupComplete.complete();
            if (output.hasListener) {
              output.addError(error, stackTrace);
              if (!output.isClosed) await output.close();
            }
          } finally {
            if (!setupComplete.isCompleted) setupComplete.complete();
          }
        }());
      },
      onCancel: () async {
        if (!streamCancelToken.isCancelled) {
          streamCancelToken.cancel('The streaming request was canceled.');
        }
        await responseSubscription?.cancel();
        if (started) await setupComplete.future;
      },
    );
    return output.stream;
  }

  Future<void> _disposeRequestResources(
    String accountId,
    _DevinCliAcpRpc? rpc,
    DevinCliAcpProcess? process,
    Directory? workspace,
  ) async {
    await rpc?.dispose();
    await process?.terminate();
    if (process != null) _activeProcesses[accountId]?.remove(process);
    if (workspace != null) await _deleteWorkspace(workspace);
  }

  Future<void> _disposeStartedSession(
    String accountId,
    _StartedDevinCliAcpSession session,
  ) async {
    try {
      await session.rpc.notify('session/close', {
        'sessionId': session.sessionId,
      });
    } catch (_) {}
    await _disposeRequestResources(
      accountId,
      session.rpc,
      session.process,
      session.workspace,
    );
  }

  void _track(String accountId, DevinCliAcpProcess process) {
    _activeProcesses
        .putIfAbsent(accountId, () => <DevinCliAcpProcess>{})
        .add(process);
  }

  void _discardStdout(DevinCliAcpProcess process) {
    process.stdoutBytes.listen((_) {}, onError: (Object _, StackTrace _) {});
  }

  static bool _hasExecutableApproval(AiGatewayAccount account) =>
      _approvedExecutablePath(account).isNotEmpty &&
      _approvedExecutableSha256(account).isNotEmpty;

  static String _approvedExecutablePath(AiGatewayAccount account) {
    final value = account.endpointConfig[DevinCliAcpLaunch.executablePathKey];
    return value is String ? value : '';
  }

  static String _approvedExecutableSha256(AiGatewayAccount account) {
    final value = account.endpointConfig[DevinCliAcpLaunch.executableSha256Key];
    return value is String ? value : '';
  }

  Future<Directory> _home(String accountId) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
        code: 'unsupported_capability',
      );
    }
    try {
      return await DevinCliAcpHome.createForAccountAt(
        supportDirectory: await _supportDirectory(),
        accountId: accountId,
      );
    } on DevinCliAcpUnsafeHomePathException {
      throw _unsafeAccountHome();
    }
  }

  static AiGatewayExecutionException _unsafeAccountHome() =>
      AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
        code: 'unsafe_account_home',
      );

  static Future<void> permissionsForDirectory(String path) =>
      DevinCliAcpHome.restrictDirectory(path);

  static Future<T> _awaitWithCancellation<T>(
    Future<T> operation,
    CancelToken? cancelToken,
  ) {
    if (cancelToken == null) return operation;
    return Future.any([
      operation,
      cancelToken.whenCancel.then((_) {
        throw AiGatewayExecutionException(kind: AiGatewayFailureKind.cancelled);
      }),
    ]);
  }

  static void _throwIfCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled == true) {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.cancelled);
    }
  }

  static String _promptText(Map body) {
    final messages = body['messages'];
    if (messages is! List || messages.isEmpty) {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
    }
    final transcript = StringBuffer();
    for (final raw in messages) {
      if (raw is! Map || raw['role'] is! String) {
        throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
      }
      final role = raw['role'] as String;
      if (raw['tool_calls'] is List && (raw['tool_calls'] as List).isNotEmpty) {
        throw AiGatewayExecutionException(
          kind: AiGatewayFailureKind.transportUnavailable,
          code: 'unsupported_capability',
        );
      }
      final content = raw['content'];
      if (content is String) {
        transcript.writeln('$role: $content');
        continue;
      }
      if (content is List) {
        final text = StringBuffer();
        for (final item in content) {
          if (item is! Map ||
              item['type'] != 'text' ||
              item['text'] is! String) {
            throw AiGatewayExecutionException(
              kind: AiGatewayFailureKind.transportUnavailable,
              code: 'unsupported_capability',
            );
          }
          text.write(item['text']);
        }
        transcript.writeln('$role: $text');
        continue;
      }
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.request);
    }
    return transcript.toString();
  }

  Stream<List<int>> _streamPrompt({
    required _DevinCliAcpRpc rpc,
    required DevinCliAcpProcess process,
    required String accountId,
    required Directory workspace,
    required String sessionId,
    required String prompt,
    required CancelToken? cancelToken,
    required Future<void> Function()? onRequestSent,
  }) {
    var cancelled = false;
    var started = false;
    Object? updateError;
    Object? streamError;
    StackTrace? streamErrorStack;
    late StreamController<List<int>> output;
    late StreamSubscription<Map<String, dynamic>> updateSubscription;
    final cancelSignal = Completer<void>();
    final cleanupComplete = Completer<void>();

    Future<void> stop() async {
      if (cancelled) return;
      cancelled = true;
      if (!cancelSignal.isCompleted) cancelSignal.complete();
      await rpc.notify('session/cancel', {'sessionId': sessionId});
    }

    void rejectUnsupportedUpdate() {
      updateError = AiGatewayExecutionException(
        kind: AiGatewayFailureKind.transportUnavailable,
        code: 'unsupported_capability',
      );
      unawaited(stop());
    }

    output = StreamController<List<int>>(
      onListen: () {
        if (started) return;
        started = true;
        updateSubscription = rpc.notifications.listen((message) {
          if (message['method'] != 'session/update') return;
          final params = message['params'];
          final update = params is Map ? params['update'] : null;
          if (update is! Map) return;
          final kind = update['sessionUpdate'];
          if (kind == 'agent_message_chunk') {
            final content = update['content'];
            if (content is! Map || content['type'] != 'text') {
              rejectUnsupportedUpdate();
              return;
            }
            final text = content['text'];
            if (text is! String) {
              rejectUnsupportedUpdate();
            } else if (text.isNotEmpty) {
              output.add(_sseContent(text));
            }
          } else if (kind == 'tool_call' || kind == 'tool_call_update') {
            final toolCall = update['toolCall'];
            final title = toolCall is Map ? toolCall['title'] : update['title'];
            if (title is String && title.isNotEmpty) {
              output.add(
                _sseContent('[Devin tool] ${_safeToolTitle(title)}\n'),
              );
            }
          }
        });
        unawaited(() async {
          try {
            final promptResult = rpc.request('session/prompt', {
              'sessionId': sessionId,
              'prompt': [
                {'type': 'text', 'text': prompt},
              ],
            });
            await onRequestSent?.call();
            final response = await Future.any([
              promptResult,
              cancelSignal.future.then((_) {
                throw AiGatewayExecutionException(
                  kind: AiGatewayFailureKind.cancelled,
                );
              }),
              if (cancelToken != null)
                cancelToken.whenCancel.then((_) async {
                  await stop();
                  throw AiGatewayExecutionException(
                    kind: AiGatewayFailureKind.cancelled,
                  );
                }),
            ]);
            if (updateError != null) throw updateError!;
            if (response['stopReason'] == 'cancelled') {
              throw AiGatewayExecutionException(
                kind: AiGatewayFailureKind.cancelled,
              );
            }
            output
              ..add(
                utf8.encode(
                  'data: ${jsonEncode({
                        'choices': [
                          {
                            'index': 0,
                            'delta': <String, Object?>{},
                            'finish_reason': 'stop'
                          },
                        ],
                      })}\n\n',
                ),
              )
              ..add(utf8.encode('data: [DONE]\n\n'));
          } catch (error, stackTrace) {
            if (output.hasListener &&
                (!cancelled ||
                    cancelToken?.isCancelled == true ||
                    updateError != null)) {
              final errorToReport = updateError ?? error;
              streamError = errorToReport is AiGatewayExecutionException
                  ? errorToReport
                  : AiGatewayExecutionException(
                      kind: cancelToken?.isCancelled == true
                          ? AiGatewayFailureKind.cancelled
                          : AiGatewayFailureKind.request,
                    );
              streamErrorStack = stackTrace;
            }
          } finally {
            if (started) await updateSubscription.cancel();
            await _disposeStartedSession(accountId, (
              workspace: workspace,
              process: process,
              rpc: rpc,
              sessionId: sessionId,
            ));
            if (streamError != null && output.hasListener) {
              output.addError(streamError!, streamErrorStack);
            }
            if (!cleanupComplete.isCompleted) cleanupComplete.complete();
            if (!output.isClosed) await output.close();
          }
        }());
      },
      onCancel: () async {
        await stop();
        if (started) await cleanupComplete.future;
      },
    );
    return output.stream;
  }

  static List<int> _sseContent(String text) => utf8.encode(
        'data: ${jsonEncode({
              'choices': [
                {
                  'index': 0,
                  'delta': {'content': text},
                  'finish_reason': null,
                },
              ],
            })}\n\n',
      );

  static String _safeToolTitle(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized.substring(
      0,
      sanitized.length > 200 ? 200 : sanitized.length,
    );
  }

  static Future<String> _collectText(Stream<List<int>> source) async {
    final text = StringBuffer();
    await for (final line
        in source.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final data = line.substring(6);
      if (data == '[DONE]') continue;
      final event = jsonDecode(data);
      if (event is Map && event['choices'] is List) {
        final choices = event['choices'] as List;
        if (choices.isNotEmpty && choices.first is Map) {
          final delta = (choices.first as Map)['delta'];
          if (delta is Map && delta['content'] is String) {
            text.write(delta['content']);
          }
        }
      }
    }
    return text.toString();
  }

  static Future<void> _deleteWorkspace(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      // The account home is private; a failed temp cleanup is not logged.
    }
  }
}

class _DevinCliAcpRpc {
  final DevinCliAcpProcess _process;
  final Map<Object, Completer<Map<String, dynamic>>> _pending = {};
  final StreamController<Map<String, dynamic>> _notifications =
      StreamController.broadcast();
  late final StreamSubscription<String> _stdout;
  var _nextId = 1;
  var _disposed = false;

  _DevinCliAcpRpc(this._process) {
    _stdout = _process.stdoutLines.listen(
      _handleLine,
      onError: (_) => _failPending(),
      onDone: _failPending,
    );
  }

  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  Future<Map<String, dynamic>> request(
    String method,
    Map<String, Object?> params,
  ) async {
    if (_disposed) throw const FormatException('ACP process is closed.');
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    try {
      await _process.writeLine(
        DevinCliAcpJsonRpc.encodeRequest(
          id: id,
          method: method,
          params: params,
        ),
      );
    } catch (_) {
      _pending.remove(id);
      throw const FormatException('ACP request could not be sent.');
    }
    return completer.future.timeout(const Duration(minutes: 5));
  }

  Future<void> notify(String method, Map<String, Object?> params) async {
    if (_disposed) return;
    try {
      await _process
          .writeLine(
            DevinCliAcpJsonRpc.encodeNotification(
              method: method,
              params: params,
            ),
          )
          .timeout(_notificationWriteTimeout);
    } catch (_) {
      // A closed process is handled by the outstanding request/stream.
    }
  }

  void _handleLine(String line) {
    if (line.length > DevinCliAcpJsonRpc.maxFrameBytes) {
      _failPending();
      return;
    }
    Map<String, dynamic> message;
    try {
      message = DevinCliAcpJsonRpc.decodeMessage(line);
    } catch (_) {
      _failPending();
      return;
    }
    final id = message['id'];
    if (id != null && message.containsKey('method')) {
      unawaited(_respondUnsupported(id));
      return;
    }
    if (id != null) {
      final completer = _pending.remove(id);
      if (completer == null || completer.isCompleted) return;
      if (message['error'] != null) {
        completer.completeError(const FormatException('ACP request failed.'));
      } else if (message['result'] is Map) {
        completer.complete(Map<String, dynamic>.from(message['result'] as Map));
      } else {
        completer.completeError(const FormatException('Invalid ACP response.'));
      }
      return;
    }
    if (message['method'] is String) _notifications.add(message);
  }

  Future<void> _respondUnsupported(Object id) async {
    try {
      await _process.writeLine(
        DevinCliAcpJsonRpc.encodeErrorResponse(
          id: id,
          code: -32601,
          message: 'Method not supported',
        ),
      );
    } catch (_) {}
  }

  void _failPending() {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const FormatException('ACP process ended.'));
      }
    }
    _pending.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stdout.cancel();
    _failPending();
    await _notifications.close();
  }
}
