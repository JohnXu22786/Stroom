import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
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

    // 写入后验证：立即回读，确认数据已实际持久化
    final verify = await read(key);
    if (verify == null) {
      debugPrint('WebFileStore 写入验证失败: $key → 回读为 null');
    } else if (verify.length != data.length) {
      debugPrint('WebFileStore 写入验证失败: $key → 期望 ${data.length} 字节, 实际 ${verify.length} 字节');
    } else {
      debugPrint('WebFileStore 写入验证通过: $key (${data.length} 字节)');
    }
  }

  /// 将 IndexedDB 读回的任意类型尽量转为 Uint8List
  static Uint8List? _toUint8List(dynamic value, String key) {
    if (value == null) return null;

    // 最常见：已经是 Uint8List
    if (value is Uint8List) {
      if (value.isEmpty) {
        debugPrint('WebFileStore _toUint8List: $key → Uint8List 长度为 0');
      }
      return value;
    }

    // ByteBuffer (如 ArrayBuffer) → 新建 Uint8List 视图
    if (value is ByteBuffer) {
      final result = Uint8List.view(value);
      debugPrint('WebFileStore _toUint8List: $key → ByteBuffer (${result.length} 字节)');
      return result;
    }

    // Int8List → 转 Uint8List (视图共享)
    if (value is Int8List) {
      final result = Uint8List.view(value.buffer, value.offsetInBytes, value.length);
      debugPrint('WebFileStore _toUint8List: $key → Int8List -> Uint8List (${result.length} 字节)');
      return result;
    }

    // Uint16List / Uint32List / Int16List / Int32List / Float32List / Float64List
    // → 取其底层 buffer 的字节视图
    if (value is TypedData) {
      final result = Uint8List.view(value.buffer, value.offsetInBytes, value.lengthInBytes);
      debugPrint('WebFileStore _toUint8List: $key → ${value.runtimeType} -> Uint8List (${result.length} 字节)');
      return result;
    }

    // List<int> → 逐字节拷贝
    if (value is List<int>) {
      final result = Uint8List.fromList(value);
      debugPrint('WebFileStore _toUint8List: $key → List<int> (${result.length} 字节)');
      return result;
    }

    // 兜底：toString 留日志
    debugPrint('WebFileStore _toUint8List: $key → 无法转换的类型 ${value.runtimeType}');
    return null;
  }

  /// 读取文件
  static Future<Uint8List?> read(String key) async {
    final db = await _database;
    final txn = db.transaction('files', idbModeReadOnly);
    final result = await txn.objectStore('files').getObject(key);
    await txn.completed;

    if (result == null) {
      debugPrint('WebFileStore 读取 $key → null (键不存在)');
      return null;
    }

    final converted = _toUint8List(result, key);
    if (converted == null) {
      debugPrint('WebFileStore 读取 $key → 原始类型: ${result.runtimeType} (值: $result)');
    }
    return converted;
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
