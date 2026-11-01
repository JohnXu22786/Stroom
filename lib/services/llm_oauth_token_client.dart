import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jose/jose.dart';

import 'llm_oauth_flow.dart';

/// Exchanges one-use authorization codes and verifies provider identity data.
/// Token values are returned only to the caller for immediate secure storage.
class LlmOAuthTokenClient {
  static const _openAiDiscoveryUri =
      'https://auth.openai.com/.well-known/openid-configuration';

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
