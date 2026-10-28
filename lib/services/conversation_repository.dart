import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import '../models/stroom_conversation.dart';
import 'conversation_repository_factory_stub.dart'
    if (dart.library.io) 'conversation_repository_factory_io.dart'
    if (dart.library.html) 'conversation_repository_factory_web.dart'
    as repository_factory;

export 'conversation_repository_memory.dart';

/// Returns a local media path, excluding URI references that are resolved by
/// the content consumer and are not part of this app's attachment store.
String? conversationLocalMediaPath(Object? value) {
  if (value is! String || value.isEmpty) return null;
  if (RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(value)) return null;
  return value;
}

bool conversationIsExternalMediaUri(Object? value) =>
    value is String &&
    value.isNotEmpty &&
    RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(value);

/// Legacy Stroom attachments use MD5 in `hash`; neutral media references may
/// provide an explicit SHA-256 digest. Accept either stored representation.
bool conversationMediaHashMatches(
  Map<String, dynamic> reference,
  Uint8List bytes,
) {
  final expectedSha256 = reference['sha256'] as String?;
  if (expectedSha256 != null && expectedSha256.isNotEmpty) {
    return sha256.convert(bytes).toString() == expectedSha256.toLowerCase();
  }
  final expected = reference['hash'] as String?;
  if (expected == null || expected.isEmpty) return true;
  final digest = expected.toLowerCase();
  return md5.convert(bytes).toString() == digest ||
      sha256.convert(bytes).toString() == digest;
}

/// One conversation row suitable for list views. It deliberately contains no
/// message bodies; histories are read separately in stable, ordered pages.
class ConversationSummary {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final Map<String, dynamic> extraFields;

  const ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.extraFields = const {},
  });

  factory ConversationSummary.fromConversation(
    StroomConversation conversation, {
    required int messageCount,
  }) =>
      ConversationSummary(
        id: conversation.id,
        title: conversation.title,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
        messageCount: messageCount,
        extraFields: conversation.extraFields,
      );
}

/// One conversation's changed rows in a repository-wide atomic snapshot.
class ConversationRepositoryChange {
  final StroomConversation conversation;
  final List<StroomMessage> upsertMessages;
  final List<String> deleteMessageIds;

  const ConversationRepositoryChange({
    required this.conversation,
    this.upsertMessages = const [],
    this.deleteMessageIds = const [],
  });
}

class ConversationIntegrityIssue {
  final String conversationId;
  final String messageId;
  final String reference;
  final String reason;

  const ConversationIntegrityIssue({
    required this.conversationId,
    required this.messageId,
    required this.reference,
    required this.reason,
  });
}

/// Protocol-neutral persistence contract shared by SQLite and IndexedDB.
abstract interface class ConversationRepository {
  /// Stable key shared by handles to the same backing store. Migration calls
  /// use it to serialize source checks and imports across repository handles.
  Object get migrationLockKey;

  Future<void> initialize();

  Future<List<ConversationSummary>> listSummaries({int? limit});

  Future<StroomConversation?> getConversation(String id);

  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  });

  Future<void> upsertConversation(StroomConversation conversation);

  /// Atomically updates conversation metadata and only the changed message
  /// records, preserving unrelated message rows on every backend.
  Future<void> applyConversationChanges(
    StroomConversation conversation, {
    List<StroomMessage> upsertMessages = const [],
    List<String> deleteMessageIds = const [],
  });

  /// Commits row changes, conversation deletions, and visible ordering as one
  /// durable snapshot. A failure leaves the previous repository state intact.
  Future<void> applySnapshotChanges({
    required List<ConversationRepositoryChange> changes,
    required List<String> conversationOrder,
    required List<String> deleteConversationIds,
  });

  Future<void> importConversation(StroomConversation conversation);

  Future<void> setConversationOrder(List<String> conversationIds);

  /// Removes repository conversations, messages, ordering, and migration
  /// marker atomically before a new authoritative legacy source is imported.
  Future<void> clearConversations();

  Future<void> replaceMessages(
    String conversationId,
    List<StroomMessage> messages,
  );

  Future<void> upsertMessage(String conversationId, StroomMessage message);

  Future<void> deleteMessage(String conversationId, String messageId);

  Future<void> deleteConversation(String conversationId);

  Future<int> countConversations();

  Future<int> countMessages({String? conversationId});

  Future<String?> migrationSourceHash();

  Future<void> setMigrationSourceHash(String sourceHash);

  Future<Map<String, dynamic>> exportData();

  Future<void> restoreData(Map<String, dynamic> data);

  Future<List<ConversationIntegrityIssue>> checkIntegrity({
    required Future<Uint8List?> Function(String reference) readMedia,
  });

  Future<void> close();
}

