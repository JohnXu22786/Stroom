import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:idb_shim/idb_shim.dart'
    show Database, idbModeReadOnly, idbModeReadWrite;
import 'package:idb_shim/idb_browser.dart' show idbFactoryBrowser;

/// Web 端使用 IndexedDB 存储二进制文件
/// 突破 SharedPreferences 约 2MB 的存储上限
///
/// 也支持纯内存模式（测试用）：调用 [enableTestMode] 即可切换到
/// [Map]-based 存储，无需依赖 IndexedDB/浏览器环境。
class WebFileStore {
  static Database? _db;
  static int _openCount = 0;
  static final List<Completer<void>> _pendingOpens = [];

  // ---- Test mode (in-memory storage, no IndexedDB dependency) ----------

  static bool _testMode = false;
  static final Map<String, Uint8List> _inMemoryStore = {};
  static Future<void> _testMutationQueue = Future<void>.value();
  static int _pendingTestMutations = 0;
  static Object? _nextTestTransformError;

  static Future<T> _serializeTestMutation<T>(T Function() operation) async {
    final shouldWait = _pendingTestMutations > 0;
    final previous = _testMutationQueue;
    final release = Completer<void>();
    _testMutationQueue = release.future;
    _pendingTestMutations++;
    if (shouldWait) await previous;
    try {
      return operation();
    } finally {
      _pendingTestMutations--;
      release.complete();
    }
  }

  /// Enable in-memory test mode — all operations use a [Map] instead of
  /// IndexedDB.  Call before any read/write/delete/exists in tests.
  static void enableTestMode() {
    _testMode = true;
    _inMemoryStore.clear();
    _testMutationQueue = Future<void>.value();
    _pendingTestMutations = 0;
    _nextTestTransformError = null;
  }

  /// Reset test mode and clear stored data.
  static void disableTestMode() {
    _testMode = false;
    _inMemoryStore.clear();
    _testMutationQueue = Future<void>.value();
    _pendingTestMutations = 0;
    _nextTestTransformError = null;
  }

  /// Whether test mode is currently active.
  static bool get isTestMode => _testMode;

  /// Makes the next in-memory [transform] that writes fail before commit.
  @visibleForTesting
  static void failNextTransformForTesting(Object error) {
    if (!_testMode) throw StateError('WebFileStore test mode is not active.');
    _nextTestTransformError = error;
  }

  // ---- IndexedDB database ------------------------------------------------

  static Future<Database> get _database async {
    if (_testMode) {
      throw StateError('_database should not be called in test mode');
    }
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
    } catch (e) {
      // Open failed — fail the waiters instead of leaving them hanging.
      for (final c in _pendingOpens) {
        c.completeError(e);
      }
      _pendingOpens.clear();
      rethrow;
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
    if (_testMode) {
      _inMemoryStore[key] = Uint8List.fromList(data);
      return;
    }
    final db = await _database;
    final txn = db.transaction('files', idbModeReadWrite);
    await txn.objectStore('files').put(data, key);
    await txn.completed;
  }

  /// Atomically transforms one stored value, returning `null` to leave it
  /// unchanged. IndexedDB read-write transactions serialize this operation
  /// across browser tabs; the in-memory implementation mirrors that behavior
  /// for tests.
  static Future<Uint8List?> transform(
    String key,
    Uint8List? Function(Uint8List? current) transform,
  ) async {
    if (_testMode) {
      return _serializeTestMutation(() {
        final current = _inMemoryStore[key];
        final updated = transform(
          current == null ? null : Uint8List.fromList(current),
        );
        if (updated != null) {
          final error = _nextTestTransformError;
          _nextTestTransformError = null;
          if (error != null) throw error;
          _inMemoryStore[key] = Uint8List.fromList(updated);
        }
        return updated;
      });
    }

    final db = await _database;
    final txn = db.transaction('files', idbModeReadWrite);
    final store = txn.objectStore('files');
    try {
      final stored = await store.getObject(key);
      final updated = transform(_toUint8List(stored, key));
      if (updated != null) await store.put(updated, key);
      await txn.completed;
      return updated;
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {
        // Preserve the original read, transform, or write error.
      }
      rethrow;
    }
  }

