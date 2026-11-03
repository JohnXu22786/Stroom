import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/qoder_cli_service.dart';

void main() {
  test('PAT plan isolates the CLI token and disables tools', () {
    final plan = QoderCliPlan.chat(
      token: 'pt-account-token',
      modelId: 'qwen3.8-max-preview',
      body: const {
        'messages': [
          {'role': 'user', 'content': 'Hello'},
        ],
      },
      configDirectory: '/tmp/qoder-account-work',
      parentEnvironment: const {
        'PATH': '/usr/bin',
        'HTTPS_PROXY': 'http://proxy.example.test:8080',
        'OPENAI_API_KEY': 'unrelated-provider-secret',
        'QODER_PERSONAL_ACCESS_TOKEN': 'unrelated-shell-token',
      },
    );

    expect(plan.environment['PATH'], '/usr/bin');
    expect(plan.environment['QODER_PERSONAL_ACCESS_TOKEN'], 'pt-account-token');
    expect(plan.environment['HTTPS_PROXY'], 'http://proxy.example.test:8080');
    expect(plan.environment, isNot(contains('OPENAI_API_KEY')));
    expect(
      plan.arguments,
      containsAllInOrder([
        '--print',
        '--output-format',
        'json',
        '--model',
        'qmodel_preview',
        '--tools',
        '',
        '--config-dir',
        '/tmp/qoder-account-work',
      ]),
    );
    expect(plan.prompt, contains('Hello'));
    expect(plan.timeout, const Duration(seconds: 45));
    expect(plan.buffered, isTrue);
  });

  test('PAT plan rejects caller tools before starting the CLI', () {
    expect(
      () => QoderCliPlan.chat(
        token: 'pt-account-token',
        modelId: 'qwen3.8-max-preview',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'lookup'},
            },
          ],
        },
        configDirectory: '/tmp/qoder-account-work',
      ),
      throwsA(isA<QoderCliToolsUnsupportedException>()),
    );
  });

  test(
    'PAT streaming wraps the buffered result as a complete SSE response',
    () async {
      final root = await Directory.systemTemp.createTemp('qoder-cli-stream-');
      addTearDown(() => root.delete(recursive: true));
      final runner = _FakeQoderCliRunner()
        ..result = const QoderCliRunResult(
          stdout: '{"type":"result","is_error":false,"result":"Reply"}',
          stderr: '',
          exitCode: 0,
          timedOut: false,
        );
      final service = QoderCliService(runner: runner, tempDirectory: root);
      final result = await service.chat(
        token: 'pt-stream-token',
        modelId: 'qwen3.8-max-preview',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
        },
        stream: true,
      ) as Stream<List<int>>;
      final output = await result.transform(utf8.decoder).join();
      expect(output, contains('"role":"assistant"'));
      expect(output, contains('"content":"Reply"'));
      expect(output, contains('"finish_reason":"stop"'));
      expect(output, endsWith('data: [DONE]\n\n'));
      expect(root.listSync(), isEmpty);
    },
  );

  test('PAT CLI result parser handles successful output and upstream errors',
      () {
    expect(
      QoderCliService.parseResult(
        '{"type":"result","is_error":false,"result":"Reply"}',
      ),
      'Reply',
    );
    expect(
      QoderCliService.parseResult(
        'Qoder CLI banner\n{"type":"result","is_error":false,"result":"Reply"}',
      ),
      'Reply',
    );
    expect(
      () => QoderCliService.parseResult(
        '{"type":"result","is_error":true,"result":"server busy 10605"}',
      ),
      throwsA(isA<QoderCliUpstreamBusyException>()),
    );
    expect(
      () => QoderCliService.parseResult(
        '{"type":"result","is_error":true,"result":"not logged in"}',
      ),
      throwsA(isA<QoderCliAuthenticationException>()),
    );
  });

  test('PAT model discovery strips ANSI styling before matching rows',
      () async {
    final root = await Directory.systemTemp.createTemp('qoder-cli-models-');
    addTearDown(() => root.delete(recursive: true));
    final runner = _FakeQoderCliRunner()
      ..result = const QoderCliRunResult(
        stdout: '\x1B[38;5;128mQwen 3.8 Max Preview\x1B[0m (default)',
        stderr: '',
        exitCode: 0,
        timedOut: false,
      );
    final service = QoderCliService(runner: runner, tempDirectory: root);

    expect(await service.listModels(token: 'pt-list-token'), [
      'qwen3.8-max-preview',
    ]);
    expect(root.listSync(), isEmpty);
  });

  test(
    'PAT workspace is removed after request completion and CLI failure',
    () async {
      final root = await Directory.systemTemp.createTemp('qoder-cli-test-');
      addTearDown(() => root.delete(recursive: true));
      final runner = _FakeQoderCliRunner();
      final service = QoderCliService(runner: runner, tempDirectory: root);

      await service.listModels(token: 'pt-list-token');
      expect(
        runner.lastEnvironment['QODER_PERSONAL_ACCESS_TOKEN'],
        'pt-list-token',
      );
      expect(runner.lastArguments, contains('--list-models'));
      expect(await service.listModels(token: 'pt-list-token'), [
        'qwen3.8-max-preview',
      ]);
      expect(root.listSync(), isEmpty);

      runner.result = const QoderCliRunResult(
        stdout: '',
        stderr: 'qodercli failed',
        exitCode: 1,
        timedOut: false,
      );
      await expectLater(
        service.chat(
          token: 'pt-chat-token',
          modelId: 'qwen3.8-max-preview',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Hello'},
            ],
          },
          stream: true,
        ),
        throwsA(isA<QoderCliRequestException>()),
      );
      expect(runner.lastTimeout, const Duration(seconds: 45));
      expect(root.listSync(), isEmpty);
    },
  );
}

class _FakeQoderCliRunner implements QoderCliRunner {
  QoderCliRunResult result = const QoderCliRunResult(
    stdout: 'Model\nQwen 3.8 Max Preview (default)',
    stderr: '',
    exitCode: 0,
    timedOut: false,
  );
  List<String> lastArguments = const [];
  Map<String, String> lastEnvironment = const {};
  Duration? lastTimeout;

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
    lastArguments = arguments;
    lastEnvironment = environment;
    lastTimeout = timeout;
    return result;
  }
}
