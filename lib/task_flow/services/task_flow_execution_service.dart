import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/providers/catcatch_provider.dart';
import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../models/assistant.dart';
import '../../models/built_in_prompts.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../providers/chat_manager_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/provider_config.dart';
import '../../providers/task_provider.dart';
import '../../providers/tts_state_provider.dart';
import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_execution.dart';
import '../models/flow_launch_snapshot.dart';
import '../models/flow_payload.dart';
import '../../utils/web_file_store.dart';
import '../../utils/provider_models.dart';
import '../models/task_flow_exception.dart';
import '../providers/task_flow_execution_provider.dart';
import '../providers/task_flow_provider.dart';
import 'block_executors/block_executors.dart';
import 'task_flow_scheduler.dart';
import 'task_flow_validator.dart';

final taskFlowExecutionServiceProvider = Provider<TaskFlowExecutionService>(
  (ref) {
    final service = TaskFlowExecutionService._(ref);
    ref.onDispose(service.dispose);
    return service;
  },
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
/// - any other id → the matching user-defined assistant;
/// - unresolvable (deleted id or a legacy `builtin:prompt_*` id — flow
///   blocks only allow user-defined assistants) → null (callers fail
///   loudly).
@visibleForTesting
Assistant? resolveChatAssistant(
    String assistantId, List<Assistant> assistants) {
  if (assistantId.isEmpty) {
    return null;
  }
  if (assistantId.startsWith(kBuiltInPromptIdPrefix)) {
    return null;
  }
  return assistants.where((a) => a.id == assistantId).firstOrNull;
}

typedef FlowBlockRunner = Future<FlowPayload> Function(TaskFlowBlock block,
    FlowPayload input, String executionId, FlowSubTask step);
@visibleForTesting
final taskFlowBlockRunnerProvider = Provider<FlowBlockRunner?>((ref) => null);

class TaskFlowPersistenceException implements Exception {
  final String message;
  const TaskFlowPersistenceException(this.message);
  @override
  String toString() => message;
}

class TaskFlowExecutionService {
  final Ref _ref;
  late final TaskFlowExecutionNotifier _savedNotifier;
  late final TaskFlowScheduler _scheduler;
  final Map<String, BlockType> _activeBlockTypes = {};
  final Map<String, void Function(TaskFlowExecution)> _stopActions = {};
  final Map<String, CancelToken> _activeRequestCancelTokens = {};
  final Map<String, Future<void>> _workers = {};
  final Map<String, Completer<void>> _pauseGates = {};
  final Map<String, int> _resumePending = {};
  final Map<String, int> _controlRevisions = {};
  final Map<String, String> _manualCatCatchWaits = {};
  final Set<String> _manualCatCatchActions = {};
  bool _disposed = false;

  TaskFlowExecutionService._(this._ref) {
    _savedNotifier = _ref.read(taskFlowExecutionsProvider.notifier);
    _scheduler = _ref.read(taskFlowSchedulerProvider);
    _ref.listen(taskFlowExecutionsProvider, (previous, next) {
      final records = {for (final e in next) e.id: e};
      for (final old in previous ?? <TaskFlowExecution>[]) {
        if (!records.containsKey(old.id) ||
            (!old.isTerminal && records[old.id]!.isTerminal)) {
          _stopUnderlying(old, remove: true);
        }
      }
    });
  }

  TaskFlowExecutionNotifier get _notifier => _savedNotifier;
  TaskFlowExecution? _execution(String id) =>
      _disposed ? null : _notifier.execution(id);
  bool _live(String id) {
    final e = _execution(id);
    return e != null && !e.isTerminal;
  }

  int _invalidateControl(String id) =>
      _controlRevisions[id] = (_controlRevisions[id] ?? 0) + 1;

  TaskFlowExecution? _currentControl(String id, int revision) {
    final current = _execution(id);
    return _controlRevisions[id] == revision &&
            current != null &&
            current.status != FlowExecutionStatus.cancelled &&
            current.status != FlowExecutionStatus.completed
        ? current
        : null;
  }

  TaskFlowExecution? _manualCatCatchExecution(String taskId, bool selecting) {
    if (_disposed) return null;
    final task = _ref
        .read(catcatchTasksProvider)
        .where((task) => task.id == taskId)
        .firstOrNull;
    if (task == null || task.status != catcatch.TaskStatus.running) {
      return null;
    }
    final awaitingSelection = task.selectedMedia == null &&
        task.detectedMedia.length > 1 &&
        task.steps.any((step) =>
            step.type == catcatch.StepType.userSelecting &&
            step.running &&
            !step.completed &&
            !step.skipped);
    final awaitingConfirmation =
        task.metadata['pendingConfirm'] == 'special_format';
    if (selecting ? !awaitingSelection : !awaitingConfirmation) return null;
    return _notifier.executions.where((execution) {
      return execution.status == FlowExecutionStatus.running &&
          _activeBlockTypes[execution.id] == BlockType.catcatch &&
          execution.subTasks.any((step) =>
              step.subTaskType == 'catcatch' &&
              step.subTaskId == taskId &&
              (step.outcome == FlowStepOutcome.running ||
                  step.outcome == FlowStepOutcome.paused));
    }).firstOrNull;
  }

  void _releaseManualCatCatchSlot(String executionId, String taskId) {
    if (_manualCatCatchActions.contains(taskId)) return;
    final waiting = _manualCatCatchExecution(taskId, true) ??
        _manualCatCatchExecution(taskId, false);
    if (waiting?.id != executionId) return;
    _manualCatCatchWaits[taskId] = executionId;
    _scheduler.release(executionId);
  }

  /// Called by flow-managed CatCatch cards before an action starts engine work.
  /// Only one tap per task may wait in the scheduler queue at a time.
  Future<bool> performManualCatCatchAction(String taskId, bool selecting,
      void Function(CatCatchNotifier) action) async {
    final execution = _manualCatCatchExecution(taskId, selecting);
    if (execution == null || !_manualCatCatchActions.add(taskId)) return false;
    final id = execution.id;
    var acquired = false;
    try {
      if (!_scheduler.holds(id)) {
        if (_manualCatCatchWaits[taskId] != id) return false;
        try {
          await _scheduler.acquire(
              id, TaskFlowScheduler.weightFor(BlockType.catcatch));
        } on FlowSchedulerCancelledException {
          return false;
        } on FlowSchedulerPausedException {
          return false;
        }
        acquired = true;
      }
      if (_manualCatCatchExecution(taskId, selecting)?.id != id ||
          !_scheduler.holds(id)) {
        if (acquired) _scheduler.release(id);
        return false;
      }
      action(_ref.read(catcatchTasksProvider.notifier));
      _manualCatCatchWaits.remove(taskId);
      return true;
    } catch (_) {
      if (acquired) _scheduler.release(id);
      rethrow;
    } finally {
      _manualCatCatchActions.remove(taskId);
    }
  }

  void cancelActiveRequest(String id) {
    final token = _activeRequestCancelTokens.remove(id);
    if (token != null && !token.isCancelled) token.cancel();
  }

  Future<bool> startFlow(String flowId, String inputText,
      {int durationSec = 0}) async {
    await startFlowMany(
        flowId, [FlowRunInput(text: inputText, durationSec: durationSec)]);
    return true;
  }

  Future<void> startFlowMany(String flowId, List<FlowRunInput> inputs) async {
    final ids = await launchFlowMany(flowId, inputs);
    await Future.wait(ids.map((id) => _workers[id] ?? Future<void>.value()));
  }

  /// Validate, persist the complete submission, then start workers from saved
  /// records. A process exit can never discard an input waiting in a batch.
  Future<List<String>> launchFlowMany(
      String flowId, List<FlowRunInput> inputs) async {
    final flow = await _prepareFlow(flowId, inputs);
    final snapshot = FlowLaunchSnapshot.capture(
        flow, _ref.read(providerEntriesProvider), _ref.read(assistantProvider),
        selectedChatModel: _ref
            .read(chatStreamManagerProvider)
            .adapter
            .selectedProviderModelReference,
        synthesisDefaults: flow.blocks.any((b) => b.typeKey == BlockType.tts)
            ? _ref.read(synthesisConfigProvider).toMap()
            : const {});
    // The capture can turn an unbound assistant into the selected model.
    // Validate that exact frozen selection before any run record is saved.
    await _validateSnapshot(snapshot, inputs);
    return _submit(snapshot, inputs);
  }

  Future<TaskFlowDefinition> _prepareFlow(
      String flowId, List<FlowRunInput> inputs) async {
    await _ref.read(providerEntriesProvider.notifier).ready;
    await _ref.read(assistantProvider.notifier).ready;
    final flow = _ref
        .read(taskFlowListProvider)
        .where((f) => f.id == flowId)
        .firstOrNull;
    if (flow == null) {
      throw TaskFlowValidationException('任务流已删除，请重新选择', flowId: flowId);
    }
    if (flow.blocks.any((b) => b.typeKey == BlockType.tts)) {
      await _ref.read(synthesisConfigProvider.notifier).ready;
    }
    await validateTaskFlow(flow, inputs,
        providers: _ref.read(providerEntriesProvider),
        assistants: _ref.read(assistantProvider),
        fallbackChatEndpointType:
            _ref.read(chatStreamManagerProvider).adapter.endpointType);
    return flow;
  }

  List<FlowSubTask> _steps(TaskFlowDefinition flow) =>
      flow.blocks.asMap().entries.map((entry) {
        final block = entry.value;
        final def = block.getDefinition();
        return FlowSubTask(
            blockTypeKey: block.typeKey.name,
            blockLabel: def?.label ?? block.typeKey.name,
            subTaskId: 'pending_${block.typeKey.name}_${entry.key}',
            subTaskType: subTaskTypeFor(def?.typeKey),
            status: TaskStatus.waiting);
      }).toList();

  Future<List<String>> _submit(
      FlowLaunchSnapshot snapshot, List<FlowRunInput> inputs) async {
    if (_disposed) {
      throw StateError('任务流服务已关闭');
    }
    final flow = snapshot.flow;
    final batch = const Uuid().v4();
    final records = inputs
        .asMap()
        .entries
        .map((entry) => TaskFlowExecution(
            flowId: flow.id,
            flowName: flow.name,
            status: FlowExecutionStatus.waiting,
            batchId: batch,
            batchIndex: entry.key,
            snapshot: snapshot,
            subTasks: _steps(flow),
            inputText: entry.value.text,
            inputDurationSec: entry.value.durationSec,
            inputMimeType: entry.value.mimeType))
        .toList();
    if (!await _notifier.addExecutions(records)) {
      for (final record in records) {
        _notifier.interruptExecution(record.id, error: '无法保存执行记录，请检查存储后重试');
      }
      throw const TaskFlowPersistenceException('无法保存执行记录，尚未开始运行');
    }
    if (_disposed) {
      return records.map((e) => e.id).toList();
    }
    _startBatch(records.map((e) => e.id).toList());
    return records.map((e) => e.id).toList();
  }

  /// Serialize inputs within a batch; scheduler still shares its weighted
  /// budget with independently submitted batches.
  void _startBatch(List<String> ids) {
    var previous = Future<void>.value();
    for (final id in ids) {
      if (_workers.containsKey(id)) {
        continue;
      }
      final work = previous.then((_) => _runSaved(id));
      _workers[id] = work;
      previous = work;
      unawaited(work.whenComplete(() => _workers.remove(id)));
    }
  }

  Future<void> restorePendingExecutions() async {
    if (_disposed) {
      return;
    }
    await _ref.read(providerEntriesProvider.notifier).ready;
    if (_disposed) return;
    await _ref.read(assistantProvider.notifier).ready;
    if (_disposed) {
      return;
    }
    final waiting = _notifier.executions
        .where((e) => e.status == FlowExecutionStatus.waiting)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final batches = <String, List<TaskFlowExecution>>{};
    for (final e in waiting) {
      if (e.snapshot == null) {
        _notifier.interruptExecution(e.id, error: '旧记录没有运行快照，请选择使用最新配置重试');
        continue;
      }
      batches.putIfAbsent(e.batchId ?? e.id, () => []).add(e);
    }
    if (!await _notifier.persist()) {
      throw const TaskFlowPersistenceException('无法保存恢复队列');
    }
    for (final batch in batches.values) {
      batch.sort((a, b) => a.batchIndex.compareTo(b.batchIndex));
      _startBatch(batch.map((e) => e.id).toList());
    }
  }

  /// A retry creates a new record. Legacy histories require the explicit
  /// latest-config option because their original configuration is unknown.
  Future<List<String>> retryExecution(String id,
      {bool useLatestConfiguration = false}) async {
    final e = _execution(id);
    if (e == null) {
      throw StateError('执行记录已删除');
    }
    if (!e.isTerminal) {
      throw StateError('执行仍在运行，请先暂停或取消');
    }
    final inputs = [
      FlowRunInput(
          text: e.inputText,
          durationSec: e.inputDurationSec,
          mimeType: e.inputMimeType)
    ];
    if (useLatestConfiguration) {
      return launchFlowMany(e.flowId, inputs);
    }
    final snapshot = e.snapshot;
    if (snapshot == null) {
      throw TaskFlowValidationException('旧记录没有运行快照，请选择使用最新配置重试',
          flowId: e.flowId);
    }
    await _validateSnapshot(snapshot, inputs);
    return _submit(snapshot, inputs);
  }

  Future<void> _validateSnapshot(
      FlowLaunchSnapshot snapshot, List<FlowRunInput> inputs) async {
    await _ref.read(providerEntriesProvider.notifier).ready;
    await _ref.read(assistantProvider.notifier).ready;
    await validateTaskFlow(snapshot.flow, inputs,
        providers:
            snapshot.resolveProviders(_ref.read(providerEntriesProvider)),
        assistants: snapshot.resolveAssistants(_ref.read(assistantProvider)),
        fallbackChatEndpointType:
            _ref.read(chatStreamManagerProvider).adapter.endpointType);
    // The test-only block runner bypasses ChatAdapter; production chat blocks
    // need a captured endpoint. The adapter has no implicit first-model
    // fallback when an assistant has no binding or usable legacy name.
    if (_ref.read(taskFlowBlockRunnerProvider) == null) {
      final selected =
          (snapshot.toMap()['chatModels'] as List? ?? []).cast<Map>();
      final blocks = snapshot.flow.blocks;
      for (var index = 0; index < blocks.length; index++) {
        final block = blocks[index];
        if (block.typeKey == BlockType.chat &&
            !selected.any((item) => item['blockId'] == block.id)) {
          throw TaskFlowValidationException('助手模型未选择或不可用，请先在对话页选择模型或给助手设置默认模型',
              flowId: snapshot.flow.id, blockId: block.id, blockIndex: index);
        }
      }
    }
  }

  Future<void> _readable(FlowPayload payload, String flowId) async {
    final path = payload.fileReference;
    if (path == null) {
      return;
    }
    try {
      if (kIsWeb) {
        if ((await WebFileStore.read(path))?.isNotEmpty != true) {
          throw const FileSystemException();
        }
      } else {
        final file = await File(path).open();
        try {
          if ((await file.read(1)).isEmpty) {
            throw const FileSystemException();
          }
        } finally {
          await file.close();
        }
      }
    } catch (_) {
      throw TaskFlowValidationException('已保存的步骤文件不存在、为空或无法读取，请重新运行',
          flowId: flowId);
    }
  }

  Future<void> resumeExecution(String id) async {
    var current = _execution(id);
    if (current == null || !current.canResume) {
      throw StateError('此执行无法继续，请重试任务流');
    }
    final revision = _invalidateControl(id);
    await _ref.read(providerEntriesProvider.notifier).ready;
    if (_currentControl(id, revision) == null) return;
    await _ref.read(assistantProvider.notifier).ready;
    current = _currentControl(id, revision);
    if (current == null) return;
    for (final step in current.subTasks) {
      if (step.outcome != FlowStepOutcome.succeeded || step.result == null) {
        break;
      }
      await _readable(step.result!, current.flowId);
      if (_currentControl(id, revision) == null) return;
    }
    current = _currentControl(id, revision);
    if (current == null) return;
    if (_workers.containsKey(id) &&
        current.status == FlowExecutionStatus.paused) {
      // A batch future can still be waiting behind another input. Pending
      // steps must remain durable waiting records, ready for cold restoration.
      final hasActiveStep = current.subTasks.any((step) =>
          step.outcome == FlowStepOutcome.running ||
          step.outcome == FlowStepOutcome.paused);
      _synthesisResumeModels(current); // Fail before opening the pause gate.
      _resumePending[id] = revision;
      try {
        final activeType = _activeBlockTypes[id];
        final awaitingManualChoice = activeType == BlockType.catcatch &&
            _manualCatCatchWaits.containsValue(id);
        if ((activeType == BlockType.catcatch || activeType == BlockType.tts) &&
            !awaitingManualChoice &&
            !_scheduler.holds(id)) {
          try {
            await _scheduler.acquire(
                id, TaskFlowScheduler.weightFor(activeType!));
          } on FlowSchedulerCancelledException {
            if (_currentControl(id, revision) == null) return;
            rethrow;
          }
          current = _currentControl(id, revision);
          if (current == null || _activeBlockTypes[id] != activeType) {
            _scheduler.release(id);
            if (current == null) return;
          }
        }
        current = _currentControl(id, revision);
        if (current == null || current.status != FlowExecutionStatus.paused) {
          return;
        }
        _notifier.setExecutionStatus(
            id,
            hasActiveStep
                ? FlowExecutionStatus.running
                : FlowExecutionStatus.waiting);
        final saved = await _notifier.persist();
        current = _currentControl(id, revision);
        if (current == null) return;
        if (!saved) {
          _notifier.setExecutionStatus(id, FlowExecutionStatus.paused,
              error: '继续状态无法保存');
          if (activeType == BlockType.catcatch || activeType == BlockType.tts) {
            _scheduler.release(id);
          }
          throw const TaskFlowPersistenceException('无法保存继续状态');
        }
        try {
          _resumeUnderlying(current);
        } catch (error) {
          _notifier.setExecutionStatus(id, FlowExecutionStatus.paused,
              error: error.toString());
          if (activeType == BlockType.catcatch || activeType == BlockType.tts) {
            _scheduler.release(id);
          }
          await _notifier.persist();
          rethrow;
        }
        if (_currentControl(id, revision) != null) {
          _pauseGates.remove(id)?.complete();
        }
      } finally {
        if (_resumePending[id] == revision) _resumePending.remove(id);
      }
      return;
    }
    final runningWorker = _workers[id];
    if (runningWorker != null) {
      await runningWorker;
    }
    current = _currentControl(id, revision);
    if (current == null) return;
    final snapshot = current.snapshot!;
    var prefix = 0;
    for (final step in current.subTasks) {
      if (step.outcome != FlowStepOutcome.succeeded || step.result == null) {
        break;
      }
      prefix++;
    }
    final flow = snapshot.flow;
    final data = prefix == 0
        ? FlowPayload.fromValue(current.inputText, flow.inputType,
            mimeType: current.inputMimeType)
        : current.subTasks[prefix - 1].result!;
    await _readable(data, current.flowId);
    current = _currentControl(id, revision);
    if (current == null) return;
    final remaining = flow.blocks.skip(prefix).toList();
    if (remaining.isNotEmpty) {
      await validateTaskFlow(
          flow.copyWith(inputType: data.type, blocks: remaining),
          [
            FlowRunInput(
                text: data.value,
                durationSec: current.inputDurationSec,
                mimeType: data.mimeType)
          ],
          providers: snapshot.resolveProviders(
              _ref.read(providerEntriesProvider),
              blocks: remaining),
          assistants: snapshot.resolveAssistants(_ref.read(assistantProvider)),
          fallbackChatEndpointType:
              _ref.read(chatStreamManagerProvider).adapter.endpointType);
      current = _currentControl(id, revision);
      if (current == null) return;
    }
    _stopUnderlying(current, remove: true, invalidateControl: false);
    _notifier.prepareResume(id);
    final saved = await _notifier.persist();
    if (_currentControl(id, revision) == null) return;
    if (!saved) {
      _notifier.interruptExecution(id, error: '无法保存恢复状态');
      throw const TaskFlowPersistenceException('无法保存恢复状态');
    }
    _startBatch([id]);
  }

  Future<void> pauseExecution(String id) async {
    final e = _execution(id);
    if (e == null) return;
    final revision = _invalidateControl(id);
    if (e.isTerminal) return;
    if (e.status == FlowExecutionStatus.paused) {
      // A second pause can race a resume waiting to reacquire resources.
      // Remove that reservation request so it cannot block the FIFO queue.
      if (_resumePending.containsKey(id)) _scheduler.cancel(id);
      return;
    }
    _notifier.setExecutionStatus(id, FlowExecutionStatus.paused);
    _scheduler.pause(id);
    for (final step
        in e.subTasks.where((s) => s.outcome == FlowStepOutcome.running)) {
      switch (step.subTaskType) {
        case 'catcatch':
          _ref.read(catcatchTasksProvider.notifier).pauseTask(step.subTaskId);
        case 'synthesis':
          _ref.read(taskListProvider.notifier).pauseTask(step.subTaskId);
        default:
          break; // network/convert blocks finish into a saved checkpoint
      }
    }
    final activeType = _activeBlockTypes[id];
    if (activeType == null ||
        activeType == BlockType.catcatch ||
        activeType == BlockType.tts) {
      _scheduler.release(id);
    }
    if (!await _notifier.persist()) {
      if (_currentControl(id, revision) != null) {
        _notifier.setExecutionStatus(id, FlowExecutionStatus.paused,
            error: '暂停状态无法保存，重新启动后请检查此执行');
      }
      throw const TaskFlowPersistenceException('已暂停，但无法保存暂停状态');
    }
  }

  Map<String, ProviderModel> _synthesisResumeModels(TaskFlowExecution e) {
    final selected = <String, ProviderModel>{};
    final snapshot = e.snapshot!;
    final blocks = snapshot.flow.blocks;
    for (var i = 0; i < e.subTasks.length; i++) {
      final step = e.subTasks[i];
      if (step.subTaskType != 'synthesis' ||
          step.subTaskId.startsWith('pending_') ||
          (step.outcome != FlowStepOutcome.paused &&
              step.outcome != FlowStepOutcome.running)) {
        continue;
      }
      final block = blocks[i];
      final providers = snapshot.resolveProviders(
          _ref.read(providerEntriesProvider),
          blocks: [block]);
      final model =
          resolveProviderModel(providers, 'tts', block.params['modelRef']);
      if (model == null) throw StateError('合成模型已删除或不可用，请使用最新配置重试');
      selected[step.id] = model;
    }
    return selected;
  }

  void _resumeUnderlying(TaskFlowExecution e) {
    final synthesis = _synthesisResumeModels(e);
    for (final step in e.subTasks.where((s) =>
        !s.subTaskId.startsWith('pending_') &&
        (s.outcome == FlowStepOutcome.paused ||
            s.outcome == FlowStepOutcome.running))) {
      switch (step.subTaskType) {
        case 'catcatch':
          _ref.read(catcatchTasksProvider.notifier).resumeTask(step.subTaskId);
        case 'synthesis':
          final model = synthesis[step.id]!;
          _ref.read(taskListProvider.notifier).resumeTask(step.subTaskId,
              providerConfig: model.config, modelConfig: model.model);
        default:
          break;
      }
    }
  }

  Future<void> cancelExecution(String id) async {
    final e = _execution(id);
    if (e == null || e.isTerminal) {
      return;
    }
    _notifier.cancelExecution(id);
    _stopUnderlying(e, remove: true);
    if (!await _notifier.persist()) {
      _notifier.setExecutionStatus(id, FlowExecutionStatus.cancelled,
          error: '取消状态无法保存，重新启动后请再次取消');
      throw const TaskFlowPersistenceException('已取消，但无法保存取消状态，重新启动后请检查此执行');
    }
  }

  Future<void> cancelBatch(String batchId) async {
    final records = _notifier.executions
        .where((e) => e.batchId == batchId && !e.isTerminal)
        .toList();
    for (final e in records) {
      _notifier.cancelExecution(e.id);
      _stopUnderlying(e, remove: true);
    }
    if (!await _notifier.persist()) {
      for (final e in records) {
        _notifier.setExecutionStatus(e.id, FlowExecutionStatus.cancelled,
            error: '批次取消状态无法保存，重新启动后请再次取消');
      }
      throw const TaskFlowPersistenceException('批次已取消，但无法保存取消状态，重新启动后请检查队列');
    }
  }

  void _stopUnderlying(TaskFlowExecution e,
      {required bool remove, bool invalidateControl = true}) {
    if (invalidateControl) _invalidateControl(e.id);
    cancelActiveRequest(e.id);
    _scheduler.cancel(e.id);
    _scheduler.release(e.id);
    _manualCatCatchWaits.removeWhere((_, executionId) => executionId == e.id);
    _resumePending.remove(e.id);
    _pauseGates.remove(e.id)?.complete();
    _stopActions.remove(e.id)?.call(e);
  }

  Future<void> _waitUnpaused(String id) async {
    while (_live(id) &&
        (_execution(id)?.status == FlowExecutionStatus.paused ||
            _resumePending.containsKey(id))) {
      final gate = _pauseGates.putIfAbsent(id, () => Completer<void>());
      await gate.future;
    }
  }

  Future<bool> _ensureBlockSlot(
      String id, TaskFlowScheduler scheduler, int weight) async {
    while (_live(id)) {
      await _waitUnpaused(id);
      if (!_live(id)) return false;
      if (!scheduler.holds(id)) {
        try {
          await scheduler.acquire(id, weight);
        } on FlowSchedulerPausedException {
          continue;
        }
      }
      if (_execution(id)?.status == FlowExecutionStatus.paused ||
          _resumePending.containsKey(id)) {
        scheduler.release(id);
        continue;
      }
      return _live(id);
    }
    return false;
  }

  Future<void> _runSaved(String id) async {
    if (!_live(id)) {
      return;
    }
    final original = _execution(id)!;
    final snapshot = original.snapshot;
    if (snapshot == null) {
      return;
    }
    final TaskFlowDefinition flow;
    try {
      flow = snapshot.flow;
    } catch (_) {
      _notifier.interruptExecution(id, error: '运行快照无法读取，请使用最新配置重试');
      await _notifier.persist();
      return;
    }
    var current = FlowPayload.fromValue(original.inputText, flow.inputType,
        mimeType: original.inputMimeType);
    final scheduler = _ref.read(taskFlowSchedulerProvider);
    String? activeStepId;
    try {
      for (var i = 0; i < flow.blocks.length; i++) {
        await _waitUnpaused(id);
        if (!_live(id)) {
          return;
        }
        final step = _execution(id)!.subTasks[i];
        if (step.outcome == FlowStepOutcome.succeeded && step.result != null) {
          await _readable(step.result!, flow.id);
          current = step.result!;
          continue;
        }
        activeStepId = step.id;
        final block = flow.blocks[i];
        final def = block.getDefinition();
        if (def == null) {
          throw BlockExecutionException('未知功能块类型');
        }
        _notifier.setExecutionStatus(id, FlowExecutionStatus.waiting);
        _notifier.setExecutionQueued(id, true);
        final weight = TaskFlowScheduler.weightFor(def.typeKey);
        if (!await _ensureBlockSlot(id, scheduler, weight)) {
          return;
        }
        _notifier.setExecutionStatus(id, FlowExecutionStatus.running);
        _notifier.updateSubTaskStatus(id, step.id, TaskStatus.running);
        if (!await _notifier.persist()) {
          throw const TaskFlowPersistenceException('无法保存步骤启动状态');
        }
        if (!await _ensureBlockSlot(id, scheduler, weight)) {
          return;
        }
        final runner = _ref.read(taskFlowBlockRunnerProvider);
        final FlowPayload result;
        _activeBlockTypes[id] = def.typeKey;
        try {
          result = runner != null
              ? await runner(block, current, id, step)
              : await _executeBlock(def, block, current, id, _notifier,
                  flowSubTask: step,
                  catcatchNotifier: _ref.read(catcatchTasksProvider.notifier),
                  bgNotifier: _ref.read(backgroundTasksProvider.notifier),
                  taskListNotifier: _ref.read(taskListProvider.notifier),
                  providerEntries: snapshot.resolveProviders(
                      _ref.read(providerEntriesProvider),
                      blocks: [block]),
                  inputDurationSec: original.inputDurationSec,
                  nextInputType: i + 1 < flow.blocks.length
                      ? flow.blocks[i + 1].getDefinition()?.inputType
                      : null);
        } finally {
          _activeBlockTypes.remove(id);
          _manualCatCatchWaits
              .removeWhere((_, executionId) => executionId == id);
          scheduler.release(id);
        }
        if (!_live(id)) {
          return;
        }
        if (!await _notifier.saveStepResult(id, step.id, result)) {
          throw const TaskFlowPersistenceException('无法保存步骤结果，后续步骤尚未运行');
        }
        current = result;
      }
      await _waitUnpaused(id);
      if (!_live(id)) {
        return;
      }
      _notifier.completeExecution(id);
      if (!await _notifier.persist() && !_disposed && _execution(id) != null) {
        _notifier.setExecutionStatus(id, FlowExecutionStatus.interrupted,
            error: '步骤已完成，但无法保存完成状态，请检查存储后继续');
      }
    } on FlowSchedulerCancelledException {
      return;
    } catch (error) {
      if (!_live(id)) {
        return;
      }
      if (error is TaskFlowPersistenceException) {
        _notifier.interruptExecution(id, error: error.toString());
      } else {
        if (activeStepId != null) {
          _notifier.updateSubTaskStatus(id, activeStepId, TaskStatus.failed);
        }
        _notifier.failExecution(id, error: error.toString());
      }
      await _notifier.persist();
    } finally {
      scheduler.release(id);
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    final records = _notifier.mounted
        ? _notifier.executions.where((e) => _workers.containsKey(e.id)).toList()
        : <TaskFlowExecution>[];
    _disposed = true;
    _resumePending.clear();
    _manualCatCatchWaits.clear();
    for (final token in _activeRequestCancelTokens.values) {
      if (!token.isCancelled) token.cancel();
    }
    _activeRequestCancelTokens.clear();
    for (final e in records) {
      _scheduler.cancel(e.id);
      _scheduler.release(e.id);
      _pauseGates.remove(e.id)?.complete();
    }
    // Riverpod lifecycle callbacks cannot mutate other providers. Captured
    // notifiers allow cleanup after the callback, without using a dead Ref.
    scheduleMicrotask(() {
      for (final e in records) {
        _stopActions[e.id]?.call(e);
      }
      _stopActions.clear();
      if (!_notifier.mounted) {
        return;
      }
      for (final e in records) {
        if (e.status == FlowExecutionStatus.running) {
          _notifier.interruptExecution(e.id, error: '执行中断，可从已保存的步骤继续');
        }
      }
    });
  }

  Future<FlowPayload> _executeBlock(
    BlockTypeDefinition def,
    TaskFlowBlock block,
    FlowPayload input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required CatCatchNotifier catcatchNotifier,
    required BackgroundTaskNotifier bgNotifier,
    required TaskListNotifier taskListNotifier,
    required ProviderEntriesState providerEntries,
    int inputDurationSec = 0,
    IOType? nextInputType,
  }) async {
    final manager = def.typeKey == BlockType.chat
        ? _ref.read(chatStreamManagerProvider)
        : null;
    _stopActions[execId] = (e) {
      final realId = e.subTasks
              .where((s) => s.id == flowSubTask.id)
              .firstOrNull
              ?.subTaskId ??
          flowSubTask.subTaskId;
      if (realId.startsWith('pending_')) {
        return;
      }
      switch (flowSubTask.subTaskType) {
        case 'catcatch':
          if (catcatchNotifier.mounted) catcatchNotifier.removeTask(realId);
        case 'synthesis':
          if (taskListNotifier.mounted) taskListNotifier.removeTask(realId);
        default:
          manager?.cancel('flow_${execId}_${flowSubTask.id}');
          if (bgNotifier.mounted) bgNotifier.removeTask(realId);
      }
    };
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
        inputDurationSec: inputDurationSec,
        nextInputType: nextInputType,
      );
    } finally {
      _activeRequestCancelTokens.remove(execId);
      _stopActions.remove(execId);
      scheduler.release(execId);
    }
  }

  Future<FlowPayload> _executeBlockInner(
    BlockTypeDefinition def,
    TaskFlowBlock block,
    FlowPayload input,
    String execId,
    TaskFlowExecutionNotifier execNotifier, {
    required FlowSubTask flowSubTask,
    required CatCatchNotifier catcatchNotifier,
    required BackgroundTaskNotifier bgNotifier,
    required TaskListNotifier taskListNotifier,
    required ProviderEntriesState providerEntries,
    int inputDurationSec = 0,
    IOType? nextInputType,
  }) async {
    if (!def.acceptsInput(input.type)) {
      execNotifier.updateSubTaskStatus(
          execId, flowSubTask.id, TaskStatus.failed);
      throw BlockExecutionException(
        '上一步实际输出为${input.type.label}，「${def.label}」需要${def.inputType.label}，请修改资源选择或输出类型',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    switch (def.typeKey) {
      case BlockType.catcatch:
        var actualType = def.outputType;
        FlowPayload? outputPayload;
        final result = await executeCatCatchBlock(
          def: def,
          block: block,
          input: input.value,
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          catcatchNotifier: catcatchNotifier,
          videoFolder: block.params['videoFolder'] ?? '',
          audioFolder: block.params['audioFolder'] ?? '',
          // Per-run duration from the run-mode input box wins over the
          // block's configured duration (0 = use the configured value).
          durationSecOverride: inputDurationSec,
          nextInputType: nextInputType,
          onManualWait: (taskId) => _releaseManualCatCatchSlot(execId, taskId),
          onOutputType: (type) => actualType = type,
          onOutputPayload: (payload) => outputPayload = payload,
        );
        return outputPayload ?? FlowPayload.fromValue(result, actualType);
      case BlockType.audioSeparation:
        return FlowPayload.fromValue(
            await executeAudioSeparationBlock(
              def: def,
              block: block,
              input: input.value,
              execId: execId,
              execNotifier: execNotifier,
              flowSubTask: flowSubTask,
              bgNotifier: bgNotifier,
            ),
            def.outputType);
      case BlockType.asr:
        return FlowPayload.fromValue(
            await executeAsrBlock(
              block: block,
              def: def,
              input: input.value,
              execId: execId,
              execNotifier: execNotifier,
              flowSubTask: flowSubTask,
              bgNotifier: bgNotifier,
              providerEntries: providerEntries,
              cancelToken: _activeRequestCancelTokens[execId],
            ),
            def.outputType);
      case BlockType.ocr:
        return FlowPayload.fromValue(
            await executeOcrBlock(
              block: block,
              def: def,
              input: input.value,
              execId: execId,
              execNotifier: execNotifier,
              flowSubTask: flowSubTask,
              bgNotifier: bgNotifier,
              providerEntries: providerEntries,
              cancelToken: _activeRequestCancelTokens[execId],
            ),
            def.outputType);
      case BlockType.tts:
        return FlowPayload.fromValue(
            await executeTtsBlock(
              block: block,
              def: def,
              input: input.value,
              execId: execId,
              execNotifier: execNotifier,
              flowSubTask: flowSubTask,
              taskListNotifier: taskListNotifier,
              providerEntries: providerEntries,
            ),
            def.outputType);
      case BlockType.chat:
        // Resolve the block's assistantId (empty = use the currently
        // selected assistant). Only user-defined assistants are allowed
        // on blocks — a legacy built-in prompt id resolves to null and
        // fails loudly below.
        final assistantId = block.params['assistantId']?.toString() ?? '';
        final chatAssistant = resolveChatAssistant(
          assistantId,
          _execution(execId)
                  ?.snapshot
                  ?.resolveAssistants(_ref.read(assistantProvider)) ??
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
        return FlowPayload.fromValue(
            await executeChatBlock(
              block: block,
              def: def,
              input: input.value,
              payload: input,
              execId: execId,
              execNotifier: execNotifier,
              flowSubTask: flowSubTask,
              bgNotifier: bgNotifier,
              chatManager: _ref.read(chatStreamManagerProvider),
              conversationsNotifier: _ref.read(conversationsProvider.notifier),
              assistant: chatAssistant,
              providerEntries: providerEntries,
              endpointType: flowChatEndpointType(chatAssistant, providerEntries,
                  fallback: _ref
                      .read(chatStreamManagerProvider)
                      .adapter
                      .endpointType),
            ),
            def.outputType);
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
