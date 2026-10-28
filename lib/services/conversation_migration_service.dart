import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'attachment_storage.dart';
import '../models/stroom_conversation.dart';
import 'conversation_record_adapter.dart';
import 'conversation_repository.dart';

class ConversationMigrationResult {
  final bool verified;
  final int conversationCount;
  final int messageCount;
  final String sourceHash;

  const ConversationMigrationResult({
    required this.verified,
    required this.conversationCount,
    required this.messageCount,
    required this.sourceHash,
  });
}

/// Resumable SharedPreferences migration. The source key and its media
/// manifest are retained through the rollback window; importing the same
/// source again is safe because each conversation/message uses stable IDs.
class ConversationMigrationService {
  static const backupKey = 'conversations.migration.backup';
  static const attachmentManifestBackupKey =
      'conversations.migration.attachment_manifest';
  static const stateKey = 'conversations.migration.state';

  static final Map<Object, Future<void>> _migrationQueues = {};

  final ConversationRepository repository;
  final int batchSize;
  Future<void> Function(int batchIndex)? beforeBatchCommit;

  ConversationMigrationService(
    this.repository, {
    this.batchSize = 25,
    this.beforeBatchCommit,
  }) : assert(batchSize > 0);

  Future<ConversationMigrationResult> migrate(
    SharedPreferences preferences,
  ) {
    final lockKey = repository.migrationLockKey;
    final previous = _migrationQueues[lockKey] ?? Future<void>.value();
    final completion = Completer<void>();
    final queued = previous.then((_) => completion.future);
    _migrationQueues[lockKey] = queued;
    return _migrateAfter(previous, completion, queued, lockKey, preferences);
  }

  Future<ConversationMigrationResult> _migrateAfter(
    Future<void> previous,
    Completer<void> completion,
    Future<void> queued,
    Object lockKey,
    SharedPreferences preferences,
  ) async {
    try {
      await previous;
      return await _migrate(preferences);
    } finally {
      completion.complete();
      if (identical(_migrationQueues[lockKey], queued)) {
        _migrationQueues.remove(lockKey);
      }
    }
  }

