import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

const _qoderCliEnvironmentAllowlist = {
  'PATH',
  'PATHEXT',
  'APPDATA',
  'HOME',
  'USERPROFILE',
  'SYSTEMROOT',
  'WINDIR',
  'TEMP',
  'TMP',
  'TMPDIR',
  'LANG',
  'LC_ALL',
  'LC_CTYPE',
  'TERM',
  'HTTP_PROXY',
  'HTTPS_PROXY',
  'ALL_PROXY',
  'NO_PROXY',
  'SSL_CERT_FILE',
  'NODE_EXTRA_CA_CERTS',
  'REQUESTS_CA_BUNDLE',
  'CURL_CA_BUNDLE',
};

Map<String, String> _safeQoderCliEnvironment(Map<String, String> source) => {
      for (final entry in source.entries)
        if (_qoderCliEnvironmentAllowlist.contains(entry.key.toUpperCase()) &&
            !entry.key.toUpperCase().startsWith('QODER_'))
          entry.key: entry.value,
    };

const _qoderModelLevels = <String, String>{
  'qwen3.8-max-preview': 'qmodel_preview',
  'qwen3.7-max': 'qmodel_latest',
  'qwen3.7-plus': 'qmodel',
  'kimi-k3': 'kmodel_latest',
  'kimi-k2.7-code': 'kmodel',
  'glm-5.2': 'gm51model',
  'deepseek-v4-pro': 'dmodel',
  'deepseek-v4-flash': 'dfmodel',
  'minimax-m3': 'mmodel',
};

final _ansiEscapePattern = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');

abstract interface class QoderCliRunner {
  Future<QoderCliRunResult> run({
    required String executable,
    required List<String> arguments,
    required Map<String, String> environment,
    required String workingDirectory,
    required String stdin,
    required Duration timeout,
    CancelToken? cancelToken,
  });
}

class QoderCliRunResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final bool timedOut;
  const QoderCliRunResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.timedOut,
  });
}

class IoQoderCliRunner implements QoderCliRunner {
  const IoQoderCliRunner();

