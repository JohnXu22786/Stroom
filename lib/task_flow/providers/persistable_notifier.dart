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
  Future<bool> persist() {
    String? contents;
    Object? encodingError;
    try {
      // Capture before any await: a later mutation or disposal must not change
      // the snapshot belonging to this request.
      contents = jsonEncode(toJsonList(state));
    } catch (e) {
      encodingError = e;
    }
    return _pendingPersistence = _pendingPersistence.then((_) async {
      try {
        if (encodingError != null) throw encodingError!;
        final file = await _dataFile();
        await AtomicFile.writeString(file, contents!);
        _persistenceError = null;
        return true;
      } catch (e) {
        _persistenceError = e;
        debugPrint('Failed to persist $persistenceFileName: $e');
        return false;
      }
    });
  }

  Future<void> restore() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) return;
      final contents = await file.readAsString();
      if (contents.isEmpty) return;
      try {
        final List<dynamic> jsonList = jsonDecode(contents);
        state = fromJsonList(jsonList);
        await persist();
      } catch (e) {
        final truncated = contents.length > 100
            ? '${contents.substring(0, 100)}...'
            : contents;
        debugPrint(
          'WARNING: Corrupt persistence file $persistenceFileName — '
          'keeping previous state. Content was: $truncated',
        );
      }
    } catch (e) {
      debugPrint('Failed to restore $persistenceFileName: $e');
    }
  }
}
