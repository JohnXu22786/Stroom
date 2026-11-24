import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jose/jose.dart';
import 'package:crypto/crypto.dart';

import 'llm_oauth_flow.dart';

/// Exchanges one-use authorization codes and verifies provider identity data.
/// Token values are returned only to the caller for immediate secure storage.
class LlmOAuthTokenClient {
  static const githubCopilotClientId = 'Iv1.b507a08c87ecfe98';
  static const _openAiDiscoveryUri =
      'https://auth.openai.com/.well-known/openid-configuration';
  static const xaiClientId = 'b1a00492-073a-47ea-816f-4c329264a828';
  static const xaiIssuer = 'https://auth.x.ai';
  static const _xaiDiscoveryUri =
      'https://auth.x.ai/.well-known/openid-configuration';
  static const _xaiCommonScopes = 'openid profile email offline_access';
  static const metaMuseClientId = '1031625952748946';
  static const _metaMuseDeviceAuthorizationUri =
      'https://auth.meta.com/oidc/device/authorization/';
  static const _metaMuseTokenUri = 'https://auth.meta.com/oidc/device/token/';
  static const _metaMuseKeyUri = 'https://api.meta.ai/muse-code/key';
  static const _metaMuseApiBaseUrl = 'https://api.meta.ai/v1';
  static const _devinApiBaseUrl = 'https://api.devin.ai';
  static const _devinServerBaseUrl = 'https://server.codeium.com';
  static const _devinUserStatusPath =
      '/exa.seat_management_pb.SeatManagementService/GetUserStatus';
  static const _devinTokenPrefix = r'devin-session-token$';
  static const _tencentCodeBuddyCnHost = 'copilot.tencent.com';
  static const _tencentCodeBuddyIntlHost = 'www.codebuddy.ai';
  static const _tencentWorkBuddyHost = 'www.workbuddy.ai';
  static const _kiloHost = 'api.kilo.ai';
  static const _clineTokenUri = 'https://api.cline.bot/api/v1/auth/token';