  @override
  Future<QoderCliRunResult> run({
    required String executable,
    required List<String> arguments,
    required Map<String, String> environment,
    required String workingDirectory,
    required String stdin,
    required Duration timeout,
    CancelToken? cancelToken,
  }) async {
    Process? process;
    var timedOut = false;
    try {
      process = await Process.start(
        executable,
        arguments,
        environment: environment,
        workingDirectory: workingDirectory,
        includeParentEnvironment: false,
      );
      cancelToken?.whenCancel.then((_) => process?.kill(ProcessSignal.sigterm));
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(stdin);
      await process.stdin.close();
      final exitFuture = process.exitCode;
      final code = await exitFuture.timeout(
        timeout,
        onTimeout: () {
          timedOut = true;
          process?.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      return QoderCliRunResult(
        stdout: await stdoutFuture,
        stderr: await stderrFuture,
        exitCode: code,
        timedOut: timedOut,
      );
    } on ProcessException catch (error) {
      throw QoderCliRequestException(
        'Could not start qodercli: ${error.message}',
      );
    } finally {
      if (process != null && !timedOut) process.kill(ProcessSignal.sigterm);
    }
  }
}

class QoderCliPlan {
  final String executable;
  final List<String> arguments;
  final Map<String, String> environment;
  final String prompt;
  final Duration timeout;
  final bool buffered;
  const QoderCliPlan({
    required this.executable,
    required this.arguments,
    required this.environment,
    required this.prompt,
    required this.timeout,
    required this.buffered,
  });

  factory QoderCliPlan.chat({
    required String token,
    required String modelId,
    required Object? body,
    required String configDirectory,
    Map<String, String>? parentEnvironment,
  }) {
    if (body is! Map ||
        (body['tools'] is Iterable && (body['tools'] as Iterable).isNotEmpty) ||
        body['tool_choice'] != null) {
      throw const QoderCliToolsUnsupportedException();
    }
    final messages = body['messages'];
    if (messages is! Iterable) {
      throw const QoderCliRequestException('Invalid chat request.');
    }
    final promptParts = <String>[];
    for (final item in messages) {
      if (item is! Map || item['content'] is! String) {
        throw const QoderCliRequestException(
          'Qoder PAT mode supports text messages only.',
        );
      }
      final content = (item['content'] as String).trim();
      if (content.isNotEmpty) {
        promptParts.add('${item['role'] ?? 'user'}: $content');
      }
    }
    if (promptParts.isEmpty) {
      throw const QoderCliRequestException('The chat request has no text.');
    }
    final env = _safeQoderCliEnvironment(
      parentEnvironment ?? Platform.environment,
    );
    env['QODER_PERSONAL_ACCESS_TOKEN'] = token;
    final executable = parentEnvironment?['CLI_QODER_BIN'] ??
        Platform.environment['CLI_QODER_BIN'] ??
        'qodercli';
    return QoderCliPlan(
      executable: executable,
      arguments: [
        '--print',
        '--output-format',
        'json',
        '--model',
        _qoderModelLevels[modelId] ?? 'auto',
        '--tools',
        '',
        '--config-dir',
        configDirectory,
      ],
      environment: env,
      prompt: promptParts.join('\n'),
      timeout: const Duration(seconds: 45),
      buffered: true,
    );
  }
}

class QoderCliService {
  final QoderCliRunner runner;
  final Directory tempDirectory;
  final Future<String?> Function(String accountId)? readCredential;

  QoderCliService({
    QoderCliRunner? runner,
    Directory? tempDirectory,
    this.readCredential,
  })  : runner = runner ?? const IoQoderCliRunner(),
        tempDirectory = tempDirectory ?? Directory.systemTemp;

  Future<List<String>> listModels({required String token}) async {
    final workspace = await tempDirectory.createTemp('stroom-qoder-');
    try {
      final environment = _environment(token);
      final result = await runner.run(
        executable: Platform.environment['CLI_QODER_BIN'] ?? 'qodercli',
        arguments: ['--list-models', '--config-dir', workspace.path],
        environment: environment,
        workingDirectory: workspace.path,
        stdin: '',
        timeout: const Duration(seconds: 20),
      );
      if (result.timedOut) {
        throw const QoderCliTimeoutException();
      }
      if (result.exitCode != 0) throw QoderCliRequestException(result.stderr);
      final found = <String>[];
      final output = result.stdout.replaceAll(_ansiEscapePattern, '');
      for (final line in output.split('\n')) {
        final value = line.trim();
        final normalizedValue = _normalizeModelName(
          value.replaceFirst(
            RegExp(r'\s*\(default\)$', caseSensitive: false),
            '',
          ),
        );
        final id = _qoderModelLevels.keys.firstWhere(
          (model) => _normalizeModelName(model) == normalizedValue,
          orElse: () => '',
        );
        if (id.isNotEmpty && !found.contains(id)) found.add(id);
      }
      return found.isEmpty ? _qoderModelLevels.keys.toList() : found;
    } finally {
      if (await workspace.exists()) await workspace.delete(recursive: true);
    }
  }

  Future<Object?> request({
    required String accountId,
    required String modelId,
    required Object? body,
    required bool stream,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const QoderCliRequestCancelled();
    }
    final reader = readCredential;
    if (reader == null) {
      throw const QoderCliRequestException(
        'Qoder CLI account service is unavailable.',
      );
    }
    final secret = await reader(accountId);
    if (secret == null || !secret.startsWith('pt-')) {
      throw const QoderCliAuthenticationException();
    }
    return chat(
      token: secret,
      modelId: modelId,
      body: body,
      stream: stream,
      cancelToken: cancelToken,
    );
  }

  Future<Object?> chat({
    required String token,
    required String modelId,
    required Object? body,
    required bool stream,
    CancelToken? cancelToken,
  }) async {
    final workspace = await tempDirectory.createTemp('stroom-qoder-');
    try {
      final plan = QoderCliPlan.chat(
        token: token,
        modelId: modelId,
        body: body,
        configDirectory: workspace.path,
        parentEnvironment: Platform.environment,
      );
      final result = await runner.run(
        executable: plan.executable,
        arguments: plan.arguments,
        environment: plan.environment,
        workingDirectory: workspace.path,
        stdin: plan.prompt,
        timeout: plan.timeout,
        cancelToken: cancelToken,
      );
      if (cancelToken?.isCancelled == true) {
        throw const QoderCliRequestCancelled();
      }
      if (result.timedOut) {
        throw const QoderCliTimeoutException();
      }
      if (result.exitCode != 0) {
        _throwCliFailure(
          '${result.stderr}\n${result.stdout}'.trim().isEmpty
              ? 'qodercli exited with ${result.exitCode}.'
              : '${result.stderr}\n${result.stdout}'.trim(),
        );
      }
      final content = parseResult(result.stdout);
      if (!stream) {
        return {
          'id': 'qoder-cli',
          'object': 'chat.completion',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': content},
              'finish_reason': 'stop',
            },
          ],
        };
      }
      final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final events = [
        {
          'id': 'qoder-cli',
          'object': 'chat.completion.chunk',
          'created': created,
          'model': modelId,
          'choices': [
            {
              'index': 0,
              'delta': {'role': 'assistant', 'content': ''},
              'finish_reason': null,
            },
          ],
        },
        if (content.isNotEmpty)
          {
            'id': 'qoder-cli',
            'object': 'chat.completion.chunk',
            'created': created,
            'model': modelId,
            'choices': [
              {
                'index': 0,
                'delta': {'content': content},
                'finish_reason': null,
              },
            ],
          },
        {
          'id': 'qoder-cli',
          'object': 'chat.completion.chunk',
          'created': created,
          'model': modelId,
          'choices': [
            {'index': 0, 'delta': {}, 'finish_reason': 'stop'},
          ],
        },
      ];
      final bytes = utf8.encode(
        '${events.map((event) => 'data: ${jsonEncode(event)}\n\n').join()}data: [DONE]\n\n',
      );
      return Stream<List<int>>.value(bytes);
    } finally {
      if (await workspace.exists()) await workspace.delete(recursive: true);
    }
  }

