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
        secret: _testJwt({'web_id': 'web-1'}),
      );
      final importFinished = DateTime.now().toUtc();
      final savedSecret = await service.readCredential(account.id);
      final storedCredential = TraeSoloCredential.fromPastedValue(
        savedSecret!,
        now: importFinished.add(const Duration(days: 20)),
      );

      final models = await service.discoverModels(account, refreshRemote: true);

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
