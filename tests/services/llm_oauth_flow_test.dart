import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jose/jose.dart';
import 'package:stroom/services/llm_oauth_flow.dart';
import 'package:stroom/services/llm_oauth_token_client.dart';

void main() {
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
        () =>
            LlmOAuthAuthorizationAttempt.openAiChatGpt(
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
  });

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
                'exp':
                    DateTime.now()
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
          'exp':
              DateTime.now()
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
        final idToken =
            (JsonWebSignatureBuilder()
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

      final bundle = await LlmOAuthTokenClient(dio: dio)
          .exchangeGeminiDeveloperApi(
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
  ) => onFetch(options);

  @override
  void close({bool force = false}) {}
}
