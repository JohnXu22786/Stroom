import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';
import 'package:stroom/ai_gateway/ai_gateway_contracts.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_routing_service.dart';
import 'package:stroom/src/ai_gateway/ai_gateway_facade.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Zed Hosted saves only account credentials after the loopback callback',
      () async {
    final (runtime, accountService, preferences) = _runtime();
    Future<void>? browserRequest;
    var browserStatus = 0;
    try {
      final saved = await runtime.oauthAuthorization.authorize(
        _zedAccount(),
        openInAppAuthorization: (authorizationUri, callbackUri, _) async {
          expect(authorizationUri.host, 'zed.dev');
          browserRequest = Future(() async {
            final callback = callbackUri.replace(
              queryParameters: {
                'user_id': 'zed-user',
                'access_token': _encryptForAuthorizationUrl(
                  authorizationUri,
                  'zed-access-token',
                ),
              },
            );
            browserStatus = await _sendLoopbackCallback(callback);
          });
          await browserRequest;
          return true;
        },
      );
      expect(browserStatus, HttpStatus.ok);
      expect(saved.hasCredential, isTrue);
      final stored = (await accountService.listAccounts()).single;
      final credential = jsonDecode(
        (await accountService.readCredential(stored.id))!,
      ) as Map<String, dynamic>;
      expect(credential['oauth_contract'], 'zed-hosted-native-rsa-v1');
      expect(credential['user_id'], 'zed-user');
      expect(credential['access_token'], 'zed-access-token');
      expect(credential['system_id'], isNotEmpty);
      expect(credential['organization_id'], 'org-1');
      expect(credential.keys, isNot(contains('private_key')));
      expect(credential.keys, isNot(contains('privateKey')));
    } finally {
      await preferences
          .remove(LlmAccountMigrationService.accountsPreferenceKey);
    }
  });

  test(
      'Zed Hosted callback denial does not save credentials and closes listener',
      () async {
    final (runtime, accountService, preferences) = _runtime();
    Future<void>? browserRequest;
    var callbackPort = 0;
    try {
      await expectLater(
        runtime.oauthAuthorization.authorize(
          _zedAccount(),
          openInAppAuthorization: (_, callbackUri, _) async {
            callbackPort = callbackUri.port;
            browserRequest = Future(() async {
              final callback = callbackUri.replace(
                queryParameters: const {'error': 'access_denied'},
              );
              await _sendLoopbackCallback(callback);
            });
            await browserRequest;
            return true;
          },
        ),
        throwsA(isA<AiGatewayOAuthException>()),
      );
      await browserRequest;
      expect(await accountService.listAccounts(), isEmpty);
      final server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        callbackPort,
      );
      await server.close();
    } finally {
      await preferences
          .remove(LlmAccountMigrationService.accountsPreferenceKey);
    }
  });
}

(LlmChatRoutingRuntime, LlmAccountConnectorService, _MemoryPreferences)
    _runtime() {
  final preferences = _MemoryPreferences();
  final accounts = LlmAccountConnectorService(
    preferences: preferences,
    credentialStore: _MemoryCredentials(),
    dio: Dio()
      ..httpClientAdapter = _FunctionalAdapter((request) async {
        if (request.uri.path == '/client/users/me') {
          return ResponseBody.fromString(
            jsonEncode({
              'email': 'zed@example.test',
              'name': 'Zed User',
              'default_organization_id': 'org-1',
            }),
            200,
            headers: const {
              'content-type': ['application/json']
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      }),
  );
  return (
    LlmChatRoutingRuntime(
      accountService: accounts,
      routingService: LlmRoutingService(accountService: accounts),
      oauthDio: Dio()
        ..httpClientAdapter = _FunctionalAdapter((request) async {
          if (request.uri.path == '/client/users/me') {
            return ResponseBody.fromString(
              jsonEncode({
                'email': 'zed@example.test',
                'name': 'Zed User',
                'default_organization_id': 'org-1',
              }),
              200,
              headers: const {
                'content-type': ['application/json']
              },
            );
          }
          return ResponseBody.fromString('{}', 404);
        }),
    ),
    accounts,
    preferences,
  );
}

Future<int> _sendLoopbackCallback(Uri callback) async {
  final socket = await Socket.connect(callback.host, callback.port);
  socket.write(
    'GET ${callback.path}?${callback.query} HTTP/1.1\r\n'
    'Host: ${callback.host}:${callback.port}\r\n'
    'Connection: close\r\n\r\n',
  );
  await socket.flush();
  final response = await utf8.decoder.bind(socket).join();
  socket.destroy();
  return int.parse(response.split(' ').elementAt(1));
}

AiGatewayAccount _zedAccount() => AiGatewayAccount(
      id: 'zed-oauth-test',
      connectorType: 'zed-hosted',
      authType: 'oauth',
      displayName: 'Zed Hosted Models',
    );

String _encryptForAuthorizationUrl(Uri authorizationUri, String value) {
  final encoded = authorizationUri.queryParameters['native_app_public_key']!;
  final sequence = ASN1Parser(
    Uint8List.fromList(base64Url.decode(base64Url.normalize(encoded))),
  ).nextObject() as ASN1Sequence;
  final elements = sequence.elements!;
  final publicKey = RSAPublicKey(
    (elements[0] as ASN1Integer).integer!,
    (elements[1] as ASN1Integer).integer!,
  );
  final cipher = OAEPEncoding.withSHA256(RSAEngine())
    ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
  return base64Url
      .encode(cipher.process(Uint8List.fromList(utf8.encode(value))));
}

class _MemoryPreferences implements LlmAccountPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

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
  final Future<ResponseBody> Function(RequestOptions request) handler;

  _FunctionalAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
