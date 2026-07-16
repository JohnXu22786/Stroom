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

  /// 缓存的文件 base64 数据（非持久化）。
  /// 文件上传时立即转换并缓存，发送时无需等待重复转换。
  /// 该字段不会被序列化到 toMap/fromMap，生命周期跟随内存中的 Conversation。
  String? base64Data;

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
    this.base64Data,
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
        // NOTE: base64Data is intentionally NOT serialized.
        // It is a transient in-memory cache tied to conversation lifecycle.
      };

  factory Attachment.fromMap(Map<String, dynamic> map) {
    // Defensive DateTime parsing
    DateTime? createdAt;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw != null && createdAtRaw is String) {
      try {
        createdAt = DateTime.parse(createdAtRaw);
      } catch (_) {
        createdAt = DateTime.now();
      }
    }

    return Attachment(
      id: map['id'] as String?,
      fileName: (map['fileName'] as String?) ?? '',
      mimeType: (map['mimeType'] as String?) ?? '',
      fileType: (map['fileType'] as String?) ?? '',
      hash: (map['hash'] as String?) ?? '',
      storagePath: (map['storagePath'] as String?) ?? '',
      fileSize: (map['fileSize'] as int?) ?? 0,
      createdAt: createdAt,
      thumbnailPath: map['thumbnailPath'] as String?,
    );
  }

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
    String? base64Data,
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
        base64Data: base64Data ?? this.base64Data,
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

    // Defensive DateTime parsing: invalid/null dates fall back to now
    DateTime? createdAt;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw != null && createdAtRaw is String) {
      try {
        createdAt = DateTime.parse(createdAtRaw);
      } catch (_) {
        // Invalid date format — fall back to current time
        createdAt = DateTime.now();
      }
    }

    // Defensive attachment parsing: skip invalid entries so a single corrupt
    // attachment does not prevent loading the entire message.
    List<Attachment> attachments = [];
    final attachmentsRaw = map['attachments'];
    if (attachmentsRaw is List) {
      for (final e in attachmentsRaw) {
        if (e is Map) {
          try {
            attachments.add(
                Attachment.fromMap(Map<String, dynamic>.from(e)));
          } catch (_) {
            // Skip corrupt attachment entry
          }
        }
      }
    }

    return ChatMessage(
      id: map['id'] as String?,
      role: roleStr,
      content: (map['content'] as String?) ?? '',
      createdAt: createdAt,
      attachments: attachments,
      isStreaming: map['isStreaming'] is bool ? map['isStreaming'] : false,
      isError: map['isError'] is bool ? map['isError'] : false,
      reasoningContent: map['reasoningContent'] as String?,
      rawRequest: map['rawRequest'] as Map<String, dynamic>?,
      rawResponse: map['rawResponse'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'ChatMessage(id: $id, role: $role)';
}
