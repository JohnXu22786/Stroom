import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:archive/archive.dart' hide ZLibDecoder;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_location_manager.dart';
import 'backup_service_shared.dart';
import 'browser_cookie_service.dart';
import 'data_migration_service.dart';
import 'manifest_database.dart';
import 'storage_service.dart';
import '../anki/database/anki_database.dart';
import '../utils/app_version.dart';
import '../utils/image_thumbnail_loader.dart';
import '../utils/system_pick_utils.dart';
import '../utils/web_file_store.dart';
import 'app_log_service.dart';
import '../catcatch/models/catcatch_task.dart' show CatCatchTask;
import '../providers/background_task_provider.dart' show BackgroundTask;
import '../providers/task_provider_shared.dart' show SynthesisTask;
import '../task_flow/models/task_flow_definition.dart' show TaskFlowDefinition;
import '../task_flow/models/task_flow_execution.dart' show TaskFlowExecution;

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

/// Exception thrown when a data operation cannot safely begin before any
/// existing data is touched.
class DataManagementPreflightException implements Exception {
  final String message;
  const DataManagementPreflightException(this.message);

  @override
  String toString() => message;
}

/// 恢复中途（已删除选中类别的现有数据之后）发现归档条目损坏时抛出。
///
/// 与 [BackupValidationException] 区分：校验期失败意味着"什么都没动"，
/// 而此异常意味着恢复可能已部分完成，调用方必须提示用户重启应用。
/// 由流式恢复的条目解压层抛出，校验期调用方将其包装为
/// [BackupValidationException]。
class _RestoreEntryCorruptException implements Exception {
  final String message;
  const _RestoreEntryCorruptException(this.message);

  @override
  String toString() => message;
}

