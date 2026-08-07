import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import '../../services/app_log_service.dart';
import '../../services/storage_service.dart';
import '../../utils/video_manifest.dart';
import '../../utils/file_manifest.dart';
import '../models/catcatch_task.dart';
import '../models/media_resource.dart';
import 'executor_utils.dart';

/// Computes the file's MD5 off the UI isolate — hashing a multi-GB video
/// on the main isolate would freeze the GUI. Streams in chunks so neither
/// the worker nor the main isolate ever holds the full file in memory.
Future<String> _computeHashInIsolate(String filePath) {
  return Isolate.run(() {
    final file = File(filePath);
    var digest = '';
    final chunked = md5.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((chunks) {
        if (chunks.isNotEmpty) digest = chunks.last.toString();
      }),
    );
    final raf = file.openSync();
    try {
      const chunkSize = 8 * 1024 * 1024;
      while (true) {
        final chunk = raf.readSync(chunkSize);
        if (chunk.isEmpty) break;
        chunked.add(chunk);
      }
    } finally {
      raf.closeSync();
    }
    chunked.close();
    return digest;
  });
}

Future<String> executeSave({
  required CatCatchTask task,
  required List<StepStatus> steps,
  required String? sourcePath,
  required void Function(CatCatchTask) onUpdate,
}) async {
  if (sourcePath == null) throw Exception('源文件路径为空，无法保存');
  final appDirPath = await AppStorage.directory;
  final saveDir = p.join(appDirPath, 'catcatch', 'completed');
  final saveDirObj = Directory(saveDir);
  if (!await saveDirObj.exists()) await saveDirObj.create(recursive: true);
  final fileName = p.basename(sourcePath);
  final finalPath = await uniqueExecutorPath(p.join(saveDir, fileName));
  await File(sourcePath).copy(finalPath);

  if (!kIsWeb) {
    try {
      await registerCompletedVideo(finalPath, task);
    } catch (e) {
      debugPrint('[TaskExecutor] Register video to gallery failed: $e');
    }
    try {
      await registerCompletedAudio(finalPath, task);
    } catch (e) {
      debugPrint('[TaskExecutor] Register audio to gallery failed: $e');
    }
  }

  markExecutorStep(steps, 7, done: true);
  onUpdate(task.copyWith(steps: steps, progress: calcExecutorProgress(steps)));
  return finalPath;
}

Future<void> registerCompletedVideo(String filePath, CatCatchTask task) async {
  final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
  const videoExts = {
    'mp4',
    'webm',
    'ogg',
    'mov',
    'mkv',
    'ogv',
    'avi',
    'flv',
    'wmv'
  };
  if (!videoExts.contains(ext)) return;

  final file = File(filePath);
  if (!await file.exists()) return;

  final hash = await _computeHashInIsolate(filePath);
  final size = await file.length();

  // Build record name from the file path (uniqueExecutorPath already handles
  // file-system dedup).  Still check the manifest for name+folder collisions
  // as defense-in-depth against edge cases like manual file moves.
  String recordName = p.basenameWithoutExtension(filePath);
  final videoFolder = task.metadata['videoFolder'] ?? '';

  final records = await VideoManifest.loadRecords();
  int dedupIdx = 2;
  while (records.any((r) => r.name == recordName && r.folder == videoFolder) &&
      dedupIdx <= 10000) {
    recordName = '${p.basenameWithoutExtension(filePath)} ($dedupIdx)';
    dedupIdx++;
  }
  if (dedupIdx > 10000) {
    recordName =
        '${p.basenameWithoutExtension(filePath)}_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Only write the physical file once — hash-addressed storage. Copy the
  // file directly (streamed, no full-file buffer) into the storage dir.
  final existing = await VideoManifest.getRecordByHash(hash);
  if (existing == null) {
    final storageDir = await VideoManifest.videoDir;
    await file.copy(p.join(storageDir, '$hash.$ext'));
  }

  // Always register a record so every download appears in the gallery.
  final record = VideoRecord(
    name: recordName,
    hash: hash,
    format: ext,
    createdAt: DateTime.now(),
    size: size,
    duration: task.expectedDurationSec * 1000,
    folder: videoFolder,
  );
  await VideoManifest.addRecord(record);
  AppLogService.info('CatCatch', '视频已保存: $recordName.$ext ($size bytes)');
  debugPrint(
      '[TaskExecutor] Registered video to gallery: $recordName.$ext (folder: $videoFolder)');
}

Future<void> registerCompletedAudio(String filePath, CatCatchTask task) async {
  final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
  const audioExts = {'mp3', 'wav', 'm4a', 'aac', 'wma', 'opus', 'flac', 'ogg'};
  if (!audioExts.contains(ext)) return;

  final file = File(filePath);
  if (!await file.exists()) return;

  final hash = await _computeHashInIsolate(filePath);
  final size = await file.length();

  String recordName = p.basenameWithoutExtension(filePath);
  final audioFolder = task.metadata['audioFolder'] ?? '';

  final records = await FileManifest.loadRecords();
  int dedupIdx = 2;
  while (records.any((r) => r.name == recordName && r.folder == audioFolder) &&
      dedupIdx <= 10000) {
    recordName = '${p.basenameWithoutExtension(filePath)} ($dedupIdx)';
    dedupIdx++;
  }
  if (dedupIdx > 10000) {
    recordName =
        '${p.basenameWithoutExtension(filePath)}_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Only write the physical file once — hash-addressed storage. Copy the
  // file directly (streamed, no full-file buffer) into the storage dir.
  final existing = await FileManifest.getRecordByHash(hash);
  if (existing == null) {
    final storageDir = await FileManifest.ttsAudioDir;
    await file.copy(p.join(storageDir, '$hash.$ext'));
  }

  // Always register a record so every download appears in the gallery.
  final record = AudioRecord(
    name: recordName,
    hash: hash,
    format: ext,
    createdAt: DateTime.now(),
    size: size,
    duration: task.expectedDurationSec,
    folder: audioFolder,
  );
  await FileManifest.addRecord(record);
  AppLogService.info('CatCatch', '音频已保存: $recordName.$ext ($size bytes)');
  debugPrint(
      '[TaskExecutor] Registered audio to gallery: $recordName.$ext (folder: $audioFolder)');
}

String sanitizeForFileName(String title) {
  var clean = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ');
  clean = clean.replaceAll(RegExp(r'\s+'), ' ');
  clean = clean.trim();
  if (clean.length > 200) {
    clean = clean.substring(0, 200);
  }
  return clean;
}

String buildDownloadFileName(
    MediaResource media, Map<String, String> taskMetadata) {
  final pageTitle = taskMetadata['pageTitle'];
  if (pageTitle != null && pageTitle.trim().isNotEmpty) {
    final sanitized = sanitizeForFileName(pageTitle);
    if (sanitized.isNotEmpty) {
      return '$sanitized.${media.ext}';
    }
  }
  return '${media.name}.${media.ext}';
}
