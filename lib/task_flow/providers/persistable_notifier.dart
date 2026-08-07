import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../../services/storage_service.dart';

mixin PersistableNotifier<T> on StateNotifier<T> {
  String get persistenceFileName;

  T fromJsonList(List<dynamic> json);

  List<dynamic> toJsonList(T state);

  Future<File> _dataFile() async {
    final appDir = await AppStorage.directory;
    final dir = Directory(p.join(appDir, 'task_flows'));
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (_) {}
    return File(p.join(dir.path, persistenceFileName));
  }

  Future<void> persist() async {
    try {
      final file = await _dataFile();
      await file.writeAsString(jsonEncode(toJsonList(state)));
    } catch (e) {
      // Silently ignore persistence errors - data is still in memory
    }
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
