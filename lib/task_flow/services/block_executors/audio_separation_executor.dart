import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show Digest, md5;
import 'package:flutter/foundation.dart'
    show compute, kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../providers/background_task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../utils/audio_separation.dart';
import '../../../utils/audio_separation_web_audio_stub.dart'
    if (dart.library.js_interop) '../../../utils/audio_separation_web_audio.dart'
    as webAudio;
import '../../../utils/audio_utils.dart';
import '../../../utils/file_manifest.dart';
import '../../../utils/web_file_store.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

/// Runs [work] while polling whether the flow execution is still active.
///
/// The underlying read or extraction cannot be aborted, but the flow's
/// global run lock must free promptly when the flow ends mid-operation —
/// otherwise a new flow cannot start for the whole duration of the work.
Future<T> _awaitWhileFlowActive<T>(
  Future<T> work,
  TaskFlowExecutionNotifier execNotifier,
  String execId,
  BlockTypeDefinition def,
) async {
  var completed = false;
  late T result;
  Object? error;
  unawaited(
    work.then(
      (r) {
        completed = true;
        result = r;
      },
      onError: (e) {
        completed = true;
        error = e;
      },
    ),
  );
  while (!completed) {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!isFlowExecutionActive(execNotifier, execId)) {
      throw BlockExecutionException(
        '任务流已结束或删除',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
  }
  if (!isFlowExecutionActive(execNotifier, execId)) {
    throw BlockExecutionException(
      '任务流已结束或删除',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
  if (error != null) throw error!;
  return result;
}

Future<T> _startWhileFlowActive<T>(
  Future<T> Function() startWork,
  TaskFlowExecutionNotifier execNotifier,
  String execId,
  BlockTypeDefinition def,
) async {
  if (!isFlowExecutionActive(execNotifier, execId)) {
    throw BlockExecutionException(
      '任务流已结束或删除',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
  return _awaitWhileFlowActive(startWork(), execNotifier, execId, def);
}

/// Reads a video file and extracts its audio track — all in a background
/// isolate so the GUI stays responsive even for 100+ MB files.
Future<Uint8List> _readAndExtractInIsolate(
  String filePath,
  String videoFormat,
) {
  return Isolate.run(() {
    final bytes = File(filePath).readAsBytesSync();
    return extractAudioSync(videoBytes: bytes, videoFormat: videoFormat);
  });
}

Uint8List _extractVideoBytes((Uint8List, String) input) {
  return extractAudioSync(videoBytes: input.$1, videoFormat: input.$2);
}

/// Uses an isolate on native platforms and the current event loop on Web.
Future<Uint8List> _extractVideoBytesInBackground(
  Uint8List videoBytes,
  String videoFormat,
) {
  if (kIsWeb) return webAudio.extractAudioFromWebBytes(videoBytes, videoFormat);
  return compute(_extractVideoBytes, (videoBytes, videoFormat));
}

(String, String) _computeAudioMeta(Uint8List audioBytes) {
  final hash = computeAudioHash(audioBytes);
  final format = normalizeAudioFormat(detectAudioFormat(audioBytes));
  return (hash, format);
}

/// Uses an isolate on native platforms and the current event loop on Web.
Future<(String, String)> _computeAudioMetaInBackground(Uint8List audioBytes) {
  if (kIsWeb) return computeAudioMetaWithEventLoopYield(audioBytes);
  return compute(_computeAudioMeta, audioBytes);
}

/// Hashes web audio in small chunks so large files do not monopolize the UI.
@visibleForTesting
Future<(String, String)> computeAudioMetaWithEventLoopYield(
  Uint8List audioBytes,
) async {
  var hash = '';
  final chunked = md5.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback((digests) {
      if (digests.isNotEmpty) hash = digests.last.toString();
    }),
  );
  const chunkSize = 64 * 1024;
  for (var offset = 0; offset < audioBytes.length; offset += chunkSize) {
    final end = offset + chunkSize < audioBytes.length
        ? offset + chunkSize
        : audioBytes.length;
    chunked.add(Uint8List.sublistView(audioBytes, offset, end));
    if (end < audioBytes.length) await Future<void>.delayed(Duration.zero);
  }
  chunked.close();
  return (hash, normalizeAudioFormat(detectAudioFormat(audioBytes)));
}

/// Yields to the event loop so the Flutter framework can render a frame
/// (process pending widget builds) before the next CPU-intensive operation.
Future<void> _yieldFrame() => Future.delayed(Duration.zero);

Future<void> _waitForAudioFileSaveLockOrFlowEnd(
  Future<void> previousReleased,
  TaskFlowExecutionNotifier execNotifier,
  String execId,
  BlockTypeDefinition def,
) async {
  bool isActive() => isFlowExecutionActive(execNotifier, execId);

  void throwIfInactive() {
    if (isActive()) return;
    throw BlockExecutionException(
      '任务流已结束或删除',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  throwIfInactive();
  final canceled = Completer<void>();
  final cancellationPoll = Timer.periodic(
    const Duration(milliseconds: 100),
    (_) {
      if (!isActive() && !canceled.isCompleted) canceled.complete();
    },
  );
  try {
    await Future.any<void>([
      previousReleased,
      canceled.future,
    ]);
    throwIfInactive();
  } finally {
    cancellationPoll.cancel();
  }
}

final Map<String, Future<void>> _audioRecordNameAllocationTails = {};

Future<T> _withAudioRecordNameAllocationLock<T>(
  String folder,
  Future<T> Function() operation, {
  required Future<void> Function(Future<void> previous) waitForPrevious,
  void Function()? onQueued,
}) async {
  final previous = _audioRecordNameAllocationTails[folder];
  final release = Completer<void>();
  final tail =
      previous == null ? release.future : previous.then((_) => release.future);
  _audioRecordNameAllocationTails[folder] = tail;
  var previousFinished = previous == null;

  void releaseLock() {
    if (release.isCompleted) return;
    release.complete();
    if (!identical(_audioRecordNameAllocationTails[folder], tail)) return;
    if (previousFinished) {
      _audioRecordNameAllocationTails.remove(folder);
    } else {
      unawaited(
        tail.then((_) {
          if (identical(_audioRecordNameAllocationTails[folder], tail)) {
            _audioRecordNameAllocationTails.remove(folder);
          }
        }),
      );
    }
  }

  if (previous != null) {
    try {
      onQueued?.call();
      final previousReleased = previous.then((_) {
        previousFinished = true;
      });
      await waitForPrevious(previousReleased);
    } catch (_) {
      releaseLock();
      rethrow;
    }
  }

  try {
    return await operation();
  } finally {
    releaseLock();
  }
}

Future<void> _deleteAudioFileIfUnreferenced(
  String storageName, {
  Future<List<AudioRecord>> Function()? loadRecords,
}) async {
  late final List<AudioRecord> records;
  try {
    records = await (loadRecords?.call() ?? FileManifest.loadRecordsStrict());
  } catch (_) {
    // Keep the bytes when the manifest cannot confirm that they are unused.
    return;
  }
  if (records.any((record) => record.storageFileName == storageName)) return;
  await FileManifest.deleteFile(storageName);
}

Future<String> executeAudioSeparationBlock({
  required BlockTypeDefinition def,
  required TaskFlowBlock block,
  required String input,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required BackgroundTaskNotifier bgNotifier,

  /// Allows the extraction wait to be controlled in cancellation tests.
  Future<Uint8List> Function(String, String)? extractAudio,

  /// Allows the WebFileStore read wait to be controlled in cancellation tests.
  Future<Uint8List?> Function(String)? readWebFileBytes,

  /// Allows cancellation tests to observe when audio metadata work starts.
  Future<(String, String)> Function(Uint8List)? computeAudioMeta,

  /// Allows cancellation tests to stop between the output write and manifest
  /// insertion.
  Future<void> Function()? onAudioFileWritten,

  /// Allows cancellation tests to observe waiting for a same-hash save.
  void Function()? onAudioFileSaveQueued,

  /// Allows tests to observe waiting for a same-folder record name allocation.
  void Function()? onAudioRecordNameAllocationQueued,

  /// Allows cancellation tests to simulate manifest reference lookup failure.
  Future<List<AudioRecord>> Function()? loadAudioRecordsForCleanup,

  /// Allows cancellation tests to simulate an audio record insertion failure.
  Future<void> Function(AudioRecord)? addAudioRecord,
}) async {
  final inputBasename = p.basename(input);
  final inputFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
  final title = '音频分离_${p.basenameWithoutExtension(inputBasename)}';

  final taskId = const Uuid().v4();
  execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
  execNotifier.updateSubTaskStatus(execId, flowSubTask.id, TaskStatus.running);
  bgNotifier.addTask(
    type: BackgroundTaskType.audioSeparation,
    title: title,
    taskId: taskId,
  );
  await _yieldFrame();

  Uint8List audioBytes;
  try {
    final usesWebFileStore =
        kIsWeb || (WebFileStore.isTestMode && await WebFileStore.exists(input));
    Uint8List? webVideoBytes;
    final bool inputExists;
    if (usesWebFileStore) {
      final readWebFile = readWebFileBytes ?? WebFileStore.read;
      webVideoBytes = await _startWhileFlowActive(
        () => readWebFile(input),
        execNotifier,
        execId,
        def,
      );
      inputExists = webVideoBytes != null;
    } else {
      inputExists = await File(input).exists();
    }
    if (!inputExists) {
      failSubTask(
        bgNotifier,
        taskId,
        execNotifier,
        execId,
        flowSubTask.id,
        '输入文件不存在: $input',
      );
      throw BlockExecutionException(
        '输入文件不存在',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    await _yieldFrame();
    if (!isFlowExecutionActive(execNotifier, execId)) {
      throw BlockExecutionException(
        '任务流已结束或删除',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    bgNotifier.updateStep(taskId, 0, running: true);

    // Extraction cannot be interrupted, so poll while it runs to release
    // the flow's run lock promptly if the execution ends.
    final Future<Uint8List> extraction;
    if (extractAudio != null) {
      extraction = extractAudio(input, inputFormat);
    } else if (usesWebFileStore) {
      extraction = _extractVideoBytesInBackground(webVideoBytes!, inputFormat);
    } else {
      extraction = _readAndExtractInIsolate(input, inputFormat);
    }
    audioBytes = await _awaitWhileFlowActive(
      extraction,
      execNotifier,
      execId,
      def,
    );

    await _yieldFrame();
    bgNotifier.updateStep(taskId, 0, completed: true);
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '音频提取失败: $e',
    );
    throw BlockExecutionException(
      '音频提取失败',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  try {
    if (audioBytes.isEmpty) {
      failSubTask(
        bgNotifier,
        taskId,
        execNotifier,
        execId,
        flowSubTask.id,
        '提取的音频数据为空',
      );
      throw BlockExecutionException(
        '提取的音频数据为空',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    await _yieldFrame();
    bgNotifier.updateStep(taskId, 1, running: true);

    await _yieldFrame();
    final computeMeta = computeAudioMeta ?? _computeAudioMetaInBackground;
    final meta = await _startWhileFlowActive(
      () => computeMeta(audioBytes),
      execNotifier,
      execId,
      def,
    );
    final hash = meta.$1;
    final format = meta.$2;
    return await FileManifest.withStorageFileSaveLock(
      '$hash.$format',
      () async {
        // The flow may have ended while the separation isolate ran — don't
        // write an orphaned audio file + gallery record.
        if (!isFlowExecutionActive(execNotifier, execId)) {
          throw BlockExecutionException(
            '任务流已结束或删除',
            blockType: def.typeKey.name,
            blockTitle: def.label,
          );
        }
        await FileManifest.writeFile('$hash.$format', audioBytes);
        await onAudioFileWritten?.call();

        final saveFolder = asStringParam(block.params, 'saveFolder', '');
        late final AudioRecord record;
        try {
          record = await _withAudioRecordNameAllocationLock(
            saveFolder,
            () async {
              // Deduplicate the record name — same video extracted twice
              // should produce "音频分离_video" then "音频分离_video (2)",
              // etc.
              final existingRecords = await FileManifest.loadRecords();
              String recordName = title;
              int dedupIdx = 2;
              while (existingRecords.any(
                    (r) => r.name == recordName && r.folder == saveFolder,
                  ) &&
                  dedupIdx <= 10000) {
                recordName = '$title ($dedupIdx)';
                dedupIdx++;
              }
              if (dedupIdx > 10000) {
                recordName = '$title _${DateTime.now().millisecondsSinceEpoch}';
              }

              final record = AudioRecord(
                name: recordName,
                hash: hash,
                format: format,
                createdAt: DateTime.now(),
                size: audioBytes.length,
                folder: saveFolder,
              );
              // Re-check before committing; cancellation can land while this
              // flow waits for another same-folder name allocation.
              if (!isFlowExecutionActive(execNotifier, execId)) {
                final storageName = '$hash.$format';
                await _deleteAudioFileIfUnreferenced(
                  storageName,
                  loadRecords: loadAudioRecordsForCleanup,
                );
                throw BlockExecutionException(
                  '任务流已结束或删除',
                  blockType: def.typeKey.name,
                  blockTitle: def.label,
                );
              }
              try {
                await (addAudioRecord?.call(record) ??
                    FileManifest.addRecord(record));
              } catch (_) {
                await _deleteAudioFileIfUnreferenced(
                  record.storageFileName,
                  loadRecords: loadAudioRecordsForCleanup,
                );
                rethrow;
              }
              return record;
            },
            waitForPrevious: (previous) => _waitForAudioFileSaveLockOrFlowEnd(
              previous,
              execNotifier,
              execId,
              def,
            ),
            onQueued: onAudioRecordNameAllocationQueued,
          );
        } catch (_) {
          if (!isFlowExecutionActive(execNotifier, execId)) {
            await _deleteAudioFileIfUnreferenced(
              '$hash.$format',
              loadRecords: loadAudioRecordsForCleanup,
            );
          }
          rethrow;
        }

        // Manifest insertion awaits storage, so cancellation can land after
        // the pre-commit check. Remove only this flow's record in that case;
        // the manifest preserves a shared file when another record uses its
        // hash.
        Future<void> ensureRecordStillActive() async {
          if (isFlowExecutionActive(execNotifier, execId)) return;
          await FileManifest.deleteRecord(record.id);
          throw BlockExecutionException(
            '任务流已结束或删除',
            blockType: def.typeKey.name,
            blockTitle: def.label,
          );
        }

        await ensureRecordStillActive();
        final filePath = await FileManifest.readFilePath('$hash.$format');
        await ensureRecordStillActive();

        if (filePath == null) {
          failSubTask(
            bgNotifier,
            taskId,
            execNotifier,
            execId,
            flowSubTask.id,
            '无法保存提取的音频文件',
          );
          throw BlockExecutionException(
            '无法保存提取的音频文件',
            blockType: def.typeKey.name,
            blockTitle: def.label,
          );
        }

        await ensureRecordStillActive();
        await _yieldFrame();
        bgNotifier.updateStep(taskId, 1, completed: true);

        await _yieldFrame();
        await ensureRecordStillActive();
        bgNotifier.completeTask(taskId, downloadedFilePath: filePath);
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.completed,
        );
        return filePath;
      },
      waitForPrevious: (previous) => _waitForAudioFileSaveLockOrFlowEnd(
        previous,
        execNotifier,
        execId,
        def,
      ),
      onQueued: onAudioFileSaveQueued,
    );
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '音频处理失败: $e',
    );
    throw BlockExecutionException(
      e.toString(),
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
}
