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
import '../anki/database/anki_database.dart';
import '../utils/app_version.dart';
import '../utils/image_thumbnail_loader.dart';
import '../utils/system_pick_utils.dart';
import '../utils/web_file_store.dart';
import 'app_log_service.dart';

/// Exception thrown when a backup operation is cancelled.
class BackupCancelledException implements Exception {
  final String message;
  const BackupCancelledException([this.message = '备份操作已取消']);

  @override
  String toString() => message;
}

/// Exception thrown when a backup file fails validation BEFORE any
/// existing data is touched (invalid/corrupt archive, manifest, JSON).
///
/// 调用方可用 `is BackupValidationException` 区分"恢复开始前就失败"
/// （未删除任何数据，无需重启）与"恢复中途失败"（可能已部分清除）。
class BackupValidationException implements Exception {
  final String message;
  const BackupValidationException(this.message);

  @override
  String toString() => message;
}

// ====================================================================
// BackupSelection — 选择性备份/恢复的数据类别
// ====================================================================
//
// 用于手动操作时选择要备份或恢复的数据类别。
// 自动备份时始终使用全量选择。
//
// 【重要】该类字段变更说明：
// - v1: conversations(聊天记录和设置) + attachments(附件)
// - v2: 将 conversations 拆分为 chatRecordsAndAttachments(聊天记录和附件)
//       和 settings(设置)，attachments 合并到 chatRecordsAndAttachments
// ====================================================================

/// 备份/恢复的选择项。
///
/// 每个 bool 字段表示是否包含对应的数据类别。
/// 所有字段默认为 `true`（全量）。
class BackupSelection {
  /// 聊天记录和附件（聊天相关Preferences + 附件文件）
  final bool chatRecordsAndAttachments;

  /// 设置（设置相关Preferences）
  final bool settings;

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

  /// Anki 闪卡原始数据库（collection.anki2）
  final bool ankiData;

  /// 浏览器Cookies持久化数据（browser_cookies.json）
  final bool browserCookies;

  /// 是否包含媒体文件与附件文件（图片/音频/视频/文本/附件本体）。
  ///
  /// 默认 true（手动备份全量）。设为 false 时只收集结构化数据：
  /// 媒体**记录**（stroom_manifest.json）与聊天记录照常打包，
  /// 但媒体/附件**文件**不进备份 —— 用于私有目录结构化快照
  /// （文件是内容寻址的，损坏风险低；结构化数据才是损坏高发区）。
  final bool includeMediaFiles;

  const BackupSelection({
    this.chatRecordsAndAttachments = true,
    this.settings = true,
    this.pictures = true,
    this.audio = true,
    this.videos = true,
    this.texts = true,
    this.tasks = true,
    this.ankiData = true,
    this.browserCookies = true,
    this.includeMediaFiles = true,
  });

  /// 全量选择（所有类别）。
  static const all = BackupSelection();

  /// 结构化数据快照选择：记录/配置/任务全包含，媒体与附件文件排除。
  static const structuredOnly = BackupSelection(includeMediaFiles: false);

  /// 根据选择结果返回包含的类别名称列表（用于 UI 显示）。
  List<String> get selectedLabels {
    final labels = <String>[];
    if (chatRecordsAndAttachments) labels.add('聊天记录和附件');
    if (settings) labels.add('设置');
    if (pictures) labels.add('图片');
    if (audio) labels.add('音频');
    if (videos) labels.add('视频');
    if (texts) labels.add('文本');
    if (tasks) labels.add('任务');
    if (ankiData) labels.add('Anki闪卡数据');
    if (browserCookies) labels.add('浏览器Cookies');
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
    // 使用流式写入：逐个文件处理并直接写入磁盘，
    // 峰值内存从 O(总备份大小) 降低到 O(最大单文件大小)。
    await _createBackupStreaming(
      outputPath: outputPath,
      onProgress: onProgress,
      isCancelled: isCancelled,
      selection: selection,
    );
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
    await _restoreFromBytes(bytes,
        onProgress: onProgress, selection: selection);
  }

  // ================================================================
  // 核心：流式备份 — 收集计划 + 后台 isolate 构建，UI 零阻塞
  // ================================================================

