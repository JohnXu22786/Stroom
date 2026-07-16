import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/web_file_store.dart';
import 'app_log_service.dart';
import 'manifest_database_shared.dart';
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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS image_records (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            hash TEXT NOT NULL,
            format TEXT NOT NULL DEFAULT 'jpg',
            created_at INTEGER NOT NULL,
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
      },
    );
    await _migrateOldVideoRecords(db);
    return db;
  }

  static Future<void> _migrateOldVideoRecords(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('migrated_video_records') == true) {
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
      await prefs.setBool('migrated_video_records', true);
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
    await prefs.setBool('migrated_video_records', true);
  }

  static Future<void> _migrateOldVideoRecordsJson() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('migrated_video_records') == true) {
      return;
    }
    final audioList =
        _webData![ManifestTables.audioRecords] as List<dynamic>? ?? [];
    final videoList =
        _webData![ManifestTables.videoRecords] as List<dynamic>? ?? [];
    if (videoList.isNotEmpty) {
      await prefs.setBool('migrated_video_records', true);
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
      await prefs.setBool('migrated_video_records', true);
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
    await prefs.setBool('migrated_video_records', true);
  }

  /// v1→v2 migration: migrate legacy shared folders to per-type tables,
  /// then remove the shared folders table entirely.
  ///
  /// After this migration, only per-type folder tables remain.
  ///
  /// Call this before [database] or [_loadWebData] is first accessed,
  /// so the migration runs before the new code (which does not read
  /// from the legacy table) takes effect.
  static Future<bool> hasLegacyFolders() async {
    if (_useJsonStore) {
      await _loadWebData();
      return _webData!.containsKey(ManifestTables.folders);
    }
    // SQLite: check if the table exists (it won't be in _database yet)
    return false; // onUpgrade already handles it for SQLite
  }

  /// Migrate legacy shared folders from `folders` table to all 4 per-type
  /// tables, then drop the legacy table. Idempotent — safe to call multiple
  /// times.
  static Future<void> migrateLegacyFoldersToPerType() async {
    if (_useJsonStore) {
      await _loadWebData();
      await _migrateLegacyFoldersJsonV2();
      return;
    }
    // For SQLite, the onUpgrade path in _initDatabase already copies
    // legacy folders to per-type tables and drops the legacy table.
    // We verify this by checking the legacy table no longer exists
    // after the DB is initialized.
    Database? db;
    try {
      db = await database;
    } catch (e) {
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
            for (final ft in ManifestTables.allPerTypeFolderTables) {
              await db.insert(ft, {'path': path},
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        }
        await db.execute('DROP TABLE IF EXISTS ${ManifestTables.folders}');
      }
    } catch (e) {
      await AppLogService.error(
          'ManifestDatabase', 'migrateLegacyFoldersToPerType SQLite error: $e');
      debugPrint(
          '[ManifestDatabase] migrateLegacyFoldersToPerType SQLite error: $e');
    }
  }

  /// Internal: migrate legacy folders in JSON/web mode (v2 format).
  /// Removes the legacy [ManifestTables.folders] key after migrating.
  static Future<void> _migrateLegacyFoldersJsonV2() async {
    final legacyFolders =
        _webData![ManifestTables.folders] as List<dynamic>? ?? [];
    if (legacyFolders.isEmpty) return;

    for (final folderTable in ManifestTables.allPerTypeFolderTables) {
      final existing =
          (_webData![folderTable] as List<dynamic>?)?.cast<String>() ?? [];
      final merged = <String>{...existing, ...legacyFolders.cast<String>()};
      _webData![folderTable] = merged.toList();
    }

    // Remove the legacy key
    _webData!.remove(ManifestTables.folders);
    await _saveWebData();
    debugPrint('[ManifestDatabase] Migrated legacy folders to per-type (JSON)');
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

  static Future<void> _saveWebData() async {
    if (_webData == null) return;
    try {
      final json = jsonEncode(_webData);
      await WebFileStore.write(_webStoreKey, utf8Encode(json));
    } catch (e) {
      debugPrint('ManifestDatabase._saveWebData error: $e');
    }
  }

  // ==================================================================
  // Image record operations
  // ==================================================================

  /// 获取所有图片记录
  static Future<List<Map<String, dynamic>>> getAllImageRecords() async {
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.imageRecords] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
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
        final data = await _loadWebData();
        final list = data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
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
    await AppLogService.info('ManifestDatabase', 'getAllVideoRecords called');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        await AppLogService.info('ManifestDatabase',
            'getAllVideoRecords completed [count=${list.length}]');
        return list.cast<Map<String, dynamic>>();
      }
      final db = await database;
      final rows = await db.query(ManifestTables.videoRecords);
      await AppLogService.info('ManifestDatabase',
          'getAllVideoRecords completed [count=${rows.length}]');
      return rows.map(dbRowToRecord).toList();
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'getAllVideoRecords failed', e, stackTrace);
      rethrow;
    }
  }

  /// 插入一条视频记录
  static Future<void> insertVideoRecord(Map<String, dynamic> record) async {
    await AppLogService.info('ManifestDatabase', 'insertVideoRecord called');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        list.add(record);
        await _saveWebData();
        await AppLogService.info(
            'ManifestDatabase', 'insertVideoRecord completed');
        return;
      }
      final db = await database;
      await db.insert(
        ManifestTables.videoRecords,
        recordToDbRow(record),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await AppLogService.info(
          'ManifestDatabase', 'insertVideoRecord completed');
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'insertVideoRecord failed', e, stackTrace);
      rethrow;
    }
  }

  /// 更新一条视频记录
  static Future<void> updateVideoRecord(
      String id, Map<String, dynamic> updates) async {
    await AppLogService.info(
        'ManifestDatabase', 'updateVideoRecord called [id=$id]');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        final index = list.indexWhere((r) => (r as Map)['id'] == id);
        if (index != -1) {
          (list[index] as Map<String, dynamic>).addAll(updates);
          await _saveWebData();
        }
        await AppLogService.info(
            'ManifestDatabase', 'updateVideoRecord completed [id=$id]');
        return;
      }
      final db = await database;
      await db.update(
        ManifestTables.videoRecords,
        recordToDbRow(updates),
        where: 'id = ?',
        whereArgs: [id],
      );
      await AppLogService.info(
          'ManifestDatabase', 'updateVideoRecord completed [id=$id]');
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'updateVideoRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 删除一条视频记录
  static Future<void> deleteVideoRecord(String id) async {
    await AppLogService.info(
        'ManifestDatabase', 'deleteVideoRecord called [id=$id]');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        list.removeWhere((r) => (r as Map)['id'] == id);
        await _saveWebData();
        await AppLogService.info(
            'ManifestDatabase', 'deleteVideoRecord completed [id=$id]');
        return;
      }
      final db = await database;
      await db.delete(
        ManifestTables.videoRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
      await AppLogService.info(
          'ManifestDatabase', 'deleteVideoRecord completed [id=$id]');
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'deleteVideoRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 批量删除视频记录
  static Future<void> deleteVideoRecords(List<String> ids) async {
    await AppLogService.info(
        'ManifestDatabase', 'deleteVideoRecords called [count=${ids.length}]');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
        final idSet = ids.toSet();
        list.removeWhere((r) => idSet.contains((r as Map)['id']));
        await _saveWebData();
        await AppLogService.info('ManifestDatabase',
            'deleteVideoRecords completed [count=${ids.length}]');
        return;
      }
      final db = await database;
      final placeholders = ids.map((_) => '?').join(',');
      await db.delete(
        ManifestTables.videoRecords,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      await AppLogService.info('ManifestDatabase',
          'deleteVideoRecords completed [count=${ids.length}]');
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'deleteVideoRecords failed', e, stackTrace);
      rethrow;
    }
  }

  /// 获取单条音频记录
  static Future<Map<String, dynamic>?> getAudioRecord(String id) async {
    await AppLogService.info(
        'ManifestDatabase', 'getAudioRecord called [id=$id]');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
        for (final r in list) {
          final map = r as Map<String, dynamic>;
          if (map['id'] == id) {
            await AppLogService.info('ManifestDatabase',
                'getAudioRecord completed [id=$id, found=true]');
            return map;
          }
        }
        await AppLogService.info('ManifestDatabase',
            'getAudioRecord completed [id=$id, found=false]');
        return null;
      }
      final db = await database;
      final rows = await db.query(
        ManifestTables.audioRecords,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        await AppLogService.info('ManifestDatabase',
            'getAudioRecord completed [id=$id, found=false]');
        return null;
      }
      await AppLogService.info(
          'ManifestDatabase', 'getAudioRecord completed [id=$id, found=true]');
      return dbRowToRecord(rows.first);
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'getAudioRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  // ==================================================================
  // Text record operations
  // ==================================================================

  /// 获取所有文本记录
  static Future<List<Map<String, dynamic>>> getAllTextRecords() async {
    await AppLogService.info('ManifestDatabase', 'getAllTextRecords called');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        await AppLogService.info('ManifestDatabase',
            'getAllTextRecords completed [count=${list.length}]');
        return list.cast<Map<String, dynamic>>();
      }
      final db = await database;
      final rows = await db.query(ManifestTables.textRecords);
      await AppLogService.info('ManifestDatabase',
          'getAllTextRecords completed [count=${rows.length}]');
      return rows.map(dbRowToRecord).toList();
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'getAllTextRecords failed', e, stackTrace);
      rethrow;
    }
  }

  /// 插入一条文本记录
  static Future<void> insertTextRecord(Map<String, dynamic> record) async {
    await AppLogService.info('ManifestDatabase', 'insertTextRecord called');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        list.add(record);
        await _saveWebData();
        await AppLogService.info(
            'ManifestDatabase', 'insertTextRecord completed');
        return;
      }
      final db = await database;
      await db.insert(
        ManifestTables.textRecords,
        recordToDbRow(record),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await AppLogService.info(
          'ManifestDatabase', 'insertTextRecord completed');
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'insertTextRecord failed', e, stackTrace);
      rethrow;
    }
  }

  /// 更新一条文本记录
  static Future<void> updateTextRecord(
      String id, Map<String, dynamic> updates) async {
    await AppLogService.info(
        'ManifestDatabase', 'updateTextRecord called [id=$id]');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        final index = list.indexWhere((r) => (r as Map)['id'] == id);
        if (index != -1) {
          (list[index] as Map<String, dynamic>).addAll(updates);
          await _saveWebData();
        }
        await AppLogService.info(
            'ManifestDatabase', 'updateTextRecord completed [id=$id]');
        return;
      }
      final db = await database;
      await db.update(
        ManifestTables.textRecords,
        recordToDbRow(updates),
        where: 'id = ?',
        whereArgs: [id],
      );
      await AppLogService.info(
          'ManifestDatabase', 'updateTextRecord completed [id=$id]');
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'updateTextRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 删除一条文本记录
  static Future<void> deleteTextRecord(String id) async {
    await AppLogService.info(
        'ManifestDatabase', 'deleteTextRecord called [id=$id]');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        list.removeWhere((r) => (r as Map)['id'] == id);
        await _saveWebData();
        await AppLogService.info(
            'ManifestDatabase', 'deleteTextRecord completed [id=$id]');
        return;
      }
      final db = await database;
      await db.delete(
        ManifestTables.textRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
      await AppLogService.info(
          'ManifestDatabase', 'deleteTextRecord completed [id=$id]');
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'deleteTextRecord failed [id=$id]', e, stackTrace);
      rethrow;
    }
  }

  /// 批量删除文本记录
  static Future<void> deleteTextRecords(List<String> ids) async {
    await AppLogService.info(
        'ManifestDatabase', 'deleteTextRecords called [count=${ids.length}]');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[ManifestTables.textRecords] as List<dynamic>? ?? [];
        final idSet = ids.toSet();
        list.removeWhere((r) => idSet.contains((r as Map)['id']));
        await _saveWebData();
        await AppLogService.info('ManifestDatabase',
            'deleteTextRecords completed [count=${ids.length}]');
        return;
      }
      final db = await database;
      final placeholders = ids.map((_) => '?').join(',');
      await db.delete(
        ManifestTables.textRecords,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      await AppLogService.info('ManifestDatabase',
          'deleteTextRecords completed [count=${ids.length}]');
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
    await AppLogService.info(
        'ManifestDatabase', 'getAllFolders called [recordTable=$recordTable]');
    try {
      if (_useJsonStore) {
        final data = await _loadWebData();
        if (recordTable != null) {
          final folderTable = ManifestTables.folderTableFor(recordTable);
          final list = data[folderTable] as List<dynamic>? ?? [];
          await AppLogService.info('ManifestDatabase',
              'getAllFolders completed [count=${list.length}]');
          return list.cast<String>();
        }
        // 无 recordTable 时合并所有四种类型的文件夹
        final all = <String>{};
        for (final ft in ManifestTables.allPerTypeFolderTables) {
          final list = data[ft] as List<dynamic>? ?? [];
          all.addAll(list.cast<String>());
        }
        await AppLogService.info('ManifestDatabase',
            'getAllFolders completed [count=${all.length}]');
        return all.toList();
      }
      final db = await database;
      if (recordTable != null) {
        final folderTable = ManifestTables.folderTableFor(recordTable);
        final rows = await db.query(folderTable);
        await AppLogService.info('ManifestDatabase',
            'getAllFolders completed [count=${rows.length}]');
        return rows.map((r) => r['path'] as String).toList();
      }
      // 无 recordTable 时合并所有四种类型的文件夹
      final all = <String>{};
      for (final ft in ManifestTables.allPerTypeFolderTables) {
        final rows = await db.query(ft);
        all.addAll(rows.map((r) => r['path'] as String));
      }
      await AppLogService.info(
          'ManifestDatabase', 'getAllFolders completed [count=${all.length}]');
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
    await AppLogService.info('ManifestDatabase',
        'insertFolder called [path=$path, recordTable=$recordTable]');
    try {
      if (recordTable == null) {
        throw ArgumentError('recordTable is required in v2+ format');
      }
      final folderTable = ManifestTables.folderTableFor(recordTable);
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[folderTable] as List<dynamic>? ?? [];
        if (!list.contains(path)) {
          list.add(path);
          await _saveWebData();
        }
        await AppLogService.info(
            'ManifestDatabase', 'insertFolder completed [path=$path]');
        return;
      }
      final db = await database;
      await db.insert(
        folderTable,
        {'path': path},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await AppLogService.info(
          'ManifestDatabase', 'insertFolder completed [path=$path]');
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
    await AppLogService.info('ManifestDatabase',
        'deleteFolder called [path=$path, recordTable=$recordTable]');
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
        await AppLogService.info(
            'ManifestDatabase', 'deleteFolder completed [path=$path]');
        return;
      }
      final db = await database;
      await db.delete(
        folderTable,
        where: 'path = ?',
        whereArgs: [path],
      );
      await AppLogService.info(
          'ManifestDatabase', 'deleteFolder completed [path=$path]');
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'deleteFolder failed [path=$path]', e, stackTrace);
      rethrow;
    }
  }

  /// 检查文件夹路径是否存在
  ///
  /// [recordTable] 必须指定，v2+ 格式不再使用共享 folders 表。
  static Future<bool> folderExists(String path, {String? recordTable}) async {
    await AppLogService.info('ManifestDatabase',
        'folderExists called [path=$path, recordTable=$recordTable]');
    try {
      if (recordTable == null) {
        throw ArgumentError('recordTable is required in v2+ format');
      }
      final folderTable = ManifestTables.folderTableFor(recordTable);
      if (_useJsonStore) {
        final data = await _loadWebData();
        final list = data[folderTable] as List<dynamic>? ?? [];
        final exists = list.contains(path);
        await AppLogService.info('ManifestDatabase',
            'folderExists completed [path=$path, exists=$exists]');
        return exists;
      }
      final db = await database;
      final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $folderTable WHERE path = ?',
        [path],
      ));
      final exists = (count ?? 0) > 0;
      await AppLogService.info('ManifestDatabase',
          'folderExists completed [path=$path, exists=$exists]');
      return exists;
    } catch (e, stackTrace) {
      await AppLogService.error('ManifestDatabase',
          'folderExists failed [path=$path]', e, stackTrace);
      rethrow;
    }
  }

  // ==================================================================
  // 工具方法
  // ==================================================================

  /// 清除所有数据（双模式通用）。
  ///
  /// 在 Native 模式下删除 SQLite 数据库文件；
  /// 在 Web / 测试模式下清除 WebFileStore 中的数据。
  static Future<void> clearAllData() async {
    await AppLogService.info('ManifestDatabase', 'clearAllData called');
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
      await AppLogService.info('ManifestDatabase', 'clearAllData completed');
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'clearAllData failed', e, stackTrace);
      rethrow;
    }
  }

  /// 关闭数据库连接（Native 端）
  static Future<void> close() async {
    await AppLogService.info('ManifestDatabase', 'close called');
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      _webData = null;
      await AppLogService.info('ManifestDatabase', 'close completed');
    } catch (e, stackTrace) {
      await AppLogService.error(
          'ManifestDatabase', 'close failed', e, stackTrace);
      rethrow;
    }
  }
}
