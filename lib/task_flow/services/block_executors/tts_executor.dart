import 'package:uuid/uuid.dart';

import '../../../providers/provider_config.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';

Future<String> executeTtsBlock({
  required TaskFlowBlock block,
  required BlockTypeDefinition def,
  required String input,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required TaskListNotifier taskListNotifier,
  required ProviderEntriesState providerEntries,
}) async {
  final configs = providerEntries.entries
      .where((e) => e.type == 'tts')
      .expand((e) => e.configs)
      .toList();
  if (configs.isEmpty) {
    throw BlockExecutionException('未配置TTS模型',
        blockType: def.typeKey.name, blockTitle: def.label);
  }

  final config = configs.first;
  final model = config.models.isNotEmpty ? config.models.first : null;
  if (model == null) {
    throw BlockExecutionException('模型配置为空',
        blockType: def.typeKey.name, blockTitle: def.label);
  }

  final title = input.length > 20 ? input.substring(0, 20) : input;
  final voice = block.params['voice'] ?? '';
  final speed = block.params['speed'] ?? '1.0';
  final saveFolder = block.params['saveFolder'] ?? '';

  try {
    final taskId = const Uuid().v4();
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
        execId, flowSubTask.id, TaskStatus.running);
    taskListNotifier.addTask(
      title: title,
      text: input,
      providerConfig: config,
      modelConfig: model,
      customParams: {
        if (voice.isNotEmpty) 'voice': voice,
        'speed': speed,
        if (saveFolder.isNotEmpty) 'saveFolder': saveFolder,
      },
      taskId: taskId,
    );

    final startTime = DateTime.now();
    const maxWait = Duration(minutes: 5);

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      final task =
          taskListNotifier.state.where((t) => t.id == taskId).firstOrNull;

      if (task == null) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        throw BlockExecutionException('任务丢失',
            blockType: def.typeKey.name, blockTitle: def.label);
      }
      if (task.status == TaskStatus.completed) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.completed);
        if (task.downloadedFilePath != null) return task.downloadedFilePath!;
        throw BlockExecutionException('合成完成但无文件路径',
            blockType: def.typeKey.name, blockTitle: def.label);
      }
      if (task.status == TaskStatus.failed) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        throw BlockExecutionException(task.error ?? '任务失败',
            blockType: def.typeKey.name, blockTitle: def.label);
      }
      if (DateTime.now().difference(startTime) > maxWait) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.failed);
        throw BlockExecutionException('合成超时',
            blockType: def.typeKey.name, blockTitle: def.label);
      }
    }
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    throw BlockExecutionException(e.toString(),
        blockType: def.typeKey.name, blockTitle: def.label);
  }
}
