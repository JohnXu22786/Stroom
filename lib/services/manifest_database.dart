import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/web_file_store.dart';
import 'app_log_service.dart';
import 'data_integrity_json_parser.dart' as json_parser;
import 'manifest_database_shared.dart';
import 'startup_data_validation_unavailable.dart';
import 'startup_preferences.dart';
export 'manifest_database_shared.dart';

// ====================================================================
// ManifestDatabase — SQLite 存储服务
// ====================================================================
//
// 单例模式，管理 manifest 元数据（图片记录、音频记录、文件夹路径）。
// - Native（Android / iOS / macOS / Linux / Windows）：使用 sqflite
// - Web：使用 WebFileStore（IndexedDB）存储 JSON 数据，规避 SharedPreferences 的 2MB 上限
// ====================================================================

class ManifestDatabase {
  ManifestDatabase._(); // 私有构造，禁止实例化

  static Database? _database;

  /// Test mode: use JSON/in-memory storage instead of SQLite.
  /// Enables unit testing without sqflite native bindings.
  static bool _useInMemoryStorage = false;

  /// Injects a folder persistence failure in manifest operation tests.
  @visibleForTesting
  static void Function(String path)? beforeFolderInsertForTesting;

  /// Signals the start of a JSON record registration in tests.
  @visibleForTesting
  static void Function()? beforeJsonRecordRegistrationForTesting;

  /// Runs immediately before JSON manifest data is written in tests.
  @visibleForTesting
  static Future<void> Function()? beforeWebDataSaveForTesting;

  /// Enable test mode — all operations use in-memory JSON storage
  /// (same code path as web), avoiding sqflite native dependencies.
  /// Also switches [WebFileStore] to in-memory mode so no IndexedDB
  /// dependency is needed in tests.
  static void enableTestMode() {
    _useInMemoryStorage = true;
    _webData = null;
    WebFileStore.enableTestMode();
  }

  /// Whether to use JSON-based storage (web or test mode)
  static bool get _useJsonStore => kIsWeb || _useInMemoryStorage;

  /// Web 端数据缓存（全量 JSON）
  static Map<String, dynamic>? _webData;

  static Future<void>? _jsonRecordRegistrationQueue;

  /// Web 端数据在 WebFileStore 中的 key
  static const String _webStoreKey = 'manifest_database_data';

  // ==================================================================
  // 数据库初始化
  // ==================================================================

