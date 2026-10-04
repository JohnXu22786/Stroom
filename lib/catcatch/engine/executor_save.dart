import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
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
import 'native_blob_replace_stub.dart'
    if (dart.library.ffi) 'native_blob_replace_ffi.dart' as native_blob;

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
  CancelToken? cancelToken,
  @visibleForTesting Future<void> Function()? afterRecordAdded,
}) async {
  if (sourcePath == null) throw Exception('源文件路径为空，无法保存');
  bool cancelled() => cancelToken?.isCancelled ?? false;
  File? completedFile;
  CompletedMediaRegistration? registration;
  try {
    _throwIfCancelled(cancelled);
    // EV1 may be XOR-obfuscated FLV, including when a server labels it .flv.
    // Its bytes need decoding before a media player can open them.
    final signature = await File(sourcePath).openRead(0, 3).toList();
    if (signature.isNotEmpty &&
        Ev1Decoder.isEv1(Uint8List.fromList(signature.first))) {
      throw StateError('EV1 原始文件无法直接播放，请选择转换为 MP4 后再保存');
    }
    _throwIfCancelled(cancelled);
    final verified =
        kIsWeb ? null : await catCatchVerifiedMediaFromPath(sourcePath);
    if (!kIsWeb && verified == null) {
      throw const FormatException('无法验证下载文件的音视频类型，请检查媒体文件');
    }
    _throwIfCancelled(cancelled);
    final appDirPath = await AppStorage.directory;
    _throwIfCancelled(cancelled);
    final saveDir = Directory(p.join(appDirPath, 'catcatch', 'completed'));
    await saveDir.create(recursive: true);
    _throwIfCancelled(cancelled);
    final fileName = _completedFileName(sourcePath, verified);
    _throwIfCancelled(cancelled);
    completedFile = await _reserveCompletedFile(saveDir.path, fileName);
    _throwIfCancelled(cancelled);
    await File(sourcePath)
        .openRead()
        .takeWhile((_) => !cancelled())
        .pipe(completedFile.openWrite());
    _throwIfCancelled(cancelled);
    if (!kIsWeb &&
        await catCatchVerifiedMediaFromPath(completedFile.path) != verified) {
      throw const FormatException('无法验证下载文件的音视频类型，请检查媒体文件');
    }
    _throwIfCancelled(cancelled);

    void finishStep() {
      _throwIfCancelled(cancelled);
      markExecutorStep(steps, 7, done: true);
      onUpdate(
          task.copyWith(steps: steps, progress: calcExecutorProgress(steps)));
    }

    if (kIsWeb) {
      finishStep();
    } else {
      registration = await registerCompletedMedia(
        completedFile.path,
        task,
        cancelled: cancelled,
        afterRecordAdded: afterRecordAdded,
        onRegistered: finishStep,
      );
    }
    _throwIfCancelled(cancelled);
    return completedFile.path;
  } catch (_) {
    try {
      await registration?.rollback();
    } finally {
      if (completedFile != null && await completedFile.exists()) {
        await completedFile.delete();
      }
    }
    rethrow;
  }
}

/// Match a verified shared-container file to a suffix its gallery can open.
/// The source bytes are checked before reserving the final path so retries
/// cannot collide with another task's completed copy.
String _completedFileName(
  String sourcePath,
  CatCatchVerifiedMedia? verified,
) {
  var fileName = p.basename(sourcePath);
  if (verified != null) {
    // Keep the equally valid MPG alias for a verified MPEG container.
    final extension = p.extension(fileName).toLowerCase() == '.mpg' &&
            verified.extension == '.mpeg'
        ? '.mpg'
        : verified.extension;
    if (p.extension(fileName).toLowerCase() != extension) {
      fileName = '${p.basenameWithoutExtension(fileName)}$extension';
    }
  }
  return fileName;
}

/// Create the completed-path entry exclusively so a concurrent save can never
/// overwrite it or make cancellation delete a different task's copy.
Future<File> _reserveCompletedFile(String directory, String sourcePath) async {
  final basename = p.basenameWithoutExtension(sourcePath);
  final extension = p.extension(sourcePath);
  for (var index = 1;; index++) {
    final name =
        index == 1 ? '$basename$extension' : '$basename ($index)$extension';
    final file = File(p.join(directory, name));
    try {
      return await file.create(exclusive: true);
    } on FileSystemException {
      if (!await file.exists()) rethrow;
    }
  }
}

class _SaveCancelled implements Exception {
  const _SaveCancelled();
}

void _throwIfCancelled(bool Function() cancelled) {
  if (cancelled()) throw const _SaveCancelled();
}

