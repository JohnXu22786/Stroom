import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/providers/catcatch_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../providers/chat_manager_provider.dart';
import '../../providers/provider_config.dart';
import '../../providers/task_provider.dart';
import '../../providers/task_provider_shared.dart';
import '../../services/app_log_service.dart';
import '../models/block_type_definition.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_execution.dart';
import '../models/task_flow_exception.dart';
import '../providers/task_flow_execution_provider.dart';
import '../providers/task_flow_provider.dart';
import 'block_executors/block_executors.dart';

final taskFlowExecutionServiceProvider = Provider<TaskFlowExecutionService>(
  (ref) => TaskFlowExecutionService._(ref),
);

/// Maps a block type to the unified-task-list sub-task card type.
///
/// Must match the switch in `TaskFlowCard._buildSubTaskCard`
/// ('catcatch' | 'background' | 'synthesis'). The chat block creates a
/// [BackgroundTask] (id `chat_<subTaskId>`), so it must map to
/// 'background' — otherwise the flow card never links to the real task.
///
/// Note: executions persisted before chat mapped to 'background' still
/// carry `subTaskType: 'chat'`; the card's default case renders those
/// with the fallback card (label + status only, no task link).
String subTaskTypeFor(BlockType? typeKey) {
  switch (typeKey) {
    case BlockType.catcatch:
      return 'catcatch';
    case BlockType.tts:
      return 'synthesis';
    default:
      return 'background';
  }
}

class TaskFlowExecutionService {
  final Ref _ref;
  bool _isRunning = false;

  /// Whether a flow is currently running.  Callers can check this
  /// before calling [startFlow] to provide user feedback.
  bool get isRunning => _isRunning;

  TaskFlowExecutionService._(this._ref);

  Future<bool> startFlow(String flowId, String inputText) async {
    if (_isRunning) return false;
    _isRunning = true;
    try {
      await _startFlowInternal(flowId, inputText);
      return true;
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _startFlowInternal(String flowId, String inputText) async {
    final flow = _ref.read(taskFlowListProvider).firstWhere(
          (f) => f.id == flowId,
          orElse: () => TaskFlowDefinition(name: ''),
        );
    if (flow.name.isEmpty) return;
    if (flow.blocks.isEmpty) return;

    final execNotifier = _ref.read(taskFlowExecutionsProvider.notifier);
    final catcatchNotifier = _ref.read(catcatchTasksProvider.notifier);
    final bgNotifier = _ref.read(backgroundTasksProvider.notifier);
    final taskListNotifier = _ref.read(taskListProvider.notifier);

    final execId = execNotifier.addExecution(
      flowId: flow.id,
      flowName: flow.name,
    );

    AppLogService.info('TaskFlow', '开始执行: ${flow.name} ($execId)');

    final placeholders = <int, FlowSubTask>{};
    for (int i = 0; i < flow.blocks.length; i++) {
      final block = flow.blocks[i];
      final def = block.getDefinition();
      final subTask = FlowSubTask(
        blockTypeKey: def?.typeKey.name ?? block.typeKey.name,
        blockLabel: def?.label ?? block.typeKey.name,
        subTaskId: 'pending_${block.typeKey.name}_$i',
        subTaskType: subTaskTypeFor(def?.typeKey),
        status: TaskStatus.waiting,
      );
      execNotifier.addSubTask(execId, subTask);
      placeholders[i] = subTask;
    }

    String currentData = inputText;

    for (int i = 0; i < flow.blocks.length; i++) {
      // Let the UI render before starting each block
      await Future.delayed(Duration.zero);
      final block = flow.blocks[i];
      final def = block.getDefinition();

      if (def == null) {
        execNotifier.failExecution(execId, error: '未知功能块类型');
        return;
      }

      try {
        final providerState = _ref.read(providerEntriesProvider);
        AppLogService.info(
          'TaskFlow',
          '步骤 ${i + 1}/${flow.blocks.length}: ${def.label}',
        );
        final result = await _executeBlock(
          def,
          block,
          currentData,
          execId,
          execNotifier,
          flowSubTask: placeholders[i]!,
          catcatchNotifier: catcatchNotifier,
          bgNotifier: bgNotifier,
          taskListNotifier: taskListNotifier,
          providerEntries: providerState,
        );
        currentData = result;
      } catch (e) {
        AppLogService.warning(
          'TaskFlow',
          '步骤 ${i + 1} 失败: ${flow.blocks[i].getDefinition()?.label ?? "?"} — $e',
        );
        final executions = execNotifier.state.where((x) => x.id == execId);
        if (executions.isNotEmpty) {
          execNotifier.failExecution(execId, error: '步骤 ${i + 1} 失败: $e');
        }
        return;
      }
    }

    execNotifier.completeExecution(execId);
    AppLogService.info('TaskFlow', '完成: ${flow.name} ($execId)');
  }

  Future<String> _executeBlock(
    BlockTypeDefinition def,
    TaskFlowBlock block,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required CatCatchNotifier catcatchNotifier,
    required BackgroundTaskNotifier bgNotifier,
    required TaskListNotifier taskListNotifier,
    required ProviderEntriesState providerEntries,
  }) async {
    switch (def.typeKey) {
      case BlockType.catcatch:
        return await executeCatCatchBlock(
          def: def,
          block: block,
          input: input,
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          catcatchNotifier: catcatchNotifier,
          videoFolder: block.params['videoFolder'] ?? '',
          audioFolder: block.params['audioFolder'] ?? '',
        );
      case BlockType.audioSeparation:
        return await executeAudioSeparationBlock(
          def: def,
          block: block,
          input: input,
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          bgNotifier: bgNotifier,
        );
      case BlockType.asr:
        return await executeAsrBlock(
          block: block,
          def: def,
          input: input,
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          bgNotifier: bgNotifier,
          providerEntries: providerEntries,
        );
      case BlockType.ocr:
        return await executeOcrBlock(
          block: block,
          def: def,
          input: input,
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          bgNotifier: bgNotifier,
          providerEntries: providerEntries,
        );
      case BlockType.tts:
        return await executeTtsBlock(
          block: block,
          def: def,
          input: input,
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          taskListNotifier: taskListNotifier,
          providerEntries: providerEntries,
        );
      case BlockType.chat:
        return await executeChatBlock(
          block: block,
          def: def,
          input: input,
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          bgNotifier: bgNotifier,
          chatManager: _ref.read(chatStreamManagerProvider),
        );
      case BlockType.custom:
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.failed,
        );
        throw BlockExecutionException('Unsupported block type');
    }
  }
}
