import 'package:uuid/uuid.dart';

import '../../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../../catcatch/providers/catcatch_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'catcatch_output_registrator.dart';

Future<String> executeCatCatchBlock({
  required BlockTypeDefinition def,
  required TaskFlowBlock block,
  required String input,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required CatCatchNotifier catcatchNotifier,
  String videoFolder = '',
  String audioFolder = '',
}) async {
  final taskId = const Uuid().v4();
  execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
  execNotifier.updateSubTaskStatus(execId, flowSubTask.id, TaskStatus.running);
  final raw = block.params['durationSec'] ?? 0;
  final durationSec =
      raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
  catcatchNotifier.addTask(input, durationSec,
      taskId: taskId, videoFolder: videoFolder, audioFolder: audioFolder);

  final startTime = DateTime.now();
  const maxWait = Duration(minutes: 10);
  bool autoSelected = false;
  bool autoConfirmed = false;

  while (true) {
    await Future.delayed(const Duration(milliseconds: 500));
    final task =
        catcatchNotifier.state.where((t) => t.id == taskId).firstOrNull;

    if (task == null) {
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.failed);
      throw BlockExecutionException('任务丢失',
          blockType: def.typeKey.name, blockTitle: def.label);
    }

    if (task.status == catcatch.TaskStatus.completed) {
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.completed);
      if (task.downloadedFilePath != null) {
        await registerFlowCatCatchOutput(task.downloadedFilePath!, task);
        return task.downloadedFilePath!;
      }
      throw BlockExecutionException('下载完成但无文件路径',
          blockType: def.typeKey.name, blockTitle: def.label);
    }
    if (task.status == catcatch.TaskStatus.failed) {
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.failed);
      throw BlockExecutionException(task.error ?? '任务失败',
          blockType: def.typeKey.name, blockTitle: def.label);
    }
    if (task.status == catcatch.TaskStatus.paused) {
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.paused);
      throw BlockExecutionException('任务已暂停',
          blockType: def.typeKey.name, blockTitle: def.label);
    }

    if (!autoSelected) {
      final us =
          task.steps.where((s) => s.type == catcatch.StepType.userSelecting);
      if (us.isNotEmpty && !us.first.completed && !us.first.skipped) {
        if (task.detectedMedia.isNotEmpty) {
          try {
            catcatchNotifier.selectMedia(taskId, task.detectedMedia.first);
            autoSelected = true;
            execNotifier.updateSubTaskStatus(
                execId, flowSubTask.id, TaskStatus.running);
          } catch (e) {
            execNotifier.updateSubTaskStatus(
                execId, flowSubTask.id, TaskStatus.failed);
            throw BlockExecutionException('自动选择媒体失败: $e',
                blockType: def.typeKey.name, blockTitle: def.label);
          }
        }
      }
    }

    if (!autoConfirmed && task.metadata['pendingConfirm'] == 'special_format') {
      autoConfirmed = true;
      try {
        catcatchNotifier.confirmAndContinue(taskId);
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.running);
      } catch (e) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        throw BlockExecutionException('自动处理特殊格式失败: $e',
            blockType: def.typeKey.name, blockTitle: def.label);
      }
    }

    if (DateTime.now().difference(startTime) > maxWait) {
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.failed);
      throw BlockExecutionException('下载超时',
          blockType: def.typeKey.name, blockTitle: def.label);
    }
  }
}
