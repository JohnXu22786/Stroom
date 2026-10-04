import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import '../../services/app_log_service.dart';
import '../../services/storage_service.dart';
import '../../utils/video_manifest.dart';
import '../../utils/file_manifest.dart';
import '../models/catcatch_task.dart';
import '../models/media_kind.dart';
import '../models/media_resource.dart';
import 'ev1_decoder.dart';
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
  // EV1 may be XOR-obfuscated FLV, including when a server labels it .flv.
  // Its bytes need decoding before a media player can open them.
  final signature = await File(sourcePath).openRead(0, 3).toList();
  if (signature.isNotEmpty &&
      Ev1Decoder.isEv1(Uint8List.fromList(signature.first))) {
    throw StateError('EV1 原始文件无法直接播放，请选择转换为 MP4 后再保存');
  }
  final verified =
      kIsWeb ? null : await catCatchVerifiedMediaFromPath(sourcePath);
  if (!kIsWeb && verified == null) {
    throw const FormatException('无法验证下载文件的音视频类型，请检查媒体文件');
  }
  final appDirPath = await AppStorage.directory;
  final saveDir = p.join(appDirPath, 'catcatch', 'completed');
  final saveDirObj = Directory(saveDir);
  if (!await saveDirObj.exists()) await saveDirObj.create(recursive: true);
  var fileName = p.basename(sourcePath);
  if (!kIsWeb) {
    // Keep the equally valid MPG alias when it already matches the verified
    // MPEG container. Every other suffix follows the inspected bytes.
    final extension = p.extension(fileName).toLowerCase() == '.mpg' &&
            verified!.extension == '.mpeg'
        ? '.mpg'
        : verified!.extension;
    if (p.extension(fileName).toLowerCase() != extension) {
      fileName = '${p.basenameWithoutExtension(fileName)}$extension';
    }
  }
  final finalPath = await uniqueExecutorPath(p.join(saveDir, fileName));
  await File(sourcePath).copy(finalPath);

  try {
    if (!kIsWeb) {
      // A successful save always has one gallery record for verified media.
      final kind = await catCatchMediaKindFromFile(task, finalPath);
      switch (kind) {
        case CatCatchMediaKind.video:
          await registerCompletedVideo(finalPath, task, verifiedKind: kind);
        case CatCatchMediaKind.audio:
          await registerCompletedAudio(finalPath, task, verifiedKind: kind);
        case CatCatchMediaKind.other:
          throw const FormatException('无法验证下载文件的音视频类型，请检查媒体文件');
      }
    }
  } catch (e) {
    // The original download is still available for retry. Do not leave an
    // unregistered copy in the completed directory after registration fails.
    try {
      await File(finalPath).delete();
    } catch (cleanupError) {
      debugPrint('[TaskExecutor] Remove incomplete copy failed: $cleanupError');
    }
    rethrow;
  }

  markExecutorStep(steps, 7, done: true);
  onUpdate(task.copyWith(steps: steps, progress: calcExecutorProgress(steps)));
  return finalPath;
}

Future<void> registerCompletedVideo(String filePath, CatCatchTask task,
    {CatCatchMediaKind? verifiedKind}) async {
  if ((verifiedKind ?? await catCatchMediaKindFromFile(task, filePath)) !=
      CatCatchMediaKind.video) {
    throw const FormatException('保存文件不是可验证的视频');
  }
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
    'wmv',
    'mpeg',
    'mpg',
  };
  if (!videoExts.contains(ext)) {
    throw FormatException('不支持的视频文件格式: .$ext');
  }

  final file = File(filePath);
  if (!await file.exists()) {
    throw FileSystemException('保存的视频文件不存在', filePath);
  }

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
  final storageDir = await VideoManifest.videoDir;
  final storageFile = File(p.join(storageDir, '$hash.$ext'));
  // An older record with this hash may use a different extension. Each new
  // record must have the exact storage path named by its own format.
  if (!await storageFile.exists()) await file.copy(storageFile.path);

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

Future<void> registerCompletedAudio(String filePath, CatCatchTask task,
    {CatCatchMediaKind? verifiedKind}) async {
  if ((verifiedKind ?? await catCatchMediaKindFromFile(task, filePath)) !=
      CatCatchMediaKind.audio) {
    throw const FormatException('保存文件不是可验证的音频');
  }
  final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
  const audioExts = {
    'mp3',
    'wav',
    'm4a',
    'aac',
    'wma',
    'opus',
    'flac',
    'mka',
    'ogg',
    'mp4',
    'webm',
    'weba',
    'mov',
    'flv',
    'avi',
    'mpeg',
    'mpg',
  };
  if (!audioExts.contains(ext)) {
    throw FormatException('不支持的音频文件格式: .$ext');
  }

  final file = File(filePath);
  if (!await file.exists()) {
    throw FileSystemException('保存的音频文件不存在', filePath);
  }

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
  final storageDir = await FileManifest.ttsAudioDir;
  final storageFile = File(p.join(storageDir, '$hash.$ext'));
  if (!await storageFile.exists()) await file.copy(storageFile.path);

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
