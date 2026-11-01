import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jose/jose.dart';

import 'llm_oauth_flow.dart';

/// Exchanges one-use authorization codes and verifies provider identity data.
/// Token values are returned only to the caller for immediate secure storage.
class LlmOAuthTokenClient {
  static const _openAiDiscoveryUri =
      'https://auth.openai.com/.well-known/openid-configuration';
  static const xaiClientId = 'b1a00492-073a-47ea-816f-4c329264a828';
  static const xaiIssuer = 'https://auth.x.ai';
  static const _xaiDiscoveryUri =
      'https://auth.x.ai/.well-known/openid-configuration';
  static const _xaiCommonScopes = 'openid profile email offline_access';

  final Dio _dio;

  LlmOAuthTokenClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  Future<Map<String, dynamic>> exchangeOpenAiChatGpt({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
    String? expectedSubject,
  }) async {
    try {
      final response = await _dio.postUri<Object?>(
        Uri.parse(LlmOAuthAuthorizationAttempt.openAiTokenEndpoint),
        data: {
          'grant_type': 'authorization_code',
          'client_id': callback.clientId,
          'code': callback.code,
          'redirect_uri': attempt.redirectUri.toString(),
          'code_verifier': attempt.codeVerifier,
          'resource': LlmOAuthAuthorizationAttempt.openAiResource,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
      final token = _jsonObject(response.data);
      final accessToken = _nonEmptyString(token['access_token']);
      final refreshToken = _nonEmptyString(token['refresh_token']);
      final idToken = _nonEmptyString(token['id_token']);
      final grantedScope = _nonEmptyString(token['scope']);
      if (accessToken == null ||
          refreshToken == null ||
          idToken == null ||
          grantedScope == null ||
          !_scopeContains(grantedScope, 'chatgpt.tokens.use.direct')) {
        throw const LlmOAuthFlowException();
      }
      final identity = await _verifyOpenAiIdentity(
        idToken: idToken,
        clientId: callback.clientId,
        expectedNonce: attempt.nonce,
      );
      final subject = _nonEmptyString(identity['sub']);
      if (subject == null ||
          (expectedSubject != null && subject != expectedSubject)) {
        throw const LlmOAuthFlowException();
      }
      return _credentialBundle(token)
        ..['client_id'] = callback.clientId
        ..['id_token'] = idToken
        ..['identity_sub'] = subject
        ..['resource'] = LlmOAuthAuthorizationAttempt.openAiResource
        ..['scope'] = grantedScope
        ..['oauth_contract'] = 'openai-siwc-v1';
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<Map<String, dynamic>> exchangeGeminiDeveloperApi({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
    required String clientSecret,
  }) async {
    try {
      final secret = clientSecret.trim();
      if (secret.isEmpty) throw const LlmOAuthFlowException();
      final response = await _dio.postUri<Object?>(
        Uri.parse(LlmOAuthAuthorizationAttempt.geminiTokenEndpoint),
        data: {
          'grant_type': 'authorization_code',
          'client_id': callback.clientId,
          'client_secret': secret,
          'code': callback.code,
          'redirect_uri': attempt.redirectUri.toString(),
          'code_verifier': attempt.codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
      final token = _jsonObject(response.data);
      final accessToken = _nonEmptyString(token['access_token']);
      final refreshToken = _nonEmptyString(token['refresh_token']);
      if (accessToken == null || refreshToken == null) {
        throw const LlmOAuthFlowException();
      }
      return _credentialBundle(token)
        ..['client_id'] = callback.clientId
        ..['client_secret'] = secret
        ..['oauth_contract'] = 'google-gemini-developer-api-v1';
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<Map<String, dynamic>> exchangeClaudeCode({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
  }) async {
    try {
      if (callback.clientId !=
          LlmOAuthAuthorizationAttempt.claudeCodeClientId) {
        throw const LlmOAuthFlowException();
      }
      final response = await _dio.postUri<Object?>(
        Uri.parse(LlmOAuthAuthorizationAttempt.claudeCodeTokenEndpoint),
        data: {
          'grant_type': 'authorization_code',
          'code': callback.code,
          'redirect_uri': attempt.redirectUri.toString(),
          'client_id': callback.clientId,
          'code_verifier': attempt.codeVerifier,
          'state': attempt.state,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          headers: const {
            'Accept': 'application/json, text/plain, */*',
            'User-Agent': 'axios/1.15.2',
            'Cache-Control': 'no-cache',
          },
        ),
      );
      final token = _jsonObject(response.data);
      final bundle = _credentialBundle(token)
        ..['oauth_contract'] = 'anthropic-claude-code-v1'
        ..['scope'] = LlmOAuthAuthorizationAttempt.claudeCodeScope;
      final account = token['account'];
      if (account is Map) {
        final accountId = _nonEmptyString(account['uuid']);
        final email = _nonEmptyString(account['email_address']);
        if (accountId != null) bundle['account_uuid'] = accountId;
        if (email != null) bundle['email'] = email;
      }
      final organization = token['organization'];
      if (organization is Map) {
        final organizationId = _nonEmptyString(organization['uuid']);
        final organizationName = _nonEmptyString(organization['name']);
        if (organizationId != null) {
          bundle['organization_uuid'] = organizationId;
        }
        if (organizationName != null) {
          bundle['organization_name'] = organizationName;
        }
      }
      return bundle;
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<LlmKimiDeviceCode> startKimiDeviceAuthorization({
    required String deviceId,
  }) async {
    try {
      final id = deviceId.trim();
      if (id.isEmpty) throw const LlmOAuthFlowException();
      final response = await _dio.postUri<Object?>(
        Uri.parse('https://auth.kimi.com/api/oauth/device_authorization'),
        data: {'client_id': LlmOAuthAuthorizationAttempt.kimiCodeClientId},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          headers: _kimiDeviceHeaders(id),
        ),
      );
      final data = _jsonObject(response.data);
      final deviceCode = _nonEmptyString(data['device_code']);
      final userCode = _nonEmptyString(data['user_code']);
      final verification = _kimiVerificationUri(
        data['verification_uri'] ?? data['verification_url'],
      );
      final complete = _kimiVerificationUri(
            data['verification_uri_complete'] ??
                data['verification_url_complete'],
          ) ??
          verification;
      if (deviceCode == null ||
          userCode == null ||
          verification == null ||
          complete == null) {
        throw const LlmOAuthFlowException();
      }
      final expiresIn = _seconds(data['expires_in']);
      final interval = _seconds(data['interval']);
      if (expiresIn <= 0) throw const LlmOAuthFlowException();
      return LlmKimiDeviceCode.fromOAuthResponse(
        deviceCode: deviceCode,
        userCode: userCode,
        verificationUri: verification,
        verificationUriComplete: complete,
        expiresIn: Duration(seconds: expiresIn),
        interval: Duration(seconds: interval > 0 ? interval : 5),
      );
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<Map<String, dynamic>> pollKimiDeviceAuthorization({
    required LlmKimiDeviceCode deviceCode,
    required String deviceId,
    CancelToken? cancelToken,
  }) async {
    try {
      final id = deviceId.trim();
      if (id.isEmpty || deviceCode.deviceCode.isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final deadline = DateTime.now().add(deviceCode.expiresIn);
      var interval = deviceCode.interval < const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : deviceCode.interval;
      final firstPollDelay = deadline.difference(DateTime.now());
      if (firstPollDelay > Duration.zero) {
        await _waitForKimiPollingInterval(
          interval > firstPollDelay ? firstPollDelay : interval,
          cancelToken,
        );
      }
      while (DateTime.now().isBefore(deadline)) {
        if (cancelToken?.isCancelled ?? false) {
          throw cancelToken!.cancelError!;
        }
        final response = await _dio.postUri<Object?>(
          Uri.parse('https://auth.kimi.com/api/oauth/token'),
          data: {
            'client_id': LlmOAuthAuthorizationAttempt.kimiCodeClientId,
            'device_code': deviceCode.deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.json,
            headers: _kimiDeviceHeaders(id),
          ),
          cancelToken: cancelToken,
        );
        final token = _jsonObject(response.data);
        final error = _nonEmptyString(token['error']);
        if (error == 'authorization_pending' || error == 'slow_down') {
          if (error == 'slow_down') interval += const Duration(seconds: 5);
          final remaining = deadline.difference(DateTime.now());
          if (remaining <= Duration.zero) break;
          await _waitForKimiPollingInterval(
            interval > remaining ? remaining : interval,
            cancelToken,
          );
          continue;
        }
        if (error != null) throw const LlmOAuthFlowException();
        final accessToken = _nonEmptyString(token['access_token']);
        final refreshToken = _nonEmptyString(token['refresh_token']);
        if (accessToken == null || refreshToken == null) {
          throw const LlmOAuthFlowException();
        }
        return _credentialBundle(token)
          ..['device_id'] = id
          ..['client_id'] = LlmOAuthAuthorizationAttempt.kimiCodeClientId
          ..['oauth_contract'] = 'kimi-code-device-v1';
      }
      throw const LlmOAuthFlowException();
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<LlmXaiDeviceCode> startXaiDeviceAuthorization({
    required String connectorType,
  }) async {
    try {
      final providerScope = switch (connectorType) {
        'grok-cli' => 'grok-cli:access',
        'xai-oauth' => 'api:access',
        _ => throw const LlmOAuthFlowException(),
      };
      final discoveryResponse = await _dio.getUri<Object?>(
        Uri.parse(_xaiDiscoveryUri),
        options: Options(responseType: ResponseType.json),
      );
      final discovery = _jsonObject(discoveryResponse.data);
      if (_nonEmptyString(discovery['issuer']) != xaiIssuer) {
        throw const LlmOAuthFlowException();
      }
      final signingAlgorithms =
          discovery['id_token_signing_alg_values_supported'];
      if (signingAlgorithms is! Iterable ||
          !signingAlgorithms.contains('ES256')) {
        throw const LlmOAuthFlowException();
      }
      final deviceEndpoint =
          _xaiEndpoint(discovery['device_authorization_endpoint']);
      final tokenEndpoint = _xaiEndpoint(discovery['token_endpoint']);
      final jwksUri = _xaiJwksUri(discovery['jwks_uri']);
      final scope = '$_xaiCommonScopes $providerScope';
      final response = await _dio.postUri<Object?>(
        deviceEndpoint,
        data: {'client_id': xaiClientId, 'scope': scope},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
      final data = _jsonObject(response.data);
      final deviceCode = _nonEmptyString(data['device_code']);
      final userCode = _nonEmptyString(data['user_code']);
      final verification = _xaiVerificationUri(data['verification_uri']);
      final complete = _xaiVerificationUri(data['verification_uri_complete']) ??
          verification;
      final expiresIn = _seconds(data['expires_in']);
      final interval = _seconds(data['interval']);
      if (deviceCode == null ||
          userCode == null ||
          verification == null ||
          complete == null ||
          expiresIn <= 0) {
        throw const LlmOAuthFlowException();
      }
      return LlmXaiDeviceCode.fromOAuthResponse(
        deviceCode: deviceCode,
        tokenEndpoint: tokenEndpoint.toString(),
        issuer: xaiIssuer,
        jwksUri: jwksUri,
        scope: scope,
        userCode: userCode,
        verificationUri: verification,
        verificationUriComplete: complete,
        expiresIn: Duration(seconds: expiresIn),
        interval: Duration(seconds: interval > 0 ? interval : 5),
      );
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<Map<String, dynamic>> pollXaiDeviceAuthorization({
    required LlmXaiDeviceCode deviceCode,
    String? expectedSubject,
    CancelToken? cancelToken,
  }) async {
    try {
      if (deviceCode.deviceCode.isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final tokenEndpoint = _xaiEndpoint(deviceCode.tokenEndpoint);
      final deadline = DateTime.now().add(deviceCode.expiresIn);
      var interval = deviceCode.interval < const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : deviceCode.interval;
      var firstPoll = true;
      while (DateTime.now().isBefore(deadline)) {
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
        if (!firstPoll) {
          final remaining = deadline.difference(DateTime.now());
          if (remaining <= Duration.zero) break;
          await _waitForXaiPollingInterval(
            interval > remaining ? remaining : interval,
            cancelToken,
          );
        }
        firstPoll = false;
        final response = await _dio.postUri<Object?>(
          tokenEndpoint,
          data: {
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'device_code': deviceCode.deviceCode,
            'client_id': xaiClientId,
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.json,
            validateStatus: (status) => status != null,
          ),
          cancelToken: cancelToken,
        );
        final token = _jsonObject(response.data);
        final error = _nonEmptyString(token['error']);
        if (error == 'authorization_pending') continue;
        if (error == 'slow_down') {
          interval += const Duration(seconds: 5);
          continue;
        }
        if (error != null || (response.statusCode ?? 0) != 200) {
          throw const LlmOAuthFlowException();
        }
        final accessToken = _nonEmptyString(token['access_token']);
        final refreshToken = _nonEmptyString(token['refresh_token']);
        final idToken = _nonEmptyString(token['id_token']);
        if (accessToken == null || refreshToken == null || idToken == null) {
          throw const LlmOAuthFlowException();
        }
        final grantedScope = _nonEmptyString(token['scope']);
        if (grantedScope != null) {
          final grantedScopes = grantedScope.split(RegExp(r'\s+')).toSet();
          final requestedModeScope = deviceCode.scope.split(' ').last;
          final otherModeScope = requestedModeScope == 'grok-cli:access'
              ? 'api:access'
              : 'grok-cli:access';
          if (!grantedScopes.contains(requestedModeScope) ||
              grantedScopes.contains(otherModeScope)) {
            throw const LlmOAuthFlowException();
          }
        }
        final identity = await _verifyXaiIdentity(
          idToken: idToken,
          jwksUri: deviceCode.jwksUri,
          issuer: deviceCode.issuer,
          clientId: xaiClientId,
        );
        final subject = _nonEmptyString(identity['sub']);
        if (subject == null ||
            (expectedSubject != null && subject != expectedSubject)) {
          throw const LlmOAuthFlowException();
        }
        final bundle = _credentialBundle(token)
          ..['client_id'] = xaiClientId
          ..['token_endpoint'] = tokenEndpoint.toString()
          ..['id_token'] = idToken
          ..['identity_sub'] = subject
          // OAuth omits the response scope when it matches the request. The
          // pinned xAI device response also omits it, so retain the requested
          // mode scope in that case.
          ..['scope'] = grantedScope ?? deviceCode.scope
          ..['oauth_contract'] = 'xai-device-v1';
        if (identity['email_verified'] == true) {
          final email = _nonEmptyString(identity['email']);
          if (email != null) bundle['identity_email'] = email;
        }
        return bundle;
      }
      throw const LlmOAuthFlowException();
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  static Map<String, String> _kimiDeviceHeaders(String deviceId) => {
        'X-Msh-Platform': 'CLIProxyAPI',
        'X-Msh-Version': 'stroom',
        'X-Msh-Device-Name': 'Stroom',
        'X-Msh-Device-Model': 'Stroom',
        'X-Msh-Device-Id': deviceId,
      };

  static Future<void> _waitForXaiPollingInterval(
    Duration interval,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      await Future<void>.delayed(interval);
      return;
    }
    await Future.any<void>([
      Future<void>.delayed(interval),
      cancelToken.whenCancel.then<void>(
        (_) => throw const LlmOAuthFlowException(),
      ),
    ]);
  }

  static Uri _xaiEndpoint(Object? value) {
    final uri = Uri.tryParse(value is String ? value.trim() : '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host != 'auth.x.ai' && !uri.host.endsWith('.auth.x.ai') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const LlmOAuthFlowException();
    }
    return uri;
  }

  static Uri? _xaiVerificationUri(Object? value) {
    final uri = Uri.tryParse(value is String ? value.trim() : '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host != 'x.ai' &&
            !uri.host.endsWith('.x.ai') &&
            uri.host != 'x.com' &&
            !uri.host.endsWith('.x.com')) {
      return null;
    }
    return uri;
  }

  static Uri _xaiJwksUri(Object? value) {
    final uri = Uri.tryParse(value is String ? value.trim() : '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host != 'auth.x.ai' ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const LlmOAuthFlowException();
    }
    return uri;
  }

  Future<Map<String, dynamic>> _verifyXaiIdentity({
    required String idToken,
    required Uri jwksUri,
    required String issuer,
    required String clientId,
  }) async {
    final segments = idToken.split('.');
    if (segments.length != 3) throw const LlmOAuthFlowException();
    final header = _jsonObject(
      utf8.decode(base64Url.decode(base64Url.normalize(segments.first))),
    );
    if (header['alg'] != 'ES256' ||
        header['kid'] is! String ||
        (header['kid'] as String).isEmpty) {
      throw const LlmOAuthFlowException();
    }
    final jwksResponse = await _dio.getUri<Object?>(
      jwksUri,
      options: Options(responseType: ResponseType.json),
    );
    final keySet = JsonWebKeySet.fromJson(_jsonObject(jwksResponse.data));
    final token = await JsonWebToken.decodeAndVerify(
      idToken,
      JsonWebKeyStore()..addKeySet(keySet),
    );
    final claims = token.claims;
    final claimsJson = claims.toJson();
    final audience = claims.audience ?? const <String>[];
    final expiry = claims.expiry;
    if (claims.issuer?.toString() != issuer ||
        !audience.contains(clientId) ||
        (audience.length > 1 && claimsJson['azp'] != clientId) ||
        expiry == null ||
        !expiry.isAfter(DateTime.now().toUtc())) {
      throw const LlmOAuthFlowException();
    }
    return claimsJson;
  }

  static Future<void> _waitForKimiPollingInterval(
    Duration interval,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      await Future<void>.delayed(interval);
      return;
    }
    await Future.any<void>([
      Future<void>.delayed(interval),
      cancelToken.whenCancel.then<void>(
        (_) => throw const LlmOAuthFlowException(),
      ),
    ]);
  }

  static Uri? _kimiVerificationUri(Object? value) {
    final uri = Uri.tryParse(value is String ? value.trim() : '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !(uri.host == 'kimi.com' || uri.host.endsWith('.kimi.com'))) {
      return null;
    }
    return uri;
  }

  static int _seconds(Object? value) => value is num
      ? value.toInt()
      : value is String
          ? int.tryParse(value) ?? 0
          : 0;

  Future<Map<String, dynamic>> _verifyOpenAiIdentity({
    required String idToken,
    required String clientId,
    required String expectedNonce,
  }) async {
    final segments = idToken.split('.');
    if (segments.length != 3) throw const LlmOAuthFlowException();
    final header = _jsonObject(
      utf8.decode(base64Url.decode(base64Url.normalize(segments.first))),
    );
    if (header['alg'] != 'RS256' ||
        header['kid'] is! String ||
        (header['kid'] as String).isEmpty) {
      throw const LlmOAuthFlowException();
    }
    final discoveryResponse = await _dio.getUri<Object?>(
      Uri.parse(_openAiDiscoveryUri),
      options: Options(responseType: ResponseType.json),
    );
    final discovery = _jsonObject(discoveryResponse.data);
    if (_nonEmptyString(discovery['issuer']) !=
        LlmOAuthAuthorizationAttempt.openAiIssuer) {
      throw const LlmOAuthFlowException();
    }
    final jwksUri = Uri.tryParse(_nonEmptyString(discovery['jwks_uri']) ?? '');
    if (jwksUri == null ||
        jwksUri.scheme != 'https' ||
        jwksUri.host != 'auth.openai.com' ||
        jwksUri.userInfo.isNotEmpty) {
      throw const LlmOAuthFlowException();
    }
    final jwksResponse = await _dio.getUri<Object?>(
      jwksUri,
      options: Options(responseType: ResponseType.json),
    );
    final keySet = JsonWebKeySet.fromJson(_jsonObject(jwksResponse.data));
    final token = await JsonWebToken.decodeAndVerify(
      idToken,
      JsonWebKeyStore()..addKeySet(keySet),
    );
    final claims = token.claims;
    final claimsJson = claims.toJson();
    final audience = claims.audience ?? const <String>[];
    final expiry = claims.expiry;
    if (claims.issuer?.toString() !=
            LlmOAuthAuthorizationAttempt.openAiIssuer ||
        !audience.contains(clientId) ||
        (audience.length > 1 && claimsJson['azp'] != clientId) ||
        expiry == null ||
        !expiry.isAfter(DateTime.now().toUtc()) ||
        claimsJson['nonce'] != expectedNonce) {
      throw const LlmOAuthFlowException();
    }
    return claimsJson;
  }

  static Map<String, dynamic> _jsonObject(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const LlmOAuthFlowException();
  }

  static Map<String, dynamic> _credentialBundle(Map<String, dynamic> token) {
    final expiresIn = token['expires_in'];
    final seconds = expiresIn is num
        ? expiresIn.toInt()
        : expiresIn is String
            ? int.tryParse(expiresIn)
            : null;
    return <String, dynamic>{
      'access_token': _nonEmptyString(token['access_token'])!,
      'refresh_token': _nonEmptyString(token['refresh_token'])!,
      if (seconds != null && seconds > 0)
        'expires_at': DateTime.now()
            .toUtc()
            .add(Duration(seconds: seconds))
            .toIso8601String(),
    };
  }

  static String? _nonEmptyString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static bool _scopeContains(String granted, String required) =>
      granted.split(RegExp(r'\s+')).contains(required);
}
