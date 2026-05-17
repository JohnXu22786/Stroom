import 'package:uuid/uuid.dart';

/// 简化的聊天消息模型，仅用于持久化到 SharedPreferences
/// UI 层使用 flutter_chat_ui 的 Message 类型
class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String?,
        role: (map['role'] as String?) ?? '',
        content: (map['content'] as String?) ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
      );

  @override
  String toString() => 'ChatMessage(id: $id, role: $role)';
}
