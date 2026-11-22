import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';

import '../models/llm_account.dart';

const _zedWebBase = 'https://zed.dev';
const _zedCloudBase = 'https://cloud.zed.dev';
const _zedInferenceTokenLifetime = Duration(minutes: 3);

bool zedHostedInferenceTokenRejected(
  int? status,
  Map<String, List<String>> headers,
) {
  if (status == 401) return true;
  final normalized = {
    for (final entry in headers.entries) entry.key.toLowerCase(): entry.value,
  };
  return (normalized['x-zed-expired-token']?.isNotEmpty ?? false) ||
      (normalized['x-zed-outdated-token']?.isNotEmpty ?? false);
}

class ZedHostedAuthorizationException implements Exception {
  const ZedHostedAuthorizationException();

  @override
  String toString() => 'Zed authorization could not be completed.';
}

class ZedHostedUnsupportedRequest implements Exception {
  final String reason;

  const ZedHostedUnsupportedRequest(this.reason);

  @override
  String toString() => reason;
}

class ZedHostedStreamException implements Exception {
  const ZedHostedStreamException();

  @override
  String toString() => 'Zed upstream stream failed.';
}

class ZedHostedCallbackCredentials {
  final String userId;
  final String accessToken;
  final String systemId;

  const ZedHostedCallbackCredentials({
    required this.userId,
    required this.accessToken,
    required this.systemId,
  });

  Map<String, dynamic> toCredentialBundle({
    String? email,
    String? name,
    String? organizationId,
  }) =>
      {
        'oauth_contract': 'zed-hosted-native-rsa-v1',
        'access_token': accessToken,
        'user_id': userId,
        'system_id': systemId,
        ...?(email == null ? null : {'email': email}),
        ...?(name == null ? null : {'name': name}),
        if (organizationId != null && organizationId.isNotEmpty)
          'organization_id': organizationId,
      };
}

/// One-use Zed native sign-in attempt. The private key is never serialized and
/// is discarded as soon as a callback succeeds, fails validation, or is
/// cancelled.
class ZedHostedAuthorizationAttempt {
  final Uri authorizationUri;
  final Uri _callbackUri;
  final String systemId;
  final RSAPublicKey publicKey;
  RSAPrivateKey? _privateKey;
  bool _consumed = false;

  ZedHostedAuthorizationAttempt._({
    required this.authorizationUri,
    required Uri callbackUri,
    required this.systemId,
    required this.publicKey,
    required RSAPrivateKey privateKey,
  })  : _callbackUri = callbackUri,
        _privateKey = privateKey;

  factory ZedHostedAuthorizationAttempt.create({
    required Uri callbackUri,
    String? systemId,
  }) {
    if (callbackUri.scheme != 'http' ||
        !_isLoopbackHost(callbackUri.host) ||
        callbackUri.port <= 0 ||
        callbackUri.path != '/' ||
        callbackUri.hasQuery ||
        callbackUri.hasFragment ||
        callbackUri.userInfo.isNotEmpty) {
      throw const ZedHostedAuthorizationException();
    }
    final keyGenerator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          _secureRandom(),
        ),
      );
    final pair = keyGenerator.generateKeyPair();
    final publicKey = pair.publicKey;
    final privateKey = pair.privateKey;
    final resolvedSystemId = systemId ?? const Uuid().v4();
    if (resolvedSystemId.trim().isEmpty) {
      throw const ZedHostedAuthorizationException();
    }
    final publicKeyDer = ASN1Sequence(elements: [
      ASN1Integer(publicKey.modulus),
      ASN1Integer(publicKey.publicExponent),
    ]).encode();
    final signIn = Uri.parse('$_zedWebBase/native_app_signin').replace(
      queryParameters: {
        'native_app_port': callbackUri.port.toString(),
        'native_app_public_key': base64Url.encode(publicKeyDer),
        'system_id': resolvedSystemId,
      },
    );
    return ZedHostedAuthorizationAttempt._(
      authorizationUri: signIn,
      callbackUri: callbackUri,
      systemId: resolvedSystemId,
      publicKey: publicKey,
      privateKey: privateKey,
    );
  }

  ZedHostedCallbackCredentials consumeCallback(Uri callback) {
    final key = _privateKey;
    if (_consumed || key == null) {
      throw const ZedHostedAuthorizationException();
    }
    _consumed = true;
    try {
      if (!_sameCallbackTarget(callback, _callbackUri)) {
        throw const ZedHostedAuthorizationException();
      }
      final query = callback.queryParametersAll;
      final users = query['user_id'];
      final encryptedValues = query['access_token'];
      if (query.containsKey('error') ||
          users == null ||
          users.length != 1 ||
          users.single.trim().isEmpty ||
          encryptedValues == null ||
          encryptedValues.length != 1 ||
          encryptedValues.single.trim().isEmpty) {
        throw const ZedHostedAuthorizationException();
      }
      final ciphertext = _decodeBase64Url(encryptedValues.single);
      final accessToken = _decryptZedToken(key, ciphertext);
      if (accessToken.trim().isEmpty) {
        throw const ZedHostedAuthorizationException();
      }
      return ZedHostedCallbackCredentials(
        userId: users.single,
        accessToken: accessToken,
        systemId: systemId,
      );
    } catch (_) {
      throw const ZedHostedAuthorizationException();
    } finally {
      _privateKey = null;
    }
  }

  void cancel() {
    _consumed = true;
    _privateKey = null;
  }
}

