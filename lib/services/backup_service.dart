import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'manifest_database.dart';
import '../utils/app_version.dart';
import '../utils/web_file_store.dart';
import 'backup_service_shared.dart';
import 'storage_service.dart';

// ====================================================================
// BackupService — 数据备份与恢复
// ====================================================================
//
// 将应用数据导出为 zip 文件，或从 zip 文件恢复。
// 支持 Web 和 Native 双平台，全程在内存中构建/解析归档，
// 避免在 Web 上使用不受支持的 dart:io File/Directory。
// ====================================================================

class BackupService {
  BackupService._();

  static Future<String> createBackup({
    required String outputPath,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('createBackup is not available on web. Use exportBackup instead.');
    }
    final bytes = await _buildBackupBytes(onProgress: onProgress);
    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  static Future<void> restoreBackup(
    String zipPath, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('restoreBackup is not available on web. Use importBackup instead.');
    }
    final bytes = await File(zipPath).readAsBytes();
    await _restoreFromBytes(bytes, onProgress: onProgress);
  }

  // ================================================================
  // 核心：在内存中构建备份归档
  // ================================================================

  /// 构建备份归档的字节数据（双平台通用）。
  static Future<Uint8List> _buildBackupBytes({
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);
    final archive = Archive();

    // 1. manifest.json
    final manifest = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'appVersion': appVersion,
    };
    addStringToArchive(archive, 'manifest.json', jsonEncode(manifest));
    onProgress?.call(0.05);

    // 2. 数据库（按存储格式：根目录 stroom_manifest.json）
    final imageRecords = await ManifestDatabase.getAllImageRecords();
    final audioRecords = await ManifestDatabase.getAllAudioRecords();
    final videoRecords = await ManifestDatabase.getAllVideoRecords();
    final textRecords = await ManifestDatabase.getAllTextRecords();
    final folders = await ManifestDatabase.getAllFolders();
    // Per-type folder tables
    final textFolders = await ManifestDatabase.getAllFolders(recordTable: ManifestTables.textRecords);
    final audioFolders = await ManifestDatabase.getAllFolders(recordTable: ManifestTables.audioRecords);
    final imageFolders = await ManifestDatabase.getAllFolders(recordTable: ManifestTables.imageRecords);
    final videoFolders = await ManifestDatabase.getAllFolders(recordTable: ManifestTables.videoRecords);
    final dbData = {
      'image_records': imageRecords,
      'audio_records': audioRecords,
      'video_records': videoRecords,
      'text_records': textRecords,
      'folders': folders,
      ManifestTables.textFolders: textFolders,
      ManifestTables.audioFolders: audioFolders,
      ManifestTables.imageFolders: imageFolders,
      ManifestTables.videoFolders: videoFolders,
    };
    addStringToArchive(
        archive, 'stroom_manifest.json', jsonEncode(dbData));
    onProgress?.call(0.15);

