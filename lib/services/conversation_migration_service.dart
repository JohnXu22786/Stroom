import 'dart:convert';

import 'package:crypto/crypto.dart';
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
  ) async {
    await repository.initialize();
    final raw = preferences.getString('conversations');
    if (raw == null || raw.isEmpty) {
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
    final previous = preferences.getString(stateKey);
    var resumeAt = 0;
    final storedSourceHash = await repository.migrationSourceHash();
    var restartForChangedSource =
        storedSourceHash != null && storedSourceHash != sourceHash;
    if (previous != null) {
      try {
        final state = jsonDecode(previous) as Map<String, dynamic>;
        final previousHash = state['sourceHash'];
        if (previousHash is String && previousHash != sourceHash) {
          restartForChangedSource = true;
        }
        if (state['verified'] == true && state['sourceHash'] == sourceHash) {
          if (await repository.migrationSourceHash() == sourceHash) {
            final storedConversationCount = await repository.countConversations();
            final storedMessageCount = await repository.countMessages();
            // After verification the repository becomes authoritative and can
            // legitimately diverge from the retained rollback source as users
            // edit, add, or delete records. The repository marker survives those
            // mutations but disappears if the store itself is reset.
            return ConversationMigrationResult(
              verified: true,
              conversationCount: storedConversationCount,
              messageCount: storedMessageCount,
              sourceHash: sourceHash,
            );
          }
          resumeAt = 0;
        } else if (state['sourceHash'] == sourceHash &&
            state['nextConversation'] is num) {
          resumeAt = (state['nextConversation'] as num)
              .toInt()
              .clamp(0, 1 << 30);
        }
      } catch (_) {
        // An invalid marker is safe to ignore; source rows remain authoritative.
      }
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Legacy conversations must be a JSON list.');
    }
    await _writeBackup(preferences, raw);
    final conversations = <StroomConversation>[];
    for (final item in decoded) {
      if (item is! Map) {
        throw const FormatException('Legacy conversation list contains a non-object row.');
      }
      conversations.add(
        await _conversationForRepository(Map<String, dynamic>.from(item)),
      );
    }

    if (restartForChangedSource) {
      // A new legacy source is authoritative during recovery. Remove rows
      // imported from the old source before the resumable import starts;
      // clearConversations is transactional, while the preference source and
      // backup above remain available if the process stops immediately after.
      await repository.clearConversations();
      resumeAt = 0;
    }
    if (!await preferences.setString(
      stateKey,
      jsonEncode({
        'sourceHash': sourceHash,
        'nextConversation': resumeAt,
        'verified': false,
      }),
    )) {
      throw StateError('Could not save the conversation migration source marker.');
    }
    for (var start = resumeAt, batchIndex = resumeAt ~/ batchSize;
        start < conversations.length;
        start += batchSize, batchIndex++) {
      await beforeBatchCommit?.call(batchIndex);
      final end = (start + batchSize).clamp(0, conversations.length);
      for (final conversation in conversations.sublist(start, end)) {
        await repository.importConversation(conversation);
      }
      await preferences.setString(
        stateKey,
        jsonEncode({
          'sourceHash': sourceHash,
          'nextConversation': end,
          'verified': false,
        }),
      );
    }
    await repository.setConversationOrder(
      conversations.map((conversation) => conversation.id).toList(),
    );

    final verifiedMessages = <String, List<String>>{};
    for (final conversation in conversations) {
      final storedConversation = await repository.getConversation(conversation.id);
      if (storedConversation == null ||
          jsonEncode(storedConversation.toMap()) !=
              jsonEncode(_withoutMessages(conversation).toMap())) {
        throw StateError('Conversation ${conversation.id} failed metadata verification.');
      }
      final stored = await repository.getMessages(
        conversation.id,
        limit: conversation.messages.length,
      );
      final expectedIds = conversation.messages.map((message) => message.id).toList();
      final actualIds = stored.map((message) => message.id).toList();
      if (expectedIds.length != actualIds.length ||
          !_sameIds(expectedIds, actualIds)) {
        throw StateError('Conversation ${conversation.id} failed migration verification.');
      }
      for (var index = 0; index < stored.length; index++) {
        if (jsonEncode(stored[index].toMap()) !=
            jsonEncode(conversation.messages[index].toMap())) {
          throw StateError('Conversation ${conversation.id} changed message content during migration.');
        }
      }
      verifiedMessages[conversation.id] = actualIds;
    }
    final conversationCount = await repository.countConversations();
    final messageCount = await repository.countMessages();
    final expectedMessageCount = conversations.fold<int>(
      0,
      (count, conversation) => count + conversation.messages.length,
    );
    if (conversationCount != conversations.length ||
        messageCount != expectedMessageCount ||
        verifiedMessages.length != conversations.length) {
      throw StateError('Conversation repository count verification failed.');
    }
    final summaryIds = (await repository.listSummaries())
        .map((summary) => summary.id)
        .toList();
    if (!_sameIds(
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
    await preferences.setString(
      stateKey,
      jsonEncode({
        'sourceHash': sourceHash,
        'nextConversation': conversations.length,
        'verified': true,
        'conversationCount': conversations.length,
        'messageCount': expectedMessageCount,
      }),
    );
    return ConversationMigrationResult(
      verified: true,
      conversationCount: conversations.length,
      messageCount: expectedMessageCount,
      sourceHash: sourceHash,
    );
  }

  Future<void> _writeBackup(
    SharedPreferences preferences,
    String raw,
  ) async {
    final existingBackup = preferences.getString(backupKey);
    if (existingBackup == null) {
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
        final path = map['storagePath'] as String? ??
            map['thumbnailPath'] as String?;
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
    if (preferences.getString(attachmentManifestBackupKey) == null &&
        !await preferences.setString(attachmentManifestBackupKey, manifestJson)) {
      throw StateError('Could not back up the conversation attachment manifest.');
    }
  }

  Future<StroomConversation> _conversationForRepository(
    Map<String, dynamic> source,
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
        final existingPath = attachment['storagePath'] as String? ?? '';
        var fileAvailable = false;
        if (existingPath.isNotEmpty) {
          try {
            fileAvailable = await AttachmentStorage.readFile(existingPath) != null;
          } catch (_) {
            // Fall back to the retained inline payload below.
          }
        }
        if (!fileAvailable) {
          final bytes = base64Decode(inlinePayload);
          final path = await AttachmentStorage.saveFile(
            attachment['fileName'] as String? ?? 'draft-attachment.bin',
            bytes,
          );
          attachment['storagePath'] = path;
          attachment['fileSize'] = bytes.length;
          attachment['hash'] = AttachmentStorage.computeHash(bytes);
        }
        attachment.remove('base64Data');
        rawDraftAttachments[rawDraftAttachments.indexOf(rawAttachment)] =
            attachment;
      }
    }
    return ConversationRecordAdapter.fromLegacyMap(conversation);
  }

  static bool _sameIds(List<String> expected, List<String> actual) {
    if (expected.length != actual.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) return false;
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