class ZedHostedIdentity {
  final String? email;
  final String? name;
  final String? organizationId;

  const ZedHostedIdentity({this.email, this.name, this.organizationId});
}

class ZedHostedApiClient {
  final Dio _dio;
  static final Map<String, ({String token, DateTime expiresAt})> _tokenCache =
      {};

  ZedHostedApiClient({Dio? dio}) : _dio = dio ?? _createDio();

  static Dio _createDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

  Future<ZedHostedIdentity> fetchIdentity(
    Map<String, dynamic> credentials, {
    CancelToken? cancelToken,
  }) async {
    final userId = _credentialString(credentials, const ['user_id', 'userId']);
    final accessToken =
        _credentialString(credentials, const ['access_token', 'accessToken']);
    final systemId =
        _credentialString(credentials, const ['system_id', 'systemId']);
    if (userId == null || accessToken == null || systemId == null) {
      throw const ZedHostedAuthorizationException();
    }
    final response = await _dio.get<Object?>(
      '$_zedCloudBase/client/users/me',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': '$userId $accessToken',
          'x-zed-system-id': systemId,
        },
        validateStatus: (_) => true,
      ),
      cancelToken: cancelToken,
    );
    final data = _objectMap(response.data);
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw const ZedHostedAuthorizationException();
    }
    final organizationId = _organizationId(credentials['organization_id']) ??
        _organizationId(credentials['organizationId']) ??
        _organizationId(data['default_organization_id']) ??
        _organizationId(data['defaultOrganizationId']) ??
        _firstOrganizationId(data['organizations']);
    return ZedHostedIdentity(
      email: _nonEmptyString(data['email'] ?? data['github_email']),
      name: _nonEmptyString(data['name'] ?? data['github_login']),
      organizationId: organizationId,
    );
  }

  Future<String> fetchInferenceToken(
    Map<String, dynamic> credentials, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final userId = _credentialString(credentials, const ['user_id', 'userId']);
    final accessToken =
        _credentialString(credentials, const ['access_token', 'accessToken']);
    final systemId =
        _credentialString(credentials, const ['system_id', 'systemId']);
    var organizationId = _organizationId(
      credentials['organization_id'] ?? credentials['organizationId'],
    );
    if (userId == null || accessToken == null || systemId == null) {
      throw const ZedHostedAuthorizationException();
    }
    organizationId ??=
        (await fetchIdentity(credentials, cancelToken: cancelToken))
            .organizationId;
    if (organizationId == null) throw const ZedHostedAuthorizationException();

    final cacheKey =
        _cacheKey(credentials, userId, accessToken, organizationId);
    final cached = _tokenCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        cached.expiresAt.isAfter(DateTime.now().toUtc())) {
      return cached.token;
    }
    _tokenCache.remove(cacheKey);
    final response = await _dio.post<Object?>(
      '$_zedCloudBase/client/llm_tokens',
      data: {'organization_id': organizationId},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          'Accept': 'application/json',
          'Authorization': '$userId $accessToken',
          'x-zed-system-id': systemId,
        },
        validateStatus: (_) => true,
      ),
      cancelToken: cancelToken,
    );
    final data = _objectMap(response.data);
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw const ZedHostedAuthorizationException();
    }
    final rawToken = data['token'];
    final token = rawToken is String
        ? rawToken
        : rawToken is List && rawToken.isNotEmpty
            ? rawToken.first.toString()
            : rawToken is Map
                ? _nonEmptyString(rawToken['value'])
                : null;
    if (token == null || token.trim().isEmpty) {
      throw const ZedHostedAuthorizationException();
    }
    _tokenCache[cacheKey] = (
      token: token,
      expiresAt: DateTime.now().toUtc().add(_zedInferenceTokenLifetime),
    );
    return token;
  }

  Future<List<LlmUpstreamModel>> fetchModels(
    Map<String, dynamic> credentials, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    var token = await fetchInferenceToken(
      credentials,
      forceRefresh: forceRefresh,
      cancelToken: cancelToken,
    );
    var didRetry = false;
    while (true) {
      final response = await _dio.get<Object?>(
        '$_zedCloudBase/models',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'x-zed-client-supports-x-ai': 'true',
          },
          validateStatus: (_) => true,
        ),
        cancelToken: cancelToken,
      );
      if (zedHostedInferenceTokenRejected(
        response.statusCode,
        response.headers.map,
      )) {
        final cacheAccountId =
            _credentialString(credentials, const ['account_id']) ??
                _credentialString(credentials, const ['user_id', 'userId']);
        if (cacheAccountId != null) clearAccountTokenCache(cacheAccountId);
        if (!didRetry) {
          didRetry = true;
          token = await fetchInferenceToken(
            credentials,
            forceRefresh: true,
            cancelToken: cancelToken,
          );
          continue;
        }
      }
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw const ZedHostedAuthorizationException();
      }
      final data = _objectMap(response.data);
      final rawModels = data['models'];
      if (rawModels is! List) return const [];
      final models = <LlmUpstreamModel>[];
      for (final raw in rawModels.whereType<Map>()) {
        final model = _mapHostedModel(Map<String, dynamic>.from(raw));
        if (model != null) models.add(model);
      }
      return models;
    }
  }

  static void clearTokenCache() => _tokenCache.clear();

  static void clearAccountTokenCache(String accountId) {
    _tokenCache.removeWhere((key, _) => key.startsWith('$accountId:'));
  }
}

