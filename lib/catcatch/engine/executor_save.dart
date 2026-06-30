import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import '../../services/storage_service.dart';
import '../../utils/video_manifest.dart';
import '../../utils/file_manifest.dart';
import '../models/catcatch_task.dart';
import '../models/media_resource.dart';
import 'executor_utils.dart';

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

  final fileBytes = await file.readAsBytes();
  final hash = md5.convert(fileBytes).toString();

  final existing = await VideoManifest.getRecordByHash(hash);
  if (existing != null) return;

  final recordName = p.basenameWithoutExtension(filePath);
  final videoFolder = task.metadata['videoFolder'] ?? '';
  final record = VideoRecord(
    name: recordName,
    hash: hash,
    format: ext,
    createdAt: DateTime.now(),
    size: fileBytes.length,
    duration: task.expectedDurationSec * 1000,
    folder: videoFolder,
  );
  await VideoManifest.writeFile('$hash.$ext', fileBytes);
  await VideoManifest.addRecord(record);
  debugPrint(
      '[TaskExecutor] Registered video to gallery: $recordName.$ext (folder: $videoFolder)');
}

Future<void> registerCompletedAudio(String filePath, CatCatchTask task) async {
  final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
  const audioExts = {'mp3', 'wav', 'm4a', 'aac', 'wma', 'opus', 'flac', 'ogg'};
  if (!audioExts.contains(ext)) return;

  final file = File(filePath);
  if (!await file.exists()) return;

  final fileBytes = await file.readAsBytes();
  final hash = md5.convert(fileBytes).toString();

  final existing = await FileManifest.getRecordByHash(hash);
  if (existing != null) return;

  final recordName = p.basenameWithoutExtension(filePath);
  final audioFolder = task.metadata['audioFolder'] ?? '';
  final record = AudioRecord(
    name: recordName,
    hash: hash,
    format: ext,
    createdAt: DateTime.now(),
    size: fileBytes.length,
    duration: task.expectedDurationSec,
    folder: audioFolder,
  );
  await FileManifest.writeFile('$hash.$ext', fileBytes);
  await FileManifest.addRecord(record);
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
