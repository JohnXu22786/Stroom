import 'package:uuid/uuid.dart';

/// 简化的聊天消息模型，仅用于持久化到 SharedPreferences
/// UI 层使用 flutter_chat_ui 的 Message 类型
class Attachment {
  final String id;
  final String fileName;
  final String mimeType;
  final String fileType;
  final String hash;
  final String storagePath;
  final int fileSize;
  final DateTime createdAt;
  final String? thumbnailPath;

  Attachment({
    String? id,
    required this.fileName,
    required this.mimeType,
    required this.fileType,
    required this.hash,
    required this.storagePath,
    required this.fileSize,
    DateTime? createdAt,
    this.thumbnailPath,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileType': fileType,
        'hash': hash,
        'storagePath': storagePath,
        'fileSize': fileSize,
        'createdAt': createdAt.toIso8601String(),
        if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
      };

  factory Attachment.fromMap(Map<String, dynamic> map) => Attachment(
        id: map['id'] as String?,
        fileName: (map['fileName'] as String?) ?? '',
        mimeType: (map['mimeType'] as String?) ?? '',
        fileType: (map['fileType'] as String?) ?? '',
        hash: (map['hash'] as String?) ?? '',
        storagePath: (map['storagePath'] as String?) ?? '',
        fileSize: (map['fileSize'] as int?) ?? 0,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
        thumbnailPath: map['thumbnailPath'] as String?,
      );

  Attachment copyWith({
    String? id,
    String? fileName,
    String? mimeType,
    String? fileType,
    String? hash,
    String? storagePath,
    int? fileSize,
    DateTime? createdAt,
    String? thumbnailPath,
  }) =>
      Attachment(
        id: id ?? this.id,
        fileName: fileName ?? this.fileName,
        mimeType: mimeType ?? this.mimeType,
        fileType: fileType ?? this.fileType,
        hash: hash ?? this.hash,
        storagePath: storagePath ?? this.storagePath,
        fileSize: fileSize ?? this.fileSize,
        createdAt: createdAt ?? this.createdAt,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );

  @override
  String toString() =>
      'Attachment(id: $id, fileName: $fileName, fileType: $fileType)';
}

class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;
  final List<Attachment> attachments;
  final bool isStreaming;
  final bool isError;
  final String? reasoningContent;
  final Map<String, dynamic>? rawRequest;
  final Map<String, dynamic>? rawResponse;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    List<Attachment>? attachments,
    this.isStreaming = false,
    this.isError = false,
    this.reasoningContent,
    this.rawRequest,
    this.rawResponse,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        attachments = attachments ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'attachments': attachments.map((a) => a.toMap()).toList(),
        if (isStreaming) 'isStreaming': true,
        if (isError) 'isError': true,
        if (reasoningContent != null) 'reasoningContent': reasoningContent,
        if (rawRequest != null) 'rawRequest': rawRequest,
        if (rawResponse != null) 'rawResponse': rawResponse,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    var roleStr = (map['role'] as String?) ?? '';
    if (roleStr != 'user' && roleStr != 'assistant') {
      roleStr = 'user';
    }
    return ChatMessage(
      id: map['id'] as String?,
      role: roleStr,
      content: (map['content'] as String?) ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      attachments: (map['attachments'] as List?)
              ?.map((e) =>
                  Attachment.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      isStreaming: map['isStreaming'] as bool? ?? false,
      isError: map['isError'] as bool? ?? false,
      reasoningContent: map['reasoningContent'] as String?,
      rawRequest: map['rawRequest'] as Map<String, dynamic>?,
      rawResponse: map['rawResponse'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'ChatMessage(id: $id, role: $role)';
}