  /// 流式创建备份。
  ///
  /// 分两个阶段：
  /// 1. 主 isolate 收集备份计划（数据库/偏好设置/文件路径，轻量异步）；
  /// 2. 后台 isolate 同步构建 ZIP（store 模式，磁盘到磁盘流式写入，
  ///    不经过内存缓冲）。
  ///
  /// 为什么必须放后台 isolate：即使使用 store 模式流式写入，
  /// 单个大文件（如 600MB 视频）的 CRC32 计算与分块读写仍是同步 CPU
  /// 密集操作，在主 isolate 执行会冻结整个应用前端。放入后台 isolate
  /// 后主 isolate 只需 await，UI 帧渲染完全不受影响（与音频分离的
  /// [Isolate.run] 方案一致）。
  ///
  /// 峰值内存：O(最大单文件的分块读取缓冲 64KB + CRC32 计算缓冲 1MB)，
  /// 不随备份文件数量或单文件大小增长。
  ///
  /// 仅限原生平台（使用 dart:io）。Web 平台请使用 [_buildBackupBytes]。
  static Future<void> _createBackupStreaming({
    required String outputPath,
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

    // ------------------------------------------------------------
    // 第 1 阶段（主 isolate）：收集备份计划（轻量异步操作）。
    // ------------------------------------------------------------
    final plan = await _collectBackupPlan(
      selection: selection,
      checkCancelled: checkCancelled,
      onProgress: onProgress,
    );

    // ------------------------------------------------------------
    // 第 2 阶段：同步构建 ZIP。
    // 生产环境放后台 isolate；测试环境（FakeAsync 不支持真实
    // Isolate）在调用方 isolate 同步执行并保留逐文件取消检查。
    // ------------------------------------------------------------
    debugPrint('[BackupService] streaming: building archive in background');
    onProgress?.call(0.95);
    checkCancelled();
    if (WebFileStore.isTestMode) {
      _createBackupStreamingSync(
          plan.jsonFiles, plan.memoryFiles, plan.diskFiles, outputPath,
          isCancelled: isCancelled);
    } else {
      try {
        await Isolate.run(() => _createBackupStreamingSync(
            plan.jsonFiles, plan.memoryFiles, plan.diskFiles, outputPath));
      } on UnsupportedError catch (e) {
        // Isolate 不可用（受限环境）：回退主 isolate 同步执行
        debugPrint('[BackupService] Isolate 不可用，回退同步执行: $e');
        _createBackupStreamingSync(
            plan.jsonFiles, plan.memoryFiles, plan.diskFiles, outputPath,
            isCancelled: isCancelled);
      }
    }
    onProgress?.call(1.0);
    await _yieldToEventLoop();
    checkCancelled();
  }

  /// 主 isolate 收集备份计划。
  ///
  /// 只执行轻量异步操作（数据库记录、偏好设置、附件路径收集），
  /// 所有大文件读写都推迟到 [._createBackupStreamingSync] 执行。
  static Future<_BackupPlan> _collectBackupPlan({
    required BackupSelection selection,
    required void Function() checkCancelled,
    void Function(double progress)? onProgress,
  }) async {
    final jsonFiles = <String, String>{};
    final memoryFiles = <String, Uint8List>{};
    final diskFiles = <List<String>>[];
    final useStreaming = !kIsWeb && !WebFileStore.isTestMode;

    // 1. manifest.json
    debugPrint('[BackupService] streaming: building manifest');
    jsonFiles['manifest.json'] = jsonEncode({
      'version': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'appVersion': appVersion,
    });
    onProgress?.call(0.05);
    await _yieldToEventLoop();
    checkCancelled();

    // 2. SharedPreferences — 拆分聊天记录和设置
    if (selection.chatRecordsAndAttachments || selection.settings) {
      debugPrint('[BackupService] streaming: reading preferences');
      final prefs = await SharedPreferences.getInstance();
      final chatData = <String, dynamic>{};
      final settingsData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        if (_isChatPrefKey(key)) {
          if (selection.chatRecordsAndAttachments) {
            chatData[key] = prefs.get(key);
          }
        } else {
          if (selection.settings) {
            settingsData[key] = prefs.get(key);
          }
        }
      }
      if (chatData.isNotEmpty) {
        jsonFiles['chat_data.json'] = jsonEncode(chatData);
      }
      if (settingsData.isNotEmpty) {
        jsonFiles['settings.json'] = jsonEncode(settingsData);
      }
    }
    onProgress?.call(0.15);
    await _yieldToEventLoop();
    checkCancelled();

    // 3. 任务文件 + Anki + Cookies
    if (selection.tasks) {
      debugPrint('[BackupService] streaming: adding task files');
      final appDir = await AppStorage.directory;
      await _addPlanFile(diskFiles, memoryFiles, 'synthesis/tasks.json',
          p.join(appDir, 'synthesis', 'tasks.json'), useStreaming);
      await _addPlanFile(diskFiles, memoryFiles, 'catcatch/tasks.json',
          p.join(appDir, 'catcatch', 'tasks.json'), useStreaming);
      await _addPlanFile(diskFiles, memoryFiles, 'background/tasks.json',
          p.join(appDir, 'background', 'tasks.json'), useStreaming);
      await _addPlanFile(diskFiles, memoryFiles, 'task_flows/flows.json',
          p.join(appDir, 'task_flows', 'flows.json'), useStreaming);
      await _addPlanFile(diskFiles, memoryFiles,
          'task_flows/executions.json',
          p.join(appDir, 'task_flows', 'executions.json'), useStreaming);
    }
    if (selection.ankiData) {
      try {
        final appDir = await AppStorage.directory;
        final ankiDb = p.join(appDir, 'collection.anki2');
        if (File(ankiDb).existsSync()) {
          await _addPlanFile(diskFiles, memoryFiles, 'anki/collection.anki2',
              ankiDb, useStreaming);
        }
      } catch (_) {}
    }
    if (selection.browserCookies) {
      try {
        final appDir = await AppStorage.directory;
        final cookiesFile = p.join(appDir, 'browser_cookies.json');
        if (File(cookiesFile).existsSync()) {
          await _addPlanFile(diskFiles, memoryFiles, 'browser_cookies.json',
              cookiesFile, useStreaming);
        }
      } catch (_) {}
    }
    onProgress?.call(0.25);
    await _yieldToEventLoop();
    checkCancelled();

    // 4. 二进制文件 — 逐个处理，用到时才加载数据库记录
    debugPrint('[BackupService] streaming: adding binary files');
    final appDir = await AppStorage.directory;
    List<Map<String, dynamic>>? manifestImageRecords;
    List<Map<String, dynamic>>? manifestAudioRecords;
    List<Map<String, dynamic>>? manifestVideoRecords;
    List<Map<String, dynamic>>? manifestTextRecords;
    List<String>? manifestTextFolders;
    List<String>? manifestAudioFolders;
    List<String>? manifestImageFolders;
    List<String>? manifestVideoFolders;

    // 图片
    if (selection.pictures) {
      final records = await ManifestDatabase.getAllImageRecords();
      manifestImageRecords = records;
      manifestImageFolders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.imageRecords);
      if (selection.includeMediaFiles) {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final hash = record['hash'] as String?;
          final format = record['format'] as String? ?? 'jpg';
          if (hash == null) continue;
          await _addPlanFile(diskFiles, memoryFiles, 'pictures/$hash.$format',
              p.join(appDir, 'pictures', '$hash.$format'), useStreaming);
          await _addPlanFile(
              diskFiles,
              memoryFiles,
              'pictures/${imageThumbFileName(hash)}',
              p.join(appDir, 'pictures', imageThumbFileName(hash)),
              useStreaming);
          if (i % 10 == 0) {
            await _yieldToEventLoop();
            checkCancelled();
          }
        }
      }
    }
    onProgress?.call(0.45);
    await _yieldToEventLoop();
    checkCancelled();

    // 音频
    if (selection.audio) {
      final records = await ManifestDatabase.getAllAudioRecords();
      manifestAudioRecords = records;
      manifestAudioFolders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.audioRecords);
      if (selection.includeMediaFiles) {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final hash = record['hash'] as String?;
          final format = record['format'] as String? ?? 'wav';
          if (hash == null) continue;
          await _addPlanFile(diskFiles, memoryFiles, 'tts_audio/$hash.$format',
              p.join(appDir, 'tts_audio', '$hash.$format'), useStreaming);
          await _addPlanFile(diskFiles, memoryFiles, 'tts_audio/$hash.txt',
              p.join(appDir, 'tts_audio', '$hash.txt'), useStreaming);
          if (i % 10 == 0) {
            await _yieldToEventLoop();
            checkCancelled();
          }
        }
      }
    }
    onProgress?.call(0.6);
    await _yieldToEventLoop();
    checkCancelled();

    // 视频
    if (selection.videos) {
      final records = await ManifestDatabase.getAllVideoRecords();
      manifestVideoRecords = records;
      manifestVideoFolders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.videoRecords);
      if (selection.includeMediaFiles) {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final hash = record['hash'] as String?;
          final format = record['format'] as String? ?? 'mp4';
          if (hash == null) continue;
          await _addPlanFile(diskFiles, memoryFiles, 'videos/$hash.$format',
              p.join(appDir, 'videos', '$hash.$format'), useStreaming);
          if (i % 10 == 0) {
            await _yieldToEventLoop();
            checkCancelled();
          }
        }
      }
    }
    onProgress?.call(0.75);
    await _yieldToEventLoop();
    checkCancelled();

    // 文本
    if (selection.texts) {
      final records = await ManifestDatabase.getAllTextRecords();
      manifestTextRecords = records;
      manifestTextFolders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.textRecords);
      if (selection.includeMediaFiles) {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final hash = record['hash'] as String?;
          if (hash == null) continue;
          await _addPlanFile(diskFiles, memoryFiles, 'texts/$hash.txt',
              p.join(appDir, 'texts', '$hash.txt'), useStreaming);
          if (i % 10 == 0) {
            await _yieldToEventLoop();
            checkCancelled();
          }
        }
      }
    }
    onProgress?.call(0.85);
    await _yieldToEventLoop();
    checkCancelled();

    // 附件
    if (selection.chatRecordsAndAttachments && selection.includeMediaFiles) {
      final attachmentPaths = await collectAttachmentPaths();
      for (final storagePath in attachmentPaths) {
        final parts = storagePath.split('/');
        if (parts.length < 2) continue;
        final subDir = parts[0];
        final fileName = parts.sublist(1).join('/');
        await _addPlanFile(diskFiles, memoryFiles, storagePath,
            p.join(appDir, subDir, fileName), useStreaming);
      }
    }
    onProgress?.call(0.93);
    await _yieldToEventLoop();
    checkCancelled();

    // 5. stroom_manifest.json
    debugPrint('[BackupService] streaming: writing manifest');
    jsonFiles['stroom_manifest.json'] = jsonEncode({
      'image_records': manifestImageRecords ?? <Map<String, dynamic>>[],
      'audio_records': manifestAudioRecords ?? <Map<String, dynamic>>[],
      'video_records': manifestVideoRecords ?? <Map<String, dynamic>>[],
      'text_records': manifestTextRecords ?? <Map<String, dynamic>>[],
      'folders': <String>[],
      ManifestTables.textFolders: manifestTextFolders ?? <String>[],
      ManifestTables.audioFolders: manifestAudioFolders ?? <String>[],
      ManifestTables.imageFolders: manifestImageFolders ?? <String>[],
      ManifestTables.videoFolders: manifestVideoFolders ?? <String>[],
    });

    return _BackupPlan(
      jsonFiles: jsonFiles,
      memoryFiles: memoryFiles,
      diskFiles: diskFiles,
    );
  }

  /// 将一个文件加入备份计划。
  ///
  /// [useStreaming] 为 true（原生生产环境）时记录磁盘路径，由后台
  /// isolate 流式读取；false（Web/测试模式）时立即读入内存。
  static Future<void> _addPlanFile(
    List<List<String>> diskFiles,
    Map<String, Uint8List> memoryFiles,
    String archiveName,
    String filePath,
    bool useStreaming,
  ) async {
    if (useStreaming) {
      diskFiles.add([archiveName, filePath]);
      return;
    }
    // Web/测试模式：从内存读取
    try {
      final parts = archiveName.split('/');
      if (parts.length < 2) return;
      final subDir = parts[0];
      final fileName = parts.sublist(1).join('/');
      final data = await readBackupFile(subDir, fileName);
      if (data != null) {
        memoryFiles[archiveName] = data;
      }
    } catch (e) {
      debugPrint('添加文件 $archiveName 失败: $e');
    }
  }

  /// 添加内存中的数据到 ZIP（store 模式，数据小无需压缩）。
  static void _addInMemoryFile(ZipEncoder encoder, String name, String json) {
    final data = Uint8List.fromList(utf8.encode(json));
    final af = ArchiveFile(name, data.length, data);
    af.compression = CompressionType.none;
    encoder.add(af);
  }

  // ================================================================
  // 核心：在内存中构建备份归档（Web/导出用）
  // ================================================================

  /// 判断 SharedPreferences 键是否为聊天相关键。
  ///
  /// 聊天键仅包括：对话数据和活跃对话ID。
  /// 所有非 `flutter.*` 前缀的其他键归类为"设置"。
  static bool _isChatPrefKey(String key) {
    return key == 'conversations' || key == 'active_conversation_id';
  }

  /// 判断一个 SharedPreferences 键是否属于 [selection] 中选中的类别。
  ///
  /// `flutter.*` 内部键永不参与备份/恢复/清除。
  static bool _isKeyInSelection(String key, BackupSelection selection) {
    if (key.startsWith('flutter.')) return false;
    if (_isChatPrefKey(key)) return selection.chatRecordsAndAttachments;
    return selection.settings;
  }

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
  ///
  /// 备份格式版本：
  /// - v1: preferences.json（聊天+设置合并）+ attachments/ 分开
  /// - v2: chat_data.json（聊天记录）+ settings.json（设置）+
  ///       attachments/ 作为聊天记录和附件的一部分
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
      'version': 2,
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

    // 3. SharedPreferences — 拆分聊天记录和设置
    // chatRecordsAndAttachments → chat_data.json（聊天相关键）
    // settings → settings.json（设置相关键）
    bool hasChatData = false;
    bool hasSettingsData = false;
    final chatData = <String, dynamic>{};
    final settingsData = <String, dynamic>{};

    if (selection.chatRecordsAndAttachments || selection.settings) {
      debugPrint('[BackupService] _buildBackupBytes: reading preferences');
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        if (_isChatPrefKey(key)) {
          if (selection.chatRecordsAndAttachments) {
            chatData[key] = prefs.get(key);
            hasChatData = true;
          }
        } else {
          if (selection.settings) {
            settingsData[key] = prefs.get(key);
            hasSettingsData = true;
          }
        }
      }
    }

    if (hasChatData) {
      addStringToArchive(archive, 'chat_data.json', jsonEncode(chatData));
    }
    if (hasSettingsData) {
      addStringToArchive(archive, 'settings.json', jsonEncode(settingsData));
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
        await addTaskFileToArchive(archive, 'background/tasks.json',
            p.join(appDir, 'background', 'tasks.json'));
        await addTaskFileToArchive(archive, 'task_flows/flows.json',
            p.join(appDir, 'task_flows', 'flows.json'));
        await addTaskFileToArchive(archive, 'task_flows/executions.json',
            p.join(appDir, 'task_flows', 'executions.json'));
      } else {
        addStringToArchive(archive, 'synthesis/tasks.json', '[]');
        addStringToArchive(archive, 'catcatch/tasks.json', '[]');
        addStringToArchive(archive, 'background/tasks.json', '[]');
        addStringToArchive(archive, 'task_flows/flows.json', '[]');
        addStringToArchive(archive, 'task_flows/executions.json', '[]');
      }
    }
    onProgress?.call(0.35);
    await _yieldToEventLoop();
    checkCancelled();

    // 4b. Anki 闪卡数据库（原始格式）
    if (selection.ankiData && !kIsWeb && !WebFileStore.isTestMode) {
      try {
        final appDir = await AppStorage.directory;
        final ankiDb = p.join(appDir, 'collection.anki2');
        if (File(ankiDb).existsSync()) {
          await addTaskFileToArchive(archive, 'anki/collection.anki2', ankiDb);
        }
      } catch (_) {}
    }

    // 4c. 浏览器Cookies持久化数据
    if (selection.browserCookies && !kIsWeb && !WebFileStore.isTestMode) {
      try {
        final appDir = await AppStorage.directory;
        final cookiesFile = p.join(appDir, 'browser_cookies.json');
        if (File(cookiesFile).existsSync()) {
          await addTaskFileToArchive(
              archive, 'browser_cookies.json', cookiesFile);
        }
      } catch (_) {}
    }

    // 5. 二进制文件（按存储格式：pictures/, tts_audio/, videos/, texts/, attachments/）
    debugPrint('[BackupService] _buildBackupBytes: adding binary files');

    if (selection.pictures && selection.includeMediaFiles) {
      for (var i = 0; i < imageRecords.length; i++) {
        final record = imageRecords[i];
        final hash = record['hash'] as String?;
        final format = record['format'] as String? ?? 'jpg';
        if (hash == null) continue;
        await addFileToArchive(
            archive, 'pictures/$hash.$format', 'pictures', '$hash.$format');
        await addFileToArchive(archive, 'pictures/${imageThumbFileName(hash)}',
            'pictures', imageThumbFileName(hash));
        if (i % 10 == 0) {
          await _yieldToEventLoop();
          checkCancelled();
        }
      }
    }
    onProgress?.call(0.5);
    await _yieldToEventLoop();
    checkCancelled();

    if (selection.audio && selection.includeMediaFiles) {
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

    if (selection.videos && selection.includeMediaFiles) {
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

    if (selection.texts && selection.includeMediaFiles) {
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

    if (selection.chatRecordsAndAttachments && selection.includeMediaFiles) {
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
  ///
  /// 兼容 v1 和 v2 备份格式：
  /// - v1: preferences.json（聊天+设置合并），attachments/ 分开
  /// - v2: chat_data.json（聊天记录）+ settings.json（设置），
  ///       attachments/ 作为聊天记录和附件的一部分
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
      throw BackupValidationException('无效的备份文件：无法解压 ($e)');
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

    // 验证 manifest（兼容 v1 和 v2）
    final manifestJson = fileMap['manifest.json'];
    if (manifestJson == null) {
      throw BackupValidationException('无效的备份文件：缺少 manifest.json');
    }
    final Map<String, dynamic> manifest;
    try {
      final decoded = jsonDecode(utf8.decode(manifestJson));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('结构不是对象');
      }
      manifest = decoded;
    } catch (e) {
      throw BackupValidationException('无效的备份文件：manifest.json 损坏 ($e)');
    }
    final int? version;
    try {
      version = manifest['version'] as int?;
    } catch (e) {
      throw BackupValidationException('无效的备份文件：version 字段损坏 ($e)');
    }
    if (version == null || (version != 1 && version != 2)) {
      throw BackupValidationException('不支持的备份版本: $version (仅支持 v1 和 v2)');
    }
    final isV1Format = version == 1;
    onProgress?.call(0.15);
    await _yieldToEventLoop();

    // ================================================================
    // 预解析并校验备份中的全部 JSON 数据（在删除任何现有文件之前）。
    // 无效备份直接中止恢复，避免"选中类别的文件已被删除但恢复失败"
    // 造成的数据丢失。
    // ================================================================
    Map<String, dynamic>? dbData;
    final dbJson = fileMap['stroom_manifest.json'] ??
        fileMap['database/manifest_data.json'];
    if (dbJson != null) {
      try {
        final decoded = jsonDecode(utf8.decode(dbJson));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('结构不是对象');
        }
        // 校验嵌套结构（与 _restoreDatabaseFromJson 的取值逻辑一致），
        // 防止恢复中途因字段形状错误抛错
        void validateRecordList(Object? value, String field) {
          if (value == null) return;
          if (value is! List) throw FormatException('$field 不是数组');
          for (final item in value) {
            if (item is! Map<String, dynamic>) {
              throw FormatException('$field 包含非对象记录');
            }
          }
        }

        void validateFolderList(Object? value, String field) {
          if (value == null) return;
          if (value is! List) throw FormatException('$field 不是数组');
          for (final item in value) {
            if (item is! String) {
              throw FormatException('$field 包含非字符串项');
            }
          }
        }

        validateRecordList(decoded['image_records'], 'image_records');
        validateRecordList(decoded['audio_records'], 'audio_records');
        validateRecordList(decoded['video_records'], 'video_records');
        validateRecordList(decoded['text_records'], 'text_records');
        validateFolderList(decoded['folders'], 'folders');
        validateFolderList(
            decoded[ManifestTables.textFolders], ManifestTables.textFolders);
        validateFolderList(
            decoded[ManifestTables.audioFolders], ManifestTables.audioFolders);
        validateFolderList(
            decoded[ManifestTables.imageFolders], ManifestTables.imageFolders);
        validateFolderList(
            decoded[ManifestTables.videoFolders], ManifestTables.videoFolders);
        dbData = decoded;
      } catch (e) {
        throw BackupValidationException('无效的备份文件：数据库记录损坏 ($e)');
      }
    }
    Map<String, dynamic>? v1Prefs;
    Map<String, dynamic>? chatPrefs;
    Map<String, dynamic>? settingsPrefs;
    Map<String, dynamic>? validatePrefsFile(String name) {
      final raw = fileMap[name];
      if (raw == null) return null;
      try {
        final decoded = jsonDecode(utf8.decode(raw));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('结构不是对象');
        }
        return decoded;
      } catch (e) {
        throw BackupValidationException('无效的备份文件：$name 损坏 ($e)');
      }
    }

    // 只校验选中类别的偏好设置文件（未选中的类别不参与恢复，
    // 其文件损坏不应阻止其他类别的恢复）
    if (isV1Format) {
      if (selection.chatRecordsAndAttachments || selection.settings) {
        v1Prefs = validatePrefsFile('preferences.json');
      }
    } else {
      if (selection.chatRecordsAndAttachments) {
        chatPrefs = validatePrefsFile('chat_data.json');
      }
      if (selection.settings) {
        settingsPrefs = validatePrefsFile('settings.json');
      }
    }

    // 勾选即清空：先清除选中类别的现有文件。
    // 即使备份中缺少对应文件，选中的类别也会被清空（与数据库/偏好设置
    // 类别的语义一致）。必须在数据库记录替换之前执行，因为媒体文件按
    // 当前数据库记录逐个删除。
    // 删除失败（如 Windows 上文件被占用）时中止恢复并提示重启重试，
    // 与清除功能的行为一致。
    if (await _deleteSelectedFiles(selection)) {
      throw Exception('部分数据文件删除失败，请重启应用后重试');
    }

    // 恢复数据库记录（使用已解析校验的数据）
    debugPrint('[BackupService] _restoreFromBytes: restoring database');
    if (dbData != null) {
      await _restoreDatabaseFromJson(dbData, selection: selection);
    } else if (selection.pictures ||
        selection.audio ||
        selection.videos ||
        selection.texts) {
      // 备份中没有数据库清单：勾选即清空 —— 清空选中媒体类别的
      // 记录与文件夹（其文件已在 _deleteSelectedFiles 中删除），
      // 避免记录悬空指向已删除的文件。
      if (selection.pictures) {
        await ManifestDatabase.clearRecords(ManifestTables.imageRecords);
        await ManifestDatabase.clearFolders(
            recordTable: ManifestTables.imageRecords);
      }
      if (selection.audio) {
        await ManifestDatabase.clearRecords(ManifestTables.audioRecords);
        await ManifestDatabase.clearFolders(
            recordTable: ManifestTables.audioRecords);
      }
      if (selection.videos) {
        await ManifestDatabase.clearRecords(ManifestTables.videoRecords);
        await ManifestDatabase.clearFolders(
            recordTable: ManifestTables.videoRecords);
      }
      if (selection.texts) {
        await ManifestDatabase.clearRecords(ManifestTables.textRecords);
        await ManifestDatabase.clearFolders(
            recordTable: ManifestTables.textRecords);
      }
    }
    onProgress?.call(0.4);
    await _yieldToEventLoop();

    // 恢复 SharedPreferences（兼容 v1/v2 格式）
    // 注意：必须将要恢复的所有数据合并后一次性调用 _restorePreferencesFromJson，
    // 因为该方法会清除选中类别的现有键。分两次调用会导致先恢复的数据被后一次清除。
    if (isV1Format) {
      // v1 格式：preferences.json 包含所有键（聊天+设置合并）
      // 按 key 分类拆分：只恢复选中类别对应的键，未选中的类别保持原样
      if (selection.chatRecordsAndAttachments || selection.settings) {
        debugPrint(
            '[BackupService] _restoreFromBytes: restoring v1 preferences');
        final restorePrefs = <String, dynamic>{};
        if (v1Prefs != null) {
          for (final entry in v1Prefs.entries) {
            final isChat = _isChatPrefKey(entry.key);
            if ((isChat && selection.chatRecordsAndAttachments) ||
                (!isChat && selection.settings)) {
              restorePrefs[entry.key] = entry.value;
            }
          }
        }
        await _restorePreferencesFromJson(restorePrefs, selection: selection);
      }
    } else {
      // v2 格式：chat_data.json + settings.json 分开，合并后一次性恢复
      final mergedPrefs = <String, dynamic>{};
      if (selection.chatRecordsAndAttachments) {
        debugPrint('[BackupService] _restoreFromBytes: merging chat_data.json');
        if (chatPrefs != null) {
          mergedPrefs.addAll(chatPrefs);
        }
      }
      if (selection.settings) {
        debugPrint('[BackupService] _restoreFromBytes: merging settings.json');
        if (settingsPrefs != null) {
          mergedPrefs.addAll(settingsPrefs);
        }
      }
      if (selection.chatRecordsAndAttachments || selection.settings) {
        await _restorePreferencesFromJson(mergedPrefs, selection: selection);
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
      'catcatch',
      'background',
      'task_flows',
      'anki',
    ];
    final skipFiles = {
      'manifest.json',
      'stroom_manifest.json',
      'database/manifest_data.json',
      'preferences.json',
      'chat_data.json',
      'settings.json',
      'browser_cookies.json',
    };

    // 恢复浏览器Cookies持久化数据（选中则恢复，未选中则保持原样）
    if (selection.browserCookies) {
      final bcData = fileMap['browser_cookies.json'];
      if (bcData != null) {
        await writeBackupFile('', 'browser_cookies.json', bcData);
      }
    }

    // 根据 selection 决定哪些目录需要恢复
    // v1 格式：attachments 由旧的 conversations 标志控制（因为 v1 的
    // conversations 包含了设置+聊天记录，不包含附件），但为了兼容，
    // v1 导入时 attachments 由 chatRecordsAndAttachments 控制
    bool shouldRestoreDir(String dir) {
      switch (dir) {
        case 'pictures':
          return selection.pictures && selection.includeMediaFiles;
        case 'tts_audio':
          return selection.audio && selection.includeMediaFiles;
        case 'videos':
          return selection.videos && selection.includeMediaFiles;
        case 'texts':
          return selection.texts && selection.includeMediaFiles;
        case 'synthesis':
        case 'catcatch':
        case 'background':
        case 'task_flows':
          return selection.tasks;
        case 'attachments':
          return selection.chatRecordsAndAttachments &&
              selection.includeMediaFiles;
        case 'anki':
          return selection.ankiData;
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

      if (matchedDir == 'anki') {
        // 实际数据库位于应用数据目录根目录 collection.anki2
        //（备份归档内的路径为 anki/collection.anki2）。
        // 先关闭可能打开的数据库连接（Windows 上文件被占用时无法写入）。
        await AnkiDatabase.closeOpenedInstance();
        await writeBackupFile('', relativePath, entry.value);
        restoreIndex++;
        continue;
      }

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

    // 未选中的类别保持原样：不清理、不覆盖其现有文件/记录，
    // 只有选中的类别会被备份中的数据替换。
    // 选中类别的现有文件已在恢复开始时清除（见 _deleteSelectedFiles），
    // 这里只需写入备份中包含的文件。

    // 数据迁移：确保恢复后的数据格式是最新的
    // 旧格式备份（pre-migration）中包含 chat_configs、null IDs 等，
    // 需要迁移到当前数据格式才能正常使用。
    await DataMigrationService.migrateDataFormatIfNeeded();
    onProgress?.call(1.0);
  }

  // ================================================================
  // 文件清理辅助
  // ================================================================

  /// 删除指定目录中的一个文件。
  ///
  /// 返回是否删除成功：文件不存在视为成功；删除异常返回 `false` 并记录日志。
  static Future<bool> _deleteFile(String subDir, String fileName) async {
    try {
      if (kIsWeb || WebFileStore.isTestMode) {
        await WebFileStore.delete('$subDir/$fileName');
      } else {
        final appDir = await AppStorage.directory;
        final file = File(p.join(appDir, subDir, fileName));
        if (await file.exists()) {
          await file.delete();
        }
      }
      return true;
    } catch (e) {
      debugPrint('删除文件 $subDir/$fileName 失败: $e');
      return false;
    }
  }

  /// 删除应用数据目录下的整个子目录（仅原生模式）。
  ///
  /// Web / 测试模式下没有目录结构概念，无法递归删除，
  /// 依靠 DB 记录清除 + 逐文件删除来控制数据。
  /// 返回是否删除成功（目录不存在视为成功）。
  static Future<bool> _deleteDirectory(String subDir) async {
    try {
      if (kIsWeb || WebFileStore.isTestMode) {
        return true;
      }
      final appDir = await AppStorage.directory;
      final targetDir = Directory(p.join(appDir, subDir));
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
        debugPrint('[BackupService] 已删除目录: $subDir');
      }
      return true;
    } catch (e) {
      debugPrint('[BackupService] 删除目录 $subDir 失败: $e');
      return false;
    }
  }

  // ================================================================
  // 恢复辅助
  // ================================================================

  static Future<void> _restoreDatabaseFromJson(
    Map<String, dynamic> data, {
    BackupSelection selection = BackupSelection.all,
  }) async {
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

    // 选择性恢复：勾选的类别清空后从备份恢复，未勾选的类别保持原样。
    // 选中的类别：先清除现有记录，再写入备份中的记录（即使备份中为空）。
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

    // Restore folders only for selected record types;
    // unselected types keep their existing folders.
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

  /// 从 Map 恢复 SharedPreferences 中选中的类别。
  ///
  /// 只清除并替换 [selection] 中选中的类别键，未选中的类别保持原样：
  /// - chatRecordsAndAttachments → 清除现有聊天键，写入备份中的聊天键
  /// - settings → 清除现有设置键，写入备份中的设置键
  ///
  /// 写入时同样按类别过滤，防止备份文件中混入其他类别的键
  /// （如异常的 chat_data.json 中包含设置键）覆盖未选中的类别。
  static Future<void> _restorePreferencesFromJson(
    Map<String, dynamic> backupPrefs, {
    required BackupSelection selection,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final keysToRemove =
        prefs.getKeys().where((k) => _isKeyInSelection(k, selection)).toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    for (final entry in backupPrefs.entries) {
      if (!_isKeyInSelection(entry.key, selection)) continue;
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
        '_restorePreferencesFromJson: restored ${backupPrefs.length} keys, removed ${keysToRemove.length}');
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
      final bytes =
          await _buildBackupBytes(onProgress: onProgress, selection: selection);

      final outputPath = await FilePicker.saveFile(
        fileName: defaultName,
        bytes: bytes,
        initialDirectory: SystemPickDirectories.documents(),
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
  /// 返回 `true` 表示恢复成功，`false` 表示用户取消选择文件；
  /// 恢复过程中出错时抛出异常（并已弹出错误提示）。
  static Future<bool> importBackup(
    BuildContext context, {
    BackupSelection selection = BackupSelection.all,
  }) async {
    await AppLogService.info('BackupService', 'importBackup: start');
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        initialDirectory: SystemPickDirectories.documents(),
      );
      if (result == null || result.files.isEmpty) return false;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes != null) {
        await _restoreFromBytes(bytes, selection: selection);
      } else if (file.path != null) {
        await restoreBackup(file.path!, selection: selection);
      }

      // 恢复成功 — 让调用方处理重启提示
      await AppLogService.info('BackupService', 'importBackup: success');
      return true;
    } catch (e) {
      await AppLogService.error('BackupService', 'importBackup: 失败', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
        );
      }
      // 重新抛出：让调用方区分"恢复失败"与"用户取消"
      // （失败时恢复可能已部分完成，需要提示用户重启应用）
      rethrow;
    }
  }

  /// 清除选中的数据类别（不涉及任何备份文件）。
  ///
  /// 只清除 [selection] 中选中的类别，未选中的类别保持原样：
  /// - 聊天记录和附件：删除聊天相关 Preferences 键 + 附件文件（含孤儿）
  /// - 设置：删除所有设置相关 Preferences 键
  /// - 图片/音频/视频/文本：删除对应数据库记录、文件夹表、逐文件删除
  ///   （Web/测试模式同样生效），并在原生模式删除整个目录
  /// - 任务：删除 synthesis/tasks.json 和 catcatch/tasks.json
  /// - Anki数据：先关闭可能打开的数据库连接，再删除 collection.anki2
  /// - 浏览器Cookies：删除 browser_cookies.json
  ///
  /// 与选择性恢复的语义一致：选中的类别被清空，未选中的保持原样。
  /// 若有文件删除失败（如 Windows 上文件被占用），抛出异常，由调用方提示。
  static Future<void> clearSelectedData(
    BackupSelection selection, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);
    await _yieldToEventLoop();

    // 1. SharedPreferences — 只删除选中类别的键
    if (selection.chatRecordsAndAttachments || selection.settings) {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs
          .getKeys()
          .where((k) => _isKeyInSelection(k, selection))
          .toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      await AppLogService.info('BackupService',
          'clearSelectedData: removed ${keysToRemove.length} preference keys');
    }

    // 2. 选中类别的文件（附件目录整清，孤儿文件一并删除）
    final deleteFailed = await _deleteSelectedFiles(selection);

    // 3. 媒体数据库记录 + 文件夹表（文件已由 _deleteSelectedFiles 删除）
    if (selection.pictures) {
      await ManifestDatabase.clearRecords(ManifestTables.imageRecords);
      await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.imageRecords);
    }
    if (selection.audio) {
      await ManifestDatabase.clearRecords(ManifestTables.audioRecords);
      await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.audioRecords);
    }
    if (selection.videos) {
      await ManifestDatabase.clearRecords(ManifestTables.videoRecords);
      await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.videoRecords);
    }
    if (selection.texts) {
      await ManifestDatabase.clearRecords(ManifestTables.textRecords);
      await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.textRecords);
    }
    onProgress?.call(0.6);
    await _yieldToEventLoop();

    if (deleteFailed) {
      throw Exception('部分数据文件删除失败，请重启应用后重试');
    }

    onProgress?.call(1.0);
  }

  /// 删除 [selection] 中选中类别的现有文件。
  ///
  /// 恢复"勾选即清空"与清除功能共用此方法。
  /// 返回是否有删除失败（调用方决定如何处理）：
  /// - 聊天附件：整个 attachments/ 目录/前缀删除 —— 附件全部存储在该目录，
  ///   引用文件与无引用的孤儿文件一并清除
  /// - 图片/音频/视频/文本：按当前数据库记录逐文件删除（Web/测试模式），
  ///   原生模式再整目录删除（清理无记录的孤儿文件）
  /// - 任务：删除 synthesis/tasks.json 和 catcatch/tasks.json
  /// - Anki：先关闭可能打开的数据库连接，再删除 collection.anki2
  ///   （应用数据目录根路径 + 历史恢复写入的 anki/ 残留）
  /// - 浏览器Cookies：删除 browser_cookies.json
  static Future<bool> _deleteSelectedFiles(BackupSelection selection) async {
    var deleteFailed = false;

    // 聊天附件：附件全部存储在 attachments/ 目录，整目录/前缀删除
    // 即可同时清掉引用文件与无引用的孤儿文件。
    // （includeMediaFiles=false 的结构化快照恢复不动附件文件）
    if (selection.chatRecordsAndAttachments && selection.includeMediaFiles) {
      if (kIsWeb || WebFileStore.isTestMode) {
        try {
          await WebFileStore.deleteByPrefix('attachments/');
        } catch (e) {
          debugPrint('删除附件文件失败: $e');
          deleteFailed = true;
        }
      } else if (!await _deleteDirectory('attachments')) {
        deleteFailed = true;
      }
    }

    // 媒体：先按数据库记录逐文件删除（Web/测试模式同样生效），
    // 原生模式再删除整个目录以清理无记录的孤儿文件。
    // （includeMediaFiles=false 的结构化快照恢复不动媒体文件）
    if (selection.pictures && selection.includeMediaFiles) {
      final records = await ManifestDatabase.getAllImageRecords();
      for (final record in records) {
        final hash = record['hash'] as String?;
        final format = record['format'] as String? ?? 'jpg';
        if (hash == null) continue;
        if (!await _deleteFile('pictures', '$hash.$format')) {
          deleteFailed = true;
        }
        if (!await _deleteFile('pictures', imageThumbFileName(hash))) {
          deleteFailed = true;
        }
        // 旧版（变形）命名残留：Web/测试模式下没有整目录删除兜底，
        // 逐记录一并清理（原生模式由下方的 _deleteDirectory 兜底）
        if (kIsWeb || WebFileStore.isTestMode) {
          await _deleteFile('pictures', '${hash}_thumb.png');
        }
      }
      if (!await _deleteDirectory('pictures')) deleteFailed = true;
    }
    if (selection.audio && selection.includeMediaFiles) {
      final records = await ManifestDatabase.getAllAudioRecords();
      for (final record in records) {
        final hash = record['hash'] as String?;
        final format = record['format'] as String? ?? 'wav';
        if (hash == null) continue;
        if (!await _deleteFile('tts_audio', '$hash.$format')) {
          deleteFailed = true;
        }
        if (!await _deleteFile('tts_audio', '$hash.txt')) {
          deleteFailed = true;
        }
      }
      if (!await _deleteDirectory('tts_audio')) deleteFailed = true;
    }
    if (selection.videos && selection.includeMediaFiles) {
      final records = await ManifestDatabase.getAllVideoRecords();
      for (final record in records) {
        final hash = record['hash'] as String?;
        final format = record['format'] as String? ?? 'mp4';
        if (hash == null) continue;
        if (!await _deleteFile('videos', '$hash.$format')) {
          deleteFailed = true;
        }
      }
      if (!await _deleteDirectory('videos')) deleteFailed = true;
    }
    if (selection.texts && selection.includeMediaFiles) {
      final records = await ManifestDatabase.getAllTextRecords();
      for (final record in records) {
        final hash = record['hash'] as String?;
        if (hash == null) continue;
        if (!await _deleteFile('texts', '$hash.txt')) {
          deleteFailed = true;
        }
      }
      if (!await _deleteDirectory('texts')) deleteFailed = true;
    }

    // 任务文件
    if (selection.tasks) {
      if (!await _deleteFile('synthesis', 'tasks.json')) deleteFailed = true;
      if (!await _deleteFile('catcatch', 'tasks.json')) deleteFailed = true;
      if (!await _deleteFile('background', 'tasks.json')) deleteFailed = true;
      if (!await _deleteFile('task_flows', 'flows.json')) deleteFailed = true;
      if (!await _deleteFile('task_flows', 'executions.json')) {
        deleteFailed = true;
      }
    }

    // Anki 闪卡数据库
    // 先关闭可能打开的数据库连接（Windows 上文件被占用时无法删除），
    // 实际数据库位于应用数据目录根目录 collection.anki2；
    // 同时清理历史恢复写入的 anki/collection.anki2 残留文件。
    if (selection.ankiData) {
      await AnkiDatabase.closeOpenedInstance();
      if (!await _deleteFile('', 'collection.anki2')) deleteFailed = true;
      if (!await _deleteFile('anki', 'collection.anki2')) deleteFailed = true;
    }

    // 浏览器Cookies持久化数据
    if (selection.browserCookies) {
      if (!await _deleteFile('', 'browser_cookies.json')) deleteFailed = true;
    }

    return deleteFailed;
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

  /// 公开流式备份的同步构建核心供测试使用（大文件路径）。
  ///
  /// 生产环境该函数在后台 isolate 中执行；测试中直接同步调用，
  /// 验证大文件 ZIP 构建的正确性与内存安全（store 模式流式写入）。
  @visibleForTesting
  static void createBackupStreamingSyncForTest({
    required Map<String, String> jsonFiles,
    required Map<String, Uint8List> memoryFiles,
    required List<List<String>> diskFiles,
    required String outputPath,
  }) {
    _createBackupStreamingSync(jsonFiles, memoryFiles, diskFiles, outputPath);
  }

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
      _restoreDatabaseFromJson(jsonDecode(json) as Map<String, dynamic>,
          selection: selection);
}