  Future<ConversationMigrationResult> _migrate(
    SharedPreferences preferences,
  ) async {
    await repository.initialize();
    final liveRaw = preferences.getString('conversations');
    final previous = preferences.getString(stateKey);
    final backupRaw = preferences.getString(backupKey);
    final raw = (liveRaw == null || liveRaw.isEmpty) &&
            backupRaw != null &&
            backupRaw.isNotEmpty
        ? backupRaw
        : liveRaw;
    if (raw == null || raw.isEmpty) {
      if (_hasIncompleteMigrationState(previous)) {
        throw StateError(
          'The interrupted conversation migration source is unavailable.',
        );
      }
      if (await repository.migrationSourceHash() == null) {
        // An empty legacy source is still a completed migration state. The
        // non-null marker tells backup and orphan scans that repository rows
        // are authoritative after conversations are created on a fresh install.
        await repository.setMigrationSourceHash('');
      }
      return ConversationMigrationResult(
        verified: true,
        conversationCount: await repository.countConversations(),
        messageCount: await repository.countMessages(),
        sourceHash: '',
      );
    }
    final sourceHash = sha256.convert(utf8.encode(raw)).toString();
    var resumeAt = 0;
    final storedSourceHash = await repository.migrationSourceHash();
    var preserveRepositoryRows = false;
    if (storedSourceHash == sourceHash) {
      // This marker is written only after the imported rows pass count, order,
      // and integrity verification. It remains authoritative as users mutate
      // the repository, even if the final SharedPreferences checkpoint failed.
      return ConversationMigrationResult(
        verified: true,
        conversationCount: await repository.countConversations(),
        messageCount: await repository.countMessages(),
        sourceHash: sourceHash,
      );
    }
    var restartForChangedSource =
        storedSourceHash != null && storedSourceHash != sourceHash;
    if (previous != null) {
      try {
        final state = jsonDecode(previous) as Map<String, dynamic>;
        final previousHash = state['sourceHash'];
        if (previousHash is String && previousHash != sourceHash) {
          restartForChangedSource = true;
        }
        preserveRepositoryRows = storedSourceHash == null &&
            previousHash == sourceHash &&
            state['preserveRepositoryRows'] == true;
        if (state['verified'] == true && state['sourceHash'] == sourceHash) {
          resumeAt = 0;
        } else if (state['sourceHash'] == sourceHash &&
            state['nextConversation'] is num) {
          resumeAt = (state['nextConversation'] as num).toInt().clamp(
                0,
                1 << 30,
              );
        }
      } catch (_) {
        // An invalid marker is safe to ignore; source rows remain authoritative.
      }
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Legacy conversations must be a JSON list.');
    }
    await _writeBackup(
      preferences,
      raw,
      replaceExisting: restartForChangedSource,
    );
    final conversations = <StroomConversation>[];
    for (final item in decoded) {
      if (item is! Map) {
        throw const FormatException(
          'Legacy conversation list contains a non-object row.',
        );
      }
      conversations.add(
        await _conversationForRepository(
          Map<String, dynamic>.from(item),
          preferences,
        ),
      );
    }

    if (restartForChangedSource) {
      // A new legacy source is authoritative during recovery. Remove rows
      // imported from the old source before the resumable import starts;
      // clearConversations is transactional, while the preference source and
      // backup above remain available if the process stops immediately after.
      await repository.clearConversations();
      resumeAt = 0;
      preserveRepositoryRows = false;
    }
    final preserveExistingIds = preserveRepositoryRows
        ? (await repository.listSummaries())
            .map((summary) => summary.id)
            .toSet()
        : const <String>{};
    if (resumeAt > 0 &&
        !await _containsImportedPrefix(conversations, resumeAt)) {
      // The repository may have been reset after a batch checkpoint was
      // persisted. Reimporting stable IDs from the beginning is idempotent;
      // trusting a stale cursor would skip rows and fail final verification.
      resumeAt = 0;
    }
    if (!await preferences.setString(
      stateKey,
      jsonEncode({
        'sourceHash': sourceHash,
        'nextConversation': resumeAt,
        'verified': false,
        if (preserveRepositoryRows) 'preserveRepositoryRows': true,
      }),
    )) {
      throw StateError(
        'Could not save the conversation migration source marker.',
      );
    }
    for (var start = resumeAt, batchIndex = resumeAt ~/ batchSize;
        start < conversations.length;
        start += batchSize, batchIndex++) {
      await beforeBatchCommit?.call(batchIndex);
      final end = (start + batchSize).clamp(0, conversations.length);
      for (final conversation in conversations.sublist(start, end)) {
        if (preserveExistingIds.contains(conversation.id)) continue;
        await repository.importConversation(conversation);
      }
      await preferences.setString(
        stateKey,
        jsonEncode({
          'sourceHash': sourceHash,
          'nextConversation': end,
          'verified': false,
          if (preserveRepositoryRows) 'preserveRepositoryRows': true,
        }),
      );
    }
    final existingOrder = (await repository.listSummaries())
        .map((summary) => summary.id)
        .toList();
    final importedIds = conversations
        .map((conversation) => conversation.id)
        .where((id) => !existingOrder.contains(id));
    final mergedOrder = [...existingOrder, ...importedIds];
    await repository.setConversationOrder(mergedOrder);

    final verifiedMessages = <String, List<String>>{};
    for (final conversation in conversations) {
      final storedConversation = await repository.getConversation(
        conversation.id,
      );
      final preserveExisting = preserveExistingIds.contains(conversation.id);
      if (storedConversation == null ||
          (!preserveExisting &&
              jsonEncode(storedConversation.toMap()) !=
                  jsonEncode(_withoutMessages(conversation).toMap()))) {
        throw StateError(
          'Conversation ${conversation.id} failed metadata verification.',
        );
      }
      if (preserveExisting) {
        verifiedMessages[conversation.id] = const [];
        continue;
      }
      final stored = await repository.getMessages(
        conversation.id,
        limit: conversation.messages.length,
      );
      final expectedIds =
          conversation.messages.map((message) => message.id).toList();
      final actualIds = stored.map((message) => message.id).toList();
      if (expectedIds.length != actualIds.length ||
          !_sameIds(expectedIds, actualIds)) {
        throw StateError(
          'Conversation ${conversation.id} failed migration verification.',
        );
      }
      for (var index = 0; index < stored.length; index++) {
        if (jsonEncode(stored[index].toMap()) !=
            jsonEncode(conversation.messages[index].toMap())) {
          throw StateError(
            'Conversation ${conversation.id} changed message content during migration.',
          );
        }
      }
      verifiedMessages[conversation.id] = actualIds;
    }
    final conversationCount = await repository.countConversations();
    final messageCount = await repository.countMessages();
    final expectedMessageCount = conversations
        .where((conversation) => !preserveExistingIds.contains(conversation.id))
        .fold<int>(
          0,
          (count, conversation) => count + conversation.messages.length,
        );
    if (conversationCount < conversations.length ||
        messageCount < expectedMessageCount ||
        verifiedMessages.length != conversations.length) {
      throw StateError('Conversation repository count verification failed.');
    }
    final summaryIds = (await repository.listSummaries())
        .map((summary) => summary.id)
        .toList();
    if (!_isOrderedSubsequence(
      conversations.map((conversation) => conversation.id).toList(),
      summaryIds,
    )) {
      throw StateError('Conversation repository order verification failed.');
    }
    final integrityIssues = await repository.checkIntegrity(
      readMedia: AttachmentStorage.readFile,
    );
    if (integrityIssues.isNotEmpty) {
      throw StateError(
        'Conversation migration found ${integrityIssues.length} invalid media reference(s).',
      );
    }
    await repository.setMigrationSourceHash(sourceHash);
    try {
      final saved = await preferences.setString(
        stateKey,
        jsonEncode({
          'sourceHash': sourceHash,
          'nextConversation': conversations.length,
          'verified': true,
          'conversationCount': conversationCount,
          'messageCount': messageCount,
        }),
      );
      if (!saved) {
        debugPrint(
          'Could not save the final conversation migration checkpoint; '
          'the verified repository source marker remains authoritative.',
        );
      }
    } catch (error) {
      debugPrint(
        'Could not save the final conversation migration checkpoint: $error; '
        'the verified repository source marker remains authoritative.',
      );
    }
    return ConversationMigrationResult(
      verified: true,
      conversationCount: conversationCount,
      messageCount: messageCount,
      sourceHash: sourceHash,
    );
  }

