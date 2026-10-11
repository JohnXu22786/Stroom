import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../providers/background_task_provider.dart';
import '../providers/task_provider.dart';
import '../utils/text_manifest.dart';

typedef AsrTextWriter = Future<String> Function(
  String fileName,
  String text, {
  void Function()? beforeCommit,
});

typedef AsrTextRecordWriter = Future<void> Function(TextRecord record,
    {void Function()? beforeCommit});

typedef AsrTextRecordsLoader = Future<List<TextRecord>> Function();

/// Saves an ASR transcript as one cancellable file-and-manifest operation.
class AsrResultSaver {
  final String taskId;
  final BackgroundTaskNotifier notifier;
  final String title;
  final String folder;
  final CancelToken cancelToken;
  final void Function() onSaved;
  final AsrTextWriter _writeText;
  final AsrTextRecordWriter _addRecord;
  final AsrTextRecordsLoader _loadRecordsUncached;

  AsrResultSaver({
    required this.taskId,
    required this.notifier,
    required this.title,
    required this.folder,
    required this.cancelToken,
    required this.onSaved,
    AsrTextWriter? writeText,
    AsrTextRecordWriter? addRecord,
    AsrTextRecordsLoader? loadRecordsUncached,
  })  : _writeText = writeText ?? TextManifest.writeText,
        _addRecord = addRecord ?? TextManifest.addRecord,
        _loadRecordsUncached =
            loadRecordsUncached ?? TextManifest.loadRecordsUncached;

  void _checkActive() {
    final task = notifier.taskById(taskId);
    if (task == null || task.status != TaskStatus.running) {
      if (!cancelToken.isCancelled) cancelToken.cancel('已取消');
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
  }

  Future<String> saveResult(String text, {required String format}) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    final hash = computeTextHash(bytes);
    return TextManifest.withSaveLock(hash, () async {
      _checkActive();
      final now = DateTime.now();
      final record = TextRecord(
        name: title,
        hash: hash,
        format: format,
        createdAt: now,
        size: bytes.length,
        folder: folder,
        textLength: text.length,
      );
      final fileName = record.storageFileName;
      var existed = true;
      try {
        existed = await TextManifest.readFilePath(fileName) != null;
        _checkActive();
        await _writeText(fileName, text, beforeCommit: _checkActive);
        _checkActive();

        final publishedPath = await TextManifest.readFilePath(fileName);
        final publishedText = await TextManifest.readText(fileName);
        if (publishedPath == null || publishedText != text) {
          throw StateError('ASR文本文件写入未确认');
        }
        _checkActive();

        await _addRecord(record, beforeCommit: _checkActive);
        _checkActive();
        final records = await _loadRecordsUncached();
        if (!records.any((item) => item.id == record.id && item.hash == hash)) {
          throw StateError('ASR文本清单记录写入未确认');
        }
        _checkActive();

        notifier.updateStep(taskId, 4, completed: true);
        notifier.completeTask(taskId, downloadedFilePath: publishedPath);
        try {
          onSaved();
        } catch (error) {
          debugPrint('[AsrResultSaver] Saved result refresh failed: $error');
        }
        return publishedPath;
      } catch (error, stackTrace) {
        await _rollback(record, fileName, hash, existed: existed);
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<void> _rollback(
    TextRecord record,
    String fileName,
    String hash, {
    required bool existed,
  }) async {
    try {
      var records = await _loadRecordsUncached();
      if (records.any((item) => item.id == record.id)) {
        await TextManifest.deleteRecordWithKnownHash(
          record.id,
          hash,
          preserveFiles: true,
        );
        records = await _loadRecordsUncached();
      }
      if (!existed && !records.any((item) => item.hash == hash)) {
        await TextManifest.deleteFile(fileName);
      }
    } catch (error) {
      debugPrint('[AsrResultSaver] Rollback failed: $error');
    }
  }
}
