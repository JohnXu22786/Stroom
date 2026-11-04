import 'dart:convert';

import 'package:dio/dio.dart';

/// Source-backed credential and text request mapping for the Trae SOLO API.
/// The pasted Cloud-IDE-JWT is not a refreshable OAuth credential.
class TraeSoloCredential {
  final String accessToken;
  final DateTime expiresAt;
  final Map<String, Object?> identity;

  const TraeSoloCredential({
    required this.accessToken,
    required this.expiresAt,
    required this.identity,
  });

  factory TraeSoloCredential.fromPastedValue(String value, {DateTime? now}) {
    var token = value.trim();
    DateTime? storedExpiry;
    Map<String, dynamic>? storedIdentity;
    if (token.startsWith('{')) {
      try {
        final stored = jsonDecode(token);
        if (stored is Map) {
          final rawToken = stored['access_token'] ?? stored['accessToken'];
          final rawExpiry = stored['expires_at'] ?? stored['expiresAt'];
          final rawIdentity =
              stored['providerSpecificData'] ?? stored['identity'];
          if (rawToken is String && rawToken.trim().isNotEmpty) {
            token = rawToken.trim();
            if (rawExpiry is String) {
              storedExpiry = DateTime.tryParse(rawExpiry);
              if (storedExpiry == null) {
                throw const FormatException('Invalid stored Trae expiry.');
              }
            }
            if (rawIdentity is Map) {
              storedIdentity = Map<String, dynamic>.from(rawIdentity);
            }
          }
        }
      } catch (_) {
        throw const FormatException('Invalid stored Trae credential.');
      }
    }
    if (token.startsWith('Cloud-IDE-JWT ')) {
      token = token.substring('Cloud-IDE-JWT '.length).trim();
    } else if (token.startsWith('Bearer ')) {
      throw const FormatException('Paste the Cloud-IDE-JWT value.');
    }
    final parts = token.split('.');
    if (token.isEmpty || parts.length != 3) {
      throw const FormatException('Invalid Cloud-IDE-JWT value.');
    }
    Map<String, dynamic> claims;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (decoded is! Map) throw const FormatException();
      claims = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const FormatException('Invalid Cloud-IDE-JWT value.');
    }
    final current = (now ?? DateTime.now()).toUtc();
    final exp = claims['exp'];
    final expiry =
        storedExpiry ??
        (exp is num
            ? DateTime.fromMillisecondsSinceEpoch(
                exp.toInt() * 1000,
                isUtc: true,
              )
            : current.add(const Duration(days: 14)));
    final identity = <String, Object?>{
      'webId': _claim(claims, const ['web_id', 'webId']),
      'bizUserId': _claim(claims, const ['biz_user_id', 'bizUserId']),
      'userUniqueId': _claim(claims, const ['user_unique_id', 'userUniqueId']),
      'scope': _claim(claims, const ['scope']) ?? 'marscode-us',
      'tenant': _claim(claims, const ['tenant']) ?? 'marscode',
      'region': _claim(claims, const ['region']) ?? 'US-East',
      'aiRegion':
          _claim(claims, const ['ai_region', 'aiRegion']) ??
          _claim(claims, const ['region']) ??
          'US-East',
      'appLanguage':
          _claim(claims, const ['app_language', 'appLanguage']) ?? 'en',
      'appVersion':
          _claim(claims, const ['app_version', 'appVersion']) ?? '1.0.0.1229',
      'userRegion': _claim(claims, const ['user_region', 'userRegion']) ?? 'US',
      'userTimezone': _claim(claims, const ['user_timezone', 'userTimezone']),
      'userIdentity':
          _claim(claims, const ['user_identity', 'userIdentity']) ?? 'Free',
    };
    if (storedIdentity != null) {
      for (final key in identity.keys.toList()) {
        final stored = storedIdentity[key];
        if (stored is String && stored.trim().isNotEmpty) {
          identity[key] = stored.trim();
        }
      }
    }
    identity.removeWhere((_, value) => value == null);
    return TraeSoloCredential(
      accessToken: token,
      expiresAt: expiry,
      identity: Map.unmodifiable(identity),
    );
  }

  String toStoredValue() => jsonEncode({
    'access_token': accessToken,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'providerSpecificData': identity,
  });

  static String? _claim(Map<String, dynamic> claims, List<String> names) {
    for (final name in names) {
      final value = claims[name];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

class TraeSoloConnector {
  static const defaultBaseUrl = 'https://core-normal.trae.ai/api/remote/v1';
  static const modelsPath =
      '/models?functions=solo_agent_remote,solo_work_remote';

  static Uri modelsUriFor(String baseUrl) =>
      Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$modelsPath');

  static Uri get modelsUri => modelsUriFor(defaultBaseUrl);

  static Map<String, dynamic> createSessionRequest({
    required String modelId,
    required List<dynamic> messages,
    required Map<String, Object?> identity,
  }) {
    final normalizedModel = modelId.trim().toLowerCase();
    final workMode = const {
      'work',
      'auto-work',
      'solo-work',
    }.contains(normalizedModel);
    final mode = workMode ? 'work' : 'code';
    final auto =
        workMode || normalizedModel.isEmpty || normalizedModel == 'auto';
    final text = <String>[];
    for (final raw in messages) {
      if (raw is! Map) throw const FormatException('Invalid text message.');
      final role = raw['role'];
      if (!const {'system', 'assistant', 'user'}.contains(role) ||
          raw['tool_calls'] != null ||
          raw['function_call'] != null) {
        throw const FormatException('Trae SOLO supports text messages only.');
      }
      final content = raw['content'];
      String value;
      if (content is String) {
        value = content;
      } else if (content is Iterable) {
        final parts = <String>[];
        for (final part in content) {
          if (part is String) {
            parts.add(part);
          } else if (part is Map && part['text'] is String) {
            parts.add(part['text'] as String);
          } else {
            throw const FormatException(
              'Trae SOLO supports text messages only.',
            );
          }
        }
        value = parts.join();
      } else {
        throw const FormatException('Trae SOLO supports text messages only.');
      }
      if (role == 'system') {
        text.add('[System]\n$value');
      } else if (role == 'assistant') {
        text.add('[Assistant]\n$value');
      } else {
        text.add(value);
      }
    }
    final commonParams = <String, Object?>{
      'language': 'en-us',
      'app_language': identity['appLanguage'] ?? 'en',
      'quality': 'stable',
      'app_version': identity['appVersion'] ?? '1.0.0.1229',
      'web_id': identity['webId'] ?? '',
      'user_identity': identity['userIdentity'] ?? 'Free',
      'is_freshman': '0',
      'biz_user_id': identity['bizUserId'] ?? '',
      'user_unique_id': identity['userUniqueId'] ?? '',
      'scope': identity['scope'] ?? 'marscode-us',
      'tenant': identity['tenant'] ?? 'marscode',
      'region': identity['region'] ?? 'US-East',
      'aiRegion': identity['aiRegion'] ?? identity['region'] ?? 'US-East',
      'is_privacy_mode': 0,
      'privacy_mode': 'off',
      'solo_chat_mode': mode,
    };
    return {
      'mode': mode,
      'environment_id': 'default',
      'initial_message': {
        'chat_session_id': '',
        'content': const [],
        'query': jsonEncode([
          {
            'type': 'text',
            'data': {'content': text.join('\n\n')},
          },
        ]),
        'model_name': workMode || auto ? '' : modelId,
        'agent_type': 'solo_agent_remote',
        'model_selection_strategy': auto ? 'auto' : 'manual',
        'common_params': jsonEncode(commonParams),
      },
      'env': 'remote',
      'auto_create_project': false,
      'origin': 'web',
    };
  }

  static Map<String, String> headers(TraeSoloCredential credential) {
    final origin = 'https://work.trae.ai';
    return {
      'Authorization': 'Cloud-IDE-JWT ${credential.accessToken}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Trae-Client-Type': 'web',
      'X-Preferenced-Language':
          (credential.identity['appLanguage'] as String?) ?? 'en',
      'x-user-region': (credential.identity['userRegion'] as String?) ?? 'US',
      'Referer': '$origin/',
      'Origin': origin,
      if (credential.identity['userTimezone'] is String)
        'x-trae-user-timezone': credential.identity['userTimezone']! as String,
    };
  }

  static List<Map<String, dynamic>> parseModels(Object? payload) {
    final root = payload is Map ? payload : null;
    final data = root?['data'];
    final raw = data is Map
        ? data['models'] ?? data['items'] ?? data['data']
        : data ?? root?['models'] ?? payload;
    if (raw is! Iterable) {
      throw const FormatException('Invalid Trae model catalog.');
    }
    final models = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['name'] ?? map['id'] ?? map['model_name'];
      if (id is! String || id.trim().isEmpty || map['chat'] == false) continue;
      models.add({
        'id': id.trim(),
        'displayName': (map['display_name'] is String)
            ? map['display_name']
            : (map['displayName'] is String ? map['displayName'] : id.trim()),
      });
    }
    return models;
  }
}

/// Adapts SOLO's cumulative plan_item text into distinct OpenAI chat deltas.
class TraeSoloEventMapper {
  final List<String> _order = [];
  final Map<String, String> _thoughts = {};
  int _sent = 0;
  bool isDone = false;
  Map<String, dynamic>? error;
  Map<String, dynamic>? usage;

  String accept(String? event, Map<String, dynamic> data) {
    if (event == 'error') {
      error = data;
      isDone = true;
      return '';
    }
    if (event == 'done') {
      isDone = true;
      return '';
    }
    if (event == 'token_usage') usage = data;
    if (event != 'plan_item') return '';
    final id = data['id'];
    final thought = data['thought'];
    if (id is! String || id.isEmpty || thought is! String) return '';
    if (!_thoughts.containsKey(id)) _order.add(id);
    if (thought.length >= (_thoughts[id]?.length ?? 0)) _thoughts[id] = thought;
    final full = _order.map((key) => _thoughts[key] ?? '').join();
    final delta = full.substring(_sent);
    _sent = full.length;
    return delta;
  }

  String get text => _order.map((key) => _thoughts[key] ?? '').join();
}

/// Runs the provider's session-create + events flow. Only plain text messages
/// are accepted; callers receive OpenAI-compatible JSON or SSE chunks.
class TraeSoloHttpAdapter {
  final Dio dio;

  const TraeSoloHttpAdapter(this.dio);

  Future<({int statusCode, Object body, Map<String, List<String>> headers})>
  request({
    required String baseUrl,
    required String credential,
    required String modelId,
    required List<dynamic> messages,
    required bool stream,
    required CancelToken? cancelToken,
    Future<void> Function()? onRequestSent,
  }) async {
    final parsed = TraeSoloCredential.fromPastedValue(credential);
    if (!parsed.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const TraeSoloAuthenticationException();
    }
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final headers = TraeSoloConnector.headers(parsed);
    final create = await dio.postUri<Object?>(
      Uri.parse('$base/chat_sessions'),
      data: TraeSoloConnector.createSessionRequest(
        modelId: modelId,
        messages: messages,
        identity: parsed.identity,
      ),
      options: Options(
        responseType: ResponseType.json,
        headers: headers,
        validateStatus: (status) => status != null,
      ),
      cancelToken: cancelToken,
    );
    final created = create.data;
    if ((create.statusCode ?? 0) < 200 || (create.statusCode ?? 0) >= 300) {
      throw TraeSoloHttpException(create.statusCode ?? 0);
    }
    await onRequestSent?.call();
    if (created is! Map || created['code'] != 0 || created['data'] is! Map) {
      throw const TraeSoloHttpException(502);
    }
    final data = created['data'] as Map;
    final sessionId = data['chat_session_id'];
    final messageId = data['message_id'];
    if (sessionId is! String ||
        sessionId.isEmpty ||
        messageId is! String ||
        messageId.isEmpty) {
      throw const TraeSoloHttpException(502);
    }
    final eventsUri = Uri.parse(
      '$base/chat_sessions/$sessionId/events',
    ).replace(queryParameters: {'reply_to_message_id': messageId});
    final events = await dio.getUri<Object?>(
      eventsUri,
      options: Options(
        responseType: ResponseType.stream,
        headers: {...headers, 'Accept': 'text/event-stream'},
        validateStatus: (status) => status != null,
        receiveTimeout: const Duration(minutes: 5),
      ),
      cancelToken: cancelToken,
    );
    final status = events.statusCode ?? 0;
    if (status < 200 || status >= 300 || events.data is! ResponseBody) {
      throw TraeSoloHttpException(status);
    }
    final source = (events.data as ResponseBody).stream;
    final mapper = TraeSoloEventMapper();
    final responseId = 'chatcmpl-trae-${DateTime.now().millisecondsSinceEpoch}';
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Stream<List<int>> chunks() async* {
      String? event;
      yield _sse({
        'id': responseId,
        'object': 'chat.completion.chunk',
        'created': createdAt,
        'model': modelId,
        'choices': [
          {
            'index': 0,
            'delta': {'role': 'assistant'},
            'finish_reason': null,
          },
        ],
      });
      await for (final rawLine
          in utf8.decoder.bind(source).transform(const LineSplitter())) {
        final line = rawLine.replaceFirst(RegExp(r'\r$'), '');
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final raw = line.substring(5).trim();
          Map<String, dynamic> parsedEvent;
          try {
            final decoded = jsonDecode(raw);
            parsedEvent = decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : <String, dynamic>{};
          } catch (_) {
            parsedEvent = const {};
          }
          final delta = mapper.accept(event, parsedEvent);
          if (delta.isNotEmpty) {
            yield _sse({
              'id': responseId,
              'object': 'chat.completion.chunk',
              'created': createdAt,
              'model': modelId,
              'choices': [
                {
                  'index': 0,
                  'delta': {'content': delta},
                  'finish_reason': null,
                },
              ],
            });
          }
          if (mapper.error != null) {
            throw const TraeSoloUpstreamException();
          }
          if (mapper.isDone) {
            yield _sse({
              'id': responseId,
              'object': 'chat.completion.chunk',
              'created': createdAt,
              'model': modelId,
              'choices': [
                {'index': 0, 'delta': {}, 'finish_reason': 'stop'},
              ],
            });
            if (mapper.usage != null) {
              final usage = mapper.usage!;
              yield _sse({
                'id': responseId,
                'object': 'chat.completion.chunk',
                'created': createdAt,
                'model': modelId,
                'choices': [],
                'usage': {
                  'prompt_tokens': usage['prompt_tokens'] ?? 0,
                  'completion_tokens': usage['completion_tokens'] ?? 0,
                  'total_tokens': usage['total_tokens'] ?? 0,
                },
              });
            }
            yield utf8.encode('data: [DONE]\n\n');
            return;
          }
        } else if (line.isEmpty) {
          event = null;
        }
      }
      if (!mapper.isDone) {
        throw const TraeSoloUpstreamException();
      }
    }

    if (stream) {
      return (statusCode: status, body: chunks(), headers: events.headers.map);
    }
    String? event;
    await for (final rawLine
        in utf8.decoder.bind(source).transform(const LineSplitter())) {
      final line = rawLine.replaceFirst(RegExp(r'\r$'), '');
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final raw = line.substring(5).trim();
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            mapper.accept(event, Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
        if (mapper.isDone) break;
      } else if (line.isEmpty) {
        event = null;
      }
    }
    if (mapper.error != null) {
      throw const TraeSoloUpstreamException();
    }
    if (!mapper.isDone) {
      throw const TraeSoloUpstreamException();
    }
    final result = {
      'id': responseId,
      'object': 'chat.completion',
      'created': createdAt,
      'model': modelId,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': mapper.text},
          'finish_reason': 'stop',
        },
      ],
      if (mapper.usage != null)
        'usage': {
          'prompt_tokens': mapper.usage!['prompt_tokens'] ?? 0,
          'completion_tokens': mapper.usage!['completion_tokens'] ?? 0,
          'total_tokens': mapper.usage!['total_tokens'] ?? 0,
        },
    };
    return (statusCode: status, body: result, headers: events.headers.map);
  }
}

List<int> _sse(Map<String, Object?> value) =>
    utf8.encode('data: ${jsonEncode(value)}\n\n');

class TraeSoloAuthenticationException implements Exception {
  const TraeSoloAuthenticationException();
}

class TraeSoloHttpException implements Exception {
  final int statusCode;
  const TraeSoloHttpException(this.statusCode);
}

class TraeSoloUpstreamException implements Exception {
  const TraeSoloUpstreamException();

  @override
  String toString() => 'Trae SOLO returned an upstream error event.';
}
