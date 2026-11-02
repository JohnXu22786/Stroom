import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway_contracts.dart';
import 'package:stroom/services/devin_cli_acp.dart';
import 'package:stroom/services/devin_cli_acp_service.dart';

const _testExecutableSha256 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('Devin CLI ACP launch', () {
    test(
      'uses a pinned CLI path, fixed commands, and an isolated environment',
      () {
        final launch = DevinCliAcpLaunch.forAccount(
          homePath: '/private/stroom/devin/account-a',
          executablePath: '/trusted/devin',
          executableSha256: _testExecutableSha256,
          parentEnvironment: const {
            'PATH': '/usr/local/bin:/usr/bin',
            'WINDSURF_API_KEY': 'host-secret',
            'HOME': '/host/home',
          },
          temporaryDirectory: '/private/stroom/workspaces/request-a',
        );

        expect(launch.executable, '/trusted/devin');
        expect(launch.arguments, ['acp']);
        expect(launch.includeParentEnvironment, isFalse);
        expect(launch.environment['HOME'], '/private/stroom/devin/account-a');
        expect(launch.environment['PATH'], '/usr/local/bin:/usr/bin');
        expect(
          launch.environment['TMPDIR'],
          '/private/stroom/workspaces/request-a',
        );
        expect(
          launch.environment['TMP'],
          '/private/stroom/workspaces/request-a',
        );
        expect(
          launch.environment['TEMP'],
          '/private/stroom/workspaces/request-a',
        );
        expect(launch.environment.containsKey('WINDSURF_API_KEY'), isFalse);
        expect(launch.environment.containsValue('/host/home'), isFalse);
      },
    );

    test('exposes only the documented login lifecycle commands', () {
      final parentEnvironment = const <String, String>{'PATH': '/bin'};
      final homes = [
        DevinCliAcpLaunch.forLogin(
          homePath: '/private/account',
          executablePath: '/trusted/devin',
          executableSha256: _testExecutableSha256,
          parentEnvironment: parentEnvironment,
        ),
        DevinCliAcpLaunch.forStatus(
          homePath: '/private/account',
          executablePath: '/trusted/devin',
          executableSha256: _testExecutableSha256,
          parentEnvironment: parentEnvironment,
        ),
        DevinCliAcpLaunch.forLogout(
          homePath: '/private/account',
          executablePath: '/trusted/devin',
          executableSha256: _testExecutableSha256,
          parentEnvironment: parentEnvironment,
        ),
      ];

      expect(homes.map((launch) => launch.arguments).toList(), [
        ['auth', 'login'],
        ['auth', 'status'],
        ['auth', 'logout'],
      ]);
      expect(
        homes.every((launch) => launch.includeParentEnvironment == false),
        isTrue,
      );
      expect(
        homes.every((launch) => launch.executable == '/trusted/devin'),
        isTrue,
      );
    });

    test(
      'derives distinct account homes without trusting account path text',
      () {
        final first = DevinCliAcpHome.pathForAccount(
          supportDirectory: '/private/stroom',
          accountId: 'account-a',
        );
        final second = DevinCliAcpHome.pathForAccount(
          supportDirectory: '/private/stroom',
          accountId: 'account-b',
        );
        final traversal = DevinCliAcpHome.pathForAccount(
          supportDirectory: '/private/stroom',
          accountId: '../../other-user',
        );

        expect(first, isNot(second));
        expect(first, startsWith('/private/stroom/'));
        expect(second, startsWith('/private/stroom/'));
        expect(traversal, startsWith('/private/stroom/'));
        expect(traversal, isNot(contains('..')));
      },
    );

    test(
      'pins an approved executable and rejects later content changes',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'stroom-cli-approval-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final executable = File(
          '${directory.path}${Platform.pathSeparator}${Platform.isWindows ? 'devin.exe' : 'devin'}',
        );
        await executable.writeAsString('official CLI fixture');
        if (!Platform.isWindows) {
          Process.runSync('chmod', ['700', executable.path]);
        }
        final approval = await DevinCliAcpLaunch.approveExecutablePath(
          executable.path,
        );

        await expectLater(
          DevinCliAcpLaunch.verifyExecutableApproval(
            approval.path,
            approval.sha256,
          ),
          completes,
        );
        expect(approval.sha256, hasLength(64));
        await executable.writeAsString('replacement executable');
        await expectLater(
          DevinCliAcpLaunch.verifyExecutableApproval(
            approval.path,
            approval.sha256,
          ),
          throwsA(isA<DevinCliAcpExecutableApprovalException>()),
        );
      },
    );

    test(
      'launch copy stays pinned when the approved source changes afterward',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'stroom-cli-copy-approval-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final executable = File(
          '${directory.path}${Platform.pathSeparator}${Platform.isWindows ? 'devin.exe' : 'devin'}',
        );
        await executable.writeAsString('official CLI fixture');
        if (!Platform.isWindows) {
          Process.runSync('chmod', ['700', executable.path]);
        }
        final approval = await DevinCliAcpLaunch.approveExecutablePath(
          executable.path,
        );
        final launch = DevinCliAcpLaunch.forAccount(
          homePath: '${directory.path}${Platform.pathSeparator}account-home',
          executablePath: approval.path,
          executableSha256: approval.sha256,
          parentEnvironment: const {'PATH': '/usr/bin'},
        );
        final copy = await launch.prepareApprovedExecutableCopy();
        addTearDown(() => copy.directory.delete(recursive: true));

        expect(copy.executablePath, isNot(approval.path));
        await executable.writeAsString('replacement CLI fixture');
        await expectLater(
          DevinCliAcpLaunch.verifyExecutableApproval(
            copy.executablePath,
            approval.sha256,
          ),
          completes,
        );
        await expectLater(
          DevinCliAcpLaunch.verifyExecutableApproval(
            approval.path,
            approval.sha256,
          ),
          throwsA(isA<DevinCliAcpExecutableApprovalException>()),
        );
      },
    );
  });

  group('ACP JSON-RPC framing', () {
    test('writes one JSON-RPC message per newline-delimited stdio frame', () {
      final frame = DevinCliAcpJsonRpc.encodeRequest(
        id: 1,
        method: 'initialize',
        params: const {'protocolVersion': 1},
      );

      expect(frame.endsWith('\n'), isTrue);
      expect(frame.contains('\r'), isFalse);
      expect(jsonDecode(frame), {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': 1},
      });
    });

    test('rejects oversized outbound request and notification frames', () {
      final oversizedText = String.fromCharCodes(
        List<int>.filled(DevinCliAcpJsonRpc.maxFrameBytes, 0x61),
      );

      expect(
        () => DevinCliAcpJsonRpc.encodeRequest(
          id: 1,
          method: 'session/prompt',
          params: {'prompt': oversizedText},
        ),
        throwsFormatException,
      );
      expect(
        () => DevinCliAcpJsonRpc.encodeNotification(
          method: 'session/update',
          params: {'content': oversizedText},
        ),
        throwsFormatException,
      );
    });

    test('rejects an oversized outbound error response', () {
      final oversizedId = String.fromCharCodes(
        List<int>.filled(DevinCliAcpJsonRpc.maxFrameBytes, 0x61),
      );

      expect(
        () => DevinCliAcpJsonRpc.encodeErrorResponse(
          id: oversizedId,
          code: -32601,
          message: 'Method not supported',
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed, oversized, and unsupported protocol frames', () {
      expect(
        () => DevinCliAcpJsonRpc.decodeMessage('not-json'),
        throwsFormatException,
      );
      expect(
        () => DevinCliAcpJsonRpc.decodeMessage(
          jsonEncode({'jsonrpc': '1.0', 'id': 1, 'result': {}}),
        ),
        throwsFormatException,
      );
      expect(
        () => DevinCliAcpJsonRpc.validateNegotiatedVersion(2),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test(
      'rejects oversized unterminated stdout frames while reading bytes',
      () {
        final source = Stream<List<int>>.value(
          List<int>.filled(DevinCliAcpJsonRpc.maxFrameBytes + 1, 0x61),
        );

        expect(
          DevinCliAcpJsonRpc.decodeLines(source),
          emitsError(isA<FormatException>()),
        );
      },
    );

    test('accepts an exactly limit-sized CRLF terminated frame', () async {
      const prefix = '{"jsonrpc":"2.0","id":1,"result":{"data":"';
      const suffix = '"}}';
      final fillLength =
          DevinCliAcpJsonRpc.maxFrameBytes - prefix.length - suffix.length;
      final payload = prefix +
          String.fromCharCodes(List<int>.filled(fillLength, 0x61)) +
          suffix;
      expect(utf8.encode(payload), hasLength(DevinCliAcpJsonRpc.maxFrameBytes));

      await expectLater(
        DevinCliAcpJsonRpc.decodeLines(
          Stream<List<int>>.value(utf8.encode('$payload\r\n')),
        ),
        emits(payload),
      );
    });
  });

  group('Devin CLI process shutdown', () {
    test('force-kills a process that ignores graceful termination', () async {
      final exitCode = Completer<int>();
      final signals = <String>[];

      await DevinCliAcpProcessShutdown.terminateAndWait(
        exitCode: exitCode.future,
        gracefulTimeout: Duration.zero,
        terminate: () => signals.add('terminate'),
        forceTerminate: () {
          signals.add('kill');
          exitCode.complete(-1);
        },
      );

      expect(signals, ['terminate', 'kill']);
      await expectLater(exitCode.future, completion(-1));
    });

    test('waits for graceful exit without force-killing', () async {
      final exitCode = Completer<int>();
      final signals = <String>[];

      await DevinCliAcpProcessShutdown.terminateAndWait(
        exitCode: exitCode.future,
        terminate: () {
          signals.add('terminate');
          exitCode.complete(0);
        },
        forceTerminate: () => signals.add('kill'),
      );

      expect(signals, ['terminate']);
      await expectLater(exitCode.future, completion(0));
    });
  });

  group('Devin CLI ACP process lifecycle', () {
    late Directory supportDirectory;
    late _FakeAcpLauncher launcher;

    setUp(() async {
      supportDirectory = await Directory.systemTemp.createTemp('stroom-acp-');
      launcher = _FakeAcpLauncher();
    });

    tearDown(() async {
      if (await supportDirectory.exists()) {
        await supportDirectory.delete(recursive: true);
      }
    });

    test('starts one isolated ACP session and maps assistant text', () async {
      final service = DevinCliAcpService(
        launcher: launcher,
        supportDirectory: () async => supportDirectory.path,
        parentEnvironment: () => const {
          'PATH': '/usr/bin',
          'WINDSURF_API_KEY': 'host-secret',
          'HOME': '/host/home',
        },
      );
      final response = await service.request(
        account: _account,
        modelId: 'devin-cli-default',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Say hello'},
          ],
        },
      );
      final body = response.body as Map<String, dynamic>;
      final choices = body['choices'] as List;
      final message = (choices.single as Map)['message'] as Map;

      expect(
        message['content'],
        '[Devin tool] Inspecting workspace\nHello from Devin',
      );
      expect(launcher.launches, hasLength(2));
      expect(launcher.launches.first.arguments, ['auth', 'status']);
      expect(launcher.launches.last.arguments, ['acp']);
      expect(launcher.launches.last.includeParentEnvironment, isFalse);
      expect(
        launcher.launches.last.environment.containsKey('WINDSURF_API_KEY'),
        isFalse,
      );
      expect(
        launcher.launches.last.environment.containsValue('/host/home'),
        isFalse,
      );
      expect(
        launcher.workingDirectories.last,
        isNot(startsWith(launcher.launches.last.environment['HOME']!)),
      );
      expect(
        launcher.launches.last.environment['TMPDIR'],
        launcher.workingDirectories.last,
      );
      expect(
        launcher.launches.last.environment['TMP'],
        launcher.workingDirectories.last,
      );
      expect(
        launcher.launches.last.environment['TEMP'],
        launcher.workingDirectories.last,
      );
      expect(launcher.processes.last.terminated, isTrue);
    });

    test(
      'auth status receives an existing private temporary directory',
      () async {
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        expect(await service.isAuthenticated(_account), isTrue);
        final temporaryDirectory = Directory(
          launcher.launches.single.environment['TMPDIR']!,
        );
        expect(await temporaryDirectory.exists(), isTrue);
        expect(
          temporaryDirectory.parent.path,
          launcher.launches.single.environment['HOME'],
        );
      },
    );

    test(
      'rejects a symlinked account-home parent before creating auth state',
      () async {
        final externalDirectory = await Directory.systemTemp.createTemp(
          'stroom-acp-external-',
        );
        addTearDown(() => externalDirectory.delete(recursive: true));
        final accountRootLink = Link(
          '${supportDirectory.path}${Platform.pathSeparator}devin_cli_acp',
        );
        await accountRootLink.create(externalDirectory.path);

        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        await expectLater(
          service.isAuthenticated(_account),
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) =>
                  error.kind == AiGatewayFailureKind.transportUnavailable &&
                  error.code == 'unsafe_account_home',
            ),
          ),
        );
        expect(launcher.launches, isEmpty);
        expect(await externalDirectory.list().isEmpty, isTrue);
      },
      skip:
          Platform.isWindows ? 'Symlink creation requires privileges.' : false,
    );

    test(
      'rejects a symlinked account temporary directory',
      () async {
        final externalDirectory = await Directory.systemTemp.createTemp(
          'stroom-acp-temp-external-',
        );
        addTearDown(() => externalDirectory.delete(recursive: true));
        final accountHomePath = DevinCliAcpHome.pathForAccount(
          supportDirectory: supportDirectory.path,
          accountId: _account.id,
        );
        await Directory(accountHomePath).create(recursive: true);
        final temporaryLink = Link(
          '$accountHomePath${Platform.pathSeparator}tmp',
        );
        await temporaryLink.create(externalDirectory.path);

        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        await expectLater(
          service.isAuthenticated(_account),
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) =>
                  error.kind == AiGatewayFailureKind.transportUnavailable &&
                  error.code == 'unsafe_account_home',
            ),
          ),
        );
        expect(launcher.launches, isEmpty);
        expect(await externalDirectory.list().isEmpty, isTrue);
      },
      skip:
          Platform.isWindows ? 'Symlink creation requires privileges.' : false,
    );

    test(
      'discards auth CLI stdout errors without leaking stream failures',
      () async {
        launcher.authStdoutError = const FormatException(
          'invalid UTF-8 output',
        );
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        final response = await service.request(
          account: _account,
          modelId: 'devin-cli-default',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Continue safely'},
            ],
          },
        );

        expect(response.statusCode, 200);
        expect(launcher.launches.map((launch) => launch.arguments), [
          ['auth', 'status'],
          ['acp'],
        ]);
      },
    );

    test(
      'continues draining auth stdout after invalid oversized frames',
      () async {
        launcher.authStdoutChunks = List<List<int>>.generate(
          DevinCliAcpJsonRpc.maxFrameBytes ~/ 1024 + 8,
          (_) => List<int>.filled(1024, 0x61),
        );
        final expectedBytes = launcher.authStdoutChunks!.fold<int>(
          0,
          (total, chunk) => total + chunk.length,
        );
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        final response = await service.request(
          account: _account,
          modelId: 'devin-cli-default',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Continue safely'},
            ],
          },
        );

        expect(response.statusCode, 200);
        expect(launcher.processes.first.stdoutBytesRead, expectedBytes);
      },
    );

    test(
      'starts a streaming ACP session only after the stream is listened',
      () async {
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );
        final response = await service.request(
          account: _account,
          modelId: 'devin-cli-default',
          stream: true,
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Say hello'},
            ],
          },
        );

        expect(launcher.launches.map((launch) => launch.arguments), [
          ['auth', 'status'],
        ]);
        expect(response.body, isA<Stream<List<int>>>());

        final chunks = await (response.body as Stream<List<int>>).toList();
        expect(chunks, isNotEmpty);
        expect(launcher.launches.last.arguments, ['acp']);
        expect(launcher.processes.last.terminated, isTrue);
      },
    );

    test(
      'reports unsupported assistant chunks instead of truncating output',
      () async {
        launcher.unsupportedAgentMessageChunk = true;
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        await expectLater(
          service.request(
            account: _account,
            modelId: 'devin-cli-default',
            body: const {
              'messages': [
                {'role': 'user', 'content': 'Return text'},
              ],
            },
          ),
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) =>
                  error.kind == AiGatewayFailureKind.transportUnavailable &&
                  error.code == 'unsupported_capability',
            ),
          ),
        );
      },
    );

    test('stream cancellation waits for pending ACP startup cleanup', () async {
      final startEntered = Completer<void>();
      final releaseStart = Completer<void>();
      launcher.onLaunch = (launch) async {
        if (launch.arguments.join(' ') == 'acp') {
          startEntered.complete();
          await releaseStart.future;
        }
      };
      final service = DevinCliAcpService(
        launcher: launcher,
        supportDirectory: () async => supportDirectory.path,
        parentEnvironment: () => const {'PATH': '/usr/bin'},
      );
      final response = await service.request(
        account: _account,
        modelId: 'devin-cli-default',
        stream: true,
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Cancel setup'},
          ],
        },
      );
      final subscription = (response.body as Stream<List<int>>).listen((_) {});
      await startEntered.future;

      var cancellationCompleted = false;
      final cancellation = subscription.cancel().then((_) {
        cancellationCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(cancellationCompleted, isFalse);

      releaseStart.complete();
      await cancellation;
      expect(launcher.processes.last.terminated, isTrue);
      expect(
        await Directory(launcher.workingDirectories.last).exists(),
        isFalse,
      );
    });

    test(
      'cancellation terminates the CLI when it stops reading notifications',
      () async {
        launcher.onMethod = (method) async {
          if (method == 'session/cancel' || method == 'session/close') {
            await Completer<void>().future;
          }
        };
        final requestSent = Completer<void>();
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );
        final response = await service.request(
          account: _account,
          modelId: 'devin-cli-default',
          stream: true,
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Cancel the blocked request'},
            ],
          },
          onRequestSent: () async => requestSent.complete(),
        );
        final subscription = (response.body as Stream<List<int>>).listen(
          (_) {},
        );
        await requestSent.future;

        await subscription.cancel().timeout(const Duration(seconds: 5));

        expect(launcher.processes.last.terminated, isTrue);
        expect(
          await Directory(launcher.workingDirectories.last).exists(),
          isFalse,
        );
      },
    );

    test(
      'requires CLI authentication before starting an ACP request',
      () async {
        launcher.authStatusExitCode = 1;
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        await expectLater(
          service.request(
            account: _account,
            modelId: 'devin-cli-default',
            body: const {
              'messages': [
                {'role': 'user', 'content': 'Check authentication'},
              ],
            },
          ),
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) =>
                  error.kind == AiGatewayFailureKind.authenticationRequired,
            ),
          ),
        );
        expect(launcher.launches.map((launch) => launch.arguments), [
          ['auth', 'status'],
        ]);
      },
    );

    test('cancels promptly while checking CLI authentication', () async {
      launcher.holdAuthStatus = true;
      final statusStarted = Completer<void>();
      launcher.onLaunch = (launch) async {
        if (launch.arguments.join(' ') == 'auth status' &&
            !statusStarted.isCompleted) {
          statusStarted.complete();
        }
      };
      final cancelToken = CancelToken();
      final service = DevinCliAcpService(
        launcher: launcher,
        supportDirectory: () async => supportDirectory.path,
        parentEnvironment: () => const {'PATH': '/usr/bin'},
      );

      final request = service.request(
        account: _account,
        modelId: 'devin-cli-default',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Cancel during auth check'},
          ],
        },
        cancelToken: cancelToken,
      );
      await statusStarted.future;
      cancelToken.cancel();

      await expectLater(
        request,
        throwsA(
          predicate<AiGatewayExecutionException>(
            (error) => error.kind == AiGatewayFailureKind.cancelled,
          ),
        ),
      );
      expect(launcher.processes.single.terminated, isTrue);
      expect(launcher.launches.map((launch) => launch.arguments), [
        ['auth', 'status'],
      ]);
    });

    test(
      'cancels while waiting for CLI authentication lifecycle lock',
      () async {
        launcher.holdLogin = true;
        final loginStarted = Completer<void>();
        launcher.onLaunch = (launch) async {
          if (launch.arguments.join(' ') == 'auth login' &&
              !loginStarted.isCompleted) {
            loginStarted.complete();
          }
        };
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );
        final login = service.login(_account);
        await loginStarted.future;

        final cancelToken = CancelToken();
        final authentication = service.isAuthenticated(
          _account,
          cancelToken: cancelToken,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        cancelToken.cancel();

        await expectLater(
          authentication.timeout(const Duration(seconds: 1)),
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) => error.kind == AiGatewayFailureKind.cancelled,
            ),
          ),
        );
        expect(launcher.launches.map((launch) => launch.arguments), [
          ['auth', 'login'],
        ]);

        final logout = service.logout(_account);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(launcher.launches.map((launch) => launch.arguments), [
          ['auth', 'login'],
        ]);
        await launcher.processes.single.terminate();
        await Future.wait([login, logout]);
        expect(launcher.launches.map((launch) => launch.arguments), [
          ['auth', 'login'],
          ['auth', 'logout'],
        ]);
      },
    );

    test('rejects caller-provided tools before starting the CLI', () async {
      final service = DevinCliAcpService(
        launcher: launcher,
        supportDirectory: () async => supportDirectory.path,
        parentEnvironment: () => const {'PATH': '/usr/bin'},
      );

      await expectLater(
        service.request(
          account: _account,
          modelId: 'devin-cli-default',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Run this tool'},
            ],
            'tools': [
              {'type': 'function'},
            ],
          },
        ),
        throwsA(
          predicate<AiGatewayExecutionException>(
            (error) =>
                error.code == 'unsupported_capability' &&
                error.toString().contains('capability is not supported'),
          ),
        ),
      );
      expect(launcher.launches, isEmpty);
    });

    test(
      'rejects legacy function-calling fields instead of ignoring them',
      () async {
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        await expectLater(
          service.request(
            account: _account,
            modelId: 'devin-cli-default',
            body: const {
              'messages': [
                {'role': 'user', 'content': 'Call the configured function'},
              ],
              'functions': [
                {
                  'name': 'lookup',
                  'parameters': {'type': 'object'},
                },
              ],
              'function_call': 'auto',
            },
          ),
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) => error.code == 'unsupported_capability',
            ),
          ),
        );
        expect(launcher.launches, isEmpty);
      },
    );

    test(
      'rejects structured output modes instead of dropping the format',
      () async {
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        await expectLater(
          service.request(
            account: _account,
            modelId: 'devin-cli-default',
            body: const {
              'messages': [
                {'role': 'user', 'content': 'Return JSON'},
              ],
              'response_format': {'type': 'json_object'},
            },
          ),
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) => error.code == 'unsupported_capability',
            ),
          ),
        );
        expect(launcher.launches, isEmpty);
      },
    );

    test(
      'cancels during ACP initialization before creating a session',
      () async {
        final cancelToken = CancelToken();
        launcher.onMethod = (method) async {
          if (method == 'initialize') cancelToken.cancel();
        };
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        await expectLater(
          service.request(
            account: _account,
            modelId: 'devin-cli-default',
            body: const {
              'messages': [
                {'role': 'user', 'content': 'Cancel startup'},
              ],
            },
            cancelToken: cancelToken,
          ),
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) => error.kind == AiGatewayFailureKind.cancelled,
            ),
          ),
        );
        expect(launcher.processes.last.methods, ['initialize']);
        expect(launcher.processes.last.terminated, isTrue);
      },
    );

    test(
      'propagates prompt cancellation instead of returning partial text',
      () async {
        launcher.holdPrompt = true;
        final promptSent = Completer<void>();
        launcher.onMethod = (method) async {
          if (method == 'session/prompt' && !promptSent.isCompleted) {
            promptSent.complete();
          }
        };
        final cancelToken = CancelToken();
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        final request = service.request(
          account: _account,
          modelId: 'devin-cli-default',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Cancel while generating'},
            ],
          },
          cancelToken: cancelToken,
        );
        await promptSent.future;
        cancelToken.cancel();

        await expectLater(
          request,
          throwsA(
            predicate<AiGatewayExecutionException>(
              (error) => error.kind == AiGatewayFailureKind.cancelled,
            ),
          ),
        );
        expect(launcher.processes.last.terminated, isTrue);
      },
    );

    test('cleans the workspace when process startup fails', () async {
      launcher.startError = StateError('process unavailable');
      launcher.startErrorArguments = ['acp'];
      final service = DevinCliAcpService(
        launcher: launcher,
        supportDirectory: () async => supportDirectory.path,
        parentEnvironment: () => const {'PATH': '/usr/bin'},
      );

      await expectLater(
        service.request(
          account: _account,
          modelId: 'devin-cli-default',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Start'},
            ],
          },
        ),
        throwsA(
          predicate<AiGatewayExecutionException>(
            (error) => error.kind == AiGatewayFailureKind.transportUnavailable,
          ),
        ),
      );
      expect(launcher.workingDirectories, hasLength(2));
      expect(
        await Directory(launcher.workingDirectories.last).exists(),
        isFalse,
      );
    });

    test('cleans the workspace when executable approval changes', () async {
      launcher.startError = const DevinCliAcpExecutableApprovalException();
      launcher.startErrorArguments = ['acp'];
      final service = DevinCliAcpService(
        launcher: launcher,
        supportDirectory: () async => supportDirectory.path,
        parentEnvironment: () => const {'PATH': '/usr/bin'},
      );

      await expectLater(
        service.request(
          account: _account,
          modelId: 'devin-cli-default',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Start'},
            ],
          },
        ),
        throwsA(
          predicate<AiGatewayExecutionException>(
            (error) =>
                error.kind == AiGatewayFailureKind.authenticationRequired,
          ),
        ),
      );
      expect(launcher.workingDirectories, hasLength(2));
      expect(
        await Directory(launcher.workingDirectories.last).exists(),
        isFalse,
      );
    });

    test(
      'terminates the logout process before removing its account home',
      () async {
        launcher.exitError = TimeoutException('logout timed out');
        final service = DevinCliAcpService(
          launcher: launcher,
          supportDirectory: () async => supportDirectory.path,
          parentEnvironment: () => const {'PATH': '/usr/bin'},
        );

        await service.logout(_account);

        expect(launcher.processes.single.terminated, isTrue);
        final accountHome = Directory(
          DevinCliAcpHome.pathForAccount(
            supportDirectory: supportDirectory.path,
            accountId: _account.id,
          ),
        );
        expect(await accountHome.exists(), isFalse);
      },
    );

    test('rejects new requests after logout', () async {
      launcher.exitError = StateError('logout complete');
      final service = DevinCliAcpService(
        launcher: launcher,
        supportDirectory: () async => supportDirectory.path,
        parentEnvironment: () => const {'PATH': '/usr/bin'},
      );
      await service.logout(_account);

      await expectLater(
        service.request(
          account: _account,
          modelId: 'devin-cli-default',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Do not start'},
            ],
          },
        ),
        throwsA(
          predicate<AiGatewayExecutionException>(
            (error) =>
                error.kind == AiGatewayFailureKind.authenticationRequired,
          ),
        ),
      );
      expect(launcher.launches.map((launch) => launch.arguments), [
        ['auth', 'logout'],
      ]);
    });
  });
}

