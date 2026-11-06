import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Source-pinned Auggie CLI models and context limits from Auggie v0.32.0.
class AuggieCliModel {
  final String id;
  final String displayName;
  final int contextLength;

  const AuggieCliModel(this.id, this.displayName, this.contextLength);
}

class AuggieCliStatus {
  final bool available;

  const AuggieCliStatus({required this.available});
}

class AuggieCliResponse {
  final int statusCode;
  final Map<String, List<String>> headers;
  final Object body;

  const AuggieCliResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
}

class AuggieCliException implements Exception {
  final String code;
  final String message;

  const AuggieCliException(this.code, this.message);

  @override
  String toString() => message;
}

abstract interface class AuggieCliProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  void writeStdin(List<int> bytes);
  Future<void> closeStdin();
  Future<void> terminate({bool force = false});
  Future<void> dispose();
}

abstract interface class AuggieCliProcessLauncher {
  Future<AuggieCliProcess> start(
    List<String> arguments, {
    required bool runInShell,
    String? workingDirectory,
  });
}

class IoAuggieCliProcessLauncher implements AuggieCliProcessLauncher {
  @override
  Future<AuggieCliProcess> start(
    List<String> arguments, {
    required bool runInShell,
    String? workingDirectory,
  }) async {
    final target = Platform.isWindows
        ? await _resolveWindowsAuggie()
        : const _AuggieLaunchTarget('auggie', []);
    final process = await Process.start(
      target.executable,
      [...target.prefixArguments, ...arguments],
      // The Windows npm .cmd shim is resolved to its Node entry point above,
      // so model IDs and all other arguments never pass through a shell.
      runInShell: false,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.normal,
    );
    return _IoAuggieCliProcess(
      process,
      workingDirectory == null ? null : Directory(workingDirectory),
    );
  }

