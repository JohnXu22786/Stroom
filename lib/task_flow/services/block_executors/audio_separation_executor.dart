import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../providers/background_task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../utils/audio_separation.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

Future<Uint8List> _extractAudioIsolate(
    Uint8List videoBytes, String videoFormat) {
  return Isolate.run(
      () => extractAudioSync(videoBytes: videoBytes, videoFormat: videoFormat));
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

  Uint8List videoBytes;
  try {
    final file = File(input);
    if (!await file.exists()) {
      failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
          '输入文件不存在: $input');
      throw BlockExecutionException('输入文件不存在',
          blockType: def.typeKey.name, blockTitle: def.label);
    }
    videoBytes = await file.readAsBytes();
    if (videoBytes.isEmpty) {
      failSubTask(
          bgNotifier, taskId, execNotifier, execId, flowSubTask.id, '输入文件为空');
      throw BlockExecutionException('输入文件为空',
          blockType: def.typeKey.name, blockTitle: def.label);
    }
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    failSubTask(bgNotifier, taskId, execNotifier, execId, flowSubTask.id,
        '无法读取输入文件: $e');
    throw BlockExecutionException('无法读取输入文件',
        blockType: def.typeKey.name, blockTitle: def.label);
  }

  try {
    bgNotifier.updateStep(taskId, 0, running: true);
    final audioBytes = await _extractAudioIsolate(videoBytes, inputFormat);
    bgNotifier.updateStep(taskId, 0, completed: true);

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