/// Returns the source protocol selected by each hosted provider's own model
/// metadata. Unknown providers intentionally have no inferred protocol.
String? zedHostedApiProtocolForProvider(Object? provider) =>
    switch (provider?.toString().trim().toLowerCase()) {
      'anthropic' => 'anthropic.messages',
      'open_ai' || 'openai' => 'openai.responses',
      'google' || 'gemini' => 'google.gemini.generate_content',
      'x_ai' || 'xai' || 'x-ai' => 'openai.chat_completions',
      _ => null,
    };

Map<String, dynamic> buildZedHostedCompletionEnvelope({
  required LlmUpstreamModel model,
  required Object? body,
  required String? nativeFormat,
  required bool stream,
  String? conversationId,
  String? promptId,
}) {
  final provider = _nonEmptyString(model.config['upstreamProvider']);
  final protocol = zedHostedApiProtocolForProvider(provider);
  if (provider == null || protocol == null) {
    throw const ZedHostedUnsupportedRequest(
      'This Zed model has no supported upstream provider metadata.',
    );
  }
  final nativeProtocol = switch (nativeFormat) {
    'anthropic' => 'anthropic.messages',
    'responses' => 'openai.responses',
    _ => nativeFormat,
  };
  final resolvedFormat = nativeProtocol ?? protocol;
  if (resolvedFormat != protocol) {
    throw const ZedHostedUnsupportedRequest(
      'The selected API protocol does not match this Zed model provider.',
    );
  }
  if (!stream) {
    throw const ZedHostedUnsupportedRequest(
      'Zed Hosted Models currently supports streaming chat only.',
    );
  }
  if (body is! Map) {
    throw const ZedHostedUnsupportedRequest('Invalid Zed chat request.');
  }
  final request = Map<String, dynamic>.from(body);
  final expectedField = switch (protocol) {
    'openai.responses' => 'input',
    'google.gemini.generate_content' => 'contents',
    _ => 'messages',
  };
  if (request[expectedField] is! List) {
    throw const ZedHostedUnsupportedRequest(
      'The selected request does not match the Zed model protocol.',
    );
  }
  final hasTools = _hasNonEmptyRequestField(
        request,
        const ['tools', 'functions', 'tool_calls', 'function_call'],
      ) ||
      _containsToolConversationItem(request['messages']) ||
      _containsToolConversationItem(request['input']) ||
      _containsToolConversationItem(request['contents']);
  if (hasTools && model.capabilities['toolCalls'] != true) {
    throw const ZedHostedUnsupportedRequest(
      'This Zed model does not support tool or function calls.',
    );
  }
  if (hasTools && model.capabilities['streamingTools'] != true) {
    throw const ZedHostedUnsupportedRequest(
      'This Zed model does not support streaming tool or function calls.',
    );
  }
  if (_containsUnsupportedMediaPayload(request)) {
    throw const ZedHostedUnsupportedRequest(
      'Audio, video, and file inputs are not supported by this connector.',
    );
  }
  if (_containsImagePayload(request) && model.capabilities['vision'] != true) {
    throw const ZedHostedUnsupportedRequest(
      'This Zed model does not support image input.',
    );
  }
  if (_containsThinkingRequest(request) &&
      model.capabilities['reasoning'] != true) {
    throw const ZedHostedUnsupportedRequest(
      'This Zed model does not support thinking controls.',
    );
  }
  return {
    'thread_id': conversationId?.trim().isNotEmpty == true
        ? conversationId!.trim()
        : const Uuid().v4(),
    'prompt_id': promptId?.trim().isNotEmpty == true
        ? promptId!.trim()
        : const Uuid().v4(),
    'provider': _zedWireProvider(provider),
    'model': model.upstreamModelId,
    'provider_request': request,
  };
}