final _account = AiGatewayAccount(
  id: 'devin-account',
  connectorType: 'devin-cli-agentic',
  authType: 'cli_session',
  displayName: 'Devin CLI',
  endpointConfig: {
    DevinCliAcpLaunch.executablePathKey: '/trusted/devin',
    DevinCliAcpLaunch.executableSha256Key: _testExecutableSha256,
  },
);

class _FakeAcpLauncher implements DevinCliAcpProcessLauncher {
  final launches = <DevinCliAcpLaunch>[];
  final workingDirectories = <String>[];
  final processes = <_FakeAcpProcess>[];
  Future<void> Function(String method)? onMethod;
  Future<void> Function(DevinCliAcpLaunch launch)? onLaunch;
  bool holdPrompt = false;
  bool holdAuthStatus = false;
  bool holdLogin = false;
  Object? startError;
  List<String>? startErrorArguments;
  Object? exitError;
  Object? authStdoutError;
  bool unsupportedAgentMessageChunk = false;
  List<List<int>>? authStdoutChunks;
  int authStatusExitCode = 0;

  @override
  Future<DevinCliAcpProcess> start(
    DevinCliAcpLaunch launch, {
    required String workingDirectory,
  }) async {
    launches.add(launch);
    workingDirectories.add(workingDirectory);
    await onLaunch?.call(launch);
    if (startError != null &&
        (startErrorArguments == null ||
            launch.arguments.toString() == startErrorArguments.toString())) {
      throw startError!;
    }
    final process = _FakeAcpProcess(
      onMethod: onMethod,
      exitError: exitError,
      holdPrompt: holdPrompt,
      immediateExitCode:
          launch.arguments.join(' ') == 'auth status' && !holdAuthStatus
              ? authStatusExitCode
              : launch.arguments.join(' ') == 'auth login' && !holdLogin
                  ? 0
                  : launch.arguments.join(' ') == 'auth logout'
                      ? 0
                      : null,
      stdoutError:
          launch.arguments.join(' ') == 'auth status' ? authStdoutError : null,
      initialStdoutChunks:
          launch.arguments.join(' ') == 'auth status' ? authStdoutChunks : null,
      unsupportedAgentMessageChunk: unsupportedAgentMessageChunk,
    );
    processes.add(process);
    return process;
  }
}