class _RegisteredVideo {
  _RegisteredVideo(this.record);
  final VideoRecord record;

  Future<void> rollback() => _withStorageLock('video:${record.storageFileName}',
      () => VideoManifest.deleteRecord(record.id, preserveFiles: true));
}

class _RegisteredAudio {
  _RegisteredAudio(this.record);
  final AudioRecord record;

  Future<void> rollback() => _withStorageLock('audio:${record.storageFileName}',
      () => FileManifest.deleteRecord(record.id, preserveFiles: true));
}

// Serialize CatCatch saves that target the same content-addressed name. Other
// manifest writers are not in this lock, so rollback retains shared blobs.
final Map<String, Future<void>> _storageLocks = {};

Future<T> _withStorageLock<T>(String key, Future<T> Function() action) async {
  final preceding = _storageLocks[key];
  final released = Completer<void>();
  _storageLocks[key] = released.future;
  try {
    if (preceding != null) await preceding;
    return await action();
  } finally {
    if (identical(_storageLocks[key], released.future)) {
      _storageLocks.remove(key);
    }
    released.complete();
  }
}

/// The caller owns this registration until it has checked its cancellation
/// state after the await. A cancellation in that await gap must undo the
/// gallery insert as well as the completed file.
class CompletedMediaRegistration {
  CompletedMediaRegistration._(this._video, this._audio);
  final _RegisteredVideo? _video;
  final _RegisteredAudio? _audio;

  Future<void> rollback() async {
    Object? firstError;
    StackTrace? firstStack;
    try {
      await _audio?.rollback();
    } catch (error, stack) {
      firstError = error;
      firstStack = stack;
    }
    try {
      await _video?.rollback();
    } catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }
}

/// Registers native CatCatch output. A flow can request only-if-absent
/// registration as a fallback if the native save did not publish a record.
/// Cancellation rolls back only the records created by this call. A hash blob
/// can be shared with an unrelated writer, so rollback leaves its bytes.
Future<CompletedMediaRegistration> registerCompletedMedia(
  String filePath,
  CatCatchTask task, {
  bool Function()? cancelled,
  bool skipIfRegistered = false,
  @visibleForTesting Future<void> Function()? beforeRecordAdded,
  Future<void> Function()? afterRecordAdded,
  void Function()? onRegistered,
}) async {
  final isCancelled = cancelled ?? () => false;
  _RegisteredVideo? video;
  _RegisteredAudio? audio;
  try {
    _throwIfCancelled(isCancelled);
    final kind = await catCatchMediaKindFromFile(task, filePath);
    _throwIfCancelled(isCancelled);
    if (kind == CatCatchMediaKind.video) {
      video = await _registerCompletedVideo(filePath, task,
          cancelled: isCancelled,
          skipIfRegistered: skipIfRegistered,
          beforeRecordAdded: beforeRecordAdded,
          afterRecordAdded: afterRecordAdded);
    } else if (kind == CatCatchMediaKind.audio) {
      audio = await _registerCompletedAudio(filePath, task,
          cancelled: isCancelled,
          skipIfRegistered: skipIfRegistered,
          beforeRecordAdded: beforeRecordAdded,
          afterRecordAdded: afterRecordAdded);
    } else {
      throw const FormatException('无法验证下载文件的音视频类型，请检查媒体文件');
    }
    _throwIfCancelled(isCancelled);
    onRegistered?.call();
    _throwIfCancelled(isCancelled);
    return CompletedMediaRegistration._(video, audio);
  } catch (_) {
    // A cancellation after the gallery commit must undo that registration.
    await CompletedMediaRegistration._(video, audio).rollback();
    rethrow;
  }
}