Stream<List<int>> zedHostedCompletionEvents(Stream<List<int>> source) async* {
  var pending = <int>[];
  var finished = false;
  await for (final bytes in source) {
    pending.addAll(bytes);
    while (true) {
      final newline = pending.indexOf(10);
      if (newline < 0) break;
      final lineBytes = pending.sublist(0, newline);
      pending = pending.sublist(newline + 1);
      final line = utf8.decode(lineBytes, allowMalformed: true);
      final output = _zedEventLine(line);
      if (output == '[DONE]') {
        finished = true;
        yield utf8.encode('data: [DONE]\n\n');
      } else if (output != null) {
        yield utf8.encode('data: $output\n\n');
      }
    }
  }
  if (pending.isNotEmpty) {
    final output = _zedEventLine(utf8.decode(pending, allowMalformed: true));
    if (output == '[DONE]') {
      finished = true;
      yield utf8.encode('data: [DONE]\n\n');
    } else if (output != null) {
      yield utf8.encode('data: $output\n\n');
    }
  }
  if (!finished) yield utf8.encode('data: [DONE]\n\n');
}

String? _zedEventLine(String line) {
  var payload = line.trim();
  if (payload.isEmpty) return null;
  if (payload.startsWith('data:')) payload = payload.substring(5).trimLeft();
  if (payload == '[DONE]') return '[DONE]';
  Object? parsed;
  try {
    parsed = jsonDecode(payload);
  } on FormatException {
    return null;
  }
  if (parsed is! Map) return null;
  if (parsed.containsKey('status')) {
    final status = parsed['status'];
    final statusName = status is String
        ? status
        : status is Map && status.isNotEmpty
            ? status.keys.first.toString()
            : '';
    if (statusName == 'failed' || status is Map && status['failed'] != null) {
      throw const ZedHostedStreamException();
    }
    return statusName == 'stream_ended' ? '[DONE]' : null;
  }
  final event = parsed['event'] ?? parsed;
  if (event is! Map) return null;
  return jsonEncode(event);
}

