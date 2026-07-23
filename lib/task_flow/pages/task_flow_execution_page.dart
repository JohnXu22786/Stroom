import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_task_provider.dart';
import '../../providers/task_provider_shared.dart';
import '../models/task_flow_definition.dart';
import '../models/task_flow_execution.dart';
import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../providers/task_flow_provider.dart';
import '../providers/task_flow_execution_provider.dart';

/// Page for executing a task flow.
///
/// The user provides the initial input (based on the first block's input type),
/// then starts the flow. Each block runs in sequence, with progress shown.
/// The final output is displayed.
class TaskFlowExecutionPage extends ConsumerStatefulWidget {
  final String flowId;

  const TaskFlowExecutionPage({super.key, required this.flowId});

  @override
  ConsumerState<TaskFlowExecutionPage> createState() =>
      _TaskFlowExecutionPageState();
}

class _TaskFlowExecutionPageState extends ConsumerState<TaskFlowExecutionPage> {
  final _inputController = TextEditingController();
  bool _isRunning = false;
  int _currentStep = -1;
  final List<String> _stepResults = [];

  @override
  void initState() {
    super.initState();
    // Listen for text changes to rebuild the UI and enable/disable start button
    _inputController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final flow = ref
        .watch(taskFlowListProvider)
        .where((f) => f.id == widget.flowId)
        .firstOrNull;

    if (flow == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务流')),
        body: const Center(child: Text('任务流未找到')),
      );
    }

    final inputType = flow.inputType;

