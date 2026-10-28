import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';
import 'conversation_repository.dart';
import '../models/stroom_conversation.dart';
import '../utils/web_file_store.dart';
import 'app_log_service.dart';
import 'conversation_migration_service.dart';
import 'startup_preferences.dart';
import 'data_migration_isolate_stub.dart'
    if (dart.library.io) 'data_migration_isolate_io.dart'
    as data_migration_isolate;

void addStringToArchive(Archive archive, String name, String content) {
  final bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(name, bytes.length, bytes));
}

Future<void> addTaskFileToArchive(
  Archive archive,
  String archiveName,
  String sourcePath,
) async {
  debugPrint(
    '[BackupServiceShared] addTaskFileToArchive: $archiveName <- $sourcePath',
  );
  if (WebFileStore.isTestMode) {
    addStringToArchive(archive, archiveName, '[]');
    return;
  }
  try {
    final file = File(sourcePath);
    if (await file.exists()) {
      final data = await file.readAsBytes();
      archive.addFile(ArchiveFile(archiveName, data.length, data));
    } else {
      addStringToArchive(archive, archiveName, '[]');
    }
  } catch (e) {
    debugPrint('添加任务文件 $archiveName 失败: $e');
    addStringToArchive(archive, archiveName, '[]');
  }
}

Future<void> addFileToArchive(
  Archive archive,
  String archiveName,
  String subDir,
  String fileName, {
  bool required = false,
}) async {
  debugPrint('[BackupServiceShared] addFileToArchive: $archiveName');
  try {
    final data = await readBackupFile(subDir, fileName);
    if (data != null) {
      archive.addFile(ArchiveFile(archiveName, data.length, data));
    } else if (required) {
      throw FileSystemException('备份文件不存在', '$subDir/$fileName');
    }
  } catch (e) {
    debugPrint('添加文件 $archiveName 失败: $e');
    if (required) rethrow;
  }
}

Future<Uint8List?> readBackupFile(String subDir, String fileName) async {
  try {
    if (kIsWeb || WebFileStore.isTestMode) {
      final data = await WebFileStore.read('$subDir/$fileName');
      if (data != null || subDir != 'attachments') return data;
      // Edited attachments were historically stored under temp_edited/ on
      // Web, while native platforms store the same bytes in attachments/.
      return await WebFileStore.read('temp_edited/$fileName');
    } else {
      final appDir = await AppStorage.directory;
      final file = File(p.join(appDir, subDir, fileName));
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    }
  } catch (e) {
    await AppLogService.error(
      'BackupServiceShared',
      'readBackupFile($subDir/$fileName) 失败',
      e,
    );
    debugPrint('读取备份文件 $subDir/$fileName 失败: $e');
    return null;
  }
}

Future<void> writeBackupFile(
  String subDir,
  String fileName,
  Uint8List data,
) async {
  try {
    if (kIsWeb || WebFileStore.isTestMode) {
      await WebFileStore.write('$subDir/$fileName', data);
    } else {
      final appDir = await AppStorage.directory;
      final file = File(p.join(appDir, subDir, fileName));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data);
    }
  } catch (e) {
    await AppLogService.error(
      'BackupServiceShared',
      'writeBackupFile($subDir/$fileName) 失败',
      e,
    );
    debugPrint('写入备份文件 $subDir/$fileName 失败: $e');
    rethrow;
  }
}

Future<Set<String>> collectAttachmentPaths({
  @visibleForTesting ConversationRepository? repositoryOverride,
}) async {
  final paths = <String>{};
  var repositoryIsAuthoritative = false;
  if (repositoryOverride != null || _shouldReadConversationRepository) {
    final repository = repositoryOverride ?? createConversationRepository();
    try {
      await repository.initialize();
      repositoryIsAuthoritative =
          await isConversationRepositoryAuthoritative(repository);
      _collectRepositoryAttachmentPaths(await repository.exportData(), paths);
    } catch (e) {
      debugPrint('收集仓库媒体引用失败: $e');
      if (await _hasAuthoritativeConversationRepository(repository)) rethrow;
      debugPrint(
          'Conversation repository is not authoritative; falling back to legacy data.');
    } finally {
      if (repositoryOverride == null) await repository.close();
    }
  }
  try {
    if (!repositoryIsAuthoritative) {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('conversations');
      if (json == null) return paths;
      // 顶层也需防御：conversations 整体不是数组时，`as List` 强转抛
      // TypeError 会让整个备份静默丢失所有附件路径。
      final decoded = jsonDecode(json);
      if (decoded is! List) {
        debugPrint('conversations 不是合法数组，跳过附件路径收集');
      } else {
        for (final conv in decoded) {
          // 逐层防御：损坏数据（非 Map 会话/消息、非 List 字段、非 Map
          // 附件）只跳过对应条目，绝不中断整个扫描 —— 否则一条坏数据
          // 会让备份丢失所有附件路径（旧代码 TypeError 被外层 catch
          // 吞掉，静默丢失）。
          if (conv is! Map<String, dynamic>) continue;
          final rawMessages = conv['messages'];
          if (rawMessages is List) {
            for (final msg in rawMessages) {
              if (msg is! Map<String, dynamic>) continue;
              _collectAttachments(msg['attachments'], paths);
            }
          }
          // Draft attachments are persisted with the conversation too; retaining
          // the draft without its files would leave broken references after import.
          _collectAttachments(conv['draftAttachments'], paths);
        }
      }
    }
  } catch (e) {
    // 仅当整体 JSON 无法解析时才放弃（逐条目损坏已在上面跳过）。
    debugPrint('收集附件路径失败: $e');
  }
  debugPrint(
    '[BackupServiceShared] collectAttachmentPaths: ${paths.length} paths found',
  );
  return paths;
}