LlmUpstreamModel? _mapHostedModel(Map<String, dynamic> raw) {
  final id = _nonEmptyString(raw['id']);
  if (id == null || raw['is_disabled'] == true || raw['isDisabled'] == true) {
    return null;
  }
  final provider = _nonEmptyString(raw['provider']);
  final protocol = zedHostedApiProtocolForProvider(provider);
  if (protocol == null) return null;
  final capabilities = <String, dynamic>{
    'chat': true,
    'streaming': true,
    if (raw['max_token_count'] is num) 'contextLength': raw['max_token_count'],
    if (raw['maxTokenCount'] is num) 'contextLength': raw['maxTokenCount'],
    if (raw['max_token_count_in_max_mode'] is num)
      'contextLengthInMaxMode': raw['max_token_count_in_max_mode'],
    if (raw['maxTokenCountInMaxMode'] is num)
      'contextLengthInMaxMode': raw['maxTokenCountInMaxMode'],
    if (raw['max_output_tokens'] is num)
      'maxOutputTokens': raw['max_output_tokens'],
    if (raw['maxOutputTokens'] is num)
      'maxOutputTokens': raw['maxOutputTokens'],
    if (raw['supports_tools'] is bool) ...{
      'toolCalls': raw['supports_tools'],
      'tools': raw['supports_tools'],
    },
    if (raw['supportsTools'] is bool) ...{
      'toolCalls': raw['supportsTools'],
      'tools': raw['supportsTools'],
    },
    if (raw['supports_images'] is bool) 'vision': raw['supports_images'],
    if (raw['supportsImages'] is bool) 'vision': raw['supportsImages'],
    if (raw['supports_thinking'] is bool) 'reasoning': raw['supports_thinking'],
    if (raw['supportsThinking'] is bool) 'reasoning': raw['supportsThinking'],
    if (raw['supports_disabling_thinking'] is bool)
      'supportsDisablingThinking': raw['supports_disabling_thinking'],
    if (raw['supportsDisablingThinking'] is bool)
      'supportsDisablingThinking': raw['supportsDisablingThinking'],
    if (raw['supports_fast_mode'] is bool)
      'supportsFastMode': raw['supports_fast_mode'],
    if (raw['supportsFastMode'] is bool)
      'supportsFastMode': raw['supportsFastMode'],
    if (raw['supported_effort_levels'] is List)
      'supportedEffortLevels': raw['supported_effort_levels'],
    if (raw['supportedEffortLevels'] is List)
      'supportedEffortLevels': raw['supportedEffortLevels'],
    if (raw['supports_streaming_tools'] is bool)
      'streamingTools': raw['supports_streaming_tools'],
    if (raw['supportsStreamingTools'] is bool)
      'streamingTools': raw['supportsStreamingTools'],
    if (raw['supports_parallel_tool_calls'] is bool)
      'parallelToolCalls': raw['supports_parallel_tool_calls'],
    if (raw['supportsParallelToolCalls'] is bool)
      'parallelToolCalls': raw['supportsParallelToolCalls'],
    'supportedApiProtocols': [protocol],
  };
  return LlmUpstreamModel(
    id: 'zed-hosted:$id',
    upstreamModelId: id,
    displayName:
        _nonEmptyString(raw['display_name'] ?? raw['displayName']) ?? id,
    capabilities: capabilities,
    config: {
      'upstreamProvider': provider!,
      'apiProtocolOverride': protocol,
      if (raw['is_latest'] is bool) 'isLatest': raw['is_latest'],
      if (raw['isLatest'] is bool) 'isLatest': raw['isLatest'],
      if (raw['disabled_reason'] != null)
        'disabledReason': raw['disabled_reason'],
    },
  );
}

String _zedWireProvider(String provider) =>
    switch (provider.trim().toLowerCase()) {
      'anthropic' => 'anthropic',
      'open_ai' || 'openai' => 'open_ai',
      'google' || 'gemini' => 'google',
      'x_ai' || 'xai' || 'x-ai' => 'x_ai',
      _ => throw const ZedHostedUnsupportedRequest(
          'This Zed model has no supported upstream provider metadata.',
        ),
    };

bool _hasNonEmptyRequestField(Map<String, dynamic> body, List<String> keys) =>
    keys.any((key) {
      final value = body[key];
      if (value is List) return value.isNotEmpty;
      if (value is Map) return value.isNotEmpty;
      return value != null && value != false && value != '';
    });

bool _containsToolConversationItem(Object? value) {
  if (value is Iterable) return value.any(_containsToolConversationItem);
  if (value is! Map) return false;
  if (value['role'] == 'tool' ||
      const {
        'function_call',
        'function_call_output',
        'functionCall',
        'functionResponse',
        'tool_call',
        'tool_call_output',
        'tool_result',
        'tool_use',
      }.contains(value['type'])) {
    return true;
  }
  for (final field in const [
    'tool_calls',
    'function_call',
    'functionCall',
    'functionResponse',
  ]) {
    final nested = value[field];
    if (nested != null &&
        nested != false &&
        nested != '' &&
        (nested is! Iterable || nested.isNotEmpty) &&
        (nested is! Map || nested.isNotEmpty)) {
      return true;
    }
  }
  return const ['content', 'parts'].any(
    (field) => _containsToolConversationItem(value[field]),
  );
}