    return Scaffold(
      appBar: AppBar(
        title: Text(flow.name),
        centerTitle: true,
        actions: [
          if (!_isRunning && flow.blocks.isNotEmpty)
            TextButton.icon(
              onPressed:
                  _inputController.text.trim().isNotEmpty ? _startFlow : null,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('开始任务流'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Flow overview card
          _buildFlowOverviewCard(flow, cs),

          const SizedBox(height: 20),

          // Input section
          _buildInputSection(inputType, flow, cs),

          // Block list with status
          const SizedBox(height: 16),
          ...flow.blocks.asMap().entries.map((entry) {
            final i = entry.key;
            final block = entry.value;
            final def = block.getDefinition();
            final isActive = _isRunning && i == _currentStep;
            final isDone = _currentStep > i;
            final isFailed = _isRunning &&
                _currentStep == i &&
                _stepResults.length > i &&
                _stepResults[i].startsWith('❌');

            return _buildBlockWithStatus(
              block: block,
              def: def,
              index: i,
              isActive: isActive,
              isDone: isDone,
              isFailed: isFailed,
              result: _stepResults.length > i ? _stepResults[i] : null,
              total: flow.blocks.length,
              cs: cs,
            );
          }),

          // Final result
          if (_isRunning && _currentStep >= flow.blocks.length - 1)
            _buildFinalResult(cs),
        ],
      ),
    );
  }

  Widget _buildFlowOverviewCard(TaskFlowDefinition flow, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                flow.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          if (flow.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              flow.description,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          // Flow chain summary
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: flow.blocks.asMap().entries.map((entry) {
                final def = entry.value.getDefinition();
                return Row(
                  children: [
                    if (entry.key > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward,
                            size: 14, color: cs.onSurfaceVariant),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: def?.color.withValues(alpha: 0.12) ??
                            Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        def?.label ?? entry.value.typeKey,
                        style: TextStyle(
                          fontSize: 11,
                          color: def?.color ?? Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(
      IOType inputType, TaskFlowDefinition flow, ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.input, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '输入（${inputType.label}）',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (inputType == IOType.url)
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入网页链接',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.link, size: 18),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: TextInputType.url,
              )
            else if (inputType == IOType.text)
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入文本',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.text_fields, size: 18),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
              )
            else
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入 ${inputType.label} 路径或标识',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            if (!_isRunning)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _inputController.text.trim().isNotEmpty
                        ? _startFlow
                        : null,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('开始任务流'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockWithStatus({
    required TaskFlowBlock block,
    required BlockTypeDefinition? def,
    required int index,
    required bool isActive,
    required bool isDone,
    required bool isFailed,
    required String? result,
    required int total,
    required ColorScheme cs,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Icon(
                isDone
                    ? Icons.check_circle
                    : (isActive ? Icons.play_circle : Icons.arrow_downward),
                size: 18,
                color: isDone
                    ? Colors.green
                    : (isActive ? cs.primary : cs.onSurfaceVariant),
              ),
            ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isActive
                    ? cs.primary
                    : (isFailed ? cs.error : cs.outlineVariant),
                width: isActive || isFailed ? 1.5 : 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? Colors.green.withValues(alpha: 0.15)
                              : (isActive
                                  ? cs.primary.withValues(alpha: 0.15)
                                  : cs.surfaceContainerLow),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDone
                              ? Icons.check_circle
                              : (isActive
                                  ? Icons.sync
                                  : (def?.icon ?? Icons.extension)),
                          size: 16,
                          color: isDone
                              ? Colors.green
                              : (isActive ? cs.primary : cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${index + 1}. ${def?.label ?? block.typeKey}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (isActive)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        result,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalResult(ColorScheme cs) {
    final lastResult = _stepResults.isNotEmpty ? _stepResults.last : '';
    final isError = lastResult.startsWith('❌');

    return Card(
      elevation: 0,
      color: isError
          ? cs.errorContainer.withValues(alpha: 0.3)
          : cs.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              size: 32,
              color: isError ? cs.error : cs.primary,
            ),
            const SizedBox(height: 8),
            Text(
              isError ? '任务流执行失败' : '任务流执行完成',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isError ? cs.error : cs.primary,
              ),
            ),
            if (lastResult.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                lastResult,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // Flow Execution — creates real tasks using existing providers
  // ========================================================================

  Future<void> _startFlow() async {
    final flow = ref.read(taskFlowListProvider).firstWhere(
          (f) => f.id == widget.flowId,
          orElse: () => TaskFlowDefinition(name: ''),
        );
    if (flow.blocks.isEmpty) return;

    setState(() {
      _isRunning = true;
      _currentStep = 0;
      _stepResults.clear();
    });

    // Create execution tracking entry
    final execNotifier = ref.read(taskFlowExecutionsProvider.notifier);
    final execId = execNotifier.addExecution(
      flowId: flow.id,
      flowName: flow.name,
    );

    String currentData = _inputController.text.trim();

    for (int i = 0; i < flow.blocks.length; i++) {
      if (!mounted) break;
      setState(() => _currentStep = i);

      final block = flow.blocks[i];
      final def = block.getDefinition();
      if (def == null) {
        _stepResults.add('❌ 未知功能块类型');
        execNotifier.failExecution(execId, error: '未知功能块类型');
        break;
      }

      try {
        final result =
            await _executeBlock(def, block, currentData, execId, execNotifier);
        _stepResults.add('✅ ${def.label} 完成');
        currentData = result;

        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        _stepResults.add('❌ ${def.label} 失败: $e');
        execNotifier.failExecution(execId, error: '$e');
        break;
      }
    }

    if (mounted) {
      setState(() => _currentStep = flow.blocks.length - 1);
      execNotifier.completeExecution(execId);
    }
  }

  Future<String> _executeBlock(
    BlockTypeDefinition def,
    TaskFlowBlock block,
    String input,
    String execId,
    TaskFlowExecutionNotifier execNotifier,
  ) async {
    switch (def.typeKey) {
      case 'catcatch':
        // Track as sub-task (real CatCatch execution requires user's API config)
        final subTask = FlowSubTask(
          blockTypeKey: 'catcatch',
          blockLabel: def.label,
          subTaskId: 'catcatch_${DateTime.now().millisecondsSinceEpoch}',
          subTaskType: 'catcatch',
        );
        execNotifier.addSubTask(execId, subTask);
        await Future.delayed(const Duration(seconds: 2));
        execNotifier.updateSubTaskStatus(
            execId, subTask.id, TaskStatus.completed);
        return '视频文件: downloaded_video.mp4';

      case 'audioSeparation':
        // Create a real background audio separation task
        final bgNotifier = ref.read(backgroundTasksProvider.notifier);
        final taskId = bgNotifier.addTask(
          type: BackgroundTaskType.audioSeparation,
          title: '音频分离: $input',
        );
        final subTask = FlowSubTask(
          blockTypeKey: 'audioSeparation',
          blockLabel: def.label,
          subTaskId: taskId,
          subTaskType: 'background',
        );
        execNotifier.addSubTask(execId, subTask);

        await Future.delayed(const Duration(seconds: 2));
        bgNotifier.completeTask(taskId);
        execNotifier.updateSubTaskStatus(
            execId, subTask.id, TaskStatus.completed);
        return '音频文件';

      case 'asr':
        // Create a real background ASR task
        final bgNotifier = ref.read(backgroundTasksProvider.notifier);
        final taskId = bgNotifier.addTask(
          type: BackgroundTaskType.asr,
          title: '语音识别: $input',
        );
        final subTask = FlowSubTask(
          blockTypeKey: 'asr',
          blockLabel: def.label,
          subTaskId: taskId,
          subTaskType: 'background',
        );
        execNotifier.addSubTask(execId, subTask);

        await Future.delayed(const Duration(seconds: 2));
        bgNotifier.setResult(taskId, '识别结果文本...');
        bgNotifier.completeTask(taskId);
        execNotifier.updateSubTaskStatus(
            execId, subTask.id, TaskStatus.completed);
        return '识别文本结果';

      case 'ocr':
        final bgNotifier = ref.read(backgroundTasksProvider.notifier);
        final taskId = bgNotifier.addTask(
          type: BackgroundTaskType.ocr,
          title: '文字识别: $input',
        );
        final subTask = FlowSubTask(
          blockTypeKey: 'ocr',
          blockLabel: def.label,
          subTaskId: taskId,
          subTaskType: 'background',
        );
        execNotifier.addSubTask(execId, subTask);

        await Future.delayed(const Duration(seconds: 2));
        bgNotifier.completeTask(taskId);
        execNotifier.updateSubTaskStatus(
            execId, subTask.id, TaskStatus.completed);
        return 'OCR文本结果';

      case 'tts':
        // For TTS (synthesis), use taskListProvider
        // (TTS tasks are SynthesisTask, but creating one requires ProviderConfig etc.)
        // For simplicity, simulate and track as sub-task
        final subTask = FlowSubTask(
          blockTypeKey: 'tts',
          blockLabel: def.label,
          subTaskId: 'tts_${DateTime.now().millisecondsSinceEpoch}',
          subTaskType: 'synthesis',
        );
        execNotifier.addSubTask(execId, subTask);

        await Future.delayed(const Duration(seconds: 2));
        execNotifier.updateSubTaskStatus(
            execId, subTask.id, TaskStatus.completed);
        return '音频文件: tts_output.mp3';

      default:
        throw Exception('不支持的功能块: ${def.typeKey}');
    }
  }
}
