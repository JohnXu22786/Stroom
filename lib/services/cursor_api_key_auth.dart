import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

const cursorApiKeyExchangeUrl =
    'https://api2.cursor.sh/auth/exchange_user_api_key';

/// Cursor API keys are exchanged for short lived session tokens before use.
/// The API key remains the stored credential; session tokens are memory only.
class CursorApiKeyAuth {
  static const _refreshSkew = Duration(minutes: 5);
  static const _fallbackLifetime = Duration(minutes: 55);
  static const _requestTimeout = Duration(seconds: 15);
  static final _fingerprintKey = utf8.encode(
    'stroom-cursor-session-cache-fingerprint-v1',
  );

  static final Map<String, _CursorSession> _sessions = {};
  static final Map<String, _PendingCursorExchange> _pending = {};

  static bool isApiKey(String value) =>
      value.startsWith('crsr_') || value.startsWith('grok_');

  static void invalidate(String apiKey) {
    _sessions.remove(_fingerprint(apiKey));
  }

  static bool retryAfterUnauthorizedResponse(
    String apiKey, {
    required int statusCode,
    required bool alreadyRetried,
  }) {
    if (statusCode != 401) return false;
    invalidate(apiKey);
    return !alreadyRetried;
  }

  static String _fingerprint(String apiKey) =>
      Hmac(sha256, _fingerprintKey).convert(utf8.encode(apiKey)).toString();

  static Future<String> resolveAccessToken(
    String apiKey, {
    required Dio dio,
    CancelToken? cancelToken,
    DateTime Function()? now,
    Duration timeout = _requestTimeout,
  }) async {
    if (!isApiKey(apiKey)) {
      throw const CursorApiKeyAuthException('invalid_api_key_format');
    }
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    final clock = now ?? DateTime.now;
    final key = _fingerprint(apiKey);
    final cached = _sessions[key];
    if (cached != null && cached.expiresAt.isAfter(clock().add(_refreshSkew))) {
      return cached.accessToken;
    }
    var pending = _pending[key];
    if (pending == null) {
      pending = _PendingCursorExchange();
      _pending[key] = pending;
      final created = pending;
      created.future = _exchange(
        apiKey,
        dio,
        created.cancelToken,
        clock,
        timeout,
      ).then((session) {
        if (!created.cancelToken.isCancelled &&
            identical(_pending[key], created)) {
          _sessions[key] = session;
        }
        return session.accessToken;
      }).whenComplete(() {
        created.completed = true;
        if (identical(_pending[key], created)) _pending.remove(key);
      });
    }
    return _waitForExchange(key, pending, cancelToken);
  }

  static Future<String> _waitForExchange(
    String key,
    _PendingCursorExchange pending,
    CancelToken? cancelToken,
  ) async {
    pending.waiters++;
    try {
      if (cancelToken == null) return await pending.future;
      return await Future.any<String>([
        pending.future,
        cancelToken.whenCancel.then<String>((error) => throw error),
      ]);
    } finally {
      pending.waiters--;
      if (pending.waiters == 0 && !pending.completed) {
        if (identical(_pending[key], pending)) _pending.remove(key);
        pending.cancelToken.cancel('No active Cursor API key requests remain');
      }
    }
  }

  static Future<_CursorSession> _exchange(
    String apiKey,
    Dio dio,
    CancelToken? cancelToken,
    DateTime Function() now,
    Duration timeout,
  ) async {
    try {
      final response = await dio
          .post<Object?>(
        cursorApiKeyExchangeUrl,
        data: <String, Object?>{},
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          validateStatus: (_) => true,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
        cancelToken: cancelToken,
      )
          .timeout(
        timeout,
        onTimeout: () {
          cancelToken?.cancel('Cursor API key exchange timed out');
          throw const CursorApiKeyAuthException('exchange_failed');
        },
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CursorApiKeyAuthException('api_key_rejected');
      }
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw const CursorApiKeyAuthException('exchange_failed');
      }
      final data = response.data;
      final token = data is Map ? data['accessToken'] : null;
      if (token is! String || token.isEmpty) {
        throw const CursorApiKeyAuthException('malformed_exchange_response');
      }
      final refreshToken = data is Map ? data['refreshToken'] : null;
      final expiry = _jwtExpiry(token) ?? now().toUtc().add(_fallbackLifetime);
      return _CursorSession(
        token,
        refreshToken is String && refreshToken.isNotEmpty ? refreshToken : null,
        expiry,
      );
    } on CursorApiKeyAuthException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        throw const CursorApiKeyAuthException('api_key_rejected');
      }
      throw const CursorApiKeyAuthException('exchange_failed');
    } catch (_) {
      throw const CursorApiKeyAuthException('exchange_failed');
    }
  }

  static DateTime? _jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final expiry = payload is Map ? payload['exp'] : null;
      if (expiry is! num || !expiry.isFinite) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (expiry * 1000).round(),
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  static void resetForTesting() {
    _sessions.clear();
    _pending.clear();
  }
}

class CursorApiKeyAuthException implements Exception {
  final String code;
  const CursorApiKeyAuthException(this.code);
}

class _CursorSession {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  const _CursorSession(this.accessToken, this.refreshToken, this.expiresAt);
}

class _PendingCursorExchange {
  final CancelToken cancelToken = CancelToken();
  late final Future<String> future;
  var waiters = 0;
  var completed = false;
}