  /// 获取数据库实例（Native 端）
  static Future<Database> get database async {
    if (_useJsonStore) {
      throw StateError('database getter should not be called in web/test mode');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'stroom_manifest.db');
    final db = await openDatabase(
      dbPath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS image_records (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            hash TEXT NOT NULL,
            format TEXT NOT NULL DEFAULT 'jpg',
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL DEFAULT 0,
            size INTEGER NOT NULL DEFAULT 0,
            folder TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS audio_records (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            hash TEXT NOT NULL,
            format TEXT NOT NULL DEFAULT 'wav',
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL DEFAULT 0,
            size INTEGER NOT NULL DEFAULT 0,
            folder TEXT NOT NULL DEFAULT '',
            source_text TEXT NOT NULL DEFAULT '',
            duration INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS video_records (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            hash TEXT NOT NULL,
            format TEXT NOT NULL DEFAULT 'mp4',
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL DEFAULT 0,
            size INTEGER NOT NULL DEFAULT 0,
            folder TEXT NOT NULL DEFAULT '',
            duration INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS text_records (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            hash TEXT NOT NULL,
            format TEXT NOT NULL DEFAULT 'txt',
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL DEFAULT 0,
            size INTEGER NOT NULL DEFAULT 0,
            folder TEXT NOT NULL DEFAULT '',
            text_length INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // ⛔ Legacy shared `folders` table is no longer created since v2 format.
        // Per-type folder tables (text_folders, audio_folders, image_folders,
        // video_folders) are used instead. See v2 migration for details.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS text_folders (
            path TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS audio_folders (
            path TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS image_folders (
            path TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS video_folders (
            path TEXT PRIMARY KEY
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE audio_records ADD COLUMN duration INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            await AppLogService.warning('ManifestDatabase',
                '_initDatabase v2: ALTER TABLE audio_records ADD COLUMN duration failed (column may already exist)');
          }
        }
        if (oldVersion < 3) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS text_records (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                hash TEXT NOT NULL,
                format TEXT NOT NULL DEFAULT 'txt',
                created_at INTEGER NOT NULL,
                size INTEGER NOT NULL DEFAULT 0,
                folder TEXT NOT NULL DEFAULT '',
                text_length INTEGER NOT NULL DEFAULT 0
              )
            ''');
          } catch (_) {
            await AppLogService.warning('ManifestDatabase',
                '_initDatabase v3: CREATE TABLE text_records failed (table may already exist)');
          }
        }
        if (oldVersion < 4) {
          // V4: 引入每个类型独立的文件夹表，替代共享的 folders 表
          await db.execute('''
            CREATE TABLE IF NOT EXISTS text_folders (
              path TEXT PRIMARY KEY
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS audio_folders (
              path TEXT PRIMARY KEY
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS image_folders (
              path TEXT PRIMARY KEY
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS video_folders (
              path TEXT PRIMARY KEY
            )
          ''');
          // 将已有文件夹迁移到四个独立的表
          try {
            final existingFolders = await db.query(ManifestTables.folders);
            for (final row in existingFolders) {
              final path = row['path'] as String;
              await db.insert(
                ManifestTables.textFolders,
                {'path': path},
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              await db.insert(
                ManifestTables.audioFolders,
                {'path': path},
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              await db.insert(
                ManifestTables.imageFolders,
                {'path': path},
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              await db.insert(
                ManifestTables.videoFolders,
                {'path': path},
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          } catch (_) {
            await AppLogService.warning('ManifestDatabase',
                '_initDatabase v4: migration of legacy folders to per-type tables failed');
          }
          // 删除旧版共享 folders 表（v2 格式不再使用）
          try {
            await db.execute('DROP TABLE IF EXISTS ${ManifestTables.folders}');
          } catch (_) {
            await AppLogService.warning('ManifestDatabase',
                '_initDatabase v4: DROP TABLE ${ManifestTables.folders} failed');
          }
        }
        if (oldVersion < 5) {
          // V5: 为四类记录表增加修改时间列 modified_at。
          // 旧记录没有修改时间 → 回填为 created_at（内容从未被修改过）。
          // 幂等且自愈：列已存在则跳过 ALTER；回填 UPDATE 只处理 0 值，
          // 重复执行（含上次失败后的重试）都是安全空操作。
          for (final table in const [
            ManifestTables.imageRecords,
            ManifestTables.audioRecords,
            ManifestTables.videoRecords,
            ManifestTables.textRecords,
          ]) {
            var hasColumn = false;
            try {
              final cols = await db.rawQuery('PRAGMA table_info($table)');
              hasColumn = cols.any((c) => c['name'] == 'modified_at');
            } catch (e) {
              await AppLogService.error('ManifestDatabase',
                  '_initDatabase v5: table_info failed for $table', e);
              continue;
            }
            if (!hasColumn) {
              try {
                await db.execute(
                  'ALTER TABLE $table ADD COLUMN modified_at INTEGER NOT NULL DEFAULT 0',
                );
              } catch (e) {
                // 列添加失败时记录真实原因；不继续回填（后续读写会显式报错）
                await AppLogService.error(
                    'ManifestDatabase',
                    '_initDatabase v5: ADD COLUMN modified_at failed for $table',
                    e);
                continue;
              }
            }
            try {
              await db.execute(
                'UPDATE $table SET modified_at = created_at WHERE modified_at = 0',
              );
            } catch (e) {
              await AppLogService.error(
                  'ManifestDatabase',
                  '_initDatabase v5: backfill modified_at failed for $table',
                  e);
            }
          }
        }
      },
    );
    await _migrateOldVideoRecords(db);
    return db;
  }

  static Future<void> _migrateOldVideoRecords(Database db) async {
    try {
      if (await StartupPreferences.getBool('migrated_video_records') == true) {
        return;
      }
      final videoFormats = [
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
        'flv',
        'wmv',
        'm4v',
        '3gp',
        'gif'
      ];
      final placeholders = videoFormats.map((_) => '?').join(',');
      final rows = await db.query(
        ManifestTables.audioRecords,
        where: 'format IN ($placeholders)',
        whereArgs: videoFormats,
      );
      if (rows.isEmpty) {
        await StartupPreferences.setBool('migrated_video_records', true);
        return;
      }
      final batch = db.batch();
      for (final row in rows) {
        batch.insert(
          ManifestTables.videoRecords,
          {
            'id': row['id'],
            'name': row['name'],
            'hash': row['hash'],
            'format': row['format'],
            'created_at': row['created_at'],
            // 旧音频记录在 v5 回填后 modified_at == created_at；
            // 列缺失时（极端场景）同样回退为 created_at，避免读到
            // 列默认值 0（1970-01-01）
            'modified_at': row['modified_at'] ?? row['created_at'],
            'size': row['size'],
            'folder': row['folder'],
            'duration': row['duration'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.delete(
          ManifestTables.audioRecords,
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      await batch.commit(noResult: true);
      await StartupPreferences.setBool('migrated_video_records', true);
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupDataValidationUnavailable.migration(error),
        stackTrace,
      );
    }
  }

  static Future<void> _migrateOldVideoRecordsJson() async {
    if (await StartupPreferences.getBool('migrated_video_records') == true) {
      return;
    }
    final audioList =
        _webData![ManifestTables.audioRecords] as List<dynamic>? ?? [];
    final videoList =
        _webData![ManifestTables.videoRecords] as List<dynamic>? ?? [];
    if (videoList.isNotEmpty) {
      await StartupPreferences.setBool('migrated_video_records', true);
      return;
    }
    final videoFormats = {
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
      'flv',
      'wmv',
      'm4v',
      '3gp',
      'gif'
    };
    final toMigrate = <Map<String, dynamic>>[];
    final remaining = <Map<String, dynamic>>[];
    for (final item in audioList) {
      final map = item as Map<String, dynamic>;
      if (videoFormats.contains(map['format'] as String?)) {
        toMigrate.add(map);
      } else {
        remaining.add(map);
      }
    }
    if (toMigrate.isEmpty) {
      await StartupPreferences.setBool('migrated_video_records', true);
      return;
    }
    for (final record in toMigrate) {
      final videoRecord = <String, dynamic>{
        'id': record['id'],
        'name': record['name'],
        'hash': record['hash'],
        'format': record['format'],
        'createdAt': record['createdAt'],
        'size': record['size'],
        'folder': record['folder'],
        'duration': record['duration'],
      };
      videoList.add(videoRecord);
    }
    _webData![ManifestTables.audioRecords] = remaining;
    _webData![ManifestTables.videoRecords] = videoList;
    await _saveWebData();
    await StartupPreferences.setBool('migrated_video_records', true);
  }

  /// Migrate legacy shared folders into the requested per-type tables.
  ///
  /// By default this migrates all media categories and removes the legacy
  /// table. A partial category restore passes only the categories it migrated
  /// and keeps the shared table until the remaining categories are current.
  /// Idempotent — safe to call multiple times.
  static Future<void> migrateLegacyFoldersToPerType({
    Set<String>? onlyFolderTables,
    bool removeLegacyTable = true,
  }) async {
    final targetFolderTables = ManifestTables.allPerTypeFolderTables
        .where(
          (folderTable) =>
              onlyFolderTables == null ||
              onlyFolderTables.contains(folderTable),
        )
        .toList();
    if (_useJsonStore) {
      if (kIsWeb && _webData == null) {
        await _migrateLegacyFoldersWeb(
          folderTables: targetFolderTables,
          removeLegacyTable: removeLegacyTable,
        );
        return;
      }
      await _loadWebData();
      await _migrateLegacyFoldersJsonV2(
        folderTables: targetFolderTables,
        removeLegacyTable: removeLegacyTable,
      );
      return;
    }
    // For SQLite, the onUpgrade path in _initDatabase already copies
    // legacy folders to per-type tables and drops the legacy table.
    // We verify this by checking the legacy table no longer exists
    // after the DB is initialized.
    Database? db;
    try {
      db = await database;
    } on MissingPluginException catch (e) {
      // Database not available (e.g. in test mode without enableTestMode).
      // The migration will be handled by onUpgrade when the DB is
      // actually initialized.
      await AppLogService.warning('ManifestDatabase',
          'migrateLegacyFoldersToPerType: DB not available, skipping: $e');
      debugPrint(
          '[ManifestDatabase] migrateLegacyFoldersToPerType: DB not available, '
          'skipping: $e');
      return;
    }
    try {
      // If the legacy table somehow still exists (e.g. from an intermediate
      // version), migrate and drop it.
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [ManifestTables.folders],
      );
      if (tables.isNotEmpty) {
        final rows = await db.query(ManifestTables.folders);
        if (rows.isNotEmpty) {
          for (final row in rows) {
            final path = row['path'] as String;
            for (final ft in targetFolderTables) {
              await db.insert(ft, {'path': path},
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        }
        if (removeLegacyTable) {
          await db.execute('DROP TABLE IF EXISTS ${ManifestTables.folders}');
        }
      }
    } catch (e) {
      await AppLogService.error(
          'ManifestDatabase', 'migrateLegacyFoldersToPerType SQLite error: $e');
      debugPrint(
          '[ManifestDatabase] migrateLegacyFoldersToPerType SQLite error: $e');
      rethrow;
    }
  }

  /// Validate the persisted Web manifest after startup migration without
  /// decoding its full payload on the UI isolate.
  static Future<void> validateWebManifestForStartup() async {
    if (!kIsWeb) return;
    final Uint8List? raw;
    try {
      raw = await WebFileStore.read(_webStoreKey);
    } catch (error) {
      throw StartupDataValidationUnavailable.migration(error);
    }
    if (raw == null || raw.isEmpty) return;

    final result = await json_parser.validateWebManifestData(raw);
    if (result['status'] != 'ok') {
      throw StartupDataValidationUnavailable.migration(
        FormatException('Invalid Web manifest: ${result['error']}'),
      );
    }
  }

  static Future<void> _migrateLegacyFoldersWeb({
    required List<String> folderTables,
    required bool removeLegacyTable,
  }) async {
    final Uint8List? raw;
    try {
      raw = await WebFileStore.read(_webStoreKey);
    } catch (error) {
      throw StartupDataValidationUnavailable.migration(error);
    }
    if (raw == null || raw.isEmpty) {
      _webData = emptyWebData();
      await _migrateOldVideoRecordsJson();
      await _migrateLegacyFoldersJsonV2(
        folderTables: folderTables,
        removeLegacyTable: removeLegacyTable,
      );
      return;
    }

    final migrateOldVideos =
        await StartupPreferences.getBool('migrated_video_records') != true;
    final result = await json_parser.migrateWebManifestData(
      raw,
      folderTables,
      removeLegacyTable,
      migrateOldVideos,
    );
    final status = result['status'];
    if (status == 'parseError' || status == 'invalidManifest') {
      throw StartupDataValidationUnavailable.migration(
        FormatException('${result['error']}'),
      );
    }

    if (status == 'videoError' || status == 'folderError') {
      if (result['videoChanged'] == true) {
        final payload = result['payloadBytes'];
        if (payload is! Uint8List || payload.isEmpty) {
          throw StartupDataValidationUnavailable.migration(
            StateError('Missing partially migrated web manifest.'),
          );
        }
        await _writeWebMigrationData(payload);
      }
      if (result['setVideoFlag'] == true) {
        await StartupPreferences.setBool('migrated_video_records', true);
      }
      throw StartupDataValidationUnavailable.migration(
        StateError('${result['error']}'),
      );
    }

    if (status != 'ok') {
      throw StartupDataValidationUnavailable.migration(
        StateError('Invalid web manifest migration result.'),
      );
    }
    if (result['changed'] == true) {
      final payload = result['payloadBytes'];
      if (payload is! Uint8List || payload.isEmpty) {
        throw StartupDataValidationUnavailable.migration(
          StateError('Missing migrated web manifest.'),
        );
      }
      await _writeWebMigrationData(payload);
    }
    if (result['setVideoFlag'] == true) {
      await StartupPreferences.setBool('migrated_video_records', true);
    }
    _webData = null;
    if (result['foldersMigrated'] == true) {
      debugPrint(
        '[ManifestDatabase] Migrated legacy folders to ${folderTables.length} '
        'per-type table(s) (JSON)',
      );
    }
  }

  static Future<void> _writeWebMigrationData(Uint8List encoded) async {
    try {
      await WebFileStore.write(_webStoreKey, encoded);
    } catch (error) {
      throw StartupDataValidationUnavailable.migration(error);
    }
  }

  /// Internal: migrate legacy folders in JSON/web mode (v2 format).
  static Future<void> _migrateLegacyFoldersJsonV2({
    required List<String> folderTables,
    required bool removeLegacyTable,
  }) async {
    final legacyFolders =
        _webData![ManifestTables.folders] as List<dynamic>? ?? [];
    if (legacyFolders.isEmpty) {
      if (removeLegacyTable &&
          _webData!.remove(ManifestTables.folders) != null) {
        await _saveWebData();
      }
      return;
    }

    for (final folderTable in folderTables) {
      final existing =
          (_webData![folderTable] as List<dynamic>?)?.cast<String>() ?? [];
      final merged = <String>{...existing, ...legacyFolders.cast<String>()};
      _webData![folderTable] = merged.toList();
    }

    if (removeLegacyTable) _webData!.remove(ManifestTables.folders);
    await _saveWebData();
    debugPrint(
      '[ManifestDatabase] Migrated legacy folders to ${folderTables.length} '
      'per-type table(s) (JSON)',
    );
  }

  // ==================================================================
  // Web 端数据加载与持久化（全量 JSON 通过 WebFileStore）
  // ==================================================================

  static Future<Map<String, dynamic>> _loadWebData() async {
    if (_webData != null) return _webData!;

    try {
      final raw = await WebFileStore.read(_webStoreKey);
      if (raw != null && raw.isNotEmpty) {
        final text = utf8Decode(raw);
        _webData = jsonDecode(text) as Map<String, dynamic>;
      } else {
        _webData = emptyWebData();
      }
    } catch (e) {
      debugPrint('ManifestDatabase._loadWebData error: $e');
      _webData = emptyWebData();
    }
    await _migrateOldVideoRecordsJson();
    return _webData!;
  }

  static Future<void> _saveWebData({bool rethrowOnError = false}) async {
    if (_webData == null) return;
    try {
      final json = jsonEncode(_webData);
      await beforeWebDataSaveForTesting?.call();
      await WebFileStore.write(_webStoreKey, utf8Encode(json));
    } catch (e, st) {
      debugPrint('ManifestDatabase._saveWebData error: $e');
      await AppLogService.error(
          'ManifestDatabase', '_saveWebData failed', e, st);
      if (rethrowOnError) rethrow;
    }
  }

  static Future<T> _withJsonRecordRegistrationLock<T>(
    Future<T> Function() operation,
  ) async {
    final previous = _jsonRecordRegistrationQueue;
    final release = Completer<void>();
    final releaseFuture = release.future;
    _jsonRecordRegistrationQueue = releaseFuture;
    try {
      if (previous != null) await previous;
      return await operation();
    } finally {
      if (identical(_jsonRecordRegistrationQueue, releaseFuture)) {
        _jsonRecordRegistrationQueue = null;
      }
      release.complete();
    }
  }

  /// Inserts a record and its folder path in one persistence operation.
  /// Folder entries are kept after their records are deleted, so they must be
  /// rolled back with the record if an ancestor cannot be persisted.
  static Future<void> insertRecordWithFolders({
    required String recordTable,
    required Map<String, dynamic> record,
    required Iterable<String> folderPaths,
    void Function()? beforeCommit,
  }) async {
    try {
      final folderTable = ManifestTables.folderTableFor(recordTable);
      final isTextRecord = recordTable == ManifestTables.textRecords;

      if (_useJsonStore) {
        beforeJsonRecordRegistrationForTesting?.call();
        await _withJsonRecordRegistrationLock(() async {
          final data = await _loadWebData();
          final records = data[recordTable] as List<dynamic>? ?? <dynamic>[];
          final folders = data[folderTable] as List<dynamic>? ?? <dynamic>[];
          data[recordTable] = records;
          data[folderTable] = folders;
          final insertedFolders = <String>[];
          var writeAttempted = false;

          if (isTextRecord) beforeCommit?.call();
          records.add(record);
          try {
            for (final path in folderPaths) {
              if (folders.contains(path)) continue;
              beforeFolderInsertForTesting?.call(path);
              folders.add(path);
              insertedFolders.add(path);
            }
            writeAttempted = true;
            await _saveWebData(rethrowOnError: true);
            if (isTextRecord) beforeCommit?.call();
          } catch (error, stackTrace) {
            records.remove(record);
            for (final path in insertedFolders) {
              folders.remove(path);
            }
            if (writeAttempted) {
              try {
                await _saveWebData(rethrowOnError: true);
              } catch (_) {
                // Keep the cancellation or original write error as the failure.
              }
            }
            Error.throwWithStackTrace(error, stackTrace);
          }
        });
        return;
      }

      final db = await database;
      await db.transaction((txn) async {
        if (isTextRecord) beforeCommit?.call();
        await txn.insert(
          recordTable,
          recordToDbRow(record),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final path in folderPaths) {
          beforeFolderInsertForTesting?.call(path);
          await txn.insert(
            folderTable,
            {'path': path},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        if (isTextRecord) beforeCommit?.call();
      });
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'insertRecordWithFolders failed', e, stackTrace);
      rethrow;
    }
  }

  // ==================================================================
  // Image record operations
  // ==================================================================

  /// 获取所有图片记录
  static Future<List<Map<String, dynamic>>> getAllImageRecords() async {
    try {
      if (_useJsonStore) {
        return await _withJsonRecordRegistrationLock(() async {
          final data = await _loadWebData();
          final list =
              data[ManifestTables.imageRecords] as List<dynamic>? ?? [];
          return list.cast<Map<String, dynamic>>().toList();
        });
      }
      final db = await database;
      final rows = await db.query(ManifestTables.imageRecords);
      return rows.map(dbRowToRecord).toList();
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'getAllImageRecords failed', e, stackTrace);
      rethrow;
    }
  }

  /// 插入一条图片记录
  static Future<void> insertImageRecord(Map<String, dynamic> record) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.imageRecords] as List<dynamic>? ?? [];
        list.add(record);
        await _saveWebData();
        return;
      }
      final db = await database;
      await db.insert(
        ManifestTables.imageRecords,
        recordToDbRow(record),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'insertImageRecord failed', e, stackTrace);
      rethrow;
    }
  }

  /// 更新一条图片记录
  static Future<void> updateImageRecord(
      String id, Map<String, dynamic> updates) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.imageRecords] as List<dynamic>? ?? [];
        final index = list.indexWhere((r) => (r as Map)['id'] == id);
        if (index != -1) {
          (list[index] as Map<String, dynamic>).addAll(updates);
          await _saveWebData();
        }
        return;
      }
      final db = await database;
      await db.update(
        ManifestTables.imageRecords,
        recordToDbRow(updates),
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'updateImageRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 删除一条图片记录
  static Future<void> deleteImageRecord(String id) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.imageRecords] as List<dynamic>? ?? [];
        list.removeWhere((r) => (r as Map)['id'] == id);
        await _saveWebData();
        return;
      }
      final db = await database;
      await db.delete(
        ManifestTables.imageRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'deleteImageRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 批量删除图片记录
  static Future<void> deleteImageRecords(List<String> ids) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.imageRecords] as List<dynamic>? ?? [];
        final idSet = ids.toSet();
        list.removeWhere((r) => idSet.contains((r as Map)['id']));
        await _saveWebData();
        return;
      }
      final db = await database;
      final placeholders = ids.map((_) => '?').join(',');
      await db.delete(
        ManifestTables.imageRecords,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'deleteImageRecords failed', e, stackTrace);
      rethrow;
    }
  }

  // ==================================================================
  // Audio record operations
  // ==================================================================

  /// 获取所有音频记录
  static Future<List<Map<String, dynamic>>> getAllAudioRecords() async {
    try {
      if (_useJsonStore) {
        return await _withJsonRecordRegistrationLock(() async {
          final data = await _loadWebData();
          final list =
              data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
          return list.cast<Map<String, dynamic>>().toList();
        });
      }
      final db = await database;
      final rows = await db.query(ManifestTables.audioRecords);
      return rows.map(dbRowToRecord).toList();
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'getAllAudioRecords failed', e, stackTrace);
      rethrow;
    }
  }

  /// 插入一条音频记录
  static Future<void> insertAudioRecord(Map<String, dynamic> record) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
        list.add(record);
        await _saveWebData();
        return;
      }
      final db = await database;
      await db.insert(
        ManifestTables.audioRecords,
        recordToDbRow(record),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'insertAudioRecord failed', e, stackTrace);
      rethrow;
    }
  }

  /// 更新一条音频记录
  static Future<void> updateAudioRecord(
      String id, Map<String, dynamic> updates) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
        final index = list.indexWhere((r) => (r as Map)['id'] == id);
        if (index != -1) {
          (list[index] as Map<String, dynamic>).addAll(updates);
          await _saveWebData();
        }
        return;
      }
      final db = await database;
      await db.update(
        ManifestTables.audioRecords,
        recordToDbRow(updates),
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'updateAudioRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 删除一条音频记录
  static Future<void> deleteAudioRecord(String id) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
        list.removeWhere((r) => (r as Map)['id'] == id);
        await _saveWebData();
        return;
      }
      final db = await database;
      await db.delete(
        ManifestTables.audioRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'deleteAudioRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 批量删除音频记录
  static Future<void> deleteAudioRecords(List<String> ids) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
        final idSet = ids.toSet();
        list.removeWhere((r) => idSet.contains((r as Map)['id']));
        await _saveWebData();
        return;
      }
      final db = await database;
      final placeholders = ids.map((_) => '?').join(',');
      await db.delete(
        ManifestTables.audioRecords,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'deleteAudioRecords failed', e, stackTrace);
      rethrow;
    }
  }

  // ==================================================================
  // Video record operations
  // ==================================================================

  /// 获取所有视频记录
  static Future<List<Map<String, dynamic>>> getAllVideoRecords() async {
    try {
      if (_useJsonStore) {
        return await _withJsonRecordRegistrationLock(() async {
          final data = await _loadWebData();
          final list =
              data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
          return list.cast<Map<String, dynamic>>().toList();
        });
      }
      final db = await database;
      final rows = await db.query(ManifestTables.videoRecords);
      return rows.map(dbRowToRecord).toList();
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'getAllVideoRecords failed', e, stackTrace);
      rethrow;
    }
  }

  /// 插入一条视频记录
  static Future<void> insertVideoRecord(Map<String, dynamic> record) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        list.add(record);
        await _saveWebData();
        return;
      }
      final db = await database;
      await db.insert(
        ManifestTables.videoRecords,
        recordToDbRow(record),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'insertVideoRecord failed', e, stackTrace);
      rethrow;
    }
  }

  /// 更新一条视频记录
  static Future<void> updateVideoRecord(
      String id, Map<String, dynamic> updates) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        final index = list.indexWhere((r) => (r as Map)['id'] == id);
        if (index != -1) {
          (list[index] as Map<String, dynamic>).addAll(updates);
          await _saveWebData();
        }
        return;
      }
      final db = await database;
      await db.update(
        ManifestTables.videoRecords,
        recordToDbRow(updates),
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'updateVideoRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 删除一条视频记录
  static Future<void> deleteVideoRecord(String id) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        list.removeWhere((r) => (r as Map)['id'] == id);
        await _saveWebData();
        return;
      }
      final db = await database;
      await db.delete(
        ManifestTables.videoRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'deleteVideoRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 批量删除视频记录
  static Future<void> deleteVideoRecords(List<String> ids) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        final idSet = ids.toSet();
        list.removeWhere((r) => idSet.contains((r as Map)['id']));
        await _saveWebData();
        return;
      }
      final db = await database;
      final placeholders = ids.map((_) => '?').join(',');
      await db.delete(
        ManifestTables.videoRecords,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'deleteVideoRecords failed', e, stackTrace);
      rethrow;
    }
  }

  // ==================================================================
  // Text record operations
  // ==================================================================

  /// 获取所有文本记录
  static Future<List<Map<String, dynamic>>> getAllTextRecords() async {
    try {
      if (_useJsonStore) {
        return await _withJsonRecordRegistrationLock(() async {
          final data = await _loadWebData();
          final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
          return list.cast<Map<String, dynamic>>().toList();
        });
      }
      final db = await database;
      final rows = await db.query(ManifestTables.textRecords);
      return rows.map(dbRowToRecord).toList();
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'getAllTextRecords failed', e, stackTrace);
      rethrow;
    }
  }

  /// 插入一条文本记录
  static Future<void> insertTextRecord(Map<String, dynamic> record,
      {void Function()? beforeCommit}) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        beforeCommit?.call();
        list.add(record);
        await _saveWebData();
        try {
          beforeCommit?.call();
        } catch (_) {
          list.remove(record);
          await _saveWebData();
          rethrow;
        }
        return;
      }
      final db = await database;
      if (beforeCommit == null) {
        await db.insert(
          ManifestTables.textRecords,
          recordToDbRow(record),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        // Cancellation while waiting for the database/transaction or insert
        // rolls back this record. The final guard is the commit boundary.
        await db.transaction((txn) async {
          beforeCommit();
          await txn.insert(
            ManifestTables.textRecords,
            recordToDbRow(record),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          beforeCommit();
        });
      }
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'insertTextRecord failed', e, stackTrace);
      rethrow;
    }
  }

  /// 更新一条文本记录
  static Future<void> updateTextRecord(
      String id, Map<String, dynamic> updates) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        final index = list.indexWhere((r) => (r as Map)['id'] == id);
        if (index != -1) {
          (list[index] as Map<String, dynamic>).addAll(updates);
          await _saveWebData();
        }
        return;
      }
      final db = await database;
      await db.update(
        ManifestTables.textRecords,
        recordToDbRow(updates),
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'updateTextRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 删除一条文本记录
  static Future<void> deleteTextRecord(String id) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        list.removeWhere((r) => (r as Map)['id'] == id);
        await _saveWebData();
        return;
      }
      final db = await database;
      await db.delete(
        ManifestTables.textRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'deleteTextRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 批量删除文本记录
  static Future<void> deleteTextRecords(List<String> ids) async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        final idSet = ids.toSet();
        list.removeWhere((r) => idSet.contains((r as Map)['id']));
        await _saveWebData();
        return;
      }
      final db = await database;
      final placeholders = ids.map((_) => '?').join(',');
      await db.delete(
        ManifestTables.textRecords,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'deleteTextRecords failed', e, stackTrace);
      rethrow;
    }
  }

  // ==================================================================
  // Folder operations
  // ==================================================================

  /// 获取所有文件夹路径
  ///
  /// [recordTable] 指定记录表名，用于选择对应的文件夹表。
  /// 为 null 时返回所有四种类型的文件夹合并结果。
  static Future<List<String>> getAllFolders({String? recordTable}) async {
    try {
      if (_useJsonStore) {
        return await _withJsonRecordRegistrationLock(() async {
          final data = await _loadWebData();
          if (recordTable != null) {
            final folderTable = ManifestTables.folderTableFor(recordTable);
            final list = data[folderTable] as List<dynamic>? ?? [];
            return list.cast<String>().toList();
          }
          // 无 recordTable 时合并所有四种类型的文件夹
          final all = <String>{};
          for (final ft in ManifestTables.allPerTypeFolderTables) {
            final list = data[ft] as List<dynamic>? ?? [];
            all.addAll(list.cast<String>());
          }
          return all.toList();
        });
      }
      final db = await database;
      if (recordTable != null) {
        final folderTable = ManifestTables.folderTableFor(recordTable);
        final rows = await db.query(folderTable);
        return rows.map((r) => r['path'] as String).toList();
      }
      // 无 recordTable 时合并所有四种类型的文件夹
      final all = <String>{};
      for (final ft in ManifestTables.allPerTypeFolderTables) {
        final rows = await db.query(ft);
        all.addAll(rows.map((r) => r['path'] as String));
      }
      return all.toList();
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'getAllFolders failed', e, stackTrace);
      rethrow;
    }
  }

  /// 插入一个文件夹路径
  ///
  /// [recordTable] 必须指定，v2+ 格式不再使用共享 folders 表。
  static Future<void> insertFolder(String path, {String? recordTable}) async {
    try {
      if (recordTable == null) {
        throw ArgumentError('recordTable is required in v2+ format');
      }
      final folderTable = ManifestTables.folderTableFor(recordTable);
      if (_useJsonStore) {
        await _withJsonRecordRegistrationLock(() async {
          final data = await _loadWebData();
          final list = data[folderTable] as List<dynamic>? ?? [];
          if (!list.contains(path)) {
            beforeFolderInsertForTesting?.call(path);
            list.add(path);
            try {
              await _saveWebData(rethrowOnError: true);
            } catch (_) {
              list.remove(path);
              rethrow;
            }
          }
        });
        return;
      }
      final db = await database;
      beforeFolderInsertForTesting?.call(path);
      await db.insert(
        folderTable,
        {'path': path},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'insertFolder failed [path=$path]', e, stackTrace);
      rethrow;
    }
  }

  /// 删除一个文件夹路径
  ///
  /// [recordTable] 必须指定，v2+ 格式不再使用共享 folders 表。
  static Future<void> deleteFolder(String path, {String? recordTable}) async {
    try {
      if (recordTable == null) {
        throw ArgumentError('recordTable is required in v2+ format');
      }
      final folderTable = ManifestTables.folderTableFor(recordTable);
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[folderTable] as List<dynamic>? ?? [];
        list.remove(path);
        await _saveWebData();
        return;
      }
      final db = await database;
      await db.delete(
        folderTable,
        where: 'path = ?',
        whereArgs: [path],
      );
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'deleteFolder failed [path=$path]', e, stackTrace);
      rethrow;
    }
  }

  // ==================================================================
  // 工具方法
  // ==================================================================

  /// 清除指定记录类型的所有数据。
  ///
  /// [tableName] 为记录表名，如 'image_records', 'audio_records' 等。
  /// 不会影响其他记录类型或文件夹数据。
  static Future<void> clearRecords(String tableName) async {
    try {
      final validTables = {
        ManifestTables.imageRecords,
        ManifestTables.audioRecords,
        ManifestTables.videoRecords,
        ManifestTables.textRecords,
      };
      if (!validTables.contains(tableName)) {
        throw ArgumentError('Invalid record table: $tableName');
      }
      if (_useJsonStore) {
        final data = await _loadWebData();
        data[tableName] = <dynamic>[];
        await _saveWebData();
      } else {
        final db = await database;
        await db.delete(tableName);
      }
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'clearRecords failed', e, stackTrace);
      rethrow;
    }
  }

  /// 清除指定记录类型的文件夹数据。
  ///
  /// [recordTable] 指定记录表名，用于选择对应的文件夹表。
  /// 为 null 时抛出 ArgumentError。
  static Future<void> clearFolders({String? recordTable}) async {
    try {
      if (recordTable == null) {
        throw ArgumentError('recordTable is required');
      }
      final folderTable = ManifestTables.folderTableFor(recordTable);
      if (_useJsonStore) {
        final data = await _loadWebData();
        data[folderTable] = <dynamic>[];
        await _saveWebData();
      } else {
        final db = await database;
        await db.delete(folderTable);
      }
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'clearFolders failed', e, stackTrace);
      rethrow;
    }
  }

  /// 清除所有数据（双模式通用）。
  ///
  /// 在 Native 模式下删除 SQLite 数据库文件；
  /// 在 Web / 测试模式下清除 WebFileStore 中的数据。
  static Future<void> clearAllData() async {
    try {
      if (_useJsonStore) {
        _webData = null;
        await WebFileStore.delete(_webStoreKey);
      } else if (_database != null) {
        await _database!.close();
        _database = null;
        final dir = await getApplicationDocumentsDirectory();
        final dbPath = p.join(dir.path, 'stroom_manifest.db');
        final dbFile = File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'clearAllData failed', e, stackTrace);
      rethrow;
    }
  }
}