/// Collects conversation attachment references for startup orphan cleanup.
/// A null result means the stored references could not be read or parsed, so
/// cleanup must abort rather than risk deleting a live attachment.
Future<Set<String>?> collectAttachmentPathsForSafety({
  @visibleForTesting ConversationRepository? repositoryOverride,
}) async {
  try {
    final paths = <String>{};
    var repositoryIsAuthoritative = false;
    if (repositoryOverride != null || _shouldReadConversationRepository) {
      final repository = repositoryOverride ?? createConversationRepository();
      try {
        await repository.initialize();
        repositoryIsAuthoritative =
            await isConversationRepositoryAuthoritative(repository);
        _collectRepositoryAttachmentPaths(await repository.exportData(), paths);
      } finally {
        if (repositoryOverride == null) await repository.close();
      }
    }
    if (!repositoryIsAuthoritative) {
      final json = await StartupPreferences.getString('conversations');
      if (json != null) {
        if (kIsWeb || _isBackupServiceFlutterTest) {
          paths.addAll(_collectAttachmentPathsFromJson(json));
        } else {
          paths.addAll(
            await data_migration_isolate.runInIsolate(
              () => _collectAttachmentPathsFromJson(json),
            ),
          );
        }
      }
    }
    return paths;
  } catch (error) {
    debugPrint('启动时收集附件路径失败，中止孤儿清理: $error');
    return null;
  }
}

bool get _shouldReadConversationRepository =>
    kIsWeb || (!WebFileStore.isTestMode && !_isBackupServiceFlutterTest);

Future<bool> _hasAuthoritativeConversationRepository(
  ConversationRepository repository,
) async {
  try {
    if (await repository.migrationSourceHash() != null) return true;
  } catch (_) {
    // Fall through to the durable migration checkpoint when the repository
    // cannot report its authority marker.
  }
  final preferences = await SharedPreferences.getInstance();
  final migrationState = preferences.getString(
    ConversationMigrationService.stateKey,
  );
  if (migrationState == null) return false;
  try {
    final decoded = jsonDecode(migrationState);
    return decoded is Map && decoded['verified'] == true;
  } catch (_) {
    return false;
  }
}

Future<bool> isConversationRepositoryAuthoritative(
  ConversationRepository repository,
) =>
    _hasAuthoritativeConversationRepository(repository);

void _collectRepositoryAttachmentPaths(Object? rawData, Set<String> paths) {
  if (rawData is! Map) {
    throw const FormatException('Invalid conversation repository export.');
  }
  void addMediaReference(Map<String, dynamic> reference) {
    for (final key in ['storagePath', 'reference', 'thumbnailPath']) {
      final path = _canonicalAttachmentPath(reference[key]);
      if (path != null) paths.add(path);
    }
  }

  final data = Map<String, dynamic>.from(rawData);
  final conversations = data['conversations'];
  if (conversations is List) {
    for (final raw in conversations) {
      if (raw is! Map) continue;
      final conversation = StroomConversation.fromMap(
        Map<String, dynamic>.from(raw),
      );
      for (final reference in conversationDraftAttachmentReferences(
        conversation,
      )) {
        addMediaReference(reference);
      }
    }
  }
  final messages = data['messages'];
  if (messages is List) {
    for (final raw in messages) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final record = data['messageEnvelopeVersion'] == 1
          ? row['record']
          : (row..remove('conversationId'));
      if (record is! Map) continue;
      final message = StroomMessage.fromMap(Map<String, dynamic>.from(record));
      for (final reference in conversationMessageMediaReferences(message)) {
        addMediaReference(reference);
      }
    }
  }
}

bool get _isBackupServiceFlutterTest {
  try {
    return Platform.environment['FLUTTER_TEST'] == 'true';
  } catch (_) {
    return false;
  }
}

Set<String> _collectAttachmentPathsFromJson(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    throw const FormatException('conversations must contain a JSON list.');
  }
  final paths = <String>{};
  for (final conv in decoded) {
    if (conv is! Map<String, dynamic>) continue;
    final rawMessages = conv['messages'];
    if (rawMessages is List) {
      for (final msg in rawMessages) {
        if (msg is! Map<String, dynamic>) continue;
        _collectAttachments(msg['attachments'], paths);
      }
    }
    _collectAttachments(conv['draftAttachments'], paths);
  }
  return paths;
}

void _collectAttachments(Object? rawAttachments, Set<String> paths) {
  if (rawAttachments is! List) return;
  for (final att in rawAttachments) {
    if (att is! Map<String, dynamic>) continue;
    for (final field in const ['storagePath', 'reference', 'thumbnailPath']) {
      final path = _canonicalAttachmentPath(att[field]);
      if (path != null) paths.add(path);
    }
  }
}

String? _canonicalAttachmentPath(Object? value) {
  if (value is! String || value.isEmpty) return null;
  if (RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(value)) return null;
  final slashPath = value.replaceAll('\\', '/');
  final pathSegments = slashPath.split('/');
  if (pathSegments.contains('..')) return null;
  if (slashPath.startsWith('temp_edited/')) {
    if (pathSegments.length != 2 ||
        pathSegments.any((segment) => segment.isEmpty || segment == '.')) {
      return null;
    }
    return 'attachments/${p.posix.basename(slashPath)}';
  }
  return slashPath;
}