  Future<_AuggieLaunchTarget> _resolveWindowsAuggie() async {
    final where = await Process.run(
      'where.exe',
      ['auggie'],
      runInShell: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    final candidates = (where.stdout as String)
        .split(RegExp(r'\r?\n'))
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();

    for (final candidate in candidates) {
      if (candidate.toLowerCase().endsWith('.exe')) {
        return _AuggieLaunchTarget(candidate, const []);
      }
      if (!candidate.toLowerCase().endsWith('.cmd')) continue;

      final shim = File(candidate);
      final contents = await shim.readAsString();
      final shimDirectory = _windowsDirectory(candidate);
      final script = _windowsNpmShimScript(contents);
      if (script == null) continue;

      final nodeBesideShim = File('$shimDirectory\\node.exe');
      final node = await nodeBesideShim.exists()
          ? nodeBesideShim.path
          : await _findWindowsNode();
      if (node == null) continue;
      final scriptPath = '$shimDirectory\\${script.replaceAll('/', r'\')}';
      if (!await File(scriptPath).exists()) continue;
      return _AuggieLaunchTarget(node, [scriptPath]);
    }

    throw ProcessException(
      'auggie',
      const [],
      candidates.isEmpty
          ? 'Auggie CLI was not found on PATH.'
          : 'Auggie CLI was found, but no shell-free Windows launcher was available.',
    );
  }

  Future<String?> _findWindowsNode() async {
    final where = await Process.run(
      'where.exe',
      ['node.exe'],
      runInShell: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    for (final line in (where.stdout as String).split(RegExp(r'\r?\n'))) {
      final path = line.trim();
      if (path.isNotEmpty && await File(path).exists()) return path;
    }
    return null;
  }

  static String? _windowsNpmShimScript(String contents) {
    // npm's cmd-shim points Node at the package's JavaScript bin entrypoint.
    // Expand only the generated shim's directory variable; never evaluate the
    // batch file itself.
    final match = RegExp(
      r'"%(?:dp0|basedir)%\\(node_modules\\[^"\r\n]+)"',
      caseSensitive: false,
    ).firstMatch(contents);
    return match?.group(1);
  }

  static String _windowsDirectory(String path) {
    final separator = path.lastIndexOf(RegExp(r'[\\/]'));
    return separator < 0 ? '' : path.substring(0, separator);
  }

  static List<String>? windowsNpmShimCommand({
    required String shimPath,
    required String shimContents,
    required String nodePath,
  }) {
    final script = _windowsNpmShimScript(shimContents);
    if (script == null) return null;
    return [
      nodePath,
      '${_windowsDirectory(shimPath)}\\${script.replaceAll('/', r'\')}',
    ];
  }
}

class _AuggieLaunchTarget {
  final String executable;
  final List<String> prefixArguments;

  const _AuggieLaunchTarget(this.executable, this.prefixArguments);
}

class _IoAuggieCliProcess implements AuggieCliProcess {
  final Process _process;
  final Directory? _workspace;

  const _IoAuggieCliProcess(this._process, this._workspace);

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void writeStdin(List<int> bytes) => _process.stdin.add(bytes);

  @override
  Future<void> closeStdin() => _process.stdin.close();

  @override
  Future<void> terminate({bool force = false}) async {
    _process.kill(force ? ProcessSignal.sigkill : ProcessSignal.sigterm);
  }

  @override
  Future<void> dispose() async {
    try {
      await _workspace?.delete(recursive: true);
    } catch (_) {}
  }
}

class AuggieCliService {
  static const pinnedModels = <AuggieCliModel>[
    AuggieCliModel('sonnet4.6', 'Sonnet 4.6', 200000),
    AuggieCliModel('fable-5', 'Claude Fable 5', 200000),
    AuggieCliModel('haiku4.5', 'Haiku 4.5', 200000),
    AuggieCliModel('sonnet4.5', 'Sonnet 4.5', 200000),
    AuggieCliModel('sonnet4.6-500k', 'Sonnet 4.6 (500K)', 500000),
    AuggieCliModel('sonnet5-high', 'Claude Sonnet 5', 200000),
    AuggieCliModel('sonnet5-500k', 'Sonnet 5 (500K)', 500000),
    AuggieCliModel('opus4.5', 'Opus 4.5', 200000),
    AuggieCliModel('opus4.6', 'Opus 4.6', 200000),
    AuggieCliModel('opus4.6-500k', 'Opus 4.6 (500K)', 500000),
    AuggieCliModel('opus4.7', 'Opus 4.7', 200000),
    AuggieCliModel('opus4.7-500k', 'Opus 4.7 (500K)', 500000),
    AuggieCliModel('opus4.8', 'Opus 4.8', 200000),
    AuggieCliModel('gemini-3.1-pro-preview', 'Gemini 3.1 Pro', 1000000),
    AuggieCliModel('gpt5', 'GPT-5', 200000),
    AuggieCliModel('gpt5.1', 'GPT-5.1', 200000),
    AuggieCliModel('gpt5.2', 'GPT-5.2', 200000),
    AuggieCliModel('gpt5.4', 'GPT-5.4', 200000),
    AuggieCliModel('gpt5.4-mini', 'GPT-5.4 Mini', 200000),
    AuggieCliModel('gpt5.5', 'GPT-5.5', 200000),
    AuggieCliModel('gpt5.6-luna', 'GPT-5.6 Luna', 200000),
    AuggieCliModel('gpt5.6-sol', 'GPT-5.6 Sol', 200000),
    AuggieCliModel('gpt5.6-terra', 'GPT-5.6 Terra', 200000),
    AuggieCliModel('glm-5.2', 'GLM 5.2', 200000),
    AuggieCliModel('kimi-k2.6', 'Kimi K2.6', 131000),
    AuggieCliModel('kimi-k2.7', 'Kimi K2.7 Code', 131000),
    AuggieCliModel('prism-a', 'Prism (Claude + Gemini)', 200000),
    AuggieCliModel('prism-b', 'Prism (GPT + Kimi)', 200000),
  ];

  static const _maxDiscoveryBytes = 64 * 1024;
  static const _maxLiveModels = 256;
  static const _diagnosticTailLength = 128;
  static const _quotaBufferLength = 2048;
  static const _processShutdownGrace = Duration(seconds: 1);
  static const _quotaPatterns = [
    'you have run out of usage',
    'run out of usage for',
    'usage limit exceeded',
  ];
  static const _unsupportedMediaKeys = {
    'image',
    'image_url',
    'images',
    'audio',
    'audio_url',
    'input_audio',
    'video',
    'video_url',
    'attachments',
  };
  static final _modelIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$');

  final AuggieCliProcessLauncher _launcher;
  final bool Function() _supportsLocalProcess;
  final Duration timeout;
  final Map<String, AuggieCliModel> _liveModels = {};

  AuggieCliService({
    AuggieCliProcessLauncher? launcher,
    bool Function()? supportsLocalProcess,
    this.timeout = const Duration(seconds: 45),
  })  : _launcher = launcher ?? IoAuggieCliProcessLauncher(),
        _supportsLocalProcess = supportsLocalProcess ?? _desktopProcessSupport;

  static bool _desktopProcessSupport() =>
      !kIsWeb &&
      const {
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);

  Future<AuggieCliStatus> testConnection() async {
    _requireDesktop();
    AuggieCliProcess process;
    try {
      process = await _start(['--version']);
    } on ProcessException {
      throw const AuggieCliException(
        'auggie_not_installed',
        'Auggie CLI was not found. Install it and sign in with `auggie login`.',
      );
    }
    final stdout = process.stdout.listen((_) {});
    final stderr = process.stderr.listen((_) {});
    try {
      await process.closeStdin();
      final code = await process.exitCode.timeout(timeout);
      if (code != 0) {
        throw const AuggieCliException(
          'auggie_cli_unavailable',
          'Auggie CLI is installed but could not be started. Check the local installation.',
        );
      }
      return const AuggieCliStatus(available: true);
    } on TimeoutException {
      await _terminateAndWait(process);
      throw const AuggieCliException(
        'timeout',
        'Auggie CLI version check timed out.',
      );
    } on ProcessException {
      await _terminateAndWait(process);
      throw const AuggieCliException(
        'auggie_not_installed',
        'Auggie CLI was not found. Install it and sign in with `auggie login`.',
      );
    } catch (_) {
      await _terminateAndWait(process);
      throw const AuggieCliException(
        'process_failure',
        'Auggie CLI version check failed.',
      );
    } finally {
      await stdout.cancel();
      await stderr.cancel();
      await process.dispose();
    }
  }

  Future<List<AuggieCliModel>> discoverModels({bool refresh = false}) async {
    if (!refresh) return List.unmodifiable(_catalog());
    _requireDesktop();
    AuggieCliProcess? process;
    StreamSubscription<List<int>>? stdout;
    StreamSubscription<List<int>>? stderr;
    final output = BytesBuilder(copy: false);
    try {
      process = await _start(['model', 'list']);
      stdout = process.stdout.listen((chunk) {
        if (output.length < _maxDiscoveryBytes) {
          final remaining = _maxDiscoveryBytes - output.length;
          output.add(
            chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
          );
        }
      });
      stderr = process.stderr.listen((_) {});
      await process.closeStdin();
      final code = await process.exitCode.timeout(const Duration(seconds: 8));
      if (code == 0) {
        final text = utf8.decode(output.takeBytes(), allowMalformed: true);
        final discovered = <String, AuggieCliModel>{};
        for (final match in RegExp(r'\[([^\]\r\n]+)\]').allMatches(text)) {
          final id = match.group(1)!.trim();
          if (_modelIdPattern.hasMatch(id) &&
              (discovered.containsKey(id) ||
                  discovered.length < _maxLiveModels)) {
            discovered[id] = _modelFor(id);
          }
        }
        _liveModels
          ..clear()
          ..addAll(discovered);
      }
    } on TimeoutException {
      if (process != null) await _terminateAndWait(process);
    } on ProcessException {
      // Discovery is best-effort; the shipped registry remains usable offline.
      if (process != null) await _terminateAndWait(process);
    } catch (_) {
      // Do not persist or surface local CLI diagnostics from model discovery.
      if (process != null) await _terminateAndWait(process);
    } finally {
      await stdout?.cancel();
      await stderr?.cancel();
      await process?.dispose();
    }
    return List.unmodifiable(_catalog());
  }

  List<AuggieCliModel> _catalog() => [
        ...pinnedModels,
        for (final entry in _liveModels.entries)
          if (!pinnedModels.any((model) => model.id == entry.key)) entry.value,
      ];

  String resolveModel(
    Object? modelId, {
    Iterable<String> knownModelIds = const [],
  }) {
    final requested = modelId is String ? modelId.trim() : '';
    if (requested.isEmpty) return pinnedModels.first.id;
    if (!_modelIdPattern.hasMatch(requested) || requested.startsWith('-')) {
      throw const AuggieCliException(
        'invalid_model',
        'The selected Auggie model ID is invalid.',
      );
    }
    if (!_catalog().any((model) => model.id == requested) &&
        !knownModelIds.contains(requested)) {
      throw const AuggieCliException(
        'unknown_model',
        'The selected Auggie model is not in the known local model catalog. Refresh the catalog and select a listed model.',
      );
    }
    return requested;
  }

  static String buildPrompt(List<dynamic> messages) {
    final lines = <String>[];
    for (final raw in messages) {
      if (raw is! Map) _unsupported();
      final message = Map<String, dynamic>.from(raw);
      if (message.containsKey('tool_calls') ||
          message.containsKey('function_call') ||
          message.keys.any(_unsupportedMediaKeys.contains) ||
          message['role'] == 'tool' ||
          message['role'] == 'function') {
        _unsupported();
      }
      final role = switch (message['role']) {
        'system' => 'System',
        'assistant' => 'Assistant',
        'user' || null => 'User',
        _ => _throwUnsupportedRole(),
      };
      final content = message['content'];
      final text = StringBuffer();
      if (content is String) {
        text.write(content);
      } else if (content is Iterable) {
        for (final part in content) {
          if (part is! Map ||
              part['type'] != 'text' ||
              part['text'] is! String ||
              part.keys.any(_unsupportedMediaKeys.contains)) {
            _unsupported();
          }
          text.write(part['text']);
        }
      } else {
        _unsupported();
      }
      final value = text.toString();
      if (value.trim().isNotEmpty) lines.add('[$role]\n$value');
    }
    return lines.isEmpty ? '(empty)' : lines.join('\n\n');
  }

  Future<AuggieCliResponse> request({
    required String modelId,
    Iterable<String> knownModelIds = const [],
    required Object? body,
    required bool stream,
    CancelToken? cancelToken,
    Future<void> Function()? onRequestSent,
  }) async {
    _requireDesktop();
    if (cancelToken?.isCancelled == true) _cancelled();
    final model = resolveModel(modelId, knownModelIds: knownModelIds);
    final request = body is Map
        ? Map<String, dynamic>.from(body)
        : const <String, dynamic>{};
    if (_hasUnsupportedTools(request) ||
        request.keys.any(_unsupportedMediaKeys.contains)) {
      _unsupported();
    }
    final messages = request['messages'];
    if (messages is! List) _unsupported();
    final prompt = buildPrompt(messages);
    AuggieCliProcess process;
    try {
      process = await _start(['--print', '--quiet', '--model', model, '--']);
    } on ProcessException {
      throw const AuggieCliException(
        'auggie_not_installed',
        'Auggie CLI was not found. Install it and sign in with `auggie login`.',
      );
    }
    if (cancelToken?.isCancelled == true) {
      await _terminateAndWait(process);
      await process.dispose();
      _cancelled();
    }
    try {
      process.writeStdin(utf8.encode(prompt));
      await process.closeStdin();
      await onRequestSent?.call();
    } catch (_) {
      await _terminateAndWait(process);
      await process.dispose();
      throw const AuggieCliException(
        'process_failure',
        'Auggie CLI request failed.',
      );
    }
    if (stream) {
      return AuggieCliResponse(
        statusCode: 200,
        headers: const {
          'content-type': ['text/event-stream'],
        },
        body: _streamResponse(process, model, cancelToken),
      );
    }
    return _bufferResponse(process, prompt, model, cancelToken);
  }

  Future<AuggieCliResponse> _bufferResponse(
    AuggieCliProcess process,
    String prompt,
    String model,
    CancelToken? cancelToken,
  ) async {
    final output = StringBuffer();
    var stderrLogin = false;
    var stderrTail = '';
    var outputReadFailed = false;
    var diagnosticReadFailed = false;
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    final stdout = process.stdout.transform(utf8.decoder).listen(
      output.write,
      onError: (Object _, StackTrace _) {
        outputReadFailed = true;
        if (!stdoutDone.isCompleted) stdoutDone.complete();
      },
      onDone: () {
        if (!stdoutDone.isCompleted) stdoutDone.complete();
      },
    );
    final stderr = process.stderr.listen(
      (bytes) {
        stderrTail = _appendDiagnosticTail(
          stderrTail,
          utf8.decode(bytes, allowMalformed: true),
        );
        stderrLogin = stderrLogin || _looksLikeLoginRequired(stderrTail);
      },
      onError: (Object _, StackTrace _) {
        diagnosticReadFailed = true;
        if (!stderrDone.isCompleted) stderrDone.complete();
      },
      onDone: () {
        if (!stderrDone.isCompleted) stderrDone.complete();
      },
    );
    try {
      final exitCode = await _waitForExit(process, cancelToken);
      await Future.wait([
        stdoutDone.future,
        stderrDone.future,
      ]).timeout(timeout);
      if (outputReadFailed || diagnosticReadFailed) _processFailed(exitCode);
      if (stderrLogin) _notLoggedIn();
      final text = output.toString();
      if (_quotaExhausted(text)) _quotaFailure();
      if (exitCode != 0) _processFailed(exitCode);
      final content = text.trim();
      final completion = {
        'id': 'chatcmpl-auggie-${DateTime.now().millisecondsSinceEpoch}',
        'object': 'chat.completion',
        'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'model': model,
        'choices': [
          {
            'index': 0,
            'message': {'role': 'assistant', 'content': content},
            'finish_reason': 'stop',
          },
        ],
        'usage': {
          'prompt_tokens': (prompt.length / 4).ceil(),
          'completion_tokens': (content.length / 4).ceil(),
          'total_tokens': ((prompt.length + content.length) / 4).ceil(),
          'estimated': true,
        },
      };
      return AuggieCliResponse(
        statusCode: 200,
        headers: const {
          'content-type': ['application/json'],
        },
        body: utf8.encode(jsonEncode(completion)),
      );
    } on TimeoutException {
      await _terminateAndWait(process);
      throw const AuggieCliException(
        'timeout',
        'Auggie CLI request timed out.',
      );
    } on AuggieCliException {
      await _terminateAndWait(process);
      rethrow;
    } finally {
      await stdout.cancel();
      await stderr.cancel();
      await process.dispose();
    }
  }

  Stream<List<int>> _streamResponse(
    AuggieCliProcess process,
    String model,
    CancelToken? cancelToken,
  ) {
    late StreamController<List<int>> controller;
    StreamSubscription<String>? stdout;
    StreamSubscription<List<int>>? stderr;
    StreamSubscription<dynamic>? cancelSub;
    final pending = StringBuffer();
    var bufferingInitialOutput = true;
    var quotaTail = '';
    var roleSent = false;
    var closed = false;
    var stderrLogin = false;
    var stderrTail = '';
    var stderrReadFailed = false;
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    late final Timer timer;
    void emitError(AuggieCliException error) {
      if (closed) return;
      closed = true;
      unawaited(
        _streamError(
          process,
          controller,
          error,
          stdout,
          stderr,
          cancelSub,
          timer: timer,
        ),
      );
    }

    timer = Timer(timeout, () {
      emitError(
        const AuggieCliException('timeout', 'Auggie CLI request timed out.'),
      );
    });

    void emitText(String text) {
      if (text.isEmpty || closed) return;
      if (!roleSent) {
        controller.add(_sse(model, {'role': 'assistant', 'content': ''}));
        roleSent = true;
      }
      controller.add(_sse(model, {'content': text}));
    }

    void emitQuotaError() => emitError(
          const AuggieCliException(
            'auggie_quota_exhausted',
            'Auggie reported that the local account usage limit is exhausted.',
          ),
        );

    void flushPending() {
      final value = pending.toString();
      if (_quotaExhausted(value)) {
        emitQuotaError();
        return;
      }
      bufferingInitialOutput = false;
      emitText(value);
      pending.clear();
    }

    controller = StreamController<List<int>>(
      onListen: () {
        stdout = process.stdout.transform(utf8.decoder).listen(
          (chunk) {
            if (closed) return;
            final quotaScan = '$quotaTail$chunk';
            if (_quotaExhausted(quotaScan)) {
              emitQuotaError();
              return;
            }
            quotaTail = quotaScan.length <= _diagnosticTailLength
                ? quotaScan
                : quotaScan.substring(
                    quotaScan.length - _diagnosticTailLength,
                  );
            if (bufferingInitialOutput) {
              pending.write(chunk);
              if (pending.length >= _quotaBufferLength) flushPending();
              return;
            }
            emitText(chunk);
          },
          onError: (_) {
            if (!stdoutDone.isCompleted) stdoutDone.complete();
            emitError(
              const AuggieCliException(
                'process_failure',
                'Auggie CLI request failed.',
              ),
            );
          },
          onDone: () {
            if (!stdoutDone.isCompleted) stdoutDone.complete();
          },
        );
        stderr = process.stderr.listen(
          (chunk) {
            stderrTail = _appendDiagnosticTail(
              stderrTail,
              utf8.decode(chunk, allowMalformed: true),
            );
            stderrLogin = stderrLogin || _looksLikeLoginRequired(stderrTail);
          },
          onError: (Object _, StackTrace _) {
            stderrReadFailed = true;
            if (!stderrDone.isCompleted) stderrDone.complete();
          },
          onDone: () {
            if (!stderrDone.isCompleted) stderrDone.complete();
          },
        );
        cancelSub = _cancelOnToken(
          process,
          cancelToken,
          () => emitError(
            const AuggieCliException(
              'cancelled',
              'Auggie CLI request was cancelled.',
            ),
          ),
        );
        unawaited(() async {
          try {
            final exitCode = await process.exitCode.timeout(timeout);
            if (closed) return;
            await Future.wait([
              stdoutDone.future,
              stderrDone.future,
            ]).timeout(timeout);
            if (closed) return;
            if (stderrReadFailed) _processFailed(exitCode);
            if (stderrLogin) _notLoggedIn();
            flushPending();
            if (closed) return;
            if (exitCode != 0) _processFailed(exitCode);
            controller.add(_sse(model, {}, finishReason: 'stop'));
            controller.add(utf8.encode('data: [DONE]\n\n'));
            closed = true;
            timer.cancel();
            await stdout?.cancel();
            await stderr?.cancel();
            await cancelSub?.cancel();
            await process.dispose();
            await controller.close();
          } on TimeoutException {
            emitError(
              const AuggieCliException(
                'timeout',
                'Auggie CLI request timed out.',
              ),
            );
          } on AuggieCliException catch (error) {
            emitError(error);
          } catch (_) {
            emitError(
              const AuggieCliException(
                'process_failure',
                'Auggie CLI request failed.',
              ),
            );
          }
        }());
      },
      onCancel: () async {
        if (closed) return;
        closed = true;
        timer.cancel();
        await _terminateAndWait(process);
        await stdout?.cancel();
        await stderr?.cancel();
        await cancelSub?.cancel();
        await process.dispose();
      },
    );
    return controller.stream;
  }

  Future<void> _streamError(
    AuggieCliProcess process,
    StreamController<List<int>> controller,
    AuggieCliException error,
    StreamSubscription<String>? stdout,
    StreamSubscription<List<int>>? stderr,
    StreamSubscription<dynamic>? cancelSub, {
    Timer? timer,
  }) async {
    if (controller.isClosed) return;
    timer?.cancel();
    await _terminateAndWait(process);
    await stdout?.cancel();
    await stderr?.cancel();
    await cancelSub?.cancel();
    await process.dispose();
    final payload = jsonEncode({
      'error': {
        'message': error.message,
        'type': 'upstream_error',
        'code': error.code,
      },
    });
    controller.add(utf8.encode('data: $payload\n\ndata: [DONE]\n\n'));
    if (!controller.isClosed) await controller.close();
  }

  StreamSubscription<dynamic>? _cancelOnToken(
    AuggieCliProcess process,
    CancelToken? cancelToken,
    void Function() onCancel,
  ) {
    if (cancelToken == null) return null;
    if (cancelToken.isCancelled) {
      onCancel();
      return null;
    }
    return cancelToken.whenCancel.asStream().listen((_) => onCancel());
  }

  Future<AuggieCliProcess> _start(List<String> arguments) async {
    final workspace = await Directory.systemTemp.createTemp('stroom-auggie-');
    try {
      return await _launcher.start(
        List.unmodifiable(arguments),
        runInShell: false,
        workingDirectory: workspace.path,
      );
    } on ProcessException {
      await workspace.delete(recursive: true);
      rethrow;
    } catch (_) {
      await workspace.delete(recursive: true);
      rethrow;
    }
  }

  Future<int> _waitForExit(AuggieCliProcess process, CancelToken? cancelToken) {
    final exit = process.exitCode.timeout(timeout);
    if (cancelToken == null) return exit;
    if (cancelToken.isCancelled) {
      return Future.error(
        const AuggieCliException(
          'cancelled',
          'Auggie CLI request was cancelled.',
        ),
      );
    }
    return Future.any([
      exit,
      cancelToken.whenCancel.then<int>(
        (_) => throw const AuggieCliException(
          'cancelled',
          'Auggie CLI request was cancelled.',
        ),
      ),
    ]);
  }

  Future<void> _terminateAndWait(AuggieCliProcess process) async {
    try {
      await process.terminate();
      await process.exitCode.timeout(_processShutdownGrace);
    } on TimeoutException {
      try {
        await process.terminate(force: true);
        await process.exitCode.timeout(_processShutdownGrace);
      } catch (_) {}
    } catch (_) {}
  }

  void _requireDesktop() {
    if (!_supportsLocalProcess()) {
      throw const AuggieCliException(
        'desktop_only',
        'Auggie CLI is available only in the Stroom desktop app.',
      );
    }
  }

  static bool _hasUnsupportedTools(Map<String, dynamic> request) {
    for (final key in const [
      'tools',
      'functions',
      'tool_choice',
      'function_call',
    ]) {
      final value = request[key];
      if (value != null && value != false && value != 'none') return true;
    }
    return false;
  }

  static Never _unsupported() => throw const AuggieCliException(
        'auggie_unsupported_capability',
        'Auggie CLI supports text-only conversations without tools or media.',
      );

  static Never _throwUnsupportedRole() => _unsupported();

  static bool _quotaExhausted(String text) {
    final normalized = text.toLowerCase();
    return _quotaPatterns.any(normalized.contains);
  }

  static bool _looksLikeLoginRequired(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('not logged in') ||
        normalized.contains('please run auggie login') ||
        normalized.contains('run `auggie login`') ||
        normalized.contains('authentication required');
  }

  static String _appendDiagnosticTail(String tail, String chunk) {
    final combined = '$tail${chunk.toLowerCase()}';
    return combined.length <= _diagnosticTailLength
        ? combined
        : combined.substring(combined.length - _diagnosticTailLength);
  }

  static Never _notLoggedIn() => throw const AuggieCliException(
        'auggie_not_logged_in',
        'Auggie CLI is not signed in. Run `auggie login` in the local terminal.',
      );

  static Never _processFailed(int code) => throw AuggieCliException(
        'process_failure',
        'Auggie CLI exited with code $code. Check the local CLI status and sign-in.',
      );

  static Never _quotaFailure() => throw const AuggieCliException(
        'auggie_quota_exhausted',
        'Auggie reported that the local account usage limit is exhausted.',
      );

  static Never _cancelled() => throw const AuggieCliException(
        'cancelled',
        'Auggie CLI request was cancelled.',
      );

  static AuggieCliModel _modelFor(String id) => AuggieCliModel(id, id, 200000);

  static Uint8List _sse(
    String model,
    Map<String, dynamic> delta, {
    String? finishReason,
  }) {
    final event = {
      'id': 'chatcmpl-auggie-${DateTime.now().millisecondsSinceEpoch}',
      'object': 'chat.completion.chunk',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {'index': 0, 'delta': delta, 'finish_reason': finishReason},
      ],
    };
    return utf8.encode('data: ${jsonEncode(event)}\n\n');
  }
}