Future<_RegisteredVideo?> _registerCompletedVideo(
  String filePath,
  CatCatchTask task, {
  required bool Function() cancelled,
  required bool skipIfRegistered,
  Future<void> Function()? beforeRecordAdded,
  Future<void> Function()? afterRecordAdded,
}) async {
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
  _throwIfCancelled(cancelled);

  final hash = await _computeHashInIsolate(filePath);
  _throwIfCancelled(cancelled);
  final size = await file.length();
  _throwIfCancelled(cancelled);
  final storageName = '$hash.$ext';
  return _withStorageLock('video:$storageName', () async {
    _throwIfCancelled(cancelled);
    final records = await VideoManifest.loadRecords();
    _throwIfCancelled(cancelled);
    final hadRecordOwner =
        records.any((record) => record.storageFileName == storageName);
    if (skipIfRegistered && hadRecordOwner) {
      return null;
    }
    final folder = task.metadata['videoFolder'] ?? '';
    final recordName = _uniqueRecordName(filePath, folder,
        records.map((record) => (record.name, record.folder)));
    final record = VideoRecord(
      name: recordName,
      hash: hash,
      format: ext,
      createdAt: DateTime.now(),
      size: size,
      duration: task.expectedDurationSec * 1000,
      folder: folder,
    );
    try {
      final storageDir = await VideoManifest.videoDir;
      _throwIfCancelled(cancelled);
      if (!await _storageBlobMatches(storageName, storageDir, hash,
          readTestFile: VideoManifest.readFile)) {
        _throwIfCancelled(cancelled);
        await _copyToStorage(file, storageName, storageDir, hash,
            writeTestFile: VideoManifest.writeFile, cancelled: cancelled);
      }
      _throwIfCancelled(cancelled);
      await beforeRecordAdded?.call();
      _throwIfCancelled(cancelled);
      await VideoManifest.addRecord(record);
      await afterRecordAdded?.call();
      _throwIfCancelled(cancelled);
      // A gallery delete can remove the last previous owner and its blob
      // between our lookup and insert. Repair it now that our record owns it.
      if (!await _storageBlobMatches(storageName, storageDir, hash,
          readTestFile: VideoManifest.readFile)) {
        await _copyToStorage(file, storageName, storageDir, hash,
            writeTestFile: VideoManifest.writeFile, cancelled: cancelled);
        await _verifyStorageBlob(storageName, storageDir, hash,
            readTestFile: VideoManifest.readFile);
      }
      _throwIfCancelled(cancelled);
      AppLogService.info('CatCatch', '视频已保存: $recordName.$ext ($size bytes)');
      debugPrint('[TaskExecutor] Registered video to gallery: '
          '$recordName.$ext (folder: $folder)');
      return _RegisteredVideo(record);
    } catch (_) {
      await VideoManifest.deleteRecord(record.id, preserveFiles: true);
      rethrow;
    }
  });
}

Future<_RegisteredAudio?> _registerCompletedAudio(
  String filePath,
  CatCatchTask task, {
  required bool Function() cancelled,
  required bool skipIfRegistered,
  Future<void> Function()? beforeRecordAdded,
  Future<void> Function()? afterRecordAdded,
}) async {
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
  _throwIfCancelled(cancelled);

  final hash = await _computeHashInIsolate(filePath);
  _throwIfCancelled(cancelled);
  final size = await file.length();
  _throwIfCancelled(cancelled);
  final storageName = '$hash.$ext';
  return _withStorageLock('audio:$storageName', () async {
    _throwIfCancelled(cancelled);
    final records = await FileManifest.loadRecords();
    _throwIfCancelled(cancelled);
    final hadRecordOwner =
        records.any((record) => record.storageFileName == storageName);
    if (skipIfRegistered && hadRecordOwner) {
      return null;
    }
    final folder = task.metadata['audioFolder'] ?? '';
    final recordName = _uniqueRecordName(filePath, folder,
        records.map((record) => (record.name, record.folder)));
    final record = AudioRecord(
      name: recordName,
      hash: hash,
      format: ext,
      createdAt: DateTime.now(),
      size: size,
      duration: task.expectedDurationSec,
      folder: folder,
    );
    try {
      final storageDir = await FileManifest.ttsAudioDir;
      _throwIfCancelled(cancelled);
      if (!await _storageBlobMatches(storageName, storageDir, hash,
          readTestFile: FileManifest.readFile)) {
        _throwIfCancelled(cancelled);
        await _copyToStorage(file, storageName, storageDir, hash,
            writeTestFile: FileManifest.writeFile, cancelled: cancelled);
      }
      _throwIfCancelled(cancelled);
      await beforeRecordAdded?.call();
      _throwIfCancelled(cancelled);
      await FileManifest.addRecord(record);
      await afterRecordAdded?.call();
      _throwIfCancelled(cancelled);
      if (!await _storageBlobMatches(storageName, storageDir, hash,
          readTestFile: FileManifest.readFile)) {
        await _copyToStorage(file, storageName, storageDir, hash,
            writeTestFile: FileManifest.writeFile, cancelled: cancelled);
        await _verifyStorageBlob(storageName, storageDir, hash,
            readTestFile: FileManifest.readFile);
      }
      _throwIfCancelled(cancelled);
      AppLogService.info('CatCatch', '音频已保存: $recordName.$ext ($size bytes)');
      debugPrint('[TaskExecutor] Registered audio to gallery: '
          '$recordName.$ext (folder: $folder)');
      return _RegisteredAudio(record);
    } catch (_) {
      await FileManifest.deleteRecord(record.id, preserveFiles: true);
      rethrow;
    }
  });
}