  /// Writes [writeData] and transforms [transformKey] in one read-write
  /// transaction. A `null` transform result commits neither change.
  static Future<Uint8List?> transformAndWrite({
    required String transformKey,
    required String writeKey,
    required Uint8List writeData,
    required Uint8List? Function(Uint8List? current) transform,
  }) async {
    if (_testMode) {
      return _serializeTestMutation(() {
        final current = _inMemoryStore[transformKey];
        final updated = transform(
          current == null ? null : Uint8List.fromList(current),
        );
        if (updated == null) return null;
        final error = _nextTestTransformError;
        _nextTestTransformError = null;
        if (error != null) throw error;
        _inMemoryStore[writeKey] = Uint8List.fromList(writeData);
        _inMemoryStore[transformKey] = Uint8List.fromList(updated);
        return updated;
      });
    }

    final db = await _database;
    final txn = db.transaction('files', idbModeReadWrite);
    final store = txn.objectStore('files');
    try {
      final stored = await store.getObject(transformKey);
      final updated = transform(_toUint8List(stored, transformKey));
      if (updated == null) {
        await txn.completed;
        return null;
      }
      await store.put(writeData, writeKey);
      await store.put(updated, transformKey);
      await txn.completed;
      return updated;
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {
        // Preserve the original read, transform, or write error.
      }
      rethrow;
    }
  }

  /// Deletes [deleteKey] only when an atomic read of [readKey] satisfies
  /// [shouldDelete]. Both operations share one IndexedDB read-write
  /// transaction so another tab cannot add a reference between the check and
  /// deletion.
  static Future<bool> deleteIf({
    required String readKey,
    required String deleteKey,
    required bool Function(Uint8List? value) shouldDelete,
  }) async {
    if (_testMode) {
      return _serializeTestMutation(() {
        final stored = _inMemoryStore[readKey];
        final current = stored == null ? null : Uint8List.fromList(stored);
        if (!shouldDelete(current)) return false;
        _inMemoryStore.remove(deleteKey);
        return true;
      });
    }

    final db = await _database;
    final txn = db.transaction('files', idbModeReadWrite);
    final store = txn.objectStore('files');
    try {
      final stored = await store.getObject(readKey);
      final current = _toUint8List(stored, readKey);
      if (!shouldDelete(current)) {
        await txn.completed;
        return false;
      }
      await store.delete(deleteKey);
      await txn.completed;
      return true;
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {
        // Preserve the original read, predicate, or delete error.
      }
      rethrow;
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
      debugPrint(
        'WebFileStore _toUint8List: $key → ByteBuffer (${result.length} 字节)',
      );
      return result;
    }

    // Int8List → 转 Uint8List (视图共享)
    if (value is Int8List) {
      final result = Uint8List.view(
        value.buffer,
        value.offsetInBytes,
        value.length,
      );
      debugPrint(
        'WebFileStore _toUint8List: $key → Int8List -> Uint8List (${result.length} 字节)',
      );
      return result;
    }

    // Uint16List / Uint32List / Int16List / Int32List / Float32List / Float64List
    // → 取其底层 buffer 的字节视图
    if (value is TypedData) {
      final result = Uint8List.view(
        value.buffer,
        value.offsetInBytes,
        value.lengthInBytes,
      );
      debugPrint(
        'WebFileStore _toUint8List: $key → ${value.runtimeType} -> Uint8List (${result.length} 字节)',
      );
      return result;
    }

    // List<int> → 逐字节拷贝
    if (value is List<int>) {
      final result = Uint8List.fromList(value);
      debugPrint(
        'WebFileStore _toUint8List: $key → List<int> (${result.length} 字节)',
      );
      return result;
    }

    // 兜底：toString 留日志
    debugPrint(
      'WebFileStore _toUint8List: $key → 无法转换的类型 ${value.runtimeType}',
    );
    return null;
  }

