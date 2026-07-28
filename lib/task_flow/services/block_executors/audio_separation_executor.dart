import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../providers/background_task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../services/app_log_service.dart';
import '../../../utils/audio_separation.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

/// Reads the video file and extracts audio — all in a background isolate
/// so the GUI stays responsive even for large files.
Future<Uint8List> _readAndExtractInIsolate(
    String filePath, String videoFormat) {
  return Isolate.run(() {
    final bytes = File(filePath).readAsBytesSync();
    return extractAudioSync(videoBytes: bytes, videoFormat: videoFormat);
  });
}

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
      type: BackgroundTaskType.audioSeparation, title: title, taskId: taskId);

  Uint8List audioBytes;
  try {
    // Validate file exists before handing off to isolate
    final file = File(input);
    if (!await file.exists()) {
      failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '输入文件不存在: $input');
      throw BlockExecutionException('输入文件不存在',
          blockType: def.typeKey.name, blockTitle: def.label);
    }

    // Read + extract audio in a background isolate so GUI stays responsive
    bgNotifier.updateStep(taskId, 0, running: true);
    audioBytes = await _readAndExtractInIsolate(input, inputFormat);
    bgNotifier.updateStep(taskId, 0, completed: true);
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    failSubTask(
        bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '音频提取失败: $e');
    throw BlockExecutionException('音频提取失败',
        blockType: def.typeKey.name, blockTitle: def.label);
  }

  try {
    if (audioBytes.isEmpty) {
      failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '提取的音频数据为空');
      throw BlockExecutionException('提取的音频数据为空',
          blockType: def.typeKey.name, blockTitle: def.label);
    }

    bgNotifier.updateStep(taskId, 1, running: true);
    final saveFolder = block.params['saveFolder'] ?? '';
    final filePath = await saveAudioForFlow(audioBytes,
        saveFolder: saveFolder, title: title);
    bgNotifier.updateStep(taskId, 1, completed: true);

    if (filePath == null) {
      failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '无法保存提取的音频文件');
      throw BlockExecutionException('无法保存提取的音频文件',
          blockType: def.typeKey.name, blockTitle: def.label);
    }

    bgNotifier.completeTask(taskId, downloadedFilePath: filePath);
    execNotifier.updateSubTaskStatus(
        execId, flowSubTask.id, TaskStatus.completed);
    return filePath;
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    failSubTask(
        bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '音频提取失败: $e');
    throw BlockExecutionException(e.toString(),
        blockType: def.typeKey.name, blockTitle: def.label);
  }
}