// ====================================================================
// 备份计划 — 主 isolate 收集，后台 isolate 执行
// ====================================================================

/// 备份计划：主 isolate 收集的数据与文件清单。
///
/// 所有字段都必须是可发送类型（Isolate.run 的闭包捕获项），
/// 因此磁盘文件用 [List<List<String>>]（[归档路径, 源文件路径]）而非
/// 自定义类。
class _BackupPlan {
  /// 归档内的小型 JSON 文件（manifest / 偏好设置 / 数据库清单等）。
  final Map<String, String> jsonFiles;

  /// 内存字节文件（Web/测试模式下的媒体文件）。
  final Map<String, Uint8List> memoryFiles;

  /// 磁盘文件（[归档路径, 源文件路径]），写入时流式读取。
  final List<List<String>> diskFiles;

  const _BackupPlan({
    required this.jsonFiles,
    required this.memoryFiles,
    required this.diskFiles,
  });
}

/// 同步构建 ZIP（store 模式，磁盘到磁盘流式写入）。
///
/// 顶层函数（非方法），供 [Isolate.run] 在后台 isolate 执行 ——
/// 大文件（数百 MB）的 CRC32 计算与分块读写都在后台完成，
/// 主 isolate 只 await，UI 帧渲染完全不受影响。
///
/// [isCancelled] 仅在测试/回退路径（调用方 isolate 同步执行）时传入；
/// 后台 isolate 模式下为 null（跨 isolate 无法共享闭包状态，取消检查
/// 由调用方在 isolate 启动前后完成）。
///
/// 使用 [ZipEncoder] + 自定义文件流，store 模式（不压缩）逐个文件写入
/// 磁盘。deflate 压缩模式下 [ZipEncoder] 会通过 [OutputMemoryStream]
/// 将每个文件的压缩结果完整缓存在内存中（一个大视频文件就足以 OOM），
/// 因此使用 store 模式（[CompressionType.none]）配合
/// [_FileInputStream]/[_FileOutputStream]，确保文件数据直接从磁盘流经
/// ZIP 写入目标文件，不经过任何内存缓冲。
///
/// 峰值内存：O(最大单文件的分块读取缓冲 64KB + CRC32 计算缓冲 1MB)，
/// 不随备份文件数量或单文件大小增长。
void _createBackupStreamingSync(
  Map<String, String> jsonFiles,
  Map<String, Uint8List> memoryFiles,
  List<List<String>> diskFiles,
  String outputPath, {
  bool Function()? isCancelled,
}) {
  void checkCancelled() {
    if (isCancelled != null && isCancelled()) {
      throw const BackupCancelledException();
    }
  }

  // 使用 ZipEncoder + 自定义文件输出流（store 模式，无压缩内存缓冲）
  final output = _FileOutputStream(outputPath);
  final encoder = ZipEncoder();
  encoder.startEncode(output);

  try {
    // 1. 内存 JSON 文件（manifest / 偏好设置 / 数据库清单）
    for (final entry in jsonFiles.entries) {
      BackupService._addInMemoryFile(encoder, entry.key, entry.value);
      checkCancelled();
    }

    // 2. 内存字节文件（Web/测试模式的媒体文件）
    for (final entry in memoryFiles.entries) {
      final data = entry.value;
      final af = ArchiveFile(entry.key, data.length, data);
      af.compression = CompressionType.none;
      encoder.add(af);
      checkCancelled();
    }

    // 3. 磁盘文件 — 直接从磁盘流式读取，不加载到内存
    for (final entry in diskFiles) {
      final archiveName = entry[0];
      final sourcePath = entry[1];
      try {
        final file = File(sourcePath);
        if (file.existsSync()) {
          final input = _FileInputStream(sourcePath);
          final af = ArchiveFile.stream(archiveName, input);
          af.compression = CompressionType.none;
          encoder.add(af);
        }
      } catch (e) {
        debugPrint('添加文件 $archiveName 失败: $e');
      }
      checkCancelled();
    }

    // 4. 完成编码
    encoder.endEncode();
  } catch (_) {
    output.closeSync();
    rethrow;
  }
  output.closeSync();
}

