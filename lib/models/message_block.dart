import 'package:flutter/foundation.dart';
import 'tool_call.dart' show ToolCallStatus;

@immutable
sealed class MessageBlock {
  const MessageBlock();
  Map<String, dynamic> toMap();

  factory MessageBlock.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    return switch (type) {
      'text' => TextBlock.fromMap(map),
      'reasoning' => ReasoningBlock.fromMap(map),
      'tool_call' => ToolCallBlock.fromMap(map),
      'error' => ErrorBlock.fromMap(map),
      _ => UnknownMessageBlock(map),
    };
  }

  static List<MessageBlock> fromJsonList(List<dynamic> raw) {
    return raw
        .map((e) => MessageBlock.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// A block introduced by a newer protocol or app version.
///
/// Unknown blocks are retained as data so an older Stroom version can load and
/// save a conversation without converting protocol content into display text.
class UnknownMessageBlock extends MessageBlock {
  final Map<String, dynamic> raw;

  UnknownMessageBlock(Map<String, dynamic> raw)
    : raw = Map<String, dynamic>.unmodifiable(raw);

  @override
  Map<String, dynamic> toMap() => Map<String, dynamic>.from(raw);
}

class TextBlock extends MessageBlock {
  final String text;
  final Map<String, dynamic> extraFields;
  const TextBlock({required this.text, this.extraFields = const {}});
  factory TextBlock.fromMap(Map<String, dynamic> map) => TextBlock(
    text: (map['text'] as String?) ?? '',
    extraFields: _extraFields(map, const {'type', 'text'}),
  );
  @override
  Map<String, dynamic> toMap() => {
    ...extraFields,
    'type': 'text',
    'text': text,
  };
}

class ReasoningBlock extends MessageBlock {
  final String text;
  final bool isComplete;
  final Map<String, dynamic> extraFields;
  const ReasoningBlock({
    required this.text,
    this.isComplete = false,
    this.extraFields = const {},
  });
  factory ReasoningBlock.fromMap(Map<String, dynamic> map) => ReasoningBlock(
    text: (map['text'] as String?) ?? '',
    isComplete: (map['isComplete'] as bool?) ?? false,
    extraFields: _extraFields(map, const {'type', 'text', 'isComplete'}),
  );
  @override
  Map<String, dynamic> toMap() => {
    ...extraFields,
    'type': 'reasoning',
    'text': text,
    'isComplete': isComplete,
  };
  ReasoningBlock append(String more, {bool? isComplete}) => ReasoningBlock(
    text: text + more,
    isComplete: isComplete ?? this.isComplete,
    extraFields: extraFields,
  );
}

class ToolCallBlock extends MessageBlock {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final ToolCallStatus status;
  final String? result;

  /// 工具结果被 prune 的时间戳（软删除标记）。
  /// 非 null 时 [result] 已被替换为占位文本。
  final DateTime? compactedAt;
  final Map<String, dynamic> extraFields;

  const ToolCallBlock({
    required this.id,
    required this.name,
    this.arguments = const {},
    this.status = ToolCallStatus.pending,
    this.result,
    this.compactedAt,
    this.extraFields = const {},
  });

  factory ToolCallBlock.fromMap(Map<String, dynamic> map) {
    final args = map['arguments'];
    DateTime? compactedAt;
    final compactedRaw = map['compactedAt'];
    if (compactedRaw is String) {
      try {
        compactedAt = DateTime.parse(compactedRaw);
      } catch (_) {
        compactedAt = null;
      }
    }
    return ToolCallBlock(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      arguments: args is Map ? Map<String, dynamic>.from(args) : const {},
      status: _parseStatus(map['status'] as String?),
      result: map['result'] as String?,
      compactedAt: compactedAt,
      extraFields: _extraFields(map, const {
        'type',
        'id',
        'name',
        'arguments',
        'status',
        'result',
        'compactedAt',
      }),
    );
  }

  static ToolCallStatus _parseStatus(String? s) => switch (s) {
    'running' => ToolCallStatus.running,
    'completed' => ToolCallStatus.completed,
    'error' => ToolCallStatus.error,
    _ => ToolCallStatus.pending,
  };

  @override
  Map<String, dynamic> toMap() => {
    ...extraFields,
    'type': 'tool_call',
    'id': id,
    'name': name,
    'arguments': arguments,
    'status': status.name,
    if (result != null) 'result': result,
    if (compactedAt != null) 'compactedAt': compactedAt!.toIso8601String(),
  };

  ToolCallBlock copyWith({
    ToolCallStatus? status,
    String? result,
    DateTime? compactedAt,
  }) => ToolCallBlock(
    id: id,
    name: name,
    arguments: Map.from(arguments),
    status: status ?? this.status,
    result: result ?? this.result,
    compactedAt: compactedAt ?? this.compactedAt,
    extraFields: extraFields,
  );
}

class ErrorBlock extends MessageBlock {
  final String message;
  final Map<String, dynamic> extraFields;
  const ErrorBlock({required this.message, this.extraFields = const {}});
  factory ErrorBlock.fromMap(Map<String, dynamic> map) => ErrorBlock(
    message: (map['message'] as String?) ?? map.toString(),
    extraFields: _extraFields(map, const {'type', 'message'}),
  );
  @override
  Map<String, dynamic> toMap() => {
    ...extraFields,
    'type': 'error',
    'message': message,
  };
}

Map<String, dynamic> _extraFields(
  Map<String, dynamic> map,
  Set<String> knownFields,
) => Map<String, dynamic>.fromEntries(
  map.entries.where((entry) => !knownFields.contains(entry.key)),
);
