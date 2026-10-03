import 'package:uuid/uuid.dart';

import '../../../providers/provider_config.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../utils/provider_models.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

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
  // Model-level selection, same granularity as the TTS page: the shared
  // flattened list (configs without host/key excluded).
  final selected =
      resolveProviderModel(providerEntries, 'tts', block.params['modelRef']);
  if (selected == null) {
    throw BlockExecutionException(
      '未配置TTS模型或模型引用已失效，请重新选择',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  final config = selected.config;
  final model = selected.model;

  final title = input.length > 20 ? input.substring(0, 20) : input;
  final defaults = Map<String, dynamic>.from(
      block.params['_launchSynthesisConfig'] as Map? ?? {});
  final configuredVoice = asStringParam(block.params, 'voice', '');
  final voice = configuredVoice.isEmpty
      ? defaults['voice']?.toString() ?? ''
      : configuredVoice;
  // Clamp into the model's speed range — an old flow may hold an
  // out-of-range value (the old number field had no bounds).
  final speedRaw =
      double.tryParse(asStringParam(block.params, 'speed', '1.0')) ?? 1.0;
  final speed = speedRaw.clamp(model.speedMin, model.speedMax).toString();
  final saveFolder = asStringParam(block.params, 'saveFolder', '');

  try {
    final taskId = const Uuid().v4();
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
      execId,
      flowSubTask.id,
      TaskStatus.running,
    );
    taskListNotifier.addTask(
      title: title,
      text: input,
      providerConfig: config,
      modelConfig: model,
      customParams: {
        if (voice.isNotEmpty) 'voice': voice,
        'speed': speed,
        if (defaults['volume'] != null) 'volume': defaults['volume'].toString(),
        if (defaults['format'] != null) 'format': defaults['format'].toString(),
        if (defaults['format'] != null)
          'response_format': defaults['format'].toString(),
        if (saveFolder.isNotEmpty) 'saveFolder': saveFolder,
      },
      taskId: taskId,
    );

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      final execution = execNotifier.execution(execId);
      if (execution == null || execution.isTerminal) {
        throw BlockExecutionException('任务流已结束',
            blockType: def.typeKey.name, blockTitle: def.label);
      }
      final task =
          taskListNotifier.state.where((t) => t.id == taskId).firstOrNull;

      if (task == null) {
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.failed,
        );
        throw BlockExecutionException(
          '任务丢失',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      if (task.status == TaskStatus.completed) {
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.completed,
        );
        if (task.downloadedFilePath != null) return task.downloadedFilePath!;
        throw BlockExecutionException(
          '合成完成但无文件路径',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      if (task.status == TaskStatus.failed) {
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.failed,
        );
        throw BlockExecutionException(
          task.error ?? '任务失败',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      if (task.status == TaskStatus.paused) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.paused);
        continue;
      }
      if (task.status == TaskStatus.running &&
          execNotifier.execution(execId)?.status ==
              FlowExecutionStatus.running) {
        execNotifier.updateSubTaskStatus(
            execId, flowSubTask.id, TaskStatus.running);
      }
      // No wall-clock timeout here: a slow-but-healthy synthesis (long
      // utterance, throttled server) must not be killed. A truly hung
      // server fails via the request-layer 60-min fallback
      // (tts_provider receiveTimeout) → task becomes failed → loop exits.
      // The 500ms tick keeps the widget's progress UI warm.
    }
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    throw BlockExecutionException(
      e.toString(),
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
}
