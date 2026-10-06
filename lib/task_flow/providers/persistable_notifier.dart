import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../../services/storage_service.dart';
import '../../utils/atomic_file.dart';

mixin PersistableNotifier<T> on StateNotifier<T> {
  String get persistenceFileName;

  T fromJsonList(List<dynamic> json);

  List<dynamic> toJsonList(T state);

  Future<bool> _pendingPersistence = Future<bool>.value(true);
  Object? _persistenceError;

  /// Result of the latest requested write, including background writes.
  Future<bool> get persistenceResult => _pendingPersistence;

  /// Last write failure, cleared after a successful retry.
  Object? get persistenceError => _persistenceError;

  Future<File> _dataFile() async {
    final appDir = await AppStorage.directory;
    final dir = Directory(p.join(appDir, 'task_flows'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, persistenceFileName));
  }

  /// Queue this state snapshot and report whether it reached disk.
  /// Failed writes keep the in-memory state and do not block later retries.
  Future<bool> persist() => _encodeAndPersist(() => state);

  /// Queue an owned snapshot without reading notifier state after an await.
  Future<bool> persistSnapshot(T snapshot) => _encodeAndPersist(() => snapshot);

  /// Queue a snapshot whose value is only final after [barrier] completes.
  /// The resulting write is visible through [persistenceResult] immediately.
  Future<bool> persistSnapshotAfter(
    Future<void> barrier,
    T Function() snapshot,
  ) {
    return _pendingPersistence = _pendingPersistence.then((_) async {
      try {
        await barrier;
      } catch (error) {
        return _writeEncoded(null, error);
      }

      String? contents;
      Object? encodingError;
      try {
        contents = jsonEncode(toJsonList(snapshot()));
      } catch (error) {
        encodingError = error;
      }
      return _writeEncoded(contents, encodingError);
    });
  }

  Future<bool> _encodeAndPersist(T Function() snapshot) {
    String? contents;
    Object? encodingError;
    try {
      // Capture before any await: a later mutation or disposal must not change
      // the snapshot belonging to this request.
      contents = jsonEncode(toJsonList(snapshot()));
    } catch (e) {
      encodingError = e;
    }
    return _pendingPersistence =
        _pendingPersistence.then((_) => _writeEncoded(contents, encodingError));
  }

  Future<bool> _writeEncoded(String? contents, Object? encodingError) async {
    try {
      if (encodingError != null) throw encodingError;
      final file = await _dataFile();
      await AtomicFile.writeString(file, contents!);
      _persistenceError = null;
      return true;
    } catch (e) {
      _persistenceError = e;
      debugPrint('Failed to persist $persistenceFileName: $e');
      return false;
    }
  }

  /// Whether persisted state was absent or read and decoded successfully.
  /// A failed read leaves the existing state intact so callers can keep
  /// controls locked when the missing records affect ownership decisions.
  Future<bool> restore() async {
    try {
      final file = await _dataFile();
      final type = await FileSystemEntity.type(file.path);
      if (type == FileSystemEntityType.notFound) return true;
      if (type != FileSystemEntityType.file) return false;
      final contents = await file.readAsString();
      if (contents.isEmpty) return false;
      try {
        final List<dynamic> jsonList = jsonDecode(contents);
        state = fromJsonList(jsonList);
        await persist();
        return true;
      } catch (e) {
        final truncated = contents.length > 100
            ? '${contents.substring(0, 100)}...'
            : contents;
        debugPrint(
          'WARNING: Corrupt persistence file $persistenceFileName — '
          'keeping previous state. Content was: $truncated',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Failed to restore $persistenceFileName: $e');
      return false;
    }
  }
}