class _FakeAcpProcess implements DevinCliAcpProcess {
  final _stdout = StreamController<String>();
  final _stdoutBytes = StreamController<List<int>>();
  final _exitCode = Completer<int>();
  final Future<void> Function(String method)? onMethod;
  final Object? exitError;
  final int? immediateExitCode;
  final bool holdPrompt;
  final Object? stdoutError;
  final List<List<int>>? initialStdoutChunks;
  final bool unsupportedAgentMessageChunk;
  final methods = <String>[];
  var stdoutBytesRead = 0;
  var terminated = false;

  _FakeAcpProcess({
    this.onMethod,
    this.exitError,
    this.immediateExitCode,
    this.holdPrompt = false,
    this.stdoutError,
    this.initialStdoutChunks,
    this.unsupportedAgentMessageChunk = false,
  }) {
    if (stdoutError != null) _stdoutBytes.addError(stdoutError!);
    for (final chunk in initialStdoutChunks ?? const <List<int>>[]) {
      _stdoutBytes.add(chunk);
    }
    if (immediateExitCode != null) _exitCode.complete(immediateExitCode);
  }

  @override
  Stream<List<int>> get stdoutBytes => _stdoutBytes.stream.map((chunk) {
        stdoutBytesRead += chunk.length;
        return chunk;
      });

