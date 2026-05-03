import 'dart:async';
import 'dart:typed_data';
import 'package:idb_shim/idb_shim.dart' show Database, idbModeReadOnly, idbModeReadWrite;
import 'package:idb_shim/idb_browser.dart' show idbFactoryBrowser;

/// Web 端使用 IndexedDB 存储二进制文件
/// 突破 SharedPreferences 约 2MB 的存储上限
class WebFileStore {
  static Database? _db;
  static int _openCount = 0;
  static final List<Completer<void>> _pendingOpens = [];

  static Future<Database> get _database async {
    if (_db != null) return _db!;

    if (_openCount > 0) {
      final completer = Completer<void>();
      _pendingOpens.add(completer);
      await completer.future;
      return _db!;
    }

    _openCount++;
    try {
      _db = await idbFactoryBrowser.open(
        'stroom_file_store',
        version: 1,
        onUpgradeNeeded: (event) {
          if (event.oldVersion < 1) {
            final db = event.transaction.database;
            db.createObjectStore('files');
          }
        },
      );
    } finally {
      _openCount--;
    }

    for (final c in _pendingOpens) {
      c.complete();
    }
    _pendingOpens.clear();

    return _db!;
  }

  /// 写入文件
  static Future<void> write(String key, Uint8List data) async {
    final db = await _database;
    final txn = db.transaction('files', idbModeReadWrite);
    await txn.objectStore('files').put(data, key);
    await txn.completed;
  }

  /// 读取文件
  static Future<Uint8List?> read(String key) async {
    final db = await _database;
    final txn = db.transaction('files', idbModeReadOnly);
    final result = await txn.objectStore('files').getObject(key);
    await txn.completed;
    if (result is Uint8List) return result;
    return null;
  }

  /// 删除文件
  static Future<void> delete(String key) async {
    final db = await _database;
    final txn = db.transaction('files', idbModeReadWrite);
    await txn.objectStore('files').delete(key);
    await txn.completed;
  }

  /// 检查文件是否存在
  static Future<bool> exists(String key) async {
    final db = await _database;
    final txn = db.transaction('files', idbModeReadOnly);
    final count = await txn.objectStore('files').count(key);
    await txn.completed;
    return count > 0;
  }
}
