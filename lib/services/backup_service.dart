import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service_shared.dart';
import 'data_migration_service.dart';
import 'manifest_database.dart';
import 'storage_service.dart';
import '../utils/app_version.dart';
import '../utils/web_file_store.dart';
import 'app_log_service.dart';

/// Exception thrown when a backup operation is cancelled.
class BackupCancelledException implements Exception {
  final String message;
  const BackupCancelledException([this.message = '备份操作已取消']);

  @override
  String toString() => message;
}

// ====================================================================
// BackupSelection — 选择性备份/恢复的数据类别
// ====================================================================
//
// 用于手动操作时选择要备份或恢复的数据类别。
// 自动备份时始终使用全量选择。
// ====================================================================

/// 备份/恢复的选择项。
///
/// 每个 bool 字段表示是否包含对应的数据类别。
/// 所有字段默认为 `true`（全量）。
class BackupSelection {
  /// 聊天记录配置（Preferences + 数据库记录）
  final bool conversations;

  /// 图片文件（pictures/）
  final bool pictures;

  /// 音频文件（tts_audio/）
  final bool audio;

  /// 视频文件（videos/）
  final bool videos;

  /// 文本文件（texts/）
  final bool texts;

  /// 任务文件（synthesis/ + catcatch/）
  final bool tasks;

  /// 附件文件（attachments/）
  final bool attachments;

  const BackupSelection({
    this.conversations = true,
    this.pictures = true,
    this.audio = true,
    this.videos = true,
    this.texts = true,
    this.tasks = true,
    this.attachments = true,
  });

  /// 全量选择（所有类别）。
  static const all = BackupSelection();