  static String parseResult(String stdout) {
    final trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      throw const QoderCliRequestException('qodercli returned no output.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      for (final line in trimmed.split('\n').reversed) {
        final candidate = line.trim();
        if (!candidate.startsWith('{')) continue;
        try {
          decoded = jsonDecode(candidate);
          break;
        } on FormatException {
          // Continue past banners and log messages until the result envelope.
        }
      }
    }
    if (decoded is! Map) {
      throw QoderCliRequestException(
        trimmed.length > 300 ? trimmed.substring(0, 300) : trimmed,
      );
    }
    final result =
        decoded['result'] ?? decoded['content'] ?? decoded['response'];
    if (decoded['is_error'] == true || decoded['subtype'] == 'error') {
      _throwCliFailure(
        result is String && result.trim().isNotEmpty ? result : trimmed,
      );
    }
    if (result is String && result.trim().isNotEmpty) return result.trim();
    throw const QoderCliRequestException(
      'qodercli returned an empty response.',
    );
  }

  static Never _throwCliFailure(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid api key') ||
        normalized.contains('invalid token') ||
        normalized.contains('personal access token') ||
        normalized.contains('personal token format') ||
        normalized.contains('not logged in') ||
        normalized.contains('/login') ||
        normalized.contains('login required') ||
        (normalized.contains('unauthorized') && normalized.contains('qoder'))) {
      throw const QoderCliAuthenticationException();
    }
    if (normalized.contains('10605') ||
        normalized.contains('queued') ||
        normalized.contains('server busy') ||
        normalized.contains('is busy')) {
      throw QoderCliUpstreamBusyException(message);
    }
    throw QoderCliRequestException(message);
  }

  static String _normalizeModelName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Map<String, String> _environment(String token) {
    final env = _safeQoderCliEnvironment(Platform.environment);
    env['QODER_PERSONAL_ACCESS_TOKEN'] = token;
    return env;
  }
}

class QoderCliRequestException implements Exception {
  final String message;
  const QoderCliRequestException([this.message = 'Qoder CLI request failed.']);
  @override
  String toString() => message;
}

class QoderCliAuthenticationException extends QoderCliRequestException {
  const QoderCliAuthenticationException()
      : super('Qoder PAT authentication failed.');
}

class QoderCliTimeoutException extends QoderCliRequestException {
  const QoderCliTimeoutException() : super('Qoder CLI request timed out.');
}

class QoderCliToolsUnsupportedException extends QoderCliRequestException {
  const QoderCliToolsUnsupportedException()
      : super('Qoder PAT mode does not support caller tools.');
}

class QoderCliUpstreamBusyException extends QoderCliRequestException {
  const QoderCliUpstreamBusyException(super.message);
}

class QoderCliRequestCancelled extends QoderCliRequestException {
  const QoderCliRequestCancelled() : super('Qoder CLI request was cancelled.');
}
