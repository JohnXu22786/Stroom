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
      _ => ErrorBlock(message: 'Unknown block type: $type'),
    };
  }

  static List<MessageBlock> fromJsonList(List<dynamic> raw) {
    return raw
        .map((e) => MessageBlock.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}

class TextBlock extends MessageBlock {
  final String text;
  const TextBlock({required this.text});
  factory TextBlock.fromMap(Map<String, dynamic> map) =>
      TextBlock(text: (map['text'] as String?) ?? '');
  @override
  Map<String, dynamic> toMap() => {'type': 'text', 'text': text};
}

class ReasoningBlock extends MessageBlock {
  final String text;
  final bool isComplete;
  const ReasoningBlock({required this.text, this.isComplete = false});
  factory ReasoningBlock.fromMap(Map<String, dynamic> map) => ReasoningBlock(
        text: (map['text'] as String?) ?? '',
        isComplete: (map['isComplete'] as bool?) ?? false,
      );
  @override
  Map<String, dynamic> toMap() => {
        'type': 'reasoning',
        'text': text,
        'isComplete': isComplete,
      };
  ReasoningBlock append(String more, {bool? isComplete}) => ReasoningBlock(
        text: text + more,
        isComplete: isComplete ?? this.isComplete,
      );
}

class ToolCallBlock extends MessageBlock {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final ToolCallStatus status;
  final String? result;

  const ToolCallBlock({
    required this.id,
    required this.name,
    this.arguments = const {},
    this.status = ToolCallStatus.pending,
    this.result,
  });

  factory ToolCallBlock.fromMap(Map<String, dynamic> map) {
    final args = map['arguments'];
    return ToolCallBlock(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      arguments: args is Map ? Map<String, dynamic>.from(args) : const {},
      status: _parseStatus(map['status'] as String?),
      result: map['result'] as String?,
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
        'type': 'tool_call',
        'id': id,
        'name': name,
        'arguments': arguments,
        'status': status.name,
        if (result != null) 'result': result,
      };

  ToolCallBlock copyWith({ToolCallStatus? status, String? result}) =>
      ToolCallBlock(
        id: id,
        name: name,
        arguments: Map.from(arguments),
        status: status ?? this.status,
        result: result ?? this.result,
      );
}

class ErrorBlock extends MessageBlock {
  final String message;
  const ErrorBlock({required this.message});
  factory ErrorBlock.fromMap(Map<String, dynamic> map) =>
      ErrorBlock(message: (map['message'] as String?) ?? map.toString());
  @override
  Map<String, dynamic> toMap() => {'type': 'error', 'message': message};
}
