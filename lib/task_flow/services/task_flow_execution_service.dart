import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/providers/catcatch_provider.dart';
import '../../models/assistant.dart';
import '../../models/built_in_prompts.dart';
import '../../providers/assistant_provider.dart';
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
import 'task_flow_scheduler.dart';

final taskFlowExecutionServiceProvider = Provider<TaskFlowExecutionService>(
  (ref) => TaskFlowExecutionService._(ref),
);

/// Resource-aware scheduler shared by all concurrent flow executions.
final taskFlowSchedulerProvider = Provider<TaskFlowScheduler>(
  (ref) => TaskFlowScheduler(),
);

/// Maps a block type to the unified-task-list sub-task card type.
///
/// Must match the switch in `TaskFlowCard._buildSubTaskCard`
/// ('catcatch' | 'background' | 'synthesis'). The chat block creates a
/// [BackgroundTask] (id `chat_<execId>_<subTaskId>`), so it must map to
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

/// Resolves a chat block's assistantId to an [Assistant]:
/// - empty → null (the currently selected assistant is used);
/// - `builtin:prompt_<index>` → an [Assistant] built from the built-in
///   prompt preset (no bound model — the currently selected model is
///   used with the preset's prompt);
/// - any other id → the matching user-defined assistant;
/// - unresolvable → null (callers fail loudly).
@visibleForTesting
Assistant? resolveChatAssistant(
    String assistantId, List<Assistant> assistants) {
  if (assistantId.isEmpty) return null;
  final builtIn = builtInPromptById(assistantId);
  if (builtIn != null) {
    return Assistant(
      id: assistantId,
      name: builtIn.name,
      prompt: builtIn.prompt,
      emoji: builtIn.emoji,
      description: builtIn.description,
    );
  }
  if (assistantId.startsWith(kBuiltInPromptIdPrefix)) return null;
  return assistants.where((a) => a.id == assistantId).firstOrNull;
}

class TaskFlowExecutionService {
  final Ref _ref;

  /// Cancel tokens for the in-flight ASR/OCR request of each executing
  /// block, keyed by execution id (multiple flows run concurrently now).
  /// Deleting a flow cancels its own token so the request dies promptly
  /// instead of running for up to the 60-min response bound.
  final Map<String, CancelToken> _activeRequestCancelTokens = {};

  TaskFlowExecutionService._(this._ref);

  /// Cancels the HTTP request of [execId]'s currently executing block
  /// (ASR/OCR). Idempotent — safe to call even when the flow is idle.
  void cancelActiveRequest(String execId) {
    final token = _activeRequestCancelTokens.remove(execId);
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
  }

  Future<bool> startFlow(String flowId, String inputText) async {
    await _startFlowInternal(flowId, inputText);
    return true;
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
    final scheduler = _ref.read(taskFlowSchedulerProvider);

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
      // The execution may have been deleted while the previous block ran
      // (flow card delete / 清除所有) — abort promptly so no further tasks
      // are created.
      if (!execNotifier.state.any((e) => e.id == execId)) {
        AppLogService.info('TaskFlow', '任务流已删除，中止执行 ($execId)');
        return;
      }
      final block = flow.blocks[i];
      final def = block.getDefinition();

      if (def == null) {
        execNotifier.failExecution(execId, error: '未知功能块类型');
        return;
      }

      // Resource-aware scheduling: wait for budget before starting this
      // block (concurrent flows). The queued flag surfaces in the UI.
      final weight = TaskFlowScheduler.weightFor(def.typeKey);
      execNotifier.setExecutionQueued(execId, true);
      try {
        await scheduler.acquire(execId, weight);
      } on FlowSchedulerCancelledException {
        // Flow was deleted while queued — nothing more to do.
        return;
      } finally {
        execNotifier.setExecutionQueued(execId, false);
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
    // A fresh per-execution cancel token for this block, exposed via
    // cancelActiveRequest(execId) so deleting THIS flow aborts its
    // in-flight ASR/OCR request promptly (other flows are unaffected).
    _activeRequestCancelTokens[execId] = CancelToken();
    final scheduler = _ref.read(taskFlowSchedulerProvider);
    try {
      return await _executeBlockInner(
        def,
        block,
        input,
        execId,
        execNotifier,
        flowSubTask: flowSubTask,
        catcatchNotifier: catcatchNotifier,
        bgNotifier: bgNotifier,
        taskListNotifier: taskListNotifier,
        providerEntries: providerEntries,
      );
    } finally {
      _activeRequestCancelTokens.remove(execId);
      scheduler.release(execId);
    }
  }

  Future<String> _executeBlockInner(
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
          cancelToken: _activeRequestCancelTokens[execId],
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
          cancelToken: _activeRequestCancelTokens[execId],
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
        // Resolve the block's assistantId (empty = use the currently
        // selected assistant). Built-in prompt ids resolve to an Assistant
        // built from the preset (no bound model → the currently selected
        // model is used, with the preset's prompt).
        final assistantId = block.params['assistantId']?.toString() ?? '';
        final chatAssistant = resolveChatAssistant(
          assistantId,
          _ref.read(assistantProvider),
        );
        // A configured assistant that no longer exists must fail loudly
        // (mirrors the ASR config resolution) — silently falling back to
        // whatever assistant the chat page last selected would produce
        // unexpected output.
        if (assistantId.isNotEmpty && chatAssistant == null) {
          execNotifier.updateSubTaskStatus(
            execId,
            flowSubTask.id,
            TaskStatus.failed,
          );
          throw BlockExecutionException(
            '助手已删除或不存在',
            blockType: def.typeKey.name,
            blockTitle: def.label,
          );
        }
        return await executeChatBlock(
          block: block,
          def: def,
          input: input,
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          bgNotifier: bgNotifier,
          chatManager: _ref.read(chatStreamManagerProvider),
          assistant: chatAssistant,
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
