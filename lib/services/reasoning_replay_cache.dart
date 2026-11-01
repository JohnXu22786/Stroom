import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Bounded, process-local replay of reasoning text actually returned by an
/// upstream. Transcript content is represented only by a digest in cache keys.
class ReasoningReplayCache {
  static const defaultCapacity = 128;
  static const defaultTtl = Duration(hours: 1);

  final int capacity;
  final Duration ttl;
  final DateTime Function() _clock;
  final LinkedHashMap<String, _ReplayEntry> _entries = LinkedHashMap();

  ReasoningReplayCache({
    this.capacity = defaultCapacity,
    this.ttl = defaultTtl,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       assert(capacity > 0),
       assert(ttl > Duration.zero);

  int get length {
    _prune();
    return _entries.length;
  }

  void remember({
    required String accountId,
    required String providerId,
    required String executorId,
    required String modelId,
    required String sessionId,
    required String protocolId,
    required List<Map<String, dynamic>> requestMessages,
    required Map<String, dynamic> returnedAssistantTurn,
    String returnedReasoning = '',
    Map<String, String> returnedToolSignatures = const {},
    List<Map<String, dynamic>> returnedResponsesOutputItems = const [],
  }) {
    final reasoning = returnedReasoning;
    final hasResponsesReasoning = returnedResponsesOutputItems.any(
      (item) => item['type'] == 'reasoning',
    );
    if ((reasoning.trim().isEmpty &&
            returnedToolSignatures.isEmpty &&
            !hasResponsesReasoning) ||
        accountId.isEmpty ||
        providerId.isEmpty ||
        executorId.isEmpty ||
        modelId.isEmpty ||
        sessionId.isEmpty ||
        protocolId.isEmpty ||
        requestMessages.isEmpty) {
      return;
    }
    _prune();
    final key = _key(
      accountId: accountId,
      providerId: providerId,
      executorId: executorId,
      modelId: modelId,
      sessionId: sessionId,
      protocolId: protocolId,
      transcriptDigest: transcriptDigest(requestMessages),
      assistantTurnDigest: _assistantTurnDigest(returnedAssistantTurn),
    );
    _entries.remove(key);
    _entries[key] = _ReplayEntry(
      reasoning,
      Map.unmodifiable(returnedToolSignatures),
      [for (final item in returnedResponsesOutputItems) Map.unmodifiable(item)],
      _clock().toUtc(),
    );
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Returns copies of assistant messages with a matching source-returned
  /// reasoning segment restored. A hit requires the exact prior transcript
  /// prefix and the same account, provider, model, session, and protocol.
  List<Map<String, dynamic>> restore({
    required String accountId,
    required String providerId,
    required String executorId,
    required String modelId,
    required String sessionId,
    required String protocolId,
    required List<Map<String, dynamic>> requestMessages,
  }) {
    _prune();
    final restored = [
      for (final message in requestMessages) Map<String, dynamic>.from(message),
    ];
    for (var index = 0; index < restored.length; index++) {
      final message = restored[index];
      if (message['role'] != 'assistant') continue;
      message.remove('reasoning_content');
      message.remove('stroom.responsesOutputItems');
      message.remove('stroom.reasoningSignature');
      final calls = message['tool_calls'];
      if (calls is List) {
        message['tool_calls'] = [
          for (final raw in calls)
            if (raw is Map)
              {
                for (final field in raw.entries)
                  if (field.key != 'thoughtSignature')
                    field.key.toString(): field.value,
              }
            else
              raw,
        ];
      }
      final content = message['content'];
      if (content is List) {
        message['content'] = [
          for (final raw in content)
            if (raw is! Map ||
                (raw['type'] != 'thinking' && raw['type'] != 'reasoning'))
              raw,
        ];
      }
      final digest = transcriptDigest(requestMessages.take(index).toList());
      final assistantTurnDigest = _assistantTurnDigest(message);
      final key = _key(
        accountId: accountId,
        providerId: providerId,
        executorId: executorId,
        modelId: modelId,
        sessionId: sessionId,
        protocolId: protocolId,
        transcriptDigest: digest,
        assistantTurnDigest: assistantTurnDigest,
      );
      final entry = _entries.remove(key);
      if (entry == null || _clock().toUtc().difference(entry.createdAt) > ttl) {
        continue;
      }
      _entries[key] = entry;
      if (entry.reasoning.isNotEmpty) {
        message['reasoning_content'] = entry.reasoning;
      }
      if (protocolId == 'openai.responses' &&
          entry.responsesOutputItems.isNotEmpty) {
        message['stroom.responsesOutputItems'] = [
          for (final item in entry.responsesOutputItems)
            Map<String, dynamic>.from(item),
        ];
      }
      final restoredCalls = message['tool_calls'];
      if (restoredCalls is List) {
        message['tool_calls'] = [
          for (final raw in restoredCalls)
            if (raw is Map)
              _restoreToolCallSignature(raw, entry.toolSignatures)
            else
              raw,
        ];
      }
      final restoredContent = message['content'];
      final thinkingSignature = entry.toolSignatures['__thinking__'];
      if (thinkingSignature != null) {
        message['stroom.reasoningSignature'] = thinkingSignature;
      }
      if (restoredContent is List && thinkingSignature != null) {
        final firstThinking = restoredContent.indexWhere(
          (part) => part is Map && part['type'] == 'thinking',
        );
        if (firstThinking >= 0) {
          final part = Map<String, dynamic>.from(
            restoredContent[firstThinking] as Map,
          )..['signature'] = thinkingSignature;
          restoredContent[firstThinking] = part;
        }
      }
    }
    return restored;
  }

  static Map<String, dynamic> _restoreToolCallSignature(
    Map raw,
    Map<String, String> signatures,
  ) {
    final function = raw['function'];
    final functionSignature = function is Map
        ? signatures[functionCallSignatureKey(
            name: function['name'] as String?,
            arguments: function['arguments'],
          )]
        : null;
    final id = raw['id'];
    final signature =
        (id is String ? signatures[id] : null) ?? functionSignature;
    return {
      for (final field in raw.entries)
        if (field.key != 'thoughtSignature') field.key.toString(): field.value,
      ...?signature == null ? null : {'thoughtSignature': signature},
    };
  }

  static String functionCallSignatureKey({
    required String? name,
    required Object? arguments,
  }) {
    Object? normalizedArguments = arguments;
    if (arguments is String) {
      try {
        normalizedArguments = jsonDecode(arguments);
      } on FormatException {
        // Keep malformed arguments distinct as their original string.
      }
    }
    return '__function_call__${jsonEncode(_canonicalize({'name': name, 'arguments': normalizedArguments}))}';
  }

  static String _assistantTurnDigest(Map<String, dynamic> message) => sha256
      .convert(
        utf8.encode(
          jsonEncode(
            _canonicalize({
              'content': _normalizedVisibleContent(message['content']),
              'tool_calls': [
                if (message['tool_calls'] is List)
                  for (final raw in message['tool_calls'] as List)
                    if (raw is Map) _normalizedToolCall(raw),
              ],
            }),
          ),
        ),
      )
      .toString();

  static Map<String, dynamic> _normalizedToolCall(Map raw) {
    final function = raw['function'];
    if (function is! Map) return {'source': _canonicalize(raw)};
    return {
      'name': function['name'],
      'arguments': _normalizeArguments(function['arguments']),
    };
  }

  static Object? _normalizedVisibleContent(Object? content) {
    if (content is! List) return content;
    return [
      for (final part in content)
        if (part is! Map ||
            (part['type'] != 'thinking' && part['type'] != 'reasoning'))
          _canonicalize(part),
    ];
  }

  static Object? _normalizeArguments(Object? arguments) {
    if (arguments is! String) return arguments;
    try {
      return jsonDecode(arguments);
    } on FormatException {
      return arguments;
    }
  }

  void clear() => _entries.clear();

  void _prune() {
    final now = _clock().toUtc();
    _entries.removeWhere((_, entry) => now.difference(entry.createdAt) > ttl);
  }

  static String transcriptDigest(List<Map<String, dynamic>> messages) => sha256
      .convert(utf8.encode(jsonEncode(_canonicalize(messages))))
      .toString();

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonicalize(value[key])};
    }
    if (value is List) return value.map(_canonicalize).toList(growable: false);
    return value;
  }

  static String _key({
    required String accountId,
    required String providerId,
    required String executorId,
    required String modelId,
    required String sessionId,
    required String protocolId,
    required String transcriptDigest,
    required String assistantTurnDigest,
  }) => jsonEncode([
    accountId,
    providerId,
    executorId,
    modelId,
    sessionId,
    protocolId,
    transcriptDigest,
    assistantTurnDigest,
  ]);
}

class _ReplayEntry {
  const _ReplayEntry(
    this.reasoning,
    this.toolSignatures,
    this.responsesOutputItems,
    this.createdAt,
  );

  final String reasoning;
  final Map<String, String> toolSignatures;
  final List<Map<String, dynamic>> responsesOutputItems;
  final DateTime createdAt;
}
