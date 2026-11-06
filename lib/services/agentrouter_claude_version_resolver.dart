import 'dart:convert';

import 'package:dio/dio.dart';

class AgentRouterClaudeClientVersion {
  static const pinnedVersion = '2.1.280';
  static const buildRevision = '1e2';
  static const sdkVersion = '0.112.1';
  static const runtimeVersion = 'v26.3.0';

  final String clientVersion;

  const AgentRouterClaudeClientVersion(this.clientVersion);

  String get billingVersion => '$clientVersion.$buildRevision';
  String get userAgent => 'claude-cli/$clientVersion (external, cli)';
}

/// Resolves the source-pinned AgentRouter Claude Code client version.
class AgentRouterClaudeVersionResolver {
  static const registryUrl =
      'https://registry.npmjs.org/@anthropic-ai/claude-code/latest';
  static const cacheDuration = Duration(hours: 6);
  static const failureCacheDuration = Duration(minutes: 5);
  static const requestTimeout = Duration(seconds: 20);
  static const maxResponseBytes = 64 * 1024;

  final Dio _dio;
  final DateTime Function() _now;
  AgentRouterClaudeClientVersion? _cached;
  DateTime? _cachedAt;
  Duration _activeCacheDuration = cacheDuration;
  Future<AgentRouterClaudeClientVersion>? _inFlight;

  AgentRouterClaudeVersionResolver({Dio? dio, DateTime Function()? now})
      : _dio = dio ?? Dio(),
        _now = now ?? DateTime.now;

  Future<AgentRouterClaudeClientVersion> resolve() {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (cached != null &&
        cachedAt != null &&
        _now().difference(cachedAt) < _activeCacheDuration) {
      return Future.value(cached);
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<AgentRouterClaudeClientVersion> _fetch() async {
    try {
      final response = await _dio
          .get<Object?>(registryUrl,
              options: Options(
                responseType: ResponseType.json,
                receiveTimeout: requestTimeout,
                sendTimeout: requestTimeout,
                headers: const {'Accept': 'application/json'},
              ))
          .timeout(requestTimeout);
      final body = response.data;
      final bodyText = body is String ? body : jsonEncode(body);
      if (utf8.encode(bodyText).length > maxResponseBytes) {
        return _cacheFallback();
      }
      final decoded = body is Map ? body : jsonDecode(bodyText);
      final version = decoded is Map ? decoded['version'] : null;
      if (version is! String || !_isNewerValidVersion(version)) {
        return _cacheFallback();
      }
      final resolved = AgentRouterClaudeClientVersion(version);
      _cached = resolved;
      _cachedAt = _now();
      _activeCacheDuration = cacheDuration;
      return resolved;
    } catch (_) {
      return _cacheFallback();
    }
  }

  AgentRouterClaudeClientVersion _cacheFallback() {
    _cached = _fallback;
    _cachedAt = _now();
    _activeCacheDuration = failureCacheDuration;
    return _fallback;
  }

  AgentRouterClaudeClientVersion get _fallback =>
      const AgentRouterClaudeClientVersion(
        AgentRouterClaudeClientVersion.pinnedVersion,
      );

  static bool _isNewerValidVersion(String value) {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) return false;
    final candidate = value.split('.').map(int.parse).toList();
    final pinned = AgentRouterClaudeClientVersion.pinnedVersion
        .split('.')
        .map(int.parse)
        .toList();
    for (var i = 0; i < 3; i++) {
      if (candidate[i] != pinned[i]) return candidate[i] > pinned[i];
    }
    return false;
  }
}