/// 从磁盘流式读取的 [InputStream] 实现（不将整个文件加载到内存）。
///
/// 每次以 [kChunkSize] 大小分块读取，配合 store 模式 ZIP 编码，
/// 确保单文件处理的内存峰值仅为块大小，不随文件大小增长。
class _FileInputStream extends InputStream {
  static const int kChunkSize = 65536;

  final RandomAccessFile _file;
  final int _fileLength;
  int _pos = 0;

  _FileInputStream(String path)
      : _file = File(path).openSync(),
        _fileLength = File(path).lengthSync(),
        super(byteOrder: ByteOrder.littleEndian);

  @override
  int get position => _pos;

  @override
  set position(int v) {
    _pos = v;
    _file.setPositionSync(v);
  }

  @override
  int get length => _fileLength;

  @override
  bool get isEOS => _pos >= _fileLength;

  @override
  bool open() => true;

  @override
  Future<void> close() async => _file.closeSync();

  @override
  void closeSync() => _file.closeSync();

  @override
  void reset() => position = 0;

  @override
  void setPosition(int v) => position = v;

  @override
  void rewind([int length = 1]) => position = _pos - length;

  @override
  void skip(int length) => position = _pos + length;

  @override
  InputStream subset({int? position, int? length, int? bufferSize}) {
    final pos = position ?? _pos;
    final len = length ?? (_fileLength - pos);
    final saved = _pos;
    _file.setPositionSync(pos);
    final data = _file.readSync(len);
    _file.setPositionSync(saved);
    return InputMemoryStream(data);
  }

