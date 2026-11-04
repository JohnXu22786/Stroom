import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_connector_http_client.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/trae_solo_connector.dart';

void main() {
  test(
    'refreshes only callback-issued Trae credentials by ExchangeToken',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            jsonEncode({
              'ResponseMetadata': {},
              'Result': {
                'Token': _testJwt({'web_id': 'web-2'}),
                'RefreshToken': 'refresh-2',
                'TokenExpireAt': DateTime.utc(
                  2030,
                  1,
                  2,
                ).millisecondsSinceEpoch.toString(),
              },
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final originalToken = _testJwt({'web_id': 'web-1'});
      final callback = Uri.http('127.0.0.1:43210', '/authorize', {
        'loginTraceID': 'state-123456789012345678901234567890',
        'userJwt': jsonEncode({
          'ClientID': 'client-1',
          'Token': originalToken,
          'RefreshToken': 'refresh-1',
          'TokenExpireAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
        }),
        'userInfo': jsonEncode({'UserID': 'user-1'}),
        'host': 'api-us.trae.ai',
      });
      final account = await service.saveAccount(
        LlmAccount(
          id: 'trae-callback',
          connectorType: 'trae',
          authType: 'session_token',
          displayName: 'Trae callback account',
          status: LlmAccountStatus.ready,
        ),
        secret: TraeSoloCredential.fromCallbackUri(
          callback,
          expectedState: 'state-123456789012345678901234567890',
        ).toStoredValue(),
        traeCallbackIssued: true,
      );

      expect(await service.refreshCredential(account), isTrue);
      expect(
        requests.single.uri.toString(),
        'https://api-us.trae.ai/cloudide/api/v3/trae/oauth/ExchangeToken',
      );
      expect(requests.single.data, {
        'ClientID': 'client-1',
        'RefreshToken': 'refresh-1',
        'ClientSecret': '-',
        'UserID': '',
      });
      final refreshed = TraeSoloCredential.fromPastedValue(
        (await service.readCredential(account.id))!,
      );
      expect(refreshed.refreshToken, 'refresh-2');
      expect(refreshed.accessToken, isNot(originalToken));
      expect(refreshed.expiresAt, DateTime.utc(2030, 1, 2));
    },
  );

  test(
    'rejects a Trae refresh error envelope even when Result has a token',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({
              'ResponseMetadata': {
                'Error': {'Code': 'InvalidRefreshToken'},
              },
              'Result': {
                'Token': _testJwt({'web_id': 'must-not-be-saved'}),
                'RefreshToken': 'must-not-be-saved',
                'TokenExpireAt': DateTime.utc(
                  2030,
                  1,
                  2,
                ).millisecondsSinceEpoch,
              },
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final originalToken = _testJwt({'web_id': 'web-1'});
      final callback = Uri.http('127.0.0.1:43210', '/authorize', {
        'loginTraceID': 'state-123456789012345678901234567890',
        'userJwt': jsonEncode({
          'ClientID': 'client-1',
          'Token': originalToken,
          'RefreshToken': 'refresh-1',
          'TokenExpireAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
        }),
        'userInfo': jsonEncode({'UserID': 'user-1'}),
      });
      final account = await service.saveAccount(
        LlmAccount(
          id: 'trae-callback-error',
          connectorType: 'trae',
          authType: 'session_token',
          displayName: 'Trae callback account',
          status: LlmAccountStatus.ready,
        ),
        secret: TraeSoloCredential.fromCallbackUri(
          callback,
          expectedState: 'state-123456789012345678901234567890',
        ).toStoredValue(),
        traeCallbackIssued: true,
      );

      await expectLater(
        service.refreshCredential(account),
        throwsA(isA<LlmAccountConnectorException>()),
      );
      final stored = TraeSoloCredential.fromPastedValue(
        (await service.readCredential(account.id))!,
      );
      expect(stored.accessToken, originalToken);
      expect(stored.refreshToken, 'refresh-1');
    },
  );

  test('uses the rotated JWT expiry when Trae omits TokenExpireAt', () async {
    final rotatedExpiry = DateTime.now().toUtc().add(const Duration(days: 2));
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'ResponseMetadata': {},
            'Result': {
              'Token': _testJwt({
                'web_id': 'web-2',
                'exp': rotatedExpiry.millisecondsSinceEpoch ~/ 1000,
              }),
              'RefreshToken': 'refresh-2',
            },
          }),
          200,
          headers: const {
            'content-type': ['application/json'],
          },
        );
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
      dio: dio,
    );
    final originalToken = _testJwt({'web_id': 'web-1'});
    final staleExpiry = DateTime.now().toUtc().subtract(
      const Duration(minutes: 1),
    );
    final callback = Uri.http('127.0.0.1:43210', '/authorize', {
      'loginTraceID': 'state-123456789012345678901234567890',
      'userJwt': jsonEncode({
        'ClientID': 'client-1',
        'Token': originalToken,
        'RefreshToken': 'refresh-1',
        'TokenExpireAt': staleExpiry.millisecondsSinceEpoch,
      }),
      'userInfo': jsonEncode({'UserID': 'user-1'}),
    });
    final account = await service.saveAccount(
      LlmAccount(
        id: 'trae-callback-no-expiry',
        connectorType: 'trae',
        authType: 'session_token',
        displayName: 'Trae callback account',
        status: LlmAccountStatus.ready,
      ),
      secret: TraeSoloCredential.fromCallbackUri(
        callback,
        expectedState: 'state-123456789012345678901234567890',
      ).toStoredValue(),
      traeCallbackIssued: true,
    );

    expect(await service.refreshCredential(account), isTrue);
    final refreshed = TraeSoloCredential.fromPastedValue(
      (await service.readCredential(account.id))!,
    );
    expect(refreshed.accessToken, isNot(originalToken));
    expect(
      refreshed.expiresAt.millisecondsSinceEpoch ~/ 1000,
      rotatedExpiry.millisecondsSinceEpoch ~/ 1000,
    );
  });

  test('replays a Trae request once after a 401 refresh', () async {
    final requests = <RequestOptions>[];
    var sessionAttempts = 0;
    var refreshAttempts = 0;
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        if (options.uri.path.endsWith('/ExchangeToken')) {
          refreshAttempts++;
          return ResponseBody.fromString(
            jsonEncode({
              'ResponseMetadata': {},
              'Result': {
                'Token': _testJwt({'web_id': 'web-$refreshAttempts'}),
                'RefreshToken': 'refresh-${refreshAttempts + 1}',
                'TokenExpireAt': DateTime.utc(
                  2030,
                  1,
                  2,
                ).millisecondsSinceEpoch,
              },
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        }
        if (options.uri.path.endsWith('/chat_sessions')) {
          sessionAttempts++;
          if (sessionAttempts == 1) return ResponseBody.fromString('{}', 401);
          return ResponseBody.fromString(
            jsonEncode({
              'code': 0,
              'data': {
                'chat_session_id': 'session-1',
                'message_id': 'message-1',
              },
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        }
        return ResponseBody.fromString('event: done\ndata: {}\n\n', 200);
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
      dio: dio,
    );
    final originalToken = _testJwt({'web_id': 'web-0'});
    final callback = Uri.http('127.0.0.1:43210', '/authorize', {
      'loginTraceID': 'state-123456789012345678901234567890',
      'userJwt': jsonEncode({
        'ClientID': 'client-1',
        'Token': originalToken,
        'RefreshToken': 'refresh-1',
        'TokenExpireAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      }),
      'userInfo': jsonEncode({'UserID': 'user-1'}),
    });
    final account = await service.saveAccount(
      LlmAccount(
        id: 'trae-callback-401',
        connectorType: 'trae',
        authType: 'session_token',
        displayName: 'Trae callback account',
        status: LlmAccountStatus.ready,
        models: [
          LlmUpstreamModel(
            id: 'trae-model',
            upstreamModelId: 'solo-model',
            displayName: 'SOLO model',
          ),
        ],
      ),
      secret: TraeSoloCredential.fromCallbackUri(
        callback,
        expectedState: 'state-123456789012345678901234567890',
      ).toStoredValue(),
      traeCallbackIssued: true,
    );

    await LlmConnectorHttpClient(accountService: service, dio: dio).request(
      account: account,
      modelId: 'solo-model',
      body: const {
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
      },
      stream: true,
    );

    final sessionRequests = requests
        .where((request) => request.uri.path.endsWith('/chat_sessions'))
        .toList();
    expect(sessionRequests, hasLength(2));
    expect(
      sessionRequests.first.headers['Authorization'],
      'Cloud-IDE-JWT ${_testJwt({'web_id': 'web-1'})}',
    );
    expect(
      sessionRequests.last.headers['Authorization'],
      'Cloud-IDE-JWT ${_testJwt({'web_id': 'web-2'})}',
    );
    final refreshRequests = requests
        .where((request) => request.uri.path.endsWith('/ExchangeToken'))
        .toList();
    expect(refreshRequests, hasLength(2));
    expect(refreshRequests.first.data['RefreshToken'], 'refresh-1');
    expect(refreshRequests.last.data['RefreshToken'], 'refresh-2');
  });

  test('maps failed Trae refreshes to authentication required', () async {
    for (final expired in [true, false]) {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          if (options.uri.path.endsWith('/ExchangeToken')) {
            return ResponseBody.fromString('{}', 500);
          }
          return ResponseBody.fromString('{}', 401);
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final callback = Uri.http('127.0.0.1:43210', '/authorize', {
        'loginTraceID': 'state-123456789012345678901234567890',
        'userJwt': jsonEncode({
          'Token': _testJwt({'web_id': 'web-1'}),
          'RefreshToken': 'refresh-1',
          'TokenExpireAt': DateTime.now()
              .toUtc()
              .add(
                expired
                    ? const Duration(minutes: -1)
                    : const Duration(minutes: 1),
              )
              .millisecondsSinceEpoch,
        }),
        'userInfo': jsonEncode({'UserID': 'user-1'}),
      });
      final account = await service.saveAccount(
        LlmAccount(
          id: 'trae-refresh-failure-$expired',
          connectorType: 'trae',
          authType: 'session_token',
          displayName: 'Trae callback account',
          status: LlmAccountStatus.ready,
          models: [
            LlmUpstreamModel(
              id: 'trae-model',
              upstreamModelId: 'solo-model',
              displayName: 'SOLO model',
            ),
          ],
        ),
        secret: TraeSoloCredential.fromCallbackUri(
          callback,
          expectedState: 'state-123456789012345678901234567890',
        ).toStoredValue(),
        traeCallbackIssued: true,
      );

      await expectLater(
        LlmConnectorHttpClient(accountService: service, dio: dio).request(
          account: account,
          modelId: 'solo-model',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
          stream: true,
        ),
        throwsA(isA<LlmConnectorAuthenticationRequired>()),
      );
      expect(
        requests.any((request) => request.uri.path.endsWith('/ExchangeToken')),
        isTrue,
      );
    }
  });

  test(
    'Trae discovery uses the account catalog and keeps routing text-only',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            jsonEncode({
              'code': 0,
              'data': [
                {'name': 'solo-model', 'display_name': 'SOLO model'},
                {'name': 'embed-private', 'chat': false},
              ],
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final importStarted = DateTime.now().toUtc();
      final account = await service.saveAccount(
        LlmAccount(
          id: 'trae-import',
          connectorType: 'trae',
          authType: 'session_token',
          displayName: 'Trae account',
          status: LlmAccountStatus.ready,
        ),
        secret: jsonEncode({
          'access_token': _testJwt({'web_id': 'web-1'}),
          'refresh_token': 'imported-refresh-token',
          'providerSpecificData': {'authMethod': 'oauth_callback'},
        }),
      );
      final importFinished = DateTime.now().toUtc();
      final savedSecret = await service.readCredential(account.id);
      final storedCredential = TraeSoloCredential.fromPastedValue(
        savedSecret!,
        now: importFinished.add(const Duration(days: 20)),
      );

      final models = await service.discoverModels(account, refreshRemote: true);

      expect(await service.refreshCredential(account), isFalse);

      expect(
        requests.single.uri.toString(),
        'https://core-normal.trae.ai/api/remote/v1/models?functions=solo_agent_remote,solo_work_remote',
      );
      expect(
        requests.single.headers['Authorization'],
        startsWith('Cloud-IDE-JWT '),
      );
      expect(models.map((model) => model.upstreamModelId), ['solo-model']);
      expect(models.single.capabilities, {'chat': true, 'streaming': true});
      expect(
        storedCredential.expiresAt.isAfter(
          importStarted.add(const Duration(days: 13, hours: 23)),
        ),
        isTrue,
      );
      expect(
        storedCredential.expiresAt.isBefore(
          importFinished.add(const Duration(days: 14, minutes: 1)),
        ),
        isTrue,
      );
      expect(LlmConnectorRegistry.chatAdapterEndpointType('trae'), 'openai');
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'trae',
          'session_token',
        ),
        isTrue,
      );
    },
  );

  test(
    'Trae rejects tool and function definitions before sending upstream',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString('{}', 200);
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await service.saveAccount(
        LlmAccount(
          id: 'trae-functions',
          connectorType: 'trae',
          authType: 'session_token',
          displayName: 'Trae account',
          status: LlmAccountStatus.ready,
          models: [
            LlmUpstreamModel(
              id: 'trae-model',
              upstreamModelId: 'solo-model',
              displayName: 'SOLO model',
            ),
          ],
        ),
        secret: _testJwt(const {}),
      );

      final client = LlmConnectorHttpClient(accountService: service, dio: dio);
      for (final unsupported in const [
        {
          'functions': [
            {'name': 'lookup'},
          ],
        },
        {
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'lookup'},
            },
          ],
        },
        {'function_call': 'auto'},
      ]) {
        await expectLater(
          client.request(
            account: account,
            modelId: 'solo-model',
            body: {
              'model': 'solo-model',
              'messages': const [
                {'role': 'user', 'content': 'hi'},
              ],
              ...unsupported,
            },
            stream: true,
          ),
          throwsA(
            isA<LlmConnectorHttpException>().having(
              (error) => error.code,
              'code',
              'unsupported_capability',
            ),
          ),
        );
      }
      expect(requests, isEmpty);
    },
  );
}

String _testJwt(Map<String, Object?> claims) =>
    'eyJhbGciOiJSUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.signature';

class _MemoryPreferences implements LlmAccountPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

class _MemoryCredentials implements LlmCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String reference) async => values.remove(reference);

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String secret) async {
    values[reference] = secret;
  }
}

class _FunctionalAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  _FunctionalAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => onFetch(options);

  @override
  void close({bool force = false}) {}
}
