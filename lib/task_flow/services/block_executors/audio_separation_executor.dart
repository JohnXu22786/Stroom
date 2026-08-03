import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../providers/background_task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../utils/audio_separation.dart';
import '../../../utils/audio_utils.dart';
import '../../../utils/file_manifest.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

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

/// Computes the audio hash and detects the format in a background isolate.
/// Both operations are CPU-bound (MD5 over raw PCM, magic-byte scanning)
/// and would freeze the GUI if run on the main isolate.
Future<(String, String)> _computeAudioMetaInIsolate(Uint8List audioBytes) {
  return Isolate.run(() {
    final hash = computeAudioHash(audioBytes);
    final format = normalizeAudioFormat(detectAudioFormat(audioBytes));
    return (
      hash,
      format,
    ); // positional record — avoids destructuring issues in CI
  });
}

/// Yields to the event loop so the Flutter framework can render a frame
/// (process pending widget builds) before the next CPU-intensive operation.
Future<void> _yieldFrame() => Future.delayed(Duration.zero);

Future<String> executeAudioSeparationBlock({
  required BlockTypeDefinition def,
  required TaskFlowBlock block,
  required String input,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required BackgroundTaskNotifier bgNotifier,
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
    final file = File(input);
    if (!await file.exists()) {
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
    bgNotifier.updateStep(taskId, 0, running: true);

    await _yieldFrame();
    audioBytes = await _readAndExtractInIsolate(input, inputFormat);

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
    final meta = await _computeAudioMetaInIsolate(audioBytes);
    final hash = meta.$1;
    final format = meta.$2;

    // The flow may have been deleted while the separation isolate ran —
    // don't write an orphaned audio file + gallery record.
    if (!execNotifier.state.any((e) => e.id == execId)) {
      throw BlockExecutionException(
        '任务流已删除',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    await FileManifest.writeFile('$hash.$format', audioBytes);

    final saveFolder = asStringParam(block.params, 'saveFolder', '');

    // Deduplicate the record name — same video extracted twice should
    // produce "音频分离_video" then "音频分离_video (2)", etc.
    String recordName = title;
    {
      final existingRecords = await FileManifest.loadRecords();
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
    }

    final record = AudioRecord(
      name: recordName,
      hash: hash,
      format: format,
      createdAt: DateTime.now(),
      size: audioBytes.length,
      folder: saveFolder,
    );
    await FileManifest.addRecord(record);
    final filePath = await FileManifest.readFilePath('$hash.$format');

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

    await _yieldFrame();
    bgNotifier.updateStep(taskId, 1, completed: true);

    await _yieldFrame();
    bgNotifier.completeTask(taskId, downloadedFilePath: filePath);
    execNotifier.updateSubTaskStatus(
      execId,
      flowSubTask.id,
      TaskStatus.completed,
    );
    return filePath;
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