/// Selects the platform persistence engine without exposing it to callers.
ConversationRepository createConversationRepository() =>
    repository_factory.createConversationRepository();

/// Returns only the known legacy draft-attachment collection. Conversation
/// extensions are open-ended, so recursively treating every `reference` key
/// as media would misclassify protocol data such as citation URLs.
Iterable<Map<String, dynamic>> conversationDraftAttachmentReferences(
  StroomConversation conversation,
) sync* {
  final legacy = conversation.extensions['stroom.legacyConversation'];
  final candidates = <Object?>[
    conversation.extraFields['draftAttachments'],
    if (legacy is Map) legacy['draftAttachments'],
  ];
  for (final candidate in candidates) {
    if (candidate is! List) continue;
    for (final attachment in candidate) {
      if (attachment is Map &&
          (attachment['storagePath'] is String ||
              attachment['reference'] is String ||
              attachment['thumbnailPath'] is String)) {
        yield Map<String, dynamic>.from(attachment);
      }
    }
  }
}

/// Extracts media from explicitly typed message parts or the legacy
/// attachment wrapper. Unknown content parts remain opaque extensions.
Map<String, dynamic>? conversationMediaReferenceForPart(
  StroomContentPart part,
) {
  final attachment = part.data['attachment'];
  if (attachment is Map) {
    final reference = Map<String, dynamic>.from(attachment);
    for (final field in const ['reference', 'storagePath', 'thumbnailPath']) {
      final siblingPath = part.data[field];
      if (siblingPath is String && siblingPath.isNotEmpty) {
        reference.putIfAbsent(field, () => siblingPath);
      }
    }
    return reference;
  }
  if (const {'image', 'audio', 'video', 'file'}.contains(part.type)) {
    return part.data;
  }
  return null;
}

Iterable<Map<String, dynamic>> conversationMessageMediaReferences(
  StroomMessage message,
) sync* {
  final seenReferences = <String>{};
  Iterable<Map<String, dynamic>> unique(
    Iterable<Map<String, dynamic>> refs,
  ) sync* {
    for (final reference in refs) {
      final key = const [
        'reference',
        'storagePath',
        'thumbnailPath',
        'hash',
        'sha256',
        'size',
        'fileSize',
        'thumbnailHash',
        'thumbnailSha256',
        'thumbnailSize',
      ].map((field) => '${reference[field] ?? ''}').join('\u001f');
      if (seenReferences.add(key)) yield reference;
    }
  }

  for (final part in message.content) {
    final reference = conversationMediaReferenceForPart(part);
    if (reference != null) yield* unique([reference]);
  }

  // The migration adapter retains the complete legacy message map in this
  // namespaced record. Older ChatMessage attachments are not always represented
  // as typed content parts, so include their durable paths in repository scans.
  final legacy = message.extensions['stroom.legacy'];
  final record = legacy is Map ? legacy['record'] : null;
  final attachments = record is Map ? record['attachments'] : null;
  if (attachments is List) {
    for (final attachment in attachments) {
      if (attachment is Map &&
          (attachment['storagePath'] is String ||
              attachment['reference'] is String ||
              attachment['thumbnailPath'] is String)) {
        yield* unique([Map<String, dynamic>.from(attachment)]);
      }
    }
  }
}