  bool _hasIncompleteMigrationState(String? rawState) {
    if (rawState == null) return false;
    try {
      final state = jsonDecode(rawState);
      return state is Map<String, dynamic> &&
          state['sourceHash'] is String &&
          state['verified'] != true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _containsImportedPrefix(
    List<StroomConversation> conversations,
    int count,
  ) async {
    final end = count.clamp(0, conversations.length);
    for (final conversation in conversations.take(end)) {
      final storedConversation = await repository.getConversation(
        conversation.id,
      );
      if (storedConversation == null ||
          jsonEncode(storedConversation.toMap()) !=
              jsonEncode(_withoutMessages(conversation).toMap())) {
        return false;
      }
      final storedMessages = await repository.getMessages(
        conversation.id,
        limit: conversation.messages.length,
      );
      if (storedMessages.length != conversation.messages.length) return false;
      for (var index = 0; index < storedMessages.length; index++) {
        if (jsonEncode(storedMessages[index].toMap()) !=
            jsonEncode(conversation.messages[index].toMap())) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _writeBackup(
    SharedPreferences preferences,
    String raw, {
    bool replaceExisting = false,
  }) async {
    final existingBackup = preferences.getString(backupKey);
    if (replaceExisting || existingBackup == null) {
      if (!await preferences.setString(backupKey, raw)) {
        throw StateError('Could not back up the legacy conversations key.');
      }
    }
    final manifest = <String, Map<String, dynamic>>{};
    void collectAttachments(Object? value) {
      if (value is! List) return;
      for (final attachment in value) {
        if (attachment is! Map) continue;
        final map = Map<String, dynamic>.from(attachment);
        map.remove('base64Data');
        final storagePath = map['storagePath'] as String?;
        final thumbnailPath = map['thumbnailPath'] as String?;
        final path = storagePath != null && storagePath.isNotEmpty
            ? storagePath
            : thumbnailPath;
        if (path != null && path.isNotEmpty) manifest[path] = map;
      }
    }

    final decoded = jsonDecode(raw);
    if (decoded is List) {
      for (final conversation in decoded) {
        if (conversation is! Map) continue;
        collectAttachments(conversation['draftAttachments']);
        final messages = conversation['messages'];
        if (messages is List) {
          for (final message in messages) {
            if (message is Map) collectAttachments(message['attachments']);
          }
        }
      }
    }
    final manifestJson = jsonEncode(manifest.values.toList());
    if ((replaceExisting ||
            preferences.getString(attachmentManifestBackupKey) == null) &&
        !await preferences.setString(
          attachmentManifestBackupKey,
          manifestJson,
        )) {
      throw StateError(
        'Could not back up the conversation attachment manifest.',
      );
    }
  }

  Future<StroomConversation> _conversationForRepository(
    Map<String, dynamic> source,
    SharedPreferences preferences,
  ) async {
    final conversation = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(source)) as Map,
    );
    final rawDraftAttachments = conversation['draftAttachments'];
    if (rawDraftAttachments is List) {
      for (final rawAttachment in rawDraftAttachments) {
        if (rawAttachment is! Map) continue;
        final attachment = Map<String, dynamic>.from(rawAttachment);
        final inlinePayload = attachment['base64Data'];
        if (inlinePayload is! String || inlinePayload.isEmpty) continue;
        final bytes = base64Decode(inlinePayload);
        final hash = AttachmentStorage.computeHash(bytes);
        final existingPath = attachment['storagePath'] as String? ?? '';
        var fileAvailable = false;
        if (existingPath.isNotEmpty) {
          try {
            final existingBytes = await AttachmentStorage.readFile(
              existingPath,
            );
            fileAvailable =
                existingBytes != null && _sameBytes(existingBytes, bytes);
          } catch (_) {
            // Fall back to the retained inline payload below.
          }
        }
        if (!fileAvailable) {
          final attachmentId = attachment['id'] is String
              ? attachment['id'] as String
              : '${rawDraftAttachments.indexOf(rawAttachment)}';
          final stableAttachmentId = sha256
              .convert(
                utf8.encode(
                    '${conversation['id']}\u0000$attachmentId\u0000$hash'),
              )
              .toString();
          final path = await AttachmentStorage.saveFile(
            attachment['fileName'] as String? ?? 'draft-attachment.bin',
            bytes,
            stableId: stableAttachmentId,
          );
          attachment['storagePath'] = path;
        }
        attachment['fileSize'] = bytes.length;
        attachment['hash'] = hash;
        attachment.remove('base64Data');
        await _appendAttachmentManifest(preferences, attachment);
        rawDraftAttachments[rawDraftAttachments.indexOf(rawAttachment)] =
            attachment;
      }
    }
    return ConversationRecordAdapter.fromLegacyMap(conversation);
  }

  Future<void> _appendAttachmentManifest(
    SharedPreferences preferences,
    Map<String, dynamic> attachment,
  ) async {
    final path = attachment['storagePath'] as String? ??
        attachment['thumbnailPath'] as String?;
    if (path == null || path.isEmpty) return;
    final existing = preferences.getString(attachmentManifestBackupKey);
    final manifest = <Map<String, dynamic>>[];
    if (existing != null) {
      final decoded = jsonDecode(existing);
      if (decoded is! List) {
        throw const FormatException(
          'Invalid conversation attachment manifest.',
        );
      }
      manifest.addAll(
        decoded.whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ),
      );
    }
    if (!manifest.any((entry) => entry['storagePath'] == path)) {
      final copy = Map<String, dynamic>.from(attachment)..remove('base64Data');
      manifest.add(copy);
      if (!await preferences.setString(
        attachmentManifestBackupKey,
        jsonEncode(manifest),
      )) {
        throw StateError('Could not save the migrated attachment manifest.');
      }
    }
  }

  static bool _sameIds(List<String> expected, List<String> actual) {
    if (expected.length != actual.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) return false;
    }
    return true;
  }

  static bool _isOrderedSubsequence(
    List<String> expected,
    List<String> actual,
  ) {
    var expectedIndex = 0;
    for (final id in actual) {
      if (expectedIndex < expected.length && id == expected[expectedIndex]) {
        expectedIndex++;
      }
    }
    return expectedIndex == expected.length;
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static StroomConversation _withoutMessages(StroomConversation source) =>
      StroomConversation(
        schemaVersion: source.schemaVersion,
        id: source.id,
        title: source.title,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
        extensions: source.extensions,
        extraFields: source.extraFields,
      );
}
