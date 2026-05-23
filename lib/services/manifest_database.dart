import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/web_file_store.dart';

// WebFileStore 没有 readString / writeString，在此扩展
String _utf8Decode(Uint8List data) => utf8.decode(data);
Uint8List _utf8Encode(String text) => Uint8List.fromList(utf8.encode(text));

// ====================================================================
// ManifestDatabase — SQLite 存储服务
// ====================================================================
//
// 单例模式，管理 manifest 元数据（图片记录、音频记录、文件夹路径）。
// - Native（Android / iOS / macOS / Linux / Windows）：使用 sqflite
// - Web：使用 WebFileStore（IndexedDB）存储 JSON 数据，规避 SharedPreferences 的 2MB 上限
// ====================================================================

/// 数据库表名常量
class ManifestTables {
  static const String imageRecords = 'image_records';
  static const String audioRecords = 'audio_records';
  static const String videoRecords = 'video_records';
  static const String folders = 'folders';
}

class ManifestDatabase {
  ManifestDatabase._(); // 私有构造，禁止实例化

  static Database? _database;

  /// Test mode: use JSON/in-memory storage instead of SQLite.
  /// Enables unit testing without sqflite native bindings.
  static bool _useInMemoryStorage = false;

  /// Enable test mode — all operations use in-memory JSON storage
  /// (same code path as web), avoiding sqflite native dependencies.
  static void enableTestMode() {
    _useInMemoryStorage = true;
    _webData = null;
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
      version: 2,
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
          CREATE TABLE IF NOT EXISTS folders (
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
            // 列可能已存在，忽略
          }
        }
      },
    );
    await _migrateOldVideoRecords(db);
    return db;
  }

  static Future<void> _migrateOldVideoRecords(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('migrated_video_records') == true) return;
    final videoFormats = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv', 'm4v', '3gp', 'gif'];
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
    if (prefs.getBool('migrated_video_records') == true) return;
    final audioList = _webData![ManifestTables.audioRecords] as List<dynamic>? ?? [];
    final videoList = _webData![ManifestTables.videoRecords] as List<dynamic>? ?? [];
    if (videoList.isNotEmpty) {
      await prefs.setBool('migrated_video_records', true);
      return;
    }
    final videoFormats = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv', 'm4v', '3gp', 'gif'};
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

  // ==================================================================
  // Web 端数据加载与持久化（全量 JSON 通过 WebFileStore）
  // ==================================================================

  static Future<Map<String, dynamic>> _loadWebData() async {
    if (_webData != null) return _webData!;

    try {
      final raw = await WebFileStore.read(_webStoreKey);
      if (raw != null && raw.isNotEmpty) {
        final text = _utf8Decode(raw);
        _webData = jsonDecode(text) as Map<String, dynamic>;
      } else {
        _webData = _emptyWebData();
      }
    } catch (e) {
      debugPrint('ManifestDatabase._loadWebData error: $e');
      _webData = _emptyWebData();
    }
    await _migrateOldVideoRecordsJson();
    return _webData!;
  }

  static Future<void> _saveWebData() async {
    if (_webData == null) return;
    try {
      final json = jsonEncode(_webData);
      await WebFileStore.write(_webStoreKey, _utf8Encode(json));
    } catch (e) {
      debugPrint('ManifestDatabase._saveWebData error: $e');
    }
  }

  static Map<String, dynamic> _emptyWebData() => {
        ManifestTables.imageRecords: <Map<String, dynamic>>[],
        ManifestTables.audioRecords: <Map<String, dynamic>>[],
        ManifestTables.videoRecords: <Map<String, dynamic>>[],
        ManifestTables.folders: <String>[],
      };

  // ==================================================================
  // 辅助方法：Map 转换
  // ==================================================================

  /// Dart camelCase → DB snake_case（列名映射表）
  static const Map<String, String> _camelToSnake = {
    'createdAt': 'created_at',
    'sourceText': 'source_text',
  };

  /// DB snake_case → Dart camelCase（列名映射表）
  static const Map<String, String> _snakeToCamel = {
    'created_at': 'createdAt',
    'source_text': 'sourceText',
  };

  /// 将 record 的 Map（fromMap 格式，camelCase 键名）转为 DB 行格式（snake_case）
  static Map<String, dynamic> _recordToDbRow(Map<String, dynamic> record) {
    final row = <String, dynamic>{};
    for (final entry in record.entries) {
      final dbKey = _camelToSnake[entry.key] ?? entry.key;
      var value = entry.value;
      // 转换 createdAt: ISO 字符串 → 毫秒时间戳
      if (dbKey == 'created_at' && value is String) {
        value = DateTime.parse(value).millisecondsSinceEpoch;
      }
      row[dbKey] = value;
    }
    return row;
  }

  /// 将 DB 行格式（snake_case）转为 record 的 Map（camelCase）
  static Map<String, dynamic> _dbRowToRecord(Map<String, dynamic> row) {
    final record = <String, dynamic>{};
    for (final entry in row.entries) {
      final recordKey = _snakeToCamel[entry.key] ?? entry.key;
      var value = entry.value;
      // 转换 created_at: 毫秒时间戳 → ISO 字符串
      if (entry.key == 'created_at' && value is int) {
        value = DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
      }
      record[recordKey] = value;
    }
    return record;
  }

  // ==================================================================
  // Image record operations
  // ==================================================================

  /// 获取所有图片记录
  static Future<List<Map<String, dynamic>>> getAllImageRecords() async {
    if (_useJsonStore) {
      final data = await _loadWebData();
      final list = data[ManifestTables.imageRecords] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    final db = await database;
    final rows = await db.query(ManifestTables.imageRecords);
    return rows.map(_dbRowToRecord).toList();
  }

  /// 插入一条图片记录
  static Future<void> insertImageRecord(Map<String, dynamic> record) async {
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
      _recordToDbRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新一条图片记录
  static Future<void> updateImageRecord(
      String id, Map<String, dynamic> updates) async {
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
      _recordToDbRow(updates),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除一条图片记录
  static Future<void> deleteImageRecord(String id) async {
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
  }

  /// 批量删除图片记录
  static Future<void> deleteImageRecords(List<String> ids) async {
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
  }

  // ==================================================================
  // Audio record operations
  // ==================================================================

  /// 获取所有音频记录
  static Future<List<Map<String, dynamic>>> getAllAudioRecords() async {
    if (_useJsonStore) {
      final data = await _loadWebData();
      final list = data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    final db = await database;
    final rows = await db.query(ManifestTables.audioRecords);
    return rows.map(_dbRowToRecord).toList();
  }

  /// 插入一条音频记录
  static Future<void> insertAudioRecord(Map<String, dynamic> record) async {
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
      _recordToDbRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新一条音频记录
  static Future<void> updateAudioRecord(
      String id, Map<String, dynamic> updates) async {
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
      _recordToDbRow(updates),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除一条音频记录
  static Future<void> deleteAudioRecord(String id) async {
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
  }

  /// 批量删除音频记录
  static Future<void> deleteAudioRecords(List<String> ids) async {
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
  }

  // ==================================================================
  // Video record operations
  // ==================================================================

  /// 获取所有视频记录
  static Future<List<Map<String, dynamic>>> getAllVideoRecords() async {
    if (_useJsonStore) {
      final data = await _loadWebData();
      final list = data[ManifestTables.videoRecords] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    final db = await database;
    final rows = await db.query(ManifestTables.videoRecords);
    return rows.map(_dbRowToRecord).toList();
  }

  /// 插入一条视频记录
  static Future<void> insertVideoRecord(Map<String, dynamic> record) async {
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
      _recordToDbRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新一条视频记录
  static Future<void> updateVideoRecord(
      String id, Map<String, dynamic> updates) async {
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
      _recordToDbRow(updates),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除一条视频记录
  static Future<void> deleteVideoRecord(String id) async {
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
  }

  /// 批量删除视频记录
  static Future<void> deleteVideoRecords(List<String> ids) async {
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
  }

  /// 获取单条音频记录
  static Future<Map<String, dynamic>?> getAudioRecord(String id) async {
    if (_useJsonStore) {
      final data = await _loadWebData();
      final list = data[ManifestTables.audioRecords] as List<dynamic>? ?? [];
      for (final r in list) {
        final map = r as Map<String, dynamic>;
        if (map['id'] == id) return map;
      }
      return null;
    }
    final db = await database;
    final rows = await db.query(
      ManifestTables.audioRecords,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _dbRowToRecord(rows.first);
  }

  // ==================================================================
  // Folder operations
  // ==================================================================

  /// 获取所有文件夹路径
  static Future<List<String>> getAllFolders() async {
    if (_useJsonStore) {
      final data = await _loadWebData();
      final list = data[ManifestTables.folders] as List<dynamic>? ?? [];
      return list.cast<String>();
    }
    final db = await database;
    final rows = await db.query(ManifestTables.folders);
    return rows.map((r) => r['path'] as String).toList();
  }

  /// 插入一个文件夹路径
  static Future<void> insertFolder(String path) async {
    if (_useJsonStore) {
      final data = await _loadWebData();
      final list = data[ManifestTables.folders] as List<dynamic>? ?? [];
      if (!list.contains(path)) {
        list.add(path);
        await _saveWebData();
      }
      return;
    }
    final db = await database;
    await db.insert(
      ManifestTables.folders,
      {'path': path},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 删除一个文件夹路径
  static Future<void> deleteFolder(String path) async {
    if (_useJsonStore) {
      final data = await _loadWebData();
      final list = data[ManifestTables.folders] as List<dynamic>? ?? [];
      list.remove(path);
      await _saveWebData();
      return;
    }
    final db = await database;
    await db.delete(
      ManifestTables.folders,
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  /// 检查文件夹路径是否存在
  static Future<bool> folderExists(String path) async {
    if (_useJsonStore) {
      final data = await _loadWebData();
      final list = data[ManifestTables.folders] as List<dynamic>? ?? [];
      return list.contains(path);
    }
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM folders WHERE path = ?',
      [path],
    ));
    return (count ?? 0) > 0;
  }

  // ==================================================================
  // 工具方法
  // ==================================================================

  /// 清除所有数据（双模式通用）。
  ///
  /// 在 Native 模式下删除 SQLite 数据库文件；
  /// 在 Web / 测试模式下清除 WebFileStore 中的数据。
  static Future<void> clearAllData() async {
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
  }

  /// 关闭数据库连接（Native 端）
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _webData = null;
  }
}