  /// Completes Cline's WorkOS authorization-code callback. Cline normally
  /// embeds its token payload in the code; the published token endpoint is the
  /// fallback for opaque codes.
  Future<Map<String, dynamic>> exchangeClineCode({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
    required String provider,
  }) async {
    if (callback.code.trim().isEmpty ||
        !const {'cline', 'clinepass'}.contains(provider)) {
      throw const LlmOAuthFlowException();
    }
    final embedded = _decodeClineCode(callback.code);
    if (embedded != null) return embedded;

    try {
      final response = await _dio.postUri<Object?>(
        Uri.parse(_clineTokenUri),
        data: {
          'grant_type': 'authorization_code',
          'code': callback.code,
          'client_type': 'extension',
          'redirect_uri': attempt.redirectUri.toString(),
          'provider': provider,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final envelope = _jsonObject(response.data);
      final token =
          envelope['data'] is Map ? _jsonObject(envelope['data']) : envelope;
      final accessToken = _nonEmptyString(
        token['accessToken'] ?? token['access_token'],
      );
      if (accessToken == null) throw const LlmOAuthFlowException();
      final userInfo = token['userInfo'] is Map
          ? _jsonObject(token['userInfo'])
          : const <String, dynamic>{};
      return _clineCredentialBundle(
        accessToken: accessToken,
        refreshToken: _nonEmptyString(
          token['refreshToken'] ?? token['refresh_token'],
        ),
        email: _nonEmptyString(token['email'] ?? userInfo['email']),
        firstName: _nonEmptyString(token['firstName']),
        lastName: _nonEmptyString(token['lastName']),
        expiresAt: _nonEmptyString(token['expiresAt'] ?? token['expires_at']),
      );
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  static Map<String, dynamic>? _decodeClineCode(String code) {
    try {
      var encoded = code.trim();
      try {
        encoded = Uri.decodeComponent(encoded);
      } catch (_) {
        // Already decoded by the loopback URI parser.
      }
      encoded = encoded
          .replaceAll(' ', '+')
          .replaceAll('+', '-')
          .replaceAll('/', '_');
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(encoded)),
      );
      final end = decoded.lastIndexOf('}');
      if (end < 0) return null;
      final token = _jsonObject(jsonDecode(decoded.substring(0, end + 1)));
      final accessToken = _nonEmptyString(token['accessToken']);
      if (accessToken == null) return null;
      return _clineCredentialBundle(
        accessToken: accessToken,
        refreshToken: _nonEmptyString(token['refreshToken']),
        email: _nonEmptyString(token['email']),
        firstName: _nonEmptyString(token['firstName']),
        lastName: _nonEmptyString(token['lastName']),
        expiresAt: _nonEmptyString(token['expiresAt']),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _clineCredentialBundle({
    required String accessToken,
    String? refreshToken,
    String? email,
    String? firstName,
    String? lastName,
    String? expiresAt,
  }) {
    final bundle = <String, dynamic>{
      'access_token': accessToken,
      'oauth_contract': 'cline-workos-v1',
    };
    if (refreshToken != null) bundle['refresh_token'] = refreshToken;
    if (email != null) bundle['email'] = email;
    if (firstName != null) bundle['first_name'] = firstName;
    if (lastName != null) bundle['last_name'] = lastName;
    if (expiresAt != null) bundle['expires_at'] = expiresAt;
    return bundle;
  }

  final Dio _dio;

  LlmOAuthTokenClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  LlmCursorOAuthSession startCursorAuthorization() =>
      LlmCursorOAuthSession.create();

  Future<LlmGithubDeviceCode> startGithubDeviceAuthorization({
    required String connectorType,
    String? enterpriseUrl,
    String? clientId,
  }) async {
    try {
      final base = _githubOAuthBase(connectorType, enterpriseUrl);
      final selectedClientId = _nonEmptyString(clientId) ??
          _nonEmptyString(
            const String.fromEnvironment('GHE_COPILOT_OAUTH_CLIENT_ID'),
          ) ??
          githubCopilotClientId;
      final response = await _dio.postUri<Object?>(
        base.replace(path: _githubPath(base, '/login/device/code')),
        data: {'client_id': selectedClientId, 'scope': 'read:user'},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final data = _jsonObject(response.data);
      final deviceCode = _nonEmptyString(data['device_code']);
      final userCode = _nonEmptyString(data['user_code']);
      final verifyText = _nonEmptyString(
        data['verification_uri_complete'] ?? data['verification_uri'],
      );
      final verification = Uri.tryParse(verifyText ?? '');
      final expires = _positiveSeconds(data['expires_in']);
      final rawInterval = data['interval'];
      final parsedInterval = rawInterval is num
          ? rawInterval.toInt()
          : int.tryParse('$rawInterval');
      final interval =
          parsedInterval != null && parsedInterval > 0 ? parsedInterval : 5;
      if (deviceCode == null ||
          userCode == null ||
          verification == null ||
          verification.scheme != 'https' ||
          verification.userInfo.isNotEmpty ||
          (connectorType == 'github' && verification.host != 'github.com') ||
          (connectorType == 'ghe-copilot' && verification.host != base.host) ||
          expires == null) {
        throw const LlmOAuthFlowException();
      }
      return LlmGithubDeviceCode.fromOAuthResponse(
        deviceCode: deviceCode,
        connectorType: connectorType,
        authorizationUri: verification,
        userCode: userCode,
        expiresIn: Duration(seconds: expires),
        interval: Duration(seconds: interval),
      );
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<Map<String, dynamic>> pollGithubDeviceAuthorization({
    required String connectorType,
    required LlmGithubDeviceCode deviceCode,
    String? enterpriseUrl,
    String? clientId,
    CancelToken? cancelToken,
  }) async {
    try {
      if (deviceCode.connectorType != connectorType ||
          !{'github', 'ghe-copilot'}.contains(connectorType)) {
        throw const LlmOAuthFlowException();
      }
      final base = _githubOAuthBase(connectorType, enterpriseUrl);
      final selectedClientId = _nonEmptyString(clientId) ??
          _nonEmptyString(
            const String.fromEnvironment('GHE_COPILOT_OAUTH_CLIENT_ID'),
          ) ??
          githubCopilotClientId;
      final tokenUri = base.replace(
        path: _githubPath(base, '/login/oauth/access_token'),
      );
      final deadline = DateTime.now().add(deviceCode.expiresIn);
      var pollInterval = deviceCode.interval;
      while (DateTime.now().isBefore(deadline)) {
        if (cancelToken?.isCancelled ?? false) {
          throw const LlmOAuthFlowException();
        }
        await _waitForGithubPollingInterval(pollInterval, cancelToken);
        final response = await _dio.postUri<Object?>(
          tokenUri,
          data: {
            'client_id': selectedClientId,
            'device_code': deviceCode.deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.json,
            headers: const {'Accept': 'application/json'},
            validateStatus: (status) => status != null,
          ),
          cancelToken: cancelToken,
        );
        final data = _jsonObject(response.data);
        final accessToken = _nonEmptyString(data['access_token']);
        if (accessToken == null) {
          final error = _nonEmptyString(data['error']);
          if (error == 'authorization_pending') continue;
          if (error == 'slow_down') {
            pollInterval += const Duration(seconds: 5);
            continue;
          }
          throw const LlmOAuthFlowException();
        }
        final userUri = connectorType == 'github'
            ? base.replace(path: '/user')
            : base.replace(path: _githubPath(base, '/api/v3/user'));
        final copilotUri = connectorType == 'github'
            ? Uri.https('api.github.com', '/copilot_internal/v2/token')
            : base.replace(
                path: _githubPath(base, '/api/v3/copilot_internal/v2/token'),
              );
        final copilotResponse = await _dio.getUri<Object?>(
          copilotUri,
          options: Options(
            responseType: ResponseType.json,
            headers: _githubCopilotHeaders(accessToken),
          ),
          cancelToken: cancelToken,
        );
        final copilot = _jsonObject(copilotResponse.data);
        final copilotToken = _nonEmptyString(copilot['token']);
        if (copilotToken == null) throw const LlmOAuthFlowException();
        final userResponse = await _dio.getUri<Object?>(
          userUri,
          options: Options(
            responseType: ResponseType.json,
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $accessToken',
            },
          ),
          cancelToken: cancelToken,
        );
        final user = _jsonObject(userResponse.data);
        final bundle = <String, dynamic>{
          ...data,
          'access_token': accessToken,
          'copilot_token': copilotToken,
          'github_user_id': user['id'],
          'github_login': _nonEmptyString(user['login']),
          if (_nonEmptyString(user['name']) != null)
            'github_name': _nonEmptyString(user['name']),
          if (_nonEmptyString(user['email']) != null)
            'email': _nonEmptyString(user['email']),
          if (copilot['expires_at'] != null)
            'copilot_expires_at': copilot['expires_at'],
        };
        final endpoints = copilot['endpoints'];
        if (connectorType == 'ghe-copilot' && endpoints is Map) {
          final api = _safeHttpsEndpoint(endpoints['api']);
          final proxy = _safeHttpsEndpoint(endpoints['proxy']);
          if (api != null) bundle['copilot_api_url'] = api;
          if (proxy != null) bundle['copilot_proxy_url'] = proxy;
        }
        if (_nonEmptyString(data['refresh_token']) != null) {
          bundle['refresh_token'] = data['refresh_token'];
        }
        final seconds = _positiveSeconds(data['expires_in']);
        if (seconds != null) {
          final oauthExpiry = DateTime.now()
              .toUtc()
              .add(Duration(seconds: seconds))
              .toIso8601String();
          final copilotExpiry = _nonEmptyString(copilot['expires_at']);
          final parsedCopilotExpiry = copilotExpiry == null
              ? null
              : DateTime.tryParse(copilotExpiry)?.toUtc();
          final parsedOAuthExpiry = DateTime.parse(oauthExpiry);
          bundle['oauth_expires_at'] = oauthExpiry;
          bundle['expires_at'] = parsedCopilotExpiry != null &&
                  parsedCopilotExpiry.isBefore(parsedOAuthExpiry)
              ? parsedCopilotExpiry.toIso8601String()
              : oauthExpiry;
        }
        return bundle;
      }
      throw const LlmOAuthFlowException();
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  static Uri _githubOAuthBase(String connectorType, String? enterpriseUrl) {
    if (connectorType == 'github') return Uri.parse('https://github.com');
    if (connectorType != 'ghe-copilot') throw const LlmOAuthFlowException();
    final uri = Uri.tryParse(enterpriseUrl?.trim() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const LlmOAuthFlowException();
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  static String _githubPath(Uri base, String suffix) =>
      '${base.path.replaceFirst(RegExp(r'/+$'), '')}$suffix';

  static Map<String, String> _githubCopilotHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'X-GitHub-Api-Version': '2026-08-01',
        'User-Agent': 'GitHubCopilotChat/1.0.91',
        'Editor-Version': 'copilot/1.0.91',
        'Editor-Plugin-Version': 'copilot-chat/1.0.91',
      };

  static String? _safeHttpsEndpoint(Object? value) {
    final uri = Uri.tryParse(_nonEmptyString(value) ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri
        .replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''))
        .toString();
  }

  static int? _positiveSeconds(Object? value) {
    final seconds = value is num ? value.toInt() : int.tryParse('$value');
    return seconds != null && seconds > 0 ? seconds : null;
  }

  static Future<void> _waitForGithubPollingInterval(
    Duration interval,
    CancelToken? cancelToken,
  ) async {
    if (interval <= Duration.zero) return;
    if (cancelToken == null) return Future<void>.delayed(interval);
    await Future.any<void>([
      Future<void>.delayed(interval),
      cancelToken.whenCancel.then<void>(
        (_) => throw const LlmOAuthFlowException(),
      ),
    ]);
  }

  /// Performs one Cursor auth poll. `null` means approval is still pending.
  Future<Map<String, dynamic>?> pollCursorAuthorization(
    LlmCursorOAuthSession session, {
    CancelToken? cancelToken,
  }) async {
    if (session.isExpired() || (cancelToken?.isCancelled ?? false)) {
      throw const LlmOAuthFlowException();
    }
    try {
      final response = await _dio.getUri<Object?>(
        Uri.https('api2.cursor.sh', '/auth/poll', {
          'uuid': session.uuid,
          'verifier': session.verifier,
        }),
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (_) => true,
        ),
        cancelToken: cancelToken,
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) throw const LlmOAuthFlowException();
      final token = _jsonObject(response.data);
      final accessToken = _nonEmptyString(token['accessToken']);
      final refreshToken = _nonEmptyString(token['refreshToken']);
      if (accessToken == null || refreshToken == null) {
        throw const LlmOAuthFlowException();
      }
      return {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': _cursorTokenExpiry(accessToken).toIso8601String(),
        'oauth_contract': 'cursor-deep-control-v1',
      };
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const LlmOAuthFlowException();
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<Map<String, dynamic>> refreshCursorAuthorization(
    String refreshToken, {
    CancelToken? cancelToken,
  }) async {
    if (refreshToken.trim().isEmpty) throw const LlmOAuthFlowException();
    try {
      final response = await _dio.postUri<Object?>(
        Uri.https('api2.cursor.sh', '/auth/exchange_user_api_key'),
        data: const <String, Object?>{},
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
        cancelToken: cancelToken,
      );
      final token = _jsonObject(response.data);
      final accessToken = _nonEmptyString(token['accessToken']);
      if (accessToken == null) throw const LlmOAuthFlowException();
      return {
        'access_token': accessToken,
        'refresh_token': _nonEmptyString(token['refreshToken']) ?? refreshToken,
        'expires_at': _cursorTokenExpiry(accessToken).toIso8601String(),
        'oauth_contract': 'cursor-deep-control-v1',
      };
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const LlmOAuthFlowException();
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  static DateTime _cursorTokenExpiry(String token) {
    try {
      final segments = token.split('.');
      if (segments.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
        );
        final exp = payload is Map ? payload['exp'] : null;
        if (exp is num) {
          return DateTime.fromMillisecondsSinceEpoch(
            (exp * 1000).round(),
            isUtc: true,
          ).subtract(const Duration(minutes: 5));
        }
      }
    } catch (_) {
      // Cursor may return an opaque token; use the source's one-hour fallback.
    }
    return DateTime.now().toUtc().add(const Duration(hours: 1));
  }

  Future<LlmTencentDeviceCode> startTencentDeviceAuthorization({
    required String connectorType,
  }) async {
    try {
      final host = _tencentHost(connectorType);
      final platform = connectorType == 'codebuddy-intl' ? 'ide' : 'CLI';
      final userAgent = switch (connectorType) {
        'codebuddy-cn' => 'CLI/2.108.1 CodeBuddy/2.108.1',
        'codebuddy-intl' => 'IDE/2.108.1 CodeBuddy/2.108.1',
        _ => 'WorkBuddy/5.5.6',
      };
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Product': 'SaaS',
      };
      if (connectorType != 'workbuddy') {
        headers.addAll({
          'User-Agent': userAgent,
          'X-Requested-With': 'XMLHttpRequest',
          'X-Domain': host,
          'X-No-Authorization': 'true',
          'X-No-User-Id': 'true',
        });
      }
      final response = await _dio.postUri<Object?>(
        Uri.https(host, '/v2/plugin/auth/state', {'platform': platform}),
        data: {'platform': platform},
        options: Options(headers: headers, responseType: ResponseType.json),
      );
      final envelope = _jsonObject(response.data);
      final data = _jsonObject(envelope['data']);
      final state = _nonEmptyString(data['state']);
      final authUrl = _nonEmptyString(data['authUrl'] ?? data['url']);
      final parsedUri = authUrl == null ? null : Uri.tryParse(authUrl);
      final allowedAuthHost = switch (connectorType) {
        'codebuddy-cn' => parsedUri?.host == 'copilot.tencent.com',
        'codebuddy-intl' => parsedUri?.host == 'www.codebuddy.ai',
        _ => parsedUri?.host == 'www.workbuddy.ai',
      };
      if (envelope['code'] != 0 ||
          state == null ||
          parsedUri == null ||
          parsedUri.scheme != 'https' ||
          !allowedAuthHost) {
        throw const LlmOAuthFlowException();
      }
      return LlmTencentDeviceCode.fromResponse(
        deviceCode: state,
        userCode: state,
        verificationUri: parsedUri,
        verificationUriComplete: parsedUri,
        expiresIn: const Duration(minutes: 10),
        interval: const Duration(seconds: 5),
      );
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<LlmKiloDeviceCode> startKiloDeviceAuthorization() async {
    try {
      final response = await _dio.postUri<Object?>(
        Uri.https(_kiloHost, '/api/device-auth/codes'),
        options: Options(
          headers: const {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
        ),
      );
      final data = _jsonObject(response.data);
      final code = _nonEmptyString(data['code']);
      final verification = _kiloVerificationUri(data['verificationUrl']);
      if (code == null || verification == null) {
        throw const LlmOAuthFlowException();
      }
      return LlmKiloDeviceCode.fromResponse(
        deviceCode: code,
        userCode: code,
        verificationUri: verification,
        verificationUriComplete: verification,
        interval: const Duration(seconds: 3),
      );
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  /// Polls Kilo's custom endpoint until approval, expiry, or cancellation.
  /// The source flow supplies no refresh token or advertised code lifetime.
  Future<Map<String, dynamic>> pollKiloDeviceAuthorization(
    LlmKiloDeviceCode deviceCode, {
    CancelToken? cancelToken,
  }) async {
    try {
      if (deviceCode.deviceCode.trim().isEmpty) {
        throw const LlmOAuthFlowException();
      }
      var firstPoll = true;
      while (true) {
        if (cancelToken?.isCancelled ?? false) {
          throw cancelToken!.cancelError!;
        }
        if (!firstPoll) {
          await _waitForKiloPollingInterval(deviceCode.interval, cancelToken);
        }
        firstPoll = false;
        final uri = Uri.https(
          _kiloHost,
          '/api/device-auth/codes/${Uri.encodeComponent(deviceCode.deviceCode)}',
        );
        final response = await _dio.getUri<Object?>(
          uri,
          options: Options(
            headers: const {'Accept': 'application/json'},
            responseType: ResponseType.json,
            validateStatus: (status) => status != null,
          ),
          cancelToken: cancelToken,
        );
        if (response.statusCode == 202) continue;
        if (response.statusCode == 410) {
          throw const LlmOAuthFlowException();
        }
        if (response.statusCode == null ||
            response.statusCode! < 200 ||
            response.statusCode! >= 300) {
          throw const LlmOAuthFlowException();
        }
        final data = _jsonObject(response.data);
        if (data['status'] == 'approved') {
          final token = _nonEmptyString(data['token']);
          if (token == null) throw const LlmOAuthFlowException();
          final credentials = <String, String>{
            'access_token': token,
            'token_type': 'Bearer',
          };
          final email = _nonEmptyString(data['userEmail']);
          if (email != null) credentials['email'] = email;
          return credentials;
        }
        if (data['status'] == null || data['status'] == 'pending') continue;
        throw const LlmOAuthFlowException();
      }
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  static Uri? _kiloVerificationUri(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'app.kilo.ai' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }

  static Future<void> _waitForKiloPollingInterval(
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

  Future<Map<String, dynamic>> pollTencentDeviceAuthorization({
    required String connectorType,
    required LlmTencentDeviceCode deviceCode,
    CancelToken? cancelToken,
  }) async {
    try {
      final host = _tencentHost(connectorType);
      final deadline = DateTime.now().add(deviceCode.expiresIn);
      var firstPoll = true;
      while (DateTime.now().isBefore(deadline)) {
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
        if (!firstPoll) {
          await _waitForTencentPollingInterval(
            deviceCode.interval,
            cancelToken,
          );
        }
        firstPoll = false;
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
        if (!DateTime.now().isBefore(deadline)) break;
        final headers = <String, String>{'Accept': 'application/json'};
        if (connectorType != 'workbuddy') {
          headers.addAll({
            'User-Agent': connectorType == 'codebuddy-cn'
                ? 'CLI/2.108.1 CodeBuddy/2.108.1'
                : 'IDE/2.108.1 CodeBuddy/2.108.1',
            'X-Requested-With': 'XMLHttpRequest',
            'X-Domain': host,
            'X-No-Authorization': 'true',
            'X-No-User-Id': 'true',
            'X-No-Enterprise-Id': 'true',
            'X-No-Department-Info': 'true',
          });
        }
        headers['X-Product'] = 'SaaS';
        final response = await _dio.getUri<Object?>(
          Uri.https(host, '/v2/plugin/auth/token', {
            'state': deviceCode.deviceCode,
          }),
          options: Options(
            headers: headers,
            responseType: ResponseType.json,
            validateStatus: (status) => status != null,
          ),
          cancelToken: cancelToken,
        );
        if ((response.statusCode ?? 0) < 200 ||
            (response.statusCode ?? 0) >= 300) {
          throw const LlmOAuthFlowException();
        }
        final envelope = _jsonObject(response.data);
        if (envelope['code'] == 11217) continue;
        final token = _jsonObject(envelope['data']);
        final accessToken = _nonEmptyString(token['accessToken']);
        if (envelope['code'] != 0 || accessToken == null) {
          throw const LlmOAuthFlowException();
        }
        final expiresIn = token['expiresIn'] is num
            ? (token['expiresIn'] as num).toInt()
            : connectorType == 'workbuddy'
                ? 31104000
                : 86400;
        if (expiresIn <= 0) throw const LlmOAuthFlowException();
        return {
          'access_token': accessToken,
          'refresh_token': _nonEmptyString(token['refreshToken']) ?? '',
          'token_type': _nonEmptyString(token['tokenType']) ?? 'Bearer',
          'expires_in': expiresIn,
          'expires_at': DateTime.now()
              .toUtc()
              .add(Duration(seconds: expiresIn))
              .toIso8601String(),
          'connector_type': connectorType,
        };
      }
      throw const LlmOAuthFlowException();
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  static String _tencentHost(String connectorType) => switch (connectorType) {
        'codebuddy-cn' => _tencentCodeBuddyCnHost,
        'codebuddy-intl' => _tencentCodeBuddyIntlHost,
        'workbuddy' => _tencentWorkBuddyHost,
        _ => throw const LlmOAuthFlowException(),
      };

  static Future<void> _waitForTencentPollingInterval(
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

  Future<Map<String, dynamic>> exchangeOpenAiChatGpt({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
    String? expectedSubject,
  }) async {
    try {
      final clientId = callback.clientId;
      if (clientId == null || clientId.isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final response = await _dio.postUri<Object?>(
        Uri.parse(LlmOAuthAuthorizationAttempt.openAiTokenEndpoint),
        data: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
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
        clientId: clientId,
        expectedNonce: attempt.nonce,
      );
      final subject = _nonEmptyString(identity['sub']);
      if (subject == null ||
          (expectedSubject != null && subject != expectedSubject)) {
        throw const LlmOAuthFlowException();
      }
      return _credentialBundle(token)
        ..['client_id'] = clientId
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
      final clientId = callback.clientId;
      if (clientId == null || clientId.isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final secret = clientSecret.trim();
      if (secret.isEmpty) throw const LlmOAuthFlowException();
      final response = await _dio.postUri<Object?>(
        Uri.parse(LlmOAuthAuthorizationAttempt.geminiTokenEndpoint),
        data: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
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
        ..['client_id'] = clientId
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
          'client_id': LlmOAuthAuthorizationAttempt.claudeCodeClientId,
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

  Future<Map<String, dynamic>> exchangeOpenferenceCode({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
  }) async {
    try {
      if (callback.clientId !=
              LlmOAuthAuthorizationAttempt.openferenceClientId ||
          callback.code.trim().isEmpty ||
          attempt.codeVerifier.isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final response = await _dio.postUri<Object?>(
        Uri.https('openference.com', '/oauth/token'),
        data: {
          'grant_type': 'authorization_code',
          'client_id': LlmOAuthAuthorizationAttempt.openferenceClientId,
          'code': callback.code,
          'redirect_uri': attempt.redirectUri.toString(),
          'code_verifier': attempt.codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final token = _jsonObject(response.data);
      final bundle = _credentialBundle(token)
        ..['client_id'] = LlmOAuthAuthorizationAttempt.openferenceClientId
        ..['scope'] = _nonEmptyString(token['scope']) ??
            LlmOAuthAuthorizationAttempt.openferenceScope
        ..['oauth_contract'] = 'openference-pkce-v1';
      return bundle;
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  /// Exchanges Qoder's administrator-configured authorization code and reads
  /// the DashScope API key returned by its configured user-info endpoint.
  /// The caller stores this entire bundle in secure storage.
  Future<Map<String, dynamic>> exchangeQoderCode({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
    required Map<String, String> configuration,
  }) async {
    try {
      final clientId = configuration['clientId']?.trim() ?? '';
      final clientSecret = configuration['clientSecret']?.trim() ?? '';
      final tokenUri = LlmOAuthAuthorizationAttempt.validateQoderOAuthEndpoint(
        configuration['tokenUrl'] ?? '',
      );
      final userInfoUri =
          LlmOAuthAuthorizationAttempt.validateQoderOAuthEndpoint(
        configuration['userInfoUrl'] ?? '',
      );
      if (clientId.isEmpty ||
          clientSecret.isEmpty ||
          callback.clientId != clientId ||
          callback.code.trim().isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final form = {
        'grant_type': 'authorization_code',
        'code': callback.code,
        'redirect_uri': attempt.redirectUri.toString(),
        'client_id': clientId,
        'client_secret': clientSecret,
      };
      final response = await _dio.postUri<Object?>(
        tokenUri,
        data: form,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          headers: {
            'Accept': 'application/json',
            'Authorization':
                'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
          },
        ),
      );
      final tokens = _jsonObject(response.data);
      final accessToken = _nonEmptyString(tokens['access_token']);
      if (accessToken == null) throw const LlmOAuthFlowException();
      final userInfoResponse = await _dio.getUri<Object?>(
        userInfoUri.replace(queryParameters: {'accessToken': accessToken}),
        options: Options(
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final envelope = _jsonObject(userInfoResponse.data);
      final userInfo =
          envelope['success'] == true ? _jsonObject(envelope['data']) : null;
      final apiKey = _nonEmptyString(userInfo?['apiKey']);
      if (apiKey == null) throw const LlmOAuthFlowException();
      final bundle = _qoderCredentialBundle(tokens)
        ..['api_key'] = apiKey
        ..['client_id'] = clientId
        ..['client_secret'] = clientSecret
        ..['authorize_url'] =
            LlmOAuthAuthorizationAttempt.validateQoderOAuthEndpoint(
          configuration['authorizeUrl'] ?? '',
        ).toString()
        ..['token_url'] = tokenUri.toString()
        ..['user_info_url'] =
            LlmOAuthAuthorizationAttempt.validateQoderOAuthEndpoint(
          configuration['userInfoUrl'] ?? '',
        ).toString()
        ..['oauth_contract'] = 'qoder-admin-code-v1';
      final identity = _nonEmptyString(userInfo?['email']) ??
          _nonEmptyString(userInfo?['phone']);
      final displayName = _nonEmptyString(userInfo?['nickname']) ??
          _nonEmptyString(userInfo?['name']);
      if (identity != null) bundle['email'] = identity;
      if (displayName != null) bundle['display_name'] = displayName;
      return bundle;
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  Future<Map<String, dynamic>> exchangeGitLabDuoCode({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
    required String baseUrl,
    required String clientSecret,
  }) async {
    final clientId = attempt.existingClientId;
    if (clientId == null || clientId.trim().isEmpty) {
      throw const LlmOAuthFlowException();
    }
    final root = LlmOAuthAuthorizationAttempt.validateGitLabDuoBaseUrl(baseUrl);
    final response = await _dio.postUri<Object?>(
      LlmOAuthAuthorizationAttempt.resolveGitLabDuoEndpoint(
        root,
        'oauth/token',
      ),
      data: {
        'client_id': clientId,
        if (clientSecret.trim().isNotEmpty)
          'client_secret': clientSecret.trim(),
        'code': callback.code,
        'grant_type': 'authorization_code',
        'redirect_uri': attempt.redirectUri.toString(),
        'code_verifier': attempt.codeVerifier,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      ),
    );
    final token = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : null;
    final accessToken = _nonEmptyString(token?['access_token']);
    final refreshToken = _nonEmptyString(token?['refresh_token']);
    if (accessToken == null) throw const LlmOAuthFlowException();
    final expiresIn = token?['expires_in'];
    final expiresAt = expiresIn is num && expiresIn > 0
        ? DateTime.now()
            .toUtc()
            .add(Duration(seconds: expiresIn.toInt()))
            .toIso8601String()
        : null;
    return {
      'oauth_contract': 'gitlab-duo-pkce-v1',
      'access_token': accessToken,
      ...?_optionalStringField('refresh_token', refreshToken),
      if (expiresIn is num && expiresIn > 0) 'expires_in': expiresIn,
      ...?_optionalStringField('expires_at', expiresAt),
      'client_id': clientId,
      ...?_optionalStringField(
        'client_secret',
        clientSecret.trim().isEmpty ? null : clientSecret.trim(),
      ),
      'base_url': root.toString(),
    };
  }

  /// Completes Devin's source-pinned PKCE exchange and verifies both the
  /// account profile and seat plan before the caller persists the credential.
  Future<Map<String, dynamic>> exchangeDevinCode({
    required LlmOAuthAuthorizationAttempt attempt,
    required LlmOAuthCallbackResult callback,
    required String accountId,
    String? expectedUserId,
    CancelToken? cancelToken,
  }) async {
    try {
      if (callback.clientId != null ||
          callback.code.trim().isEmpty ||
          attempt.codeVerifier.isEmpty ||
          accountId.trim().isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final tokenResponse = await _dio.postUri<Object?>(
        Uri.parse('$_devinApiBaseUrl/auth/cli/token'),
        data: {'code': callback.code, 'code_verifier': attempt.codeVerifier},
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
        cancelToken: cancelToken,
      );
      final rawToken = _nonEmptyString(
        _jsonObject(tokenResponse.data)['token'],
      );
      if (rawToken == null) throw const LlmOAuthFlowException();
      final sessionToken = _formatDevinSessionToken(rawToken);

      final profileResponse = await _dio.getUri<Object?>(
        Uri.parse('$_devinApiBaseUrl/v3/self'),
        options: Options(
          headers: {
            'Authorization': 'Bearer $sessionToken',
            'Accept': 'application/json',
          },
          responseType: ResponseType.json,
        ),
        cancelToken: cancelToken,
      );
      final profile = _jsonObject(profileResponse.data);
      final userId = _nonEmptyString(profile['user_id']);
      if (profileResponse.statusCode != 200 ||
          userId == null ||
          (expectedUserId != null && userId != expectedUserId)) {
        throw const LlmOAuthFlowException();
      }

      final statusResponse = await _dio.postUri<List<int>>(
        Uri.parse('$_devinServerBaseUrl$_devinUserStatusPath'),
        data: _buildDevinUserStatusRequest(sessionToken, accountId),
        options: Options(
          headers: {
            'Authorization': 'Basic $sessionToken-$sessionToken',
            'Connect-Protocol-Version': '1',
            'Content-Type': 'application/proto',
            'Accept': '*/*',
          },
          contentType: 'application/proto',
          responseType: ResponseType.bytes,
        ),
        cancelToken: cancelToken,
      );
      if (statusResponse.statusCode != 200 || statusResponse.data == null) {
        throw const LlmOAuthFlowException();
      }
      final status = _parseDevinUserStatus(
        Uint8List.fromList(statusResponse.data!),
      );
      if (status.userId != userId || status.plan.isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final planEnd = status.planEnd;
      if (planEnd != null && !planEnd.isAfter(DateTime.now().toUtc())) {
        throw const LlmOAuthFlowException();
      }

      return {
        'session_token': sessionToken,
        'user_id': userId,
        if (_nonEmptyString(profile['user_name']) case final String name)
          'user_name': name,
        if (_nonEmptyString(profile['org_id']) case final String orgId)
          'org_id': orgId,
        if (status.email.isNotEmpty) 'email': status.email,
        'plan': status.plan,
        if (planEnd != null) 'plan_end': planEnd.toIso8601String(),
        'base_url': _devinServerBaseUrl,
        'auth_kind': 'oauth',
        'oauth_contract': 'devin-pkce-v1',
      };
    } catch (_) {
      throw const LlmOAuthFlowException();
    }
  }

  static String _formatDevinSessionToken(String token) {
    final clean = token.trim();
    if (clean.startsWith(_devinTokenPrefix) || !clean.startsWith('eyJ')) {
      return clean;
    }
    return '$_devinTokenPrefix$clean';
  }

  static Uint8List _buildDevinUserStatusRequest(
    String sessionToken,
    String seed,
  ) {
    final metadata = <int>[];
    _appendProtoBytes(metadata, 1, utf8.encode('chisel'));
    _appendProtoBytes(metadata, 2, utf8.encode('3000.10.21'));
    _appendProtoBytes(metadata, 3, utf8.encode(sessionToken));
    _appendProtoBytes(metadata, 4, utf8.encode('en'));
    _appendProtoBytes(
      metadata,
      5,
      utf8.encode(_devinOsName(defaultTargetPlatform)),
    );
    _appendProtoBytes(metadata, 7, utf8.encode('3000.10.21'));
    _appendProtoBytes(metadata, 12, utf8.encode('chisel'));
    _appendProtoBytes(metadata, 31, utf8.encode(_devenFingerprint(seed)));
    final request = <int>[];
    _appendProtoBytes(request, 1, metadata);
    return Uint8List.fromList(request);
  }

  static _DevinUserStatus _parseDevinUserStatus(Uint8List data) {
    final userStatus = _protoBytesFields(data, 1).firstOrNull;
    if (userStatus == null) throw const LlmOAuthFlowException();
    final userFields = _protoFields(userStatus);
    final userId = utf8.decode(_firstBytesField(userFields, 36) ?? const []);
    final email = utf8.decode(_firstBytesField(userFields, 7) ?? const []);
    final planStatus = _firstBytesField(userFields, 13);
    if (planStatus == null) throw const LlmOAuthFlowException();
    final planFields = _protoFields(planStatus);
    final planInfo = _firstBytesField(planFields, 1);
    if (planInfo == null) throw const LlmOAuthFlowException();
    final infoFields = _protoFields(planInfo);
    final plan = utf8.decode(_firstBytesField(infoFields, 2) ?? const []);
    final expiration = _firstBytesField(planFields, 3);
    final endEpoch = expiration == null
        ? null
        : _firstVarintField(_protoFields(expiration), 1);
    return _DevinUserStatus(
      userId: userId,
      email: email,
      plan: plan,
      planEnd: endEpoch == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endEpoch * 1000, isUtc: true),
    );
  }

  static List<Uint8List> _protoBytesFields(Uint8List bytes, int field) =>
      _protoFields(bytes)
          .where((item) => item.number == field && item.bytes != null)
          .map((item) => item.bytes!)
          .toList(growable: false);

  static Uint8List? _firstBytesField(
    List<_DevinProtoField> fields,
    int number,
  ) =>
      fields.where((field) => field.number == number).firstOrNull?.bytes;

  static int? _firstVarintField(List<_DevinProtoField> fields, int number) =>
      fields.where((field) => field.number == number).firstOrNull?.value;

  static List<_DevinProtoField> _protoFields(Uint8List bytes) {
    final fields = <_DevinProtoField>[];
    var offset = 0;
    while (offset < bytes.length) {
      final tag = _readProtoVarint(bytes, offset);
      offset = tag.$2;
      final number = tag.$1 >> 3;
      if (number == 0) throw const LlmOAuthFlowException();
      switch (tag.$1 & 7) {
        case 0:
          final value = _readProtoVarint(bytes, offset);
          offset = value.$2;
          fields.add(_DevinProtoField(number, value: value.$1));
          break;
        case 1:
          offset += 8;
          if (offset > bytes.length) throw const LlmOAuthFlowException();
          fields.add(_DevinProtoField(number));
          break;
        case 2:
          final size = _readProtoVarint(bytes, offset);
          offset = size.$2;
          final end = offset + size.$1;
          if (end > bytes.length) throw const LlmOAuthFlowException();
          fields.add(
            _DevinProtoField(number, bytes: bytes.sublist(offset, end)),
          );
          offset = end;
          break;
        case 5:
          offset += 4;
          if (offset > bytes.length) throw const LlmOAuthFlowException();
          fields.add(_DevinProtoField(number));
          break;
        default:
          throw const LlmOAuthFlowException();
      }
    }
    return fields;
  }

  static (int, int) _readProtoVarint(Uint8List data, int offset) {
    var result = 0;
    var shift = 0;
    while (offset < data.length && shift < 64) {
      final byte = data[offset++];
      result |= (byte & 0x7f) << shift;
      if (byte < 0x80) return (result, offset);
      shift += 7;
    }
    throw const LlmOAuthFlowException();
  }

  static void _appendProtoBytes(List<int> output, int field, List<int> value) {
    _appendProtoVarint(output, (field << 3) | 2);
    _appendProtoVarint(output, value.length);
    output.addAll(value);
  }

  static void _appendProtoVarint(List<int> output, int value) {
    while (value >= 0x80) {
      output.add((value & 0x7f) | 0x80);
      value >>= 7;
    }
    output.add(value);
  }

  static String _devinOsName(TargetPlatform platform) => switch (platform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.linux => 'linux',
        TargetPlatform.macOS => 'darwin',
        TargetPlatform.windows => 'windows',
        TargetPlatform.fuchsia => 'fuchsia',
      };

  static String _devenFingerprint(String seed) {
    final value = StringBuffer();
    var counter = 0;
    while (value.length < 732) {
      value.write(sha256.convert(utf8.encode('$seed-$counter')));
      counter++;
    }
    return value.toString().substring(0, 732);
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

  Future<LlmMetaMuseDeviceCode> startMetaMuseDeviceAuthorization() async {
    try {
      final response = await _dio.postUri<Object?>(
        Uri.parse(_metaMuseDeviceAuthorizationUri),
        data: {'client_id': metaMuseClientId},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
      final data = _jsonObject(response.data);
      final deviceCode = _nonEmptyString(data['device_code']);
      final userCode = _nonEmptyString(data['user_code']);
      final verification = _metaMuseVerificationUri(
        data['verification_uri'] ?? data['verification_url'],
      );
      final complete = _metaMuseVerificationUri(
            data['verification_uri_complete'] ??
                data['verification_url_complete'],
          ) ??
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
      return LlmMetaMuseDeviceCode.fromOAuthResponse(
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

  Future<Map<String, dynamic>> pollMetaMuseDeviceAuthorization({
    required LlmMetaMuseDeviceCode deviceCode,
    String? expectedEmail,
    CancelToken? cancelToken,
  }) async {
    try {
      if (deviceCode.deviceCode.isEmpty) {
        throw const LlmOAuthFlowException();
      }
      final deadline = DateTime.now().add(deviceCode.expiresIn);
      var interval = deviceCode.interval <= Duration.zero
          ? const Duration(seconds: 5)
          : deviceCode.interval;
      while (DateTime.now().isBefore(deadline)) {
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final expiresBeforeNextPoll = interval >= remaining;
        await _waitForMetaMusePollingInterval(
          interval > remaining ? remaining : interval,
          cancelToken,
        );
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
        if (expiresBeforeNextPoll) break;
        if (!DateTime.now().isBefore(deadline)) break;
        final response = await _dio.postUri<Object?>(
          Uri.parse(_metaMuseTokenUri),
          data: {
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'device_code': deviceCode.deviceCode,
            'client_id': metaMuseClientId,
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
        final dcaToken = _nonEmptyString(token['access_token']);
        if (dcaToken == null || !dcaToken.startsWith('dca:')) {
          throw const LlmOAuthFlowException();
        }
        final mintedResponse = await _dio.postUri<Object?>(
          Uri.parse(_metaMuseKeyUri),
          data: {'dca_token': dcaToken},
          options: Options(
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
            headers: {
              'Authorization': 'Bearer $dcaToken',
              'User-Agent': 'muse-code/1.0.2',
              'Accept': 'application/json',
            },
          ),
          cancelToken: cancelToken,
        );
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
        final minted = _jsonObject(mintedResponse.data);
        final apiKey = _nonEmptyString(minted['api_key']);
        if (apiKey == null) throw const LlmOAuthFlowException();
        final email = _nonEmptyString(minted['user_email']);
        if (email == null ||
            (expectedEmail != null &&
                email.toLowerCase() != expectedEmail.toLowerCase())) {
          throw const LlmOAuthFlowException();
        }
        final active = minted['is_subs_active'];
        if (active != true) throw const LlmOAuthFlowException();
        final baseUrl = _metaMuseBaseUrl(minted['base_url']);
        final fullName = _nonEmptyString(minted['user_full_name']);
        final tierName = _nonEmptyString(minted['subs_tier_name']);
        final tierId = _nonEmptyString(minted['subs_tier_id']);
        return <String, dynamic>{
          'access_token': apiKey,
          'api_key': apiKey,
          'dca_token': dcaToken,
          'base_url': baseUrl,
          'auth_kind': 'oauth',
          'oauth_contract': 'meta-muse-device-v1',
          'email': email,
          ...?_optionalStringField('name', fullName),
          ...?_optionalStringField('subs_tier_name', tierName),
          ...?_optionalStringField('subs_tier_id', tierId),
          if (active is bool) 'is_subs_active': active,
          if (minted['has_payment_method'] is bool)
            'has_payment_method': minted['has_payment_method'],
        };
      }
      throw const LlmOAuthFlowException();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
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
      final deviceEndpoint = _xaiEndpoint(
        discovery['device_authorization_endpoint'],
      );
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
        if (token.containsKey('scope') && grantedScope == null) {
          throw const LlmOAuthFlowException();
        }
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
    final hasAuthorizedParty = claimsJson.containsKey('azp');
    final authorizedParty = claimsJson['azp'];
    if (claims.issuer?.toString() != issuer ||
        !audience.contains(clientId) ||
        (audience.length > 1 && authorizedParty != clientId) ||
        (hasAuthorizedParty && authorizedParty != clientId) ||
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

  static Future<void> _waitForMetaMusePollingInterval(
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

  static Uri? _metaMuseVerificationUri(Object? value) {
    final uri = Uri.tryParse(value is String ? value.trim() : '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !(uri.host == 'meta.ai' ||
            uri.host.endsWith('.meta.ai') ||
            uri.host == 'meta.com' ||
            uri.host.endsWith('.meta.com'))) {
      return null;
    }
    return uri;
  }

  static String _metaMuseBaseUrl(Object? value) {
    final uri = Uri.tryParse(value is String ? value.trim() : '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'api.meta.ai' ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/v1') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return _metaMuseApiBaseUrl;
    }
    return uri.replace(path: '/v1').toString();
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

  static Map<String, dynamic> _qoderCredentialBundle(
    Map<String, dynamic> token,
  ) {
    final expiresIn = token['expires_in'];
    final seconds = expiresIn is num
        ? expiresIn.toInt()
        : expiresIn is String
            ? int.tryParse(expiresIn)
            : null;
    final refreshToken = _nonEmptyString(token['refresh_token']);
    return <String, dynamic>{
      'access_token': _nonEmptyString(token['access_token'])!,
      ...?_optionalStringField('refresh_token', refreshToken),
      if (seconds != null && seconds > 0)
        'expires_at': DateTime.now()
            .toUtc()
            .add(Duration(seconds: seconds))
            .toIso8601String(),
    };
  }

  static String? _nonEmptyString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static Map<String, String>? _optionalStringField(String key, String? value) =>
      value == null ? null : <String, String>{key: value};

  static bool _scopeContains(String granted, String required) =>
      granted.split(RegExp(r'\s+')).contains(required);
}

class _DevinUserStatus {
  final String userId;
  final String email;
  final String plan;
  final DateTime? planEnd;

  const _DevinUserStatus({
    required this.userId,
    required this.email,
    required this.plan,
    required this.planEnd,
  });
}

class _DevinProtoField {
  final int number;
  final int? value;
  final Uint8List? bytes;

  const _DevinProtoField(this.number, {this.value, this.bytes});
}