  @override
  Stream<String> get stdoutLines => _stdout.stream;

  @override
  Future<int> get exitCode =>
      exitError == null ? _exitCode.future : Future.error(exitError!);

  @override
  Future<void> writeLine(String line) async {
    final request = jsonDecode(line) as Map<String, dynamic>;
    final method = request['method'];
    if (method is String) {
      methods.add(method);
      await onMethod?.call(method);
    }
    final id = request['id'];
    if (id == null) return;
    final result = switch (method) {
      'initialize' => {'protocolVersion': 1},
      'session/new' => {'sessionId': 'session-1'},
      'session/prompt' => {'stopReason': 'end_turn'},
      _ => <String, Object?>{},
    };
    if (method == 'session/prompt') {
      _addLine(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'session/update',
          'params': {
            'sessionId': 'session-1',
            'update': {
              'sessionUpdate': 'tool_call',
              'toolCall': {'title': 'Inspecting workspace'},
            },
          },
        }),
      );
      _addLine(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'session/update',
          'params': {
            'sessionId': 'session-1',
            'update': {
              'sessionUpdate': 'agent_message_chunk',
              'content': unsupportedAgentMessageChunk
                  ? {'type': 'image', 'data': 'unsupported'}
                  : {'type': 'text', 'text': 'Hello from Devin'},
            },
          },
        }),
      );
    }
    if (method == 'session/prompt' && holdPrompt) return;
    _addLine(jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}));
  }

  void _addLine(String line) => _stdout.add(line);

  @override
  Future<void> terminate() async {
    if (terminated) return;
    terminated = true;
    if (!_exitCode.isCompleted) _exitCode.complete(0);
    unawaited(_stdout.close());
    unawaited(_stdoutBytes.close());
  }
}
