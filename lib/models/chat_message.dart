import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final bool isStreaming;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.isStreaming = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? createdAt,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'isStreaming': isStreaming,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: (map['id'] as String?) ?? const Uuid().v4(),
        role: (map['role'] as String?) ?? '',
        content: map['content'] as String? ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        isStreaming: map['isStreaming'] as bool? ?? false,
      );

  @override
  String toString() =>
      'ChatMessage(id: $id, role: $role, isStreaming: $isStreaming)';
}
