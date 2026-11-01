import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jose/jose.dart';
import 'package:stroom/services/llm_oauth_flow.dart';
import 'package:stroom/services/llm_oauth_token_client.dart';

void main() {
  test(
    'Meta Muse uses its pinned device grant and key-mint exchange',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          requests.add(request);
          if (request.uri.path == '/oidc/device/authorization/') {
            return ResponseBody.fromString(
              jsonEncode({
                'device_code': 'fixture-meta-device-code',
                'user_code': 'META-1234',
                'verification_uri': 'https://www.meta.ai/device',
                'verification_uri_complete':
                    'https://www.meta.ai/device?code=META-1234',
                'expires_in': 60,
                'interval': 1,
              }),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          if (request.uri.path == '/oidc/device/token/') {
            return ResponseBody.fromString(
              jsonEncode({'access_token': 'dca:fixture-meta-dca'}),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({
              'api_key': 'fixture-meta-muse-key',
              'base_url': 'https://api.meta.ai/v1',
              'user_email': 'muse@example.test',
              'user_full_name': 'Muse User',
              'subs_tier_name': 'Muse Plan',
              'is_subs_active': true,
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final client = LlmOAuthTokenClient(dio: dio);

      final deviceCode = await client.startMetaMuseDeviceAuthorization();
      final bundle = await client.pollMetaMuseDeviceAuthorization(
        deviceCode: deviceCode,
      );

      expect(deviceCode.userCode, 'META-1234');
      expect(deviceCode.verificationUri.host, 'www.meta.ai');
      expect(requests.first.uri.host, 'auth.meta.com');
      expect(requests.first.method, 'POST');
      expect(requests[1].uri.path, '/oidc/device/token/');
      expect(
        requests[1].data,
        containsPair('device_code', 'fixture-meta-device-code'),
      );
      expect(requests.last.uri.toString(), 'https://api.meta.ai/muse-code/key');
      expect(
        requests.last.headers['Authorization'],
        'Bearer dca:fixture-meta-dca',
      );
      expect(bundle['api_key'], 'fixture-meta-muse-key');
      expect(bundle['dca_token'], 'dca:fixture-meta-dca');
      expect(bundle['email'], 'muse@example.test');
      expect(bundle['name'], 'Muse User');
      expect(bundle['oauth_contract'], 'meta-muse-device-v1');
      expect(
        requests.last.toString(),
        isNot(contains('fixture-meta-muse-key')),
      );
    },
  );

  test(
    'Meta Muse device authorization expires and polling can be cancelled',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          requests.add(request);
          return ResponseBody.fromString(
            jsonEncode({
              'device_code': 'fixture-meta-device-code',
              'user_code': 'META-1234',
              'verification_uri': 'https://www.meta.ai/device',
              'expires_in': 1,
              'interval': 5,
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final client = LlmOAuthTokenClient(dio: dio);
      final expiredCode = await client.startMetaMuseDeviceAuthorization();

      await expectLater(
        client.pollMetaMuseDeviceAuthorization(deviceCode: expiredCode),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      expect(requests, hasLength(1), reason: 'expired grants are not polled');

      final cancelToken = CancelToken();
      final cancelCode = LlmMetaMuseDeviceCode.fromOAuthResponse(
        deviceCode: 'fixture-meta-device-code',
        userCode: 'META-1234',
        verificationUri: Uri.parse('https://www.meta.ai/device'),
        verificationUriComplete: Uri.parse('https://www.meta.ai/device'),
        expiresIn: const Duration(minutes: 1),
        interval: const Duration(seconds: 5),
      );
      final polling = client.pollMetaMuseDeviceAuthorization(
        deviceCode: cancelCode,
        cancelToken: cancelToken,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cancelToken.cancel('User cancelled');
      await expectLater(polling, throwsA(isA<LlmOAuthFlowException>()));
      expect(
        requests,
        hasLength(1),
        reason: 'cancelled polls do not reach Meta',
      );
    },
  );

  test(
    'Meta Muse requires verified email and active subscription status',
    () async {
      for (final minted in [
        {'api_key': 'muse-key', 'is_subs_active': true},
        {'api_key': 'muse-key', 'user_email': 'muse@example.test'},
        {
          'api_key': 'muse-key',
          'user_email': 'muse@example.test',
          'is_subs_active': 'true',
        },
      ]) {
        final dio = Dio()
          ..httpClientAdapter = _OAuthAdapter((request) async {
            final response = switch (request.uri.path) {
              '/oidc/device/authorization/' => {
                  'device_code': 'fixture-meta-device-code',
                  'user_code': 'META-1234',
                  'verification_uri': 'https://www.meta.ai/device',
                  'expires_in': 60,
                  'interval': 1,
                },
              '/oidc/device/token/' => {'access_token': 'dca:fixture-meta-dca'},
              _ => minted,
            };
            return ResponseBody.fromString(
              jsonEncode(response),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });
        final client = LlmOAuthTokenClient(dio: dio);
        final deviceCode = await client.startMetaMuseDeviceAuthorization();

        await expectLater(
          client.pollMetaMuseDeviceAuthorization(deviceCode: deviceCode),
          throwsA(isA<LlmOAuthFlowException>()),
        );
      }
    },
  );

  test(
    'xAI device authorization stays separate across its two API modes',
    () async {
      final requests = <RequestOptions>[];
      final generatedKey = JsonWebKey.generate('ES256');
      final privateKey = JsonWebKey.fromCryptoKeys(
        publicKey: generatedKey.cryptoKeyPair.publicKey,
        privateKey: generatedKey.cryptoKeyPair.privateKey,
        keyId: 'xai-signing-key',
      );
      final publicKey = JsonWebKey.fromCryptoKeys(
        publicKey: generatedKey.cryptoKeyPair.publicKey,
        keyId: 'xai-signing-key',
      );
      final claims = {
        'iss': LlmOAuthTokenClient.xaiIssuer,
        'sub': 'account-123',
        'aud': LlmOAuthTokenClient.xaiClientId,
        'email': 'xai@example.test',
        'email_verified': true,
        'exp': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
      };
      final validIdToken = (JsonWebSignatureBuilder()
            ..jsonContent = claims
            ..setProtectedHeader('typ', 'JWT')
            ..setProtectedHeader('kid', 'xai-signing-key')
            ..addRecipient(privateKey, algorithm: 'ES256'))
          .build()
          .toCompactSerialization();
      var returnedIdToken = validIdToken;
      Object? returnedScope =
          'openid profile email offline_access grok-cli:access';
      var includeReturnedScope = true;
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          requests.add(request);
          if (request.uri.path == '/.well-known/openid-configuration') {
            return ResponseBody.fromString(
              jsonEncode({
                'issuer': LlmOAuthTokenClient.xaiIssuer,
                'jwks_uri': 'https://auth.x.ai/.well-known/jwks.json',
                'id_token_signing_alg_values_supported': ['ES256'],
                'device_authorization_endpoint':
                    'https://auth.x.ai/oauth2/device/code',
                'token_endpoint': 'https://auth.x.ai/oauth2/token',
              }),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          if (request.uri.path == '/.well-known/jwks.json') {
            return ResponseBody.fromString(
              jsonEncode({
                'keys': [publicKey.toJson()],
              }),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          if (request.uri.path == '/oauth2/device/code') {
            return ResponseBody.fromString(
              jsonEncode({
                'device_code': 'fixture-xai-device-code',
                'user_code': 'XAI-1234',
                'verification_uri': 'https://x.ai/activate',
                'verification_uri_complete':
                    'https://x.ai/activate?code=XAI-1234',
                'expires_in': 600,
                'interval': 1,
              }),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'fixture-xai-access',
              'refresh_token': 'fixture-xai-refresh',
              'id_token': returnedIdToken,
              'token_type': 'Bearer',
              if (includeReturnedScope) 'scope': returnedScope,
              'expires_in': 3600,
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final client = LlmOAuthTokenClient(dio: dio);

      final code = await client.startXaiDeviceAuthorization(
        connectorType: 'grok-cli',
      );
      final apiCode = await client.startXaiDeviceAuthorization(
        connectorType: 'xai-oauth',
      );
      final token = await client.pollXaiDeviceAuthorization(deviceCode: code);

      expect(
        requests.map((request) => request.uri.host),
        everyElement('auth.x.ai'),
      );
      final deviceRequests = requests
          .where((request) => request.uri.path == '/oauth2/device/code')
          .toList();
      expect(deviceRequests, hasLength(2));
      expect(
        deviceRequests[0].data['scope'],
        'openid profile email offline_access grok-cli:access',
      );
      expect(
        deviceRequests[1].data['scope'],
        'openid profile email offline_access api:access',
      );
      expect(
        deviceRequests[0].data['client_id'],
        LlmOAuthTokenClient.xaiClientId,
      );
      final tokenRequest = requests.singleWhere(
        (request) => request.uri.path == '/oauth2/token',
      );
      expect(tokenRequest.data.toString(), contains('device_code'));
      expect(token['access_token'], 'fixture-xai-access');
      expect(token['refresh_token'], 'fixture-xai-refresh');
      expect(token['identity_sub'], 'account-123');
      expect(token['identity_email'], 'xai@example.test');
      expect(token['oauth_contract'], 'xai-device-v1');
      expect(requests.last.toString(), isNot(contains('fixture-xai-access')));
      await expectLater(
        client.pollXaiDeviceAuthorization(
          deviceCode: code,
          expectedSubject: 'different-account',
        ),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      returnedIdToken = '${validIdToken.split('.').take(2).join('.')}.invalid';
      await expectLater(
        client.pollXaiDeviceAuthorization(deviceCode: code),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      final nullAzpToken = (JsonWebSignatureBuilder()
            ..jsonContent = {...claims, 'azp': null}
            ..setProtectedHeader('typ', 'JWT')
            ..setProtectedHeader('kid', 'xai-signing-key')
            ..addRecipient(privateKey, algorithm: 'ES256'))
          .build()
          .toCompactSerialization();
      returnedIdToken = nullAzpToken;
      await expectLater(
        client.pollXaiDeviceAuthorization(deviceCode: code),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      returnedIdToken = validIdToken;
      final conflictingAzpToken = (JsonWebSignatureBuilder()
            ..jsonContent = {...claims, 'azp': 'another-client'}
            ..setProtectedHeader('typ', 'JWT')
            ..setProtectedHeader('kid', 'xai-signing-key')
            ..addRecipient(privateKey, algorithm: 'ES256'))
          .build()
          .toCompactSerialization();
      returnedIdToken = conflictingAzpToken;
      await expectLater(
        client.pollXaiDeviceAuthorization(deviceCode: code),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      returnedIdToken = validIdToken;
      returnedScope = 'openid profile email offline_access api:access';
      await expectLater(
        client.pollXaiDeviceAuthorization(deviceCode: code),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      returnedScope = 'openid profile email offline_access grok-cli:access';
      await expectLater(
        client.pollXaiDeviceAuthorization(deviceCode: apiCode),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      returnedScope = '  ';
      await expectLater(
        client.pollXaiDeviceAuthorization(deviceCode: code),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      returnedScope = 42;
      await expectLater(
        client.pollXaiDeviceAuthorization(deviceCode: code),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      includeReturnedScope = false;
      returnedScope = null;
      final tokenWithoutScope = await client.pollXaiDeviceAuthorization(
        deviceCode: code,
      );
      expect(tokenWithoutScope['scope'], code.scope);
    },
  );

  test(
    'Kimi Code device authorization exchanges a polled grant safely',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          requests.add(request);
          if (request.uri.path.endsWith('/device_authorization')) {
            return ResponseBody.fromString(
              jsonEncode({
                'device_code': 'fixture-device-code',
                'user_code': 'ABCD-EFGH',
                'verification_uri': 'https://www.kimi.com/code/verify',
                'verification_uri_complete':
                    'https://www.kimi.com/code/verify?user_code=ABCD-EFGH',
                'expires_in': 600,
                'interval': 5,
              }),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'fixture-access-token',
              'refresh_token': 'fixture-refresh-token',
              'token_type': 'Bearer',
              'scope': 'user:inference',
              'expires_in': 3600,
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final client = LlmOAuthTokenClient(dio: dio);

      final deviceCode = await client.startKimiDeviceAuthorization(
        deviceId: 'stroom-device-1',
      );
      final pollingStarted = Stopwatch()..start();
      final token = await client.pollKimiDeviceAuthorization(
        deviceCode: deviceCode,
        deviceId: 'stroom-device-1',
      );

      expect(
        pollingStarted.elapsed,
        greaterThanOrEqualTo(const Duration(seconds: 5)),
      );
      expect(requests, hasLength(2));
      expect(requests.first.uri.host, 'auth.kimi.com');
      expect(requests.first.uri.path, '/api/oauth/device_authorization');
      expect(requests.first.headers['X-Msh-Platform'], 'CLIProxyAPI');
      expect(requests.first.headers['X-Msh-Device-Id'], 'stroom-device-1');
      expect(deviceCode.userCode, 'ABCD-EFGH');
      expect(deviceCode.verificationUriComplete.host, 'www.kimi.com');
      expect(requests.last.uri.path, '/api/oauth/token');
      expect(requests.last.headers['X-Msh-Platform'], 'CLIProxyAPI');
      expect(requests.last.data.toString(), contains('fixture-device-code'));
      expect(requests.last.data.toString(), contains('grant_type'));
      expect(requests.last.data.toString(), contains('device_code'));
      expect(token['access_token'], 'fixture-access-token');
      expect(token['refresh_token'], 'fixture-refresh-token');
      expect(token['device_id'], 'stroom-device-1');
      expect(token['oauth_contract'], 'kimi-code-device-v1');
      expect(requests.last.toString(), isNot(contains('fixture-access-token')));
    },
  );

  test('Kimi Code cancellation interrupts a pending polling delay', () async {
    final responseReturned = Completer<void>();
    final dio = Dio()
      ..httpClientAdapter = _OAuthAdapter((request) async {
        responseReturned.complete();
        return ResponseBody.fromString(
          jsonEncode({'error': 'authorization_pending'}),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
    final cancelToken = CancelToken();
    final client = LlmOAuthTokenClient(dio: dio);
    final deviceCode = LlmKimiDeviceCode.fromOAuthResponse(
      deviceCode: 'fixture-device-code',
      userCode: 'ABCD-EFGH',
      verificationUri: Uri.parse('https://www.kimi.com/code/verify'),
      verificationUriComplete: Uri.parse(
        'https://www.kimi.com/code/verify?user_code=ABCD-EFGH',
      ),
      expiresIn: const Duration(minutes: 1),
      interval: const Duration(seconds: 5),
    );
    final polling = client.pollKimiDeviceAuthorization(
      deviceCode: deviceCode,
      deviceId: 'stroom-device-1',
      cancelToken: cancelToken,
    );

    await responseReturned.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final stopwatch = Stopwatch()..start();
    cancelToken.cancel('User cancelled');

    await expectLater(polling, throwsA(isA<LlmOAuthFlowException>()));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('Kimi Code cancellation interrupts the initial polling delay', () async {
    var tokenRequests = 0;
    final dio = Dio()
      ..httpClientAdapter = _OAuthAdapter((request) async {
        tokenRequests++;
        return ResponseBody.fromString(
          jsonEncode({'error': 'authorization_pending'}),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
    final cancelToken = CancelToken();
    final client = LlmOAuthTokenClient(dio: dio);
    final deviceCode = LlmKimiDeviceCode.fromOAuthResponse(
      deviceCode: 'fixture-device-code',
      userCode: 'ABCD-EFGH',
      verificationUri: Uri.parse('https://www.kimi.com/code/verify'),
      verificationUriComplete: Uri.parse(
        'https://www.kimi.com/code/verify?user_code=ABCD-EFGH',
      ),
      expiresIn: const Duration(minutes: 1),
      interval: const Duration(seconds: 5),
    );
    final polling = client.pollKimiDeviceAuthorization(
      deviceCode: deviceCode,
      deviceId: 'stroom-device-1',
      cancelToken: cancelToken,
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    cancelToken.cancel('User cancelled');

    await expectLater(polling, throwsA(isA<LlmOAuthFlowException>()));
    expect(tokenRequests, 0);
  });

  group('LlmOAuthAuthorizationAttempt', () {
    test('creates separate ChatGPT registration attempts with PKCE', () {
      final callback = Uri.parse('http://127.0.0.1:54321/auth/callback');
      final first = LlmOAuthAuthorizationAttempt.openAiChatGpt(
        redirectUri: callback,
        hostId: 'urn:uuid:host',
      );
      final second = LlmOAuthAuthorizationAttempt.openAiChatGpt(
        redirectUri: callback,
        hostId: 'urn:uuid:host',
      );

      expect(first.state, isNot(second.state));
      expect(first.nonce, isNot(second.nonce));
      expect(first.codeVerifier, isNot(second.codeVerifier));
      expect(first.authorizationUri.host, 'auth.openai.com');
      expect(first.authorizationUri.path, '/api/accounts/authorize');
      expect(
        first.authorizationUri.queryParameters['client_id'],
        'dynamic_agent_client',
      );
      expect(
        first.authorizationUri.queryParameters['redirect_uri'],
        callback.toString(),
      );
      expect(
        first.authorizationUri.queryParameters['resource'],
        'https://api.openai.com/v1',
      );
      expect(
        first.authorizationUri.queryParameters['code_challenge_method'],
        'S256',
      );
      expect(
        first.authorizationUri.queryParameters['code_challenge'],
        isNot(first.codeVerifier),
      );
      expect(first.authorizationUri.queryParameters['state'], first.state);
      expect(first.authorizationUri.queryParameters['nonce'], first.nonce);
      expect(
        first.authorizationUri.queryParameters['agent_name_hint'],
        'Stroom',
      );
      expect(
        first.authorizationUri.queryParameters['ext_agent_host_id'],
        'urn:uuid:host',
      );
      expect(
        first.authorizationUri.queryParameters['scope']!.split(' '),
        containsAll([
          'openid',
          'email',
          'offline_access',
          'resource.invoke',
          'chatgpt.tokens.use.direct',
        ]),
      );

      final reauthorization = LlmOAuthAuthorizationAttempt.openAiChatGpt(
        redirectUri: callback,
        hostId: 'urn:uuid:host',
        existingClientId: 'registered-client',
        idTokenHint: 'previously-verified-id-token',
      );
      expect(
        reauthorization.authorizationUri.queryParameters['id_token_hint'],
        'previously-verified-id-token',
      );
    });

    test('validates callback origin, path, state and issued client ID', () {
      final redirect = Uri.parse('http://127.0.0.1:54321/auth/callback');
      final attempt = LlmOAuthAuthorizationAttempt.openAiChatGpt(
        redirectUri: redirect,
        hostId: 'urn:uuid:host',
      );
      final callback = redirect.replace(
        queryParameters: {
          'code': 'one-time-code',
          'state': attempt.state,
          'client_id': 'oaiapp_registered-client',
        },
      );

      final result = attempt.consumeCallback(callback);

      expect(result.code, 'one-time-code');
      expect(result.clientId, 'oaiapp_registered-client');
      expect(
        () => attempt.consumeCallback(callback),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      expect(
        () => LlmOAuthAuthorizationAttempt.openAiChatGpt(
          redirectUri: redirect,
          hostId: 'urn:uuid:host',
        ).consumeCallback(
          callback.replace(
            queryParameters: {
              ...callback.queryParameters,
              'state': 'wrong-state',
            },
          ),
        ),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      expect(
        () => attempt.consumeCallback(callback.replace(path: '/callback')),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      expect(
        () => attempt.consumeCallback(callback.replace(host: 'localhost')),
        throwsA(isA<LlmOAuthFlowException>()),
      );
    });

    test('does not exchange an authorization denial or missing code', () {
      final redirect = Uri.parse('http://127.0.0.1:1455/auth/callback');
      final attempt = LlmOAuthAuthorizationAttempt.openAiChatGpt(
        redirectUri: redirect,
        hostId: 'urn:uuid:host',
      );

      expect(
        () => attempt.consumeCallback(
          redirect.replace(
            queryParameters: {'state': attempt.state, 'error': 'access_denied'},
          ),
        ),
        throwsA(isA<LlmOAuthFlowException>()),
      );
    });

    test('preserves hash characters in non-Claude OAuth codes', () {
      final redirect = Uri.parse('http://127.0.0.1:1455/auth/callback');
      final attempt = LlmOAuthAuthorizationAttempt.openAiChatGpt(
        redirectUri: redirect,
        hostId: 'urn:uuid:host',
      );

      final callback = attempt.consumeCallback(
        redirect.replace(
          queryParameters: {
            'code': 'opaque#code-suffix',
            'state': attempt.state,
            'client_id': 'oaiapp_registered-client',
          },
        ),
      );

      expect(callback.code, 'opaque#code-suffix');
    });

    test(
      'keeps Gemini Developer API OAuth separate from API keys and Code Assist',
      () {
        final attempt = LlmOAuthAuthorizationAttempt.geminiDeveloperApi(
          redirectUri: Uri.parse('http://127.0.0.1:49661'),
          clientId: 'configured-desktop-client.apps.googleusercontent.com',
        );

        expect(attempt.authorizationUri.host, 'accounts.google.com');
        expect(attempt.authorizationUri.path, '/o/oauth2/v2/auth');
        expect(
          attempt.authorizationUri.queryParameters['redirect_uri'],
          'http://127.0.0.1:49661',
        );
        expect(
          attempt.authorizationUri.queryParameters['client_id'],
          'configured-desktop-client.apps.googleusercontent.com',
        );
        expect(
          attempt.authorizationUri.queryParameters['scope']!.split(' '),
          contains('https://www.googleapis.com/auth/cloud-platform'),
        );
        expect(
          attempt.authorizationUri.queryParameters['access_type'],
          'offline',
        );
        expect(
          attempt.authorizationUri.queryParameters['code_challenge_method'],
          'S256',
        );
        expect(LlmOAuthProviderPolicy.forProvider('gemini').supported, isTrue);
        expect(
          LlmOAuthProviderPolicy.forProvider('aistudio').supported,
          isTrue,
        );
        expect(
          attempt
              .consumeCallback(
                Uri.parse('http://127.0.0.1:49661/').replace(
                  queryParameters: {
                    'code': 'gemini-code',
                    'state': attempt.state,
                  },
                ),
              )
              .code,
          'gemini-code',
        );
        expect(
          LlmOAuthProviderPolicy.forProvider('google-code-assist').supported,
          isFalse,
        );
        expect(
          LlmOAuthProviderPolicy.forProvider('antigravity').supported,
          isFalse,
        );
        expect(
          LlmOAuthProviderPolicy.forProvider('openrouter').supported,
          isFalse,
        );
      },
    );

    test('creates and validates the Claude Code OAuth PKCE flow', () {
      final redirect = Uri.parse('http://localhost:54545/callback');
      final attempt = LlmOAuthAuthorizationAttempt.claudeCode(
        redirectUri: redirect,
      );

      expect(attempt.authorizationUri.host, 'claude.ai');
      expect(attempt.authorizationUri.path, '/oauth/authorize');
      expect(
        attempt.authorizationUri.queryParameters['client_id'],
        '9d1c250a-e61b-44d9-88ed-5944d1962f5e',
      );
      expect(
        attempt.authorizationUri.queryParameters['redirect_uri'],
        redirect.toString(),
      );
      expect(attempt.authorizationUri.queryParameters['response_type'], 'code');
      expect(attempt.authorizationUri.queryParameters['code'], 'true');
      expect(
        attempt.authorizationUri.queryParameters['scope']!.split(' '),
        containsAll([
          'user:profile',
          'user:inference',
          'user:sessions:claude_code',
        ]),
      );
      expect(
        attempt.authorizationUri.queryParameters['code_challenge_method'],
        'S256',
      );
      expect(
        attempt.authorizationUri.queryParameters['code_challenge'],
        isNot(attempt.codeVerifier),
      );

      final callback = attempt.consumeCallback(
        redirect.replace(
          queryParameters: {'code': 'claude-code', 'state': attempt.state},
        ),
      );
      expect(callback.code, 'claude-code');
      expect(callback.clientId, '9d1c250a-e61b-44d9-88ed-5944d1962f5e');
      expect(
        () => attempt.consumeCallback(
          redirect.replace(
            queryParameters: {'code': 'second-use', 'state': attempt.state},
          ),
        ),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      final fragmentAttempt = LlmOAuthAuthorizationAttempt.claudeCode(
        redirectUri: redirect,
      );
      expect(
        fragmentAttempt
            .consumeCallback(
              redirect.replace(
                queryParameters: {
                  'code': 'fragment-code#${fragmentAttempt.state}',
                  'state': fragmentAttempt.state,
                },
              ),
            )
            .code,
        'fragment-code',
      );
      expect(LlmOAuthProviderPolicy.forProvider('claude').supported, isTrue);
      expect(
        () => LlmOAuthAuthorizationAttempt.claudeCode(
          redirectUri: Uri.parse('http://127.0.0.1:49661/callback'),
        ),
        throwsA(isA<LlmOAuthFlowException>()),
      );
    });
  });

  test(
    'exchanges Claude Code PKCE credentials and keeps returned identity',
    () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'claude-access',
              'refresh_token': 'claude-refresh',
              'expires_in': 3600,
              'account': {
                'uuid': 'account-uuid',
                'email_address': 'a@example.test',
              },
              'organization': {'uuid': 'org-uuid', 'name': 'Example Org'},
            }),
            200,
          );
        });
      final attempt = LlmOAuthAuthorizationAttempt.claudeCode(
        redirectUri: Uri.parse('http://localhost:54545/callback'),
      );
      final callbackUri = attempt.redirectUri.replace(
        queryParameters: {'code': 'one-time-code', 'state': attempt.state},
      );
      final callback = attempt.consumeCallback(callbackUri);

      final bundle = await LlmOAuthTokenClient(
        dio: dio,
      ).exchangeClaudeCode(attempt: attempt, callback: callback);

      expect(
        captured?.uri.toString(),
        'https://platform.claude.com/v1/oauth/token',
      );
      expect(captured?.data, containsPair('grant_type', 'authorization_code'));
      expect(
        captured?.data,
        containsPair('code_verifier', attempt.codeVerifier),
      );
      expect(bundle['access_token'], 'claude-access');
      expect(bundle['refresh_token'], 'claude-refresh');
      expect(bundle['account_uuid'], 'account-uuid');
      expect(bundle['email'], 'a@example.test');
      expect(bundle['organization_uuid'], 'org-uuid');
      expect(bundle['organization_name'], 'Example Org');
    },
  );

  test(
    'rejects a ChatGPT token response without the direct-token scope',
    () async {
      final requestedPaths = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((options) async {
          requestedPaths.add(options.uri.path);
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'chatgpt-access',
              'refresh_token': 'chatgpt-refresh',
              'id_token': 'unverified-id-token',
              'scope': 'openid profile email offline_access',
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final attempt = LlmOAuthAuthorizationAttempt.openAiChatGpt(
        redirectUri: Uri.parse('http://127.0.0.1:49561/auth/callback'),
        hostId: 'urn:uuid:host',
      );
      final callback = attempt.consumeCallback(
        attempt.redirectUri.replace(
          queryParameters: {
            'code': 'single-use-chatgpt-code',
            'state': attempt.state,
            'client_id': 'registered-openai-client',
          },
        ),
      );

      await expectLater(
        LlmOAuthTokenClient(
          dio: dio,
        ).exchangeOpenAiChatGpt(attempt: attempt, callback: callback),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      expect(requestedPaths, [
        Uri.parse(LlmOAuthAuthorizationAttempt.openAiTokenEndpoint).path,
      ]);
    },
  );

  test(
    'rejects a ChatGPT ID token whose signature cannot be verified',
    () async {
      final requestedPaths = <String>[];
      final header = base64Url
          .encode(
            utf8.encode(jsonEncode({'alg': 'RS256', 'kid': 'signing-key'})),
          )
          .replaceAll('=', '');
      final claims = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'iss': LlmOAuthAuthorizationAttempt.openAiIssuer,
                'aud': 'registered-openai-client',
                'exp': DateTime.now()
                        .toUtc()
                        .add(const Duration(minutes: 5))
                        .millisecondsSinceEpoch ~/
                    1000,
                'nonce': 'will-be-replaced',
              }),
            ),
          )
          .replaceAll('=', '');
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((options) async {
          requestedPaths.add(options.uri.path);
          final response = switch (options.uri.path) {
            '/api/accounts/oauth/token' => {
                'access_token': 'chatgpt-access',
                'refresh_token': 'chatgpt-refresh',
                'id_token': '$header.$claims.invalid-signature',
                'scope': 'openid chatgpt.tokens.use.direct',
              },
            '/.well-known/openid-configuration' => {
                'issuer': LlmOAuthAuthorizationAttempt.openAiIssuer,
                'jwks_uri': 'https://auth.openai.com/jwks',
              },
            '/jwks' => {'keys': []},
            _ => throw StateError('Unexpected OAuth endpoint.'),
          };
          return ResponseBody.fromString(
            jsonEncode(response),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final attempt = LlmOAuthAuthorizationAttempt.openAiChatGpt(
        redirectUri: Uri.parse('http://127.0.0.1:49560/auth/callback'),
        hostId: 'urn:uuid:host',
      );
      final callback = attempt.consumeCallback(
        attempt.redirectUri.replace(
          queryParameters: {
            'code': 'single-use-chatgpt-code',
            'state': attempt.state,
            'client_id': 'registered-openai-client',
          },
        ),
      );

      await expectLater(
        LlmOAuthTokenClient(
          dio: dio,
        ).exchangeOpenAiChatGpt(attempt: attempt, callback: callback),
        throwsA(isA<LlmOAuthFlowException>()),
      );
      expect(requestedPaths, contains('/jwks'));
    },
  );

  test(
    'stores the verified ChatGPT identity and rejects account takeover',
    () async {
      final generatedKey = JsonWebKey.generate('RS256', keyBitLength: 2048);
      const clientId = 'registered-openai-client';

      Future<Map<String, dynamic>> exchangeForSubject(
        String subject, {
        String? expectedSubject,
      }) async {
        final attempt = LlmOAuthAuthorizationAttempt.openAiChatGpt(
          redirectUri: Uri.parse('http://127.0.0.1:49560/auth/callback'),
          hostId: 'urn:uuid:host',
          existingClientId: clientId,
          idTokenHint: 'old-verified-id-token',
        );
        final claims = {
          'iss': LlmOAuthAuthorizationAttempt.openAiIssuer,
          'sub': subject,
          'aud': clientId,
          'exp': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch ~/
              1000,
          'nonce': attempt.nonce,
        };
        final privateKey = JsonWebKey.fromCryptoKeys(
          publicKey: generatedKey.cryptoKeyPair.publicKey,
          privateKey: generatedKey.cryptoKeyPair.privateKey,
          keyId: 'signing-key',
        );
        final idToken = (JsonWebSignatureBuilder()
              ..jsonContent = claims
              ..setProtectedHeader('typ', 'JWT')
              ..setProtectedHeader('kid', 'signing-key')
              ..addRecipient(privateKey, algorithm: 'RS256'))
            .build()
            .toCompactSerialization();
        final publicKey = JsonWebKey.fromCryptoKeys(
          publicKey: generatedKey.cryptoKeyPair.publicKey,
          keyId: 'signing-key',
        );
        final dio = Dio()
          ..httpClientAdapter = _OAuthAdapter((options) async {
            final response = switch (options.uri.path) {
              '/api/accounts/oauth/token' => {
                  'access_token': 'chatgpt-access',
                  'refresh_token': 'chatgpt-refresh',
                  'id_token': idToken,
                  'scope': 'openid chatgpt.tokens.use.direct',
                },
              '/.well-known/openid-configuration' => {
                  'issuer': LlmOAuthAuthorizationAttempt.openAiIssuer,
                  'jwks_uri': 'https://auth.openai.com/jwks',
                },
              '/jwks' => {
                  'keys': [publicKey.toJson()],
                },
              _ => throw StateError('Unexpected OAuth endpoint.'),
            };
            return ResponseBody.fromString(
              jsonEncode(response),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final callback = attempt.consumeCallback(
          attempt.redirectUri.replace(
            queryParameters: {
              'code': 'single-use-chatgpt-code',
              'state': attempt.state,
            },
          ),
        );
        return LlmOAuthTokenClient(dio: dio).exchangeOpenAiChatGpt(
          attempt: attempt,
          callback: callback,
          expectedSubject: expectedSubject,
        );
      }

      final bundle = await exchangeForSubject('chatgpt-user-1');
      expect(bundle['id_token'], isA<String>());
      expect(bundle['identity_sub'], 'chatgpt-user-1');
      await expectLater(
        exchangeForSubject('chatgpt-user-2', expectedSubject: 'chatgpt-user-1'),
        throwsA(isA<LlmOAuthFlowException>()),
      );
    },
  );

  test(
    'exchanges Gemini OAuth code using the configured Desktop client',
    () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'gemini-access',
              'refresh_token': 'gemini-refresh',
              'expires_in': 3600,
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final attempt = LlmOAuthAuthorizationAttempt.geminiDeveloperApi(
        redirectUri: Uri.parse('http://127.0.0.1:49564'),
        clientId: 'desktop-client.apps.googleusercontent.com',
      );
      final callback = attempt.consumeCallback(
        attempt.redirectUri.replace(
          queryParameters: {'code': 'google-code', 'state': attempt.state},
        ),
      );

      final bundle =
          await LlmOAuthTokenClient(dio: dio).exchangeGeminiDeveloperApi(
        attempt: attempt,
        callback: callback,
        clientSecret: 'desktop-client-secret',
      );

      expect(captured?.uri.toString(), 'https://oauth2.googleapis.com/token');
      expect(captured?.data.toString(), contains('desktop-client-secret'));
      expect(bundle['access_token'], 'gemini-access');
      expect(bundle['refresh_token'], 'gemini-refresh');
      expect(bundle['client_id'], 'desktop-client.apps.googleusercontent.com');
      expect(bundle['client_secret'], 'desktop-client-secret');
      expect(bundle['oauth_contract'], 'google-gemini-developer-api-v1');
    },
  );
}

class _OAuthAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  _OAuthAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onFetch(options);

  @override
  void close({bool force = false}) {}
}