bool _containsUnsupportedMediaPayload(Object? value) {
  if (value is List) return value.any(_containsUnsupportedMediaPayload);
  if (value is! Map) return false;
  for (final entry in value.entries) {
    final key = entry.key.toString().toLowerCase();
    final child = entry.value;
    if (const {
          'audio',
          'audio_url',
          'input_audio',
          'video',
          'video_url',
          'file',
          'file_url',
          'input_file',
          'filedata',
          'file_data',
          'files',
        }.contains(key) &&
        child != null &&
        child != '' &&
        (child is! List || child.isNotEmpty)) {
      return true;
    }
    if (key == 'type' &&
        child is String &&
        RegExp(r'(^|_)(audio|video|file)(_|$)', caseSensitive: false)
            .hasMatch(child)) {
      return true;
    }
    if ((key == 'mime_type' || key == 'mimetype') &&
        child is String &&
        (child.toLowerCase().startsWith('audio/') ||
            child.toLowerCase().startsWith('video/') ||
            child.toLowerCase() == 'application/pdf')) {
      return true;
    }
    if (_containsUnsupportedMediaPayload(child)) return true;
  }
  return false;
}

bool _containsImagePayload(Object? value) {
  if (value is List) return value.any(_containsImagePayload);
  if (value is! Map) return false;
  for (final entry in value.entries) {
    final key = entry.key.toString().toLowerCase();
    final child = entry.value;
    if (const {'images', 'image_url', 'inline_data', 'inlinedata'}
        .contains(key)) {
      return child != null &&
          child != '' &&
          (child is! List || child.isNotEmpty);
    }
    if (child is String &&
        (key == 'type' && child.toLowerCase().contains('image') ||
            key == 'mime_type' && child.toLowerCase().startsWith('image/'))) {
      return true;
    }
    if (_containsImagePayload(child)) return true;
  }
  return false;
}

bool _containsThinkingRequest(Object? value) {
  if (value is List) return value.any(_containsThinkingRequest);
  if (value is! Map) return false;
  for (final entry in value.entries) {
    final key = entry.key.toString().toLowerCase();
    if (const {
          'thinking',
          'thinking_config',
          'thinkingconfig',
          'reasoning',
          'reasoning_effort',
          'reasoningeffort',
        }.contains(key) &&
        entry.value != null &&
        entry.value != false &&
        entry.value != '' &&
        (entry.value is! List || entry.value.isNotEmpty)) {
      return true;
    }
    if (_containsThinkingRequest(entry.value)) return true;
  }
  return false;
}

String? _organizationId(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is Map) {
    final id = _nonEmptyString(value['id'] ?? value[0]);
    if (id != null) return id;
  }
  return null;
}

String? _firstOrganizationId(Object? value) {
  if (value is! List) return null;
  final organizations = value.whereType<Map>().toList();
  final personal = organizations.where((item) => item['is_personal'] == true);
  return _organizationId(
      (personal.isNotEmpty ? personal.first : organizations.firstOrNull));
}

String _cacheKey(
  Map<String, dynamic> credentials,
  String userId,
  String accessToken,
  String organizationId,
) {
  final accountId =
      _credentialString(credentials, const ['account_id']) ?? userId;
  final tokenDigest = sha256.convert(utf8.encode(accessToken)).toString();
  return '$accountId:$organizationId:$tokenDigest';
}

String? _credentialString(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? _nonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

Map<String, dynamic> _objectMap(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : value is String
        ? _tryDecodeMap(value)
        : <String, dynamic>{};

Map<String, dynamic> _tryDecodeMap(String value) {
  try {
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  } on FormatException {
    return {};
  }
}

Uint8List _decodeBase64Url(String value) {
  try {
    return Uint8List.fromList(base64Url.decode(base64Url.normalize(value)));
  } on FormatException {
    try {
      return Uint8List.fromList(base64.decode(base64.normalize(value)));
    } on FormatException {
      throw const ZedHostedAuthorizationException();
    }
  }
}

String _decryptZedToken(RSAPrivateKey key, Uint8List ciphertext) {
  try {
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(key));
    return utf8.decode(cipher.process(ciphertext));
  } catch (_) {
    try {
      final cipher = PKCS1Encoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(key));
      return utf8.decode(cipher.process(ciphertext));
    } catch (_) {
      throw const ZedHostedAuthorizationException();
    }
  }
}

SecureRandom _secureRandom() {
  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  );
  return FortunaRandom()..seed(KeyParameter(seed));
}

bool _sameCallbackTarget(Uri callback, Uri expected) =>
    callback.scheme == expected.scheme &&
    callback.host.toLowerCase() == expected.host.toLowerCase() &&
    callback.port == expected.port &&
    callback.path == expected.path &&
    callback.userInfo.isEmpty &&
    !callback.hasFragment;

bool _isLoopbackHost(String host) =>
    const {'127.0.0.1', 'localhost', '::1'}.contains(host.toLowerCase());
