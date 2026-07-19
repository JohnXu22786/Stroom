import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';

import '../utils/data_sanitizer.dart';

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

  /// Sanitize a raw data map for JSON serialization.
  ///
  /// Recursively ensures all values are JSON-serializable (Map, List, String,
  /// num, bool, Null). Strips any keys/values that would cause [jsonEncode] to
  /// throw. This prevents `rawRequest` / `rawResponse` from containing
  /// non-serializable types (e.g. Dio ResponseBody, custom objects, DateTime)
  /// that would silently break conversation persistence.
  ///
  /// **Also strips large base64 attachment data** (data URIs and plain base64
  /// payloads) via [DataSanitizer.sanitizeForDisplay]. Without this, sending a
  /// single video/image/audio/PDF could bloat the on-disk JSON to multiple MB,
  /// causing SharedPreferences write failures, UI freezes, and silent data
  /// corruption (the "flash crash + half-broken history" bug).
  ///
  /// The sanitized copy is returned; the original map is NOT modified.
  static Map<String, dynamic>? _sanitizeRawMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    try {
      final result = <String, dynamic>{};
      for (final entry in raw.entries) {
        // First make the value JSON-serializable (strip non-encodable types).
        final typed = _sanitizeJsonValue(entry.value);
        // Then strip large base64 content so the on-disk payload stays small.
        // This is safe because:
        //   1. The original raw data is preserved in memory for the "view raw
        //      data" dialog, which already sanitizes for display.
        //   2. Restoring the conversation does not need the full base64 —
        //      attachments live on disk (AttachmentStorage) and are loaded
        //      separately when needed.
        //   3. The first 100 chars of every base64 string is preserved as
        //      context, so users can still see what was sent.
        final value = (typed is String || typed is Map || typed is List)
            ? DataSanitizer.sanitizeForDisplay(typed)
            : typed;
        // Only include the entry if it's JSON-serializable
        if (value != null || entry.value == null) {
          result[entry.key] = value;
        }
      }
      return result;
    } catch (_) {
      // If ANY error occurs during sanitization, skip the entire raw map
      // rather than letting a partial/serialization-error corrupt the save.
      return null;
    }
  }

  /// Recursively sanitize a single value for JSON serialization.
  /// Returns the sanitized value, or null if it can't be sanitized.
  static dynamic _sanitizeJsonValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key?.toString();
        if (key == null) continue;
        result[key] = _sanitizeJsonValue(entry.value);
      }
      return result;
    }
    if (value is List) {
      return value.map(_sanitizeJsonValue).toList();
    }
    // Non-serializable type (DateTime, Uri, custom object, etc.) — skip
    return null;
  }

  /// Safely cast a dynamic value to [Map<String, dynamic>?].
  ///
  /// Returns the map if the value is a valid [Map], or `null` otherwise.
  /// This prevents the `as Map<String, dynamic>?` cast from throwing a runtime
  /// [TypeError] when the stored data is a non-Map type (String, List, int,
  /// etc.), which would cause the entire message to be skipped during loading.
  ///
  /// Such corruption can happen when a streaming API error stores non-Map
  /// diagnostic data in `rawResponse` or when in-flight request data is
  /// captured in an unexpected format.
  @visibleForTesting
  static Map<String, dynamic>? safeCastToMap(dynamic value) {
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'attachments': attachments.map((a) => a.toMap()).toList(),
        if (isStreaming) 'isStreaming': true,
        if (isError) 'isError': true,
        if (reasoningContent != null) 'reasoningContent': reasoningContent,
        // Sanitize raw maps to ensure JSON-serializable output.
        // This prevents non-serializable types (Dio ResponseBody, DateTime,
        // custom objects, etc.) from silently breaking conversation persistence.
        if (rawRequest != null) 'rawRequest': _sanitizeRawMap(rawRequest),
        if (rawResponse != null) 'rawResponse': _sanitizeRawMap(rawResponse),
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
            attachments.add(Attachment.fromMap(Map<String, dynamic>.from(e)));
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
      // Use safe casting so non-Map rawRequest/rawResponse values don't throw
      // a TypeError, which would skip the ENTIRE message in Conversation.fromMap.
      rawRequest: safeCastToMap(map['rawRequest']),
      rawResponse: safeCastToMap(map['rawResponse']),
    );
  }

  @override
  String toString() => 'ChatMessage(id: $id, role: $role)';
}