// ====================================================================
// BackupSelection — 选择性备份/恢复的数据类别
// ====================================================================
//
// 用于手动操作时选择要备份或恢复的数据类别。
// 私有启动快照使用 structuredOnly 选择。
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

  /// 结构化数据快照选择：保留结构化数据，排除媒体/附件文件和浏览器Cookies。
  static const structuredOnly = BackupSelection(
    includeMediaFiles: false,
    browserCookies: false,
  );

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

  Set<String> get selectedPartIds => {
        if (chatRecordsAndAttachments) DataParts.chat,
        if (settings) DataParts.settings,
        if (pictures) DataParts.pictures,
        if (audio) DataParts.audio,
        if (videos) DataParts.videos,
        if (texts) DataParts.texts,
        if (tasks) DataParts.tasks,
        if (ankiData) DataParts.anki,
        if (browserCookies) DataParts.browserCookies,
      };
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
  static int? _lastBackupFileTimestampSeconds;

  BackupService._();

  static Future<String> createBackup({
    required String outputPath,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
    BackupSelection selection = BackupSelection.all,
  }) async {
    await AppLogService.info(
      'BackupService',
      'createBackup: outputPath=$outputPath',
    );
    if (kIsWeb) {
      throw UnsupportedError(
        'createBackup is not available on web. Use exportBackup instead.',
      );
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
    bool skipPostRestoreMigration = false,
    bool skipMissingCategories = false,
    bool trustEmptyLegacyTaskPayloads = false,
  }) async {
    await AppLogService.info(
      'BackupService',
      'restoreBackup: zipPath=$zipPath',
    );
    if (kIsWeb) {
      throw UnsupportedError(
        'restoreBackup is not available on web. Use importBackup instead.',
      );
    }
    // 流式恢复：只解析中央目录 + 按条目分块解压落盘，
    // 峰值内存 O(块大小)，不再把整个备份包 readAsBytes 进内存。
    await _restoreFromZipFile(
      zipPath,
      onProgress: onProgress,
      selection: selection,
      skipPostRestoreMigration: skipPostRestoreMigration,
      skipMissingCategories: skipMissingCategories,
      trustEmptyLegacyTaskPayloads: trustEmptyLegacyTaskPayloads,
    );
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
        plan.jsonFiles,
        plan.memoryFiles,
        plan.diskFiles,
        outputPath,
        isCancelled: isCancelled,
      );
    } else {
      try {
        await Isolate.run(
          () => _createBackupStreamingSync(
            plan.jsonFiles,
            plan.memoryFiles,
            plan.diskFiles,
            outputPath,
          ),
        );
      } on UnsupportedError catch (e) {
        // Isolate 不可用（受限环境）：回退主 isolate 同步执行
        debugPrint('[BackupService] Isolate 不可用，回退同步执行: $e');
        _createBackupStreamingSync(
          plan.jsonFiles,
          plan.memoryFiles,
          plan.diskFiles,
          outputPath,
          isCancelled: isCancelled,
        );
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

    final browserCookieSnapshot = selection.browserCookies && useStreaming
        ? await BrowserCookieService.snapshotCookiesForBackup()
        : null;
    final ankiDbPath = await _findAnkiDatabasePath(selection);
    if (browserCookieSnapshot != null) {
      jsonFiles['browser_cookies.json'] = jsonEncode(browserCookieSnapshot);
    }

    // 1. manifest.json
    debugPrint('[BackupService] streaming: building manifest');
    jsonFiles['manifest.json'] = jsonEncode({
      'version': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'appVersion': appVersion,
      'dataParts': _exportedPartIds(
        selection,
        hasBrowserCookieSnapshot: browserCookieSnapshot != null,
        hasAnkiDatabase: ankiDbPath != null,
      ).toList(),
      'dataPartVersions': await DataMigrationService.getStoredPartVersions(),
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
        if (key.startsWith('flutter.') ||
            DataMigrationService.isFormatMetadataKey(key) ||
            _isDeviceLocalPreferenceKey(key) ||
            (key == _browserCookieRetentionKey && !selection.browserCookies)) {
          continue;
        }
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
      if (selection.chatRecordsAndAttachments) {
        jsonFiles['chat_data.json'] = jsonEncode(chatData);
      }
      if (selection.settings) {
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
      await _addTaskPlanFile(
        jsonFiles,
        memoryFiles,
        diskFiles,
        'synthesis/tasks.json',
        p.join(appDir, 'synthesis', 'tasks.json'),
        useStreaming,
      );
      await _addTaskPlanFile(
        jsonFiles,
        memoryFiles,
        diskFiles,
        'catcatch/tasks.json',
        p.join(appDir, 'catcatch', 'tasks.json'),
        useStreaming,
      );
      await _addTaskPlanFile(
        jsonFiles,
        memoryFiles,
        diskFiles,
        'background/tasks.json',
        p.join(appDir, 'background', 'tasks.json'),
        useStreaming,
      );
      await _addTaskPlanFile(
        jsonFiles,
        memoryFiles,
        diskFiles,
        'task_flows/flows.json',
        p.join(appDir, 'task_flows', 'flows.json'),
        useStreaming,
      );
      await _addTaskPlanFile(
        jsonFiles,
        memoryFiles,
        diskFiles,
        'task_flows/executions.json',
        p.join(appDir, 'task_flows', 'executions.json'),
        useStreaming,
      );
    }
    if (ankiDbPath != null) {
      await _addPlanFile(
        diskFiles,
        memoryFiles,
        'anki/collection.anki2',
        ankiDbPath,
        useStreaming,
      );
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
        recordTable: ManifestTables.imageRecords,
      );
      if (selection.includeMediaFiles) {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final hash = record['hash'] as String?;
          final format = record['format'] as String? ?? 'jpg';
          if (hash == null) continue;
          await _addPlanFile(
            diskFiles,
            memoryFiles,
            'pictures/$hash.$format',
            p.join(appDir, 'pictures', '$hash.$format'),
            useStreaming,
          );
          await _addPlanFile(
            diskFiles,
            memoryFiles,
            'pictures/${imageThumbFileName(hash)}',
            p.join(appDir, 'pictures', imageThumbFileName(hash)),
            useStreaming,
            required: false,
          );
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
        recordTable: ManifestTables.audioRecords,
      );
      if (selection.includeMediaFiles) {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final hash = record['hash'] as String?;
          final format = record['format'] as String? ?? 'wav';
          if (hash == null) continue;
          await _addPlanFile(
            diskFiles,
            memoryFiles,
            'tts_audio/$hash.$format',
            p.join(appDir, 'tts_audio', '$hash.$format'),
            useStreaming,
          );
          await _addPlanFile(
            diskFiles,
            memoryFiles,
            'tts_audio/$hash.txt',
            p.join(appDir, 'tts_audio', '$hash.txt'),
            useStreaming,
            required: false,
          );
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
        recordTable: ManifestTables.videoRecords,
      );
      if (selection.includeMediaFiles) {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final hash = record['hash'] as String?;
          final format = record['format'] as String? ?? 'mp4';
          if (hash == null) continue;
          await _addPlanFile(
            diskFiles,
            memoryFiles,
            'videos/$hash.$format',
            p.join(appDir, 'videos', '$hash.$format'),
            useStreaming,
          );
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
        recordTable: ManifestTables.textRecords,
      );
      if (selection.includeMediaFiles) {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final hash = record['hash'] as String?;
          if (hash == null) continue;
          await _addPlanFile(
            diskFiles,
            memoryFiles,
            'texts/$hash.txt',
            p.join(appDir, 'texts', '$hash.txt'),
            useStreaming,
          );
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
        await _addPlanFile(
          diskFiles,
          memoryFiles,
          storagePath,
          p.join(appDir, subDir, fileName),
          useStreaming,
        );
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
    bool useStreaming, {
    bool required = true,
  }) async {
    if (useStreaming) {
      if (!await File(filePath).exists()) {
        if (required) {
          throw FileSystemException('备份文件不存在', filePath);
        }
        return;
      }
      diskFiles.add([archiveName, filePath]);
      return;
    }
    // Web/测试模式：从内存读取
    final parts = archiveName.split('/');
    if (parts.length < 2) {
      if (required) throw FileSystemException('无效的备份路径', archiveName);
      return;
    }
    final subDir = parts[0];
    final fileName = parts.sublist(1).join('/');
    try {
      final data = await readBackupFile(subDir, fileName);
      if (data != null) {
        memoryFiles[archiveName] = data;
      } else if (required) {
        throw FileSystemException('备份文件不存在', '$subDir/$fileName');
      }
    } catch (e) {
      debugPrint('添加文件 $archiveName 失败: $e');
      if (required) rethrow;
    }
  }

  static Future<void> _addTaskPlanFile(
    Map<String, String> jsonFiles,
    Map<String, Uint8List> memoryFiles,
    List<List<String>> diskFiles,
    String archiveName,
    String filePath,
    bool useStreaming,
  ) async {
    if (useStreaming) {
      if (await File(filePath).exists()) {
        diskFiles.add([archiveName, filePath]);
      } else {
        jsonFiles[archiveName] = '[]';
      }
      return;
    }

    final parts = archiveName.split('/');
    final data = await readBackupFile(parts.first, parts.skip(1).join('/'));
    if (data == null) {
      jsonFiles[archiveName] = '[]';
    } else {
      memoryFiles[archiveName] = data;
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

  static const _browserCookieRetentionKey = 'browser_cookie_retention';

  /// Device-specific filesystem permissions cannot be transferred safely.
  static bool _isDeviceLocalPreferenceKey(String key) =>
      key == 'backup_saf_uri' || key == 'browser_cookie_backup_restore_pending';

  /// 判断一个 SharedPreferences 键是否属于 [selection] 中选中的类别。
  ///
  /// `flutter.*` 内部键永不参与备份/恢复/清除。
  static bool _isKeyInSelection(String key, BackupSelection selection) {
    if (key.startsWith('flutter.') ||
        _isDeviceLocalPreferenceKey(key) ||
        DataMigrationService.isFormatMetadataKey(key)) {
      return false;
    }
    if (key == _browserCookieRetentionKey) {
      return selection.settings && selection.browserCookies;
    }
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
    List<Map<String, Object?>> files,
  ) async {
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
    final browserCookieSnapshot =
        selection.browserCookies && !kIsWeb && !WebFileStore.isTestMode
            ? await BrowserCookieService.snapshotCookiesForBackup()
            : null;
    final ankiDbPath = await _findAnkiDatabasePath(selection);

    // 1. manifest.json（始终包含）
    debugPrint('[BackupService] _buildBackupBytes: building manifest');
    final manifest = {
      'version': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'appVersion': appVersion,
      'dataParts': _exportedPartIds(
        selection,
        hasBrowserCookieSnapshot: browserCookieSnapshot != null,
        hasAnkiDatabase: ankiDbPath != null,
      ).toList(),
      'dataPartVersions': await DataMigrationService.getStoredPartVersions(),
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
            recordTable: ManifestTables.textRecords,
          )
        : <String>[];
    final audioFolders = selection.audio
        ? await ManifestDatabase.getAllFolders(
            recordTable: ManifestTables.audioRecords,
          )
        : <String>[];
    final imageFolders = selection.pictures
        ? await ManifestDatabase.getAllFolders(
            recordTable: ManifestTables.imageRecords,
          )
        : <String>[];
    final videoFolders = selection.videos
        ? await ManifestDatabase.getAllFolders(
            recordTable: ManifestTables.videoRecords,
          )
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
    final chatData = <String, dynamic>{};
    final settingsData = <String, dynamic>{};

    if (selection.chatRecordsAndAttachments || selection.settings) {
      debugPrint('[BackupService] _buildBackupBytes: reading preferences');
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.') ||
            DataMigrationService.isFormatMetadataKey(key) ||
            _isDeviceLocalPreferenceKey(key) ||
            (key == _browserCookieRetentionKey && !selection.browserCookies)) {
          continue;
        }
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
    }

    if (selection.chatRecordsAndAttachments) {
      addStringToArchive(archive, 'chat_data.json', jsonEncode(chatData));
    }
    if (selection.settings) {
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
        await addTaskFileToArchive(
          archive,
          'synthesis/tasks.json',
          p.join(appDir, 'synthesis', 'tasks.json'),
        );
        await addTaskFileToArchive(
          archive,
          'catcatch/tasks.json',
          p.join(appDir, 'catcatch', 'tasks.json'),
        );
        await addTaskFileToArchive(
          archive,
          'background/tasks.json',
          p.join(appDir, 'background', 'tasks.json'),
        );
        await addTaskFileToArchive(
          archive,
          'task_flows/flows.json',
          p.join(appDir, 'task_flows', 'flows.json'),
        );
        await addTaskFileToArchive(
          archive,
          'task_flows/executions.json',
          p.join(appDir, 'task_flows', 'executions.json'),
        );
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
    if (ankiDbPath != null) {
      await addTaskFileToArchive(archive, 'anki/collection.anki2', ankiDbPath);
    }

    // 4c. 浏览器Cookies持久化数据
    if (browserCookieSnapshot != null) {
      addStringToArchive(
        archive,
        'browser_cookies.json',
        jsonEncode(browserCookieSnapshot),
      );
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
          archive,
          'pictures/$hash.$format',
          'pictures',
          '$hash.$format',
        );
        await addFileToArchive(
          archive,
          'pictures/${imageThumbFileName(hash)}',
          'pictures',
          imageThumbFileName(hash),
          required: false,
        );
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
          archive,
          'tts_audio/$hash.$format',
          'tts_audio',
          '$hash.$format',
        );
        await addFileToArchive(
          archive,
          'tts_audio/$hash.txt',
          'tts_audio',
          '$hash.txt',
          required: false,
        );
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
          archive,
          'videos/$hash.$format',
          'videos',
          '$hash.$format',
        );
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
          archive,
          'texts/$hash.txt',
          'texts',
          '$hash.txt',
        );
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
  /// [skipPostRestoreMigration] 为 true 时，恢复后不执行
  /// `migrateDataFormatIfNeeded`（数据保持快照中的旧格式与旧版本记录）。
  /// 仅迁移失败回退场景使用：此时迁移代码本身有缺陷，恢复后立即重跑
  /// 同一条坏迁移只会再次破坏数据；保持旧格式 + 旧版本记录才能让
  /// 用户回退旧版应用正常使用（旧版读到旧版本记录，版本哨兵不拦截）。
  ///
  /// 兼容 v1 和 v2 备份格式：
  /// - v1: preferences.json（聊天+设置合并），attachments/ 分开
  /// - v2: chat_data.json（聊天记录）+ settings.json（设置），
  ///       attachments/ 作为聊天记录和附件的一部分
  static Future<List<String>> _restoreFromBytes(
    Uint8List bytes, {
    void Function(double progress)? onProgress,
    BackupSelection selection = BackupSelection.all,
    bool skipPostRestoreMigration = false,
    bool skipMissingCategories = false,
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
      '[BackupService] _restoreFromBytes: archive decoded (${fileMap.length} files)',
    );

    // ================================================================
    // 预解析并校验备份中的全部 JSON 数据（在删除任何现有文件之前）。
    // 无效备份直接中止恢复，避免"选中类别的文件已被删除但恢复失败"
    // 造成的数据丢失。
    // ================================================================
    final metadata = _validateAndParseMetadata(
      (name) => fileMap[name],
      selection,
      archiveEntries: fileMap.keys.toSet(),
      skipMissingCategories: skipMissingCategories,
    );
    final restoreSelection = metadata.restoreSelection;
    _validateArchiveEntryChecksums(archive, fileMap, restoreSelection);
    final taskFlowAttachmentKeys = await _taskFlowAttachmentsToPreserve(
      restoreSelection,
      taskFilesToReplace: metadata.taskFilesToReplace,
    );
    final previousCookies = await _captureCookiesForRestoreRollback(
      restoreSelection,
      metadata.browserCookiesData,
    );
    onProgress?.call(0.15);
    await _yieldToEventLoop();

    // 先清除本次确实要恢复的数据类别。手动导入会先将备份中不存在的类别
    // 从 restoreSelection 排除，避免空备份内容清掉当前数据。
    // 删除失败（如 Windows 上文件被占用）时中止恢复并提示重启重试，
    // 与清除功能的行为一致。
    await _prepareSelectedFilesForRestore(
      restoreSelection,
      taskFlowAttachmentKeys: taskFlowAttachmentKeys,
      taskFilesToReplace: metadata.taskFilesToReplace,
    );

    // 恢复数据库记录与 SharedPreferences（使用已解析校验的数据）
    debugPrint('[BackupService] _restoreFromBytes: restoring database');
    await _restoreRecordsAndPrefs(metadata, restoreSelection);
    onProgress?.call(0.55);
    await _yieldToEventLoop();

    // 恢复二进制文件和任务文件（兼容新旧两种路径格式）
    // 新格式: pictures/, tts_audio/, videos/, texts/, attachments/, synthesis/, catcatch/
    // 旧格式: files/pictures/, files/tts_audio/, ..., tasks/synthesis_tasks.json
    debugPrint(
      '[BackupService] _restoreFromBytes: restoring binary files (selection: ${restoreSelection.selectedLabels})',
    );
    var restoreIndex = 0;
    for (final entry in fileMap.entries) {
      final handled = await _restoreArchiveEntry(entry.key, restoreSelection, (
        subDir,
        fileName,
      ) async {
        final builder = BytesBuilder(copy: false);
        builder.add(entry.value);
        await writeBackupFile(subDir, fileName, builder.takeBytes());
      });
      if (handled) {
        restoreIndex++;
        // 每处理 20 个文件让出事件循环
        if (restoreIndex % 20 == 0) await _yieldToEventLoop();
      }
    }

    // 数据迁移：确保恢复后的数据格式是最新的
    // 旧格式备份（pre-migration）中包含 chat_configs、null IDs 等，
    // 需要迁移到当前数据格式才能正常使用。
    // （迁移失败回退场景传 skipPostRestoreMigration=true，保持旧格式。）
    final restoredPartIds = _restoredPartIds(metadata, restoreSelection);
    await DataMigrationService.mergeRestoredPartVersions(
      backupVersions: metadata.dataPartVersions,
      restoredParts: restoredPartIds,
    );
    if (!skipPostRestoreMigration && restoredPartIds.isNotEmpty) {
      await DataMigrationService.migrateDataFormatIfNeeded(
        onlyParts: restoredPartIds,
      );
    }
    await _restoreBrowserCookiesAfterDataRestore(
      restoreSelection,
      metadata.browserCookiesData,
      previousCookies: previousCookies,
    );
    onProgress?.call(1.0);
    return metadata.skippedLabels;
  }

  // ================================================================
  // 流式恢复（原生）：_restoreFromBytes 的磁盘流式等价实现
  // ================================================================

  /// 从磁盘 ZIP 文件流式恢复（原生平台，[restoreBackup] 使用）。
  ///
  /// 与 [_restoreFromBytes]（Web/内存版）的恢复语义完全一致，但内存
  /// 策略不同：
  /// 1. 只解析 ZIP 中央目录（文件末尾小块），不把整个备份包读进内存；
  /// 2. 元数据文件（manifest / 数据库清单 / 偏好设置）按需少量读取；
  /// 3. 二进制条目按 64KB 分块流式解压并直接落盘（见 [_ZipStreamReader]）。
  ///
  /// 峰值内存 O(最大元数据文件 + 分块缓冲)，不随备份体积增长 ——
  /// 手动导入含数百 MB 视频的备份不再 OOM（与旧自动备份的流式创建对称）。
  static Future<List<String>> _restoreFromZipFile(
    String zipPath, {
    void Function(double progress)? onProgress,
    BackupSelection selection = BackupSelection.all,
    bool skipPostRestoreMigration = false,
    bool skipMissingCategories = false,
    bool trustEmptyLegacyTaskPayloads = false,
  }) async {
    onProgress?.call(0.0);
    await _yieldToEventLoop();

    late _ZipStreamReader reader;
    try {
      reader = _ZipStreamReader(zipPath);
    } catch (e) {
      debugPrint('[BackupService] _restoreFromZipFile: 无法解析备份文件: $e');
      throw BackupValidationException('无效的备份文件：无法读取 ($e)');
    }
    onProgress?.call(0.1);
    await _yieldToEventLoop();
    try {
      // ================================================================
      // 预解析并校验备份中的全部 JSON 数据（在删除任何现有文件之前）。
      // 无效备份直接中止恢复，避免"选中类别的文件已被删除但恢复失败"
      // 造成的数据丢失。
      //
      // 注意：元数据读取和所选条目的尺寸/CRC 预检都在删除之前；条目
      // 损坏会包装为 BackupValidationException，表示现有数据没有变动。
      // 预检通过后，实际写入仍可能因文件系统错误中断；这些错误不包装，
      // 让调用方提示恢复未完成并建议重启。
      // ================================================================
      final metadata = _validateAndParseMetadata(
        (name) {
          try {
            return reader.readMetaFile(name);
          } on _RestoreEntryCorruptException catch (e) {
            throw BackupValidationException('无效的备份文件：$e');
          }
        },
        selection,
        archiveEntries: reader.entries.map((entry) => entry.name).toSet(),
        skipMissingCategories: skipMissingCategories,
        trustEmptyLegacyTaskPayloads: trustEmptyLegacyTaskPayloads,
      );
      final restoreSelection = metadata.restoreSelection;
      _validateZipEntryChecksumsBeforeRestore(reader, restoreSelection);
      final taskFlowAttachmentKeys = await _taskFlowAttachmentsToPreserve(
        restoreSelection,
        taskFilesToReplace: metadata.taskFilesToReplace,
      );
      final previousCookies = await _captureCookiesForRestoreRollback(
        restoreSelection,
        metadata.browserCookiesData,
      );
      onProgress?.call(0.15);
      await _yieldToEventLoop();

      // 勾选即清空：先清除选中类别的现有文件（语义与内存版一致）。
      await _prepareSelectedFilesForRestore(
        restoreSelection,
        taskFlowAttachmentKeys: taskFlowAttachmentKeys,
        taskFilesToReplace: metadata.taskFilesToReplace,
      );

      // 恢复数据库记录与 SharedPreferences（使用已解析校验的数据）
      debugPrint('[BackupService] _restoreFromZipFile: restoring database');
      await _restoreRecordsAndPrefs(metadata, restoreSelection);
      onProgress?.call(0.55);
      await _yieldToEventLoop();

      // 恢复二进制文件和任务文件：逐条目分块流式落盘
      // （新格式: pictures/, tts_audio/, ...；旧格式: files/, tasks/ 前缀）
      // （条目损坏在此处按恢复中途失败传播，调用方需提示重启）
      debugPrint(
        '[BackupService] _restoreFromZipFile: restoring binary files '
        '(selection: ${restoreSelection.selectedLabels})',
      );
      var restoreIndex = 0;
      for (final entry in reader.entries) {
        final handled = await _restoreArchiveEntry(
          entry.name,
          restoreSelection,
          (subDir, fileName) =>
              _writeZipEntryStreamed(reader, entry, subDir, fileName),
        );
        if (handled) {
          restoreIndex++;
          // 每处理 20 个文件让出事件循环
          if (restoreIndex % 20 == 0) await _yieldToEventLoop();
        }
      }

      // 数据迁移：确保恢复后的数据格式是最新的
      // （迁移失败回退场景传 skipPostRestoreMigration=true，保持旧格式。）
      final restoredPartIds = _restoredPartIds(metadata, restoreSelection);
      await DataMigrationService.mergeRestoredPartVersions(
        backupVersions: metadata.dataPartVersions,
        restoredParts: restoredPartIds,
      );
      if (!skipPostRestoreMigration && restoredPartIds.isNotEmpty) {
        await DataMigrationService.migrateDataFormatIfNeeded(
          onlyParts: restoredPartIds,
        );
      }
      await _restoreBrowserCookiesAfterDataRestore(
        restoreSelection,
        metadata.browserCookiesData,
        previousCookies: previousCookies,
      );
      onProgress?.call(1.0);
      return metadata.skippedLabels;
    } finally {
      reader.close();
    }
  }

  /// 把单个 ZIP 条目分块写出到应用数据目录。
  ///
  /// 测试模式（[WebFileStore.isTestMode]）：收集后经 [writeBackupFile]
  /// 写入（与内存版测试路径一致）；原生：直接分块写磁盘，峰值内存
  /// O(块大小)，不随条目大小增长。
  ///
  /// 写出失败时删除半成品文件，避免损坏的半个文件被后续逻辑使用。
  static Future<void> _writeZipEntryStreamed(
    _ZipStreamReader reader,
    _ZipEntryInfo entry,
    String subDir,
    String fileName,
  ) async {
    if (WebFileStore.isTestMode) {
      final builder = BytesBuilder(copy: false);
      reader.extractEntry(entry, builder.add);
      await writeBackupFile(subDir, fileName, builder.takeBytes());
      return;
    }
    final appDir = await AppStorage.directory;
    final dir = Directory(p.join(appDir, subDir));
    await dir.create(recursive: true);
    final dest = File(p.join(dir.path, fileName));
    final raf = dest.openSync(mode: FileMode.write);
    try {
      reader.extractEntry(entry, raf.writeFromSync);
    } catch (_) {
      try {
        raf.closeSync();
      } catch (_) {}
      try {
        await dest.delete();
      } catch (_) {}
      rethrow;
    }
    raf.closeSync();
  }

  /// 预解析并校验备份中的全部 JSON 元数据（在任何删除操作之前调用）。
  ///
  /// [readFile] 读取归档中的文件（不存在返回 `null`）。
  /// 无效备份抛 [BackupValidationException]。
  ///
  /// 兼容 v1 和 v2 备份格式：
  /// - v1: preferences.json（聊天+设置合并），attachments/ 分开
  /// - v2: chat_data.json（聊天记录）+ settings.json（设置），
  ///       attachments/ 作为聊天记录和附件的一部分
  static _RestoreMetadata _validateAndParseMetadata(
    Uint8List? Function(String name) readFile,
    BackupSelection selection, {
    required Set<String> archiveEntries,
    required bool skipMissingCategories,
    bool trustEmptyLegacyTaskPayloads = false,
  }) {
    // 验证 manifest（兼容 v1 和 v2）
    final manifestJson = readFile('manifest.json');
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

    // 数据库清单（stroom_manifest.json，兼容旧路径 database/manifest_data.json）
    Map<String, dynamic>? dbData;
    final needsMediaManifest = selection.pictures ||
        selection.audio ||
        selection.videos ||
        selection.texts;
    final dbJson = needsMediaManifest
        ? readFile('stroom_manifest.json') ??
            readFile('database/manifest_data.json')
        : null;
    if (dbJson != null) {
      try {
        final decoded = jsonDecode(utf8.decode(dbJson));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('结构不是对象');
        }
        // 校验嵌套结构（与 _restoreDatabaseFromJson 的取值逻辑一致），
        // 防止恢复中途因字段形状错误抛错
        void validateRecordList(
          Object? value,
          String field,
          Set<String> allowedColumns,
          Set<String> stringColumns,
          Set<String> integerColumns,
        ) {
          if (value == null) return;
          if (value is! List) throw FormatException('$field 不是数组');
          for (final item in value) {
            if (item is! Map<String, dynamic>) {
              throw FormatException('$field 包含非对象记录');
            }

            final columns = <String, Object?>{};
            final sanitizedItem = <String, dynamic>{};
            for (final entry in item.entries) {
              final column = camelToSnake[entry.key] ?? entry.key;
              if (!allowedColumns.contains(column)) {
                // Ignore fields from newer app versions. This app cannot
                // persist unknown columns, but they should not make an
                // otherwise usable cross-version backup unrestorable.
                continue;
              }
              if (columns.containsKey(column)) {
                throw FormatException('$field 中字段 ${entry.key} 重复');
              }
              columns[column] = entry.value;
              sanitizedItem[entry.key] = entry.value;
            }

            for (final requiredColumn in const {
              'id',
              'name',
              'hash',
              'created_at',
            }) {
              if (!columns.containsKey(requiredColumn)) {
                throw FormatException('$field 缺少必需字段 $requiredColumn');
              }
            }

            for (final entry in columns.entries) {
              final value = entry.value;
              if (stringColumns.contains(entry.key)) {
                if (value is! String) {
                  throw FormatException('$field 字段 ${entry.key} 不是字符串');
                }
              } else if (integerColumns.contains(entry.key)) {
                if (entry.key == 'duration' ? value is! num : value is! int) {
                  throw FormatException('$field 字段 ${entry.key} 不是有效数字');
                }
              } else if (entry.key == 'created_at' ||
                  entry.key == 'modified_at') {
                if (value is String) {
                  try {
                    DateTime.parse(value);
                  } on FormatException {
                    throw FormatException('$field 字段 ${entry.key} 日期无效');
                  }
                } else if (value is! int) {
                  throw FormatException('$field 字段 ${entry.key} 不是有效日期');
                }
              }
            }

            item
              ..clear()
              ..addAll(sanitizedItem);
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

        const commonColumns = {
          'id',
          'name',
          'hash',
          'format',
          'created_at',
          'modified_at',
          'size',
          'folder',
        };
        const commonStringColumns = {'id', 'name', 'hash', 'format', 'folder'};
        const commonIntegerColumns = {'size'};
        bool needsLegacyFolders(Object? value) =>
            value is! List || value.isEmpty;
        bool usesLegacyFolders = false;
        if (selection.pictures) {
          final folders = decoded[ManifestTables.imageFolders];
          validateRecordList(
            decoded['image_records'],
            'image_records',
            commonColumns,
            commonStringColumns,
            commonIntegerColumns,
          );
          validateFolderList(folders, ManifestTables.imageFolders);
          usesLegacyFolders = usesLegacyFolders || needsLegacyFolders(folders);
        }
        if (selection.audio) {
          final folders = decoded[ManifestTables.audioFolders];
          validateRecordList(
            decoded['audio_records'],
            'audio_records',
            {...commonColumns, 'source_text', 'duration'},
            {...commonStringColumns, 'source_text'},
            {...commonIntegerColumns, 'duration'},
          );
          validateFolderList(folders, ManifestTables.audioFolders);
          usesLegacyFolders = usesLegacyFolders || needsLegacyFolders(folders);
        }
        if (selection.videos) {
          final folders = decoded[ManifestTables.videoFolders];
          validateRecordList(
            decoded['video_records'],
            'video_records',
            {...commonColumns, 'duration'},
            commonStringColumns,
            {...commonIntegerColumns, 'duration'},
          );
          validateFolderList(folders, ManifestTables.videoFolders);
          usesLegacyFolders = usesLegacyFolders || needsLegacyFolders(folders);
        }
        if (selection.texts) {
          final folders = decoded[ManifestTables.textFolders];
          validateRecordList(
            decoded['text_records'],
            'text_records',
            {...commonColumns, 'text_length'},
            commonStringColumns,
            {...commonIntegerColumns, 'text_length'},
          );
          validateFolderList(folders, ManifestTables.textFolders);
          usesLegacyFolders = usesLegacyFolders || needsLegacyFolders(folders);
        }
        // Older v1 manifests used one shared folder list as a fallback for
        // every selected media type that has no per-type folders.
        if (usesLegacyFolders) {
          validateFolderList(decoded['folders'], 'folders');
        }
        dbData = decoded;
      } catch (e) {
        throw BackupValidationException('无效的备份文件：数据库记录损坏 ($e)');
      }
    }

    // 偏好设置：只校验选中类别的文件（未选中的类别不参与恢复，
    // 其文件损坏不应阻止其他类别的恢复）
    Map<String, dynamic>? v1Prefs;
    Map<String, dynamic>? chatPrefs;
    Map<String, dynamic>? settingsPrefs;
    Map<String, dynamic>? validatePrefsFile(String name) {
      final raw = readFile(name);
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

    final declaredSelection = _selectionFromDeclaredParts(
      manifest['dataParts'],
    );
    final availableSelection = declaredSelection != null
        ? _getAvailableDeclaredSelection(
            declared: declaredSelection,
            archiveEntries: archiveEntries,
            dbData: dbData,
            chatPrefs: isV1Format ? v1Prefs : chatPrefs,
            requireMediaFiles: selection.includeMediaFiles,
            requireAttachmentFiles: selection.chatRecordsAndAttachments &&
                selection.includeMediaFiles,
          )
        : _getAvailableSelection(
            archiveEntries: archiveEntries,
            dbData: dbData,
            v1Prefs: v1Prefs,
            chatPrefs: chatPrefs,
            settingsPrefs: settingsPrefs,
            isV1: isV1Format,
            hasTaskData: skipMissingCategories &&
                selection.tasks &&
                (trustEmptyLegacyTaskPayloads
                    ? _hasTaskPayloadFile(archiveEntries)
                    : _hasNonEmptyTaskPayload(readFile)),
            requireMediaFiles: selection.includeMediaFiles,
            requireAttachmentFiles: selection.chatRecordsAndAttachments &&
                selection.includeMediaFiles,
          );
    final skippedLabels = skipMissingCategories
        ? selection.selectedLabels
            .where(
              (label) => !availableSelection.selectedLabels.contains(label),
            )
            .toList()
        : <String>[];
    final restoreSelection = skipMissingCategories
        ? _intersectSelections(selection, availableSelection)
        : selection;
    // Tasks is a single selectable category. When an archive makes that
    // category available, clear every known task payload before restoring the
    // files it contains so a partial legacy archive cannot merge stale local
    // task types into the restored category.
    final taskFilesToReplace = restoreSelection.tasks
        ? _taskPayloadFiles
            .map(_canonicalTaskPayloadName)
            .whereType<String>()
            .toSet()
        : <String>{};

    if (restoreSelection.tasks) {
      _validateTaskPayloads(readFile, archiveEntries);
    }

    Uint8List? browserCookiesData;
    if (restoreSelection.browserCookies) {
      browserCookiesData = readFile('browser_cookies.json');
      if (browserCookiesData != null) {
        try {
          BrowserCookieService.validateCookieSnapshotForRestore(
            jsonDecode(utf8.decode(browserCookiesData)),
          );
        } catch (e) {
          throw BackupValidationException(
            '无效的备份文件：browser_cookies.json 损坏 ($e)',
          );
        }
      }
    }

    Map<String, dynamic>? versionPrefs = v1Prefs ?? settingsPrefs;
    if (versionPrefs == null) {
      // Older archives stored the source format version in preferences. Read
      // that metadata even when restoring another category, but ignore a
      // malformed unselected preferences file so it cannot block the restore.
      final rawPrefs = readFile(
        isV1Format ? 'preferences.json' : 'settings.json',
      );
      if (rawPrefs != null) {
        try {
          final decoded = jsonDecode(utf8.decode(rawPrefs));
          if (decoded is Map<String, dynamic>) versionPrefs = decoded;
        } catch (_) {}
      }
    }
    final dataPartVersions =
        _parseBackupPartVersions(manifest['dataPartVersions']) ??
            _parseBackupPartVersions(versionPrefs?['data_format_versions']) ??
            DataMigrationService.partVersionsFromLegacyGlobal(
              versionPrefs?['data_format_version'],
            );

    for (final part in restoreSelection.selectedPartIds) {
      final backupVersion = dataPartVersions?[part];
      final currentVersion = DataMigrationService.currentPartVersions[part];
      if (backupVersion != null &&
          currentVersion != null &&
          backupVersion > currentVersion) {
        throw const BackupValidationException(
          '备份包含由较新版本 Stroom 创建的数据格式，请先更新应用后再导入',
        );
      }
    }

    return _RestoreMetadata(
      isV1: isV1Format,
      restoreChatPreferences: declaredSelection?.chatRecordsAndAttachments ??
          (isV1Format
              ? v1Prefs?.keys.any(_isChatPrefKey) ?? false
              : chatPrefs != null),
      dbData: dbData,
      v1Prefs: v1Prefs,
      chatPrefs: chatPrefs,
      settingsPrefs: settingsPrefs,
      restoreSelection: restoreSelection,
      taskFilesToReplace: taskFilesToReplace,
      skippedLabels: skippedLabels,
      dataPartVersions: dataPartVersions,
      browserCookiesData: browserCookiesData,
    );
  }

  /// 新格式清单明确记录导出时选中的类别；旧备份没有该字段，需按归档
  /// 内容推断。显式字段可区分“选中的空类别”和“未导出的类别”。
  /// Web 和测试文件存储不导出任务文件、原生 Anki 数据库与浏览器
  /// Cookies，因此清单也必须排除这些类别，避免导入时清理目标端数据。
  static Future<String?> _findAnkiDatabasePath(
    BackupSelection selection,
  ) async {
    if (!selection.ankiData || kIsWeb || WebFileStore.isTestMode) return null;
    try {
      final path = p.join(await AppStorage.directory, 'collection.anki2');
      return await File(path).exists() ? path : null;
    } catch (_) {
      return null;
    }
  }

  static Set<String> _exportedPartIds(
    BackupSelection selection, {
    required bool hasBrowserCookieSnapshot,
    required bool hasAnkiDatabase,
  }) {
    final parts = selection.selectedPartIds;
    if (kIsWeb || WebFileStore.isTestMode) {
      parts
        ..remove(DataParts.tasks)
        ..remove(DataParts.anki)
        ..remove(DataParts.browserCookies);
    } else if (!hasBrowserCookieSnapshot) {
      parts.remove(DataParts.browserCookies);
    }
    if (!hasAnkiDatabase) parts.remove(DataParts.anki);
    return parts;
  }

  static BackupSelection? _selectionFromDeclaredParts(Object? value) {
    if (value == null) return null;
    if (value is! List || value.any((part) => part is! String)) {
      throw BackupValidationException('无效的备份文件：dataParts 字段损坏');
    }
    final parts = value.whereType<String>().toSet();
    return BackupSelection(
      chatRecordsAndAttachments: parts.contains(DataParts.chat),
      settings: parts.contains(DataParts.settings),
      pictures: parts.contains(DataParts.pictures),
      audio: parts.contains(DataParts.audio),
      videos: parts.contains(DataParts.videos),
      texts: parts.contains(DataParts.texts),
      tasks: parts.contains(DataParts.tasks),
      ankiData: parts.contains(DataParts.anki),
      browserCookies: parts.contains(DataParts.browserCookies),
    );
  }

  static BackupSelection _intersectSelections(
    BackupSelection requested,
    BackupSelection available,
  ) =>
      BackupSelection(
        chatRecordsAndAttachments: requested.chatRecordsAndAttachments &&
            available.chatRecordsAndAttachments,
        settings: requested.settings && available.settings,
        pictures: requested.pictures && available.pictures,
        audio: requested.audio && available.audio,
        videos: requested.videos && available.videos,
        texts: requested.texts && available.texts,
        tasks: requested.tasks && available.tasks,
        ankiData: requested.ankiData && available.ankiData,
        browserCookies: requested.browserCookies && available.browserCookies,
        includeMediaFiles: requested.includeMediaFiles,
      );

  static bool _isSafeRelativeArchivePath(String path) {
    final pathSegments = path.split(RegExp(r'[/\\]'));
    return !pathSegments.any((part) => part == '..') &&
        !RegExp(r'^[a-zA-Z]:').hasMatch(path) &&
        !path.startsWith('/') &&
        pathSegments.first.isNotEmpty;
  }

  static void _validateArchiveEntryChecksums(
    Archive archive,
    Map<String, Uint8List> fileMap,
    BackupSelection selection,
  ) {
    for (final file in archive) {
      if (!file.isFile ||
          !_shouldValidateArchiveEntryChecksum(file.name, selection)) {
        continue;
      }
      final expected = file.crc32;
      final content = fileMap[file.name];
      if (expected == null || content == null) {
        throw BackupValidationException('无效的备份文件：条目 ${file.name} 缺少校验信息');
      }
      final checksum = _ZipCrc32()..add(content);
      if (checksum.value != expected) {
        throw BackupValidationException('无效的备份文件：条目 ${file.name} CRC32 校验失败');
      }
    }
  }

  static void _validateZipEntryChecksumsBeforeRestore(
    _ZipStreamReader reader,
    BackupSelection selection,
  ) {
    for (final entry in reader.entries) {
      if (!_shouldValidateArchiveEntryChecksum(entry.name, selection)) {
        continue;
      }
      try {
        reader.extractEntry(entry, (_) {});
      } on _RestoreEntryCorruptException catch (e) {
        throw BackupValidationException('无效的备份文件：$e');
      }
    }
  }

  static bool _shouldValidateArchiveEntryChecksum(
    String rawKey,
    BackupSelection selection,
  ) {
    if (rawKey == 'manifest.json') return true;
    if (rawKey == 'stroom_manifest.json' ||
        rawKey == 'database/manifest_data.json') {
      return selection.pictures ||
          selection.audio ||
          selection.videos ||
          selection.texts;
    }
    if (rawKey == 'preferences.json') {
      return selection.chatRecordsAndAttachments || selection.settings;
    }
    if (rawKey == 'chat_data.json') {
      return selection.chatRecordsAndAttachments;
    }
    if (rawKey == 'settings.json') return selection.settings;
    if (rawKey == 'browser_cookies.json') return selection.browserCookies;
    if (rawKey.endsWith('/') || rawKey.endsWith(r'\')) return false;

    var key = rawKey;
    if (key.startsWith('files/')) {
      key = key.substring('files/'.length);
    }
    if (key.startsWith('temp_edited/')) {
      key = 'attachments/${p.basename(key)}';
    }
    if (key.startsWith('tasks/')) {
      key = key.substring('tasks/'.length);
      if (key == 'synthesis_tasks.json') key = 'synthesis/tasks.json';
      if (key == 'catcatch_tasks.json') key = 'catcatch/tasks.json';
    }
    if (key == 'collection.anki2') return selection.ankiData;

    for (final dir in _restoreKnownDirs) {
      if (!key.startsWith('$dir/')) continue;
      final relativePath = key.substring(dir.length + 1);
      return _shouldRestoreDir(dir, selection) &&
          _isSafeRelativeArchivePath(relativePath);
    }
    return false;
  }

  static bool _hasAllMediaFiles({
    required Map<String, dynamic>? dbData,
    required Set<String> archiveEntries,
    required String recordsKey,
    required String directory,
    required String defaultExtension,
  }) {
    final records = dbData?[recordsKey];
    if (records is! List) return false;
    for (final record in records) {
      if (record is! Map || record['hash'] is! String) return false;
      final rawExtension = record['format'];
      if (rawExtension != null && rawExtension is! String) return false;
      final extension = (rawExtension as String?) ?? defaultExtension;
      final relativePath = '${record['hash']}.$extension';
      if (!_isSafeRelativeArchivePath(relativePath) ||
          !archiveEntries.contains('$directory/$relativePath')) {
        return false;
      }
    }
    return true;
  }

  static BackupSelection _getAvailableDeclaredSelection({
    required BackupSelection declared,
    required Set<String> archiveEntries,
    required Map<String, dynamic>? dbData,
    required Map<String, dynamic>? chatPrefs,
    required bool requireMediaFiles,
    required bool requireAttachmentFiles,
  }) {
    final entries = archiveEntries
        .where((entry) => !entry.endsWith('/') && !entry.endsWith(r'\'))
        .map(
          (entry) => entry.startsWith('files/')
              ? entry.substring('files/'.length)
              : entry,
        )
        .toSet();

    final hasManifest = dbData != null;
    return BackupSelection(
      chatRecordsAndAttachments: declared.chatRecordsAndAttachments &&
          entries.contains('chat_data.json') &&
          _hasAllReferencedAttachmentFiles(
            chatPrefs: chatPrefs,
            archiveEntries: entries,
            requireFiles: requireAttachmentFiles,
          ),
      settings: declared.settings && entries.contains('settings.json'),
      pictures: declared.pictures &&
          hasManifest &&
          (!requireMediaFiles ||
              _hasAllMediaFiles(
                dbData: dbData,
                archiveEntries: entries,
                recordsKey: 'image_records',
                directory: 'pictures',
                defaultExtension: 'jpg',
              )),
      audio: declared.audio &&
          hasManifest &&
          (!requireMediaFiles ||
              _hasAllMediaFiles(
                dbData: dbData,
                archiveEntries: entries,
                recordsKey: 'audio_records',
                directory: 'tts_audio',
                defaultExtension: 'wav',
              )),
      videos: declared.videos &&
          hasManifest &&
          (!requireMediaFiles ||
              _hasAllMediaFiles(
                dbData: dbData,
                archiveEntries: entries,
                recordsKey: 'video_records',
                directory: 'videos',
                defaultExtension: 'mp4',
              )),
      texts: declared.texts &&
          hasManifest &&
          (!requireMediaFiles ||
              _hasAllMediaFiles(
                dbData: dbData,
                archiveEntries: entries,
                recordsKey: 'text_records',
                directory: 'texts',
                defaultExtension: 'txt',
              )),
      tasks: !kIsWeb &&
          declared.tasks &&
          const [
            'synthesis/tasks.json',
            'catcatch/tasks.json',
            'background/tasks.json',
            'task_flows/flows.json',
            'task_flows/executions.json',
          ].every(entries.contains),
      ankiData: !kIsWeb &&
          declared.ankiData &&
          (entries.contains('anki/collection.anki2') ||
              entries.contains('collection.anki2')),
      browserCookies: declared.browserCookies &&
          !kIsWeb &&
          entries.contains('browser_cookies.json'),
    );
  }

  static bool _hasAllReferencedAttachmentFiles({
    required Map<String, dynamic>? chatPrefs,
    required Set<String> archiveEntries,
    required bool requireFiles,
  }) {
    if (!requireFiles) return true;
    final rawConversations = chatPrefs?['conversations'];
    if (rawConversations == null) return true;
    if (rawConversations is! String) return false;

    final Object? decoded;
    try {
      decoded = jsonDecode(rawConversations);
    } catch (_) {
      return false;
    }
    if (decoded is! List) return false;

    bool allPresent = true;
    void checkAttachments(Object? rawAttachments) {
      if (rawAttachments == null) return;
      if (rawAttachments is! List) {
        allPresent = false;
        return;
      }
      for (final attachment in rawAttachments) {
        if (attachment is! Map) {
          allPresent = false;
          continue;
        }
        for (final key in const ['storagePath', 'thumbnailPath']) {
          final path = attachment[key];
          if (path == null || path == '') continue;
          if (path is! String) {
            allPresent = false;
            continue;
          }
          final normalizedPath = path.replaceAll(r'\', '/');
          if (!_isSafeRelativeArchivePath(normalizedPath)) {
            allPresent = false;
            continue;
          }
          final archivePaths = normalizedPath.startsWith('temp_edited/')
              ? {normalizedPath, 'attachments/${p.basename(normalizedPath)}'}
              : {normalizedPath};
          if (!archivePaths.any(archiveEntries.contains)) allPresent = false;
        }
      }
    }

    for (final conversation in decoded) {
      if (conversation is! Map) {
        allPresent = false;
        continue;
      }
      final messages = conversation['messages'];
      if (messages is! List) {
        allPresent = false;
      } else {
        for (final message in messages) {
          if (message is! Map) {
            allPresent = false;
            continue;
          }
          checkAttachments(message['attachments']);
        }
      }
      checkAttachments(conversation['draftAttachments']);
    }
    return allPresent;
  }

  static Set<String> _restoredPartIds(
    _RestoreMetadata metadata,
    BackupSelection selection,
  ) {
    final parts = {...selection.selectedPartIds};
    if (selection.chatRecordsAndAttachments &&
        !metadata.restoreChatPreferences) {
      parts.remove(DataParts.chat);
    }
    return parts;
  }

  static BackupSelection _getAvailableSelection({
    required Set<String> archiveEntries,
    required Map<String, dynamic>? dbData,
    required Map<String, dynamic>? v1Prefs,
    required Map<String, dynamic>? chatPrefs,
    required Map<String, dynamic>? settingsPrefs,
    required bool isV1,
    required bool hasTaskData,
    required bool requireMediaFiles,
    required bool requireAttachmentFiles,
  }) {
    final normalizedEntries = archiveEntries
        .where((entry) => !entry.endsWith('/') && !entry.endsWith(r'\'))
        .map(
          (entry) => entry.startsWith('files/')
              ? entry.substring('files/'.length)
              : entry,
        )
        .toSet();
    bool hasNonEmptyList(Map<String, dynamic>? data, String key) =>
        data?[key] is List && (data![key] as List).isNotEmpty;

    bool hasDirectory(String directory) =>
        normalizedEntries.any((entry) => entry.startsWith('$directory/'));

    bool hasV1Preference(bool Function(String key) predicate) =>
        v1Prefs?.keys.any(
          (key) =>
              !_isDeviceLocalPreferenceKey(key) &&
              !DataMigrationService.isFormatMetadataKey(key) &&
              predicate(key),
        ) ??
        false;

    bool hasSettingsPreference(Map<String, dynamic>? prefs) =>
        prefs?.keys.any(
          (key) =>
              key != _browserCookieRetentionKey &&
              !key.startsWith('flutter.') &&
              !_isDeviceLocalPreferenceKey(key) &&
              !DataMigrationService.isFormatMetadataKey(key),
        ) ??
        false;

    bool hasMediaData(
      String recordsKey,
      String foldersKey,
      String directory,
      String defaultExtension,
    ) {
      final records = dbData?[recordsKey];
      if (records != null) {
        if (records is! List) return false;
        if (records.isNotEmpty) {
          if (!requireMediaFiles) return true;
          return _hasAllMediaFiles(
            dbData: dbData,
            archiveEntries: normalizedEntries,
            recordsKey: recordsKey,
            directory: directory,
            defaultExtension: defaultExtension,
          );
        }
      }
      if (requireMediaFiles && hasDirectory(directory)) return false;
      return hasNonEmptyList(dbData, foldersKey);
    }

    final hasChatData = normalizedEntries.contains('chat_data.json') ||
        (isV1 && hasV1Preference(_isChatPrefKey));
    final chatAttachmentsPresent = _hasAllReferencedAttachmentFiles(
      chatPrefs: isV1 ? v1Prefs : chatPrefs,
      archiveEntries: normalizedEntries,
      requireFiles: requireAttachmentFiles,
    );

    return BackupSelection(
      chatRecordsAndAttachments: hasChatData && chatAttachmentsPresent,
      settings: hasSettingsPreference(settingsPrefs) ||
          (isV1 &&
              hasV1Preference(
                (key) =>
                    !_isChatPrefKey(key) &&
                    key != _browserCookieRetentionKey &&
                    !DataMigrationService.isFormatMetadataKey(key),
              )),
      pictures: hasMediaData(
        'image_records',
        ManifestTables.imageFolders,
        'pictures',
        'jpg',
      ),
      audio: hasMediaData(
        'audio_records',
        ManifestTables.audioFolders,
        'tts_audio',
        'wav',
      ),
      videos: hasMediaData(
        'video_records',
        ManifestTables.videoFolders,
        'videos',
        'mp4',
      ),
      texts: hasMediaData(
        'text_records',
        ManifestTables.textFolders,
        'texts',
        'txt',
      ),
      tasks: !kIsWeb && hasTaskData,
      ankiData: !kIsWeb &&
          (normalizedEntries.contains('anki/collection.anki2') ||
              normalizedEntries.contains('collection.anki2')),
      browserCookies:
          !kIsWeb && normalizedEntries.contains('browser_cookies.json'),
    );
  }

  static const _taskPayloadFiles = [
    'synthesis/tasks.json',
    'files/synthesis/tasks.json',
    'catcatch/tasks.json',
    'files/catcatch/tasks.json',
    'background/tasks.json',
    'files/background/tasks.json',
    'task_flows/flows.json',
    'files/task_flows/flows.json',
    'task_flows/executions.json',
    'files/task_flows/executions.json',
    'tasks/synthesis_tasks.json',
    'files/tasks/synthesis_tasks.json',
    'tasks/catcatch_tasks.json',
    'files/tasks/catcatch_tasks.json',
  ];

  static bool _hasTaskPayloadFile(Set<String> archiveEntries) =>
      _taskPayloadFiles.any(archiveEntries.contains);

  /// Older Web archives have task filenames containing only placeholder
  /// empty arrays. Without `dataParts`, count task data as available only if
  /// at least one recognized task file actually contains records.
  static bool _hasNonEmptyTaskPayload(
    Uint8List? Function(String name) readFile,
  ) {
    for (final name in _taskPayloadFiles) {
      final raw = readFile(name);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(utf8.decode(raw));
        if (decoded is List && decoded.isNotEmpty) return true;
        if (decoded is Map) {
          final jobs = decoded['jobs'];
          if (jobs is List && jobs.isNotEmpty) return true;
        }
      } catch (_) {
        // A malformed or unrelated task entry is not usable task data.
      }
    }
    return false;
  }

  /// Parses every selected task payload through the same model factories used
  /// by the task providers. A malformed entry must be caught before restore
  /// clears the existing task files.
  static void _validateTaskPayloads(
    Uint8List? Function(String name) readFile,
    Set<String> archiveEntries,
  ) {
    for (final name in _taskPayloadFiles) {
      if (!archiveEntries.contains(name)) continue;
      final raw = readFile(name);
      if (raw == null) continue;
      final target = _canonicalTaskPayloadName(name);
      if (target == null) continue;
      try {
        final decoded = jsonDecode(utf8.decode(raw));
        if (decoded is! List) {
          final legacyName = name.startsWith('files/')
              ? name.substring('files/'.length)
              : name;
          if (legacyName == 'tasks/synthesis_tasks.json' &&
              decoded is Map &&
              decoded['jobs'] is List &&
              (decoded['jobs'] as List).every((job) => job is Map)) {
            // Older backups stored synthesis jobs in an object envelope.
            // Preserve this supported legacy payload as-is.
            continue;
          }
          throw const FormatException('结构不是数组');
        }
        for (final item in decoded) {
          if (item is! Map) {
            throw const FormatException('包含非对象任务记录');
          }
          final map = Map<String, dynamic>.from(item);
          switch (target) {
            case 'synthesis/tasks.json':
              SynthesisTask.fromMap(map);
              break;
            case 'catcatch/tasks.json':
              CatCatchTask.fromMap(map);
              break;
            case 'background/tasks.json':
              BackgroundTask.fromMap(map);
              break;
            case 'task_flows/flows.json':
              TaskFlowDefinition.fromMap(map);
              break;
            case 'task_flows/executions.json':
              TaskFlowExecution.fromMap(map);
              break;
          }
        }
      } catch (e) {
        throw BackupValidationException('无效的备份文件：$name 损坏 ($e)');
      }
    }
  }

  static String? _canonicalTaskPayloadName(String name) {
    var normalized =
        name.startsWith('files/') ? name.substring('files/'.length) : name;
    if (normalized == 'tasks/synthesis_tasks.json') {
      normalized = 'synthesis/tasks.json';
    } else if (normalized == 'tasks/catcatch_tasks.json') {
      normalized = 'catcatch/tasks.json';
    }
    return const {
      'synthesis/tasks.json',
      'catcatch/tasks.json',
      'background/tasks.json',
      'task_flows/flows.json',
      'task_flows/executions.json',
    }.contains(normalized)
        ? normalized
        : null;
  }

  static Future<List<Map<String, dynamic>>?> _captureCookiesForRestoreRollback(
    BackupSelection selection,
    Uint8List? cookieData,
  ) async {
    if (!selection.browserCookies ||
        cookieData == null ||
        kIsWeb ||
        WebFileStore.isTestMode) {
      return null;
    }

    if (!(Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows)) {
      throw const DataManagementPreflightException(
        '当前平台无法完整读取现有内置浏览器Cookies，已中止恢复以保护现有数据。',
      );
    }

    final snapshot = await BrowserCookieService.runExclusiveRetentionOperation(
      () => BrowserCookieService.snapshotCookiesForRestoreRollback(),
    );
    if (snapshot == null) {
      throw const DataManagementPreflightException(
        '当前平台无法完整读取现有内置浏览器Cookies，已中止恢复以保护现有数据。',
      );
    }
    return snapshot;
  }

  static Future<void> _clearLiveCookiesForRestore(
    BackupSelection selection,
  ) async {
    if (!selection.browserCookies ||
        kIsWeb ||
        WebFileStore.isTestMode ||
        !(Platform.isAndroid ||
            Platform.isIOS ||
            Platform.isMacOS ||
            Platform.isWindows ||
            Platform.isLinux)) {
      return;
    }
    if (!await BrowserCookieService.clearPlatformCookies()) {
      throw Exception('清除本机内置浏览器Cookies失败，已中止恢复');
    }
  }

  static Future<Set<String>> _taskFlowAttachmentsToPreserve(
    BackupSelection selection, {
    Set<String>? taskFilesToReplace,
  }) async {
    if (!selection.chatRecordsAndAttachments || !selection.includeMediaFiles) {
      return <String>{};
    }

    const taskFlowFiles = <String>{
      'task_flows/flows.json',
      'task_flows/executions.json',
    };
    final taskFlowFilesToPreserve = taskFilesToReplace == null
        ? (selection.tasks ? <String>{} : taskFlowFiles)
        : taskFlowFiles.difference(taskFilesToReplace);
    if (taskFlowFilesToPreserve.isEmpty) return <String>{};

    final preservedTaskFiles = await _collectTaskFlowAttachmentKeys(
      taskFlowFilesToPreserve,
    );
    if (preservedTaskFiles == null) {
      throw const DataManagementPreflightException(
        '无法读取未被替换任务中的附件引用，已取消操作以避免误删数据。',
      );
    }
    return preservedTaskFiles;
  }

  /// Keep the existing cookie snapshot until all other selected data has been
  /// restored, so an earlier failure leaves the destination's cookies intact.
  static Future<void> _prepareSelectedFilesForRestore(
    BackupSelection selection, {
    required Set<String> taskFlowAttachmentKeys,
    required Set<String> taskFilesToReplace,
  }) async {
    if (await _deleteSelectedFiles(
      selection,
      taskFlowAttachmentKeys: taskFlowAttachmentKeys,
      preserveBrowserCookieSnapshot: selection.browserCookies,
      taskFilesToReplace: taskFilesToReplace,
    )) {
      throw Exception('部分数据文件删除失败，请重启应用后重试');
    }
  }

  /// Replaces cookies after all other selected data and migrations succeed.
  /// On failure, restore the old live state and snapshot file.
  static Future<void> _restoreBrowserCookiesAfterDataRestore(
    BackupSelection selection,
    Uint8List? cookieData, {
    required List<Map<String, dynamic>>? previousCookies,
  }) async {
    if (!selection.browserCookies || cookieData == null) return;

    await BrowserCookieService.runExclusiveRetentionOperation(() async {
      // Retention may have persisted or cleared cookies while the other
      // selected categories were being restored. Capture the latest rollback
      // state after joining the queue, before replacing the cookie snapshot.
      final rollbackCookies = previousCookies == null
          ? null
          : (await BrowserCookieService.snapshotCookiesForRestoreRollback() ??
              previousCookies);
      final previousFileData = await readBackupFile('', 'browser_cookies.json');
      final previousRestorePending =
          await BrowserCookieService.hasBackupRestorePending();
      try {
        await _clearLiveCookiesForRestore(selection);
        await writeBackupFile('', 'browser_cookies.json', cookieData);
        if (!WebFileStore.isTestMode &&
            !await BrowserCookieService.restoreCookiesFromFileChecked(
              force: true,
            )) {
          throw Exception('部分内置浏览器Cookies未能恢复');
        }
        await BrowserCookieService.markBackupRestorePending();
      } catch (e) {
        await _rollbackCookiesAfterFailedRestore(
          previousCookies: rollbackCookies,
          previousFileData: previousFileData,
          previousRestorePending: previousRestorePending,
        );
        rethrow;
      }
    });
  }

  static Future<void> _rollbackCookiesAfterFailedRestore({
    required List<Map<String, dynamic>>? previousCookies,
    required Uint8List? previousFileData,
    required bool previousRestorePending,
  }) async {
    try {
      if (previousCookies != null) {
        await BrowserCookieService.clearPlatformCookies();
      }
      if (previousFileData == null) {
        await _deleteFile('', 'browser_cookies.json');
      } else {
        await writeBackupFile('', 'browser_cookies.json', previousFileData);
      }
      if (previousCookies == null) {
        if (previousFileData != null) {
          await BrowserCookieService.restoreCookiesFromFile(force: true);
        }
      } else {
        await BrowserCookieService.restoreCookiesFromSnapshot(
          previousCookies,
          force: true,
        );
      }
    } catch (e) {
      debugPrint('恢复失败后回滚Cookies状态时出错: $e');
    } finally {
      if (previousRestorePending) {
        await BrowserCookieService.markBackupRestorePending();
      } else {
        await BrowserCookieService.clearBackupRestorePending();
      }
    }
  }

  static Map<String, int>? _parseBackupPartVersions(Object? value) {
    Object? decoded = value;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return null;
      }
    }
    if (decoded is! Map) return null;

    final versions = <String, int>{};
    for (final part in DataMigrationService.currentPartVersions.keys) {
      final version = decoded[part];
      if (version is num) versions[part] = version.toInt();
    }
    return versions.isEmpty ? null : versions;
  }

  /// 恢复数据库记录与 SharedPreferences（删除操作已在调用前完成）。
  ///
  /// 注意：偏好设置必须将要恢复的所有数据合并后一次性调用
  /// [_restorePreferencesFromJson]，因为该方法会清除选中类别的现有键。
  /// 分两次调用会导致先恢复的数据被后一次清除。
  static Future<void> _restoreRecordsAndPrefs(
    _RestoreMetadata metadata,
    BackupSelection selection,
  ) async {
    // 恢复数据库记录（使用已解析校验的数据）
    if (metadata.dbData != null) {
      await _restoreDatabaseFromJson(metadata.dbData!, selection: selection);
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
          recordTable: ManifestTables.imageRecords,
        );
      }
      if (selection.audio) {
        await ManifestDatabase.clearRecords(ManifestTables.audioRecords);
        await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.audioRecords,
        );
      }
      if (selection.videos) {
        await ManifestDatabase.clearRecords(ManifestTables.videoRecords);
        await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.videoRecords,
        );
      }
      if (selection.texts) {
        await ManifestDatabase.clearRecords(ManifestTables.textRecords);
        await ManifestDatabase.clearFolders(
          recordTable: ManifestTables.textRecords,
        );
      }
    }

    // 恢复 SharedPreferences（兼容 v1/v2 格式）
    final restoreChatPreferences =
        selection.chatRecordsAndAttachments && metadata.restoreChatPreferences;
    final preferenceSelection = BackupSelection(
      chatRecordsAndAttachments: restoreChatPreferences,
      settings: selection.settings,
      browserCookies: selection.browserCookies,
      includeMediaFiles: false,
    );
    if (metadata.isV1) {
      // v1 格式：preferences.json 包含所有键（聊天+设置合并）
      // 按 key 分类拆分：只恢复选中类别对应的键，未选中的类别保持原样
      if (restoreChatPreferences || selection.settings) {
        debugPrint(
          '[BackupService] _restoreRecordsAndPrefs: restoring v1 preferences',
        );
        final restorePrefs = <String, dynamic>{};
        if (metadata.v1Prefs != null) {
          for (final entry in metadata.v1Prefs!.entries) {
            final isChat = _isChatPrefKey(entry.key);
            if ((isChat && restoreChatPreferences) ||
                (!isChat && selection.settings)) {
              restorePrefs[entry.key] = entry.value;
            }
          }
        }
        await _restorePreferencesFromJson(
          restorePrefs,
          selection: preferenceSelection,
        );
      }
    } else {
      // v2 格式：chat_data.json + settings.json 分开，合并后一次性恢复
      final mergedPrefs = <String, dynamic>{};
      if (restoreChatPreferences) {
        debugPrint(
          '[BackupService] _restoreRecordsAndPrefs: merging chat_data.json',
        );
        if (metadata.chatPrefs != null) {
          mergedPrefs.addAll(metadata.chatPrefs!);
        }
      }
      if (selection.settings) {
        debugPrint(
          '[BackupService] _restoreRecordsAndPrefs: merging settings.json',
        );
        if (metadata.settingsPrefs != null) {
          mergedPrefs.addAll(metadata.settingsPrefs!);
        }
      }
      if (restoreChatPreferences || selection.settings) {
        await _restorePreferencesFromJson(
          mergedPrefs,
          selection: preferenceSelection,
        );
      }
    }
  }

  /// 将归档条目 [rawKey] 恢复为应用数据文件（含旧格式路径重映射与
  /// selection 过滤）。返回是否实际处理了该条目。
  ///
  /// 两个恢复路径共用此调度逻辑（内存版 [_restoreFromBytes] 与流式版
  /// [_restoreFromZipFile]），避免两套路径的映射规则漂移。
  ///
  /// [writeEntry] 负责把条目内容写出到 (subDir, fileName)。
  static Future<bool> _restoreArchiveEntry(
    String rawKey,
    BackupSelection selection,
    Future<void> Function(String subDir, String fileName) writeEntry,
  ) async {
    var key = rawKey;

    // ZIP 归档可能包含显式目录条目；它们不是数据文件，不能作为类别
    // 存在的依据，也不能尝试写成普通文件。
    if (key.endsWith('/') || key.endsWith(r'\')) return false;

    // 跳过元数据文件
    if (_restoreSkipFiles.contains(key)) return false;

    // 旧格式 binary: 去掉 files/ 前缀
    if (key.startsWith('files/')) {
      key = key.substring('files/'.length);
    }

    // Earlier Web backups stored edited attachments in temp_edited/;
    // current storage keeps them with the rest of the attachments.
    if (key.startsWith('temp_edited/')) {
      key = 'attachments/${p.basename(key)}';
    }

    // 旧格式 task: tasks/synthesis_tasks.json → synthesis/tasks.json
    if (key.startsWith('tasks/')) {
      key = key.substring('tasks/'.length);
      // synthesis_tasks.json → synthesis/tasks.json
      if (key == 'synthesis_tasks.json') key = 'synthesis/tasks.json';
      if (key == 'catcatch_tasks.json') key = 'catcatch/tasks.json';
    }

    // 兼容较早归档中存放在根目录的 Anki 数据库。
    if (key == 'collection.anki2') {
      if (!selection.ankiData) return false;
      await AnkiDatabase.closeOpenedInstance();
      await writeEntry('', key);
      return true;
    }

    // 匹配已知存储目录
    String? matchedDir;
    for (final dir in _restoreKnownDirs) {
      if (key.startsWith('$dir/')) {
        matchedDir = dir;
        break;
      }
    }
    if (matchedDir == null) return false;

    // 根据 selection 跳过不需要恢复的目录
    if (!_shouldRestoreDir(matchedDir, selection)) return false;

    final relativePath = key.substring(matchedDir.length + 1);

    // 安全：拒绝含 `..` 路径段或绝对/根路径的条目名（zip-slip 防护 ——
    // 备份文件是外部输入，`p.join` 会把绝对段当作路径重置，导致写出
    // 逃逸出应用数据目录；Windows 上反斜杠同样可被 p.join 识别为
    // 分隔符，故两种都检查）。盘符前缀（Windows 风格绝对路径）在
    // 任何平台上都不是合法的备份相对路径，一律跳过（不依赖
    // p.isAbsolute —— 它在 POSIX 上不识别盘符）。
    // 未知条目按"跳过"处理，与未知目录语义一致。
    if (!_isSafeRelativeArchivePath(relativePath)) {
      debugPrint('[BackupService] 跳过不安全路径条目: $rawKey');
      return false;
    }

    if (matchedDir == 'anki') {
      // 实际数据库位于应用数据目录根目录 collection.anki2
      //（备份归档内的路径为 anki/collection.anki2）。
      // 先关闭可能打开的数据库连接（Windows 上文件被占用时无法写入）。
      await AnkiDatabase.closeOpenedInstance();
      await writeEntry('', relativePath);
      return true;
    }

    if (matchedDir == 'synthesis' || matchedDir == 'catcatch') {
      if (relativePath == 'tasks.json') {
        await writeEntry(matchedDir, 'tasks.json');
      }
      return true;
    }

    // 普通二进制文件
    await writeEntry(matchedDir, relativePath);
    return true;
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
    final imageRecords = selection.pictures
        ? (data['image_records'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];
    final audioRecords = selection.audio
        ? (data['audio_records'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];
    final videoRecords = selection.videos
        ? (data['video_records'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];
    final textRecords = selection.texts
        ? (data['text_records'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];

    // Per-type folders (v2+ backups)
    final textFolders = selection.texts
        ? (data[ManifestTables.textFolders] as List<dynamic>?)
                ?.cast<String>() ??
            <String>[]
        : <String>[];
    final audioFolders = selection.audio
        ? (data[ManifestTables.audioFolders] as List<dynamic>?)
                ?.cast<String>() ??
            <String>[]
        : <String>[];
    final imageFolders = selection.pictures
        ? (data[ManifestTables.imageFolders] as List<dynamic>?)
                ?.cast<String>() ??
            <String>[]
        : <String>[];
    final videoFolders = selection.videos
        ? (data[ManifestTables.videoFolders] as List<dynamic>?)
                ?.cast<String>() ??
            <String>[]
        : <String>[];
    final usesLegacyFolders = (selection.texts && textFolders.isEmpty) ||
        (selection.audio && audioFolders.isEmpty) ||
        (selection.pictures && imageFolders.isEmpty) ||
        (selection.videos && videoFolders.isEmpty);
    final folders = usesLegacyFolders
        ? (data['folders'] as List<dynamic>?)?.cast<String>() ?? <String>[]
        : <String>[];

    debugPrint(
      '[BackupService] _restoreDatabaseFromJson: '
      'image(${imageRecords.length}) audio(${audioRecords.length}) '
      'video(${videoRecords.length}) text(${textRecords.length})',
    );

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
        recordTable: ManifestTables.textRecords,
      );
      for (final folder in dirs) {
        await ManifestDatabase.insertFolder(
          folder,
          recordTable: ManifestTables.textRecords,
        );
      }
    }
    if (selection.audio) {
      final dirs = audioFolders.isNotEmpty ? audioFolders : folders;
      await ManifestDatabase.clearFolders(
        recordTable: ManifestTables.audioRecords,
      );
      for (final folder in dirs) {
        await ManifestDatabase.insertFolder(
          folder,
          recordTable: ManifestTables.audioRecords,
        );
      }
    }
    if (selection.pictures) {
      final dirs = imageFolders.isNotEmpty ? imageFolders : folders;
      await ManifestDatabase.clearFolders(
        recordTable: ManifestTables.imageRecords,
      );
      for (final folder in dirs) {
        await ManifestDatabase.insertFolder(
          folder,
          recordTable: ManifestTables.imageRecords,
        );
      }
    }
    if (selection.videos) {
      final dirs = videoFolders.isNotEmpty ? videoFolders : folders;
      await ManifestDatabase.clearFolders(
        recordTable: ManifestTables.videoRecords,
      );
      for (final folder in dirs) {
        await ManifestDatabase.insertFolder(
          folder,
          recordTable: ManifestTables.videoRecords,
        );
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
    await AppLogService.info(
      'BackupService',
      '_restorePreferencesFromJson: restored ${backupPrefs.length} keys, removed ${keysToRemove.length}',
    );
  }

  // ================================================================
  // UI 便捷方法（双平台）
  // ================================================================

  static Future<String> _nextBackupFileName({String? directoryPath}) async {
    final existingNames = kIsWeb || directoryPath != null
        ? <String>{}
        : (await BackupLocationManager.listBackupFiles()).toSet();
    var timestampSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final lastTimestamp = _lastBackupFileTimestampSeconds;
    if (lastTimestamp != null && timestampSeconds <= lastTimestamp) {
      timestampSeconds = lastTimestamp + 1;
    }

    String fileNameFor(int seconds) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(seconds * 1000)
          .toIso8601String()
          .split('.')
          .first
          .replaceAll(':', '-');
      return 'backup_$timestamp.zip';
    }

    var fileName = fileNameFor(timestampSeconds);
    while (existingNames.contains(fileName) ||
        (directoryPath != null &&
            await File(p.join(directoryPath, fileName)).exists())) {
      timestampSeconds++;
      fileName = fileNameFor(timestampSeconds);
    }
    _lastBackupFileTimestampSeconds = timestampSeconds;
    return fileName;
  }

  /// 导出备份：弹出保存文件对话框，创建 zip。
  ///
  /// [onProgress] 可选回调，报告备份构建进度（0.0 ~ 1.0）。
  /// [selection] 控制哪些数据类别包含在备份中。默认全量。
  ///
  /// 内存策略（与旧自动备份一致，避免大备份 OOM）：
  /// - Web：没有 dart:io，只能整体构建后在浏览器下载（内存构建）。
  /// - Android/iOS：流式构建到系统临时文件（64KB 分块、后台 isolate），
  ///   再写入备份位置 —— Android 经 SAF 分块上传（整包过 Binder 会抛
  ///   TransactionTooLargeException），iOS/桌面 dart:io 直接复制。
  /// - 桌面：先让用户选择保存位置（`saveFile` 不传 bytes 只返回路径），
  ///   再流式写入该路径。
  static Future<void> exportBackup(
    BuildContext context, {
    void Function(double progress)? onProgress,
    BackupSelection selection = BackupSelection.all,
  }) async {
    await AppLogService.info('BackupService', 'exportBackup: start');
    try {
      final defaultName = await _nextBackupFileName();

      String? savedLocation;
      if (kIsWeb) {
        // Web：内存构建 + 浏览器下载（Web 无法流式写本地文件）
        final bytes = await _buildBackupBytes(
          onProgress: onProgress,
          selection: selection,
        );
        savedLocation = await FilePicker.saveFile(
          fileName: defaultName,
          bytes: bytes,
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Android/iOS：流式构建到系统临时文件，再写入备份位置
        final tempPath = p.join(Directory.systemTemp.path, defaultName);
        try {
          await createBackup(
            outputPath: tempPath,
            onProgress: onProgress,
            selection: selection,
          );
          await BackupLocationManager.writeBackupFileFromPath(
            defaultName,
            tempPath,
          );
        } finally {
          try {
            await File(tempPath).delete();
          } catch (_) {}
        }
        final displayPath = await BackupLocationManager.getDisplayPath();
        savedLocation =
            displayPath.isEmpty ? defaultName : '$displayPath/$defaultName';
      } else {
        // 桌面：先选保存位置（不传 bytes → 只返回路径，不写文件），
        // 再流式写入 —— 峰值内存不随备份体积增长。
        final outputPath = await FilePicker.saveFile(
          fileName: defaultName,
          initialDirectory: SystemPickDirectories.documents(),
        );
        if (outputPath == null) {
          // 用户取消保存
          await AppLogService.info('BackupService', 'exportBackup: 用户取消');
          return;
        }
        var destinationPath = outputPath;
        if (await File(destinationPath).exists()) {
          final uniqueName = await _nextBackupFileName(
            directoryPath: p.dirname(outputPath),
          );
          destinationPath = p.join(p.dirname(outputPath), uniqueName);
        }
        try {
          await createBackup(
            outputPath: destinationPath,
            onProgress: onProgress,
            selection: selection,
          );
        } catch (e) {
          // 构建失败时清理用户位置留下的半成品 zip
          try {
            final partial = File(destinationPath);
            if (await partial.exists()) {
              await partial.delete();
            }
          } catch (_) {}
          rethrow;
        }
        savedLocation = destinationPath;
      }

      if (savedLocation != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('备份已保存到: $savedLocation')));
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
    void Function(List<String> skippedCategories)? onSkippedCategories,
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
      final List<String> skippedCategories;

      if (bytes != null) {
        skippedCategories = await _restoreFromBytes(
          bytes,
          selection: selection,
          skipMissingCategories: true,
        );
      } else if (file.path != null) {
        skippedCategories = await _restoreFromZipFile(
          file.path!,
          selection: selection,
          skipMissingCategories: true,
        );
      } else {
        return false;
      }

      onSkippedCategories?.call(skippedCategories);

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
  /// - 浏览器Cookies：清除内置浏览器Cookies并删除 browser_cookies.json
  ///
  /// 与选择性恢复的语义一致：选中的类别被清空，未选中的保持原样。
  /// 若有文件删除失败（如 Windows 上文件被占用），抛出异常，由调用方提示。
  static Future<void> clearSelectedData(
    BackupSelection selection, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);
    await _yieldToEventLoop();
    final taskFlowAttachmentKeys = await _taskFlowAttachmentsToPreserve(
      selection,
    );

    // Clear live and persisted Cookies together so browser-close persistence
    // cannot recreate the snapshot after the selected data is deleted.
    var cookieDeleteFailed = false;
    if (selection.browserCookies) {
      cookieDeleteFailed =
          await BrowserCookieService.runExclusiveRetentionOperation(() async {
        await _clearLiveCookiesForRestore(selection);
        final deleted = await _deleteFile('', 'browser_cookies.json');
        await BrowserCookieService.clearBackupRestorePending();
        return !deleted;
      });
    }

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
      await AppLogService.info(
        'BackupService',
        'clearSelectedData: removed ${keysToRemove.length} preference keys',
      );
    }

    // 2. 选中类别的文件（附件目录整清，孤儿文件一并删除）
    final otherDeleteFailed = await _deleteSelectedFiles(
      selection,
      taskFlowAttachmentKeys: taskFlowAttachmentKeys,
      preserveBrowserCookieSnapshot: selection.browserCookies,
    );
    final deleteFailed = cookieDeleteFailed || otherDeleteFailed;

    // 3. 媒体数据库记录 + 文件夹表（文件已由 _deleteSelectedFiles 删除）
    if (selection.pictures) {
      await ManifestDatabase.clearRecords(ManifestTables.imageRecords);
      await ManifestDatabase.clearFolders(
        recordTable: ManifestTables.imageRecords,
      );
    }
    if (selection.audio) {
      await ManifestDatabase.clearRecords(ManifestTables.audioRecords);
      await ManifestDatabase.clearFolders(
        recordTable: ManifestTables.audioRecords,
      );
    }
    if (selection.videos) {
      await ManifestDatabase.clearRecords(ManifestTables.videoRecords);
      await ManifestDatabase.clearFolders(
        recordTable: ManifestTables.videoRecords,
      );
    }
    if (selection.texts) {
      await ManifestDatabase.clearRecords(ManifestTables.textRecords);
      await ManifestDatabase.clearFolders(
        recordTable: ManifestTables.textRecords,
      );
    }
    onProgress?.call(0.6);
    await _yieldToEventLoop();

    if (deleteFailed) {
      throw Exception('部分数据文件删除失败，请重启应用后重试');
    }

    onProgress?.call(1.0);
  }

  /// Returns attachment-store keys referenced by task-flow files that will
  /// remain in place, so clearing chat attachments does not break them. A null
  /// result means the references could not be read safely.
  static Future<Set<String>?> _collectTaskFlowAttachmentKeys(
    Set<String> taskFlowFilesToPreserve,
  ) async {
    final preservedKeys = <String>{};
    try {
      final isWebStore = kIsWeb || WebFileStore.isTestMode;
      final appDir = isWebStore ? null : await AppStorage.directory;
      final attachmentDir =
          appDir == null ? null : p.normalize(p.join(appDir, 'attachments'));

      void preserveReference(String reference) {
        final slashPath = reference.replaceAll('\\', '/');
        final webPath = p.posix.normalize(slashPath);
        if (p.posix.isWithin('attachments', webPath)) {
          preservedKeys.add(webPath);
          return;
        }
        if (p.posix.isWithin('temp_edited', webPath)) {
          preservedKeys.add(webPath);
          preservedKeys.add(
            p.posix.join('attachments', p.posix.basename(webPath)),
          );
          return;
        }
        if (isWebStore) return;

        final normalized = p.normalize(reference);
        String? relativePath;
        if (p.isAbsolute(normalized) &&
            p.isWithin(attachmentDir!, normalized)) {
          relativePath = p.relative(normalized, from: attachmentDir);
        } else if (!p.isAbsolute(normalized) &&
            normalized.split(p.separator).first == 'attachments') {
          relativePath = normalized.split(p.separator).skip(1).join('/');
        }
        if (relativePath == null || relativePath.isEmpty) return;
        final normalizedRelative = p.posix.normalize(
          relativePath.split(p.separator).join('/'),
        );
        if (normalizedRelative == '..' ||
            normalizedRelative.startsWith('../')) {
          return;
        }
        preservedKeys.add(p.posix.join('attachments', normalizedRelative));
      }

      void collectReferences(Object? value) {
        if (value is String) {
          preserveReference(value);
        } else if (value is Map) {
          for (final child in value.values) {
            collectReferences(child);
          }
        } else if (value is Iterable) {
          for (final child in value) {
            collectReferences(child);
          }
        }
      }

      for (final taskFlowFile in taskFlowFilesToPreserve) {
        final fileName = p.posix.basename(taskFlowFile);
        Uint8List? data;
        if (isWebStore) {
          if (!await WebFileStore.exists(taskFlowFile)) continue;
          data = await WebFileStore.read(taskFlowFile);
        } else {
          final file = File(p.join(appDir!, 'task_flows', fileName));
          if (!await file.exists()) continue;
          data = await file.readAsBytes();
        }
        if (data == null) return null;
        collectReferences(jsonDecode(utf8.decode(data)));
      }
      return preservedKeys;
    } catch (e) {
      debugPrint('读取任务流附件引用失败，保留附件以避免误删: $e');
      return null;
    }
  }

  static Future<bool> _deleteAttachmentsExceptTaskFiles(
    Set<String> preservedKeys,
  ) async {
    try {
      if (kIsWeb || WebFileStore.isTestMode) {
        await WebFileStore.deleteByPrefixExcept('attachments/', preservedKeys);
        await WebFileStore.deleteByPrefixExcept('temp_edited/', preservedKeys);
        return true;
      }

      final appDir = await AppStorage.directory;
      final attachmentDir = Directory(p.join(appDir, 'attachments'));
      if (!await attachmentDir.exists()) return true;
      await for (final entity in attachmentDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relativePath = p.relative(entity.path, from: attachmentDir.path);
        final key = p.posix.join(
          'attachments',
          relativePath.split(p.separator).join('/'),
        );
        if (!preservedKeys.contains(key)) await entity.delete();
      }
      return true;
    } catch (e) {
      debugPrint('删除未被任务流引用的附件失败: $e');
      return false;
    }
  }

  /// 删除 [selection] 中选中类别的现有文件。
  ///
  /// 恢复"勾选即清空"与清除功能共用此方法。
  /// 返回是否有删除失败（调用方决定如何处理）：
  /// - 聊天附件：清理附件目录中未被未选中任务流引用的文件
  /// - 图片/音频/视频/文本：按当前数据库记录逐文件删除（Web/测试模式），
  ///   原生模式再整目录删除（清理无记录的孤儿文件）
  /// - 任务：删除 synthesis/tasks.json 和 catcatch/tasks.json
  /// - Anki：先关闭可能打开的数据库连接，再删除 collection.anki2
  ///   （应用数据目录根路径 + 历史恢复写入的 anki/ 残留）
  /// - 浏览器Cookies：默认删除 browser_cookies.json；恢复时可暂时保留
  static Future<bool> _deleteSelectedFiles(
    BackupSelection selection, {
    required Set<String> taskFlowAttachmentKeys,
    bool preserveBrowserCookieSnapshot = false,
    Set<String>? taskFilesToReplace,
  }) async {
    var deleteFailed = false;

    // 聊天附件与任务流输入共用 attachments/。保留未被本次替换的
    // flows.json / executions.json 所引用的文件，只清除其余聊天附件。
    // （includeMediaFiles=false 的结构化快照恢复不动附件文件）
    if (selection.chatRecordsAndAttachments && selection.includeMediaFiles) {
      if (taskFlowAttachmentKeys.isEmpty) {
        if (kIsWeb || WebFileStore.isTestMode) {
          try {
            await WebFileStore.deleteByPrefix('attachments/');
            await WebFileStore.deleteByPrefix('temp_edited/');
          } catch (e) {
            debugPrint('删除附件文件失败: $e');
            deleteFailed = true;
          }
        } else if (!await _deleteDirectory('attachments')) {
          deleteFailed = true;
        }
      } else if (!await _deleteAttachmentsExceptTaskFiles(
        taskFlowAttachmentKeys,
      )) {
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
      final taskFiles = taskFilesToReplace ??
          const {
            'synthesis/tasks.json',
            'catcatch/tasks.json',
            'background/tasks.json',
            'task_flows/flows.json',
            'task_flows/executions.json',
          };
      if (taskFiles.contains('synthesis/tasks.json') &&
          !await _deleteFile('synthesis', 'tasks.json')) {
        deleteFailed = true;
      }
      if (taskFiles.contains('catcatch/tasks.json') &&
          !await _deleteFile('catcatch', 'tasks.json')) {
        deleteFailed = true;
      }
      if (taskFiles.contains('background/tasks.json') &&
          !await _deleteFile('background', 'tasks.json')) {
        deleteFailed = true;
      }
      if (taskFiles.contains('task_flows/flows.json') &&
          !await _deleteFile('task_flows', 'flows.json')) {
        deleteFailed = true;
      }
      if (taskFiles.contains('task_flows/executions.json') &&
          !await _deleteFile('task_flows', 'executions.json')) {
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
      if (!preserveBrowserCookieSnapshot) {
        if (!await _deleteFile('', 'browser_cookies.json')) {
          deleteFailed = true;
        }
        await BrowserCookieService.clearBackupRestorePending();
      }
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
        selection: selection,
      );

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
    bool skipMissingCategories = false,
  }) async {
    await _restoreFromBytes(
      bytes,
      onProgress: onProgress,
      selection: selection,
      skipMissingCategories: skipMissingCategories,
    );
  }

  /// 公开 [_restoreDatabaseFromJson] 供测试使用。
  @visibleForTesting
  static Future<void> restoreDatabaseFromJsonForTest(
    String json, {
    BackupSelection selection = BackupSelection.all,
  }) =>
      _restoreDatabaseFromJson(
        jsonDecode(json) as Map<String, dynamic>,
        selection: selection,
      );
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
      final file = File(sourcePath);
      if (!file.existsSync()) {
        debugPrint('[BackupService] skipping missing backup file: $sourcePath');
        checkCancelled();
        continue;
      }
      final input = _FileInputStream(sourcePath);
      final af = ArchiveFile.stream(archiveName, input);
      af.compression = CompressionType.none;
      encoder.add(af);
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

// ====================================================================
// 流式恢复 — ZIP 中央目录解析 + 条目分块解压落盘
// ====================================================================

/// 恢复时跳过/映射的归档条目集合（内存版与流式版恢复共用）。
const Set<String> _restoreSkipFiles = {
  'manifest.json',
  'stroom_manifest.json',
  'database/manifest_data.json',
  'preferences.json',
  'chat_data.json',
  'settings.json',
  'browser_cookies.json',
};

/// 恢复时识别的存储目录（兼容新旧两种路径格式）。
const List<String> _restoreKnownDirs = [
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

/// 根据 selection 决定哪些目录需要恢复。
///
/// v1 格式：attachments 由旧的 conversations 标志控制（因为 v1 的
/// conversations 包含了设置+聊天记录，不包含附件），但为了兼容，
/// v1 导入时 attachments 由 chatRecordsAndAttachments 控制。
bool _shouldRestoreDir(String dir, BackupSelection selection) {
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
      return selection.chatRecordsAndAttachments && selection.includeMediaFiles;
    case 'anki':
      return selection.ankiData;
    default:
      return false;
  }
}

/// 备份元数据校验结果（[_restoreFromBytes] / [_restoreFromZipFile] 共用）。
class _RestoreMetadata {
  final bool isV1;
  final bool restoreChatPreferences;
  final Map<String, dynamic>? dbData;
  final Map<String, dynamic>? v1Prefs;
  final Map<String, dynamic>? chatPrefs;
  final Map<String, dynamic>? settingsPrefs;
  final BackupSelection restoreSelection;
  final Set<String> taskFilesToReplace;
  final List<String> skippedLabels;
  final Map<String, int>? dataPartVersions;
  final Uint8List? browserCookiesData;

  const _RestoreMetadata({
    required this.isV1,
    required this.restoreChatPreferences,
    required this.restoreSelection,
    required this.taskFilesToReplace,
    required this.skippedLabels,
    required this.dataPartVersions,
    this.browserCookiesData,
    this.dbData,
    this.v1Prefs,
    this.chatPrefs,
    this.settingsPrefs,
  });
}

/// ZIP 中央目录条目信息（流式恢复用）。
class _ZipEntryInfo {
  final String name;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int crc32;
  final int localHeaderOffset;

  const _ZipEntryInfo({
    required this.name,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.crc32,
    required this.localHeaderOffset,
  });
}

/// 流式 ZIP 读取器：只解析中央目录（文件末尾小块），条目内容按
/// 64KB 分块从磁盘读取 —— store 直接复制、deflate 流式解压，
/// 峰值内存 O(块大小)，不随备份体积增长。
///
/// 与 archive 包的 [ZipDecoder] 相对：decodeStream 会把每个条目的
/// 压缩数据急切读进内存（zip_file.dart: `_rawContent = readBytes(...)`），
/// 大备份（数百 MB 视频）在手动导入时必然 OOM。
class _ZipStreamReader {
  static const int kChunkSize = 65536;

  /// 元数据文件（manifest / 数据库清单 / 偏好设置）的合理尺寸上限；
  /// 超过即视为损坏，防止恶意/损坏条目声明超大尺寸拖垮内存。
  static const int _maxMetaFileBytes = 64 * 1024 * 1024;

  static const int _localHeaderSignature = 0x04034b50;
  static const int _centralDirSignature = 0x02014b50;
  static const int _zip64EocdLocatorSignature = 0x07064b50;
  static const int _zip64EocdSignature = 0x06064b50;
  static const int _zip64ExtraId = 0x0001;

  /// 条目数上限（防止损坏文件声称天文数字的条目导致空转）。
  static const int _maxEntryCount = 1000000;

  final RandomAccessFile _file;
  final List<_ZipEntryInfo> _entries;
  final Map<String, _ZipEntryInfo> _byName;

  _ZipStreamReader._fromFile(this._file, this._entries)
      : _byName = {for (final e in _entries) e.name: e};

  /// 解析 [path] 指向的 ZIP 文件。结构损坏时抛 [FormatException]
  /// （由调用方包装为 [BackupValidationException]）。
  factory _ZipStreamReader(String path) {
    final file = File(path).openSync();
    try {
      return _ZipStreamReader._fromFile(file, _readCentralDirectory(file));
    } catch (_) {
      file.closeSync();
      rethrow;
    }
  }

  List<_ZipEntryInfo> get entries => _entries;

  void close() => _file.closeSync();

  /// 读取单个条目内容（仅限小型元数据文件）。
  ///
  /// 实际解压字节数超出 [_maxMetaFileBytes] 即抛 [_RestoreEntryCorruptException]
  /// （防 zip 炸弹：声明的尺寸可以撒谎，实际输出必须受控）。
  Uint8List? readMetaFile(String name) {
    final entry = _byName[name];
    if (entry == null) return null;
    if (entry.uncompressedSize > _maxMetaFileBytes) {
      throw const _RestoreEntryCorruptException('元数据文件尺寸异常');
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    extractEntry(entry, (chunk) {
      total += chunk.length;
      if (total > _maxMetaFileBytes) {
        throw const _RestoreEntryCorruptException('元数据文件解压后超出安全上限');
      }
      builder.add(chunk);
    });
    return builder.takeBytes();
  }

  /// 把条目内容分块推送给 [onChunk]（同步执行，块内不持有状态）。
  ///
  /// 条目损坏（本地头签名错误、数据截断、解压失败、不支持的压缩方式、
  /// 解压尺寸与声明不符）时抛 [_RestoreEntryCorruptException]：
  /// - 校验期调用方（[_restoreFromZipFile] 元数据读取和条目预检）包装为
  ///   [BackupValidationException]（未删除任何数据）；
  /// - 删除之后的恢复循环直接传播（恢复可能已部分完成）。
  void extractEntry(
    _ZipEntryInfo entry,
    void Function(Uint8List chunk) onChunk,
  ) {
    // 定位条目数据区：本地头（30 字节固定）+ 文件名 + extra 之后。
    // 条目在备份中的存储方式由中央目录的尺寸字段决定（archive 包的
    // 写入器不会使用 data descriptor，尺寸总是已知）。
    try {
      _file.setPositionSync(entry.localHeaderOffset);
      final localHeader = _readExact(_file, 30);
      if (_le32(localHeader, 0) != _localHeaderSignature) {
        throw const _RestoreEntryCorruptException('本地头损坏');
      }
      final nameLen = _le16(localHeader, 26);
      final extraLen = _le16(localHeader, 28);
      final dataOffset = entry.localHeaderOffset + 30 + nameLen + extraLen;
      _file.setPositionSync(dataOffset);

      var remaining = entry.compressedSize;
      final checksum = _ZipCrc32();
      if (entry.compressionMethod == 0) {
        // store：直接分块复制，不经内存缓冲。
        // store 条目压缩尺寸必须等于解压尺寸 —— 计数核对，防止
        // 声明的 uncompressedSize 与实际数据不符时静默恢复半个文件。
        var written = 0;
        while (remaining > 0) {
          final n = remaining < kChunkSize ? remaining : kChunkSize;
          final chunk = _readExact(_file, n);
          checksum.add(chunk);
          onChunk(chunk);
          written += chunk.length;
          remaining -= chunk.length;
        }
        if (written != entry.uncompressedSize) {
          throw _RestoreEntryCorruptException(
            '条目 ${entry.name} 尺寸不符 '
            '(实际 $written / 声明 ${entry.uncompressedSize})',
          );
        }
        _verifyChecksum(entry, checksum.value);
      } else if (entry.compressionMethod == 8) {
        // deflate：raw inflate 流式解压（dart:io zlib 分块转换）。
        // dart:io 对截断的 deflate 流不报错，只输出已解压的部分 ——
        // 必须按中央目录声明的 uncompressedSize 核对实际输出字节数，
        // 否则损坏的备份会静默恢复出截断的文件。
        var outputBytes = 0;
        final decoder = ZLibDecoder(raw: true);
        final conversion = decoder.startChunkedConversion(
          _ChunkSink((chunk) {
            outputBytes += chunk.length;
            checksum.add(chunk);
            onChunk(chunk);
          }),
        );
        try {
          while (remaining > 0) {
            final n = remaining < kChunkSize ? remaining : kChunkSize;
            final chunk = _readExact(_file, n);
            conversion.add(chunk);
            remaining -= chunk.length;
          }
          // close 也可能在流末尾报错（截断/损坏），必须在 try 内
          conversion.close();
        } catch (e) {
          debugPrint('[BackupService] 条目 ${entry.name} 解压失败: $e');
          throw _RestoreEntryCorruptException('条目 ${entry.name} 解压失败 ($e)');
        }
        if (outputBytes != entry.uncompressedSize) {
          throw _RestoreEntryCorruptException(
            '条目 ${entry.name} 解压尺寸不符 '
            '(实际 $outputBytes / 声明 ${entry.uncompressedSize})',
          );
        }
        _verifyChecksum(entry, checksum.value);
      } else {
        throw _RestoreEntryCorruptException(
          '条目 ${entry.name} 使用不支持的'
          '压缩方式 (${entry.compressionMethod})',
        );
      }
    } on FormatException catch (e) {
      // _readExact 的截断/结构错误：统一为条目损坏
      throw _RestoreEntryCorruptException('条目 ${entry.name} 数据不完整 ($e)');
    }
  }

  static void _verifyChecksum(_ZipEntryInfo entry, int actual) {
    if (actual != entry.crc32) {
      throw _RestoreEntryCorruptException('条目 ${entry.name} CRC32 校验失败');
    }
  }

  // ---- 中央目录解析 ----

  static List<_ZipEntryInfo> _readCentralDirectory(RandomAccessFile file) {
    final fileLength = file.lengthSync();
    if (fileLength < 22) {
      throw const FormatException('文件过小，不是有效的 ZIP 归档');
    }

    // 1. 定位 EOCD：文件末尾最多 64KB+22 字节内反向搜索签名。
    //    注释可长达 65535 字节，故搜索窗口 = 64KB + EOCD 固定长度。
    final tailLen = fileLength < kChunkSize + 22 ? fileLength : kChunkSize + 22;
    file.setPositionSync(fileLength - tailLen);
    final tail = file.readSync(tailLen);

    int? eocdRelOffset;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (tail[i] == 0x50 &&
          tail[i + 1] == 0x4b &&
          tail[i + 2] == 0x05 &&
          tail[i + 3] == 0x06) {
        final commentLen = _le16(tail, i + 20);
        // EOCD 记录必须正好延伸到文件末尾
        if (i + 22 + commentLen == tail.length) {
          eocdRelOffset = i;
          break;
        }
      }
    }
    if (eocdRelOffset == null) {
      throw const FormatException('找不到 ZIP 中央目录（EOCD）');
    }
    final eocdOffset = (fileLength - tailLen) + eocdRelOffset;

    var entryCount = _le16(tail, eocdRelOffset + 10);
    var cdSize = _le32(tail, eocdRelOffset + 12);
    var cdOffset = _le32(tail, eocdRelOffset + 16);

    // 2. ZIP64：EOCD 任一字段满值时读取 zip64 EOCD（位于 EOCD 前
    //    20 字节的定位器指向它）。
    //    注意：entryCount == 0xFFFF 同时是"恰好 65535 个条目"的合法
    //    编码 —— 定位器签名不匹配时回退到 32 位值，而不是报错。
    if (entryCount == 0xFFFF ||
        cdSize == 0xFFFFFFFF ||
        cdOffset == 0xFFFFFFFF) {
      final locatorPos = eocdOffset - 20;
      if (locatorPos >= 0) {
        file.setPositionSync(locatorPos);
        final locator = _readExact(file, 20);
        if (_le32(locator, 0) == _zip64EocdLocatorSignature) {
          final zip64EocdPos = _le64(locator, 8);
          if (zip64EocdPos < 0 || zip64EocdPos >= fileLength) {
            throw const FormatException('ZIP64 EOCD 偏移异常');
          }
          file.setPositionSync(zip64EocdPos);
          final zip64Eocd = _readExact(file, 56);
          if (_le32(zip64Eocd, 0) != _zip64EocdSignature) {
            throw const FormatException('ZIP64 EOCD 签名错误');
          }
          entryCount = _le64(zip64Eocd, 32);
          cdSize = _le64(zip64Eocd, 40);
          cdOffset = _le64(zip64Eocd, 48);
        }
      }
    }
    // 64 位值不允许为负（≥2^63 的尺寸/偏移不是合法 ZIP 数据）
    if (entryCount < 0 || cdSize < 0 || cdOffset < 0) {
      throw const FormatException('ZIP64 字段溢出（负数）');
    }
    if (entryCount > _maxEntryCount) {
      throw FormatException('ZIP 条目数异常: $entryCount');
    }
    // 中央目录必须位于文件内（APPNOTE 4.3.16 边界校验）
    if (cdOffset > eocdOffset || cdOffset + cdSize > eocdOffset) {
      throw const FormatException('中央目录超出文件范围');
    }

    // 3. 中央目录条目（固定 46 字节头 + 文件名 + extra + 注释）。
    file.setPositionSync(cdOffset);
    final entries = <_ZipEntryInfo>[];
    for (var i = 0; i < entryCount; i++) {
      final header = _readExact(file, 46);
      if (_le32(header, 0) != _centralDirSignature) {
        throw FormatException('中央目录条目 $i 签名错误');
      }
      final method = _le16(header, 10);
      final crc32 = _le32(header, 16);
      var compSize = _le32(header, 20);
      var uncompSize = _le32(header, 24);
      final nameLen = _le16(header, 28);
      final extraLen = _le16(header, 30);
      final commentLen = _le16(header, 32);
      var localOffset = _le32(header, 42);

      final nameBytes = _readExact(file, nameLen);
      final extraBytes = _readExact(file, extraLen);
      _readExact(file, commentLen); // 丢弃注释

      // ZIP64 extra（id 0x0001）：值按 [uncompressed(8), compressed(8),
      // offset(8), disk(4)] 顺序出现，只包含被置满值的字段。
      if (compSize == 0xFFFFFFFF ||
          uncompSize == 0xFFFFFFFF ||
          localOffset == 0xFFFFFFFF) {
        final zip64 = _parseZip64Extra(
          extraBytes,
          needUncompressed: uncompSize == 0xFFFFFFFF,
          needCompressed: compSize == 0xFFFFFFFF,
          needOffset: localOffset == 0xFFFFFFFF,
        );
        if (uncompSize == 0xFFFFFFFF) uncompSize = zip64.$1!;
        if (compSize == 0xFFFFFFFF) compSize = zip64.$2!;
        if (localOffset == 0xFFFFFFFF) localOffset = zip64.$3!;
      }
      // 64 位值不允许为负（≥2^63 不是合法尺寸/偏移）；负的压缩尺寸
      // 会让分块循环被跳过、静默恢复出空文件。
      if (compSize < 0 || uncompSize < 0 || localOffset < 0) {
        throw FormatException('条目 $i ZIP64 字段溢出（负数）');
      }

      entries.add(
        _ZipEntryInfo(
          name: utf8.decode(nameBytes, allowMalformed: true),
          compressionMethod: method,
          compressedSize: compSize,
          uncompressedSize: uncompSize,
          crc32: crc32,
          localHeaderOffset: localOffset,
        ),
      );
    }
    return entries;
  }

  /// 解析条目 extra 字段中的 ZIP64 数据。
  ///
  /// 每个字段读取前做边界检查（extra 声明的尺寸可能小于实际需要的
  /// 字段），字段值不允许为负（≥2^63 不是合法尺寸）。
  static (int?, int?, int?) _parseZip64Extra(
    Uint8List extra, {
    required bool needUncompressed,
    required bool needCompressed,
    required bool needOffset,
  }) {
    var i = 0;
    while (i + 4 <= extra.length) {
      final id = _le16(extra, i);
      final size = _le16(extra, i + 2);
      final dataStart = i + 4;
      if (id == _zip64ExtraId) {
        var p = dataStart;
        int? uncompressed;
        int? compressed;
        int? offset;
        if (needUncompressed) {
          // 同时核对声明的字段尺寸与实际缓冲区边界（声明可以撒谎）
          if (p + 8 > extra.length || p + 8 > dataStart + size) {
            throw const FormatException('ZIP64 extra 字段截断');
          }
          uncompressed = _le64(extra, p);
          p += 8;
        }
        if (needCompressed) {
          if (p + 8 > extra.length || p + 8 > dataStart + size) {
            throw const FormatException('ZIP64 extra 字段截断');
          }
          compressed = _le64(extra, p);
          p += 8;
        }
        if (needOffset) {
          if (p + 8 > extra.length || p + 8 > dataStart + size) {
            throw const FormatException('ZIP64 extra 字段截断');
          }
          offset = _le64(extra, p);
          p += 8;
        }
        if ((uncompressed != null && uncompressed < 0) ||
            (compressed != null && compressed < 0) ||
            (offset != null && offset < 0)) {
          throw const FormatException('ZIP64 extra 字段溢出（负数）');
        }
        return (uncompressed, compressed, offset);
      }
      i = dataStart + size;
    }
    throw const FormatException('缺少 ZIP64 extra 字段');
  }

  /// 精确读取 [count] 字节；文件提前结束时抛 [FormatException]
  /// （防止损坏条目声明的尺寸与实际数据不符时无限循环）。
  static Uint8List _readExact(RandomAccessFile file, int count) {
    final builder = BytesBuilder(copy: false);
    var remaining = count;
    while (remaining > 0) {
      final chunk = file.readSync(remaining);
      if (chunk.isEmpty) {
        throw const FormatException('文件提前结束（ZIP 结构不完整）');
      }
      builder.add(chunk);
      remaining -= chunk.length;
    }
    return builder.takeBytes();
  }

  // ---- 小端读取 ----

  static int _le16(Uint8List b, int offset) => b[offset] | (b[offset + 1] << 8);

  static int _le32(Uint8List b, int offset) =>
      b[offset] |
      (b[offset + 1] << 8) |
      (b[offset + 2] << 16) |
      (b[offset + 3] << 24);

  static int _le64(Uint8List b, int offset) {
    final lo = _le32(b, offset);
    final hi = _le32(b, offset + 4);
    return (hi << 32) | lo;
  }
}

/// Incremental CRC32 calculation for validating streamed ZIP entries.
class _ZipCrc32 {
  static final List<int> _table = List<int>.generate(256, (index) {
    var value = index;
    for (var bit = 0; bit < 8; bit++) {
      value = (value & 1) != 0 ? (value >> 1) ^ 0xedb88320 : value >> 1;
    }
    return value;
  }, growable: false);

  var _value = 0xffffffff;

  void add(List<int> bytes) {
    for (final byte in bytes) {
      _value = _table[(_value ^ byte) & 0xff] ^ (_value >> 8);
    }
  }

  int get value => (_value ^ 0xffffffff) & 0xffffffff;
}

/// 把 deflate 解压输出块转发给 [onChunk]。
class _ChunkSink implements ByteConversionSink {
  final void Function(Uint8List chunk) onChunk;

  _ChunkSink(this.onChunk);

  @override
  void add(List<int> chunk) => onChunk(Uint8List.fromList(chunk));

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) =>
      onChunk(Uint8List.fromList(chunk.sublist(start, end)));

  @override
  void close() {}
}
