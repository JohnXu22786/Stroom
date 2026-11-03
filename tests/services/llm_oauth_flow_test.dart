import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jose/jose.dart';
import 'package:stroom/services/llm_oauth_flow.dart';
import 'package:stroom/services/llm_oauth_token_client.dart';

void main() {
  test('Cursor deep-control OAuth keeps PKCE verifier off the login URL', () {
    final session = LlmCursorOAuthSession.create(
      now: DateTime.utc(2026, 11, 3),
      uuid: 'cursor-test-uuid',
      verifier: _cursorVerifier,
    );

    expect(session.authorizationUri.origin, 'https://cursor.com');
    expect(session.authorizationUri.path, '/loginDeepControl');
    expect(session.authorizationUri.queryParameters['challenge'], isNotEmpty);
    expect(
      session.authorizationUri.queryParameters['uuid'],
      'cursor-test-uuid',
    );
    expect(session.authorizationUri.queryParameters['mode'], 'login');
    expect(session.authorizationUri.queryParameters['redirectTarget'], 'cli');
    expect(
      session.authorizationUri.toString(),
      isNot(contains(session.verifier)),
    );
    expect(session.isExpired(DateTime.utc(2026, 11, 3, 0, 14, 59)), isFalse);
    expect(session.isExpired(DateTime.utc(2026, 11, 3, 0, 15)), isTrue);
  });

  test(
    'Cursor poll treats 404 as pending and validates the returned token pair',
    () async {
      var poll = 0;
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          expect(request.uri.origin, 'https://api2.cursor.sh');
          expect(request.uri.path, '/auth/poll');
          expect(request.uri.queryParameters['uuid'], 'poll-uuid');
          expect(request.uri.queryParameters['verifier'], _cursorVerifier);
          poll++;
          if (poll == 1) return ResponseBody.fromString('', 404);
          return ResponseBody.fromString(
            jsonEncode({
              'accessToken': 'cursor-access',
              'refreshToken': 'cursor-refresh',
            }),
            200,
          );
        });
      final session = LlmCursorOAuthSession.create(
        uuid: 'poll-uuid',
        verifier: _cursorVerifier,
      );
      final client = LlmOAuthTokenClient(dio: dio);

      expect(await client.pollCursorAuthorization(session), isNull);
      final bundle = await client.pollCursorAuthorization(session);
      expect(bundle?['access_token'], 'cursor-access');
      expect(bundle?['refresh_token'], 'cursor-refresh');
      expect(bundle?['oauth_contract'], 'cursor-deep-control-v1');
      expect(poll, 2);
    },
  );

  test(
    'Cursor refresh sends bearer refresh token and keeps it when not rotated',
    () async {
      RequestOptions? request;
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((options) async {
          request = options;
          return ResponseBody.fromString(
            jsonEncode({'accessToken': 'cursor-next-access'}),
            200,
          );
        });

      final bundle = await LlmOAuthTokenClient(
        dio: dio,
      ).refreshCursorAuthorization('cursor-refresh');

      expect(
        request?.uri.toString(),
        'https://api2.cursor.sh/auth/exchange_user_api_key',
      );
      expect(request?.method, 'POST');
      expect(request?.headers['Authorization'], 'Bearer cursor-refresh');
      expect(request?.data, isA<Map>());
      expect(bundle['access_token'], 'cursor-next-access');
      expect(bundle['refresh_token'], 'cursor-refresh');
    },
  );

  test('Cline WorkOS OAuth uses the extension callback contract', () {
    final redirectUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: 43127,
      path: LlmOAuthAuthorizationAttempt.newClineCallbackPath(),
    );
    final attempt = LlmOAuthAuthorizationAttempt.cline(
      redirectUri: redirectUri,
    );

    expect(attempt.authorizationUri.origin, 'https://api.cline.bot');
    expect(attempt.authorizationUri.path, '/api/v1/auth/authorize');
    expect(attempt.authorizationUri.queryParameters, {
      'client_type': 'extension',
      'callback_url': attempt.redirectUri.toString(),
      'redirect_uri': attempt.redirectUri.toString(),
    });
    expect(attempt.redirectUri.path, startsWith('/auth/callback/'));
    final callback = attempt.consumeCallback(
      attempt.redirectUri.replace(
        queryParameters: {'code': 'base64-workos-token'},
      ),
    );
    expect(callback.code, 'base64-workos-token');
    expect(callback.clientId, isNull);
    expect(
      () => LlmOAuthAuthorizationAttempt.cline(
        redirectUri: Uri.parse('http://127.0.0.1:43127/auth/callback'),
      ),
      throwsA(isA<LlmOAuthFlowException>()),
    );
    final freshAttempt = LlmOAuthAuthorizationAttempt.cline(
      redirectUri: Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: 43127,
        path: LlmOAuthAuthorizationAttempt.newClineCallbackPath(),
      ),
    );
    expect(
      () => freshAttempt.consumeCallback(
        Uri.parse('http://127.0.0.1:43127/auth/callback?code=forged-code'),
      ),
      throwsA(isA<LlmOAuthFlowException>()),
    );
    expect(
      () => attempt.consumeCallback(
        attempt.redirectUri.replace(
          queryParameters: {'code': 'base64-workos-token'},
        ),
      ),
      throwsA(isA<LlmOAuthFlowException>()),
    );
  });

  test(
    'Cline OAuth code can carry a base64 token bundle without a network call',
    () async {
      final token = base64Encode(
        utf8.encode(
          jsonEncode({
            'accessToken': 'cline-access-secret',
            'refreshToken': 'cline-refresh-secret',
            'email': 'cline@example.test',
            'firstName': 'Cline',
            'lastName': 'User',
            'expiresAt': '2026-11-04T12:00:00Z',
          }),
        ),
      );
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          fail('embedded token codes must not be exchanged over the network');
        });
      final attempt = LlmOAuthAuthorizationAttempt.cline(
        redirectUri: Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: 43127,
          path: LlmOAuthAuthorizationAttempt.newClineCallbackPath(),
        ),
      );
      final callback = attempt.consumeCallback(
        attempt.redirectUri.replace(queryParameters: {'code': token}),
      );

      final credentials = await LlmOAuthTokenClient(dio: dio).exchangeClineCode(
        attempt: attempt,
        callback: callback,
        provider: 'cline',
      );

      expect(credentials['access_token'], 'cline-access-secret');
      expect(credentials['refresh_token'], 'cline-refresh-secret');
      expect(credentials['email'], 'cline@example.test');
      expect(credentials['expires_at'], '2026-11-04T12:00:00Z');
      expect(jsonEncode(credentials), isNot(contains('workos:')));
    },
  );

  test(
    'Cline OAuth exchanges opaque authorization codes with extension fields',
    () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          captured = request;
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'accessToken': 'cline-access-secret',
                'refreshToken': 'cline-refresh-secret',
                'userInfo': {'email': 'cline@example.test'},
                'expiresAt': '2026-11-04T12:00:00Z',
              },
            }),
            200,
          );
        });
      final attempt = LlmOAuthAuthorizationAttempt.cline(
        redirectUri: Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: 43127,
          path: LlmOAuthAuthorizationAttempt.newClineCallbackPath(),
        ),
      );
      final callback = attempt.consumeCallback(
        attempt.redirectUri.replace(queryParameters: {'code': 'opaque-code'}),
      );

      final credentials = await LlmOAuthTokenClient(dio: dio).exchangeClineCode(
        attempt: attempt,
        callback: callback,
        provider: 'clinepass',
      );

      expect(
        captured?.uri.toString(),
        'https://api.cline.bot/api/v1/auth/token',
      );
      expect(captured?.method, 'POST');
      expect(captured?.contentType, Headers.jsonContentType);
      expect(captured?.data, {
        'grant_type': 'authorization_code',
        'code': 'opaque-code',
        'client_type': 'extension',
        'redirect_uri': attempt.redirectUri.toString(),
        'provider': 'clinepass',
      });
      expect(credentials['access_token'], 'cline-access-secret');
      expect(credentials['refresh_token'], 'cline-refresh-secret');
      expect(credentials['email'], 'cline@example.test');
    },
  );

  test('Openference OAuth uses the pinned PKCE loopback contract', () {
    final attempt = LlmOAuthAuthorizationAttempt.openference(
      redirectUri: Uri.parse('http://127.0.0.1:56123/callback'),
    );
    final uri = attempt.authorizationUri;

    expect(uri.origin, 'https://openference.com');
    expect(uri.path, '/app/oauth/authorize');
    expect(uri.queryParameters['client_id'], 'omniroute');
    expect(uri.queryParameters['response_type'], 'code');
    expect(uri.queryParameters['redirect_uri'], attempt.redirectUri.toString());
    expect(
      uri.queryParameters['scope'],
      'openid profile email model:invoke offline_access',
    );
    expect(uri.queryParameters['code_challenge_method'], 'S256');
    expect(uri.queryParameters['code_challenge'], isNotEmpty);
    expect(attempt.codeVerifier, isNotEmpty);

    final callback = attempt.consumeCallback(
      attempt.redirectUri.replace(
        queryParameters: {'code': 'openference-code', 'state': attempt.state},
      ),
    );
    expect(callback.code, 'openference-code');
    expect(callback.clientId, 'omniroute');
    expect(callback.scope, isNull);
  });

  test(
    'Openference OAuth exchanges PKCE code and stores rotated token fields',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          requests.add(request);
          expect(request.uri.toString(), 'https://openference.com/oauth/token');
          expect(request.method, 'POST');
          expect(request.contentType, Headers.formUrlEncodedContentType);
          final form = _requestForm(request.data);
          expect(form['grant_type'], 'authorization_code');
          expect(form['client_id'], 'omniroute');
          expect(form['code'], 'openference-code');
          expect(form['redirect_uri'], 'http://127.0.0.1:56123/callback');
          expect(form['code_verifier'], isNotEmpty);
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'oauth-access-secret',
              'refresh_token': 'oar-rotating-secret',
              'id_token': 'unverified-id-token',
              'expires_in': 3600,
            }),
            200,
          );
        });
      final attempt = LlmOAuthAuthorizationAttempt.openference(
        redirectUri: Uri.parse('http://127.0.0.1:56123/callback'),
      );
      final callback = attempt.consumeCallback(
        attempt.redirectUri.replace(
          queryParameters: {'code': 'openference-code', 'state': attempt.state},
        ),
      );

      final bundle = await LlmOAuthTokenClient(
        dio: dio,
      ).exchangeOpenferenceCode(attempt: attempt, callback: callback);

      expect(requests, hasLength(1));
      expect(bundle['access_token'], 'oauth-access-secret');
      expect(bundle['refresh_token'], 'oar-rotating-secret');
      expect(bundle['oauth_contract'], 'openference-pkce-v1');
      expect(
        bundle,
        isNot(contains('id_token')),
        reason:
            'unverified identity tokens must not be treated as verified account claims',
      );
    },
  );

  test(
    'Kilo Code device authorization uses its custom polling contract',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((options) async {
          requests.add(options);
          if (options.method == 'POST') {
            return ResponseBody.fromString(
              jsonEncode({
                'code': 'KILO-USER-CODE',
                'verificationUrl': 'https://app.kilo.ai/device-auth',
              }),
              200,
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'status': 'approved', 'token': 'kilo-access-token'}),
            200,
          );
        });
      final client = LlmOAuthTokenClient(dio: dio);

      final code = await client.startKiloDeviceAuthorization();
      final token = await client.pollKiloDeviceAuthorization(code);

      expect(requests.map((request) => request.uri.toString()), [
        'https://api.kilo.ai/api/device-auth/codes',
        'https://api.kilo.ai/api/device-auth/codes/KILO-USER-CODE',
      ]);
      expect(code.userCode, 'KILO-USER-CODE');
      expect(code.verificationUri.host, 'app.kilo.ai');
      expect(token['access_token'], 'kilo-access-token');
      expect(token, isNot(contains('refresh_token')));
      expect(requests.last.headers['Authorization'], isNull);
    },
  );

  test(
    'Kilo Code device authorization rejects an expired poll response',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter(
          (options) async => ResponseBody.fromString(
            jsonEncode({'error': 'expired_token'}),
            410,
          ),
        );

      await expectLater(
        LlmOAuthTokenClient(dio: dio).pollKiloDeviceAuthorization(
          LlmKiloDeviceCode.fromResponse(
            deviceCode: 'expired-device-code',
            userCode: 'expired-user-code',
            verificationUri: Uri.parse('https://app.kilo.ai/device-auth'),
            verificationUriComplete: Uri.parse(
              'https://app.kilo.ai/device-auth',
            ),
            interval: const Duration(seconds: 3),
          ),
        ),
        throwsA(isA<LlmOAuthFlowException>()),
      );
    },
  );
  test('Qoder browser OAuth is configurable and state-bound', () {
    expect(LlmOAuthProviderPolicy.forProvider('qoder').supported, isTrue);
    final attempt = LlmOAuthAuthorizationAttempt.qoder(
      redirectUri: Uri.parse('http://127.0.0.1:43127/auth/callback'),
      authorizeUrl: 'https://login.example.com/authorize',
      clientId: 'qoder-client-id',
    );
    expect(attempt.authorizationUri.host, 'login.example.com');
    expect(attempt.authorizationUri.path, '/authorize');
    expect(attempt.authorizationUri.queryParameters, {
      'loginMethod': 'phone',
      'type': 'phone',
      'redirect': attempt.redirectUri.toString(),
      'state': attempt.state,
      'client_id': 'qoder-client-id',
    });
    final callback = attempt.consumeCallback(
      Uri.parse(
        '${attempt.redirectUri}?code=authorization-code&state=${attempt.state}',
      ),
    );
    expect(callback.code, 'authorization-code');
    expect(callback.clientId, 'qoder-client-id');
    expect(
      () => LlmOAuthAuthorizationAttempt.qoder(
        redirectUri: Uri.parse('http://127.0.0.1:43127/auth/callback'),
        authorizeUrl: 'http://127.0.0.1:43127/authorize',
        clientId: 'qoder-client-id',
      ),
      throwsA(isA<LlmOAuthFlowException>()),
    );
    expect(
      () => LlmOAuthAuthorizationAttempt.qoder(
        redirectUri: Uri.parse('http://127.0.0.1:43127/auth/callback'),
        authorizeUrl: 'https://login.example.com/authorize',
        clientId: '',
      ),
      throwsA(isA<LlmOAuthFlowException>()),
    );
  });
  test(
    'Tencent device auth uses distinct hosts and stores only bearer tokens',
    () async {
      for (final (connector, host, platform) in [
        ('codebuddy-cn', 'copilot.tencent.com', 'CLI'),
        ('codebuddy-intl', 'www.codebuddy.ai', 'ide'),
        ('workbuddy', 'www.workbuddy.ai', 'CLI'),
      ]) {
        expect(LlmOAuthProviderPolicy.forProvider(connector).supported, isTrue);
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _OAuthAdapter((request) async {
            requests.add(request);
            if (request.uri.path.endsWith('/state')) {
              return ResponseBody.fromString(
                jsonEncode({
                  'code': 0,
                  'data': {
                    'state': 'device-state',
                    'authUrl': 'https://$host/device',
                  },
                }),
                200,
              );
            }
            return ResponseBody.fromString(
              jsonEncode({
                'code': 0,
                'data': {
                  'accessToken': 'account-access-token',
                  'refreshToken': 'account-refresh-token',
                  'expiresIn': 1800,
                },
              }),
              200,
            );
          });
        final client = LlmOAuthTokenClient(dio: dio);
        final challenge = await client.startTencentDeviceAuthorization(
          connectorType: connector,
        );
        expect(challenge.verificationUri.host, host);
        expect(requests.single.uri.queryParameters['platform'], platform);
        final bundle = await client.pollTencentDeviceAuthorization(
          connectorType: connector,
          deviceCode: challenge,
        );
        expect(requests.last.uri.host, host);
        expect(requests.last.uri.queryParameters['state'], 'device-state');
        expect(requests.last.headers['X-Product'], 'SaaS');
        expect(bundle['access_token'], 'account-access-token');
        expect(bundle['refresh_token'], 'account-refresh-token');
      }
    },
  );

  test('Tencent device polling stops promptly when cancelled', () async {
    final firstPollReturned = Completer<void>();
    var tokenRequests = 0;
    final dio = Dio()
      ..httpClientAdapter = _OAuthAdapter((request) async {
        if (request.uri.path.endsWith('/state')) {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 0,
              'data': {
                'state': 'device-state',
                'authUrl': 'https://copilot.tencent.com/device',
              },
            }),
            200,
          );
        }
        tokenRequests++;
        firstPollReturned.complete();
        return ResponseBody.fromString(jsonEncode({'code': 11217}), 200);
      });
    final client = LlmOAuthTokenClient(dio: dio);
    final deviceCode = await client.startTencentDeviceAuthorization(
      connectorType: 'codebuddy-cn',
    );
    final cancelToken = CancelToken();
    final polling = client.pollTencentDeviceAuthorization(
      connectorType: 'codebuddy-cn',
      deviceCode: deviceCode,
      cancelToken: cancelToken,
    );

    await firstPollReturned.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final stopwatch = Stopwatch()..start();
    cancelToken.cancel('User cancelled');

    await expectLater(polling, throwsA(isA<LlmOAuthFlowException>()));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(tokenRequests, 1);
  });

  test('Tencent device polling stops on a rejected token request', () async {
    var tokenRequests = 0;
    final dio = Dio()
      ..httpClientAdapter = _OAuthAdapter((request) async {
        if (request.uri.path.endsWith('/state')) {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 0,
              'data': {
                'state': 'device-state',
                'authUrl': 'https://copilot.tencent.com/device',
              },
            }),
            200,
          );
        }
        tokenRequests++;
        return ResponseBody.fromString('{}', 401);
      });
    final client = LlmOAuthTokenClient(dio: dio);
    final deviceCode = await client.startTencentDeviceAuthorization(
      connectorType: 'codebuddy-cn',
    );

    await expectLater(
      client.pollTencentDeviceAuthorization(
        connectorType: 'codebuddy-cn',
        deviceCode: deviceCode,
      ),
      throwsA(isA<LlmOAuthFlowException>()),
    );
    expect(tokenRequests, 1);
  });

  test(
    'Devin OAuth is separate and uses its pinned PKCE callback contract',
    () {
      expect(LlmOAuthProviderPolicy.forProvider('devin').supported, isTrue);
      expect(LlmOAuthProviderPolicy.forProvider('claude').supported, isTrue);
      expect(
        LlmOAuthProviderPolicy.forProvider('session_token').supported,
        isFalse,
      );

      final attempt = LlmOAuthAuthorizationAttempt.devin(
        redirectUri: Uri.parse('http://127.0.0.1:43127/callback'),
      );
      final authorization = attempt.authorizationUri;
      expect(authorization.origin, 'https://app.devin.ai');
      expect(authorization.path, '/auth/cli/continue');
      expect(
        authorization.queryParameters['redirect_uri'],
        attempt.redirectUri.toString(),
      );
      expect(authorization.queryParameters['prompt'], 'select_account');
      expect(authorization.queryParameters['code_challenge_method'], 'S256');
      expect(authorization.queryParameters['code_challenge'], isNotEmpty);
      expect(authorization.queryParameters['state'], attempt.state);
      expect(authorization.queryParameters, isNot(contains('client_id')));

      final callback = attempt.consumeCallback(
        Uri.parse(
          '${attempt.redirectUri}?code=fixture-code&state=${attempt.state}',
        ),
      );
      expect(callback.code, 'fixture-code');
      expect(callback.clientId, isNull);
      expect(
        () => attempt.consumeCallback(
          Uri.parse(
            '${attempt.redirectUri}?code=another&state=${attempt.state}',
          ),
        ),
        throwsA(isA<LlmOAuthFlowException>()),
      );
    },
  );

  test('Devin OAuth exchanges, verifies identity and checks plan status', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _OAuthAdapter((request) async {
        requests.add(request);
        if (request.uri.toString() == 'https://api.devin.ai/auth/cli/token') {
          return ResponseBody.fromString(
            '{"token":"eyJfixture-devin-token"}',
            200,
          );
        }
        if (request.uri.toString() == 'https://api.devin.ai/v3/self') {
          return ResponseBody.fromString(
            '{"user_id":"devin-user-1","user_name":"Dev User","org_id":"org-1"}',
            200,
          );
        }
        if (request.uri.toString() ==
            'https://server.codeium.com/exa.seat_management_pb.SeatManagementService/GetUserStatus') {
          return ResponseBody.fromBytes(
            _devinStatusResponse(userId: 'devin-user-1', plan: 'Team'),
            200,
          );
        }
        throw StateError('Unexpected Devin OAuth request');
      });
    final attempt = LlmOAuthAuthorizationAttempt.devin(
      redirectUri: Uri.parse('http://127.0.0.1:43127/callback'),
    );
    final callback = attempt.consumeCallback(
      Uri.parse(
        '${attempt.redirectUri}?code=fixture-code&state=${attempt.state}',
      ),
    );

    final bundle = await LlmOAuthTokenClient(dio: dio).exchangeDevinCode(
      attempt: attempt,
      callback: callback,
      accountId: 'devin-account-1',
    );

    expect(
      bundle['session_token'],
      r'devin-session-token$eyJfixture-devin-token',
    );
    expect(bundle['user_id'], 'devin-user-1');
    expect(bundle['user_name'], 'Dev User');
    expect(bundle['org_id'], 'org-1');
    expect(bundle['plan'], 'Team');
    expect(bundle['oauth_contract'], 'devin-pkce-v1');
    expect(requests[0].method, 'POST');
    expect(requests[0].contentType, Headers.jsonContentType);
    expect(requests[0].data, {
      'code': 'fixture-code',
      'code_verifier': attempt.codeVerifier,
    });
    expect(requests[0].data, isNot(contains('client_id')));
    expect(
      requests[1].headers['Authorization'],
      r'Bearer devin-session-token$eyJfixture-devin-token',
    );
    expect(requests[2].uri.host, 'server.codeium.com');
    expect(
      requests[2].headers['Authorization'],
      r'Basic devin-session-token$eyJfixture-devin-token-devin-session-token$eyJfixture-devin-token',
    );
    expect(requests[2].headers['Connect-Protocol-Version'], '1');
    expect(requests[2].headers['Content-Type'], 'application/proto');
    expect(requests.toString(), isNot(contains('fixture-devin-token')));
  });

  test(
    'Devin OAuth rejects identity mismatches and accounts without plan status',
    () async {
      final attempt = LlmOAuthAuthorizationAttempt.devin(
        redirectUri: Uri.parse('http://127.0.0.1:43127/callback'),
      );
      final callback = attempt.consumeCallback(
        Uri.parse(
          '${attempt.redirectUri}?code=fixture-code&state=${attempt.state}',
        ),
      );

      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((request) async {
          if (request.uri.path == '/auth/cli/token') {
            return ResponseBody.fromString('{"token":"fixture-token"}', 200);
          }
          if (request.uri.path == '/v3/self') {
            return ResponseBody.fromString('{"user_id":"profile-user"}', 200);
          }
          return ResponseBody.fromBytes(
            _devinStatusResponse(userId: 'different-user', plan: ''),
            200,
          );
        });

      await expectLater(
        LlmOAuthTokenClient(dio: dio).exchangeDevinCode(
          attempt: attempt,
          callback: callback,
          accountId: 'devin-account-2',
        ),
        throwsA(isA<LlmOAuthFlowException>()),
      );
    },
  );

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
        'exp':
            DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
      };
      final validIdToken =
          (JsonWebSignatureBuilder()
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
      final nullAzpToken =
          (JsonWebSignatureBuilder()
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
      final conflictingAzpToken =
          (JsonWebSignatureBuilder()
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
  test(
    'Qoder OAuth exchanges configured endpoints and returns a DashScope key',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((options) async {
          requests.add(options);
          final response = options.uri.path == '/token'
              ? {
                  'access_token': 'qoder-access',
                  'refresh_token': 'qoder-refresh',
                }
              : {
                  'success': true,
                  'data': {
                    'apiKey': 'dashscope-account-key',
                    'email': 'qoder@example.test',
                    'nickname': 'Qoder User',
                  },
                };
          return ResponseBody.fromString(
            jsonEncode(response),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final attempt = LlmOAuthAuthorizationAttempt.qoder(
        redirectUri: Uri.parse('http://127.0.0.1:43127/auth/callback'),
        authorizeUrl: 'https://login.example.test/authorize',
        clientId: 'qoder-client',
      );
      final callback = attempt.consumeCallback(
        attempt.redirectUri.replace(
          queryParameters: {'code': 'qoder-code', 'state': attempt.state},
        ),
      );
      final bundle = await LlmOAuthTokenClient(dio: dio).exchangeQoderCode(
        attempt: attempt,
        callback: callback,
        configuration: const {
          'authorizeUrl': 'https://login.example.test/authorize',
          'tokenUrl': 'https://login.example.test/token',
          'userInfoUrl': 'https://login.example.test/user',
          'clientId': 'qoder-client',
          'clientSecret': 'qoder-client-secret',
        },
      );
      expect(requests, hasLength(2));
      expect(requests.first.uri.path, '/token');
      expect(
        (requests.first.data as Map)['client_secret'],
        'qoder-client-secret',
      );
      expect(requests.first.headers['Authorization'], startsWith('Basic '));
      expect(requests.last.uri.queryParameters['accessToken'], 'qoder-access');
      expect(bundle['api_key'], 'dashscope-account-key');
      expect(bundle['client_secret'], 'qoder-client-secret');
      expect(bundle['oauth_contract'], 'qoder-admin-code-v1');
      expect(bundle['display_name'], 'Qoder User');
    },
  );

  test(
    'Qoder OAuth accepts an access-token-only authorization response',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _OAuthAdapter((options) async {
          final response = options.uri.path == '/token'
              ? {'access_token': 'qoder-access'}
              : {
                  'success': true,
                  'data': {'apiKey': 'dashscope-account-key'},
                };
          return ResponseBody.fromString(
            jsonEncode(response),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final attempt = LlmOAuthAuthorizationAttempt.qoder(
        redirectUri: Uri.parse('http://127.0.0.1:43127/auth/callback'),
        authorizeUrl: 'https://login.example.test/authorize',
        clientId: 'qoder-client',
      );
      final callback = attempt.consumeCallback(
        attempt.redirectUri.replace(
          queryParameters: {'code': 'qoder-code', 'state': attempt.state},
        ),
      );

      final bundle = await LlmOAuthTokenClient(dio: dio).exchangeQoderCode(
        attempt: attempt,
        callback: callback,
        configuration: const {
          'authorizeUrl': 'https://login.example.test/authorize',
          'tokenUrl': 'https://login.example.test/token',
          'userInfoUrl': 'https://login.example.test/user',
          'clientId': 'qoder-client',
          'clientSecret': 'qoder-client-secret',
        },
      );

      expect(bundle['access_token'], 'qoder-access');
      expect(bundle, isNot(contains('refresh_token')));
      expect(bundle['api_key'], 'dashscope-account-key');
    },
  );
}

Map<String, String> _requestForm(Object? body) {
  if (body is Map) return body.map((key, value) => MapEntry('$key', '$value'));
  if (body is String) return Uri.splitQueryString(body);
  throw StateError('Expected an encoded form body.');
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

Uint8List _devinStatusResponse({required String userId, required String plan}) {
  final status = <int>[..._protoBytes(36, utf8.encode(userId))];
  if (plan.isNotEmpty) {
    final planInfo = _protoBytes(2, utf8.encode(plan));
    status.addAll(_protoBytes(13, _protoBytes(1, planInfo)));
  }
  return Uint8List.fromList(_protoBytes(1, status));
}

final _cursorVerifier = List.filled(43, 'v').join();

List<int> _protoBytes(int field, List<int> bytes) => [
  ..._protoVarint((field << 3) | 2),
  ..._protoVarint(bytes.length),
  ...bytes,
];

List<int> _protoVarint(int value) {
  final bytes = <int>[];
  while (value >= 0x80) {
    bytes.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  bytes.add(value);
  return bytes;
}