  /// 根据选择结果返回包含的类别名称列表（用于 UI 显示）。
  List<String> get selectedLabels {
    final labels = <String>[];
    if (conversations) labels.add('聊天记录和设置');
    if (pictures) labels.add('图片');
    if (audio) labels.add('音频');
    if (videos) labels.add('视频');
    if (texts) labels.add('文本');
    if (tasks) labels.add('任务');
    if (attachments) labels.add('附件');
    return labels;
  }
}

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
    bool Function()? isCancelled,
    BackupSelection selection = BackupSelection.all,
  }) async {
    await AppLogService.info(
        'BackupService', 'createBackup: outputPath=$outputPath');
    if (kIsWeb) {
      throw UnsupportedError(
          'createBackup is not available on web. Use exportBackup instead.');
    }
    if (isCancelled != null && isCancelled()) {
      throw const BackupCancelledException();
    }
    final bytes = await _buildBackupBytes(
        onProgress: onProgress, isCancelled: isCancelled, selection: selection);
    if (isCancelled != null && isCancelled()) {
      throw const BackupCancelledException();
    }
    await File(outputPath).writeAsBytes(bytes);
    await AppLogService.info('BackupService', 'createBackup: success');
    return outputPath;
  }

  static Future<void> restoreBackup(
    String zipPath, {
    void Function(double progress)? onProgress,
    BackupSelection selection = BackupSelection.all,
  }) async {
    await AppLogService.info(
        'BackupService', 'restoreBackup: zipPath=$zipPath');
    if (kIsWeb) {
      throw UnsupportedError(
          'restoreBackup is not available on web. Use importBackup instead.');
    }
    final bytes = await File(zipPath).readAsBytes();
    await _restoreFromBytes(bytes, onProgress: onProgress, selection: selection);
  }

  // ================================================================
  // 核心：在内存中构建备份归档
  // ================================================================

  /// 短暂的延迟以让出事件循环，确保 UI 可以处理帧渲染。
  /// 这是防止导出备份时页面冻结的关键机制。
  ///
  /// 生产环境中使用 1ms 定时器，确保事件循环有机会处理帧渲染请求；
  /// 测试环境中使用 Future.microtask，因为 Flutter 测试的 FakeAsync Zone
  /// 会将所有 Future.delayed 创建为 FakeTimer，无法被简单的 await 推进，
  /// 必须通过 pump() 才能完成。
  static Future<void> _yieldToEventLoop() {
    // 测试环境：使用微任务（FakeAsync 中不会创建 FakeTimer）
    if (WebFileStore.isTestMode) {
      return Future<void>.microtask(() {});
    }
    // 生产环境：1ms 定时器，通过事件循环让出给帧渲染
    return Future<void>.delayed(const Duration(milliseconds: 1));
  }

  /// 将 Archive 中的文件列表提取为可跨隔离传输的格式。
  static List<Map<String, Object?>> _extractArchiveFiles(Archive archive) {
    final files = <Map<String, Object?>>[];
    for (final file in archive.files) {
      if (file.isFile) {
        files.add({
          'name': file.name,
          'size': file.size,
          'content': Uint8List.fromList(file.content as List<int>),
        });
      }
    }
    return files;
  }

  /// 在后台隔离（Isolate）中执行 zip 编码，避免阻塞主 UI 线程。
  ///
  /// [files] 是 [_extractArchiveFiles] 提取的可传输文件列表。
  /// 在测试模式下（Isolate 无法在 Flutter 测试环境的 FakeAsync Zone 中正常
  /// 工作），回退到同步编码。在其他不支持 Isolate 的环境也回退到同步编码。
  static Future<Uint8List> _encodeArchiveInBackground(
      List<Map<String, Object?>> files) async {
    // 测试模式下无法使用 Isolate.run（FakeAsync Zone 不支持真正的 Isolate），
    // 回退到同步编码
    if (WebFileStore.isTestMode) {
      return _encodeArchiveSync(files);
    }

    try {
      return await Isolate.run(() {
        final archive = Archive();
        for (final f in files) {
          final name = f['name'] as String;
          final content = f['content'] as Uint8List;
          archive.addFile(ArchiveFile(name, content.length, content));
        }
        final encoded = ZipEncoder().encode(archive);
        return Uint8List.fromList(encoded);
      });
    } on UnsupportedError catch (e) {
      // Isolate 不可用（如部分 Web 环境），回退到同步编码
      // 同步编码会短暂阻塞主线程，但至少功能可用
      debugPrint('Isolate 编码不可用，回退到同步编码: $e');
      return _encodeArchiveSync(files);
    }
  }

  /// 同步编码（回退路径）— 直接在当前线程执行 zip 编码。
  static Uint8List _encodeArchiveSync(List<Map<String, Object?>> files) {
    final archive = Archive();
    for (final f in files) {
      final name = f['name'] as String;
      final content = f['content'] as Uint8List;
      archive.addFile(ArchiveFile(name, content.length, content));
    }
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// 构建备份归档的字节数据（双平台通用）。
  ///
  /// [isCancelled] 是一个可选的回调，在每次让出事件循环时被调用。
  /// 如果返回 `true`，则抛出 [BackupCancelledException] 终止备份。
  ///
  /// [selection] 控制哪些数据类别包含在归档中。默认全量。
  /// 自动备份始终使用全量选择。
  static Future<Uint8List> _buildBackupBytes({
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
    BackupSelection selection = BackupSelection.all,
  }) async {
    void checkCancelled() {
      if (isCancelled != null && isCancelled()) {
        throw const BackupCancelledException();
      }
    }

    onProgress?.call(0.0);
    await _yieldToEventLoop();
    checkCancelled();
    final archive = Archive();

    // 1. manifest.json（始终包含）
    debugPrint('[BackupService] _buildBackupBytes: building manifest');
    final manifest = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'appVersion': appVersion,
    };
    addStringToArchive(archive, 'manifest.json', jsonEncode(manifest));
    onProgress?.call(0.05);
    await _yieldToEventLoop();
    checkCancelled();

    // 2. 数据库（按存储格式：根目录 stroom_manifest.json）
    debugPrint('[BackupService] _buildBackupBytes: reading database');
    final imageRecords = selection.pictures
        ? await ManifestDatabase.getAllImageRecords()
        : <Map<String, dynamic>>[];
    final audioRecords = selection.audio
        ? await ManifestDatabase.getAllAudioRecords()
        : <Map<String, dynamic>>[];
    final videoRecords = selection.videos
        ? await ManifestDatabase.getAllVideoRecords()
        : <Map<String, dynamic>>[];
    final textRecords = selection.texts
        ? await ManifestDatabase.getAllTextRecords()
        : <Map<String, dynamic>>[];
    final folders = <String>[];
    final textFolders = selection.texts
        ? await ManifestDatabase.getAllFolders(
            recordTable: ManifestTables.textRecords)
        : <String>[];
    final audioFolders = selection.audio
        ? await ManifestDatabase.getAllFolders(
            recordTable: ManifestTables.audioRecords)
        : <String>[];
    final imageFolders = selection.pictures
        ? await ManifestDatabase.getAllFolders(
            recordTable: ManifestTables.imageRecords)
        : <String>[];
    final videoFolders = selection.videos
        ? await ManifestDatabase.getAllFolders(
            recordTable: ManifestTables.videoRecords)
        : <String>[];
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
    addStringToArchive(archive, 'stroom_manifest.json', jsonEncode(dbData));
    onProgress?.call(0.15);
    await _yieldToEventLoop();
    checkCancelled();

    // 3. SharedPreferences（仅在选中 conversations 时包含）
    if (selection.conversations) {
      debugPrint('[BackupService] _buildBackupBytes: reading preferences');
      final prefs = await SharedPreferences.getInstance();
      final prefData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        prefData[key] = prefs.get(key);
      }
      addStringToArchive(archive, 'preferences.json', jsonEncode(prefData));
    }
    onProgress?.call(0.25);
    await _yieldToEventLoop();
    checkCancelled();

    // 4. 任务文件（按存储格式：synthesis/tasks.json, catcatch/tasks.json）
    if (selection.tasks) {
      debugPrint('[BackupService] _buildBackupBytes: adding task files');
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
    }
    onProgress?.call(0.35);
    await _yieldToEventLoop();
    checkCancelled();

    // 5. 二进制文件（按存储格式：pictures/, tts_audio/, videos/, texts/, attachments/）
    debugPrint('[BackupService] _buildBackupBytes: adding binary files');

    if (selection.pictures) {
      for (var i = 0; i < imageRecords.length; i++) {
        final record = imageRecords[i];
        final hash = record['hash'] as String?;
        final format = record['format'] as String? ?? 'jpg';
        if (hash == null) continue;
        await addFileToArchive(
            archive, 'pictures/$hash.$format', 'pictures', '$hash.$format');
        await addFileToArchive(archive, 'pictures/${hash}_thumb.png',
            'pictures', '${hash}_thumb.png');
        if (i % 10 == 0) {
          await _yieldToEventLoop();
          checkCancelled();
        }
      }
    }
    onProgress?.call(0.5);
    await _yieldToEventLoop();
    checkCancelled();

    if (selection.audio) {
      for (var i = 0; i < audioRecords.length; i++) {
        final record = audioRecords[i];
        final hash = record['hash'] as String?;
        final format = record['format'] as String? ?? 'wav';
        if (hash == null) continue;
        await addFileToArchive(
            archive, 'tts_audio/$hash.$format', 'tts_audio', '$hash.$format');
        await addFileToArchive(
            archive, 'tts_audio/$hash.txt', 'tts_audio', '$hash.txt');
        if (i % 10 == 0) {
          await _yieldToEventLoop();
          checkCancelled();
        }
      }
    }
    onProgress?.call(0.65);
    await _yieldToEventLoop();
    checkCancelled();

    if (selection.videos) {
      for (var i = 0; i < videoRecords.length; i++) {
        final record = videoRecords[i];
        final hash = record['hash'] as String?;
        final format = record['format'] as String? ?? 'mp4';
        if (hash == null) continue;
        await addFileToArchive(
            archive, 'videos/$hash.$format', 'videos', '$hash.$format');
        if (i % 10 == 0) {
          await _yieldToEventLoop();
          checkCancelled();
        }
      }
    }
    onProgress?.call(0.75);
    await _yieldToEventLoop();
    checkCancelled();

    if (selection.texts) {
      for (var i = 0; i < textRecords.length; i++) {
        final record = textRecords[i];
        final hash = record['hash'] as String?;
        if (hash == null) continue;
        await addFileToArchive(
            archive, 'texts/$hash.txt', 'texts', '$hash.txt');
        if (i % 10 == 0) {
          await _yieldToEventLoop();
          checkCancelled();
        }
      }
    }
    onProgress?.call(0.8);
    await _yieldToEventLoop();
    checkCancelled();

    if (selection.attachments) {
      final attachmentPaths = await collectAttachmentPaths();
      final pathList = attachmentPaths.toList();
      for (var i = 0; i < pathList.length; i++) {
        final storagePath = pathList[i];
        final parts = storagePath.split('/');
        if (parts.length < 2) continue;
        final subDir = parts[0];
        final fileName = parts.sublist(1).join('/');
        await addFileToArchive(archive, storagePath, subDir, fileName);
        if (i % 10 == 0) {
          await _yieldToEventLoop();
          checkCancelled();
        }
      }
    }
    onProgress?.call(0.85);
    await _yieldToEventLoop();
    checkCancelled();

    // 6. 编码 — 在后台隔离中执行，不阻塞主 UI 线程
    debugPrint('[BackupService] _buildBackupBytes: encoding archive');
    final files = _extractArchiveFiles(archive);
    onProgress?.call(0.9);
    await _yieldToEventLoop();
    checkCancelled();

    final encoded = await _encodeArchiveInBackground(files);
    onProgress?.call(1.0);
    return encoded;
  }

  /// 从字节数据恢复备份（双平台通用）。
  ///
  /// [selection] 控制只恢复哪些数据类别。默认全量恢复。
  static Future<void> _restoreFromBytes(
    Uint8List bytes, {
    void Function(double progress)? onProgress,
    BackupSelection selection = BackupSelection.all,
  }) async {
    onProgress?.call(0.0);
    await _yieldToEventLoop();

    Archive? archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      debugPrint('[BackupService] _restoreFromBytes: 备份文件解压失败: $e');
      throw Exception('无效的备份文件：无法解压 ($e)');
    }
    onProgress?.call(0.1);
    await _yieldToEventLoop();

    // 读取所有文件内容到内存 Map
    final fileMap = <String, Uint8List>{};
    var fileIndex = 0;
    for (final f in archive) {
      if (f.isFile) {
        fileMap[f.name] = Uint8List.fromList(f.content as List<int>);
      }
      fileIndex++;
      if (fileIndex % 50 == 0) await _yieldToEventLoop();
    }

    debugPrint(
        '[BackupService] _restoreFromBytes: archive decoded (${fileMap.length} files)');

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
    await _yieldToEventLoop();

    // 恢复数据库记录（兼容新旧格式）
    // 数据库记录（media metadata）不属于"聊天记录和设置"，
    // 各自受对应的 selection 标志控制（pictures, audio 等）
    debugPrint('[BackupService] _restoreFromBytes: restoring database');
    final dbJson = fileMap['stroom_manifest.json'] ??
        fileMap['database/manifest_data.json'];
    if (dbJson != null) {
      await _restoreDatabaseFromJson(utf8.decode(dbJson),
          selection: selection);
    }
    onProgress?.call(0.4);
    await _yieldToEventLoop();

    // 恢复 SharedPreferences（受 conversations 标志控制）
    if (selection.conversations) {
      debugPrint('[BackupService] _restoreFromBytes: restoring preferences');
      final prefJson = fileMap['preferences.json'];
      if (prefJson != null) {
        await _restorePreferencesFromJson(utf8.decode(prefJson));
      }
    }
    onProgress?.call(0.55);
    await _yieldToEventLoop();

    debugPrint(
        '[BackupService] _restoreFromBytes: restoring binary files (selection: ${selection.selectedLabels})');
    // 恢复二进制文件和任务文件（兼容新旧两种路径格式）
    // 新格式: pictures/, tts_audio/, videos/, texts/, attachments/, synthesis/, catcatch/
    // 旧格式: files/pictures/, files/tts_audio/, ..., tasks/synthesis_tasks.json
    const knownDirs = [
      'pictures',
      'tts_audio',
      'videos',
      'texts',
      'attachments',
      'synthesis',
      'catcatch'
    ];
    final skipFiles = {
      'manifest.json',
      'stroom_manifest.json',
      'database/manifest_data.json',
      'preferences.json'
    };

    // 根据 selection 决定哪些目录需要恢复
    bool shouldRestoreDir(String dir) {
      switch (dir) {
        case 'pictures':
          return selection.pictures;
        case 'tts_audio':
          return selection.audio;
        case 'videos':
          return selection.videos;
        case 'texts':
          return selection.texts;
        case 'synthesis':
        case 'catcatch':
          return selection.tasks;
        case 'attachments':
          return selection.attachments;
        default:
          return false;
      }
    }

    var restoreIndex = 0;
    for (final entry in fileMap.entries) {
      var key = entry.key;

      // 跳过元数据文件
      if (skipFiles.contains(key)) {
        restoreIndex++;
        continue;
      }

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
      if (matchedDir == null) {
        restoreIndex++;
        continue;
      }

      // 根据 selection 跳过不需要恢复的目录
      if (!shouldRestoreDir(matchedDir)) {
        restoreIndex++;
        continue;
      }

      final relativePath = key.substring(matchedDir.length + 1);

      if (matchedDir == 'synthesis' || matchedDir == 'catcatch') {
        if (relativePath == 'tasks.json') {
          await writeBackupFile(matchedDir, 'tasks.json', entry.value);
        }
        restoreIndex++;
        continue;
      }

      // 普通二进制文件
      await writeBackupFile(matchedDir, relativePath, entry.value);
      restoreIndex++;
      // 每处理 20 个文件让出事件循环
      if (restoreIndex % 20 == 0) await _yieldToEventLoop();
    }

    // 数据迁移：确保恢复后的数据格式是最新的
    // 旧格式备份（pre-migration）中包含 chat_configs、null IDs 等，
    // 需要迁移到当前数据格式才能正常使用。
    await DataMigrationService.migrateDataFormatIfNeeded();
    onProgress?.call(1.0);
  }

  // ================================================================
  // 恢复辅助
  // ================================================================

  static Future<void> _restoreDatabaseFromJson(
    String json, {
    BackupSelection selection = BackupSelection.all,
  }) async {
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

    // Per-type folders (v2+ backups)
    final textFolders =
        (data[ManifestTables.textFolders] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final audioFolders =
        (data[ManifestTables.audioFolders] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final imageFolders =
        (data[ManifestTables.imageFolders] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final videoFolders =
        (data[ManifestTables.videoFolders] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final folders = (data['folders'] as List<dynamic>?)?.cast<String>() ?? [];

    debugPrint('[BackupService] _restoreDatabaseFromJson: '
        'image(${imageRecords.length}) audio(${audioRecords.length}) '
        'video(${videoRecords.length}) text(${textRecords.length})');

    // 选择性恢复：只清除并恢复选中的记录类型
    if (selection.pictures) {
      await ManifestDatabase.clearRecords('image_records');
      for (final record in imageRecords) {
        await ManifestDatabase.insertImageRecord(record);
      }
    }
    if (selection.audio) {
      await ManifestDatabase.clearRecords('audio_records');
      for (final record in audioRecords) {
        await ManifestDatabase.insertAudioRecord(record);
      }
    }
    if (selection.videos) {
      await ManifestDatabase.clearRecords('video_records');
      for (final record in videoRecords) {
        await ManifestDatabase.insertVideoRecord(record);
      }
    }
    if (selection.texts) {
      await ManifestDatabase.clearRecords('text_records');
      for (final record in textRecords) {
        await ManifestDatabase.insertTextRecord(record);
      }
    }

    // Restore folders only for selected record types
    // 与记录清除一致：选中即先清除，再从备份中恢复（备份可能为空）
    if (selection.texts) {
      final dirs = textFolders.isNotEmpty ? textFolders : folders;
      await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.textRecords);
      for (final folder in dirs) {
        await ManifestDatabase.insertFolder(folder,
            recordTable: ManifestTables.textRecords);
      }
    }
    if (selection.audio) {
      final dirs = audioFolders.isNotEmpty ? audioFolders : folders;
      await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.audioRecords);
      for (final folder in dirs) {
        await ManifestDatabase.insertFolder(folder,
            recordTable: ManifestTables.audioRecords);
      }
    }
    if (selection.pictures) {
      final dirs = imageFolders.isNotEmpty ? imageFolders : folders;
      await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.imageRecords);
      for (final folder in dirs) {
        await ManifestDatabase.insertFolder(folder,
            recordTable: ManifestTables.imageRecords);
      }
    }
    if (selection.videos) {
      final dirs = videoFolders.isNotEmpty ? videoFolders : folders;
      await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.videoRecords);
      for (final folder in dirs) {
        await ManifestDatabase.insertFolder(folder,
            recordTable: ManifestTables.videoRecords);
      }
    }
  }

  static Future<void> _restorePreferencesFromJson(String json) async {
    final backupPrefs = jsonDecode(json) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();

    final keysToRemove =
        prefs.getKeys().where((k) => !k.startsWith('flutter.')).toList();
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
    await AppLogService.info('BackupService',
        '_restorePreferencesFromJson: restored ${backupPrefs.length} keys');
  }

  // ================================================================
  // UI 便捷方法（双平台）
  // ================================================================

  /// 导出备份：弹出保存文件对话框，创建 zip。
  ///
  /// [onProgress] 可选回调，报告备份构建进度（0.0 ~ 1.0）。
  /// [selection] 控制哪些数据类别包含在备份中。默认全量。
  static Future<void> exportBackup(
    BuildContext context, {
    void Function(double progress)? onProgress,
    BackupSelection selection = BackupSelection.all,
  }) async {
    await AppLogService.info('BackupService', 'exportBackup: start');
    try {
      final dateStr =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final defaultName = 'stroom_backup_$dateStr.zip';

      // 在内存中构建归档（传递进度回调）
      final bytes = await _buildBackupBytes(
          onProgress: onProgress, selection: selection);

      final outputPath = await FilePicker.saveFile(
        fileName: defaultName,
        bytes: bytes,
      );

      if (outputPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份已保存到: $outputPath')),
        );
      }
      await AppLogService.info('BackupService', 'exportBackup: success');
    } catch (e) {
      await AppLogService.error('BackupService', 'exportBackup: 失败', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 导入备份：弹出打开文件对话框，从选中的 zip 恢复。
  ///
  /// [selection] 控制只恢复哪些数据类别。默认全量恢复。
  /// 返回 `true` 表示恢复成功，`false` 表示用户取消或失败。
  static Future<bool> importBackup(
    BuildContext context, {
    BackupSelection selection = BackupSelection.all,
  }) async {
    await AppLogService.info('BackupService', 'importBackup: start');
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty) return false;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes != null) {
        await _restoreFromBytes(bytes, selection: selection);
      } else if (file.path != null) {
        await restoreBackup(file.path!, selection: selection);
      }

      // 恢复成功 — 让调用方处理倒计时和重启
      await AppLogService.info('BackupService', 'importBackup: success');
      return true;
    } catch (e) {
      await AppLogService.error('BackupService', 'importBackup: 失败', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // ================================================================
  // 测试辅助方法（@visibleForTesting）
  // ================================================================

  /// 公开 [_buildBackupBytes] 供测试使用。
  @visibleForTesting
  static Future<Uint8List> buildBackupBytesForTest({
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
    BackupSelection selection = BackupSelection.all,
  }) =>
      _buildBackupBytes(
          onProgress: onProgress,
          isCancelled: isCancelled,
          selection: selection);

  /// 公开 [_restoreFromBytes] 供测试使用。
  @visibleForTesting
  static Future<void> restoreFromBytesForTest(
    Uint8List bytes, {
    void Function(double progress)? onProgress,
    BackupSelection selection = BackupSelection.all,
  }) =>
      _restoreFromBytes(bytes, onProgress: onProgress, selection: selection);

  /// 公开 [_restoreDatabaseFromJson] 供测试使用。
  @visibleForTesting
  static Future<void> restoreDatabaseFromJsonForTest(
    String json, {
    BackupSelection selection = BackupSelection.all,
  }) =>
      _restoreDatabaseFromJson(json, selection: selection);
}
