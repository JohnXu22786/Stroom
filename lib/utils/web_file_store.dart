import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:idb_shim/idb_shim.dart'
    show Database, Transaction, idbModeReadOnly, idbModeReadWrite;
import 'package:idb_shim/idb_browser.dart' show idbFactoryBrowser;

import 'web_file_store_blob_stub.dart'
    if (dart.library.js_interop) 'web_file_store_blob_web.dart' as blob_store;

class WebFileStoreReadLimitExceededException implements Exception {
  const WebFileStoreReadLimitExceededException(
    this.maxBytes, {
    this.headerBytes,
  });

  final int maxBytes;
  final Uint8List? headerBytes;
}

/// Web 端使用 IndexedDB 存储二进制文件
/// 突破 SharedPreferences 约 2MB 的存储上限
///
/// 也支持纯内存模式（测试用）：调用 [enableTestMode] 即可切换到
/// [Map]-based 存储，无需依赖 IndexedDB/浏览器环境。
class WebFileStore {
  static const String _attachmentPrefix = 'attachments/';
  static const String _editedAttachmentPrefix = 'temp_edited/';
  static const String _formatMarkerKey = '__web_file_store_format__';
  static const int _currentFormatVersion = 1;
  static Database? _db;
  static int _openCount = 0;
  static final List<Completer<void>> _pendingOpens = [];

  // ---- Test mode (in-memory storage, no IndexedDB dependency) ----------

  static bool _testMode = false;
  static final Map<String, Uint8List> _inMemoryStore = {};
  static Future<Uint8List?> Function(Object?)? readBlobOverrideForTesting;

  /// Enable in-memory test mode — all operations use a [Map] instead of
  /// IndexedDB.  Call before any read/write/delete/exists in tests.
  static void enableTestMode() {
    _testMode = true;
    _inMemoryStore.clear();
  }

  /// Reset test mode and clear stored data.
  static void disableTestMode() {
    _testMode = false;
    _inMemoryStore.clear();
  }

  /// Whether test mode is currently active.
  static bool get isTestMode => _testMode;

  @visibleForTesting
  static Future<Object?> waitForRequestAndTransactionCompletionForTesting(
    Future<Object?> request,
    Future<void> completed,
  ) =>
      _waitForRequestAndTransactionCompletion(request, completed);

