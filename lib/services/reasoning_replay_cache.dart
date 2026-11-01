import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Bounded, process-local replay of reasoning text actually returned by an
/// upstream. Portable and opaque entries have independent capacity bounds;
/// transcript content is represented only by a digest in cache keys.
class ReasoningReplayCache {
  static const defaultCapacity = 128;
  static const defaultTtl = Duration(hours: 1);

  final int capacity;
  final Duration ttl;
  final DateTime Function() _clock;
  final LinkedHashMap<String, _PortableReasoningEntry> _portableEntries =
      LinkedHashMap();
  final LinkedHashMap<String, _OpaqueReplayEntry> _opaqueEntries =
      LinkedHashMap();

  ReasoningReplayCache({
    this.capacity = defaultCapacity,
    this.ttl = defaultTtl,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        assert(capacity > 0),
        assert(ttl > Duration.zero);

  int get length {
    _prune();
    return _portableEntries.length + _opaqueEntries.length;
  }

  void remember({
    required String accountId,
    required String providerId,
    required String executorFamilyId,
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
    final hasPortableReasoning = reasoning.trim().isNotEmpty;
    final hasResponsesReasoning = returnedResponsesOutputItems.any(
      (item) => item['type'] == 'reasoning',
    );
    final hasOpaqueReplay =
        returnedToolSignatures.isNotEmpty || hasResponsesReasoning;
    if ((!hasPortableReasoning && !hasOpaqueReplay) ||
        accountId.isEmpty ||
        providerId.isEmpty ||
        executorFamilyId.isEmpty ||
        executorId.isEmpty ||
        modelId.isEmpty ||
        sessionId.isEmpty ||
        protocolId.isEmpty ||
        requestMessages.isEmpty) {
      return;
    }
    _prune();
    final transcriptHash = transcriptDigest(requestMessages);
    final assistantTurnHash = _assistantTurnDigest(returnedAssistantTurn);
    final createdAt = _clock().toUtc();
    if (hasPortableReasoning) {
      final key = _portableKey(
        providerId: providerId,
        executorFamilyId: executorFamilyId,
        modelId: modelId,
        sessionId: sessionId,
        protocolId: protocolId,
        transcriptDigest: transcriptHash,
        assistantTurnDigest: assistantTurnHash,
      );
      _portableEntries.remove(key);
      _portableEntries[key] = _PortableReasoningEntry(reasoning, createdAt);
      while (_portableEntries.length > capacity) {
        _portableEntries.remove(_portableEntries.keys.first);
      }
    }
    if (hasOpaqueReplay) {
      final key = _opaqueKey(
        accountId: accountId,
        providerId: providerId,
        executorId: executorId,
        modelId: modelId,
        sessionId: sessionId,
        protocolId: protocolId,
        transcriptDigest: transcriptHash,
        assistantTurnDigest: assistantTurnHash,
      );
      _opaqueEntries.remove(key);
      _opaqueEntries[key] = _OpaqueReplayEntry(
        Map.unmodifiable(returnedToolSignatures),
        [
          for (final item in returnedResponsesOutputItems)
            Map.unmodifiable(item),
        ],
        createdAt,
      );
      while (_opaqueEntries.length > capacity) {
        _opaqueEntries.remove(_opaqueEntries.keys.first);
      }
    }
  }

  /// Returns copies of assistant messages with a matching source-returned
  /// reasoning segment restored. Plain text replay uses the provider/executor
  /// family and visible turn scope; opaque payloads additionally require the
  /// exact source account and executor instance.
  List<Map<String, dynamic>> restore({
    required String accountId,
    required String providerId,
    required String executorFamilyId,
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
      final portableEntry = _readRecent(
        _portableEntries,
        _portableKey(
          providerId: providerId,
          executorFamilyId: executorFamilyId,
          modelId: modelId,
          sessionId: sessionId,
          protocolId: protocolId,
          transcriptDigest: digest,
          assistantTurnDigest: assistantTurnDigest,
        ),
      );
      final opaqueEntry = _readRecent(
        _opaqueEntries,
        _opaqueKey(
          accountId: accountId,
          providerId: providerId,
          executorId: executorId,
          modelId: modelId,
          sessionId: sessionId,
          protocolId: protocolId,
          transcriptDigest: digest,
          assistantTurnDigest: assistantTurnDigest,
        ),
      );
      if (portableEntry != null) {
        message['reasoning_content'] = portableEntry.reasoning;
      }
      if (opaqueEntry == null) continue;
      if (protocolId == 'openai.responses' &&
          opaqueEntry.responsesOutputItems.isNotEmpty) {
        message['stroom.responsesOutputItems'] = [
          for (final item in opaqueEntry.responsesOutputItems)
            Map<String, dynamic>.from(item),
        ];
      }
      final restoredCalls = message['tool_calls'];
      if (restoredCalls is List) {
        message['tool_calls'] = [
          for (final raw in restoredCalls)
            if (raw is Map)
              _restoreToolCallSignature(raw, opaqueEntry.toolSignatures)
            else
              raw,
        ];
      }
      final restoredContent = message['content'];
      final thinkingSignature = opaqueEntry.toolSignatures['__thinking__'];
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
    return '__function_call__${jsonEncode(_canonicalize({
          'name': name,
          'arguments': normalizedArguments
        }))}';
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

  void clear() {
    _portableEntries.clear();
    _opaqueEntries.clear();
  }

  void _prune() {
    final now = _clock().toUtc();
    _portableEntries.removeWhere(
      (_, entry) => now.difference(entry.createdAt) > ttl,
    );
    _opaqueEntries.removeWhere(
      (_, entry) => now.difference(entry.createdAt) > ttl,
    );
  }

  T? _readRecent<T extends _TimedEntry>(
    LinkedHashMap<String, T> entries,
    String key,
  ) {
    final entry = entries.remove(key);
    if (entry == null || _clock().toUtc().difference(entry.createdAt) > ttl) {
      return null;
    }
    entries[key] = entry;
    return entry;
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

  static String _portableKey({
    required String providerId,
    required String executorFamilyId,
    required String modelId,
    required String sessionId,
    required String protocolId,
    required String transcriptDigest,
    required String assistantTurnDigest,
  }) =>
      jsonEncode([
        'portable',
        providerId,
        executorFamilyId,
        modelId,
        sessionId,
        protocolId,
        transcriptDigest,
        assistantTurnDigest,
      ]);

  static String _opaqueKey({
    required String accountId,
    required String providerId,
    required String executorId,
    required String modelId,
    required String sessionId,
    required String protocolId,
    required String transcriptDigest,
    required String assistantTurnDigest,
  }) =>
      jsonEncode([
        'opaque',
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

abstract interface class _TimedEntry {
  DateTime get createdAt;
}

class _PortableReasoningEntry implements _TimedEntry {
  const _PortableReasoningEntry(this.reasoning, this.createdAt);

  final String reasoning;
  @override
  final DateTime createdAt;
}

class _OpaqueReplayEntry implements _TimedEntry {
  const _OpaqueReplayEntry(
    this.toolSignatures,
    this.responsesOutputItems,
    this.createdAt,
  );

  final Map<String, String> toolSignatures;
  final List<Map<String, dynamic>> responsesOutputItems;
  @override
  final DateTime createdAt;
}