String _uniqueRecordName(
    String filePath, String folder, Iterable<(String, String)> names) {
  final basename = p.basenameWithoutExtension(filePath);
  final used =
      names.where((name) => name.$2 == folder).map((name) => name.$1).toSet();
  var name = basename;
  for (var index = 2; used.contains(name) && index <= 10000; index++) {
    name = '$basename ($index)';
  }
  if (used.contains(name)) {
    name = '${basename}_${DateTime.now().millisecondsSinceEpoch}';
  }
  return name;
}

Future<void> _copyToStorage(
  File source,
  String storageName,
  String storageDir,
  String expectedHash, {
  required Future<String> Function(String, Uint8List) writeTestFile,
  required bool Function() cancelled,
}) async {
  if (storageDir.isEmpty) {
    // Manifest test mode stores files in memory. Native saves remain streamed.
    final bytes = await source.readAsBytes();
    _throwIfCancelled(cancelled);
    if (md5.convert(bytes).toString() != expectedHash) {
      throw StateError('Completed file changed during save: $storageName');
    }
    await writeTestFile(storageName, bytes);
    return;
  }
  await publishCompletedBlob(source, storageName, storageDir, expectedHash,
      cancelled: cancelled);
}

/// Publishes a fully copied native hash blob. The optional staging hook lets
/// the cancellation regression hold the copy immediately before publication.
@visibleForTesting
Future<void> publishCompletedBlob(
  File source,
  String storageName,
  String storageDir,
  String expectedHash, {
  required bool Function() cancelled,
  @visibleForTesting Future<void> Function()? afterStaged,
  @visibleForTesting Future<File> Function(File, String)? renameStaged,
  @visibleForTesting Future<bool> Function(String, String)? replaceExisting,
}) async {
  if (await _storageBlobMatches(storageName, storageDir, expectedHash,
      readTestFile: (_) async => null)) {
    return;
  }
  // Stream into a private directory on the same volume, then atomically
  // publish only a complete copy. Cancellation deletes only our staging file.
  final stageDir = await Directory(storageDir).createTemp('.catcatch-');
  final staged = File(p.join(stageDir.path, storageName));
  final target = File(p.join(storageDir, storageName));
  try {
    _throwIfCancelled(cancelled);
    await source
        .openRead()
        .takeWhile((_) => !cancelled())
        .pipe(staged.openWrite());
    _throwIfCancelled(cancelled);
    if (await _computeHashInIsolate(staged.path) != expectedHash) {
      throw StateError('Incomplete staged file: $storageName');
    }
    await afterStaged?.call();
    _throwIfCancelled(cancelled);
    try {
      await (renameStaged ?? (file, path) => file.rename(path))(
          staged, target.path);
    } on FileSystemException {
      // On platforms where rename cannot replace a concurrently published
      // file, retain it if valid. Windows needs an explicit atomic replace
      // when the existing target is incomplete; never stream over it.
      if (!await _storageBlobMatches(storageName, storageDir, expectedHash,
          readTestFile: (_) async => null)) {
        _throwIfCancelled(cancelled);
        final replace = replaceExisting ?? native_blob.replaceExistingBlob;
        if (!await replace(staged.path, target.path)) rethrow;
        if (!await _storageBlobMatches(storageName, storageDir, expectedHash,
            readTestFile: (_) async => null)) {
          throw StateError(
              'Replacement did not publish a valid blob: $storageName');
        }
      }
    }
    _throwIfCancelled(cancelled);
  } finally {
    await stageDir.delete(recursive: true);
  }
}

Future<bool> _storageBlobMatches(
  String storageName,
  String storageDir,
  String expectedHash, {
  required Future<Uint8List?> Function(String) readTestFile,
}) async {
  String? actualHash;
  if (storageDir.isEmpty) {
    final data = await readTestFile(storageName);
    if (data != null) actualHash = md5.convert(data).toString();
  } else {
    try {
      actualHash = await _computeHashInIsolate(p.join(storageDir, storageName));
    } on FileSystemException {
      // A concurrent gallery delete can remove an old owner's blob.
    }
  }
  return actualHash == expectedHash;
}

Future<void> _verifyStorageBlob(
  String storageName,
  String storageDir,
  String expectedHash, {
  required Future<Uint8List?> Function(String) readTestFile,
}) async {
  if (!await _storageBlobMatches(storageName, storageDir, expectedHash,
      readTestFile: readTestFile)) {
    throw StateError('Missing or incomplete hash-addressed file: $storageName');
  }
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
