import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../providers/background_task_provider.dart';
import '../providers/task_provider.dart';
import '../utils/text_manifest.dart';

typedef OcrTextWriter = Future<String> Function(
  String fileName,
  String text, {
  void Function()? beforeCommit,
});

typedef OcrTextRecordWriter = Future<void> Function(TextRecord record,
    {void Function()? beforeCommit});
typedef OcrTextRecordsLoader = Future<List<TextRecord>> Function();
typedef OcrTextFileDeleter = Future<bool> Function(String fileName);

/// Publishes an OCR result and its manifest record as one cancellable save.
/// The OCR runner and the task-list save-only retry share this implementation.
class OcrResultSaver {
  final String taskId;
  final BackgroundTaskNotifier notifier;
  final String title;
  final String folder;
  final void Function() onSaved;
  final CancelToken _cancelToken;
  final OcrTextWriter _writeText;
  final OcrTextRecordWriter _addRecord;
  final OcrTextRecordsLoader _loadRecordsUncached;
  final OcrTextFileDeleter _deleteTextFile;
  final BackgroundTask? _taskGeneration;

  OcrResultSaver({
    required this.taskId,
    required this.notifier,
    required this.title,
    required this.folder,
    required this.onSaved,
    CancelToken? cancelToken,
    OcrTextWriter? writeText,
    OcrTextRecordWriter? addRecord,
    OcrTextRecordsLoader? loadRecordsUncached,
    OcrTextFileDeleter? deleteTextFile,
  })  : _taskGeneration = notifier.taskById(taskId),
        _cancelToken = cancelToken ?? CancelToken(),
        _writeText = writeText ?? TextManifest.writeText,
        _addRecord = addRecord ?? TextManifest.addRecord,
        _loadRecordsUncached =
            loadRecordsUncached ?? TextManifest.loadRecordsUncached,
        _deleteTextFile = deleteTextFile ?? TextManifest.deleteFile;

  void cancel() => _cancelToken.cancel('已取消');

  bool get _ownsTaskGeneration {
    final taskGeneration = _taskGeneration;
    return taskGeneration != null &&
        notifier.taskById(taskId)?.hasSameGenerationAs(taskGeneration) == true;
  }

  void _checkActive() {
    if (!notifier.mounted || !_ownsTaskGeneration) {
      cancel();
    }
    if (_cancelToken.isCancelled) throw _cancelToken.cancelError!;
  }

  /// Save an OCR result without issuing an OCR request.
  /// Incomplete results require [allowPartial], which is set only by the
  /// explicit partial-save action and persisted before writing.
  Future<String> retryTaskResult({bool allowPartial = false}) async {
    final task = notifier.state.where((task) => task.id == taskId).firstOrNull;
    if (task == null ||
        task.type != BackgroundTaskType.ocr ||
        task.status != TaskStatus.failed ||
        task.result == null) {
      throw StateError('没有可重试保存的 OCR 结果');
    }
    if (!task.resultIsComplete && !allowPartial && !task.partialSaveRequested) {
      throw StateError('不完整的 OCR 结果需要明确选择保存为部分结果');
    }

    _checkActive();
    final taskGeneration = _taskGeneration!;
    if (!task.resultIsComplete && allowPartial) {
      notifier.markPartialResultSaveRequested(taskId);
      _checkActive();
    }
    final cancellationOwner = notifier.registerCancellationForGeneration(
      taskId,
      taskGeneration,
      cancel,
    );
    try {
      _checkActive();
      notifier.startSaveRetry(taskId);
      _checkActive();
      return await saveResult(
        task.result!,
        isComplete: task.resultIsComplete,
        allowPartial: allowPartial || task.partialSaveRequested,
      );
    } catch (error) {
      if (!_cancelToken.isCancelled &&
          notifier.mounted &&
          _ownsTaskGeneration) {
        final current = notifier.taskById(taskId);
        if (current != null && current.hasSameGenerationAs(taskGeneration)) {
          for (var i = 0; i < current.steps.length; i++) {
            if (_cancelToken.isCancelled || !_ownsTaskGeneration) break;
            if (current.steps[i].running) {
              notifier.updateStep(taskId, i, failed: true, error: '$error');
            } else if (current.steps[i].status == BgStepStatus.pending) {
              notifier.updateStep(taskId, i, skipped: true);
            }
          }
          if (!_cancelToken.isCancelled && _ownsTaskGeneration) {
            notifier.failTask(taskId, error: 'OCR结果保存失败: $error');
          }
        }
      }
      rethrow;
    } finally {
      if (cancellationOwner != null) {
        notifier.unregisterCancellationForGeneration(
          taskId,
          cancellationOwner,
        );
      }
    }
  }

