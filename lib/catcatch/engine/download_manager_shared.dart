import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import '../config/default_rules.dart';
import '../../services/storage_service.dart';

final Map<String, Completer<void>> pauseTokens = {};

Future<String> progressPath(String taskId) async {
  final dirPath = await AppStorage.directory;
  final progDir = Directory(p.join(dirPath, 'catcatch', '.progress'));
  if (!await progDir.exists()) {
    await progDir.create(recursive: true);
  }
  return p.join(progDir.path, '${taskId}_dl_progress.json');
}

Future<void> saveSegmentProgress(
  String taskId,
  Map<String, dynamic> data,
) async {
  try {
    final path = await progressPath(taskId);
    final file = File(path);
    await file.writeAsString(jsonEncode(data));
  } catch (e) {
    debugPrint('[DownloadManager] Failed to save progress: $e');
  }
}

Future<Map<String, dynamic>?> loadSegmentProgress(String taskId) async {
  try {
    final path = await progressPath(taskId);
    final file = File(path);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('[DownloadManager] Failed to load progress: $e');
    return null;
  }
}

Future<void> deleteSegmentProgress(String taskId) async {
  try {
    final path = await progressPath(taskId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    debugPrint('[DownloadManager] Failed to delete progress: $e');
  }
}

Future<void> downloadSingleSegment({
  required int index,
  required String url,
  required String tempDir,
  required List<String?> partFiles,
  Map<String, String>? headers,
  required Semaphore semaphore,
  CancelToken? cancelToken,
  required Map<int, String> errors,
  required void Function(int index) onSegmentComplete,
  String taskId = '',
}) async {
  await semaphore.acquire();
  try {
    final partPath = p.join(tempDir, 'part_$index');
    partFiles[index] = partPath;

    int retries = 0;
    while (retries <= DefaultRules.maxRetriesPerSegment) {
      try {
        final dio = Dio();
        cancelToken?.whenCancel.then((_) => dio.close());
        try {
          final mergedHeaders =
              Map<String, String>.from(DefaultRules.defaultHeaders);
          if (headers != null) mergedHeaders.addAll(headers);

          final response = await dio.get(
            url,
            options: Options(
              headers: mergedHeaders,
              responseType: ResponseType.stream,
              receiveTimeout: const Duration(seconds: 30),
            ),
            cancelToken: cancelToken,
          );

          if (response.statusCode != 200 && response.statusCode != 206) {
            throw DioException(
              requestOptions: response.requestOptions,
              response: response,
              message: 'HTTP ${response.statusCode}',
            );
          }

          try {
            final file = File(partPath);
            final raf = await file.open(mode: FileMode.write);
            try {
              final stream = response.data.stream as Stream<List<int>>;
              await for (final chunk in stream) {
                if (taskId.isNotEmpty) {
                  final pauseCompleter = pauseTokens[taskId];
                  if (pauseCompleter != null) {
                    await pauseCompleter.future;
                  }
                }
                await raf.writeFrom(chunk);
              }
            } finally {
              await raf.close();
            }
          } catch (e) {
            if (retries < DefaultRules.maxRetriesPerSegment) {
              retries++;
              continue;
            }
            errors[index] = e.toString();
            return;
          }

          onSegmentComplete(index);
          return;
        } finally {
          dio.close();
        }
      } catch (e) {
        retries++;
        if (retries > DefaultRules.maxRetriesPerSegment) {
          errors[index] = e.toString();
          return;
        }
        debugPrint('[DownloadManager] Retry $retries for segment $index: $e');
        await Future.delayed(Duration(seconds: retries));
      }
    }
  } finally {
    semaphore.release();
  }
}

class Semaphore {
  final int _max;
  int _current = 0;
  final _queue = <Completer<void>>[];

  Semaphore(this._max);

  Future<void> acquire() async {
    while (_current >= _max) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }
    _current++;
  }

  void release() {
    _current--;
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    }
  }
}