  /// 读取文件
  static Future<Uint8List?> read(String key) async {
    if (_testMode) {
      final val = _inMemoryStore[key];
      return val != null ? Uint8List.fromList(val) : null;
    }
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
      debugPrint(
        'WebFileStore 读取 $key → 原始类型: ${result.runtimeType} (值: $result)',
      );
    }
    return converted;
  }

  /// Reads a stored value only when its byte length is within [maxBytes].
  static Future<Uint8List?> readLimited(String key, int maxBytes) async {
    if (_testMode) {
      final value = _inMemoryStore[key];
      if (value == null) return null;
      if (value.lengthInBytes > maxBytes) {
        throw StoredFileSizeLimitExceeded(maxBytes);
      }
      return Uint8List.fromList(value);
    }

    final db = await _database;
    final txn = db.transaction('files', idbModeReadOnly);
    final value = await txn.objectStore('files').getObject(key);
    await txn.completed;
    if (value == null) return null;

    final length = _storedValueLength(value);
    if (length != null && length > maxBytes) {
      throw StoredFileSizeLimitExceeded(maxBytes);
    }
    final converted = _toUint8List(value, key);
    if (converted != null && converted.lengthInBytes > maxBytes) {
      throw StoredFileSizeLimitExceeded(maxBytes);
    }
    return converted;
  }

  static int? _storedValueLength(dynamic value) {
    if (value is Uint8List) return value.lengthInBytes;
    if (value is ByteBuffer) return value.lengthInBytes;
    if (value is TypedData) return value.lengthInBytes;
    if (value is List<int>) return value.length;
    try {
      final length = (value as dynamic).size;
      if (length is num) return length.toInt();
    } catch (_) {
      // Unknown IndexedDB values are handled by the regular conversion path.
    }
    return null;
  }

  /// 删除文件
  static Future<void> delete(String key) async {
    if (_testMode) {
      _inMemoryStore.remove(key);
      return;
    }
    final db = await _database;
    final txn = db.transaction('files', idbModeReadWrite);
    await txn.objectStore('files').delete(key);
    await txn.completed;
  }

  /// 检查文件是否存在
  static Future<bool> exists(String key) async {
    if (_testMode) {
      return _inMemoryStore.containsKey(key);
    }
    final db = await _database;
    final txn = db.transaction('files', idbModeReadOnly);
    final count = await txn.objectStore('files').count(key);
    await txn.completed;
    return count > 0;
  }

  /// Lists stored file keys under [prefix].
  ///
  /// Manual backup uses this to include app-managed files that are not
  /// currently referenced by a manifest record. Website storage owned by the
  /// embedded browser is separate from this store and is not exposed here.
  static Future<List<String>> keysWithPrefix(String prefix) async {
    if (_testMode) {
      return _inMemoryStore.keys
          .where((key) => key.startsWith(prefix))
          .toList(growable: false);
    }

    final db = await _database;
    final txn = db.transaction('files', idbModeReadOnly);
    final keys = <String>[];
    await for (final cwv
        in txn.objectStore('files').openCursor(autoAdvance: true)) {
      final key = cwv.key;
      if (key is String && key.startsWith(prefix)) keys.add(key);
    }
    await txn.completed;
    return keys;
  }

  /// 删除所有以 [prefix] 开头的文件（如 `'attachments/'`）。
  ///
  /// 用于清除/恢复场景中按目录前缀清理文件（Web 端没有目录结构，
  /// 文件 key 即存储路径）。
  static Future<void> deleteByPrefix(String prefix) async {
    await deleteByPrefixExcept(prefix, const <String>{});
  }

  /// Deletes files under [prefix], except keys still referenced by another
  /// data category.
  static Future<void> deleteByPrefixExcept(
    String prefix,
    Set<String> preservedKeys,
  ) async {
    bool shouldDelete(String key) =>
        key.startsWith(prefix) && !preservedKeys.contains(key);

    if (_testMode) {
      _inMemoryStore.removeWhere((key, _) => shouldDelete(key));
      return;
    }
    final db = await _database;
    final txn = db.transaction('files', idbModeReadWrite);
    final store = txn.objectStore('files');
    await for (final cwv in store.openCursor(autoAdvance: true)) {
      if (cwv.key is String && shouldDelete(cwv.key as String)) {
        await cwv.delete();
      }
    }
    await txn.completed;
  }
}

class StoredFileSizeLimitExceeded implements Exception {
  final int maxBytes;

  const StoredFileSizeLimitExceeded(this.maxBytes);
}