  static Future<Object?> _waitForRequestAndTransactionCompletion(
    Future<Object?> request,
    Future<void> completed,
  ) async {
    final results = await Future.wait<Object?>([
      request,
      completed.then<Object?>((_) => null),
    ], eagerError: false);
    return results.first;
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
  static Future<void> write(
    String key,
    Uint8List data, {
    void Function()? beforeCommit,
  }) async {
    if (_testMode) {
      beforeCommit?.call();
      _inMemoryStore[key] = Uint8List.fromList(data);
      return;
    }
    final db = await _database;
    if (beforeCommit == null) {
      final txn = db.transaction('files', idbModeReadWrite);
      await txn.objectStore('files').put(_storedValue(key, data), key);
      await txn.completed;
      return;
    }
    beforeCommit();
    final txn = db.transaction('files', idbModeReadWrite);
    // Observe abort errors before issuing the write.
    final completed = txn.completed;
    try {
      await txn.objectStore('files').put(_storedValue(key, data), key);
      beforeCommit();
      await completed;
    } catch (_) {
      try {
        txn.abort();
      } catch (_) {}
      try {
        await completed;
      } catch (_) {}
      rethrow;
    }
  }

  static bool _isAttachmentKey(String key) =>
      key.startsWith(_attachmentPrefix) ||
      key.startsWith(_editedAttachmentPrefix);

  static Object _storedValue(String key, Uint8List data) =>
      _isAttachmentKey(key) && !_testMode ? blob_store.createBlob(data) : data;

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

  static int _prefixLength(int length, int maxBytes) =>
      length < maxBytes ? length : maxBytes;

  static Uint8List? _prefixBytes(dynamic value, int maxBytes) =>
      switch (value) {
        Uint8List bytes => Uint8List.fromList(Uint8List.sublistView(
            bytes,
            0,
            _prefixLength(bytes.length, maxBytes),
          )),
        ByteBuffer buffer => Uint8List.fromList(Uint8List.view(
            buffer,
            0,
            _prefixLength(buffer.lengthInBytes, maxBytes),
          )),
        TypedData data => Uint8List.fromList(Uint8List.view(
            data.buffer,
            data.offsetInBytes,
            _prefixLength(data.lengthInBytes, maxBytes),
          )),
        List<int> bytes => Uint8List.fromList(bytes.take(maxBytes).toList()),
        _ => null,
      };

  /// Reads only the first [maxBytes] of a stored value, allowing callers to
  /// classify a Blob before selecting its full-read limit.
  static Future<Uint8List?> readPrefix(
    String key, {
    required int maxBytes,
  }) async {
    if (maxBytes < 0) throw ArgumentError.value(maxBytes, 'maxBytes');
    if (maxBytes == 0) return Uint8List(0);
    if (_testMode) return _prefixBytes(_inMemoryStore[key], maxBytes);

    final db = await _database;
    final Object? value;
    if (_isAttachmentKey(key)) {
      final txn = db.transaction('files', idbModeReadOnly);
      value = await txn.objectStore('files').getObject(key);
      await txn.completed;
    } else {
      final txn = db.transaction('files', idbModeReadOnly);
      value = await txn.objectStore('files').getObject(key);
      await txn.completed;
    }
    if (value == null) return null;
    return await blob_store.readBlobPrefix(value, maxBytes) ??
        _prefixBytes(value, maxBytes);
  }

  static Future<void> _checkReadLimit(dynamic value, int? maxBytes) async {
    if (maxBytes == null) return;
    final byteLength = switch (value) {
      _ when blob_store.isBlob(value) => blob_store.blobByteLength(value),
      ByteBuffer buffer => buffer.lengthInBytes,
      TypedData data => data.lengthInBytes,
      List<int> bytes => bytes.length,
      _ => null,
    };
    if (byteLength != null && byteLength > maxBytes) {
      final headerBytes =
          await blob_store.readBlobPrefix(value, 32) ?? _prefixBytes(value, 32);
      throw WebFileStoreReadLimitExceededException(
        maxBytes,
        headerBytes: headerBytes,
      );
    }
  }

  static Future<Uint8List?> _readBlob(Object? value) =>
      readBlobOverrideForTesting?.call(value) ?? blob_store.readBlob(value);

  static Future<Uint8List?> _readBlobCancellable(
    Object? value,
    CancelToken cancelToken,
  ) {
    final override = readBlobOverrideForTesting;
    if (override != null) return override(value);
    return blob_store.readBlobCancellable(
      value,
      cancelToken.whenCancel.then<void>((_) {}),
    );
  }

  /// 读取文件
  static Future<Uint8List?> read(String key, {int? maxBytes}) async {
    if (_testMode) {
      final val = _inMemoryStore[key];
      await _checkReadLimit(val, maxBytes);
      return val != null ? Uint8List.fromList(val) : null;
    }
    final db = await _database;
    if (_isAttachmentKey(key)) {
      if (maxBytes != null) {
        final txn = db.transaction('files', idbModeReadOnly);
        final value = await txn.objectStore('files').getObject(key);
        await txn.completed;
        if (value == null) return null;
        await _checkReadLimit(value, maxBytes);
        final blobBytes = await _readBlob(value);
        if (blobBytes != null) return blobBytes;
        return _toUint8List(value, key);
      }
      final txn = db.transaction('files', idbModeReadWrite);
      final result = await blob_store.migrateStoredValueToBlob(
        txn.objectStore('files'),
        key,
      );
      await txn.completed;
      await _checkReadLimit(result.value, maxBytes);
      return await _readBlob(result.value);
    }
    final txn = db.transaction('files', idbModeReadOnly);
    final result = await txn.objectStore('files').getObject(key);
    await txn.completed;

    if (result == null) {
      debugPrint('WebFileStore 读取 $key → null (键不存在)');
      return null;
    }

    await _checkReadLimit(result, maxBytes);
    if (_isAttachmentKey(key) && !blob_store.isBlob(result)) {
      throw StateError(
        'Attachment storage format migration has not completed for $key',
      );
    }
    final blobBytes = await blob_store.readBlob(result);
    if (blobBytes != null) return blobBytes;
    final converted = _toUint8List(result, key);
    await _checkReadLimit(converted, maxBytes);
    if (converted == null) {
      debugPrint(
        'WebFileStore 读取 $key → 原始类型: ${result.runtimeType} (值: $result)',
      );
    }
    return converted;
  }

  /// Reads an ASR source while allowing cancellation to abort an IndexedDB
  /// transaction before the stored value is materialized in Dart memory.
  static Future<Uint8List?> readCancellable(
    String key, {
    required CancelToken cancelToken,
  }) async {
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    if (_testMode) return read(key);
    final db = await _database;
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    final transaction = db.transaction(
      'files',
      _isAttachmentKey(key) ? idbModeReadWrite : idbModeReadOnly,
    );
    final completed = transaction.completed;
    final request = _isAttachmentKey(key)
        ? blob_store
            .migrateStoredValueToBlob(transaction.objectStore('files'), key)
            .then<Object?>((result) => result.value)
        : transaction.objectStore('files').getObject(key);
    unawaited(
      cancelToken.whenCancel.then<void>((_) {
        try {
          transaction.abort();
        } catch (_) {
          // The transaction may have completed just before cancellation.
        }
      }),
    );
    try {
      final value = await _waitForRequestAndTransactionCompletion(
        request,
        completed,
      );
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      if (_isAttachmentKey(key)) {
        final bytes = await Future.any<Uint8List?>([
          _readBlobCancellable(value, cancelToken),
          cancelToken.whenCancel.then<Uint8List?>(
            (_) => throw cancelToken.cancelError!,
          ),
        ]);
        if (cancelToken.isCancelled) throw cancelToken.cancelError!;
        return bytes;
      }
      return _toUint8List(value, key);
    } catch (_) {
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      rethrow;
    }
  }

  /// Upgrades legacy attachment byte arrays to IndexedDB Blobs. Blob.size is
  /// available without reading its payload, so later bounded reads can reject
  /// oversized attachments before allocating their bytes in Dart memory.
  /// Returns true when the format was migrated. Partial runs are safe to retry:
  /// each converted value is committed independently and the marker is last.
  static Future<bool> migrateAttachmentValuesToBlobs() async {
    if (_testMode) return false;
    final db = await _database;
    final checkTxn = db.transaction('files', idbModeReadOnly);
    final marker =
        await checkTxn.objectStore('files').getObject(_formatMarkerKey);
    await checkTxn.completed;
    if (marker == _currentFormatVersion) return false;

    final keyTxn = db.transaction('files', idbModeReadOnly);
    final keys = <String>[];
    await for (final cursor
        in keyTxn.objectStore('files').openCursor(autoAdvance: true)) {
      if (cursor.key is String && _isAttachmentKey(cursor.key as String)) {
        keys.add(cursor.key as String);
      }
    }
    await keyTxn.completed;

    var convertedAny = false;
    for (final key in keys) {
      final txn = db.transaction('files', idbModeReadWrite);
      final store = txn.objectStore('files');
      try {
        final result = await blob_store.migrateStoredValueToBlob(store, key);
        convertedAny |= result.converted;
        await txn.completed;
      } catch (_) {
        await _abortTransaction(txn);
        rethrow;
      }
    }

    final markerTxn = db.transaction('files', idbModeReadWrite);
    await markerTxn
        .objectStore('files')
        .put(_currentFormatVersion, _formatMarkerKey);
    await markerTxn.completed;
    return convertedAny;
  }

  static Future<void> _abortTransaction(Transaction transaction) async {
    try {
      transaction.abort();
    } catch (_) {}
    try {
      await transaction.completed;
    } catch (_) {}
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