    // 3. SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final prefData = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('flutter.')) continue;
      prefData[key] = prefs.get(key);
    }
    addStringToArchive(archive, 'preferences.json', jsonEncode(prefData));
    onProgress?.call(0.25);

    // 4. 任务文件（按存储格式：synthesis/tasks.json, catcatch/tasks.json）
    // 在测试模式下跳过文件系统操作以避免平台通道挂起
    if (!kIsWeb && !WebFileStore.isTestMode) {
      final appDir = await AppStorage.directory;
      await addTaskFileToArchive(archive, 'synthesis/tasks.json',
          p.join(appDir, 'synthesis', 'tasks.json'));
      await addTaskFileToArchive(archive, 'catcatch/tasks.json',
          p.join(appDir, 'catcatch', 'tasks.json'));
    } else {
      addStringToArchive(archive, 'synthesis/tasks.json', '[]');
      addStringToArchive(archive, 'catcatch/tasks.json', '[]');
    }
    onProgress?.call(0.35);

    // 5. 二进制文件（按存储格式：pictures/, tts_audio/, videos/, texts/, attachments/）
    for (final record in imageRecords) {
      final hash = record['hash'] as String?;
      final format = record['format'] as String? ?? 'jpg';
      if (hash == null) continue;
      await addFileToArchive(
          archive, 'pictures/$hash.$format', 'pictures', '$hash.$format');
      await addFileToArchive(archive, 'pictures/${hash}_thumb.png',
          'pictures', '${hash}_thumb.png');
    }
    onProgress?.call(0.5);

    for (final record in audioRecords) {
      final hash = record['hash'] as String?;
      final format = record['format'] as String? ?? 'wav';
      if (hash == null) continue;
      await addFileToArchive(archive, 'tts_audio/$hash.$format',
          'tts_audio', '$hash.$format');
      await addFileToArchive(
          archive, 'tts_audio/$hash.txt', 'tts_audio', '$hash.txt');
    }
    onProgress?.call(0.65);

    for (final record in videoRecords) {
      final hash = record['hash'] as String?;
      final format = record['format'] as String? ?? 'mp4';
      if (hash == null) continue;
      await addFileToArchive(archive, 'videos/$hash.$format', 'videos',
          '$hash.$format');
    }
    onProgress?.call(0.75);

    for (final record in textRecords) {
      final hash = record['hash'] as String?;
      if (hash == null) continue;
      await addFileToArchive(
          archive, 'texts/$hash.txt', 'texts', '$hash.txt');
    }
    onProgress?.call(0.8);

    final attachmentPaths = await collectAttachmentPaths();
    for (final storagePath in attachmentPaths) {
      final parts = storagePath.split('/');
      if (parts.length < 2) continue;
      final subDir = parts[0];
      final fileName = parts.sublist(1).join('/');
      await addFileToArchive(
          archive, storagePath, subDir, fileName);
    }
    onProgress?.call(0.85);

    // 6. 编码
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('zip 编码失败');
    }
    onProgress?.call(1.0);
    return Uint8List.fromList(encoded);
  }

  /// 从字节数据恢复备份（双平台通用）。
  static Future<void> _restoreFromBytes(
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);

    Archive? archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw Exception('无效的备份文件：无法解压 ($e)');
    }
    onProgress?.call(0.1);

    // 读取所有文件内容到内存 Map
    final fileMap = <String, Uint8List>{};
    for (final f in archive) {
      if (f.isFile) {
        fileMap[f.name] = Uint8List.fromList(f.content as List<int>);
      }
    }

    // 验证 manifest
    final manifestJson = fileMap['manifest.json'];
    if (manifestJson == null) {
      throw Exception('无效的备份文件：缺少 manifest.json');
    }
    final manifest =
        jsonDecode(utf8.decode(manifestJson)) as Map<String, dynamic>;
    final version = manifest['version'] as int? ?? 0;
    if (version != 1) {
      throw Exception('不支持的备份版本: $version');
    }
    onProgress?.call(0.15);

    // 恢复数据库（兼容新旧格式）
    final dbJson = fileMap['stroom_manifest.json']
        ?? fileMap['database/manifest_data.json'];
    if (dbJson != null) {
      await _restoreDatabaseFromJson(utf8.decode(dbJson));
    }
    onProgress?.call(0.4);

    // 恢复 SharedPreferences
    final prefJson = fileMap['preferences.json'];
    if (prefJson != null) {
      await _restorePreferencesFromJson(utf8.decode(prefJson));
    }
    onProgress?.call(0.55);

    // 恢复二进制文件和任务文件（兼容新旧两种路径格式）
    // 新格式: pictures/, tts_audio/, videos/, texts/, attachments/, synthesis/, catcatch/
    // 旧格式: files/pictures/, files/tts_audio/, ..., tasks/synthesis_tasks.json
    const knownDirs = ['pictures', 'tts_audio', 'videos', 'texts', 'attachments',
                       'synthesis', 'catcatch'];
    final skipFiles = {'manifest.json', 'stroom_manifest.json',
        'database/manifest_data.json', 'preferences.json'};

    for (final entry in fileMap.entries) {
      var key = entry.key;

      // 跳过元数据文件
      if (skipFiles.contains(key)) continue;

      // 旧格式 binary: 去掉 files/ 前缀
      if (key.startsWith('files/')) {
        key = key.substring('files/'.length);
      }

      // 旧格式 task: tasks/synthesis_tasks.json → synthesis/tasks.json
      if (key.startsWith('tasks/')) {
        key = key.substring('tasks/'.length);
        // synthesis_tasks.json → synthesis/tasks.json
        if (key == 'synthesis_tasks.json') key = 'synthesis/tasks.json';
        if (key == 'catcatch_tasks.json') key = 'catcatch/tasks.json';
      }

      // 匹配已知存储目录
      String? matchedDir;
      for (final dir in knownDirs) {
        if (key.startsWith('$dir/')) {
          matchedDir = dir;
          break;
        }
      }
      if (matchedDir == null) continue;

      final relativePath = key.substring(matchedDir.length + 1);

      if (matchedDir == 'synthesis' || matchedDir == 'catcatch') {
        if (relativePath == 'tasks.json') {
          await writeBackupFile(matchedDir, 'tasks.json', entry.value);
        }
        continue;
      }

      // 普通二进制文件
      await writeBackupFile(matchedDir, relativePath, entry.value);
    }
    onProgress?.call(1.0);
  }

  // ================================================================
  // 恢复辅助
  // ================================================================

  static Future<void> _restoreDatabaseFromJson(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final imageRecords = (data['image_records'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final audioRecords = (data['audio_records'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final videoRecords = (data['video_records'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final textRecords = (data['text_records'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final folders = (data['folders'] as List<dynamic>?)?.cast<String>() ?? [];

    // Per-type folders (v2+ backups)
    final textFolders = (data[ManifestTables.textFolders] as List<dynamic>?)
            ?.cast<String>() ??
        <String>[];
    final audioFolders = (data[ManifestTables.audioFolders] as List<dynamic>?)
            ?.cast<String>() ??
        <String>[];
    final imageFolders = (data[ManifestTables.imageFolders] as List<dynamic>?)
            ?.cast<String>() ??
        <String>[];
    final videoFolders = (data[ManifestTables.videoFolders] as List<dynamic>?)
            ?.cast<String>() ??
        <String>[];

    await ManifestDatabase.clearAllData();

    for (final record in imageRecords) {
      await ManifestDatabase.insertImageRecord(record);
    }
    for (final record in audioRecords) {
      await ManifestDatabase.insertAudioRecord(record);
    }
    for (final record in videoRecords) {
      await ManifestDatabase.insertVideoRecord(record);
    }
    for (final record in textRecords) {
      await ManifestDatabase.insertTextRecord(record);
    }

    // Restore per-type folders if available (v2+); otherwise fall back to shared folders
    if (textFolders.isNotEmpty ||
        audioFolders.isNotEmpty ||
        imageFolders.isNotEmpty ||
        videoFolders.isNotEmpty) {
      for (final folder in textFolders) {
        await ManifestDatabase.insertFolder(folder, recordTable: ManifestTables.textRecords);
      }
      for (final folder in audioFolders) {
        await ManifestDatabase.insertFolder(folder, recordTable: ManifestTables.audioRecords);
      }
      for (final folder in imageFolders) {
        await ManifestDatabase.insertFolder(folder, recordTable: ManifestTables.imageRecords);
      }
      for (final folder in videoFolders) {
        await ManifestDatabase.insertFolder(folder, recordTable: ManifestTables.videoRecords);
      }
    } else {
      // v1 backup (legacy): distribute shared folders to all 4 per-type tables
      for (final folder in folders) {
        await ManifestDatabase.insertFolder(folder, recordTable: ManifestTables.textRecords);
        await ManifestDatabase.insertFolder(folder, recordTable: ManifestTables.audioRecords);
        await ManifestDatabase.insertFolder(folder, recordTable: ManifestTables.imageRecords);
        await ManifestDatabase.insertFolder(folder, recordTable: ManifestTables.videoRecords);
      }
    }
  }

  static Future<void> _restorePreferencesFromJson(String json) async {
    final backupPrefs = jsonDecode(json) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();

    final keysToRemove = prefs
        .getKeys()
        .where((k) => !k.startsWith('flutter.'))
        .toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    for (final entry in backupPrefs.entries) {
      final v = entry.value;
      try {
        if (v is String) {
          await prefs.setString(entry.key, v);
        } else if (v is bool) {
          await prefs.setBool(entry.key, v);
        } else if (v is int) {
          await prefs.setInt(entry.key, v);
        } else if (v is double) {
          await prefs.setDouble(entry.key, v);
        } else if (v is List) {
          await prefs.setStringList(entry.key, v.cast<String>());
        }
      } catch (e) {
        debugPrint('恢复偏好设置 ${entry.key} 失败: $e');
      }
    }
  }

  // ================================================================
  // UI 便捷方法（双平台）
  // ================================================================

  /// 导出备份：弹出保存文件对话框，创建 zip。
  static Future<void> exportBackup(BuildContext context) async {
    try {
      final dateStr =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final defaultName = 'stroom_backup_$dateStr.zip';

      // 在内存中构建归档
      final bytes = await _buildBackupBytes();

      final outputPath = await FilePicker.saveFile(
        fileName: defaultName,
        bytes: bytes,
      );

      if (outputPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份已保存到: $outputPath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 导出当前数据的备份，让用户选择保存路径。
  static Future<String?> exportBackupAuto() async {
    try {
      final bytes = await _buildBackupBytes();
      final dateStr =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final defaultName = 'stroom_backup_$dateStr.zip';

      final outputPath = await FilePicker.saveFile(
        fileName: defaultName,
        bytes: bytes,
      );
      return outputPath;
    } catch (e) {
      debugPrint('自动备份失败: $e');
      return null;
    }
  }

  /// 导入备份：弹出打开文件对话框，从选中的 zip 恢复。
  static Future<void> importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes != null) {
        await _restoreFromBytes(bytes);
      } else if (file.path != null) {
        await restoreBackup(file.path!);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据恢复成功，请重启应用')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ================================================================
  // 测试辅助方法（@visibleForTesting）
  // ================================================================

  /// 公开 [_buildBackupBytes] 供测试使用。
  @visibleForTesting
  static Future<Uint8List> buildBackupBytesForTest({
    void Function(double progress)? onProgress,
  }) =>
      _buildBackupBytes(onProgress: onProgress);

  /// 公开 [_restoreFromBytes] 供测试使用。
  @visibleForTesting
  static Future<void> restoreFromBytesForTest(
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) =>
      _restoreFromBytes(bytes, onProgress: onProgress);

  /// 公开 [_restoreDatabaseFromJson] 供测试使用。
  @visibleForTesting
  static Future<void> restoreDatabaseFromJsonForTest(String json) =>
      _restoreDatabaseFromJson(json);
}