  /// Write the text, verify it, add its record, and confirm the persisted row.
  Future<String> saveResult(
    String text, {
    required bool isComplete,
    bool allowPartial = false,
  }) async {
    if (!isComplete && text.isEmpty) {
      throw StateError('空的 OCR 部分结果不能保存');
    }
    if (!isComplete && !allowPartial) {
      throw StateError('不完整的 OCR 结果不能自动保存');
    }
    final bytes = Uint8List.fromList(utf8.encode(text));
    final hash = computeTextHash(bytes);
    return TextManifest.withSaveLock(hash, () async {
      _checkActive();
      final fileName = '$hash.txt';
      final record = TextRecord(
        name: isComplete ? title : '$title（部分结果）',
        hash: hash,
        createdAt: DateTime.now(),
        size: bytes.length,
        folder: folder,
        textLength: text.length,
      );
      var existed =
          true; // Until known, never delete a potentially shared file.
      try {
        existed = await TextManifest.readFilePath(fileName) != null;
        _checkActive();
        await _writeText(fileName, text, beforeCommit: _checkActive);
        _checkActive();

        final publishedPath = await TextManifest.readFilePath(fileName);
        final publishedText = await TextManifest.readText(fileName);
        if (publishedPath == null || publishedText != text) {
          throw StateError('OCR文本文件写入未确认');
        }
        _checkActive();

        await _addRecord(record, beforeCommit: _checkActive);
        _checkActive();
        final records = await _loadRecordsUncached();
        if (!records.any((item) => item.id == record.id && item.hash == hash)) {
          throw StateError('OCR文本清单记录写入未确认');
        }
        _checkActive();

        notifier.updateStep(taskId, 4, completed: true);
        _checkActive();
        notifier.completeTask(
          taskId,
          downloadedFilePath: publishedPath,
          resultSavedAsPartial: !isComplete,
        );
        try {
          onSaved();
        } catch (error) {
          debugPrint('[OcrResultSaver] Saved result refresh failed: $error');
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
        await TextManifest.deleteRecord(record.id, preserveFiles: true);
        records = await _loadRecordsUncached();
        if (records.any((item) => item.id == record.id)) return;
      }
      if (!existed && !records.any((item) => item.hash == hash)) {
        await _deleteUnreferencedTextFile(fileName);
      }
    } catch (error) {
      debugPrint('[OcrResultSaver] Rollback lookup failed: $error');
      try {
        await TextManifest.deleteRecordWithKnownHash(
          record.id,
          hash,
          preserveFiles: true,
        );
        final records = await _loadRecordsUncached();
        if (records.any((item) => item.id == record.id)) return;
        if (!existed && !records.any((item) => item.hash == hash)) {
          await _deleteUnreferencedTextFile(fileName);
        }
      } catch (cleanupError) {
        // Without a confirmed reference list, preserve the content-addressed file.
        debugPrint(
            '[OcrResultSaver] Rollback cleanup could not be confirmed: $cleanupError');
      }
    }
  }

  Future<void> _deleteUnreferencedTextFile(String fileName) async {
    if (!await _deleteTextFile(fileName)) {
      debugPrint(
        '[OcrResultSaver] Rollback cleanup could not be confirmed: '
        'deleteFile returned false for $fileName',
      );
    }
  }
}