  @override
  int readByte() {
    _pos++;
    return _file.readByteSync();
  }

  @override
  Uint8List toUint8List() {
    final remaining = _fileLength - _pos;
    final data = _file.readSync(remaining);
    _pos = _fileLength;
    return data;
  }
}

/// 流式写入 ZIP 文件的 [OutputStream] 实现（不将整个 ZIP 保留在内存）。
class _FileOutputStream extends OutputStream {
  final RandomAccessFile _file;
  int _length = 0;

  _FileOutputStream(String path)
      : _file = File(path).openSync(mode: FileMode.write),
        super(byteOrder: ByteOrder.littleEndian);

  @override
  int get length => _length;

  @override
  void clear() => _length = 0;

  @override
  void flush() {}

  @override
  void writeByte(int value) {
    _file.writeByteSync(value);
    _length++;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final len = length ?? bytes.length;
    _file.writeFromSync(bytes, 0, len);
    _length += len;
  }

  @override
  void writeStream(InputStream stream) {
    const int chunkSize = _FileInputStream.kChunkSize;
    while (!stream.isEOS) {
      final count = chunkSize < stream.length ? chunkSize : stream.length;
      final chunk = stream.readBytes(count).toUint8List();
      _file.writeFromSync(chunk);
      _length += chunk.length;
    }
  }

  @override
  Uint8List subset(int start, [int? end]) => Uint8List(0); // 流式写入不支持随机读取

  @override
  Future<void> close() async => _file.closeSync();

  @override
  void closeSync() => _file.closeSync();
}
